import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:halo/services/image_service.dart';
import 'package:media_info/media_info.dart';

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

    // Probe BEFORE upload so we can set flags on the Firestore doc and
    // decide whether the raw file is safe for direct playback.
    final probe = await _probeVideoFile(videoFile);
    debugPrint(
      '[PROBE_RESULT] ${probe.width}x${probe.height} fps=${probe.fps} '
      'hevc=${probe.isHevc} hdr=${probe.isHdr} dv=${probe.isDolbyVision} '
      'exotic=${probe.isExotic}',
    );

    await videoRef.putFile(
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

    // KEY RULE:
    //   exotic video → videoUrl = ''   (resolver shows Processing overlay,
    //                                   Cloud Function fills it when done)
    //   safe video   → videoUrl = raw  (plays immediately while CF runs)
    final playableUrl = '';

    return {
      'type': 'video',

      'videoUrl': '',
      'url': '',

      'rawVideoUrl': videoUrl,

      'processing': true,
      'processed': false,

      if (probe.isDolbyVision)
        'isDolbyVision': true,

      if (probe.isHevc)
        'isHevc': true,

      if (probe.isHdr)
        'isHdr': true,

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

  /// Probe a local video file BEFORE upload to decide whether it is safe to
  /// play raw on Android. We use `media_info` for dimensions / fps and a
  /// lightweight MP4 box-signature sniff for codec / HDR / Dolby Vision —
  /// the `media_info` plugin does not expose those by itself.
  Future<_VideoProbe> _probeVideoFile(File videoFile) async {
    try {
      // Step 1: get width/height/fps from media_info
      final mediaInfo = MediaInfo();
      final info = await mediaInfo.getMediaInfo(videoFile.path);

      final w = (info['width'] as num?)?.round();
      final h = (info['height'] as num?)?.round();
      final fpsRaw = info['frameRate'];
      int? fps;
      if (fpsRaw is num) {
        fps = fpsRaw.round();
      } else if (fpsRaw is String && fpsRaw.contains('/')) {
        final parts = fpsRaw.split('/');
        final n = double.tryParse(parts[0]) ?? 0;
        final d = double.tryParse(parts[1]) ?? 1;
        if (d > 0) fps = (n / d).round();
      } else if (fpsRaw is String) {
        fps = double.tryParse(fpsRaw)?.round();
      }

      // Step 2: sniff first 256KB of file for codec box signatures
      final bytes = await videoFile.openRead(0, 262144).fold<List<int>>(
        [],
            (acc, chunk) => acc..addAll(chunk),
      );
      final hex = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toLowerCase();

      // iPhone Dolby Vision: dvh1, dvhe, dby1 box signatures
      final isDolbyVision = hex.contains('64766831') || // dvh1
          hex.contains('64766865') || // dvhe
          hex.contains('64627931'); // dby1

      // HEVC: hvc1 or hev1 box signatures
      final isHevc = hex.contains('68766331') || // hvc1
          hex.contains('68657631'); // hev1

      // HDR: mdcv (mastering display colour volume) or clli box
      final isHdr = hex.contains('6d646376') || // mdcv
          hex.contains('636c6c69'); // clli

      debugPrint(
        '[PROBE_RESULT] ${w}x$h fps=$fps '
            'hevc=$isHevc hdr=$isHdr dv=$isDolbyVision',
      );

      return _VideoProbe(
        width: w,
        height: h,
        fps: fps,
        isHevc: isHevc,
        isHdr: isHdr,
        isDolbyVision: isDolbyVision,
      );
    } catch (e) {
      debugPrint('[PROBE_FAILED] $e — treating as safe');
      return const _VideoProbe();
    }
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

/// Lightweight description of an uploaded video, populated by
/// [UploadService._probeVideoFile] BEFORE the file is sent to Storage. We
/// use it to decide whether the raw URL is safe to hand straight to
/// ExoPlayer/AVPlayer, or whether we must wait for the Cloud Function to
/// produce an HLS ladder first.
class _VideoProbe {
  final int? width;
  final int? height;
  final int? fps;
  final bool isHevc;
  final bool isHdr;
  final bool isDolbyVision;

  const _VideoProbe({
    this.width,
    this.height,
    this.fps,
    this.isHevc = false,
    this.isHdr = false,
    this.isDolbyVision = false,
  });

  bool get isExotic =>
      isDolbyVision ||
          isHevc ||
          isHdr ||
          (width != null && width! > 1920) ||
          (height != null && height! > 1920) ||
          (fps != null && fps! > 31);
}
