---
status: planned
verified-by:
  - test/backup_test.dart
---

# Plan 03 — Local backup / restore

**Outcome:** The user can export all reminders to a JSON file via the system
share sheet and import such a file back on a new device, so data survives
phone loss/migration with no accounts, backend, or sync.

## Prereq

None (plans 01 and 02 are done). Adds two runtime dependencies, both standard
and each covering exactly one platform gap Flutter has no native API for:

- `share_plus` — system share sheet for the export file (the feature's stated
  delivery mechanism; user saves it to Drive/iCloud/wherever they like).
- `file_selector` (flutter.dev-maintained) — `openFile()` document picker for
  import; supported on Android and iOS.

## Design decisions (why JSON, why merge)

- **JSON, not a raw SQLite copy.** The DB runs with
  `shareAcrossIsolates: true` (WAL mode) — copying the live file risks a torn
  snapshot, and a raw copy also freezes the schema version into the backup.
  Drift's generated data classes already have `toJson`/`fromJson`
  (`database.g.dart`), so JSON is nearly free and future migrations keep
  working (import goes through the normal data classes, not raw SQL).
- **Envelope with a version:** `{"takna": 1, "reminders": [ ... ]}` so a
  future format change can branch on `takna`.
- **Import merges by id** (upsert). Same-id rows are overwritten, everything
  else is kept. // ponytail: no wipe-and-replace or dedupe UI — upsert is the
  smallest correct behavior; add a "replace all" toggle only if users ask.

## Context (files this touches)

- `lib/core/database/backup.dart` — **new**, the pure seam:
  `String encodeBackup(List<Reminder>)` and
  `List<Reminder> decodeBackup(String)`.
- `lib/features/reminders/data/reminder_repository.dart` — new
  `importAll(List<Reminder>)`: upsert every row, then **one** `reconcile()`
  (not one per row — the repository is the single write path and reconcile is
  idempotent, so once at the end is correct and cheap).
- `lib/features/settings/presentation/settings_screen.dart` — new "Data"
  section (a `TkCard` with Export / Import rows, same `_permRow`-style layout).
- `pubspec.yaml` — the two deps.
- `test/backup_test.dart` — **new**.

## Steps

1. **Deps.** `flutter pub add share_plus file_selector` (caret-pinned like the
   rest of the file). No manifest/Info.plist changes needed for either.

2. **Pure codec — `lib/core/database/backup.dart`.**
   ```dart
   const backupVersion = 1;

   String encodeBackup(List<Reminder> rows) => jsonEncode({
         'takna': backupVersion,
         'reminders': [for (final r in rows) r.toJson()],
       });

   /// Throws FormatException on anything that isn't a Takna backup.
   List<Reminder> decodeBackup(String source) {
     final map = jsonDecode(source);
     if (map is! Map<String, dynamic> || map['takna'] != backupVersion) {
       throw const FormatException('Not a Takna backup');
     }
     final rows = map['reminders'];
     if (rows is! List) throw const FormatException('Not a Takna backup');
     return [
       for (final r in rows) Reminder.fromJson(r as Map<String, dynamic>)
     ];
   }
   ```
   Validation is the trust boundary: `fromJson` throws on missing/mistyped
   fields, and the caller catches everything (step 5) — a bad file can never
   half-import (rows are only written after the whole list decodes).

3. **Repository — `importAll`.**
   ```dart
   Future<void> importAll(List<Reminder> rows) async {
     for (final r in rows) {
       await _db.upsert(r);
     }
     await _scheduler.reconcile();
   }
   ```
   Keeps the CLAUDE.md flow intact: UI → repository → DB write → reconcile.

4. **Export (settings row).** Read all reminders (one-shot `first` on
   `watchAll()` via the repository — add `Future<List<Reminder>> getAll()`
   delegating to a new `_db` select if cleaner), `encodeBackup`, write to a
   temp file `takna-backup-<yyyy-MM-dd>.json` (use `intl` for the stamp,
   already a dep), then `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`.

5. **Import (settings row).** `openFile()` from `file_selector` (accept
   `.json` / `application/json` via `XTypeGroup`), read the string,
   `decodeBackup`, then `repository.importAll`. Wrap the whole flow in
   try/catch → `SnackBar` "Import failed — not a Takna backup" on error,
   "Imported N reminders" on success. User cancelling the picker (null) is a
   silent no-op.

6. **UI.** In `settings_screen.dart`, add a `TkSectionLabel('Data')` +
   `TkCard` with two tappable rows (Export backup / Import backup), matching
   the existing "Alarm sound" row's look. No new widgets.

## Done when

- `test/backup_test.dart` (new) passes — pure, no platform channels:
  - **Round trip:** build 2–3 `Reminder` rows exercising nullable fields
    (`notes`, `rruleString`, `snoozedUntil` both null and set),
    `decodeBackup(encodeBackup(rows))` equals the originals.
  - **Garbage rejected:** `decodeBackup('hello')`, `decodeBackup('{}')`, and
    `decodeBackup('{"takna": 999, "reminders": []}')` all throw
    `FormatException` (or a `FormatException` from `jsonDecode`).
  - **Half-bad file rejected atomically:** a list where the second entry is
    missing `id` throws — no partial result returned.
  - **importAll reconciles once:** using the existing scheduler-test fakes,
    `importAll` with 3 rows results in 3 rows in the DB and exactly one
    reconcile pass.
- `flutter analyze` clean; all existing suites still pass.
- [ ] Manual (device/emulator): export with 2+ reminders → share sheet opens
  with a `.json` file; delete one reminder; import the file → the deleted
  reminder is back, appears on home, and its notification is rescheduled
  (check via detail screen next-fire).
- [ ] Manual: import a random non-backup `.json` → snackbar error, no data
  change.

## Out of scope

- Live/automatic sync of any kind — this is manual export/import only.
- Backing up settings/prefs (theme, defaults) — reminders are the data that
  hurts to lose; prefs take seconds to re-pick.
- A "replace all" import mode or duplicate-detection UI (merge-by-id only).
- Encrypting the backup file.
- Scheduled/automatic periodic backups.
