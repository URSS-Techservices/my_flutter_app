// ExplorePage — Instagram-style Explore grid + reel viewer
// Clean rewrite. No legacy pool code, no complex resolver logic.
// Data: simple paginated Firestore query via ExploreService.
// Grid: 3-column square cells. Every 7th item is a 2×2 featured tile.
// Reel viewer: vertical PageView, single VideoPlayerController per page.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:halo/models/media_model.dart';
import 'package:halo/services/app_video_focus.dart';
import 'package:halo/services/explore_reel_prefetch.dart';
import 'package:halo/services/explore_service.dart';
import 'package:halo/services/reel_preload_policy.dart';
import 'package:halo/services/video_controller_pool.dart';
import 'package:halo/services/video_decoder_budget.dart';
import 'package:halo/services/video_dispose_serial.dart';
import 'package:halo/services/video_playback_resolver.dart';

// ─── constants ───────────────────────────────────────────────────────────────

const Color _kPrimary   = Color(0xFF5B3FA3);
const Color _kAccent    = Color(0xFFA58CE3);
const double _kGap      = 1.5;
const int    _kCols     = 3;
const int    _kFeatEvery = 7;   // every 7th item is a featured (2×2) tile

// ─── helpers ─────────────────────────────────────────────────────────────────

/// Returns the best available thumbnail/poster URL — never returns a raw video file URL.
String _thumb(Map<String, dynamic> d) {
  final candidates = [
    d['thumbnailUrl'], d['previewUrl'], d['thumbnail'], d['posterUrl'],
    d['coverUrl'], d['thumbUrl'],
    d['imageUrl'], d['photoUrl'], d['image'],
  ];
  for (final v in candidates) {
    final s = (v ?? '').toString().trim();
    if (s.isNotEmpty && !_isVideoUrl(s)) return s;
  }
  // Try inside media array
  final media = d['media'];
  if (media is List) {
    for (final item in media) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      for (final k in ['thumbnail', 'thumbnailUrl', 'previewUrl', 'posterUrl', 'coverUrl', 'thumb']) {
        final s = (m[k] ?? '').toString().trim();
        if (s.isNotEmpty && !_isVideoUrl(s)) return s;
      }
      final img = m['image'];
      if (img is Map) {
        for (final k in ['thumb', 'medium', 'full']) {
          final s = (img[k] ?? '').toString().trim();
          if (s.isNotEmpty && !_isVideoUrl(s)) return s;
        }
      }
      // For image media items, use the url itself
      if ((m['type'] ?? '') != 'video') {
        final s = (m['url'] ?? '').toString().trim();
        if (s.isNotEmpty && !_isVideoUrl(s)) return s;
      }
    }
  }
  // Structured media model (covers legacy + nested shapes)
  for (final m in MediaModel.parsePostMedia(d)) {
    if (m.isVideo && m.thumbnail.isNotEmpty && !_isVideoUrl(m.thumbnail)) {
      return m.thumbnail;
    }
    if (m.isImage) {
      final u = m.image.forGrid();
      if (u.isNotEmpty && !_isVideoUrl(u)) return u;
    }
  }
  // image-only posts: plain imageUrl fields
  final img = (d['images'] is List && (d['images'] as List).isNotEmpty)
      ? (d['images'] as List).first.toString().trim()
      : '';
  if (img.isNotEmpty && !_isVideoUrl(img)) return img;
  return '';
}

String _posterUrlFor(_Post post) {
  if (post.thumbUrl.isNotEmpty) return post.thumbUrl;
  if (post.imageUrl.isNotEmpty && !_isVideoUrl(post.imageUrl)) {
    return post.imageUrl;
  }
  return '';
}

/// Playable URL for Explore — processed MP4 first on iOS and Android; HLS as fallback.
({String primary, String fallback}) _resolveExploreUrls(Map<String, dynamic> d) {
  return resolveFeedVideoUrls(postData: d);
}

String _videoUrl(Map<String, dynamic> d) => _resolveExploreUrls(d).primary;

bool _isVideoUrl(String u) {
  final l = u.toLowerCase();
  return l.contains('.mp4') || l.contains('.mov') || l.contains('.m4v') ||
      l.contains('/videos/raw/') || l.contains('/video.mp4');
}

