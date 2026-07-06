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

/// getById returns a reminder carrying [_challenge] (so the ring screen sees
/// the gate or not); snooze records calls so SAFETY can assert it's never
/// blocked. db/scheduler passed to super are never touched (both overridden).
class _FakeRepo extends ReminderRepository {
  _FakeRepo(this._challenge) : super(_db, Scheduler(_db, NotificationService()));
  static final _db = AppDatabase();
  final String? _challenge;
  final calls = <({String id, int minutes})>[];

  @override
  Future<void> snooze(String id, int minutes) async =>
      calls.add((id: id, minutes: minutes));

  @override
  Future<Reminder?> getById(String id) async {
    final now = DateTime(2026, 7, 7, 9);
    return Reminder(
      id: id,
      title: 'Take pills',
      startDateTime: now,
      timeZone: 'UTC',
      offsetMinutes: 0,
      snoozeMinutes: 5,
      isEnabled: true,
      isAlarm: true,
      challenge: _challenge,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Records rolling-window re-arms; dismissal is the only thing that reconciles.
class _FakeScheduler extends Scheduler {
  _FakeScheduler(super.db, super.notifications);
  int reconciles = 0;
  @override
  Future<void> reconcile() async => reconciles++;
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> cancel(int id) async {}
}

/// Pumps the ring screen for a reminder whose challenge is [challenge], flushes
/// the re-cancel timer, then lets the async getById resolve so _challenge is set.
Future<({_FakeRepo repo, _FakeScheduler scheduler})> _pump(
    WidgetTester tester,
    {required String? challenge}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('takna/settings'), (_) async => null);
  addTearDown(() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('takna/settings'), null));

  final repo = _FakeRepo(challenge);
  final scheduler = _FakeScheduler(AppDatabase(), _FakeNotificationService());
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
      schedulerProvider.overrideWithValue(scheduler),
    ],
    child: MaterialApp.router(
      theme: themeFor(Brightness.light),
      routerConfig: router,
    ),
  ));

  // Flush the 2s one-shot re-cancel timer, then let getById resolve.
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  return (repo: repo, scheduler: scheduler);
}

/// Correct answer for the currently-shown challenge, read off the prompt.
int _promptAnswer(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('challengePrompt')));
  final expr = text.data!.replaceAll(' = ?', '');
  if (expr.contains(' + ')) {
    final p = expr.split(' + ');
    return int.parse(p[0]) + int.parse(p[1]);
  }
  final p = expr.split(' × ');
  return int.parse(p[0]) * int.parse(p[1]);
}

void main() {
  testWidgets('wrong answer does not dismiss; a fresh prompt stays', (tester) async {
    final f = await _pump(tester, challenge: 'math');

    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.byKey(const Key('challengePrompt')), findsOneWidget);

    // 999999 is always wrong (max possible answer is 198).
    await tester.enterText(find.byType(TextField), '999999');
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(f.scheduler.reconciles, 0); // never dismissed
    expect(find.byType(AlarmScreen), findsOneWidget); // still ringing
    expect(find.byKey(const Key('challengePrompt')), findsOneWidget);
  });

  testWidgets('right answer dismisses (reconcile + navigate home)', (tester) async {
    final f = await _pump(tester, challenge: 'math');

    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    await tester.enterText(
        find.byType(TextField), '${_promptAnswer(tester)}');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(f.scheduler.reconciles, 1);
    expect(find.byType(AlarmScreen), findsNothing);
  });

  testWidgets('SAFETY: snooze preset works without solving the challenge',
      (tester) async {
    final f = await _pump(tester, challenge: 'math');

    await tester.tap(find.text('10 min'));
    await tester.pumpAndSettle();

    expect(f.repo.calls, [(id: 'rid', minutes: 10)]);
    expect(f.scheduler.reconciles, 0); // snooze path never dismisses
  });

  testWidgets('SAFETY: big Snooze button works without solving the challenge',
      (tester) async {
    final f = await _pump(tester, challenge: 'math');

    await tester.tap(find.text('Snooze 5 min'));
    await tester.pumpAndSettle();

    expect(f.repo.calls, [(id: 'rid', minutes: 5)]);
  });

  testWidgets('no challenge → immediate dismiss, no prompt (regression)',
      (tester) async {
    final f = await _pump(tester, challenge: null);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(f.scheduler.reconciles, 1);
    expect(find.byKey(const Key('challengePrompt')), findsNothing);
    expect(find.byType(AlarmScreen), findsNothing);
  });
}
