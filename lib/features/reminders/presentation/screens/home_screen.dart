import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider (riverpod 3 legacy)
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/widgets.dart';
import '../../domain/recurrence.dart';
import '../providers.dart';
import '../widgets/reliability_banner.dart';

/// Distinct non-null tags in use, sorted for a stable chip order. Derived in
/// memory from the watched list — never stored (CLAUDE.md: no derived data).
List<String> distinctTags(List<Reminder> rs) =>
    (rs.map((r) => r.tag).whereType<String>().toSet().toList()..sort());

/// Transient home filter: null = "All". Not persisted — reopening shows All.
final tagFilterProvider = StateProvider<String?>((ref) => null);

String _countdown(DateTime d) {
  final diff = d.difference(DateTime.now());
  if (diff.isNegative) return 'now';
  final mins = diff.inMinutes;
  if (mins < 60) return 'in ${mins}m';
  final h = mins ~/ 60, m = mins % 60;
  return m > 0 ? 'in ${h}h ${m}m' : 'in ${h}h';
}

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(d, now)) return 'Today';
  if (DateUtils.isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
  return DateFormat(d.year == now.year ? 'EEE, MMM d' : 'EEE, MMM d, y').format(d);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final reminders = ref.watch(remindersStreamProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: reminders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Something went wrong loading your reminders',
                style: body(14, FontWeight.w600, t.ink2))),
          data: (list) => list.isEmpty ? const _EmptyState() : _HomeList(list),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => context.push('/add'),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: t.accent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x99E0A43B), blurRadius: 26, offset: Offset(0, 14), spreadRadius: -6)
              ],
            ),
            child: const Icon(Icons.add, color: Color(0xFF173B44), size: 28),
          ),
        ),
      ),
    );
  }
}

/// Shared bottom tab bar (Reminders / Settings).
class TkTabBar extends StatelessWidget {
  const TkTabBar({super.key, required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget tab(int i, IconData icon, String label, String route) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => i == current ? null : context.go(route),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: i == current ? t.accent : t.ink3),
            const SizedBox(height: 5),
            Text(label, style: body(10, FontWeight.w700, i == current ? t.ink : t.ink3)),
          ]),
        );
    return Container(
      decoration: BoxDecoration(color: t.navBg, border: Border(top: BorderSide(color: t.navLine))),
      child: SafeArea(
        top: false,
        child: Container(
          height: 68,
          padding: const EdgeInsets.only(top: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            tab(0, Icons.schedule, 'Reminders', '/'),
            tab(1, Icons.tune, 'Settings', '/settings'),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
            style: body(12.5, FontWeight.w600, t.ink2)),
        const SizedBox(height: 3),
        Text(greeting, style: body(25, FontWeight.w800, t.ink, height: 1.1)),
      ]),
    );
  }
}

class _HomeList extends ConsumerWidget {
  const _HomeList(this.reminders);
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final now = DateTime.now();
    final reliable = ref.watch(reliabilityProvider).value?.reliable ?? true;
    final tags = distinctTags(reminders);
    final raw = ref.watch(tagFilterProvider);
    final sel = tags.contains(raw) ? raw : null; // clamp stale selection → All
    final visible = sel == null
        ? reminders
        : [for (final r in reminders) if (r.tag == sel) r];
    ({Reminder r, DateTime at, bool snoozed})? hero;
    final nextAt = <String, ({DateTime at, bool snoozed})?>{};
    for (final r in visible) {
      final next = effectiveNextFire(r, now);
      nextAt[r.id] = next;
      if (r.isEnabled && next != null && (hero == null || next.at.isBefore(hero.at))) {
        hero = (r: r, at: next.at, snoozed: next.snoozed);
      }
    }
    final today = <Reminder>[];
    final upcoming = <Reminder>[];
    for (final r in visible) {
      final at = nextAt[r.id]?.at;
      (at != null && DateUtils.isSameDay(at, now) ? today : upcoming).add(r);
    }

    Widget section(String title, List<Reminder> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 11),
              child: Row(children: [
                Expanded(child: Text(title, style: body(13, FontWeight.w700, t.ink))),
                Text('${items.length}', style: body(12, FontWeight.w600, t.ink3)),
              ]),
            ),
            ...items.map((r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
                  child: _ReminderRow(r, nextAt[r.id]),
                )),
          ],
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const _Header(),
        const _PauseBanner(),
        if (tags.isNotEmpty) _TagChips(tags: tags, selected: sel),
        if (!reliable)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: ReliabilityBanner(),
          ),
        if (hero != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _HeroCard(hero.r, hero.at, hero.snoozed, reliable),
          ),
        if (today.isNotEmpty) section('Today', today),
        if (upcoming.isNotEmpty) section('Upcoming', upcoming),
      ],
    );
  }
}

