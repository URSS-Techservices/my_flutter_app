import 'package:flutter_test/flutter_test.dart';
import 'package:halo/screens/profile/core/wellness_facility_hours.dart';

void main() {
  group('WellnessFacilityHours', () {
    test('open during Mon-Sat hours', () {
      const hours = WellnessFacilityHours(
        availability: {'Mon-Sat': '6:00 AM - 10:00 PM', 'Sun': '8:00 AM - 8:00 PM'},
      );
      // Wednesday 2pm
      final status = hours.statusAt(DateTime(2026, 6, 3, 14, 0));
      expect(status.isOpen, isTrue);
      expect(status.label, 'Open Now');
    });

    test('closed after hours', () {
      const hours = WellnessFacilityHours(
        availability: {'Mon-Sat': '6:00 AM - 10:00 PM'},
      );
      final status = hours.statusAt(DateTime(2026, 6, 3, 23, 0));
      expect(status.isOpen, isFalse);
      expect(status.label, 'Closed');
    });

    test('Sunday uses Sun schedule', () {
      const hours = WellnessFacilityHours(
        availability: {'Mon-Sat': '6:00 AM - 10:00 PM', 'Sun': 'Closed'},
      );
      final status = hours.statusAt(DateTime(2026, 6, 7, 12, 0));
      expect(status.isOpen, isFalse);
    });

    test('falls back to facilityHours map', () {
      const hours = WellnessFacilityHours(
        availability: {},
        facilityHours: {'openTime': '09:00', 'closeTime': '17:00'},
      );
      final status = hours.statusAt(DateTime(2026, 6, 3, 10, 0));
      expect(status.isOpen, isTrue);
    });
  });
}
