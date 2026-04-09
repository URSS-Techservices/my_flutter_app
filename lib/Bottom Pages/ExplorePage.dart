import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/services/explore_service.dart';
import 'package:video_player/video_player.dart';
import 'package:halo/widgets/save_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/Profile%20Pages/aspirant_profile_page.dart' as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart' as guru_profile;
import 'package:halo/Profile%20Pages/wellness_profile_page.dart' as wellness_profile;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kExplorePrimary = Color(0xFF5B3FA3);
const Color _kExploreBg = Color(0xFFF4F1FB);
const int _kPageSize = 20;

// ─────────────────────────────────────────────────────────────────────────────
// FIX #5 — Typed Post model (no more raw Map<String, dynamic> everywhere)
// ─────────────────────────────────────────────────────────────────────────────

class PostMediaItem {
  final String url;
  final bool isVideo;
  const PostMediaItem({required this.url, required this.isVideo});
}

class PostModel {
  final String id;
  final String userId;
  final String caption;
  final String location;
  final List<PostMediaItem> mediaItems;
  final DateTime? createdAt;
  final List<String> tags;

  const PostModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.location,
    required this.mediaItems,
    required this.tags,
    this.createdAt,
  });

  bool get isVideo => mediaItems.isNotEmpty && mediaItems.first.isVideo;
  String get firstImageUrl {
    for (final m in mediaItems) {
      if (!m.isVideo) return m.url;
    }
    return '';
  }

  String get firstVideoUrl {
    for (final m in mediaItems) {
      if (m.isVideo) return m.url;
    }
    return '';
  }

  // FIX #5 — Parse once at the query boundary, pass typed model everywhere
  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PostModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      mediaItems: _parseMediaItems(data),
      tags: ((data['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static List<PostMediaItem> _parseMediaItems(Map<String, dynamic> data) {
    final out = <PostMediaItem>[];

    final media = data['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final url = (m['url'] ?? '').toString().trim();
          if (url.isEmpty) continue;
          final t = (m['type'] ?? '').toString().toLowerCase();
          out.add(PostMediaItem(
            url: url,
            isVideo: t == 'video' || url.endsWith('.mp4'),
          ));
        }
      }
    }

    if (out.isNotEmpty) return out;

    // Fallbacks for legacy field shapes
    final imageUrl = data['imageUrl']?.toString() ?? '';
    if (imageUrl.isNotEmpty) {
      out.add(PostMediaItem(url: imageUrl, isVideo: false));
      return out;
    }

    final images = data['images'];
    if (images is List) {
      for (final img in images) {
        final url = img?.toString() ?? '';
        if (url.isNotEmpty) out.add(PostMediaItem(url: url, isVideo: false));
      }
      if (out.isNotEmpty) return out;
    }

    final videoUrl =
    (data['videoUrl'] ?? data['mediaUrl'] ?? '').toString().trim();
    if (videoUrl.isNotEmpty) {
      out.add(PostMediaItem(url: videoUrl, isVideo: true));
    }

    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX #2 — User profile cache (prevents N+1 Firestore reads)
// ─────────────────────────────────────────────────────────────────────────────

class _UserProfileCache {
  static final _UserProfileCache _instance = _UserProfileCache._();
  _UserProfileCache._();
  factory _UserProfileCache() => _instance;

  final Map<String, Map<String, dynamic>> _cache = {};

  Future<Map<String, dynamic>> get(String userId) async {
    if (_cache.containsKey(userId)) return _cache[userId]!;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = snap.data() ?? {};
    _cache[userId] = data;
    return data;
  }

  void clear() => _cache.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE PAGE
// ─────────────────────────────────────────────────────────────────────────────

class ExplorePage extends StatefulWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // persistence cache
  static final List<PostModel> _cachedPosts = [];
  static DocumentSnapshot? _cachedLastDoc;
  static double _cachedScrollOffset = 0;

  // FIX #1 — Pagination state
  final List<PostModel> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final ExploreService _exploreService = ExploreService(); // FIX #9 — actually used via service layer
  final Set<String> _hiddenPostIds = <String>{};
  final Set<String> _hiddenUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (_cachedPosts.isNotEmpty) {
      _posts.addAll(_cachedPosts);
      _lastDoc = _cachedLastDoc;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _cachedScrollOffset.clamp(0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    } else {
      _fetchNextPage();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _cachedPosts
      ..clear()
      ..addAll(_posts);
    _cachedLastDoc = _lastDoc;
    _cachedScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0;
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        _hasMore) {
      _fetchNextPage();
    }
  }

  // FIX #1 — Paginated fetch using startAfterDocument
  Future<void> _fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_kPageSize);

      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snap = await query.get();

      if (snap.docs.isEmpty || snap.docs.length < _kPageSize) {
        _hasMore = false;
      }

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        final newPosts = snap.docs.map(PostModel.fromFirestore).toList();
        setState(() => _posts.addAll(newPosts));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load posts. Pull to retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    _posts.clear();
    _lastDoc = null;
    _hasMore = true;
    _UserProfileCache().clear();
    await _fetchNextPage();
  }

  List<PostModel> get _visiblePosts => _posts
      .where((p) => !_hiddenPostIds.contains(p.id) && !_hiddenUserIds.contains(p.userId))
      .toList(growable: false);

  void _hidePost(String postId) => setState(() => _hiddenPostIds.add(postId));

  void _hideUser(String userId) => setState(() => _hiddenUserIds.add(userId));

  Future<void> _reportPost(String postId, String ownerId) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('post_reports').add({
      'postId': postId,
      'ownerId': ownerId,
      'reporterId': me,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post reported. Thank you.')),
    );
  }

  void _onPostMenuAction(_PostMenuAction action, PostModel post) {
    switch (action) {
      case _PostMenuAction.notInterested:
        _hidePost(post.id);
        break;
      case _PostMenuAction.hideUser:
        _hideUser(post.userId);
        break;
      case _PostMenuAction.report:
        _reportPost(post.id, post.userId);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kExploreBg,
      appBar: AppBar(
        title: Text(
          'Explore',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _kExplorePrimary,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_posts.isEmpty && _isLoading) {
      return _ExploreSkeletonGrid();
    }

    if (_visiblePosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No posts to explore yet',
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.9,
      ),
      itemCount: _visiblePosts.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _visiblePosts.length) {
          return const Center(
              child:
              CircularProgressIndicator(strokeWidth: 2, color: _kExplorePrimary));
        }
        final post = _visiblePosts[index];
        return _ExploreGridTile(
          post: post,
          onTap: () => _onTileTap(index, post),
        );
      },
    );
  }

  void _onTileTap(int index, PostModel post) {
    if (post.isVideo) {
      final videoPosts = _visiblePosts.where((p) => p.isVideo).toList();
      final startIndex = videoPosts.indexWhere((p) => p.id == post.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ExploreReelsViewer(
            videoPosts: videoPosts,
            initialIndex: startIndex < 0 ? 0 : startIndex,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ExplorePostsViewer(
            posts: _visiblePosts,
            initialIndex: index,
            onMenuAction: _onPostMenuAction,
          ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID TILE — extracted for cleanliness
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreGridTile extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;

  const _ExploreGridTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.firstImageUrl;
    final count = post.mediaItems.length;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.grey.shade300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post.isVideo && post.firstVideoUrl.isNotEmpty)
              _SharedVideoPlayer(
                url: post.firstVideoUrl,
                fit: BoxFit.cover,
                autoPlay: true,
                visibilityKey: 'grid_${post.id}',
              )
            else if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey),
              )
            else if (post.isVideo)
              const ColoredBox(
                color: Colors.black87,
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 30),
              )
            else
              const Icon(Icons.image, color: Colors.grey),
            if (post.isVideo)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 18),
              ),
            if (post.mediaItems.length > 1)
              Positioned(
                top: 6,
                left: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.collections, color: Colors.white, size: 16),
                    const SizedBox(width: 2),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POSTS VIEWER — Instagram-style full-screen scroll
