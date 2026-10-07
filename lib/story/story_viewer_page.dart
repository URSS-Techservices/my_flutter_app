import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import '../models/story_model.dart';

class StoryViewerPage extends StatefulWidget {
  final List<StoryModel> stories;

  const StoryViewerPage({super.key, required this.stories});

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  late AnimationController _progressController;
  VideoPlayerController? _videoController;

  int _currentIndex = 0;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  static const Duration _imageDuration = Duration(seconds: 7);

  final List<Widget> _floatingReactions = [];

  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: _imageDuration,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goNext();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markStoriesAsSeen();
      _loadStory(0);
    });
  }

  // ---------------- STORY LOADING ----------------
  Future<void> _loadStory(int index) async {
    if (index >= widget.stories.length) return;

    final story = widget.stories[index];

    _progressController.stop();
    await _videoController?.dispose();
    _videoController = null;

    if (story.mediaType == 'video') {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
      await _videoController!.initialize();
      if (!mounted) return;

      _progressController.duration = _videoController!.value.duration;
      _videoController!.play();
    } else {
      _progressController.duration = _imageDuration;
    }

    _progressController
      ..reset()
      ..forward();

    setState(() {});
  }

  // ---------------- NAVIGATION ----------------
  void _goNext() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.jumpToPage(_currentIndex);
      _loadStory(_currentIndex);
    } else {
      Navigator.pop(context);
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.jumpToPage(_currentIndex);
      _loadStory(_currentIndex);
    }
  }

  // ---------------- PAUSE / RESUME ----------------
  void _pauseStory() {
    _progressController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    _progressController.forward();
    _videoController?.play();
  }

  // ---------------- HELPERS ----------------
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _markStoriesAsSeen() async {
    if (currentUserId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var story in widget.stories) {
      batch.set(
        FirebaseFirestore.instance.collection('stories').doc(story.id),
        {'viewers': FieldValue.arrayUnion([currentUserId])},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  // ---------------- REACTIONS ----------------
  void _sendReaction(String emoji) {
    final key = UniqueKey();

    setState(() {
      _floatingReactions.add(
        _FloatingEmoji(
          key: key,
          emoji: emoji,
          onComplete: () {
            setState(() {
              _floatingReactions.removeWhere((w) => w.key == key);
            });
          },
        ),
      );
    });
  }

  // ---------------- VIEWERS ----------------
  void _openViewers(StoryModel story) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: story.viewers.map((uid) {
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(uid,
                  style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------- DISPOSE ----------------
  @override
  void dispose() {
    _videoController?.dispose();
    _progressController.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          if (_replyFocusNode.hasFocus) return;
          final w = MediaQuery.of(context).size.width;
          details.globalPosition.dx < w / 2
              ? _goPrevious()
              : _goNext();
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onVerticalDragUpdate: (d) {
          if ((d.primaryDelta ?? 0) > 12) Navigator.pop(context);
        },
        child: Stack(
          children: [
            // ---------------- STORY ----------------
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (_, index) {
                final story = widget.stories[index];
                final isCurrent = index == _currentIndex;
                final isVideo = story.mediaType == 'video';

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isVideo &&
                        isCurrent &&
                        _videoController != null &&
                        _videoController!.value.isInitialized)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    else
                      Image.network(story.mediaUrl, fit: BoxFit.cover),

                    // Gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black54,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Header
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 28,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StoryHeaderUsername(
                                userId: story.userId,
                                fallbackUsername: story.username,
                              ),
                              Text(_timeAgo(story.createdAt),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.more_horiz,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Bottom
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 20,
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                _emojiBtn('❤️'),
                                const SizedBox(width: 16),
                                _emojiBtn('🔥'),
                                const SizedBox(width: 16),
                                _emojiBtn('😂'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _replyBar(),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _openViewers(story),
                              child: Text(
                                '${story.viewers.length} views',
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ---------------- PROGRESS ----------------
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (_, __) {
                  return Row(
                    children:
                    List.generate(widget.stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 2),
                          child: LinearProgressIndicator(
                            value: i < _currentIndex
                                ? 1
                                : i == _currentIndex
                                ? _progressController.value
                                : 0,
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor:
                            const AlwaysStoppedAnimation(
                                Colors.white),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

            ..._floatingReactions,
          ],
        ),
      ),
    );
  }

  Widget _emojiBtn(String e) =>
      GestureDetector(onTap: () => _sendReaction(e), child: Text(e, style: const TextStyle(fontSize: 28)));

  Widget _replyBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              focusNode: _replyFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Send message',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
            ),
          ),
          const Icon(Icons.send_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

/// Shows username in story header; fetches from users collection when story has "Unknown".
class _StoryHeaderUsername extends StatelessWidget {
  final String userId;
  final String fallbackUsername;

  const _StoryHeaderUsername({
    required this.userId,
    required this.fallbackUsername,
  });

  @override
  Widget build(BuildContext context) {
    final useFallback = fallbackUsername.isEmpty ||
        fallbackUsername.toLowerCase() == 'unknown' ||
        fallbackUsername == 'User';
    if (!useFallback) {
      return Text(
        fallbackUsername,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userId.isEmpty
          ? null
          : FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String name = fallbackUsername;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          name = (data?['username'] ?? data?['name'] ?? data?['full_name'] ?? data?['business_name'])?.toString().trim() ?? 'User';
        }
        return Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

// ---------------- FLOATING EMOJI ----------------
class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const _FloatingEmoji(
      {super.key, required this.emoji, required this.onComplete});

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120,
      left: MediaQuery.of(context).size.width / 2 - 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: 1 - _c.value,
          child: Transform.translate(
            offset: Offset(0, -120 * _c.value),
            child:
            Text(widget.emoji, style: const TextStyle(fontSize: 32)),
          ),
        ),
      ),
    );
  }
}
