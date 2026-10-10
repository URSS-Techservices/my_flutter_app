import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/profile_feature/domain/profile_activity.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_posts_grid.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

/// "Recent Activity" — the 3 newest posts and follows. "Show more" expands
/// the list in place, no new page.
class ProfileActivitySection extends ConsumerStatefulWidget {
  const ProfileActivitySection({super.key, required this.profileUserId});

  final String profileUserId;

  @override
  ConsumerState<ProfileActivitySection> createState() =>
      _ProfileActivitySectionState();
}

class _ProfileActivitySectionState
    extends ConsumerState<ProfileActivitySection> {
  static const _shown = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(profileActivityProvider(widget.profileUserId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(title: 'Recent Activity'),
        activity.when(
          // Same height as one row, so the page does not jump.
          loading: () => const SizedBox(height: 72),
          error: (_, __) => const ProfileEmptyMessage(
            icon: Icons.error_outline,
            text: 'Could not load activity',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const ProfileEmptyMessage(
                icon: Icons.timeline,
                text: 'No recent activity',
              );
            }
            final hasMore = items.length > _shown;
            return AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  ProfileActivityList(
                    profileUserId: widget.profileUserId,
                    items: _expanded ? items : items.take(_shown).toList(),
                  ),
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ProfileTextLink(
                        label: _expanded ? 'Show less' : 'Show more',
                        icon: _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        onTap: () => setState(() => _expanded = !_expanded),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Bordered card of activity rows.
class ProfileActivityList extends ConsumerWidget {
  const ProfileActivityList({
    super.key,
    required this.profileUserId,
    required this.items,
  });

  final String profileUserId;
  final List<ProfileActivity> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(profileProvider(profileUserId).select(
      (async) {
        final b = async.valueOrNull;
        return (name: b?.name ?? '', photo: b?.profilePhoto ?? '');
      },
    ));
    final postIds = [
      for (final a in items)
        if (a.post != null) a.post!.id,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileStyle.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: ProfileStyle.divider),
            _ActivityRow(
              item: items[i],
              ownerName: owner.name.isEmpty ? 'Halo user' : owner.name,
              ownerPhoto: owner.photo,
              onTap: () {
                final item = items[i];
                if (item.post != null) {
                  openPost(context, postIds, postIds.indexOf(item.post!.id));
                } else if (item.followed != null) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        DynamicProfilePage(profileUserId: item.followed!.id),
                  ));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.ownerName,
    required this.ownerPhoto,
    required this.onTap,
  });

  final ProfileActivity item;
  final String ownerName;
  final String ownerPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final followed = item.followed;
    final isVideo = post != null &&
        post.media.isNotEmpty &&
        post.media.first.isVideo;

    final action = post != null
        ? (isVideo ? 'posted a new video' : 'posted a new photo')
        : 'started following ${followed!.displayName}';
    final thumb = post != null && post.media.isNotEmpty
        ? post.media.first.thumbUrl
        : followed?.photoUrl ?? '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _RoundImage(url: ownerPhoto, size: 40, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: ownerName,
                        style: ProfileStyle.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' $action', style: ProfileStyle.body),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.at != null)
                    Text(feedTimeAgo(item.at), style: ProfileStyle.small),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _RoundImage(url: thumb, size: 48, circle: followed != null),
            const Icon(Icons.chevron_right, color: ProfileStyle.mutedText),
          ],
        ),
      ),
    );
  }
}

class _RoundImage extends StatelessWidget {
  const _RoundImage({
    required this.url,
    required this.size,
    required this.circle,
  });

  final String url;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final radius = BorderRadius.circular(circle ? size / 2 : 8);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(
                color: ProfileStyle.surface,
                child: Icon(Icons.person, color: ProfileStyle.mutedText),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (size * dpr).round(),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: ProfileStyle.surface),
              ),
      ),
    );
  }
}
