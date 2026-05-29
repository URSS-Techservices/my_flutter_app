import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/reel_ranking.dart';

class ReelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Last [limit] reels ordered by createdAt descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentReels({int limit = 100}) {
    return _firestore
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Fetches the next page of reels after [lastDocument] (Firestore cursor
  /// pagination). Returns raw docs in reverse-chronological order; caller
  /// re-ranks them for display.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getNextReelsPage({
    required QueryDocumentSnapshot<Map<String, dynamic>> lastDocument,
    int limit = 20,
  }) async {
    final snap = await _firestore
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(limit)
        .get();
    return snap.docs;
  }

  /// Stream of reels ranked by reelScore, with top 10% lightly shuffled.
  /// [limit] controls the initial batch size (default 20 for pagination).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getRankedReelsStream({
    int limit = 20,
  }) {
    return getRecentReels(limit: limit).map((snapshot) {
      final docs = snapshot.docs;
      if (docs.isEmpty) return <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final scored = <_ScoredReel>[];
      for (final doc in docs) {
        final d = doc.data();
        final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final durationSeconds = (d['durationSeconds'] as int?) ?? 1;
        final views = (d['views'] as int?) ?? 0;
        final totalWatchTime = (d['totalWatchTime'] as int?) ?? 0;
        final replayCount = (d['replayCount'] as int?) ?? 0;
        final completedViews = (d['completedViews'] as int?) ??
            (views > 0 && durationSeconds > 0
                ? (totalWatchTime / durationSeconds).round().clamp(0, views)
                : 0);
        final likes = (d['likes'] as int?) ?? 0;
        final comments = (d['comments'] as int?) ?? 0;
        final shares = (d['shares'] as int?) ?? 0;

        final score = reelScore(
          totalWatchTime: totalWatchTime,
          views: views,
          durationSeconds: durationSeconds,
          completedViews: completedViews,
          replayCount: replayCount,
          likes: likes,
          comments: comments,
          shares: shares,
          createdAt: createdAt,
        );
        scored.add(_ScoredReel(doc: doc, score: score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      var list = scored.map((e) => e.doc).toList();

      final topCount = (list.length * 0.1).ceil().clamp(0, list.length);
      if (topCount > 1) {
        final top = list.sublist(0, topCount)..shuffle(_random);
        final rest = list.sublist(topCount);
        list = [...top, ...rest];
      }

      return list;
    });
  }

  /// Rank a list of raw docs (used by pagination to rank fetched pages before
  /// appending to the live list).
  List<QueryDocumentSnapshot<Map<String, dynamic>>> rankDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return docs;

    final scored = <_ScoredReel>[];
    for (final doc in docs) {
      final d = doc.data();
      final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final durationSeconds = (d['durationSeconds'] as int?) ?? 1;
      final views = (d['views'] as int?) ?? 0;
      final totalWatchTime = (d['totalWatchTime'] as int?) ?? 0;
      final replayCount = (d['replayCount'] as int?) ?? 0;
      final completedViews = (d['completedViews'] as int?) ??
          (views > 0 && durationSeconds > 0
              ? (totalWatchTime / durationSeconds).round().clamp(0, views)
              : 0);
      final likes = (d['likes'] as int?) ?? 0;
      final comments = (d['comments'] as int?) ?? 0;
      final shares = (d['shares'] as int?) ?? 0;

      final score = reelScore(
        totalWatchTime: totalWatchTime,
        views: views,
        durationSeconds: durationSeconds,
        completedViews: completedViews,
        replayCount: replayCount,
        likes: likes,
        comments: comments,
        shares: shares,
        createdAt: createdAt,
      );
      scored.add(_ScoredReel(doc: doc, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.doc).toList();
  }
}

class _ScoredReel {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredReel({required this.doc, required this.score});
}
