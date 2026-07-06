import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/database/database.dart';
import 'package:takna/core/notifications/notification_service.dart';

Reminder _r({required String id, required bool isAlarm}) {
  final now = DateTime.now();
  return Reminder(
    id: id,
    title: 'Title',
    notes: null,
    startDateTime: now,
    timeZone: 'UTC',
    rruleString: null,
    offsetMinutes: 0,
    snoozeMinutes: 10,
    isEnabled: true,
    isAlarm: isAlarm,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late List<({String location, Object? extra})> nav;
  void go(String location, {Object? extra}) =>
      nav.add((location: location, extra: extra));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nav = [];
    await db.upsert(_r(id: 'alarm', isAlarm: true));
    await db.upsert(_r(id: 'notif', isAlarm: false));
  });

  tearDown(() => db.close());

  test('alarm reminder → /alarm with the payload as extra', () async {
    const payload = '0|10|alarm|Title';
    await routeNotificationTap(payload, db, go);
    expect(nav, [(location: '/alarm', extra: payload)]);
  });

  test('notification-style reminder → /detail/<id>', () async {
    await routeNotificationTap('0|10|notif|Title', db, go);
    expect(nav, [(location: '/detail/notif', extra: null)]);
  });

  test('unknown reminderId → /alarm (default)', () async {
    const payload = '0|10|ghost|Title';
    await routeNotificationTap(payload, db, go);
    expect(nav, [(location: '/alarm', extra: payload)]);
  });
}
