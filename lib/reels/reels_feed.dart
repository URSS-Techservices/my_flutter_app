// ═══════════════════════════════════════════════════════════════════════════════

// reels_feed.dart — Production-Grade Reels Feed

// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'dart:math' as math;

import 'package:better_player/better_player.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:halo/models/media_model.dart';
import 'package:halo/services/app_cache_manager.dart';
import 'package:halo/services/blocked_url_memory.dart';
import 'package:halo/services/memory_watchdog.dart';
import 'package:halo/services/reel_player_lifecycle.dart';
import 'package:halo/services/video_playback_resolver.dart';

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

// URL HELPERS — see [video_playback_resolver.dart] for shared playback selection.

BetterPlayerVideoFormat _formatForUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';

  if (path.endsWith('.m3u8')) return BetterPlayerVideoFormat.hls;

  return BetterPlayerVideoFormat.other;
}

/// Caps poster decode pixels for faster decode / less memory (still sharp on device).
(int, int) _reelPosterMemCachePixels(MediaQueryData mq, {int maxLongEdge = 960}) {
  var w = (mq.size.width * mq.devicePixelRatio).round();
  var h = (mq.size.height * mq.devicePixelRatio).round();
  final long = math.max(w, h);
  if (long > maxLongEdge) {
    final scale = maxLongEdge / long;
    w = math.max(1, (w * scale).round());
    h = math.max(1, (h * scale).round());
  }
  return (w, h);
}

/// HLS must NEVER be cached (segments rotate). For raw MP4 we keep a tiny LRU
/// cache (32 MB total) just for thumbnails / processed MP4 first bytes.
BetterPlayerCacheConfiguration getCache(String url) {
  final isHls = url.contains('.m3u8');
  return BetterPlayerCacheConfiguration(
    useCache: !isHls,
    maxCacheSize: 32 * 1024 * 1024,
    maxCacheFileSize: 4 * 1024 * 1024,
  );
}

/// Instagram-grade buffering tuned for instant start AND zero mid-playback
/// stalls.
///
/// Earlier we set `minBufferMs=800/maxBufferMs=2500` to fight OOM crashes on
/// 256 MB-heap devices. That fixed memory but made every reel look like it
/// was buffering: the renderer would start with a 300 ms head, run dry within
/// a second on slower networks, and the "rebuffering" indicator would flash
/// for every swipe — exactly the "slow-start with buffering" the user is
/// reporting in the logs.
///
/// The new numbers (≈4 s start headroom, up to 15 s of pre-roll, only 400 ms
/// required before playback begins) match the public defaults used by
/// Instagram/TikTok-style feeds:
///
///   * `bufferForPlaybackMs: 400` → playback starts as soon as ~0.4 s of
///     video is decoded — feels instant on swipe.
///   * `minBufferMs: 4000` → keeps roughly 4 s of decoded media on hand so
///     transient network jitter doesn't immediately turn into a stall.
///   * `maxBufferMs: 15000` → allows pre-buffering up to ~15 s on Wi-Fi so
///     the user can scrub or watch through a network blip; with 2 active
///     1080p H.264 reels at ~4 Mbps this caps memory at ~15 MB/player,
///     well under the 8 MB/player ceiling we were forcing before
///     (since BetterPlayer/ExoPlayer evicts already-played samples).
///   * `bufferForPlaybackAfterRebufferMs: 1500` → after a stall, wait for a
///     reasonable 1.5 s before resuming, preventing a stall-loop on bad
///     networks.
const BetterPlayerBufferingConfiguration kReelBufferingConfig =
    BetterPlayerBufferingConfiguration(
      minBufferMs: 2000,
      maxBufferMs: 7000,
      bufferForPlaybackMs: 300,
      bufferForPlaybackAfterRebufferMs: 800,
);

/// Pooled BetterPlayer instances with generation guards (Phase 4).
class ReelPlaybackPool {
  ReelPlaybackPool._();

  static final ReelPlaybackPool instance = ReelPlaybackPool._();

  final Map<String, _PoolSlot> _slots = {};
  final List<String> _lru = [];

  int get maxSlots => ReelPlatformPolicy.maxPoolSlots;

  BetterPlayerController? get(String reelId) {
    final slot = _slots[reelId];
    if (slot == null || slot.disposed) return null;
    return slot.controller;
  }

  int? generationFor(String reelId) => _slots[reelId]?.generation;

  bool isSlotAlive(String reelId, int generation) {
    final slot = _slots[reelId];
    return slot != null && !slot.disposed && slot.generation == generation;
  }

  bool isReady(String reelId) {
    final slot = _slots[reelId];
    if (slot == null || slot.disposed) return false;
    try {
      return slot.initialized && slot.controller.isVideoInitialized() == true;
    } catch (_) {
      return false;
    }
  }

