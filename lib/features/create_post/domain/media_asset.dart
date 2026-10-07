import 'dart:io';
import 'dart:typed_data';

import 'media_quality_profile.dart';

/// What kind of file a [MediaAsset] wraps.
enum MediaKind { image, video }

/// Lifecycle of a single selected media file, from pick to upload.
///
/// `selected -> validating -> (editing) -> processing -> ready -> queued ->
/// uploading -> uploaded`, or `-> failed` from validating/processing/uploading.
/// A failed asset can be retried without re-running steps that already
/// succeeded (e.g. a failed upload keeps its already-compressed [processedFile]).
enum MediaStatus {
  selected,
  validating,
  processing,
  ready,
  queued,
  uploading,
  uploaded,
  failed,
}

/// One photo or video the user has added to a post draft.
///
/// [originalFile] is never deleted or overwritten so a failed processing step
/// can always be retried from the untouched source.
class MediaAsset {
  final String id;
  final MediaKind kind;
  final File originalFile;
  final File? processedFile;
  final Uint8List? coverBytes;
  final int? width;
  final int? height;
  final Duration? trimStart;
  final Duration? trimEnd;
  final MediaStatus status;
  final double uploadProgress;
  final Map<String, dynamic>? uploadResult;
  final String? error;
  final MediaQualityProfile? qualityProfile;

  const MediaAsset({
    required this.id,
    required this.kind,
    required this.originalFile,
    this.processedFile,
    this.coverBytes,
    this.width,
    this.height,
    this.trimStart,
    this.trimEnd,
    this.status = MediaStatus.selected,
    this.uploadProgress = 0,
    this.uploadResult,
    this.error,
    this.qualityProfile,
  });

  /// The file that should actually be uploaded: the processed/compressed
  /// output when one exists, otherwise the original.
  File get fileToUpload => processedFile ?? originalFile;

  bool get isVideo => kind == MediaKind.video;
  bool get isImage => kind == MediaKind.image;
  bool get isFailed => status == MediaStatus.failed;
  bool get isUploaded => status == MediaStatus.uploaded;
  bool get isTerminal => status == MediaStatus.uploaded || status == MediaStatus.failed;

  MediaAsset copyWith({
    File? processedFile,
    bool clearProcessedFile = false,
    Uint8List? coverBytes,
    int? width,
    int? height,
    Duration? trimStart,
    Duration? trimEnd,
    MediaStatus? status,
    double? uploadProgress,
    Map<String, dynamic>? uploadResult,
    String? error,
    bool clearError = false,
    MediaQualityProfile? qualityProfile,
  }) {
    return MediaAsset(
      id: id,
      kind: kind,
      originalFile: originalFile,
      processedFile: clearProcessedFile ? null : (processedFile ?? this.processedFile),
      coverBytes: coverBytes ?? this.coverBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadResult: uploadResult ?? this.uploadResult,
      error: clearError ? null : (error ?? this.error),
      qualityProfile: qualityProfile ?? this.qualityProfile,
    );
  }
}
