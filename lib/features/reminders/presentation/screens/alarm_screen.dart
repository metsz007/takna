import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/challenge.dart';
import '../providers.dart';

// ponytail: hardcoded presets — wire to a pref only if users ask. The
// reminder's own default is still the primary big button below.
const _snoozePresets = [5, 10, 30];

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
  // null = off / not yet loaded; 'math' = gate Dismiss behind a math problem.
  // Looked up async, so there's a microtask window where it's null (see plan).
  String? _challenge;
  // Non-null once Dismiss is tapped on a challenge reminder: the problem the
  // user must solve. Snooze is never gated by this.
  MathChallenge? _pending;
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    // Take over the ringing: cancel the notification (whose sound Android
    // stops as soon as the shade is opened) and loop the alarm sound
    // ourselves until Snooze/Dismiss is pressed.
    final p = parsePayload(widget.payload);
    // Honest "it rang and I saw it" marker — the ring UI is actually on screen.
    ref.read(databaseProvider).logFired(p.reminderId, p.title, 'fired');
    ref.read(notificationServiceProvider).cancel(p.id);
    // The OS notification may post a beat after we open (foreground-watcher
    // race) — cancel again once it has had time to appear.
    Timer(const Duration(seconds: 2),
        () => ref.read(notificationServiceProvider).cancel(p.id));
    // Ring-screen-only lookup: rings with the reminder's chosen soundKey and
    // reads its dismiss challenge in one fetch. A deleted/missing reminder →
    // sound null (default alarm) and _challenge null → no gate (fail open
    // toward being able to dismiss, never toward trapping).
    ref.read(reminderRepositoryProvider).getById(p.reminderId).then((r) {
      _native.invokeMethod('playAlarm', {'sound': r?.soundKey});
      if (mounted) setState(() => _challenge = r?.challenge);
    });
  }

  @override
  void dispose() {
    _native.invokeMethod('stopAlarm');
    _tick.cancel();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _native.invokeMethod('stopAlarm');
    // Re-arm the rolling window: dismissing a recurring alarm consumes one
    // pre-scheduled occurrence, so reconcile to refill it (architecture:
    // re-arm on alarm fire). A reconcile failure must never strand the user on
    // the ringing screen — leave regardless.
    try {
      await ref.read(schedulerProvider).reconcile();
    } finally {
      if (mounted) context.go('/');
    }
  }

  void _checkAnswer() {
    if (int.tryParse(_answer.text.trim()) == _pending!.answer) {
      _dismiss();
      return;
    }
    // Wrong: keep ringing, clear the field, and regenerate with a fresh seed so
    // the same value can't be resubmitted.
    setState(() =>
        _pending = generateMathChallenge(DateTime.now().microsecondsSinceEpoch));
    _answer.clear();
  }

  Future<void> _snooze(int minutes) async {
    final p = parsePayload(widget.payload);
    await _native.invokeMethod('stopAlarm');
    await ref.read(reminderRepositoryProvider).snooze(p.reminderId, minutes);
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
      // Scroll when cramped (short screen, or the challenge input's keyboard is
      // up) so the answer field can never be clipped/occluded — the Spacers
      // still centre the content when there's room.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
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
            // Quick presets: snooze by a chosen duration this once, without
            // touching the reminder's saved default (that's the big button).
            Row(children: [
              for (final m in _snoozePresets) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => _snooze(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x29F2EBDA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text('$m min',
                          style: body(13, FontWeight.w700, heroInk)),
                    ),
                  ),
                ),
                if (m != _snoozePresets.last) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 12),
            // Dismiss challenge (math): shown only after Dismiss is tapped on a
            // challenge reminder. Sits above the Dismiss button; the whole
            // Snooze row above stays active and ungated the entire time.
            if (_pending != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x29F2EBDA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  Text('${_pending!.prompt} = ?',
                      key: const Key('challengePrompt'),
                      style: body(20, FontWeight.w700, heroInk)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _answer,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: body(18, FontWeight.w700, heroInk),
                    decoration: InputDecoration(
                      hintText: 'Answer',
                      hintStyle: body(15, FontWeight.w500, heroSub),
                      filled: true,
                      fillColor: const Color(0x1AF2EBDA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _checkAnswer,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: amber,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text('Check',
                          style: body(15, FontWeight.w700, const Color(0xFF173B44))),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _snooze(p.snoozeMinutes),
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
                  onTap: () {
                    // No challenge → dismiss immediately (today's behavior).
                    // Otherwise reveal the math problem; the actual dismissal
                    // only runs on a correct answer (_checkAnswer → _dismiss).
                    if (_challenge != 'math') {
                      _dismiss();
                      return;
                    }
                    setState(() => _pending = generateMathChallenge(
                        DateTime.now().microsecondsSinceEpoch));
                  },
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
            ),
          ),
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
