import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';
import 'package:takna/features/reminders/data/reminder_repository.dart';
import 'package:takna/features/reminders/domain/recurrence.dart';

/// Records the fire times scheduled onto the OS queue (same shape as the
/// scheduler-test fakes).
class _FakeNotifications extends NotificationService {
  final scheduledWhen = <DateTime>[];

  @override
  Future<void> cancelAll() async => scheduledWhen.clear();

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
    scheduledWhen.add(when);
  }
}

Reminder _r({
  required String id,
  String? rrule,
  required DateTime start,
  String? skippedDates,
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
      snoozedUntil: null,
      skippedDates: skippedDates,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  final start = DateTime(2026, 7, 1, 9, 0);
  final after = DateTime(2026, 7, 4, 12, 0);

  group('nextOccurrences filter (pure)', () {
    test('skipped instant is omitted and the window still returns 3', () {
      final full = nextOccurrences(_r(id: 'x', rrule: 'FREQ=DAILY', start: start), after, 4);
      // Skip the 2nd upcoming occurrence.
      final skipped = full[1];
      final r = _r(
          id: 'x',
          rrule: 'FREQ=DAILY',
          start: start,
          skippedDates: encodeSkips({skipped.millisecondsSinceEpoch}));

      final occ = nextOccurrences(r, after, 3);
      expect(occ.length, 3, reason: 'filter must run before take(count)');
      expect(occ, isNot(contains(skipped)));
      // Every returned item is a real daily 9:00 occurrence.
      for (final d in occ) {
        expect(d.hour, 9);
        expect(d.minute, 0);
        expect(after.isBefore(d), isTrue);
      }
    });

    test('later occurrences are untouched (list shifts by one)', () {
      final full = nextOccurrences(_r(id: 'x', rrule: 'FREQ=DAILY', start: start), after, 4);
      final r = _r(
          id: 'x',
          rrule: 'FREQ=DAILY',
          start: start,
          skippedDates: encodeSkips({full.first.millisecondsSinceEpoch}));

      // Skipping the next occurrence yields exactly the unskipped tail.
      expect(nextOccurrences(r, after, 3), full.sublist(1));
    });
  });

  group('codec', () {
    test('round trip preserves the set', () {
      const a = 1000;
      const b = 2000;
      expect(decodeSkips(encodeSkips({a, b})), {a, b});
    });

    test('null decodes to empty', () {
      expect(decodeSkips(null), isEmpty);
    });
  });

  group('repository + reconcile', () {
    late AppDatabase db;
    late _FakeNotifications notifications;
    late ReminderRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      notifications = _FakeNotifications();
      repo = ReminderRepository(db, Scheduler(db, notifications));
    });
    tearDown(() => db.close());

    test('skipNext persists, and reconcile schedules the occurrence after', () async {
      // Past start so occurrences roll from now; deterministic 9:00 daily.
      final s = DateTime.now().subtract(const Duration(days: 10));
      await db.upsert(_r(id: 'd', rrule: 'FREQ=DAILY', start: DateTime(s.year, s.month, s.day, 9)));
      final r = (await db.getById('d'))!;
      final upcoming = nextOccurrences(r, DateTime.now(), 2);

      final skipped = await repo.skipNext('d');
      expect(skipped, upcoming.first);

      // Persisted in the column.
      final stored = (await db.getById('d'))!;
      expect(decodeSkips(stored.skippedDates), contains(upcoming.first.millisecondsSinceEpoch));

      // The reconcile skipNext triggered rebuilt the queue without the skip.
      expect(notifications.scheduledWhen, isNot(contains(upcoming.first)));
      expect(notifications.scheduledWhen, contains(upcoming[1]));
    });

    test('skipNext on a one-time reminder returns null and writes nothing', () async {
      await db.upsert(_r(id: 'o', start: DateTime.now().add(const Duration(days: 1))));
      expect(await repo.skipNext('o'), isNull);
      expect((await db.getById('o'))!.skippedDates, isNull);
    });

    test('unskip restores the occurrence to the queue', () async {
      final s = DateTime.now().subtract(const Duration(days: 10));
      await db.upsert(_r(id: 'd', rrule: 'FREQ=DAILY', start: DateTime(s.year, s.month, s.day, 9)));
      final upcoming = nextOccurrences((await db.getById('d'))!, DateTime.now(), 1).first;

      final skipped = await repo.skipNext('d');
      expect(notifications.scheduledWhen, isNot(contains(upcoming)));

      await repo.unskip('d', skipped!);
      expect(decodeSkips((await db.getById('d'))!.skippedDates), isEmpty);
      expect(notifications.scheduledWhen, contains(upcoming));
    });
  });

  test('old backups (no skippedDates key) decode with a null column', () {
    // Plan 03 round-trips reminders through JSON; a pre-07 backup lacks the key.
    final row = _r(id: 'a', rrule: 'FREQ=DAILY', start: start).toJson()
      ..remove('skippedDates');
    expect(Reminder.fromJson(row).skippedDates, isNull);
  });
}
