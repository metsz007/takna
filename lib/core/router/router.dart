import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/reminders/presentation/screens/add_edit_reminder_screen.dart';
import '../../features/reminders/presentation/screens/alarm_screen.dart';
import '../../features/reminders/presentation/screens/home_screen.dart';
import '../../features/reminders/presentation/screens/reminder_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

CustomTransitionPage _fadePage(GoRouterState s, Widget child) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

GoRouter buildRouter({required bool onboarded}) => GoRouter(
      initialLocation: onboarded ? '/' : '/onboarding',
      routes: [
        // Tab shell: the bar is persistent chrome; only the body swaps.
        ShellRoute(
          builder: (_, state, child) => Scaffold(
            body: child,
            bottomNavigationBar:
                TkTabBar(current: state.uri.path == '/settings' ? 1 : 0),
          ),
          routes: [
            GoRoute(path: '/', pageBuilder: (_, s) => _fadePage(s, const HomeScreen())),
            GoRoute(
                path: '/settings',
                pageBuilder: (_, s) => _fadePage(s, const SettingsScreen())),
          ],
        ),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/add', builder: (_, _) => const AddEditReminderScreen()),
        GoRoute(
            path: '/edit/:id',
            builder: (_, s) =>
                AddEditReminderScreen(reminderId: s.pathParameters['id'])),
        GoRoute(
            path: '/detail/:id',
            builder: (_, s) =>
                ReminderDetailScreen(reminderId: s.pathParameters['id']!)),
        GoRoute(
            path: '/alarm',
            builder: (_, s) => AlarmScreen(payload: s.extra as String?)),
      ],
    );
