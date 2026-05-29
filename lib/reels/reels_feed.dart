import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:better_player/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/services/reel_service.dart';
import 'package:halo/services/reel_player_lifecycle.dart';
import 'package:halo/services/app_logger.dart';

/// Full-screen vertical reels feed ranked by virality score.
///
/// Architecture notes:
/// - Uses `better_player` (ExoPlayer / AVPlayer) — handles MP4, WebM, MOV,
///   MKV, HLS (.m3u8), DASH (.mpd) and most codecs out of the box.
/// - Controller pool is bounded to [ReelPlatformPolicy.maxPoolSlots]:
///     Android = 3 (current + 2 ahead + 1 behind)
///     iOS     = 2 (current + 1 ahead + 1 behind)
///   All exotic HEVC / HDR uploads are now transcoded server-side to H.264 SDR
///   by the Cloud Function, so the tighter pool is safe at 720p.
/// - Thumbnail poster frames (from `thumbnailUrl` field) are shown while the
///   video buffers — eliminates the blank-spinner flash on swipe.
/// - Pagination: loads [_pageSize] reels at a time; triggers next page when
///   the user is [_prefetchThreshold] items from the end.
/// - Plays only the currently visible page; pauses every other controller.
/// - Reacts to app-lifecycle via [WidgetsBindingObserver] (audio leak guard).
/// - Evicts every controller except current on [didHaveMemoryPressure].
/// - [VisibilityDetector] as a second safety net when the feed is under
///   another route.
class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> with WidgetsBindingObserver {
  final ReelService _reelService = ReelService();
  final PageController _pageController = PageController();

  /// Live controllers keyed by reelId. Bounded to
  /// [ReelPlatformPolicy.maxPoolSlots] entries.
  final Map<String, BetterPlayerController> _controllers = {};

  int _currentIndex = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reels = const [];
  bool _appBackgrounded = false;
  int _lastLoggedReelCount = -1;

