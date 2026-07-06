import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/reminders/data/reminder_repository.dart';
import 'package:takna/features/reminders/presentation/providers.dart';
import 'package:takna/features/reminders/presentation/screens/reminder_detail_screen.dart';

/// Serves a fixed reminder to reminderByIdProvider (which reads getById and
/// watches watchAll). db/scheduler passed to super are never touched.
class _FakeRepo extends ReminderRepository {
  _FakeRepo(this.seed) : super(_db, Scheduler(_db, NotificationService()));
  static final _db = AppDatabase();
  final Reminder seed;

  @override
  Future<Reminder?> getById(String id) async => seed;
  @override
  Stream<List<Reminder>> watchAll() => Stream.value([seed]);
}

Reminder _seed({DateTime? snoozedUntil, required DateTime start}) {
  final created = DateTime(2020, 1, 1);
  return Reminder(
    id: 'rid',
    title: 'Take pills',
    startDateTime: start,
    timeZone: 'UTC',
    offsetMinutes: 0,
    snoozeMinutes: 5,
    isEnabled: true,
    isAlarm: true,
    createdAt: created,
    updatedAt: created,
    snoozedUntil: snoozedUntil,
  );
}

Future<void> _pump(WidgetTester tester, Reminder seed) async {
  final router = GoRouter(
    initialLocation: '/detail/rid',
    routes: [
      GoRoute(
          path: '/detail/:id',
          builder: (context, state) =>
              const ReminderDetailScreen(reminderId: 'rid')),
      GoRoute(path: '/edit/:id', builder: (context, state) => const SizedBox()),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      reminderRepositoryProvider.overrideWithValue(_FakeRepo(seed)),
    ],
    child: MaterialApp.router(
      theme: themeFor(Brightness.light),
      routerConfig: router,
    ),
  ));
  // Let the FutureProvider resolve. Avoid pumpAndSettle (loading spinner).
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  testWidgets('pending snooze earlier than next occurrence → SNOOZED + snooze time',
      (tester) async {
    final now = DateTime.now();
    final occurrence = now.add(const Duration(days: 2));
    final snooze = now.add(const Duration(minutes: 90));
    await _pump(tester, _seed(start: occurrence, snoozedUntil: snooze));

    expect(find.text('SNOOZED'), findsOneWidget);
    expect(find.text('NEXT ALARM'), findsNothing);
    expect(find.text(DateFormat('h:mm a').format(snooze)), findsWidgets);
  });

  testWidgets('no snooze → NEXT ALARM + occurrence time', (tester) async {
    final now = DateTime.now();
    final occurrence = now.add(const Duration(days: 2));
    await _pump(tester, _seed(start: occurrence));

    expect(find.text('NEXT ALARM'), findsOneWidget);
    expect(find.text('SNOOZED'), findsNothing);
    // Hero + the matching row in the "Next 5 occurrences" list.
    expect(find.text(DateFormat('h:mm a').format(occurrence)), findsWidgets);
  });
}
