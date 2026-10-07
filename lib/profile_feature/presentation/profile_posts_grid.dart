import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/reel_viewer_page.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

const _gap = 3.0;
const _tileAspect = 0.8;
const _placeholder = Color(0xFFE5E7EB);

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  mainAxisSpacing: _gap,
  crossAxisSpacing: _gap,
  childAspectRatio: _tileAspect,
);

/// Posts shown before "See All".
const profilePostsPreviewCount = 6;

/// "My Posts / Posts" title with See All / Show less when there are more
/// than [profilePostsPreviewCount] posts.
class ProfilePostsHeader extends ConsumerWidget {
  const ProfilePostsHeader({
    super.key,
    required this.profileUserId,
    required this.isOwnProfile,
    required this.expanded,
    required this.onToggle,
  });

  final String profileUserId;
  final bool isOwnProfile;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMore = ref.watch(profilePostsProvider(profileUserId).select(
      (async) {
        final s = async.valueOrNull;
        return s != null &&
            (s.posts.length > profilePostsPreviewCount || s.hasMore);
      },
    ));
    return ProfileSectionHeader(
      title: isOwnProfile ? 'My Posts' : 'Posts',
      onSeeAll: hasMore ? onToggle : null,
      actionLabel: expanded ? 'Show less' : 'See All',
    );
  }
}

/// Instagram-style posts grid. Shows [profilePostsPreviewCount] posts; when
/// [expanded] it shows all and loads older ones as you scroll — all on the
/// same page.
class ProfilePostsGrid extends ConsumerWidget {
  const ProfilePostsGrid({
    super.key,
    required this.profileUserId,
    required this.isOwnProfile,
    required this.expanded,
  });

  final String profileUserId;
  final bool isOwnProfile;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profilePostsProvider(profileUserId));
    const padding = EdgeInsets.symmetric(horizontal: _gap);

    return async.when(
      // Grey tiles in the final layout, so nothing jumps when posts arrive.
      loading: () => SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: _gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, __) => const ColoredBox(color: _placeholder),
            childCount: 6,
          ),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: TextButton(
          onPressed: () => ref.invalidate(profilePostsProvider(profileUserId)),
          child: const Text('Could not load posts. Tap to retry'),
        ),
      ),
      data: (state) {
        final all = state.posts;
        final posts =
            expanded ? all : all.take(profilePostsPreviewCount).toList();
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: ProfileEmptyMessage(
              icon: Icons.photo_library_outlined,
              text: isOwnProfile
                  ? 'No posts added yet. Share your first one!'
                  : 'No posts added yet',
            ),
          );
        }
        final ids = all.map((p) => p.id).toList();
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverGrid(
                gridDelegate: _gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    // Near the end: fetch the next page in the background.
                    if (expanded && state.hasMore && i >= posts.length - 6) {
                      Future.microtask(() => ref
                          .read(profilePostsProvider(profileUserId).notifier)
                          .loadMore());
                    }
                    return ProfilePostTile(
                      post: posts[i],
                      onTap: () => openPost(context, ids, i),
                    );
                  },
                  childCount: posts.length,
                ),
              ),
            ),
            if (expanded && state.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Opens posts in the same full-screen viewer the feed uses.
void openPost(BuildContext context, List<String> postIds, int index) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ReelViewerPage(postIds: postIds, initialIndex: index),
  ));
}

/// Thumbnail with video / multi-photo badges. Likes show only inside the post.
class ProfilePostTile extends StatelessWidget {
  const ProfilePostTile({super.key, required this.post, required this.onTap});

  final PostData post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = post.media.isEmpty ? null : post.media.first;
    final thumb = first == null
        ? ''
        : (first.thumbUrl.isNotEmpty ? first.thumbUrl : (first.isVideo ? '' : first.url));
    final width = MediaQuery.sizeOf(context).width / 3;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumb.isEmpty)
            const ColoredBox(
              color: _placeholder,
              child: Icon(Icons.image_outlined, color: ProfileStyle.mutedText),
            )
          else
            CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              memCacheWidth: (width * dpr).round(),
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => const ColoredBox(color: _placeholder),
              errorWidget: (_, __, ___) => const ColoredBox(color: _placeholder),
            ),
          if (first != null && (first.isVideo || post.media.length > 1))
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                first.isVideo ? Icons.play_circle_fill : Icons.collections,
                size: 18,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 4)],
              ),
            ),
        ],
      ),
    );
  }
}
