---
status: in-progress
verified-by:
  - test/nagging_test.dart
  - test/scheduler_test.dart
---

# Plan 06 — Nagging / repeat-until-dismissed (medication mode)

**Outcome:** A reminder can be set to nag — fire N minutes before (the existing
lead offset), again at the exact time, then every M minutes until the user
dismisses it — with every nag fire computed from `startDateTime` + RRULE at
reconcile time (nothing derived is persisted) and dismissal reliably stopping
the remaining nags, including a Dismiss tapped from the notification shade while
the app is dead.

## Prereq

None. Plans 01–03 are independent of this. **No new runtime dependency** — this
is entirely extra `zonedSchedule` calls the scheduler already makes, plus two
new columns and one UI row. It does add a DB migration (schemaVersion 3 → 4).

## Design decisions (the important calls)

### Nags are extra scheduled notifications, computed at read time

The app already fires **one** notification per occurrence, at
`occ - offsetMinutes` (`scheduler.dart:67`). Nagging just makes each occurrence
expand into a small *set* of fire times instead of one:

```
occ - offsetMinutes   (the existing "N minutes before" lead — unchanged)
occ                    (the "at time" ping — new, only when nagging is on)
occ + M, occ + 2M, …, occ + maxNags·M   (the nags)
```

These times are **never stored** — they are recomputed every `reconcile()` from
`startDateTime` + RRULE via a new pure helper `occurrenceFireTimes()` in the
domain layer, exactly like `nextOccurrences()`. This obeys the hard CLAUDE.md
rule (no derived data) and stays inside the rolling-window model (DB is truth,
OS queue rebuilt from it, idempotent).

**`offsetMinutes` reused as the "before".** When nagging is **off** the fire set
is `[occ - offsetMinutes]` — byte-for-byte today's behavior. When nagging is
**on**, the same offset produces the heads-up "before", and a fresh fire is
added *at* `occ`. So nagging is purely additive; existing reminders (nag off)
are untouched. // ponytail: not adding a second "pre-alarm offset" field — the
one offset covers the "before", the toggle adds the "at time + nags". Add a
separate pre-offset only if users ask for before *and* a different lead.

### "Until dismissed" needs one persisted flag — `dismissedUntil`

This is the subtle part. Dismiss today (`notification_service.dart:108`,
`alarm_screen.dart:_dismiss`, `reminder_repository`) just calls `reconcile()`.
That works for snooze (which writes `snoozedUntil`) and for one-time reminders
(auto-disabled once fired), but it **does not stop nags**: reconcile
`cancelAll()`s then reschedules, and since nag times are recomputed from
`startDateTime`, the still-future nags of the current occurrence get re-added.
Dismiss changes no DB state, so reconcile faithfully re-arms the very nags the
user just dismissed. Verified by reading `_reconcile()` end to end.

So "until dismissed" is impossible in a rebuild-from-DB model **without a
persisted record of the dismissal**. The minimal fix mirrors how `snoozedUntil`
already works: a nullable `dismissedUntil` timestamp set on Dismiss. In
reconcile, an occurrence whose anchor time `occ` is at or before `dismissedUntil`
emits **no** fire set. Current occurrence anchor `occ ≤ dismiss-time` → skipped
(nags gone); tomorrow's anchor `occ + 24h > dismiss-time` → kept (still nags).

`dismissedUntil` is **not** derived data — it is a record of a user action,
computable from nothing but the tap, identical in kind to the already-stored
`snoozedUntil`. It never needs clearing: a stale value from yesterday only
suppresses occurrences `≤` itself, and every future occurrence is later than
any past dismissal, so old values self-expire (same reasoning as a past
`snoozedUntil`).

### Fixed interval choice, capped repeat count

`nagMinutes` is a small **choice** (Off / 5 / 15 / 30) reusing the existing
segmented-control pattern, not a free number. Repeats are capped by a scheduler
const `_maxNags` so a never-dismissed reminder can't nag forever (battery /
shade spam) or blow the notification budget. // ponytail: fixed cap constant,
no per-reminder repeat-count setting — one ceiling for everyone; make it
per-reminder only if someone needs a 3-nag vs 20-nag distinction.

## Context (files this touches)

- `lib/core/database/database.dart` — `Reminders` table: add `nagMinutes`
  (int, default 0 = off) and `dismissedUntil` (nullable DateTime); bump
  `schemaVersion` to 4 and add the `from < 4` migration; add
  `setDismissedUntil(id, when)` next to `setSnoozedUntil` (63).
- `lib/features/reminders/domain/recurrence.dart` — **new pure helper**
  `occurrenceFireTimes(Reminder r, DateTime occ, int maxNags)` alongside
  `nextOccurrences`/`effectiveNextFire` (the established pure-seam pattern).
