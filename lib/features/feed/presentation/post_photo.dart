import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/media_aspect_data.dart';
import 'package:halo/features/feed/presentation/post_image.dart';
import 'package:halo/features/feed/presentation/post_media_chrome.dart';
import 'package:halo/features/feed/presentation/post_video.dart';

class PostPhoto extends ConsumerStatefulWidget {
  final PostData post;
  final VoidCallback? onDoubleLike;

  const PostPhoto({
    super.key,
    required this.post,
    this.onDoubleLike,
  });

  @override
  ConsumerState<PostPhoto> createState() => _PostPhotoState();
}

class _PostPhotoState extends ConsumerState<PostPhoto> {
  final _pc = PageController();
  int _page = 0;
  bool _heart = false;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _doubleTap() {
    HapticFeedback.lightImpact();
    setState(() => _heart = true);
    widget.onDoubleLike?.call();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _heart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.post.media;
    if (items.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(color: HomeLayout.mediaFill),
      );
    }

    final measured = ref.watch(
      mediaAspectProvider(widget.post.id).select((m) => m[_page]),
    );
    final stored =
        _page >= 0 && _page < items.length ? items[_page].aspectRatio : null;
    final aspect = HomeLayout.mediaAspect(measured ?? stored);
    final cacheW = HomeLayout.imageCacheWidth(context);
    final muted = ref.watch(feedMutedProvider);

    return GestureDetector(
      onDoubleTap: widget.onDoubleLike == null ? null : _doubleTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              ColoredBox(
                color: HomeLayout.mediaFill,
                child: PageView.builder(
                  controller: _pc,
                  itemCount: items.length,
                  allowImplicitScrolling: true,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _MediaPage(
                    postId: widget.post.id,
                    index: i,
                    media: items[i],
                    cacheWidth: cacheW,
                    muted: muted,
                    onMuteToggle: () {
                      ref.read(feedMutedProvider.notifier).state = !muted;
                    },
                  ),
                ),
              ),
              PostMediaChrome(
                page: _page,
                count: items.length,
                location: widget.post.location,
                showHeart: _heart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPage extends StatelessWidget {
  final String postId;
  final int index;
  final PostMedia media;
  final int cacheWidth;
  final bool muted;
  final VoidCallback onMuteToggle;

  const _MediaPage({
    required this.postId,
    required this.index,
    required this.media,
    required this.cacheWidth,
    required this.muted,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return PostInlineVideo(
        postId: postId,
        index: index,
        videoUrl: media.url,
        thumbUrl: media.thumbUrl,
        cacheWidth: cacheWidth,
        muted: muted,
        onMuteToggle: onMuteToggle,
      );
    }
    return FittedPostImage(
      postId: postId,
      index: index,
      url: media.url,
      thumbUrl: media.thumbUrl,
      cacheWidth: cacheWidth,
    );
  }
}
