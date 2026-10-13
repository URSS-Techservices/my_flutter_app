import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/presence_feature/domain/activity_status.dart';
import 'package:halo/presence_feature/presentation/presence_providers.dart';
import 'package:halo/profile_feature/data/follow_repository.dart';
import 'package:halo/profile_feature/data/profile_repository.dart';
import 'package:halo/profile_feature/data/suggestion_repository.dart';
import 'package:halo/profile_feature/data/wellness_repository.dart';
import 'package:halo/profile_feature/domain/aspirant_profile.dart';
import 'package:halo/profile_feature/domain/guru_profile.dart';
import 'package:halo/profile_feature/domain/profile_basics.dart';
import 'package:halo/profile_feature/domain/profile_activity.dart';
import 'package:halo/profile_feature/domain/profile_counts.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/domain/wellness_booking.dart';
import 'package:halo/profile_feature/domain/wellness_product.dart';
import 'package:halo/profile_feature/domain/wellness_profile.dart';
import 'package:halo/services/follow_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  ),
);

final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => FollowRepository(FirebaseFirestore.instance, FollowService()),
);

final _authUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Signed-in user's id. Follows login/logout so it is never stale.
final myUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(_authUserProvider);
  return auth.hasValue
      ? auth.value?.uid
      : FirebaseAuth.instance.currentUser?.uid;
});

/// How long profile data is kept after leaving a page, so coming back
/// shows it instantly instead of loading again.
const profileCacheTime = Duration(minutes: 5);

extension CacheFor on Ref<Object?> {
  /// Keep this provider's value for [duration] after the last listener leaves.
  void cacheFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;
    onCancel(() => timer = Timer(duration, link.close));
    onResume(() => timer?.cancel());
    onDispose(() => timer?.cancel());
  }
}

/// Shared fields of any profile (aspirant, guru, wellness): what the
/// header, stats, bio and social links show. One live listener per
/// profile, kept for [profileCacheTime] after the page is left. Widgets
/// should `select` only the fields they show, so a change to one field
/// (e.g. follower count) does not rebuild the whole page.
final profileProvider =
    StreamProvider.autoDispose.family<ProfileBasics?, String>((ref, userId) {
  ref.cacheFor(profileCacheTime);
  return ref.watch(profileRepositoryProvider).watchProfile(userId);
});

/// Aspirant-only fields (fitness stats). Same document as
/// [profileProvider]; Firestore shares the connection.
final aspirantProfileProvider =
    StreamProvider.autoDispose.family<AspirantProfile?, String>((ref, userId) {
  ref.cacheFor(profileCacheTime);
  return ref.watch(profileRepositoryProvider).watchAspirant(userId);
});

/// Booking settings and sessions for the guru booking screen.
final guruBookingProvider =
    FutureProvider.autoDispose.family<GuruBooking, String>(
  (ref, guruId) => ref.watch(profileRepositoryProvider).loadGuruBooking(guruId),
);

/// The signed-in user's booking requests to one wellness centre (live).
final myWellnessBookingsProvider =
    StreamProvider.autoDispose.family<List<WellnessBooking>, String>(
  (ref, wellnessId) {
    final myId = ref.watch(myUserIdProvider);
    if (myId == null) return Stream.value(const []);
    return ref
        .watch(profileRepositoryProvider)
        .watchMyWellnessBookings(wellnessId: wellnessId, myId: myId);
  },
);

final wellnessRepositoryProvider = Provider<WellnessRepository>(
  (ref) => WellnessRepository(FirebaseFirestore.instance),
);

/// Wellness-only fields (services, hours, featured gurus). Same document as
/// [profileProvider]; Firestore shares the connection.
final wellnessProfileProvider =
    StreamProvider.autoDispose.family<WellnessProfile?, String>((ref, id) {
  ref.cacheFor(profileCacheTime);
  return ref.watch(wellnessRepositoryProvider).watchWellness(id);
});

/// The featured gurus' names and photos. Reloads only when the list of
/// ids changes, not on every change to the wellness document.
final featuredGurusProvider = FutureProvider.autoDispose
    .family<List<ProfilePerson>, String>((ref, wellnessId) async {
  ref.cacheFor(profileCacheTime);
  final ids = await ref.watch(wellnessProfileProvider(wellnessId).selectAsync(
    (w) => (w?.featuredGuruIds ?? const <String>[]).join(','),
  ));
  if (ids.isEmpty) return const [];
  return ref.watch(wellnessRepositoryProvider).loadPeople(ids.split(','));
});

