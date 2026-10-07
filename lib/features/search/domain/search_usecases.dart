import 'package:halo/features/search/domain/category_feed.dart';
import 'package:halo/features/search/domain/search_contract.dart';
import 'package:halo/features/search/domain/search_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ALL SEARCH USE-CASES
// Each use-case has a single call() that delegates to the repository contract.
// The notifier calls these; it never touches Firebase directly.
// ─────────────────────────────────────────────────────────────────────────────

/// Run user search and return ranked results.
class SearchUsersUseCase {
  final SearchContract _repo;
  SearchUsersUseCase(this._repo);

  Future<SearchUsersOutcome> call(String query) =>
      _repo.searchUsers(query.trim());
}

/// Run post search and return ranked results.
class SearchPostsUseCase {
  final SearchContract _repo;
  SearchPostsUseCase(this._repo);

  Future<List<PostResult>> call(String query) =>
      _repo.searchPosts(query.trim());
}

/// Stream active carousel banners (Firebase-managed by admin).
class GetBannersUseCase {
  final SearchContract _repo;
  GetBannersUseCase(this._repo);

  Stream<List<CarouselBanner>> call() => _repo.getBanners();
}

/// Load recent search history from local storage.
class GetRecentsUseCase {
  final SearchContract _repo;
  GetRecentsUseCase(this._repo);

  Future<List<String>> call() => _repo.getRecentSearches();
}

/// Save a search term to local history.
class SaveRecentUseCase {
  final SearchContract _repo;
  SaveRecentUseCase(this._repo);

  Future<void> call(String term) => _repo.saveRecentSearch(term.trim());
}

/// Remove a single term from local history.
class RemoveRecentUseCase {
  final SearchContract _repo;
  RemoveRecentUseCase(this._repo);

  Future<void> call(String term) => _repo.removeRecentSearch(term);
}

/// Clear all recent searches.
class ClearRecentsUseCase {
  final SearchContract _repo;
  ClearRecentsUseCase(this._repo);

  Future<void> call() => _repo.clearRecentSearches();
}

/// Fetch category experts.
class GetCategoryExpertsUseCase {
  final SearchContract _repo;
  GetCategoryExpertsUseCase(this._repo);

  Future<List<UserResult>> call({
    String? interestTerm,
    String? specializationTerm,
  }) =>
      _repo.getUsersByCategory(
        interestTerm: interestTerm,
        specializationTerm: specializationTerm,
      );
}

/// Load browse categories (Firestore-managed).
class GetCategoriesUseCase {
  final SearchContract _repo;
  GetCategoriesUseCase(this._repo);

  Future<List<WellnessCategory>> call() => _repo.getCategories();
}

/// Load the admin-tunable feed settings.
class GetSearchConfigUseCase {
  final SearchContract _repo;
  GetSearchConfigUseCase(this._repo);

  Future<SearchConfig> call() => _repo.getSearchConfig();
}

/// Build the ranked, sectioned people feed for one subcategory.
class GetCategoryFeedUseCase {
  final SearchContract _repo;
  GetCategoryFeedUseCase(this._repo);

  Future<CategoryFeed> call(SubcategorySpec spec, SearchConfig config) =>
      _repo.getCategoryFeed(spec, config);
}
