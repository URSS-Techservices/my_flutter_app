import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH REMOTE DATA SOURCE
// All Firestore queries live here. Nothing else should touch Firebase directly
// for search-related operations.
// ─────────────────────────────────────────────────────────────────────────────

class SearchRemote {
  final FirebaseFirestore _db;

  SearchRemote({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const int _userLimit = 80;
  static const int _postLimit = 80;
  static const int _feedPoolLimit = 200;
  static const int _followIdLimit = 1000;

  // ── USER SEARCH ──────────────────────────────────────────────────────────

  /// Returns raw user docs + whether prefix query succeeded.
  Future<
      ({
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
        bool usedPrefix
      })> fetchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return (
        docs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        usedPrefix: false
      );
    }

    // Try prefix match on searchTerms field first
    try {
      final snap = await _db
          .collection('users')
          .orderBy('searchTerms')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(_userLimit)
          .get();
      if (snap.docs.isNotEmpty) {
        return (
          docs: snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
          usedPrefix: true,
        );
      }
    } catch (_) {}

    // Fallback: full collection scan (client-side ranking handles relevance)
    try {
      final snap = await _db.collection('users').limit(100).get();
      return (
        docs: snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
        usedPrefix: false,
      );
    } catch (_) {
      return (
        docs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        usedPrefix: false
      );
    }
  }

  // ── POST SEARCH ───────────────────────────────────────────────────────────

  /// Returns raw post docs ordered by recency (client-side scoring applied later).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchPosts(
      String query) async {
    try {
      final snap = await _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_postLimit)
          .get();
      return snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    } catch (e) {
      if (kDebugMode) debugPrint('[SearchRemote] fetchPosts error: $e');
      return [];
    }
  }

  // ── CAROUSEL BANNERS ─────────────────────────────────────────────────────

  /// Real-time stream of active banners from Firestore.
  /// Admin uploads/manages these from the Firebase console.
  /// Collection: search_banners | Fields: imageUrl, title, subtitle, ctaText,
  ///             ctaRoute (optional), order, isActive
  Stream<List<Map<String, dynamic>>> streamBanners() {
    return _db
        .collection('search_banners')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── CATEGORY EXPERTS ─────────────────────────────────────────────────────

  /// Fetches users matching either interestTerm or specializationTerm.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchUsersByCategory({
    String? interestTerm,
    String? specializationTerm,
  }) async {
    final Set<String> seenIds = {};
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> merged = [];

    final cleanInterest = interestTerm?.trim() ?? '';
    if (cleanInterest.isNotEmpty) {
      try {
        final snap = await _db
            .collection('users')
            .where('interests', arrayContains: cleanInterest.toLowerCase())
            .get();
        for (final doc
            in snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>()) {
          if (seenIds.add(doc.id)) merged.add(doc);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SearchRemote] fetchUsersByCategory interest: $e');
        }
      }
    }

    final cleanSpec = specializationTerm?.trim() ?? '';
    if (cleanSpec.isNotEmpty) {
      try {
        final snap = await _db
            .collection('users')
            .where('areas_of_specialization', arrayContains: cleanSpec)
            .get();
        for (final doc
            in snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>()) {
          if (seenIds.add(doc.id)) merged.add(doc);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SearchRemote] fetchUsersByCategory spec: $e');
        }
      }
    }

    return merged;
  }

  // ── CATEGORIES + CONFIG (admin managed) ──────────────────────────────────

  /// Active category docs, ordered. `isActive` is filtered client-side so no
  /// composite index is needed.
  Future<List<Map<String, dynamic>>> fetchCategoryDocs() async {
    try {
      final snap =
          await _db.collection('search_categories').orderBy('order').get();
      return snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((m) => m['isActive'] != false)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[SearchRemote] fetchCategoryDocs: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> fetchSearchConfigDoc() async {
    try {
      final snap = await _db.collection('search_config').doc('main').get();
      return snap.data();
    } catch (e) {
      if (kDebugMode) debugPrint('[SearchRemote] fetchSearchConfigDoc: $e');
      return null;
    }
  }

  // ── PEOPLE FOR A SUBCATEGORY ─────────────────────────────────────────────

  /// Users whose normalized `interestTags` overlap [tags]. One query, no
  /// composite index; the feed groups by profile type client-side.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchUsersByTags(
    List<String> tags,
  ) async {
    if (tags.isEmpty) return const [];
    try {
      final snap = await _db
          .collection('users')
          .where('interestTags', arrayContainsAny: tags.take(30).toList())
          .limit(_feedPoolLimit)
          .get();
      return snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    } catch (e) {
      if (kDebugMode) debugPrint('[SearchRemote] fetchUsersByTags: $e');
      return const [];
    }
  }

  /// Ids in `users/{uid}/following` or `.../followers`.
  Future<Set<String>> fetchFollowIds(String uid, String subcollection) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection(subcollection)
          .limit(_followIdLimit)
          .get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SearchRemote] fetchFollowIds $subcollection: $e');
      }
      return <String>{};
    }
  }

  /// The signed-in user's own profile document (for interest matching).
  Future<Map<String, dynamic>?> fetchUserDoc(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  // ── RELATIONSHIP SCORES ───────────────────────────────────────────────────

  /// Returns follow-graph scores for current user → each target user (0..1).
  Future<Map<String, double>> fetchRelationshipScores(
    String currentUserId,
    List<String> targetUserIds,
  ) async {
    if (currentUserId.isEmpty || targetUserIds.isEmpty) return {};
    final Map<String, double> out = {};
    const batchSize = 10;
    for (var i = 0; i < targetUserIds.length; i += batchSize) {
      final batch = targetUserIds.skip(i).take(batchSize).toList();
      try {
        final snap = await _db
            .collection('relationships')
            .where('fromUserId', isEqualTo: currentUserId)
            .where('toUserId', whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          final to = doc.data()['toUserId'] as String?;
          final score = (doc.data()['score'] as num?)?.toDouble();
          if (to != null && score != null) out[to] = score.clamp(0.0, 1.0);
        }
      } catch (_) {}
    }
    return out;
  }

  // ── FOLLOW / UNFOLLOW ─────────────────────────────────────────────────────

  /// Check if current user follows [targetUserId].
  Future<bool> checkFollowing(String currentUserId, String targetUserId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Toggle follow/unfollow for [targetUserId].
  Future<void> toggleFollow({
    required String currentUserId,
    required String targetUserId,
    required bool isCurrentlyFollowing,
  }) async {
    final followRef = _db
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);
    final followerRef = _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    if (isCurrentlyFollowing) {
      await followRef.delete();
      await followerRef.delete();
    } else {
      await followRef.set({'followedAt': FieldValue.serverTimestamp()});
      await followerRef.set({'followedAt': FieldValue.serverTimestamp()});
    }
  }

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFE FIELD HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String safeStr(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  return v.toString().trim();
}

List<String> safeStrList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => safeStr(e)).where((s) => s.isNotEmpty).toList();
  }
  return [];
}

String? postImageUrl(Map<String, dynamic> data) {
  final imageUrl = data['imageUrl']?.toString();
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  final images = data['images'];
  if (images is List && images.isNotEmpty) return images.first?.toString();
  final media = data['media'];
  if (media is List && media.isNotEmpty) {
    final first = media.first;
    if (first is Map && first['url'] != null) return first['url']?.toString();
  }
  return null;
}
