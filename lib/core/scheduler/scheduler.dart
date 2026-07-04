import '../../features/reminders/domain/recurrence.dart';
import '../database/database.dart';
import '../notifications/notification_service.dart';

/// Stable notification id for one occurrence of one reminder (FNV-1a).
/// Deterministic across app runs — Object.hash is not — so the foreground
/// watcher can compute the same id the scheduler used.
int occurrenceNotificationId(String reminderId, DateTime fireAt) {
  var h = 0x811c9dc5;
  for (final c in '$reminderId|${fireAt.millisecondsSinceEpoch}'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h;
}

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
      // A pending snooze fires at its exact time (no offset).
      final snooze = r.snoozedUntil;
      if (snooze != null && snooze.isAfter(now)) {
        occurrences.add((r: r, fireAt: snooze));
      }
      for (final occ in nextOccurrences(r, now, _perReminder)) {
        final fireAt = occ.subtract(Duration(minutes: r.offsetMinutes));
        if (fireAt.isAfter(now)) occurrences.add((r: r, fireAt: fireAt));
      }
    }
    occurrences.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    await _notifications.cancelAll();
    for (final o in occurrences.take(_windowTotal)) {
      await _notifications.schedule(
        id: occurrenceNotificationId(o.r.id, o.fireAt),
        title: o.r.title,
        body: o.r.notes,
        when: o.fireAt,
        snoozeMinutes: o.r.snoozeMinutes,
        reminderId: o.r.id,
      );
    }
  }
}
