class MediaVariant {
  final String thumb;
  final String medium;
  final String full;

  const MediaVariant({
    required this.thumb,
    required this.medium,
    required this.full,
  });

  bool get hasAny => thumb.isNotEmpty || medium.isNotEmpty || full.isNotEmpty;

  String forGrid() {
    if (thumb.isNotEmpty) return thumb;
    if (medium.isNotEmpty) return medium;
    if (full.isNotEmpty) return full;
    return '';
  }

  String withWebpFallback(String url) {
    if (url.isEmpty) return '';
    if (!url.contains('.webp')) return url;
    return url;
  }

  String webpFallbackAlt(String url) {
    if (url.isEmpty) return '';
    return url.replaceAll('.webp', '.jpg');
  }

  String forFeed() {
    if (medium.isNotEmpty) return medium;
    if (full.isNotEmpty) return full;
    if (thumb.isNotEmpty) return thumb;
    return '';
  }

  String forFeedByDevice(bool preferFull) {
    if (preferFull) {
      if (full.isNotEmpty) return full;
      if (medium.isNotEmpty) return medium;
      if (thumb.isNotEmpty) return thumb;
      return '';
    }
    return forFeed();
  }

  String forFullscreen() {
    if (full.isNotEmpty) return full;
    if (medium.isNotEmpty) return medium;
    if (thumb.isNotEmpty) return thumb;
    return '';
  }

  String forFullscreenByDevice(bool preferFull) {
    if (preferFull) return forFullscreen();
    if (medium.isNotEmpty) return medium;
    if (full.isNotEmpty) return full;
    if (thumb.isNotEmpty) return thumb;
    return '';
  }
}

class MediaModel {
  final String type; // image | video
  final MediaVariant image;
  final String videoUrl;
  final String hlsUrl;
  final String thumbnail;
  final int? trimStartMs;
  final int? trimEndMs;
  final bool processed;
  final bool processing;
  final String rawVideoUrl;
  final Map<String, dynamic> qualities;

  const MediaModel({
    required this.type,
    required this.image,
    required this.videoUrl,
    required this.hlsUrl,
    required this.thumbnail,
    this.trimStartMs,
    this.trimEndMs,
    this.processed = false,
    this.processing = false,
    this.rawVideoUrl = '',
    this.qualities = const {},
  });

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  String get preferredVideoUrl => hlsUrl.isNotEmpty ? hlsUrl : videoUrl;

  Map<String, dynamic> toVideoMediaMap() => {
        'type': 'video',
        'videoUrl': videoUrl,
        'url': videoUrl,
        'hlsUrl': hlsUrl,
        'thumbnail': thumbnail,
        'rawVideoUrl': rawVideoUrl,
        'processed': processed,
        'processing': processing,
        if (qualities.isNotEmpty) 'qualities': qualities,
        if (trimStartMs != null) 'trimStartMs': trimStartMs,
        if (trimEndMs != null) 'trimEndMs': trimEndMs,
      };

  factory MediaModel.fromMap(Map<String, dynamic> map) {
    final type = (map['type'] ?? '').toString().toLowerCase();
    final url = (map['url'] ?? '').toString().trim();
    final thumb = (map['thumb'] ?? '').toString().trim();
    final medium = (map['medium'] ?? '').toString().trim();
    final full = (map['full'] ?? '').toString().trim();
    final videoUrl = (map['videoUrl'] ?? url).toString().trim();
    final thumbnail = (map['thumbnail'] ?? map['thumbnailUrl'] ?? thumb).toString().trim();
    final processed = map['processed'] == true;
    final processing = map['processing'] == true;
    final rawVideoUrl = (map['rawVideoUrl'] ?? '').toString().trim();
    final q = map['qualities'];
    final qualities =
        q is Map ? Map<String, dynamic>.from(q) : const <String, dynamic>{};

    if (type == 'video' || videoUrl.endsWith('.mp4')) {
      return MediaModel(
        type: 'video',
        image: const MediaVariant(thumb: '', medium: '', full: ''),
        videoUrl: videoUrl,
        hlsUrl: (map['hlsUrl'] ?? map['manifestUrl'] ?? '').toString().trim(),
        thumbnail: thumbnail,
        trimStartMs: _asIntNullable(map['trimStartMs']),
        trimEndMs: _asIntNullable(map['trimEndMs']),
        processed: processed,
        processing: processing,
        rawVideoUrl: rawVideoUrl,
        qualities: qualities,
      );
    }

    final normalized = MediaVariant(
      thumb: thumb,
      medium: medium.isNotEmpty ? medium : url,
      full: full.isNotEmpty ? full : (medium.isNotEmpty ? medium : url),
    );

    return MediaModel(
      type: 'image',
      image: normalized,
      videoUrl: '',
      hlsUrl: '',
      thumbnail: normalized.forGrid(),
      trimStartMs: null,
      trimEndMs: null,
    );
  }

