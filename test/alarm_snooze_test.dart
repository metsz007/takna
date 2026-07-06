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

/// Records snooze(id, minutes) instead of touching db/scheduler. The db and
/// scheduler passed to super are never used (snooze is fully overridden).
class _FakeRepo extends ReminderRepository {
  _FakeRepo() : super(_db, Scheduler(_db, NotificationService()));
  static final _db = AppDatabase();
  final calls = <({String id, int minutes})>[];

  @override
  Future<void> snooze(String id, int minutes) async =>
      calls.add((id: id, minutes: minutes));
}

/// No-op service so initState's `cancel` never hits the notifications plugin.
class _FakeNotificationService extends NotificationService {
  @override
  Future<void> cancel(int id) async {}
}

Future<_FakeRepo> _pump(WidgetTester tester) async {
  // AlarmScreen drives the native alarm sound over MethodChannel.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('takna/settings'), (_) async => null);
  addTearDown(() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('takna/settings'), null));

  final repo = _FakeRepo();
  final router = GoRouter(
    initialLocation: '/alarm',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      GoRoute(
          path: '/alarm',
          builder: (context, state) =>
              const AlarmScreen(payload: '0|5|rid|Take pills')),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      reminderRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      theme: themeFor(Brightness.light),
      routerConfig: router,
    ),
  ));

  // Flush the 2s one-shot re-cancel timer while still mounted.
  await tester.pump(const Duration(seconds: 2));
  return repo;
}

void main() {
  testWidgets('preset chip overrides the saved default (10 min → snooze 10)',
      (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('10 min'));
    await tester.pumpAndSettle();

    expect(repo.calls, [(id: 'rid', minutes: 10)]);
  });

  testWidgets('another preset (30 min → snooze 30)', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    expect(repo.calls, [(id: 'rid', minutes: 30)]);
  });

  testWidgets('big button keeps the saved default (Snooze 5 min → snooze 5)',
      (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('Snooze 5 min'));
    await tester.pumpAndSettle();

    expect(repo.calls, [(id: 'rid', minutes: 5)]);
  });
}
