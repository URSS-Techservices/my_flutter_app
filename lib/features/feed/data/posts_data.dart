import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:halo/features/feed/data/media_url.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/models/story_model.dart';
import 'package:halo/services/feed_service.dart';
import 'package:halo/services/follow_service.dart';
import 'package:halo/services/reel_player_lifecycle.dart';
import 'package:halo/services/save_service.dart';
import 'package:halo/services/story_service.dart';
import 'package:halo/services/video_playback_resolver.dart';

/// Firebase implementation. Ranking stays inside [FeedService] — not rewritten.
class PostsData implements FeedRepository {
  PostsData({
    FirebaseFirestore? firestore,
    FeedService? feedService,
    StoryService? storyService,
    FollowService? followService,
    SaveService? saveService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _feed = feedService ?? FeedService(),
        _stories = storyService ?? StoryService(),
        _follow = followService ?? FollowService(),
        _save = saveService ?? SaveService();

  final FirebaseFirestore _firestore;
  final FeedService _feed;
  final StoryService _stories;
  final FollowService _follow;
  final SaveService _save;

  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;

  static const _userTtl = Duration(minutes: 5);
  final Map<String, _UserCache> _users = {};

  @override
  Future<HomeConfig> loadConfig() async {
    try {
      final snap =
          await _firestore.collection('appConfig').doc('home').get();
      if (!snap.exists) return HomeConfig.defaults;
      final d = snap.data() ?? const <String, dynamic>{};
      return HomeConfig(
        searchPlaceholder: _str(
          d['searchPlaceholder'],
          HomeConfig.defaults.searchPlaceholder,
        ),
        showStories: d['showStories'] != false,
        showDistance: d['showDistance'] != false,
        pageSize: _int(d['pageSize'], HomeConfig.defaults.pageSize).clamp(4, 20),
        accent: _color(d['accentColor']) ?? HomeConfig.defaults.accent,
        emptyMessage: _str(d['emptyMessage'], HomeConfig.defaults.emptyMessage),
      );
    } catch (_) {
      return HomeConfig.defaults;
    }
  }

  @override
  Future<FeedPage> loadPosts({
    required String userId,
    required int limit,
    bool refresh = false,
  }) async {
    if (refresh) _cursor = null;
    try {
      final result = await _feed
          .getRankedFeedPage(
            currentUserId: userId,
            userPreference: '',
            limit: limit,
            startAfterDoc: _cursor,
          )
          .timeout(const Duration(seconds: 20));

      _cursor = result.lastDoc;

      final authorIds = result.docs
          .map((d) => (d.data()['userId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      final authors = await _authors(authorIds);

      final posts = <PostData>[];
      for (final doc in result.docs) {
        try {
          posts.add(_mapPost(doc.id, doc.data(), authors));
        } catch (_) {
          // Skip a broken doc so one bad post does not kill the page.
        }
      }

      return FeedPage(posts: posts, hasMore: result.hasMore);
    } on FirebaseException catch (e) {
      throw FeedLoadException(_firebaseMessage(e));
    } on FeedLoadException {
      rethrow;
    } catch (e) {
      throw FeedLoadException(_genericMessage(e));
    }
  }

  @override
  Stream<FeedStories> watchStories(String userId) {
    if (userId.isEmpty) return Stream.value(FeedStories.empty);
    return _stories.fetchStoriesRanked(userId).map((ranked) {
      try {
        return _mapStories(userId, ranked.orderedUserIds, ranked.grouped);
      } catch (_) {
        return FeedStories.empty;
      }
    }).transform(_onError(FeedStories.empty));
  }

  @override
  Stream<bool> watchHasUnread(String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty)
        .transform(_onError(false));
  }

  @override
  Stream<String> watchPhotoUrl(String userId) {
    if (userId.isEmpty) return Stream.value('');
    return _firestore.collection('users').doc(userId).snapshots().map((snap) {
      return _photoOf(snap.data());
    }).transform(_onError(''));
  }

  static StreamTransformer<T, T> _onError<T>(T fallback) {
    return StreamTransformer<T, T>.fromHandlers(
      handleError: (e, st, sink) => sink.add(fallback),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _authors(Set<String> ids) async {
    final out = <String, Map<String, dynamic>>{};
    final missing = <String>[];
    final now = DateTime.now();
    for (final id in ids) {
      final cached = _users[id];
      if (cached != null && now.difference(cached.at) < _userTtl) {
        if (cached.data != null) out[id] = cached.data!;
      } else {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return out;

    const chunk = 10;
    for (var i = 0; i < missing.length; i += chunk) {
      final slice = missing.sublist(
        i,
        i + chunk > missing.length ? missing.length : i + chunk,
      );
      final snaps = await Future.wait(slice.map((id) async {
        try {
          return MapEntry(id, await _firestore.collection('users').doc(id).get());
        } catch (_) {
          return MapEntry(id, null);
        }
      }));
      for (final e in snaps) {
        final data = e.value?.data();
        _users[e.key] = _UserCache(data, now);
        if (data != null) out[e.key] = data;
      }
    }
    return out;
  }

  PostData _mapPost(
    String id,
    Map<String, dynamic> d,
    Map<String, Map<String, dynamic>> authors,
  ) {
    final userId = (d['userId'] ?? '').toString();
    final user = authors[userId];
    return PostData(
      id: id,
      userId: userId,
      username: _str(
        user?['username'] ?? user?['name'] ?? d['username'],
        'User',
      ),
      userPhotoUrl: _photoOf(user),
      accountType: _str(
        user?['accountType'] ?? d['accountType'],
        'aspirant',
      ).toLowerCase(),
      caption: (d['caption'] ?? '').toString().trim(),
      location: (d['location'] ?? d['place'] ?? '').toString().trim(),
      createdAt: _time(d['createdAt'] ?? d['timestamp']),
      media: _media(d),
      tags: _tags(d),
      likeCount: _int(d['likeCount'] ?? d['likesCount']),
      commentCount: _int(d['commentCount'] ?? d['commentsCount']),
      shareCount: _int(d['shareCount'] ?? d['sharesCount']),
      saveCount: _int(d['saveCount'] ?? d['savesCount']),
      lat: (d['lat'] as num?)?.toDouble() ?? (d['latitude'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble() ?? (d['longitude'] as num?)?.toDouble(),
    );
  }

  List<PostMedia> _media(Map<String, dynamic> d) {
    final raw = d['media'];
    if (raw is List && raw.isNotEmpty) {
      final items = <PostMedia>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final type = (m['type'] ?? 'image').toString();
        if (type == 'video') {
          final video = _videoUrl(d, m);
          var thumb = _thumb(m, d);
          if (thumb.isEmpty) thumb = MediaUrl.poster(video);
          items.add(PostMedia(
            isVideo: true,
            url: video,
            thumbUrl: thumb.isNotEmpty ? MediaUrl.thumb(thumb) : '',
            aspectRatio: _aspect(m, d),
          ));
        } else {
          final url = _imageFeed(m);
          if (url.isNotEmpty) {
            items.add(PostMedia(
              isVideo: false,
              url: MediaUrl.feed(url),
              thumbUrl: MediaUrl.thumb(_imageThumb(m, url)),
              aspectRatio: _aspect(m, d),
            ));
          }
        }
      }
      if (items.isNotEmpty) return items;
    }

    final images = d['images'];
    if (images is List && images.isNotEmpty) {
      return images
          .map((e) => e.toString().trim())
          .where((u) => u.isNotEmpty)
          .map((u) => PostMedia(
                isVideo: false,
                url: MediaUrl.feed(u),
                thumbUrl: MediaUrl.thumb(u),
                aspectRatio: _aspect(const {}, d),
              ))
          .toList();
    }

    final img = (d['imageUrl'] ?? d['photoUrl'] ?? '').toString().trim();
    if (img.isNotEmpty) {
      return [
        PostMedia(
          isVideo: false,
          url: MediaUrl.feed(img),
          thumbUrl: MediaUrl.thumb(img),
          aspectRatio: _aspect(const {}, d),
        ),
      ];
    }

    final video = _videoUrl(d, const {});
    if (video.isNotEmpty) {
      var thumb = _thumb(const {}, d);
      if (thumb.isEmpty) thumb = MediaUrl.poster(video);
      return [
        PostMedia(
          isVideo: true,
          url: video,
          thumbUrl: thumb.isNotEmpty ? MediaUrl.thumb(thumb) : '',
          aspectRatio: _aspect(const {}, d),
        ),
      ];
    }
    return const [];
  }

  String _videoUrl(Map<String, dynamic> d, Map<String, dynamic> m) {
    final resolved = resolveVideoPlayback(postData: d, mediaItem: m);
    if (ReelPlatformPolicy.isAndroid) {
      final mp4 = pickProcessedMp4(m, d)?.trim() ?? '';
      if (mp4.isNotEmpty &&
          (resolved.primaryUrl.contains('.m3u8') ||
              resolved.status == ReelStatus.readyHls)) {
        return mp4;
      }
      if (resolved.fallbackUrl.isNotEmpty &&
          resolved.primaryUrl.contains('.m3u8')) {
        return resolved.fallbackUrl;
      }
    }
    return resolved.primaryUrl.trim();
  }

  double? _aspect(Map<String, dynamic> m, Map<String, dynamic> d) {
    final w = _num(m['width'] ?? m['originalWidth'] ?? d['width'] ?? d['originalWidth']);
    final h = _num(m['height'] ?? m['originalHeight'] ?? d['height'] ?? d['originalHeight']);
    if (w != null && h != null && w > 0 && h > 0) {
      return w / h;
    }
    final raw = m['aspectRatio'] ?? d['aspectRatio'];
    if (raw is num && raw > 0) return raw.toDouble();
    if (raw is String) {
      final n = double.tryParse(raw);
      if (n != null && n > 0) return n;
      if (raw.contains(':')) {
        final parts = raw.split(':');
        if (parts.length == 2) {
          final aw = double.tryParse(parts[0].trim());
          final ah = double.tryParse(parts[1].trim());
          if (aw != null && ah != null && aw > 0 && ah > 0) return aw / ah;
        }
      }
    }
    return null;
  }

  String _imageFeed(Map<String, dynamic> m) {
    for (final k in ['medium', 'url', 'full']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _imageThumb(Map<String, dynamic> m, String fallback) {
    for (final k in ['thumb', 'thumbnail', 'thumbnailUrl', 'previewUrl']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return fallback;
  }

  String _thumb(Map<String, dynamic> m, Map<String, dynamic> d) {
    for (final k in ['thumbnail', 'thumbnailUrl', 'previewUrl']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    for (final k in ['thumbnailUrl', 'previewUrl', 'thumbnail']) {
      final v = (d[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  FeedStories _mapStories(
    String myUid,
    List<String> orderedIds,
    Map<String, List<StoryModel>> grouped,
  ) {
    final rings = <StoryRing>[];
    final mine = grouped[myUid] ?? const <StoryModel>[];
    rings.add(StoryRing(
      userId: myUid,
      username: 'Your story',
      photoUrl: '',
      isMe: true,
      hasStories: mine.isNotEmpty,
      hasUnseen: mine.any((s) => !s.viewers.contains(myUid)),
    ));

    for (final id in orderedIds) {
      if (id == myUid) continue;
      final list = grouped[id];
      if (list == null || list.isEmpty) continue;
      final first = list.first;
      rings.add(StoryRing(
        userId: id,
        username: first.username.isNotEmpty ? first.username : 'User',
        photoUrl: first.userPhotoUrl ?? '',
        isMe: false,
        hasStories: true,
        hasUnseen: list.any((s) => !s.viewers.contains(myUid)),
      ));
    }
    return FeedStories(rings: rings, byUser: grouped);
  }

  @override
  Stream<bool> watchLiked(String userId, String postId) {
    if (userId.isEmpty || postId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((s) => s.exists)
        .transform(_onError(false));
  }

  @override
  Stream<Map<String, dynamic>> watchSavedMap(String userId) {
    if (userId.isEmpty) return Stream.value(const {});
    return _save.savedPostsStream(userId).transform(_onError(const <String, dynamic>{}));
  }

  @override
  Stream<bool> watchSaved(String userId, String postId) {
    if (userId.isEmpty || postId.isEmpty) return Stream.value(false);
    return watchSavedMap(userId).map((m) => m[postId] == true);
  }

  @override
  Stream<bool> watchFollowing(String userId, String otherUserId) {
    if (userId.isEmpty || otherUserId.isEmpty || userId == otherUserId) {
      return Stream.value(false);
    }
    return _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('followers')
        .doc(userId)
        .snapshots()
        .map((s) => s.exists)
        .transform(_onError(false));
  }

  @override
  Stream<List<CommentData>> watchComments(String postId) {
    if (postId.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .limit(80)
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs
              .map((d) => (d.data()['userId'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet();
          final authors = await _authors(ids);
          final list = snap.docs.map((d) {
            final data = d.data();
            final uid = (data['userId'] ?? '').toString();
            final user = authors[uid];
            return CommentData(
              id: d.id,
              userId: uid,
              username: _str(
                data['username'] ?? user?['username'] ?? user?['name'],
                'User',
              ),
              photoUrl: _photoOf(user),
              text: (data['text'] ?? data['comment'] ?? '').toString(),
              createdAt: _time(data['createdAt']),
              likeCount: _int(data['likeCount'] ?? data['likesCount']),
            );
          }).toList();
          list.sort((a, b) {
            final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return at.compareTo(bt);
          });
          return list;
        })
        .transform(_onError(const <CommentData>[]));
  }

  @override
  Stream<List<LikerData>> watchPostLikers(String postId) {
    if (postId.isEmpty) return Stream.value(const []);
    return _watchLikers(
      _firestore.collection('posts').doc(postId).collection('likes'),
    );
  }

  @override
  Stream<List<LikerData>> watchCommentLikers(String postId, String commentId) {
    if (postId.isEmpty || commentId.isEmpty) return Stream.value(const []);
    return _watchLikers(
      _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('likes'),
    );
  }

  Stream<List<LikerData>> _watchLikers(
    CollectionReference<Map<String, dynamic>> col,
  ) {
    return col.limit(60).snapshots().asyncMap((snap) async {
      final ids = snap.docs
          .map((d) => (d.data()['userId'] ?? d.id).toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      final authors = await _authors(ids);
      final list = snap.docs.map((d) {
        final data = d.data();
        final uid = (data['userId'] ?? d.id).toString();
        final user = authors[uid];
        return LikerData(
          userId: uid,
          username: _str(
            data['username'] ?? user?['username'] ?? user?['name'],
            'User',
          ),
          photoUrl: _photoOf(user),
        );
      }).toList();
      list.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      return list;
    }).transform(_onError(const <LikerData>[]));
  }

  @override
  Stream<bool> watchCommentLiked(String userId, String postId, String commentId) {
    if (userId.isEmpty || postId.isEmpty || commentId.isEmpty) {
      return Stream.value(false);
    }
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((s) => s.exists)
        .transform(_onError(false));
  }

  @override
  Stream<PostCounts> watchPostCounts(String postId) {
    if (postId.isEmpty) return Stream.value(PostCounts.zero);
    final postRef = _firestore.collection('posts').doc(postId);
    late final StreamController<PostCounts> out;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? postSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? likeSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? commentSub;
    var postReady = false;
    var likesField = 0;
    var commentsField = 0;
    var sharesField = 0;
    var likesSize = 0;
    var commentsSize = 0;
    PostCounts? last;

    void emit() {
      if (!postReady || out.isClosed) return;
      final next = PostCounts(
        likes: likesField > likesSize ? likesField : likesSize,
        comments: commentsField > commentsSize ? commentsField : commentsSize,
        shares: sharesField,
      );
      if (next == last) return;
      last = next;
      out.add(next);
    }

    out = StreamController<PostCounts>(
      onListen: () {
        postSub = postRef.snapshots().listen((snap) {
          final d = snap.data() ?? const <String, dynamic>{};
          likesField = _int(d['likeCount'] ?? d['likesCount']);
          commentsField = _int(d['commentCount'] ?? d['commentsCount']);
          sharesField = _int(d['shareCount'] ?? d['sharesCount']);
          postReady = true;
          emit();
        }, onError: (_) {});
        likeSub = postRef.collection('likes').snapshots().listen((snap) {
          likesSize = snap.size;
          emit();
        }, onError: (_) {});
        commentSub = postRef.collection('comments').limit(80).snapshots().listen((snap) {
          commentsSize = snap.size;
          emit();
        }, onError: (_) {});
      },
      onCancel: () {
        postSub?.cancel();
        likeSub?.cancel();
        commentSub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<bool> setLiked({
    required String userId,
    required String postId,
    required bool liked,
  }) async {
    if (userId.isEmpty || postId.isEmpty) return false;
    final username = _cachedUsername(userId);
    final likeRef =
        _firestore.collection('posts').doc(postId).collection('likes').doc(userId);
    final postRef = _firestore.collection('posts').doc(postId);
    return _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final postSnap = await tx.get(postRef);
      final exists = likeSnap.exists;
      if (liked == exists) return liked;
      final current = _int(postSnap.data()?['likeCount'] ?? postSnap.data()?['likesCount']);
      if (liked) {
        tx.set(likeRef, {
          'userId': userId,
          'likedAt': FieldValue.serverTimestamp(),
          if (username.isNotEmpty) 'username': username,
        });
        if (postSnap.exists) {
          tx.update(postRef, {'likeCount': current + 1, 'likesCount': current + 1});
        }
        return true;
      }
      tx.delete(likeRef);
      final next = current > 0 ? current - 1 : 0;
      if (postSnap.exists) {
        tx.update(postRef, {'likeCount': next, 'likesCount': next});
      }
      return false;
    });
  }

  @override
  Future<bool> toggleLike({required String userId, required String postId}) async {
    if (userId.isEmpty || postId.isEmpty) return false;
    final likeRef =
        _firestore.collection('posts').doc(postId).collection('likes').doc(userId);
    final exists = (await likeRef.get()).exists;
    return setLiked(userId: userId, postId: postId, liked: !exists);
  }

  @override
  Future<bool> setCommentLiked({
    required String userId,
    required String postId,
    required String commentId,
    required bool liked,
  }) async {
    if (userId.isEmpty || postId.isEmpty || commentId.isEmpty) return false;
    final username = _cachedUsername(userId);
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final likeRef = commentRef.collection('likes').doc(userId);
    return _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final commentSnap = await tx.get(commentRef);
      if (!commentSnap.exists) return false;
      final exists = likeSnap.exists;
      if (liked == exists) return liked;
      final current = _int(
        commentSnap.data()?['likeCount'] ?? commentSnap.data()?['likesCount'],
      );
      if (liked) {
        tx.set(likeRef, {
          'userId': userId,
          'likedAt': FieldValue.serverTimestamp(),
          if (username.isNotEmpty) 'username': username,
        });
        tx.update(commentRef, {
          'likeCount': current + 1,
          'likesCount': current + 1,
        });
        return true;
      }
      tx.delete(likeRef);
      final next = current > 0 ? current - 1 : 0;
      tx.update(commentRef, {'likeCount': next, 'likesCount': next});
      return false;
    });
  }

  String _cachedUsername(String userId) {
    final user = _users[userId]?.data;
    return _str(user?['username'] ?? user?['name']);
  }

  @override
  Future<void> toggleSave({required String userId, required String postId}) {
    return _save.toggleSavePost(userId: userId, postId: postId);
  }

  @override
  Future<void> toggleFollow({
    required String userId,
    required String otherUserId,
    required bool shouldFollow,
  }) {
    return _follow.setFollowState(
      currentUserId: userId,
      profileUserId: otherUserId,
      shouldFollow: shouldFollow,
    );
  }

  @override
  Future<void> addShare({required String postId}) async {
    if (postId.isEmpty) return;
    await _firestore.collection('posts').doc(postId).set({
      'shareCount': FieldValue.increment(1),
      'sharesCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addComment({
    required String userId,
    required String postId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (userId.isEmpty || postId.isEmpty || trimmed.isEmpty) return;
    final user = await _firestore.collection('users').doc(userId).get();
    final username = _str(user.data()?['username'] ?? user.data()?['name'], 'User');
    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'userId': userId,
      'username': username,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('posts').doc(postId).set({
      'commentCount': FieldValue.increment(1),
      'commentsCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  String _photoOf(Map<String, dynamic>? d) {
    if (d == null) return '';
    for (final k in [
      'profilePhoto',
      'photoURL',
      'photoUrl',
      'profile_photo',
      'profileImage',
      'profilePic',
      'avatar',
      'userPhotoUrl',
      'image',
    ]) {
      final v = (d[k] ?? '').toString().trim();
      if (v.isNotEmpty &&
          v != 'null' &&
          (v.startsWith('http://') || v.startsWith('https://'))) {
        return v;
      }
    }
    return '';
  }

  List<String> _tags(Map<String, dynamic> d) {
    final raw = d['tags'] ?? d['hashtags'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((t) => t.isNotEmpty)
        .map((t) => t.startsWith('#') ? t.substring(1) : t)
        .toList();
  }

  DateTime? _time(dynamic v) {
    if (v is Timestamp) return v.toDate().toLocal();
    if (v is DateTime) return v.toLocal();
    return null;
  }

  static String _str(dynamic v, [String fallback = '']) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static int _int(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? fallback;
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString().trim());
  }

  static Color? _color(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    var hex = s.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return null;
    return Color(n);
  }

  static String _firebaseMessage(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No internet. Check your connection and try again.';
      case 'permission-denied':
        return 'You do not have access to the feed.';
      case 'unauthenticated':
        return 'Please sign in to see posts.';
      default:
        return 'Could not load posts. Please try again.';
    }
  }

  static String _genericMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('timeout') ||
        s.contains('timed out') ||
        s.contains('failed host lookup')) {
      return 'No internet. Check your connection and try again.';
    }
    return 'Could not load posts. Please try again.';
  }
}

class FeedLoadException implements Exception {
  FeedLoadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _UserCache {
  _UserCache(this.data, this.at);
  final Map<String, dynamic>? data;
  final DateTime at;
}