/// Horizontally scrollable filter chips: "All" plus one per distinct tag.
/// ponytail: inline chips styled locally (like the weekday circles in add/edit),
/// not a new TkChip widget — one caller doesn't earn an abstraction.
class _TagChips extends ConsumerWidget {
  const _TagChips({required this.tags, required this.selected});
  final List<String> tags;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    Widget chip(String label, bool active, String? value) => GestureDetector(
          onTap: () => ref.read(tagFilterProvider.notifier).state = value,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? t.accent : t.field,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? t.accent : t.line),
            ),
            child: Text(label,
                style: body(13, FontWeight.w600, active ? t.onAccent : t.ink2)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip('All', selected == null, null),
          for (final tag in tags) chip(tag, tag == selected, tag),
        ]),
      ),
    );
  }
}

/// Unmissable "all alarms paused" banner. A silent pause is the worst bug in
/// this app's terms, so this is loud (accent-filled) with an inline Resume.
/// Renders nothing when not paused; a stale past pausedUntil counts as not
/// paused.
class _PauseBanner extends ConsumerWidget {
  const _PauseBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final raw = ref.watch(pausedUntilProvider).value;
    if (raw == null || !raw.isAfter(DateTime.now())) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
        decoration:
            BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.pause_circle_filled, size: 20, color: Color(0xFF173B44)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
                'All alarms paused until ${DateFormat('MMM d, y').format(raw)}',
                style: body(13, FontWeight.w700, const Color(0xFF173B44), height: 1.35)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await ref.read(reminderRepositoryProvider).setPausedUntil(null);
              ref.invalidate(pausedUntilProvider);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                  color: const Color(0xFF173B44),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('Resume', style: body(12, FontWeight.w700, Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(this.reminder, this.at, this.snoozed, this.reliable);
  final Reminder reminder;
  final DateTime at;
  final bool snoozed;
  final bool reliable;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final time = DateFormat('h:mm').format(at);
    final suffix = DateFormat('a').format(at);
    return GestureDetector(
      onTap: () => context.push('/detail/${reminder.id}'),
      child: TkHero(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(snoozed ? 'SNOOZED' : 'NEXT REMINDER',
                    style: body(10, FontWeight.w700, t.accent, spacing: 1.5))),
            TkBadge(snoozed ? 'Snoozed' : recurrenceLabel(reminder.rruleString),
                filled: true),
          ]),
          const SizedBox(height: 13),
          Text(reminder.title, style: body(19, FontWeight.w700, t.heroInk)),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(time, style: display(42, FontWeight.w700, Colors.white, spacing: -1)),
                    const SizedBox(width: 5),
                    Text(suffix, style: display(15, FontWeight.w600, t.heroSub)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration:
                    BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(20)),
                child: Text(_countdown(at),
                    style: body(12, FontWeight.w700, const Color(0xFF173B44))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            reliable
                ? Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Color(0x38E0A43B), spreadRadius: 3)],
                    ),
                  )
                : Icon(Icons.warning_amber_rounded, size: 13, color: t.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  !reliable
                      ? 'Alarm set · may not ring until you fix permissions'
                      : reminder.isAlarm
                          ? 'Alarm set · notifies even when your phone is locked'
                          : 'Notification set · sounds once at the scheduled time',
                  style: body(11, FontWeight.w500, t.heroSub)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow(this.reminder, this.next);
  final Reminder reminder;
  final ({DateTime at, bool snoozed})? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final at = next?.at;
    final snoozed = next?.snoozed ?? false;
    final when = at == null
        ? 'No upcoming'
        : DateUtils.isSameDay(at, DateTime.now())
            ? DateFormat('h:mm a').format(at)
            : '${_dayLabel(at)} · ${DateFormat('h:mm a').format(at)}';
    return TkCard(
      onTap: () => context.push('/detail/${reminder.id}'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(children: [
        TkIconBox(icon: snoozed ? Icons.snooze : Icons.notifications_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reminder.title,
                style: body(14, FontWeight.w600, t.ink), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Flexible(child: Text(when, style: display(12, FontWeight.w600, t.ink2))),
              const SizedBox(width: 7),
              if (snoozed) ...[
                const TkBadge('Snoozed', filled: true),
                const SizedBox(width: 5),
              ],
              TkBadge(recurrenceLabel(reminder.rruleString)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        TkToggle(
          value: reminder.isEnabled,
          onChanged: (v) => ref.read(reminderRepositoryProvider).setEnabled(reminder.id, v),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Header(),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 104,
              height: 104,
              decoration:
                  BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.schedule, size: 46, color: t.ic1),
            ),
            const SizedBox(height: 26),
            Text('No reminders yet', style: body(20, FontWeight.w700, t.ink)),
            const SizedBox(height: 9),
            SizedBox(
              width: 230,
              child: Text(
                'Add your first reminder and Takna will make sure it wakes you — on time, every time.',
                textAlign: TextAlign.center,
                style: body(13.5, FontWeight.w400, t.ink2, height: 1.55),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.push('/add'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x99E0A43B),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                        spreadRadius: -6)
                  ],
                ),
                child: Text('Add a reminder',
                    style: body(14, FontWeight.w700, t.onAccent)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
