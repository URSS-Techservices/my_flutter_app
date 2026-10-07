/**
 * Pure interest-tag logic (no Firebase dependencies) so both the Cloud Function
 * and the seed/backfill script can use it.
 *
 * KEEP IN SYNC with lib/features/search/domain/interest_tags.dart
 * (same normalization, same source fields).
 */
function normalizeTag(raw) {
  return String(raw)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function buildInterestTags(data) {
  const tags = new Set();
  const add = (v) => {
    if (v == null) return;
    if (Array.isArray(v)) return v.forEach(add);
    const t = normalizeTag(v);
    if (t) tags.add(t);
  };

  switch (String(data.accountType || '').toLowerCase()) {
    case 'guru':
      add(data.areas_of_specialization);
      add(data.profession);
      break;
    case 'wellness':
      add(data.facilities_services);
      add(data.business_type);
      break;
    case 'aspirant':
      add(data.fitness_goals);
      break;
  }
  add(data.interests); // older docs
  return [...tags].sort();
}

module.exports = { normalizeTag, buildInterestTags };
