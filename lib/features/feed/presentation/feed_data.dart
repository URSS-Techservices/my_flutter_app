import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/auth/presentation/session_controller.dart';
import 'package:halo/features/feed/data/feed_prefetch.dart';
import 'package:halo/features/feed/data/posts_data.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return PostsData();
});

/// Only the uid. Follow / like must not recreate the feed when the user doc changes.
final currentUidProvider = Provider<String>((ref) {
  return ref.watch(sessionProvider.select((s) => s.valueOrNull?.uid ?? ''));
});

final homeConfigProvider = FutureProvider<HomeConfig>((ref) async {
  try {
    return await ref.watch(feedRepositoryProvider).loadConfig();
  } catch (_) {
    return HomeConfig.defaults;
  }
});

final storiesProvider = StreamProvider<FeedStories>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchStories(uid);
});

final unreadDotProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchHasUnread(uid);
});

final myPhotoProvider = StreamProvider<String>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchPhotoUrl(uid);
});

final feedMutedProvider = StateProvider<bool>((ref) => true);

final likedProvider = StreamProvider.autoDispose.family<bool, String>((ref, postId) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchLiked(uid, postId);
});

final savedMapProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchSavedMap(uid);
});

final savedProvider = Provider.autoDispose.family<bool, String>((ref, postId) {
  return ref.watch(savedMapProvider.select((async) => async.valueOrNull?[postId] == true));
});

final followingProvider = StreamProvider.autoDispose.family<bool, String>((ref, otherId) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchFollowing(uid, otherId);
});

/// Optimistic follow so the button flips without rebuilding the feed.
final followOptimisticProvider = StateProvider<Map<String, bool>>((ref) => {});

final commentsProvider =
    StreamProvider.autoDispose.family<List<CommentData>, String>((ref, postId) {
  return ref.watch(feedRepositoryProvider).watchComments(postId);
});

final postCountsProvider =
    StreamProvider.autoDispose.family<PostCounts, String>((ref, postId) {
  return ref.watch(feedRepositoryProvider).watchPostCounts(postId);
});

class LikeUiState {
  final bool liked;
  final int count;

  const LikeUiState({required this.liked, required this.count});
}

/// Heart flips immediately. Firestore catches up in the background.
class InstantLikeController extends StateNotifier<LikeUiState> {
  InstantLikeController({
    required this.uid,
    required this.write,
    required bool liked,
    required int count,
  }) : super(LikeUiState(liked: liked, count: count));

  final String uid;
  final Future<void> Function(bool liked) write;

  bool _busy = false;
  bool? _wanted;
  DateTime? _holdUntil;
  int? _queuedCount;

  bool get _holding {
    final until = _holdUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void hydrateLiked(bool liked) {
    if (_busy || _wanted != null || _holding) return;
    if (state.liked == liked) return;
    state = LikeUiState(liked: liked, count: state.count);
  }

  void hydrateCount(int count) {
    if (_busy || _wanted != null || _holding) {
      _queuedCount = count;
      return;
    }
    if (state.count == count) return;
    state = LikeUiState(liked: state.liked, count: count);
  }

  Future<void> likeOnly() async {
    if (state.liked) return;
    await _flip(true);
  }

  Future<void> toggle() => _flip(!state.liked);

  Future<void> _flip(bool liked) async {
    if (uid.isEmpty || state.liked == liked) return;
    var count = state.count + (liked ? 1 : -1);
    if (count < 0) count = 0;
    state = LikeUiState(liked: liked, count: count);
    _wanted = liked;
    await _drain();
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_wanted != null) {
        final target = _wanted;
        _wanted = null;
        if (target == null) break;
        try {
          await write(target);
          _holdUntil = DateTime.now().add(const Duration(milliseconds: 900));
        } catch (_) {
          if (_wanted == null && state.liked == target) {
            var count = state.count + (target ? -1 : 1);
            if (count < 0) count = 0;
            state = LikeUiState(liked: !target, count: count);
          }
          rethrow;
        }
      }
    } finally {
      _busy = false;
      final queued = _queuedCount;
      _queuedCount = null;
      if (queued != null && !_holding) hydrateCount(queued);
    }
  }
}

