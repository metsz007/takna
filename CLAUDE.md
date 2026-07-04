# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Takna is a local-only Flutter scheduling/reminder app (Bisaya: *time*) whose core promise is **reliable exact alarms**. **No Flutter code exists yet** — this repo contains only:

- `docs/ARCHITECTURE.md` — the authoritative v1 blueprint. Read it before any implementation work; it defines the tech stack, data model, folder structure, provider map, theming tokens, and build order.
- `design/Takna.dc.html` — the finalized UI prototype (Home, Add/Edit, Detail, Settings, Onboarding, Empty).

When scaffolding begins, follow the feature-first `lib/` layout and the build order in section 10 of the architecture doc (reliability spike first, before any UI).

## Non-negotiable architecture rules (from docs/ARCHITECTURE.md)

- **The database (drift/SQLite) is the single source of truth.** OS notifications are disposable; the scheduler's `reconcile()` fully rebuilds them from DB state (idempotent, self-healing).
- **One-directional flow:** UI → Repository → DB write → scheduler reconciles. UI never touches the DB or notification plugin directly.
- **Never store derived data** (next fire time, occurrence lists, badge labels) — compute from `startDateTime` + RRULE at read time.
- **Recurrence is standard iCalendar RRULE** via the `rrule` package — never invent a custom format.
- **Rolling-window scheduling:** iOS caps pending notifications at 64; expand RRULEs into the next N occurrences and re-arm on app open, any reminder change, and alarm fire.
- **Reboot survival is mandatory on Android:** `BOOT_COMPLETED` receiver → `reconcile()`.
- Stack: Flutter, `flutter_local_notifications` (`zonedSchedule` + `exactAllowWhileIdle`), `android_alarm_manager_plus`, drift, riverpod, `timezone`, `rrule`, `permission_handler`, `go_router`.
- Reliability wins every tradeoff — battery-optimization/exact-alarm prompts are a first-class user flow.

## Out of scope for v1

Accounts, cloud sync, calendar import, sharing, month-grid calendar view.
