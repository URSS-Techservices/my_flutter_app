import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:halo/services/reel_service.dart';
import 'package:halo/services/video_controller_pool.dart' show VideoPoolCoordinator;
import 'package:halo/services/video_decoder_budget.dart';

// ─── constants ───────────────────────────────────────────────────────────────

const Color _kPurple = Color(0xFFA58CE3);
const String _kBudgetOwner = 'reels_feed';

// ─── helpers ─────────────────────────────────────────────────────────────────

String _bestUrl(Map<String, dynamic> d) {
  final hls = (d['hlsUrl'] ?? '').toString().trim();
  if (hls.isNotEmpty) return hls;
  for (final k in ['videoUrl', 'url', 'mediaUrl', 'rawVideoUrl', 'previewUrl']) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

String _bestThumb(Map<String, dynamic> d) {
  for (final k in ['thumbnailUrl', 'previewUrl', 'thumbnail', 'imageUrl']) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

// ═══════════════════════════════════════════════════════════════════════════
// ReelsFeed — vertical paging, Instagram-style
// ═══════════════════════════════════════════════════════════════════════════

class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});
  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  final ReelService _svc = ReelService();
  final PageController _pc = PageController();

  // We keep at most 3 controllers: current + 1 ahead + 1 behind.
  static const int _kWindow = 3;

  int _page = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reels = const [];

  // postId → controller (only controllers inside the window)
  final Map<String, VideoPlayerController> _ctrlMap = {};
  final Set<String> _initializing = {};

  @override
  void initState() {
    super.initState();
    VideoPoolCoordinator.instance.registerEvictOldest(_evictOldestController);
    VideoPoolCoordinator.instance.registerDisposeAll(_disposeAllControllers);
    VideoPoolCoordinator.instance.registerCount(() => _ctrlMap.length);
  }

  void _evictOldestController() {
    if (_ctrlMap.isEmpty) return;
    final oldest = _ctrlMap.keys.first;
    final c = _ctrlMap.remove(oldest);
    _initializing.remove(oldest);
    if (c != null) {
      unawaited(() async {
        try {
          await c.dispose();
        } catch (_) {}
        VideoDecoderBudget.instance.release(_kBudgetOwner);
      }());
    }
  }

  void _disposeAllControllers() {
    _releaseAll();
    _initializing.clear();
  }

  @override
  void dispose() {
    _releaseAll();
    _pc.dispose();
    super.dispose();
  }

  // ── window management ────────────────────────────────────────────────────

  Set<int> _windowIndices(int total) {
    final s = <int>{};
    for (final i in [_page - 1, _page, _page + 1]) {
      if (i >= 0 && i < total) s.add(i);
    }
    return s;
  }

  void _syncWindow() {
    if (!mounted || _reels.isEmpty) return;
    final keep    = _windowIndices(_reels.length);
    final keepIds = keep.map((i) => _reels[i].id).toSet();

    // Dispose controllers outside the window immediately
    for (final id in _ctrlMap.keys.where((id) => !keepIds.contains(id)).toList()) {
      final c = _ctrlMap.remove(id);
      _initializing.remove(id);
      unawaited(() async {
        try { c?.pause(); await c?.dispose(); } catch (_) {}
        VideoDecoderBudget.instance.release(_kBudgetOwner);
      }());
    }

    // Start controllers inside window — current page first so it plays ASAP
    final ordered = [_page, _page + 1, _page - 1]
        .where((i) => i >= 0 && i < _reels.length)
        .toList();
    for (final i in ordered) {
      final doc = _reels[i];
      if (_ctrlMap.containsKey(doc.id) || _initializing.contains(doc.id)) continue;
      if (_ctrlMap.length + _initializing.length >= _kWindow) continue;
      if (!VideoDecoderBudget.instance.tryAcquire(_kBudgetOwner)) continue;
      final url = _bestUrl(doc.data());
      if (url.isEmpty) {
        VideoDecoderBudget.instance.release(_kBudgetOwner);
        continue;
      }
      _initializing.add(doc.id);
      _startController(doc.id, url, i == _page);
    }

    _applyPlayback();
  }

  // ── Non-blocking init via listener — same pattern as _InlineVideoPlayer ──
  // This is why the home screen is fast: we fire initialize() and return
  // immediately. The listener fires as soon as the first frame is decoded.
  void _startController(String id, String url, bool active) {
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false, allowBackgroundPlayback: false),
      httpHeaders: const {'Connection': 'keep-alive'},
    );

    void onUpdate() {
      if (!mounted) return;
      final v = ctrl.value;
      if (v.hasError) {
        ctrl.removeListener(onUpdate);
        ctrl.dispose();
        VideoDecoderBudget.instance.release(_kBudgetOwner);
        _initializing.remove(id);
        if (mounted) setState(() {});
        return;
      }
      if (v.isInitialized && !_ctrlMap.containsKey(id)) {
        ctrl.removeListener(onUpdate);
        ctrl.setLooping(true);
        final isActive = id == _currentId;
        ctrl.setVolume(isActive ? 1.0 : 0.0);
        if (isActive) ctrl.play();
        _ctrlMap[id] = ctrl;
        _initializing.remove(id);
        if (mounted) setState(() {});
      }
    }

    ctrl.addListener(onUpdate);
    // Fire and forget — the listener above handles completion
    ctrl.initialize().catchError((_) {
      ctrl.removeListener(onUpdate);
      ctrl.dispose();
      VideoDecoderBudget.instance.release(_kBudgetOwner);
      _initializing.remove(id);
      if (mounted) setState(() {});
    });
  }

  void _applyPlayback() {
    final active = _currentId;
    for (final e in _ctrlMap.entries) {
      try {
        if (e.key == active) {
          e.value.setVolume(1.0);
          if (!e.value.value.isPlaying) e.value.play();
        } else {
          e.value.setVolume(0.0);
          if (e.value.value.isPlaying) e.value.pause();
        }
      } catch (_) {}
    }
  }

  void _releaseAll() {
    for (final c in _ctrlMap.values) {
      try { c.pause(); c.dispose(); } catch (_) {}
      VideoDecoderBudget.instance.release(_kBudgetOwner);
    }
    _ctrlMap.clear();
    VideoDecoderBudget.instance.releaseAll(_kBudgetOwner);
  }

  String? get _currentId =>
      (_page >= 0 && _page < _reels.length) ? _reels[_page].id : null;

  void _onReels(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final ids    = docs.map((d) => d.id).join('|');
    final curIds = _reels.map((d) => d.id).join('|');
    if (ids == curIds) return;
    _reels = docs;
    if (_page >= docs.length) _page = docs.isEmpty ? 0 : docs.length - 1;
    // No postFrameCallback delay — start immediately so the first reel
    // begins downloading before the first frame even paints.
    _syncWindow();
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _svc.getRankedReelsStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting && _reels.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError) {
            return const Center(child: Text('Could not load reels', style: TextStyle(color: Colors.white54)));
          }
          final docs = snap.data ?? [];
          _onReels(docs);
          if (docs.isEmpty) {
            return const Center(child: Text('No reels yet', style: TextStyle(color: Colors.white54)));
          }
          return PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            itemCount: docs.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _syncWindow();
            },
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data();
              return _ReelItem(
                key: ValueKey(doc.id),
                docId: doc.id,
                data: d,
                isActive: i == _page,
                ctrl: _ctrlMap[doc.id],
                loading: _initializing.contains(doc.id),
                onRetry: () {
                  if (_ctrlMap.containsKey(doc.id)) return;
                  final url = _bestUrl(d);
                  if (url.isEmpty || !VideoDecoderBudget.instance.tryAcquire(_kBudgetOwner)) return;
                  _initializing.add(doc.id);
                  setState(() {});
                  _startController(doc.id, url, i == _page);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Single reel item
// ═══════════════════════════════════════════════════════════════════════════

class _ReelItem extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isActive;
  final VideoPlayerController? ctrl;
  final bool loading;
  final VoidCallback onRetry;

  const _ReelItem({
    super.key,
    required this.docId,
    required this.data,
    required this.isActive,
    required this.ctrl,
    required this.loading,
    required this.onRetry,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  bool _paused    = false;
  bool _showHeart = false;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (!old.isActive && widget.isActive && _paused) _paused = false;
  }

  void _onTap() {
    final c = widget.ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      if (c.value.isPlaying) { c.pause(); _paused = true; }
      else                    { c.play();  _paused = false; }
    });
  }

  Future<void> _doubleTapLike() async {
    if (_uid == null) return;
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
    try {
      await FirebaseFirestore.instance
          .collection('reels').doc(widget.docId)
          .collection('likes').doc(_uid)
          .set({'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final d        = widget.data;
    final thumb    = _bestThumb(d);
    final caption  = (d['caption'] ?? '').toString().trim();
    final username = (d['username'] ?? d['userName'] ?? d['displayName'] ?? d['name'] ?? '').toString().trim();
    final userId   = (d['userId'] ?? '').toString();
    final likes    = (d['likes'] as int?) ?? 0;
    final comments = (d['comments'] as int?) ?? 0;
    final c        = widget.ctrl;
    final ready    = c != null && c.value.isInitialized;

    return GestureDetector(
      onTap: _onTap,
      onDoubleTap: _doubleTapLike,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail background
          if (thumb.isNotEmpty)
            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black))
          else
            const ColoredBox(color: Colors.black),

          // Video
          if (ready)
            FittedBox(fit: BoxFit.cover,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height,
                child: VideoPlayer(c))),

          // Loading bar at top while video is initialising or buffering
          if (widget.loading || (ready && c.value.isBuffering))
            Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
                minHeight: 2,
              ),
            ),

          // Error
          if (!widget.loading && c == null && _bestUrl(d).isEmpty)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.videocam_off, color: Colors.white38, size: 48),
              TextButton(onPressed: widget.onRetry,
                child: const Text('Tap to retry', style: TextStyle(color: Colors.white70))),
            ])),

          // Double-tap heart
          if (_showHeart)
            Center(child: Icon(Icons.favorite, color: Colors.white, size: 90,
                shadows: const [Shadow(blurRadius: 16, color: Colors.black54)])),

          // Pause icon
          if (ready && _paused)
            const Center(child: Icon(Icons.play_circle_filled, color: Colors.white60, size: 72)),

          // Bottom gradient
          Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.7)],
              stops: const [0, 0.4, 1]))))),

          // Left: username + caption + follow
          Positioned(
            left: 12, right: 80, bottom: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text('@$username',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 15, shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
                  const SizedBox(width: 10),
                  if (userId.isNotEmpty && userId != _uid)
                    _FollowButton(targetUserId: userId),
                ]),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4,
                      shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
                ],
              ]),
          ),

          // Right: like / comment / share
          Positioned(
            right: 12, bottom: 80,
            child: Column(children: [
              _SideAction(
                icon: StreamBuilder<DocumentSnapshot>(
                  stream: _uid != null
                    ? FirebaseFirestore.instance
                        .collection('reels').doc(widget.docId)
                        .collection('likes').doc(_uid!).snapshots()
                    : const Stream.empty(),
                  builder: (_, snap) {
                    final liked = snap.data?.exists ?? false;
                    return Icon(liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? const Color(0xFFED4956) : Colors.white, size: 30);
                  },
                ),
                label: likes > 0 ? _fmt(likes) : '',
                onTap: () async {
                  if (_uid == null) return;
                  final ref = FirebaseFirestore.instance
                      .collection('reels').doc(widget.docId)
                      .collection('likes').doc(_uid);
                  final doc = await ref.get();
                  doc.exists ? await ref.delete()
                             : await ref.set({'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
                },
              ),
              const SizedBox(height: 20),
              _SideAction(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
                label: comments > 0 ? _fmt(comments) : '',
                onTap: () {}, // comments sheet — future feature
              ),
              const SizedBox(height: 20),
              _SideAction(
                icon: const Icon(Icons.send_outlined, color: Colors.white, size: 28),
                label: 'Share',
                onTap: () {},
              ),
            ]),
          ),

          // Progress bar
          if (ready)
            Positioned(left: 0, right: 0, bottom: 0,
              child: VideoProgressIndicator(c, allowScrubbing: false,
                colors: const VideoProgressColors(
                  playedColor: _kPurple, bufferedColor: Colors.white24, backgroundColor: Colors.white12),
                padding: EdgeInsets.zero)),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ─── Side action button (like / comment / share) ─────────────────────────────

class _SideAction extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _SideAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        icon,
        if (label.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
        ],
      ]),
    );
  }
}

