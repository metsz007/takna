import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/theme/widgets.dart';
import '../../domain/recurrence.dart';
import '../providers.dart';
import '../widgets/reliability_banner.dart';

class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.reminderId});
  final String reminderId;

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) return 'Today';
    if (DateUtils.isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat(d.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final reminder = ref.watch(reminderByIdProvider(reminderId));
    return Scaffold(
      body: SafeArea(
        child: reminder.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text("Couldn't load this reminder",
                style: body(14, FontWeight.w600, t.ink2))),
          data: (r) {
            if (r == null) return const Center(child: Text('Reminder not found'));
            final now = DateTime.now();
            final next5 = nextOccurrences(r, now, 5);
            // A pending snooze wins if it comes before the next regular
            // occurrence (mirrors _HomeList). Occurrence list below stays RRULE.
            final snooze = r.snoozedUntil;
            final snoozed = snooze != null &&
                snooze.isAfter(now) &&
                (next5.isEmpty || snooze.isBefore(next5.first));
            final nextFire = snoozed ? snooze : (next5.isEmpty ? null : next5.first);
            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: Row(children: [
                    TkIconButton(icon: Icons.arrow_back_ios_new, onTap: () => context.pop()),
                    const Spacer(),
                    TkIconButton(
                      icon: Icons.delete_outline,
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text('Delete reminder?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await ref.read(reminderRepositoryProvider).delete(reminderId);
                          if (context.mounted) context.pop();
                        }
                      },
                    ),
                    const SizedBox(width: 9),
                    GestureDetector(
                      onTap: () => context.push('/edit/$reminderId'),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                            color: t.accent, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF173B44)),
                          const SizedBox(width: 7),
                          Text('Edit', style: body(13, FontWeight.w700, const Color(0xFF173B44))),
                        ]),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: t.accentSoft, borderRadius: BorderRadius.circular(8)),
                        child: Text(recurrenceLabel(r.rruleString).toUpperCase(),
                            style: body(10, FontWeight.w600, t.accentInk, spacing: 1)),
                      ),
                      const SizedBox(width: 9),
                      Text(r.isEnabled ? 'Active' : 'Paused',
                          style: body(12, FontWeight.w500, r.isEnabled ? t.ok : t.ink3)),
                    ]),
                    const SizedBox(height: 14),
                    Text(r.title, style: body(27, FontWeight.w800, t.ink, height: 1.15)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: TkHero(
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(snoozed ? 'SNOOZED' : 'NEXT ALARM',
                          style: body(10, FontWeight.w700, t.accent, spacing: 1.4)),
                      const SizedBox(height: 8),
                      nextFire == null
                          ? Text('No upcoming occurrences',
                              style: body(15, FontWeight.w700, t.heroInk))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(_dayLabel(nextFire),
                                    style: body(15, FontWeight.w700, t.heroInk)),
                                const SizedBox(width: 8),
                                Text(DateFormat('h:mm a').format(nextFire),
                                    style:
                                        display(30, FontWeight.w700, Colors.white, spacing: -.5)),
                              ],
                            ),
                    ]),
                  ),
                ),
                if (r.notes != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: TkCard(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('NOTES', style: body(10, FontWeight.w600, t.ink3, spacing: 1)),
                        const SizedBox(height: 7),
                        Text(r.notes!, style: body(14, FontWeight.w400, t.ink, height: 1.55)),
                      ]),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                  child: Row(children: [
                    Text('Next 5 occurrences', style: body(13, FontWeight.w700, t.ink)),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_outline, size: 15, color: t.ok),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    for (var i = 0; i < next5.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                        decoration:
                            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                        child: Row(children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                                color: t.accentSoft, borderRadius: BorderRadius.circular(8)),
                            alignment: Alignment.center,
                            child:
                                Text('${i + 1}', style: display(11, FontWeight.w700, t.accentInk)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Text(_dayLabel(next5[i]),
                                  style: body(14, FontWeight.w600, t.ink))),
                          Text(DateFormat('h:mm a').format(next5[i]),
                              style: display(13, FontWeight.w600, t.ink2)),
                        ]),
                      ),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: ReliabilityBanner(showWhenReliable: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
