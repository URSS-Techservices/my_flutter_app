import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_info/media_info.dart';

/// Safe upload profile — resolution and FPS caps only.
/// HEVC / HDR / Dolby Vision are allowed; the Cloud Function transcodes them.
class VideoUploadLimits {
  VideoUploadLimits._();

  static const int maxLongEdgePx = 1920;
  static const int maxFps = 60; // Allow 60fps source; Cloud Function caps output to 30fps

  static const String supportedSummary =
      'Video up to 1080p (1920px). HEVC, HDR, and Dolby Vision are accepted '
      'and transcoded automatically.';
}

/// Result of probing a local file before upload.
class VideoUploadProbe {
  final int? width;
  final int? height;
  final int? fps;
  final bool isHevc;
  final bool isHdr;
  final bool isDolbyVision;

  const VideoUploadProbe({
    this.width,
    this.height,
    this.fps,
    this.isHevc = false,
    this.isHdr = false,
    this.isDolbyVision = false,
  });

  int? get longEdge {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w > h ? w : h;
  }

  bool get isExoticCodec => isDolbyVision || isHevc || isHdr;

  bool get exceedsResolution {
    final edge = longEdge;
    return edge != null && edge > VideoUploadLimits.maxLongEdgePx;
  }

  bool get exceedsFps =>
      fps != null && fps! > VideoUploadLimits.maxFps;

  /// Returns the correct MIME type for this video file path.
  static String mimeTypeForPath(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    switch (ext) {
      case 'mov':
        return 'video/quicktime'; // iOS records .mov files
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }
}

/// Why an upload was rejected (user-facing message included).
class VideoUploadRejection {
  final String code;
  final String userMessage;

  const VideoUploadRejection({
    required this.code,
    required this.userMessage,
  });
}

class VideoUploadRejectedException implements Exception {
  final VideoUploadRejection rejection;

  const VideoUploadRejectedException(this.rejection);

  @override
  String toString() => rejection.userMessage;
}

/// Pre-upload validation shared by Add Post and [UploadService].
///
/// ### iOS Fix
/// HEVC / HDR / Dolby Vision are intentionally ALLOWED to upload.
/// iPhones record in HEVC by default (iPhone 7+). The Firebase Cloud Function
/// (FFmpeg `normalizeSource`) handles all exotic codecs and transcodes to
/// H.264 SDR. Rejecting them client-side was blocking all iOS video uploads.
///
/// Only hard limits (extreme resolution > 1920px) are enforced — and even
/// those are advisory since FFmpeg can rescale, but they indicate a file so
/// large that the upload itself would time out on mobile.
class VideoUploadPolicy {
  VideoUploadPolicy._();

  static Future<VideoUploadProbe> probeFile(File videoFile) async {
    try {
      final mediaInfo = MediaInfo();
      final info = await mediaInfo.getMediaInfo(videoFile.path);

      final w = (info['width'] as num?)?.round();
      final h = (info['height'] as num?)?.round();
      final fpsRaw = info['frameRate'];
      int? fps;
      if (fpsRaw is num) {
        fps = fpsRaw.round();
      } else if (fpsRaw is String && fpsRaw.contains('/')) {
        final parts = fpsRaw.split('/');
        final n = double.tryParse(parts[0]) ?? 0;
        final d = double.tryParse(parts[1]) ?? 1;
        if (d > 0) fps = (n / d).round();
      } else if (fpsRaw is String) {
        fps = double.tryParse(fpsRaw)?.round();
      }

      final bytes = await videoFile.openRead(0, 262144).fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      final hex = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toLowerCase();

      final isDolbyVision = hex.contains('64766831') ||
          hex.contains('64766865') ||
          hex.contains('64627931');
      final isHevc =
          hex.contains('68766331') || hex.contains('68657631');
      final isHdr =
          hex.contains('6d646376') || hex.contains('636c6c69');

      return VideoUploadProbe(
        width: w,
        height: h,
        fps: fps,
        isHevc: isHevc,
        isHdr: isHdr,
        isDolbyVision: isDolbyVision,
      );
    } catch (e) {
      debugPrint('[VideoUploadPolicy] probe failed: $e');
      return const VideoUploadProbe();
    }
  }

  /// Returns a rejection only when the file would genuinely fail to upload
  /// (e.g. extreme 4K+ resolution that signals a 2GB+ raw file).
  /// HEVC / HDR / Dolby Vision are NOT rejected — the Cloud Function (FFmpeg)
  /// transcodes them server-side to H.264 SDR for universal playback.
  static VideoUploadRejection? validate(VideoUploadProbe probe) {
    // Log exotic codecs for diagnostics but allow upload.
    if (probe.isExoticCodec) {
      debugPrint(
        '[VideoUploadPolicy] exotic codec '
        '(hevc=${probe.isHevc} hdr=${probe.isHdr} dv=${probe.isDolbyVision}) '
        '— allowed; Cloud Function will transcode to H.264 SDR.',
      );
    }

    // Only hard-block absurdly large sources (> 1920px long edge at source).
    // This is a proxy for "file is too big to upload on mobile" (likely 4K raw).
    if (probe.exceedsResolution) {
      final edge = probe.longEdge;
      return VideoUploadRejection(
        code: 'resolution',
        userMessage:
            'Video resolution is too high (${edge ?? '?'}px long edge). '
            'Please export at 1080p or lower and try again.',
      );
    }

    return null;
  }

  static Future<VideoUploadRejection?> validateFile(File videoFile) async {
    final probe = await probeFile(videoFile);
    debugPrint(
      '[VideoUploadPolicy] ${probe.width}x${probe.height} fps=${probe.fps} '
      'hevc=${probe.isHevc} hdr=${probe.isHdr} dv=${probe.isDolbyVision}',
    );
    return validate(probe);
  }
}
