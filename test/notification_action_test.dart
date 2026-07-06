import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';

/// Records schedule/cancelAll instead of touching the plugin. init() is never
/// called — the isolate bootstrap is out of scope here.
class _FakeNotifications extends NotificationService {
  final scheduled = <({String reminderId, DateTime when})>[];
  int cancelAllCount = 0;

  @override
  Future<void> cancelAll() async => cancelAllCount++;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime when,
    required int snoozeMinutes,
    required String reminderId,
    bool isAlarm = true,
    String? soundKey,
  }) async {
    scheduled.add((reminderId: reminderId, when: when));
  }
}

Reminder _r({
  required String id,
  required DateTime start,
  DateTime? snoozedUntil,
}) =>
    Reminder(
      id: id,
      title: 'Title',
      notes: null,
      startDateTime: start,
      timeZone: 'UTC',
      rruleString: null,
      offsetMinutes: 0,
      snoozeMinutes: 10,
      isEnabled: true,
      isAlarm: true,
      snoozedUntil: snoozedUntil,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  late AppDatabase db;
  late _FakeNotifications notifications;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _FakeNotifications();
  });

  tearDown(() => db.close());

  test('dismiss on a fired one-time reminder → disabled, nothing scheduled',
      () async {
    final past = DateTime.now().subtract(const Duration(hours: 1));
    await db.upsert(_r(id: 'a', start: past));

    await handleNotificationAction('dismiss', '0|10|a|Title', db, notifications);

    expect((await db.getById('a'))!.isEnabled, isFalse);
    expect(notifications.scheduled.any((s) => s.reminderId == 'a'), isFalse);
  });

  test('snooze persists snoozedUntil and schedules at that time', () async {
    final future = DateTime.now().add(const Duration(days: 1));
    await db.upsert(_r(id: 'b', start: future));

    final before = DateTime.now();
    await handleNotificationAction('snooze', '0|15|b|Title', db, notifications);
    final after = DateTime.now();

    // Drift floors DateTime to whole seconds, so allow a second of slack.
    final snoozed = (await db.getById('b'))!.snoozedUntil!;
    final target = before.add(const Duration(minutes: 15));
    expect((snoozed.difference(target)).inSeconds.abs(), lessThanOrEqualTo(2));
    expect(snoozed.isAfter(after.add(const Duration(minutes: 15))), isFalse);

    final s = notifications.scheduled.firstWhere((s) => s.reminderId == 'b');
    expect((s.when.difference(snoozed)).inSeconds.abs(), lessThan(1));
  });

  test('null/unknown actionId → no DB change, nothing scheduled', () async {
    final future = DateTime.now().add(const Duration(days: 1));
    await db.upsert(_r(id: 'c', start: future));

    await handleNotificationAction(null, '0|10|c|Title', db, notifications);
    await handleNotificationAction('bogus', '0|10|c|Title', db, notifications);

    final row = (await db.getById('c'))!;
    expect(row.isEnabled, isTrue);
    expect(row.snoozedUntil, isNull);
    expect(notifications.scheduled, isEmpty);
    expect(notifications.cancelAllCount, 0);
  });

  group('dispatchNotificationResponse', () {
    late List<({String location, Object? extra})> nav;
    void go(String location, {Object? extra}) =>
        nav.add((location: location, extra: extra));

    setUp(() => nav = []);

    test('null actionId (body tap) → routes, no DB action', () async {
      await db.upsert(_r(id: 'a', start: DateTime.now().add(const Duration(days: 1))));

      await dispatchNotificationResponse(null, '0|10|a|Title', db, notifications, go);

      expect(nav, [(location: '/alarm', extra: '0|10|a|Title')]);
      expect(notifications.scheduled, isEmpty);
    });

    test('snooze action persists snoozedUntil and schedules', () async {
      await db.upsert(_r(id: 'b', start: DateTime.now().add(const Duration(days: 1))));

      await dispatchNotificationResponse('snooze', '0|15|b|Title', db, notifications, go);

      expect((await db.getById('b'))!.snoozedUntil, isNotNull);
      expect(notifications.scheduled.any((s) => s.reminderId == 'b'), isTrue);
      expect(nav, isEmpty);
    });

    test('dismiss action reconciles (fired one-time gets disabled)', () async {
      await db.upsert(_r(id: 'c', start: DateTime.now().subtract(const Duration(hours: 1))));

      await dispatchNotificationResponse('dismiss', '0|10|c|Title', db, notifications, go);

      expect((await db.getById('c'))!.isEnabled, isFalse);
      expect(nav, isEmpty);
    });
  });
}
