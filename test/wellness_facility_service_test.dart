import 'package:flutter_test/flutter_test.dart';
import 'package:halo/services/wellness_facility_service.dart';

void main() {
  group('WellnessFacilityService', () {
    test('eventTitle prefers title over name', () {
      expect(
        WellnessFacilityService.eventTitle({'title': 'Yoga Workshop', 'name': 'Old'}),
        'Yoga Workshop',
      );
      expect(
        WellnessFacilityService.eventTitle({'name': 'HIIT Day'}),
        'HIIT Day',
      );
      expect(WellnessFacilityService.eventTitle({}), 'Event');
    });

    test('eventWhen combines date and time', () {
      expect(
        WellnessFacilityService.eventWhen({'date': 'Sun, Jun 15', 'time': '7:00 AM'}),
        'Sun, Jun 15 · 7:00 AM',
      );
      expect(
        WellnessFacilityService.eventWhen({'date': 'Sun, Jun 15'}),
        'Sun, Jun 15',
      );
      expect(WellnessFacilityService.eventWhen({}), '');
    });
  });
}
