import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get startDateTime => dateTime()();
  TextColumn get timeZone => text()();
  TextColumn get rruleString => text().nullable()();
  IntColumn get offsetMinutes => integer().withDefault(const Constant(0))();
  // 5 matches the UI default and the payload fallback in parsePayload().
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isAlarm => boolean().withDefault(const Constant(true))();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Reminders])
class AppDatabase extends _$AppDatabase {
  // shareAcrossIsolates: the notification background isolate (snooze from
  // the shade) writes to the same DB while the app may be running.
  AppDatabase()
      : super(driftDatabase(
            name: 'takna',
            native: const DriftNativeOptions(shareAcrossIsolates: true)));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(reminders, reminders.snoozedUntil);
          if (from < 3) await m.addColumn(reminders, reminders.isAlarm);
        },
      );

  Stream<List<Reminder>> watchAll() => (select(reminders)
        ..orderBy([(t) => OrderingTerm.asc(t.startDateTime)]))
      .watch();

  Future<List<Reminder>> getEnabled() =>
      (select(reminders)..where((t) => t.isEnabled)).get();

  Future<Reminder?> getById(String id) =>
      (select(reminders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(Reminder r) => into(reminders).insertOnConflictUpdate(r);

  Future<void> deleteById(String id) =>
      (delete(reminders)..where((t) => t.id.equals(id))).go();

  Future<void> setSnoozedUntil(String id, DateTime? until) =>
      (update(reminders)..where((t) => t.id.equals(id)))
          .write(RemindersCompanion(snoozedUntil: Value(until)));

  Future<void> setEnabled(String id, bool enabled) =>
      (update(reminders)..where((t) => t.id.equals(id)))
          .write(RemindersCompanion(isEnabled: Value(enabled)));
}
