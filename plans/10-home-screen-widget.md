---
status: done
verified-by:
  - test/home_widget_test.dart
---

# Plan 10 — Home-screen widget (next upcoming reminder)

**Outcome:** An Android home-screen widget shows the single next upcoming
reminder (title + when), tapping it opens the app, and its contents are pushed
fresh by `reconcile()` — so the widget is a disposable display cache that the
DB+RRULE rebuild every time state changes, never a second source of truth.

## Prereq

None (plans 01–03 independent). Adds one runtime dependency, `home_widget` —
the standard Flutter↔native bridge for Android AppWidget + iOS WidgetKit. It is
the right rung on the ladder: the platform gap it fills (saving key/values the
native widget reads, and triggering a redraw from Dart) is exactly what it does,
and hand-rolling it means re-implementing a `MethodChannel` + a
`SharedPreferences` bridge + launch-intent plumbing that this package already
maintains. We still write the native provider + layout XML by hand either way
(no package generates those); `home_widget` only removes the glue. **Verdict:
use `home_widget`, not hand-rolled platform code.**

## Scope: Android only for v1

`home_widget` supports iOS too, but a WidgetKit widget requires a **separate
Swift extension target** added in Xcode, an App Group entitlement shared between
the app and the extension, and a SwiftUI view — a self-contained native chunk
with signing implications. // ponytail: iOS WidgetKit is a separate plan; this
plan ships the Android AppWidget only and guards the Dart push with
`Platform.isAndroid` so it's a no-op elsewhere.

## Design: how this squares with "never store derived data"

CLAUDE.md forbids storing derived data (next-fire time, occurrence lists) — but
that rule is about the **DB**, the single source of truth, which stays clean:
no new columns, no persisted next-fire. The widget snapshot is derived data
living **outside** the DB, in `home_widget`'s own `SharedPreferences` store and
the widget's on-screen buffer — the exact same category as the OS notification
queue, which the scheduler already rebuilds from scratch on every `reconcile()`.
The widget is disposable and self-healing for the identical reason the
notification queue is: it is recomputed from `startDateTime` + RRULE (via
`effectiveNextFire`) at push time and thrown away, never read back as truth.

## Data flow (push at reconcile)

`Scheduler._reconcile()` is the one choke point through which every state change
already flows, and it holds the enabled-reminders list plus a `_db` — with **no
Flutter/riverpod dependency**, so it works in the background isolate too
(`notificationBackgroundHandler` builds its own `Scheduler`). So the push hangs
off the tail of `_reconcile()`:

1. Compute the earliest upcoming enabled reminder with `effectiveNextFire`
   (same selection the home hero uses — `home_screen.dart:131-137`).
2. Save `title` + `when` via `HomeWidget.saveWidgetData`, then
   `HomeWidget.updateWidget(...)` to redraw.
3. The native `ReminderWidgetProvider` reads those keys and paints the two
   `TextView`s; the root view's `PendingIntent` opens the app.

### Does the widget update after an alarm fires? (the "verify" ask)

`reconcile()` runs on: app launch (`main.dart:33`), every reminder
create/edit/delete/toggle (repository → scheduler), snooze/dismiss action taps
**in both the foreground and the dead-app background isolate**
(`handleNotificationAction` → `Scheduler(db, service).reconcile()`,
`notification_service.dart:111`), and import (plan 03). It does **not** run at
the raw OS fire instant with zero user interaction — the OS posts a
pre-scheduled notification and no Dart executes in the background then. The
honest consequences:

- **Alarm-style reminders (the default):** the notification loops
  (`FLAG_INSISTENT`) until the user taps Snooze or Dismiss → background handler
  reconciles → widget refreshes to the next occurrence within a moment of the
  ring ending. Covered.
- **Notification-style reminders:** the user may never tap. The widget can then
  show a just-passed time until the next reconcile (app open / any change). //
  ponytail: acceptable — the widget is a disposable cache, and the stale row is
  a *past* time, not wrong data. Ceiling: a WorkManager background tick that
  re-runs the snapshot at fire time is the upgrade path if users complain;
  AppWidget `updatePeriodMillis` won't help (it re-runs the native `onUpdate`
  against the same stale saved data, not the Dart computation).

## Context (files this touches)

- `lib/core/widget/next_reminder_snapshot.dart` — **new**. Two functions: a
  pure `nextReminderSnapshot(reminders, now)` (the test seam) and an impure
  `pushNextReminder(reminders, now)` that calls `home_widget`.
- `lib/core/scheduler/scheduler.dart` — one call at the end of `_reconcile()`
  (after the schedule loop, line 84), wrapped so it can never throw into
  reconcile.
