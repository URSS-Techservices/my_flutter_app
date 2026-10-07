// Shared helper for user search. Used by SearchPage (prefix query) and
// anywhere we write user docs so that search finds them correctly.

/// Builds a single lowercase string from display name + username for
/// Firestore prefix search (orderBy('searchTerms').startAt/endAt).
/// Store this in user doc as `searchTerms` and create index: users, searchTerms (Ascending).
String buildSearchTerms({
  String? name,
  String? username,
  String? fullName,
  String? businessName,
}) {
  final n = _trim(name ?? fullName ?? businessName ?? '');
  final u = _trim(username ?? '');
  final combined = [n, u].where((s) => s.isNotEmpty).join(' ').toLowerCase();
  return combined.trim();
}

String _trim(String s) => s.trim();