/// A wellness centre's products for "Popular Products".
final wellnessProductsProvider = FutureProvider.autoDispose
    .family<List<WellnessProduct>, String>((ref, wellnessId) {
  ref.cacheFor(profileCacheTime);
  return ref.watch(wellnessRepositoryProvider).loadProducts(wellnessId);
});

/// Gurus who follow [wellnessId] (newest first): the only people the
/// owner can pick for "Featured Gurus".
final guruFollowersProvider = FutureProvider.autoDispose
    .family<List<ProfilePerson>, String>((ref, wellnessId) async {
  final followers = await ref
      .watch(followRepositoryProvider)
      .listPeople(userId: wellnessId, followers: true, limit: 300);
  return [
    for (final p in followers)
      if (p.accountType == 'guru') p,
  ];
});

/// Whether the signed-in user follows [theirId]. Updates instantly on tap
/// and rolls back if the write fails.
final followProvider =
    AsyncNotifierProvider.autoDispose.family<FollowNotifier, bool, String>(
  FollowNotifier.new,
);

class FollowNotifier extends AutoDisposeFamilyAsyncNotifier<bool, String> {
  bool _saving = false;

  @override
  Future<bool> build(String theirId) async {
    final myId = ref.watch(myUserIdProvider);
    if (myId == null || myId == theirId) return false;
    return ref
        .watch(followRepositoryProvider)
        .isFollowing(myId: myId, theirId: theirId);
  }

  /// Returns false if the change could not be saved.
  Future<bool> toggle() async {
    final myId = ref.read(myUserIdProvider);
    final current = state.valueOrNull;
    if (_saving || myId == null || current == null) return true;

    _saving = true;
    state = AsyncData(!current);
    try {
      await ref.read(followRepositoryProvider).setFollowing(
            myId: myId,
            theirId: arg,
            follow: !current,
          );
      return true;
    } catch (_) {
      state = AsyncData(current);
      return false;
    } finally {
      _saving = false;
    }
  }
}

/// Posts grid state: what is loaded so far and whether more exist.
class ProfilePostsState {
  final List<PostData> posts;
  final bool hasMore;
  final bool loadingMore;

  const ProfilePostsState({
    required this.posts,
    required this.hasMore,
    this.loadingMore = false,
  });
}

/// A user's posts, newest first, loaded one page at a time as the grid
/// scrolls.
final profilePostsProvider = AsyncNotifierProvider.autoDispose
    .family<ProfilePostsNotifier, ProfilePostsState, String>(
  ProfilePostsNotifier.new,
);

