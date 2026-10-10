/**
 * Cleans up after a post is deleted.
 *
 * The app deletes only `posts/{postId}` (and lowers the author's
 * postsCount). Everything that hangs off the post is removed here, with
 * admin rights, so nothing is left taking up storage or showing up broken:
 *   - likes / comments (and any nested sub-collections) under the post
 *   - photos and videos in Storage, including the processed HLS ladder
 *   - the post id in other users' `savedPosts` maps
 *   - a postsCount that went below zero
 *
 * Photos are de-duplicated across users (`media_hashes`): the same photo
 * uploaded twice points at the FIRST upload's files. So photo files are
 * only deleted when no other post still uses them; otherwise they (and
 * their media_hashes entry) are kept.
 */
const { onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

const SAVES_PAGE = 400;

async function deletePrefix(bucket, prefix) {
  try {
    await bucket.deleteFiles({ prefix, force: true });
  } catch (err) {
    console.warn(`post cleanup: could not delete ${prefix}`, err.message);
  }
}

async function deleteFile(bucket, path) {
  try {
    await bucket.file(path).delete({ ignoreNotFound: true });
  } catch (err) {
    console.warn(`post cleanup: could not delete ${path}`, err.message);
  }
}

async function removeFromSaves(db, postId) {
  const field = `savedPosts.${postId}`;
  for (;;) {
    const snap = await db
      .collection('users')
      .where(field, '==', true)
      .limit(SAVES_PAGE)
      .get();
    if (snap.empty) return;
    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.update(doc.ref, { [field]: admin.firestore.FieldValue.delete() });
    }
    await batch.commit();
    if (snap.size < SAVES_PAGE) return;
  }
}

/** True when another post still shows one of this post's photos. */
async function photosSharedWithOtherPosts(db, postId, data) {
  const urls = Array.isArray(data && data.images) ? data.images : [];
  for (const url of urls) {
    if (typeof url !== 'string' || !url) continue;
    const snap = await db
      .collection('posts')
      .where('images', 'array-contains', url)
      .limit(2)
      .get();
    if (snap.docs.some((d) => d.id !== postId)) return true;
  }
  return false;
}

async function deleteMediaHashes(db, data) {
  const media = Array.isArray(data && data.media) ? data.media : [];
  const hashes = media
    .map((m) => (m && typeof m.hash === 'string' ? m.hash : ''))
    .filter(Boolean);
  await Promise.all(
    hashes.map((h) => db.collection('media_hashes').doc(h).delete()),
  );
}

async function clampPostsCount(db, uid) {
  const ref = db.collection('users').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const count = snap.get('postsCount');
    if (typeof count === 'number' && count < 0) {
      tx.update(ref, { postsCount: 0 });
    }
  });
}

exports.onPostDeleted = onDocumentDeleted(
  { document: 'posts/{postId}', timeoutSeconds: 300 },
  async (event) => {
    const postId = event.params.postId;
    const data = event.data ? event.data.data() : null;
    const uid = data && typeof data.userId === 'string' ? data.userId : '';

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    const jobs = [
      // Sub-collections of the (already deleted) post document.
      db.recursiveDelete(db.collection('posts').doc(postId)),
      removeFromSaves(db, postId),
      deletePrefix(bucket, `videos/processed/posts/${postId}/`),
      // Legacy flat uploads: posts/{postId}-{timestamp}.mp4
      deletePrefix(bucket, `posts/${postId}-`),
    ];
    const photosShared = await photosSharedWithOtherPosts(db, postId, data);
    if (!photosShared) jobs.push(deleteMediaHashes(db, data));

    if (uid) {
      jobs.push(
        // Current uploads: users/{uid}/posts/{postId}/thumb.webp, video.mp4 …
        // Kept when another post reuses these photo files.
        photosShared
          ? deletePrefix(bucket, `users/${uid}/posts/${postId}/video`)
          : deletePrefix(bucket, `users/${uid}/posts/${postId}/`),
        // Older single-image / flat-video uploads.
        photosShared
          ? Promise.resolve()
          : deleteFile(bucket, `users/${uid}/posts/${postId}.jpg`),
        deletePrefix(bucket, `users/${uid}/posts/${postId}-`),
        clampPostsCount(db, uid),
      );
    }

    const results = await Promise.allSettled(jobs);
    for (const r of results) {
      if (r.status === 'rejected') {
        console.error(`post cleanup failed for ${postId}`, r.reason);
      }
    }
  },
);
