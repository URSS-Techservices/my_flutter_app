// ExplorePage.dart — Fixed + Instagram-style Explore & Reels for Halo
//
// FIXES IN THIS VERSION:
// [V1] Grid videos now show play icon + black bg thumbnail (no broken tiles)
// [V2] VideoPlayerController autoPlay now correctly triggers on page change
// [V12] Explore masonry: 1px gaps, 2-col phones for wider tiles, aspect from media/decode
// [V4] Reels use SizedBox.expand + FittedBox(BoxFit.cover) for true fullscreen
// [V5] Video ratio matches screen — FittedBox wraps SizedBox with video dimensions
// [V6] PageView gesture conflict resolved (NeverScrollableScrollPhysics on inner)
// [V7] isCurrent propagation fixed — controller play/pause on didUpdateWidget
// [V8] Video grid tile: uses firstVideoUrl for thumbnail extraction
// [V9] Reels PageController initialPage set correctly
// [V10] All StreamBuilders merged per-post (no redundant listeners)
// [V11] _VideoCell: pool-first bind, no visibility-based controller drop, preload dedupe

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/widgets/save_button.dart';
import 'package:halo/services/save_service.dart';
import 'package:halo/models/media_model.dart';
import 'package:halo/services/app_cache_manager.dart';

const double _kExploreGridGutter = 1;
const double _kExploreGridOuterPadH = 2;

/// Masonry column width / tile height (w ÷ h). Clamped so layout never explodes.
const double _kExploreTileMinAspect = 0.42;
const double _kExploreTileMaxAspect = 2.05;
/// Vertical-ish default until real dimensions load (9:16-ish thumbs).
const double _kExploreFallbackAspectVideo = 0.56;
/// Slightly portrait default — avoids stiff squares while thumbnails decode.
const double _kExploreFallbackAspectPhoto = 0.78;

/// Fewer columns on phones so each tile is **wider** (less tall-skinny “rectangle”).
int exploreMasonryCrossAxisCount(double width) {
  if (width >= 1100) return 4;
  if (width >= 560) return 3;
  return 2;
}

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

