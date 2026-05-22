// ExplorePage.dart — Instagram-style Explore & Reels for Halo
//
// GRID CHANGES (Instagram-style):
// [G1] 3-column uniform square grid (no masonry). Every cell is a perfect square.
// [G2] Featured cells: every 10th item spans 2×2 (like Instagram's big highlight tiles).
//      This is optional — see kUseFeaturedCells to toggle it off.
// [G3] 1px gaps between cells, zero outer padding, clean edge-to-edge.
// [G4] Video badge (play icon, top-right) and multi-image badge (stacked icon).
// [G5] Like/comment count overlay on tap (peek mode) — not implemented yet, stub ready.
// [G6] SliverGrid replaces SliverMasonryGrid for stable, consistent layout.
//
// All other functionality (reels, pool, comments, post detail) is unchanged.

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/widgets/save_button.dart';
import 'package:halo/services/save_service.dart';
import 'package:halo/models/media_model.dart';
import 'package:halo/services/app_cache_manager.dart';
import 'package:halo/services/reel_player_lifecycle.dart';
import 'package:halo/services/video_playback_resolver.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GRID LAYOUT CONFIG
// ─────────────────────────────────────────────────────────────────────────────

/// Set to true for Instagram-style "big tile every N items" pattern.
/// Set to false for a pure uniform 3×3 grid.
const bool kUseFeaturedCells = true;

/// Every Nth item becomes a 2×2 featured tile (0-indexed). Instagram uses ~10.
const int kFeaturedEvery = 10;

/// Always 3 columns — matches Instagram exactly.
const int kExploreColumns = 3;

/// Gap between cells in logical pixels.
const double kGridGap = 1.5;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary    = Color(0xFF5B3FA3);
const Color _kExploreBg  = Color(0xFFFFFFFF); // Instagram uses pure white
const Color _kLikeRed    = Color(0xFFED4956);
const int   _kPageSize   = 20;

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

int? _readPositiveInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v > 0 ? v : null;
  if (v is num) {
    final i = v.toInt();
    return i > 0 ? i : null;
  }
  final p = int.tryParse(v.toString());
  return (p != null && p > 0) ? p : null;
}

