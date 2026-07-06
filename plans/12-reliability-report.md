---
status: done
verified-by:
  - test/alarm_report_test.dart
---

# Plan 12 — Reliability report + history screen

**Outcome:** One new screen (reachable from Settings) that answers "have my
alarms actually been ringing?" It shows a chronological log of every recorded
alarm event, a small summary (counts per kind + a current no-miss streak), and
a **missed-alarm** section: enabled alarm-mode reminders whose past occurrences
have no fired event recorded — worded softly as "no ring recorded." Everything
is computed at read time from the existing `fired_events` rows plus live RRULE
expansion; nothing new is stored.

## Prereq

None. **No schema change** — this rides entirely on the `fired_events` table,
`logFired`, and the 90-day prune that plan 04 already shipped
(`lib/core/database/database.dart`). schemaVersion stays **6**; no migration,
no `build_runner` regen (unless a trivial new query method triggers one — the
two read methods below are hand-written selects, so `.g.dart` is unaffected).
No new runtime dependency — `drift`, `intl`, `go_router`, `rrule` are all here.

## Design decisions

- **Missed detection is COMPUTED, never stored** (CLAUDE.md rule). Past
  occurrences are re-expanded from `startDateTime` + RRULE over a small window
  and compared against `fired_events`. A "missed" row is a derived read-time
  fact — it must never become a column.
- **Alarm-mode only, soft wording.** (Correctness constraint from the idea
  challenge.) Notification-mode reminders never open `AlarmScreen` and log
  *nothing* when swiped away — a gap there is meaningless, not a miss. So
  missed detection is scoped to `isAlarm == true`, and the copy says "no ring
  recorded," never "you missed this." Notification-mode reminders are simply
  absent from the missed list.
- **Enabled reminders only, small window.** The window is the **last 7 days**
  (`_reportWindow`). Kept small because each reminder re-expands its RRULE over
  the window on every screen open. Only currently-`isEnabled` reminders are
  scanned: a disabled recurring reminder has occurrences we never scheduled, so
  flagging them would be a false positive. // ponytail: 7-day window and
  enabled-only are the cheap, false-positive-free cut. Ceiling: streak caps at
  7 days and one-time alarms that auto-disable on fire aren't scanned (see Out
  of scope). Widen `_reportWindow` only if someone wants a longer streak.
- **"Covered" = any event near the fire instant, any kind.** An occurrence's
  fire instant is `occurrence - offsetMinutes` (same math the scheduler uses,
  `scheduler.dart:67`). It counts as rung if *any* `fired_events` row for that
  reminder falls in `[fireInstant - 2min, nextFireInstant)`. Using any kind
  (`fired`/`snoozed`/`dismissed`) means a **snoozed** or dismissed occurrence is
  covered, not missed — satisfying "snoozed occurrences must not count as
  missed." **Skipped** occurrences are dropped before the check (they were never
  scheduled) because `pastOccurrences` reuses `decodeSkips`, the same filter
  `nextOccurrences` uses.
- **All aggregation is pure + testable.** The DB layer only fetches rows; a
  pure `buildAlarmReport(reminders, events, now)` in the domain produces the
  log, per-kind counts, missed list, and streak. The screen is a thin
  `ConsumerWidget` over one `FutureProvider`.
- **Laziest UI: one screen, house widgets.** Reached by one Settings row (the
  trust question is global, not per-reminder — the per-reminder "Last fired"
  line from plan 04 stays). TkHero for the streak, TkSectionLabel + TkCard for
  the three sections. No home-screen entry, no filtering, no per-day charts.

## Context (files this touches)

- `lib/core/database/database.dart` — add one read method `allEvents()` next to
  `lastFired` (~113): `select(firedEvents)` ordered `firedAt` desc. The 90-day
  prune already caps the row count, so "all" is small — no pagination.
- `lib/features/reminders/domain/recurrence.dart` — add pure `pastOccurrences(r,
  from, to)` (mirrors `_rawOccurrences` but bounded with `takeWhile` and
  skip-filtered). This is occurrence expansion, so it belongs here beside
  `nextOccurrences`/`upcomingWithSkips`.
- `lib/features/reminders/domain/alarm_report.dart` — **new**, pure aggregation:
  `MissedAlarm`, `AlarmReport`, `missedOccurrences(...)`, and
  `buildAlarmReport(...)`. Kept out of `recurrence.dart` so the report record
  types don't clutter the expansion helpers.