// ─── Follow button ────────────────────────────────────────────────────────────

class _FollowButton extends StatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});
  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _following = false;
  bool _loading   = true;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    if (_uid == null) { setState(() => _loading = false); return; }
    final doc = await FirebaseFirestore.instance
        .collection('follows')
        .where('followerId',  isEqualTo: _uid)
        .where('followingId', isEqualTo: widget.targetUserId)
        .limit(1).get();
    if (mounted) setState(() { _following = doc.docs.isNotEmpty; _loading = false; });
  }

  Future<void> _toggle() async {
    if (_uid == null) return;
    setState(() => _following = !_following);
    try {
      final col = FirebaseFirestore.instance.collection('follows');
      if (_following) {
        await col.add({'followerId': _uid, 'followingId': widget.targetUserId,
          'createdAt': FieldValue.serverTimestamp()});
      } else {
        final snap = await col
            .where('followerId',  isEqualTo: _uid)
            .where('followingId', isEqualTo: widget.targetUserId)
            .limit(1).get();
        for (final d in snap.docs) await d.reference.delete();
      }
    } catch (_) {
      if (mounted) setState(() => _following = !_following);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _toggle,
      child: _following
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white60, width: 1.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Following',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              child: const Text('Follow',
                style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700))),
    );
  }
}
