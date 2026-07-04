import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/theme.dart';
import '../../../core/theme/widgets.dart';
import '../../reminders/presentation/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  bool _notif = false;
  bool _alarm = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _notif = await Permission.notification.isGranted;
    _alarm = await Permission.scheduleExactAlarm.isGranted;
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ready = _notif && _alarm;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 40, 26, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(gradient: t.heroBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.schedule, size: 18, color: Color(0xFFE0A43B)),
              ),
              const SizedBox(width: 10),
              Text('Takna', style: body(18, FontWeight.w800, t.ink)),
            ]),
            const SizedBox(height: 38),
            Text('So Takna can wake you on time',
                style: body(27, FontWeight.w800, t.ink, height: 1.2)),
            const SizedBox(height: 12),
            Text(
              'Two quick permissions and every reminder will fire at the exact minute — reliably, even when your phone is asleep.',
              style: body(14, FontWeight.w400, t.ink2, height: 1.6),
            ),
            const SizedBox(height: 30),
            _PermCard(
              icon: Icons.notifications_outlined,
              title: 'Show notifications',
              blurb: 'Reminders appear on your lock screen and play the alarm sound.',
              granted: _notif,
              cta: 'Allow notifications',
              onGrant: () async {
                await ref.read(notificationServiceProvider).requestPermissions();
                _refresh();
              },
            ),
            const SizedBox(height: 12),
            _PermCard(
              icon: Icons.alarm_on_outlined,
              title: 'Exact alarms & reliability',
              blurb: 'Fire at the precise minute and ignore battery-saver, so nothing is missed.',
              granted: _alarm,
              cta: 'Allow exact alarms',
              onGrant: () async {
                await Permission.scheduleExactAlarm.request();
                await Permission.ignoreBatteryOptimizations.request();
                _refresh();
              },
            ),
            const Spacer(),
            Center(
                child: Text('You can change these anytime in Settings.',
                    style: body(11.5, FontWeight.w400, t.ink3))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _finish,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: ready ? t.heroBg : null,
                  color: ready ? null : t.field,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ready
                      ? const [
                          BoxShadow(
                              color: Color(0x80173B44),
                              blurRadius: 26,
                              offset: Offset(0, 12),
                              spreadRadius: -8)
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(ready ? 'Start using Takna' : 'Skip for now',
                    style: body(15, FontWeight.w700, ready ? t.heroInk : t.ink3)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.granted,
    required this.cta,
    required this.onGrant,
  });
  final IconData icon;
  final String title, blurb, cta;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return TkCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TkIconBox(icon: icon, size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: body(15, FontWeight.w700, t.ink)),
              const SizedBox(height: 3),
              Text(blurb, style: body(12.5, FontWeight.w400, t.ink2, height: 1.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 13),
        granted
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(13)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check, size: 15, color: t.ok),
                  const SizedBox(width: 7),
                  Text('Allowed', style: body(13.5, FontWeight.w700, t.ok)),
                ]),
              )
            : GestureDetector(
                onTap: onGrant,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration:
                      BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(13)),
                  alignment: Alignment.center,
                  child: Text(cta, style: body(13.5, FontWeight.w700, t.onAccent)),
                ),
              ),
      ]),
    );
  }
}
