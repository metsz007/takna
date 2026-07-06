import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';

void main() {
  test('snooze default is 5 everywhere: DB column and payload fallback', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026, 7, 6, 9);
    await db.into(db.reminders).insert(RemindersCompanion.insert(
          id: 'x',
          title: 't',
          startDateTime: now,
          timeZone: 'UTC',
          createdAt: now,
          updatedAt: now,
        ));
    final r = await db.getById('x');
    expect(r!.snoozeMinutes, 5);
    await db.close();

    expect(parsePayload('1').snoozeMinutes, 5);
  });
}
