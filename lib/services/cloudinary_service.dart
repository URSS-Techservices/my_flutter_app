import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Cloudinary cloud name and upload preset.
const String _kCloudName = 'djzdaleib';
const String _kUploadPreset = 'flutter_upload';

/// CDN transformation string applied to ALL reel video playback URLs.
///
/// - `f_auto`   — Cloudinary selects the best format for the device:
///                MP4/H.264 on iOS (AVPlayer), WebM/VP9 on Android/Chrome.
///                This alone fixes iOS ↔ Android format mismatch.
/// - `q_auto`   — Automatic quality optimisation (60-80% smaller files
///                with visually identical quality on mobile screens).
/// - `vc_h264`  — Force H.264 codec for universal compatibility; Cloudinary
///                transcodes HEVC / MOV / AV1 sources to H.264 SDR.
/// - `so_0`     — Start offset 0: video playback starts from the beginning.
const String _kVideoTransform = 'f_auto,q_auto,vc_h264,so_0';

/// Transformation for thumbnail extraction (poster frame at 1 second).
const String _kThumbTransform = 'so_1,w_480,h_854,c_fill,f_jpg,q_auto:good';

class CloudinaryService {
  CloudinaryService._internal();
  static final CloudinaryService instance = CloudinaryService._internal();

  final _cloudinary = CloudinaryPublic(
    _kCloudName,
    _kUploadPreset,
    cache: false,
  );

  // ── Image upload (existing functionality — unchanged) ────────────────────

  Future<String?> uploadMedia(String filePath, {bool isVideo = false}) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: isVideo
              ? CloudinaryResourceType.Video
              : CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      debugPrint('[Cloudinary] upload failed: ${e.message}');
      return null;
    }
  }

  // ── Reel video upload ────────────────────────────────────────────────────

  /// Uploads a reel video to Cloudinary and returns a [CloudinaryReelResult]
  /// with ready-to-use CDN URLs.
  ///
  /// ### Why Cloudinary for reels?
  /// - Global CDN edge nodes → video served from the nearest POP (reduces
  ///   latency by 60-80% vs Firebase Storage for non-US users).
  /// - `f_auto` selects MP4 for iOS and WebM for Android automatically,
  ///   fixing the "iOS-recorded video doesn't play on Android" format issue.
  /// - `vc_h264` transcodes HEVC / MOV / AV1 sources to H.264 SDR on
  ///   Cloudinary's servers — no separate Cloud Function needed.
  /// - `q_auto` compresses intelligently (raw 50 MB → 3-8 MB on mobile).
  ///
  /// ### Cloudinary transcoding time
  /// The raw `secureUrl` is available immediately after upload but may take
  /// 5-30 seconds to be fully transcoded. The `f_auto,q_auto` transform URL
  /// serves the raw file first and streams the optimised version once ready.
  Future<CloudinaryReelResult?> uploadReelVideo(File videoFile) async {
    try {
      final fileName =
          'reel_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('[Cloudinary] uploading reel: ${videoFile.path}');

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          identifier: fileName,
          // Tags for easy filtering in the Cloudinary dashboard.
          tags: ['reel', 'halo_app'],
        ),
      );

      final publicId = response.publicId;
      final cloudName = _kCloudName;

      // CDN-optimised playback URL (f_auto selects best format per platform).
      final cdnUrl =
          'https://res.cloudinary.com/$cloudName/video/upload/$_kVideoTransform/$publicId';

      // Poster frame thumbnail (extracted at 1 second, 480×854 crop).
      final thumbnailUrl =
          'https://res.cloudinary.com/$cloudName/video/upload/$_kThumbTransform/$publicId';

      // Raw upload URL (fallback while CDN propagates — should not normally
      // be used for playback but kept as a safety net).
      final rawUrl = response.secureUrl;

      debugPrint('[Cloudinary] reel upload success publicId=$publicId');

      // CloudinaryResponse v0.23.1 doesn't expose width/height/duration as
      // typed fields — read them from response.data (the raw API JSON map).
      final rawData = response.data;
      final width = (rawData['width'] as num?)?.toInt();
      final height = (rawData['height'] as num?)?.toInt();
      final durationRaw = rawData['duration'];
      final duration = durationRaw != null
          ? (durationRaw as num).round()
          : null;

      return CloudinaryReelResult(
        publicId: publicId,
        cdnUrl: cdnUrl,
        thumbnailUrl: thumbnailUrl,
        rawUrl: rawUrl,
        width: width,
        height: height,
        duration: duration,
      );
    } on CloudinaryException catch (e) {
      debugPrint('[Cloudinary] reel upload failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Cloudinary] reel upload error: $e');
      return null;
    }
  }

  // ── Firestore reel document helpers ─────────────────────────────────────

  /// Builds the Firestore data map for a new reel document from a
  /// [CloudinaryReelResult]. Stores both the CDN URL (primary) and raw URL
  /// (fallback) so the `video_playback_resolver` chain works correctly.
  static Map<String, dynamic> buildReelFirestoreData({
    required CloudinaryReelResult result,
    required String userId,
    required String caption,
    String? username,
    String? profilePic,
  }) {
    return {
      // ── Video URLs ──
      // Primary playback URL: Cloudinary CDN with f_auto,q_auto,vc_h264.
      // This is what video_playback_resolver uses as the "processed MP4".
      'videoUrl': result.cdnUrl,
      'url': result.cdnUrl,

      // Raw Cloudinary URL kept as fallback for video_playback_resolver.
      'rawVideoUrl': result.rawUrl,

      // Cloudinary public ID for future URL transformations.
      'cloudinaryPublicId': result.publicId,

      // ── Thumbnail ──
      'thumbnailUrl': result.thumbnailUrl,
      'thumbnail': result.thumbnailUrl,

      // ── Lifecycle ──
      // Mark as "processed" since Cloudinary serves optimised content via CDN.
      // The f_auto transform handles transcoding transparently.
      'processed': true,
      'processing': false,

      // ── Author ──
      'userId': userId,
      if (username != null && username.isNotEmpty) 'username': username,
      if (profilePic != null && profilePic.isNotEmpty) 'profilePic': profilePic,

      // ── Content ──
      'caption': caption,

      // ── Dimensions ──
      if (result.width != null) 'sourceWidth': result.width,
      if (result.height != null) 'sourceHeight': result.height,
      if (result.duration != null) 'durationSeconds': result.duration,

      // ── Engagement (initialised to 0) ──
      'views': 0,
      'likes': 0,
      'comments': 0,
      'shares': 0,
      'replayCount': 0,
      'totalWatchTime': 0,
      'completedViews': 0,

      // ── Timestamps ──
      'createdAt': Timestamp.now(),
      'createdAtServer': FieldValue.serverTimestamp(),
    };
  }
}

/// Result of a successful Cloudinary reel video upload.
class CloudinaryReelResult {
  /// Cloudinary public ID (used for dynamic URL transformations).
  final String publicId;

  /// CDN-optimised playback URL with `f_auto,q_auto,vc_h264` applied.
  /// This is the primary URL stored in Firestore and used for playback.
  final String cdnUrl;

  /// Thumbnail/poster frame URL (extracted at 1 second, 480×854).
  final String thumbnailUrl;

  /// Raw Cloudinary URL (fallback; use `cdnUrl` for playback).
  final String rawUrl;

  final int? width;
  final int? height;

  /// Duration in seconds (from Cloudinary metadata).
  final int? duration;

  const CloudinaryReelResult({
    required this.publicId,
    required this.cdnUrl,
    required this.thumbnailUrl,
    required this.rawUrl,
    this.width,
    this.height,
    this.duration,
  });
}
