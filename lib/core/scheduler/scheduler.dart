import '../../features/reminders/domain/recurrence.dart';
import '../database/database.dart';
import '../notifications/notification_service.dart';

/// Rolling-window reconciler: the DB is the source of truth, the OS
/// notification queue is rebuilt from it. Idempotent and self-healing.
class Scheduler {
  Scheduler(this._db, this._notifications);
  final AppDatabase _db;
  final NotificationService _notifications;

  static const _windowTotal = 60; // stay under iOS's 64 pending cap
  static const _perReminder = 10;

  Future<void> reconcile() async {
    final reminders = await _db.getEnabled();
    final now = DateTime.now();

    final occurrences = <({Reminder r, DateTime fireAt})>[];
    for (final r in reminders) {
      for (final occ in nextOccurrences(r, now, _perReminder)) {
        final fireAt = occ.subtract(Duration(minutes: r.offsetMinutes));
        if (fireAt.isAfter(now)) occurrences.add((r: r, fireAt: fireAt));
      }
    }
    occurrences.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    await _notifications.cancelAll();
    for (final o in occurrences.take(_windowTotal)) {
      await _notifications.schedule(
        id: Object.hash(o.r.id, o.fireAt.millisecondsSinceEpoch),
        title: o.r.title,
        body: o.r.notes,
        when: o.fireAt,
        snoozeMinutes: o.r.snoozeMinutes,
      );
    }
  }
}
