import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:halo/features/create_post/data/post_repository.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/domain/media_quality_profile.dart';
import 'package:halo/features/create_post/domain/post_draft_state.dart';
import 'package:halo/features/create_post/services/media_upload_manager.dart';
import 'package:halo/features/create_post/services/media_video_compression_service.dart';
import 'package:halo/services/video_upload_policy.dart';

/// Owns the whole Create Post draft: media lifecycle, caption/tags/location,
/// and submission. UI-agnostic — anything that needs a [BuildContext] (the
/// quality-choice dialog, camera/gallery pickers) is supplied by the caller
/// as a callback rather than reached for directly.
class AddPostController extends StateNotifier<PostDraftState> {
  AddPostController() : super(const PostDraftState());

  static const int maxMediaCount = 10;

  final MediaVideoCompressionService _videoCompression = MediaVideoCompressionService();
  final PostRepository _postRepository = PostRepository();
  MediaUploadManager? _uploadManager;

  /// Validates, optionally compresses (video) and adds one freshly picked
  /// asset to the draft. [resolveQuality] is invoked only when the file is
  /// large enough to matter; returning null (user dismissed the sheet) drops
  /// the pick without adding it.
  Future<String?> processAndAddAsset(
    MediaAsset asset, {
    required Future<MediaQualityProfile?> Function(MediaAsset asset, int originalBytes) resolveQuality,
  }) async {
    if (state.media.length >= maxMediaCount) {
      return 'You can add up to $maxMediaCount photos/videos per post.';
    }

    var current = asset.copyWith(status: MediaStatus.validating);
    state = state.copyWith(media: [...state.media, current]);

    final originalBytes = await asset.originalFile.length();
    final threshold = asset.isVideo
        ? MediaQualityThresholds.videoAutoOptimizeBytes
        : MediaQualityThresholds.imageAutoOptimizeBytes;

    var profile = asset.isVideo ? MediaQualityProfile.balanced : MediaQualityProfile.highQuality;
    if (originalBytes > threshold) {
      final chosen = await resolveQuality(current, originalBytes);
      if (chosen == null) {
        _removeAsset(asset.id);
        return null;
      }
      profile = chosen;
    }
    current = current.copyWith(qualityProfile: profile);

    if (asset.isVideo) {
      current = current.copyWith(status: MediaStatus.processing);
      _updateAsset(current);

      final compressed = await _videoCompression.compress(asset.originalFile, profile);
      final wasCompressed = compressed.path != asset.originalFile.path;
      current = current.copyWith(
        processedFile: wasCompressed ? compressed : null,
        clearProcessedFile: !wasCompressed,
      );

      final rejection = await VideoUploadPolicy.validateFile(current.fileToUpload);
      if (rejection != null) {
        current = current.copyWith(status: MediaStatus.failed, error: rejection.userMessage);
        _updateAsset(current);
        return rejection.userMessage;
      }
    }

    current = current.copyWith(status: MediaStatus.ready, clearError: true);
    _updateAsset(current);
    return null;
  }

  void _updateAsset(MediaAsset updated) {
    state = state.copyWith(
      media: [for (final a in state.media) a.id == updated.id ? updated : a],
    );
  }

  void _removeAsset(String id) {
    state = state.copyWith(media: state.media.where((a) => a.id != id).toList());
  }

  void removeMedia(String id) => _removeAsset(id);

  void reorderMedia(int oldIndex, int newIndex) {
    final list = [...state.media];
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(media: list);
  }

  /// Puts a failed asset back into the pending queue; the next [submit] call
  /// only re-uploads assets that aren't already `uploaded`.
  void retryAsset(String id) {
    final index = state.media.indexWhere((a) => a.id == id);
    if (index == -1) return;
    _updateAsset(state.media[index].copyWith(status: MediaStatus.ready, uploadProgress: 0, clearError: true));
  }

  void setCaption(String value) => state = state.copyWith(caption: value);

  void setLocation(String value) => state = state.copyWith(location: value);

  void toggleTag(String tag) {
    final tags = [...state.tags];
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(tags: tags);
  }

  Future<void> submit(List<String> mentions) async {
    if (state.isSubmitting) return; // guards double-tap duplicate uploads
    if (state.media.isEmpty) {
      state = state.copyWith(submitStatus: const PostSubmitFailure('Please select at least one photo or video.'));
      return;
    }
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      state = state.copyWith(submitStatus: const PostSubmitFailure('Please sign in to post.'));
      return;
    }

    state = state.copyWith(submitStatus: const PostSubmitInProgress());

    final postId = FirebaseFirestore.instance.collection('posts').doc().id;
    _uploadManager = MediaUploadManager();

    final uploaded = await _uploadManager!.uploadAll(
      assets: state.media,
      postId: postId,
      onUpdate: _updateAsset,
    );

    final failed = uploaded.where((a) => a.status == MediaStatus.failed).toList();
    if (failed.isNotEmpty) {
      state = state.copyWith(
        media: uploaded,
        submitStatus: PostSubmitFailure(
          '${failed.length} of ${uploaded.length} uploads failed. Retry the failed item(s) and post again.',
        ),
      );
      return;
    }

    try {
      await _postRepository.createPost(
        postId: postId,
        userId: userId,
        media: uploaded,
        caption: state.caption.trim(),
        location: state.location.trim(),
        tags: state.tags,
        mentions: mentions,
      );
      state = PostDraftState(submitStatus: PostSubmitSuccess(postId));
    } catch (e) {
      state = state.copyWith(media: uploaded, submitStatus: PostSubmitFailure('Could not publish post: $e'));
    }
  }

  void resetSubmitStatus() {
    if (state.submitStatus is! PostSubmitInProgress) {
      state = state.copyWith(submitStatus: const PostSubmitIdle());
    }
  }

  @override
  void dispose() {
    _uploadManager?.cancel();
    super.dispose();
  }
}

final addPostControllerProvider =
    StateNotifierProvider.autoDispose<AddPostController, PostDraftState>(
  (ref) => AddPostController(),
);
