import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/sounds.dart';

import 'package:drift/drift.dart' show Value;

void main() {
  group('catalog integrity', () {
    test('every entry has non-empty key, label, iosFile', () {
      for (final s in soundCatalog) {
        expect(s.key, isNotEmpty);
        expect(s.label, isNotEmpty);
        expect(s.iosFile, isNotEmpty);
      }
    });

    test('keys are unique', () {
      final keys = soundCatalog.map((s) => s.key).toList();
      expect(keys.toSet().length, keys.length);
    });
  });

  group('iosSoundFor', () {
    test('known key returns its catalog iosFile', () {
      expect(iosSoundFor('chime'), soundCatalog.first.iosFile);
    });

    test('null and unknown key return null (never throws)', () {
      expect(iosSoundFor(null), isNull);
      expect(iosSoundFor('bogus'), isNull);
    });
  });

  group('soundLabelFor', () {
    test('known key returns its catalog label', () {
      expect(soundLabelFor('chime'), soundCatalog.first.label);
    });

    test('null and unknown key return System default (never throws)', () {
      expect(soundLabelFor(null), 'Default');
      expect(soundLabelFor('bogus'), 'Default');
    });
  });

  group('soundKey column', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    RemindersCompanion base(String id, {Value<String?> soundKey = const Value.absent()}) =>
        RemindersCompanion.insert(
          id: id,
          title: 't',
          startDateTime: DateTime.now(),
          timeZone: 'UTC',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          soundKey: soundKey,
        );

    test('absent soundKey defaults to null', () async {
      await db.into(db.reminders).insert(base('a'));
      expect((await db.getById('a'))!.soundKey, isNull);
    });

    test('round-trips a set soundKey', () async {
      await db.into(db.reminders).insert(base('b', soundKey: const Value('chime')));
      expect((await db.getById('b'))!.soundKey, 'chime');
    });
  });
}
