---
status: done
verified-by:
  - test/reminder_sound_test.dart
  - test/scheduler_test.dart
---

# Plan 11 — Per-reminder alarm sound

**Outcome:** Each reminder can carry its own alert sound (a small bundled set
plus "System default") instead of every alarm sharing the one whole-channel
sound the settings deep-link controls. The sound the user picks is the sound
that rings when the alarm fires.

## Prereq

None (plans 01/02 done, 03 planned). **No new dependency** — this uses
mechanisms already in the app: `DarwinNotificationDetails(sound:)` on iOS
(ships with `flutter_local_notifications`), the existing `takna/settings`
`playAlarm` MethodChannel on Android, and drift for the new column. The only
*additions* are a few short bundled sound files (assets, not a package). The
builder sources 2–3 royalty-free alarm tones; that sourcing is the bulk of the
manual work here, not code.

## Investigation — where the sound actually comes from (and why the channel
approach is mostly avoidable)

The task framed this around "a channel per sound" (Android bakes a channel's
sound at creation and it's immutable on API 26+, so N sounds → N channels).
Reading the code shows that balloon is **not** needed for the app's core mode:

- **Android, alarm mode (`isAlarm == true`, the default):** the ringing sound
  you hear is **not** the channel sound. The notification's `fullScreenIntent`
  launches `AlarmScreen`, whose `initState` calls the native
  `playAlarm` MethodChannel (`MainActivity.kt:27`), which loops
  `RingtoneManager.getDefaultUri(TYPE_ALARM)` on the alarm stream
  (`alarm_screen.dart:40`). The `takna_alarms` channel's own sound is only a
  brief pre-roll / a safety net if the full-screen UI can't launch. So
  per-reminder alarm sound on Android = **pass the chosen sound into
  `playAlarm`**. Zero extra channels.
- **iOS (both modes):** per-notification sound is trivial —
  `DarwinNotificationDetails(sound: '<file>.caf')` set at schedule time.
- **Android, notification mode (`isAlarm == false`):** no `AlarmScreen`, no
  native player — the sound is purely the `takna_notifications` channel's.
  This is the *only* place a custom per-reminder sound would need
  channel-per-sound, and it's the non-core, secondary mode.

So the honest, bounded scope:

| | Android | iOS |
|---|---|---|
| **Alarm mode** (default/core) | ✅ per-reminder via native `playAlarm(soundKey)` | ✅ per-reminder via `DarwinNotificationDetails.sound` |
| **Notification mode** | ❌ keeps default channel sound (see ponytail note) | ✅ per-reminder via `DarwinNotificationDetails.sound` |

The one gap — Android notification-mode custom sound — is deferred, not faked.
Its upgrade path (channel-per-sound) is named in a `ponytail:` note. This gap
costs nothing to the app's promise: the reliable-alarm story is entirely the
alarm mode, which is fully covered on both platforms.

## Design decisions

- **`soundKey` nullable text column.** `null` = "System default" (today's
  behavior — unchanged fallback). A non-null key names one catalog entry.
  Nullable + default null means the migration needs no data backfill and every
  existing reminder keeps ringing exactly as it does now.
- **One shared catalog, one pure resolver.** `lib/core/notifications/sounds.dart`
  holds a `const` list of `(key, label, iosFile)` plus pure functions
  `iosSoundFor(String? key)` / `soundLabelFor(String? key)`. Unknown or null key
  → default (never throws). Both platforms read the *same* keys so the picker is
  not platform-conditional; the audio files are per-platform (Android raw
  resources, iOS `.caf`) but sourced from the same tones.
- **Android maps the key to a raw resource by name at the native boundary** —
  `resources.getIdentifier(key, "raw", packageName)`, `0` → default alarm URI.
  No hardcoded Kotlin key→resource map to keep in sync; add a `res/raw/<key>`
  file and it's wired.
- **AlarmScreen reads `soundKey` from the DB by `reminderId`** (already in the
  payload) rather than widening the payload string. // ponytail: DB lookup is a
  smaller diff than changing the `id|snooze|reminderId|title` payload format
  (which would churn parsePayload + four payload-literal test files). Ceiling: a
  few-ms DB read before the ring starts; upgrade path if that delay ever matters
  = thread `soundKey` through the payload instead.
- **Start with 2–3 tones.** The catalog is a `const` list — each further sound
  is one entry + one asset file per platform. // ponytail: ship the small set,
  grow the list only if users ask.

## Context (files this touches)

- `lib/core/notifications/sounds.dart` — **new**, the pure seam: catalog +
  `iosSoundFor` / `soundLabelFor`.
- `lib/core/database/database.dart` — add `soundKey` column; bump
  `schemaVersion` 3→4; `onUpgrade` `if (from < 4) addColumn(...)`.
- `lib/core/database/database.g.dart` — regenerated (`dart run build_runner`).
- `lib/core/notifications/notification_service.dart` — `schedule()` gains
  `String? soundKey`; iOS `DarwinNotificationDetails(sound: iosSoundFor(soundKey))`.
  Android `NotificationDetails` unchanged (channel stays the default-sound
  safety net).
- `lib/core/scheduler/scheduler.dart` — pass `o.r.soundKey` into `schedule()`.
- `lib/features/reminders/presentation/screens/alarm_screen.dart` — look up the
  reminder's `soundKey` and pass it to `playAlarm`.
- `android/app/src/main/kotlin/com/metsz007/takna/MainActivity.kt` — `playAlarm`
  reads an optional `sound` arg and resolves it to a raw-resource URI (or
  default).
- `android/app/src/main/res/raw/` — **new**, the bundled Android tones.
- `ios/Runner/` (+ Xcode `Resources`) — the bundled `.caf` tones.
- `lib/features/reminders/presentation/screens/add_edit_reminder_screen.dart` —
  a new "Alarm sound" card (a `TkSegmented`/list) writing `_soundKey`.
- `test/reminder_sound_test.dart` — **new**; `test/scheduler_test.dart` — extend
  the fake to assert `soundKey` is forwarded.

## Steps

1. **Column + migration.** In `database.dart` add
   `TextColumn get soundKey => text().nullable()();`, bump `schemaVersion` to 4,
   and add `if (from < 4) await m.addColumn(reminders, reminders.soundKey);` to
   `onUpgrade`. Regenerate `database.g.dart`. Plan 03's backup goes through the
   generated `toJson`/`fromJson`, so it picks up `soundKey` for free — nothing
   to change there.

2. **Catalog + resolver — `lib/core/notifications/sounds.dart`.**
   ```dart
   /// (key stored in DB, UI label, iOS bundle filename).
   /// key == null is "System default" and is not in this list.
   const soundCatalog = <({String key, String label, String iosFile})>[
     (key: 'chime',  label: 'Chime',  iosFile: 'chime.caf'),
     (key: 'classic', label: 'Classic', iosFile: 'classic.caf'),
     // add one entry + one asset per platform to grow the set.
   ];

   /// iOS sound filename for [key]; null (→ system default) for null or any
   /// key not in the catalog. Pure, never throws — the trust boundary for a
   /// stale/hand-edited soundKey.
   String? iosSoundFor(String? key) {
     for (final s in soundCatalog) {
       if (s.key == key) return s.iosFile;
     }
     return null;
   }

   String soundLabelFor(String? key) {
     for (final s in soundCatalog) {
       if (s.key == key) return s.label;
     }
     return 'System default';
   }
   ```

3. **iOS sound at schedule time.** In `notification_service.dart`, add
   `String? soundKey` to `schedule(...)` and pass
   `sound: iosSoundFor(soundKey)` into `DarwinNotificationDetails` (keep the
   existing `interruptionLevel`). `null` → the framework default sound, i.e. no
   behavior change for existing reminders. Android `NotificationDetails` stays
   as-is.

4. **Scheduler forwards it.** In `scheduler.dart`'s `schedule(...)` call, add
   `soundKey: o.r.soundKey,`.

5. **Android native ring honors the key.** In `MainActivity.kt`, in the
   `playAlarm` branch:
   ```kotlin
   val key = call.argument<String>("sound")
   val uri = if (key != null) {
       val id = resources.getIdentifier(key, "raw", packageName)
       if (id != 0) android.net.Uri.parse("android.resource://$packageName/raw/$key")
       else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
   } else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
   ```
   then `RingtoneManager.getRingtone(this, uri)` (rest unchanged). Drop each
   Android tone in `res/raw/<key>.ogg` (lowercase, no dashes — raw-resource
   naming rules).

6. **AlarmScreen passes the reminder's key.** In `alarm_screen.dart` `initState`,
   replace the bare `_native.invokeMethod('playAlarm')` with a lookup:
   ```dart
   ref.read(reminderRepositoryProvider).getById(p.reminderId).then(
       (r) => _native.invokeMethod('playAlarm', {'sound': r?.soundKey}));
   ```
   A deleted/missing reminder → `sound: null` → default alarm. Keep `stopAlarm`
   unchanged.

7. **Add/Edit UI.** Below the "Alert style" card (`add_edit_reminder_screen.dart`
   ~line 344), add an "Alarm sound" `TkCard` listing `soundCatalog` labels plus
   "System default" (key `null`), writing `_soundKey`. Initialize `_soundKey`
   from the loaded reminder (like `_isAlarm` at ~line 87) and set
   `soundKey: _soundKey` in the `Reminder(...)` built at ~line 124. A
   `TkSegmented<String?>` over `[null, 'chime', 'classic']` with
   `labelOf: soundLabelFor` reuses the existing widget — no new UI component.

8. **Settings row.** Leave the existing "Alarm sound" deep-link
   (`settings_screen.dart:123`, MethodChannel `openAlarmChannelSettings`) — it
   still governs the channel's default/pre-roll sound and Android
   notification-mode sound. // ponytail: relabel to "Default alarm sound" only
   if the per-reminder picker makes the global one read as confusing; not worth
   a change now.

## Done when

- `test/reminder_sound_test.dart` (new) passes — pure, no platform channels:
  - **Catalog integrity:** every `soundCatalog` entry has a non-empty `key`,
    `label`, and `iosFile`; keys are unique.
  - **Resolver, known key:** `iosSoundFor('chime')` returns the catalog's
    `iosFile`; `soundLabelFor('chime')` returns its label.
  - **Resolver, default + unknown:** `iosSoundFor(null)`, `iosSoundFor('bogus')`
    both return `null`; `soundLabelFor(null)` and `soundLabelFor('bogus')` both
    return `'System default'` — never throws (the stale-key trust boundary).
- `test/scheduler_test.dart` extended: `_FakeNotifications.schedule` records the
  `soundKey` arg; a reminder built with `soundKey: 'chime'` results in `'chime'`
  reaching `schedule()`, and one with `soundKey: null` forwards `null`.
- **Migration:** insert a reminder via `RemindersCompanion.insert` without
  `soundKey` → column is `null` (default preserved), and a round-tripped
  `soundKey: Value('chime')` reads back `'chime'` (assert in the sound test or
  alongside `database_default_test`).
- `flutter analyze` clean; all existing suites still pass.
- [ ] Manual (Android device/emulator): create an alarm-mode reminder with
  "Chime" → when it fires, the full-screen alarm rings the chime, not the
  default alarm tone.
- [ ] Manual (Android): a reminder left on "System default" still rings the
  default alarm tone (no regression).
- [ ] Manual (Android): reboot with a scheduled custom-sound alarm pending →
  it still fires and rings the chosen sound (reboot survival unaffected).
- [ ] Manual (iOS device): alarm-mode reminder with "Chime" plays the bundled
  `.caf`; a notification-mode reminder with "Chime" also plays it; "System
  default" plays the default sound.

## Out of scope

- **Android notification-mode custom sound.** Stays the single
  `takna_notifications` channel default. // ponytail: per-sound here needs
  channel-per-sound (immutable channel sound on API 26+); upgrade path is to
  pre-create one channel per catalog entry at `init()` and pick it by `soundKey`
  in `schedule()`. Not worth it for the non-core mode in v1.
- **Per-reminder vibration pattern.** Same channel-immutability constraint on
  Android; the alarm's insistent loop already vibrates. Add later only if asked.
- **User-imported / device-ringtone-picker sounds.** Fixed bundled set only —
  no `RingtoneManager` browse UI, no file import.
- **Per-occurrence or time-of-day sound variation.** One sound per reminder.
- **Migrating the global channel sound into the per-reminder default.** The
  settings deep-link stays; the two coexist.
