import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/heart_button.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';
import 'package:halo/features/feed/presentation/like_comment_data.dart' show showPostComments;
import 'package:halo/features/feed/presentation/post_detail.dart' show showPostQuickActions, toggleFollow;
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';
import 'package:halo/services/app_video_focus.dart';
import 'package:halo/services/feed_reel_prefetch.dart';
import 'package:halo/services/video_decoder_budget.dart';
import 'package:halo/services/video_dispose_serial.dart';

/// Instagram/TikTok-style fullscreen viewer: opened by tapping a post's
/// media in the feed. Swipe vertically to move to the next/previous post;
/// video autoplays for whichever page is current, exactly one decoder alive
/// at a time via [VideoDecoderBudget]'s 'feed_reel_viewer' lease.
class ReelViewerPage extends ConsumerStatefulWidget {
  final List<String> postIds;
  final int initialIndex;

  const ReelViewerPage({super.key, required this.postIds, required this.initialIndex});

  @override
  ConsumerState<ReelViewerPage> createState() => _ReelViewerPageState();
}

class _ReelViewerPageState extends ConsumerState<ReelViewerPage> {
  // Matches VideoDecoderBudget's reserved 'feed_reel_viewer' capacity
  // (1 back + 2 ahead + current = 4 slots on Android): buffer those pages'
  // videos ahead of time so swiping to one is instant instead of a cold fetch.
  static const int _preloadBehind = 1;
  static const int _preloadAhead = 2;

  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  /// Consumed once, for the very first page only: whatever [FeedReelPrefetch]
  /// already started buffering the moment the user's finger touched the
  /// thumbnail in the feed (onTapDown, before this route even opened).
  VideoPlayerController? _initialAdopted;

  @override
  void initState() {
    super.initState();
    AppVideoFocus.instance.enterFullscreenReel();
    _initialAdopted = FeedReelPrefetch.instance.take(widget.postIds[widget.initialIndex]);
  }

