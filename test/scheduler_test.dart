import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';

/// Records schedule/cancelAll calls instead of touching the plugin.
class _FakeNotifications extends NotificationService {
  final scheduled = <String>[]; // reminderIds scheduled
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
  }) async {
    scheduled.add(reminderId);
  }
}

Reminder _r({
  required String id,
  String? rrule,
  required DateTime start,
  DateTime? snoozedUntil,
}) =>
    Reminder(
      id: id,
      title: 't',
      notes: null,
      startDateTime: start,
      timeZone: 'UTC',
      rruleString: rrule,
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
  late Scheduler scheduler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _FakeNotifications();
    scheduler = Scheduler(db, notifications);
  });

  tearDown(() => db.close());

  final now = DateTime.now();
  final past = now.subtract(const Duration(days: 1));
  final future = now.add(const Duration(days: 1));

  test('past one-time with no pending snooze → disabled, nothing scheduled',
      () async {
    await db.upsert(_r(id: 'a', start: past));
    await scheduler.reconcile();

    expect((await db.getById('a'))!.isEnabled, isFalse);
    expect(notifications.scheduled, isNot(contains('a')));
  });

  test('past one-time with pending future snooze → stays enabled, snooze scheduled',
      () async {
    await db.upsert(_r(id: 'b', start: past, snoozedUntil: future));
    await scheduler.reconcile();

    expect((await db.getById('b'))!.isEnabled, isTrue);
    expect(notifications.scheduled, contains('b'));
  });

  test('future one-time → stays enabled, scheduled once', () async {
    await db.upsert(_r(id: 'c', start: future));
    await scheduler.reconcile();

    expect((await db.getById('c'))!.isEnabled, isTrue);
    expect(notifications.scheduled.where((id) => id == 'c').length, 1);
  });

  test('past-start recurring → stays enabled, occurrences scheduled', () async {
    await db.upsert(_r(id: 'd', rrule: 'FREQ=DAILY', start: past));
    await scheduler.reconcile();

    expect((await db.getById('d'))!.isEnabled, isTrue);
    expect(notifications.scheduled, contains('d'));
  });
}