- `lib/core/scheduler/scheduler.dart` — `_reconcile()`: expand each occurrence
  through `occurrenceFireTimes`, skip dismissed-occurrence sets, and widen the
  one-time auto-disable to the *last* nag time.
- `lib/core/notifications/notification_service.dart` —
  `handleNotificationAction`: on Dismiss, write `dismissedUntil = now` before
  reconcile (this is the path the background isolate uses via
  `notificationBackgroundHandler`).
- `lib/features/reminders/data/reminder_repository.dart` — new
  `dismiss(String id)` (set `dismissedUntil`, reconcile) for the in-app path.
- `lib/features/reminders/presentation/screens/alarm_screen.dart` —
  `_dismiss()` calls `repository.dismiss(p.reminderId)` instead of a bare
  `reconcile()`.
- `lib/features/reminders/presentation/screens/add_edit_reminder_screen.dart` —
  a "Nag until dismissed" segmented row modeled on the "Remind me" row
  (315-340); persist to `nagMinutes` (131).
- `test/nagging_test.dart` — **new**. `test/scheduler_test.dart` — extended.

## Steps

1. **DB columns + migration.** In `Reminders` add:
   ```dart
   IntColumn get nagMinutes => integer().withDefault(const Constant(0))();
   DateTimeColumn get dismissedUntil => dateTime().nullable()();
   ```
   Bump `schemaVersion` to `4`; in `onUpgrade` add
   `if (from < 4) { await m.addColumn(reminders, reminders.nagMinutes);
   await m.addColumn(reminders, reminders.dismissedUntil); }`. Add:
   ```dart
   Future<void> setDismissedUntil(String id, DateTime? until) =>
       (update(reminders)..where((t) => t.id.equals(id)))
           .write(RemindersCompanion(dismissedUntil: Value(until)));
   ```
   Regenerate drift (`dart run build_runner build`) so `database.g.dart` picks
   up the columns.

2. **Pure fire-time helper (the test seam).** In `recurrence.dart`:
   ```dart
   /// All notification fire times for one occurrence anchored at [occ]:
   /// the "before" lead, and — when nagging is on — the at-time ping plus up
   /// to [maxNags] repeats every nagMinutes. Sorted, de-duplicated. Nag off
   /// (nagMinutes == 0) yields exactly [occ - offsetMinutes] — today's single
   /// fire. Pure: no DB, no clock.
   List<DateTime> occurrenceFireTimes(Reminder r, DateTime occ, int maxNags) {
     final before = occ.subtract(Duration(minutes: r.offsetMinutes));
     if (r.nagMinutes <= 0) return [before];
     final times = <DateTime>{before, occ};
     for (var i = 1; i <= maxNags; i++) {
       times.add(occ.add(Duration(minutes: r.nagMinutes * i)));
     }
     final list = times.toList()..sort();
     return list;
   }
   ```
   (When `offsetMinutes == 0` the "before" equals `occ`; the `Set` dedupes it.)

3. **Scheduler — expand occurrences, honor dismissal.** In `_reconcile()`:
   - Replace the one-time `fired` filter's time test so a nagging one-time is
     only disabled after its **last** nag, and a dismissed one is disabled at
     once:
     ```dart
     final fired = reminders.where((r) {
       if (r.rruleString != null) return false;
       final fires = occurrenceFireTimes(r, r.startDateTime, _maxNags);
       final dismissed = r.dismissedUntil != null &&
           !r.startDateTime.isAfter(r.dismissedUntil!);
       final snoozePending =
           r.snoozedUntil != null && r.snoozedUntil!.isAfter(now);
       return (fires.last.isBefore(now) || dismissed) && !snoozePending;
     });
     ```
     (Nag off → `fires.last == start - offset`, i.e. the exact test at line 52
     today.)
   - In the occurrence loop, expand each occurrence and skip dismissed sets,
     capping per-reminder fires at `_perReminder` so a heavy nagger can't starve
     the 60-slot window:
     ```dart
     final dismissed = r.dismissedUntil;
     var count = 0;
     for (final occ in nextOccurrences(r, now, _perReminder)) {
       if (dismissed != null && !occ.isAfter(dismissed)) continue; // whole set
       for (final fireAt in occurrenceFireTimes(r, occ, _maxNags)) {
         if (fireAt.isAfter(now) && count < _perReminder) {
           occurrences.add((r: r, fireAt: fireAt));
           count++;
         }
       }
     }
     ```
   - Add `static const _maxNags = 8;` near the other window consts.
   // ponytail: two nag times that collide with a neighbor occurrence's fire map
   to the same `occurrenceNotificationId` (id is by time) and the later
   `schedule` overwrites — cosmetic, not a correctness bug. Note: later
   occurrences a nagger pushes past its 10 slots are picked up on the next
   reconcile (app open / any change) — the same rolling-window property the app
   already relies on; a nag firing while idle does not itself trigger a top-up.

