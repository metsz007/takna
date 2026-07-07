import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/features/reminders/domain/alarm_report.dart';
import 'package:takna/features/reminders/domain/recurrence.dart';

Reminder _r({
  String id = 'a',
  String? rrule = 'FREQ=DAILY',
  required DateTime start,
  int offsetMinutes = 0,
  bool isAlarm = true,
  bool isEnabled = true,
  String? skippedDates,
}) =>
    Reminder(
      id: id,
      title: 'Alarm',
      notes: null,
      startDateTime: start,
      timeZone: 'UTC',
      rruleString: rrule,
      offsetMinutes: offsetMinutes,
      snoozeMinutes: 10,
      nagMinutes: 0,
      isEnabled: isEnabled,
      isAlarm: isAlarm,
      snoozedUntil: null,
      skippedDates: skippedDates,
      createdAt: start,
      updatedAt: start,
    );

FiredEvent _e(String reminderId, String kind, DateTime at) =>
    FiredEvent(id: 0, reminderId: reminderId, title: 'Alarm', kind: kind, firedAt: at);

void main() {
  // Fixed clock so the 7-day window is deterministic.
  final now = DateTime(2026, 7, 7, 12, 0);
  final from = now.subtract(const Duration(days: 7)); // 2026-06-30 12:00
  final start = DateTime(2026, 6, 25, 9, 0); // daily 09:00, before the window

  group('pastOccurrences', () {
    test('one per day inside window, none >= to', () {
      final occ = pastOccurrences(_r(start: start), from, now);
      // 09:00 on Jul 1..7 — Jun 30 09:00 is before `from` (12:00), Jul 7 09:00
      // is before `to` (12:00).
      expect(occ, [
        DateTime(2026, 7, 1, 9),
        DateTime(2026, 7, 2, 9),
        DateTime(2026, 7, 3, 9),
        DateTime(2026, 7, 4, 9),
        DateTime(2026, 7, 5, 9),
        DateTime(2026, 7, 6, 9),
        DateTime(2026, 7, 7, 9),
      ]);
      expect(occ.every((d) => d.isBefore(now)), isTrue);
    });

    test('skipped instant is absent', () {
      final skip = DateTime(2026, 7, 3, 9).millisecondsSinceEpoch;
      final occ = pastOccurrences(
          _r(start: start, skippedDates: encodeSkips({skip})), from, now);
      expect(occ.length, 6);
      expect(occ.contains(DateTime(2026, 7, 3, 9)), isFalse);
    });
  });

  group('missedOccurrences', () {
    test('a day with no event is missed, days with one are not', () {
      final r = _r(start: start);
      // Fired every day except Jul 4.
      final fired = [
        for (final d in [1, 2, 3, 5, 6, 7]) DateTime(2026, 7, d, 9),
      ];
      final missed = missedOccurrences(r, fired, from, now);
      expect(missed, [DateTime(2026, 7, 4, 9)]);
    });

    test('an event within 2 min of the fire instant covers it', () {
      final r = _r(start: start);
      final fired = [
        for (final d in [1, 2, 3, 4, 5, 6, 7])
          DateTime(2026, 7, d, 9, 1), // one minute late
      ];
      expect(missedOccurrences(r, fired, from, now), isEmpty);
    });

    test('offset shifts the fire instant', () {
      final r = _r(start: start, offsetMinutes: 10); // fires at 08:50
      final fired = [
        for (final d in [1, 2, 3, 4, 5, 6, 7]) DateTime(2026, 7, d, 8, 50),
      ];
      expect(missedOccurrences(r, fired, from, now), isEmpty);
    });
  });

  group('buildAlarmReport', () {
    List<FiredEvent> fullWeek(String kind) =>
        [for (final d in [1, 2, 3, 4, 5, 6, 7]) _e('a', kind, DateTime(2026, 7, d, 9))];

    test('snoozed / dismissed events cover an occurrence', () {
      final events = [
        for (final d in [1, 2, 3, 5, 6, 7]) _e('a', 'fired', DateTime(2026, 7, d, 9)),
        _e('a', 'snoozed', DateTime(2026, 7, 4, 9)), // only a snooze on Jul 4
      ];
      final report = buildAlarmReport([_r(start: start)], events, now);
      expect(report.missed, isEmpty);
    });

    test('notification-mode reminders never produce misses', () {
      final report =
          buildAlarmReport([_r(start: start, isAlarm: false)], const [], now);
      expect(report.missed, isEmpty);
    });

    test('disabled reminders never produce misses', () {
      final report =
          buildAlarmReport([_r(start: start, isEnabled: false)], const [], now);
      expect(report.missed, isEmpty);
    });

    test('countsByKind tallies each kind', () {
      final events = [
        _e('a', 'fired', DateTime(2026, 7, 1, 9)),
        _e('a', 'fired', DateTime(2026, 7, 2, 9)),
        _e('a', 'snoozed', DateTime(2026, 7, 3, 9)),
        _e('a', 'dismissed', DateTime(2026, 7, 4, 9)),
      ];
      // Use a future-start reminder so no misses distract the count.
      final report = buildAlarmReport(
          [_r(start: DateTime(2026, 8, 1, 9))], events, now);
      expect(report.countsByKind, {'fired': 2, 'snoozed': 1, 'dismissed': 1});
    });

    test('clean week counts a streak; a mid-window miss stops it', () {
      final clean = buildAlarmReport([_r(start: start)], fullWeek('fired'), now);
      // Loop spans from-day..now-day inclusive (8 calendar days), all clean.
      expect(clean.streakDays, 8);

      // Drop Jul 4's event → a miss on Jul 4 breaks the streak there.
      final gapped = buildAlarmReport(
          [_r(start: start)],
          [for (final d in [1, 2, 3, 5, 6, 7]) _e('a', 'fired', DateTime(2026, 7, d, 9))],
          now);
      expect(gapped.missed.map((m) => m.at), [DateTime(2026, 7, 4, 9)]);
      // Jul 7, 6, 5 clean, Jul 4 missed → streak 3.
      expect(gapped.streakDays, 3);
    });
  });
}
