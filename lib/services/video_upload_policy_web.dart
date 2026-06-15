import 'package:flutter/foundation.dart';

/// Safe upload profile until 4K / exotic codecs are officially supported.
class VideoUploadLimits {
  VideoUploadLimits._();

  static const int maxLongEdgePx = 1920;
  static const int maxFps = 30;

  static const String supportedSummary =
      'H.264 SDR video up to 1080p (1920px) at 30 fps or lower.';
}

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

  bool get exceedsFps => fps != null && fps! > VideoUploadLimits.maxFps;
}

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

class VideoUploadPolicy {
  VideoUploadPolicy._();

  static Future<VideoUploadProbe> probeBytes(List<int> bytes) async {
    try {
      final sample = bytes.length > 262144 ? bytes.sublist(0, 262144) : bytes;
      final hex = sample
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
        isHevc: isHevc,
        isHdr: isHdr,
        isDolbyVision: isDolbyVision,
      );
    } catch (e) {
      debugPrint('[VideoUploadPolicy] probeBytes failed: $e');
      return const VideoUploadProbe();
    }
  }

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
}
