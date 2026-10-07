import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/search/data/search_repository.dart';
import 'package:halo/features/search/domain/category_feed.dart';
import 'package:halo/features/search/domain/search_contract.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/domain/search_usecases.dart';
import 'package:halo/features/search/presentation/search_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEPENDENCY INJECTION PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Provides the concrete repository (can be overridden in tests with a mock).
final searchRepositoryProvider = Provider<SearchContract>((ref) {
  return SearchRepository();
});

// ─────────────────────────────────────────────────────────────────────────────
// CAROUSEL BANNERS PROVIDER (real-time stream)
// ─────────────────────────────────────────────────────────────────────────────

final bannersProvider = StreamProvider<List<CarouselBanner>>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return GetBannersUseCase(repo).call();
});

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORIES, CONFIG AND CATEGORY FEED
// Cached for the session; the feed is per subcategory and dropped when its
// page closes.
// ─────────────────────────────────────────────────────────────────────────────

final searchCategoriesProvider = FutureProvider<List<WellnessCategory>>((ref) {
  return GetCategoriesUseCase(ref.watch(searchRepositoryProvider)).call();
});

final searchConfigProvider = FutureProvider<SearchConfig>((ref) {
  return GetSearchConfigUseCase(ref.watch(searchRepositoryProvider)).call();
});

final categoryFeedProvider =
    FutureProvider.autoDispose.family<CategoryFeed, SubcategorySpec>(
  (ref, spec) async {
    final repo = ref.watch(searchRepositoryProvider);
    final config = await ref.watch(searchConfigProvider.future);
    return GetCategoryFeedUseCase(repo).call(spec, config);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH NOTIFIER + PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repo);
});

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH NOTIFIER
// All business logic that was previously in _SearchPageState lives here.
// ─────────────────────────────────────────────────────────────────────────────

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchContract _repo;

  late final SearchUsersUseCase _searchUsers;
  late final SearchPostsUseCase _searchPosts;
  late final GetRecentsUseCase _getRecents;
  late final SaveRecentUseCase _saveRecent;
  late final RemoveRecentUseCase _removeRecent;
  late final ClearRecentsUseCase _clearRecents;

  static const int _debounceMs = 400;
  static const int _minQueryLength = 2;

  Timer? _debounceTimer;

  SearchNotifier(this._repo) : super(const SearchState()) {
    _searchUsers = SearchUsersUseCase(_repo);
    _searchPosts = SearchPostsUseCase(_repo);
    _getRecents = GetRecentsUseCase(_repo);
    _saveRecent = SaveRecentUseCase(_repo);
    _removeRecent = RemoveRecentUseCase(_repo);
    _clearRecents = ClearRecentsUseCase(_repo);
    _loadRecents();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── RECENTS ──────────────────────────────────────────────────────────────

  Future<void> _loadRecents() async {
    final recents = await _getRecents.call();
    if (mounted) state = state.copyWith(recentSearches: recents);
  }

  Future<void> removeRecent(String term) async {
    await _removeRecent.call(term);
    final updated = state.recentSearches.where((s) => s != term).toList();
    state = state.copyWith(recentSearches: updated);
  }

  Future<void> clearAllRecents() async {
    await _clearRecents.call();
    state = state.copyWith(recentSearches: []);
  }

  // ── QUERY HANDLING ────────────────────────────────────────────────────────

  /// Called on every keystroke from the search bar.
  void onQueryChanged(String val, {bool hasFocus = true}) {
    state = state.copyWith(
      query: val,
      showRecents: hasFocus && val.trim().isEmpty,
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      final trimmed = val.trim();
      if (trimmed.length < _minQueryLength) {
        state = state.copyWith(
          debouncedQuery: trimmed,
          userResults: [],
          postResults: [],
          loading: false,
          clearError: true,
          clearCachedQuery: true,
        );
      } else {
        state = state.copyWith(
          debouncedQuery: trimmed,
          loading: state.cachedQueryFor != trimmed,
        );
        _fetchSearch(trimmed);
      }
    });
  }

  /// Called when user submits from keyboard.
  void onSearchSubmitted(String val) {
    final trimmed = val.trim();
    if (trimmed.length < _minQueryLength) return;
    _debounceTimer?.cancel();
    if (state.cachedQueryFor != trimmed) {
      state = state.copyWith(debouncedQuery: trimmed, loading: true);
    }
    _fetchSearch(trimmed);
    _persistRecent(trimmed);
  }

  /// Clear the search field and reset all results.
  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      debouncedQuery: '',
      userResults: [],
      postResults: [],
      loading: false,
      clearError: true,
      clearCachedQuery: true,
      showRecents: true,
    );
  }

  /// Called when user taps a recent search chip.
  void applyRecentSearch(String term) {
    onQueryChanged(term, hasFocus: false);
    onSearchSubmitted(term);
  }

  /// Called when focus changes on the search bar.
  void onFocusChanged(bool hasFocus) {
    state = state.copyWith(
      showRecents: hasFocus && state.query.trim().isEmpty,
    );
  }

  /// Manually retry the last failed search.
  void retrySearch() {
    final q = state.debouncedQuery;
    if (q.length < _minQueryLength) return;
    state = state.copyWith(
      userResults: [],
      postResults: [],
      loading: true,
      clearError: true,
      clearCachedQuery: true,
    );
    _fetchSearch(q);
  }

  // ── INTERNAL FETCH ────────────────────────────────────────────────────────

  Future<void> _fetchSearch(String query) async {
    // Cache guard — skip if already have results for this query
    if (state.cachedQueryFor == query && state.hasResults && !state.loading) {
      return;
    }

    state = state.copyWith(
      loading: true,
      clearError: true,
      userResults: [],
      postResults: [],
    );

    try {
      // Run both searches concurrently
      final results = await Future.wait([
        _searchUsers.call(query),
        _searchPosts.call(query),
      ]);

      final userOutcome = results[0] as SearchUsersOutcome;
      final posts = results[1] as List<PostResult>;

      if (mounted) {
        state = state.copyWith(
          loading: false,
          userResults: userOutcome.users,
          postResults: posts,
          usedFallback: userOutcome.usedFallback,
          cachedQueryFor: query,
          clearError: true,
        );
        _persistRecent(query);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          loading: false,
          error: e,
          clearCachedQuery: true,
        );
      }
    }
  }

  Future<void> _persistRecent(String term) async {
    if (term.trim().isEmpty) return;
    await _saveRecent.call(term);
    final existing = state.recentSearches;
    final updated = [
      term.trim(),
      ...existing.where((s) => s != term.trim()),
    ].take(8).toList();
    if (mounted) state = state.copyWith(recentSearches: updated);
  }
}