bool _isVideoPost(Map<String, dynamic> d) {
  final media = d['media'];
  if (media is List) {
    for (final item in media) {
      if (item is! Map) continue;
      if ((item['type'] ?? '') == 'video') return true;
    }
  }
  final type = (d['type'] ?? '').toString();
  if (type == 'video') return true;
  final v = _videoUrl(d);
  return v.isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════
// Post data model — flat, no resolver complexity
// ═══════════════════════════════════════════════════════════════════════════

class _Post {
  final String id;
  final String thumbUrl;   // for grid cell
  final String videoUrl;   // playable URL (empty for image posts)
  final String fallbackVideoUrl;
  final String imageUrl;   // for image posts
  final bool isVideo;
  final int likeCount;
  final int commentCount;
  final String caption;
  final String userId;
  final String username;
  final bool isMulti;      // more than one media item

  const _Post({
    required this.id,
    required this.thumbUrl,
    required this.videoUrl,
    this.fallbackVideoUrl = '',
    required this.imageUrl,
    required this.isVideo,
    required this.likeCount,
    required this.commentCount,
    required this.caption,
    required this.userId,
    required this.username,
    required this.isMulti,
  });

  bool get hasContent => thumbUrl.isNotEmpty || videoUrl.isNotEmpty || imageUrl.isNotEmpty;

  factory _Post.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final isVid = _isVideoPost(d);
    final tv = _thumb(d);
    final iv = isVid ? tv : ((d['imageUrl'] ?? d['photoUrl'] ?? tv).toString().trim());
    final urls = isVid ? _resolveExploreUrls(d) : (primary: '', fallback: '');
    return _Post(
      id: doc.id,
      thumbUrl: tv,
      videoUrl: urls.primary,
      fallbackVideoUrl: urls.fallback,
      imageUrl: iv,
      isVideo: isVid,
      likeCount: _asInt(d['likeCount'] ?? d['likesCount']),
      commentCount: _asInt(d['commentCount'] ?? d['commentsCount']),
      caption: (d['caption'] ?? '').toString().trim(),
      userId: (d['userId'] ?? '').toString().trim(),
      username: (d['username'] ?? d['userName'] ?? d['displayName'] ?? '').toString().trim(),
      isMulti: (d['media'] is List && (d['media'] as List).length > 1) ||
          (d['images'] is List && (d['images'] as List).length > 1),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ─── Filter enum ─────────────────────────────────────────────────────────────

enum _Filter { forYou, videos, photos, trending }

extension _FilterLabel on _Filter {
  String get label {
    switch (this) {
      case _Filter.forYou:    return 'For you';
      case _Filter.videos:    return 'Videos';
      case _Filter.photos:    return 'Photos';
      case _Filter.trending:  return 'Trending';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ExplorePage
// ═══════════════════════════════════════════════════════════════════════════

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ExploreService _svc = ExploreService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<_Post> _all   = [];
  List<_Post> _shown = [];
  bool _loading = true;
  bool _error   = false;
  StreamSubscription? _sub;
  String _query  = '';
  _Filter _filter = _Filter.forYou;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _sub?.cancel();
    _sub = _svc.getExplorePostsStream(uid).listen(
      (docs) {
        if (!mounted) return;
        final posts = docs
            .map((d) => _Post.fromDoc(d))
            .where((p) => p.hasContent)
            .toList();
        setState(() {
          _all     = posts;
          _loading = false;
          _error   = false;
          _applyFilter();
        });
      },
      onError: (_) {
        if (mounted) setState(() { _loading = false; _error = true; });
      },
    );
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q == _query) return;
    _query = q;
    setState(_applyFilter);
  }

  void _applyFilter() {
    var list = List.of(_all);
    // Search
    if (_query.isNotEmpty) {
      list = list.where((p) =>
        p.caption.toLowerCase().contains(_query) ||
        p.username.toLowerCase().contains(_query)
      ).toList();
    }
    // Filter chip
    switch (_filter) {
      case _Filter.videos:
        list = list.where((p) => p.isVideo).toList();
        break;
      case _Filter.photos:
        list = list.where((p) => !p.isVideo).toList();
        break;
      case _Filter.trending:
        list.sort((a, b) => (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));
        break;
      case _Filter.forYou:
        break;
    }
    _shown = list;
  }

  void _onScroll() {
    // could trigger pagination here; ExploreService is a stream so omitted
  }

  void _openReel(_Post post) {
    // Use ALL video posts (not just current filter) so swipe-through works
    final videos = _all.where((p) => p.isVideo && p.videoUrl.isNotEmpty).toList();
    if (videos.isEmpty) return;
    final idx = videos.indexWhere((p) => p.id == post.id);
    // Ensure prefetch is running (onTapDown may have already started it).
    ExploreReelPrefetch.instance.start(
      postId: post.id,
      videoUrl: post.videoUrl,
      fallbackUrl: post.fallbackVideoUrl,
    );
    AppVideoFocus.instance.enterFullscreenReel();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _ReelViewer(
          posts: videos,
          initialIndex: idx < 0 ? 0 : idx,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    ).whenComplete(AppVideoFocus.instance.exitFullscreenReel);
  }

  void _openDetail(_Post post) {
    if (post.isVideo && post.videoUrl.isNotEmpty) {
      _openReel(post);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _ImageDetail(post: post),
      ));
    }
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = false; _all = []; _shown = []; });
    _sub?.cancel();
    _load();
  }

  // Trending tags from current posts
  List<String> get _trendingTags {
    final freq = <String, int>{};
    for (final p in _all) {
      // Re-fetch tags from raw is unnecessary — caption words as proxy
    }
    return freq.entries
        .where((e) => e.value > 1)
        .take(8)
        .map((e) => e.key)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────────────
            _SearchBar(ctrl: _searchCtrl),

            // ── Filter chips ───────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _Filter.values.map((f) {
                  final selected = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() { _filter = f; _applyFilter(); }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? _kPrimary : const Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF444444),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 4),

            // ── Grid ───────────────────────────────────────────────────────
            Expanded(
              child: _error
                  ? _ErrorView(onRetry: _refresh)
                  : _loading
                      ? const _ShimmerGrid()
                      : _shown.isEmpty
                          ? _EmptyView(hasQuery: _query.isNotEmpty || _filter != _Filter.forYou)
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              color: _kPrimary,
                              child: _Grid(
                                posts: _shown,
                                scrollCtrl: _scrollCtrl,
                                onTap: _openDetail,
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: ctrl,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF262626)),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E8E8E), size: 20),
            suffixIcon: ListenableBuilder(
              listenable: ctrl,
              builder: (_, __) => ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Color(0xFF8E8E8E), size: 18),
                      onPressed: ctrl.clear,
                    )
                  : const SizedBox.shrink(),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer box ─────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double width, height;
  const _Shimmer({required this.width, required this.height});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        color: Color.lerp(const Color(0xFFE8E8E8), const Color(0xFFF4F4F4), _ctrl.value),
      ),
    );
  }
}

