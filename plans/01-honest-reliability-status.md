---
status: done
verified-by:
  - test/reliability_status_test.dart
---

# Plan 01 — Honest reliability status

**Outcome:** The detail-screen banner and home hero stop claiming alarms are
reliable when notification or exact-alarm permission is missing; instead they
warn that alarms "may not ring" and route the user to Settings to fix it.

## Prereq

None. First plan. Scope was narrowed by the idea-challenge in
`docs/audits/2026-07-06.md` (finding #1 + its "Challenged" section) — do not
widen it. In particular: battery-optimization stays out of the warning logic
(unreliable across OEMs) and remains settings-only as today.

## Context (files this touches)

- `lib/features/reminders/presentation/providers.dart` — riverpod provider map.
  Add the reliability provider here (home + detail already import this file).
- `lib/features/reminders/presentation/screens/reminder_detail_screen.dart:175-191`
  — the hardcoded green "Reliable alarms are on…" banner.
- `lib/features/reminders/presentation/screens/home_screen.dart` — `_HomeList`
  (builds the list, already a `ConsumerWidget`) and `_HeroCard:234-247` (the
  footer line "Alarm set · notifies even when your phone is locked").
- `lib/main.dart` — `TaknaApp` (currently `ConsumerWidget`); needs an
  app-resume hook to refresh the provider.
- Existing pattern to copy for reading permissions:
  `lib/features/settings/presentation/settings_screen.dart:31-32`
  (`Permission.notification.isGranted`, `Permission.scheduleExactAlarm.isGranted`).
- Theming: `TkCard` and tokens (`t.okSoft`/`t.ok` green, `t.accentSoft`/
  `t.accentInk` amber) from `lib/core/theme/{theme,widgets}.dart`. There is no
  dedicated "warning" token — reuse the amber accent tokens for the warning
  state (matches the design's attention color).

## Steps

1. **Reliability provider** (in `providers.dart`). Add a tiny value type and an
   overridable `FutureProvider`:
   ```dart
   class ReliabilityStatus {
     const ReliabilityStatus(this.notifications, this.exactAlarm);
     final bool notifications, exactAlarm;
     bool get reliable => notifications && exactAlarm;
   }

   final reliabilityProvider = FutureProvider<ReliabilityStatus>((ref) async =>
       ReliabilityStatus(
         await Permission.notification.isGranted,
         await Permission.scheduleExactAlarm.isGranted));
   ```
   `import 'package:permission_handler/permission_handler.dart';`. A plain
   `FutureProvider` is chosen deliberately so tests override it with
   `reliabilityProvider.overrideWith((ref) async => const ReliabilityStatus(...))`
   and never touch the platform channel; refresh is just `ref.invalidate`.
   Only the two *hard* permissions — do NOT read
   `Permission.ignoreBatteryOptimizations` here (challenged out).

2. **Refresh on app resume.** Convert `TaknaApp` (`lib/main.dart`) to a
   `ConsumerStatefulWidget` and, in `initState`, create an
   `AppLifecycleListener(onResume: () => ref.invalidate(reliabilityProvider))`
   (dispose it in `dispose`). One app-level listener covers both home and
   detail — the lazy single place both screens benefit from.
   `// ponytail:` note that this is the only resume hook the reliability UI
   needs (settings' own `_load` on resume is a separate audit item, not this
   plan).

3. **Shared banner widget** — new file
   `lib/features/reminders/presentation/widgets/reliability_banner.dart`.
   A `ConsumerWidget` `ReliabilityBanner({bool showWhenReliable = false})` that
   `ref.watch(reliabilityProvider)` and renders:
   - unknown/loading (`valueOrNull == null`) → treat as reliable (return the
     reliable branch or `SizedBox.shrink()`) so no warning flashes before the
     async read resolves;
   - `reliable == true` → if `showWhenReliable`, the green `t.okSoft` row with
     `Icons.verified_user_outlined` and non-absolute copy, e.g.
     *"Notifications and exact alarms are on — Takna is set to ring on time."*;
     otherwise `SizedBox.shrink()`;
   - `reliable == false` → an amber warning row (`t.accentSoft` bg,
     `Icons.warning_amber_rounded`, `t.accentInk` text), tappable
     (`GestureDetector` → `context.go('/settings')`) with copy that avoids
     absolute claims, e.g. *"Notifications or exact alarms are off — your
     alarms may not ring. Tap to fix."*
   Reusing one widget for both screens' warning is fewer lines than two copies;
   `showWhenReliable` is the only real difference (detail shows the positive
   state, home does not).

4. **Detail screen.** Replace the hardcoded banner block
   (`reminder_detail_screen.dart:175-191`) with
   `const ReliabilityBanner(showWhenReliable: true)` inside the same
   `Padding(fromLTRB(20,16,20,0))`. Remove the old unconditional green text.

5. **Home screen.**
   - In `_HomeList.build`, after `_Header()` in the `ListView` children, insert
     a padded `ReliabilityBanner()` (defaults to `showWhenReliable: false`, so
     it renders only when a permission is missing) wrapped in a `TkCard` look —
     the one warning card required by the challenge. Compute
     `reliable = ref.watch(reliabilityProvider).valueOrNull?.reliable ?? true`
     in `_HomeList` and pass it into `_HeroCard`.
   - `_HeroCard`: add a `final bool reliable;` constructor field. In the footer
     row (`home_screen.dart:234-247`), when `reliable` show the current
     "Alarm set · notifies even when your phone is locked"; when `!reliable`
     show a non-claiming line, e.g. *"Alarm set · may not ring until you fix
     permissions"* (and/or drop the reassuring dot). It must NOT claim
     "notifies even when your phone is locked" while permissions are missing.

6. **No new dependency, no plugin call outside the provider.** `permission_handler`
   is already in `pubspec.yaml`; the UI reads permission state only through
   `reliabilityProvider` (respects CLAUDE.md: UI → provider layer, never the
   plugin directly).

## Done when

- `test/reliability_status_test.dart` (new) passes and covers, via
  `ProviderScope` overrides of `reliabilityProvider`, pumping `ReliabilityBanner`
  wrapped in a themed `MaterialApp`:
  - `ReliabilityStatus(true, true)` + `showWhenReliable: true` → the green
    "set to ring on time" copy is present; the "may not ring" warning is absent.
  - `ReliabilityStatus(false, true)` (notifications denied) → the "may not ring"
    warning text is present; the green copy is absent.
  - `ReliabilityStatus(true, false)` (exact alarms denied) → warning present.
  - `showWhenReliable: false` + `ReliabilityStatus(true, true)` → renders
    nothing (`find.byType(GestureDetector)`/warning text both absent).
- `flutter analyze` is clean; existing `test/recurrence_test.dart` still passes.
- The provider reads only `Permission.notification` and
  `Permission.scheduleExactAlarm` — no battery-optimization in the warning path.
- [ ] Manual (Android 13 emulator, platform-dependent): deny notifications,
  create a reminder → home shows the warning card and the hero footer no longer
  claims "notifies even when your phone is locked"; detail shows the amber
  warning. Tapping either lands on Settings. Grant the permission in system
  settings, return to the app → on resume both revert to the green/reliable
  state without a manual reload.

## Out of scope

- Battery-optimization in the warning logic (challenged out; stays a
  settings-only affordance as today).
- Any new "home banner subsystem", dismissible/snoozable banners, or
  onboarding changes — one card + one detail banner + one footer tweak only.
- Settings screen's own resume refresh (audit finding #5 — separate tiny item).
- The uncommitted working-tree changes in
  `lib/core/{database,notifications,scheduler}` and `add_edit_reminder_screen.dart`
  — this plan does not touch those files.
- Verifying that alarms *actually* fire (that is the reliability-spike work);
  this plan only makes the displayed status honest.
