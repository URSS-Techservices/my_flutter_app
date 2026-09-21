import 'package:halo/features/search/domain/search_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH STATE
// Immutable state class for all search UI state.
// ─────────────────────────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final String debouncedQuery;
  final bool loading;
  final Object? error;
  final List<UserResult> userResults;
  final List<PostResult> postResults;
  final List<String> recentSearches;
  final bool showRecents;
  final bool usedFallback;
  final String? cachedQueryFor;

  const SearchState({
    this.query = '',
    this.debouncedQuery = '',
    this.loading = false,
    this.error,
    this.userResults = const [],
    this.postResults = const [],
    this.recentSearches = const [],
    this.showRecents = false,
    this.usedFallback = false,
    this.cachedQueryFor,
  });

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasResults => userResults.isNotEmpty || postResults.isNotEmpty;

  SearchState copyWith({
    String? query,
    String? debouncedQuery,
    bool? loading,
    Object? error,
    bool clearError = false,
    List<UserResult>? userResults,
    List<PostResult>? postResults,
    List<String>? recentSearches,
    bool? showRecents,
    bool? usedFallback,
    String? cachedQueryFor,
    bool clearCachedQuery = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      debouncedQuery: debouncedQuery ?? this.debouncedQuery,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      userResults: userResults ?? this.userResults,
      postResults: postResults ?? this.postResults,
      recentSearches: recentSearches ?? this.recentSearches,
      showRecents: showRecents ?? this.showRecents,
      usedFallback: usedFallback ?? this.usedFallback,
      cachedQueryFor:
          clearCachedQuery ? null : (cachedQueryFor ?? this.cachedQueryFor),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAROUSEL STATE
// Tracks the currently visible banner page (for dot indicators).
// ─────────────────────────────────────────────────────────────────────────────

class CarouselState {
  final int currentPage;

  const CarouselState({this.currentPage = 0});

  CarouselState copyWith({int? currentPage}) =>
      CarouselState(currentPage: currentPage ?? this.currentPage);
}