// ─── Shimmer grid (shown while loading) ──────────────────────────────────────

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();
  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final cell = (w - _kGap * (_kCols - 1)) / _kCols;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kCols,
        mainAxisSpacing: _kGap,
        crossAxisSpacing: _kGap,
        childAspectRatio: 1,
      ),
      itemCount: 15,
      itemBuilder: (_, __) => _Shimmer(width: cell, height: cell),
    );
  }
}

// ─── Grid ────────────────────────────────────────────────────────────────────

class _Grid extends StatelessWidget {
  final List<_Post> posts;
  final ScrollController scrollCtrl;
  final void Function(_Post) onTap;

  const _Grid({required this.posts, required this.scrollCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final cell = (w - _kGap * (_kCols - 1)) / _kCols;

    // Build sections: every _kFeatEvery items → featured row (1 big + 2 small)
    // All others → plain row of 3 equal cells
    final sections = <Widget>[];
    int i = 0;
    while (i < posts.length) {
      final isFeat = (i % _kFeatEvery == 0) && (i + 2 < posts.length);
      if (isFeat) {
        final big = posts[i];
        final sm1 = posts[i + 1];
        final sm2 = posts[i + 2];
        final bigSize = cell * 2 + _kGap;
        sections.add(
          RepaintBoundary(
            child: SizedBox(
              height: bigSize,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Cell(post: big, size: bigSize, isFeatured: true, onTap: onTap),
                  SizedBox(width: _kGap),
                  Column(children: [
                    _Cell(post: sm1, size: cell, onTap: onTap),
                    SizedBox(height: _kGap),
                    _Cell(post: sm2, size: cell, onTap: onTap),
                  ]),
                ],
              ),
            ),
          ),
        );
        i += 3;
      } else {
        final rowItems = posts.sublist(i, (i + _kCols).clamp(0, posts.length));
        // Pad row to always be 3 cells wide so alignment stays consistent
        sections.add(
          Row(
            children: List.generate(_kCols, (col) {
              if (col >= rowItems.length) {
                return SizedBox(width: cell + (col > 0 ? _kGap : 0));
              }
              return Row(mainAxisSize: MainAxisSize.min, children: [
                if (col > 0) SizedBox(width: _kGap),
                RepaintBoundary(child: _Cell(post: rowItems[col], size: cell, onTap: onTap)),
              ]);
            }),
          ),
        );
        i += _kCols;
      }
      sections.add(SizedBox(height: _kGap));
    }

    return ListView(
      controller: scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: sections,
    );
  }
}

// ─── Grid cell ───────────────────────────────────────────────────────────────

class _Cell extends StatelessWidget {
  final _Post post;
  final double size;
  final bool isFeatured;
  final void Function(_Post) onTap;

  const _Cell({
    required this.post,
    required this.size,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayUrl = post.isVideo
        ? post.thumbUrl
        : (post.imageUrl.isNotEmpty ? post.imageUrl : post.thumbUrl);
    final badgeIcon = post.isVideo
        ? Icons.play_arrow_rounded
        : (post.isMulti ? Icons.collections_rounded : null);
    final badgeSize = isFeatured ? 20.0 : 16.0;

    return GestureDetector(
      onTapDown: post.isVideo && post.videoUrl.isNotEmpty
          ? (_) => ExploreReelPrefetch.instance.start(
                postId: post.id,
                videoUrl: post.videoUrl,
                fallbackUrl: post.fallbackVideoUrl,
              )
          : null,
      onTap: () => onTap(post),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            displayUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: displayUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _Shimmer(width: size, height: size),
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFDDDDDD)),
                  )
                : _Shimmer(width: size, height: size),

