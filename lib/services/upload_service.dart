import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:halo/services/image_service.dart';
import 'package:halo/services/video_upload_policy.dart';

class UploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImageService _imageService = ImageService();

  Future<String> uploadPostImage({
    required File imageFile,
    required String uid,
    required String postId,
  }) async {
    final ref = _storage.ref('users/$uid/posts/$postId.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }

  /// [maxWidth] caps the highest-resolution tier (Balanced/Data Saver
  /// profiles); `null` keeps the original High Quality tiering.
  /// [onProgress] reports aggregate upload fraction (0..1) across all tiers.
  Future<Map<String, dynamic>> uploadAdaptivePostImage({
    required File imageFile,
    required String postId,
    required int index,
    int? maxWidth,
    void Function(double progress)? onProgress,
  }) async {
    final fileHash = await _sha256OfFile(imageFile);
    final hash = maxWidth == null ? fileHash : '${fileHash}_mw$maxWidth';
    final hashDoc = _firestore.collection('media_hashes').doc(hash);
    final hashSnap = await hashDoc.get();
    if (hashSnap.exists) {
      final cached = hashSnap.data() ?? const <String, dynamic>{};
      final cachedMedia = (cached['media'] as Map?)?.cast<String, dynamic>();
      if (cachedMedia != null &&
          ((cachedMedia['medium'] ?? cachedMedia['full'] ?? cachedMedia['thumb'] ?? '')
              .toString()
              .trim()
              .isNotEmpty)) {
        onProgress?.call(1);
        return {
          ...cachedMedia,
          'hash': hash,
        };
      }
    }

    final generated = await _imageService.buildAdaptiveSet(imageFile, maxWidth: maxWidth);

    final suffix = index == 0 ? '' : '_$index';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final base = _storage.ref('users/$uid/posts/$postId');
    final contentType = SettableMetadata(
      contentType: 'image/webp',
      cacheControl: 'public,max-age=31536000,immutable',
    );

    final tasks = <UploadTask>[];
    final refs = <String, Reference>{};

    if (generated.hasThumb) {
      final thumbRef = base.child('thumb$suffix.webp');
      tasks.add(thumbRef.putData(generated.thumbBytes!, contentType));
      refs['thumb'] = thumbRef;
    }
    if (generated.hasMedium) {
      final mediumRef = base.child('medium$suffix.webp');
      tasks.add(mediumRef.putData(generated.mediumBytes!, contentType));
      refs['medium'] = mediumRef;
    }
    if (generated.hasFull) {
      final fullRef = base.child('full$suffix.webp');
      tasks.add(fullRef.putData(generated.fullBytes!, contentType));
      refs['full'] = fullRef;
    }

    List<StreamSubscription<TaskSnapshot>>? subs;
    if (onProgress != null && tasks.isNotEmpty) {
      final totals = List<int>.filled(tasks.length, 0);
      final sent = List<int>.filled(tasks.length, 0);
      subs = [
        for (var i = 0; i < tasks.length; i++)
          tasks[i].snapshotEvents.listen((snap) {
            totals[i] = snap.totalBytes;
            sent[i] = snap.bytesTransferred;
            final totalSum = totals.fold<int>(0, (a, b) => a + b);
            final sentSum = sent.fold<int>(0, (a, b) => a + b);
            if (totalSum > 0) onProgress(sentSum / totalSum);
          }),
      ];
    }

    await Future.wait(tasks);
    for (final s in subs ?? const <StreamSubscription<TaskSnapshot>>[]) {
      await s.cancel();
    }
    final resolved = <String, String>{};
    for (final entry in refs.entries) {
      resolved[entry.key] = await entry.value.getDownloadURL();
    }

    final medium = resolved['medium'] ?? resolved['full'] ?? resolved['thumb'] ?? '';
    final full = resolved['full'] ?? medium;
    final thumb = resolved['thumb'] ?? medium;

    final result = {
      'type': 'image',
      if (thumb.isNotEmpty) 'thumb': thumb,
      if (medium.isNotEmpty) 'medium': medium,
      if (full.isNotEmpty) 'full': full,
      'url': medium,
      'mimeType': 'image/webp',
      'width': generated.originalWidth,
      'height': generated.originalHeight,
      'hash': hash,
    };
    await hashDoc.set({
      'media': result,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return result;
  }

  /// [onProgress] reports upload fraction (0..1) for the (dominant) video
  /// file; the thumbnail upload is small enough to ignore for progress.
  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required File videoFile,
    required String postId,
    required int index,
    Uint8List? thumbnailBytes,
    int? trimStartMs,
    int? trimEndMs,
    void Function(double progress)? onProgress,
  }) async {
    final suffix = index == 0 ? '' : '_$index';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final base = _storage.ref('users/$uid/posts/$postId');
    final videoRef = base.child('video$suffix.mp4');

    final fileSize = await videoFile.length();
    debugPrint(
      '[UPLOAD_START] path=users/$uid/posts/$postId/video$suffix.mp4 '
      'sizeBytes=$fileSize',
    );

    final probe = await VideoUploadPolicy.probeFile(videoFile);
    final rejection = VideoUploadPolicy.validate(probe);
    if (rejection != null) {
      debugPrint('[UPLOAD_REJECTED] ${rejection.code}');
      throw VideoUploadRejectedException(rejection);
    }

    final videoTask = videoRef.putFile(
      videoFile,
      SettableMetadata(
        contentType: 'video/mp4',
        cacheControl: 'public,max-age=31536000,immutable',
        customMetadata: {
          'postId': postId,
          'mediaIndex': index.toString(),
        },
      ),
    );
    StreamSubscription<TaskSnapshot>? sub;
    if (onProgress != null) {
      sub = videoTask.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }
    await videoTask;
    await sub?.cancel();
    final videoUrl = await videoRef.getDownloadURL();
    debugPrint('[UPLOAD_COMPLETE] postId=$postId index=$index');

    String thumbnailUrl = '';
    if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
      final thumbRef = base.child('video_thumb$suffix.jpg');
      await thumbRef.putData(
        thumbnailBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=31536000,immutable',
        ),
      );
      thumbnailUrl = await thumbRef.getDownloadURL();
    }

    // Safe profile only (validated above): raw URL is playable while HLS transcodes.
    return {
      'type': 'video',

      'videoUrl': videoUrl,
      'url': videoUrl,

      'rawVideoUrl': videoUrl,

      'processing': true,
      'processed': false,

      if (probe.width != null)
        'intrinsicWidth': probe.width,

      if (probe.height != null)
        'intrinsicHeight': probe.height,

      if (probe.width != null)
        'sourceWidth': probe.width,

      if (probe.height != null)
        'sourceHeight': probe.height,

      if (probe.fps != null)
        'sourceFps': probe.fps,

      if (thumbnailUrl.isNotEmpty)
        'thumbnail': thumbnailUrl,

      if (thumbnailUrl.isNotEmpty)
        'thumbnailUrl': thumbnailUrl,

      if (trimStartMs != null)
        'trimStartMs': trimStartMs,

      if (trimEndMs != null)
        'trimEndMs': trimEndMs,
    };
  }

  Future<String> uploadProfileImage({
    required File imageFile,
    required String uid,
  }) async {
    final ref = _storage.ref('users/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
