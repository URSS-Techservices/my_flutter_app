import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';

class AspirantRecentActivitiesSection extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final bool isOwnProfile;
  final VoidCallback? onEdit;

  const AspirantRecentActivitiesSection({
    super.key,
    required this.activities,
    required this.isOwnProfile,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activities', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              if (isOwnProfile && onEdit != null)
                TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18), label: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 10),
          if (activities.isEmpty && isOwnProfile)
            const ProfileEmptyStateRich(
              text: 'No activities yet. Add your first match, session or practice!',
              icon: Icons.star_border,
              card: true,
            )
          else if (activities.isEmpty)
            const SizedBox.shrink()
          else
            ...activities.map((w) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.sports, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w['title']?.toString() ?? 'Activity',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 12,
                            runSpacing: 2,
                            children: [
                              if (w['intensity'] != null) _tag(w['intensity'].toString()),
                              if (w['calories'] != null) _tag(w['calories'].toString()),
                              if (w['duration'] != null) _tag(w['duration'].toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 11)),
    );
  }
}