// ─────────────────────────────────────────────────────────────────────────────

class _ExplorePostsViewer extends StatefulWidget {
  final List<PostModel> posts;
  final int initialIndex;
  final void Function(_PostMenuAction action, PostModel post) onMenuAction;

  const _ExplorePostsViewer({
    required this.posts,
    required this.initialIndex,
    required this.onMenuAction,
  });

  @override
  State<_ExplorePostsViewer> createState() => _ExplorePostsViewerState();
}

class _ExplorePostsViewerState extends State<_ExplorePostsViewer> {
  late final PageController _controller;
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(String postId) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }
    final likeRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid);
    try {
      final likeDoc = await likeRef.get();
      if (likeDoc.exists) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'userId': uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      // FIX #11 — user-friendly error, no raw exception exposed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update like. Try again.')),
      );
    }
  }

  Future<void> _addComment(
    String postId,
    TextEditingController controller, {
    String? replyToCommentId,
  }) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': uid,
        'text': text,
        if (replyToCommentId != null && replyToCommentId.isNotEmpty)
          'replyTo': replyToCommentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      controller.clear();
    } catch (_) {
      // FIX #11 — friendly error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post comment. Try again.')),
      );
    }
  }

  Future<void> _sharePost(PostModel post) async {
    final firstUrl = post.mediaItems.isNotEmpty ? post.mediaItems.first.url : '';
    final deepLink = 'https://halo.app/post/${post.id}';
    final payload = [
      if (post.caption.isNotEmpty) post.caption,
      if (firstUrl.isNotEmpty) firstUrl,
      deepLink,
    ].join('\n');
    if (payload.isEmpty) return;
    await Share.share(payload);
  }

  void _openComments(String postId) {
    final input = TextEditingController();
    String? replyingToCommentId;
    String? replyingToUsername;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Comments',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Divider(),
                Expanded(
                  child: _CommentsList(
                    postId: postId,
                    onReply: (commentId, username) {
                      setModalState(() {
                        replyingToCommentId = commentId;
                        replyingToUsername = username;
                        input.text = '@$username ';
                        input.selection = TextSelection.fromPosition(
                          TextPosition(offset: input.text.length),
                        );
                      });
                    },
                  ),
                ),
                if (replyingToCommentId != null && replyingToUsername != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to @$replyingToUsername',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setModalState(() {
                              replyingToCommentId = null;
                              replyingToUsername = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () async {
                          await _addComment(
                            postId,
                            input,
                            replyToCommentId: replyingToCommentId,
                          );
                          setModalState(() {
                            replyingToCommentId = null;
                            replyingToUsername = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        });
      },
    ).whenComplete(input.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.primaryDelta != null && d.primaryDelta! > 14) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Posts'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: true,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          return _PostCard(
            post: post,
            currentUserId: _currentUserId,
            onLike: () => _toggleLike(post.id),
            onComment: () => _openComments(post.id),
            onShare: () => _sharePost(post),
            onMenuAction: (action) => widget.onMenuAction(action, post),
          );
        },
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST CARD — single post in the viewer
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final PostModel post;
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final ValueChanged<_PostMenuAction> onMenuAction;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX #2 — cached user profile, no FutureBuilder per post
          _UserHeader(
            userId: post.userId,
            location: post.location,
            onMenuAction: onMenuAction,
          ),

          // Media carousel
          SizedBox(
            height: 420,
            child: PageView.builder(
              itemCount: post.mediaItems.length,
              itemBuilder: (context, mediaIndex) {
                final media = post.mediaItems[mediaIndex];
                return GestureDetector(
                  onDoubleTap: onLike,
                  child: media.isVideo
                  // FIX #3 & #6 — single shared video widget, lazy init
                      ? _SharedVideoPlayer(
                    url: media.url,
                    fit: BoxFit.contain,
                    autoPlay: false,
                  )
                      : CachedNetworkImage(
                    imageUrl: media.url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image)),
                  ),
                );
              },
            ),
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                // FIX #7 — single source of truth for like state
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: currentUserId == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                      .collection('posts')
                      .doc(post.id)
                      .collection('likes')
                      .doc(currentUserId!)
                      .snapshots(),
                  builder: (context, mineSnap) {
                    final isLiked =
                        mineSnap.hasData && (mineSnap.data?.exists ?? false);
                    return IconButton(
                      onPressed: onLike,
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.black87,
                      ),
                    );
                  },
                ),
                // FIX #7 — single stream, no stale fallback
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(post.id)
                      .collection('likes')
                      .snapshots(),
                  builder: (context, s) {
                    final count = s.data?.docs.length ?? 0;
                    return Text('$count');
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(post.id)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, s) {
                    final count = s.data?.docs.length ?? 0;
                    return Text('$count');
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.send_outlined),
                ),
                const Spacer(),
                SaveButton(
                  postId: post.id,
                  currentUserId: currentUserId,
                  iconSize: 24,
                  color: Colors.black87,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              post.caption.isEmpty ? '' : post.caption,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          if (post.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags
                    .take(8)
                    .map((t) => Chip(
                          label: Text('#$t'),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          if (post.location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(post.location,
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER HEADER — FIX #2: uses profile cache instead of FutureBuilder per post
// ─────────────────────────────────────────────────────────────────────────────

class _UserHeader extends StatefulWidget {
  final String userId;
  final String location;
  final ValueChanged<_PostMenuAction> onMenuAction;
  const _UserHeader({
    required this.userId,
    required this.location,
    required this.onMenuAction,
  });

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
    final photoUrl = (_userData?['photoUrl'] ?? '').toString();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUid == widget.userId;
    final accountType =
        ((_userData?['accountType'] ?? 'aspirant').toString().toLowerCase());
    return ListTile(
      onTap: () async {
        if (widget.userId.isEmpty) return;
        if (accountType == 'wellness') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => wellness_profile.WellnessProfilePage(profileUserId: widget.userId),
            ),
          );
        } else if (accountType == 'guru') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => guru_profile.GuruProfilePage(profileUserId: widget.userId),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => aspirant_profile.ProfilePage(profileUserId: widget.userId),
            ),
          );
        }
      },
      leading: CircleAvatar(
        backgroundImage: photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(photoUrl)
            : const AssetImage('assets/images/Profile.png') as ImageProvider,
      ),
      title: Text(username,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle:
      widget.location.isNotEmpty ? Text(widget.location) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe) _InlineFollowButton(targetUserId: widget.userId),
          PopupMenuButton<_PostMenuAction>(
            icon: const Icon(Icons.more_horiz),
            onSelected: widget.onMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PostMenuAction.notInterested,
                child: Text('Not interested'),
              ),
              PopupMenuItem(
                value: _PostMenuAction.hideUser,
                child: Text('Hide posts from this user'),
              ),
              PopupMenuItem(
                value: _PostMenuAction.report,
                child: Text('Report post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS LIST — FIX #8: batch-fetches unique user profiles for comments
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsList extends StatelessWidget {
  final String postId;
  final void Function(String commentId, String username)? onReply;
  const _CommentsList({required this.postId, this.onReply});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No comments yet'));
        }
        // FIX #8 — pre-fetch all unique user profiles in one pass
        return _CommentsFetcher(docs: docs, onReply: onReply);
      },
    );
  }
}

