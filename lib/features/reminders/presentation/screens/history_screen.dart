import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/theme/widgets.dart';
import '../providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  // Same helper as the detail screen — not worth a shared util for two sites.
  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) return 'Today';
    if (DateUtils.isSameDay(d, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat(d.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y')
        .format(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final report = ref.watch(alarmReportProvider);
    return Scaffold(
      body: SafeArea(
        child: report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text("Couldn't load alarm history",
                style: body(14, FontWeight.w600, t.ink2)),
          ),
          data: (r) => ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(children: [
                  TkIconButton(
                      icon: Icons.arrow_back_ios_new, onTap: () => context.pop()),
                  const SizedBox(width: 14),
                  Text('Alarm history', style: body(22, FontWeight.w800, t.ink)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: TkHero(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child:
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        r.streakDays > 0
                            ? '🔥 ${r.streakDays}-day streak'
                            : 'No streak yet',
                        style: display(24, FontWeight.w700, t.heroInk, spacing: -.3)),
                    const SizedBox(height: 6),
                    Text(
                        r.missed.isEmpty
                            ? 'Every alarm rang'
                            : 'Some alarms had no ring recorded',
                        style: body(13, FontWeight.w500, t.heroSub)),
                  ]),
                ),
              ),
              const TkSectionLabel('No ring recorded'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TkCard(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: r.missed.isEmpty
                      ? _row('No missed alarms in the last 7 days', null, t.ink3, t)
                      : Column(
                          children: [
                            for (final m in r.missed)
                              _row(
                                  m.title,
                                  '${_dayLabel(m.at)} · ${DateFormat('h:mm a').format(m.at)}',
                                  t.ink,
                                  t),
                          ],
                        ),
                ),
              ),
              const TkSectionLabel('Summary'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TkCard(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(children: [
                    _row('Rang', '${r.countsByKind['fired'] ?? 0}', t.ink, t),
                    _row('Dismissed', '${r.countsByKind['dismissed'] ?? 0}', t.ink, t),
                    _row('Snoozed', '${r.countsByKind['snoozed'] ?? 0}', t.ink, t),
                  ]),
                ),
              ),
              const TkSectionLabel('Recent'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TkCard(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: r.log.isEmpty
                      ? _row('No alarm activity yet', null, t.ink3, t)
                      : Column(
                          children: [
                            for (final e in r.log.take(100))
                              _row(
                                  e.title,
                                  '${e.kind} · ${_dayLabel(e.firedAt)} '
                                      '${DateFormat('h:mm a').format(e.firedAt)}',
                                  t.ink,
                                  t),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // One list row: a bold-ish label and an optional muted trailing/sub line.
  Widget _row(String label, String? sub, Color labelColor, Tk t) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Row(children: [
          Expanded(
              child: Text(label, style: body(14, FontWeight.w600, labelColor))),
          if (sub != null) ...[
            const SizedBox(width: 12),
            Text(sub, style: body(12.5, FontWeight.w500, t.ink3)),
          ],
        ]),
      );
}
