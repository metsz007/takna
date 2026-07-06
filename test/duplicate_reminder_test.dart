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

/// Serves a fixed reminder for the copy-source load and captures whatever
/// `_save` writes. save/getById are overridden, so the db/scheduler passed to
/// super are never touched.
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

  testWidgets('duplicating a reminder saves a fresh sibling', (tester) async {
    final seedCreatedAt = DateTime(2020, 1, 1);
    // MONTHLY (not daily/weekly) keeps _needsDate true, so _save preserves the
    // start date rather than normalizing it to today.
    final seed = Reminder(
      id: 'rid',
      title: 'Original',
      notes: 'some notes',
      startDateTime: DateTime(2030, 6, 15, 9, 30),
      timeZone: 'UTC',
      rruleString: 'FREQ=MONTHLY',
      offsetMinutes: 15,
      snoozeMinutes: 30,
      isEnabled: false, // paused source: the copy must still start enabled
      isAlarm: false,
      snoozedUntil: DateTime(2030, 6, 15, 9, 40),
      createdAt: seedCreatedAt,
      updatedAt: seedCreatedAt,
    );
    final repo = _FakeRepo(seed);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
            path: '/dup',
            builder: (context, state) =>
                const AddEditReminderScreen(copyFromId: 'rid')),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [reminderRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        theme: themeFor(Brightness.light),
        routerConfig: router,
      ),
    ));

    // Push dup over home so `context.pop()` on save has somewhere to go, then
    // let the push transition and async `_load` settle. Avoid pumpAndSettle —
    // the loading spinner animates forever.
    router.push('/dup');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // A copy is a new reminder, not an edit.
    expect(find.text('New reminder'), findsOneWidget);
    expect(find.text('Edit reminder'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.saved, isNotNull);
    final s = repo.saved!;

    // New identity.
    expect(s.id, isNot('rid'));
    expect(s.id, isNotEmpty);

    // Fields copied verbatim from the source.
    expect(s.title, 'Original');
    expect(s.notes, 'some notes');
    expect(s.startDateTime, DateTime(2030, 6, 15, 9, 30));
    expect(s.rruleString, 'FREQ=MONTHLY');
    expect(s.offsetMinutes, 15);
    expect(s.snoozeMinutes, 30);
    expect(s.isAlarm, isFalse);

    // Snooze cleared, fresh timestamps, enabled even though the source paused.
    expect(s.snoozedUntil, isNull);
    expect(s.createdAt.isAfter(seedCreatedAt), isTrue);
    expect(s.updatedAt.isAfter(seedCreatedAt), isTrue);
    expect(s.isEnabled, isTrue);
  });
}
