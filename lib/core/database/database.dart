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
  // null = off; 'math' = solve a math problem before Dismiss will dismiss.
  // Text (not bool) so a future 'typed'/'shake' needs no new migration.
  // Ring-screen-only; scheduler/notification path ignores it.
  TextColumn get challenge => text().nullable()();
  // null = System default (unchanged channel/native behavior); a non-null key
  // names one lib/core/notifications/sounds.dart catalog entry. Never derived.
  TextColumn get soundKey => text().nullable()();
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

/// Single-row global app state that must be visible in every isolate. Lives in
/// the DB (not shared_preferences) because reconcile() also runs in the
/// notification background isolate, and the shared DB is the only cross-isolate
/// source of truth.
// ponytail: one-column single-row table, not a generic key/value store — one
// setting doesn't earn a KV schema. Widen to KV only when a second
// cross-isolate setting appears.
class AppState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  DateTimeColumn get pausedUntil => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Reminders, FiredEvents, AppState])
class AppDatabase extends _$AppDatabase {
  // shareAcrossIsolates: the notification background isolate (snooze from
  // the shade) writes to the same DB while the app may be running.
  AppDatabase()
      : super(driftDatabase(
            name: 'takna',
            native: const DriftNativeOptions(shareAcrossIsolates: true)));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(reminders, reminders.snoozedUntil);
          if (from < 3) await m.addColumn(reminders, reminders.isAlarm);
          if (from < 4) await m.createTable(firedEvents);
          if (from < 5) await m.addColumn(reminders, reminders.skippedDates);
          if (from < 6) await m.addColumn(reminders, reminders.tag);
          if (from < 7) await m.addColumn(reminders, reminders.challenge);
          if (from < 8) await m.createTable(appState);
          if (from < 9) await m.addColumn(reminders, reminders.soundKey);
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

  Future<List<FiredEvent>> allEvents() => (select(firedEvents)
        ..orderBy([(t) => OrderingTerm.desc(t.firedAt)]))
      .get();

  Future<FiredEvent?> lastFired(String reminderId) => (select(firedEvents)
        ..where((t) => t.reminderId.equals(reminderId))
        ..orderBy([(t) => OrderingTerm.desc(t.firedAt)])
        ..limit(1))
      .getSingleOrNull();

  /// Global "pause all alarms until" timestamp, or null if not paused. A stale
  /// past value reads as not-paused (the scheduler treats it as inert).
  Future<DateTime?> getPausedUntil() async =>
      (await (select(appState)..where((t) => t.id.equals(0)))
              .getSingleOrNull())
          ?.pausedUntil;

  // id pinned to 0: an INTEGER PRIMARY KEY is a rowid alias, so an absent id
  // auto-increments (a new row per write) instead of using the column default.
  // Pinning keeps this a true single-row table that insertOnConflictUpdate
  // overwrites in place.
  Future<void> setPausedUntil(DateTime? until) => into(appState)
      .insertOnConflictUpdate(
          AppStateCompanion.insert(id: const Value(0), pausedUntil: Value(until)));
}
