import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/features/reminders/domain/recurrence.dart';

Reminder _r({
  String? rrule,
  required DateTime start,
  DateTime? snoozedUntil,
}) =>
    Reminder(
      id: 'x',
      title: 't',
      notes: null,
      startDateTime: start,
      timeZone: 'UTC',
      rruleString: rrule,
      offsetMinutes: 0,
      snoozeMinutes: 10,
      nagMinutes: 0,
      snoozedUntil: snoozedUntil,
      isEnabled: true,
      isAlarm: true,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  final start = DateTime(2026, 7, 1, 9, 0);
  final after = DateTime(2026, 7, 4, 12, 0);

  test('one-time future fires once, past fires never', () {
    expect(nextOccurrences(_r(start: DateTime(2026, 7, 10, 9)), after, 5).length, 1);
    expect(nextOccurrences(_r(start: start), after, 5), isEmpty);
  });

  test('daily expands to next N at 9:00', () {
    final occ = nextOccurrences(_r(rrule: 'FREQ=DAILY', start: start), after, 3);
    expect(occ, [
      DateTime(2026, 7, 5, 9),
      DateTime(2026, 7, 6, 9),
      DateTime(2026, 7, 7, 9),
    ]);
  });

  test('recurring with a future start does not crash and starts at start', () {
    // Regression: rrule's getInstances asserts after >= start; a series
    // starting after "now" used to throw on every render.
    final future = DateTime(2026, 7, 10, 9);
    final occ = nextOccurrences(_r(rrule: 'FREQ=DAILY', start: future), after, 3);
    expect(occ, [
      DateTime(2026, 7, 10, 9),
      DateTime(2026, 7, 11, 9),
      DateTime(2026, 7, 12, 9),
    ]);
  });

  test('weekly MO,WE,FR', () {
    final occ = nextOccurrences(
        _r(rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR', start: start), after, 3);
    // Jul 4 2026 is a Saturday → next are Mon 6, Wed 8, Fri 10.
    expect(occ, [
      DateTime(2026, 7, 6, 9),
      DateTime(2026, 7, 8, 9),
      DateTime(2026, 7, 10, 9),
    ]);
  });

  group('effectiveNextFire', () {
    test('snooze earlier than next occurrence wins', () {
      final snooze = DateTime(2026, 7, 4, 12, 30);
      final r = _r(rrule: 'FREQ=DAILY', start: start, snoozedUntil: snooze);
      // Next occurrence is Jul 5 09:00; snooze is sooner.
      expect(effectiveNextFire(r, after), (at: snooze, snoozed: true));
    });

    test('snooze later than next occurrence loses', () {
      final snooze = DateTime(2026, 7, 6, 12, 0);
      final r = _r(rrule: 'FREQ=DAILY', start: start, snoozedUntil: snooze);
      expect(
          effectiveNextFire(r, after), (at: DateTime(2026, 7, 5, 9), snoozed: false));
    });

    test('past snooze is ignored', () {
      final r = _r(
          rrule: 'FREQ=DAILY',
          start: start,
          snoozedUntil: DateTime(2026, 7, 4, 11, 0));
      expect(
          effectiveNextFire(r, after), (at: DateTime(2026, 7, 5, 9), snoozed: false));
    });

    test('no occurrence but pending snooze → snooze', () {
      final snooze = DateTime(2026, 7, 5, 8, 0);
      final r = _r(start: start, snoozedUntil: snooze); // one-time, already past
      expect(effectiveNextFire(r, after), (at: snooze, snoozed: true));
    });

    test('neither occurrence nor snooze → null', () {
      final r = _r(start: start); // one-time, already past
      expect(effectiveNextFire(r, after), isNull);
    });
  });

  test('labels', () {
    expect(recurrenceLabel(null), 'Once');
    expect(recurrenceLabel('FREQ=DAILY'), 'Daily');
    expect(recurrenceLabel('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'), 'Weekdays');
    expect(recurrenceLabel('FREQ=DAILY;INTERVAL=3'), 'Custom');
  });
}
