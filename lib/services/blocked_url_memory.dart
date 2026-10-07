/// Tracks video URLs that previously crashed ExoPlayer with a codec / capacity
/// failure (`NO_EXCEEDS_CAPABILITIES`, decoder init failure, 4K HEVC OOM, …).
///
/// The resolver checks this set BEFORE handing a raw URL to the player so we
/// only feed the decoder things we know it can handle. Persisted to
/// SharedPreferences so the block survives app restarts (otherwise every
/// cold-start would re-crash on the same iPhone 4K HEVC reel and bounce the
/// user's whole feed).
///
/// API is intentionally tiny + synchronous after [init] completes:
///
/// ```dart
/// await BlockedUrlMemory.instance.init();
/// if (BlockedUrlMemory.instance.contains(url)) { /* skip raw playback */ }
/// await BlockedUrlMemory.instance.add(url);
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedUrlMemory {
  BlockedUrlMemory._();
  static final BlockedUrlMemory instance = BlockedUrlMemory._();

  static const String _prefsKey = 'reel.blockedUrls.v1';
  static const int _maxEntries = 256;

  final Set<String> _blocked = <String>{};
  bool _initialised = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_initialised) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      final list = _prefs?.getStringList(_prefsKey) ?? const <String>[];
      _blocked
        ..clear()
        ..addAll(list.map(_canonicalise).where((e) => e.isNotEmpty));
    } catch (e) {
      debugPrint('[BLOCKED_URL_MEMORY] init failed: $e');
    }
    _initialised = true;
  }

  bool contains(String url) {
    if (url.isEmpty) return false;
    return _blocked.contains(_canonicalise(url));
  }

  Future<void> add(String url) async {
    if (url.isEmpty) return;
    final key = _canonicalise(url);
    if (key.isEmpty) return;
    final added = _blocked.add(key);
    if (!added) return;

    if (_blocked.length > _maxEntries) {
      final overflow = _blocked.length - _maxEntries;
      final iter = _blocked.iterator;
      final toRemove = <String>[];
      for (int i = 0; i < overflow && iter.moveNext(); i++) {
        toRemove.add(iter.current);
      }
      _blocked.removeAll(toRemove);
    }

    try {
      await _prefs?.setStringList(_prefsKey, _blocked.toList(growable: false));
    } catch (e) {
      debugPrint('[BLOCKED_URL_MEMORY] persist failed: $e');
    }
  }

  Future<void> clear() async {
    _blocked.clear();
    try {
      await _prefs?.remove(_prefsKey);
    } catch (_) {/* best-effort */}
  }

  /// Strip auth tokens / cache-busting query params so two URLs that point at
  /// the same Storage object collapse to one entry.
  static String _canonicalise(String raw) {
    if (raw.isEmpty) return '';
    try {
      final uri = Uri.parse(raw);
      // Storage URLs: keep scheme + host + path, drop ?alt=media&token=… etc.
      if (uri.scheme.isEmpty || uri.host.isEmpty) return raw.trim();
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
      ).toString();
    } catch (_) {
      return raw.trim();
    }
  }
}
