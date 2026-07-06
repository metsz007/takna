import 'package:flutter_test/flutter_test.dart';
import 'package:takna/core/notifications/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('trusts a valid IANA id verbatim (not re-derived by offset scan)', () {
    // This id's offset won't match the test machine, proving it's trusted
    // directly rather than re-derived by the scan.
    expect(resolveTimeZoneName('Pacific/Kiritimati'), 'Pacific/Kiritimati');
  });

  test('trusts another valid IANA id', () {
    expect(resolveTimeZoneName('America/New_York'), 'America/New_York');
  });

  test('unknown id falls back to a valid db name or UTC, never the bogus id', () {
    final result = resolveTimeZoneName('Not/AZone');
    expect(result, isNot('Not/AZone'));
    if (result == 'UTC') return;
    expect(tz.timeZoneDatabase.locations.containsKey(result), isTrue);
    expect(tz.getLocation(result).timeZone(DateTime.now().millisecondsSinceEpoch).offset,
        DateTime.now().timeZoneOffset);
  });

  test('null id behaves like the unknown-id fallback', () {
    final result = resolveTimeZoneName(null);
    if (result == 'UTC') return;
    expect(tz.timeZoneDatabase.locations.containsKey(result), isTrue);
    expect(tz.getLocation(result).timeZone(DateTime.now().millisecondsSinceEpoch).offset,
        DateTime.now().timeZoneOffset);
  });
}
