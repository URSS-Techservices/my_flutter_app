import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuruAnalyticsSection extends StatelessWidget {
  final String guruid;
  final bool isOwnProfile;
  final Map<String, dynamic> analytics;

  const GuruAnalyticsSection({
    Key? key,
    required this.guruid,
    required this.isOwnProfile,
    required this.analytics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile) return const SizedBox.shrink();

    final int views = (analytics['profileViews'] ?? 0) as int;
    final int saves = (analytics['profileSaves'] ?? 0) as int;
    final int bookings = (analytics['bookingsThisMonth'] ?? 0) as int;
    final int followersGrowth =
    (analytics['followersGrowth'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics (Only you)',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Profile views', views.toString()),
              _statCard('Saves', saves.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statCard('Bookings (month)', bookings.toString()),
              _statCard('Follower growth', '+$followersGrowth'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These stats help you understand how your profile is performing.\nWe will keep adding more analytics here.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
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
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