4. **Dismiss writes the flag (both paths).**
   - `notification_service.dart` `handleNotificationAction`: add a real Dismiss
     branch before the reconcile:
     ```dart
     } else if (actionId == dismissActionId) {
       final p = parsePayload(payload);
       await db.setDismissedUntil(p.reminderId, DateTime.now());
     } else {
       return;
     }
     await Scheduler(db, service).reconcile();
     ```
     This is exactly the code `notificationBackgroundHandler` runs in the dead-
     app isolate — no extra wiring needed for background dismissal.
   - `reminder_repository.dart`: add
     ```dart
     Future<void> dismiss(String id) async {
       await _db.setDismissedUntil(id, DateTime.now());
       await _scheduler.reconcile();
     }
     ```
   - `alarm_screen.dart` `_dismiss()`: replace
     `ref.read(schedulerProvider).reconcile()` with
     `ref.read(reminderRepositoryProvider).dismiss(p.reminderId)` (keep the
     `try/finally` + `context.go('/')` so a failure never strands the ring
     screen). Setting `dismissedUntil` on a non-nag or one-time reminder is
     harmless — its only effect is suppressing occurrences `≤ now`, which are
     already past.

5. **Add/Edit UI.** Below the "Remind me" `TkCard` (ends line 341), add a
   "Nag until dismissed" `TkSegmented<int>` mirroring the offset control:
   options `[0, 5, 15, 30]`, `value: _nag`, labels `Off / Every 5 min /
   Every 15 min / Every 30 min`, `onChanged: (v) => setState(() => _nag = v)`.
   Add `int _nag = 0;` field, load it in the edit path
   (`_nag = r.nagMinutes;` near line 85), and pass `nagMinutes: _nag` into the
   `Reminder(...)` build (near line 131). // ponytail: no `defaultNag` pref —
   defaults to Off; add a settings default only if repeat naggers appear.

## Done when

- `test/nagging_test.dart` (new) passes — pure, no platform channels:
  - **Nag off is unchanged:** `occurrenceFireTimes(r(nag:0, offset:5), occ, 8)`
    returns exactly `[occ - 5min]`.
  - **Full pattern:** `occurrenceFireTimes(r(nag:5, offset:15), occ, 3)` returns
    `[occ-15, occ, occ+5, occ+10, occ+15]` — sorted, the "before", the at-time,
    and 3 nags, no duplicates.
  - **Offset 0 dedupes:** `r(nag:5, offset:0)` does not emit `occ` twice.
- `test/scheduler_test.dart` (extended, using the existing in-memory DB + fake):
  - **Nagging occurrence schedules multiple fires:** a future recurring reminder
    with `nagMinutes:5` schedules more entries for its id than an identical
    `nagMinutes:0` reminder.
  - **Dismiss stops the current occurrence's nags:** with a reminder whose
    anchor is in the recent past and nags still ahead, setting
    `dismissedUntil = now` then `reconcile()` schedules **zero** fires for the
    current occurrence but still schedules the next occurrence's set.
  - **Dismissed one-time is disabled:** a one-time nagging reminder with
    `dismissedUntil` at/after its start ends up `isEnabled == false`.
  - **Non-dismissed nagging one-time stays enabled until its last nag** (guards
    the widened `fired` filter — a first-fire-passed one-time must not disable
    mid-nag).
  - Existing scheduler tests (offset-in-past disable, serialization, etc.) still
    pass unchanged.
- `flutter analyze` clean; all existing suites pass (regenerated
  `database.g.dart` compiles; `database_default_test` still green).
- [ ] Manual (device/emulator): create a reminder ~2 min out, offset "5 min
  before", nag "Every 5 min", alarm style. Confirm: a heads-up ~5 min before
  (if time allows), the alarm at the time, then a re-ring ~5 min later. Dismiss
  it → no further nags arrive; the reminder still shows its next occurrence.
- [ ] Manual (dead-app / shade dismiss): let a nagging alarm fire with the app
  swiped away, dismiss from the notification shade, force-stop the app, wait
  past the next nag interval → **no** further nag fires (proves
  `dismissedUntil` written in the background isolate survives to the next
  reconcile).

## Out of scope

- A separate pre-alarm offset field distinct from `offsetMinutes` — the one
  offset is the "before".
- Per-reminder repeat-count or free-form nag interval — fixed choices + one cap
  const.
- Foreground full-screen takeover on each nag: `ForegroundAlarmWatcher`
  continues to track only the primary `occ - offset` fire; while the app is
  foregrounded, nags appear as heads-up notifications, not the full-screen ring.
  Wiring the watcher to nag times is a follow-up.
- A `defaultNag` setting/pref (settings screen unchanged).
- Combining nagging with an active snooze in any special way — snooze schedules
  its own single fire as today; the two features don't interact beyond both
  living on the same reminder.
- Escalating behavior (louder, different sound per nag) — every nag reuses the
  existing alarm/notification channel.
