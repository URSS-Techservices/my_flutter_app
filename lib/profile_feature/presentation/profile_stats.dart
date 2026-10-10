import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/presentation/profile_people_sheet.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:intl/intl.dart';

final _compact = NumberFormat.compact();

/// Following / Followers / Posts row. Followers / Following open a sheet;
/// Posts scrolls down to the grid.
class ProfileStats extends ConsumerWidget {
  const ProfileStats({
    super.key,
    required this.profileUserId,
    required this.onPostsTap,
  });

  final String profileUserId;
  final VoidCallback onPostsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stored counters show instantly; real counts replace them once loaded.
    final stored = ref.watch(profileProvider(profileUserId).select(
      (async) {
        final b = async.valueOrNull;
        return (
          following: b?.followingCount ?? 0,
          followers: b?.followersCount ?? 0,
          posts: b?.postsCount ?? 0,
        );
      },
    ));
    final counted = ref.watch(profileCountsProvider(profileUserId)).valueOrNull;
    final stats = counted == null
        ? stored
        : (
            following: counted.following,
            followers: counted.followers,
            posts: counted.posts,
          );

    void openPeople({required bool followers}) => showPeopleSheet(
          context,
          userId: profileUserId,
          followers: followers,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileStyle.sideGap,
        vertical: 12,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Stat(
              value: stats.following,
              label: 'Following',
              onTap: () => openPeople(followers: false),
            ),
            const VerticalDivider(color: ProfileStyle.divider, width: 1),
            _Stat(
              value: stats.followers,
              label: 'Followers',
              onTap: () => openPeople(followers: true),
            ),
            const VerticalDivider(color: ProfileStyle.divider, width: 1),
            _Stat(value: stats.posts, label: 'Posts', onTap: onPostsTap),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.onTap});

  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(_compact.format(value), style: ProfileStyle.statNumber),
              const SizedBox(height: 2),
              Text(label, style: ProfileStyle.statLabel),
            ],
          ),
        ),
      ),
    );
  }
}
