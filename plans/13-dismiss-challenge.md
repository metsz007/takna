---
status: planned
verified-by:
  - test/challenge_test.dart
  - test/alarm_challenge_test.dart
---

# Plan 13 — Dismiss challenge on the ring screen

**Outcome:** A reminder can require the user to solve a small math problem
before the full-screen alarm's **Dismiss** button will actually dismiss — so a
half-asleep tap can't silence-and-forget the alarm. The challenge is opt-in
per reminder (a "Dismiss challenge" toggle in add/edit), math-only for v1, and
lives entirely in the ring screen UI; the scheduler, notification service, and
payload format are untouched.

## SAFETY (hard requirement — do not weaken)

**Snooze must always work without solving the challenge.** The challenge gates
**Dismiss only**. The quick-snooze presets and the big "Snooze N min" button
stay fully functional and ungated at all times, so a user who cannot (or will
not) solve the problem can *always* silence the alarm by snoozing. A challenge
that could trap someone with a ringing alarm they can't stop is a defect, not a
feature. This is asserted by a test (see Done when: "snooze works untouched").

## Prereq

None. Plans 01/02 done; 05 (ring-screen snooze presets) is **done** and already
shipped the preset chips + `_snooze(int)` this plan relies on. No new
dependency — a nullable text column (drift, already used), a pure Dart
generator, and inline widgets in an existing screen. Reuses the reminder DB
lookup pattern plan 11 specced for `soundKey` (fetch via
`reminderRepositoryProvider.getById(p.reminderId)` — the reminderId is already
in the payload).

**Schema coordination:** current `schemaVersion` is **6**. This column is the
"next schema version" (7 if nothing lands first). **Plan 11 (per-reminder
sound) also adds a column and is also written against 6** — its step text even
says "3→4", which has drifted from reality. Whichever of 11/13 the builder
implements first is version 7; the second is version 8. **The builder must read
the actual current `schemaVersion` at build time and use the real next number
and matching `if (from < N)` guard — never a hardcoded one from this plan.**

## How dismiss flows today (traced)

`alarm_screen.dart` is the full-screen ring UI, launched by the notification's
`fullScreenIntent`. Its `initState` (lines 31–47) takes over the ring: it
`logFired`, `cancel`s the OS notification (twice, to beat the foreground-watcher
race), and starts the native `playAlarm` loop.

- **Dismiss** (`_dismiss`, lines 56–67): stops the native alarm, `reconcile`s
  the rolling window (re-arm on fire), then `context.go('/')`. Wired to the big
  amber Dismiss button at line 164 (`onTap: _dismiss`).
- **Snooze** (`_snooze(int minutes)`, lines 69–74): stops the alarm, calls
  `repository.snooze(reminderId, minutes)`, then `context.go('/')`. Wired to the
  three preset chips (line 128, `_snooze(m)`) and the big Snooze button
  (line 148, `_snooze(p.snoozeMinutes)`).

There is **no challenge today** — Dismiss fires immediately on tap.

Once `AlarmScreen` is up, it has already `cancel`ed the shade notification, so
the notification-shade **Dismiss** action is *not reachable while the ring
screen is showing*. The shade action only exists in the brief pre-launch window
(or if the OS renders the full-screen intent as a heads-up instead of launching
the activity). See "The shade Dismiss bypass" below.

## Design decisions

- **`challenge` nullable text column.** `null` = off (today's behavior,
  unchanged for every existing reminder), `'math'` = the math challenge. Text,
  not bool, so a future `'typed'` / `'shake'` needs no second migration — but
  v1 only ever reads/writes `null` or `'math'`. Nullable + default null means
  the migration needs no backfill.
- **The challenge lives only in the ring screen.** Scheduler, notification
  service, and the `id|snooze|reminderId|title` payload are all untouched.
  `AlarmScreen` looks up the reminder's `challenge` via
  `reminderRepositoryProvider.getById(p.reminderId)` (same seam plan 11 uses for
  `soundKey`) — a smaller diff than widening the payload string, which would
  churn `parsePayload` plus four payload-literal test files.
  // ponytail: DB lookup is async, so there's a few-ms window after the screen
  // opens before `_challenge` is known. A groggy human cannot tap Dismiss
  // inside that microtask window in practice. Ceiling: if the race ever
  // matters, thread `challenge` through the payload (same upgrade path plan 11
  // named for soundKey). Not worth it now.