/// Reads `width`/`height` or `aspectRatio` + one side from a Firestore media map.
(int?, int?) _intrinsicSizeFromMediaMap(Map<String, dynamic> map) {
  int? w = _readPositiveInt(map['width']) ??
      _readPositiveInt(map['thumbWidth']) ??
      _readPositiveInt(map['w']);
  int? h = _readPositiveInt(map['height']) ??
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

String _exploreGridDisplayUrl(PostModel post) {
  if (post.isVideo) {
    if (post.thumbnailUrl.isNotEmpty) return post.thumbnailUrl;
    final v = post.firstVideoItem;
    if (v == null) return '';
    if (v.thumbnail.isNotEmpty) return v.thumbnail;
    if (v.thumb.isNotEmpty) return v.thumb;
    return v.url;
  }
  return post.firstImageUrl;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary    = Color(0xFF5B3FA3);
const Color _kExploreBg  = Color(0xFFF4F1FB);
const Color _kLikeRed    = Color(0xFFED4956);
const int   _kPageSize   = 10;

// ─────────────────────────────────────────────────────────────────────────────
// POST MODEL
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// VIDEO CONTROLLER POOL
// ═══════════════════════════════════════════════════════════════════════════════

class _PooledController {
  final String url;
  VideoPlayerController controller;
  bool isInitialized = false;
  bool isDisposed = false;
  DateTime lastUsed = DateTime.now();

  _PooledController({required this.url, required this.controller});
}

class VideoControllerPool {
  VideoControllerPool._();
  static final VideoControllerPool instance = VideoControllerPool._();

  static const int _maxPoolSize = 5;
  final Map<String, _PooledController> _pool = {};
  final List<String> _lruOrder = [];
  final Map<String, Future<VideoPlayerController?>> _preloadInflight = {};

  /// Single in-flight [preload] per URL so parallel callers share one init.
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

  Future<VideoPlayerController?> _preloadBody(String url) async {
    if (_pool.containsKey(url)) {
      _touch(url);
      final entry = _pool[url]!;
      if (entry.isDisposed) return null;
      if (entry.isInitialized) return entry.controller;
      try {
        await entry.controller.initialize();
        if (!entry.isDisposed) {
          entry.isInitialized = true;
          await entry.controller.setLooping(true);
          await entry.controller.setVolume(0);
          await entry.controller.pause();
        }
      } catch (_) {
        _remove(url);
        return null;
      }
      return entry.controller;
    }

    await _evictIfNeeded();

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );

    final entry = _PooledController(url: url, controller: ctrl);
    _pool[url] = entry;
    _lruOrder.add(url);

    try {
      // ✅ Initialize only once safely
      if (!entry.isInitialized && !entry.isDisposed) {
        await ctrl.initialize();

        if (!entry.isDisposed) {
          entry.isInitialized = true;

          // ✅ Reels should loop
          await ctrl.setLooping(true);
          await ctrl.setVolume(0);
          await ctrl.pause();
        }
      }
    } catch (e) {
      _remove(url);
      return null;
    }

    return ctrl;
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
      _pool.containsKey(url) && _pool[url]!.isInitialized && !_pool[url]!.isDisposed;

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
// REEL PREFETCH MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

class ReelPrefetchManager {
  ReelPrefetchManager._();
  static final ReelPrefetchManager instance = ReelPrefetchManager._();

  int _lastIndex = -1;

  Future<void> prefetchAround(List<String> videoUrls, int currentIndex) async {
    if (currentIndex == _lastIndex) return;
    _lastIndex = currentIndex;

    final indices = <int>{};
    for (int i = -1; i <= 2; i++) {
      final idx = currentIndex + i;
      if (idx >= 0 && idx < videoUrls.length && idx != currentIndex) {
        indices.add(idx);
      }
    }

    for (final idx in indices) {
      final url = videoUrls[idx];
      if (url.isNotEmpty && !VideoControllerPool.instance.isReady(url)) {
        unawaited(VideoControllerPool.instance.preload(url));
      }
    }
  }
}


class PostMediaItem {
  final String url;
  final bool isVideo;
  final String thumb;
  final String medium;
  final String full;
  final String videoUrl;
  final String thumbnail;
  final int? trimStartMs;
  final int? trimEndMs;
  /// From Firestore when present — drives masonry tile height without decoding.
  final int? intrinsicWidth;
  final int? intrinsicHeight;
  const PostMediaItem({
    required this.url,
    required this.isVideo,
    this.thumb = '',
    this.medium = '',
    this.full = '',
    this.videoUrl = '',
    this.thumbnail = '',
    this.trimStartMs,
    this.trimEndMs,
    this.intrinsicWidth,
    this.intrinsicHeight,
  });

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

  // Precomputed fields to avoid repeated runtime calculations during scroll.
  final bool isVideo;
  final bool hasMedia;
  final String firstImageUrl;
  final String firstVideoUrl;
  final PostMediaItem? firstVideoItem;

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
    required this.firstVideoItem,
    required this.captionLower,
    required this.locationLower,
  });

  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final parsedTags = _safeStringList(data['tags']);
    final parsedMedia = _parseMediaItems(data);
    final parsedIsVideo = parsedMedia.any((m) => m.isVideo);
    final parsedHasMedia = parsedMedia.isNotEmpty;
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
    final parsedFirstVideoUrl =
    parsedIsVideo && parsedFirstVideoItem.forFeed().isNotEmpty
        ? parsedFirstVideoItem.forFeed()
        : parsedFirstVideoItem.url;
    final parsedFirstVideoItemNullable = parsedIsVideo ? parsedFirstVideoItem : null;

    return PostModel(
      id:         doc.id,
      userId:     (data['userId'] ?? '').toString(),
      caption:    (data['caption'] ?? '').toString(),
      location:   (data['location'] ?? '').toString(),
      tags:       parsedTags,
      tagsLower: parsedTags.map((t) => t.toLowerCase()).toList(growable: false),
      mediaItems: parsedMedia,
      createdAt:  (data['createdAt'] as Timestamp?)?.toDate(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString().trim(),
      likeCount: _asInt(data['likeCount']),
      commentCount: _asInt(data['commentCount']),
      isVideo: parsedIsVideo,
      hasMedia: parsedHasMedia,
      firstImageUrl: parsedFirstImageUrl,
      firstVideoUrl: parsedFirstVideoUrl,
      firstVideoItem: parsedFirstVideoItemNullable,
      captionLower: (data['caption'] ?? '').toString().toLowerCase(),
      locationLower: (data['location'] ?? '').toString().toLowerCase(),
    );
  }

  PostMediaItem? get _exploreCoverMediaItem {
    if (isVideo) return firstVideoItem;
    for (final m in mediaItems) {
      if (!m.isVideo && m.forGrid().isNotEmpty) return m;
    }
    return mediaItems.isNotEmpty ? mediaItems.first : null;
  }

  /// Pixel size of the Explore thumbnail when `width`/`height` exist on media.
  (int, int)? get exploreCoverPixelSize {
    final cover = _exploreCoverMediaItem;
    if (cover == null) return null;
    final w = cover.intrinsicWidth;
    final h = cover.intrinsicHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return (w, h);
  }

  /// Width ÷ height for the masonry cell, clamped for stable layout.
  double exploreCoverAspectRatioClamped() {
    final px = exploreCoverPixelSize;
    if (px != null) {
      return (px.$1 / px.$2).clamp(_kExploreTileMinAspect, _kExploreTileMaxAspect).toDouble();
    }
    return isVideo ? _kExploreFallbackAspectVideo : _kExploreFallbackAspectPhoto;
  }

  static List<PostMediaItem> _parseMediaItems(Map<String, dynamic> data) {

    // ✅ PRIORITY 1: images[] (ALWAYS FIRST)
    // FIRST check media (videos/images mixed)
    if (data['media'] is List && (data['media'] as List).isNotEmpty) {
      final list = data['media'] as List;

      return list.map((item) {
        final map = item as Map<String, dynamic>;

        final type = (map['type'] ?? 'image').toString();
        final url = (map['url'] ?? '').toString();
        final thumb = (map['thumbnail'] ?? '').toString();
        final dims = _intrinsicSizeFromMediaMap(map);

        return PostMediaItem(
          url: url,
          isVideo: type == 'video',
          thumb: thumb.isNotEmpty ? thumb : url,
          medium: url,
          full: url,
          videoUrl: type == 'video' ? url : '',
          thumbnail: thumb,
          intrinsicWidth: dims.$1,
          intrinsicHeight: dims.$2,
        );
      }).toList();
    }

    // 🔹 THEN fallback to parsed media
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
          thumbnail: m.thumbnail ?? '',
          trimStartMs: m.trimStartMs,
          trimEndMs: m.trimEndMs,
        );
      }).toList(growable: false);
    }

    // 🔹 legacy fallback
    final legacyUrl = (data['imageUrl'] ??
        data['photoUrl'] ??
        data['mediaUrl'] ??
        data['thumbnailUrl'] ??
        '')
        .toString();

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

    // ❌ FINAL fallback
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

