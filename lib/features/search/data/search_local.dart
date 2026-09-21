import 'package:shared_preferences/shared_preferences.dart';

// SEARCH LOCAL DATA SOURCE
// Manages recent search history using SharedPreferences.

class SearchLocal {
  static const String _key = 'halo_recent_searches';
  static const int _maxItems = 8;

  /// Load saved search terms.
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Add a term to the top of the list (deduplicates, trims to max).
  Future<void> saveSearch(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_key) ?? [];
      final updated = [
        trimmed,
        ...existing.where((s) => s != trimmed),
      ].take(_maxItems).toList();
      await prefs.setStringList(_key, updated);
    } catch (_) {}
  }

  /// Remove a single term.
  Future<void> removeSearch(String term) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_key) ?? [];
      await prefs.setStringList(
          _key, existing.where((s) => s != term).toList());
    } catch (_) {}
  }

  /// Wipe all recent searches.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