typedef LikeController = InstantLikeController;

final feedPostIdsProvider = Provider<List<String>>((ref) {
  final joined = ref.watch(
    feedControllerProvider.select((s) => s.posts.map((p) => p.id).join('\u0001')),
  );
  if (joined.isEmpty) return const [];
  return joined.split('\u0001');
});

final feedPostProvider = Provider.autoDispose.family<PostData?, String>((ref, id) {
  return ref.watch(feedControllerProvider.select((s) {
    for (final p in s.posts) {
      if (p.id == id) return p;
    }
    return null;
  }));
});

final likeUiProvider =
    StateNotifierProvider.autoDispose.family<InstantLikeController, LikeUiState, String>(
        (ref, postId) {
  final uid = ref.watch(currentUidProvider);
  final repo = ref.watch(feedRepositoryProvider);
  final post = ref.read(feedPostProvider(postId));
  final liked = ref.read(likedProvider(postId)).valueOrNull ?? false;
  final live = ref.read(postCountsProvider(postId)).valueOrNull?.likes;
  final ctrl = InstantLikeController(
    uid: uid,
    write: (liked) => repo.setLiked(userId: uid, postId: postId, liked: liked),
    count: live ?? post?.likeCount ?? 0,
    liked: liked,
  );
  ref.listen<AsyncValue<bool>>(likedProvider(postId), (_, next) {
    final v = next.valueOrNull;
    if (v == null) return;
    ctrl.hydrateLiked(v);
  }, fireImmediately: true);
  ref.listen<AsyncValue<PostCounts>>(postCountsProvider(postId), (_, next) {
    final v = next.valueOrNull;
    if (v == null) return;
    ctrl.hydrateCount(v.likes);
  }, fireImmediately: true);
  return ctrl;
});

final postLikersProvider =
    StreamProvider.autoDispose.family<List<LikerData>, String>((ref, postId) {
  return ref.watch(feedRepositoryProvider).watchPostLikers(postId);
});

final commentLikedProvider =
    StreamProvider.autoDispose.family<bool, CommentRef>((ref, target) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(feedRepositoryProvider).watchCommentLiked(
        uid,
        target.postId,
        target.commentId,
      );
});

final commentLikersProvider =
    StreamProvider.autoDispose.family<List<LikerData>, CommentRef>((ref, target) {
  return ref.watch(feedRepositoryProvider).watchCommentLikers(
        target.postId,
        target.commentId,
      );
});

final commentLikeUiProvider = StateNotifierProvider.autoDispose
    .family<InstantLikeController, LikeUiState, CommentRef>((ref, target) {
  final uid = ref.watch(currentUidProvider);
  final repo = ref.watch(feedRepositoryProvider);
  final comments = ref.read(commentsProvider(target.postId)).valueOrNull;
  CommentData? comment;
  if (comments != null) {
    for (final c in comments) {
      if (c.id == target.commentId) {
        comment = c;
        break;
      }
    }
  }
  final liked = ref.read(commentLikedProvider(target)).valueOrNull ?? false;
  final ctrl = InstantLikeController(
    uid: uid,
    write: (liked) => repo.setCommentLiked(
      userId: uid,
      postId: target.postId,
      commentId: target.commentId,
      liked: liked,
    ),
    count: comment?.likeCount ?? 0,
    liked: liked,
  );
  ref.listen<AsyncValue<bool>>(commentLikedProvider(target), (_, next) {
    final v = next.valueOrNull;
    if (v == null) return;
    ctrl.hydrateLiked(v);
  }, fireImmediately: true);
  ref.listen<AsyncValue<List<CommentData>>>(commentsProvider(target.postId), (_, next) {
    final list = next.valueOrNull;
    if (list == null) return;
    for (final c in list) {
      if (c.id == target.commentId) {
        ctrl.hydrateCount(c.likeCount);
        break;
      }
    }
  });
  return ctrl;
});

class FeedState {
  final List<PostData> posts;
  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final bool hasMore;
  final String? error;
  final String? moreError;