// ─────────────────────────────────────────────────────────────────────────────
// USER PROFILE CACHE
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
// FILTER ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _ExploreFilter { forYou, photos, videos, trending }

extension _ExploreFilterLabel on _ExploreFilter {
  String get label {
    switch (this) {
      case _ExploreFilter.forYou:    return 'For You';
      case _ExploreFilter.photos:    return 'Photos';
      case _ExploreFilter.videos:    return 'Videos';
      case _ExploreFilter.trending:  return 'Trending';
    }
  }
  IconData get icon {
    switch (this) {
      case _ExploreFilter.forYou:    return Icons.auto_awesome_rounded;
      case _ExploreFilter.photos:    return Icons.photo_rounded;
      case _ExploreFilter.videos:    return Icons.videocam_rounded;
      case _ExploreFilter.trending:  return Icons.trending_up_rounded;
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
  final List<PostModel>   _posts          = [];
  DocumentSnapshot?       _lastDoc;
  bool                    _isFetching     = false;
  bool                    _hasMore        = true;
  bool                    _didAutoOpenReels = false;
  bool                    _hasMoreUndated = true;
  final ScrollController  _scrollCtrl     = ScrollController();
  DocumentSnapshot?      _undatedLastDoc;
  final TextEditingController _searchCtrl = TextEditingController();

  _ExploreFilter _filter      = _ExploreFilter.forYou;
  String         _searchQuery = '';
  List<String>   _trendingTags = [];

  // Cached saved posts to avoid a StreamBuilder per tile/action (production
  // performance critical).
  final ValueNotifier<Map<String, dynamic>> _savedPostsNotifier =
      ValueNotifier<Map<String, dynamic>>(const <String, dynamic>{});
  StreamSubscription<Map<String, dynamic>>? _savedPostsSub;

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

  List<PostModel> _filteredPostsCache = const [];

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
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
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
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400 &&
        !_isFetching && (_hasMore || _hasMoreUndated)) {
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

      // 1) Main page query (depends on createdAt ordering)
      if (_hasMore) {
        Query<Map<String, dynamic>> datedQuery = FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(_kPageSize);
        if (_lastDoc != null) {
          datedQuery = datedQuery.startAfterDocument(_lastDoc!);
        }

        final snap = await datedQuery.get();

        if (snap.docs.isEmpty || snap.docs.length < _kPageSize) {
          _hasMore = false;
        }

        if (snap.docs.isNotEmpty) {
          _lastDoc = snap.docs.last;
          final newPosts = snap.docs.map(PostModel.fromFirestore).toList();
          for (final p in newPosts) {
            if (existingIds.contains(p.id)) continue;
            existingIds.add(p.id);
            _posts.add(p);
            addedCount++;
          }
        }
      }

      // 2) Fetch "createdAt is null" posts safely, with their own pagination.
      // This prevents missing tiles when scrolling past the first page.
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
        final undatedDocs = undatedSnap.docs;
        if (undatedDocs.isEmpty || undatedDocs.length < remaining) {
          _hasMoreUndated = false;
        }

        if (undatedDocs.isNotEmpty) {
          _undatedLastDoc = undatedDocs.last;
          final undatedPosts =
              undatedDocs.map(PostModel.fromFirestore).toList();
          for (final p in undatedPosts) {
            if (existingIds.contains(p.id)) continue;
            existingIds.add(p.id);
            _posts.add(p);
            addedCount++;
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
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _trendingTags = sorted.take(10).map((e) => e.key).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _lastDoc    = null;
      _hasMore    = true;
      _isFetching = false;
      _trendingTags = [];
      _hasMoreUndated = true;
      _undatedLastDoc = null;
      _filteredPostsCache = const [];
    });
    _UserProfileCache().clear();
    await _fetchNextPage();
  }

  // _filteredPostsCache is computed on state changes.

  void _openReels(List<PostModel> videoPosts, int startIdx) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ExploreReelsViewer(
        videoPosts: videoPosts,
        initialIndex: startIdx,
        savedPostsListenable: _savedPostsNotifier,
      ),
    ));
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

  void _onTileTap(PostModel post, List<PostModel> posts) async {
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
                  (_filter == _ExploreFilter.forYou || _filter == _ExploreFilter.trending))
                SliverToBoxAdapter(child: _buildTrendingSection()),

              _buildGrid(),

              if (_isFetching)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: _kPrimary))),
                ),

              if (!_hasMore && _posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.all(24),
                      child: Center(child: Text("You've seen it all!",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
          Text('Explore', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 22, color: const Color(0xFF1F1033))),
        ]),
      ),

      // Search bar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _rebuildFilteredPostsCache();
            }),
            textInputAction: TextInputAction.search,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search posts, tags, places...',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _kPrimary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _rebuildFilteredPostsCache();
                }),
              )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ),

      const SizedBox(height: 10),

      // Filter chips
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _ExploreFilter.values.map((f) => _FilterChip(
            filter: f, selected: _filter == f,
            onTap: () => setState(() {
              _filter = f;
              _rebuildFilteredPostsCache();
            }),
          )).toList(),
        ),
      ),

      const SizedBox(height: 10),
    ],
  );

  Widget _buildTrendingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: _kPrimary, size: 18),
          const SizedBox(width: 6),
          Text('Trending', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1F1033))),
        ]),
      ),
      SizedBox(
        height: 36,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.18), width: 1),
                ),
                child: Text('#$tag', style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500, color: _kPrimary)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
    ],
  );

  Widget _buildShimmerMasonry() {
    final w = MediaQuery.sizeOf(context).width;
    final n = exploreMasonryCrossAxisCount(w);
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        _kExploreGridOuterPadH,
        6,
        _kExploreGridOuterPadH,
        10,
      ),
      crossAxisCount: n,
      mainAxisSpacing: _kExploreGridGutter,
      crossAxisSpacing: _kExploreGridGutter,
      itemCount: 15,
      itemBuilder: (_, i) {
        final a = i % 7 == 0 ? 0.78 : (i % 3 == 1 ? 0.95 : 0.88);
        return AspectRatio(
          aspectRatio: a,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const _ShimmerBox(width: double.infinity, height: double.infinity),
          ),
        );
      },
    );
  }

  /// Masonry feed: chronological order, breathing room, 2–4 columns by width.
  Widget _buildGrid() {
    final posts = _filteredPostsCache;

    if (posts.isEmpty && !_isFetching) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.explore_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'Nothing to explore yet',
              style: GoogleFonts.poppins(color: Colors.grey.shade500),
            ),
          ]),
        ),
      );
    }

    if (posts.isEmpty && _isFetching) {
      return SliverToBoxAdapter(child: _buildShimmerMasonry());
    }

    final w = MediaQuery.sizeOf(context).width;
    final n = exploreMasonryCrossAxisCount(w);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        _kExploreGridOuterPadH,
        4,
        _kExploreGridOuterPadH,
        12,
      ),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: n,
        mainAxisSpacing: _kExploreGridGutter,
        crossAxisSpacing: _kExploreGridGutter,
        childCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final showCaption = index % 11 == 0 &&
              post.caption.isNotEmpty &&
              !post.isVideo;
          return RepaintBoundary(
            child: _ExploreGridTile(
              post: post,
              crossAxisCount: n,
              showCaptionOverlay: showCaption,
              onTap: () => _onTileTap(post, posts),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final _ExploreFilter filter;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.filter, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? _kPrimary : Colors.grey.shade300, width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(filter.icon, size: 14, color: selected ? Colors.white : Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(filter.label, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade700)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
          colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreGridTile extends StatefulWidget {
  final PostModel post;
  final int crossAxisCount;
  final bool showCaptionOverlay;
  final VoidCallback onTap;

  const _ExploreGridTile({
    required this.post,
    required this.crossAxisCount,
    required this.showCaptionOverlay,
    required this.onTap,
  });

  @override
  State<_ExploreGridTile> createState() => _ExploreGridTileState();
}

class _ExploreGridTileState extends State<_ExploreGridTile> {
  late double _aspect;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _aspect = widget.post.exploreCoverAspectRatioClamped();
    if (widget.post.exploreCoverPixelSize == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAspectFromImage());
    }
  }

  @override
  void didUpdateWidget(covariant _ExploreGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _stopImageListener();
      _aspect = widget.post.exploreCoverAspectRatioClamped();
      if (widget.post.exploreCoverPixelSize == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAspectFromImage());
      }
    }
  }

  @override
  void dispose() {
    _stopImageListener();
    super.dispose();
  }

  void _stopImageListener() {
    final listener = _imageListener;
    final stream = _imageStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _imageListener = null;
    _imageStream = null;
  }

  void _resolveAspectFromImage() {
    if (!mounted) return;
    if (widget.post.exploreCoverPixelSize != null) return;
    final url = _exploreGridDisplayUrl(widget.post);
    if (url.isEmpty) return;

    _stopImageListener();

    final provider = CachedNetworkImageProvider(
      url,
      cacheManager: AppCacheManager.media,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _imageStream = stream;
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w <= 0 || h <= 0 || !mounted) return;
        final r = (w / h).clamp(_kExploreTileMinAspect, _kExploreTileMaxAspect);
        _stopImageListener();
        setState(() => _aspect = r.toDouble());
      },
      onError: (_, __) => _stopImageListener(),
    );
    _imageListener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final extent = MediaQuery.sizeOf(context).width - _kExploreGridOuterPadH * 2;
    final colW =
        (extent - _kExploreGridGutter * (widget.crossAxisCount - 1)) / widget.crossAxisCount;
    final tileH = colW / _aspect;
    final decodeW = (colW * dpr).round();
    final decodeH = (tileH * dpr).round();
    final imageUrl = widget.post.firstImageUrl;
    final videoThumbUrl = widget.post.thumbnailUrl.isNotEmpty
        ? widget.post.thumbnailUrl
        : (widget.post.firstVideoItem?.thumbnail ?? '').isNotEmpty
            ? widget.post.firstVideoItem!.thumbnail
            : (widget.post.firstVideoItem?.url ?? '');
    const playIconSize = 34.0;
    const badgeIconSize = 14.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: _aspect,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.post.isVideo && videoThumbUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: videoThumbUrl,
                    cacheManager: AppCacheManager.media,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    memCacheWidth: decodeW,
                    memCacheHeight: decodeH,
                    maxWidthDiskCache: decodeW,
                    placeholder: (_, __) => ColoredBox(color: Colors.grey.shade900),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: Colors.grey.shade900,
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: playIconSize),
                    ),
                  )
                else if (widget.post.isVideo)
                  ColoredBox(
                    color: const Color(0xFF2D1B69),
                    child: Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: playIconSize),
                    ),
                  )
                else if (widget.post.hasMedia && imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheManager: AppCacheManager.media,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    memCacheWidth: decodeW,
                    memCacheHeight: decodeH,
                    maxWidthDiskCache: decodeW,
                    placeholder: (_, __) => ColoredBox(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  )
                else
                  ColoredBox(color: Colors.grey.shade200),

                if (widget.post.isVideo)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.26),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (widget.post.isVideo)
                  Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white.withValues(alpha: 0.92),
                      size: playIconSize,
                    ),
                  ),

                if (widget.post.isVideo)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.videocam_rounded,
                          color: Colors.white, size: badgeIconSize),
                    ),
                  )
                else if (widget.post.mediaItems.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.collections_rounded,
                          color: Colors.white, size: badgeIconSize),
                    ),
                  ),

                if (widget.showCaptionOverlay)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Text(
                        widget.post.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// POST DETAIL PAGE
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
    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like.')));
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
              child: Text(post.caption, style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF262626))),
            ),

          if (post.location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.location, style: GoogleFonts.poppins(
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
// MEDIA CAROUSEL
// ─────────────────────────────────────────────────────────────────────────────

class _MediaCarousel extends StatefulWidget {
  final List<PostMediaItem> mediaItems;
  final VoidCallback onDoubleTap;

  const _MediaCarousel({required this.mediaItems, required this.onDoubleTap});

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
            physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),

            // 🔥 FIX: update page only; avoid hidden preloads here
            onPageChanged: (i) {
              setState(() => _page = i);
              final videoUrls = widget.mediaItems
                  .where((m) => m.isVideo)
                  .map((m) => m.forFeed())
                  .toList();
              if (videoUrls.isNotEmpty) {
                ReelPrefetchManager.instance.prefetchAround(videoUrls, i);
              }
            },

            itemBuilder: (_, i) {
              final m = widget.mediaItems[i];
              final mq = MediaQuery.of(context);
              final isLargeDevice = mq.size.width >= 900;
              final imageUrl = m.forFullscreenByDevice(isLargeDevice);
              final decodeWidth = (mq.size.width * mq.devicePixelRatio).round();
              final decodeHeight = (380 * mq.devicePixelRatio).round();
              final thumbUrl = m.forGrid();
              final fallbackUrl = imageUrl.replaceAll('.webp', '.jpg');

              return GestureDetector(
                onDoubleTap: widget.onDoubleTap,

                child: m.isVideo
                    ? _VideoCell(
                  key: ValueKey('media_${m.forFeed()}'),
                  url: m.forFeed(),
                  thumbnailUrl: m.thumbnail.isNotEmpty ? m.thumbnail : m.thumb,  // ← ADD
                  trimStartMs: m.trimStartMs,
                  trimEndMs: m.trimEndMs,
                  fit: BoxFit.cover,
                  autoPlay: i == _page,
                  warmUp: (i - _page).abs() == 1,   // ← ADD
                  visibilityKey: 'media_${m.forFeed().hashCode}_$i',
                )

                    : CachedNetworkImage(
                  imageUrl: imageUrl,
                  cacheManager: AppCacheManager.media,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  memCacheWidth: decodeWidth,
                  memCacheHeight: decodeHeight,
                  maxWidthDiskCache: decodeWidth,
                  fadeInDuration: const Duration(milliseconds: 140),
                  placeholder: (_, __) => thumbUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbUrl,
                          cacheManager: AppCacheManager.media,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          memCacheWidth: decodeWidth,
                          memCacheHeight: decodeHeight,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) => const SizedBox(),
                        )
                      : const SizedBox(),
                  errorWidget: (_, __, ___) =>
                  (fallbackUrl != imageUrl)
                      ? Image.network(
                          fallbackUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : const Center(child: Icon(Icons.broken_image)),
                ),
              );
            },
          ),
        ),

        // 🔘 DOT INDICATOR
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
                    color:
                    _page == i ? _kPrimary : Colors.grey.shade300,
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
// POST ACTIONS
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
    required this.postId, required this.currentUserId,
    required this.likeCount, required this.commentCount,
    required this.onLike, required this.onComment, required this.onShare,
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
      _localLikeCount = (_localLikeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 60);
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
          icon: const Icon(Icons.chat_bubble_outline, size: 26, color: Colors.black87),
        ),
        IconButton(
          onPressed: widget.onShare,
          icon: const Icon(Icons.send_outlined, size: 26, color: Colors.black87),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
// USER HEADER
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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    final data = await _UserProfileCache().get(widget.userId);
    if (mounted) setState(() => _userData = data);
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] ?? _userData?['name'] ?? _userData?['full_name'] ?? 'User').toString();
    final photoUrl = _UserProfileCache.extractPhotoUrl(_userData ?? {});

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
          )
              : const Icon(Icons.person, color: Colors.grey),
        ),
      ),
      title: Text(username, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: widget.location.isNotEmpty
          ? Text(widget.location, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500))
          : null,
      trailing: const Icon(Icons.more_horiz),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final GlobalKey<_CommentsListState> _commentsKey =
      GlobalKey<_CommentsListState>();

  @override
  void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _addComment() async {
    final uid  = _currentUserId;
    if (uid == null) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentRef = postRef.collection('comments').doc();
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(commentRef, {
          'userId': uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'commentCount': FieldValue.increment(1)});
      });
      _input.clear();
      // Reload comments once (no realtime listener) so new comment appears.
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Text('Comments', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
          const Divider(),
          Expanded(child: _CommentsList(key: _commentsKey, postId: widget.postId)),
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
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
    if (!mounted) return;
    if (_isLoading) return;
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
      // Keep showing already loaded comments.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_docs.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_docs.isEmpty) {
      return Center(
        child: Text(
          'No comments yet',
          style: GoogleFonts.poppins(color: Colors.grey.shade500),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final metrics = n.metrics;
        final nearBottom =
            metrics.pixels >= metrics.maxScrollExtent - 220;
        if (nearBottom && !_isLoading && _hasMore) {
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
  void initState() { super.initState(); _fetchProfiles(); }

  @override
  void didUpdateWidget(_CommentsFetcher old) { super.didUpdateWidget(old); _fetchProfiles(); }

  Future<void> _fetchProfiles() async {
    final ids = widget.docs.map((d) => (d.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty).toSet();
    final missing = ids.where((id) => !_profiles.containsKey(id)).toList();
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
    if (!_loaded) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.docs.length,
      itemBuilder: (_, i) {
        final c  = widget.docs[i].data();
        final uid = (c['userId'] ?? '').toString();
        final ud  = _profiles[uid] ?? {};
        final username = (ud['username'] ?? ud['name'] ?? 'User').toString();
        final photoUrl = _UserProfileCache.extractPhotoUrl(ud);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  placeholder: (_, __) => const SizedBox(),
                  errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
                )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF262626)),
                  children: [
                    TextSpan(text: '$username ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: (c['text'] ?? '').toString()),
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
// [V4][V5] REELS VIEWER — true fullscreen, correct aspect ratio
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
  State<_ExploreReelsViewer> createState() => _ExploreReelsViewerState();
}

class _ExploreReelsViewerState extends State<_ExploreReelsViewer> {
  late final PageController _controller;
  int  _currentIndex = 0;
  bool _globalMuted  = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);

    // Preload first reel + next 2 immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final urls = widget.videoPosts.map((p) => p.firstVideoUrl).toList();
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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text('No videos', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Go back', style: TextStyle(color: Colors.white))),
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
        physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
        itemCount: widget.videoPosts.length,
        onPageChanged: (i) {
          setState(() => _currentIndex = i);

          // Prefetch adjacent reels on every swipe
          final urls = widget.videoPosts.map((p) => p.firstVideoUrl).toList();
          ReelPrefetchManager.instance.prefetchAround(urls, i);
        },
        itemBuilder: (_, index) {
          final post = widget.videoPosts[index];
          final warmUp = (index - _currentIndex).abs() <= 1;
          return _ReelItem(
            key: ValueKey(post.id),
            post: post,
            // [V7] isCurrent correctly passed to each item
            isCurrent: index == _currentIndex,
            warmUp: warmUp,
            savedPostsListenable: widget.savedPostsListenable,
            muted: _globalMuted,
            onMuteToggle: () => setState(() => _globalMuted = !_globalMuted),
            onBack: () => Navigator.pop(context),
            currentUserId: FirebaseAuth.instance.currentUser?.uid,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [V7] REEL ITEM — play/pause responds correctly when isCurrent changes
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
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
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
        // Non-current reels show a cheap thumbnail; no video initialization.
        // Always show thumbnail as base layer — prevents black flash while video loads
        if (post.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: post.thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: 600,
            memCacheHeight: 1000,
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
// [V4][V5] Full-screen video (only for current tile)
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
              // [V7] autoPlay is driven by isCurrent
              autoPlay: widget.isCurrent,
              warmUp: widget.warmUp,
              muted: widget.muted,
              visibilityKey: 'reel_${post.id}',
              showProgressBar: true,
            ),
          ),

        // Double-tap heart
        if (_showHeart)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: const Icon(Icons.favorite, color: Colors.white, size: 90),
              ),
            ),
          ),

        // Top gradient
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.5), Colors.transparent],
              ),
            ),
          ),
        ),

        // Back button
        Positioned(
          top: 44, left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: widget.onBack,
          ),
        ),

        // Mute button
        Positioned(
          top: 44, right: 8,
          child: IconButton(
            icon: Icon(widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white, size: 24),
            onPressed: widget.onMuteToggle,
          ),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.75), Colors.transparent],
              ),
            ),
          ),
        ),

        // Author info — bottom left (only for current tile)
        if (widget.isCurrent)
          Positioned(
            left: 12,
            bottom: 100,
            right: 80,
            child: _ReelAuthorInfo(userId: post.userId),
          ),

        // Caption
        if (post.caption.isNotEmpty)
          Positioned(
            left: 12, right: 80, bottom: 50,
            child: Text(post.caption, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, height: 1.4)),
          ),

        // Right action bar (only for current tile)
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
// REEL AUTHOR INFO
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
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    final data = await _UserProfileCache().get(widget.userId);
    if (!mounted) return;
    setState(() => _userData = data);

    if (_currentUserId != null && _currentUserId != widget.userId) {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(_currentUserId!).collection('following').doc(widget.userId).get();
      if (mounted) setState(() => _following = doc.exists);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;
    setState(() => _followLoading = true);
    final followRef  = FirebaseFirestore.instance
        .collection('users').doc(_currentUserId!).collection('following').doc(widget.userId);
    final followerRef = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('followers').doc(_currentUserId!);
    try {
      if (_following) {
        await followRef.delete();
        await followerRef.delete();
      } else {
        await followRef.set({'followedAt': FieldValue.serverTimestamp()});
        await followerRef.set({'followedAt': FieldValue.serverTimestamp()});
      }
      if (mounted) setState(() { _following = !_following; _followLoading = false; });
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
    final username = (_userData?['username'] ?? _userData?['name'] ?? 'User').toString();
    final photoUrl = _UserProfileCache.extractPhotoUrl(_userData ?? {});
    final isSelf   = _currentUserId == widget.userId;

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
                    : const Icon(Icons.person, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(username, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
        ),
        if (!isSelf) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _followLoading ? null : _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _following ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: _followLoading
                  ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                  : Text(_following ? 'Following' : 'Follow',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _following ? Colors.white : Colors.black)),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL ACTION BAR
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
    required this.postId, required this.currentUserId,
    required this.likeCount, required this.commentCount,
    required this.onLike, required this.onComment, required this.onShare,
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
      _localLikeCount = (_localLikeCount + (next ? 1 : -1)).clamp(0, 1 << 60);
    });
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final likeCount = _localLikeCount;
    final isLiked = _isLiked;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _ReelActionButton(
        icon: isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? _kLikeRed : Colors.white,
        label: likeCount > 0 ? '$likeCount' : '',
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

  const _ReelActionButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 30),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// [V2][V5][V7][V11] VIDEO CELL — pool-first, warmUp preload without play,
