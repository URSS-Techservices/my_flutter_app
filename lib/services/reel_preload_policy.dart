import 'package:halo/services/reel_player_lifecycle.dart';

/// Reel viewer warm window around the current page.
///
/// Android (MTK): 1 back + 2 ahead (4 decoders max) — 5 slots OOM/crashes RMX3998.
/// iOS: 1 back + 3 ahead (5 decoders).
class ReelPreloadPolicy {
  ReelPreloadPolicy._();

  static int get back => 1;

  static int get ahead => ReelPlatformPolicy.isAndroid ? 2 : 3;

  static int get maxWarmSlots => back + ahead + 1;

  static Set<int> warmIndices(int center, int length) {
    final out = <int>{};
    for (var d = -back; d <= ahead; d++) {
      final i = center + d;
      if (i >= 0 && i < length) out.add(i);
    }
    return out;
  }

  /// Init order: current first, then next reels, then previous.
  static List<int> initOrder(int center, int length) {
    final keep = warmIndices(center, length);
    final ordered = <int>[
      center,
      for (var d = 1; d <= ahead; d++) center + d,
      for (var d = 1; d <= back; d++) center - d,
    ];
    return ordered.where(keep.contains).toList();
  }
}
