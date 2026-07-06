import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/theme/theme.dart';
import '../providers.dart';

/// Full-screen ringing UI, launched over the lock screen by the
/// notification's full-screen intent (payload arrives via route extra).
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key, required this.payload});
  final String? payload;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  static const _native = MethodChannel('takna/settings');
  late Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    // Take over the ringing: cancel the notification (whose sound Android
    // stops as soon as the shade is opened) and loop the alarm sound
    // ourselves until Snooze/Dismiss is pressed.
    final p = parsePayload(widget.payload);
    ref.read(notificationServiceProvider).cancel(p.id);
    // The OS notification may post a beat after we open (foreground-watcher
    // race) — cancel again once it has had time to appear.
    Timer(const Duration(seconds: 2),
        () => ref.read(notificationServiceProvider).cancel(p.id));
    _native.invokeMethod('playAlarm');
  }

  @override
  void dispose() {
    _native.invokeMethod('stopAlarm');
    _tick.cancel();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _native.invokeMethod('stopAlarm');
    // Re-arm the rolling window: dismissing a recurring alarm consumes one
    // pre-scheduled occurrence, so reconcile to refill it (architecture:
    // re-arm on alarm fire).
    await ref.read(schedulerProvider).reconcile();
    if (mounted) context.go('/');
  }

  Future<void> _snooze() async {
    final p = parsePayload(widget.payload);
    await _native.invokeMethod('stopAlarm');
    await ref
        .read(reminderRepositoryProvider)
        .snooze(p.reminderId, p.snoozeMinutes);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final p = parsePayload(widget.payload);
    final now = DateTime.now();
    const heroInk = Color(0xFFF2EBDA);
    const heroSub = Color(0xB3F2EBDA);
    const amber = Color(0xFFE0A43B);
    return Scaffold(
      backgroundColor: const Color(0xFF173B44),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(children: [
            const Spacer(),
            // pulsing bell
            _Pulse(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0x29E0A43B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active, size: 44, color: amber),
              ),
            ),
            const SizedBox(height: 36),
            Text('REMINDER', style: body(11, FontWeight.w700, amber, spacing: 2)),
            const SizedBox(height: 12),
            Text(p.title,
                textAlign: TextAlign.center,
                style: body(28, FontWeight.w800, heroInk, height: 1.2)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(DateFormat('h:mm').format(now),
                    style: display(64, FontWeight.w700, Colors.white, spacing: -2)),
                const SizedBox(width: 8),
                Text(DateFormat('a').format(now),
                    style: display(22, FontWeight.w600, heroSub)),
              ],
            ),
            const Spacer(),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _snooze,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0x29F2EBDA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text('Snooze ${p.snoozeMinutes} min',
                        style: body(15, FontWeight.w700, heroInk)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: amber,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x80E0A43B),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                            spreadRadius: -6)
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('Dismiss',
                        style: body(15, FontWeight.w700, const Color(0xFF173B44))),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: .92, end: 1.08)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: widget.child,
      );
}
