// ─────────────────────────────────────────────────────────────────────────────
// INTEREST TAGS
// Every profile type stores what a person does in a different field
// (guru: specializations, wellness: facilities, aspirant: goals). We flatten
// them into ONE normalized list, `users/{uid}.interestTags`, so search only
// ever needs a single query.
//
// KEEP IN SYNC with functions/interest_tags.js (same normalization + fields).
// ─────────────────────────────────────────────────────────────────────────────

/// "Yoga & Breathwork" → "yoga_breathwork".
String normalizeTag(String raw) => raw
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// Builds the normalized, de-duplicated tag list from any mix of strings and
/// lists of strings (the raw option labels chosen during profile creation).
List<String> buildInterestTags(Iterable<Object?> sources) {
  final tags = <String>{};
  void add(Object? v) {
    if (v == null) return;
    if (v is Iterable) {
      v.forEach(add);
    } else {
      final t = normalizeTag(v.toString());
      if (t.isNotEmpty) tags.add(t);
    }
  }

  sources.forEach(add);
  return tags.toList()..sort();
}
