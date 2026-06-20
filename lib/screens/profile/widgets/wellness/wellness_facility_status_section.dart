import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/core/wellness_facility_hours.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class WellnessFacilityStatusSection extends StatelessWidget {
  final Map<String, String> availability;
  final Map<String, dynamic>? facilityHours;
  final bool isOwnProfile;
  final VoidCallback? onEdit;

  const WellnessFacilityStatusSection({
    super.key,
    required this.availability,
    this.facilityHours,
    required this.isOwnProfile,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hours = WellnessFacilityHours(
      availability: availability,
      facilityHours: facilityHours,
    );
    final status = hours.statusAt();
    final entries = hours.displayEntries();
    final todayKey = status.scheduleKey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    'Facility Status',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (isOwnProfile && onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit, color: ProfileLayout.lavender),
                    onPressed: onEdit,
                  )
                else
                  _StatusPill(status: status),
              ],
            ),
            if (!isOwnProfile) ...[
              const SizedBox(height: 12),
              _StatusBanner(status: status),
            ],
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Text(
                isOwnProfile
                    ? 'Add your operating hours so visitors know when you\'re open.'
                    : 'Hours not published yet.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              )
            else
              ...entries.map((e) {
                final isToday = e.key == todayKey ||
                    (todayKey == 'Sun' && (e.key == 'Sunday' || e.key == 'Sun')) ||
                    (todayKey == 'Mon-Sat' && (e.key == 'Mon-Sat' || e.key == 'Mon–Sat'));
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: isToday ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : EdgeInsets.zero,
                  decoration: isToday
                      ? BoxDecoration(
                          color: ProfileLayout.lavender.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isToday) ...[
                            Icon(Icons.today, size: 16, color: ProfileLayout.deepLavender),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            e.key,
                            style: GoogleFonts.poppins(
                              fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        e.value,
                        style: GoogleFonts.poppins(
                          color: isToday ? ProfileLayout.deepLavender : Colors.grey.shade700,
                          fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final FacilityOpenStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    if (!status.hasKnownHours && status.label == 'Hours not set') {
      return Text(
        'Set hours',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
      );
    }

    final color = status.isOpen ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final FacilityOpenStatus status;

  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.isOpen ? Colors.green.shade700 : Colors.red.shade700;
    final bg = status.isOpen ? Colors.green.shade50 : Colors.red.shade50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(status.isOpen ? Icons.check_circle : Icons.schedule, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: color)),
                if (status.subtitle != null)
                  Text(
                    status.subtitle!,
                    style: GoogleFonts.poppins(fontSize: 12, color: color.withValues(alpha: 0.85)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