class ProfilePostsNotifier
    extends AutoDisposeFamilyAsyncNotifier<ProfilePostsState, String> {
  static const pageSize = 18;

  @override
  Future<ProfilePostsState> build(String userId) async {
    ref.cacheFor(profileCacheTime);
    // A post deleted anywhere disappears from the grid at once.
    ref.listen(deletedPostsProvider, (_, deleted) {
      final current = state.valueOrNull;
      if (current == null) return;
      final kept = [
        for (final p in current.posts)
          if (!deleted.contains(p.id)) p,
      ];
      if (kept.length == current.posts.length) return;
      state = AsyncData(ProfilePostsState(
        posts: kept,
        hasMore: current.hasMore,
        loadingMore: current.loadingMore,
      ));
    });
    final first = await ref
        .watch(feedRepositoryProvider)
        .loadUserPosts(userId, limit: pageSize);
    return ProfilePostsState(posts: first, hasMore: first.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final before = current.posts.isEmpty ? null : current.posts.last.createdAt;
    if (before == null) {
      state = AsyncData(ProfilePostsState(posts: current.posts, hasMore: false));
      return;
    }

    state = AsyncData(ProfilePostsState(
      posts: current.posts,
      hasMore: true,
      loadingMore: true,
    ));
    try {
      final next = await ref
          .read(feedRepositoryProvider)
          .loadUserPosts(arg, limit: pageSize, before: before);
      state = AsyncData(ProfilePostsState(
        posts: [...current.posts, ...next],
        hasMore: next.length == pageSize,
      ));
    } catch (_) {
      // Keep what we have; scrolling again retries.
      state = AsyncData(ProfilePostsState(posts: current.posts, hasMore: true));
    }
  }
}

/// Followers (`followers: true`) or Following list for a profile.
final profilePeopleProvider = FutureProvider.autoDispose
    .family<List<ProfilePerson>, ({String userId, bool followers})>(
  (ref, key) {
    ref.cacheFor(profileCacheTime);
    return ref
        .watch(followRepositoryProvider)
        .listPeople(userId: key.userId, followers: key.followers);
  },
);

/// Latest posts and follows merged into one list, newest first.
final profileActivityProvider =
    FutureProvider.autoDispose.family<List<ProfileActivity>, String>(
  (ref, userId) async {
    ref.cacheFor(profileCacheTime);
    // Reload when a post is deleted so it leaves Recent Activity too.
    ref.watch(deletedPostsProvider.select((s) => s.length));
    final results = await Future.wait([
      ref.watch(feedRepositoryProvider).loadUserPosts(userId, limit: 5),
      ref.watch(followRepositoryProvider).recentFollows(userId, limit: 5),
    ]);
    final posts = results[0] as List<PostData>;
    final follows = results[1] as List<ProfileFollowEvent>;
    return [
      for (final p in posts) ProfileActivity.posted(p),
      for (final f in follows) ProfileActivity.followed(f.person, f.at),
    ]..sort(ProfileActivity.newestFirst);
  },
);

/// Real Following / Followers / Posts totals. Recounted whenever the
/// stored counters on the user doc change (e.g. after a follow).
final profileCountsProvider =
    FutureProvider.autoDispose.family<ProfileCounts, String>((ref, userId) {
  ref.cacheFor(profileCacheTime);
  ref.watch(profileProvider(userId).select((async) {
    final b = async.valueOrNull;
    return (b?.followersCount, b?.followingCount, b?.postsCount);
  }));
  return ref.watch(profileRepositoryProvider).countAll(userId);
});

final suggestionRepositoryProvider = Provider<SuggestionRepository>(
  (ref) => SuggestionRepository(FirebaseFirestore.instance),
);

/// Account types shown as chips in "Suggested for you".
enum SuggestionType {
  aspirants('aspirant', 'Aspirants'),
  coaches('guru', 'Coaches'),
  wellness('wellness', 'Wellness');

  const SuggestionType(this.accountType, this.label);

  final String accountType;
  final String label;
}

/// Suggestions of one type for the signed-in user, never including the
/// profile being viewed. Cached for 10 minutes.
final suggestionsProvider = FutureProvider.autoDispose.family<
    List<ProfilePerson>,
    ({SuggestionType type, String profileUserId})>((ref, key) async {
  ref.cacheFor(const Duration(minutes: 10));
  final myId = ref.watch(myUserIdProvider);
  if (myId == null) return const [];
  // Only interests and city matter; other changes to my profile (e.g.
  // last seen) must not reload suggestions.
  final me = await ref.watch(profileProvider(myId).selectAsync(
    (p) => (
      interests: p?.interests.join('\u0001') ?? '',
      city: p?.location ?? '',
    ),
  ));
  return ref.watch(suggestionRepositoryProvider).suggest(
        accountType: key.type.accountType,
        myId: myId,
        myInterests: me.interests.isEmpty ? const [] : me.interests.split('\u0001'),
        myCity: me.city,
        exclude: {key.profileUserId},
      );
});

/// Suggestions the user closed with ✕ (kept for this app session).
final dismissedSuggestionsProvider = StateProvider<Set<String>>((ref) => {});

/// Instagram rules for showing someone's activity status:
/// never on your own profile, only for people you follow, and only when
/// both of you have activity status turned on.
final activityStatusProvider =
    Provider.autoDispose.family<ActivityStatus, String>((ref, userId) {
  final myId = ref.watch(myUserIdProvider);
  if (myId == null || myId == userId) return ActivityStatus.hidden;

  final their = ref.watch(profileProvider(userId).select((async) {
    final b = async.valueOrNull;
    return (
      online: b?.isOnline ?? false,
      lastSeen: b?.lastSeen,
      shares: b?.showActivityStatus ?? false,
    );
  }));
  if (!their.shares) return ActivityStatus.hidden;

  final iShare = ref.watch(profileProvider(myId)
      .select((async) => async.valueOrNull?.showActivityStatus ?? true));
  if (!iShare) return ActivityStatus.hidden;

  final iFollow =
      ref.watch(followProvider(userId).select((async) => async.valueOrNull ?? false));
  if (!iFollow) return ActivityStatus.hidden;

  return ActivityStatus.from(
    isOnline: their.online,
    lastSeen: their.lastSeen,
    now: ref.watch(minuteTickProvider).valueOrNull ?? DateTime.now(),
  );
});
