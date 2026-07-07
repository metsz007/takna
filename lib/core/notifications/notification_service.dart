import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../database/database.dart';
import '../scheduler/scheduler.dart';
import 'sounds.dart';

const snoozeActionId = 'snooze';
const dismissActionId = 'dismiss';

// Real-alarm behavior: rings on the ALARM audio stream, repeats until
// dismissed (FLAG_INSISTENT), and pops full-screen over the lock screen.
// New channel id — channel settings are immutable once created.
final _channel = AndroidNotificationDetails(
  'takna_alarms',
  'Alarms',
  channelDescription: 'Reminder alarms that ring until dismissed',
  importance: Importance.max,
  priority: Priority.max,
  category: AndroidNotificationCategory.alarm,
  audioAttributesUsage: AudioAttributesUsage.alarm,
  fullScreenIntent: true,
  additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: loops until dismissed
  actions: _actions,
);

// Notification-only mode: a normal heads-up notification — sounds once,
// no full-screen takeover, no looping.
final _notifChannel = AndroidNotificationDetails(
  'takna_notifications',
  'Notifications',
  channelDescription: 'Reminders shown as regular notifications',
  importance: Importance.high,
  priority: Priority.high,
  category: AndroidNotificationCategory.reminder,
  actions: _actions,
);

const _actions = [
  AndroidNotificationAction(snoozeActionId, 'Snooze', cancelNotification: true),
  AndroidNotificationAction(dismissActionId, 'Dismiss', cancelNotification: true),
];

/// Resolves the device-reported IANA id [candidate] to a tz-database
/// location name. Trusts a known id verbatim; if it's null or not in the
/// database, falls back to the current-offset scan, then UTC. Pure — the
/// platform-channel call is the caller's job. Assumes tz data is already
/// initialized (init() does this before calling).
String resolveTimeZoneName(String? candidate) {
  if (candidate != null &&
      tz.timeZoneDatabase.locations.containsKey(candidate)) {
    return candidate;
  }
  // ponytail: offset scan kept as fallback if the plugin throws or reports
  // an id not in the tz database — a wrong-DST sibling still beats UTC.
  // Ceiling: same DST-ambiguity as before, but only on the rare fallback
  // path now, not every launch.
  try {
    final offset = DateTime.now().timeZoneOffset;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      if (tz.getLocation(name).timeZone(now).offset == offset) return name;
    }
  } catch (_) {}
  return 'UTC';
}

/// Payload format: "notificationId|snoozeMinutes|reminderId|title".
({int id, int snoozeMinutes, String reminderId, String title}) parsePayload(
    String? payload) {
  final parts = (payload ?? '').split('|');
  return (
    id: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
    snoozeMinutes: parts.length > 1 ? int.tryParse(parts[1]) ?? 5 : 5,
    reminderId: parts.length > 2 ? parts[2] : '',
    title: parts.length > 3 ? parts.sublist(3).join('|') : 'Reminder',
  );
}

/// Routes a notification-body tap. Alarm-mode reminders (the default) open the
/// ringing full-screen alarm; notification-mode reminders open their detail
/// page instead. Unknown/missing reminder → alarm (preserves prior behavior).
/// [go] mirrors GoRouter.go so this stays testable without a real router.
Future<void> routeNotificationTap(String? payload, AppDatabase db,
    void Function(String location, {Object? extra}) go) async {
  final reminderId = parsePayload(payload).reminderId;
  final reminder = reminderId.isEmpty ? null : await db.getById(reminderId);
  if (reminder?.isAlarm != false) {
    go('/alarm', extra: payload);
  } else {
    go('/detail/$reminderId');
  }
}

/// Applies a notification action to the DB and re-arms the rolling window.
/// Snooze persists snoozedUntil (survives reboots, shown in the UI) then
/// reconciles; Dismiss persists dismissedUntil — the record that stops a
/// nagging reminder's remaining re-rings — then reconciles, which also
/// auto-disables fired one-time reminders. Other actions are no-ops. This is
/// the exact code the dead-app background isolate runs, so a shade Dismiss
/// survives to the next reconcile with no extra wiring.
Future<void> handleNotificationAction(
    String? actionId, String? payload, AppDatabase db, NotificationService service) async {
  final p = parsePayload(payload);
  if (actionId == snoozeActionId) {
    await db.setSnoozedUntil(
        p.reminderId, DateTime.now().add(Duration(minutes: p.snoozeMinutes)));
    await db.logFired(p.reminderId, p.title, 'snoozed');
  } else if (actionId == dismissActionId) {
    await db.setDismissedUntil(p.reminderId, DateTime.now());
    await db.logFired(p.reminderId, p.title, 'dismissed');
  } else {
    return;
  }
  await Scheduler(db, service).reconcile();
}

/// Foreground response dispatch: a body tap (no actionId) routes to the alarm
/// or detail page; a Snooze/Dismiss action button applies its DB effect and
/// re-arms the window. main wires this to the plugin's foreground callback;
/// takes plain actionId/payload so it's testable without a NotificationResponse.
Future<void> dispatchNotificationResponse(
    String? actionId,
    String? payload,
    AppDatabase db,
    NotificationService service,
    void Function(String location, {Object? extra}) go) async {
  if (actionId == null) {
    await routeNotificationTap(payload, db, go);
  } else {
    await handleNotificationAction(actionId, payload, db, service);
  }
}

/// Handles Snooze/Dismiss taps while the app is dead. Runs in a background
/// isolate, so it bootstraps its own plugin/database instances.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) async {
  if (response.actionId != snoozeActionId &&
      response.actionId != dismissActionId) {
    return;
  }
  final service = NotificationService();
  await service.init(handleForeground: false);
  final db = AppDatabase();
  try {
    await handleNotificationAction(response.actionId, response.payload, db, service);
  } finally {
    await db.close();
  }
}

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(NotificationResponse)? onForegroundResponse;

  Future<void> init({bool handleForeground = true}) async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _localTimeZoneName()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse:
          handleForeground ? (r) => onForegroundResponse?.call(r) : null,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    // Create the channel up front so its system settings page (where the
    // user picks the alarm sound) exists before the first alarm fires.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'takna_alarms',
          'Alarms',
          description: 'Reminder alarms that ring until dismissed',
          importance: Importance.max,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ));
  }

  Future<String> _localTimeZoneName() async {
    String? id;
    try {
      id = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    return resolveTimeZoneName(id);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// Payload if the app was launched by tapping / full-screening a
  /// notification, else null.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final response = details!.notificationResponse;
    if (response?.actionId != null) return null; // action buttons handled elsewhere
    return response?.payload;
  }

  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime when,
    required int snoozeMinutes,
    required String reminderId,
    bool isAlarm = true,
    String? soundKey,
  }) =>
      _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(
          android: isAlarm ? _channel : _notifChannel,
          // null (system default or unknown key) → the framework default sound,
          // i.e. no behavior change for existing reminders.
          iOS: DarwinNotificationDetails(
              sound: iosSoundFor(soundKey),
              interruptionLevel: isAlarm
                  ? InterruptionLevel.timeSensitive
                  : InterruptionLevel.active),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$id|$snoozeMinutes|$reminderId|$title',
      );
}
