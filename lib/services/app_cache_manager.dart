import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  static final CacheManager media = CacheManager(
    Config(
      'haloMediaCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 220,
    ),
  );
}