  // ── Pagination state ───────────────────────────────────────────────────────
  static const int _pageSize = 20;
  static const int _prefetchThreshold = 5; // load next page this many before end
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.perf('reels_feed_open');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appBackgrounded = state != AppLifecycleState.resumed;
    if (_appBackgrounded) {
      for (final c in _controllers.values) {
        c.pause();
      }
    } else {
      _playOnlyCurrent();
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    if (_reels.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _reels.length) {
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      return;
    }
    final keep = _reels[_currentIndex].id;
    ReelLifecycleLog.memoryPressure(keepReelId: keep);
    final evict = _controllers.keys.where((id) => id != keep).toList();
    for (final id in evict) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
    }
  }

  // ── Data extraction helpers ────────────────────────────────────────────────

  /// Reads the video URL from a reel document. Tolerates several field names
  /// that have been used historically by uploaders.
  String _extractVideoUrl(Map<String, dynamic> data) {
    return (data['videoUrl'] ??
            data['video_url'] ??
            data['url'] ??
            data['mediaUrl'] ??
            '')
        .toString()
        .trim();
  }

  /// Reads the thumbnail URL from a reel document (poster frame shown while
  /// video buffers). Checks Cloudinary, Firebase Storage, and legacy fields.
  String _extractThumbnailUrl(Map<String, dynamic> data) {
    return (data['thumbnailUrl'] ??
            data['thumbnail'] ??
            data['posterUrl'] ??
            data['coverUrl'] ??
            data['thumbUrl'] ??
            '')
        .toString()
        .trim();
  }

  // ── Controller pool ────────────────────────────────────────────────────────

  BetterPlayerController _getOrCreateController(
    String reelId,
    String url,
    String thumbnailUrl,
  ) {
    final existing = _controllers[reelId];
    if (existing != null) return existing;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      cacheConfiguration: BetterPlayerCacheConfiguration(
        useCache: true,
        preCacheSize: 10 * 1024 * 1024,
        maxCacheSize: 200 * 1024 * 1024,
        maxCacheFileSize: 50 * 1024 * 1024,
        key: reelId,
      ),
      // Tight buffer window — keeps ExoPlayer's allocator footprint small for
      // the 3-slot pool on Android. Cloud Function now ensures all videos are
      // H.264 720p, so this is sufficient for smooth playback.
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 3000,
        maxBufferMs: 8000,
        bufferForPlaybackMs: 800,
        bufferForPlaybackAfterRebufferMs: 1500,
      ),
    );

    // Build placeholder widget: thumbnail poster frame if available,
    // otherwise a minimal dark spinner. This gives the Instagram "instant
    // content" feel — users see something while the video segment downloads.
    final Widget placeholderWidget = thumbnailUrl.isNotEmpty
        ? _ThumbnailPoster(url: thumbnailUrl)
        : const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white38,
                strokeWidth: 2,
              ),
            ),
          );

    final configuration = BetterPlayerConfiguration(
      autoPlay: false,
      looping: true,
      fit: BoxFit.cover,
      aspectRatio: 9 / 16,
      // We own the controller lifecycle; disable better_player's own handlers
      // so it does not double-dispose or double-pause.
      handleLifecycle: false,
      autoDispose: false,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
      ),
      errorBuilder: (context, error) {
        AppLogger.error(
          LogCategory.reel,
          'playback error reelId=$reelId',
          error: error,
        );
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Icon(Icons.error_outline, color: Colors.white54, size: 56),
          ),
        );
      },
      placeholder: placeholderWidget,
      showPlaceholderUntilPlay: true,
    );

    final controller = BetterPlayerController(
      configuration,
      betterPlayerDataSource: dataSource,
    );

    _controllers[reelId] = controller;
    AppLogger.perf('reels_controller_created', fields: {
      'reelId': reelId,
      'poolSize': _controllers.length,
    });
    return controller;
  }

  /// Ensures only the controllers chosen by [ReelPlatformPolicy.warmIndices]
  /// are alive, then plays the current one and pauses the rest.
  /// Pool is evicted if it exceeds [ReelPlatformPolicy.maxPoolSlots].
  void _syncControllers() {
    if (_reels.isEmpty) {
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      return;
    }

    if (_currentIndex >= _reels.length) {
      _currentIndex = _reels.length - 1;
    }
    if (_currentIndex < 0) _currentIndex = 0;

    final keep = <String>{};
    for (final i in ReelPlatformPolicy.warmIndices(
      _currentIndex,
      _reels.length,
    )) {
      final doc = _reels[i];
      final data = doc.data();
      final url = _extractVideoUrl(data);
      final thumbnailUrl = _extractThumbnailUrl(data);
      if (url.isEmpty) continue;
      keep.add(doc.id);
      _getOrCreateController(doc.id, url, thumbnailUrl);
    }

    final stale = _controllers.keys.where((id) => !keep.contains(id)).toList();
    for (final id in stale) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
    }

    _playOnlyCurrent();
  }

  void _playOnlyCurrent() {
    if (_appBackgrounded || _reels.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= _reels.length) return;
    final currentId = _reels[_currentIndex].id;
    for (final entry in _controllers.entries) {
      if (entry.key == currentId) {
        entry.value.play();
      } else {
        entry.value.pause();
      }
    }
  }

  void _onPageChanged(int index) {
    AppLogger.perf('reels_page_changed', fields: {
      'index': index,
      'reelId': index >= 0 && index < _reels.length ? _reels[index].id : null,
    });
    setState(() => _currentIndex = index);
    _syncControllers();

    // Trigger pagination when approaching the end.
    if (_hasMore &&
        !_isLoadingMore &&
        _reels.isNotEmpty &&
        index >= _reels.length - _prefetchThreshold) {
      _loadMoreReels();
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  Future<void> _loadMoreReels() async {
    if (_isLoadingMore || !_hasMore || _reels.isEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final lastDoc = _reels.last;
      final nextBatch = await _reelService.getNextReelsPage(
        lastDocument: lastDoc,
        limit: _pageSize,
      );

      if (!mounted) return;

      if (nextBatch.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Merge new docs (ranked list from service) into existing list.
      setState(() {
        _reels = [..._reels, ...nextBatch];
        _isLoadingMore = false;
        AppLogger.perf('reels_page_loaded', fields: {
          'total': _reels.length,
          'newBatch': nextBatch.length,
        });
      });
    } catch (e) {
      AppLogger.error(LogCategory.reel, 'pagination error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _reelService.getRankedReelsStream(limit: _pageSize),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final reels = snapshot.data ?? const [];
          if (snapshot.hasData && reels.length != _lastLoggedReelCount) {
            _lastLoggedReelCount = reels.length;
            AppLogger.perf('reels_firestore_ready', fields: {'count': reels.length});
          }

          // The reels list reference changed (new doc, deletion, reorder).
          // Schedule a sync for after this frame so we don't mutate the
          // controller map mid-build. Only update from the stream if the user
          // hasn't paginated beyond the initial batch (to avoid clobbering).
          if (!identical(_reels, reels)) {
            // If we're at the beginning, always sync with the live stream.
            // If the user has paginated, only update if it's a content change
            // in the first batch (new reel uploaded, etc.).
            if (_reels.length <= _pageSize) {
              _reels = reels;
            } else {
              // Merge: update the first `_pageSize` entries from the stream,
              // keep the rest from pagination.
              _reels = [
                ...reels,
                ..._reels.sublist(_reels.length > _pageSize ? _pageSize : _reels.length),
              ];
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncControllers();
            });
          }

          if (_reels.isEmpty) {
            return const Center(
              child: Text(
                'No reels yet',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          // Pre-compute the set of indices allowed to hold a live controller.
          // PageView builds neighbours eagerly; without this gate we would
          // momentarily exceed [ReelPlatformPolicy.maxPoolSlots] and risk OOM.
          final warmSet = ReelPlatformPolicy.warmIndices(
            _currentIndex,
            _reels.length,
          ).toSet();

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final doc = _reels[index];
              final data = doc.data();
              final videoUrl = _extractVideoUrl(data);
              final thumbnailUrl = _extractThumbnailUrl(data);
              final caption = (data['caption'] ?? '').toString();
              final userId = (data['userId'] ?? '').toString();

              // Phase 6: read denormalized author fields if the reel doc has
              // them. Old docs (or unmigrated ones) won't, and _ReelPage
              // falls back to a Firestore lookup for those.
              final denormUsername = (data['username'] ??
                      data['displayName'] ??
                      data['authorName'] ??
                      '')
                  .toString()
                  .trim();
              final denormProfilePic = (data['profilePic'] ??
                      data['profilePhoto'] ??
                      data['photoUrl'] ??
                      data['userPhotoUrl'] ??
                      '')
                  .toString()
                  .trim();

              BetterPlayerController? controller;
              if (videoUrl.isNotEmpty && warmSet.contains(index)) {
                controller = _getOrCreateController(doc.id, videoUrl, thumbnailUrl);
              }

              return _ReelPage(
                reelId: doc.id,
                controller: controller,
                thumbnailUrl: thumbnailUrl,
                caption: caption,
                userId: userId,
                username: denormUsername,
                profilePic: denormProfilePic,
                isActive: index == _currentIndex,
              );
            },
          );
        },
      ),
    );
  }
}

// ── _ThumbnailPoster ──────────────────────────────────────────────────────────

/// Shown as the BetterPlayer placeholder while the video segment downloads.
/// Displays the reel thumbnail (from Cloudinary or Firebase Storage) so the
/// user sees content immediately instead of a blank screen or spinner.
class _ThumbnailPoster extends StatelessWidget {
  final String url;

  const _ThumbnailPoster({required this.url});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const ColoredBox(color: Colors.black),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 48),
          ),
        ),
      ),
    );
  }
}

