import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';

/// Records schedule/cancelAll calls instead of touching the plugin.
class _FakeNotifications extends NotificationService {
  final scheduled = <String>[]; // reminderIds scheduled
  final whens = <DateTime>[]; // fire time of each scheduled occurrence
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
    whens.add(when);
  }
}

/// Records the order of cancelAll/schedule calls; schedule await-delays so a
/// second reconcile has a window to interleave if serialization is missing.
class _OrderFakeNotifications extends NotificationService {
  final List<String> events = [];

  @override
  Future<void> cancelAll() async => events.add('cancel');

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
    // A real async gap per schedule: without serialization it lets a second
    // reconcile's getEnabled()/cancelAll slip in between these calls.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    events.add('schedule');
  }
}

Reminder _r({
  required String id,
  String? rrule,
  required DateTime start,
  DateTime? snoozedUntil,
  int offset = 0,
}) =>
    Reminder(
      id: id,
      title: 't',
      notes: null,
      startDateTime: start,
      timeZone: 'UTC',
      rruleString: rrule,
      offsetMinutes: offset,
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

  test('offset pushes fire time into the past → disabled', () async {
    // start 10min out, but a 30min lead-time means it should have fired 20min ago.
    await db.upsert(_r(
        id: 'e', start: now.add(const Duration(minutes: 10)), offset: 30));
    await scheduler.reconcile();

    expect((await db.getById('e'))!.isEnabled, isFalse);
  });

  test('no offset, future start → stays enabled', () async {
    await db.upsert(_r(
        id: 'f', start: now.add(const Duration(minutes: 10)), offset: 0));
    await scheduler.reconcile();

    expect((await db.getById('f'))!.isEnabled, isTrue);
  });

  test('pause: nothing scheduled before pausedUntil, occurrences after it are',
      () async {
    final pausedUntil = now.add(const Duration(days: 3));
    await db.upsert(_r(id: 'p', rrule: 'FREQ=DAILY', start: past));
    await db.setPausedUntil(pausedUntil);
    await scheduler.reconcile();

    // The reminder is still scheduled — just its post-pause occurrences.
    expect(notifications.scheduled, contains('p'));
    expect(notifications.whens, isNotEmpty);
    // Every queued fire is at or after the pause end — nothing inside the window.
    for (final w in notifications.whens) {
      expect(w.isBefore(pausedUntil), isFalse);
    }
  });

  test('pause: one-time inside the window is suppressed, one after is not',
      () async {
    await db.upsert(_r(id: 'before', start: now.add(const Duration(hours: 1))));
    await db.upsert(_r(id: 'after', start: now.add(const Duration(days: 2))));
    await db.setPausedUntil(now.add(const Duration(days: 1)));
    await scheduler.reconcile();

    expect(notifications.scheduled, contains('after'));
    expect(notifications.scheduled, isNot(contains('before')));
  });

  test('pause: a stale past pausedUntil is inert (normal scheduling)', () async {
    await db.upsert(_r(id: 's', start: future));
    await db.setPausedUntil(now.subtract(const Duration(days: 1)));
    await scheduler.reconcile();

    expect(notifications.scheduled, contains('s'));
  });

  test('pause: resume (clearing) restores normal scheduling', () async {
    await db.upsert(_r(id: 'r', start: now.add(const Duration(hours: 1))));
    await db.setPausedUntil(now.add(const Duration(days: 1)));
    await scheduler.reconcile();
    expect(notifications.scheduled, isNot(contains('r'))); // suppressed while paused

    await db.setPausedUntil(null); // Resume
    await scheduler.reconcile();
    expect(notifications.scheduled, contains('r'));
  });

  test('concurrent reconcile() calls are serialized (no interleave)', () async {
    final ordered = _OrderFakeNotifications();
    final s = Scheduler(db, ordered);
    // Several reminders so each run has multiple schedule() calls with async
    // gaps between them — a window for a second run's cancelAll to slip in.
    await db.upsert(_r(id: 'g1', start: future));
    await db.upsert(_r(id: 'g2', start: future));
    await db.upsert(_r(id: 'g3', start: future));

    // Fire the second before awaiting the first: with per-instance chaining the
    // second's cancelAll must wait for all of the first run's schedules.
    final first = s.reconcile();
    final second = s.reconcile();
    await Future.wait([first, second]);

    // Each run: one cancelAll then its three schedules, fully before the next.
    expect(ordered.events, [
      'cancel', 'schedule', 'schedule', 'schedule', //
      'cancel', 'schedule', 'schedule', 'schedule',
    ]);
  });
}
