import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
              if (isOwnProfile)
                TextButton(
                  onPressed: onManageSlots ?? () {
                    // Default: show dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Manage Booking Slots'),
                        content: const Text('Booking management feature coming soon!'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Manage Slots'),
                ),
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
              'Upcoming Sessions',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            if (upcomingSessions.isEmpty)
              Text(
                'No upcoming sessions yet.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              )
            else
              ...upcomingSessions.take(3).map((s) => _sessionTile(s)),
            const SizedBox(height: 10),
            Text(
              'Past Sessions',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            if (pastSessions.isEmpty)
              Text(
                'No past sessions yet.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              )
            else
              ...pastSessions.take(3).map((s) => _sessionTile(s)),
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

  Widget _sessionTile(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.event, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['title']?.toString() ?? 'Session',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['time']?.toString() ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