- `lib/features/reminders/presentation/providers.dart` — add
  `alarmReportProvider` (FutureProvider.autoDispose) next to `lastFiredProvider`
  (~32).
- `lib/features/reminders/presentation/screens/history_screen.dart` — **new**
  screen (`HistoryScreen`), sibling of `reminder_detail_screen.dart`.
- `lib/core/router/router.dart` — register `GoRoute(path: '/history', ...
  slide: true)` (import the screen).
- `lib/features/settings/presentation/settings_screen.dart` — one chevron row
  ("Alarm history") that `context.push('/history')`; add
  `import 'package:go_router/go_router.dart';`.
- `test/alarm_report_test.dart` — **new**, alongside `recurrence_test.dart` /
  `fired_events_test.dart`.

Not touched: `scheduler.dart`, the notification service, `reconcile()`, the
notification queue, any existing column.

## Steps

1. **DB read — `database.dart`.** Beside `lastFired`:
   ```dart
   Future<List<FiredEvent>> allEvents() => (select(firedEvents)
         ..orderBy([(t) => OrderingTerm.desc(t.firedAt)]))
       .get();
   ```
   Hand-written select — no `.g.dart` regen needed.

2. **Bounded past expansion — `recurrence.dart`.** Add:
   ```dart
   /// Occurrence wall-times in [from, to), skip-filtered. Reuses the same
   /// lazy RRULE expansion as nextOccurrences; the window is expected small.
   List<DateTime> pastOccurrences(Reminder r, DateTime from, DateTime to) {
     final skips = decodeSkips(r.skippedDates);
     return _rawOccurrences(r, from)
         .takeWhile((d) => d.isBefore(to))
         .where((d) => !skips.contains(d.millisecondsSinceEpoch))
         .toList();
   }
   ```
   `_rawOccurrences(r, from)` already returns a one-time reminder's start only
   when it's after `from`, and a lazy RRULE stream otherwise, so `takeWhile`
   stops the iteration at `to` — cheap for a 7-day window.

3. **Pure aggregation — `alarm_report.dart` (new).**
   ```dart
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
     final List<FiredEvent> log;          // newest first
     final Map<String, int> countsByKind; // 'fired'/'dismissed'/'snoozed'
     final List<MissedAlarm> missed;      // newest first
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
     for (final e in events) counts[e.kind] = (counts[e.kind] ?? 0) + 1;

     // events grouped by reminder → their firedAt instants
     final byReminder = <String, List<DateTime>>{};
     for (final e in events) {
       (byReminder[e.reminderId] ??= []).add(e.firedAt);
     }

     final missed = <MissedAlarm>[];
     for (final r in reminders.where((r) => r.isAlarm && r.isEnabled)) {
       for (final at in missedOccurrences(
           r, byReminder[r.id] ?? const [], from, now)) {
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
   ```
   // ponytail: streak counts clean days (no miss) rather than "had a scheduled
   // alarm and it rang" — simpler and reads the same to a user. A day with no
   // alarms is a clean day, not a break. Ceiling: capped at the 7-day window.

4. **Provider — `providers.dart`.** Beside `lastFiredProvider`:
   ```dart
   final alarmReportProvider = FutureProvider.autoDispose<AlarmReport>((ref) async {
     ref.watch(remindersStreamProvider); // rebuild on any reminder change
     final db = ref.watch(databaseProvider);
     final reminders = await ref.watch(reminderRepositoryProvider).getAll();
     return buildAlarmReport(reminders, await db.allEvents(), DateTime.now());
   });
   ```
   `autoDispose` so it re-reads on each screen open (fresh events), matching the
   `lastFiredProvider` reasoning. Import `../domain/alarm_report.dart`.

