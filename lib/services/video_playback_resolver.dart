/// Reel / post playback resolver.
///
/// Priority chain (ALWAYS evaluated in this order, NEVER returns "" when a
/// usable URL exists):
///
///   1. processed HLS (master.m3u8)        → ReelStatus.readyHls
///   2. processed optimized MP4            → ReelStatus.readyMp4
///   3. raw upload (legacy / in-progress)  → ReelStatus.processing
///                                            (sets legacyRawFallback=true)
///   4. nothing                            → ReelStatus.missingVideo
///                                            (UI must show poster + retry)
///
/// We NEVER return an empty `primaryUrl` if any non-m3u8 URL exists on the
/// reel — that was the bug that produced "blank player + bind reel url=".
library;

import 'package:flutter/foundation.dart';

import 'blocked_url_memory.dart';

/// Maximum source dimensions we'll *attempt* to play from a raw upload when
/// metadata IS present and exceeds capability — anything bigger (true 4K /
/// 60fps) is blocked outright.
///
/// When metadata is MISSING we now optimistically attempt playback (legacy
/// uploads almost universally lack width/height fields). If ExoPlayer reports
/// `NO_EXCEEDS_CAPABILITIES`, the URL is recorded in [BlockedUrlMemory] so we
/// never re-attempt it. This mirrors how Instagram handles legacy content.
const int kMaxRawPlaybackWidth = 1920;
const int kMaxRawPlaybackHeight = 1920;
const int kMaxRawPlaybackFps = 31;

/// Explicit reel lifecycle states the UI can switch on.
enum ReelStatus {
  /// Master HLS playlist resolved — adaptive playback.
  readyHls,

  /// Processed optimized MP4 resolved — single-bitrate playback.
  readyMp4,

  /// Falling back to raw upload because no processed asset exists yet
  /// (Cloud Function still running OR legacy reel uploaded before transcode).
  processing,

  /// Transcode finished with `transcodeError` — UI shows retry button.
  failedTranscode,

  /// Reel doc has no usable video URL at all — UI shows poster + "Video unavailable".
  missingVideo,

  /// Resolver attempted but DNS / fetch was offline — UI shows "No connection".
  noNetwork,
}

extension ReelStatusX on ReelStatus {
  String get tag {
    switch (this) {
      case ReelStatus.readyHls:
        return 'READY_HLS';
      case ReelStatus.readyMp4:
        return 'READY_MP4';
      case ReelStatus.processing:
        return 'PROCESSING';
      case ReelStatus.failedTranscode:
        return 'FAILED_TRANSCODE';
      case ReelStatus.missingVideo:
        return 'MISSING_VIDEO';
      case ReelStatus.noNetwork:
        return 'NO_NETWORK';
    }
  }

  bool get hasPlayableUrl =>
      this == ReelStatus.readyHls ||
      this == ReelStatus.readyMp4 ||
      this == ReelStatus.processing;
}

class ResolvedVideoPlayback {
  final String primaryUrl;
  final String fallbackUrl;
  final bool processed;
  final bool processing;
  final ReelStatus status;
  final String? blockedReason;
  final int? sourceWidth;
  final int? sourceHeight;
  final int? sourceFps;

  /// True when we're feeding the raw upload to the player because no
  /// processed asset exists yet. Background tasks may want to re-queue
  /// transcoding when they see this flag.
  final bool legacyRawFallback;

  const ResolvedVideoPlayback({
    required this.primaryUrl,
    this.fallbackUrl = '',
    this.processed = false,
    this.processing = false,
    this.status = ReelStatus.missingVideo,
    this.blockedReason,
    this.sourceWidth,
    this.sourceHeight,
    this.sourceFps,
    this.legacyRawFallback = false,
  });

  bool get isPlayable => primaryUrl.isNotEmpty;

  /// Show the "Processing video…" overlay only when:
  ///   * we have NO URL at all, AND
  ///   * the doc says transcoding is in progress.
  ///
  /// If we have a raw URL we play it instead — no overlay, no black surface.
  bool get showProcessingOverlay =>
      !isPlayable && status == ReelStatus.processing;

  /// Show "Video unavailable" + retry button.
  bool get showMissingOverlay => !isPlayable &&
      (status == ReelStatus.missingVideo ||
          status == ReelStatus.failedTranscode);
}

class VideoSourceMetadata {
  final int? width;
  final int? height;
  final int? fps;

  const VideoSourceMetadata({this.width, this.height, this.fps});

