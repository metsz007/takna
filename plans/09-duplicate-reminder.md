---
status: done
verified-by:
  - test/duplicate_reminder_test.dart
---

# Plan 09 — Duplicate a reminder

**Outcome:** A "Duplicate" action on the detail screen opens the add/edit form
pre-filled with a copy of the reminder (same title/notes/time/RRULE/offset/
snooze/alert-style), but as a *new* reminder — fresh uuid, fresh
createdAt/updatedAt, snoozedUntil cleared — so the user can tweak and save a
sibling in a couple of taps instead of re-entering everything.

## Prereq

None. No new dependency, no scheduler/DB/model change. Saving a duplicate goes
through the existing `ReminderRepository.save` path unchanged.

## Design decision (why reuse `/add`)

The add/edit screen already has exactly two modes keyed off `reminderId`:

- **edit** (`reminderId != null`): `_load` fills the form from `getById`, and
  `_save` reuses that id + the loaded `createdAt` → an update in place.
- **create** (`reminderId == null`): `_save` mints `const Uuid().v4()`,
  `createdAt ?? now`, never sets `snoozedUntil` (so it defaults null on the
  `Reminder` it builds).

A duplicate is exactly **create-mode semantics with the form pre-filled from an
existing row.** So the whole feature is: give the screen a way to seed the form
from a source id *without* switching into edit mode. Adding a `copyFromId`
constructor arg (passed via a `?copy=` query param on the existing `/add`
route) does that — no new route, no new save path, no new provider.
`_save` already produces a new uuid / fresh timestamps / null snoozedUntil in
create mode, so those requirements fall out for free.

// ponytail: reuse `/add` + a query param, not a new `/duplicate/:id` route or
// a copy method on the repository. The only new logic is one branch in `_load`.

## Context (files this touches)

- `lib/features/reminders/presentation/screens/add_edit_reminder_screen.dart` —
  add `final String? copyFromId;` to the widget; add a copy branch in `_load`
  (72-99). `isEdit` stays `reminderId != null` (unchanged), so a copy is create
  mode. `_save` (101-142) is **not touched** — its create-mode branch already
  gives new uuid, `createdAt ?? now`, `updatedAt = now`, and never sets
  `snoozedUntil` (nullable column, confirmed in `database.g.dart:371`).
- `lib/core/router/router.dart` — the `/add` GoRoute (88-91): pass
  `copyFromId: s.uri.queryParameters['copy']` into the screen. No new route.
- `lib/features/reminders/presentation/screens/reminder_detail_screen.dart` —
  add a Duplicate action in the top action row (48-89), next to the delete
  icon, that does `context.push('/add?copy=$reminderId')`.
- `test/duplicate_reminder_test.dart` — **new**; mirrors the `_FakeRepo` +
  router harness already in `test/add_edit_test.dart`.

## Steps

1. **Screen — accept a copy source.** Add `this.copyFromId` to the
   `AddEditReminderScreen` constructor (alongside `reminderId`). Leave
   `bool get isEdit => widget.reminderId != null;` as-is — a copy is **not** an
   edit.

2. **Screen — seed the form in `_load`.** The row to fetch is
   `widget.reminderId ?? widget.copyFromId`. Restructure `_load` so:
   - **edit** (`isEdit`): unchanged — fill controllers/state *and* set
     `_createdAt`, `_isEnabled`, `_loadedDate`, `_loadedRrule` from the row.
   - **copy** (`!isEdit && copyFromId != null`): fetch the source, fill the
     same editable fields (`_title`, `_notes`, `_date`, `_rrule`, `_offset`,
     `_snooze`, `_isAlarm`) **but leave the create-mode defaults for the rest**
     — `_createdAt` stays null, `_isEnabled` stays true, `_loadedDate` /
     `_loadedRrule` stay null. (Null `_loadedDate` means `_save` treats it as a
     new schedule → the copy saves enabled, which is what you want for a fresh
     reminder.) snoozedUntil is simply never carried, so the copy starts
     un-snoozed.
   - **create** (neither id): unchanged — read prefs defaults.

   Extract the shared field-fill into a small helper (e.g.
   `void _fillFrom(Reminder r, {required bool asCopy})`) to avoid duplicating
   the seven assignments; `asCopy` gates whether the four "identity" fields get
   set. // ponytail: helper only because the same seven lines run in two
   branches — not a new abstraction, just don't copy-paste them.

3. **Screen — header label (optional).** `_save` needs nothing. The header
   still reads "New reminder" for a copy (from `isEdit`). Leave it — a copy *is*
   a new reminder. // ponytail: not worth a third label state.

4. **Router — thread the param.** In the `/add` GoRoute pageBuilder pass
   `AddEditReminderScreen(copyFromId: s.uri.queryParameters['copy'])`
   (`copy` is null for a plain `/add`, so create mode is unaffected).

5. **Detail — the action.** In the action row add a `TkIconButton`
   (`Icons.copy_outlined` or `Icons.control_point_duplicate`) before the delete
   icon, `onTap: () => context.push('/add?copy=$reminderId')`. Matches the
   existing `TkIconButton` back/delete styling; no new widget.

## Done when

- `test/duplicate_reminder_test.dart` (new) passes. Same harness as
  `add_edit_test.dart` (`_FakeRepo` seeding `getById`, capturing `_save`'s
  output; router with a `/dup` route rendering
  `AddEditReminderScreen(copyFromId: 'rid')`). Seed a reminder with a distinct
  id, a set `snoozedUntil`, an old `createdAt`, an rrule, and non-default
  offset/snooze/isAlarm, then tap **Save** and assert on `repo.saved`:
  - **new identity:** `saved.id != 'rid'` (and is non-empty), header shows
    "New reminder" not "Edit reminder".
  - **fields copied:** `title`, `notes`, `startDateTime`, `rruleString`,
    `offsetMinutes`, `snoozeMinutes`, `isAlarm` all equal the seed's.
  - **snooze cleared:** `saved.snoozedUntil == null`.
  - **fresh timestamps:** `saved.createdAt.isAfter(seedCreatedAt)` and
    `saved.updatedAt.isAfter(seedCreatedAt)`.
  - **enabled:** `saved.isEnabled == true` (even if the seed was paused).
- `flutter analyze` clean; all existing suites (esp. `add_edit_test.dart`)
  still pass — the edit and create paths are behaviorally unchanged.
- [ ] Manual (device/emulator): open a reminder's detail → tap Duplicate → form
  opens pre-filled → change the title → Save → home shows both the original and
  the copy, and the original's next-fire is unchanged (the copy is a separate
  row, not an edit of the original).

## Out of scope

- A "Duplicate" entry from the home list swipe/long-press or the edit screen —
  detail-screen action only. Add elsewhere later if asked.
- Auto-renaming the copy ("Foo (copy)") — the form opens for editing, the user
  renames if they want. // ponytail: no string munging.
- Bulk duplicate / duplicate-to-a-date-shift.
- Any repository, scheduler, DB schema, or model change.