5. **Screen — `history_screen.dart` (new).** `ConsumerWidget`, `ref.watch(
   alarmReportProvider)`, `.when(loading/error/data)` like the detail screen.
   Layout inside a `ListView`, all house widgets:
   - **Header row:** `TkIconButton(Icons.arrow_back_ios_new, context.pop)` + a
     `body(22, w800)` "Alarm history" title (mirror detail-screen header).
   - **Streak `TkHero`:** e.g. `report.streakDays` → "🔥 5-day streak" with a
     sub line "Every alarm rang" — or when `streakDays == 0` and there are
     misses, "Some alarms had no ring recorded." Reuse the settings TkHero copy
     style (`t.heroInk`/`t.heroSub`).
   - **`TkSectionLabel('No ring recorded')` + `TkCard`:** one row per
     `report.missed` — reuse a `_dayLabel`-style date + `DateFormat('h:mm a')` +
     the reminder title, muted (`t.ink3`). If `missed.isEmpty`, render a single
     positive row ("No missed alarms in the last 7 days") instead of the list.
   - **`TkSectionLabel('Summary')` + `TkCard`:** three lines from
     `countsByKind` — Rang / Dismissed / Snoozed with counts (default 0).
   - **`TkSectionLabel('Recent')` + `TkCard`:** `report.log` rows (cap render at
     ~100 with `.take(100)` — 90-day retention keeps it small anyway), each
     `title · kind · <relative date/time>`. If the log is empty, one muted
     "No alarm activity yet" row.
   Copy `_dayLabel` from the detail screen (small private helper — not worth a
   shared util for two call sites). // ponytail: one screen, no charts, no
   per-reminder drill-down — the list answers the trust question.

6. **Route — `router.dart`.** Import `history_screen.dart`; add:
   ```dart
   GoRoute(
       path: '/history',
       pageBuilder: (_, s) => _fadePage(s, const HistoryScreen(), slide: true)),
   ```
   Placed among the pushed (non-shell) routes so the tab bar slides away like
   detail/edit.

7. **Entry point — `settings_screen.dart`.** Add
   `import 'package:go_router/go_router.dart';` and one chevron row. Reuse the
   existing `_dataRow` helper (icon + label + chevron) — append it to the
   Reliability card (it *is* a reliability question) as a third row after "Alarm
   sound", or add a standalone row: `_dataRow(Icons.history, 'Alarm history',
   () => context.push('/history'))`.

## Done when

- `test/alarm_report_test.dart` (new) passes — pure, no platform channels
  (build `Reminder`s directly like `fired_events_test.dart`'s `_r`, and
  `FiredEvent` rows in memory; call the domain functions, no DB needed except
  optionally an in-memory `AppDatabase` to exercise `allEvents`):
  - **`pastOccurrences` window + skips:** a `FREQ=DAILY` reminder over a 7-day
    past window returns one occurrence per day, none `>= to`, and a skipped
    instant (encoded in `skippedDates`) is absent.
  - **Missed detection:** a daily alarm with `fired` events on some days but a
    gap on one day → that day's fire instant is in `missedOccurrences`; days
    with an event are not. An event within 2 min of the fire instant covers it.
  - **Snoozed / dismissed cover:** an occurrence whose only event is `'snoozed'`
    (or `'dismissed'`) near the fire instant is **not** missed.
  - **Alarm-mode scoping:** a notification-mode reminder (`isAlarm == false`)
    with the same gaps produces **zero** missed entries from `buildAlarmReport`.
  - **Disabled scoping:** a disabled reminder contributes no missed entries.
  - **Counts:** `countsByKind` tallies each kind correctly from the events.
  - **Streak:** consecutive clean days ending today count up; inserting a missed
    fire on an intermediate day stops the streak at that boundary; caps at 7.
- `flutter analyze` clean; all existing suites still pass (no schema change, so
  `database_default_test` / `fired_events_test` are untouched).
- [x] Manual (device/emulator): open Settings → tap "Alarm history" → screen
  loads. With a recorded fire, it appears under Recent and Summary "Rang"
  increments.
- [x] Manual: create a daily alarm-mode reminder whose time already passed today
  without ringing (e.g. set start earlier, disable/re-enable so a past
  occurrence exists with no event) → it shows under "No ring recorded" with soft
  wording; the streak reflects the miss. A notification-mode reminder with the
  same gap does **not** appear.

## Out of scope

- **Missed detection for one-time alarms.** `reconcile()` disables a one-time
  reminder once its instant passes (`scheduler.dart:54`), so it leaves the
  enabled set and isn't scanned. Detecting a one-time alarm that never rang
  would need scanning disabled reminders, which reintroduces the
  user-disabled-vs-never-fired ambiguity. Left out deliberately.
- **Streaks longer than the 7-day window** — widen `_reportWindow` if wanted.
- **Missed detection for notification-mode reminders** — impossible honestly
  (no delivery/interaction callback; same limitation noted in plan 04's scope).
- **Home-screen entry, per-reminder history drill-down, filtering, charts,
  export** — the single Settings-reached screen answers the trust question; add
  any of these only if asked.
- **Any change to `reconcile()`, the scheduler window, or the notification
  queue** — this feature is read-only over existing data.
