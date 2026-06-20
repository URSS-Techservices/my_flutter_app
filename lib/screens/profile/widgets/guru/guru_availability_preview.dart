import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/guru_availability_service.dart';

/// Compact preview of the guru's next open bookable slots.
class GuruAvailabilityPreview extends StatelessWidget {
  final String guruId;

  const GuruAvailabilityPreview({super.key, required this.guruId});

  @override
  Widget build(BuildContext context) {
    final service = GuruAvailabilityService();
    return FutureBuilder<List<GuruAvailableSlot>>(
      future: service.getAvailableSlots(guruId: guruId, daysAhead: 7),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 4);
        }
        final slots = snapshot.data ?? const [];
        if (slots.isEmpty) {
          return Text(
            'No open slots this week — coach may add availability soon.',
            style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
          );
        }

        final preview = slots.take(4).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Open this week', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: preview.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ProfileLayout.chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${s.displayDate} · ${s.displayTime}',
                    style: GoogleFonts.poppins(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