(int?, int?) _intrinsicSizeFromMediaMap(Map<String, dynamic> map) {
  int? w = _readPositiveInt(map['width'])      ??
      _readPositiveInt(map['thumbWidth'])  ??
      _readPositiveInt(map['w']);
  int? h = _readPositiveInt(map['height'])     ??
      _readPositiveInt(map['thumbHeight']) ??
      _readPositiveInt(map['h']);
  if (w != null && h != null) return (w, h);

  double? ard;
  final ar = map['aspectRatio'] ?? map['aspect'];
  if (ar is num) {
    ard = ar.toDouble();
  } else if (ar is String) {
    ard = double.tryParse(ar);
  }
  if (ard != null && ard > 0) {
    if (w != null) {
      final hh = (w / ard).round();
      if (hh > 0) return (w, hh);
    }
    if (h != null) {
      final ww = (h * ard).round();
      if (ww > 0) return (ww, h);
    }
  }
  return (null, null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VIDEO CONTROLLER POOL (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════

class _PooledController {
  final String url;
  VideoPlayerController controller;
  bool isInitialized = false;
  bool isDisposed = false;
  int generation = 0;
  DateTime lastUsed = DateTime.now();

  _PooledController({required this.url, required this.controller});
}

class VideoControllerPool {
  VideoControllerPool._();
  static final VideoControllerPool instance = VideoControllerPool._();

  static int get _maxPoolSize => ReelPlatformPolicy.isIOS ? 2 : 4;
  final Map<String, _PooledController> _pool = {};
  final List<String> _lruOrder = [];
  final Map<String, Future<VideoPlayerController?>> _preloadInflight = {};

  Future<VideoPlayerController?> preload(String url) {
    if (url.isEmpty) return Future.value(null);
    return _preloadInflight.putIfAbsent(url, () {
      return _preloadBody(url).whenComplete(() {
        _preloadInflight.remove(url);
      });
    });
  }

  Future<VideoPlayerController?> getOrPreload(String url) async {
    final existing = get(url);
    if (existing != null) return existing;
    return await preload(url);
  }

  bool _entryAlive(_PooledController entry, int generation) =>
      !entry.isDisposed && entry.generation == generation;

  Future<VideoPlayerController?> _preloadBody(String url) async {
    if (_pool.containsKey(url)) {
      _touch(url);
      final entry = _pool[url]!;
      if (entry.isDisposed) return null;
      if (entry.isInitialized) return entry.controller;
      final gen = entry.generation;
      try {
        await entry.controller.initialize();
        if (_entryAlive(entry, gen)) {
          entry.isInitialized = true;
          await entry.controller.setLooping(true);
          await entry.controller.setVolume(0);
          await entry.controller.pause();
        }
      } catch (_) {
        _remove(url);
        return null;
      }
      return entry.isDisposed ? null : entry.controller;
    }

    await _evictIfNeeded();

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );

    final generation = DateTime.now().microsecondsSinceEpoch;
    final entry = _PooledController(url: url, controller: ctrl)
      ..generation = generation;
    _pool[url] = entry;
    _lruOrder.add(url);
    ReelLifecycleLog.bind(url, generation: generation);

    try {
      if (!entry.isDisposed) {
        await ctrl.initialize();
        if (_entryAlive(entry, generation)) {
          entry.isInitialized = true;
          await ctrl.setLooping(true);
          await ctrl.setVolume(0);
          await ctrl.pause();
        }
      }
    } catch (e) {
      ReelLifecycleLog.playerException(url, e);
      _remove(url);
      return null;
    }

    return entry.isDisposed ? null : ctrl;
  }

  Future<void> _pauseAndMute(VideoPlayerController ctrl) async {
    try {
      if (ctrl.value.isInitialized) {
        await ctrl.setVolume(0);
        await ctrl.pause();
      }
    } catch (_) {}
  }

  VideoPlayerController? get(String url) {
    final entry = _pool[url];
    if (entry != null && entry.isInitialized && !entry.isDisposed) {
      _touch(url);
      return entry.controller;
    }
    return null;
  }

  bool isReady(String url) =>
      _pool.containsKey(url) &&
          _pool[url]!.isInitialized &&
          !_pool[url]!.isDisposed;

  void _touch(String url) {
    _pool[url]?.lastUsed = DateTime.now();
    _lruOrder.remove(url);
    _lruOrder.add(url);
  }

  Future<void> _evictIfNeeded() async {
    while (_pool.length >= _maxPoolSize && _lruOrder.isNotEmpty) {
      final oldest = _lruOrder.first;
      _remove(oldest);
    }
  }

  void _remove(String url) {
    final entry = _pool.remove(url);
    _lruOrder.remove(url);
    if (entry != null && !entry.isDisposed) {
      entry.isDisposed = true;
      entry.generation++;
      ReelLifecycleLog.dispose(url, generation: entry.generation, reason: 'pool_remove');
      final ctrl = entry.controller;
      unawaited(() async {
        await _pauseAndMute(ctrl);
        ctrl.dispose();
      }());
    }
  }

  void release(String url) {
    final entry = _pool[url];
    if (entry != null && !entry.isDisposed && entry.isInitialized) {
      unawaited(_pauseAndMute(entry.controller));
    }
    _touch(url);
  }

  void disposeAll() {
    for (final url in List.of(_pool.keys)) {
      _remove(url);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REEL PREFETCH MANAGER (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════

class ReelPrefetchManager {
  ReelPrefetchManager._();
  static final ReelPrefetchManager instance = ReelPrefetchManager._();

  int _lastIndex = -1;

  Future<void> prefetchAround(List<String> videoUrls, int currentIndex) async {
    if (currentIndex == _lastIndex) return;
    _lastIndex = currentIndex;

    final indices = ReelPlatformPolicy.warmIndices(currentIndex, videoUrls.length)
        .where((idx) => idx != currentIndex);

    for (final idx in indices) {
      final url = videoUrls[idx];
      if (url.isNotEmpty && !VideoControllerPool.instance.isReady(url)) {
        unawaited(VideoControllerPool.instance.preload(url));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA ITEM MODEL (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class PostMediaItem {
  final String url;
  final bool isVideo;
  final String thumb;
  final String medium;
  final String full;
  final String videoUrl;
  final String hlsUrl;
  final String thumbnail;
  final String rawVideoUrl;
  final bool processed;
  final bool processing;
  final int? trimStartMs;
  final int? trimEndMs;
  final int? intrinsicWidth;
  final int? intrinsicHeight;
  final Map<String, dynamic> qualities;

  const PostMediaItem({
    required this.url,
    required this.isVideo,
    this.thumb = '',
    this.medium = '',
    this.full = '',
    this.videoUrl = '',
    this.hlsUrl = '',
    this.thumbnail = '',
    this.rawVideoUrl = '',
    this.processed = false,
    this.processing = false,
    this.qualities = const {},
    this.trimStartMs,
    this.trimEndMs,
    this.intrinsicWidth,
    this.intrinsicHeight,
  });

  Map<String, dynamic> toMediaMap() => {
        'type': isVideo ? 'video' : 'image',
        'url': url,
        'videoUrl': videoUrl,
        'hlsUrl': hlsUrl,
        'thumbnail': thumbnail,
        'rawVideoUrl': rawVideoUrl,
        'processed': processed,
        'processing': processing,
        if (qualities.isNotEmpty) 'qualities': qualities,
        if (trimStartMs != null) 'trimStartMs': trimStartMs,
        if (trimEndMs != null) 'trimEndMs': trimEndMs,
      };

  String forGrid() {
    if (isVideo) {
      if (thumbnail.isNotEmpty) return thumbnail;
      if (thumb.isNotEmpty) return thumb;
      return url;
    }
    if (thumb.isNotEmpty) return thumb;
    if (medium.isNotEmpty) return medium;
    if (full.isNotEmpty) return full;
    return url;
  }

  String forFeed() {
    if (isVideo) return videoUrl.isNotEmpty ? videoUrl : url;
    if (medium.isNotEmpty) return medium;
    if (full.isNotEmpty) return full;
    if (thumb.isNotEmpty) return thumb;
    return url;
  }

  String forFullscreen() {
    if (isVideo) return videoUrl.isNotEmpty ? videoUrl : url;
    if (full.isNotEmpty) return full;
    if (medium.isNotEmpty) return medium;
    if (thumb.isNotEmpty) return thumb;
    return url;
  }

  String forFullscreenByDevice(bool preferFull) {
    if (isVideo) return videoUrl.isNotEmpty ? videoUrl : url;
    if (preferFull) return forFullscreen();
    if (medium.isNotEmpty) return medium;
    if (full.isNotEmpty) return full;
    if (thumb.isNotEmpty) return thumb;
    return url;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST MODEL (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class PostModel {
  final String id;
  final String userId;
  final String caption;
  final String location;
  final List<String> tags;
  final List<String> tagsLower;
  final List<PostMediaItem> mediaItems;
  final DateTime? createdAt;
  final String thumbnailUrl;
  final int likeCount;
  final int commentCount;

  final bool isVideo;
  final bool hasMedia;
  final String firstImageUrl;
  final String firstVideoUrl;
  final String firstVideoFallbackUrl;
  final PostMediaItem? firstVideoItem;
  final bool processed;
  final bool processing;
  final String hlsUrl;
  final Map<String, dynamic> qualities;

  final String captionLower;
  final String locationLower;

  const PostModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.location,
    required this.tags,
    required this.tagsLower,
    required this.mediaItems,
    this.createdAt,
    this.thumbnailUrl = '',
    this.likeCount = 0,
    this.commentCount = 0,
    required this.isVideo,
    required this.hasMedia,
    required this.firstImageUrl,
    required this.firstVideoUrl,
    this.firstVideoFallbackUrl = '',
    required this.firstVideoItem,
    this.processed = false,
    this.processing = false,
    this.hlsUrl = '',
    this.qualities = const {},
    required this.captionLower,
    required this.locationLower,
  });

  Map<String, dynamic> get _playbackPostData => {
        'processed': processed,
        'processing': processing,
        'videoUrl': firstVideoUrl,
        'hlsUrl': hlsUrl,
        if (qualities.isNotEmpty)
          'qualities': qualities
        else if (firstVideoItem?.qualities.isNotEmpty == true)
          'qualities': firstVideoItem!.qualities,
      };

  ResolvedVideoPlayback playbackFor(PostMediaItem item) =>
      resolveVideoPlayback(
        postData: _playbackPostData,
        mediaItem: item.toMediaMap(),
      );

  String playbackUrlFor(PostMediaItem item) =>
      playbackFor(item).primaryUrl;

  String fallbackUrlFor(PostMediaItem item) =>
      playbackFor(item).fallbackUrl;

  bool get isVideoProcessing =>
      processing && !processed && isVideo;

  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final parsedTags = _safeStringList(data['tags']);
    final parsedMedia = _parseMediaItems(data);
    final parsedIsVideo = parsedMedia.any((m) => m.isVideo);
    final parsedHasMedia = parsedMedia.isNotEmpty;
    final parsedProcessed = data['processed'] == true;
    final parsedProcessing = data['processing'] == true;
    final parsedHlsUrl = (data['hlsUrl'] ?? '').toString().trim();
    final parsedQualities = data['qualities'] is Map
        ? Map<String, dynamic>.from(data['qualities'] as Map)
        : const <String, dynamic>{};
    final postPlaybackData = {
      'processed': parsedProcessed,
      'processing': parsedProcessing,
      'videoUrl': (data['videoUrl'] ?? '').toString().trim(),
      'hlsUrl': parsedHlsUrl,
    };
    final parsedFirstImageItem = parsedMedia.firstWhere(
          (m) => !m.isVideo,
      orElse: () => const PostMediaItem(url: '', isVideo: false),
    );
    final parsedImages = _safeStringList(data['images']);
    final parsedFirstImageUrl = parsedFirstImageItem.forGrid().isNotEmpty
        ? parsedFirstImageItem.forGrid()
        : (parsedImages.isNotEmpty
        ? parsedImages.first
        : (data['imageUrl'] ?? data['thumbnailUrl'] ?? '').toString());
    final parsedFirstVideoItem =
    parsedMedia.firstWhere((m) => m.isVideo, orElse: () => const PostMediaItem(url: '', isVideo: false));
    final firstVideoPlayback = parsedFirstVideoItem.isVideo
        ? resolveVideoPlayback(
            postData: postPlaybackData,
            mediaItem: parsedFirstVideoItem.toMediaMap(),
          )
        : const ResolvedVideoPlayback(primaryUrl: '');
    final parsedFirstVideoUrl = firstVideoPlayback.primaryUrl;
    final parsedFirstVideoFallback = firstVideoPlayback.fallbackUrl;
    final parsedFirstVideoItemNullable = parsedIsVideo ? parsedFirstVideoItem : null;

    return PostModel(
      id:           doc.id,
      userId:       (data['userId'] ?? '').toString(),
      caption:      (data['caption'] ?? '').toString(),
      location:     (data['location'] ?? '').toString(),
      tags:         parsedTags,
      tagsLower:    parsedTags.map((t) => t.toLowerCase()).toList(growable: false),
      mediaItems:   parsedMedia,
      createdAt:    (data['createdAt'] as Timestamp?)?.toDate(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString().trim(),
      likeCount:    _asInt(data['likeCount']),
      commentCount: _asInt(data['commentCount']),
      isVideo:      parsedIsVideo,
      hasMedia:     parsedHasMedia,
      firstImageUrl:      parsedFirstImageUrl,
      firstVideoUrl:      parsedFirstVideoUrl,
      firstVideoFallbackUrl: parsedFirstVideoFallback,
      firstVideoItem:     parsedFirstVideoItemNullable,
      processed:    parsedProcessed,
      processing:   parsedProcessing,
      hlsUrl:       parsedHlsUrl,
      qualities:    parsedQualities,
      captionLower:       (data['caption'] ?? '').toString().toLowerCase(),
      locationLower:      (data['location'] ?? '').toString().toLowerCase(),
    );
  }

  static List<PostMediaItem> _parseMediaItems(Map<String, dynamic> data) {
    if (data['media'] is List && (data['media'] as List).isNotEmpty) {
      final list = data['media'] as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final type  = (map['type'] ?? 'image').toString();
        final url   = (map['url'] ?? '').toString();
        final thumb = (map['thumbnail'] ?? '').toString();
        final dims  = _intrinsicSizeFromMediaMap(map);
        final q = map['qualities'];
        return PostMediaItem(
          url: url,
          isVideo: type == 'video',
          thumb: thumb.isNotEmpty ? thumb : url,
          medium: url,
          full: url,
          videoUrl: type == 'video'
              ? ((map['videoUrl'] ?? url).toString())
              : '',
          hlsUrl: (map['hlsUrl'] ?? '').toString(),
          thumbnail: thumb,
          rawVideoUrl: (map['rawVideoUrl'] ?? '').toString(),
          processed: map['processed'] == true,
          processing: map['processing'] == true,
          qualities: q is Map
              ? Map<String, dynamic>.from(q)
              : const {},
          trimStartMs: _asIntNullable(map['trimStartMs']),
          trimEndMs: _asIntNullable(map['trimEndMs']),
          intrinsicWidth: dims.$1,
          intrinsicHeight: dims.$2,
        );
      }).toList();
    }

    final parsed = MediaModel.parsePostMedia(data);
    final validParsed = parsed.where((m) {
      final u = m.isVideo ? (m.videoUrl ?? '') : m.image.forFeed();
      return u.trim().isNotEmpty;
    }).toList();

    if (validParsed.isNotEmpty) {
      return validParsed.map((m) {
        final isVideo = m.isVideo;
        final imageUrl = m.image.forFeed().isNotEmpty
            ? m.image.forFeed()
            : (m.image.thumb.isNotEmpty
            ? m.image.thumb
            : (m.image.medium.isNotEmpty
            ? m.image.medium
            : (m.image.full.isNotEmpty ? m.image.full : '')));
        return PostMediaItem(
          url: isVideo ? (m.videoUrl ?? '') : imageUrl,
          isVideo: isVideo,
          thumb: m.image.thumb,
          medium: m.image.medium,
          full: m.image.full,
          videoUrl: m.videoUrl ?? '',
          hlsUrl: m.hlsUrl,
          thumbnail: m.thumbnail ?? '',
          rawVideoUrl: m.rawVideoUrl,
          processed: m.processed,
          processing: m.processing,
          qualities: const {},
          trimStartMs: m.trimStartMs,
          trimEndMs: m.trimEndMs,
        );
      }).toList(growable: false);
    }

    final legacyUrl = (data['imageUrl'] ??
        data['photoUrl'] ??
        data['mediaUrl'] ??
        data['thumbnailUrl'] ??
        '').toString();

    if (legacyUrl.isNotEmpty) {
      return [
        PostMediaItem(
          url: legacyUrl,
          isVideo: false,
          thumb: legacyUrl,
          medium: legacyUrl,
          full: legacyUrl,
        )
      ];
    }

    return [];
  }
}

List<String> _safeStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  return [];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

// ─────────────────────────────────────────────────────────────────────────────
// USER PROFILE CACHE (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime fetchedAt;
  _CacheEntry(this.data) : fetchedAt = DateTime.now();
  bool get isStale => DateTime.now().difference(fetchedAt).inMinutes >= 5;
}

class _UserProfileCache {
  static final _instance = _UserProfileCache._();
  _UserProfileCache._();
  factory _UserProfileCache() => _instance;

  final Map<String, _CacheEntry> _cache = {};

  static String extractPhotoUrl(Map<String, dynamic> data) {
    return (data['profilePhoto'] ??
        data['photoURL']    ??
        data['profile_photo'] ??
        data['avatar']      ??
        data['photoUrl']    ??
        '').toString().trim();
  }

  Future<Map<String, dynamic>> get(String userId) async {
    final entry = _cache[userId];
    if (entry != null && !entry.isStale) return entry.data;
    final snap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = snap.data() ?? {};
    _cache[userId] = _CacheEntry(data);
    return data;
  }

  void clear() => _cache.clear();
  void invalidate(String userId) => _cache.remove(userId);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ENUM (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

enum _ExploreFilter { forYou, photos, videos, trending }

extension _ExploreFilterLabel on _ExploreFilter {
  String get label {
    switch (this) {
      case _ExploreFilter.forYou:   return 'For You';
      case _ExploreFilter.photos:   return 'Photos';
      case _ExploreFilter.videos:   return 'Videos';
      case _ExploreFilter.trending: return 'Trending';
    }
  }
  IconData get icon {
    switch (this) {
      case _ExploreFilter.forYou:   return Icons.auto_awesome_rounded;
      case _ExploreFilter.photos:   return Icons.photo_rounded;
      case _ExploreFilter.videos:   return Icons.videocam_rounded;
      case _ExploreFilter.trending: return Icons.trending_up_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE PAGE
// ─────────────────────────────────────────────────────────────────────────────

class ExplorePage extends StatefulWidget {
  final bool openReelsOnStart;
  final String? initialReelPostId;

  const ExplorePage({
    Key? key,
    this.openReelsOnStart = false,
    this.initialReelPostId,
  }) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final List<PostModel>  _posts   = [];
  DocumentSnapshot?      _lastDoc;
  bool                   _isFetching   = false;
  bool                   _hasMore      = true;
  bool                   _didAutoOpenReels = false;
  bool                   _hasMoreUndated   = true;
  DocumentSnapshot?      _undatedLastDoc;
  final ScrollController _scrollCtrl   = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  _ExploreFilter _filter      = _ExploreFilter.forYou;
  String         _searchQuery = '';
  List<String>   _trendingTags = [];

  final ValueNotifier<Map<String, dynamic>> _savedPostsNotifier =
  ValueNotifier<Map<String, dynamic>>(const <String, dynamic>{});
  StreamSubscription<Map<String, dynamic>>? _savedPostsSub;

  List<PostModel> _filteredPostsCache = const [];

  @override
  void initState() {
    super.initState();
    if (widget.openReelsOnStart) _filter = _ExploreFilter.videos;
    _initSavedPostsListener();
    _fetchNextPage();
    _scrollCtrl.addListener(_onScroll);
  }

  void _initSavedPostsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    _savedPostsSub = SaveService().savedPostsStream(uid).listen((savedMap) {
      _savedPostsNotifier.value = savedMap;
    });
  }

  void _rebuildFilteredPostsCache() {
    var list = _posts;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) =>
      p.captionLower.contains(q) ||
          p.locationLower.contains(q) ||
          p.tagsLower.any((t) => t.contains(q))).toList();
    } else {
      list = list.toList(growable: false);
    }

    switch (_filter) {
      case _ExploreFilter.forYou:
        break;
      case _ExploreFilter.photos:
        list = list.where((p) => !p.isVideo && p.hasMedia).toList();
        break;
      case _ExploreFilter.videos:
        list = list.where((p) => p.isVideo).toList();
        break;
      case _ExploreFilter.trending:
        list = list.where((p) => p.tags.isNotEmpty).toList()
          ..sort((a, b) =>
              (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
    }

    _filteredPostsCache = list;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _savedPostsSub?.cancel();
    _savedPostsNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 500 &&
        !_isFetching &&
        (_hasMore || _hasMoreUndated)) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isFetching || (!_hasMore && !_hasMoreUndated)) return;
    _isFetching = true;
    if (mounted) setState(() {});

    try {
      final existingIds = _posts.map((p) => p.id).toSet();
      var addedCount = 0;

      if (_hasMore) {
        Query<Map<String, dynamic>> datedQuery = FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(_kPageSize);
        if (_lastDoc != null) {
          datedQuery = datedQuery.startAfterDocument(_lastDoc!);
        }
        final snap = await datedQuery.get();
        if (snap.docs.isEmpty || snap.docs.length < _kPageSize) _hasMore = false;
        if (snap.docs.isNotEmpty) {
          _lastDoc = snap.docs.last;
          for (final doc in snap.docs) {
            final p = PostModel.fromFirestore(doc);
            if (existingIds.contains(p.id)) continue;
            existingIds.add(p.id);
            _posts.add(p);
            addedCount++;
          }
        }
      }

      final remaining = _kPageSize - addedCount;
      if (_hasMoreUndated && remaining > 0) {
        Query<Map<String, dynamic>> undatedQuery = FirebaseFirestore.instance
            .collection('posts')
            .where('createdAt', isNull: true)
            .orderBy(FieldPath.documentId)
            .limit(remaining);
        if (_undatedLastDoc != null) {
          undatedQuery = undatedQuery.startAfterDocument(_undatedLastDoc!);
        }
        final undatedSnap = await undatedQuery.get();
        if (undatedSnap.docs.isEmpty || undatedSnap.docs.length < remaining) {
          _hasMoreUndated = false;
        }
        if (undatedSnap.docs.isNotEmpty) {
          _undatedLastDoc = undatedSnap.docs.last;
          for (final doc in undatedSnap.docs) {
            final p = PostModel.fromFirestore(doc);
            if (existingIds.contains(p.id)) continue;
            existingIds.add(p.id);
            _posts.add(p);
          }
        }
      }

      _recomputeTrending();
      _rebuildFilteredPostsCache();
      _tryAutoOpenReels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load posts. Pull to retry.')),
        );
      }
    } finally {
      _isFetching = false;
      if (mounted) setState(() {});
    }
  }

  void _tryAutoOpenReels() {
    if (!widget.openReelsOnStart || _didAutoOpenReels) return;
    final videoPosts = _posts.where((p) => p.isVideo).toList();
    if (videoPosts.isEmpty) return;

    final targetId = widget.initialReelPostId?.trim() ?? '';
    int startIdx = 0;
    if (targetId.isNotEmpty) {
      final found = videoPosts.indexWhere((p) => p.id == targetId);
      if (found >= 0) startIdx = found;
    }

    _didAutoOpenReels = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openReels(videoPosts, startIdx);
    });
  }

  void _recomputeTrending() {
    final freq = <String, int>{};
    for (final p in _posts) {
      for (final t in p.tags) freq[t] = (freq[t] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _trendingTags = sorted.take(10).map((e) => e.key).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _lastDoc        = null;
      _hasMore        = true;
      _isFetching     = false;
      _trendingTags   = [];
      _hasMoreUndated = true;
      _undatedLastDoc = null;
      _filteredPostsCache = const [];
    });
    _UserProfileCache().clear();
    await _fetchNextPage();
  }

  void _openReels(List<PostModel> videoPosts, int startIdx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ExploreReelsViewer(
          videoPosts: videoPosts,
          initialIndex: startIdx,
          savedPostsListenable: _savedPostsNotifier,
        ),
      ),
    );
  }

  void _openPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostDetailPage(
          post: post,
          currentUserId: FirebaseAuth.instance.currentUser?.uid,
          savedPostsListenable: _savedPostsNotifier,
        ),
      ),
    );
  }

  void _onTileTap(PostModel post, List<PostModel> posts) {
    if (post.isVideo) {
      final videoPosts = posts.where((p) => p.isVideo).toList();
      final startIdx = videoPosts.indexWhere((p) => p.id == post.id);
      _openReels(videoPosts, startIdx < 0 ? 0 : startIdx);
      return;
    }
    _openPostDetail(post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kExploreBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _kPrimary,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              if (_trendingTags.isNotEmpty &&
                  (_filter == _ExploreFilter.forYou ||
                      _filter == _ExploreFilter.trending))
                SliverToBoxAdapter(child: _buildTrendingSection()),

              _buildGrid(),

              if (_isFetching)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child:
                      CircularProgressIndicator(color: _kPrimary),
                    ),
                  ),
                ),

              if (!_hasMore && _posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        "You've seen it all!",
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Title row
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _kPrimary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Explore',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: const Color(0xFF1F1033),
            ),
          ),
        ]),
      ),

      // Search bar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _rebuildFilteredPostsCache();
            }),
            textInputAction: TextInputAction.search,
            style:
            GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.grey, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.grey),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _rebuildFilteredPostsCache();
                }),
              )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
      ),

      const SizedBox(height: 8),

      // Filter chips
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _ExploreFilter.values
              .map((f) => _FilterChip(
            filter: f,
            selected: _filter == f,
            onTap: () => setState(() {
              _filter = f;
              _rebuildFilteredPostsCache();
            }),
          ))
              .toList(),
        ),
      ),

      const SizedBox(height: 8),
    ],
  );

  // ── TRENDING ─────────────────────────────────────────────────────────────────

  Widget _buildTrendingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          const Icon(Icons.local_fire_department_rounded,
              color: _kPrimary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Trending',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: const Color(0xFF1F1033)),
          ),
        ]),
      ),
      SizedBox(
        height: 34,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _trendingTags.length,
          itemBuilder: (_, i) {
            final tag = _trendingTags[i];
            return GestureDetector(
              onTap: () => setState(() {
                _searchCtrl.text = tag;
                _searchQuery = tag;
                _rebuildFilteredPostsCache();
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.18), width: 1),
                ),
                child: Text(
                  '#$tag',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kPrimary),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
    ],
  );

  // ── INSTAGRAM-STYLE GRID ─────────────────────────────────────────────────────
  //
  // Layout rules (matching Instagram Explore exactly):
  //   • 3 equal columns, cells are perfect squares.
  //   • 1.5px gaps — cell colours look flush, no coloured background shows through.
  //   • Every kFeaturedEvery-th item (0-indexed) is featured: rendered as a
  //     2×2 tile that spans the full row's height and the rightmost 2 columns
  //     (or the leftmost 2 if the index math lands differently).
  //     We implement this with a custom SliverGrid delegate below.
  //   • Video badge: small play ▶ icon in the top-right corner.
  //   • Multi-image badge: stacked squares icon in the top-right corner.
  //   • No caption overlays (Instagram style: clean, image-only grid).
  //   • Pure white background between cells.
  //
  // We use a plain SliverGrid + SliverChildBuilderDelegate for the uniform
  // grid, and insert featured tiles by wrapping them in a custom layout.
  //
  // Implementation note: Flutter's SliverGrid does not natively support
  // variable-size cells in a masonry-free way, so we implement the Instagram
  // "one big + two small" pattern by grouping every kFeaturedEvery items into
  // a "section" rendered as a SliverToBoxAdapter containing a Row.
  //
  // This is the cleanest, most maintainable approach in Flutter without
  // pulling in extra packages.

  Widget _buildGrid() {
    final posts = _filteredPostsCache;

    if (posts.isEmpty && !_isFetching) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_off,
                    size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No results for "$_searchQuery"'
                      : 'Nothing to explore yet',
                  style: GoogleFonts.poppins(color: Colors.grey.shade500),
                ),
              ]),
        ),
      );
    }

    if (posts.isEmpty && _isFetching) {
      return SliverToBoxAdapter(child: _buildShimmerGrid());
    }

    // Group posts into sections for the Instagram layout pattern.
    // Each section is either:
    //   A) A "featured" section: 1 big tile (2 cols × 2 rows) + 2 small tiles
    //      (1 col × 1 row each, stacked vertically in the remaining column).
    //   B) A "plain" row: 3 equal square tiles side-by-side.
    //
    // We consume posts sequentially and emit sections.

    if (!kUseFeaturedCells) {
      // Simple uniform 3-column grid — no featured tiles.
      return SliverPadding(
        padding: EdgeInsets.zero,
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kExploreColumns,
            mainAxisSpacing: kGridGap,
            crossAxisSpacing: kGridGap,
            childAspectRatio: 1.0,
          ),
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              if (index >= posts.length) return null;
              final post = posts[index];
              return RepaintBoundary(
                child: _InstagramGridTile(
                  post: post,
                  onTap: () => _onTileTap(post, posts),
                ),
              );
            },
            childCount: posts.length,
          ),
        ),
      );
    }

    // Featured-cell layout: build a list of sliver sections.
    return _InstagramFeaturedGrid(
      posts: posts,
      onTap: (post) => _onTileTap(post, posts),
    );
  }

  Widget _buildShimmerGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize =
            (constraints.maxWidth - kGridGap * (kExploreColumns - 1)) /
                kExploreColumns;
        return Wrap(
          spacing: kGridGap,
          runSpacing: kGridGap,
          children: List.generate(15, (i) {
            return _ShimmerBox(
              width: cellSize,
              height: cellSize,
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTAGRAM FEATURED GRID
// Renders the classic Instagram Explore layout:
//   • Every kFeaturedEvery items, one big tile + 2 small tiles appear.
//   • All other items are plain 3-column rows.
// ─────────────────────────────────────────────────────────────────────────────

class _InstagramFeaturedGrid extends StatelessWidget {
  final List<PostModel> posts;
  final void Function(PostModel) onTap;

  const _InstagramFeaturedGrid({
    required this.posts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cellSize =
        (screenWidth - kGridGap * (kExploreColumns - 1)) / kExploreColumns;

    // Build sections
    final sections = <Widget>[];
    int i = 0;
    int featuredCount = 0;

    while (i < posts.length) {
      // Featured section: triggers at index 0-based positions
      // Instagram pattern: positions 0, 10, 20, 30... are featured.
      // We track how many items we've consumed and trigger every kFeaturedEvery.
      final isFeatured = kUseFeaturedCells &&
          (i == 0 || (i % kFeaturedEvery == 0)) &&
          i + 2 < posts.length;

      if (isFeatured) {
        // Even-numbered featured sections: big tile on LEFT.
        // Odd-numbered: big tile on RIGHT. Alternating like Instagram.
        final bigLeft = featuredCount.isEven;
        final bigPost = posts[i];
        final small1  = posts[i + 1];
        final small2  = posts[i + 2];
        featuredCount++;
        i += 3;

        sections.add(SliverToBoxAdapter(
          child: _FeaturedSection(
            bigPost: bigPost,
            small1: small1,
            small2: small2,
            cellSize: cellSize,
            bigOnLeft: bigLeft,
            onTap: onTap,
          ),
        ));
      } else {
        // Plain row: up to 3 tiles.
        final rowPosts = <PostModel>[];
        while (rowPosts.length < kExploreColumns && i < posts.length) {
          // Don't start another featured section mid-row — skip check here.
          rowPosts.add(posts[i]);
          i++;
        }

        sections.add(SliverToBoxAdapter(
          child: _UniformRow(
            rowPosts: rowPosts,
            cellSize: cellSize,
            onTap: onTap,
          ),
        ));
      }
    }

    return MultiSliver(children: sections);
  }
}

/// Renders a plain row of up to 3 equal square tiles.
class _UniformRow extends StatelessWidget {
  final List<PostModel> rowPosts;
  final double cellSize;
  final void Function(PostModel) onTap;

  const _UniformRow({
    required this.rowPosts,
    required this.cellSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kGridGap),
      height: cellSize,
      child: Row(
        children: List.generate(rowPosts.length, (j) {
          final post = rowPosts[j];
          return Container(
            width: cellSize,
            height: cellSize,
            margin: EdgeInsets.only(right: j < rowPosts.length - 1 ? kGridGap : 0),
            child: RepaintBoundary(
              child: _InstagramGridTile(
                post: post,
                onTap: () => onTap(post),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Featured section: one big tile (2×2) + two small tiles stacked on the side.
class _FeaturedSection extends StatelessWidget {
  final PostModel bigPost;
  final PostModel small1;
  final PostModel small2;
  final double cellSize;
  final bool bigOnLeft;
  final void Function(PostModel) onTap;

  const _FeaturedSection({
    required this.bigPost,
    required this.small1,
    required this.small2,
    required this.cellSize,
    required this.bigOnLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bigSize = cellSize * 2 + kGridGap;
    final sectionHeight = bigSize;

    Widget bigTile = SizedBox(
      width: bigSize,
      height: bigSize,
      child: RepaintBoundary(
        child: _InstagramGridTile(
          post: bigPost,
          onTap: () => onTap(bigPost),
          isFeatured: true,
        ),
      ),
    );

    Widget smallStack = SizedBox(
      width: cellSize,
      height: sectionHeight,
      child: Column(
        children: [
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: RepaintBoundary(
              child: _InstagramGridTile(
                post: small1,
                onTap: () => onTap(small1),
              ),
            ),
          ),
          SizedBox(height: kGridGap),
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: RepaintBoundary(
              child: _InstagramGridTile(
                post: small2,
                onTap: () => onTap(small2),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: kGridGap),
      height: sectionHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bigOnLeft
            ? [bigTile, SizedBox(width: kGridGap), smallStack]
            : [smallStack, SizedBox(width: kGridGap), bigTile],
      ),
    );
  }
}

// Tiny helper to allow returning a list of slivers from build()
class MultiSliver extends StatelessWidget {
  final List<Widget> children;
  const MultiSliver({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Each child is a SliverToBoxAdapter, so we wrap them in a SliverList.
    return SliverList(
      delegate: SliverChildListDelegate.fixed(
        children
            .whereType<SliverToBoxAdapter>()
            .map((s) => s.child ?? const SizedBox.shrink())
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTAGRAM GRID TILE
// ─────────────────────────────────────────────────────────────────────────────
//
// Design principles:
//   • Image fills the entire tile with BoxFit.cover — no letterboxing.
//   • Badges (video icon, multi-image icon) are small, top-right, semi-transparent.
//   • No caption overlay by default (clean Instagram look).
//   • Press feedback via InkWell splash.
//   • Thumbnail shown instantly; main image loads on top with a fade.

class _InstagramGridTile extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  final bool isFeatured;

  const _InstagramGridTile({
    required this.post,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final dpr = mq.devicePixelRatio;
    final cellSize = (screenW - kGridGap * (kExploreColumns - 1)) /
        kExploreColumns;
    final decodeSize = ((isFeatured ? cellSize * 2 : cellSize) * dpr).round();

    // Pick the best display URL
    final String displayUrl;
    if (post.isVideo) {
      displayUrl = post.thumbnailUrl.isNotEmpty
          ? post.thumbnailUrl
          : (post.firstVideoItem?.thumbnail.isNotEmpty == true
          ? post.firstVideoItem!.thumbnail
          : (post.firstVideoItem?.thumb.isNotEmpty == true
          ? post.firstVideoItem!.thumb
          : post.firstVideoUrl));
    } else {
      displayUrl = post.firstImageUrl;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image / thumbnail layer ─────────────────────────────────────
          displayUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: displayUrl,
            cacheManager: AppCacheManager.media,
            fit: BoxFit.cover,
            memCacheWidth: decodeSize,
            memCacheHeight: decodeSize,
            maxWidthDiskCache: decodeSize,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) =>
            const ColoredBox(color: Color(0xFFEEEEEE)),
            errorWidget: (_, __, ___) => ColoredBox(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.image_not_supported,
                    color: Colors.grey, size: 20),
              ),
            ),
          )
              : ColoredBox(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.image_not_supported,
                  color: Colors.grey, size: 20),
            ),
          ),

          // ── Top-right badge ─────────────────────────────────────────────
          if (post.isVideo)
            Positioned(
              top: 6,
              right: 6,
              child: _GridBadge(
                icon: Icons.play_arrow_rounded,
                size: isFeatured ? 18 : 14,
              ),
            )
          else if (post.mediaItems.length > 1)
            Positioned(
              top: 6,
              right: 6,
              child: _GridBadge(
                icon: Icons.collections_rounded,
                size: isFeatured ? 18 : 14,
              ),
            ),

          // ── Bottom gradient + like/comment count for featured tiles ─────
          if (isFeatured && (post.likeCount > 0 || post.commentCount > 0))
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 32, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    if (post.likeCount > 0) ...[
                      const Icon(Icons.favorite,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(post.likeCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black45)
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (post.commentCount > 0) ...[
                      const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(post.commentCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black45)
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Small semi-transparent icon badge for the top-right of a tile.
class _GridBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const _GridBadge({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP (updated style — cleaner, Instagram-adjacent)
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final _ExploreFilter filter;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.filter, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.black : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filter.icon,
            size: 13,
            color: selected ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 5),
          Text(
            filter.label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER (unchanged logic, updated colour)
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value, 0),
          colors: [
            const Color(0xFFEEEEEE),
            const Color(0xFFF8F8F8),
            const Color(0xFFEEEEEE),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// POST DETAIL PAGE (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _PostDetailPage extends StatelessWidget {
  final PostModel post;
  final String? currentUserId;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;

  const _PostDetailPage({
    required this.post,
    required this.currentUserId,
    required this.savedPostsListenable,
  });

  Future<void> _toggleLike(BuildContext context) async {
    final uid = currentUserId;
    if (uid == null) return;
    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(post.id);
    final ref = postRef.collection('likes').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final d = await tx.get(ref);
        if (d.exists) {
          tx.delete(ref);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(ref, {
            'userId': uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not update like.')));
    }
  }

  Future<void> _share() async {
    final parts = [
      if (post.caption.isNotEmpty) post.caption,
      if (post.mediaItems.isNotEmpty) post.mediaItems.first.url,
    ];
    if (parts.isNotEmpty) await Share.share(parts.join('\n'));
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(postId: post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _UserHeader(userId: post.userId, location: post.location),

          if (post.mediaItems.isNotEmpty)
            _MediaCarousel(
              mediaItems: post.mediaItems,
              post: post,
              onDoubleTap: () => _toggleLike(context),
            ),

          _PostActions(
            postId: post.id,
            currentUserId: currentUserId,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            onLike: () => _toggleLike(context),
            onComment: () => _openComments(context),
            onShare: _share,
            savedPostsListenable: savedPostsListenable,
          ),

          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Text(post.caption,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: const Color(0xFF262626))),
            ),

          if (post.location.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.location,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),

          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA CAROUSEL (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _MediaCarousel extends StatefulWidget {
  final List<PostMediaItem> mediaItems;
  final PostModel post;
  final VoidCallback onDoubleTap;

  const _MediaCarousel({
    required this.mediaItems,
    required this.post,
    required this.onDoubleTap,
  });

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            itemCount: widget.mediaItems.length,
            physics: const BouncingScrollPhysics(
                parent: PageScrollPhysics()),
            onPageChanged: (i) {
              setState(() => _page = i);
              final videoUrls = widget.mediaItems
                  .where((m) => m.isVideo)
                  .map((m) => widget.post.playbackUrlFor(m))
                  .where((u) => u.isNotEmpty)
                  .toList();
              if (videoUrls.isNotEmpty) {
                ReelPrefetchManager.instance
                    .prefetchAround(videoUrls, i);
              }
            },
            itemBuilder: (_, i) {
              final m = widget.mediaItems[i];
              final playback = widget.post.playbackFor(m);
              final playUrl = playback.primaryUrl;
              final mq = MediaQuery.of(context);
              final isLargeDevice = mq.size.width >= 900;
              final imageUrl = m.forFullscreenByDevice(isLargeDevice);
              final decodeWidth =
              (mq.size.width * mq.devicePixelRatio).round();
              final decodeHeight = (380 * mq.devicePixelRatio).round();
              final thumbUrl = m.forGrid();
              final fallbackUrl =
              imageUrl.replaceAll('.webp', '.jpg');

              return GestureDetector(
                onDoubleTap: widget.onDoubleTap,
                child: m.isVideo
                    ? _VideoCell(
                  key: ValueKey('media_${playUrl.isNotEmpty ? playUrl : m.rawVideoUrl}'),
                  url: playUrl,
                  thumbnailUrl: m.thumbnail.isNotEmpty
                      ? m.thumbnail
                      : m.thumb,
                  trimStartMs: m.trimStartMs,
                  trimEndMs: m.trimEndMs,
                  fit: BoxFit.cover,
                  autoPlay: i == _page && playUrl.isNotEmpty,
                  warmUp: (i - _page).abs() == 1 && playUrl.isNotEmpty,
                  showProcessing: playback.showProcessingOverlay,
                  visibilityKey:
                  'media_${playUrl.hashCode}_$i',
                )
                    : CachedNetworkImage(
                  imageUrl: imageUrl,
                  cacheManager: AppCacheManager.media,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  memCacheWidth: decodeWidth,
                  memCacheHeight: decodeHeight,
                  maxWidthDiskCache: decodeWidth,
                  fadeInDuration:
                  const Duration(milliseconds: 140),
                  placeholder: (_, __) => thumbUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    cacheManager: AppCacheManager.media,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    memCacheWidth: decodeWidth,
                    memCacheHeight: decodeHeight,
                    placeholder: (_, __) =>
                    const SizedBox(),
                    errorWidget: (_, __, ___) =>
                    const SizedBox(),
                  )
                      : const SizedBox(),
                  errorWidget: (_, __, ___) =>
                  (fallbackUrl != imageUrl)
                      ? Image.network(
                    fallbackUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                      : const Center(
                      child:
                      Icon(Icons.broken_image)),
                ),
              );
            },
          ),
        ),

        if (widget.mediaItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.mediaItems.length,
                    (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? _kPrimary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST ACTIONS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _PostActions extends StatefulWidget {
  final String postId;
  final String? currentUserId;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;

  const _PostActions({
    required this.postId,
    required this.currentUserId,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.savedPostsListenable,
  });

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  bool _isLiked = false;
  late int _localLikeCount;

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.likeCount;
  }

  void _handleLike() {
    final uid = widget.currentUserId;
    if (uid == null) {
      widget.onLike();
      return;
    }
    final nextLiked = !_isLiked;
    setState(() {
      _isLiked = nextLiked;
      _localLikeCount = (_localLikeCount + (nextLiked ? 1 : -1))
          .clamp(0, 1 << 60);
    });
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final likeCount = _localLikeCount;
    final isLiked = _isLiked;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          onPressed: _handleLike,
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? _kLikeRed : Colors.black87,
            size: 28,
          ),
        ),
        IconButton(
          onPressed: widget.onComment,
          icon: const Icon(Icons.chat_bubble_outline,
              size: 26, color: Colors.black87),
        ),
        IconButton(
          onPressed: widget.onShare,
          icon: const Icon(Icons.send_outlined,
              size: 26, color: Colors.black87),
        ),
        const Spacer(),
        ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: widget.savedPostsListenable,
          builder: (_, savedMap, __) {
            return SaveButton(
              postId: widget.postId,
              currentUserId: widget.currentUserId,
              savedPostsMap: savedMap,
              iconSize: 26,
              color: Colors.black87,
            );
          },
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                likeCount == 0
                    ? 'Be the first to like this'
                    : isLiked && likeCount == 1
                    ? 'Liked by you'
                    : isLiked
                    ? 'Liked by you and ${likeCount - 1} others'
                    : '$likeCount likes',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: const Color(0xFF262626),
                ),
              ),
              if (widget.commentCount > 0)
                GestureDetector(
                  onTap: widget.onComment,
                  child: Text(
                    'View all ${widget.commentCount} comments',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER HEADER (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _UserHeader extends StatefulWidget {
  final String userId;
  final String location;
  const _UserHeader({required this.userId, required this.location});

  @override
  State<_UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<_UserHeader> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    final data = await _UserProfileCache().get(widget.userId);
    if (mounted) setState(() => _userData = data);
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] ??
        _userData?['name'] ??
        _userData?['full_name'] ??
        'User')
        .toString();
    final photoUrl =
    _UserProfileCache.extractPhotoUrl(_userData ?? {});

    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: photoUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: photoUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            memCacheWidth: 300,
            memCacheHeight: 300,
            maxWidthDiskCache: 300,
            placeholder: (_, __) => const SizedBox(),
            errorWidget: (_, __, ___) =>
            const Icon(Icons.person, color: Colors.grey),
          )
              : const Icon(Icons.person, color: Colors.grey),
        ),
      ),
      title: Text(username,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: widget.location.isNotEmpty
          ? Text(widget.location,
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade500))
          : null,
      trailing: const Icon(Icons.more_horiz),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS SHEET (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;
  final GlobalKey<_CommentsListState> _commentsKey =
  GlobalKey<_CommentsListState>();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final uid = _currentUserId;
    if (uid == null) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentRef = postRef.collection('comments').doc();
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(commentRef, {
          'userId': uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef,
            {'commentCount': FieldValue.increment(1)});
      });
      _input.clear();
      await _commentsKey.currentState?.refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Text('Comments',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const Divider(),
          Expanded(
              child: _CommentsList(
                  key: _commentsKey, postId: widget.postId)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _addComment(),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                            color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: _kPrimary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CommentsList extends StatefulWidget {
  final String postId;
  const _CommentsList({super.key, required this.postId});

  @override
  State<_CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends State<_CommentsList> {
  static const int _kCommentPageSize = 20;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _isLoading = false;
  bool _hasMore = true;

  Future<void> refresh() async {
    _docs.clear();
    _lastDoc = null;
    _hasMore = true;
    await _loadMore(initial: true);
  }

  @override
  void initState() {
    super.initState();
    _loadMore(initial: true);
  }

  Future<void> _loadMore({required bool initial}) async {
    if (!mounted || _isLoading) return;
    if (!_hasMore && !initial) return;

    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt')
          .limit(_kCommentPageSize);

      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();
      final newDocs = snap.docs;
      if (newDocs.isEmpty) {
        _hasMore = false;
        return;
      }
      _lastDoc = newDocs.last;
      _docs.addAll(newDocs);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_docs.isEmpty && _isLoading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_docs.isEmpty) {
      return Center(
        child: Text('No comments yet',
            style:
            GoogleFonts.poppins(color: Colors.grey.shade500)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final metrics = n.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 220 &&
            !_isLoading &&
            _hasMore) {
          _loadMore(initial: false);
        }
        return false;
      },
      child: _CommentsFetcher(docs: List.of(_docs)),
    );
  }
}

class _CommentsFetcher extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _CommentsFetcher({required this.docs});

  @override
  State<_CommentsFetcher> createState() => _CommentsFetcherState();
}

class _CommentsFetcherState extends State<_CommentsFetcher> {
  final Map<String, Map<String, dynamic>> _profiles = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  @override
  void didUpdateWidget(_CommentsFetcher old) {
    super.didUpdateWidget(old);
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    final ids = widget.docs
        .map((d) => (d.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final missing =
    ids.where((id) => !_profiles.containsKey(id)).toList();
    if (missing.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    await Future.wait(missing.map((id) async {
      _profiles[id] = await _UserProfileCache().get(id);
    }));
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.docs.length,
      itemBuilder: (_, i) {
        final c = widget.docs[i].data();
        final uid = (c['userId'] ?? '').toString();
        final ud = _profiles[uid] ?? {};
        final username =
        (ud['username'] ?? ud['name'] ?? 'User').toString();
        final photoUrl = _UserProfileCache.extractPhotoUrl(ud);

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  child: ClipOval(
                    child: photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      maxWidthDiskCache: 300,
                      placeholder: (_, __) =>
                      const SizedBox(),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.grey),
                    )
                        : const Icon(Icons.person,
                        color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF262626)),
                      children: [
                        TextSpan(
                            text: '$username ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        TextSpan(
                            text: (c['text'] ?? '').toString()),
                      ],
                    ),
                  ),
                ),
              ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REELS VIEWER (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreReelsViewer extends StatefulWidget {
  final List<PostModel> videoPosts;
  final int initialIndex;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;

  const _ExploreReelsViewer({
    required this.videoPosts,
    required this.initialIndex,
    required this.savedPostsListenable,
  });

  @override
  State<_ExploreReelsViewer> createState() =>
      _ExploreReelsViewerState();
}

class _ExploreReelsViewerState extends State<_ExploreReelsViewer> {
  late final PageController _controller;
  int _currentIndex = 0;
  bool _globalMuted = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final urls =
      widget.videoPosts.map((p) => p.firstVideoUrl).toList();
      ReelPrefetchManager.instance.prefetchAround(urls, _currentIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoPosts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                const Text('No videos',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go back',
                        style: TextStyle(color: Colors.white))),
              ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(
            parent: PageScrollPhysics()),
        itemCount: widget.videoPosts.length,
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          final urls =
          widget.videoPosts.map((p) => p.firstVideoUrl).toList();
          ReelPrefetchManager.instance.prefetchAround(urls, i);
        },
        itemBuilder: (_, index) {
          final post = widget.videoPosts[index];
          final warmUp = (index - _currentIndex).abs() <= 1;
          return _ReelItem(
            key: ValueKey(post.id),
            post: post,
            isCurrent: index == _currentIndex,
            warmUp: warmUp,
            savedPostsListenable: widget.savedPostsListenable,
            muted: _globalMuted,
            onMuteToggle: () =>
                setState(() => _globalMuted = !_globalMuted),
            onBack: () => Navigator.pop(context),
            currentUserId: FirebaseAuth.instance.currentUser?.uid,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL ITEM (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ReelItem extends StatefulWidget {
  final PostModel post;
  final bool isCurrent;
  final bool warmUp;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;
  final bool muted;
  final VoidCallback onMuteToggle;
  final VoidCallback onBack;
  final String? currentUserId;

  const _ReelItem({
    Key? key,
    required this.post,
    required this.isCurrent,
    required this.warmUp,
    required this.savedPostsListenable,
    required this.muted,
    required this.onMuteToggle,
    required this.onBack,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  bool _showHeart = false;

  Future<void> _toggleLike() async {
    final uid = widget.currentUserId;
    if (uid == null) return;
    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final ref = postRef.collection('likes').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final d = await tx.get(ref);
        if (d.exists) {
          tx.delete(ref);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(ref, {
            'userId': uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (_) {}
  }

  void _onDoubleTap() {
    _toggleLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(postId: widget.post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final firstVideo = post.firstVideoItem;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (post.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: post.thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: 600,
            memCacheHeight: 1000,
            placeholder: (_, __) =>
            const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) =>
            const ColoredBox(color: Colors.black),
          ),

        if (widget.isCurrent)
          GestureDetector(
            onDoubleTap: _onDoubleTap,
            child: _VideoCell(
              key: ValueKey('reel_${post.id}'),
              url: post.firstVideoUrl,
              thumbnailUrl: post.thumbnailUrl,
              trimStartMs: firstVideo?.trimStartMs,
              trimEndMs: firstVideo?.trimEndMs,
              fit: BoxFit.cover,
              autoPlay: widget.isCurrent && post.firstVideoUrl.isNotEmpty,
              warmUp: widget.warmUp && post.firstVideoUrl.isNotEmpty,
              muted: widget.muted,
              visibilityKey: 'reel_${post.id}',
              showProgressBar: true,
              showProcessing: post.isVideoProcessing,
            ),
          ),

        if (_showHeart)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: const Icon(Icons.favorite,
                    color: Colors.white, size: 90),
              ),
            ),
          ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: 44,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 22),
            onPressed: widget.onBack,
          ),
        ),

        Positioned(
          top: 44,
          right: 8,
          child: IconButton(
            icon: Icon(
                widget.muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: Colors.white,
                size: 24),
            onPressed: widget.onMuteToggle,
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.75),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),

        if (widget.isCurrent)
          Positioned(
            left: 12,
            bottom: 100,
            right: 80,
            child: _ReelAuthorInfo(userId: post.userId),
          ),

        if (post.caption.isNotEmpty)
          Positioned(
            left: 12,
            right: 80,
            bottom: 50,
            child: Text(post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13, height: 1.4)),
          ),

        if (widget.isCurrent)
          Positioned(
            right: 10,
            bottom: 80,
            child: _ReelActionBar(
              postId: post.id,
              currentUserId: widget.currentUserId,
              likeCount: post.likeCount,
              commentCount: post.commentCount,
              onLike: _toggleLike,
              onComment: _openComments,
              onShare: () async {
                final url = post.firstVideoUrl;
                if (url.isNotEmpty) await Share.share(url);
              },
              savedPostsListenable: widget.savedPostsListenable,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL AUTHOR INFO (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ReelAuthorInfo extends StatefulWidget {
  final String userId;
  const _ReelAuthorInfo({required this.userId});

  @override
  State<_ReelAuthorInfo> createState() => _ReelAuthorInfoState();
}

class _ReelAuthorInfoState extends State<_ReelAuthorInfo> {
  Map<String, dynamic>? _userData;
  bool _following = false;
  bool _followLoading = false;
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    final data = await _UserProfileCache().get(widget.userId);
    if (!mounted) return;
    setState(() => _userData = data);

    if (_currentUserId != null &&
        _currentUserId != widget.userId) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .collection('following')
          .doc(widget.userId)
          .get();
      if (mounted) setState(() => _following = doc.exists);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null ||
        _currentUserId == widget.userId) return;
    setState(() => _followLoading = true);
    final followRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId!)
        .collection('following')
        .doc(widget.userId);
    final followerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .doc(_currentUserId!);
    try {
      if (_following) {
        await followRef.delete();
        await followerRef.delete();
      } else {
        await followRef
            .set({'followedAt': FieldValue.serverTimestamp()});
        await followerRef
            .set({'followedAt': FieldValue.serverTimestamp()});
      }
      if (mounted) {
        setState(
                () {
              _following = !_following;
              _followLoading = false;
            });
      }
    } catch (_) {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  void _openProfile() {
    if (widget.userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileRouterScreen(profileUserId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] ??
        _userData?['name'] ??
        'User')
        .toString();
    final photoUrl =
    _UserProfileCache.extractPhotoUrl(_userData ?? {});
    final isSelf = _currentUserId == widget.userId;

    return Row(
      children: [
        GestureDetector(
          onTap: _openProfile,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade800,
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                  maxWidthDiskCache: 300,
                  placeholder: (_, __) => const SizedBox(),
                )
                    : const Icon(Icons.person,
                    color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(username,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ]),
        ),
        if (!isSelf) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _followLoading ? null : _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color:
                _following ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: _followLoading
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white))
                  : Text(
                _following ? 'Following' : 'Follow',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _following
                        ? Colors.white
                        : Colors.black),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL ACTION BAR (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ReelActionBar extends StatefulWidget {
  final String postId;
  final String? currentUserId;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;

  const _ReelActionBar({
    required this.postId,
    required this.currentUserId,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.savedPostsListenable,
  });

  @override
  State<_ReelActionBar> createState() => _ReelActionBarState();
}

class _ReelActionBarState extends State<_ReelActionBar> {
  bool _isLiked = false;
  late int _localLikeCount;

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.likeCount;
  }

  void _handleLike() {
    if (widget.currentUserId == null) {
      widget.onLike();
      return;
    }
    final next = !_isLiked;
    setState(() {
      _isLiked = next;
      _localLikeCount =
          (_localLikeCount + (next ? 1 : -1)).clamp(0, 1 << 60);
    });
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _ReelActionButton(
        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
        color: _isLiked ? _kLikeRed : Colors.white,
        label: _localLikeCount > 0 ? '$_localLikeCount' : '',
        onTap: _handleLike,
      ),
      const SizedBox(height: 20),
      _ReelActionButton(
        icon: Icons.chat_bubble_outline_rounded,
        color: Colors.white,
        label: widget.commentCount > 0 ? '${widget.commentCount}' : '',
        onTap: widget.onComment,
      ),
      const SizedBox(height: 20),
      _ReelActionButton(
        icon: Icons.send_outlined,
        color: Colors.white,
        label: 'Share',
        onTap: widget.onShare,
      ),
      const SizedBox(height: 20),
      ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: widget.savedPostsListenable,
        builder: (_, savedMap, __) {
          return SaveButton(
            postId: widget.postId,
            currentUserId: widget.currentUserId,
            savedPostsMap: savedMap,
            iconSize: 28,
            color: Colors.white,
          );
        },
      ),
    ]);
  }
}

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ReelActionButton(
      {required this.icon,
        required this.color,
        required this.label,
        required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 30),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(blurRadius: 4, color: Colors.black54)
                ])),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO CELL (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _VideoCell extends StatefulWidget {
  final String url;
  final String thumbnailUrl;
  final int? trimStartMs;
  final int? trimEndMs;
  final BoxFit fit;
  final bool autoPlay;
  final bool warmUp;
  final bool muted;
  final String? visibilityKey;
  final bool showProgressBar;
  final bool showProcessing;

  const _VideoCell({
    Key? key,
    required this.url,
    this.thumbnailUrl = '',
    this.trimStartMs,
    this.trimEndMs,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
    this.warmUp = false,
    this.muted = false,
    this.visibilityKey,
    this.showProgressBar = false,
    this.showProcessing = false,
  }) : super(key: key);

  @override
  State<_VideoCell> createState() => _VideoCellState();
}

class _VideoCellState extends State<_VideoCell> {
  VideoPlayerController? _ctrl;
  String? _attachedUrl;
  bool _error = false;
  bool _isVisible = false;
  bool _listenerAttached = false;
  Duration _effectiveTrimStart = Duration.zero;
  Duration? _effectiveTrimEnd;
  Timer? _bindDebounce;
  int _bindGeneration = 0;

  bool get _videoReady =>
      _ctrl != null && _ctrl!.value.isInitialized && !_error;

  bool get _shouldBind =>
      widget.url.isNotEmpty &&
          (widget.autoPlay || widget.warmUp || _isVisible);

  @override
  void initState() {
    super.initState();
    if (widget.url.isNotEmpty &&
        (widget.autoPlay || widget.warmUp)) {
      Future.microtask(_kickBind);
    }
  }

  void _kickBind() {
    if (!mounted) return;
    if (widget.autoPlay) {
      _bindDebounce?.cancel();
      unawaited(_bindToPoolOrPreload());
    } else {
      _scheduleBind();
    }
  }

  void _scheduleBind() {
    if (!mounted || widget.url.isEmpty) return;
    _bindDebounce?.cancel();
    final ms = widget.autoPlay ? 0 : (widget.warmUp ? 50 : 80);
    if (ms == 0) {
      unawaited(_bindToPoolOrPreload());
      return;
    }
    _bindDebounce = Timer(Duration(milliseconds: ms), () {
      if (mounted) unawaited(_bindToPoolOrPreload());
    });
  }

  @override
  void didUpdateWidget(_VideoCell old) {
    super.didUpdateWidget(old);

    if (old.url != widget.url) {
      if (old.url.isNotEmpty) {
        VideoControllerPool.instance.release(old.url);
      }
      _bindGeneration++;
      _bindDebounce?.cancel();
      _detachListener();
      _ctrl = null;
      _attachedUrl = null;
      _error = false;
      if (widget.url.isNotEmpty) {
        Future.microtask(_kickBind);
      } else {
        setState(() {});
      }
      return;
    }

    if (_videoReady) {
      if (old.autoPlay != widget.autoPlay ||
          old.muted != widget.muted) {
        _applyMuteAndPlayback();
      }
    }

    if (!old.warmUp &&
        widget.warmUp &&
        widget.url.isNotEmpty) {
      _scheduleBind();
    }

    if (old.autoPlay != widget.autoPlay &&
        widget.autoPlay &&
        widget.url.isNotEmpty &&
        !_videoReady) {
      unawaited(_bindToPoolOrPreload());
    }
  }

  Future<void> _bindToPoolOrPreload() async {
    if (!mounted || widget.url.isEmpty) return;

    final url = widget.url;
    final gen = ++_bindGeneration;

    if (_attachedUrl == url &&
        _ctrl != null &&
        _ctrl!.value.isInitialized) {
      _applyMuteAndPlayback();
      return;
    }

    if (!_shouldBind &&
        !VideoControllerPool.instance.isReady(url)) {
      return;
    }

    VideoPlayerController? pooled =
    VideoControllerPool.instance.get(url);
    pooled ??= await VideoControllerPool.instance.preload(url);

    if (!mounted || gen != _bindGeneration || widget.url != url) {
      ReelLifecycleLog.generationMismatch(url, expected: gen, actual: _bindGeneration);
      return;
    }

    if (pooled == null) {
      setState(() => _error = true);
      return;
    }

    _attachController(pooled, url);
    ReelLifecycleLog.bind(url, generation: gen);
  }

  void _attachController(
      VideoPlayerController ctrl, String url) {
    if (!mounted || widget.url != url) return;

    if (_ctrl != ctrl) {
      _detachListener();
      _ctrl = ctrl;
      _attachedUrl = url;
    }

    if (!_listenerAttached) {
      _ctrl!.addListener(_onControllerUpdate);
      _listenerAttached = true;
    }

    if (_ctrl!.value.isInitialized) {
      _updateTrimBounds();
    }
    _applyMuteAndPlayback();
    setState(() {});
  }

  void _detachListener() {
    if (_listenerAttached && _ctrl != null) {
      _ctrl!.removeListener(_onControllerUpdate);
      _listenerAttached = false;
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;

    if (c.value.hasError) {
      setState(() => _error = true);
      return;
    }

    if (c.value.isInitialized) {
      if (_effectiveTrimStart == Duration.zero &&
          _effectiveTrimEnd == null &&
          (widget.trimStartMs != null ||
              widget.trimEndMs != null)) {
        _updateTrimBounds();
      }
    }

    _enforceTrimWindow();
  }

  void _applyMuteAndPlayback() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || !mounted) return;
    if (_attachedUrl != widget.url) return;
    try {
      c.setVolume(widget.muted ? 0 : 1);
      if (widget.autoPlay) {
        ReelLifecycleLog.activate(widget.url);
        _ensureAtTrimStart();
        c.play();
      } else {
        ReelLifecycleLog.deactivate(widget.url);
        c.pause();
      }
    } catch (e) {
      ReelLifecycleLog.playerException(widget.url, e);
    }
  }

  void _ensureAtTrimStart() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.position < _effectiveTrimStart) {
      c.seekTo(_effectiveTrimStart);
    }
  }

  void _updateTrimBounds() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final duration = c.value.duration;
    final maxMs = duration.inMilliseconds;
    if (maxMs <= 0) return;
    final startMs = (widget.trimStartMs ?? 0).clamp(0, maxMs);
    final rawEnd = widget.trimEndMs;
    int? boundedEnd;
    if (rawEnd != null) {
      boundedEnd = rawEnd.clamp(startMs, maxMs);
    }
    _effectiveTrimStart = Duration(milliseconds: startMs);
    _effectiveTrimEnd = boundedEnd != null
        ? Duration(milliseconds: boundedEnd)
        : null;
  }

  void _enforceTrimWindow() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (_effectiveTrimEnd == null) return;
    if (c.value.position >= _effectiveTrimEnd!) {
      c.seekTo(_effectiveTrimStart);
      if (widget.autoPlay) c.play();
    }
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null || !_videoReady) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  void dispose() {
    _bindDebounce?.cancel();
    _bindGeneration++;
    ReelLifecycleLog.dispose(widget.url, reason: 'video_cell');
    _detachListener();
    final ctrl = _ctrl;
    if (ctrl != null) {
      unawaited(() async {
        try {
          if (ctrl.value.isInitialized) {
            await ctrl.setVolume(0);
            await ctrl.pause();
          }
        } catch (_) {}
      }());
    }
    if (widget.url.isNotEmpty) {
      VideoControllerPool.instance.release(widget.url);
    }
    _ctrl = null;
    super.dispose();
  }

  Widget _thumbnailLayer(int decodeW, int decodeH) {
    if (widget.thumbnailUrl.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return CachedNetworkImage(
      imageUrl: widget.thumbnailUrl,
      cacheManager: AppCacheManager.media,
      fit: BoxFit.cover,
      memCacheWidth: decodeW,
      memCacheHeight: decodeH,
      placeholder: (_, __) => const ColoredBox(color: Colors.black),
      errorWidget: (_, __, ___) =>
      const ColoredBox(color: Colors.black),
    );
  }

  Widget _buildCore(int decodeW, int decodeH) {
    if (widget.showProcessing || (widget.url.isEmpty && ! _error)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailLayer(decodeW, decodeH),
          const ColoredBox(
            color: Colors.black54,
            child: Center(
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
                    'Processing video…',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_error) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailLayer(decodeW, decodeH),
          const ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Icon(Icons.videocam_off,
                  color: Colors.white54, size: 56),
            ),
          ),
        ],
      );
    }

    final showLoader = !_error &&
        (_ctrl == null || !_ctrl!.value.isInitialized) &&
        (widget.autoPlay || widget.warmUp);

    final showPoster = !_videoReady || !_ctrl!.value.isPlaying;

    return GestureDetector(
      onTap: _videoReady ? _togglePlay : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showPoster) _thumbnailLayer(decodeW, decodeH),
          if (_videoReady) ...[
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl!.value.size.width,
                  height: _ctrl!.value.size.height,
                  child: VideoPlayer(_ctrl!),
                ),
              ),
            ),
            if (!_ctrl!.value.isPlaying)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white70,
                    size: 64,
                  ),
                ),
              ),
            if (widget.showProgressBar)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _ctrl!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor:
                    Colors.white.withValues(alpha: 0.3),
                    backgroundColor:
                    Colors.white.withValues(alpha: 0.1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                ),
              ),
          ],
          if (showLoader)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.videocam_off,
              color: Colors.white54, size: 56),
        ),
      );
    }

    final mq = MediaQuery.of(context);
    final decodeW = (mq.size.width * mq.devicePixelRatio).round();
    final decodeH =
    (mq.size.height * mq.devicePixelRatio).round();

    final core = _buildCore(decodeW, decodeH);

    if (widget.visibilityKey != null) {
      return VisibilityDetector(
        key: Key(widget.visibilityKey!),
        onVisibilityChanged: (info) {
          final nowVisible = info.visibleFraction > 0.05;
          _isVisible = nowVisible;

          if (nowVisible) {
            if (widget.autoPlay ||
                widget.warmUp ||
                VideoControllerPool.instance
                    .isReady(widget.url)) {
              _bindDebounce?.cancel();
              if (widget.autoPlay) {
                unawaited(_bindToPoolOrPreload());
              } else {
                _scheduleBind();
              }
            }
          } else {
            _bindDebounce?.cancel();
            _ctrl?.pause();
          }
        },
        child: core,
      );
    }

    return core;
  }
}
