import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/features/reminders/domain/recurrence.dart';

Reminder _r({int nag = 0, int offset = 0}) {
  final t = DateTime(2026, 1, 1);
  return Reminder(
    id: 'x',
    title: 't',
    startDateTime: t,
    timeZone: 'UTC',
    offsetMinutes: offset,
    snoozeMinutes: 5,
    nagMinutes: nag,
    isEnabled: true,
    isAlarm: true,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  final occ = DateTime(2026, 7, 7, 9, 0);

  test('nag off is unchanged: exactly one fire at occ - offset', () {
    expect(occurrenceFireTimes(_r(nag: 0, offset: 5), occ, 8),
        [occ.subtract(const Duration(minutes: 5))]);
  });

  test('full pattern: before, at-time, then maxNags repeats, sorted', () {
    expect(occurrenceFireTimes(_r(nag: 5, offset: 15), occ, 3), [
      occ.subtract(const Duration(minutes: 15)),
      occ,
      occ.add(const Duration(minutes: 5)),
      occ.add(const Duration(minutes: 10)),
      occ.add(const Duration(minutes: 15)),
    ]);
  });

  test('offset 0 dedupes: occ appears once', () {
    final fires = occurrenceFireTimes(_r(nag: 5, offset: 0), occ, 2);
    expect(fires, [
      occ,
      occ.add(const Duration(minutes: 5)),
      occ.add(const Duration(minutes: 10)),
    ]);
  });
}
