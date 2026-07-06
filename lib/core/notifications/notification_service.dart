import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../database/database.dart';
import '../scheduler/scheduler.dart';

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

/// Handles Snooze taps while the app is dead. Runs in a background isolate,
/// so it bootstraps its own plugin/database instances. The snooze is
/// persisted on the reminder so the UI shows it and it survives reboots.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) async {
  if (response.actionId != snoozeActionId) return;
  final p = parsePayload(response.payload);
  final service = NotificationService();
  await service.init(handleForeground: false);
  final db = AppDatabase();
  try {
    await db.setSnoozedUntil(
        p.reminderId, DateTime.now().add(Duration(minutes: p.snoozeMinutes)));
    await Scheduler(db, service).reconcile();
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
    // ponytail: DateTime.now().timeZoneName gives abbreviations, not IANA ids;
    // tz.local defaults to UTC otherwise. Use offset match as pragmatic v1
    // fallback; swap in flutter_timezone package if this misfires for users.
    try {
      final offset = DateTime.now().timeZoneOffset;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final name in tz.timeZoneDatabase.locations.keys) {
        final loc = tz.getLocation(name);
        if (loc.timeZone(now).offset == offset) {
          return name;
        }
      }
    } catch (_) {}
    return 'UTC';
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
  }) =>
      _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(
          android: isAlarm ? _channel : _notifChannel,
          iOS: DarwinNotificationDetails(
              interruptionLevel: isAlarm
                  ? InterruptionLevel.timeSensitive
                  : InterruptionLevel.active),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$id|$snoozeMinutes|$reminderId|$title',
      );
}
