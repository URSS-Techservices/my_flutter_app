import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_logger.dart';
import 'video_playback_resolver.dart';

/// Best-effort Firestore flag so [requeueLegacyPost] transcodes legacy raw-only
/// uploads (videoUrl set, no HLS, no rawVideoUrl field).
class VideoTranscodeQueueService {
  VideoTranscodeQueueService._();
  static final VideoTranscodeQueueService instance =
      VideoTranscodeQueueService._();

  static const int _maxAttempts = 12;
  static final Set<String> _sessionRequested = {};
  static const Duration _stuckProcessingThreshold = Duration(minutes: 8);

  Future<void> maybeRequestTranscode({
    required String postId,
    required ResolvedVideoPlayback playback,
  }) async {
    if (postId.isEmpty) return;
    if (!playback.legacyRawFallback) return;
    if (playback.status == ReelStatus.failedTranscode) return;
    if (_sessionRequested.contains(postId)) return;
    _sessionRequested.add(postId);

    try {
      final ref = FirebaseFirestore.instance.collection('posts').doc(postId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return;
      if (data['processed'] == true) return;
      if (data['processing'] == true) return;
      if (data['transcodeRequeueExhausted'] == true) return;

      final category =
          (data['transcodeErrorCategory'] ?? '').toString().trim();
      final existingError = (data['transcodeError'] ?? '').toString().trim();
      if (category == 'permanent' && existingError.isNotEmpty) return;

      final attempts = (data['transcodeAttemptCount'] as num?)?.toInt() ?? 0;
      if (attempts >= _maxAttempts) return;

      await ref.set(
        {
          'legacyRawFallback': true,
          'requestedTranscodeAt': FieldValue.serverTimestamp(),
          'processed': false,
        },
        SetOptions(merge: true),
      );
      AppLogger.info(
        LogCategory.explore,
        'TRANSCODE_QUEUE_REQUEST postId=$postId',
      );
    } catch (e) {
      AppLogger.warning(
        LogCategory.explore,
        'TRANSCODE_QUEUE_REQUEST failed postId=$postId: $e',
      );
    }
  }

  /// Best-effort Firestore flag so [requeueLegacyReel] can transcode reels
  /// that are legacy/raw-only or stuck in processing (common for large iOS 4K).
  Future<void> maybeRequestReelTranscode({
    required String reelId,
    required ResolvedVideoPlayback playback,
  }) async {
    if (reelId.isEmpty) return;
    if (_sessionRequested.contains('reel:$reelId')) return;
    _sessionRequested.add('reel:$reelId');

    try {
      final ref = FirebaseFirestore.instance.collection('reels').doc(reelId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return;
      if (data['processed'] == true) return;
      if (data['transcodeRequeueExhausted'] == true) return;

      final category =
          (data['transcodeErrorCategory'] ?? '').toString().trim();
      final existingError = (data['transcodeError'] ?? '').toString().trim();
      if (category == 'permanent' && existingError.isNotEmpty) return;

      final attempts = (data['transcodeAttemptCount'] as num?)?.toInt() ?? 0;
      if (attempts >= _maxAttempts) return;

      final processing = data['processing'] == true;
      var shouldQueue = playback.legacyRawFallback || playback.status == ReelStatus.processing;

      if (processing) {
        final started = data['transcodeStartedAt'];
        final startedAt = started is Timestamp ? started.toDate() : null;
        if (startedAt != null) {
          final age = DateTime.now().difference(startedAt);
          // Re-nudge only when clearly stale.
          shouldQueue = shouldQueue || age > _stuckProcessingThreshold;
        }
      }

      if (!shouldQueue) return;

      await ref.set(
        {
          'legacyRawFallback': true,
          'requestedTranscodeAt': FieldValue.serverTimestamp(),
          'processed': false,
        },
        SetOptions(merge: true),
      );
      AppLogger.info(
        LogCategory.explore,
        'TRANSCODE_QUEUE_REQUEST reelId=$reelId',
      );
    } catch (e) {
      AppLogger.warning(
        LogCategory.explore,
        'TRANSCODE_QUEUE_REQUEST failed reelId=$reelId: $e',
      );
    }
  }
}
