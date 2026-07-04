import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/reminders/presentation/screens/add_edit_reminder_screen.dart';
import '../../features/reminders/presentation/screens/alarm_screen.dart';
import '../../features/reminders/presentation/screens/home_screen.dart';
import '../../features/reminders/presentation/screens/reminder_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Transitions over the shared wave background (transparent scaffolds).
///
/// Tabs use fade-through: outgoing fades out in the first half, incoming
/// fades in during the second half — never both at full strength.
/// [slide] gives pushed screens (add/edit/detail) a right-to-left push:
/// the incoming page slides in from the right while the outgoing page
/// slides partly off to the left, moving together like one surface.
CustomTransitionPage _fadePage(GoRouterState s, Widget child,
        {bool slide = false}) =>
    CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        // "Being covered by a push": every page reacts the same way —
        // drift left and fade across the full push duration, in sync with
        // the incoming right-to-left slide.
        final secondaryCurved = CurvedAnimation(
            parent: secondaryAnimation, curve: Curves.easeInOutCubic);
        Widget covered(Widget w) => SlideTransition(
              position: Tween(begin: Offset.zero, end: const Offset(-.3, 0))
                  .animate(secondaryCurved),
              child: FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.0).animate(secondaryCurved),
                child: w,
              ),
            );

        if (slide) {
          // entry: slide in from the right
          return SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic)),
            child: covered(child),
          );
        }
        // entry (tabs): fade-through — in during the second half
        return FadeTransition(
          opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(.5, 1, curve: Curves.easeOut)),
          child: covered(child),
        );
      },
    );

GoRouter buildRouter({required bool onboarded}) => GoRouter(
      initialLocation: onboarded ? '/' : '/onboarding',
      routes: [
        // Tab shell: the bar is persistent chrome between tabs, but the
        // shell as a whole is a page — so a push (add/edit/detail) slides
        // the entire thing (content + tab bar) off to the left together.
        ShellRoute(
          pageBuilder: (_, state, child) => _fadePage(
            state,
            Scaffold(
              body: child,
              bottomNavigationBar:
                  TkTabBar(current: state.uri.path == '/settings' ? 1 : 0),
            ),
          ),
          routes: [
            GoRoute(path: '/', pageBuilder: (_, s) => _fadePage(s, const HomeScreen())),
            GoRoute(
                path: '/settings',
                pageBuilder: (_, s) => _fadePage(s, const SettingsScreen())),
          ],
        ),
        GoRoute(
            path: '/onboarding',
            pageBuilder: (_, s) => _fadePage(s, const OnboardingScreen())),
        GoRoute(
            path: '/add',
            pageBuilder: (_, s) =>
                _fadePage(s, const AddEditReminderScreen(), slide: true)),
        GoRoute(
            path: '/edit/:id',
            pageBuilder: (_, s) => _fadePage(
                s, AddEditReminderScreen(reminderId: s.pathParameters['id']),
                slide: true)),
        GoRoute(
            path: '/detail/:id',
            pageBuilder: (_, s) => _fadePage(
                s, ReminderDetailScreen(reminderId: s.pathParameters['id']!),
                slide: true)),
        GoRoute(
            path: '/alarm',
            pageBuilder: (_, s) =>
                _fadePage(s, AlarmScreen(payload: s.extra as String?))),
      ],
    );