            // Featured tile: subtle bottom gradient + like/comment count
            if (isFeatured && (post.likeCount > 0 || post.commentCount > 0)) ...[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10, bottom: 10,
                child: Row(children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text(_fmtCount(post.likeCount),
                    style: const TextStyle(color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
                  if (post.commentCount > 0) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.chat_bubble, color: Colors.white, size: 13),
                    const SizedBox(width: 3),
                    Text(_fmtCount(post.commentCount),
                      style: const TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
                  ],
                ]),
              ),
            ],

            // Badge top-right
            if (badgeIcon != null)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(badgeIcon, color: Colors.white, size: badgeSize),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Reel UI helpers (display-only, no post/data logic changes) ───────────────

const List<Shadow> _kReelTextShadow = [
  Shadow(blurRadius: 6, color: Colors.black54, offset: Offset(0, 1)),
];

class _ReelUserLookup {
  static final Map<String, Future<({String name, String photo})>> _cache = {};

  static Future<({String name, String photo})> load(String userId) {
    if (userId.isEmpty) {
      return Future.value((name: '', photo: ''));
    }
    return _cache.putIfAbsent(userId, () async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final d = snap.data();
        if (d == null) return (name: '', photo: '');
        final name = (d['username'] ?? d['displayName'] ?? d['name'] ?? '')
            .toString()
            .trim();
        for (final k in ['profilePhoto', 'photoURL', 'profile_photo', 'avatar']) {
          final v = (d[k] ?? '').toString().trim();
          if (v.isNotEmpty) return (name: name, photo: v);
        }
        return (name: name, photo: '');
      } catch (_) {
        return (name: '', photo: '');
      }
    });
  }
}

class _ReelCircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ReelCircleIconBtn({
    required this.icon,
    required this.onTap,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

/// Full-screen poster behind the player — avoids a black flash before first frame.
class _ReelPoster extends StatelessWidget {
  final String posterUrl;
  final bool showLoading;

  const _ReelPoster({
    required this.posterUrl,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (posterUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => _ReelPosterFallback(loading: true),
        errorWidget: (_, __, ___) => _ReelPosterFallback(loading: showLoading),
      );
    }
    return _ReelPosterFallback(loading: showLoading);
  }
}

class _ReelPosterFallback extends StatelessWidget {
  final bool loading;

  const _ReelPosterFallback({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1C1C1E),
      child: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            )
          : const Center(
              child: Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white38, size: 56),
            ),
    );
  }
}

class _ReelAuthorStrip extends StatelessWidget {
  final String userId;
  final String fallbackUsername;
  final String? currentUid;

  const _ReelAuthorStrip({
    required this.userId,
    required this.fallbackUsername,
    this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty && fallbackUsername.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<({String name, String photo})>(
      future: _ReelUserLookup.load(userId),
      builder: (context, snap) {
        final meta = snap.data;
        final name = fallbackUsername.isNotEmpty
            ? fallbackUsername
            : (meta?.name.isNotEmpty == true ? meta!.name : 'User');
        final photo = meta?.photo ?? '';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage:
                    photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
                child: photo.isEmpty
                    ? const Icon(Icons.person, color: Colors.white70, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name.startsWith('@') ? name : '@$name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  shadows: _kReelTextShadow,
                ),
              ),
            ),
            if (userId.isNotEmpty && userId != currentUid) ...[
              const SizedBox(width: 10),
              _FollowBtn(targetUserId: userId),
            ],
          ],
        );
      },
    );
  }
}

class _ReelCaption extends StatefulWidget {
  final String caption;
  const _ReelCaption({required this.caption});

  @override
  State<_ReelCaption> createState() => _ReelCaptionState();
}

class _ReelCaptionState extends State<_ReelCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.caption.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 180),
        crossFadeState:
            _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.35,
              shadows: _kReelTextShadow,
            ),
            children: [
              TextSpan(text: text),
              if (text.length > 64)
                const TextSpan(
                  text: ' …more',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        secondChild: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.35,
              shadows: _kReelTextShadow,
            ),
            children: [
              TextSpan(text: text),
              const TextSpan(
                text: '  less',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelMusicChip extends StatelessWidget {
  const _ReelMusicChip();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white38),
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Original audio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              shadows: _kReelTextShadow,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReelThinProgress extends StatelessWidget {
  final VideoPlayerController controller;
  const _ReelThinProgress({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final duration = value.duration.inMilliseconds;
        final position = value.position.inMilliseconds;
        final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
        return ClipRRect(
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      },
    );
  }
}

/// Fires [onSurfaceReady] after the platform video surface is in the tree.
/// iOS/Android decoders often ignore [VideoPlayerController.play] until then.
class _MountedVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onSurfaceReady;

  const _MountedVideoPlayer({
    required this.controller,
    this.onSurfaceReady,
  });

  @override
  State<_MountedVideoPlayer> createState() => _MountedVideoPlayerState();
}

class _MountedVideoPlayerState extends State<_MountedVideoPlayer> {
  @override
  void initState() {
    super.initState();
    _notifySurfaceReady();
  }

  @override
  void didUpdateWidget(_MountedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _notifySurfaceReady();
    }
  }

  void _notifySurfaceReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSurfaceReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width > 0 ? c.value.size.width : 1080,
        height: c.value.size.height > 0 ? c.value.size.height : 1920,
        child: VideoPlayer(c),
      ),
    );
  }
}