  @override
  void dispose() {
    AppVideoFocus.instance.exitFullscreenReel();
    unawaited(FeedReelPrefetch.instance.cancel());
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            itemCount: widget.postIds.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final distance = i - _current;
              return _ReelPage(
                postId: widget.postIds[i],
                isCurrent: i == _current,
                shouldPreload: distance >= -_preloadBehind && distance <= _preloadAhead,
                // Only current + immediate next actually render a video
                // texture — the rest keep buffering silently in the background.
                mountTexture: i == _current || i == _current + 1,
                adopted: i == widget.initialIndex ? _initialAdopted : null,
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends ConsumerWidget {
  final String postId;
  final bool isCurrent;
  final bool shouldPreload;
  final bool mountTexture;
  final VideoPlayerController? adopted;

  const _ReelPage({
    required this.postId,
    required this.isCurrent,
    required this.shouldPreload,
    required this.mountTexture,
    this.adopted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(feedPostProvider(postId));
    if (post == null) return const ColoredBox(color: Colors.black);

    final media = post.media.isNotEmpty ? post.media.first : null;
    final uid = ref.watch(currentUidProvider);
    final isMe = uid.isNotEmpty && uid == post.userId;

    return GestureDetector(
      onLongPress: () => showPostQuickActions(context, ref, post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media == null)
            const ColoredBox(color: Colors.black)
          else if (media.isVideo)
            _ReelVideo(
              postId: postId,
              media: media,
              isCurrent: isCurrent,
              shouldPreload: shouldPreload,
              mountTexture: mountTexture,
              adopted: adopted,
            )
          else
            _ReelImage(media: media),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 78,
            bottom: 44,
            child: _ReelInfo(post: post, isMe: isMe),
          ),
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ReelActions(post: post, isVideo: media?.isVideo ?? false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelImage extends StatelessWidget {
  final PostMedia media;
  const _ReelImage({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.url.isEmpty) return const ColoredBox(color: Colors.black);
    return CachedNetworkImage(
      imageUrl: media.url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: Colors.black),
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }
}

class _ReelVideo extends ConsumerStatefulWidget {
  final String postId;
  final PostMedia media;
  final bool isCurrent;
  /// True for the current page plus a small window of neighbors — the
  /// controller is created and starts buffering immediately, but only
  /// actually plays once [isCurrent] is also true. This is what makes
  /// swiping to the next post feel instant instead of a cold network fetch.
  final bool shouldPreload;
  /// Only current + immediate-next actually mount the [VideoPlayer] texture;
  /// further-preloaded pages keep buffering without paying render cost.
  final bool mountTexture;
  /// Handed off from [FeedReelPrefetch] for the page the user tapped —
  /// already warming (or fully ready) before this route even opened.
  final VideoPlayerController? adopted;

  const _ReelVideo({
    required this.postId,
    required this.media,
    required this.isCurrent,
    required this.shouldPreload,
    required this.mountTexture,
    this.adopted,
  });

  @override
  ConsumerState<_ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends ConsumerState<_ReelVideo> {
  String get _owner => 'feed_reel:${widget.postId}';
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;
  bool _acquired = false;
  bool _usedFallback = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    final adopted = widget.adopted;
    if (adopted != null) {
      _ctrl = adopted;
      _acquired = true; // lease already taken by FeedReelPrefetch under the same owner key
      adopted.addListener(_onCtrl);
      if (adopted.value.isInitialized) {
        _ready = true;
        if (widget.isCurrent) {
          adopted.setVolume(ref.read(feedMutedProvider) ? 0 : 1);
          adopted.play();
        }
      }
      return;
    }
    if (widget.shouldPreload) unawaited(_init());
  }

  @override
  void didUpdateWidget(covariant _ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPreload && !oldWidget.shouldPreload && _ctrl == null && !_initializing) {
      unawaited(_init());
    } else if (!widget.shouldPreload && oldWidget.shouldPreload) {
      unawaited(_teardown());
      return;
    }
    final c = _ctrl;
    if (c == null || !_ready) return;
    if (widget.isCurrent && !oldWidget.isCurrent) {
      c.setVolume(ref.read(feedMutedProvider) ? 0 : 1);
      c.play();
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      c.pause();
    }
  }

  @override
  void dispose() {
    final c = _ctrl;
    _ctrl = null;
    c?.removeListener(_onCtrl);
    try {
      c?.pause();
      c?.dispose();
    } catch (_) {}
    _releaseAcquired();
    super.dispose();
  }

  Future<void> _teardown() async {
    final c = _ctrl;
    _ctrl = null;
    if (c != null) {
      c.removeListener(_onCtrl);
      await VideoDisposeSerial.instance.run(() async {
        try {
          c.pause();
          await c.dispose();
        } catch (_) {}
      });
    }
    _releaseAcquired();
    if (mounted) setState(() => _ready = false);
  }

  /// HLS (.m3u8) can't be cached this way — ExoPlayer/AVPlayer fetch each
  /// segment individually and this app-level cache only ever sees the tiny
  /// playlist text, not the actual video bytes. Only a flat MP4 (the
  /// fallback path, or the primary before HLS has transcoded) benefits.
  bool _isCacheableUrl(String url) => !url.toLowerCase().contains('.m3u8');

  Future<void> _init() async {
    if (_initializing || _ctrl != null) return;
    _initializing = true;
    try {
      final url = _usedFallback ? widget.media.fallbackUrl : widget.media.url;
      if (url.isEmpty) {
        if (!_usedFallback && widget.media.fallbackUrl.isNotEmpty) {
          _usedFallback = true;
          _initializing = false;
          await _init();
          return;
        }
        if (mounted) setState(() => _error = true);
        return;
      }
      if (!VideoDecoderBudget.instance.tryAcquire(_owner)) return;
      _acquired = true;

      final cacheable = _isCacheableUrl(url);
      File? cachedFile;
      if (cacheable) {
        try {
          cachedFile = (await DefaultCacheManager().getFileFromCache(url))?.file;
        } catch (_) {}
        if (!mounted || !widget.shouldPreload) {
          _releaseAcquired();
          return;
        }
      }

      final c = cachedFile != null
          ? VideoPlayerController.file(
              cachedFile,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
            )
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
              httpHeaders: const {'Connection': 'keep-alive'},
            );
      _ctrl = c;
      c.addListener(_onCtrl);
      unawaited(c.initialize().catchError((_) {
        _releaseAcquired();
        _handleFailure();
      }));

      if (cacheable && cachedFile == null) {
        // Not cached yet — cache it now so the next time this post is
        // viewed (scrolled back to, or reopened later) plays instantly
        // from disk instead of hitting the network again.
        unawaited(() async {
          try {
            await DefaultCacheManager().downloadFile(url);
          } catch (_) {}
        }());
      }
    } catch (_) {
      _releaseAcquired();
      _handleFailure();
    } finally {
      _initializing = false;
    }
  }

  void _releaseAcquired() {
    if (_acquired) {
      VideoDecoderBudget.instance.release(_owner);
      _acquired = false;
    }
  }

  void _handleFailure() {
    if (!mounted) return;
    final c = _ctrl;
    _ctrl = null;
    c?.removeListener(_onCtrl);
    unawaited(c?.dispose().catchError((_) {}));
    if (!_usedFallback && widget.media.fallbackUrl.isNotEmpty && widget.media.fallbackUrl != widget.media.url) {
      _usedFallback = true;
      _init();
      return;
    }
    setState(() => _error = true);
  }

  void _onCtrl() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;
    if (!_ready && c.value.isInitialized) {
      c.setLooping(true);
      if (widget.isCurrent) {
        c.setVolume(ref.read(feedMutedProvider) ? 0 : 1);
        c.play();
      }
      setState(() => _ready = true);
      return;
    }
    if (c.value.hasError && !_error) {
      _releaseAcquired();
      _handleFailure();
      return;
    }
    // Repaint for the progress bar as playback advances.
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    final muted = ref.read(feedMutedProvider);
    ref.read(feedMutedProvider.notifier).state = !muted;
  }

  @override
  Widget build(BuildContext context) {
    final muted = ref.watch(feedMutedProvider);
    final c = _ctrl;
    final ready = _ready && c != null && c.value.isInitialized;
    if (widget.isCurrent) c?.setVolume(muted ? 0 : 1);
    final active = widget.isCurrent && ready;
    final showTexture = widget.mountTexture && ready;
    final buffering = active && c.value.isBuffering;
    final loading = widget.isCurrent && !ready && !_error;
    final progress = active && c.value.duration.inMilliseconds > 0
        ? c.value.position.inMilliseconds / c.value.duration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onTap: _toggleMute,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.media.thumbUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.media.thumbUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),
          if (showTexture)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
            ),
          // Thin top progress bar — same indicator Explore's reel viewer uses
          // for both first-load and mid-playback buffering, instead of a
          // center spinner.
          if (loading || buffering)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 2,
              ),
            ),
          if (_error)
            const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40)),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            right: 8,
            child: IconButton(
              icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
              onPressed: _toggleMute,
            ),
          ),
          if (active)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

