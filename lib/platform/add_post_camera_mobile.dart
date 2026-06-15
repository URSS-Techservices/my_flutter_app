import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:halo/platform/add_post_full_screen_camera.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> openAddPostCamera(
  BuildContext context, {
  List<CameraDescription>? cameras,
}) {
  final cams = cameras ?? const <CameraDescription>[];
  if (cams.isEmpty) return Future.value();
  return Navigator.push<XFile>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddPostFullScreenCamera(cameras: cams),
    ),
  );
}
