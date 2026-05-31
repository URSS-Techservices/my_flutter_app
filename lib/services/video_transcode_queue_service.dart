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
}
