/**
 * Backfill contentTokens on posts for faster Explore similarity.
 *
 * Usage:
 *   cd functions
 *   npm run backfill:content-tokens
 */
const admin = require('firebase-admin');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';
const maxDocs = Math.min(
  Math.max(parseInt(process.env.MAX_DOCS || '400', 10), 1),
  500,
);
const dryRun = process.env.DRY_RUN === '1';

const STOP = new Set([
  'the', 'and', 'for', 'with', 'from', 'this', 'that', 'your', 'you', 'are',
  'was', 'were', 'have', 'has', 'had', 'been', 'will', 'just', 'our', 'all',
  'but', 'not', 'can', 'get', 'out', 'day', 'new', 'one', 'two', 'how', 'what',
  'when', 'where', 'who', 'why', 'into', 'about', 'over', 'than', 'then', 'them',
  'they', 'like', 'post', 'video', 'reel',
]);

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

function stringList(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((v) => String(v).trim()).filter(Boolean);
}

function tokenize(text) {
  const out = new Set();
  const parts = String(text || '')
    .toLowerCase()
    .split(/[^a-z0-9+#/&]+/);
  for (const part of parts) {
    const token = part.trim();
    if (token.length < 3) continue;
    if (STOP.has(token)) continue;
    out.add(token);
  }
  return out;
}

function tokensForPost(data) {
  const tokens = new Set();
  const add = (value) => {
    for (const t of tokenize(value)) tokens.add(t);
  };

  for (const tag of stringList(data.tags)) add(tag);
  add(data.caption);
  add(data.description);
  add(data.locationName);
  add(data.location);
  for (const spec of stringList(data.authorSpecializations)) add(spec);

  return Array.from(tokens).slice(0, 48);
}

async function main() {
  const fs = admin.firestore();
  const snap = await fs
    .collection('posts')
    .orderBy('timestamp', 'desc')
    .limit(maxDocs)
    .get();

  let batch = fs.batch();
  let pending = 0;
  let updated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const tokens = tokensForPost(data);
    if (tokens.length === 0) {
      skipped++;
      continue;
    }

    const prev = JSON.stringify(data.contentTokens || []);
    const next = JSON.stringify(tokens);
    if (prev === next) {
      skipped++;
      continue;
    }

    if (dryRun) {
      console.log(`[dry-run] ${doc.id} tokens=${tokens.length}`);
      updated++;
      continue;
    }

    batch.set(doc.ref, { contentTokens: tokens }, { merge: true });
    updated++;
    pending++;
    if (pending >= 400) {
      await batch.commit();
      batch = fs.batch();
      pending = 0;
    }
  }

  if (pending > 0) await batch.commit();
  console.log(
    `[backfill_content_tokens] scanned=${snap.size} updated=${updated} skipped=${skipped}`,
  );
}

main().catch((e) => {
  console.error('[backfill_content_tokens] failed', e);
  process.exit(1);
});
