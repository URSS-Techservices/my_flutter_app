import 'package:flutter_test/flutter_test.dart';
import 'package:halo/services/guru_availability_service.dart';

void main() {
  group('GuruAvailabilityService', () {
    test('parseWeeklySlots', () {
      final parsed = GuruAvailabilityService.parseWeeklySlots({
        '1': ['09:00', '14:00'],
        '7': ['10:30'],
      });
      expect(parsed['1'], ['09:00', '14:00']);
      expect(parsed['7'], ['10:30']);
    });

    test('normalizeTime24 from 12h', () {
      expect(GuruAvailabilityService.normalizeTime24('9:00 AM'), '09:00');
      expect(GuruAvailabilityService.normalizeTime24('2:30 pm'), '14:30');
    });

    test('formatTime12', () {
      expect(GuruAvailabilityService.formatTime12('09:00'), '9:00 AM');
      expect(GuruAvailabilityService.formatTime12('14:30'), '2:30 PM');
    });

    test('slotId format', () {
      final slot = GuruAvailableSlot(
        date: DateTime(2026, 6, 10),
        time24: '09:00',
      );
      expect(slot.slotId, '2026-06-10_09:00');
    });
  });
}
