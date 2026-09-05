import 'package:flutter/material.dart';
import 'package:halo/models/story_model.dart';

/// One photo or video on a post. URLs are resolved in the data layer.
class PostMedia {
  final bool isVideo;
  final String url;
  final String thumbUrl;
  /// Width / height. Null when the post did not store dimensions.
  final double? aspectRatio;

  const PostMedia({
    required this.isVideo,
    required this.url,
    required this.thumbUrl,
    this.aspectRatio,
  });
}

/// One feed post. UI reads this — never raw Firestore maps.
class PostData {
  final String id;
  final String userId;
  final String username;
  final String userPhotoUrl;
  final String accountType;
  final String caption;
  final String location;
  final DateTime? createdAt;
  final List<PostMedia> media;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final double? lat;
  final double? lng;

  const PostData({
    required this.id,
    required this.userId,
    required this.username,
    required this.userPhotoUrl,
    required this.accountType,
    required this.caption,
    required this.location,
    required this.createdAt,
    required this.media,
    required this.tags,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.saveCount,
    this.lat,
    this.lng,
  });

  PostData copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? saveCount,
    String? userPhotoUrl,
  }) {
    return PostData(
      id: id,
      userId: userId,
      username: username,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      accountType: accountType,
      caption: caption,
      location: location,
      createdAt: createdAt,
      media: media,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
      lat: lat,
      lng: lng,
    );
  }
}

class CommentData {
  final String id;
  final String userId;
  final String username;
  final String photoUrl;
  final String text;
  final DateTime? createdAt;
  final int likeCount;

  const CommentData({
    required this.id,
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.text,
    required this.createdAt,
    this.likeCount = 0,
  });
}

/// Someone who liked a post or a comment.
class LikerData {
  final String userId;
  final String username;
  final String photoUrl;

  const LikerData({
    required this.userId,
    required this.username,
    required this.photoUrl,
  });
}

class CommentRef {
  final String postId;
  final String commentId;

  const CommentRef({required this.postId, required this.commentId});

  @override
  bool operator ==(Object other) {
    return other is CommentRef &&
        other.postId == postId &&
        other.commentId == commentId;
  }

  @override
  int get hashCode => Object.hash(postId, commentId);
}

/// Live like / comment / share totals for one post.
class PostCounts {
  final int likes;
  final int comments;
  final int shares;

  const PostCounts({
    required this.likes,
    required this.comments,
    required this.shares,
  });

  static const zero = PostCounts(likes: 0, comments: 0, shares: 0);

  @override
  bool operator ==(Object other) {
    return other is PostCounts &&
        other.likes == likes &&
        other.comments == comments &&
        other.shares == shares;
  }

  @override
  int get hashCode => Object.hash(likes, comments, shares);
}

/// Admin-tunable home settings from `appConfig/home`.
class HomeConfig {
  final String searchPlaceholder;
  final bool showStories;
  final bool showDistance;
  final int pageSize;
  final Color accent;
  final String emptyMessage;

  const HomeConfig({
    required this.searchPlaceholder,
    required this.showStories,
    required this.showDistance,
    required this.pageSize,
    required this.accent,
    required this.emptyMessage,
  });

  static const defaults = HomeConfig(
    searchPlaceholder: 'Search people, places, events...',
    showStories: true,
    showDistance: true,
    pageSize: 10,
    accent: Color(0xFF6B4EFF),
    emptyMessage: 'No posts yet. Follow people to see their posts.',
  );
}

class FeedPage {
  final List<PostData> posts;
  final bool hasMore;

  const FeedPage({required this.posts, required this.hasMore});
}

class StoryRing {
  final String userId;
  final String username;
  final String photoUrl;
  final bool isMe;
  final bool hasUnseen;
  final bool hasStories;

  const StoryRing({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.isMe,
    required this.hasUnseen,
    required this.hasStories,
  });
}

class FeedStories {
  final List<StoryRing> rings;
  final Map<String, List<StoryModel>> byUser;

  const FeedStories({required this.rings, required this.byUser});

  static const empty = FeedStories(rings: [], byUser: {});
}

/// Feed contract. Firebase stays in `data/`.
abstract class FeedRepository {
  Future<HomeConfig> loadConfig();

  Future<FeedPage> loadPosts({
    required String userId,
    required int limit,
    bool refresh = false,
  });

  Stream<FeedStories> watchStories(String userId);

  Stream<bool> watchHasUnread(String userId);

  Stream<String> watchPhotoUrl(String userId);

  Stream<bool> watchLiked(String userId, String postId);

  Stream<Map<String, dynamic>> watchSavedMap(String userId);

  Stream<bool> watchSaved(String userId, String postId);

  Stream<bool> watchFollowing(String userId, String otherUserId);

  Stream<List<CommentData>> watchComments(String postId);

  Stream<List<LikerData>> watchPostLikers(String postId);

  Stream<List<LikerData>> watchCommentLikers(String postId, String commentId);

  Stream<bool> watchCommentLiked(String userId, String postId, String commentId);

  /// Live counts from the post doc plus likes/comments collections.
  Stream<PostCounts> watchPostCounts(String postId);

  /// Returns whether the post is liked after the write. No-op if already in that state.
  Future<bool> setLiked({
    required String userId,
    required String postId,
    required bool liked,
  });

  /// Returns whether the post is liked after the toggle.
  Future<bool> toggleLike({required String userId, required String postId});

  Future<bool> setCommentLiked({
    required String userId,
    required String postId,
    required String commentId,
    required bool liked,
  });

  Future<void> toggleSave({required String userId, required String postId});

  Future<void> toggleFollow({
    required String userId,
    required String otherUserId,
    required bool shouldFollow,
  });

  Future<void> addShare({required String postId});

  Future<void> addComment({
    required String userId,
    required String postId,
    required String text,
  });
}
