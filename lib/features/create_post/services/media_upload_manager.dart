import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/services/app_logger.dart';
import 'package:halo/services/upload_service.dart';
import 'package:halo/services/video_upload_policy.dart';

/// Uploads a post's media with bounded concurrency, per-asset retry, and
/// real byte progress — instead of one unbounded `Future.wait` or a blind
/// sequential loop.
///
/// A failure on one asset never blocks or restarts the others: each asset
/// gets its own retry budget, and [uploadAll] always returns (never throws)
/// so the caller can show exactly which items failed.
class MediaUploadManager {
  MediaUploadManager({int maxConcurrent = 3}) : _maxConcurrent = maxConcurrent;

  final int _maxConcurrent;
  final UploadService _uploadService = UploadService();
  static const int _maxAttemptsPerAsset = 3;

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<List<MediaAsset>> uploadAll({
    required List<MediaAsset> assets,
    required String postId,
    required void Function(MediaAsset updated) onUpdate,
  }) async {
    final results = <String, MediaAsset>{for (final a in assets) a.id: a};
    final pending = assets.where((a) => !a.isUploaded).toList();

    final kindIndex = <String, int>{};
    var imageIndex = 0;
    var videoIndex = 0;
    for (final a in assets) {
      kindIndex[a.id] = a.isVideo ? videoIndex++ : imageIndex++;
    }

    var cursor = 0;
    Future<void> worker() async {
      while (!_cancelled) {
        if (cursor >= pending.length) return;
        final asset = pending[cursor];
        cursor++;
        await _uploadOne(asset, postId, kindIndex[asset.id]!, results, onUpdate);
      }
    }

    final workerCount = _maxConcurrent < pending.length ? _maxConcurrent : pending.length;
    if (workerCount > 0) {
      await Future.wait(List.generate(workerCount, (_) => worker()));
    }

    return assets.map((a) => results[a.id]!).toList();
  }

  Future<void> _uploadOne(
    MediaAsset asset,
    String postId,
    int kindIndex,
    Map<String, MediaAsset> results,
    void Function(MediaAsset) onUpdate,
  ) async {
    var current = asset.copyWith(status: MediaStatus.uploading, uploadProgress: 0, clearError: true);
    results[asset.id] = current;
    onUpdate(current);

    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttemptsPerAsset; attempt++) {
      if (_cancelled) return;
      try {
        void reportProgress(double p) {
          current = current.copyWith(uploadProgress: p);
          results[asset.id] = current;
          onUpdate(current);
        }

        final uploadResult = asset.isVideo
            ? await _uploadService.uploadVideoWithThumbnail(
                videoFile: asset.fileToUpload,
                postId: postId,
                index: kindIndex,
                thumbnailBytes: asset.coverBytes,
                trimStartMs: asset.trimStart?.inMilliseconds,
                trimEndMs: asset.trimEnd?.inMilliseconds,
                onProgress: reportProgress,
              )
            : await _uploadService.uploadAdaptivePostImage(
                imageFile: asset.fileToUpload,
                postId: postId,
                index: kindIndex,
                maxWidth: asset.qualityProfile?.imageMaxWidth,
                onProgress: reportProgress,
              );

        current = current.copyWith(
          status: MediaStatus.uploaded,
          uploadProgress: 1,
          uploadResult: uploadResult,
          clearError: true,
        );
        results[asset.id] = current;
        onUpdate(current);
        return;
      } catch (e) {
        lastError = e;
        AppLogger.warning(
          LogCategory.general,
          'MEDIA_UPLOAD attempt=$attempt/$_maxAttemptsPerAsset assetId=${asset.id} failed: $e',
        );
        if (attempt < _maxAttemptsPerAsset) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    current = current.copyWith(status: MediaStatus.failed, error: _messageFor(lastError));
    results[asset.id] = current;
    onUpdate(current);
  }

  String _messageFor(Object? error) {
    if (error is VideoUploadRejectedException) return error.rejection.userMessage;
    if (error == null) return 'Upload failed. Please try again.';
    return 'Upload failed: check your connection and try again.';
  }
}
