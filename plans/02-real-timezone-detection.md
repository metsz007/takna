---
status: in-progress
verified-by:
  - test/timezone_test.dart
---

# Plan 02 — Real timezone detection (flutter_timezone)

**Outcome:** `tz.local` is set from the device's real IANA zone id (via the
`flutter_timezone` plugin) instead of the first zone that happens to match the
current UTC offset, so `zonedSchedule`'s TZDateTime conversions no longer drift
by an hour after a DST transition.

## Prereq

None (independent of plan 01). Adds a new runtime dependency
(`flutter_timezone`); the approval gate challenged this on 2026-07-07 and
cleared it to proceed autonomously (reversible one-line dep, the package the
code's own comment named, already justified by re-audit finding 4 in
`docs/audits/2026-07-06.md`). Mitigation for the one machine-checkable risk:
verification includes a debug Android build to catch plugin Gradle breakage.

## Why (the bug)

`notification_service.dart:136` `_localTimeZoneName()` scans
`tz.timeZoneDatabase.locations` for the first zone whose *current* offset equals
`DateTime.now().timeZoneOffset`, else UTC. Two zones can share an offset today
but have different DST rules (e.g. `America/New_York` vs `America/Bogota`, or
`Europe/Paris` vs zones with no DST). If the scan latches onto a sibling with
different DST rules, every `tz.TZDateTime.from(when, tz.local)`
(`schedule()`, line 191) is computed against the wrong rule set — after the next
DST boundary the scheduled instant is off by an hour. That is a direct hit on
the app's core promise (reliable exact alarms). The original `// ponytail:`
comment already names the correct fix: the `flutter_timezone` package, which
returns the device's real IANA zone id.

## Context (files this touches)

- `lib/core/notifications/notification_service.dart` — `_localTimeZoneName()`
  (136-151) and its `// ponytail:` comment; `init()` (113) already calls it and
  sets `tz.setLocalLocation`. This file already exposes top-level public helpers
  (`parsePayload`, `handleNotificationAction`) that tests import directly — the
  new seam follows that same pattern.
- `pubspec.yaml` — dependencies block (37-48).
- `test/timezone_test.dart` — new; sits alongside `test/recurrence_test.dart`,
  `test/scheduler_test.dart`, `test/reliability_status_test.dart`.

Only these three files change. Scope stays narrow — no scheduler, DB, or UI
changes.

## Steps

1. **Add the dependency.** In `pubspec.yaml` add `flutter_timezone` pinned to
   its current stable major (a caret range on that major, matching how every
   other dep here is pinned, e.g. `flutter_timezone: ^<current-major>.x.y`).
   The builder runs `flutter pub add flutter_timezone` (or edits + `pub get`);
   **do not run pub add now** — pinning is the whole reason this waits for user
   approval. flutter_timezone is a normal Flutter plugin (auto-registered); it
   needs **no** Android manifest or iOS Info.plist changes for reading the zone.

2. **Extract a pure resolver (the test seam).** Add a top-level public function
   in `notification_service.dart`:
   ```dart
   /// Resolves the device-reported IANA id [candidate] to a tz-database
   /// location name. Trusts a known id verbatim; if it's null or not in the
   /// database, falls back to the current-offset scan, then UTC. Pure — the
   /// platform-channel call is the caller's job. Assumes tz data is already
   /// initialized (init() does this before calling).
   String resolveTimeZoneName(String? candidate) {
     if (candidate != null &&
         tz.timeZoneDatabase.locations.containsKey(candidate)) {
       return candidate;
     }
     // ponytail: offset scan kept as fallback if the plugin throws or reports
     // an id not in the tz database — a wrong-DST sibling still beats UTC.
     // Ceiling: same DST-ambiguity as before, but only on the rare fallback
     // path now, not every launch.
     try {
       final offset = DateTime.now().timeZoneOffset;
       final now = DateTime.now().millisecondsSinceEpoch;
       for (final name in tz.timeZoneDatabase.locations.keys) {
         if (tz.getLocation(name).timeZone(now).offset == offset) return name;
       }
     } catch (_) {}
     return 'UTC';
   }
   ```
   This is a straight move of the existing scan body plus one membership check
   in front — smallest diff that makes the logic testable without the channel.

