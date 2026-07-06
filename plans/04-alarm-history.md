---
status: in-progress
verified-by:
  - test/fired_events_test.dart
---

# Plan 04 â€” Alarm history / fired log

**Outcome:** Every time an alarm rings or is dismissed/snoozed, Takna appends a
row to a small `fired_events` table, and the reminder's detail screen shows a
"Last fired" line â€” so the user can answer "did my 8am alarm actually fire?"
without trusting the OS blindly.

## Prereq

None (plans 01 and 02 are done; 03 is independent). No new runtime
dependencies â€” drift, the DB, and `intl` are already here. Requires a
`build_runner` regen (new table â†’ regenerated `database.g.dart`).

## Design decisions (why a log, why not reconcile)

- **Append-only audit log, deliberately outside the single write path.**
  CLAUDE.md's rule is UI â†’ repository â†’ DB â†’ `reconcile()`. A fired-event row is
  not source-of-truth scheduling state â€” it is a historical fact ("this alarm
  rang at this instant") that nothing recomputes and nothing schedules from.
  So the write is a **direct DB insert** at the capture point, with **no
  reconcile**. This is the same exemption the task calls out. It does not
  weaken the rule: `reconcile()` still owns the notification queue and reads
  only from `reminders`, never from `fired_events`.
- **Store a title snapshot, and that is NOT "derived data".** The
  never-store-derived rule (next-fire, occurrence lists) forbids caching values
  recomputable from `startDateTime` + RRULE. A past event's title is the
  opposite: the reminder can later be renamed or deleted, and the history must
  still read "Standup â€” dismissed". A recorded fact at time-of-fire is not
  derivable after the fact, so it is stored, once, on the event row.
- **`kind` is a plain text tag** (`'fired'` / `'dismissed'` / `'snoozed'`) â€”
  three states, clearest as a string, no enum table.
- **Retention: prune-on-insert, 90-day cap.** `logFired` deletes rows older
  than 90 days in the same call. // ponytail: prune-on-insert, no scheduled
  job â€” alarms are infrequent, one extra `DELETE` per fire is free. Ceiling:
  if a user has hundreds of alarms/day, switch the cap to "keep last N rows"
  (one `DELETE ... WHERE id NOT IN (SELECT ... LIMIT N)`).
- **Laziest UI: a "Last fired" line on the existing detail screen.** No new
  screen, no new route, no settings entry â€” the trust question is per-reminder,
  and the detail screen is where the user already looks. A full scrollable
  history list is out of scope (see below).

## Context (files this touches)

- `lib/core/database/database.dart` â€” add the `FiredEvents` table (6-24 area),
  register it in `@DriftDatabase(tables: [Reminders, FiredEvents])` (26), bump
  `schemaVersion` 3 â†’ 4 (37) with a `createTable` migration (40-45), and add
  `logFired` + `lastFired` methods (alongside `setSnoozedUntil` etc., 62-68).
- `lib/core/database/database.g.dart` â€” **regenerated** by build_runner (do not
  hand-edit).
- `lib/core/notifications/notification_service.dart` â€”
  `handleNotificationAction` (102-112) already has `db` + the parsed payload
  (title, reminderId); add a `logFired` call for the snooze and dismiss
  branches. This path runs in the **background isolate** too
  (`notificationBackgroundHandler`, 133-147) which already builds its own
  `AppDatabase` â€” the DB uses `shareAcrossIsolates`, so the insert is safe.
- `lib/features/reminders/presentation/screens/alarm_screen.dart` â€”
  `initState` (27-41) logs the `'fired'` event (the ring is actually on
  screen); the existing `_dismiss`/`_snooze` are left alone (the shade path
  already covers those verbs â€” see note in step 4).
- `lib/features/reminders/presentation/providers.dart` â€” add
  `lastFiredProvider` (FutureProvider.family) next to `reminderByIdProvider`
  (24-28).
- `lib/features/reminders/presentation/screens/reminder_detail_screen.dart` â€”
  one "Last fired" line under the NEXT ALARM hero (~136).
- `test/fired_events_test.dart` â€” **new**, sits alongside `scheduler_test.dart`
  / `notification_action_test.dart`.

## Steps

1. **Table + DB methods â€” `database.dart`.**
   ```dart
   class FiredEvents extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get reminderId => text()();
     TextColumn get title => text()();     // snapshot at fire time (see design)
     TextColumn get kind => text()();      // 'fired' | 'dismissed' | 'snoozed'
     DateTimeColumn get firedAt => dateTime()();
   }
   ```
   Register it: `@DriftDatabase(tables: [Reminders, FiredEvents])`. Bump
   `schemaVersion` to `4` and add to `onUpgrade`:
   ```dart
   if (from < 4) await m.createTable(firedEvents);
   ```
   Methods:
   ```dart
   // at defaults to now; the param exists only so the prune test can log an
   // old row. Not reconcile-routed on purpose â€” append-only audit log.
   Future<void> logFired(String reminderId, String title, String kind,
       {DateTime? at}) async {
     await into(firedEvents).insert(FiredEventsCompanion.insert(
         reminderId: reminderId, title: title, kind: kind,
         firedAt: at ?? DateTime.now()));
     // ponytail: prune-on-insert, 90-day cap â€” no background job.
     final cutoff = DateTime.now().subtract(const Duration(days: 90));
     await (delete(firedEvents)
           ..where((t) => t.firedAt.isSmallerThanValue(cutoff)))
         .go();
   }

   Future<FiredEvent?> lastFired(String reminderId) =>
       (select(firedEvents)
             ..where((t) => t.reminderId.equals(reminderId))
             ..orderBy([(t) => OrderingTerm.desc(t.firedAt)])
             ..limit(1))
           .getSingleOrNull();
   ```
   Then regenerate: `dart run build_runner build --delete-conflicting-outputs`.

2. **Log the terminal action â€” `notification_service.dart`.** In
   `handleNotificationAction`, after the existing DB effect and before/after the
   `reconcile()` (order doesn't matter â€” separate table), record the verb:
   ```dart
   final p = parsePayload(payload);
   if (actionId == snoozeActionId) {
     await db.setSnoozedUntil(p.reminderId, ...);
     await db.logFired(p.reminderId, p.title, 'snoozed');
   } else if (actionId == dismissActionId) {
     await db.logFired(p.reminderId, p.title, 'dismissed');
   } else {
     return;
   }
   await Scheduler(db, service).reconcile();
   ```
   (Parse `payload` once at the top; the dismiss branch currently doesn't.)
   This covers **shade action buttons in every state** â€” foreground dispatch and
   the dead-app background isolate â€” because both route through this function.

3. **Log the ring â€” `alarm_screen.dart` `initState`.** The full-screen alarm
   opening is the honest "it fired and I saw it" marker for alarm-mode
   reminders (both the full-screen-intent launch and the foreground watcher
   route here). Add after the existing `parsePayload`:
   ```dart
   ref.read(databaseProvider)
       .logFired(p.reminderId, p.title, 'fired');
   ```
   `databaseProvider` is already reachable via `ref` here. Guard nothing extra â€”
   a missing `reminderId` just writes an empty-id row that no detail screen
   queries; not worth a branch.

4. **Do NOT double-log the full-screen Snooze/Dismiss buttons.**
   `AlarmScreen._dismiss`/`_snooze` are a *different* interaction path than the
   shade buttons â€” a single fire is resolved by exactly one of them. The
   `'fired'` row from step 3 already proves the full-screen alarm rang; adding
   `'dismissed'`/`'snoozed'` there too is a nice-to-have, not needed for the
   trust question. // ponytail: skip it â€” the `'fired'` row answers "did it
   ring?"; add the full-screen terminal verb only if users want the outcome,
   not just the fire.

5. **Provider â€” `providers.dart`.**
   ```dart
   final lastFiredProvider = FutureProvider.family<FiredEvent?, String>(
       (ref, id) => ref.watch(databaseProvider).lastFired(id));
   ```
   // ponytail: not wired to auto-refresh mid-view â€” the alarm screen navigates
   home before detail is reopened, so a plain one-shot fetch is fresh enough.

6. **Detail line â€” `reminder_detail_screen.dart`.** Under the NEXT ALARM
   `TkHero` (~136), read `ref.watch(lastFiredProvider(reminderId))` and, when it
   has a value, render one muted line matching the screen's type scale, e.g.:
   ```
   Last fired: Today 8:00 AM Â· dismissed
   ```
   Reuse the existing `_dayLabel` + `DateFormat('h:mm a')` and `body(...)`
   styling (`t.ink3`). Render nothing when the event is null or still loading â€”
   no "never fired" placeholder (lazy; absence reads as "hasn't rung yet").

## Done when

- `test/fired_events_test.dart` (new) passes â€” pure, in-memory
  `AppDatabase.forTesting(NativeDatabase.memory())`, no platform channels
  (same setup as `scheduler_test.dart`):
  - **Insert + read back:** `logFired('a', 'Standup', 'fired')` then
    `lastFired('a')` returns a row with `kind == 'fired'`, `title == 'Standup'`.
  - **Most-recent wins:** three `logFired` calls for `'a'` with `at:` a minute
    apart â†’ `lastFired('a')` returns the newest `kind`.
  - **Per-reminder scoping:** an event for `'b'` does not surface in
    `lastFired('a')`.
  - **90-day prune:** `logFired('a', 'Old', 'fired', at: now - 91 days)` then
    `logFired('a', 'New', 'fired')` â†’ exactly one `'a'` row remains and
    `lastFired('a').title == 'New'`. (Query the table count directly.)
  - **Action path wiring (reuses the `_FakeNotifications` pattern):**
    `handleNotificationAction('dismiss', '0|10|a|Standup', db, fake)` writes a
    `'dismissed'` row for `'a'`; `'snooze'` writes a `'snoozed'` row; a bogus/
    null actionId writes **no** row.
- `flutter analyze` clean; all existing suites still pass (schema bump doesn't
  break `database_default_test.dart` â€” verify).
- [ ] Manual (device/emulator): let an alarm fire full-screen â†’ open its detail
  â†’ "Last fired: â€¦ Â· fired" (or the verb after acting) shows. Dismiss from the
  notification shade instead â†’ detail shows "Â· dismissed".
- [ ] Manual: kill the app, let an alarm fire, press Dismiss on the lock-screen
  notification â†’ reopen app â†’ detail shows the dismissed event (confirms the
  background-isolate write landed).

## Out of scope

- A full scrollable history list / a Settings "History" screen â€” the per-
  reminder "Last fired" line answers the trust question; a global log is a
  separate plan if anyone asks.
- Logging fires that the user **never interacts with** (alarm rings, user swipes
  the notification away with no action and never opens full-screen). Alarm-mode
  reminders still log `'fired'` when the ring UI opens; notification-only
  reminders that are swiped away log nothing â€” `flutter_local_notifications`
  gives no delivery callback for a `zonedSchedule` post while the app is dead,
  and adding native delivery tracking is not worth it here.
- The full-screen Snooze/Dismiss buttons logging a second terminal-verb row
  (step 4).
- Exporting the history (plan 03's backup covers reminders only, by design).
- Any change to `reconcile()`, the scheduler window, or the notification queue.
