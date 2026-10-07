import 'media_asset.dart';

sealed class PostSubmitStatus {
  const PostSubmitStatus();
}

class PostSubmitIdle extends PostSubmitStatus {
  const PostSubmitIdle();
}

class PostSubmitInProgress extends PostSubmitStatus {
  const PostSubmitInProgress();
}

class PostSubmitSuccess extends PostSubmitStatus {
  final String postId;
  const PostSubmitSuccess(this.postId);
}

class PostSubmitFailure extends PostSubmitStatus {
  final String message;
  const PostSubmitFailure(this.message);
}

/// Everything the Create Post screen needs to render, in one immutable value.
class PostDraftState {
  final List<MediaAsset> media;
  final String caption;
  final String location;
  final List<String> tags;
  final PostSubmitStatus submitStatus;

  const PostDraftState({
    this.media = const [],
    this.caption = '',
    this.location = '',
    this.tags = const [],
    this.submitStatus = const PostSubmitIdle(),
  });

  bool get hasMedia => media.isNotEmpty;
  bool get isSubmitting => submitStatus is PostSubmitInProgress;

  PostDraftState copyWith({
    List<MediaAsset>? media,
    String? caption,
    String? location,
    List<String>? tags,
    PostSubmitStatus? submitStatus,
  }) {
    return PostDraftState(
      media: media ?? this.media,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      submitStatus: submitStatus ?? this.submitStatus,
    );
  }
}
