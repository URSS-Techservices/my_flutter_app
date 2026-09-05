import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/heart_button.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/likers_sheet.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';
import 'package:share_plus/share_plus.dart';

class LikeCommentData extends ConsumerStatefulWidget {
  final PostData post;
  final VoidCallback? onLike;

  const LikeCommentData({super.key, required this.post, this.onLike});

  @override
  ConsumerState<LikeCommentData> createState() => _LikeCommentDataState();
}

class _LikeCommentDataState extends ConsumerState<LikeCommentData> {
  late int _shares = widget.post.shareCount;

  PostData get post => widget.post;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final like = ref.watch(likeUiProvider(post.id));
    final counts = ref.watch(postCountsProvider(post.id)).valueOrNull;
    final saved = ref.watch(savedProvider(post.id));
    final scale = HomeLayout.textScale(context);
    final icon = (24.0 * scale).clamp(20.0, 30.0);
    final comments = counts?.comments ?? post.commentCount;
    final shares = _shares > (counts?.shares ?? post.shareCount)
        ? _shares
        : (counts?.shares ?? post.shareCount);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InstantHeartButton(
                  liked: like.liked,
                  size: icon,
                  onTap: () => _like(uid),
                ),
                _count(
                  like.count,
                  onTap: like.count > 0 ? () => showPostLikers(context, post.id) : null,
                ),
                _btn(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: comments,
                  size: icon,
                  onTap: () => showPostComments(context, post),
                ),
                _btn(
                  icon: Icons.send_outlined,
                  count: shares,
                  size: icon,
                  onTap: () => _share(),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _save(uid),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: icon,
                    color: const Color(0xFF262626),
                  ),
                ),
              ],
            ),
            if (like.count > 0)
              _LikedByLine(
                count: like.count,
                onTap: () => showPostLikers(context, post.id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _count(int count, {VoidCallback? onTap}) {
    if (count <= 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          feedCount(count),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF262626),
          ),
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required int count,
    required double size,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: const Color(0xFF262626)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                feedCount(count),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF262626),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _like(String uid) {
    if (uid.isEmpty) {
      HaloToast.show('Sign in to like posts');
      return;
    }
    widget.onLike?.call();
    unawaited(
      ref.read(likeUiProvider(post.id).notifier).toggle().catchError((_) {
        HaloToast.show('Could not update like');
      }),
    );
  }

  Future<void> _save(String uid) async {
    if (uid.isEmpty) {
      HaloToast.show('Sign in to save posts');
      return;
    }
    try {
      await ref.read(feedRepositoryProvider).toggleSave(userId: uid, postId: post.id);
    } catch (_) {
      HaloToast.show('Could not save post');
    }
  }

  Future<void> _share() async {
    try {
      final text = [
        if (post.username.isNotEmpty) post.username,
        if (post.caption.isNotEmpty) post.caption,
        'https://halo.app/post/${post.id}',
      ].join('\n');
      await Share.share(text);
      await ref.read(feedRepositoryProvider).addShare(postId: post.id);
      if (!mounted) return;
      final live = ref.read(postCountsProvider(post.id)).valueOrNull?.shares ?? post.shareCount;
      final current = _shares > live ? _shares : live;
      setState(() => _shares = current + 1);
    } catch (_) {
      HaloToast.show('Could not share post');
    }
  }
}

class _LikedByLine extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _LikedByLine({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final who = count == 1 ? '1 person' : '${feedCount(count)} people';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 8, 4),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Liked by ',
                style: TextStyle(fontSize: 13, color: Color(0xFF262626)),
              ),
              TextSpan(
                text: who,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF262626),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showPostComments(BuildContext context, PostData post) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CommentsSheet(post: post),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final PostData post;
  const _CommentsSheet({required this.post});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = ref.read(currentUidProvider);
    final text = _ctrl.text.trim();
    if (uid.isEmpty) {
      HaloToast.show('Sign in to comment');
      return;
    }
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(feedRepositoryProvider).addComment(
            userId: uid,
            postId: widget.post.id,
            text: text,
          );
      _ctrl.clear();
    } catch (_) {
      HaloToast.show('Could not post comment');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.post.id));
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: h,
        child: Column(
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
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Comments', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: comments.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => const Center(child: Text('Could not load comments')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(child: Text('No comments yet'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      return _CommentRow(
                        postId: widget.post.id,
                        comment: list[i],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends ConsumerWidget {
  final String postId;
  final CommentData comment;

  const _CommentRow({required this.postId, required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final target = CommentRef(postId: postId, commentId: comment.id);
    final like = ref.watch(commentLikeUiProvider(target));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: comment.userId.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DynamicProfilePage(profileUserId: comment.userId),
                      ),
                    ),
            child: FeedAvatar(url: comment.photoUrl, radius: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: comment.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF262626),
                        ),
                      ),
                      TextSpan(
                        text: '  ${comment.text}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF262626),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (comment.createdAt != null)
                      Text(
                        feedTimeAgo(comment.createdAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E8E)),
                      ),
                    if (like.count > 0) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => showCommentLikers(context, target),
                        child: Text(
                          like.count == 1 ? '1 like' : '${like.count} likes',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E8E8E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          CommentHeartButton(
            liked: like.liked,
            count: like.count,
            onLike: () => _likeComment(ref, uid, target),
            onShowLikers: like.count > 0 ? () => showCommentLikers(context, target) : null,
          ),
        ],
      ),
    );
  }

  void _likeComment(WidgetRef ref, String uid, CommentRef target) {
    if (uid.isEmpty) {
      HaloToast.show('Sign in to like comments');
      return;
    }
    unawaited(
      ref.read(commentLikeUiProvider(target).notifier).toggle().catchError((_) {
        HaloToast.show('Could not like comment');
      }),
    );
  }
}
