---
status: done
verified-by:
  - test/tags_test.dart
---

# Plan 08 — Tags + home filtering

**Outcome:** A reminder can carry one optional free-text tag (set in add/edit),
and the home screen shows a chip row — "All" plus each distinct tag currently in
use — that filters the list to one tag at a time.

## Prereq

None. Independent of plans 01/02 (done) and 03 (planned) — but see the backup
compat note under Design decisions, since plan 03's codec must keep decoding
pre-tag backups once this ships.

This was flagged in review as "hold until users have >15 reminders." It's being
planned now at the user's request, so the whole plan is deliberately the *lazy*
version: **one nullable column, single tag per reminder** (not many-to-many, no
join table), distinct tags derived in memory, and inline chips rather than any
new shared widget. If real tag management ever earns its keep (rename, colour,
multi-tag), that's a later plan — this one stays a thin slice.

## Design decisions

- **Single `tag` text column, nullable.** No `Tags` table, no `ReminderTags`
  join. `// ponytail:` one tag per reminder is the whole feature; a
  many-to-many model is 3x the code for a need nobody has hit yet. Upgrade path:
  add a join table and a migration if users ask for multiple tags.
- **Distinct tags are computed from the loaded list, never stored** (CLAUDE.md:
  never store derived data). `distinctTags(reminders)` runs at build time on the
  already-watched list — no query, no cache.
- **Selected filter is transient UI state**, held in a `StateProvider<String?>`
  (null = "All"), matching the codebase's riverpod conventions. It is *not*
  persisted — reopening the app shows "All". `// ponytail:` a remembered filter
  is a pref nobody asked for; add it if it's ever missed.
- **Backup compat (drift `fromJson`, missing key).** Plan 03 serializes rows via
  `Reminder.toJson()` / `Reminder.fromJson()`. The generated `fromJson` reads
  the new column as `serializer.fromJson<String?>(json['tag'])`; drift's default
  `ValueSerializer` returns `null` for a `null`/absent value, so a pre-tag
  backup (no `'tag'` key) decodes cleanly with `tag == null`. This plan's test
  pins that behavior directly (see Done when) so plan 03 stays green — plan 03
  does not need to change.

## Context (files this touches)

- `lib/core/database/database.dart` — add the `tag` column to `Reminders`, bump
  `schemaVersion` 3 → 4, add one `onUpgrade` branch. Regenerate
  `database.g.dart` via build_runner.
- `lib/features/reminders/presentation/screens/add_edit_reminder_screen.dart` —
  a `_tag` controller, load from `r.tag`, and one tag `TkCard` in the form;
  include `tag:` in the `Reminder(...)` built in `_save`.
- `lib/features/reminders/presentation/screens/home_screen.dart` — two top-level
  pure helpers (`distinctTags`, and the trivial filter), a `tagFilterProvider`,
  a chip row in `_HomeList`, and filtering the list before hero/section
  computation.
- `test/tags_test.dart` — **new**; sits alongside `test/database_default_test.dart`
  and `test/add_edit_test.dart`.

No scheduler, notification, repository, or router changes — `tag` is inert data
the scheduler never reads.

## Steps

1. **DB column + migration.** In `Reminders` (database.dart), after
   `snoozedUntil`:
   ```dart
   TextColumn get tag => text().nullable()();
   ```
   Bump `int get schemaVersion => 4;` and add to `onUpgrade`:
   ```dart
   if (from < 4) await m.addColumn(reminders, reminders.tag);
   ```
   Regenerate: `dart run build_runner build --delete-conflicting-outputs`. No
   new query methods — `watchAll()`, `upsert`, `toJson`/`fromJson` all pick up
   the column for free.

