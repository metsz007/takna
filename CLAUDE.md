# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Takna is a local-only Flutter scheduling/reminder app (Bisaya: *time*) whose core promise is **reliable exact alarms**. The v1 app is implemented and working: home list + hero card, add/edit with RRULE recurrence, detail, settings, onboarding, a full-screen alarm ring UI, snooze persistence, and alarm-vs-notification alert styles.

- `lib/` — feature-first layout: `core/` (database, notifications, scheduler, router, theme) and `features/` (reminders, settings, onboarding).
- `docs/ARCHITECTURE.md` — the v1 blueprint (data model, provider map, theming tokens). Still authoritative for the rules below; some stack details have drifted (see next section).
- `docs/audits/` — dated audit reports; the newest one lists open findings.
- `plans/` — numbered plan files with frontmatter `status:` (`planned` / `in-progress` / `done` / `needs-rework`) and `verified-by:` test paths.
- `design/Takna.dc.html` — the finalized UI prototype.
- `test/` — run with `flutter test`; `flutter analyze` must stay clean.

## Non-negotiable architecture rules (from docs/ARCHITECTURE.md)

- **The database (drift/SQLite) is the single source of truth.** OS notifications are disposable; the scheduler's `reconcile()` fully rebuilds them from DB state (idempotent, self-healing).
- **One-directional flow:** UI → `ReminderRepository` → DB write → scheduler reconciles. UI never touches the DB or notification plugin directly (permission *state* is read via providers).
- **Never store derived data** (next fire time, occurrence lists, badge labels) — compute from `startDateTime` + RRULE at read time (`nextOccurrences()` in `features/reminders/domain/recurrence.dart`).
- **Recurrence is standard iCalendar RRULE** via the `rrule` package — never invent a custom format.
- **Rolling-window scheduling:** iOS caps pending notifications at 64; `reconcile()` schedules the next 60 occurrences (max 10 per reminder) and re-arms on app open and any reminder change.
- **Reboot survival is mandatory on Android:** handled by `flutter_local_notifications`' `ScheduledNotificationBootReceiver` (manifest `BOOT_COMPLETED`), which re-posts the scheduled queue. `android_alarm_manager_plus` (named in the architecture doc) was deliberately not added.
- Stack: Flutter, `flutter_local_notifications` (`zonedSchedule` + `exactAllowWhileIdle`), drift, riverpod, `timezone`, `rrule`, `permission_handler`, `go_router`, `shared_preferences` (prefs/defaults), `uuid`, `intl`, `google_fonts`.
- Reliability wins every tradeoff — battery-optimization/exact-alarm prompts are a first-class user flow, and the UI must never claim reliability it hasn't verified (see `reliabilityProvider` + `ReliabilityBanner`).

## Out of scope for v1

Accounts, cloud sync, calendar import, sharing, month-grid calendar view.