  static List<MediaModel> parsePostMedia(Map<String, dynamic> data) {
    final structured = <MediaModel>[];
    final media = data['media'];
    if (media is List) {
      for (final item in media) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final parsed = MediaModel.fromMap(map);
          if (parsed.isVideo && parsed.videoUrl.isEmpty) continue;
          if (parsed.isImage && !parsed.image.hasAny) continue;
          structured.add(parsed);
        } else if (item is String) {
          final url = item.trim();
          if (url.isEmpty) continue;
          structured.add(
            MediaModel(
              type: url.endsWith('.mp4') ? 'video' : 'image',
              image: MediaVariant(thumb: '', medium: url, full: url),
              videoUrl: url.endsWith('.mp4') ? url : '',
              hlsUrl: '',
              thumbnail: '',
            ),
          );
        }
      }
    }

    if (structured.isNotEmpty) return structured;

    // Single fallback path for legacy documents.
    final legacyImage = _legacyImageUrl(data);
    final legacyVideo = _legacyVideoUrl(data);
    final legacyThumb = _legacyThumbnailUrl(data);

    if (legacyImage.isNotEmpty) {
      return [
        MediaModel(
          type: 'image',
          image: MediaVariant(thumb: legacyThumb, medium: legacyImage, full: legacyImage),
          videoUrl: '',
          hlsUrl: '',
          thumbnail: legacyThumb.isNotEmpty ? legacyThumb : legacyImage,
        ),
      ];
    }

    if (legacyVideo.isNotEmpty) {
      final docQ = data['qualities'];
      final legacyQualities = docQ is Map
          ? Map<String, dynamic>.from(docQ)
          : const <String, dynamic>{};
      return [
        MediaModel(
          type: 'video',
          image: const MediaVariant(thumb: '', medium: '', full: ''),
          videoUrl: legacyVideo,
          hlsUrl: (data['hlsUrl'] ?? '').toString().trim(),
          thumbnail: legacyThumb,
          trimStartMs: _asIntNullable(data['trimStartMs']),
          trimEndMs: _asIntNullable(data['trimEndMs']),
          processed: data['processed'] == true,
          processing: data['processing'] == true,
          rawVideoUrl: (data['rawVideoUrl'] ?? '').toString().trim(),
          qualities: legacyQualities,
        ),
      ];
    }

    return const [];
  }
}

String _legacyImageUrl(Map<String, dynamic> data) {
  final imageUrl = (data['imageUrl'] ?? '').toString().trim();
  if (imageUrl.isNotEmpty) return imageUrl;

  final images = data['images'];
  if (images is List) {
    for (final item in images) {
      final url = item?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
  }

  final url = (data['url'] ?? '').toString().trim();
  if (url.isNotEmpty && !url.endsWith('.mp4')) return url;
  return '';
}

String _legacyVideoUrl(Map<String, dynamic> data) {
  return (data['videoUrl'] ?? data['mediaUrl'] ?? data['reelUrl'] ?? '')
      .toString()
      .trim();
}

String _legacyThumbnailUrl(Map<String, dynamic> data) {
  return (data['thumbnailUrl'] ?? data['thumbUrl'] ?? '').toString().trim();
}

int? _asIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
