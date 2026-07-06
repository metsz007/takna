---
status: done
verified-by:
  - test/alarm_snooze_test.dart
  - test/alarm_dismiss_test.dart
---

# Plan 14 — Escalating alarm volume ramp (Android)

**Outcome:** When the full-screen alarm starts ringing on Android, the loudness
climbs from a clearly-audible start to full volume over ~45s instead of blasting
at whatever the alarm stream is fixed at — a gentler wake that still reaches
full volume well inside a minute, so it never becomes a quieter, slept-through
alarm. Entirely native; no Dart, DB, or UI changes.

## Prereq

None. Independent of every other plan. **No new dependency** — the ramp uses
only `android.media.Ringtone.setVolume(float)` (already reachable from the
existing `MainActivity.kt` ring code) plus an `android.os.Handler`. Reversible:
the whole feature is a handful of lines and constants in one Kotlin file.

## Why (the change, and the guardrail it must respect)

Today the alarm sound is played natively:
`alarm_screen.dart:46` (`initState`) invokes `_native.invokeMethod('playAlarm')`
on the `takna/settings` MethodChannel, handled at `MainActivity.kt:27`. That
branch loops `RingtoneManager.getDefaultUri(TYPE_ALARM)` on the alarm stream
(`AudioAttributes.USAGE_ALARM`, `isLooping = true`) and calls `play()`. It never
touches per-ring volume, so the alarm comes in at a single fixed loudness for its
whole duration. `dispose()` (`alarm_screen.dart:51`) and `onDestroy()`
(`MainActivity.kt:52`) both call `stopAlarm`, which does `ringtone?.stop()`.

A rising ramp is friendlier to wake to, but the app's core promise is a
**reliable** alarm — the idea-challenge flagged the obvious failure mode: a ramp
that starts near-silent or climbs too slowly is a *quieter* alarm, i.e. one the
user sleeps through. So the ramp has two hard guardrails baked into its
constants:

1. **Start clearly audible**, not from 0 — `RAMP_START = 0.4f` of alarm-stream
   volume, loud enough to wake on its own.
2. **Reach full volume within ~60s regardless** — `RAMP_DURATION_MS = 45_000`,
   ending at `1.0f`. Even if an OEM's volume curve makes 0.4 sound soft, it is at
   full within three-quarters of a minute.

`Ringtone.setVolume(float)` is a per-*Ringtone* scalar (0.0–1.0) applied on top
of the system alarm-stream volume — it does **not** mutate the device's alarm
volume setting, so nothing needs to be saved or restored. It was added in **API
28 (Android 9 / P)**. `MainActivity.kt` currently has no min-SDK guard, and
`android/app/build.gradle.kts:23` sets `minSdk = flutter.minSdkVersion` (the
Flutter default, currently 21 — the builder confirms the resolved value). So the
ramp must be guarded by `Build.VERSION.SDK_INT >= Build.VERSION_CODES.P`; below
28 the alarm rings exactly as it does today (full stream volume, no ramp) — no
regression on old devices, and no attempt to hack per-ring volume via the
system `AudioManager` stream (which would be intrusive and require save/restore).

## Decision: global, always-on, no setting

