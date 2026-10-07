import 'package:light_compressor/light_compressor.dart';

/// User-facing upload quality choice for a large media file.
///
/// Naming deliberately avoids "Original" / "Compressed" — [highQuality] is
/// still optimized (right-sized WebP tiers for images, a light bitrate trim
/// for video), it just keeps the most detail of the three options.
enum MediaQualityProfile {
  highQuality,
  balanced,
  dataSaver;

  String get label {
    switch (this) {
      case MediaQualityProfile.highQuality:
        return 'High Quality';
      case MediaQualityProfile.balanced:
        return 'Balanced';
      case MediaQualityProfile.dataSaver:
        return 'Data Saver';
    }
  }

  String get description {
    switch (this) {
      case MediaQualityProfile.highQuality:
        return 'Best visual quality, larger upload';
      case MediaQualityProfile.balanced:
        return 'Good quality with a smaller file';
      case MediaQualityProfile.dataSaver:
        return 'Faster upload, less mobile data';
    }
  }

  /// Maps this profile to a [VideoQuality] for `light_compressor`.
  VideoQuality get videoQuality {
    switch (this) {
      case MediaQualityProfile.highQuality:
        return VideoQuality.high;
      case MediaQualityProfile.balanced:
        return VideoQuality.medium;
      case MediaQualityProfile.dataSaver:
        return VideoQuality.low;
    }
  }

  /// Caps the highest-resolution WebP tier [ImageService] generates.
  /// `null` means "no extra cap" (use whatever the image's own size implies).
  int? get imageMaxWidth {
    switch (this) {
      case MediaQualityProfile.highQuality:
        return null;
      case MediaQualityProfile.balanced:
        return 720;
      case MediaQualityProfile.dataSaver:
        return 300;
    }
  }
}

/// Central place for the "is this file big enough to bother the user with a
/// choice" thresholds, instead of hardcoding a number in the UI.
class MediaQualityThresholds {
  MediaQualityThresholds._();

  /// Videos at or under this size are optimized automatically at
  /// [MediaQualityProfile.balanced] with no dialog shown.
  static const int videoAutoOptimizeBytes = 60 * 1024 * 1024; // 60 MB

  /// Images at or under this size skip the quality dialog entirely; the
  /// adaptive tiers from [ImageService] are already appropriately sized.
  static const int imageAutoOptimizeBytes = 15 * 1024 * 1024; // 15 MB

  /// Hard cap regardless of profile — matches [VideoUploadLimits] duration
  /// expectations elsewhere in the app.
  static const Duration maxVideoDuration = Duration(minutes: 3);
}
