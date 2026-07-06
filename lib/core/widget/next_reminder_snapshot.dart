import 'dart:io';

import 'package:flutter/material.dart' show DateUtils;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../features/reminders/domain/recurrence.dart';
import '../database/database.dart';

/// Title + when-label for the earliest upcoming *enabled* reminder relative to
/// [now], or null when nothing is upcoming. Pure — no platform channel.
/// Selection matches the home hero (effectiveNextFire, earliest wins) so the
/// app and the widget never disagree.
({String title, String when})? nextReminderSnapshot(
    List<Reminder> reminders, DateTime now) {
  ({Reminder r, DateTime at})? best;
  for (final r in reminders) {
    if (!r.isEnabled) continue;
    final next = effectiveNextFire(r, now);
    if (next != null && (best == null || next.at.isBefore(best.at))) {
      best = (r: r, at: next.at);
    }
  }
  if (best == null) return null;
  final at = best.at;
  // Same phrasing as the home list row: bare time when it's today, else a
  // day-label prefix (mirrors home_screen _dayLabel + 'h:mm a').
  final time = DateFormat('h:mm a').format(at);
  final when =
      DateUtils.isSameDay(at, now) ? time : '${_dayLabel(at, now)} · $time';
  return (title: best.r.title, when: when);
}

/// Today / Tomorrow / date — pure twin of home_screen's `_dayLabel` (takes an
/// explicit [now] so it stays testable off a real clock).
String _dayLabel(DateTime d, DateTime now) {
  if (DateUtils.isSameDay(d, now)) return 'Today';
  if (DateUtils.isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
  return DateFormat(d.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(d);
}

/// Pushes the current snapshot to the Android home-screen widget. No-op off
/// Android (iOS widget is a separate plan) and never throws into the caller —
/// the widget is a disposable display cache, so a missing channel (unit tests)
/// or an unplaced widget must not break reconcile.
Future<void> pushNextReminder(List<Reminder> reminders, DateTime now) async {
  if (!Platform.isAndroid) return; // ponytail: iOS widget = separate plan
  final snap = nextReminderSnapshot(reminders, now);
  try {
    await HomeWidget.saveWidgetData(
        'title', snap?.title ?? 'No upcoming reminders');
    await HomeWidget.saveWidgetData('when', snap?.when ?? '');
    await HomeWidget.updateWidget(androidName: 'ReminderWidgetProvider');
  } catch (_) {
    // No channel / no widget placed → never break reconcile.
  }
}
