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
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(10))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Reminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'takna'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

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
}
