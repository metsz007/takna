import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/widgets.dart';
import '../../domain/recurrence.dart';
import '../providers.dart';
import '../widgets/recurrence_sheet.dart';

class AddEditReminderScreen extends ConsumerStatefulWidget {
  const AddEditReminderScreen({super.key, this.reminderId});
  final String? reminderId;

  @override
  ConsumerState<AddEditReminderScreen> createState() => _AddEditState();
}

class _AddEditState extends ConsumerState<AddEditReminderScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  String? _rrule;
  int _offset = 0;
  int _snooze = 5;
  bool _isAlarm = true;
  bool _loaded = false;
  // Preserved across an edit so saving doesn't re-enable a paused reminder or
  // reset its creation date. Defaults hold for create mode.
  bool _isEnabled = true;
  DateTime? _createdAt;

  bool get isEdit => widget.reminderId != null;

  // Alarm-clock pattern: for daily/weekly repeats the date is meaningless —
  // only the time (and weekdays) matter. Date stays for once/monthly/yearly.
  bool get _isWeekly => _rrule?.contains('FREQ=WEEKLY') ?? false;
  bool get _isDaily => _rrule?.contains('FREQ=DAILY') ?? false;
  bool get _needsDate => !_isWeekly && !_isDaily;

  static const _weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Set<String> get _byday {
    final m = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(_rrule ?? '');
    return m == null ? {} : m.group(1)!.split(',').toSet();
  }

  void _toggleDay(String code) {
    final days = _byday;
    if (days.contains(code)) {
      if (days.length == 1) return; // keep at least one day
      days.remove(code);
    } else {
      days.add(code);
    }
    final ordered = _weekdayCodes.where(days.contains).join(',');
    final without = _rrule!.replaceAll(RegExp(r';?BYDAY=[A-Z,]+'), '');
    setState(() => _rrule = '$without;BYDAY=$ordered');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (isEdit) {
      final r = await ref.read(reminderRepositoryProvider).getById(widget.reminderId!);
      if (r != null) {
        _title.text = r.title;
        _notes.text = r.notes ?? '';
        _date = r.startDateTime;
        _rrule = r.rruleString;
        _offset = r.offsetMinutes;
        _snooze = r.snoozeMinutes;
        _isAlarm = r.isAlarm;
        _isEnabled = r.isEnabled;
        _createdAt = r.createdAt;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      _offset = prefs.getInt('defaultOffset') ?? 0;
      _snooze = prefs.getInt('defaultSnooze') ?? 5;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final t = context.tk;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Give it a title', style: body(13, FontWeight.w600, t.heroInk)),
          backgroundColor: t.ink));
      return;
    }
    final now = DateTime.now();
    // Dateless repeats anchor at today at the chosen time; RRULE expansion
    // finds the next matching weekday from there.
    if (!_needsDate) {
      _date = DateTime(now.year, now.month, now.day, _date.hour, _date.minute);
    }
    final r = Reminder(
      id: widget.reminderId ?? const Uuid().v4(),
      title: _title.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      startDateTime: _date,
      timeZone: tz.local.name,
      rruleString: _rrule,
      offsetMinutes: _offset,
      snoozeMinutes: _snooze,
      isEnabled: _isEnabled,
      isAlarm: _isAlarm,
      createdAt: _createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(reminderRepositoryProvider).save(r);
    if (mounted) context.pop();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (t == null) return;
    setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (t == null) return;
    setState(() =>
        _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // header: X · title · Save
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Row(children: [
                TkIconButton(icon: Icons.close, onTap: () => context.pop()),
                Expanded(
                  child: Center(
                    child: Text(isEdit ? 'Edit reminder' : 'New reminder',
                        style: body(15, FontWeight.w700, t.ink)),
                  ),
                ),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration:
                        BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(12)),
                    child: Text('Save', style: body(14, FontWeight.w700, t.onAccent)),
                  ),
                ),
              ]),
            ),
            // borderless title + notes
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(children: [
                TextField(
                  controller: _title,
                  autofocus: !isEdit,
                  style: body(24, FontWeight.w700, t.ink),
                  decoration: InputDecoration(
                    hintText: 'Reminder title',
                    hintStyle: body(24, FontWeight.w700, t.ink3),
                    border: InputBorder.none,
                  ),
                ),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  style: body(14, FontWeight.w400, t.ink2, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Add notes (optional)',
                    hintStyle: body(14, FontWeight.w400, t.ink3),
                    border: InputBorder.none,
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(children: [
                // repeat first — it decides what the rest of the form asks for
                TkCard(
                  onTap: () async {
                    final result = await showRecurrenceSheet(context, _rrule, _date);
                    if (result != null) setState(() => _rrule = result.rrule);
                  },
                  padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                  child: Row(children: [
                    Icon(Icons.repeat, size: 20, color: t.ic1),
                    const SizedBox(width: 13),
                    Expanded(child: Text('Repeat', style: body(14, FontWeight.w600, t.ink))),
                    Text(_rrule == null ? 'Does not repeat' : recurrenceLabel(_rrule),
                        style: body(13, FontWeight.w600, t.accentInk)),
                    Icon(Icons.chevron_right, size: 16, color: t.ink3),
                  ]),
                ),
                const SizedBox(height: 11),
                // when card: full date for once/monthly, time-only for daily/weekly
                TkCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _needsDate ? _pickDateTime : _pickTime,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                        decoration:
                            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                        child: Row(children: [
                          Icon(
                              _needsDate
                                  ? Icons.calendar_today_outlined
                                  : Icons.access_time,
                              size: 20,
                              color: t.ic1),
                          const SizedBox(width: 13),
                          Expanded(
                              child: Text(_needsDate ? 'Date & time' : 'Time',
                                  style: body(14, FontWeight.w600, t.ink))),
                          if (_needsDate) ...[
                            Text(_dayShort(_date), style: body(13, FontWeight.w600, t.ink2)),
                            const SizedBox(width: 9),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: t.accentSoft, borderRadius: BorderRadius.circular(8)),
                            child: Text(DateFormat('h:mm a').format(_date),
                                style: display(13, FontWeight.w600, t.accentInk)),
                          ),
                        ]),
                      ),
                    ),
                    if (_isWeekly)
                      Container(
                        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                        decoration:
                            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < _weekdayCodes.length; i++)
                              GestureDetector(
                                onTap: () => _toggleDay(_weekdayCodes[i]),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _byday.contains(_weekdayCodes[i])
                                        ? t.accent
                                        : t.field,
                                    border: Border.all(
                                        color: _byday.contains(_weekdayCodes[i])
                                            ? t.accent
                                            : t.line),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(_weekdayLabels[i],
                                      style: body(
                                          12,
                                          FontWeight.w700,
                                          _byday.contains(_weekdayCodes[i])
                                              ? t.onAccent
                                              : t.ink2)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
                      child: Row(children: [
                        Icon(Icons.notifications_outlined, size: 20, color: t.ic1),
                        const SizedBox(width: 13),
                        Expanded(
                            child: Text('Remind me', style: body(14, FontWeight.w600, t.ink))),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: TkSegmented<int>(
                        options: const [0, 5, -1],
                        value: _offset == 0 || _offset == 5 ? _offset : -1,
                        labelOf: (v) => switch (v) {
                          0 => 'At time',
                          5 => '5 min before',
                          _ => _offset > 5 ? '$_offset min before' : 'Custom',
                        },
                        onChanged: (v) async {
                          if (v >= 0) return setState(() => _offset = v);
                          final custom = await _promptMinutes(context, 'Minutes before');
                          if (custom != null) setState(() => _offset = custom);
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 11),
                // alert style: full alarm vs plain notification
                TkCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.alarm, size: 20, color: t.ic1),
                      const SizedBox(width: 13),
                      Text('Alert style', style: body(14, FontWeight.w600, t.ink)),
                    ]),
                    const SizedBox(height: 12),
                    TkSegmented<bool>(
                      options: const [true, false],
                      value: _isAlarm,
                      labelOf: (v) => v ? 'Alarm' : 'Notification',
                      onChanged: (v) => setState(() => _isAlarm = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 11),
                // snooze card
                TkCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.snooze, size: 20, color: t.ic1),
                      const SizedBox(width: 13),
                      Text('Snooze duration', style: body(14, FontWeight.w600, t.ink)),
                    ]),
                    const SizedBox(height: 12),
                    TkSegmented<int>(
                      options: const [5, 10, 15, 30],
                      value: _snooze,
                      labelOf: (v) => '$v min',
                      onChanged: (v) => setState(() => _snooze = v),
                    ),
                  ]),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 13),
                  GestureDetector(
                    onTap: () async {
                      await ref.read(reminderRepositoryProvider).delete(widget.reminderId!);
                      if (context.mounted) context.go('/');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.line2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.delete_outline, size: 17, color: Color(0xFFC25B4A)),
                        const SizedBox(width: 8),
                        Text('Delete reminder',
                            style: body(14, FontWeight.w600, const Color(0xFFC25B4A))),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _dayShort(DateTime d) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(d, now)) return 'Today';
    if (DateUtils.isSameDay(d, now.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(d);
  }
}

Future<int?> _promptMinutes(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  return showDialog<int>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'min')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(d, int.tryParse(ctrl.text)),
            child: const Text('OK')),
      ],
    ),
  );
}
