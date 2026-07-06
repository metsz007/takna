import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/reminders/presentation/providers.dart';
import 'package:takna/features/reminders/presentation/screens/home_screen.dart';

Reminder _reminder({required bool isAlarm}) {
  final created = DateTime(2020, 1, 1);
  return Reminder(
    id: 'rid',
    title: 'Take pills',
    startDateTime: DateTime.now().add(const Duration(hours: 2)),
    timeZone: 'UTC',
    offsetMinutes: 0,
    snoozeMinutes: 5,
    isEnabled: true,
    isAlarm: isAlarm,
    createdAt: created,
    updatedAt: created,
  );
}

Future<void> _pump(WidgetTester tester, {required bool isAlarm}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      remindersStreamProvider
          .overrideWith((ref) => Stream.value([_reminder(isAlarm: isAlarm)])),
      reliabilityProvider
          .overrideWith((ref) async => const ReliabilityStatus(true, true)),
    ],
    child: MaterialApp(
      theme: themeFor(Brightness.light),
      home: const HomeScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('alarm hero → locked-screen copy', (tester) async {
    await _pump(tester, isAlarm: true);
    expect(find.textContaining('notifies even when your phone is locked'),
        findsOneWidget);
  });

  testWidgets('notification-style hero → sounds-once copy, no alarm claim',
      (tester) async {
    await _pump(tester, isAlarm: false);
    expect(find.textContaining('notifies even when your phone is locked'),
        findsNothing);
    expect(find.textContaining('sounds once at the scheduled time'),
        findsOneWidget);
  });
}