// ─── Reel viewer ─────────────────────────────────────────────────────────────

class _ReelViewer extends StatefulWidget {
  final List<_Post> posts;
  final int initialIndex;
  const _ReelViewer({required this.posts, required this.initialIndex});
  @override
  State<_ReelViewer> createState() => _ReelViewerState();
}

class _ReelViewerState extends State<_ReelViewer> {
  static const String _kExploreOwner = 'explore_reel_viewer';

  late PageController _pc;
  int _page = 0;
  final Map<int, VideoPlayerController> _ctrls = {};
  final Set<int> _initing = {};
  final Set<int> _surfacesReady = {};
  bool _syncing = false;

  late final void Function() _memoryEvictOldest;
  late final void Function() _memoryDisposeAll;
  late final int Function() _memoryCount;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _pc = PageController(initialPage: _page);
    _memoryEvictOldest = _onMemoryEvictOldest;
    _memoryDisposeAll = _onMemoryDisposeAll;
    _memoryCount = () => _ctrls.length;
    VideoPoolCoordinator.instance.registerEvictOldest(_memoryEvictOldest);
    VideoPoolCoordinator.instance.registerDisposeAll(_memoryDisposeAll);
    VideoPoolCoordinator.instance.registerCount(_memoryCount);
    AppVideoFocus.instance.enterFullscreenReel();
    _bootstrapFromPrefetchOrSync();
  }

  void _bootstrapFromPrefetchOrSync() {
    final post = widget.posts[_page];
    final adopted = ExploreReelPrefetch.instance.take(post.id);
    if (adopted != null) {
      _ctrls[_page] = adopted;
      if (adopted.value.isInitialized) {
        _initing.remove(_page);
        if (mounted) setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensurePlaying(_page);
        });
      } else {
        _initing.add(_page);
        adopted.addListener(_onPrefetchReady);
        if (mounted) setState(() {});
      }
      unawaited(_syncWarmNeighbors());
      return;
    }
    unawaited(_sync());
  }

  Future<void> _initCurrentReel() async {
    if (!mounted) return;
    final current = _page;
    if (_ctrls.containsKey(current) || _initing.contains(current)) return;
    final post = widget.posts[current];
    if (post.videoUrl.isEmpty) return;
    if (!VideoDecoderBudget.instance.tryAcquire(_kExploreOwner)) return;
    _initing.add(current);
    if (mounted) setState(() {});
    await _initCtrl(current, post, true);
  }

  void _onSurfaceReady(int idx) {
    _surfacesReady.add(idx);
    if (idx == _page) {
      _ensurePlaying(idx);
    }
  }

  void _ensurePlaying(int idx) {
    Future<void> attempt() async {
      if (!mounted || _page != idx) return;
      final c = _ctrls[idx];
      if (c == null || !c.value.isInitialized || c.value.hasError) return;
      if (!_surfacesReady.contains(idx)) return;
      try {
        await c.setVolume(1.0);
        if (!c.value.isPlaying) {
          await c.play();
        }
      } catch (_) {}
    }

    unawaited(attempt());
    Future.delayed(const Duration(milliseconds: 50), () => unawaited(attempt()));
  }

  void _onPrefetchReady() {
    if (!mounted) return;
    final c = _ctrls[_page];
    if (c == null || !c.value.isInitialized) return;
    c.removeListener(_onPrefetchReady);
    _initing.remove(_page);
    if (mounted) setState(() {});
    _ensurePlaying(_page);
  }

  @override
  void dispose() {
    VideoPoolCoordinator.instance.unregisterEvictOldest(_memoryEvictOldest);
    VideoPoolCoordinator.instance.unregisterDisposeAll(_memoryDisposeAll);
    VideoPoolCoordinator.instance.unregisterCount(_memoryCount);
    AppVideoFocus.instance.exitFullscreenReel();
    unawaited(ExploreReelPrefetch.instance.cancel());
    _pc.dispose();
    for (final c in _ctrls.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _ctrls.clear();
    VideoDecoderBudget.instance.releaseAll(_kExploreOwner);
    super.dispose();
  }

  void _onMemoryEvictOldest() {
    if (!mounted || _ctrls.length <= 1) return;
    int? victim;
    var maxDist = -1;
    for (final idx in _ctrls.keys) {
      if (idx == _page) continue;
      final dist = (idx - _page).abs();
      if (dist > maxDist) {
        maxDist = dist;
        victim = idx;
      }
    }
    if (victim != null) unawaited(_disposeIndex(victim));
  }

  void _onMemoryDisposeAll() {
    if (!mounted) return;
    for (final idx in _ctrls.keys.where((k) => k != _page).toList()) {
      unawaited(_disposeIndex(idx));
    }
  }

  Future<void> _disposeIndex(int idx) async {
    final c = _ctrls.remove(idx);
    _initing.remove(idx);
    _surfacesReady.remove(idx);
    if (c == null) return;
    await VideoDisposeSerial.instance.run(() async {
      try {
        await c.dispose();
      } catch (_) {}
      VideoDecoderBudget.instance.release(_kExploreOwner);
    });
    if (mounted) setState(() {});
  }

  Future<void> _evictOutside(Set<int> keep) async {
    for (final idx in _ctrls.keys.where((k) => !keep.contains(k)).toList()) {
      await _disposeIndex(idx);
    }
  }

  /// Load current reel first (fast start), then neighbors in background.
  Future<void> _sync() async {
    if (!mounted || _syncing) return;
    _syncing = true;
    try {
      // Start current reel immediately — don't block on eviction first.
      if (!_ctrls.containsKey(_page) && !_initing.contains(_page)) {
        await _initCurrentReel();
      }

      final keep = ReelPreloadPolicy.warmIndices(_page, widget.posts.length);
      await _evictOutside(keep);

      final current = _page;
      if (!_ctrls.containsKey(current) && !_initing.contains(current)) {
        final post = widget.posts[current];
        if (post.videoUrl.isNotEmpty) {
          final adopted = ExploreReelPrefetch.instance.take(post.id);
          if (adopted != null) {
            _ctrls[current] = adopted;
            if (adopted.value.isInitialized) {
              _initing.remove(current);
              _ensurePlaying(current);
            } else {
              _initing.add(current);
              adopted.addListener(_onPrefetchReady);
            }
          } else if (VideoDecoderBudget.instance.tryAcquire(_kExploreOwner)) {
            _initing.add(current);
            if (mounted) setState(() {});
            await _initCtrl(current, post, true);
          }
        }
      }

      _applyPlayback();
      if (mounted) setState(() {});
    } finally {
      _syncing = false;
    }
    unawaited(_syncWarmNeighbors());
  }

  Future<void> _syncWarmNeighbors() async {
    if (!mounted) return;
    if (VideoPoolCoordinator.instance.pauseNewPreloads) return;
    final keep = ReelPreloadPolicy.warmIndices(_page, widget.posts.length);
    for (final idx in ReelPreloadPolicy.initOrder(_page, widget.posts.length)) {
      if (!mounted) break;
      if (idx == _page) continue;
      if (!keep.contains(idx)) continue;
      if (_ctrls.containsKey(idx) || _initing.contains(idx)) continue;
      if (_ctrls.length + _initing.length >= ReelPreloadPolicy.maxWarmSlots) {
        break;
      }
      final post = widget.posts[idx];
      if (post.videoUrl.isEmpty) continue;
      if (!VideoDecoderBudget.instance.tryAcquire(_kExploreOwner)) break;
      _initing.add(idx);
      if (mounted) setState(() {});
      await _initCtrl(idx, post, false);
    }
    _applyPlayback();
    if (mounted) setState(() {});
  }

  Future<void> _initCtrl(int idx, _Post post, bool active) async {
    var url = post.videoUrl.trim();
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        VideoDecoderBudget.instance.release(_kExploreOwner);
        return;
      }
      await c.setLooping(true);
      _ctrls[idx] = c;
      if (active) {
        await c.setVolume(1.0);
        await c.play();
      } else {
        await c.setVolume(0.0);
        await c.pause();
      }
    } catch (_) {
      final alt = post.fallbackVideoUrl.trim();
      if (alt.isNotEmpty && alt != url) {
        try {
          await c.dispose();
        } catch (_) {}
        url = alt;
        final c2 = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
          httpHeaders: const {'Connection': 'keep-alive'},
        );
        try {
          await c2.initialize();
          if (!mounted) {
            await c2.dispose();
            VideoDecoderBudget.instance.release(_kExploreOwner);
            return;
          }
          await c2.setLooping(true);
          _ctrls[idx] = c2;
          if (active) {
            await c2.setVolume(1.0);
            await c2.play();
          } else {
            await c2.setVolume(0.0);
            await c2.pause();
          }
        } catch (_) {
          try {
            await c2.dispose();
          } catch (_) {}
          VideoDecoderBudget.instance.release(_kExploreOwner);
        }
      } else {
        try {
          await c.dispose();
        } catch (_) {}
        VideoDecoderBudget.instance.release(_kExploreOwner);
      }
    } finally {
      _initing.remove(idx);
      if (mounted) setState(() {});
      if (active) _ensurePlaying(idx);
    }
  }

  void _applyPlayback() {
    for (final e in _ctrls.entries) {
      try {
        final active = e.key == _page;
        if (active) {
          e.value.setVolume(1.0);
          if (_surfacesReady.contains(e.key) && !e.value.value.isPlaying) {
            e.value.play();
          }
        } else {
          e.value.setVolume(0.0);
          if (e.value.value.isPlaying) e.value.pause();
        }
      } catch (_) {}
    }
    _ensurePlaying(_page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            itemCount: widget.posts.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _applyPlayback();
              unawaited(_sync());
            },
            itemBuilder: (_, i) {
              final post = widget.posts[i];
              final c = _ctrls[i];
              final ready = c != null && c.value.isInitialized;
              return _ReelPage(
                key: ValueKey(post.id),
                post: post,
                isActive: i == _page,
                preloadSurface: i == _page || i == _page + 1,
                ctrl: c,
                ready: ready,
                loading: _initing.contains(i),
                onSurfaceReady: () => _onSurfaceReady(i),
              );
            },
          ),
          // Top-left back to Explore grid (no title)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Align(
                alignment: Alignment.topLeft,
                child: _ReelCircleIconBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single reel page ────────────────────────────────────────────────────────

