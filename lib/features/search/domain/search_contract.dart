import 'package:halo/features/search/domain/category_feed.dart';
import 'package:halo/features/search/domain/search_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH CONTRACT (Abstract Repository Interface)
// The data layer must implement all of these methods.
// The presentation layer only depends on this contract — never on Firebase directly.
// ─────────────────────────────────────────────────────────────────────────────

abstract class SearchContract {
  /// Search users by query — returns ranked list of UserResult.
  Future<SearchUsersOutcome> searchUsers(String query);

  /// Search posts by query — returns ranked list of PostResult.
  Future<List<PostResult>> searchPosts(String query);

  /// Stream of active carousel banners from Firestore (real-time).
  Stream<List<CarouselBanner>> getBanners();

  /// Fetch experts for a wellness category.
  Future<List<UserResult>> getUsersByCategory({
    String? interestTerm,
    String? specializationTerm,
  });

  /// Categories for the browse grid (Firestore, falls back to built-ins).
  Future<List<WellnessCategory>> getCategories();

  /// Admin-tunable feed settings (Firestore `search_config/main`).
  Future<SearchConfig> getSearchConfig();

  /// People for one subcategory, grouped by profile type and ranked.
  Future<CategoryFeed> getCategoryFeed(
      SubcategorySpec spec, SearchConfig config);

  /// Fetch follow-relationship scores (current user → target users).
  Future<Map<String, double>> getRelationshipScores(
    String currentUserId,
    List<String> targetUserIds,
  );

  /// Load recent search terms from local storage.
  Future<List<String>> getRecentSearches();

  /// Persist a new search term to local storage.
  Future<void> saveRecentSearch(String term);

  /// Remove one search term from local storage.
  Future<void> removeRecentSearch(String term);

  /// Clear all recent searches from local storage.
  Future<void> clearRecentSearches();
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTCOME WRAPPER — carries whether prefix search was used (for UI hint)
// ─────────────────────────────────────────────────────────────────────────────

class SearchUsersOutcome {
  final List<UserResult> users;
  final bool usedFallback;

  const SearchUsersOutcome({
    required this.users,
    required this.usedFallback,
  });
}
