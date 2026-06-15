class ResolvedReelSource {
  final String primaryUrl;
  final String fallbackUrl;
  final String posterUrl;
  final bool isPlayable;
  final int? startupHintMs;

  const ResolvedReelSource({
    required this.primaryUrl,
    required this.fallbackUrl,
    required this.posterUrl,
    required this.isPlayable,
    this.startupHintMs,
  });
}

class ReelSourceResolver {
  const ReelSourceResolver._();

  static String _s(dynamic value) => (value ?? '').toString().trim();

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _looksLikeVideo(String url) {
    final v = url.toLowerCase();
    return v.contains('.m3u8') ||
        v.contains('.mp4') ||
        v.contains('.mov') ||
        v.contains('.m4v') ||
        v.contains('/videos/');
  }

  static ResolvedReelSource resolve({
    required Map<String, dynamic> postData,
    Map<String, dynamic>? mediaData,
  }) {
    final media = mediaData ?? const <String, dynamic>{};

    final hls = _s(media['hlsUrl']).isNotEmpty
        ? _s(media['hlsUrl'])
        : _s(postData['hlsUrl']);
    final videoUrl = _s(media['videoUrl']).isNotEmpty
        ? _s(media['videoUrl'])
        : _s(postData['videoUrl']);
    final fallback = _s(media['rawVideoUrl']).isNotEmpty
        ? _s(media['rawVideoUrl'])
        : _s(postData['rawVideoUrl']);
    final poster = _s(media['thumbnail']).isNotEmpty
        ? _s(media['thumbnail'])
        : (_s(media['thumbnailUrl']).isNotEmpty
            ? _s(media['thumbnailUrl'])
            : _s(postData['thumbnailUrl']));

    final primary = hls.isNotEmpty ? hls : videoUrl;
    final chosenFallback = fallback.isNotEmpty ? fallback : videoUrl;
    final playable = _looksLikeVideo(primary) || _looksLikeVideo(chosenFallback);
    final startupHint = _safeInt(media['startupHintMs']) ??
        _safeInt(postData['startupHintMs']) ??
        _safeInt(postData['durationMs']);

    return ResolvedReelSource(
      primaryUrl: primary,
      fallbackUrl: chosenFallback,
      posterUrl: poster,
      isPlayable: playable,
      startupHintMs: startupHint,
    );
  }
}
