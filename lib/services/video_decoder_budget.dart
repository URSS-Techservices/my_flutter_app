import 'package:flutter/foundation.dart';

/// Global decoder slot budget shared by all video surfaces.
///
/// This prevents independent pools from each believing they can allocate
/// `N` decoders and collectively exhausting MediaCodec resources.
class VideoDecoderBudget {
  VideoDecoderBudget._();
  static final VideoDecoderBudget instance = VideoDecoderBudget._();

  static const int _androidMax = 2;
  static const int _iosMax = 3;
  static const int _fallbackMax = 2;

  final Map<String, int> _leasesByOwner = <String, int>{};

  int get maxSlots {
    if (kIsWeb) return _fallbackMax;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidMax;
      case TargetPlatform.iOS:
        return _iosMax;
      default:
        return _fallbackMax;
    }
  }

  int get usedSlots =>
      _leasesByOwner.values.fold<int>(0, (sum, count) => sum + count);

  int get availableSlots {
    final available = maxSlots - usedSlots;
    return available > 0 ? available : 0;
  }

  bool tryAcquire(String owner) {
    if (availableSlots <= 0) return false;
    _leasesByOwner.update(owner, (value) => value + 1, ifAbsent: () => 1);
    return true;
  }

  void release(String owner) {
    final count = _leasesByOwner[owner];
    if (count == null) return;
    if (count <= 1) {
      _leasesByOwner.remove(owner);
      return;
    }
    _leasesByOwner[owner] = count - 1;
  }

  void releaseAll(String owner) {
    _leasesByOwner.remove(owner);
  }
}