The ramp is **global and always on** — no per-reminder column, no settings
toggle for v1. Rationale: a gentle start that provably ends at full volume
inside ~45s harms nobody (the loud end-state is identical to today's behavior),
and the whole reason to avoid a setting is that a per-reminder "ramp off" knob
only re-introduces the fixed-blast behavior it replaces. If a user ever wants an
instant-full alarm, that is a future item; state it, don't build it. The curve
constants are the calibration knob instead (see Steps), since hardware/OEM
volume curves vary far more than user preference does.

## Context (files this touches)

- `android/app/src/main/kotlin/com/metsz007/takna/MainActivity.kt` — the *only*
  file that changes. Add ramp constants + a `Handler`, extend the `playAlarm`
  branch to start the ramp, and cancel it in `stopAlarm` and `onDestroy`.
- `android/app/build.gradle.kts:23` — **read only**, to confirm the resolved
  `minSdk` and thus that the API-28 guard is needed (it is, unless minSdk is
  already ≥ 28).
- `lib/features/reminders/presentation/screens/alarm_screen.dart` — **no change**.
  It already calls `playAlarm` / `stopAlarm` with the exact contract the ramp
  hooks into. The point of doing this natively is that Dart stays untouched.

No Dart, no drift schema, no iOS change (iOS uses the notification/critical-sound
path, not this native player — out of scope, see below).

## Steps

1. **Add ramp constants at the top of `MainActivity.kt`** (the calibration knob —
   keep them named and together, above the class):
   ```kotlin
   // ponytail: THE calibration knob. Hardware/OEM alarm-stream volume curves
   // vary — a value that's a gentle wake on a Pixel can be too soft on some
   // skins. Tune these three, nothing else. Guardrails that must hold:
   // START must stay clearly audible (never near 0) and the ramp must reach
   // full (1.0) within ~60s — a too-quiet/too-slow ramp is a slept-through
   // alarm, which attacks the app's core promise.
   private const val RAMP_START = 0.4f        // initial per-ring volume (0..1)
   private const val RAMP_END = 1.0f          // full volume
   private const val RAMP_DURATION_MS = 45_000L
   private const val RAMP_STEP_MS = 3_000L    // step cadence (~15 steps)
   ```

2. **Add a Handler field** on `MainActivity` (alongside `private var ringtone`):
   ```kotlin
   private val rampHandler = Handler(Looper.getMainLooper())
   ```
   Import `android.os.Handler`, `android.os.Looper`, `android.os.Build`.

3. **Start the ramp in the `playAlarm` branch.** Immediately after the existing
   `play()` (inside/after the `.apply { ... }`), and only when supported:
   ```kotlin
   rampHandler.removeCallbacksAndMessages(null) // clear any prior ramp
   if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
       val r = ringtone ?: return@apply /* or guard around the block */
       r.volume = RAMP_START
       val steps = (RAMP_DURATION_MS / RAMP_STEP_MS).toInt()
       for (i in 1..steps) {
           rampHandler.postDelayed({
               // linear climb RAMP_START -> RAMP_END across the window
               val v = RAMP_START + (RAMP_END - RAMP_START) * i / steps
               ringtone?.let { if (it.isPlaying) it.volume = v.coerceAtMost(RAMP_END) }
           }, RAMP_STEP_MS * i)
       }
   }
   ```
   Notes for the builder: `Ringtone.volume` (the Kotlin property for
   `setVolume`) is API 28+, hence the guard. `ringtone?.let { if (it.isPlaying) }`
   inside each posted step means a step that fires after `stopAlarm` is a no-op
   even in the race where a callback is already queued. Keep the existing
   `ringtone?.stop()` at the top of `playAlarm` — a restart re-arms cleanly
   because step 1's `removeCallbacksAndMessages(null)` clears the old ramp first.

4. **Cancel the ramp in `stopAlarm`.** Add one line before/after the existing
   `ringtone?.stop()`:
   ```kotlin
   rampHandler.removeCallbacksAndMessages(null)
   ```
   Same one line in `onDestroy()` before `ringtone?.stop()`, so a destroyed
   activity leaves no pending callbacks. (Handler is bound to the main looper,
   which is gone with the activity, but cancelling is correct and cheap.)

5. **Confirm minSdk.** Read the resolved `flutter.minSdkVersion`
   (`flutter pub deps` / the generated `local.properties` / a debug build log).
   If it is already ≥ 28 the `Build.VERSION.SDK_INT` guard is harmless dead-code
   but keep it anyway (defensive, zero cost) — do **not** raise minSdk for this
   feature.

## Done when

- `flutter analyze` is clean and a **debug Android build compiles**
  (`flutter build apk --debug` or `flutter run`) — the change is Kotlin, so a
  successful compile is the machine-checkable proof the native code is valid.
- Existing alarm-screen tests still pass unchanged
  (`test/alarm_snooze_test.dart`, `test/alarm_dismiss_test.dart`): they mock the
  `takna/settings` channel and drive `AlarmScreen`, proving the `playAlarm` /
  `stopAlarm` Dart contract the ramp hooks into is untouched. **No new Dart test**
  — the ramp lives entirely in Kotlin with no Dart-observable surface, and there
  is no Kotlin unit-test harness in this project, so honestly everything specific
  to the ramp is device-manual below. (Adding a Dart test here would only assert
  behavior that didn't change.)
- [x] Manual (Android device/emulator, API ≥ 28): trigger an alarm → the ring
  starts clearly audible (not silent) and audibly gets louder over the first
  ~45s, reaching full volume by then.
- [x] Manual (Android, API ≥ 28): press **Dismiss** (and separately **Snooze**)
  mid-ramp → sound stops immediately and does **not** get louder afterwards
  (no stray ramp callback resurrects/raises volume). Then trigger another alarm
  → it ramps from the start again (clean re-arm).
- [x] Manual (Android, API ≥ 28): the device's system alarm-volume setting is
  **unchanged** after an alarm rings and dismisses (per-ring `setVolume` only,
  nothing mutated/left on the stream).
- [x] Manual (Android, API < 28 device/emulator, if one is available): alarm
  still rings at full volume with no crash — the guard degrades gracefully.
- [x] Manual (reboot survival unaffected): schedule an alarm, reboot, let it
  fire → it rings and ramps normally (the ramp is purely in-process at ring
  time; it does not touch scheduling/boot).

## Out of scope

- **iOS.** iOS alarms don't use this native player; per-notification/critical
  sound volume there is a separate mechanism (and largely OS-controlled). Not
  touched.
- **Any setting or per-reminder control** for the ramp (on/off, curve, duration).
  Global always-on is the decision above. // ponytail: if a user ever needs an
  instant-full alarm, the upgrade path is a single global bool pref read in
  `playAlarm` — add it only when asked.
- **Vibration ramp / haptics escalation.** Sound only.
- **Non-linear curves (ease-in, logarithmic-to-perceived-loudness).** The linear
  step is the lazy version; the constants are the tuning knob if a real device
  shows the linear climb feels wrong. Don't build a curve engine.
- **Changing which sound plays** — that's plan 11 (per-reminder sound); this plan
  only ramps whatever sound `playAlarm` already chose, and composes cleanly with
  plan 11 (the ramp wraps the resolved ringtone regardless of its URI).
