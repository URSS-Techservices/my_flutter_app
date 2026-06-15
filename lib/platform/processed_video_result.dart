import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Result of gallery/camera video processing before adding to a post draft.
class ProcessedVideoResult {
  final XFile file;
  final Uint8List? coverBytes;
  final int trimStartMs;
  final int trimEndMs;

  /// Populated on web when uploads use bytes instead of filesystem paths.
  final Uint8List? videoBytes;

  const ProcessedVideoResult({
    required this.file,
    this.coverBytes,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
    this.videoBytes,
  });
}
