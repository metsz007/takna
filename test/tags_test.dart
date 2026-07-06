import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/features/reminders/presentation/screens/home_screen.dart';

Reminder _r({required String id, String? tag}) => Reminder(
      id: id,
      title: 't',
      notes: null,
      startDateTime: DateTime(2026, 7, 1, 9),
      timeZone: 'UTC',
      rruleString: null,
      offsetMinutes: 0,
      snoozeMinutes: 5,
      isEnabled: true,
      isAlarm: true,
      snoozedUntil: null,
      skippedDates: null,
      tag: tag,
      createdAt: DateTime(2026, 7, 1, 9),
      updatedAt: DateTime(2026, 7, 1, 9),
    );

void main() {
  group('distinctTags (pure)', () {
    test('dedupes, drops null, sorts', () {
      final rs = [
        _r(id: 'a', tag: 'work'),
        _r(id: 'b', tag: null),
        _r(id: 'c', tag: 'home'),
        _r(id: 'd', tag: 'work'),
      ];
      expect(distinctTags(rs), ['home', 'work']);
    });

    test('empty when nothing is tagged', () {
      expect(distinctTags([_r(id: 'a'), _r(id: 'b')]), isEmpty);
    });
  });

  test('old backups (no tag key) decode with a null column', () {
    // Plan 03 round-trips reminders through JSON; a pre-tag backup lacks the key.
    final row = _r(id: 'a', tag: 'work').toJson()..remove('tag');
    expect(Reminder.fromJson(row).tag, isNull);
  });

  test('DB column round-trips: absent → null, upsert → read back', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026, 7, 6, 9);
    // Insert without a tag → reads back null.
    await db.into(db.reminders).insert(RemindersCompanion.insert(
          id: 'x',
          title: 't',
          startDateTime: now,
          timeZone: 'UTC',
          createdAt: now,
          updatedAt: now,
        ));
    expect((await db.getById('x'))!.tag, isNull);

    // Upsert a tagged row → reads back the tag.
    await db.upsert(_r(id: 'x', tag: 'work'));
    expect((await db.getById('x'))!.tag, 'work');

    await db.close();
  });
}
