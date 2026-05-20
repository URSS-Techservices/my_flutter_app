// ═══════════════════════════════════════════════════════════════════════════════

// reels_feed.dart — Production-Grade Reels Feed

// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:better_player/better_player.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:halo/models/media_model.dart';

import 'package:halo/services/app_cache_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────

// USER CACHE

// ─────────────────────────────────────────────────────────────────────────────

class UserCache {
  UserCache._();

  static final _cache = <String, String>{};

  static Future<String> getName(String userId) async {
    if (userId.isEmpty) return 'User';

    if (_cache.containsKey(userId)) return _cache[userId]!;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final name = (doc.data()?['username'] as String?)?.trim();

      _cache[userId] = (name != null && name.isNotEmpty) ? name : 'User';
    } catch (_) {
      _cache[userId] = 'User';
    }

    return _cache[userId]!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// URL HELPERS

// ─────────────────────────────────────────────────────────────────────────────

bool _isRawUploadUrl(String url) {
  if (url.isEmpty) return false;

  final lower = url.toLowerCase();

  return lower.contains('videos/raw/') || lower.contains('/raw/');
}

/// Primary + alternate URLs for playback and retry.

({String primary, String fallback, bool isProcessed}) resolveReelPlaybackUrls(
  Map<String, dynamic> data,
  MediaModel firstVideo,
) {
  final processed = data['processed'] == true;

  final docMp4 = (data['videoUrl'] as String? ?? '').trim();

  final docHls = (data['hlsUrl'] as String? ?? '').trim();

  final mediaMp4 = firstVideo.videoUrl.trim();

  final mediaHls = firstVideo.hlsUrl.trim();

  String? pickMp4() {
    for (final u in [docMp4, mediaMp4]) {
      if (u.isNotEmpty && !u.contains('.m3u8') && !_isRawUploadUrl(u)) {
        return u;
      }
    }

    if (processed) return null;

    for (final u in [docMp4, mediaMp4]) {
      if (u.isNotEmpty && !u.contains('.m3u8')) return u;
    }

    return null;
  }

  String? pickHls() {
    for (final u in [docHls, mediaHls]) {
      if (u.isNotEmpty && u.contains('.m3u8')) return u;
    }

    return null;
  }

  final mp4 = pickMp4();

  final hls = pickHls();

  // Processed reels: HLS first (720p segments, works across devices).
  // Unprocessed: MP4-first; HLS/MP4 as retry alternate.

  String primary = '';

  String fallback = '';

  if (processed && hls != null && hls.isNotEmpty) {
    primary = hls;

    if (mp4 != null && mp4.isNotEmpty) fallback = mp4;
  } else if (mp4 != null && mp4.isNotEmpty) {
    primary = mp4;

    if (hls != null && hls.isNotEmpty) fallback = hls;
  } else if (hls != null && hls.isNotEmpty) {
    primary = hls;
  } else {
    final preferred = firstVideo.preferredVideoUrl.trim();

    if (preferred.isNotEmpty && (!processed || !_isRawUploadUrl(preferred))) {
      primary = preferred;
    }
  }

  if (fallback.isEmpty && primary.isNotEmpty) {
    if (primary.contains('.m3u8')) {
      if (mp4 != null && mp4 != primary) fallback = mp4;
    } else if (hls != null && hls != primary) {
      fallback = hls;
    }
  }

  return (primary: primary, fallback: fallback, isProcessed: processed);
}

BetterPlayerVideoFormat _formatForUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';

  if (path.endsWith('.m3u8')) return BetterPlayerVideoFormat.hls;

  return BetterPlayerVideoFormat.other;
}

const BetterPlayerCacheConfiguration _reelCacheConfig =
    BetterPlayerCacheConfiguration(
  useCache: false,
  maxCacheSize: 0,
  maxCacheFileSize: 0,
);

// ─────────────────────────────────────────────────────────────────────────────

// REEL DATA

// ─────────────────────────────────────────────────────────────────────────────

class ReelData {
  final String id;

  final String videoUrl;

  final String fallbackVideoUrl;

  final String thumbnailUrl;

  final String caption;

  final String userId;

  final bool isProcessed;

  const ReelData({
    required this.id,
    required this.videoUrl,
    this.fallbackVideoUrl = '',
    required this.thumbnailUrl,
    required this.caption,
    required this.userId,
    this.isProcessed = false,
  });

  bool get isPlayable => videoUrl.isNotEmpty;

