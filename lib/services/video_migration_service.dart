import 'package:cloud_functions/cloud_functions.dart';

import 'package:cloud_functions/cloud_functions.dart';

/// Calls the `migrateLegacyVideos` Cloud Function to re-queue transcodes
/// for legacy raw-only posts and docs stuck in `processing`.
class VideoMigrationService {
  VideoMigrationService._();
  static final VideoMigrationService instance = VideoMigrationService._();

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> migrateLegacyVideos({
    int maxDocs = 200,
    String collection = 'both',
    bool includeStuckProcessing = true,
    bool retryPermanentFailures = false,
  }) async {
    final callable = _functions.httpsCallable(
      'migrateLegacyVideos',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
    );
    final result = await callable.call({
      'maxDocs': maxDocs,
      'collection': collection,
      'includeStuckProcessing': includeStuckProcessing,
      'retryPermanentFailures': retryPermanentFailures,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
