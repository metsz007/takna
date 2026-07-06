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
  // JSON array of millisecondsSinceEpoch ints, one per skipped occurrence.
  // Null = no skips. User input (an explicit skip), not derived data.
  TextColumn get skippedDates => text().nullable()();
  // Optional free-text tag for home filtering. Single tag per reminder; distinct
  // tags are derived in memory (never stored). Inert data — scheduler ignores it.
  TextColumn get tag => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only audit log of alarm fires and terminal actions. Deliberately
/// outside the reconcile write-path: a fired row is a historical fact nothing
/// recomputes or schedules from. The title is a snapshot at fire time (not
/// derived data — the reminder may later be renamed or deleted).
class FiredEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get reminderId => text()();
  TextColumn get title => text()();
  TextColumn get kind => text()(); // 'fired' | 'dismissed' | 'snoozed'
  DateTimeColumn get firedAt => dateTime()();
}

@DriftDatabase(tables: [Reminders, FiredEvents])
class AppDatabase extends _$AppDatabase {
  // shareAcrossIsolates: the notification background isolate (snooze from
  // the shade) writes to the same DB while the app may be running.
  AppDatabase()
      : super(driftDatabase(
            name: 'takna',
            native: const DriftNativeOptions(shareAcrossIsolates: true)));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(reminders, reminders.snoozedUntil);
          if (from < 3) await m.addColumn(reminders, reminders.isAlarm);
          if (from < 4) await m.createTable(firedEvents);
          if (from < 5) await m.addColumn(reminders, reminders.skippedDates);
          if (from < 6) await m.addColumn(reminders, reminders.tag);
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

  /// Records one alarm-history fact. [at] defaults to now; the param exists so
  /// the prune test can log an old row. Not reconcile-routed on purpose —
  /// append-only audit log.
  Future<void> logFired(String reminderId, String title, String kind,
      {DateTime? at}) async {
    await into(firedEvents).insert(FiredEventsCompanion.insert(
        reminderId: reminderId,
        title: title,
        kind: kind,
        firedAt: at ?? DateTime.now()));
    // ponytail: prune-on-insert, 90-day cap — no background job. Ceiling: if a
    // user fires hundreds/day, switch to keep-last-N.
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    await (delete(firedEvents)..where((t) => t.firedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<FiredEvent?> lastFired(String reminderId) => (select(firedEvents)
        ..where((t) => t.reminderId.equals(reminderId))
        ..orderBy([(t) => OrderingTerm.desc(t.firedAt)])
        ..limit(1))
      .getSingleOrNull();
}
