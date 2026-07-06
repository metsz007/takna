---
status: planned
verified-by:
  - test/alarm_snooze_test.dart
---

# Plan 05 — Quick-snooze presets on the ring screen

**Outcome:** The full-screen alarm screen offers 5 / 10 / 30-minute snooze
presets so the user can pick a duration in the moment, without editing the
reminder's saved `snoozeMinutes`; the fixed-default button and all other snooze
paths (detail screen, notification-shade action) are unchanged.

## Prereq

None. Plans 01/02 are done, 03/04 are independent. No new dependencies, no DB
change — `snoozeMinutes` already exists on `Reminder` and the "Default snooze"
pref already lives in settings (`settings_screen.dart:91-100`). This is a
UI-only change plus a one-argument tweak to an existing screen method.

## How snooze flows today (traced)

There are two snooze entry points and they already converge on the same effect:

1. **Ring screen** (`alarm_screen.dart:63` `_snooze()`): reads the baked-in
   `p.snoozeMinutes` from the payload, calls
   `repository.snooze(p.reminderId, p.snoozeMinutes)` →
   `db.setSnoozedUntil(id, now + minutes)` + `reconcile()`
   (`reminder_repository.dart:24`), then `context.go('/')`.
2. **Notification-shade action** (foreground or dead-app isolate):
   `handleNotificationAction('snooze', payload, …)`
   (`notification_service.dart:104-107`) does the same
   `db.setSnoozedUntil(reminderId, now + p.snoozeMinutes)` + `reconcile()`.

Both take `snoozeMinutes` from the payload string
(`"$id|$snoozeMinutes|$reminderId|$title"`, built in `schedule()` at
`notification_service.dart:233` from the reminder's saved value). The two paths
are therefore *already consistent*: both persist `snoozedUntil` and reconcile.
This plan only lets the ring screen substitute a chosen duration for the payload
default before calling `repository.snooze` — the effect shape is identical.

The shade-action path is **deliberately left at the fixed default.** Android
notification actions are static (`_actions`, `notification_service.dart:42-45`);
turning one Snooze button into three (5/10/30) would clutter the shade and the
dead-app isolate, for a case the full-screen UI already covers. See Out of scope.

## Context (files this touches)

- `lib/features/reminders/presentation/screens/alarm_screen.dart` — the only
  code change. `_snooze()` (63-70) gets a `minutes` parameter; the button Row
  (118-157) gains a preset chip row.
- `test/alarm_snooze_test.dart` — **new** widget test, patterned on
  `test/detail_snooze_test.dart` (fake repo + `ProviderScope` overrides + a
  `GoRouter`).

No repository, scheduler, DB, notification-service, or settings changes.

## Steps

1. **Parametrize `_snooze`.** Change the signature to
   `Future<void> _snooze(int minutes)` and pass `minutes` (not
   `p.snoozeMinutes`) into `repository.snooze(p.reminderId, minutes)`. The
   `stopAlarm` invoke and `context.go('/')` stay exactly as they are.

2. **Preset list (top-level const).**
   ```dart
   // ponytail: hardcoded presets — wire to a pref only if users ask. The
   // reminder's own default is still the primary big button below.
   const _snoozePresets = [5, 10, 30];
   ```

3. **Primary button uses the default.** The existing big "Snooze ${p.snoozeMinutes} min"
   button (118-133) now calls `_snooze(p.snoozeMinutes)` — unchanged behavior,
   just the explicit argument.

4. **Add a preset chip row** directly above the Snooze/Dismiss `Row` (before
   line 118). Smallest thing that works: a centered `Row` of three tappable
   chips reusing the same translucent-fill styling already on the Snooze button
   (`Color(0x29F2EBDA)`, `BorderRadius.circular`), each labelled `'$m'` (or
   `'$m min'`) and calling `_snooze(m)` on tap. No new widget class — an inline
   `for (final m in _snoozePresets)` mapping to `Expanded`/`GestureDetector`
   chips, matching the existing button idiom. Add a small `SizedBox` gap so it
   doesn't crowd the big buttons.

   // ponytail: presets may duplicate the reminder's default (e.g. default is 5)
   // — harmless overlap, no dedupe. The big button names the saved value; chips
   // are the in-the-moment alternates.

## Done when

- `test/alarm_snooze_test.dart` (new) passes. It pumps `AlarmScreen` inside a
  `ProviderScope` with:
  - a fake `ReminderRepository` overriding `snooze(id, minutes)` to record the
    `(id, minutes)` call (super'd with a throwaway db/scheduler like
    `detail_snooze_test.dart`'s `_FakeRepo`);
  - a fake `NotificationService` overriding `cancel(int)` to a no-op (so
    `initState`'s `cancel` calls don't hit the plugin);
  - `notificationServiceProvider` and `reminderRepositoryProvider` overridden to
    those fakes;
  - a `GoRouter` with `/alarm` and `/` routes;
  - a mock handler on `MethodChannel('takna/settings')` via
    `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler` so
    `playAlarm`/`stopAlarm` no-op.

  Assertions, with payload `'0|5|rid|Take pills'`:
  - **Preset overrides default:** tapping the `10` chip records
    `snooze('rid', 10)` — not 5.
  - **Another preset:** tapping the `30` chip records `snooze('rid', 30)`.
  - **Primary button keeps the saved default:** tapping the big
    "Snooze 5 min" button records `snooze('rid', 5)`.
- `flutter analyze` clean.
- Existing suites still pass — in particular `test/notification_action_test.dart`
  (shade-action snooze/dismiss) and `test/detail_snooze_test.dart` are untouched
  and green, proving the other two snooze surfaces didn't regress.
- [ ] Manual (device/emulator): let an alarm ring full-screen; tap a preset
  (e.g. 30) → screen closes to home, and the reminder's hero/detail shows
  `SNOOZED` at now + 30 min (not now + the reminder's saved snooze). Tapping the
  big Snooze button instead snoozes by the saved default.

## Out of scope

- Preset buttons on the **notification-shade** action (static Android action,
  dead-app isolate) — stays on the reminder's saved default. Ring screen covers
  the in-the-moment case.
- Making the preset list user-configurable or reading it from the "Default
  snooze" pref — hardcoded `[5, 10, 30]` until asked.
- Changing the reminder's persisted `snoozeMinutes` (a preset is a one-shot
  choice, never written back to the reminder).
- A custom / free-entry snooze duration picker.
- Any change to `reminder_repository.dart`, the scheduler, or
  `notification_service.dart`.