  static VideoSourceMetadata fromMaps(
    Map<String, dynamic> item,
    Map<String, dynamic> postData,
  ) {
    int? readInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v.toString());
    }

    final w = readInt(
      item['intrinsicWidth'] ??
          item['sourceWidth'] ??
          item['width'] ??
          item['videoWidth'] ??
          postData['sourceWidth'] ??
          postData['videoWidth'],
    );
    final h = readInt(
      item['intrinsicHeight'] ??
          item['sourceHeight'] ??
          item['height'] ??
          item['videoHeight'] ??
          postData['sourceHeight'] ??
          postData['videoHeight'],
    );
    final fps = readInt(
      item['sourceFps'] ??
          item['fps'] ??
          item['frameRate'] ??
          postData['sourceFps'] ??
          postData['fps'],
    );
    return VideoSourceMetadata(width: w, height: h, fps: fps);
  }

  /// Optimistic gate: allow raw playback unless we have HARD evidence the
  /// file exceeds device capability. Missing metadata = "try it" (Instagram
  /// strategy). If ExoPlayer actually crashes, the player records the URL in
  /// [BlockedUrlMemory] and the next attempt is blocked locally.
  bool get allowsRawPlayback {
    final w = width;
    final h = height;
    if (w != null && h != null && w > 0 && h > 0) {
      final longEdge = w > h ? w : h;
      if (longEdge > kMaxRawPlaybackWidth) return false;
    }
    if (fps != null && fps! > kMaxRawPlaybackFps) return false;
    return true;
  }

  String? get rawBlockReason {
    final w = width;
    final h = height;
    if (w != null && h != null) {
      final longEdge = (w > h) ? w : h;
      if (longEdge > kMaxRawPlaybackWidth) {
        return 'resolution_exceeds_$kMaxRawPlaybackWidth';
      }
    }
    if (fps != null && fps! > kMaxRawPlaybackFps) {
      return 'fps_exceeds_$kMaxRawPlaybackFps';
    }
    return null;
  }
}

/// Codec / dynamic-range hints stored on the post doc by the upload service
/// (and refined later by Cloud Function `probeVideo`). Returning `true` means
/// the file is exotic enough that we must NOT play raw — only HLS.
bool _hasExoticCodecHints(Map<String, dynamic> item, Map<String, dynamic> post) {
  bool flag(String key) =>
      _truthy(item[key]) || _truthy(post[key]);
  if (flag('isHevc') || flag('hevc')) return true;
  if (flag('isHdr') || flag('hdr')) return true;
  if (flag('isDolbyVision') || flag('dolbyVision')) return true;
  final codec =
      '${_str(item['codec']).toLowerCase()} ${_str(post['codec']).toLowerCase()}';
  if (codec.contains('hevc') || codec.contains('h265') ||
      codec.contains('dvhe') || codec.contains('dvh1') ||
      codec.contains('prores') || codec.contains('av1')) {
    return true;
  }
  return false;
}

bool isRawUploadStorageUrl(String url) {
  if (url.isEmpty) return false;
  final lower = url.toLowerCase();
  return lower.contains('videos/raw/') ||
      lower.contains('/videos/raw/') ||
      (lower.contains('/posts/') &&
          (lower.contains('/video.mp4') ||
              (lower.contains('/video_') && lower.contains('.mp4'))));
}

bool isProcessedOutputUrl(String url) {
  if (url.isEmpty) return false;
  final lower = url.toLowerCase();
  if (lower.contains('/videos/processed/')) return true;
  if (lower.contains('optimized_') || lower.contains('optimized.mp4')) {
    return true;
  }
  if (lower.contains('master.m3u8')) return true;
  if (lower.contains('.m3u8') && !isLegacyOrInvalidHlsUrl(url)) return true;
  return false;
}

bool isLegacyOrInvalidHlsUrl(String url) {
  if (url.isEmpty || !url.contains('.m3u8')) return true;
  final lower = url.toLowerCase();
  if (lower.contains('index.m3u8')) return true;
  if (lower.contains('/hls/playlist.m3u8')) return true;
  if (lower.contains('playlist.m3u8') && !lower.contains('master.m3u8')) {
    return true;
  }
  return false;
}

bool isAdaptiveMasterHls(String url) {
  if (url.isEmpty) return false;
  return url.toLowerCase().contains('master.m3u8');
}

bool _truthy(dynamic v) => v == true || v == 'true';

String _str(dynamic v) => (v ?? '').toString().trim();

String _shortUrl(String url) {
  if (url.isEmpty) return '';
  return url.length <= 80 ? url : '${url.substring(0, 80)}…';
}

String? pickProcessedHls(
  Map<String, dynamic> item,
  Map<String, dynamic> postData,
) {
  final itemHls = _str(item['hlsUrl']);
  final docHls = _str(postData['hlsUrl']);
  String? fallbackVariant;
  for (final u in [itemHls, docHls]) {
    if (u.isEmpty || !u.contains('.m3u8')) continue;
    if (isLegacyOrInvalidHlsUrl(u)) continue;
    if (isAdaptiveMasterHls(u)) return u;
    fallbackVariant ??= u;
  }
  return fallbackVariant;
}

