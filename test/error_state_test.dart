import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/reminders/presentation/providers.dart';
import 'package:takna/features/reminders/presentation/screens/home_screen.dart';

void main() {
  testWidgets('stream error → friendly message, no raw exception', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        remindersStreamProvider
            .overrideWith((ref) => Stream.error(Exception('boom-db-explosion'))),
      ],
      child: MaterialApp(
        theme: themeFor(Brightness.light),
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Something went wrong loading your reminders'),
        findsOneWidget);
    expect(find.textContaining('boom-db-explosion'), findsNothing);
  });
}
