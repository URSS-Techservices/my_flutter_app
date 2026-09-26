import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:halo/Bottom Pages/full_screen_camera_page.dart';
import 'package:halo/Bottom Pages/video_quick_edit_page.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/domain/media_quality_profile.dart';

enum CameraAccess { granted, denied, permanentlyDenied }

const _videoExtensions = ['.mp4', '.mov', '.m4v', '.webm'];

/// Orchestrates media selection: gallery pick, lazy camera capture, and
/// wiring picked/captured video into the existing trim/cover editor.
///
/// Camera permission and `availableCameras()` are only ever requested from
/// [captureFromCamera] — never eagerly — so opening Create Post never touches
/// the camera.
class MediaPickerService {
  final ImagePicker _picker = ImagePicker();
  final _random = Random();

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 31)}';

  bool _looksLikeVideo(String path) {
    final lower = path.toLowerCase();
    return _videoExtensions.any(lower.endsWith);
  }

  Future<List<MediaAsset>> pickImagesFromGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 100);
    return images
        .map((x) => MediaAsset(id: _newId(), kind: MediaKind.image, originalFile: File(x.path)))
        .toList();
  }

  Future<MediaAsset?> pickVideoFromGallery(BuildContext context) async {
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: MediaQualityThresholds.maxVideoDuration,
    );
    if (video == null) return null;
    if (!context.mounted) return null;
    return _editVideo(context, File(video.path));
  }

  /// Camera capture always enables audio (for video), so both permissions
  /// are requested together before the camera page ever opens.
  Future<CameraAccess> _ensureCameraPermission() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    final cameraStatus = statuses[Permission.camera]!;
    if (cameraStatus.isPermanentlyDenied) return CameraAccess.permanentlyDenied;
    if (!cameraStatus.isGranted) return CameraAccess.denied;
    return CameraAccess.granted;
  }

  Future<MediaAsset?> captureFromCamera(BuildContext context) async {
    final access = await _ensureCameraPermission();
    if (access == CameraAccess.permanentlyDenied) {
      HaloToast.show('Camera permission is off. Enable it in Settings to take photos or videos.');
      await openAppSettings();
      return null;
    }
    if (access == CameraAccess.denied) {
      HaloToast.show('Camera permission is required to take photos and videos.');
      return null;
    }

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      HaloToast.show('Could not access the camera on this device.');
      return null;
    }
    if (cameras.isEmpty) {
      HaloToast.show('No camera found on this device.');
      return null;
    }

    if (!context.mounted) return null;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenCameraPage(cameras: cameras),
      ),
    );
    if (result is! XFile) return null;

    if (_looksLikeVideo(result.path)) {
      if (!context.mounted) return null;
      return _editVideo(context, File(result.path));
    }
    return MediaAsset(id: _newId(), kind: MediaKind.image, originalFile: File(result.path));
  }

  Future<MediaAsset?> _editVideo(BuildContext context, File file) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoQuickEditPage(file: file)),
    );
    if (result is! VideoQuickEditResult) return null;
    return MediaAsset(
      id: _newId(),
      kind: MediaKind.video,
      originalFile: result.file,
      coverBytes: result.coverBytes,
      trimStart: Duration(milliseconds: result.trimStartMs),
      trimEnd: Duration(milliseconds: result.trimEndMs),
    );
  }
}
