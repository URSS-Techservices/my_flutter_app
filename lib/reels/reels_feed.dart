import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:halo/services/reel_service.dart';
import 'package:halo/services/video_decoder_budget.dart';
import 'package:halo/services/video_playback_resolver.dart';
import 'package:halo/services/video_transcode_queue_service.dart';

class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  final ReelService _reelService = ReelService();
  final PageController _pageController = PageController();
  // MTK devices hit MediaCodec resource limits quickly (resources:6). Keep
  // this conservative for stability.
  static const int _kMaxLiveControllers = 2;
  int _currentPage = 0;
  String _reelsSignature = '';
  List<String> _reelIds = const [];

  final Map<String, VideoPlayerController> _controllers = {};
  final Set<String> _initializing = {};
  final Set<String> _errors = {};
  static const String _budgetOwner = 'reels_feed';
  Future<void> _pendingDispose = Future<void>.value();

  @override
  void dispose() {
    VideoDecoderBudget.instance.releaseAll(_budgetOwner);
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  String _playbackUrl(Map<String, dynamic> data) {
    final media = <String, dynamic>{
      'type': 'video',
      'videoUrl': (data['videoUrl'] ?? data['url'] ?? data['mediaUrl'] ?? '')
          .toString()
          .trim(),
      'url': (data['url'] ?? data['videoUrl'] ?? '').toString().trim(),
      'hlsUrl': (data['hlsUrl'] ?? '').toString().trim(),
      'rawVideoUrl': (data['rawVideoUrl'] ?? '').toString().trim(),
      'previewUrl': (data['previewUrl'] ?? '').toString().trim(),
      'processed': data['processed'] == true,
      'processing': data['processing'] == true,
      if (data['qualities'] is Map)
        'qualities': Map<String, dynamic>.from(data['qualities'] as Map),
      if ((data['transcodeError'] ?? '').toString().trim().isNotEmpty)
        'transcodeError': (data['transcodeError']).toString().trim(),
      if ((data['transcodeErrorCategory'] ?? '').toString().trim().isNotEmpty)
        'transcodeErrorCategory':
            (data['transcodeErrorCategory']).toString().trim(),
    };

    final playback = resolveReelPlayback(postData: data, mediaItem: media);
    if (playback.status == ReelStatus.failedTranscode) return '';
    if (playback.primaryUrl.isNotEmpty) return playback.primaryUrl;

    // When resolver says "processing/no URL", try explicit short preview.
    final preview = (data['previewUrl'] ?? '').toString().trim();
    if (preview.isNotEmpty) return preview;

    return playback.fallbackUrl;
  }

  String? get _activeReelId {
    if (_currentPage < 0 || _currentPage >= _reelIds.length) return null;
    return _reelIds[_currentPage];
  }

  Set<int> _windowIndices(int len) {
    final keep = <int>{};
    for (final i in [
      _currentPage, // current
      _currentPage + 1, // next
    ]) {
      if (i >= 0 && i < len) keep.add(i);
    }
    return keep;
  }

  Future<void> _ensureController(
    int index,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reels,
  ) async {
    if (!mounted || index < 0 || index >= reels.length) return;
    final reelId = reels[index].id;
    if (_controllers.containsKey(reelId) || _initializing.contains(reelId)) {
      return;
    }
    // Safety valve against decoder stampede under rapid swipes/stream updates.
    if (_controllers.length + _initializing.length >= _kMaxLiveControllers) {
      return;
    }
    await _pendingDispose;
    if (!VideoDecoderBudget.instance.tryAcquire(_budgetOwner)) return;

    final docData = reels[index].data();
    final url = _playbackUrl(docData);
    if (url.isEmpty) {
      _errors.add(reelId);
      final media = <String, dynamic>{
        'type': 'video',
        'videoUrl':
            (docData['videoUrl'] ?? docData['url'] ?? docData['mediaUrl'] ?? '')
                .toString()
                .trim(),
        'url': (docData['url'] ?? docData['videoUrl'] ?? '').toString().trim(),
        'hlsUrl': (docData['hlsUrl'] ?? '').toString().trim(),
        'rawVideoUrl': (docData['rawVideoUrl'] ?? '').toString().trim(),
        'previewUrl': (docData['previewUrl'] ?? '').toString().trim(),
        'processed': docData['processed'] == true,
        'processing': docData['processing'] == true,
      };
      final playback = resolveReelPlayback(postData: docData, mediaItem: media);
      unawaited(
        VideoTranscodeQueueService.instance.maybeRequestReelTranscode(
          reelId: reelId,
          playback: playback,
        ),
      );
      if (mounted && reelId == _activeReelId) setState(() {});
      return;
    }

    _initializing.add(reelId);
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: const VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: const {'Connection': 'keep-alive'},
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      if (index == _currentPage) {
        await ctrl.setVolume(1.0);
        await ctrl.play();
      } else {
        await ctrl.setVolume(0.0);
        await ctrl.pause();
      }
      _controllers[reelId] = ctrl;
      _errors.remove(reelId);
    } catch (_) {
      VideoDecoderBudget.instance.release(_budgetOwner);
      _errors.add(reelId);
    } finally {
      _initializing.remove(reelId);
      // Avoid global rebuild churn while preloading non-active reels.
      if (mounted && reelId == _activeReelId) setState(() {});
    }
  }

  Future<void> _syncControllerWindow(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reels,
  ) async {
    if (!mounted || reels.isEmpty) return;
    final keep = _windowIndices(reels.length);

    // Dispose controllers more than 2 positions away.
    final keepIds = keep.map((i) => reels[i].id).toSet();
    final toDispose =
        _controllers.keys.where((id) => !keepIds.contains(id)).toList();
    for (final id in toDispose) {
      final c = _controllers.remove(id);
      _errors.remove(id);
      _initializing.remove(id);
      if (c == null) continue;
      _pendingDispose = _pendingDispose.then((_) async {
        await c.dispose();
        VideoDecoderBudget.instance.release(_budgetOwner);
      });
    }
    await _pendingDispose;

    for (final i in keep) {
      unawaited(_ensureController(i, reels));
    }
    _applyPlaybackState();
  }

  Future<void> _applyPlaybackState() async {
    final activeId = _activeReelId;
    for (final entry in _controllers.entries) {
      final ctrl = entry.value;
      try {
        if (activeId != null && entry.key == activeId) {
          await ctrl.setVolume(1.0);
          if (!ctrl.value.isPlaying) await ctrl.play();
        } else {
          await ctrl.setVolume(0.0);
          if (ctrl.value.isPlaying) await ctrl.pause();
        }
      } catch (_) {
        // Controller might be disposing; ignore.
      }
    }
  }

  void _handleReelsChanged(List<QueryDocumentSnapshot<Map<String, dynamic>>> reels) {
    final ids = reels.map((d) => d.id).toList(growable: false);
    final signature = ids.join('|');
    if (signature == _reelsSignature) return;
    _reelsSignature = signature;
    _reelIds = ids;
    if (_currentPage >= reels.length) {
      _currentPage = reels.isEmpty ? 0 : reels.length - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_syncControllerWindow(reels));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _reelService.getRankedReelsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)),
            );
          }

          final reels = snapshot.data ?? [];
          _handleReelsChanged(reels);
          if (reels.isEmpty) {
            return const Center(
              child: Text('No reels yet',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              unawaited(_syncControllerWindow(reels));
            },
            itemBuilder: (context, index) {
              final doc = reels[index];
              final data = doc.data();
              final videoUrl = _playbackUrl(data);
              final caption = (data['caption'] ?? '').toString();
              final userId = (data['userId'] ?? '').toString();
              final username = (data['username'] ??
                      data['userName'] ??
                      data['displayName'] ??
                      data['name'] ??
                      'User')
                  .toString()
                  .trim();

              return _ReelPage(
                reelId: doc.id,
                videoUrl: videoUrl,
                caption: caption,
                userId: userId,
                data: data,
                isActive: index == _currentPage,
                controller: _controllers[doc.id],
                isInitializing: _initializing.contains(doc.id),
                hasError: _errors.contains(doc.id),
                username: username.isEmpty ? 'User' : username,
                onRetry: () {
                  _errors.remove(doc.id);
                  unawaited(_ensureController(index, reels));
                  if (mounted) setState(() {});
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  final String reelId;
  final String videoUrl;
  final String caption;
  final String userId;
  final Map<String, dynamic> data;
  final bool isActive;
  final VideoPlayerController? controller;
  final bool isInitializing;
  final bool hasError;
  final VoidCallback onRetry;
  final String? username;

  const _ReelPage({
    required this.reelId,
    required this.videoUrl,
    required this.caption,
    required this.userId,
    required this.data,
    required this.isActive,
    required this.controller,
    required this.isInitializing,
    required this.hasError,
    required this.onRetry,
    required this.username,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.videoUrl.isNotEmpty)
          _ReelVideoPlayer(
            controller: widget.controller,
            isActive: widget.isActive,
            isInitializing: widget.isInitializing,
            hasError: widget.hasError,
            onRetry: widget.onRetry,
          )
        else
          const Center(
            child: Icon(Icons.videocam_off, color: Colors.white38, size: 64),
          ),

        // Gradient overlay for readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 64,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.userId.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '@${(widget.username ?? 'User')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                    ),
                  ],
                ),
              if (widget.caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Side actions
        Positioned(
          right: 12,
          bottom: 100,
          child: _ReelSideActions(
            reelId: widget.reelId,
            data: widget.data,
          ),
        ),
      ],
    );
  }
}

class _ReelSideActions extends StatelessWidget {
  final String reelId;
  final Map<String, dynamic> data;

  const _ReelSideActions({required this.reelId, required this.data});

  @override
  Widget build(BuildContext context) {
    final likes = (data['likes'] ?? 0) as int;
    final comments = (data['comments'] ?? 0) as int;

    return Column(
      children: [
        _SideBtn(icon: Icons.favorite_border, label: '$likes'),
        const SizedBox(height: 16),
        _SideBtn(icon: Icons.chat_bubble_outline, label: '$comments'),
        const SizedBox(height: 16),
        _SideBtn(icon: Icons.send_outlined, label: 'Share'),
      ],
    );
  }
}

class _SideBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SideBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)]),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
      ],
    );
  }
}

class _ReelVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool isActive;
  final bool isInitializing;
  final bool hasError;
  final VoidCallback onRetry;

  const _ReelVideoPlayer({
    required this.controller,
    required this.isActive,
    required this.isInitializing,
    required this.hasError,
    required this.onRetry,
  });

  @override
  State<_ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<_ReelVideoPlayer> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (widget.hasError) {
      return Center(
        child: TextButton(
          onPressed: widget.onRetry,
          child: const Text(
            'Video unavailable · Tap to retry',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }
    if (c == null || !c.value.isInitialized || widget.isInitializing) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white54));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          c.value.isPlaying ? c.pause() : c.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          // Tap-to-pause icon (briefly shown)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (_, val, __) {
              if (val.isPlaying) return const SizedBox.shrink();
              return const Center(
                child: Icon(Icons.play_circle_filled,
                    color: Colors.white70, size: 72),
              );
            },
          ),
          // Progress bar at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFA58CE3),
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white10,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}