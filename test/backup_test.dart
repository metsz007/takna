import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/backup.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:takna/core/scheduler/scheduler.dart';
import 'package:takna/features/reminders/data/reminder_repository.dart';

/// Counts reconcile passes without touching the plugin (same shape as the
/// scheduler-test fakes).
class _CountingNotifications extends NotificationService {
  int cancelAllCount = 0;

  @override
  Future<void> cancelAll() async => cancelAllCount++;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    String? body,
    required DateTime when,
    required int snoozeMinutes,
    required String reminderId,
    bool isAlarm = true,
    String? soundKey,
  }) async {}
}

Reminder _r({
  required String id,
  String? notes,
  String? rrule,
  DateTime? snoozedUntil,
}) {
  final t = DateTime(2026, 1, 1, 9);
  return Reminder(
    id: id,
    title: 'Reminder $id',
    notes: notes,
    startDateTime: t,
    timeZone: 'UTC',
    rruleString: rrule,
    offsetMinutes: 0,
    snoozeMinutes: 10,
    nagMinutes: 0,
    isEnabled: true,
    isAlarm: true,
    snoozedUntil: snoozedUntil,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  test('round trip preserves rows with nullable fields null and set', () {
    final rows = [
      _r(id: 'a'), // notes / rrule / snoozedUntil all null
      _r(
        id: 'b',
        notes: 'buy milk',
        rrule: 'FREQ=DAILY',
        snoozedUntil: DateTime(2026, 2, 3, 8, 30),
      ),
      _r(id: 'c', notes: 'only notes'),
    ];

    expect(decodeBackup(encodeBackup(rows)), rows);
  });

  test('pre-schema-10 backup (no nagMinutes) restores with nag off', () {
    final old = _r(id: 'a').toJson()
      ..remove('nagMinutes')
      ..remove('dismissedUntil');
    final source = jsonEncode({
      'takna': backupVersion,
      'reminders': [old],
    });

    expect(decodeBackup(source).single.nagMinutes, 0);
  });

  test('garbage and wrong envelopes throw FormatException', () {
    expect(() => decodeBackup('hello'), throwsFormatException);
    expect(() => decodeBackup('{}'), throwsFormatException);
    expect(() => decodeBackup('{"takna": 999, "reminders": []}'),
        throwsFormatException);
  });

  test('half-bad file is rejected atomically (no partial result)', () {
    // First row valid, second is missing its id → the whole decode throws.
    final good = _r(id: 'a').toJson();
    final bad = _r(id: 'b').toJson()..remove('id');
    final source = jsonEncode({
      'takna': backupVersion,
      'reminders': [good, bad],
    });

    expect(() => decodeBackup(source), throwsA(isA<Object>()));
  });

  test('importAll upserts every row with exactly one reconcile', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final notifications = _CountingNotifications();
    final repo = ReminderRepository(db, Scheduler(db, notifications));
    addTearDown(db.close);

    await repo.importAll([_r(id: 'a'), _r(id: 'b'), _r(id: 'c')]);

    expect((await repo.getAll()).length, 3);
    expect(notifications.cancelAllCount, 1); // one reconcile, not one per row
  });
}