class _ReelPage extends StatefulWidget {
  final _Post post;
  final bool isActive;
  final bool preloadSurface;
  final VideoPlayerController? ctrl;
  final bool ready;
  final bool loading;
  final VoidCallback? onSurfaceReady;
  const _ReelPage({
    super.key,
    required this.post,
    required this.isActive,
    this.preloadSurface = false,
    required this.ctrl,
    required this.ready,
    required this.loading,
    this.onSurfaceReady,
  });
  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  bool _userPaused = false;
  bool _showHeart = false;
  bool _muted = false;
  bool _hidePoster = false;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _syncPosterVisibility();
    _attachVideoListener();
  }

  @override
  void dispose() {
    _detachVideoListener(widget.ctrl);
    super.dispose();
  }

  void _attachVideoListener() {
    widget.ctrl?.addListener(_onVideoTick);
  }

  void _detachVideoListener(VideoPlayerController? c) {
    c?.removeListener(_onVideoTick);
  }

  void _syncPosterVisibility() {
    final c = widget.ctrl;
    if (c == null || !c.value.isInitialized) {
      _hidePoster = false;
      return;
    }
    _hidePoster = _hasVisibleFrame(c.value);
  }

  bool _hasVisibleFrame(VideoPlayerValue v) {
    if (v.hasError || !v.isInitialized) return false;
    // Only hide poster once decoded frames are actually advancing.
    return v.position > const Duration(milliseconds: 50);
  }

  void _onVideoTick() {
    if (!_hidePoster && mounted) {
      final c = widget.ctrl;
      if (c != null &&
          c.value.isInitialized &&
          !c.value.hasError &&
          _hasVisibleFrame(c.value)) {
        setState(() => _hidePoster = true);
      }
    }
  }

  @override
  void didUpdateWidget(_ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ctrl != widget.ctrl) {
      _detachVideoListener(oldWidget.ctrl);
      _hidePoster = false;
      _attachVideoListener();
      _syncPosterVisibility();
    } else if (!widget.ready && oldWidget.ready) {
      _hidePoster = false;
    } else if (widget.ready && !_hidePoster) {
      _syncPosterVisibility();
    }
    if (widget.isActive && !oldWidget.isActive) {
      _userPaused = false;
      _muted = false;
      final c = widget.ctrl;
      if (c != null && c.value.isInitialized) {
        try {
          c.setVolume(1.0);
        } catch (_) {}
      }
      if (widget.ready && widget.onSurfaceReady != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive) widget.onSurfaceReady!();
        });
      }
    }
    if (widget.ready && !oldWidget.ready && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) widget.onSurfaceReady?.call();
      });
    }
  }

  void _toggleMute() {
    if (!widget.isActive) return;
    final c = widget.ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      _muted = !_muted;
      try {
        c.setVolume(_muted ? 0.0 : 1.0);
      } catch (_) {}
    });
  }

  void _onTap() {
    if (!widget.isActive) return;
    final c = widget.ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _userPaused = true;
      } else {
        c.play();
        _userPaused = false;
      }
    });
  }

  Future<void> _doubleTapLike() async {
    if (_uid == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
    try {
      await FirebaseFirestore.instance
          .collection('posts').doc(widget.post.id)
          .collection('likes').doc(_uid)
          .set({'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('posts').doc(widget.post.id)
        .collection('likes').doc(_uid);
    final doc = await ref.get();
    doc.exists ? await ref.delete()
               : await ref.set({'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ctrl;
    final post = widget.post;
    final ready = widget.ready;
    final loading = widget.loading;
    final posterUrl = _posterUrlFor(post);
    final showVideo = ready &&
        c != null &&
        c.value.isInitialized &&
        (widget.isActive || widget.preloadSurface);

    return GestureDetector(
      onTap: _onTap,
      onDoubleTap: _doubleTapLike,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Neutral base — never pure black while loading
          const ColoredBox(color: Color(0xFF1C1C1E)),

          // Video sits under the poster until decoded frames are visible
          if (showVideo)
            _MountedVideoPlayer(
              controller: c,
              onSurfaceReady: widget.onSurfaceReady,
            ),

          // Thumbnail stays on top until playback has real frames
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hidePoster ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _ReelPoster(
                  posterUrl: posterUrl,
                  showLoading: (loading || !ready) && !_hidePoster,
                ),
              ),
            ),
          ),

          if (loading || (ready && c != null && c.value.isBuffering))
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                minHeight: 2,
              ),
            ),

          if (widget.isActive && ready && c != null && _userPaused)
            Center(
              child: AnimatedOpacity(
                opacity: _userPaused ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
            ),

          // Bottom gradient for caption legibility (Instagram-style)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.82),
                    ],
                    stops: const [0.45, 0.72, 1],
                  ),
                ),
              ),
            ),
          ),

          if (_showHeart)
            Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_showHeart),
                tween: Tween(begin: 0.6, end: 1.15),
                duration: const Duration(milliseconds: 320),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 96,
                  shadows: [Shadow(blurRadius: 20, color: Colors.black54)],
                ),
              ),
            ),

          // Mute toggle — top-right overlay
          if (widget.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 52,
              right: 14,
              child: _ReelCircleIconBtn(
                icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 20,
                onTap: _toggleMute,
              ),
            ),

          // ── LEFT: avatar + username + follow + caption + audio chip ───────
          Positioned(
            left: 14,
            right: 72,
            bottom: MediaQuery.of(context).padding.bottom + 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ReelAuthorStrip(
                  userId: post.userId,
                  fallbackUsername: post.username,
                  currentUid: _uid,
                ),
                if (post.caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ReelCaption(caption: post.caption),
                ],
                const SizedBox(height: 10),
                const _ReelMusicChip(),
              ],
            ),
          ),

          // ── RIGHT: action rail (Instagram-style) ──────────────────────────
          Positioned(
            right: 10,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (post.userId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: FutureBuilder<({String name, String photo})>(
                      future: _ReelUserLookup.load(post.userId),
                      builder: (_, snap) {
                        final photo = snap.data?.photo ?? '';
                        return Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            backgroundImage: photo.isNotEmpty
                                ? CachedNetworkImageProvider(photo)
                                : null,
                            child: photo.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white70, size: 20)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                _SideBtn(
                  icon: StreamBuilder<DocumentSnapshot>(
                    stream: _uid != null
                        ? FirebaseFirestore.instance
                            .collection('posts')
                            .doc(post.id)
                            .collection('likes')
                            .doc(_uid!)
                            .snapshots()
                        : const Stream.empty(),
                    builder: (_, snap) {
                      final liked = snap.data?.exists ?? false;
                      return Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? const Color(0xFFED4956) : Colors.white,
                        size: 32,
                      );
                    },
                  ),
                  label: post.likeCount > 0 ? _fmtN(post.likeCount) : '',
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 20),
                _SideBtn(
                  icon: const Icon(Icons.mode_comment_outlined,
                      color: Colors.white, size: 30),
                  label: post.commentCount > 0 ? _fmtN(post.commentCount) : '',
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _SideBtn(
                  icon: Transform.rotate(
                    angle: -0.35,
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 28),
                  ),
                  label: '',
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _SideBtn(
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: Colors.white, size: 30),
                  label: '',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Thin progress bar at the very bottom
          if (widget.isActive && ready && c != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ReelThinProgress(controller: c),
            ),
        ],
      ),
    );
  }
}

