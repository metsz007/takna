import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';

/// Records nothing useful — handleNotificationAction reconciles at the end,
/// and reconcile touches the plugin. init() is never called (isolate bootstrap
/// out of scope), so we just no-op the calls reconcile makes.
class _FakeNotifications extends NotificationService {
  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime when,
    required int snoozeMinutes,
    required String reminderId,
    bool isAlarm = true,
  }) async {}
}

Reminder _r(String id, DateTime start) => Reminder(
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
      snoozedUntil: null,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('insert + read back', () async {
    await db.logFired('a', 'Standup', 'fired');
    final row = await db.lastFired('a');
    expect(row, isNotNull);
    expect(row!.kind, 'fired');
    expect(row.title, 'Standup');
  });

  test('most-recent wins', () async {
    final base = DateTime.now().subtract(const Duration(minutes: 5));
    await db.logFired('a', 'Standup', 'fired', at: base);
    await db.logFired('a', 'Standup', 'snoozed',
        at: base.add(const Duration(minutes: 1)));
    await db.logFired('a', 'Standup', 'dismissed',
        at: base.add(const Duration(minutes: 2)));
    expect((await db.lastFired('a'))!.kind, 'dismissed');
  });

  test('per-reminder scoping', () async {
    await db.logFired('b', 'Other', 'fired');
    expect(await db.lastFired('a'), isNull);
    await db.logFired('a', 'Standup', 'fired');
    expect((await db.lastFired('a'))!.title, 'Standup');
  });

  test('90-day prune-on-insert', () async {
    final old = DateTime.now().subtract(const Duration(days: 91));
    await db.logFired('a', 'Old', 'fired', at: old);
    await db.logFired('a', 'New', 'fired');

    final rows = await db.select(db.firedEvents).get();
    expect(rows.where((e) => e.reminderId == 'a').length, 1);
    expect((await db.lastFired('a'))!.title, 'New');
  });

  group('action-path wiring', () {
    late _FakeNotifications fake;
    setUp(() async {
      fake = _FakeNotifications();
      await db.upsert(_r('a', DateTime.now().add(const Duration(days: 1))));
    });

    test('dismiss writes a dismissed row', () async {
      await handleNotificationAction('dismiss', '0|10|a|Standup', db, fake);
      final row = await db.lastFired('a');
      expect(row!.kind, 'dismissed');
      expect(row.title, 'Standup');
    });

    test('snooze writes a snoozed row', () async {
      await handleNotificationAction('snooze', '0|10|a|Standup', db, fake);
      expect((await db.lastFired('a'))!.kind, 'snoozed');
    });

    test('bogus / null actionId writes no row', () async {
      await handleNotificationAction('bogus', '0|10|a|Standup', db, fake);
      await handleNotificationAction(null, '0|10|a|Standup', db, fake);
      expect(await db.lastFired('a'), isNull);
    });
  });
}
