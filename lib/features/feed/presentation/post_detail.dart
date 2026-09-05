import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/like_comment_data.dart';
import 'package:halo/features/feed/presentation/post_photo.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

class PostDetail extends ConsumerWidget {
  final PostData post;
  final Color accent;

  const PostDetail({
    super.key,
    required this.post,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final isMe = uid.isNotEmpty && uid == post.userId;
    final time = feedTimeAgo(post.createdAt);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openProfile(context),
                  child: FeedAvatar(url: post.userPhotoUrl, radius: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openProfile(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF262626),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E8E),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isMe && post.userId.isNotEmpty)
                  FollowButton(userId: post.userId),
                IconButton(
                  onPressed: () => _more(context, ref, uid, isMe),
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF262626)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          PostPhoto(
            post: post,
            onDoubleLike: uid.isEmpty ? null : () => _doubleLike(ref, uid),
          ),
          LikeCommentData(post: post),
          if (post.caption.isNotEmpty || post.tags.isNotEmpty)
            FeedCaption(
              username: post.username,
              caption: post.caption,
              tags: post.tags,
              accent: accent,
            )
          else
            const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.4, color: Color(0xFFDBDBDB)),
        ],
      ),
    );
  }

  void _doubleLike(WidgetRef ref, String uid) {
    if (uid.isEmpty) return;
    unawaited(ref.read(likeUiProvider(post.id).notifier).likeOnly());
  }

  void _openProfile(BuildContext context) {
    if (post.userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicProfilePage(profileUserId: post.userId),
      ),
    );
  }

  Future<void> _message(BuildContext context, String uid) async {
    if (uid.isEmpty || post.userId.isEmpty) return;
    try {
      final chatId = await ChatService().getOrCreateChatId(uid, post.userId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            currentUserId: uid,
            otherUserId: post.userId,
          ),
        ),
      );
    } catch (_) {
      HaloToast.show('Could not open chat');
    }
  }

  void _more(
    BuildContext context,
    WidgetRef ref,
    String uid,
    bool isMe,
  ) {
    final following = ref.read(followOptimisticProvider)[post.userId] ??
        ref.read(followingProvider(post.userId)).valueOrNull ??
        false;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _message(context, uid);
                },
              ),
            if (!isMe)
              ListTile(
                leading: Icon(following ? Icons.person_remove_outlined : Icons.person_add_outlined),
                title: Text(following ? 'Unfollow' : 'Follow'),
                onTap: () {
                  Navigator.pop(ctx);
                  toggleFollow(ref, otherId: post.userId, shouldFollow: !following);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Close'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> toggleFollow(
  WidgetRef ref, {
  required String otherId,
  required bool shouldFollow,
}) async {
  final uid = ref.read(currentUidProvider);
  if (uid.isEmpty) {
    HaloToast.show('Sign in to follow');
    return;
  }
  if (otherId.isEmpty || otherId == uid) return;
  ref.read(followOptimisticProvider.notifier).update((m) => {...m, otherId: shouldFollow});
  try {
    await ref.read(feedRepositoryProvider).toggleFollow(
          userId: uid,
          otherUserId: otherId,
          shouldFollow: shouldFollow,
        );
  } catch (_) {
    ref.read(followOptimisticProvider.notifier).update((m) => {...m, otherId: !shouldFollow});
    HaloToast.show('Could not update follow');
  }
}

/// Isolated so Follow does not rebuild the post, video, or feed.
class FollowButton extends ConsumerWidget {
  final String userId;

  const FollowButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid.isEmpty || uid == userId) return const SizedBox.shrink();

    final optimistic = ref.watch(followOptimisticProvider.select((m) => m[userId]));
    final remote = ref.watch(followingProvider(userId)).valueOrNull ?? false;
    final following = optimistic ?? remote;

    return TextButton(
      onPressed: () => toggleFollow(ref, otherId: userId, shouldFollow: !following),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        following ? 'Following' : 'Follow',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: following ? const Color(0xFF262626) : const Color(0xFF0095F6),
        ),
      ),
    );
  }
}

class FeedCaption extends StatefulWidget {
  final String username;
  final String caption;
  final List<String> tags;
  final Color accent;

  const FeedCaption({
    super.key,
    required this.username,
    required this.caption,
    required this.tags,
    required this.accent,
  });

  @override
  State<FeedCaption> createState() => _FeedCaptionState();
}

class _FeedCaptionState extends State<FeedCaption> {
  bool _expanded = false;

  TextSpan get _span => TextSpan(
        children: [
          TextSpan(
            text: '${widget.username} ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF262626),
            ),
          ),
          if (widget.caption.isNotEmpty)
            TextSpan(
              text: widget.caption,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF262626),
                height: 1.35,
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final tags = widget.tags.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.caption.isNotEmpty || widget.username.isNotEmpty)
                Text.rich(
                  _span,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              if (!_expanded && widget.caption.isEmpty && tags.isNotEmpty)
                Text(
                  tags.map((t) => '#$t').join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_expanded && tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.map((t) {
                    return Text(
                      '#$t',
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
