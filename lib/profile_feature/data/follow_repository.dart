import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/services/follow_service.dart';

/// Follow state and follower / following lists.
class FollowRepository {
  FollowRepository(this._firestore, this._followService);

  final FirebaseFirestore _firestore;
  final FollowService _followService;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<bool> isFollowing({
    required String myId,
    required String theirId,
  }) async {
    final doc =
        await _users.doc(theirId).collection('followers').doc(myId).get();
    return doc.exists;
  }

  /// Writes both follow docs and both counters in one transaction.
  Future<void> setFollowing({
    required String myId,
    required String theirId,
    required bool follow,
  }) {
    return _followService.setFollowState(
      currentUserId: myId,
      profileUserId: theirId,
      shouldFollow: follow,
    );
  }

  /// People who follow [userId] (or whom [userId] follows), newest first.
  Future<List<ProfilePerson>> listPeople({
    required String userId,
    required bool followers,
    int limit = 50,
  }) async {
    final events = await _people(
      userId: userId,
      subcollection: followers ? 'followers' : 'following',
      limit: limit,
    );
    return events.map((e) => e.person).toList();
  }

  /// The latest accounts [userId] started following, for Recent Activity.
  Future<List<ProfileFollowEvent>> recentFollows(String userId, {int limit = 3}) {
    return _people(userId: userId, subcollection: 'following', limit: limit);
  }

  Future<List<ProfileFollowEvent>> _people({
    required String userId,
    required String subcollection,
    required int limit,
  }) async {
    final snap = await _users
        .doc(userId)
        .collection(subcollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    if (snap.docs.isEmpty) return const [];

    final ids = snap.docs.map((d) => d.id).toList();
    final profiles = await _profilesById(ids);
    return [
      for (final doc in snap.docs)
        if (profiles[doc.id] != null)
          ProfileFollowEvent(
            person: profiles[doc.id]!,
            at: (doc.data()['createdAt'] as Timestamp?)?.toDate(),
          ),
    ];
  }

  /// Loads user docs 30 at a time (Firestore's `whereIn` limit).
  Future<Map<String, ProfilePerson>> _profilesById(List<String> ids) async {
    const chunk = 30;
    final batches = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      for (var i = 0; i < ids.length; i += chunk)
        _users
            .where(FieldPath.documentId,
                whereIn: ids.sublist(
                    i, i + chunk > ids.length ? ids.length : i + chunk))
            .get(),
    ];
    final result = <String, ProfilePerson>{};
    for (final snap in await Future.wait(batches)) {
      for (final doc in snap.docs) {
        result[doc.id] = ProfilePerson.fromMap(doc.id, doc.data());
      }
    }
    return result;
  }
}
