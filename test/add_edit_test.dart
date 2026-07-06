import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/reminders/data/reminder_repository.dart';
import 'package:takna/features/reminders/presentation/providers.dart';
import 'package:takna/features/reminders/presentation/screens/add_edit_reminder_screen.dart';

/// Serves a fixed reminder for the edit load and captures whatever `_save`
/// writes. save/getById are overridden, so the db/scheduler passed to super
/// are never touched.
class _FakeRepo extends ReminderRepository {
  _FakeRepo(this.seed) : super(_db, Scheduler(_db, NotificationService()));
  static final _db = AppDatabase();
  final Reminder seed;
  Reminder? saved;

  @override
  Future<Reminder?> getById(String id) async => seed;
  @override
  Future<void> save(Reminder r) async => saved = r;
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  testWidgets('editing a paused reminder preserves isEnabled and createdAt',
      (tester) async {
    final created = DateTime(2020, 1, 1);
    final seed = Reminder(
      id: 'rid',
      title: 'Paused',
      startDateTime: DateTime(2030, 1, 1, 9, 0),
      timeZone: 'UTC',
      offsetMinutes: 0,
      snoozeMinutes: 5,
      isEnabled: false,
      isAlarm: true,
      createdAt: created,
      updatedAt: created,
    );
    final repo = _FakeRepo(seed);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
            path: '/edit',
            builder: (context, state) =>
                const AddEditReminderScreen(reminderId: 'rid')),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        theme: themeFor(Brightness.light),
        routerConfig: router,
      ),
    ));

    // Push edit over home so `context.pop()` on save has somewhere to go, then
    // let the push transition and async `_load` settle. Avoid pumpAndSettle —
    // the loading spinner animates forever.
    router.push('/edit');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Edit reminder'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.saved, isNotNull);
    expect(repo.saved!.isEnabled, isFalse);
    expect(repo.saved!.createdAt, created);
    expect(repo.saved!.updatedAt.isAfter(created), isTrue);
  });
}