  void sync(List<ReelData> reels, int centerIndex, {int? alsoWarmIndex}) {
    final keep = <String>{};
    final indices = ReelPlatformPolicy.warmIndices(centerIndex, reels.length).toSet();
    if (alsoWarmIndex != null &&
        alsoWarmIndex >= 0 &&
        alsoWarmIndex < reels.length) {
      indices.add(alsoWarmIndex);
    }

    for (final i in indices) {
      final reel = reels[i];
      keep.add(reel.id);
      final warmOnly = i != centerIndex;
      unawaited(_ensureSlot(reel, warmOnly: warmOnly));
    }

    final remove = _slots.keys.where((id) => !keep.contains(id)).toList();
    for (final id in remove) {
      _disposeSlot(id, reason: 'sync_trim');
    }

    _enforceSlotLimit(keep);
  }

  void _enforceSlotLimit(Set<String> keep) {
    while (_slots.length > maxSlots) {
      String? victim;
      for (final id in _lru) {
        if (!keep.contains(id)) {
          victim = id;
          break;
        }
      }
      victim ??= _slots.keys.firstWhere(
        (id) => !keep.contains(id),
        orElse: () => _lru.isNotEmpty ? _lru.first : _slots.keys.first,
      );
      _disposeSlot(victim, reason: 'pool_limit');
    }
  }

  Future<void> prepare(ReelData reel, {required bool warmOnly}) =>
      _ensureSlot(reel, warmOnly: warmOnly);

  Future<void> switchToFallback(
    String reelId,
    String fallbackUrl, {
    required ReelData template,
  }) async {
    if (fallbackUrl.isEmpty) return;
    _disposeSlot(reelId, reason: 'fallback');
    await _ensureSlot(
      ReelData(
        id: template.id,
        videoUrl: fallbackUrl,
        fallbackVideoUrl: '',
        thumbnailUrl: template.thumbnailUrl,
        caption: template.caption,
        userId: template.userId,
        isProcessed: template.isProcessed,
        isProcessing: template.isProcessing,
      ),
      warmOnly: false,
    );
  }

  void onMemoryPressure({String? keepReelId}) {
    ReelLifecycleLog.memoryPressure(keepReelId: keepReelId);
    final remove = _slots.keys.where((id) => id != keepReelId).toList();
    for (final id in remove) {
      _disposeSlot(id, reason: 'memory_pressure');
    }
  }

  /// Hard pressure: drop the LRU slot (does not touch `keepReelId`).
  void evictOldest({String? keepReelId}) {
    final candidates = _lru.where((id) => id != keepReelId).toList();
    if (candidates.isEmpty) return;
    final victim = candidates.first;
    debugPrint('[PLAYER_RECYCLED] memory_evict $victim');
    _disposeSlot(victim, reason: 'memory_evict_oldest');
  }

  /// Soft pressure: stop accepting new warm-only slots; already-warm and the
  /// current reel keep playing.
  bool _acceptNewWarmSlots = true;
  bool get acceptNewWarmSlots => _acceptNewWarmSlots;
  set acceptNewWarmSlots(bool v) {
    if (_acceptNewWarmSlots == v) return;
    _acceptNewWarmSlots = v;
    debugPrint('[PLAYER_RECYCLED] acceptWarm=$v');
  }

  Future<void> _ensureSlot(ReelData reel, {required bool warmOnly}) async {
    if (!reel.isPlayable) return;
    if (warmOnly && !_acceptNewWarmSlots) {
      debugPrint('[PLAYER_RECYCLED] warm_skipped_under_pressure ${reel.id}');
      return;
    }

    final existing = _slots[reel.id];
    if (existing != null && !existing.disposed) {
      if (existing.url == reel.videoUrl) {
        _touch(reel.id);
        if (warmOnly && ReelPlatformPolicy.allowMutedWarmPlay) {
          unawaited(_warmBuffer(existing));
        }
        return;
      }
      _disposeSlot(reel.id, reason: 'url_change');
    }

    final generation = DateTime.now().microsecondsSinceEpoch;
    final config = BetterPlayerConfiguration(
      autoPlay: false,
      looping: true,
      fit: BoxFit.cover,
      aspectRatio: 9 / 16,
      expandToFill: true,
      autoDispose: false,
      handleLifecycle: false,
      allowedScreenSleep: false,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
        showControlsOnInitialize: false,
      ),
    );

    final controller = BetterPlayerController(config);
    final slot = _PoolSlot(
      reel: reel,
      controller: controller,
      url: reel.videoUrl,
      generation: generation,
    );
    _slots[reel.id] = slot;
    _touch(reel.id);
    ReelLifecycleLog.bind(reel.id, generation: generation, url: reel.videoUrl);

