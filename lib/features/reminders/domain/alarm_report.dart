import '../../../core/database/database.dart';
import 'recurrence.dart';

const _reportWindow = Duration(days: 7);
const _tolerance = Duration(minutes: 2);

class MissedAlarm {
  const MissedAlarm(this.reminderId, this.title, this.at);
  final String reminderId, title;
  final DateTime at; // the fire instant with no ring recorded
}

class AlarmReport {
  const AlarmReport(this.log, this.countsByKind, this.missed, this.streakDays);
  final List<FiredEvent> log; // newest first
  final Map<String, int> countsByKind; // 'fired'/'dismissed'/'snoozed'
  final List<MissedAlarm> missed; // newest first
  final int streakDays;
}

/// Fire instants in the window with no fired_events row near them. Alarm-mode
/// only; caller passes this reminder's event instants (any kind — a snooze or
/// dismiss still proves it rang). Skipped occurrences are already excluded.
List<DateTime> missedOccurrences(
    Reminder r, List<DateTime> firedInstants, DateTime from, DateTime to) {
  final occs = pastOccurrences(r, from, to)
      .map((o) => o.subtract(Duration(minutes: r.offsetMinutes)))
      .toList();
  final out = <DateTime>[];
  for (var i = 0; i < occs.length; i++) {
    final f = occs[i];
    final end = i + 1 < occs.length ? occs[i + 1] : to;
    final covered = firedInstants.any(
        (e) => !e.isBefore(f.subtract(_tolerance)) && e.isBefore(end));
    if (!covered) out.add(f);
  }
  return out;
}

AlarmReport buildAlarmReport(
    List<Reminder> reminders, List<FiredEvent> events, DateTime now) {
  final from = now.subtract(_reportWindow);

  // counts per kind (over whatever the 90-day retention holds)
  final counts = <String, int>{};
  for (final e in events) {
    counts[e.kind] = (counts[e.kind] ?? 0) + 1;
  }

  // events grouped by reminder → their firedAt instants
  final byReminder = <String, List<DateTime>>{};
  for (final e in events) {
    (byReminder[e.reminderId] ??= []).add(e.firedAt);
  }

  final missed = <MissedAlarm>[];
  for (final r in reminders.where((r) => r.isAlarm && r.isEnabled)) {
    for (final at
        in missedOccurrences(r, byReminder[r.id] ?? const [], from, now)) {
      missed.add(MissedAlarm(r.id, r.title, at));
    }
  }
  missed.sort((a, b) => b.at.compareTo(a.at)); // newest first

  return AlarmReport(events, counts, missed, _streak(missed, from, now));
}

/// Consecutive days ending today with zero misses, within the window. A day
/// with a missed fire breaks the streak; the count caps at the window size.
int _streak(List<MissedAlarm> missed, DateTime from, DateTime now) {
  final missedDays = missed
      .map((m) => DateTime(m.at.year, m.at.month, m.at.day))
      .toSet();
  var streak = 0;
  for (var day = DateTime(now.year, now.month, now.day);
      !day.isBefore(DateTime(from.year, from.month, from.day));
      day = day.subtract(const Duration(days: 1))) {
    if (missedDays.contains(day)) break;
    streak++;
  }
  return streak;
}
// ponytail: streak counts clean days (no miss) rather than "had a scheduled
// alarm and it rang" — simpler and reads the same to a user. A day with no
// alarms is a clean day, not a break. Ceiling: capped at the 7-day window.