String? pickProcessedMp4(
  Map<String, dynamic> item,
  Map<String, dynamic> postData,
) {
  final qualities = item['qualities'] ?? postData['qualities'];
  if (qualities is Map) {
    final q720 = _str(qualities['720']);
    if (q720.isNotEmpty && !q720.contains('.m3u8')) return q720;
    final q480 = _str(qualities['480']);
    if (q480.isNotEmpty && !q480.contains('.m3u8')) return q480;
    final q1080 = _str(qualities['1080']);
    if (q1080.isNotEmpty && !q1080.contains('.m3u8')) return q1080;
  }
  final docMp4 = _str(postData['videoUrl']);
  final itemMp4 = _str(item['videoUrl']).isNotEmpty
      ? _str(item['videoUrl'])
      : _str(item['url']);
  for (final u in [itemMp4, docMp4]) {
    if (u.isEmpty || u.contains('.m3u8')) continue;
    if (isRawUploadStorageUrl(u)) continue;
    if (!isProcessedOutputUrl(u)) continue;
    return u;
  }
  return null;
}

String? pickRawFallback(
  Map<String, dynamic> item,
  Map<String, dynamic> postData,
) {
  // rawVideoUrl is the definitive raw source — always check it first.
  final rawUrl = _str(item['rawVideoUrl']);
  if (rawUrl.isNotEmpty && !rawUrl.contains('.m3u8')) return rawUrl;

  // Only use videoUrl/url as fallback if they are not empty placeholders.
  // upload_service sets videoUrl='' for exotic videos intentionally —
  // an empty videoUrl must never be promoted to a playable URL.
  final candidates = <String>[
    _str(item['videoUrl']),
    _str(item['url']),
    _str(postData['videoUrl']),
  ];
  for (final u in candidates) {
    if (u.isEmpty || u.contains('.m3u8')) continue;
    return u;
  }
  return null;
}