- `pubspec.yaml` — add `home_widget`.
- `android/app/src/main/AndroidManifest.xml` — one `<receiver>`.
- `android/app/src/main/res/layout/reminder_widget.xml` — **new** layout.
- `android/app/src/main/res/xml/reminder_widget_info.xml` — **new** provider
  metadata.
- `android/app/src/main/kotlin/com/metsz007/takna/ReminderWidgetProvider.kt` —
  **new** (alongside `MainActivity.kt`).
- `test/home_widget_test.dart` — **new**.

## Steps

1. **Dep.** Add `home_widget` to `pubspec.yaml`, caret-pinned to its current
   stable major like every other dep. Builder runs `flutter pub add home_widget`
   (or edits + `pub get`) — **do not run pub add now**; pinning is why this waits
   for approval. No manifest/Info.plist change is needed by the *plugin*; the
   AppWidget `<receiver>` (step 5) is app config, not plugin config.

2. **Pure snapshot — `next_reminder_snapshot.dart`.** Mirror the home hero's
   selection so the app and widget never disagree:
   ```dart
   /// Title + when-label for the earliest upcoming *enabled* reminder, or null
   /// when nothing is upcoming. Pure — no platform channel. Selection matches
   /// the home hero (effectiveNextFire, earliest wins).
   ({String title, String when})? nextReminderSnapshot(
       List<Reminder> reminders, DateTime now) {
     ({Reminder r, DateTime at})? best;
     for (final r in reminders) {
       if (!r.isEnabled) continue;
       final next = effectiveNextFire(r, now);
       if (next != null && (best == null || next.at.isBefore(best!.at))) {
         best = (r: r, at: next.at);
       }
     }
     if (best == null) return null;
     final at = best!.at;
     // Same phrasing as the home list row (home_screen.dart _dayLabel + h:mm a).
     final when = DateUtils.isSameDay(at, now)
         ? DateFormat('h:mm a').format(at)
         : '${_dayLabel(at, now)} · ${DateFormat('h:mm a').format(at)}';
     return (title: best!.r.title, when: when);
   }
   ```
   Copy `_dayLabel` (Today/Tomorrow/`EEE, MMM d`) from `home_screen.dart:22-27`
   — or lift it into this file and have the screen import it if the builder
   prefers one home. Either is fine; don't over-abstract. `intl` (`DateFormat`)
   is already a dep.

3. **Impure push — same file.**
   ```dart
   Future<void> pushNextReminder(List<Reminder> reminders, DateTime now) async {
     if (!Platform.isAndroid) return; // ponytail: iOS widget = separate plan
     final snap = nextReminderSnapshot(reminders, now);
     try {
       await HomeWidget.saveWidgetData('title',
           snap?.title ?? 'No upcoming reminders');
       await HomeWidget.saveWidgetData('when', snap?.when ?? '');
       await HomeWidget.updateWidget(androidName: 'ReminderWidgetProvider');
     } catch (_) {
       // No channel (unit tests) / no widget placed yet → never break reconcile.
     }
   }
   ```
   The `try/catch` matches the codebase's platform-call pattern (see
   `notification_service.dart` `_localTimeZoneName`) and is what keeps
   `scheduler_test.dart` green — the push silently no-ops under `flutter test`
   where the channel is absent.

4. **Wire into reconcile.** At the end of `_reconcile()` in `scheduler.dart`,
   after the `for (final o in occurrences.take(_windowTotal))` loop:
   ```dart
   await pushNextReminder(reminders, now);
   ```
   `reminders` is the post-disable enabled list; `now` is already captured at
   the top. This adds no interleave risk — it touches neither the notification
   plugin nor the `_chain` ordering, and runs inside the serialized
   `_reconcile` body, so the existing "concurrent reconcile() calls are
   serialized" test's cancel/schedule event order is unchanged.

5. **Android manifest receiver.** In `AndroidManifest.xml`, inside
   `<application>`:
   ```xml
   <receiver android:name=".ReminderWidgetProvider" android:exported="true">
       <intent-filter>
           <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
       </intent-filter>
       <meta-data android:name="android.appwidget.provider"
           android:resource="@xml/reminder_widget_info" />
   </receiver>
   ```

6. **Provider metadata — `res/xml/reminder_widget_info.xml`.**
   ```xml
   <appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
       android:minWidth="180dp" android:minHeight="70dp"
       android:updatePeriodMillis="0"
       android:initialLayout="@layout/reminder_widget"
       android:resizeMode="horizontal|vertical"
       android:widgetCategory="home_screen" />
   ```
   `updatePeriodMillis="0"` — we push on reconcile; no OS polling. // ponytail.