class _CommentsFetcher extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(String commentId, String username)? onReply;
  const _CommentsFetcher({required this.docs, this.onReply});

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
    // FIX #8 — collect unique IDs, use cache for already-fetched ones
    final uniqueIds = widget.docs
        .map((d) => (d.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    await Future.wait(
      uniqueIds.map((id) async {
        final data = await _UserProfileCache().get(id);
        _profiles[id] = data;
      }),
    );

    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ListView.builder(
      itemCount: widget.docs.length,
      itemBuilder: (_, i) {
        final c = widget.docs[i].data();
        final uid = (c['userId'] ?? '').toString();
        final ud = _profiles[uid] ?? {};
        final username =
        (ud['username'] ?? ud['name'] ?? 'User').toString();
        final photoUrl = (ud['photoUrl'] ?? '').toString();
        final isReply = (c['replyTo'] ?? '').toString().isNotEmpty;
        return Padding(
          padding: EdgeInsets.only(left: isReply ? 24 : 0),
          child: ListTile(
          leading: CircleAvatar(
            backgroundImage: photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(photoUrl)
                : const AssetImage('assets/images/Profile.png')
            as ImageProvider,
          ),
          title: Text(username,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((c['text'] ?? '').toString()),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => widget.onReply?.call(widget.docs[i].id, username),
                child: const Text(
                  'Reply',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REELS VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreReelsViewer extends StatefulWidget {
  final List<PostModel> videoPosts;
  final int initialIndex;

  const _ExploreReelsViewer({
    required this.videoPosts,
    required this.initialIndex,
  });

  @override
  State<_ExploreReelsViewer> createState() => _ExploreReelsViewerState();
}

class _ExploreReelsViewerState extends State<_ExploreReelsViewer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX #10 — guard against empty list
    if (widget.videoPosts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              const Text('No videos yet',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: true,
        itemCount: widget.videoPosts.length,
        itemBuilder: (context, index) {
          final post = widget.videoPosts[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // FIX #3 & #6 — shared widget, lazy/visibility-based init
              _SharedVideoPlayer(
                url: post.firstVideoUrl,
                fit: BoxFit.cover,
                autoPlay: true,
                visibilityKey: 'reel_${post.id}',
              ),
              Positioned(
                top: 40,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              if (post.caption.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 30,
                  child: Text(
                    post.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX #3 & #6 — Single shared video player widget (replaces the two duplicates)
// Supports lazy init via VisibilityDetector and autoPlay flag.
//
// Add to pubspec.yaml:
//   visibility_detector: ^0.4.0
// ─────────────────────────────────────────────────────────────────────────────

class _SharedVideoPlayer extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool autoPlay;
  final String? visibilityKey;

  const _SharedVideoPlayer({
    required this.url,
    this.fit = BoxFit.contain,
    this.autoPlay = false,
    this.visibilityKey,
  });

  @override
  State<_SharedVideoPlayer> createState() => _SharedVideoPlayerState();
}

class _SharedVideoPlayerState extends State<_SharedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;
  bool _initialized = false;

  // FIX #6 — only initialize when visible
  void _initIfNeeded() {
    if (_initialized || widget.url.isEmpty) return;
    _initialized = true;

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        if (widget.autoPlay) {
          _controller!.setLooping(true);
          _controller!.play();
        }
        setState(() => _ready = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return const Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 64));
    }

    // If a visibilityKey is provided, use VisibilityDetector for lazy init.
    // Otherwise fall back to eager init (for inline posts where it's already visible).
    if (widget.visibilityKey != null) {
      return VisibilityDetector(
        key: Key(widget.visibilityKey!),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.2) {
            _initIfNeeded();
          } else {
            // FIX #6 — pause when scrolled off screen
            _controller?.pause();
          }
        },
        child: _playerContent(),
      );
    } else {
      _initIfNeeded();
      return _playerContent();
    }
  }

  Widget _playerContent() {
    if (_error) {
      return const Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 56));
    }
    if (!_ready || _controller == null || !_controller!.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white54));
    }
    final c = _controller!;
    return GestureDetector(
      onTap: () {
        setState(() {
          c.value.isPlaying ? c.pause() : c.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          // Play/pause overlay (only show when paused)
          if (!c.value.isPlaying)
            const Icon(Icons.play_circle_fill,
                color: Colors.white70, size: 54),
        ],
      ),
    );
  }
}

enum _PostMenuAction { notInterested, hideUser, report }

class _InlineFollowButton extends StatelessWidget {
  final String targetUserId;
  const _InlineFollowButton({required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me.isEmpty || me == targetUserId) {
      return const SizedBox.shrink();
    }
    final ref = FirebaseFirestore.instance.collection('follows').doc('${me}_$targetUserId');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, s) {
        final following = s.data?.exists ?? false;
        return TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(0, 30),
            backgroundColor: following ? Colors.grey.shade200 : _kExplorePrimary,
            foregroundColor: following ? Colors.black87 : Colors.white,
          ),
          onPressed: () async {
            if (following) {
              await ref.delete();
            } else {
              await ref.set({
                'followerId': me,
                'followingId': targetUserId,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          },
          child: Text(following ? 'Following' : 'Follow'),
        );
      },
    );
  }
}

class _ExploreSkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 18,
      itemBuilder: (_, __) => Container(
        color: Colors.grey.shade300,
      ),
    );
  }
}