- **Pure, seeded generator in the domain layer.**
  `lib/features/reminders/domain/challenge.dart` (no Flutter imports, like
  `recurrence.dart`) exposes `generateMathChallenge(int seed)` returning a
  record `({String prompt, int answer})`. Deterministic: same seed → same
  problem, so it's unit-testable. Difficulty is **fixed by construction** (not
  randomly easy/hard): a two-digit addition or a small multiplication, operands
  bounded so a sleepy human can still solve it. The screen seeds with
  `DateTime.now().microsecondsSinceEpoch`; a wrong answer regenerates with a
  fresh seed so a wrong value can't be resubmitted.
- **Challenge is an alarm-mode concept.** Notification-mode reminders
  (`isAlarm == false`) never open the ring screen, so a challenge has nowhere to
  appear. The add/edit card is therefore shown **only when Alert style =
  Alarm**; a notification-mode reminder simply never exercises `challenge` (the
  scheduler/notification path doesn't read the column at all).

## Context (files this touches)

- `lib/features/reminders/domain/challenge.dart` — **new**, the pure generator
  (the whole non-UI logic + its unit test target).
- `lib/core/database/database.dart` — add the `challenge` column; bump
  `schemaVersion` to the actual next number; add the matching `if (from < N)
  addColumn` guard. (See Schema coordination above — do **not** hardcode 7.)
- `lib/core/database/database.g.dart` — regenerated (`dart run build_runner
  build`). Plan 03's backup rides the generated `toJson`/`fromJson`, so it picks
  up `challenge` for free — nothing to change there.
- `lib/features/reminders/presentation/screens/alarm_screen.dart` — look up
  `challenge` in `initState`; gate the Dismiss button; add the inline math
  input. The Snooze paths are **not touched**.
- `lib/features/reminders/presentation/screens/add_edit_reminder_screen.dart` —
  a new "Dismiss challenge" `TkCard` (shown only in alarm mode) writing
  `_challenge`; init in `_fillFrom`; set in the `Reminder(...)` built by `_save`.
- `test/challenge_test.dart` — **new**, pure generator tests.
- `test/alarm_challenge_test.dart` — **new** widget test, patterned on
  `test/alarm_dismiss_test.dart` + `test/alarm_snooze_test.dart`.

No scheduler, no `notification_service.dart`, no `reminder_repository.dart`
changes.

## Steps

1. **Column + migration.** In `database.dart` (after `tag`, line 24) add:
   ```dart
   // null = off; 'math' = solve a math problem before Dismiss will dismiss.
   // Text (not bool) so a future 'typed'/'shake' needs no new migration.
   // Ring-screen-only; scheduler/notification path ignores it.
   TextColumn get challenge => text().nullable()();
   ```
   Bump `schemaVersion` to the **actual next number** and add
   `if (from < N) await m.addColumn(reminders, reminders.challenge);` to
   `onUpgrade` (with `N` = that same number). Regenerate `database.g.dart`.

2. **Pure generator — `lib/features/reminders/domain/challenge.dart`.**
   ```dart
   import 'dart:math';

   /// A dismiss challenge: a problem to display and the integer that solves it.
   typedef MathChallenge = ({String prompt, int answer});

   /// Deterministic from [seed] (same seed → same problem, for tests and to
   /// keep a re-render stable). Difficulty is fixed by construction: either a
   /// two-digit addition or a small multiplication — bounded so a half-asleep
   /// user can still solve it, not a brain-teaser.
   MathChallenge generateMathChallenge(int seed) {
     final r = Random(seed);
     if (r.nextBool()) {
       final a = 10 + r.nextInt(90); // 10..99
       final b = 10 + r.nextInt(90);
       return (prompt: '$a + $b', answer: a + b);
     }
     final a = 2 + r.nextInt(11); // 2..12
     final b = 2 + r.nextInt(11);
     return (prompt: '$a × $b', answer: a * b);
   }
   ```
   // ponytail: one fixed difficulty band, math only. No per-reminder
   // difficulty setting, no typed-phrase/shake variants — add a new branch here
   // keyed off the `challenge` string only if users ask.

3. **Ring screen — look up the challenge.** In `alarm_screen.dart`, add
   `String? _challenge;` state. In `initState`, after the existing lookups, fetch
   it (repository seam, like plan 11's soundKey):
   ```dart
   ref.read(reminderRepositoryProvider).getById(p.reminderId).then((r) {
     if (mounted) setState(() => _challenge = r?.challenge);
   });
   ```
   A deleted/missing reminder → `_challenge` stays null → no challenge (fail
   open toward *being able to dismiss*, never toward trapping the user).

4. **Ring screen — gate Dismiss.** Add `MathChallenge? _pending;` state. Change
   the big Dismiss button's `onTap` (line 164) from `_dismiss` to:
   ```dart
   onTap: () {
     if (_challenge != 'math') return _dismiss();
     setState(() => _pending =
         generateMathChallenge(DateTime.now().microsecondsSinceEpoch));
   },
   ```
   `_dismiss()` itself is unchanged (the actual dismissal still runs only after a
   correct answer).

5. **Ring screen — inline math input.** When `_pending != null`, render an
   inline panel **in place of / directly above** the Dismiss button (keep the
   whole Snooze row above it exactly as-is — see SAFETY). Smallest thing that
   works, reusing the existing translucent-chip styling:
   - the prompt `Text('${_pending!.prompt} = ?', key: const Key('challengePrompt'), …)`,
   - a numeric `TextField` (`keyboardType: TextInputType.number`, autofocus),
   - a "Check" button (amber, same style as Dismiss) whose onTap reads the
     field, and:
     ```dart
     if (int.tryParse(text.trim()) == _pending!.answer) {
       _dismiss();
     } else {
       // wrong: keep ringing, clear field, regenerate so the same value can't
       // be resubmitted, show a brief "Try again".
       setState(() => _pending =
           generateMathChallenge(DateTime.now().microsecondsSinceEpoch));
       controller.clear();
     }
     ```
   No new widget class — inline in `build`, matching the existing
   `GestureDetector`/`Container` chip idiom. The Snooze presets and big Snooze
   button remain rendered and active the entire time `_pending != null`.

6. **Add/Edit — the toggle.** Add `String? _challenge;` state. In `_fillFrom`
   (~line 108, beside `_isAlarm = r.isAlarm;`) add `_challenge = r.challenge;`.
   In the `Reminder(...)` in `_save` (~line 140) add `challenge: _challenge,`.
   Add a new `TkCard` **only when `_isAlarm`** (challenge is meaningless without
   the ring screen — place it right after the Alert style card, ~line 380):
   ```dart
   if (_isAlarm) ...[
     const SizedBox(height: 11),
     TkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Row(children: [
         Icon(Icons.calculate_outlined, size: 20, color: t.ic1),
         const SizedBox(width: 13),
         Text('Dismiss challenge', style: body(14, FontWeight.w600, t.ink)),
       ]),
       const SizedBox(height: 12),
       TkSegmented<bool>(
         options: const [false, true],
         value: _challenge == 'math',
         labelOf: (v) => v ? 'Solve math' : 'Off',
         onChanged: (v) => setState(() => _challenge = v ? 'math' : null),
       ),
     ])),
   ],
   ```
   // ponytail: bool segmented ↔ `'math'`/null. The column stays text so a
   // future variant is a new option here, not a migration.

## Done when

- `test/challenge_test.dart` (new, pure — no widgets, no channels):
  - **Deterministic:** `generateMathChallenge(42)` equals
    `generateMathChallenge(42)` (same prompt and answer).
  - **Answer is correct:** for a spread of seeds (e.g. 0..99), the `answer`
    equals the arithmetic of the operands parsed back out of `prompt` (split on
    the ` + ` / ` × ` operator) — proving the displayed problem and its solution
    never disagree.
  - **Bounded difficulty:** for that spread, addition answers stay ≤ 198 and
    multiplication answers ≤ 144 (operands within the specced ranges).
- `test/alarm_challenge_test.dart` (new widget test, built on the
  `alarm_dismiss_test.dart`/`alarm_snooze_test.dart` scaffold — mock the
  `takna/settings` MethodChannel, `_FakeNotificationService` for `cancel`,
  `_FakeScheduler` recording `reconcile`s, `_FakeRepo` whose **`getById` returns
  a reminder with `challenge: 'math'`** and whose `snooze` records calls; pump
  `AlarmScreen(payload: '0|5|rid|Take pills')` in a `ProviderScope` + `GoRouter`
  with `/` and `/alarm`; `pump(2s)` to flush the re-cancel timer, then
  `pump()` to let the `getById` future resolve so `_challenge` is set):
  - **Wrong answer does not dismiss:** tap Dismiss → the prompt appears; enter a
    deliberately wrong number → the router stays on `/alarm` and
    `scheduler.reconciles == 0` (no dismissal). A fresh prompt is shown.
  - **Right answer dismisses:** tap Dismiss → read the `Key('challengePrompt')`
    Text, compute the correct answer from its operands, enter it, tap Check →
    `scheduler.reconciles == 1` and the app navigates to `/` (same effect as an
    un-challenged dismiss).
  - **Snooze works untouched (SAFETY):** without ever solving the challenge,
    tapping the "10 min" preset records `snooze('rid', 10)` and navigates to
    `/` — proving snooze is never gated by the challenge. (Also assert the big
    "Snooze 5 min" button still records `snooze('rid', 5)`.)
  - **No challenge → immediate dismiss (no regression):** with `getById`
    returning `challenge: null`, tapping Dismiss dismisses at once
    (`reconciles == 1`, no prompt) — matching today's `alarm_dismiss_test.dart`.
- `flutter analyze` clean; all existing suites still pass — in particular
  `test/alarm_dismiss_test.dart` and `test/alarm_snooze_test.dart` are untouched
  and green (the un-challenged Dismiss and all Snooze surfaces didn't regress),
  and `test/database_default_test.dart` still passes (new column defaults null).
- [ ] Manual (Android device/emulator): create an alarm-mode reminder with
  Dismiss challenge = "Solve math"; let it ring full-screen → tapping Dismiss
  reveals a math problem; a wrong answer keeps it ringing; the correct answer
  dismisses and returns home.
- [ ] Manual: on that same ringing challenge alarm, tap a Snooze preset (or the
  big Snooze button) **without** solving the problem → it snoozes and closes
  (SAFETY: snooze is never blocked).
- [ ] Manual: a reminder with the challenge left "Off" dismisses immediately on
  the first Dismiss tap (no regression), and the "Dismiss challenge" card is
  hidden when Alert style is switched to Notification.

## The shade Dismiss bypass (known limitation — deliberately left)

The notification-shade **Dismiss** action is a potential bypass: it calls
`handleNotificationAction('dismiss', …)` directly, with no ring screen and no
challenge. We **leave it**, honestly documented, rather than remove it, because:

- `_actions` (`notification_service.dart:42–45`) is a single shared `const` list
  referenced by both channels. Making Dismiss conditional per reminder means
  passing `challenge` into `schedule()` and building a per-reminder
  `AndroidNotificationDetails` with a filtered actions list — i.e. touching the
  scheduler and notification service, which this plan deliberately keeps
  unchanged, for a narrow window.
- That window really is narrow: in alarm mode `AlarmScreen.initState` **cancels
  the shade notification** as soon as it launches, so the shade Dismiss is only
  reachable before the full-screen activity comes up (or if the OS demotes the
  full-screen intent to a heads-up). The primary dismiss surface — the ring
  screen — is fully gated.
- Snooze must always work anyway, so a shade action that can silence the alarm
  is not itself a safety problem; the shade Dismiss only weakens the *friction*,
  in a corner the groggy-tap case rarely hits.

// ponytail: leave the shade Dismiss. Upgrade path if the bypass ever matters —
// thread `challenge` into `schedule()` and emit a Dismiss-less actions list for
// challenge reminders. Named, not built.

## Out of scope

- **Typed-phrase and shake challenges.** Math only for v1. Shake would add a
  sensor dependency (`sensors_plus`) — explicitly not worth it. The `challenge`
  column is text so either is a future option value, not a migration.
- **Per-reminder difficulty / number of problems / a difficulty setting.** One
  fixed band, one problem.
- **Removing or gating the notification-shade Dismiss action** (see "The shade
  Dismiss bypass" — left as a documented limitation).
- **Any scheduler, notification-service, or payload-format change.**
- **Gating Snooze in any way** — snooze is never blocked (SAFETY).
- **A challenge on notification-mode reminders** — no ring screen to host it;
  the card is hidden in that mode.
