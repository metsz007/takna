import 'dart:convert';

import 'package:rrule/rrule.dart';

import '../../../core/database/database.dart';

/// User-chosen occurrence instants to exclude (epoch millis of the wall-time
/// value nextOccurrences emits). Not derived data — explicit user input, like
/// snoozedUntil.
Set<int> decodeSkips(String? raw) =>
    raw == null ? {} : {for (final v in jsonDecode(raw) as List) v as int};

String encodeSkips(Set<int> skips) => jsonEncode(skips.toList());

/// Expands a reminder into its next [count] occurrence times (local wall
/// time), starting strictly after [after]. One-time reminders yield their
/// startDateTime if it's still in the future.
///
/// The rrule package computes in UTC, so we feed it wall-clock components
/// stamped as UTC and strip the flag on the way out. DST-safe for wall-time
/// semantics ("every day at 9:00").
List<DateTime> nextOccurrences(Reminder r, DateTime after, int count) {
  if (r.rruleString == null) {
    return r.startDateTime.isAfter(after) ? [r.startDateTime] : [];
  }
  final rule = RecurrenceRule.fromString(
      r.rruleString!.startsWith('RRULE:') ? r.rruleString! : 'RRULE:${r.rruleString!}');
  final s = r.startDateTime;
  final startUtc = DateTime.utc(s.year, s.month, s.day, s.hour, s.minute);
  final a = after;
  final afterUtc = DateTime.utc(a.year, a.month, a.day, a.hour, a.minute, a.second);
  final skips = decodeSkips(r.skippedDates);
  // rrule asserts after >= start; a future-start series means every instance
  // (including start itself) is already after [after], so iterate from start.
  final instances = afterUtc.isBefore(startUtc)
      ? rule.getInstances(start: startUtc)
      : rule.getInstances(start: startUtc, after: afterUtc);
  return instances
      .map((d) => DateTime(d.year, d.month, d.day, d.hour, d.minute))
      .where((d) => !skips.contains(d.millisecondsSinceEpoch))
      .take(count)
      .toList();
}

/// The next time this reminder will actually fire, and whether that's a
/// pending snooze rather than a regular occurrence. A snooze
/// (`snoozedUntil` after [now]) wins if there's no occurrence or it lands
/// before the next one. Returns null when nothing is upcoming.
({DateTime at, bool snoozed})? effectiveNextFire(Reminder r, DateTime now) {
  final occ = nextOccurrences(r, now, 1);
  final snooze = r.snoozedUntil;
  ({DateTime at, bool snoozed})? next;
  if (occ.isNotEmpty) next = (at: occ.first, snoozed: false);
  if (snooze != null &&
      snooze.isAfter(now) &&
      (next == null || snooze.isBefore(next.at))) {
    next = (at: snooze, snoozed: true);
  }
  return next;
}

/// Friendly label for the repeat badge ("Daily", "Weekly", ...).
String recurrenceLabel(String? rruleString) {
  if (rruleString == null) return 'Once';
  final s = rruleString.toUpperCase();
  final hasInterval = RegExp(r'INTERVAL=([2-9]|\d\d+)').hasMatch(s);
  if (s.contains('FREQ=DAILY')) return hasInterval ? 'Custom' : 'Daily';
  if (s.contains('FREQ=WEEKLY')) {
    if (hasInterval) return 'Custom';
    final byday = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(s)?.group(1);
    if (byday == 'MO,TU,WE,TH,FR') return 'Weekdays';
    if (byday != null && byday.split(',').length > 1) return 'Custom';
    return 'Weekly';
  }
  if (s.contains('FREQ=MONTHLY')) return hasInterval ? 'Custom' : 'Monthly';
  if (s.contains('FREQ=YEARLY')) return hasInterval ? 'Custom' : 'Yearly';
  return 'Custom';
}