  factory ReelData.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final media = MediaModel.parsePostMedia(data);

    final firstVideo = media.firstWhere(
      (m) => m.isVideo,
      orElse: () => const MediaModel(
        type: 'video',
        image: MediaVariant(thumb: '', medium: '', full: ''),
        videoUrl: '',
        hlsUrl: '',
        thumbnail: '',
      ),
    );

    final urls = resolveReelPlaybackUrls(data, firstVideo);

    final thumbnailUrl = firstVideo.thumbnail.trim().isNotEmpty
        ? firstVideo.thumbnail.trim()
        : (data['thumbnailUrl'] as String? ?? '').trim();

    return ReelData(
      id: doc.id,
      videoUrl: urls.primary,
      fallbackVideoUrl: urls.fallback,
      thumbnailUrl: thumbnailUrl,
      caption: (data['caption'] as String? ?? '').trim(),
      userId: (data['userId'] as String? ?? '').trim(),
      isProcessed: urls.isProcessed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// REELS FEED

// ─────────────────────────────────────────────────────────────────────────────

class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> with WidgetsBindingObserver {
  final _pageController = PageController();

  List<ReelData> _reels = [];

  int _currentIndex = 0;

  bool _loading = true;

  bool _appPaused = false;

  final _appPausedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadReels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _pageController.dispose();

    _appPausedNotifier.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _appPaused = true;

      _appPausedNotifier.value = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_appPaused) {
        _appPaused = false;

        _appPausedNotifier.value = false;
      }
    }
  }

  Future<void> _loadReels() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reels')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (!mounted) return;

      setState(() {
        _reels = snap.docs.map(ReelData.fromDoc).toList();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
    }
  }

  void _onPageChanged(int index) {
    if (!mounted) return;

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No reels yet', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final reel = _reels[index];

          return ReelItem(
            key: ValueKey(reel.id),
            reel: reel,
            isActive: index == _currentIndex,
            shouldPreload: index == _currentIndex + 1,
            appPausedNotifier: _appPausedNotifier,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// REEL ITEM

// ─────────────────────────────────────────────────────────────────────────────

class ReelItem extends StatefulWidget {
  final ReelData reel;

  final bool isActive;

  final bool shouldPreload;

  final ValueNotifier<bool> appPausedNotifier;

  const ReelItem({
    super.key,
    required this.reel,
    required this.isActive,
    required this.shouldPreload,
    required this.appPausedNotifier,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  BetterPlayerController? _controller;

  bool _disposed = false;

  bool _videoInitialized = false;

  bool _firstFrameRendered = false;

  bool _playbackError = false;

  bool _usingFallbackUrl = false;

  bool _triedFallback = false;

  Timer? _playbackDebounce;

  bool _handlingException = false;

  bool _liked = false;

  bool _showHeartOverlay = false;

  bool _userPaused = false;

  String _username = '';

  bool get _needsController => widget.isActive || widget.shouldPreload;

  bool get _wantsPlay =>
      widget.isActive && !_userPaused && !widget.appPausedNotifier.value;

  @override
  void initState() {
    super.initState();

    widget.appPausedNotifier.addListener(_onAppPausedChanged);

    _loadUsername();

    _ensureControllerLifecycle();
  }

  void _loadUsername() async {
    final name = await UserCache.getName(widget.reel.userId);

    if (!_disposed && mounted) {
      setState(() => _username = name);
    }
  }

  void _ensureControllerLifecycle() {
    if (_needsController && widget.reel.isPlayable) {
      if (_controller == null) {
        _createController();
      }
    } else {
      _disposeController();
    }
  }

  void _createController() {
    if (_disposed || _controller != null) return;

    final url =
        _usingFallbackUrl ? widget.reel.fallbackVideoUrl : widget.reel.videoUrl;

    if (url.isEmpty) return;

    _playbackError = false;

    final config = BetterPlayerConfiguration(
      autoPlay: false,
      looping: true,
      fit: BoxFit.cover,
      aspectRatio: 9 / 16,
      expandToFill: true,
      autoDispose: false,
      handleLifecycle: false,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
        showControlsOnInitialize: false,
      ),
    );

    final controller = BetterPlayerController(config);

    controller.addEventsListener(_onPlayerEvent);

    _controller = controller;

    unawaited(_setupDataSource(controller, url));
  }

  Future<void> _setupDataSource(
    BetterPlayerController controller,
    String url,
  ) async {
    if (_disposed || _controller != controller) return;

    final dataSource = BetterPlayerDataSource.network(
      url,
      videoFormat: _formatForUrl(url),
      cacheConfiguration: _reelCacheConfig,
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: false,
      ),
    );

    try {
      await controller.setupDataSource(dataSource);
      // Playback starts from the initialized event after the surface mounts.
    } catch (e) {
      debugPrint('[ReelItem] setupDataSource error for ${widget.reel.id}: $e');

      if (!_disposed && mounted) {
        setState(() => _playbackError = true);
      }
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (_disposed || !mounted) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        setState(() => _videoInitialized = true);

        _schedulePlaybackSync();

        break;

      case BetterPlayerEventType.play:
        if (widget.isActive && !_firstFrameRendered) {
          setState(() => _firstFrameRendered = true);
        }

        break;

      case BetterPlayerEventType.finished:
        if (_wantsPlay && _controller != null) {
          unawaited(_restartLoop());
        }

        break;

      case BetterPlayerEventType.exception:
        debugPrint(
          '[ReelItem] Player exception for ${widget.reel.id}: '
          '${event.parameters}',
        );

        _handlePlaybackException();

        break;

      default:
        break;
    }
  }

  Future<void> _restartLoop() async {
    final c = _controller;

    if (_disposed || c == null || !_isVideoReady(c) || !_wantsPlay) return;

    try {
      await c.seekTo(Duration.zero);

      if (_disposed || _controller != c || !_wantsPlay) return;

      await c.play();
    } catch (e) {
      debugPrint('[ReelItem] loop restart error for ${widget.reel.id}: $e');
    }
  }

  Future<void> _handlePlaybackException() async {
    if (_disposed || !mounted || _handlingException) return;

    _handlingException = true;

    if (!_triedFallback &&
        widget.reel.fallbackVideoUrl.isNotEmpty &&
        !_usingFallbackUrl) {
      _triedFallback = true;

      _usingFallbackUrl = true;

      _disposeController(keepState: true);

      if (mounted) {
        setState(() {
          _videoInitialized = false;

          _firstFrameRendered = false;

          _playbackError = false;
        });

        _createController();
      }

      _handlingException = false;

      return;
    }

    _handlingException = false;

    setState(() => _playbackError = true);
  }

  /// Play/pause only after [BetterPlayer] is in the tree (next frame).
  void _schedulePlaybackSync() {
    _playbackDebounce?.cancel();

    _playbackDebounce = Timer(const Duration(milliseconds: 32), () {
      if (!_disposed && mounted) {
        unawaited(_applyPlayback());
      }
    });
  }

  bool _isVideoReady(BetterPlayerController c) {
    try {
      return c.isVideoInitialized() == true;
    } catch (_) {
      return false;
    }
  }

  bool _safeIsPlaying(BetterPlayerController? c) {
    if (c == null || !_isVideoReady(c)) return false;

    try {
      return c.isPlaying() == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyPlayback() async {
    final c = _controller;

    if (_disposed || c == null || !_isVideoReady(c)) return;

    try {
      if (_wantsPlay) {
        await c.setVolume(1.0);

        if (_disposed || _controller != c || !_wantsPlay) {
          await c.setVolume(0);

          await c.pause();

          return;
        }

        await c.play();
      } else {
        await c.setVolume(0);

        await c.pause();
      }
    } catch (e) {
      debugPrint('[ReelItem] playback apply error for ${widget.reel.id}: $e');
    }
  }

  void _onAppPausedChanged() {
    if (_disposed || !mounted) return;

    _schedulePlaybackSync();
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final needsNow = widget.isActive || widget.shouldPreload;

    final neededBefore = oldWidget.isActive || oldWidget.shouldPreload;

    if (widget.isActive && !oldWidget.isActive) {
      _userPaused = false;
    }

    if (needsNow != neededBefore ||
        oldWidget.reel.videoUrl != widget.reel.videoUrl) {
      _usingFallbackUrl = false;

      _triedFallback = false;

      if (!needsNow) {
        _disposeController();
      } else if (_controller == null && widget.reel.isPlayable) {
        _createController();
      }
    }

    if (oldWidget.isActive != widget.isActive ||
        oldWidget.shouldPreload != widget.shouldPreload ||
        oldWidget.reel.id != widget.reel.id) {
      _schedulePlaybackSync();
    }

    if (!widget.isActive && _firstFrameRendered) {
      setState(() => _firstFrameRendered = false);
    }
  }

  void _disposeController({bool keepState = false}) {
    _playbackDebounce?.cancel();

    final c = _controller;

    _controller = null;

    if (c != null) {
      c.removeEventsListener(_onPlayerEvent);

      unawaited(() async {
        try {
          if (_isVideoReady(c)) {
            await c.setVolume(0);

            await c.pause();
          }

          c.dispose(forceDispose: true);
        } catch (e) {
          debugPrint('[ReelItem] dispose controller error: $e');
        }
      }());
    }

    if (!keepState && mounted) {
      setState(() {
        _videoInitialized = false;

        _firstFrameRendered = false;

        _playbackError = false;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _playbackDebounce?.cancel();

    widget.appPausedNotifier.removeListener(_onAppPausedChanged);

    _disposeController(keepState: true);

    super.dispose();
  }

  void _handleTap() {
    if (_controller == null || !widget.isActive) return;

    setState(() {
      _userPaused = !_userPaused;
    });

    _schedulePlaybackSync();
  }

  void _handleDoubleTap() {
    setState(() {
      _liked = true;

      _showHeartOverlay = true;
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_disposed && mounted) {
        setState(() => _showHeartOverlay = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    final pixelWidth = (mq.size.width * mq.devicePixelRatio).round();

    final pixelHeight = (mq.size.height * mq.devicePixelRatio).round();

    final c = _controller;

    final isPlaying = _safeIsPlaying(c);

    final isBuffering = _videoInitialized &&
        c != null &&
        _isVideoReady(c) &&
        (c.isBuffering() == true);

    final showThumbnail = !widget.isActive || !_firstFrameRendered;

    final showProcessing = !widget.reel.isPlayable && !widget.reel.isProcessed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.reel.thumbnailUrl.isNotEmpty && showThumbnail)
              CachedNetworkImage(
                imageUrl: widget.reel.thumbnailUrl,
                cacheManager: AppCacheManager.media,
                fit: BoxFit.cover,
                memCacheWidth: pixelWidth,
                memCacheHeight: pixelHeight,
                placeholder: (_, __) => const ColoredBox(color: Colors.black),
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Colors.black),
              )
            else if (showThumbnail)
              const ColoredBox(color: Colors.black),

            // Surface must exist before play() — Offstage keeps preload attached.
            if (_videoInitialized && c != null && _needsController)
              Offstage(
                offstage: !widget.isActive,
                child: SizedBox.expand(
                  child: BetterPlayer(
                    key: ValueKey('reel_player_${widget.reel.id}'),
                    controller: c,
                  ),
                ),
              ),

            if (showProcessing)
              const Center(
                child: Text(
                  'Processing video…',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),

            if (_playbackError && widget.isActive)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _playbackError = false;

                      _triedFallback = false;

                      _usingFallbackUrl = false;
                    });

                    _disposeController();

                    _createController();
                  },
                  child: const Text(
                    'Tap to retry',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),

            if (isBuffering || (widget.isActive && !_videoInitialized))
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Colors.white70,
                    strokeWidth: 2,
                  ),
                ),
              ),

            if (_userPaused && widget.isActive && !isPlaying)
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 72,
                  color: Colors.white70,
                ),
              ),

            if (_showHeartOverlay)
              const Center(
                child: Icon(Icons.favorite, size: 96, color: Colors.white),
              ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.80),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.50, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              right: 10,
              bottom: 100,
              child: _ActionColumn(
                liked: _liked,
                onLikeTap: () => setState(() => _liked = !_liked),
              ),
            ),

            Positioned(
              left: 12,
              bottom: 40,
              right: 80,
              child: _CaptionBlock(
                username: _username,
                caption: widget.reel.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionColumn extends StatelessWidget {
  final bool liked;

  final VoidCallback onLikeTap;

  const _ActionColumn({required this.liked, required this.onLikeTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.favorite,
            color: liked ? Colors.red : Colors.white,
            size: 30,
          ),
          onPressed: onLikeTap,
        ),
        const SizedBox(height: 16),
        const Icon(Icons.comment, color: Colors.white, size: 28),
        const SizedBox(height: 16),
        const Icon(Icons.share, color: Colors.white, size: 28),
      ],
    );
  }
}

class _CaptionBlock extends StatelessWidget {
  final String username;

  final String caption;

  const _CaptionBlock({required this.username, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@$username',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
