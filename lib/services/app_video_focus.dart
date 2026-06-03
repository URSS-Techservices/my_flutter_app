import 'package:flutter/foundation.dart';

import 'package:halo/services/video_decoder_budget.dart';

/// Signals when a fullscreen reel route should own decoders (pause feed inline video).
class AppVideoFocus {
  AppVideoFocus._();
  static final AppVideoFocus instance = AppVideoFocus._();

  final List<VoidCallback> _listeners = <VoidCallback>[];

  bool isFullscreenReel = false;

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void enterFullscreenReel() {
    if (isFullscreenReel) return;
    isFullscreenReel = true;
    VideoDecoderBudget.instance.releaseFeedLeases();
    _notify();
  }

  void exitFullscreenReel() {
    if (!isFullscreenReel) return;
    isFullscreenReel = false;
    _notify();
  }

  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}
