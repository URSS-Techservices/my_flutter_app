import 'package:flutter/material.dart';
import 'package:halo/widgets/stats_widget.dart';

/// Standard white stats card used by aspirant + guru profiles (3 columns).
class ProfileThreeColumnStatsCard extends StatelessWidget {
  final int followers;
  final int following;
  final int posts;

  const ProfileThreeColumnStatsCard({
    super.key,
    required this.followers,
    required this.following,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: StatsWidget(
              value: followers.toString(),
              label: 'Followers',
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: StatsWidget(
              value: following.toString(),
              label: 'Following',
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: StatsWidget(
              value: posts.toString(),
              label: 'Posts',
            ),
          ),
        ],
      ),
    );
  }
}

/// Wellness stats row (4 metrics) — preserves original card styling.
class ProfileWellnessStatsCard extends StatelessWidget {
  final int followers;
  final int following;
  final int posts;
  final int likes;
  final Color cardColor;
  final Color lavenderAccent;

  const ProfileWellnessStatsCard({
    super.key,
    required this.followers,
    required this.following,
    required this.posts,
    required this.likes,
    required this.cardColor,
    required this.lavenderAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: lavenderAccent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatsWidget(value: followers.toString(), label: 'Followers'),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          StatsWidget(value: following.toString(), label: 'Following'),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          StatsWidget(value: posts.toString(), label: 'Posts'),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          StatsWidget(value: likes.toString(), label: 'Likes'),
        ],
      ),
    );
  }
}
