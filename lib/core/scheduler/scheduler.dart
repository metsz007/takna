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

  // Serialize reconciles: cancelAll + the schedule loop must not interleave
  // with another run's, or the OS queue ends up half-rebuilt.
  // ponytail: per-isolate serialization only — the background isolate has its
  // own Scheduler, so cross-isolate interleaving on the OS queue is still
  // possible (rare: an action tap racing an in-app mutation). Upgrade path if
  // it bites: a shared OS-level lock / single reconcile entry point.
  Future<void> _chain = Future.value();

  Future<void> reconcile() {
    _chain = _chain.catchError((_) {}).then((_) => _reconcile());
    return _chain;
  }

  Future<void> _reconcile() async {
    var reminders = await _db.getEnabled();
    final now = DateTime.now();

    // Vacation pause: while now < pausedUntil, schedule nothing before it but
    // still pre-queue the occurrences after it — those pre-scheduled fires are
    // what auto-resume alarms without an app open. A stale past pausedUntil is
    // inert (floor collapses to now). The fired-one-time-disable block below
    // stays on real `now` on purpose.
    final paused = await _db.getPausedUntil();
    final floor = (paused != null && paused.isAfter(now)) ? paused : now;

    // Google Clock pattern: a fired one-time reminder flips its toggle off so
    // it stops sitting in the list as enabled with "No upcoming". A pending
    // snooze keeps it alive — that occurrence must still fire, and it gets
    // disabled on the reconcile after the snooze passes. Deliberate: a one-time
    // reminder that fired while the phone was off is disabled on next reconcile
    // — the time has passed either way.
    final fired = reminders.where((r) =>
        r.rruleString == null &&
        r.startDateTime.subtract(Duration(minutes: r.offsetMinutes)).isBefore(now) &&
        (r.snoozedUntil == null || r.snoozedUntil!.isBefore(now)));
    for (final r in fired) {
      await _db.setEnabled(r.id, false);
    }
    if (fired.isNotEmpty) reminders = await _db.getEnabled();

    final occurrences = <({Reminder r, DateTime fireAt})>[];
    for (final r in reminders) {
      // A pending snooze fires at its exact time (no offset).
      final snooze = r.snoozedUntil;
      if (snooze != null && snooze.isAfter(floor)) {
        occurrences.add((r: r, fireAt: snooze));
      }
      for (final occ in nextOccurrences(r, floor, _perReminder)) {
        final fireAt = occ.subtract(Duration(minutes: r.offsetMinutes));
        if (fireAt.isAfter(floor)) occurrences.add((r: r, fireAt: fireAt));
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
        isAlarm: o.r.isAlarm,
        soundKey: o.r.soundKey,
      );
    }
  }
}
