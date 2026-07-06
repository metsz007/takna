---
status: done
verified-by:
  - test/scheduler_test.dart
---

# Plan 15 — Vacation pause

**Outcome:** The user can pause *all* alarms until a chosen date with one
global switch; while paused nothing rings, the home screen and settings say so
unmissably, and alarms resume on their own at the pause date — even if the app
was never reopened.

## Prereq

None. No new dependencies — the date picker is Flutter's built-in
`showDatePicker` (ladder rung 4: native platform feature over a lib). One DB
schema bump (6 → 7).

## Design decisions

### Store `pausedUntil` in the DB, not shared_preferences

`reconcile()` (`lib/core/scheduler/scheduler.dart`) is the only place that
decides what gets scheduled, and it runs in **two isolates**: the main app
isolate, and the `flutter_local_notifications` background isolate
(`notificationBackgroundHandler` in `notification_service.dart:137`, which
builds its own `AppDatabase()` and `Scheduler(db, service).reconcile()` when a
Snooze/Dismiss action is tapped while the app is dead).

shared_preferences is unreliable across that boundary: each isolate loads its
own cached snapshot at `getInstance()`, there is no cross-isolate change
notification, and a value written on the main isolate is not guaranteed visible
to a background-isolate instance created later. So a pause set in Settings could
be silently ignored by the background reconcile — the exact silent-pause failure
the honesty requirement forbids.

The app database is already `shareAcrossIsolates: true` (WAL,
`database.dart:48`) and the background isolate already opens it — a DB read is
the one path guaranteed consistent in both isolates. CLAUDE.md also mandates the
DB as the single source of truth and forbids the scheduler reading prefs/UI
state. **Verdict: `pausedUntil` lives in the DB.**

Shape: a single-row `AppState` table with a nullable `pausedUntil` column.
// ponytail: one-column single-row table, not a generic key/value store — one
setting doesn't earn a KV schema. Widen to KV only when a second cross-isolate
setting appears.

### The pause is a scheduling *floor*, not a cancel

While `now < pausedUntil`, reconcile must schedule **nothing before**
`pausedUntil` but **still schedule occurrences after it** — otherwise a closed
phone would never resume (nothing re-runs reconcile at the moment the pause
ends). The mechanism: anchor the occurrence expansion at
`floor = max(now, pausedUntil)` instead of `now`. Because
`nextOccurrences(r, floor, _perReminder)` already starts strictly after its
anchor (`recurrence.dart`), the rolling 60-slot window fills with the first
*post-pause* occurrences, they get written into the OS queue now, survive reboot
via the existing `BOOT_COMPLETED` receiver, and fire on their own when the pause
date arrives — with no app open. That pre-scheduling **is** the auto-resume.

### Auto-expiry is passive — be honest about it

Nothing is scheduled to run exactly at `pausedUntil`. Reconcile only re-runs on
app open (`main.dart:33`), any reminder mutation (repository → reconcile), or a
Snooze/Dismiss action. None is guaranteed at the pause boundary — so we do **not**
rely on a reconcile firing at expiry. Resume for a closed app comes solely from
the post-pause notifications pre-scheduled above. Whenever a reconcile next does
run, `floor` collapses back to `now` and behavior is normal; a stale past
`pausedUntil` is inert (never clamps anything) and is left in the DB rather than
cleared. // ponytail: no cleanup job — a past timestamp already reads as
"not paused".

### One-time reminders landing inside the pause window

The fired-one-time auto-disable block stays on real `now` (unchanged). A one-time
reminder whose time falls inside the pause window is suppressed (its occurrence
< `floor`, so nothing is scheduled); once the pause ends its time is in the past
and the next reconcile disables it like any missed one-timer. This is the honest
meaning of "paused": alarms during the window do not ring, full stop.

### Pending snoozes are suppressed too

The snooze occurrence is gated by `floor` as well — a pause means *nothing*
rings, snoozes included. A snooze time inside the window is dropped; when the
pause ends it's in the past and gone. Consistent, no special case.

### Pause semantics

`showDatePicker` returns a day; `pausedUntil = DateTime(y, m, d)` at local
midnight. Alarms resume at 00:00 on the chosen date. Banner/row read "…paused
until <that date>".

## Context (files this touches)

- `lib/core/database/database.dart` — **new** `AppState` table (single row,
  `pausedUntil` nullable `DateTime`); `schemaVersion` 6 → 7 with
  `createTable(appState)` in `onUpgrade`; `getPausedUntil()` / `setPausedUntil()`.
- `lib/core/scheduler/scheduler.dart` — read `pausedUntil`, compute `floor`,
  use it as the occurrence anchor/filter (not the fired-disable block).
- `lib/features/reminders/data/reminder_repository.dart` — `setPausedUntil(DateTime?)`
  (write DB → reconcile), keeping the one write path intact.
- `lib/features/reminders/presentation/providers.dart` — `pausedUntilProvider`
  (FutureProvider reading `db.getPausedUntil()`; invalidated after a set).
- `lib/features/settings/presentation/settings_screen.dart` — a "Pause all
  alarms" row (date picker / Resume), reusing the `_permRow`/`_dataRow` look.
- `lib/features/reminders/presentation/screens/home_screen.dart` — a prominent
  pause banner at the top of `_HomeList`.
