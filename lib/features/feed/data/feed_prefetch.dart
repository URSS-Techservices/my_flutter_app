import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:halo/features/feed/domain/post_data.dart';

/// Downloads the next 6 feed images in the background so they paint instantly.
class FeedPrefetch {
  static const _ahead = 6;

  static void warm(List<PostData> posts, {int from = 0}) {
    final end = (from + _ahead).clamp(0, posts.length);
    for (var i = from; i < end; i++) {
      for (final m in posts[i].media) {
        final preview = m.thumbUrl;
        final feed = m.isVideo ? '' : m.url;
        if (preview.isNotEmpty) _get(preview);
        if (feed.isNotEmpty && feed != preview) _get(feed);
      }
    }
  }

  static void _get(String url) {
    unawaited(() async {
      try {
        await DefaultCacheManager().downloadFile(url);
      } catch (_) {}
    }());
  }
}
