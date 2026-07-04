import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/scheduler/scheduler.dart';
import '../data/reminder_repository.dart';

final databaseProvider = Provider((ref) => AppDatabase());

final notificationServiceProvider = Provider((ref) => NotificationService());

final schedulerProvider = Provider((ref) =>
    Scheduler(ref.watch(databaseProvider), ref.watch(notificationServiceProvider)));

final reminderRepositoryProvider = Provider((ref) =>
    ReminderRepository(ref.watch(databaseProvider), ref.watch(schedulerProvider)));

final remindersStreamProvider = StreamProvider<List<Reminder>>(
    (ref) => ref.watch(reminderRepositoryProvider).watchAll());

final reminderByIdProvider = FutureProvider.family<Reminder?, String>(
    (ref, id) async {
  ref.watch(remindersStreamProvider); // refresh on any change
  return ref.watch(reminderRepositoryProvider).getById(id);
});

final prefsProvider = FutureProvider((ref) => SharedPreferences.getInstance());

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> set(ThemeMode m) async {
    state = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', m.name);
  }

  void load(SharedPreferences prefs) {
    final saved = prefs.getString('themeMode');
    if (saved != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