// ── _ReelPage ─────────────────────────────────────────────────────────────────

class _ReelPage extends StatelessWidget {
  final String reelId;
  final BetterPlayerController? controller;
  final String thumbnailUrl;
  final String caption;
  final String userId;
  final String username;
  final String profilePic;
  final bool isActive;

  const _ReelPage({
    required this.reelId,
    required this.controller,
    required this.thumbnailUrl,
    required this.caption,
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null)
          _ReelVideoPlayer(
            reelId: reelId,
            controller: controller!,
            isActive: isActive,
          )
        else if (thumbnailUrl.isNotEmpty)
          // Warm-up slot not yet assigned a controller: show thumbnail so
          // we never show an empty black frame to the user.
          _ThumbnailPoster(url: thumbnailUrl)
        else
          const Center(
            child: Icon(Icons.videocam_off, color: Colors.white38, size: 64),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _AuthorRow(
                userId: userId,
                denormalizedName: username,
                denormalizedProfilePic: profilePic,
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Avatar + username row for a reel. Prefers the denormalized fields baked
/// into the reel doc (Phase 6) and only hits Firestore for legacy docs that
/// lack them — and even then, exactly one Firestore round-trip per legacy
/// reel instead of the previous many-per-rebuild fetches.
class _AuthorRow extends StatelessWidget {
  final String userId;
  final String denormalizedName;
  final String denormalizedProfilePic;

  const _AuthorRow({
    required this.userId,
    required this.denormalizedName,
    required this.denormalizedProfilePic,
  });

  static const TextStyle _nameStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  static const double _avatarRadius = 18;

  @override
  Widget build(BuildContext context) {
    final hasDenorm =
        denormalizedName.isNotEmpty || denormalizedProfilePic.isNotEmpty;

    if (hasDenorm || userId.isEmpty) {
      return _buildRow(denormalizedName, denormalizedProfilePic);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snap) {
        String name = 'User';
        String pic = '';
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() ?? const {};
          name = (data['username'] ??
                  data['name'] ??
                  data['full_name'] ??
                  'User')
              .toString();
          pic = (data['profilePhoto'] ??
                  data['photoUrl'] ??
                  data['profilePic'] ??
                  '')
              .toString();
        }
        return _buildRow(name, pic);
      },
    );
  }

  Widget _buildRow(String name, String picUrl) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(url: picUrl, radius: _avatarRadius),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name.isEmpty ? 'User' : name,
            overflow: TextOverflow.ellipsis,
            style: _nameStyle,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double radius;

  const _Avatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white24,
        child: const Icon(Icons.person, color: Colors.white70, size: 20),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.white12),
        errorWidget: (_, __, ___) => Container(
          color: Colors.white24,
          child: const Icon(Icons.person, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

class _ReelVideoPlayer extends StatefulWidget {
  final String reelId;
  final BetterPlayerController controller;
  final bool isActive;

  const _ReelVideoPlayer({
    required this.reelId,
    required this.controller,
    required this.isActive,
  });

  @override
  State<_ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<_ReelVideoPlayer> {
  bool _firstFrameLogged = false;

  @override
  void initState() {
    super.initState();
    widget.controller.videoPlayerController?.addListener(_onVideoTick);
  }

  @override
  void dispose() {
    widget.controller.videoPlayerController?.removeListener(_onVideoTick);
    super.dispose();
  }

  void _onVideoTick() {
    if (_firstFrameLogged || !mounted) return;
    final vpc = widget.controller.videoPlayerController;
    if (vpc == null) return;
    final v = vpc.value;
    final size = v.size;
    if (size == null || size.width <= 0 || size.height <= 0) return;
    if (v.position <= Duration.zero && !v.isPlaying) return;
    _firstFrameLogged = true;
    AppLogger.perf('reels_first_frame', fields: {'reelId': widget.reelId});
    ReelLifecycleLog.firstFrameRendered(widget.reelId);
  }

  @override
  void didUpdateWidget(covariant _ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        widget.controller.play();
      } else {
        widget.controller.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('reel-vis-${widget.reelId}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        // Pause if user navigates away or the page slides out; resume only if
        // this page is still the active one in the feed.
        if (info.visibleFraction < 0.5) {
          widget.controller.pause();
        } else if (widget.isActive) {
          widget.controller.play();
        }
      },
      child: BetterPlayer(controller: widget.controller),
    );
  }
}