3. **Call the plugin in `_localTimeZoneName()`.** Replace its body with:
   ```dart
   Future<String> _localTimeZoneName() async {
     String? id;
     try {
       id = await FlutterTimezone.getLocalTimezone(); // see note on return type
     } catch (_) {}
     return resolveTimeZoneName(id);
   }
   ```
   `import 'package:flutter_timezone/flutter_timezone.dart';`.
   **Return-type note for the builder:** flutter_timezone changed this API
   across majors — `getLocalTimezone()` returns a `String` in v3.x but a
   `TimezoneInfo` (read the id via `.identifier`) in v4.x+. Check the pinned
   version and take the IANA id string accordingly (e.g.
   `(await FlutterTimezone.getLocalTimezone()).identifier` on v4+). Feed that
   string into `resolveTimeZoneName`.

4. **Remove the stale ponytail comment.** Delete the old
   `// ponytail: DateTime.now().timeZoneName ...` block (137-139) — the fix it
   pointed to is now done. The only remaining `// ponytail:` note is the new one
   on the fallback in step 2.

## Done when

- `test/timezone_test.dart` (new) passes. It calls
  `tzdata.initializeTimeZones()` in `setUpAll`, then asserts on the pure
  `resolveTimeZoneName` (no platform channel touched):
  - **Valid id accepted verbatim:** `resolveTimeZoneName('Pacific/Kiritimati')`
    returns exactly `'Pacific/Kiritimati'`. (This id's offset won't match the
    test machine, so it also proves the id is trusted directly, not re-derived
    by the offset scan.)
  - **Another valid id:** `resolveTimeZoneName('America/New_York')` returns it
    unchanged.
  - **Fallback path (unknown id):** `resolveTimeZoneName('Not/AZone')` returns a
    name that IS in `tz.timeZoneDatabase.locations` and whose current offset
    equals `DateTime.now().timeZoneOffset` (or `'UTC'` if the scan finds none) —
    i.e. it never throws and never returns the bogus id.
  - **Fallback path (null):** `resolveTimeZoneName(null)` behaves identically to
    the unknown-id case (valid db name or `'UTC'`).
- `flutter analyze` is clean; existing suites (`recurrence`, `scheduler`,
  `reliability_status`) still pass.
- `flutter_timezone` appears in `pubspec.yaml` pinned to one major.
- The plugin call is wrapped in try/catch so a channel failure degrades to the
  offset scan, never crashes `init()`.
- [ ] Manual (physical/emulated device in a DST-observing zone whose offset is
  shared by a non-DST sibling — e.g. set the device to `America/New_York`): add
  a log or assert that `tz.local.name` after `init()` equals the device's real
  IANA id (`America/New_York`), not an offset-matched sibling. Confirms the
  plugin id is what's used, not the scan.

## Reconcile implications

None. `init()` sets `tz.local` once at startup, before any scheduling; nothing
derived is persisted (CLAUDE.md rule), and `reconcile()` recomputes all
occurrences from `startDateTime` + RRULE on launch, so the corrected zone takes
effect the next time reconcile runs — no migration, no stored-data fix-up.

## Out of scope

- Reacting to a timezone change *while the app is running* (device travels
  across zones mid-session). `init()` reads it once at startup; a live
  re-`setLocalLocation` on resume is a separate item — not this plan.
- Any change to scheduler, DB, or UI code.
- iOS/Android native config beyond adding the plugin (none needed for reading
  the zone).
- The uncommitted working-tree changes in `lib/core/**` — this plan touches
  only `notification_service.dart`'s `_localTimeZoneName`/resolver and does not
  depend on the rest.
