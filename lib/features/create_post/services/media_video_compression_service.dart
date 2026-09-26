import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:light_compressor/light_compressor.dart';
import 'package:path_provider/path_provider.dart';

import 'package:halo/features/create_post/domain/media_quality_profile.dart';
import 'package:halo/services/app_logger.dart';

/// Wraps `light_compressor` with a graceful fallback: any native failure,
/// cancellation, an unsupported platform (web/desktop), or an output that
/// isn't actually smaller falls back to returning the original file so the
/// upload step always has something valid to send.
class MediaVideoCompressionService {
  final LightCompressor _compressor = LightCompressor();

  Future<File> compress(File source, MediaQualityProfile profile) async {
    if (kIsWeb) return source;

    try {
      final dir = await getTemporaryDirectory();
      final destinationPath =
          '${dir.path}/post_video_${DateTime.now().microsecondsSinceEpoch}.mp4';

      final response = await _compressor.compressVideo(
        path: source.path,
        destinationPath: destinationPath,
        videoQuality: profile.videoQuality,
        isMinBitrateCheckEnabled: true,
      );

      if (response is OnSuccess) {
        final output = File(response.destinationPath);
        if (!await output.exists()) return source;
        final originalSize = await source.length();
        final outputSize = await output.length();
        AppLogger.info(
          LogCategory.general,
          'VIDEO_COMPRESS ok profile=${profile.name} original=$originalSize output=$outputSize',
        );
        // A "compressed" file that isn't actually smaller isn't useful.
        return outputSize > 0 && outputSize < originalSize ? output : source;
      }

      if (response is OnFailure) {
        AppLogger.warning(
          LogCategory.general,
          'VIDEO_COMPRESS failed profile=${profile.name}: ${response.message}',
        );
      }
      return source;
    } catch (e) {
      AppLogger.warning(LogCategory.general, 'VIDEO_COMPRESS threw: $e');
      return source;
    }
  }
}