// ─── Shared side-button widget ───────────────────────────────────────────────

class _SideBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _SideBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: _kReelTextShadow,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Follow button ────────────────────────────────────────────────────────────

class _FollowBtn extends StatefulWidget {
  final String targetUserId;
  const _FollowBtn({required this.targetUserId});
  @override
  State<_FollowBtn> createState() => _FollowBtnState();
}

class _FollowBtnState extends State<_FollowBtn> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _following = false;
  bool _checking  = true;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    if (_uid == null) { setState(() => _checking = false); return; }
    try {
      final snap = await FirebaseFirestore.instance.collection('follows')
          .where('followerId',  isEqualTo: _uid)
          .where('followingId', isEqualTo: widget.targetUserId)
          .limit(1).get();
      if (mounted) setState(() { _following = snap.docs.isNotEmpty; _checking = false; });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _toggle() async {
    if (_uid == null) return;
    final next = !_following;
    setState(() => _following = next);
    try {
      final col = FirebaseFirestore.instance.collection('follows');
      if (next) {
        await col.add({
          'followerId': _uid,
          'followingId': widget.targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final snap = await col
            .where('followerId',  isEqualTo: _uid)
            .where('followingId', isEqualTo: widget.targetUserId)
            .limit(1).get();
        for (final d in snap.docs) await d.reference.delete();
      }
    } catch (_) {
      if (mounted) setState(() => _following = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _toggle,
      child: _following
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 1.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Following',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Follow',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

// ─── Format number helper ─────────────────────────────────────────────────────

String _fmtN(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ─── Image detail ─────────────────────────────────────────────────────────────

class _ImageDetail extends StatelessWidget {
  final _Post post;
  const _ImageDetail({required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: post.imageUrl.isNotEmpty ? post.imageUrl : post.thumbUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: _kAccent)),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 64),
          ),
        ),
      ),
    );
  }
}

// ─── Error / empty states ─────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Could not load posts', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasQuery;
  const _EmptyView({required this.hasQuery});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'No results found' : 'Nothing to explore yet',
            style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
