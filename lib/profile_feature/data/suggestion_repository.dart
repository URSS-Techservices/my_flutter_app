import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';

/// "Suggested for you": people of one account type the user does not
/// follow yet, same interests first, then same city.
class SuggestionRepository {
  SuggestionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<List<ProfilePerson>> suggest({
    required String accountType,
    required String myId,
    required List<String> myInterests,
    required String myCity,
    Set<String> exclude = const {},
    int limit = 10,
  }) async {
    const pool = 25;
    final byType = _users.where('accountType', isEqualTo: accountType);
    final found = <String, ProfilePerson>{};

    void add(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final d in snap.docs) {
        if (d.id == myId || exclude.contains(d.id)) continue;
        found.putIfAbsent(d.id, () => ProfilePerson.fromMap(d.id, d.data()));
      }
    }

    if (myInterests.isNotEmpty) {
      try {
        add(await byType
            .where('interests', arrayContainsAny: myInterests.take(10).toList())
            .limit(pool)
            .get());
      } on FirebaseException catch (e) {
        // Needs a composite index (accountType + interests). The message
        // contains a link that creates it in one click.
        if (e.code != 'failed-precondition') rethrow;
        debugPrint('Suggestions index missing: ${e.message}');
      }
    }
    if (found.length < limit) add(await byType.limit(pool).get());

    final notFollowed = await _withoutFollowed(myId, found);
    final city = myCity.trim().toLowerCase();
    notFollowed.sort((a, b) {
      final aSame = city.isNotEmpty && a.city.toLowerCase() == city;
      final bSame = city.isNotEmpty && b.city.toLowerCase() == city;
      return aSame == bSame ? 0 : (aSame ? -1 : 1);
    });
    return notFollowed.take(limit).toList();
  }

  /// Drops people [myId] already follows: one query per 30 candidates
  /// instead of one per person.
  Future<List<ProfilePerson>> _withoutFollowed(
    String myId,
    Map<String, ProfilePerson> candidates,
  ) async {
    final ids = candidates.keys.toList();
    final following = <String>{};
    final myFollowing = _users.doc(myId).collection('following');
    const chunk = 30;
    final snaps = await Future.wait([
      for (var i = 0; i < ids.length; i += chunk)
        myFollowing
            .where(FieldPath.documentId,
                whereIn: ids.sublist(
                    i, i + chunk > ids.length ? ids.length : i + chunk))
            .get(),
    ]);
    for (final snap in snaps) {
      following.addAll(snap.docs.map((d) => d.id));
    }
    return [
      for (final id in ids)
        if (!following.contains(id)) candidates[id]!,
    ];
  }
}