2. **Add/edit field.** In `_AddEditState`: add `final _tag = TextEditingController();`.
   In `_load`, `_tag.text = r.tag ?? '';`. Add one `TkCard` in the form (near the
   notes/snooze cards — anywhere in the existing `Column`) with a label icon
   (`Icons.label_outline`) and a single-line `TextField(controller: _tag)` whose
   decoration mirrors the borderless notes field. In `_save`'s `Reminder(...)`:
   ```dart
   tag: _tag.text.trim().isEmpty ? null : _tag.text.trim(),
   ```
   `// ponytail:` free text, no length cap and no autocomplete against existing
   tags — trim-to-null is the whole input. Add suggestions only if typos become
   a real complaint.

3. **Home: pure helpers.** Top-level in home_screen.dart (test seam, same shape
   as `_countdown`):
   ```dart
   /// Distinct non-null tags in use, sorted for a stable chip order.
   List<String> distinctTags(List<Reminder> rs) =>
       (rs.map((r) => r.tag).whereType<String>().toSet().toList()..sort());
   ```
   Filtering itself is a trivial one-liner used inline (step 4); no helper/test
   needed for it (`where((r) => r.tag == sel)`).

4. **Home: chip row + filter.** Add
   `final tagFilterProvider = StateProvider<String?>((ref) => null);`. In
   `_HomeList.build`, before computing hero/today/upcoming:
   ```dart
   final tags = distinctTags(reminders);
   final raw = ref.watch(tagFilterProvider);
   final sel = tags.contains(raw) ? raw : null; // clamp stale selection → All
   final visible = sel == null
       ? reminders
       : [for (final r in reminders) if (r.tag == sel) r];
   ```
   Use `visible` in place of `reminders` for the rest of the method (hero,
   today/upcoming split) so the filter applies to everything. Render the chip
   row from the ListView after `_Header`, only `if (tags.isNotEmpty)`: a
   horizontally scrollable `Row`/`ListView` of inline chips — "All" (selected
   when `sel == null`) plus one per tag — each a `GestureDetector` that sets
   `ref.read(tagFilterProvider.notifier).state = tag` (or `null` for All).
   `// ponytail:` inline chips styled locally (like the weekday circles in
   add/edit), not a new `TkChip` widget — one caller doesn't earn an abstraction.
   The stale-selection clamp keeps the list from going blank when the last
   reminder of a tag is deleted or retagged.

## Done when

- `test/tags_test.dart` (new) passes:
  - **`distinctTags` dedupes, drops null, sorts:** given rows with tags
    `['work', null, 'home', 'work']`, returns exactly `['home', 'work']`.
  - **Old-backup decode (drift missing-key compat):** a `Map` built to look like
    a pre-tag `toJson()` row (all existing keys, **no `'tag'`**) passed to
    `Reminder.fromJson` yields `tag == null` and does not throw. This pins the
    behavior plan 03's codec relies on.
  - **DB column round-trips (mirrors `database_default_test.dart`):** insert via
    `RemindersCompanion.insert` without `tag` → `getById` reads `tag == null`;
    `upsert` a row with `tag: 'work'` → reads back `'work'`.
- `flutter analyze` is clean; all existing suites still pass (including
  `add_edit_test.dart` and `database_default_test.dart`).
- [x] Manual (device/emulator): create 3 reminders, tag two of them "work" and
  one "home"; home shows an All/home/work chip row; tapping "work" narrows the
  list (and hero) to the two work reminders; tapping "All" restores everything;
  deleting the only "home" reminder while "home" is selected falls back to All
  with no blank screen.
- [x] Manual: fresh install over an existing DB (schema 3 → 4) opens without
  error and all pre-existing reminders show untagged.

## Out of scope

- Multiple tags per reminder, a tag table, rename/merge/colour, or any tag
  management screen — single free-text tag only.
- Persisting the selected filter across launches.
- Autocomplete / suggestion of existing tags in the add/edit field.
- Filtering by anything other than tag (date range, alarm-vs-notification, etc.).
- Any change to scheduling — `tag` is never read by the scheduler or
  notifications.
- The backup codec itself (plan 03) — this plan only guarantees its rows keep
  decoding; it adds no export/import code.
