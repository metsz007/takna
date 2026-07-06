// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateTimeMeta = const VerificationMeta(
    'startDateTime',
  );
  @override
  late final GeneratedColumn<DateTime> startDateTime =
      GeneratedColumn<DateTime>(
        'start_date_time',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rruleStringMeta = const VerificationMeta(
    'rruleString',
  );
  @override
  late final GeneratedColumn<String> rruleString = GeneratedColumn<String>(
    'rrule_string',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMinutesMeta = const VerificationMeta(
    'offsetMinutes',
  );
  @override
  late final GeneratedColumn<int> offsetMinutes = GeneratedColumn<int>(
    'offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _snoozeMinutesMeta = const VerificationMeta(
    'snoozeMinutes',
  );
  @override
  late final GeneratedColumn<int> snoozeMinutes = GeneratedColumn<int>(
    'snooze_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isAlarmMeta = const VerificationMeta(
    'isAlarm',
  );
  @override
  late final GeneratedColumn<bool> isAlarm = GeneratedColumn<bool>(
    'is_alarm',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_alarm" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skippedDatesMeta = const VerificationMeta(
    'skippedDates',
  );
  @override
  late final GeneratedColumn<String> skippedDates = GeneratedColumn<String>(
    'skipped_dates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    startDateTime,
    timeZone,
    rruleString,
    offsetMinutes,
    snoozeMinutes,
    isEnabled,
    isAlarm,
    snoozedUntil,
    skippedDates,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('start_date_time')) {
      context.handle(
        _startDateTimeMeta,
        startDateTime.isAcceptableOrUnknown(
          data['start_date_time']!,
          _startDateTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startDateTimeMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('rrule_string')) {
      context.handle(
        _rruleStringMeta,
        rruleString.isAcceptableOrUnknown(
          data['rrule_string']!,
          _rruleStringMeta,
        ),
      );
    }
    if (data.containsKey('offset_minutes')) {
      context.handle(
        _offsetMinutesMeta,
        offsetMinutes.isAcceptableOrUnknown(
          data['offset_minutes']!,
          _offsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('snooze_minutes')) {
      context.handle(
        _snoozeMinutesMeta,
        snoozeMinutes.isAcceptableOrUnknown(
          data['snooze_minutes']!,
          _snoozeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('is_alarm')) {
      context.handle(
        _isAlarmMeta,
        isAlarm.isAcceptableOrUnknown(data['is_alarm']!, _isAlarmMeta),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('skipped_dates')) {
      context.handle(
        _skippedDatesMeta,
        skippedDates.isAcceptableOrUnknown(
          data['skipped_dates']!,
          _skippedDatesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date_time'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      rruleString: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rrule_string'],
      ),
      offsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_minutes'],
      )!,
      snoozeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_minutes'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      isAlarm: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_alarm'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      skippedDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skipped_dates'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final String id;
  final String title;
  final String? notes;
  final DateTime startDateTime;
  final String timeZone;
  final String? rruleString;
  final int offsetMinutes;
  final int snoozeMinutes;
  final bool isEnabled;
  final bool isAlarm;
  final DateTime? snoozedUntil;
  final String? skippedDates;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Reminder({
    required this.id,
    required this.title,
    this.notes,
    required this.startDateTime,
    required this.timeZone,
    this.rruleString,
    required this.offsetMinutes,
    required this.snoozeMinutes,
    required this.isEnabled,
    required this.isAlarm,
    this.snoozedUntil,
    this.skippedDates,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['start_date_time'] = Variable<DateTime>(startDateTime);
    map['time_zone'] = Variable<String>(timeZone);
    if (!nullToAbsent || rruleString != null) {
      map['rrule_string'] = Variable<String>(rruleString);
    }
    map['offset_minutes'] = Variable<int>(offsetMinutes);
    map['snooze_minutes'] = Variable<int>(snoozeMinutes);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['is_alarm'] = Variable<bool>(isAlarm);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    if (!nullToAbsent || skippedDates != null) {
      map['skipped_dates'] = Variable<String>(skippedDates);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startDateTime: Value(startDateTime),
      timeZone: Value(timeZone),
      rruleString: rruleString == null && nullToAbsent
          ? const Value.absent()
          : Value(rruleString),
      offsetMinutes: Value(offsetMinutes),
      snoozeMinutes: Value(snoozeMinutes),
      isEnabled: Value(isEnabled),
      isAlarm: Value(isAlarm),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      skippedDates: skippedDates == null && nullToAbsent
          ? const Value.absent()
          : Value(skippedDates),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      startDateTime: serializer.fromJson<DateTime>(json['startDateTime']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      rruleString: serializer.fromJson<String?>(json['rruleString']),
      offsetMinutes: serializer.fromJson<int>(json['offsetMinutes']),
      snoozeMinutes: serializer.fromJson<int>(json['snoozeMinutes']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      isAlarm: serializer.fromJson<bool>(json['isAlarm']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      skippedDates: serializer.fromJson<String?>(json['skippedDates']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'startDateTime': serializer.toJson<DateTime>(startDateTime),
      'timeZone': serializer.toJson<String>(timeZone),
      'rruleString': serializer.toJson<String?>(rruleString),
      'offsetMinutes': serializer.toJson<int>(offsetMinutes),
      'snoozeMinutes': serializer.toJson<int>(snoozeMinutes),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'isAlarm': serializer.toJson<bool>(isAlarm),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'skippedDates': serializer.toJson<String?>(skippedDates),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Reminder copyWith({
    String? id,
    String? title,
    Value<String?> notes = const Value.absent(),
    DateTime? startDateTime,
    String? timeZone,
    Value<String?> rruleString = const Value.absent(),
    int? offsetMinutes,
    int? snoozeMinutes,
    bool? isEnabled,
    bool? isAlarm,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<String?> skippedDates = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Reminder(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    startDateTime: startDateTime ?? this.startDateTime,
    timeZone: timeZone ?? this.timeZone,
    rruleString: rruleString.present ? rruleString.value : this.rruleString,
    offsetMinutes: offsetMinutes ?? this.offsetMinutes,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    isEnabled: isEnabled ?? this.isEnabled,
    isAlarm: isAlarm ?? this.isAlarm,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    skippedDates: skippedDates.present ? skippedDates.value : this.skippedDates,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      startDateTime: data.startDateTime.present
          ? data.startDateTime.value
          : this.startDateTime,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      rruleString: data.rruleString.present
          ? data.rruleString.value
          : this.rruleString,
      offsetMinutes: data.offsetMinutes.present
          ? data.offsetMinutes.value
          : this.offsetMinutes,
      snoozeMinutes: data.snoozeMinutes.present
          ? data.snoozeMinutes.value
          : this.snoozeMinutes,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      isAlarm: data.isAlarm.present ? data.isAlarm.value : this.isAlarm,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      skippedDates: data.skippedDates.present
          ? data.skippedDates.value
          : this.skippedDates,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startDateTime: $startDateTime, ')
          ..write('timeZone: $timeZone, ')
          ..write('rruleString: $rruleString, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isAlarm: $isAlarm, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('skippedDates: $skippedDates, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    startDateTime,
    timeZone,
    rruleString,
    offsetMinutes,
    snoozeMinutes,
    isEnabled,
    isAlarm,
    snoozedUntil,
    skippedDates,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.startDateTime == this.startDateTime &&
          other.timeZone == this.timeZone &&
          other.rruleString == this.rruleString &&
          other.offsetMinutes == this.offsetMinutes &&
          other.snoozeMinutes == this.snoozeMinutes &&
          other.isEnabled == this.isEnabled &&
          other.isAlarm == this.isAlarm &&
          other.snoozedUntil == this.snoozedUntil &&
          other.skippedDates == this.skippedDates &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> notes;
  final Value<DateTime> startDateTime;
  final Value<String> timeZone;
  final Value<String?> rruleString;
  final Value<int> offsetMinutes;
  final Value<int> snoozeMinutes;
  final Value<bool> isEnabled;
  final Value<bool> isAlarm;
  final Value<DateTime?> snoozedUntil;
  final Value<String?> skippedDates;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.startDateTime = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.rruleString = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isAlarm = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.skippedDates = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    required DateTime startDateTime,
    required String timeZone,
    this.rruleString = const Value.absent(),
    this.offsetMinutes = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isAlarm = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.skippedDates = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startDateTime = Value(startDateTime),
       timeZone = Value(timeZone),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? startDateTime,
    Expression<String>? timeZone,
    Expression<String>? rruleString,
    Expression<int>? offsetMinutes,
    Expression<int>? snoozeMinutes,
    Expression<bool>? isEnabled,
    Expression<bool>? isAlarm,
    Expression<DateTime>? snoozedUntil,
    Expression<String>? skippedDates,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (startDateTime != null) 'start_date_time': startDateTime,
      if (timeZone != null) 'time_zone': timeZone,
      if (rruleString != null) 'rrule_string': rruleString,
      if (offsetMinutes != null) 'offset_minutes': offsetMinutes,
      if (snoozeMinutes != null) 'snooze_minutes': snoozeMinutes,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (isAlarm != null) 'is_alarm': isAlarm,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (skippedDates != null) 'skipped_dates': skippedDates,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? notes,
    Value<DateTime>? startDateTime,
    Value<String>? timeZone,
    Value<String?>? rruleString,
    Value<int>? offsetMinutes,
    Value<int>? snoozeMinutes,
    Value<bool>? isEnabled,
    Value<bool>? isAlarm,
    Value<DateTime?>? snoozedUntil,
    Value<String?>? skippedDates,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startDateTime: startDateTime ?? this.startDateTime,
      timeZone: timeZone ?? this.timeZone,
      rruleString: rruleString ?? this.rruleString,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      isAlarm: isAlarm ?? this.isAlarm,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      skippedDates: skippedDates ?? this.skippedDates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startDateTime.present) {
      map['start_date_time'] = Variable<DateTime>(startDateTime.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (rruleString.present) {
      map['rrule_string'] = Variable<String>(rruleString.value);
    }
    if (offsetMinutes.present) {
      map['offset_minutes'] = Variable<int>(offsetMinutes.value);
    }
    if (snoozeMinutes.present) {
      map['snooze_minutes'] = Variable<int>(snoozeMinutes.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (isAlarm.present) {
      map['is_alarm'] = Variable<bool>(isAlarm.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (skippedDates.present) {
      map['skipped_dates'] = Variable<String>(skippedDates.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startDateTime: $startDateTime, ')
          ..write('timeZone: $timeZone, ')
          ..write('rruleString: $rruleString, ')
          ..write('offsetMinutes: $offsetMinutes, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isAlarm: $isAlarm, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('skippedDates: $skippedDates, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FiredEventsTable extends FiredEvents
    with TableInfo<$FiredEventsTable, FiredEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FiredEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firedAt = GeneratedColumn<DateTime>(
    'fired_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, reminderId, title, kind, firedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fired_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<FiredEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_firedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FiredEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FiredEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fired_at'],
      )!,
    );
  }

  @override
  $FiredEventsTable createAlias(String alias) {
    return $FiredEventsTable(attachedDatabase, alias);
  }
}

class FiredEvent extends DataClass implements Insertable<FiredEvent> {
  final int id;
  final String reminderId;
  final String title;
  final String kind;
  final DateTime firedAt;
  const FiredEvent({
    required this.id,
    required this.reminderId,
    required this.title,
    required this.kind,
    required this.firedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reminder_id'] = Variable<String>(reminderId);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<String>(kind);
    map['fired_at'] = Variable<DateTime>(firedAt);
    return map;
  }

  FiredEventsCompanion toCompanion(bool nullToAbsent) {
    return FiredEventsCompanion(
      id: Value(id),
      reminderId: Value(reminderId),
      title: Value(title),
      kind: Value(kind),
      firedAt: Value(firedAt),
    );
  }

  factory FiredEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FiredEvent(
      id: serializer.fromJson<int>(json['id']),
      reminderId: serializer.fromJson<String>(json['reminderId']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<String>(json['kind']),
      firedAt: serializer.fromJson<DateTime>(json['firedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reminderId': serializer.toJson<String>(reminderId),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(kind),
      'firedAt': serializer.toJson<DateTime>(firedAt),
    };
  }

  FiredEvent copyWith({
    int? id,
    String? reminderId,
    String? title,
    String? kind,
    DateTime? firedAt,
  }) => FiredEvent(
    id: id ?? this.id,
    reminderId: reminderId ?? this.reminderId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    firedAt: firedAt ?? this.firedAt,
  );
  FiredEvent copyWithCompanion(FiredEventsCompanion data) {
    return FiredEvent(
      id: data.id.present ? data.id.value : this.id,
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FiredEvent(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('firedAt: $firedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, reminderId, title, kind, firedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FiredEvent &&
          other.id == this.id &&
          other.reminderId == this.reminderId &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.firedAt == this.firedAt);
}

class FiredEventsCompanion extends UpdateCompanion<FiredEvent> {
  final Value<int> id;
  final Value<String> reminderId;
  final Value<String> title;
  final Value<String> kind;
  final Value<DateTime> firedAt;
  const FiredEventsCompanion({
    this.id = const Value.absent(),
    this.reminderId = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.firedAt = const Value.absent(),
  });
  FiredEventsCompanion.insert({
    this.id = const Value.absent(),
    required String reminderId,
    required String title,
    required String kind,
    required DateTime firedAt,
  }) : reminderId = Value(reminderId),
       title = Value(title),
       kind = Value(kind),
       firedAt = Value(firedAt);
  static Insertable<FiredEvent> custom({
    Expression<int>? id,
    Expression<String>? reminderId,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<DateTime>? firedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reminderId != null) 'reminder_id': reminderId,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (firedAt != null) 'fired_at': firedAt,
    });
  }

  FiredEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? reminderId,
    Value<String>? title,
    Value<String>? kind,
    Value<DateTime>? firedAt,
  }) {
    return FiredEventsCompanion(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      firedAt: firedAt ?? this.firedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<DateTime>(firedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FiredEventsCompanion(')
          ..write('id: $id, ')
          ..write('reminderId: $reminderId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('firedAt: $firedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $FiredEventsTable firedEvents = $FiredEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [reminders, firedEvents];
}

typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String title,
      Value<String?> notes,
      required DateTime startDateTime,
      required String timeZone,
      Value<String?> rruleString,
      Value<int> offsetMinutes,
      Value<int> snoozeMinutes,
      Value<bool> isEnabled,
      Value<bool> isAlarm,
      Value<DateTime?> snoozedUntil,
      Value<String?> skippedDates,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> notes,
      Value<DateTime> startDateTime,
      Value<String> timeZone,
      Value<String?> rruleString,
      Value<int> offsetMinutes,
      Value<int> snoozeMinutes,
      Value<bool> isEnabled,
      Value<bool> isAlarm,
      Value<DateTime?> snoozedUntil,
      Value<String?> skippedDates,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rruleString => $composableBuilder(
    column: $table.rruleString,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAlarm => $composableBuilder(
    column: $table.isAlarm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skippedDates => $composableBuilder(
    column: $table.skippedDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rruleString => $composableBuilder(
    column: $table.rruleString,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAlarm => $composableBuilder(
    column: $table.isAlarm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skippedDates => $composableBuilder(
    column: $table.skippedDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startDateTime => $composableBuilder(
    column: $table.startDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<String> get rruleString => $composableBuilder(
    column: $table.rruleString,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetMinutes => $composableBuilder(
    column: $table.offsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get isAlarm =>
      $composableBuilder(column: $table.isAlarm, builder: (column) => column);

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skippedDates => $composableBuilder(
    column: $table.skippedDates,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
          Reminder,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> startDateTime = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<String?> rruleString = const Value.absent(),
                Value<int> offsetMinutes = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isAlarm = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> skippedDates = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                title: title,
                notes: notes,
                startDateTime: startDateTime,
                timeZone: timeZone,
                rruleString: rruleString,
                offsetMinutes: offsetMinutes,
                snoozeMinutes: snoozeMinutes,
                isEnabled: isEnabled,
                isAlarm: isAlarm,
                snoozedUntil: snoozedUntil,
                skippedDates: skippedDates,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> notes = const Value.absent(),
                required DateTime startDateTime,
                required String timeZone,
                Value<String?> rruleString = const Value.absent(),
                Value<int> offsetMinutes = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isAlarm = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> skippedDates = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                startDateTime: startDateTime,
                timeZone: timeZone,
                rruleString: rruleString,
                offsetMinutes: offsetMinutes,
                snoozeMinutes: snoozeMinutes,
                isEnabled: isEnabled,
                isAlarm: isAlarm,
                snoozedUntil: snoozedUntil,
                skippedDates: skippedDates,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;
typedef $$FiredEventsTableCreateCompanionBuilder =
    FiredEventsCompanion Function({
      Value<int> id,
      required String reminderId,
      required String title,
      required String kind,
      required DateTime firedAt,
    });
typedef $$FiredEventsTableUpdateCompanionBuilder =
    FiredEventsCompanion Function({
      Value<int> id,
      Value<String> reminderId,
      Value<String> title,
      Value<String> kind,
      Value<DateTime> firedAt,
    });

class $$FiredEventsTableFilterComposer
    extends Composer<_$AppDatabase, $FiredEventsTable> {
  $$FiredEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FiredEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $FiredEventsTable> {
  $$FiredEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FiredEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FiredEventsTable> {
  $$FiredEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get reminderId => $composableBuilder(
    column: $table.reminderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);
}

class $$FiredEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FiredEventsTable,
          FiredEvent,
          $$FiredEventsTableFilterComposer,
          $$FiredEventsTableOrderingComposer,
          $$FiredEventsTableAnnotationComposer,
          $$FiredEventsTableCreateCompanionBuilder,
          $$FiredEventsTableUpdateCompanionBuilder,
          (
            FiredEvent,
            BaseReferences<_$AppDatabase, $FiredEventsTable, FiredEvent>,
          ),
          FiredEvent,
          PrefetchHooks Function()
        > {
  $$FiredEventsTableTableManager(_$AppDatabase db, $FiredEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FiredEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FiredEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FiredEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> reminderId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> firedAt = const Value.absent(),
              }) => FiredEventsCompanion(
                id: id,
                reminderId: reminderId,
                title: title,
                kind: kind,
                firedAt: firedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String reminderId,
                required String title,
                required String kind,
                required DateTime firedAt,
              }) => FiredEventsCompanion.insert(
                id: id,
                reminderId: reminderId,
                title: title,
                kind: kind,
                firedAt: firedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FiredEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FiredEventsTable,
      FiredEvent,
      $$FiredEventsTableFilterComposer,
      $$FiredEventsTableOrderingComposer,
      $$FiredEventsTableAnnotationComposer,
      $$FiredEventsTableCreateCompanionBuilder,
      $$FiredEventsTableUpdateCompanionBuilder,
      (
        FiredEvent,
        BaseReferences<_$AppDatabase, $FiredEventsTable, FiredEvent>,
      ),
      FiredEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$FiredEventsTableTableManager get firedEvents =>
      $$FiredEventsTableTableManager(_db, _db.firedEvents);
}
