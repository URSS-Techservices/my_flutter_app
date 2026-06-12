import 'package:flutter/material.dart';
import 'package:halo/widgets/stats_widget.dart';

/// Standard white stats card used by aspirant + guru profiles (3 columns).
class ProfileThreeColumnStatsCard extends StatelessWidget {
  final int followers;
  final int following;
  final int posts;
  final VoidCallback? onTapFollowers;
  final VoidCallback? onTapFollowing;
  final VoidCallback? onTapPosts;

  const ProfileThreeColumnStatsCard({
    super.key,
    required this.followers,
    required this.following,
    required this.posts,
    this.onTapFollowers,
    this.onTapFollowing,
    this.onTapPosts,
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTap(
              onTap: onTapFollowers,
              child: StatsWidget(
                value: followers.toString(),
                label: 'Followers',
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: _StatTap(
              onTap: onTapFollowing,
              child: StatsWidget(
                value: following.toString(),
                label: 'Following',
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: _StatTap(
              onTap: onTapPosts,
              child: StatsWidget(
                value: posts.toString(),
                label: 'Posts',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _StatTap({this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
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
  final VoidCallback? onTapFollowers;
  final VoidCallback? onTapFollowing;
  final VoidCallback? onTapPosts;

  const ProfileWellnessStatsCard({
    super.key,
    required this.followers,
    required this.following,
    required this.posts,
    required this.likes,
    required this.cardColor,
    required this.lavenderAccent,
    this.onTapFollowers,
    this.onTapFollowing,
    this.onTapPosts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTap(
              onTap: onTapFollowers,
              child: StatsWidget(
                value: followers.toString(),
                label: 'Followers',
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: _StatTap(
              onTap: onTapFollowing,
              child: StatsWidget(
                value: following.toString(),
                label: 'Following',
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: _StatTap(
              onTap: onTapPosts,
              child: StatsWidget(
                value: posts.toString(),
                label: 'Posts',
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          Expanded(
            child: StatsWidget(
              value: likes.toString(),
              label: 'Likes',
            ),
          ),
        ],
      ),
    );
  }
}