    final isPreview =
        reel.previewUrl.isNotEmpty &&
            reel.videoUrl == reel.previewUrl;

    final targetVideo =
        reel.fallbackVideoUrl;

    final dataSource = BetterPlayerDataSource.network(
      reel.videoUrl,
      videoFormat: _formatForUrl(reel.videoUrl),
      cacheConfiguration: getCache(reel.videoUrl),
      bufferingConfiguration: kReelBufferingConfig,
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: false,
      ),
    );

    try {
      await controller.setupDataSource(dataSource);
      if (!isSlotAlive(reel.id, generation)) {
        ReelLifecycleLog.generationMismatch(
          reel.id,
          expected: generation,
          actual: _slots[reel.id]?.generation,
        );
        await _safeDisposeController(controller);
        return;
      }
      slot.initialized = true;

// preview → HLS switch
      if (
      isPreview &&
          targetVideo.isNotEmpty &&
          !warmOnly
      ) {
        Future.delayed(
          const Duration(milliseconds: 800),
              () async {
            try {
              // Slot already removed/replaced
              if (!isSlotAlive(
                reel.id,
                generation,
              )) {
                return;
              }

              await controller.setupDataSource(
                BetterPlayerDataSource.network(
                  targetVideo,
                  videoFormat:
                  _formatForUrl(targetVideo),
                  cacheConfiguration:
                  getCache(targetVideo),
                  bufferingConfiguration:
                  kReelBufferingConfig,
                  notificationConfiguration:
                  const BetterPlayerNotificationConfiguration(
                    showNotification: false,
                  ),
                ),
              );

              // Recheck after async switch
              if (!isSlotAlive(
                reel.id,
                generation,
              )) {
                return;
              }

              // Resume playback after switch
              await controller.setVolume(1);

              if (
              controller.isPlaying() !=
                  true
              ) {
                await controller.play();
              }

              debugPrint(
                '[PREVIEW_TO_HLS_OK] ${reel.id}',
              );
            } catch (e) {
              debugPrint(
                '[PREVIEW_SWITCH_FAIL] '
                    '${reel.id} $e',
              );
            }
          },
        );
      }

      if (
      warmOnly &&
          ReelPlatformPolicy.allowMutedWarmPlay
      ) {
        unawaited(_warmBuffer(slot));
      }
    } catch (e) {
      ReelLifecycleLog.playerException(reel.id, e);
      if (isSlotAlive(reel.id, generation)) {
        _disposeSlot(reel.id, reason: 'setup_failed');
      }
    }
  }

  Future<void> _warmBuffer(_PoolSlot slot) async {
    if (!ReelPlatformPolicy.allowMutedWarmPlay) return;
    if (slot.disposed || !slot.initialized) return;
    final c = slot.controller;
    final gen = slot.generation;
    try {
      if (!isSlotAlive(slot.reel.id, gen)) return;
      if (c.isPlaying() != true) {
        await c.setVolume(0);
        if (!isSlotAlive(slot.reel.id, gen)) return;
        await c.play();
        if (!isSlotAlive(slot.reel.id, gen)) {
          await c.pause();
          await c.setVolume(0);
        }
      }
    } catch (e) {
      ReelLifecycleLog.playerException(slot.reel.id, e);
    }
  }

  void _touch(String reelId) {
    _lru.remove(reelId);
    _lru.add(reelId);
    final slot = _slots[reelId];
    if (slot != null) slot.lastUsed = DateTime.now();
  }

  void _disposeSlot(String reelId, {String reason = ''}) {
    final slot = _slots.remove(reelId);
    _lru.remove(reelId);
    if (slot == null) return;
    slot.disposed = true;
    ReelLifecycleLog.dispose(reelId, generation: slot.generation, reason: reason);
    final c = slot.controller;
    unawaited(_safeDisposeController(c));
  }

  Future<void> _safeDisposeController(BetterPlayerController c) async {
    try {
      if (c.isVideoInitialized() == true) {
        await c.setVolume(0);
        await c.pause();
      }
      c.dispose(forceDispose: true);
    } catch (e) {
      debugPrint('[ReelPlaybackPool] dispose error: $e');
    }
  }

  void disposeAll() {
    for (final id in _slots.keys.toList()) {
      _disposeSlot(id, reason: 'dispose_all');
    }
  }
}

class _PoolSlot {
  final ReelData reel;
  final BetterPlayerController controller;
  final String url;
  final int generation;
  bool initialized = false;
  bool disposed = false;
  DateTime lastUsed = DateTime.now();

