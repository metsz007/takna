import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';
import '../../../core/scheduler/scheduler.dart';
import '../domain/recurrence.dart';

/// Single write path: every mutation goes through here and ends in a
/// reconcile so the OS queue always mirrors the DB.
class ReminderRepository {
  ReminderRepository(this._db, this._scheduler);
  final AppDatabase _db;
  final Scheduler _scheduler;

  Stream<List<Reminder>> watchAll() => _db.watchAll();
  Future<Reminder?> getById(String id) => _db.getById(id);

  Future<void> save(Reminder r) async {
    await _db.upsert(r);
    await _scheduler.reconcile();
  }

  Future<void> delete(String id) async {
    await _db.deleteById(id);
    await _scheduler.reconcile();
  }

  Future<void> snooze(String id, int minutes) async {
    await _db.setSnoozedUntil(id, DateTime.now().add(Duration(minutes: minutes)));
    await _scheduler.reconcile();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final r = await _db.getById(id);
    if (r == null) return;
    await _db.upsert(r.copyWith(isEnabled: enabled, updatedAt: DateTime.now()));
    await _scheduler.reconcile();
  }

  /// Skips one specific RRULE occurrence.
  Future<void> skip(String id, DateTime occurrence) async {
    final r = await _db.getById(id);
    if (r == null || r.rruleString == null) return;
    final skips = decodeSkips(r.skippedDates)
      ..add(occurrence.millisecondsSinceEpoch);
    await _db.upsert(r.copyWith(
        skippedDates: Value(encodeSkips(skips)), updatedAt: DateTime.now()));
    await _scheduler.reconcile();
  }

  /// Skips the next RRULE occurrence (not a pending snooze). Returns the
  /// skipped occurrence, or null if nothing to skip / not recurring.
  Future<DateTime?> skipNext(String id) async {
    final r = await _db.getById(id);
    if (r == null || r.rruleString == null) return null;
    final next = nextOccurrences(r, DateTime.now(), 1);
    if (next.isEmpty) return null;
    await skip(id, next.first);
    return next.first;
  }

  Future<void> unskip(String id, DateTime occurrence) async {
    final r = await _db.getById(id);
    if (r == null) return;
    final skips = decodeSkips(r.skippedDates)
      ..remove(occurrence.millisecondsSinceEpoch);
    await _db.upsert(r.copyWith(
        skippedDates: Value(encodeSkips(skips)), updatedAt: DateTime.now()));
    await _scheduler.reconcile();
  }

  /// All reminders, one-shot (for export).
  Future<List<Reminder>> getAll() => _db.watchAll().first;

  /// Restores a backup: upsert every row (merge by id), then a single
  /// reconcile — the DB is the write path and reconcile is idempotent, so once
  /// at the end is correct and cheap.
  Future<void> importAll(List<Reminder> rows) async {
    for (final r in rows) {
      await _db.upsert(r);
    }
    await _scheduler.reconcile();
  }
}
