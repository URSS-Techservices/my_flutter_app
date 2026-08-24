import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/wellness_facility_service.dart';

/// Upcoming fitness events card for wellness facility profiles.
class WellnessEventsSection extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final bool isOwnProfile;
  final VoidCallback? onManage;

  const WellnessEventsSection({
    super.key,
    required this.events,
    required this.isOwnProfile,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ProfileLayout.lavender.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fitness Events',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (isOwnProfile && onManage != null)
                  TextButton(onPressed: onManage, child: const Text('Manage')),
              ],
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promote workshops, challenges, and open-house days.',
                    style: GoogleFonts.poppins(fontSize: 14, color: ProfileLayout.textSecondary),
                  ),
                  if (onManage != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: const Text('Schedule an event'),
                    ),
                  ],
                ],
              )
            else
              Column(
                children: events.map((event) {
                  final title = WellnessFacilityService.eventTitle(event);
                  final when = WellnessFacilityService.eventWhen(event);
                  final place = event['place']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: ProfileLayout.deepLavender,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              if (when.isNotEmpty)
                                Text(
                                  when,
                                  style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
                                ),
                              if (place.isNotEmpty)
                                Text(
                                  place,
                                  style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
