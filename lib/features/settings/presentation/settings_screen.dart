import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/backup.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/widgets.dart';
import '../../reminders/presentation/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returned from the system settings app — re-probe permissions through
    // their providers (no direct channel reads; home + banner share these).
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(reliabilityProvider);
      ref.invalidate(batteryUnrestrictedProvider);
    }
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final prefs = _prefs;
    final themeMode = ref.watch(themeModeProvider);
    // Loading defaults to granted (same convention as ReliabilityBanner).
    final reliability = ref.watch(reliabilityProvider);
    final notifGranted = reliability.value?.notifications ?? true;
    final exactGranted = reliability.value?.exactAlarm ?? true;
    final batteryUnrestricted = ref.watch(batteryUnrestrictedProvider).value ?? false;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: prefs == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Text('Settings', style: body(22, FontWeight.w800, t.ink)),
                  ),
                  const TkSectionLabel('Defaults'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TkCard(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Default reminder offset', style: body(13.5, FontWeight.w600, t.ink)),
                        const SizedBox(height: 10),
                        TkSegmented<int>(
                          options: const [0, 5, 10],
                          value: prefs.getInt('defaultOffset') ?? 0,
                          labelOf: (v) => v == 0 ? 'At time' : '$v min before',
                          onChanged: (v) async {
                            await prefs.setInt('defaultOffset', v);
                            setState(() {});
                          },
                        ),
                        Container(
                            height: 1,
                            color: t.line,
                            margin: const EdgeInsets.symmetric(vertical: 16)),
                        Text('Default snooze', style: body(13.5, FontWeight.w600, t.ink)),
                        const SizedBox(height: 10),
                        TkSegmented<int>(
                          options: const [5, 10, 15, 30],
                          value: prefs.getInt('defaultSnooze') ?? 5,
                          labelOf: (v) => '$v min',
                          onChanged: (v) async {
                            await prefs.setInt('defaultSnooze', v);
                            setState(() {});
                          },
                        ),
                      ]),
                    ),
                  ),
                  const TkSectionLabel('Reliability'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TkCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        _permRow(Icons.notifications_outlined, 'Notifications', notifGranted,
                            () async {
                          await ref.read(notificationServiceProvider).requestPermissions();
                          ref.invalidate(reliabilityProvider);
                        }, divider: true),
                        _permRow(Icons.alarm_on_outlined, 'Exact alarms', exactGranted,
                            () async {
                          await Permission.scheduleExactAlarm.request();
                          ref.invalidate(reliabilityProvider);
                        }, divider: true),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => const MethodChannel('takna/settings')
                              .invokeMethod('openAlarmChannelSettings'),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                            decoration: BoxDecoration(
                                border:
                                    Border(bottom: BorderSide(color: t.line))),
                            child: Row(children: [
                              Icon(Icons.music_note_outlined, size: 20, color: t.ic1),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text('Alarm sound',
                                      style: body(14, FontWeight.w600, t.ink))),
                              Icon(Icons.chevron_right, size: 18, color: t.ink3),
                            ]),
                          ),
                        ),
                        _dataRow(Icons.history, 'Alarm history',
                            () => context.push('/history')),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TkHero(
                      radius: 18,
                      padding: const EdgeInsets.all(17),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.bolt_outlined, size: 18, color: t.accent),
                          const SizedBox(width: 9),
                          Text('Make alarms reliable', style: body(14, FontWeight.w700, t.heroInk)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          'Let Takna ignore battery optimization so alarms always fire on time — even when your phone sleeps overnight.',
                          style: body(12.5, FontWeight.w400, t.heroSub, height: 1.5),
                        ),
                        const SizedBox(height: 13),
                        batteryUnrestricted
                            ? Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                    color: const Color(0x2E57C79A),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.check,
                                      size: 14, color: Color(0xFF8FE3C0)),
                                  const SizedBox(width: 7),
                                  Text('Reliable mode on',
                                      style: body(
                                          13, FontWeight.w700, const Color(0xFF8FE3C0))),
                                ]),
                              )
                            : GestureDetector(
                                onTap: () async {
                                  await Permission.ignoreBatteryOptimizations.request();
                                  ref.invalidate(batteryUnrestrictedProvider);
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: t.accent,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text('Allow unrestricted',
                                      style: body(
                                          13, FontWeight.w700, const Color(0xFF173B44))),
                                ),
                              ),
                      ]),
                    ),
                  ),
                  const TkSectionLabel('Appearance'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TkCard(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Theme', style: body(13.5, FontWeight.w600, t.ink)),
                        const SizedBox(height: 10),
                        TkSegmented<ThemeMode>(
                          options: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
                          value: themeMode,
                          labelOf: (m) => switch (m) {
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                            _ => 'Auto',
                          },
                          onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                        ),
                      ]),
                    ),
                  ),
                  const TkSectionLabel('Data'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TkCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        _dataRow(Icons.ios_share_outlined, 'Export backup', _export,
                            divider: true),
                        _dataRow(Icons.file_download_outlined, 'Import backup', _import),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) => Text(
                        snap.hasData
                            ? 'Takna ${snap.data!.version} (${snap.data!.buildNumber})'
                            : '',
                        textAlign: TextAlign.center,
                        style: body(12, FontWeight.w500, t.ink3),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _permRow(IconData icon, String label, bool granted, VoidCallback onFix,
      {bool divider = false}) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: t.line)))
          : null,
      child: Row(children: [
        Icon(icon, size: 20, color: t.ic1),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: body(14, FontWeight.w600, t.ink))),
        granted
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration:
                    BoxDecoration(color: t.okSoft, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check, size: 12, color: t.ok),
                  const SizedBox(width: 5),
                  Text('Granted', style: body(11, FontWeight.w700, t.ok)),
                ]),
              )
            : GestureDetector(
                onTap: onFix,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration:
                      BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(20)),
                  child: Text('Allow', style: body(11, FontWeight.w700, t.onAccent)),
                ),
              ),
      ]),
    );
  }

  // Same look as the "Alarm sound" row: icon + label + chevron.
  Widget _dataRow(IconData icon, String label, VoidCallback onTap, {bool divider = false}) {
    final t = context.tk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: divider
            ? BoxDecoration(border: Border(bottom: BorderSide(color: t.line)))
            : null,
        child: Row(children: [
          Icon(icon, size: 20, color: t.ic1),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: body(14, FontWeight.w600, t.ink))),
          Icon(Icons.chevron_right, size: 18, color: t.ink3),
        ]),
      ),
    );
  }

  Future<void> _export() async {
    final repo = ref.read(reminderRepositoryProvider);
    final rows = await repo.getAll();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${Directory.systemTemp.path}/takna-backup-$stamp.json');
    await file.writeAsString(encodeBackup(rows));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    const group = XTypeGroup(
        label: 'JSON', extensions: ['json'], mimeTypes: ['application/json']);
    final picked = await openFile(acceptedTypeGroups: [group]);
    if (picked == null) return; // user cancelled — silent no-op
    try {
      final rows = decodeBackup(await picked.readAsString());
      await ref.read(reminderRepositoryProvider).importAll(rows);
      messenger.showSnackBar(
          SnackBar(content: Text('Imported ${rows.length} reminders')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Import failed — not a Takna backup')));
    }
  }
}
