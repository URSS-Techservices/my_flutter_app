import 'dart:typed_data';

/// Cross-platform media picked from gallery/camera before upload.
class PickedMedia {
  final Uint8List bytes;
  final String name;
  final String? mimeType;

  /// Optional local path (mobile gallery/camera; may be empty on web).
  final String path;

  const PickedMedia({
    required this.bytes,
    required this.name,
    required this.path,
    this.mimeType,
  });

  int get length => bytes.length;
}
