import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shared sizes so home scales on small phones and tablets.
class HomeLayout {
  static double contentWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > 720 ? 560 : w;
  }

  static EdgeInsets pagePad(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = w < 360 ? 12.0 : 16.0;
    return EdgeInsets.symmetric(horizontal: h);
  }

  static double textScale(BuildContext context) {
    return MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5).scale(1);
  }

  static double storySize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 340) return 52;
    if (w > 600) return 64;
    return 58;
  }

  static double storyStripHeight(BuildContext context) {
    return storySize(context) + 14 + 14 * textScale(context);
  }

  static const mediaFill = Color(0xFFF0F0F0);
  static const mediaError = Color(0xFFEEEEEE);

  /// Instagram crop window: 4:5 portrait through ~1.91:1 landscape.
  static const mediaMinAspect = 4 / 5;
  static const mediaMaxAspect = 1.91;

  static double mediaAspect(double? aspect) {
    final a = (aspect == null || aspect <= 0) ? 1.0 : aspect;
    return a.clamp(mediaMinAspect, mediaMaxAspect);
  }

  static double imageHeight(BuildContext context, {double? aspect}) {
    return contentWidth(context) / mediaAspect(aspect);
  }

  static int imageCacheWidth(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = contentWidth(context);
    return (w * dpr).round().clamp(360, 1080);
  }

  static int avatarCacheWidth(BuildContext context, double radius) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (radius * 2 * dpr * 2).round().clamp(80, 320);
  }

  static Widget constrain(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth(context)),
        child: child,
      ),
    );
  }
}

String feedCount(int n) {
  if (n < 0) return '0';
  if (n >= 1000000) {
    final v = n / 1000000;
    return v % 1 == 0 ? '${v.toInt()}M' : '${v.toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return v % 1 == 0 ? '${v.toInt()}K' : '${v.toStringAsFixed(1)}K';
  }
  return '$n';
}

String feedTimeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

/// Sharp circular photo. Uses a 2x cache so faces stay clear on high-DPI screens.
class FeedAvatar extends StatelessWidget {
  final String url;
  final double radius;

  const FeedAvatar({super.key, required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final cache = HomeLayout.avatarCacheWidth(context, radius);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? ColoredBox(
                color: const Color(0xFFE8E6F0),
                child: Icon(Icons.person, size: radius, color: Colors.white),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                memCacheWidth: cache,
                filterQuality: FilterQuality.high,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFE8E6F0)),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: const Color(0xFFE8E6F0),
                  child: Icon(Icons.person, size: radius, color: Colors.white),
                ),
              ),
      ),
    );
  }
}
