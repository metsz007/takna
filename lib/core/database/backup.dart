import 'dart:convert';

import 'database.dart';

/// Bumped only if the envelope shape changes; import branches on it.
const backupVersion = 1;

/// Serializes reminders into the versioned backup envelope. Pure — no I/O.
String encodeBackup(List<Reminder> rows) => jsonEncode({
      'takna': backupVersion,
      'reminders': [for (final r in rows) r.toJson()],
    });

/// Parses a backup string back into reminders. Throws [FormatException] on
/// anything that isn't a Takna backup (bad JSON, wrong/missing envelope, or a
/// malformed row). Atomic: the whole list decodes or nothing does — the list
/// comprehension builds fully before returning, so one bad row throws with no
/// partial result.
List<Reminder> decodeBackup(String source) {
  final map = jsonDecode(source);
  if (map is! Map<String, dynamic> || map['takna'] != backupVersion) {
    throw const FormatException('Not a Takna backup');
  }
  final rows = map['reminders'];
  if (rows is! List) throw const FormatException('Not a Takna backup');
  return [
    for (final r in rows) Reminder.fromJson(r as Map<String, dynamic>),
  ];
}
