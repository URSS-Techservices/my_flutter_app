/**
 * Keeps `users/{uid}.interestTags` in sync.
 *
 * Every profile type stores what a person does in a different field. Search
 * needs ONE normalized list, so this trigger rebuilds it whenever a profile is
 * created or edited (including edits made after signup).
 *
 * The tag logic lives in interest_tags_core.js.
 */
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

const { buildInterestTags } = require('./interest_tags_core');

function sameList(a, b) {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

exports.syncInterestTags = onDocumentWritten('users/{uid}', async (event) => {
  const after = event.data && event.data.after;
  if (!after || !after.exists) return;

  const data = after.data();
  const next = buildInterestTags(data);
  const prev = Array.isArray(data.interestTags) ? [...data.interestTags].sort() : [];

  // Writing only when the list changed also stops the trigger from looping.
  if (sameList(prev, next)) return;
  await after.ref.update({ interestTags: next });
});
