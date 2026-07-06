import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/notifications/notification_service.dart';
import 'core/router/router.dart';
import 'core/scheduler/foreground_alarm_watcher.dart';
import 'core/theme/theme.dart';
import 'core/theme/wave_background.dart';
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
  final db = container.read(databaseProvider);
  // Full-screen intent / tap launched us: alarm reminders ring, plain
  // notification reminders open their detail page (routeNotificationTap).
  final launchPayload = await notifications.launchPayload();
  if (launchPayload != null) {
    try {
      await routeNotificationTap(launchPayload, db, app.router.go);
    } catch (_) {
      // A DB read that throws before runApp must not black-hole the launch —
      // fall back to the old behavior (always open the alarm screen).
      app.router.go('/alarm', extra: launchPayload);
    }
  }
  // Tap or action button while the app is alive: route body taps, apply
  // Snooze/Dismiss actions (these were previously dropped).
  notifications.onForegroundResponse = (r) => dispatchNotificationResponse(
      r.actionId, r.payload, db, notifications, app.router.go);
  // Foreground firing: Android won't full-screen while the app is active,
  // so a Dart timer takes the app to the alarm screen itself.
  ForegroundAlarmWatcher(container, app.router).start();
  runApp(UncontrolledProviderScope(container: container, child: app));
}

class TaknaApp extends ConsumerStatefulWidget {
  TaknaApp({super.key, required bool onboarded})
      : router = buildRouter(onboarded: onboarded);
  final GoRouter router;

  @override
  ConsumerState<TaknaApp> createState() => _TaknaAppState();
}

class _TaknaAppState extends ConsumerState<TaknaApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The only resume hook the reliability UI needs: re-read permissions when
    // the user returns from system settings so home + detail refresh together.
    // ponytail: settings' own _load-on-resume is a separate audit item, not this.
    _lifecycle = AppLifecycleListener(
        onResume: () => ref.invalidate(reliabilityProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Takna',
        theme: themeFor(Brightness.light),
        darkTheme: themeFor(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: widget.router,
        debugShowCheckedModeBanner: false,
        // One wave background behind the whole navigator — screens are
        // transparent layers over it, so it never resets or re-mounts.
        builder: (context, child) => WaveBackground(
          animate: true,
          dark: Theme.of(context).brightness == Brightness.dark,
          child: child,
        ),
      );
}
