import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_info/media_info.dart';

/// Safe upload profile until 4K / exotic codecs are officially supported.
class VideoUploadLimits {
  VideoUploadLimits._();

  static const int maxLongEdgePx = 1920;
  static const int maxFps = 30;

  static const String supportedSummary =
      'H.264 SDR video up to 1080p (1920px) at 30 fps or lower.';
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

  /// Returns a rejection when the file is outside the safe profile, else null.
  static VideoUploadRejection? validate(VideoUploadProbe probe) {
    if (probe.isDolbyVision) {
      return const VideoUploadRejection(
        code: 'dolby_vision',
        userMessage:
            'Dolby Vision is not supported yet. Export as H.264 SDR (up to 1080p30) and try again.',
      );
    }
    if (probe.isHevc) {
      return const VideoUploadRejection(
        code: 'hevc',
        userMessage:
            'HEVC (H.265) is not supported yet. Use H.264 SDR up to 1080p30.',
      );
    }
    if (probe.isHdr) {
      return const VideoUploadRejection(
        code: 'hdr',
        userMessage:
            'HDR video is not supported yet. Turn off HDR or export as H.264 SDR up to 1080p30.',
      );
    }
    if (probe.exceedsResolution) {
      final edge = probe.longEdge;
      return VideoUploadRejection(
        code: 'resolution',
        userMessage:
            'Video is too large (${edge ?? '?'}px). Maximum long edge is '
            '${VideoUploadLimits.maxLongEdgePx}px (1080p class).',
      );
    }
    if (probe.exceedsFps) {
      return VideoUploadRejection(
        code: 'fps',
        userMessage:
            'Frame rate is too high (${probe.fps} fps). Maximum is '
            '${VideoUploadLimits.maxFps} fps.',
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
