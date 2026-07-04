import '../../../core/database/database.dart';
import '../../../core/scheduler/scheduler.dart';

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

  Future<void> setEnabled(String id, bool enabled) async {
    final r = await _db.getById(id);
    if (r == null) return;
    await _db.upsert(r.copyWith(isEnabled: enabled, updatedAt: DateTime.now()));
    await _scheduler.reconcile();
  }
}