const List<Shadow> _reelTextShadows = [
  Shadow(color: Color(0xAA000000), blurRadius: 8),
  Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
];

class _ReelInfo extends StatelessWidget {
  final PostData post;
  final bool isMe;
  const _ReelInfo({required this.post, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openProfile(context),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
                ),
                child: FeedAvatar(url: post.userPhotoUrl, radius: 18),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: GestureDetector(
                onTap: () => _openProfile(context),
                child: Text(
                  post.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    letterSpacing: 0.2,
                    shadows: _reelTextShadows,
                  ),
                ),
              ),
            ),
            if (!isMe && post.userId.isNotEmpty) ...[
              const SizedBox(width: 10),
              _ReelFollowButton(userId: post.userId),
            ],
          ],
        ),
        if (post.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
              shadows: _reelTextShadows,
            ),
          ),
        ],
      ],
    );
  }

  void _openProfile(BuildContext context) {
    if (post.userId.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => DynamicProfilePage(profileUserId: post.userId)));
  }
}

class _ReelFollowButton extends ConsumerWidget {
  final String userId;
  const _ReelFollowButton({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid.isEmpty || uid == userId) return const SizedBox.shrink();
    final optimistic = ref.watch(followOptimisticProvider.select((m) => m[userId]));
    final remote = ref.watch(followingProvider(userId)).valueOrNull ?? false;
    final following = optimistic ?? remote;

    return GestureDetector(
      onTap: () => toggleFollow(ref, otherId: userId, shouldFollow: !following),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          following ? 'Following' : 'Follow',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}

class _ReelActions extends ConsumerWidget {
  final PostData post;
  final bool isVideo;
  const _ReelActions({required this.post, required this.isVideo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final like = ref.watch(likeUiProvider(post.id));
    final counts = ref.watch(postCountsProvider(post.id)).valueOrNull;
    final saved = ref.watch(savedProvider(post.id));
    final comments = counts?.comments ?? post.commentCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InstantHeartButton(
          liked: like.liked,
          size: 30,
          likedColor: const Color(0xFFFF3040),
          idleColor: Colors.white,
          onTap: () => _like(ref),
        ),
        if (like.count > 0) _count(like.count),
        const SizedBox(height: 20),
        _iconButton(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => showPostComments(context, post),
        ),
        if (comments > 0) _count(comments),
        const SizedBox(height: 20),
        _iconButton(icon: Icons.send_outlined, onTap: () => _share(ref)),
        const SizedBox(height: 20),
        _iconButton(
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          onTap: () => _save(ref),
        ),
      ],
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _count(int count) {
    return Text(
      feedCount(count),
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  void _like(WidgetRef ref) {
    final uid = ref.read(currentUidProvider);
    if (uid.isEmpty) {
      HaloToast.show('Sign in to like posts');
      return;
    }
    unawaited(
      ref.read(likeUiProvider(post.id).notifier).toggle().catchError((_) {
        HaloToast.show('Could not update like');
      }),
    );
  }

  Future<void> _save(WidgetRef ref) async {
    final uid = ref.read(currentUidProvider);
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

  Future<void> _share(WidgetRef ref) async {
    try {
      final text = [
        if (post.username.isNotEmpty) post.username,
        if (post.caption.isNotEmpty) post.caption,
        'https://halo.app/post/${post.id}',
      ].join('\n');
      await Share.share(text);
      await ref.read(feedRepositoryProvider).addShare(postId: post.id);
    } catch (_) {
      HaloToast.show('Could not share post');
    }
  }
}
