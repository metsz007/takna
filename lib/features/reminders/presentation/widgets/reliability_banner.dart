import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../providers.dart';

/// Honest alarm-reliability banner. Warns (amber, tap → Settings) when a hard
/// permission is missing; optionally reassures (green) when all is well.
class ReliabilityBanner extends ConsumerWidget {
  const ReliabilityBanner({super.key, this.showWhenReliable = false});

  /// Detail screen shows the positive state; home only warns.
  final bool showWhenReliable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    // null while the async read resolves → treat as reliable so no warning
    // flashes before we actually know.
    final reliable = ref.watch(reliabilityProvider).value?.reliable ?? true;

    if (reliable) {
      if (!showWhenReliable) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration:
            BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.verified_user_outlined, size: 18, color: t.ok),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Notifications and exact alarms are on — Takna is set to ring on time.',
                style: body(12, FontWeight.w500, t.ink2, height: 1.4)),
          ),
        ]),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/settings'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
            color: t.accentSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: t.accentInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Notifications or exact alarms are off — your alarms may not ring. Tap to fix.',
                style: body(12, FontWeight.w600, t.accentInk, height: 1.4)),
          ),
        ]),
      ),
    );
  }
}
