import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:halo/Bottom Pages/full_screen_camera_page.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/domain/media_quality_profile.dart';
import 'package:halo/features/create_post/presentation/editors/post_image_editor_page.dart';
import 'package:halo/features/create_post/presentation/editors/post_video_editor_page.dart';

enum CameraAccess { granted, denied, permanentlyDenied }

const _videoExtensions = ['.mp4', '.mov', '.m4v', '.webm'];

/// Orchestrates media selection: gallery pick, lazy camera capture, and
/// routing every picked/captured photo or video through the full editor
/// ([PostImageEditorPage] / [PostVideoEditorPage]) before it joins the draft.
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

  /// Picks photos and opens the editor for each one in turn. Closing the
  /// editor without pressing Done keeps that photo unedited.
  Future<List<MediaAsset>> pickImagesFromGallery(BuildContext context) async {
    final images = await _picker.pickMultiImage(imageQuality: 100);
    final assets = <MediaAsset>[];
    for (final image in images) {
      if (!context.mounted) break;
      final file = File(image.path);
      final edited = await editImageFile(context, file);
      assets.add(MediaAsset(id: _newId(), kind: MediaKind.image, originalFile: edited ?? file));
    }
    return assets;
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

  /// Only the camera permission gates opening the camera. The microphone is
  /// requested alongside it, but a denied mic just means videos are recorded
  /// without sound instead of blocking the camera entirely.
  Future<(CameraAccess, bool)> _ensureCameraPermission() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    final cameraStatus = statuses[Permission.camera]!;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    if (cameraStatus.isGranted || cameraStatus.isLimited) return (CameraAccess.granted, micGranted);
    if (cameraStatus.isPermanentlyDenied || cameraStatus.isRestricted) {
      return (CameraAccess.permanentlyDenied, micGranted);
    }
    return (CameraAccess.denied, micGranted);
  }

  Future<MediaAsset?> captureFromCamera(BuildContext context) async {
    final (access, micGranted) = await _ensureCameraPermission();
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
        builder: (_) => FullScreenCameraPage(cameras: cameras, enableAudio: micGranted),
      ),
    );
    if (result is! XFile) return null;

    if (!context.mounted) return null;
    final file = File(result.path);
    if (_looksLikeVideo(result.path)) return _editVideo(context, file);

    final edited = await editImageFile(context, file);
    return MediaAsset(id: _newId(), kind: MediaKind.image, originalFile: edited ?? file);
  }

  /// Opens the photo editor; returns the edited file, or null if the user
  /// closed it without pressing Done.
  Future<File?> editImageFile(BuildContext context, File file) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostImageEditorPage(file: file)),
    );
    return result is File ? result : null;
  }

  Future<MediaAsset?> _editVideo(BuildContext context, File file) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostVideoEditorPage(file: file)),
    );
    if (result is! PostVideoEditResult) return null;
    return MediaAsset(
      id: _newId(),
      kind: MediaKind.video,
      originalFile: result.file,
      coverBytes: result.coverBytes,
      trimStart: result.trimStart,
      trimEnd: result.trimEnd,
    );
  }

  /// Re-opens the matching editor for an asset already in the draft.
  /// Returns a fresh asset to replace it with, or null if nothing changed.
  Future<MediaAsset?> reEdit(BuildContext context, MediaAsset asset) async {
    if (asset.isVideo) return _editVideo(context, asset.originalFile);
    final edited = await editImageFile(context, asset.originalFile);
    if (edited == null) return null;
    return MediaAsset(id: _newId(), kind: MediaKind.image, originalFile: edited);
  }
}
