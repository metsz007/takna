# Takna — Architecture

> **Takna** (Bisaya: *time*) is a local-only mobile scheduling and reminder app. Its core promise is **reliable alarms** — reminders fire at the exact minute, even when the phone is locked or asleep. Built with Flutter, no accounts, no cloud sync.

This document is the technical blueprint for the v1 build. It is derived from the finalized prototype (Home, Add/Edit, Detail, Settings, Onboarding, Empty).

---

## 1. Product scope (v1)

**In scope**
- Create, edit, delete, enable/disable reminders
- One-time and recurring reminders (daily, weekly, monthly, custom)
- Reliable exact alarms + notifications that fire when the phone is locked
- Per-reminder "remind me" offset (at time / 5 min before / custom) and snooze duration
- Detail view showing the next 5 upcoming occurrences
- Positively-framed permission onboarding + a Settings reliability panel
- Light and dark mode

**Explicitly out of scope for v1**
- Accounts, cloud sync, multi-device
- Google/Apple calendar import
- Sharing / collaboration
- A month-grid calendar view (list-first for v1)

---

## 2. Guiding principles

1. **The database is the single source of truth.** The OS notification queue is disposable and rebuildable. Never treat scheduled OS notifications as data — they get wiped on reboot and are capped on iOS.
2. **One-directional data flow.** UI → Repository → DB write → Scheduler reconciles OS notifications. The UI never touches the DB or notification plugin directly.
3. **Reliability is the product.** Every architectural decision favors an alarm actually firing over convenience. If a tradeoff threatens reliability, reliability wins.
4. **Feature-first, lightly layered.** Enough structure to scale, not so much it becomes ceremony.

---

## 3. Tech stack

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter | Cross-platform (iOS + Android) |
| Notifications / alarms | `flutter_local_notifications` | `zonedSchedule` with `exactAllowWhileIdle` |
| Alarm fallback (Android) | *(none — deliberately)* | `flutter_local_notifications`' boot receiver re-posts the scheduled queue; `android_alarm_manager_plus` was not added in v1 |
| Local storage | `drift` (SQLite) | Type-safe; real SQL helps recurrence querying |
| State management | `riverpod` | Testable, right-sized for this app |
| Time zones | `timezone` | Required — `zonedSchedule` needs TZ data or DST breaks |
| Recurrence | `rrule` | iCalendar RRULE standard — do not invent a custom format |
| Permissions | `permission_handler` | Notifications, exact alarm, battery optimization |
| Routing | `go_router` | Flat routes; bottom sheet stays modal |
| Launcher icon | `flutter_launcher_icons` | Generates platform sizes from one master |

---

## 4. Folder structure (feature-first, 3-layer)

```
lib/
  main.dart
  core/
    database/            # drift setup, tables, migrations
    notifications/       # notification service wrapper (plugin isolation)
    scheduler/           # RRULE expansion + rolling-window reconciliation
    permissions/         # permission + battery-optimization helpers
    theme/               # colors, typography, light/dark
    router/              # go_router config
    utils/
  features/
    reminders/
      data/
        reminder_dao.dart          # drift queries
        reminder_repository.dart   # source of truth; wraps DAO + scheduler
      domain/
        reminder.dart              # model
        recurrence.dart            # RRULE wrapper + occurrence expansion
        reminder_offset.dart       # at time / N min before / custom
      presentation/
        providers/                 # riverpod providers
        screens/
          home_screen.dart
          add_edit_reminder_screen.dart
          reminder_detail_screen.dart
          empty_state.dart         # part of home
        widgets/
          next_reminder_card.dart  # the hero card
          reminder_row.dart
          recurrence_sheet.dart
    onboarding/
      presentation/
        onboarding_screen.dart
    settings/
      presentation/
        settings_screen.dart
        reliability_panel.dart
```

---

## 5. Data model

Derived directly from the prototype fields (title, notes, date & time, remind-me offset, repeat rule, snooze, enabled toggle).

```
Reminder
  id: String (uuid)
  title: String
  notes: String?
  startDateTime: DateTime          # anchor for the first / one-time occurrence
  timeZone: String                 # IANA tz id, e.g. "Asia/Manila"
  rruleString: String?             # null = one-time; else RRULE, e.g. "FREQ=DAILY"
  offsetMinutes: int               # 0 = at time; 5 = "5 min before"; custom allowed
  snoozeMinutes: int               # default 10
  isEnabled: bool                  # the home-screen toggle; false = keep but don't fire
  createdAt: DateTime
  updatedAt: DateTime
```

**Derived, never stored:** the "next fire time", the recurrence badge label ("Daily"/"Monthly"), and the "next 5 occurrences" — all computed from `startDateTime` + `rruleString` at read time. Storing them would create staleness bugs.

### Recurrence

- Store the rule as a standard RRULE string (`FREQ=DAILY;INTERVAL=1`, `FREQ=WEEKLY;BYDAY=MO,WE,FR`, etc.).
- Expand on demand via the `rrule` package to get the next N occurrences.
- The recurrence bottom sheet maps friendly presets → RRULE under the hood; "Custom" exposes interval + weekday chips.

---

## 6. The scheduling engine (the hard part)

### 6.1 Rolling window, not infinite

iOS caps pending local notifications at **64**. You cannot schedule an infinite recurrence up front. Instead:

