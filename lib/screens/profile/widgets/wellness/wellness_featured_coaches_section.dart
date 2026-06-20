import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Featured gurus linked from a wellness facility profile.
class WellnessFeaturedCoachesSection extends StatelessWidget {
  final List<String> guruIds;
  final bool isOwnProfile;
  final VoidCallback? onManage;

  const WellnessFeaturedCoachesSection({
    super.key,
    required this.guruIds,
    required this.isOwnProfile,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (guruIds.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Featured Coaches', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              if (isOwnProfile && onManage != null)
                TextButton(onPressed: onManage, child: const Text('Manage')),
            ],
          ),
          const SizedBox(height: 8),
          if (guruIds.isEmpty)
            Text(
              isOwnProfile ? 'Highlight coaches who train at your facility' : 'No featured coaches yet',
              style: GoogleFonts.poppins(fontSize: 13, color: ProfileLayout.textSecondary),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: guruIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _CoachChip(guruId: guruIds[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoachChip extends StatelessWidget {
  final String guruId;

  const _CoachChip({required this.guruId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(guruId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final name = (data['name'] ?? data['full_name'] ?? 'Coach').toString();
        final photo = data['profilePhoto'] as String?;
        final category = (data['primaryCategory'] ?? 'Coach').toString();

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileRouterScreen(profileUserId: guruId)),
          ),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ProfileLayout.lavender.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: photo != null
                      ? NetworkImage(photo)
                      : const AssetImage('assets/images/Profile.png') as ImageProvider,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 9, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