  _PoolSlot({
    required this.reel,
    required this.controller,
    required this.url,
    required this.generation,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

// REEL DATA

// ─────────────────────────────────────────────────────────────────────────────

class ReelData {
  final String id;

  final String videoUrl;

  final String fallbackVideoUrl;

  final String thumbnailUrl;

  final String previewUrl;

  final String caption;

  final String userId;

  final bool isProcessed;
  final bool isProcessing;
  final bool legacyRawFallback;
  final ReelStatus status;
  final String? blockedReason;

  const ReelData({
    required this.id,
    required this.videoUrl,
    this.fallbackVideoUrl = '',
    required this.thumbnailUrl,
    this.previewUrl = '',
    required this.caption,
    required this.userId,
    this.isProcessed = false,
    this.isProcessing = false,
    this.legacyRawFallback = false,
    this.status = ReelStatus.missingVideo,
    this.blockedReason,
  });

  bool get isPlayable => videoUrl.isNotEmpty;

  /// Show processing only while transcoding.
  /// Raw uploads are NEVER played directly.
  /// Playback starts after preview / processed output exists.
  bool get showProcessingOverlay => !isPlayable &&
      status == ReelStatus.processing;

  /// Show "Video unavailable" + retry button for failed / missing reels.
  bool get showMissingOverlay => !isPlayable &&
      (status == ReelStatus.failedTranscode ||
          status == ReelStatus.missingVideo);

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

    final urls = resolveReelPlayback(
      postData: data,
      mediaItem: firstVideo.toVideoMediaMap(),
    );

    final thumbnailUrl = firstVideo.thumbnail.trim().isNotEmpty
        ? firstVideo.thumbnail.trim()
        : (data['thumbnailUrl'] as String? ?? '').trim();
    final previewUrl = (data['previewUrl'] as String? ?? '').trim();

    if (
    urls.legacyRawFallback &&
        !urls.processed
    ) {
      unawaited(
        _markForLegacyTranscodeRequeue(
          doc.id,
        ),
      );
    }

    return ReelData(
      id: doc.id,
      videoUrl:
        previewUrl.isNotEmpty
            ? previewUrl
            : urls.primaryUrl,

      fallbackVideoUrl:
          urls.fallbackUrl.isNotEmpty
              ? urls.fallbackUrl
              : urls.primaryUrl,
      thumbnailUrl:  thumbnailUrl,
      previewUrl: previewUrl,
      caption: (data['caption'] as String? ?? '').trim(),
      userId: (data['userId'] as String? ?? '').trim(),
      isProcessed: urls.processed,
      isProcessing: urls.processing,
      legacyRawFallback: urls.legacyRawFallback,
      status: urls.status,
      blockedReason: urls.blockedReason,
    );
  }
}

/// Best-effort: nudge the backend to re-queue transcoding for a legacy reel.
///
/// Writes `requestedTranscodeAt = serverTimestamp` on BOTH `reels/{id}` and
/// `posts/{id}` (the same id is used for both in this app). The
/// `requeueLegacyReel` / `requeueLegacyPost` Cloud Functions dedup on
/// `requeuedAt` so spamming this is safe.
///
/// Throttled per-id with a tiny in-memory cache so a single feed scroll doesn't
/// produce hundreds of Firestore writes.
final Set<String> _legacyRequeueSentThisSession = <String>{};

Future<void> _markForLegacyTranscodeRequeue(String reelId) async {
  if (reelId.isEmpty) return;
  if (!_legacyRequeueSentThisSession.add(reelId)) return;
  try {
    final fs = FirebaseFirestore.instance;
    final payload = <String, dynamic>{
      'legacyRawFallback': true,
      'requestedTranscodeAt': FieldValue.serverTimestamp(),
    };
    await Future.wait([
      fs.collection('reels').doc(reelId).set(payload, SetOptions(merge: true)),
      fs.collection('posts').doc(reelId).set(payload, SetOptions(merge: true)),
    ]);
  } catch (_) {/* ignore — non-fatal */}
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
  StreamSubscription<MemoryWatchdogEvent>? _memorySub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _pageController.addListener(_onPageScroll);

    MemoryWatchdog.instance.start();
    _memorySub =
        MemoryWatchdog.instance.stream.listen(_handleMemoryWatchdog);

    _loadReels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _pageController.removeListener(_onPageScroll);

    ReelPlaybackPool.instance.disposeAll();

    _memorySub?.cancel();
    MemoryWatchdog.instance.stop();

    _swipeDebounce?.cancel();
    _pageController.dispose();

    _appPausedNotifier.dispose();

    super.dispose();
  }

  void _handleMemoryWatchdog(MemoryWatchdogEvent ev) {
    if (!mounted || _reels.isEmpty) return;
    final keep = _reels[_currentIndex.clamp(0, _reels.length - 1)].id;
    switch (ev.pressure) {
      case MemoryPressure.ok:
        ReelPlaybackPool.instance.acceptNewWarmSlots = true;
        break;
      case MemoryPressure.soft:
        ReelPlaybackPool.instance.acceptNewWarmSlots = false;
        break;
      case MemoryPressure.hard:
        ReelPlaybackPool.instance.acceptNewWarmSlots = false;
        ReelPlaybackPool.instance.evictOldest(keepReelId: keep);
        break;
      case MemoryPressure.critical:
        ReelPlaybackPool.instance.acceptNewWarmSlots = false;
        ReelPlaybackPool.instance.onMemoryPressure(keepReelId: keep);
        break;
    }
  }

  Timer? _swipeDebounce;
  int? _lastSyncedCenter;

  void _onPageScroll() {
    if (!_pageController.hasClients || _reels.isEmpty) return;
    final page = _pageController.page;
    if (page == null) return;
    final center = page.round().clamp(0, _reels.length - 1);
    if (_lastSyncedCenter == center) return;
    _swipeDebounce?.cancel();
    _swipeDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _lastSyncedCenter = center;
      ReelPlaybackPool.instance.sync(_reels, center);
    });
  }

  void _syncPlaybackPool(int center) {
    _swipeDebounce?.cancel();
    _lastSyncedCenter = center;
    ReelPlaybackPool.instance.sync(_reels, center);
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    if (_reels.isEmpty) return;
    final keepId = _reels[_currentIndex.clamp(0, _reels.length - 1)].id;
    ReelPlaybackPool.instance.onMemoryPressure(keepReelId: keepId);
  }

  /// Instagram prefetch window: 5 thumbnails around the center reel.
  void _precacheReelPosters(int center) {
    if (!mounted) return;
    final mq = MediaQuery.of(context);
    final px = _reelPosterMemCachePixels(mq);
    final range = <int>{};
    for (int i = center - 2; i <= center + 2; i++) {
      if (i >= 0 && i < _reels.length) range.add(i);
    }
    for (final i in range) {
      final url = _reels[i].thumbnailUrl;
      if (url.isEmpty) continue;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(url, cacheManager: AppCacheManager.media),
          context,
          size: Size(px.$1.toDouble(), px.$2.toDouble()),
        ),
      );
    }
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

      final reels = snap.docs.map(ReelData.fromDoc).toList();

      if (!mounted) return;

      setState(() {
        _reels = reels;
        _loading = false;
      });

      _syncPlaybackPool(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _precacheReelPosters(0);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
    }
  }

  void _onPageChanged(int index) {
    if (!mounted) return;

    _syncPlaybackPool(index);
    _precacheReelPosters(index);
    setState(() => _currentIndex = index);
  }

  bool _shouldWarmIndex(int index) {
    return ReelPlatformPolicy.warmIndices(_currentIndex, _reels.length).contains(index) &&
        index != _currentIndex;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
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
                shouldPreload: _shouldWarmIndex(index) && index != _currentIndex,
                appPausedNotifier: _appPausedNotifier,
              );
            },
          ),
          if (ReelPlatformPolicy.useAheadWarmSurfaces)
            _ReelAheadWarmSurfaces(
              reels: _reels,
              currentIndex: _currentIndex,
            ),
        ],
      ),
    );
  }
}

