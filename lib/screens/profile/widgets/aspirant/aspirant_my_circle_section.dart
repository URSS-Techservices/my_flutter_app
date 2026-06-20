import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/services/profile_circle_service.dart';
import 'package:halo/services/wellness_check_in_service.dart';

/// Saved coaches and wellness places, plus visit streak from check-ins.
class AspirantMyCircleSection extends StatelessWidget {
  final String aspirantUserId;
  final bool isOwnProfile;

  const AspirantMyCircleSection({
    super.key,
    required this.aspirantUserId,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile) return const SizedBox.shrink();

    final circleService = ProfileCircleService();
    final checkInService = WellnessCheckInService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_outlined, color: ProfileLayout.deepLavender),
              const SizedBox(width: 8),
              Text('My Circle', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              StreamBuilder<int>(
                stream: checkInService.visitStreakStream(aspirantUserId),
                builder: (context, snap) {
                  final streak = snap.data ?? 0;
                  if (streak <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ProfileLayout.chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, size: 16, color: ProfileLayout.deepLavender),
                        const SizedBox(width: 4),
                        Text('$streak-day visits', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Coaches and wellness places you saved',
            style: GoogleFonts.poppins(fontSize: 12, color: ProfileLayout.textSecondary),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: circleService.savedProfilesStream(aspirantUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const ProfileEmptyState(
                  text: 'Save coaches and wellness spots from their profiles to see them here.',
                  card: true,
                );
              }

              return SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item['profileUserId']?.toString() ?? item['id']?.toString() ?? '';
                    final name = item['displayName']?.toString() ?? 'Profile';
                    final type = item['accountType']?.toString() ?? '';
                    final photo = item['profilePhoto'] as String?;
                    final category = item['category']?.toString() ?? type;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: id.isEmpty
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ProfileRouterScreen(profileUserId: id)),
                              ),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: photo != null
                                  ? NetworkImage(photo)
                                  : const AssetImage('assets/images/Profile.png') as ImageProvider,
                            ),
                            const SizedBox(height: 6),
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(category, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 9, color: Colors.black54)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