7. **Layout — `res/layout/reminder_widget.xml`.** Dead simple: a vertical
   `LinearLayout` root `@+id/widget_root` (give it a solid/rounded background
   drawable or a plain color so it's tappable and legible) holding two
   `TextView`s — `@+id/widget_title` (single line, bold, `ellipsize=end`) and
   `@+id/widget_when` (smaller, muted). No icons, no lists — title + time only.

8. **Kotlin provider — `ReminderWidgetProvider.kt`** (package
   `com.metsz007.takna`, next to `MainActivity.kt`), extending `home_widget`'s
   base so `onUpdate` is handed the saved data:
   ```kotlin
   package com.metsz007.takna

   import android.appwidget.AppWidgetManager
   import android.content.Context
   import android.content.SharedPreferences
   import android.widget.RemoteViews
   import es.antonborri.home_widget.HomeWidgetLaunchIntent
   import es.antonborri.home_widget.HomeWidgetProvider

   class ReminderWidgetProvider : HomeWidgetProvider() {
       override fun onUpdate(
           context: Context,
           appWidgetManager: AppWidgetManager,
           appWidgetIds: IntArray,
           widgetData: SharedPreferences,
       ) {
           for (id in appWidgetIds) {
               val views = RemoteViews(context.packageName, R.layout.reminder_widget).apply {
                   setTextViewText(R.id.widget_title,
                       widgetData.getString("title", "No upcoming reminders"))
                   setTextViewText(R.id.widget_when, widgetData.getString("when", ""))
                   setOnClickPendingIntent(R.id.widget_root,
                       HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
               }
               appWidgetManager.updateAppWidget(id, views)
           }
       }
   }
   ```
   Confirm the import package matches the pinned `home_widget` version (it is
   `es.antonborri.home_widget` at time of writing); `getActivity` is the
   package's launch-intent helper. Tap opens the app plainly — // ponytail: no
   deep-link routing to a specific reminder; "opens app" is the whole ask.

## Done when

- `test/home_widget_test.dart` (new) passes — pure, no platform channels
  (guard the `DateFormat`/`DateUtils` uses run fine under `flutter_test`):
  - **Picks the earliest enabled:** given three enabled reminders at different
    future times, `nextReminderSnapshot` returns the earliest one's title and a
    `when` containing its `h:mm`.
  - **Skips disabled & past:** a disabled reminder and a past one-time reminder
    are ignored even if "earlier".
  - **Snooze wins:** a reminder whose `snoozedUntil` is sooner than any other's
    occurrence is chosen (exercises `effectiveNextFire`'s snooze branch),
    confirming the widget agrees with the hero card.
  - **Today vs future label:** a same-day reminder's `when` is just `h:mm a`
    (no day prefix); a reminder 3 days out includes the day label
    (`Today`/`Tomorrow`/`EEE, MMM d · h:mm a`).
  - **Empty state:** an empty list (and an all-disabled list) returns `null`.
- `flutter analyze` clean; existing suites (esp. `scheduler_test`) still pass
  unchanged — the reconcile push no-ops under test via its `try/catch`.
- `home_widget` appears in `pubspec.yaml` pinned to one major.
- [x] Manual (device/emulator): long-press home screen → **Widgets** → Takna →
  place the widget. It shows the next reminder's title + time (or "No upcoming
  reminders" when the list is empty).
- [x] Manual: add a reminder sooner than the current one → widget updates to the
  new one within a moment (reconcile-on-write pushes it). Delete/disable it →
  widget falls back to the next, or the empty state.
- [x] Manual: tap the widget → the app opens.
- [x] Manual (the fire-path claim): set an **alarm-style** reminder ~1 min out,
  lock the phone, let it ring, tap **Dismiss** → widget advances to the next
  occurrence (for a recurring one) or shows the empty state (one-time). Confirms
  the background-isolate reconcile pushes to the widget.
- [x] Manual: reboot the device with the widget placed → widget still renders
  its last snapshot (native `onUpdate` reads persisted `SharedPreferences`);
  opening the app re-pushes a fresh one.

## Out of scope

- **iOS / WidgetKit** — separate plan (needs a Swift extension target + App
  Group entitlement).
- Deep-linking the tap to a specific reminder's detail page — plain app launch
  only.
- Any richer widget (multiple reminders, a list, a mini calendar, quick actions
  like snooze-from-widget, theming to match the wave background).
- A WorkManager/background tick to refresh the widget at the exact fire instant
  for notification-style reminders that the user never taps — noted as the
  ceiling above; add only if it bites.
- Storing anything derived in the DB — the snapshot lives only in
  `home_widget`'s store, rebuilt by reconcile.
