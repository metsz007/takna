import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/reminders/data/reminder_repository.dart';
import 'package:takna/features/reminders/presentation/providers.dart';
import 'package:takna/features/reminders/presentation/screens/alarm_screen.dart';

/// No-op service so initState's `cancel` never hits the notifications plugin.
class _FakeNotificationService extends NotificationService {
  @override
  Future<void> cancel(int id) async {}
}

/// Records that the rolling window was re-armed. `reconcile` is overridden, so
/// the db/service passed to super are never touched.
class _FakeScheduler extends Scheduler {
  _FakeScheduler(super.db, super.notifications);
  int reconciles = 0;
  @override
  Future<void> reconcile() async => reconciles++;
}

void main() {
  testWidgets('dismiss persists dismissedUntil and re-arms via reconcile',
      (tester) async {
    // AlarmScreen drives the native alarm sound over MethodChannel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('takna/settings'), (_) async => null);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await db.upsert(Reminder(
      id: 'rid',
      title: 'Test',
      startDateTime: now.subtract(const Duration(minutes: 2)),
      timeZone: 'UTC',
      offsetMinutes: 0,
      snoozeMinutes: 5,
      nagMinutes: 5,
      isEnabled: true,
      isAlarm: true,
      createdAt: now,
      updatedAt: now,
    ));
    // Real repository over the in-memory DB: dismiss must write the flag AND
    // reconcile — the pair that stops a nagging reminder's remaining re-rings.
    final scheduler = _FakeScheduler(db, _FakeNotificationService());
    final repo = ReminderRepository(db, scheduler);

    final router = GoRouter(
      initialLocation: '/alarm',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
            path: '/alarm',
            builder: (context, state) =>
                const AlarmScreen(payload: '1|5|rid|Test')),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(_FakeNotificationService()),
        schedulerProvider.overrideWithValue(scheduler),
        reminderRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        theme: themeFor(Brightness.light),
        routerConfig: router,
      ),
    ));

    // Flush the 2s one-shot re-cancel timer while still mounted (it isn't
    // cancelled in dispose).
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(scheduler.reconciles, 1);
    expect((await db.getById('rid'))!.dismissedUntil, isNotNull);

    addTearDown(() =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
                const MethodChannel('takna/settings'), null));
  });
}
