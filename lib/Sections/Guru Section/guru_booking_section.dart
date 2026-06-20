import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/widgets/guru/guru_availability_preview.dart';
import 'package:halo/screens/profile/pages/booking_inbox_page.dart';
import 'package:halo/services/booking_requests_service.dart';

class GuruBookingSection extends StatelessWidget {
  final String guruid;
  final bool isOwnProfile;
  final Map<String, dynamic> bookingSettings;
  final List<Map<String, dynamic>> upcomingSessions;
  final List<Map<String, dynamic>> pastSessions;
  final VoidCallback? onManageSlots;
  final VoidCallback? onBookNow;

  const GuruBookingSection({
    Key? key,
    required this.guruid,
    required this.isOwnProfile,
    required this.bookingSettings,
    required this.upcomingSessions,
    required this.pastSessions,
    this.onManageSlots,
    this.onBookNow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Always render - never return empty
    final bool acceptsOnline =
        bookingSettings['online'] == true || bookingSettings['online'] == 'true';
    final bool acceptsOffline =
        bookingSettings['offline'] == true || bookingSettings['offline'] == 'true';
    final String priceText = bookingSettings['basePrice']?.toString() ?? 'Contact for pricing';
    final String durationText =
        bookingSettings['duration']?.toString() ?? '60 min';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book a Session',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              if (isOwnProfile && onManageSlots != null)
                TextButton(
                  onPressed: onManageSlots,
                  child: const Text('Manage Slots'),
                ),
              if (isOwnProfile) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingInboxPage(
                          providerId: guruid,
                          providerKind: BookingProviderKind.guru,
                        ),
                      ),
                    );
                  },
                  child: const Text('Inbox'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting from ₹$priceText • $durationText',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (acceptsOnline) _chip('Online'),
                    if (acceptsOffline) ...[
                      const SizedBox(width: 6),
                      _chip('In-person'),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (!isOwnProfile) GuruAvailabilityPreview(guruId: guruid),
                if (!isOwnProfile) const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onBookNow ?? () {
                      // Default: show booking dialog
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Book a Session'),
                          content: Text(
                            'Book a session with this guru. Booking feature coming soon!',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                // TODO: Navigate to booking page
                              },
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA58CE3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Book Now'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isOwnProfile) ...[
            Text(
              'Quick tip: Open Inbox to accept or decline session requests.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container( 
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFEDE7F6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: Colors.black87,
        ),
      ),
    );
  }
}
