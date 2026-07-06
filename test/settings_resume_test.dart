import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takna/core/theme/theme.dart';
import 'package:takna/features/settings/presentation/settings_screen.dart';

// permission_handler's method channel. checkPermissionStatus returns an int
// index into PermissionStatus: 0 = denied, 1 = granted.
const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  // Flipped between denied (0) and granted (1) to simulate the user changing a
  // permission in the system settings app while Takna is backgrounded.
  var status = 0;

  setUp(() {
    status = 0;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'checkPermissionStatus') return status;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('permission rows refresh on app lifecycle resume', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: themeFor(Brightness.light),
        home: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Initially denied: rows show the "Allow" button, no "Granted" chip.
    expect(find.text('Allow'), findsWidgets);
    expect(find.text('Granted'), findsNothing);

    // User grants the permissions in the system settings app, then returns.
    status = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Granted'), findsWidgets);
    expect(find.text('Allow'), findsNothing);
  });
}