- `test/scheduler_test.dart` — pause cases.

## Steps

1. **DB — `AppState` table + accessors.** In `database.dart`:
   ```dart
   class AppState extends Table {
     IntColumn get id => integer().withDefault(const Constant(0))();
     DateTimeColumn get pausedUntil => dateTime().nullable()();
     @override
     Set<Column> get primaryKey => {id};
   }
   ```
   Add to `@DriftDatabase(tables: [...])`, bump `schemaVersion` to 7, and in
   `onUpgrade` add `if (from < 7) await m.createTable(appState);`. Accessors:
   ```dart
   Future<DateTime?> getPausedUntil() async =>
       (await (select(appState)..where((t) => t.id.equals(0)))
               .getSingleOrNull())?.pausedUntil;

   Future<void> setPausedUntil(DateTime? until) => into(appState)
       .insertOnConflictUpdate(AppStateCompanion.insert(pausedUntil: Value(until)));
   ```
   Regenerate drift (`dart run build_runner build`).

2. **Scheduler — apply the floor.** In `_reconcile()`, after `final now = …`:
   ```dart
   final paused = await _db.getPausedUntil();
   final floor = (paused != null && paused.isAfter(now)) ? paused : now;
   ```
   Leave the fired-one-time-disable block on `now`. In the per-reminder
   occurrence loop, replace `now` with `floor` in the three spots: the snooze
   gate (`snooze.isAfter(floor)`), the `nextOccurrences(r, floor, _perReminder)`
   anchor, and the `fireAt.isAfter(floor)` filter.

3. **Repository — `setPausedUntil`.**
   ```dart
   Future<void> setPausedUntil(DateTime? until) async {
     await _db.setPausedUntil(until);
     await _scheduler.reconcile();
   }
   ```
   Resume is `setPausedUntil(null)`. Keeps UI → repository → DB → reconcile.

4. **Provider.**
   `final pausedUntilProvider = FutureProvider((ref) => ref.watch(databaseProvider).getPausedUntil());`
   Both the banner and settings watch it; callers `ref.invalidate(pausedUntilProvider)`
   after a set (same pattern as `reliabilityProvider`).

5. **Settings row.** New `TkSectionLabel('Vacation')` + `TkCard`. When not paused,
   a `_dataRow`-style "Pause all alarms" that opens
   `showDatePicker(firstDate: today, lastDate: today + 365d)`; on a pick →
   `repo.setPausedUntil(picked)` + invalidate. When paused, the row shows
   "Paused until <date>" (via `pausedUntilProvider`) with a "Resume" button
   styled like the `_permRow` Allow button → `setPausedUntil(null)` + invalidate.

6. **Home banner.** At the top of `_HomeList`'s `ListView` (above the hero),
   render a prominent banner when `pausedUntilProvider` is a future date:
   "All alarms paused until <date>" + a Resume button. Reuse the
   `ReliabilityBanner` warning tone (accent/amber) so it's unmissable; a silent
   pause is the worst bug in this app's terms. Renders nothing when not paused.
   // ponytail: banner only in `_HomeList`, not `_EmptyState` — with zero
   reminders there is nothing to pause.

## Done when

- `test/scheduler_test.dart` (extended) passes — uses the real in-memory
  `AppDatabase`, so `setPausedUntil`/`getPausedUntil` work directly:
  - **Nothing before, something after.** Extend `_FakeNotifications` to also
    record each `when`. A daily reminder (past start) + `db.setPausedUntil(now + 3d)`,
    reconcile → `scheduled` contains the reminder **and every recorded `when`
    is `>= pausedUntil`** (nothing inside the window, occurrences after it).
  - **One-time inside the window is suppressed, one after is not.** Two one-time
    reminders — `before` at `now + 1h`, `after` at `now + 2d` — with
    `pausedUntil = now + 1d`; reconcile → `scheduled` contains `after`, not
    `before`.
  - **Expiry is passive.** `db.setPausedUntil(now - 1d)` (past) with a future
    one-time reminder → it schedules normally (stale pause is inert).
  - Existing cases still pass unchanged (no pause row → `getPausedUntil()` null
    → `floor == now`).
- `flutter analyze` clean; all existing suites pass.
- [ ] Manual: set pause to a future date in Settings → home shows the paused
  banner and the settings row reads "Paused until <date>".
- [ ] Manual: with pause active, add a reminder for +2 min (inside the window)
  → it does **not** ring.
- [ ] Manual: set a reminder for shortly after the pause end, force-close the
  app, leave it closed through the pause boundary → it rings without the app
  being opened (proves the pre-scheduled post-pause occurrence).
- [ ] Manual: tap Resume (banner or settings) → banner clears, alarms
  reschedule immediately.

## Out of scope

- Per-reminder or per-tag pause — this is one global switch only.
- Pause presets ("this weekend", "1 week") or a duration picker — a single
  resume date covers the vacation use case; add presets only if asked.
- A pause history/audit entry — pause is transient state, not a fired event.
- Snoozing *through* a pause (re-arming a suppressed snooze after resume) —
  suppressed snoozes are simply dropped.
- Clearing the stale `pausedUntil` after expiry (left inert on purpose).
