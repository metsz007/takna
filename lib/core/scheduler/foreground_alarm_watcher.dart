import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/reminders/domain/recurrence.dart';
import '../../features/reminders/presentation/providers.dart';
import '../database/database.dart';
import 'scheduler.dart';

/// While the app is in the foreground, Android shows alarms as heads-up
/// notifications instead of launching the full-screen intent. This watcher
/// tracks the next upcoming occurrence with a Dart timer and, if the app is
/// active at fire time, navigates to the alarm screen itself.
class ForegroundAlarmWatcher with WidgetsBindingObserver {
  ForegroundAlarmWatcher(this._container, this._router);
  final ProviderContainer _container;
  final GoRouter _router;
  Timer? _timer;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    // Re-arm on every reminder change (create/edit/delete/toggle).
    _container.listen(remindersStreamProvider, (_, _) => _arm(),
        fireImmediately: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _arm();
  }

  Future<void> _arm() async {
    _timer?.cancel();
    final reminders = await _container.read(databaseProvider).getEnabled();
    final now = DateTime.now();
    ({Reminder r, DateTime fireAt})? next;
    void consider(Reminder r, DateTime fireAt) {
      if (fireAt.isAfter(now) && (next == null || fireAt.isBefore(next!.fireAt))) {
        next = (r: r, fireAt: fireAt);
      }
    }

    for (final r in reminders) {
      final snooze = r.snoozedUntil;
      if (snooze != null) consider(r, snooze);
      for (final occ in nextOccurrences(r, now, 1)) {
        consider(r, occ.subtract(Duration(minutes: r.offsetMinutes)));
      }
    }
    final target = next;
    if (target == null) return;
    _timer = Timer(target.fireAt.difference(now), () => _fire(target));
  }

  void _fire(({Reminder r, DateTime fireAt}) entry) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      final id = occurrenceNotificationId(entry.r.id, entry.fireAt);
      _router.go('/alarm',
          extra: '$id|${entry.r.snoozeMinutes}|${entry.r.id}|${entry.r.title}');
    }
    _arm(); // track the following occurrence
  }
}