  const FeedState({
    required this.posts,
    required this.loading,
    required this.loadingMore,
    required this.refreshing,
    required this.hasMore,
    this.error,
    this.moreError,
  });

  static const initial = FeedState(
    posts: [],
    loading: true,
    loadingMore: false,
    refreshing: false,
    hasMore: true,
  );

  FeedState copyWith({
    List<PostData>? posts,
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    bool? hasMore,
    String? error,
    String? moreError,
    bool clearError = false,
    bool clearMoreError = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      moreError: clearMoreError ? null : (moreError ?? this.moreError),
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._repo, this._uid, {bool wait = false})
      : super(FeedState.initial) {
    if (!wait) loadInitial();
  }

  final FeedRepository _repo;
  final String _uid;
  HomeConfig? _config;
  List<String> _interests = const [];
  bool _busy = false;

  Future<void> loadInitial() async {
    if (_uid.isEmpty) {
      state = state.copyWith(
        loading: false,
        posts: const [],
        error: 'Please sign in to see posts.',
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    await _loadInterests();
    await _fetch(refresh: true);
  }

  Future<void> refresh() async {
    if (_busy) return;
    state = state.copyWith(refreshing: true, clearError: true, clearMoreError: true);
    await _loadInterests();
    await _fetch(refresh: true);
  }

  Future<void> loadMore() async {
    if (_busy || state.loading || !state.hasMore || state.posts.isEmpty) return;
    state = state.copyWith(loadingMore: true, clearMoreError: true);
    await _fetch(refresh: false);
  }

  Future<void> retry() => loadInitial();

  void patchCounts(
    String postId, {
    int? likeCount,
    int? commentCount,
    int? shareCount,
  }) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts)
          if (p.id == postId)
            p.copyWith(
              likeCount: likeCount,
              commentCount: commentCount,
              shareCount: shareCount,
            )
          else
            p,
      ],
    );
  }

  Future<void> _fetch({required bool refresh}) async {
    if (_busy) return;
    _busy = true;
    try {
      if (refresh) _config = null;
      _config ??= await _repo.loadConfig();
      final limit = _config?.pageSize ?? 10;
      var page = await _repo.loadPosts(
        userId: _uid,
        limit: limit,
        refresh: refresh,
      );
      var visible = _filter(page.posts);
      var hasMore = page.hasMore;
      var extra = 0;
      while (visible.isEmpty && hasMore && extra < 3) {
        extra++;
        page = await _repo.loadPosts(userId: _uid, limit: limit);
        visible = _filter(page.posts);
        hasMore = page.hasMore;
      }
      state = state.copyWith(
        posts: refresh ? visible : [...state.posts, ...visible],
        hasMore: hasMore,
        loading: false,
        loadingMore: false,
        refreshing: false,
        clearError: true,
        clearMoreError: true,
      );
      final all = state.posts;
      FeedPrefetch.warm(
        all,
        from: refresh ? 0 : (all.length - visible.length).clamp(0, all.length),
      );
    } catch (e) {
      final message = e is FeedLoadException
          ? e.message
          : 'Could not load posts. Please try again.';
      if (refresh && state.posts.isEmpty) {
        state = state.copyWith(
          loading: false,
          loadingMore: false,
          refreshing: false,
          error: message,
        );
      } else {
        state = state.copyWith(
          loading: false,
          loadingMore: false,
          refreshing: false,
          moreError: message,
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _loadInterests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _interests = prefs.getStringList('user_interests') ?? const [];
    } catch (_) {
      _interests = const [];
    }
  }

  List<PostData> _filter(List<PostData> posts) {
    if (_interests.isEmpty) return posts;
    return posts.where((p) {
      if (p.accountType == 'guru') return true;
      if (p.tags.isEmpty) return true;
      return p.tags.any(_interests.contains);
    }).toList();
  }
}

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  final uid = ref.watch(currentUidProvider);
  final loading = ref.watch(sessionProvider.select((s) => s.isLoading));
  final repo = ref.watch(feedRepositoryProvider);
  if (uid.isEmpty) {
    return FeedController(repo, '', wait: loading);
  }
  return FeedController(repo, uid);
});
