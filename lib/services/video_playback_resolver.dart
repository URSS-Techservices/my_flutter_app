/// Chooses mobile-safe playback URLs (processed H.264 MP4 / HLS) for posts & reels.
library;

import 'reel_player_lifecycle.dart';

/// Result of [resolveVideoPlayback].
class ResolvedVideoPlayback {
  /// URL to pass to the video player (empty when not ready).
  final String primaryUrl;

  /// Alternate stream when [primaryUrl] fails (often HLS or optimized MP4).
  final String fallbackUrl;

  final bool processed;
  final bool processing;

  const ResolvedVideoPlayback({
    required this.primaryUrl,
    this.fallbackUrl = '',
    this.processed = false,
    this.processing = false,
  });

  bool get isPlayable => primaryUrl.isNotEmpty;

  bool get showProcessingOverlay => processing && !processed && !isPlayable;
}

bool isRawUploadStorageUrl(String url) {
  if (url.isEmpty) return false;
  final lower = url.toLowerCase();
  return lower.contains('videos/raw/') ||
      lower.contains('/videos/raw/') ||
      // Pre-transcode user upload path (camera master file).
      (lower.contains('/posts/') &&
          (lower.contains('/video.mp4') ||
              lower.contains('/video_') && lower.contains('.mp4')));
}

bool _truthy(dynamic v) => v == true || v == 'true';

String _str(dynamic v) => (v ?? '').toString().trim();

/// Picks processed MP4 first (reliable on Firebase Storage), then HLS, then legacy raw.
ResolvedVideoPlayback resolveVideoPlayback({
  required Map<String, dynamic> postData,
  Map<String, dynamic>? mediaItem,
}) {
  final item = mediaItem ?? const <String, dynamic>{};

  final processed =
      _truthy(item['processed']) || _truthy(postData['processed']);
  final processing =
      _truthy(item['processing']) || _truthy(postData['processing']);

  final docMp4 = _str(postData['videoUrl']);
  final docHls = _str(postData['hlsUrl']);
  final itemMp4 = _str(item['videoUrl']).isNotEmpty
      ? _str(item['videoUrl'])
      : _str(item['url']);
  final itemHls = _str(item['hlsUrl']);
  final rawUrl = _str(item['rawVideoUrl']);

  String? pickProcessedMp4() {
    final qualities = item['qualities'] ?? postData['qualities'];
    if (qualities is Map) {
      final q720 = _str(qualities['720']);
      if (q720.isNotEmpty && !q720.contains('.m3u8')) return q720;
    }
    for (final u in [itemMp4, docMp4]) {
      if (u.isEmpty || u.contains('.m3u8')) continue;
      if (isRawUploadStorageUrl(u)) continue;
      if (u.contains('/videos/processed/') ||
          u.contains('optimized_') ||
          u.contains('optimized.mp4') ||
          processed) {
        return u;
      }
    }
    if (processed) {
      for (final u in [itemMp4, docMp4]) {
        if (u.isNotEmpty && !u.contains('.m3u8')) return u;
      }
    }
    return null;
  }

  String? pickHls() {
    for (final u in [itemHls, docHls]) {
      if (u.isNotEmpty && u.contains('.m3u8')) return u;
    }
    return null;
  }

  String? pickMp4Fallback() {
    final mp4 = pickProcessedMp4();
    if (mp4 != null && mp4.isNotEmpty) return mp4;
    return null;
  }

  String? pickRawFallback() {
    final raw = rawUrl;
    if (raw.isNotEmpty && !raw.contains('.m3u8')) return raw;
    for (final u in [itemMp4, docMp4]) {
      if (u.isNotEmpty &&
          !u.contains('.m3u8') &&
          isRawUploadStorageUrl(u)) {
        return u;
      }
    }
    return null;
  }

  final hls = pickHls();
  final mp4Fallback = pickMp4Fallback();
  final rawFallback = pickRawFallback();

  if (processing && !processed) {
    return ResolvedVideoPlayback(
      primaryUrl: '',
      fallbackUrl: '',
      processed: false,
      processing: true,
    );
  }

  if (processed) {
    // Adaptive / legacy: HLS master (or variant) first, MP4 fallback, then raw.
    final primary = (hls != null && hls.isNotEmpty)
        ? hls
        : (mp4Fallback ?? '');
    var fallback = '';
    if (primary.contains('.m3u8')) {
      fallback = mp4Fallback ?? rawFallback ?? '';
    } else if (mp4Fallback != null && mp4Fallback.isNotEmpty) {
      fallback = rawFallback ?? '';
    } else {
      fallback = rawFallback ?? '';
    }
    return ResolvedVideoPlayback(
      primaryUrl: primary,
      fallbackUrl: fallback,
      processed: true,
      processing: false,
    );
  }

  // Legacy documents without transcode — raw first, then any HLS/MP4 on doc.
  final legacy = rawFallback ?? mp4Fallback ?? hls ?? '';
  return ResolvedVideoPlayback(
    primaryUrl: legacy,
    fallbackUrl: (mp4Fallback != null &&
            mp4Fallback.isNotEmpty &&
            mp4Fallback != legacy)
        ? mp4Fallback
        : (hls ?? ''),
    processed: false,
    processing: false,
  );
}

/// Reels playback URLs — platform aware.
///
/// iOS (AVPlayer): processed HLS primary, MP4 / qualities[720] fallback.
/// Android: progressive MP4 first for fast start, HLS fallback.
ResolvedVideoPlayback resolveReelPlayback({
  required Map<String, dynamic> postData,
  Map<String, dynamic>? mediaItem,
}) {
  final base = resolveVideoPlayback(postData: postData, mediaItem: mediaItem);
  if (!base.processed || base.processing) return base;

  // iOS: keep HLS-first from [resolveVideoPlayback] (never raw-first when processed).
  if (ReelPlatformPolicy.isIOS) {
    return base;
  }

  // Android: MP4 before HLS for startup latency.
  final mp4 = base.fallbackUrl;
  final hls = base.primaryUrl;
  if (mp4.isNotEmpty &&
      !mp4.contains('.m3u8') &&
      hls.isNotEmpty &&
      hls.contains('.m3u8')) {
    return ResolvedVideoPlayback(
      primaryUrl: mp4,
      fallbackUrl: hls,
      processed: true,
      processing: false,
    );
  }
  return base;
}

/// Convenience for a [MediaModel]-shaped map inside [postData].
ResolvedVideoPlayback resolveVideoPlaybackForMediaMap(
  Map<String, dynamic> postData,
  Map<String, dynamic> mediaMap,
) =>
    resolveVideoPlayback(postData: postData, mediaItem: mediaMap);