- For each enabled reminder, expand its RRULE into the **next N occurrences** (a rolling window, e.g. 30–60 total notifications shared across all reminders, staying safely under 64).
- Each occurrence is scheduled with `zonedSchedule` using `AndroidScheduleMode.exactAllowWhileIdle`, offset by `offsetMinutes`.
- **Re-arm the window** whenever: the app is opened, a reminder is created/edited/deleted/toggled, or an alarm fires. This keeps the queue continuously topped up.

### 6.2 Reconciliation

The scheduler is a pure function of DB state:

```
reconcile():
  1. read all enabled reminders from DB
  2. expand each into its share of the rolling window
  3. cancel all pending OS notifications
  4. re-schedule the computed set
  5. persist a lightweight index of what was scheduled (for debugging / reboot)
```

Because it fully rebuilds, it is idempotent and self-healing — a missed edit or a reboot just triggers another `reconcile()`.

### 6.3 Surviving reboot (Android)

- Register a `BOOT_COMPLETED` receiver. OS alarms do **not** survive reboot on their own — this step is mandatory or every alarm silently dies after a restart.
- **As built (v1):** `flutter_local_notifications`' `ScheduledNotificationBootReceiver` handles `BOOT_COMPLETED` and re-posts the previously scheduled queue. It does not run Dart, so no `reconcile()` happens until the next app open — acceptable because the rolling window is 10 occurrences deep per reminder.

### 6.4 The reliability battle (Android OEMs)

- Android 12+ requires `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`.
- OEMs (Xiaomi, Samsung, Oppo, …) aggressively kill background apps. The **Settings → "Make alarms reliable"** card and the **onboarding "Allow exact alarms"** step exist specifically to prompt the user to disable battery optimization (`ignoreBatteryOptimizations`).
- Treat this as a first-class user flow, not an afterthought — it is the difference between a working app and a broken one.

### 6.5 Snooze & dismiss

- Notification actions ("Snooze" / "Dismiss") are handled by the notification service.
- Snooze schedules a one-off `zonedSchedule` at `now + snoozeMinutes` for that occurrence; it does not alter the RRULE.

---

## 7. Screen ↔ architecture map

| Screen | Reads | Writes / actions |
|---|---|---|
| **Home** (hero card + Today/Upcoming list) | `remindersStreamProvider` (live drift stream); hero = soonest enabled occurrence | Toggle `isEnabled` → repo → `reconcile()`; FAB → Add |
| **Empty state** | same stream, empty | "Add a reminder" → Add |
| **Add / Edit** | reminder by id (edit mode) | Save/delete via repo → `reconcile()`; opens recurrence sheet |
| **Recurrence sheet** (modal) | current rule | Returns an RRULE string to the form (no direct DB write) |
| **Detail** | reminder by id; computes **next 5 occurrences** from RRULE | Edit → Add/Edit; delete → repo → `reconcile()` |
| **Onboarding** | permission status | Requests notification + exact-alarm permissions |
| **Settings** | permission status; defaults | Default offset/snooze; "Allow unrestricted" → battery-optimization request |

The "next 5 occurrences" on Detail doubles as a built-in correctness check — if recurrence logic is wrong, it's visibly wrong here.

---

## 8. State management (riverpod)

| Provider | Type | Responsibility |
|---|---|---|
| `databaseProvider` | singleton | drift instance |
| `reminderRepositoryProvider` | singleton | source of truth; wraps DAO + scheduler |
| `remindersStreamProvider` | stream | live list the Home screen watches |
| `reminderFormControllerProvider` | Notifier | Add/Edit form state; calls repo on save |
| `notificationServiceProvider` | singleton | isolates `flutter_local_notifications` |
| `schedulerProvider` | singleton | `reconcile()` orchestration |
| `permissionStatusProvider` | async | notification / exact-alarm / battery status for Onboarding + Settings |

Screens stay dumb: read providers, render, dispatch intents.

---

## 9. Theming

| Token | Value | Use |
|---|---|---|
| Primary | `#173B44` (deep teal-navy) | Backgrounds, hero card, text on light |
| Accent | `#E0A43B` (warm amber/gold) | CTAs, active toggles, badges, FAB |
| Surface | `#F2EBDA` / off-white | Cards, page background |
| Amber prominence | **Balanced** | Accents, badges, highlights — teal stays the calm base |

Both light and dark mode are required. Typography: sans body with a characterful display face for the large times ("9:00 AM").

---

## 10. Suggested build order

1. **Prove reliability first.** Before any UI, confirm an exact alarm fires when the app is fully closed and the phone idles overnight on a *real* device (ideally Xiaomi/Samsung). If this fails, nothing else matters.
2. drift schema + repository + `remindersStreamProvider`; Home list + Empty state.
3. Add/Edit form → one-time `zonedSchedule`.
4. `reconcile()` + `BOOT_COMPLETED` re-arm + battery-optimization prompt.
5. RRULE recurrence + rolling-window scheduler; recurrence sheet; Detail "next 5".
6. Snooze/dismiss actions.
7. Onboarding permission flow + Settings reliability panel.
8. Polish, dark mode, launcher icon.

---

## 11. Known risks

| Risk | Mitigation |
|---|---|
| OEM battery killers silently drop alarms | Battery-optimization prompt (onboarding + settings); document per-OEM quirks; `android_alarm_manager_plus` re-arm is a future option if field reports demand it |
| iOS 64-notification cap | Rolling-window scheduler, re-armed on app open + alarm fire |
| Alarms die on reboot | `BOOT_COMPLETED` → `reconcile()` |
| DST / timezone drift | `timezone` package + store IANA tz per reminder; `zonedSchedule` |
| Stale derived data | Never store next-fire/occurrences; always compute from RRULE |