// visibility only pauses (never drops pooled ref), shared preload Future per URL.
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
    if (widget.url.isNotEmpty && (widget.autoPlay || widget.warmUp)) {
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

  /// Short debounce (≤100ms) to coalesce rapid parent updates; autoplay binds immediately.
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
      if (old.autoPlay != widget.autoPlay || old.muted != widget.muted) {
        _applyMuteAndPlayback();
      }
    }

    if (!old.warmUp && widget.warmUp && widget.url.isNotEmpty) {
      _scheduleBind();
    }

    if (old.autoPlay != widget.autoPlay &&
        widget.autoPlay &&
        widget.url.isNotEmpty &&
        !_videoReady) {
      unawaited(_bindToPoolOrPreload());
    }
  }

  /// Prefer pooled controller (already initialized). Otherwise [preload] and await
  /// (deduped in [VideoControllerPool]).
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

    if (!_shouldBind && !VideoControllerPool.instance.isReady(url)) {
      return;
    }

    VideoPlayerController? pooled = VideoControllerPool.instance.get(url);
    pooled ??= await VideoControllerPool.instance.preload(url);

    if (!mounted || gen != _bindGeneration || widget.url != url) return;

    if (pooled == null) {
      setState(() => _error = true);
      return;
    }

    _attachController(pooled, url);
  }

  void _attachController(VideoPlayerController ctrl, String url) {
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
          (widget.trimStartMs != null || widget.trimEndMs != null)) {
        _updateTrimBounds();
      }
    }

    _enforceTrimWindow();
  }

  void _applyMuteAndPlayback() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;

    c.setVolume(widget.muted ? 0 : 1);
    if (widget.autoPlay) {
      _ensureAtTrimStart();
      c.play();
    } else {
      c.pause();
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
    _effectiveTrimEnd =
        boundedEnd != null ? Duration(milliseconds: boundedEnd) : null;
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
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
    );
  }

  Widget _buildCore(int decodeW, int decodeH) {
    if (_error) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailLayer(decodeW, decodeH),
          const ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Icon(Icons.videocam_off, color: Colors.white54, size: 56),
            ),
          ),
        ],
      );
    }

    final showLoader = !_error &&
        (_ctrl == null || !_ctrl!.value.isInitialized) &&
        (widget.autoPlay || widget.warmUp);

    return GestureDetector(
      onTap: _videoReady ? _togglePlay : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailLayer(decodeW, decodeH),
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
                    bufferedColor: Colors.white.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
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
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 56),
        ),
      );
    }

    final mq = MediaQuery.of(context);
    final decodeW = (mq.size.width * mq.devicePixelRatio).round();
    final decodeH = (mq.size.height * mq.devicePixelRatio).round();

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
                VideoControllerPool.instance.isReady(widget.url)) {
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