/// Internal: shared chain used by both `resolveVideoPlayback` and
/// `resolveReelPlayback`. Guarantees a non-empty `primaryUrl` whenever ANY
/// non-m3u8 URL exists on the post.
ResolvedVideoPlayback _resolveChain({
  required Map<String, dynamic> item,
  required Map<String, dynamic> postData,
  required String context,
}) {
  final meta = VideoSourceMetadata.fromMaps(item, postData);

  final processed =
      _truthy(item['processed']) ||
          _truthy(postData['processed']);

  final processing =
      _truthy(item['processing']) ||
          _truthy(postData['processing']);

  final transcodeError =
      _str(item['transcodeError']).isNotEmpty ||
          _str(postData['transcodeError']).isNotEmpty;

  final hls = pickProcessedHls(item, postData);
  final mp4 = pickProcessedMp4(item, postData);
  final raw = pickRawFallback(item, postData);

  // ─────────────────────────────
  // 1. HLS (highest priority)
  // ─────────────────────────────
  if (hls != null && hls.isNotEmpty) {
    debugPrint(
      '[HLS_SELECTED] $context ${_shortUrl(hls)}',
    );

    return ResolvedVideoPlayback(
      primaryUrl: hls,
      fallbackUrl: mp4 ?? '',
      processed: true,
      processing: false,
      status: ReelStatus.readyHls,
      sourceWidth: meta.width,
      sourceHeight: meta.height,
      sourceFps: meta.fps,
    );
  }

  // ─────────────────────────────
  // 2. Processed MP4 fallback
  // ─────────────────────────────
  if (mp4 != null && mp4.isNotEmpty) {
    debugPrint(
      '[PROCESSED_SELECTED] $context ${_shortUrl(mp4)}',
    );

    return ResolvedVideoPlayback(
      primaryUrl: mp4,
      fallbackUrl: '',
      processed: true,
      processing: false,
      status: ReelStatus.readyMp4,
      sourceWidth: meta.width,
      sourceHeight: meta.height,
      sourceFps: meta.fps,
    );
  }

  // ─────────────────────────────
  // 3. Raw upload fallback (legacy / in-progress).
  //
  // We OPTIMISTICALLY play the raw upload unless we have hard evidence
  // it will crash the decoder:
  //   * metadata explicitly says it's > FHD / > 30fps
  //   * codec hints say HEVC / Dolby Vision / HDR / ProRes / AV1
  //   * we previously crashed ExoPlayer on this exact URL
  //   * upload_service deliberately blanked videoUrl='' for an exotic file
  //
  // The "always wait" approach blocked EVERY non-transcoded reel from
  // playing — including plain 1080p H.264 selfies that ExoPlayer handles
  // perfectly. Most legacy reels are exactly that, so we mirror
  // Instagram's try-then-fallback strategy here.
  // ─────────────────────────────
  if (raw != null && raw.isNotEmpty) {
    final isLegacy = !processing && !processed;
    final exoticCodec = _hasExoticCodecHints(item, postData);
    final metaSaysBad = !meta.allowsRawPlayback;
    final knownBad = BlockedUrlMemory.instance.contains(raw);

    // uploadServiceBlocked: upload_service set videoUrl='' intentionally
    // because it probed the file as exotic (Dolby Vision / HEVC / HDR / 4K).
    // `raw` came from rawVideoUrl in that case — never play it directly.
    final videoUrlField = _str(item['videoUrl']);
    final urlField = _str(item['url']);
    final uploadServiceBlocked =
        processing &&
        videoUrlField.isEmpty &&
        urlField.isEmpty &&
        raw == _str(item['rawVideoUrl']);

    final mustBlock =
        metaSaysBad || exoticCodec || knownBad || uploadServiceBlocked;

    if (!mustBlock) {
      debugPrint(
        '[RAW_FALLBACK] $context legacy=$isLegacy '
        'processing=$processing processed=$processed '
        'meta=${meta.width}x${meta.height}@${meta.fps} ${_shortUrl(raw)}',
      );
      return ResolvedVideoPlayback(
        primaryUrl: raw,
        fallbackUrl: '',
        processed: processed,
        processing: processing,
        status: processed ? ReelStatus.readyMp4 : ReelStatus.processing,
        blockedReason: 'raw_fallback',
        legacyRawFallback: isLegacy,
        sourceWidth: meta.width,
        sourceHeight: meta.height,
        sourceFps: meta.fps,
      );
    }

    final reason = knownBad
        ? 'prev_decoder_crash'
        : uploadServiceBlocked
            ? 'upload_service_blocked'
            : (meta.rawBlockReason ??
                (exoticCodec ? 'exotic_codec' : 'unknown'));
    debugPrint(
      '[RAW_BLOCKED] $context legacy=$isLegacy reason=$reason '
      'size=${meta.width}x${meta.height}@${meta.fps} ${_shortUrl(raw)}',
    );
    return ResolvedVideoPlayback(
      primaryUrl: '',
      fallbackUrl: '',
      processed: processed,
      processing: true,
      status: ReelStatus.processing,
      blockedReason: reason,
      legacyRawFallback: isLegacy,
      sourceWidth: meta.width,
      sourceHeight: meta.height,
      sourceFps: meta.fps,
    );
  }

  // ─────────────────────────────
  // 4. Failed transcode
  // ─────────────────────────────
  if (transcodeError) {
    debugPrint(
      '[FAILED_TRANSCODE] $context',
    );

    return ResolvedVideoPlayback(
      primaryUrl: '',
      fallbackUrl: '',
      processed: false,
      processing: false,
      status: ReelStatus.failedTranscode,
      blockedReason: 'transcode_error',
      sourceWidth: meta.width,
      sourceHeight: meta.height,
      sourceFps: meta.fps,
    );
  }

  // ─────────────────────────────
  // 5. Missing video
  // ─────────────────────────────
  debugPrint(
    '[MISSING_VIDEO] $context',
  );

  return ResolvedVideoPlayback(
    primaryUrl: '',
    fallbackUrl: '',
    processed: processed,
    processing: processing,
    status: ReelStatus.missingVideo,
    blockedReason: 'missing_video',
    sourceWidth: meta.width,
    sourceHeight: meta.height,
    sourceFps: meta.fps,
  );
}

ResolvedVideoPlayback resolveVideoPlayback({
  required Map<String, dynamic> postData,
  Map<String, dynamic>? mediaItem,
}) =>
    _resolveChain(
      item: mediaItem ?? const <String, dynamic>{},
      postData: postData,
      context: 'post',
    );

ResolvedVideoPlayback resolveReelPlayback({
  required Map<String, dynamic> postData,
  Map<String, dynamic>? mediaItem,
}) =>
    _resolveChain(
      item: mediaItem ?? const <String, dynamic>{},
      postData: postData,
      context: 'reel',
    );

ResolvedVideoPlayback resolveVideoPlaybackForMediaMap(
  Map<String, dynamic> postData,
  Map<String, dynamic> mediaMap,
) =>
    resolveVideoPlayback(postData: postData, mediaItem: mediaMap);

/// Kept for compat — never blocks a URL now; instant playback wins.
bool shouldBlockPlaybackUrl(
  String url, {
  required Map<String, dynamic> postData,
  Map<String, dynamic>? mediaItem,
}) {
  return url.trim().isEmpty;
}
