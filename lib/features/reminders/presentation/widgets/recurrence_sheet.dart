import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/theme/widgets.dart';

class RecurrenceResult {
  const RecurrenceResult(this.rrule);
  final String? rrule; // null = one-time
}

/// Design's bottom sheet: preset rows + custom (interval stepper, unit
/// segment, weekday chips). Returns null if dismissed.
Future<RecurrenceResult?> showRecurrenceSheet(
    BuildContext context, String? current, DateTime anchor) {
  return showModalBottomSheet<RecurrenceResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => _RecurrenceSheet(current: current, anchor: anchor),
  );
}

const _weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class _RecurrenceSheet extends StatefulWidget {
  const _RecurrenceSheet({required this.current, required this.anchor});
  final String? current;
  final DateTime anchor;

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  bool _custom = false;
  int _interval = 1;
  String _freq = 'WEEKLY';
  late final Set<String> _days = {_weekdayCodes[widget.anchor.weekday - 1]};

  String get _customRule {
    var rule = 'FREQ=$_freq';
    if (_interval > 1) rule += ';INTERVAL=$_interval';
    if (_freq == 'WEEKLY' && _days.isNotEmpty) {
      rule += ';BYDAY=${_weekdayCodes.where(_days.contains).join(',')}';
    }
    return rule;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final presets = <(String, String?)>[
      ('Does not repeat', null),
      ('Daily', 'FREQ=DAILY'),
      ('Weekdays', 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
      ('Weekly', 'FREQ=WEEKLY;BYDAY=${_weekdayCodes[widget.anchor.weekday - 1]}'),
      ('Monthly', 'FREQ=MONTHLY'),
    ];

    Widget option(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: active ? t.accentSoft : t.surface,
              border: Border.all(color: active ? t.accent : t.line),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: body(14.5, FontWeight.w600, active ? t.accentInk : t.ink))),
              if (active) Icon(Icons.check, size: 19, color: t.accentInk),
            ]),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 8, bottom: 26 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 5,
            margin: const EdgeInsets.only(top: 6, bottom: 16),
            decoration:
                BoxDecoration(color: t.line2, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(child: Text('Repeat', style: body(18, FontWeight.w800, t.ink))),
              GestureDetector(
                onTap: () => Navigator.pop(
                    context, _custom ? RecurrenceResult(_customRule) : null),
                child: Text('Done', style: body(14, FontWeight.w700, t.accentInk)),
              ),
            ]),
          ),
          ...presets.map((p) => option(p.$1, !_custom && widget.current == p.$2,
              () => Navigator.pop(context, RecurrenceResult(p.$2)))),
          option('Custom', _custom, () => setState(() => _custom = !_custom)),
          if (_custom) ...[
            Container(
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EVERY', style: body(11, FontWeight.w600, t.ink3, spacing: .8)),
                const SizedBox(height: 11),
                Row(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      _step('−', () => setState(() => _interval = (_interval - 1).clamp(1, 99))),
                      SizedBox(
                        width: 34,
                        child: Center(
                            child: Text('$_interval', style: display(18, FontWeight.w700, t.ink))),
                      ),
                      _step('+', () => setState(() => _interval = (_interval + 1).clamp(1, 99))),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TkSegmented<String>(
                      options: const ['DAILY', 'WEEKLY', 'MONTHLY'],
                      value: _freq,
                      labelOf: (v) => switch (v) {
                        'DAILY' => 'days',
                        'WEEKLY' => 'weeks',
                        _ => 'months',
                      },
                      onChanged: (v) => setState(() => _freq = v),
                    ),
                  ),
                ]),
                if (_freq == 'WEEKLY') ...[
                  const SizedBox(height: 18),
                  Text('ON THESE DAYS', style: body(11, FontWeight.w600, t.ink3, spacing: .8)),
                  const SizedBox(height: 11),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        GestureDetector(
                          onTap: () => setState(() => _days.contains(_weekdayCodes[i])
                              ? _days.remove(_weekdayCodes[i])
                              : _days.add(_weekdayCodes[i])),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _days.contains(_weekdayCodes[i]) ? t.accent : t.surface,
                              border: Border.all(
                                  color: _days.contains(_weekdayCodes[i]) ? t.accent : t.line),
                            ),
                            alignment: Alignment.center,
                            child: Text(_weekdayLabels[i],
                                style: body(12, FontWeight.w700,
                                    _days.contains(_weekdayCodes[i]) ? t.onAccent : t.ink2)),
                          ),
                        ),
                    ],
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _step(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Text(label, style: body(20, FontWeight.w700, context.tk.ink))),
        ),
      );
}
