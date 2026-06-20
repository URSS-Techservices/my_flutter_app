import 'package:flutter_test/flutter_test.dart';
import 'package:halo/services/booking_requests_service.dart';

void main() {
  group('BookingRequestsService', () {
    test('displayWhen prefers slot fields', () {
      expect(
        BookingRequestsService.displayWhen({
          'slotDate': '2026-06-10',
          'slotTime': '09:00',
        }),
        '2026-06-10 · 09:00',
      );
    });

    test('displayWhen falls back to preferred date/time', () {
      expect(
        BookingRequestsService.displayWhen({
          'preferredDate': 'Mon 10 Jun',
          'preferredTime': '7:00 AM',
        }),
        'Mon 10 Jun · 7:00 AM',
      );
    });

    test('displayService default', () {
      expect(BookingRequestsService.displayService({}), 'Session');
      expect(
        BookingRequestsService.displayService({'service': 'Yoga class'}),
        'Yoga class',
      );
    });

    test('isAccepted', () {
      expect(BookingRequestsService.isAccepted({'status': 'accepted'}), true);
      expect(BookingRequestsService.isAccepted({'status': 'pending'}), false);
    });
  });
}
