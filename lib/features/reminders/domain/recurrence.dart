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
List<DateTime> nextOccurrences(Reminder r, DateTime after, int count) =>
    _rawOccurrences(r, after)
        .where((d) =>
            !decodeSkips(r.skippedDates).contains(d.millisecondsSinceEpoch))
        .take(count)
        .toList();

/// Like [nextOccurrences] but keeps skipped instants in the list, flagged —
/// for UIs that show a skip in place (faded + undo) instead of hiding it.
List<({DateTime at, bool skipped})> upcomingWithSkips(
    Reminder r, DateTime after, int count) {
  final skips = decodeSkips(r.skippedDates);
  return _rawOccurrences(r, after)
      .take(count)
      .map((d) => (at: d, skipped: skips.contains(d.millisecondsSinceEpoch)))
      .toList();
}

/// Occurrence wall-times in [from, to), skip-filtered. Reuses the same lazy
/// RRULE expansion as nextOccurrences; the window is expected small.
List<DateTime> pastOccurrences(Reminder r, DateTime from, DateTime to) {
  final skips = decodeSkips(r.skippedDates);
  return _rawOccurrences(r, from)
      .takeWhile((d) => d.isBefore(to))
      .where((d) => !skips.contains(d.millisecondsSinceEpoch))
      .toList();
}

Iterable<DateTime> _rawOccurrences(Reminder r, DateTime after) {
  if (r.rruleString == null) {
    return r.startDateTime.isAfter(after) ? [r.startDateTime] : [];
  }
  final rule = RecurrenceRule.fromString(
      r.rruleString!.startsWith('RRULE:') ? r.rruleString! : 'RRULE:${r.rruleString!}');
  final s = r.startDateTime;
  final startUtc = DateTime.utc(s.year, s.month, s.day, s.hour, s.minute);
  final a = after;
  final afterUtc = DateTime.utc(a.year, a.month, a.day, a.hour, a.minute, a.second);
  // rrule asserts after >= start; a future-start series means every instance
  // (including start itself) is already after [after], so iterate from start.
  final instances = afterUtc.isBefore(startUtc)
      ? rule.getInstances(start: startUtc)
      : rule.getInstances(start: startUtc, after: afterUtc);
  return instances.map((d) => DateTime(d.year, d.month, d.day, d.hour, d.minute));
}

/// All notification fire times for one occurrence anchored at [occ]: the
/// "before" lead, and — when nagging is on — the at-time ping plus up to
/// [maxNags] repeats every nagMinutes. Sorted, de-duplicated. Nag off
/// (nagMinutes == 0) yields exactly [occ - offsetMinutes] — today's single
/// fire. Pure: no DB, no clock.
List<DateTime> occurrenceFireTimes(Reminder r, DateTime occ, int maxNags) {
  final before = occ.subtract(Duration(minutes: r.offsetMinutes));
  if (r.nagMinutes <= 0) return [before];
  final times = <DateTime>{before, occ};
  for (var i = 1; i <= maxNags; i++) {
    times.add(occ.add(Duration(minutes: r.nagMinutes * i)));
  }
  return times.toList()..sort();
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
