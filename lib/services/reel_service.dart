import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/reel_ranking.dart';
import 'dart:async';

class ReelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Last 100 reels ordered by createdAt descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentReels() {
    return _firestore
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Stream of playable reels ranked by reelScore.
  ///
  /// Important: keep ordering stable between snapshots to avoid churn in the
  /// UI's controller pool (random resorting causes decoder re-inits and can
  /// exhaust MediaCodec resources on MTK devices).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getRankedReelsStream() {
    return getRecentReels()
        .map((snapshot) {
      final docs = snapshot.docs;
      if (docs.isEmpty) return <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final scored = <_ScoredReel>[];
      for (final doc in docs) {
        final d = doc.data();
        final processed = d['processed'] == true;
        final processing = d['processing'] == true;
        if (!processed || processing) {
          continue;
        }
        final hls = (d['hlsUrl'] ?? '').toString().trim();
        final mp4 = (d['videoUrl'] ?? d['url'] ?? d['mediaUrl'] ?? '')
            .toString()
            .trim();
        final preview = (d['previewUrl'] ?? '').toString().trim();
        // Hard ingress filter: only pass reels with playable processed URLs.
        if (hls.isEmpty && mp4.isEmpty && preview.isEmpty) {
          continue;
        }

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

      scored.sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        final aCreated = (a.doc.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bCreated = (b.doc.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final byCreated = bCreated.compareTo(aCreated);
        if (byCreated != 0) return byCreated;
        return a.doc.id.compareTo(b.doc.id);
      });

      return scored.map((e) => e.doc).toList(growable: false);
    })
        .transform(
          _debounceAndDistinct(
            const Duration(milliseconds: 160),
            (items) => items.map((e) => e.id).join('|'),
          ),
        );
  }
}

StreamTransformer<T, T> _debounceAndDistinct<T>(
  Duration duration,
  String Function(T event) signature,
) {
  Timer? timer;
  T? pending;
  String? lastSignature;

  return StreamTransformer<T, T>.fromHandlers(
    handleData: (event, sink) {
      pending = event;
      timer?.cancel();
      timer = Timer(duration, () {
        final value = pending;
        if (value == null) return;
        final sig = signature(value);
        if (sig == lastSignature) return;
        lastSignature = sig;
        sink.add(value);
      });
    },
    handleError: (error, stackTrace, sink) {
      sink.addError(error, stackTrace);
    },
    handleDone: (sink) {
      timer?.cancel();
      final value = pending;
      if (value != null) {
        final sig = signature(value);
        if (sig != lastSignature) sink.add(value);
      }
      sink.close();
    },
  );
}

class _ScoredReel {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredReel({required this.doc, required this.score});
}
