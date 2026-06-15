import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/services/image_service.dart';
import 'package:halo/services/video_upload_policy.dart';

/// Mobile upload service — [putFile] paths preserved.
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
    final task = await uploadReferenceFile(
      ref,
      imageFile,
      metadata: SettableMetadata(contentType: 'image/jpeg'),
    );
    await task;
    return ref.getDownloadURL();
  }

  Future<Map<String, dynamic>> uploadAdaptivePostImage({
    required File imageFile,
    required String postId,
    required int index,
  }) async {
    final hash = await _sha256OfFile(imageFile);
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
        return {
          ...cachedMedia,
          'hash': hash,
        };
      }
    }

    final generated = await _imageService.buildAdaptiveSet(imageFile);

    final suffix = index == 0 ? '' : '_$index';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final base = _storage.ref('users/$uid/posts/$postId');
    final contentType = SettableMetadata(
      contentType: 'image/webp',
      cacheControl: 'public,max-age=31536000,immutable',
    );

    final tasks = <Future<void>>[];
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

    await Future.wait(tasks);
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

  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required File videoFile,
    required String postId,
    required int index,
    Uint8List? thumbnailBytes,
    int? trimStartMs,
    int? trimEndMs,
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

    await uploadReferenceFile(
      videoRef,
      videoFile,
      metadata: SettableMetadata(
        contentType: 'video/mp4',
        cacheControl: 'public,max-age=31536000,immutable',
        customMetadata: {
          'postId': postId,
          'mediaIndex': index.toString(),
        },
      ),
    );
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

    return {
      'type': 'video',
      'videoUrl': videoUrl,
      'url': videoUrl,
      'rawVideoUrl': videoUrl,
      'processing': true,
      'processed': false,
      if (probe.width != null) 'intrinsicWidth': probe.width,
      if (probe.height != null) 'intrinsicHeight': probe.height,
      if (probe.width != null) 'sourceWidth': probe.width,
      if (probe.height != null) 'sourceHeight': probe.height,
      if (probe.fps != null) 'sourceFps': probe.fps,
      if (thumbnailUrl.isNotEmpty) 'thumbnail': thumbnailUrl,
      if (thumbnailUrl.isNotEmpty) 'thumbnailUrl': thumbnailUrl,
      if (trimStartMs != null) 'trimStartMs': trimStartMs,
      if (trimEndMs != null) 'trimEndMs': trimEndMs,
    };
  }

  Future<String> uploadProfileImage({
    required File imageFile,
    required String uid,
  }) async {
    final ref = _storage
        .ref('users/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = await uploadReferenceFile(
      ref,
      imageFile,
      metadata: SettableMetadata(contentType: 'image/jpeg'),
    );
    await task;
    return ref.getDownloadURL();
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
