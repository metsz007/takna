import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/reminders/presentation/providers.dart';
import 'package:takna/features/reminders/presentation/widgets/reliability_banner.dart';

Future<void> _pump(
  WidgetTester tester,
  ReliabilityStatus status, {
  required bool showWhenReliable,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      reliabilityProvider.overrideWith((ref) async => status),
    ],
    child: MaterialApp(
      theme: themeFor(Brightness.light),
      home: Scaffold(
        body: ReliabilityBanner(showWhenReliable: showWhenReliable),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

const _warning = 'your alarms may not ring';
const _reliable = 'set to ring on time';

void main() {
  testWidgets('reliable + showWhenReliable → green copy, no warning', (tester) async {
    await _pump(tester, const ReliabilityStatus(true, true), showWhenReliable: true);
    expect(find.textContaining(_reliable), findsOneWidget);
    expect(find.textContaining(_warning), findsNothing);
  });

  testWidgets('notifications denied → warning shown, no green copy', (tester) async {
    await _pump(tester, const ReliabilityStatus(false, true), showWhenReliable: true);
    expect(find.textContaining(_warning), findsOneWidget);
    expect(find.textContaining(_reliable), findsNothing);
  });

  testWidgets('exact alarms denied → warning shown', (tester) async {
    await _pump(tester, const ReliabilityStatus(true, false), showWhenReliable: true);
    expect(find.textContaining(_warning), findsOneWidget);
  });

  testWidgets('reliable without showWhenReliable → renders nothing', (tester) async {
    await _pump(tester, const ReliabilityStatus(true, true), showWhenReliable: false);
    expect(find.byType(GestureDetector), findsNothing);
    expect(find.textContaining(_warning), findsNothing);
    expect(find.textContaining(_reliable), findsNothing);
  });
}