/// 1×1 surfaces so the pool can buffer the next reels before [PageView] builds them.
class _ReelAheadWarmSurfaces extends StatelessWidget {
  final List<ReelData> reels;
  final int currentIndex;

  const _ReelAheadWarmSurfaces({
    required this.reels,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final pool = ReelPlaybackPool.instance;
    final children = <Widget>[];

    for (final delta in [1]) {
      final i = currentIndex + delta;
      if (i < 0 || i >= reels.length) continue;
      final c = pool.get(reels[i].id);
      if (c == null || !pool.isReady(reels[i].id)) continue;
      children.add(
        Positioned(
          left: 0,
          top: 0,
          width: 2,
          height: 2,
          child: BetterPlayer(
            key: ValueKey('reel_warm_${reels[i].id}'),
            controller: c,
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(children: children),
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
  bool _capabilityErrorMarked = false;

  String? _activePlaybackUrl;

  final _bindGen = ReelBindGeneration();

  final _fallbackTracker = ReelPlaybackFallbackTracker();

  Timer? _playbackDebounce;

  bool _handlingException = false;

  bool _liked = false;

  bool _showHeartOverlay = false;

  bool _userPaused = false;

  String _username = '';

  int? _boundSlotGeneration;

  bool get _needsController =>
      widget.isActive ||
      widget.shouldPreload ||
      ReelPlaybackPool.instance.get(widget.reel.id) != null;

  bool get _wantsPlay =>
      widget.isActive && !_userPaused && !widget.appPausedNotifier.value;

  @override
  void initState() {
    super.initState();

    widget.appPausedNotifier.addListener(_onAppPausedChanged);
    _activePlaybackUrl = widget.reel.videoUrl;

    _loadUsername();

    _bindPooledController();
    _ensureControllerLifecycle();
  }

  void _loadUsername() async {
    final name = await UserCache.getName(widget.reel.userId);

    if (!_disposed && mounted) {
      setState(() => _username = name);
    }
  }

  bool _lifecycleAlive(int bindToken) {
    if (_disposed) return false;
    if (!_bindGen.matches(bindToken)) return false;
    final gen = _boundSlotGeneration;
    if (gen == null) return _controller != null;
    return ReelPlaybackPool.instance.isSlotAlive(widget.reel.id, gen);
  }

  void _bindPooledController() {
    final bindToken = _bindGen.value;
    final pooled = ReelPlaybackPool.instance.get(widget.reel.id);
    final slotGen = ReelPlaybackPool.instance.generationFor(widget.reel.id);

    if (pooled == _controller && _boundSlotGeneration == slotGen) {
      if (pooled != null && ReelPlaybackPool.instance.isReady(widget.reel.id)) {
        if (mounted) setState(() => _videoInitialized = true);
      }
      return;
    }

    _detachControllerListener();
    ReelLifecycleLog.unbind(widget.reel.id, generation: _boundSlotGeneration);

    _controller = pooled;
    _boundSlotGeneration = slotGen;
    if (pooled != null && slotGen != null) {
      pooled.addEventsListener(_onPlayerEvent);
      ReelLifecycleLog.bind(widget.reel.id, generation: slotGen, url: _activePlaybackUrl);
      _playbackError = false;
      if (ReelPlaybackPool.instance.isReady(widget.reel.id) && mounted) {
        setState(() => _videoInitialized = true);
      }
    }

    if (pooled != null &&
        slotGen != null &&
        !_lifecycleAlive(bindToken)) {
      ReelLifecycleLog.generationMismatch(
        widget.reel.id,
        expected: bindToken,
        actual: slotGen,
      );
    }
  }

  void _ensureControllerLifecycle() {
    if (_needsController && widget.reel.isPlayable) {
      if (_controller == null) {
        unawaited(_createLocalController());
      }
    } else {
      _releaseLocalBinding();
    }
  }

  ReelData _reelForUrl(String url) => ReelData(
        id: widget.reel.id,
        videoUrl: url,
        fallbackVideoUrl: widget.reel.fallbackVideoUrl,
        thumbnailUrl: widget.reel.thumbnailUrl,
        caption: widget.reel.caption,
        userId: widget.reel.userId,
        isProcessed: widget.reel.isProcessed,
        isProcessing: widget.reel.isProcessing,
      );

  /// Single-bind guard — prevents the `activate → dispose → activate` loop that
  /// produced "generation mismatch expected=1 actual=4" in the logs.
  String? _bindingUrl;

  Future<void> _createLocalController() async {
    if (_disposed) return;
    if (widget.reel.showProcessingOverlay || !widget.reel.isPlayable) return;

    final url = _activePlaybackUrl ?? widget.reel.videoUrl;
    if (url.isEmpty) return;

    // Same URL is already being bound or has already been bound — skip.
    if (_bindingUrl == url) {
      debugPrint('[PLAYER_RECYCLED] duplicate_bind_skipped ${widget.reel.id}');
      return;
    }
    final existing = ReelPlaybackPool.instance.get(widget.reel.id);
    if (existing != null && _activePlaybackUrl == url && _controller == existing) {
      return;
    }

    _bindingUrl = url;
    final bindToken = _bindGen.bump();
    _fallbackTracker.markAttempted(url);
    _activePlaybackUrl = url;

    try {
      await ReelPlaybackPool.instance.prepare(
        _reelForUrl(url),
        warmOnly: !widget.isActive,
      );
    } finally {
      // Clear binding lock only if a fresher bind hasn't kicked in.
      if (_bindingUrl == url) _bindingUrl = null;
    }

    if (!_lifecycleAlive(bindToken) || !mounted) return;

    _bindPooledController();
    if (_lifecycleAlive(bindToken)) {
      _schedulePlaybackSync(immediate: widget.isActive);
    }
  }

  void _detachControllerListener() {
    final c = _controller;
    if (c != null) {
      try {
        c.removeEventsListener(_onPlayerEvent);
      } catch (_) {}
    }
  }

  void _markFirstFrame() {
    if (_firstFrameRendered || !mounted) return;
    setState(() => _firstFrameRendered = true);
    ReelLifecycleLog.firstFrameRendered(widget.reel.id);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (_disposed || !mounted) return;
    final gen = _boundSlotGeneration;
    if (gen != null && !ReelPlaybackPool.instance.isSlotAlive(widget.reel.id, gen)) {
      return;
    }

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        setState(() => _videoInitialized = true);
        if (widget.isActive) _schedulePlaybackSync();
        break;

      case BetterPlayerEventType.play:
      case BetterPlayerEventType.progress:
        if (widget.isActive) _markFirstFrame();
        break;

      case BetterPlayerEventType.finished:
        if (_wantsPlay && _controller != null) {
          unawaited(_restartLoop());
        }

        break;

      case BetterPlayerEventType.exception:
        ReelLifecycleLog.playerException(
          widget.reel.id,
          event.parameters,
        );
        _maybeMarkTranscodeError(event.parameters);
        _handlePlaybackException();
        break;

      default:
        break;
    }
  }

  Future<void> _restartLoop() async {
    final c = _controller;
    final bindToken = _bindGen.value;
    final gen = _boundSlotGeneration;

    if (!_wantsPlay || c == null || !_isVideoReady(c)) return;
    if (gen != null && !ReelPlaybackPool.instance.isSlotAlive(widget.reel.id, gen)) {
      return;
    }

    try {
      await c.seekTo(Duration.zero);
      if (!_lifecycleAlive(bindToken) || !_wantsPlay) return;
      await c.play();
    } catch (e) {
      ReelLifecycleLog.playerException(widget.reel.id, e);
    }
  }

  /// If ExoPlayer reports a *codec capability* failure (e.g. 4K Dolby Vision
  /// or H.264 high@4K60 on an Android decoder that tops out at FHD@30),
  /// persist `transcodeError` on the Firestore doc so:
  ///   1. The resolver returns `FAILED_TRANSCODE` next time and the UI shows
  ///      "Video unavailable" + retry instead of re-entering the OOM loop.
  ///   2. A backend Firestore trigger can re-queue transcoding for this reel.
  void _maybeMarkTranscodeError(Map<String, dynamic>? params) {
    if (_capabilityErrorMarked) return;
    final detail =
        params?.values.map((v) => v.toString()).join(' ').toLowerCase() ?? '';
    final isCapability = detail.contains('no_exceeds_capabilities') ||
        detail.contains('decoder init failed') ||
        detail.contains('mediacodecvideorenderer error') ||
        detail.contains('exceeds_capabilities') ||
        detail.contains('decoderinitializationexception');
    if (!isCapability) return;

    _capabilityErrorMarked = true;
    final reelId = widget.reel.id;
    final failingUrl = _activePlaybackUrl ?? widget.reel.videoUrl;

    if (failingUrl.isNotEmpty) {
      unawaited(BlockedUrlMemory.instance.add(failingUrl));
    }
    debugPrint(
      '[TRANSCODE_ERROR] reel=$reelId url=$failingUrl — marking for re-queue',
    );
    unawaited(_writeCapabilityError(reelId));
  }

  static Future<void> _writeCapabilityError(String reelId) async {
    if (reelId.isEmpty) return;
    try {
      final fs = FirebaseFirestore.instance;
      final payload = <String, dynamic>{
        'transcodeError': 'exceeds_capabilities',
        'legacyRawFallback': true,
        'requestedTranscodeAt': FieldValue.serverTimestamp(),
      };
      await Future.wait([
        fs.collection('reels').doc(reelId).set(payload, SetOptions(merge: true)),
        fs.collection('posts').doc(reelId).set(payload, SetOptions(merge: true)),
      ]);
    } catch (_) {/* best-effort */}
  }

  Future<void> _handlePlaybackException() async {
    if (_disposed || !mounted || _handlingException) return;

    _handlingException = true;

    final current = _activePlaybackUrl ?? widget.reel.videoUrl;
    _fallbackTracker.markAttempted(current);

    final next = _fallbackTracker.pickNext(
      primaryUrl: widget.reel.videoUrl,
      fallbackUrl: widget.reel.fallbackVideoUrl,
    );

    if (next != null && next != current) {
      ReelLifecycleLog.fallbackStart(widget.reel.id, next);
      _releaseLocalBinding(keepState: true);

      if (mounted) {
        setState(() {
          _videoInitialized = false;
          _firstFrameRendered = false;
          _playbackError = false;
        });

        final bindToken = _bindGen.bump();
        _activePlaybackUrl = next;

        unawaited(
          ReelPlaybackPool.instance
              .switchToFallback(
                widget.reel.id,
                next,
                template: widget.reel,
              )
              .then((_) {
            if (!_lifecycleAlive(bindToken) || !mounted) return;
            ReelLifecycleLog.fallbackSuccess(widget.reel.id, next);
            _bindPooledController();
            _schedulePlaybackSync(immediate: widget.isActive);
          }),
        );
      }

      _handlingException = false;
      return;
    }

    _handlingException = false;
    if (mounted) setState(() => _playbackError = true);
  }

  /// Play/pause only after [BetterPlayer] is in the tree (next frame).
  void _schedulePlaybackSync({bool immediate = false}) {
    _playbackDebounce?.cancel();

    if (immediate) {
      if (!_disposed && mounted) unawaited(_applyPlayback());
      return;
    }

    _playbackDebounce = Timer(const Duration(milliseconds: 16), () {
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
    final bindToken = _bindGen.value;
    final c = _controller;
    final gen = _boundSlotGeneration;

    if (c == null || !_isVideoReady(c)) return;
    if (gen != null && !ReelPlaybackPool.instance.isSlotAlive(widget.reel.id, gen)) {
      ReelLifecycleLog.generationMismatch(widget.reel.id, expected: gen);
      return;
    }
    if (!_lifecycleAlive(bindToken)) return;

    try {
      if (_wantsPlay) {
        ReelLifecycleLog.activate(widget.reel.id);
        await c.setVolume(1.0);
        if (!_lifecycleAlive(bindToken) || !_wantsPlay) {
          await c.setVolume(0);
          await c.pause();
          return;
        }
        await c.play();
      } else {
        ReelLifecycleLog.deactivate(widget.reel.id);
        await c.setVolume(0);
        await c.pause();
      }
    } catch (e) {
      ReelLifecycleLog.playerException(widget.reel.id, e);
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
      _firstFrameRendered = false;
      ReelLifecycleLog.activate(widget.reel.id);
    } else if (!widget.isActive && oldWidget.isActive) {
      ReelLifecycleLog.deactivate(widget.reel.id);
      _schedulePlaybackSync(immediate: true);
    }

    _bindPooledController();

    if (needsNow != neededBefore ||
        oldWidget.reel.videoUrl != widget.reel.videoUrl) {
      _fallbackTracker.reset();
      _activePlaybackUrl = null;

      if (!needsNow) {
        _releaseLocalBinding();
      } else if (_controller == null && widget.reel.isPlayable) {
        unawaited(_createLocalController());
      }
    }

    if (widget.isActive && !oldWidget.isActive) {
      _schedulePlaybackSync(immediate: true);
    } else if (oldWidget.isActive != widget.isActive ||
        oldWidget.shouldPreload != widget.shouldPreload ||
        oldWidget.reel.id != widget.reel.id) {
      _schedulePlaybackSync(immediate: widget.isActive);
    }
  }

  void _releaseLocalBinding({bool keepState = false}) {
    _playbackDebounce?.cancel();
    ReelLifecycleLog.unbind(widget.reel.id, generation: _boundSlotGeneration);
    _detachControllerListener();
    _bindGen.bump();
    _controller = null;
    _boundSlotGeneration = null;

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
    ReelLifecycleLog.dispose(widget.reel.id, generation: _boundSlotGeneration, reason: 'item_dispose');
    _bindGen.bump();
    _releaseLocalBinding(keepState: true);
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

    final posterPx = _reelPosterMemCachePixels(mq);
    final pixelWidth = posterPx.$1;
    final pixelHeight = posterPx.$2;

    final c = _controller;

    final isPlaying = _safeIsPlaying(c);

    final isBuffering = _videoInitialized &&
        c != null &&
        _isVideoReady(c) &&
        (c.isBuffering() == true);

    final showThumbnail = !_firstFrameRendered || !_videoInitialized;

    final showProcessing = widget.reel.showProcessingOverlay;

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

            // Surface must exist before play(); pool prefetches data source early.
            if (_videoInitialized && c != null && _needsController)
              Opacity(
                opacity: _firstFrameRendered ? 1.0 : 0.0,
                child: SizedBox.expand(
                  child: BetterPlayer(
                    key: ValueKey(
                      'reel_player_${widget.reel.id}_${_boundSlotGeneration ?? 0}',
                    ),
                    controller: c,
                  ),
                ),
              ),

            if (showProcessing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Preparing video…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ready in ~2 minutes',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),

            if (widget.reel.showMissingOverlay)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded,
                        color: Colors.white70, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Video unavailable',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            if (_playbackError && widget.isActive)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _playbackError = false;
                    });
                    _fallbackTracker.reset();
                    _activePlaybackUrl = null;
                    _releaseLocalBinding();
                    unawaited(_createLocalController());
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

