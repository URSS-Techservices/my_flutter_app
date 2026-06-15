import 'package:flutter/material.dart';
import 'package:halo/platform/processed_video_result.dart';
import 'package:image_picker/image_picker.dart';

/// Web video flow — skip native trim/thumbnail tools; upload raw pick.
Future<ProcessedVideoResult?> runVideoPostFlow(
  BuildContext context,
  XFile picked,
) async {
  final bytes = await picked.readAsBytes();
  return ProcessedVideoResult(
    file: picked,
    videoBytes: bytes,
  );
}
