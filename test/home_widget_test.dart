import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/widget/next_reminder_snapshot.dart';

/// Minimal Reminder builder (mirrors scheduler_test's helper).
Reminder _r({
  required String id,
  String title = 't',
  String? rrule,
  required DateTime start,
  DateTime? snoozedUntil,
  bool enabled = true,
}) =>
    Reminder(
      id: id,
      title: title,
      notes: null,
      startDateTime: start,
      timeZone: 'UTC',
      rruleString: rrule,
      offsetMinutes: 0,
      snoozeMinutes: 10,
      isEnabled: enabled,
      isAlarm: true,
      snoozedUntil: snoozedUntil,
      soundKey: null,
      createdAt: start,
      updatedAt: start,
    );

void main() {
  // Anchor on a fixed midday so "today" math and h:mm formatting are stable.
  final now = DateTime(2026, 7, 7, 12, 0);

  test('picks the earliest enabled reminder', () {
    final soon = now.add(const Duration(hours: 1)); // 1:00 PM today
    final snap = nextReminderSnapshot([
      _r(id: 'later', title: 'Later', start: now.add(const Duration(days: 2))),
      _r(id: 'soon', title: 'Soon', start: soon),
      _r(id: 'mid', title: 'Mid', start: now.add(const Duration(hours: 5))),
    ], now);

    expect(snap, isNotNull);
    expect(snap!.title, 'Soon');
    expect(snap.when, contains(DateFormat('h:mm a').format(soon)));
  });

  test('ignores disabled and past reminders even if earlier', () {
    final snap = nextReminderSnapshot([
      _r(
          id: 'disabled',
          title: 'Disabled',
          start: now.add(const Duration(minutes: 5)),
          enabled: false),
      _r(id: 'past', title: 'Past', start: now.subtract(const Duration(hours: 1))),
      _r(id: 'real', title: 'Real', start: now.add(const Duration(hours: 2))),
    ], now);

    expect(snap!.title, 'Real');
  });

  test('a sooner snooze wins over another reminder occurrence', () {
    final snoozeAt = now.add(const Duration(minutes: 20));
    final snap = nextReminderSnapshot([
      // Fired-and-snoozed: its start is past, but snoozedUntil is upcoming.
      _r(
          id: 'snoozed',
          title: 'Snoozed',
          start: now.subtract(const Duration(hours: 1)),
          snoozedUntil: snoozeAt),
      _r(id: 'other', title: 'Other', start: now.add(const Duration(hours: 3))),
    ], now);

    expect(snap!.title, 'Snoozed');
    expect(snap.when, contains(DateFormat('h:mm a').format(snoozeAt)));
  });

  test('same-day when is a bare time; a future day carries a day-label prefix', () {
    final todaySnap = nextReminderSnapshot(
        [_r(id: 't', start: now.add(const Duration(hours: 2)))], now);
    expect(todaySnap!.when, DateFormat('h:mm a').format(now.add(const Duration(hours: 2))));
    expect(todaySnap.when, isNot(contains('·')));

    final threeDaysOut = now.add(const Duration(days: 3));
    final futureSnap =
        nextReminderSnapshot([_r(id: 'f', start: threeDaysOut)], now);
    expect(futureSnap!.when, contains('·'));
    expect(futureSnap.when, contains(DateFormat('h:mm a').format(threeDaysOut)));
  });

  test('empty and all-disabled lists return null', () {
    expect(nextReminderSnapshot([], now), isNull);
    expect(
      nextReminderSnapshot([
        _r(id: 'a', start: now.add(const Duration(hours: 1)), enabled: false),
        _r(id: 'b', start: now.add(const Duration(hours: 2)), enabled: false),
      ], now),
      isNull,
    );
  });
}
