import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:halo/Bottom Pages/video_quick_edit_page.dart';
import 'package:halo/Bottom Pages/video_thumbnail_picker.dart';
import 'package:halo/platform/processed_video_result.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile video pick flow — trim/edit + thumbnail (unchanged).
Future<ProcessedVideoResult?> runVideoPostFlow(
  BuildContext context,
  XFile picked,
) async {
  final edited = await Navigator.push<VideoQuickEditResult>(
    context,
    MaterialPageRoute(
      builder: (_) => VideoQuickEditPage(file: File(picked.path)),
    ),
  );
  if (edited == null) return null;

  final thumbBytes = await Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      builder: (_) => VideoThumbnailPicker(videoPath: edited.file.path),
    ),
  );

  return ProcessedVideoResult(
    file: XFile(edited.file.path),
    coverBytes: thumbBytes ?? edited.coverBytes,
    trimStartMs: edited.trimStartMs,
    trimEndMs: edited.trimEndMs,
  );
}
