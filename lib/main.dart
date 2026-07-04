import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/reminders/presentation/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status/nav bars (the splash generator's theme edits
  // otherwise leave an opaque status bar strip).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    // Android otherwise paints a darkening scrim over the bars "for contrast",
    // which reads as an opaque band on top of the wave background.
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  ));
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer();
  container.read(themeModeProvider.notifier).load(prefs);
  final notifications = container.read(notificationServiceProvider);
  await notifications.init();
  // Re-arm the rolling notification window on every launch (self-healing).
  container.read(schedulerProvider).reconcile();

  final app = TaknaApp(onboarded: prefs.getBool('onboarded') ?? false);
  // Full-screen intent / tap launched us while ringing → open the alarm UI.
  final launchPayload = await notifications.launchPayload();
  if (launchPayload != null) app.router.go('/alarm', extra: launchPayload);
  // Alarm fires while the app is alive → same screen.
  notifications.onForegroundResponse = (r) {
    if (r.actionId == null) app.router.go('/alarm', extra: r.payload);
  };
  runApp(UncontrolledProviderScope(container: container, child: app));
}

class TaknaApp extends ConsumerWidget {
  TaknaApp({super.key, required bool onboarded})
      : router = buildRouter(onboarded: onboarded);
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Takna',
        theme: themeFor(Brightness.light),
        darkTheme: themeFor(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      );
}
