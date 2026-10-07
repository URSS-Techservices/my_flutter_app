# Halo Video Pipeline — Developer Handoff

**Project:** Halo Flutter app (`my_flutter_app`)  
**Firebase project:** `halo-fb212`  
**Functions region:** `us-central1`  
**Storage bucket:** `halo-fb212.firebasestorage.app`  
**Last updated:** May 2026  

This document summarizes a debugging and hardening session on the video transcode / reels / Explore subsystem. It is intended for developers onboarding to the codebase or continuing work on legacy video migration.

---

## Table of contents

1. [Architecture overview](#architecture-overview)
2. [How transcoding is triggered](#how-transcoding-is-triggered)
3. [Issues found and fixes](#issues-found-and-fixes)
4. [Client UI: Processing vs Unavailable](#client-ui-processing-vs-unavailable)
5. [Migration tool (`migrateLegacyVideos`)](#migration-tool-migratelegacyvideos)
6. [Key files](#key-files)
7. [Firestore fields reference](#firestore-fields-reference)
8. [Successful post example](#successful-post-example)
9. [Operational runbook](#operational-runbook)
10. [Remaining backlog](#remaining-backlog)
11. [Recommendations for future work](#recommendations-for-future-work)

---

## Architecture overview

```
┌─────────────────┐     upload      ┌──────────────────────────┐
│  Flutter app    │ ──────────────► │ Firebase Storage         │
│  UploadService  │                 │ users/{uid}/posts/       │
└────────┬────────┘                 │   {postId}/video.mp4     │
         │                          └────────────┬─────────────┘
         │ Firestore metadata                    │ onObjectFinalized
         ▼                                       ▼
┌─────────────────┐                 ┌──────────────────────────┐
│ posts/{postId}  │ ◄────────────── │ processVideo (CF)        │
│ processed,hlsUrl│   update doc    │ FFmpeg → HLS + MP4s      │
└────────┬────────┘                 └──────────────────────────┘
         │ document.written
         ▼
┌─────────────────┐
│ requeueLegacyPost (CF) — safety net for stuck / legacy docs
└─────────────────┘
```

**Playback resolution (client):** `lib/services/video_playback_resolver.dart`

Priority chain:

1. Processed HLS (`master.m3u8`)
2. Processed optimized MP4 (`optimized_720.mp4`, etc.)
3. Raw upload fallback (legacy / in-progress)
4. Missing / failed

**Processed output layout (Storage):**

```
videos/processed/posts/{postId}/0/
  master.m3u8
  360p.m3u8, 480p.m3u8, 720p.m3u8
  segments/{tier}/seg_*.ts
  optimized_360.mp4, optimized_480.mp4, optimized_720.mp4
  preview.mp4
  thumb.jpg
```

---

## How transcoding is triggered

| Path | Trigger | When |
|------|---------|------|
| **Normal upload** | Storage `processVideo` | New file at `users/{uid}/posts/{postId}/video.mp4` |
| **Legacy requeue** | Firestore `requeueLegacyPost` | Doc write matches `shouldRequeueNow()` |
| **Client auto-queue** | `VideoTranscodeQueueService` | Explore shows legacy raw video |
| **Manual migration** | Callable `migrateLegacyVideos` | Admin taps sync icon on Explore |

### `requeueLegacyPost` vs `requeueLegacyReel`

- **`requeueLegacyPost`** — listens to `posts/{postId}`. **This is what Halo uses** for grid/reels content.
- **`requeueLegacyReel`** — listens to `reels/{reelId}`. **0 requests is normal**; almost all video lives in `posts`.

### `migrateLegacyVideos` — Run vs Retry failed

| Button | `retryPermanentFailures` | Behavior |
|--------|--------------------------|----------|
| **Run migration** | `false` | Queues unprocessed / legacy posts. **Skips** permanent `transcodeError`. |
| **Retry failed transcodes** | `true` | Also retries permanent failures; clears error fields and resets attempt count. |

Example successful log:

```json
{
  "posts": { "scanned": 31, "queued": 14, "skipped": 17 },
  "reels": { "scanned": 0, "queued": 0, "skipped": 0 },
  "stuck": { "posts": { "scanned": 0, "queued": 0, "skipped": 0 } }
}
```

---

## Issues found and fixes

### Issue #1 — FFmpeg “Filter not found” (P0) ✅ Fixed

**Symptoms:** New uploads failed immediately; `transcodeError: Filter not found`.

**Root cause:** Malformed FFmpeg filter chain in `scalePadFilter()`. When rotation was 0°, an empty filter prefix produced a leading comma (`,scale=...`), which FFmpeg rejects.

**Fix (`functions/index.js`):**

- Replaced `rotationFilterPrefix()` with `rotationFilters()` array (no empty strings).
- Simplified scale: `scale=W:H:force_original_aspect_ratio=decrease`.
- Removed invalid `-metadata:s:v side_data=`.

**Verify:** `node functions/scripts/test_vf.js`

---

### Issue #1b — HLS validation `zero_segments` ✅ Fixed

**Symptoms:** Transcode completed in Storage but Firestore stayed `processed: false`; error `HLS validation failed … zero_segments`.

**Root cause:** After rewriting playlist URLs, segment lines end with `?alt=media&token=…`, not `.ts`. Validation used `endsWith('.ts')`.

**Fix:** `isHlsSegmentRef()` / `isHlsPlaylistRef()` use regex `/\.ts(\?|$)/i`.

---

### Issue #1c — Firestore array update failure ✅ Fixed

**Symptoms:** `FieldValue.delete() cannot be used inside of an array (found in field "media.0.transcodeError")`.

**Root cause:** `updatePostDoc()` tried to delete fields inside `media[]` using `FieldValue.delete()`.

**Fix:** `omitTranscodeErrorFields()` strips error keys from media objects instead of using delete inside arrays.

---

### Issue #2 — Requeue loop (800+ `transcodeAttemptCount`) ✅ Fixed

**Symptoms:** Failed posts retried hundreds of times; runaway Cloud Function cost.

**Root causes:**

1. `isNewUpload` requeued failed docs that looked like fresh uploads.
2. Missing `transcodeErrorCategory` on old docs bypassed permanent-failure guard.
3. Race: concurrent `onDocumentWritten` invocations started parallel pipelines.
4. `legacyRawFallback: true` stayed set after permanent failure.

**Fix (`functions/index.js`):**

- `MAX_REQUEUE_ATTEMPTS = 12` (single constant).
- `isPermanentTranscodeDoc()` — infers permanent failures from error text when category missing.
- `isTranscodeInFlight()` — blocks duplicate runs (~11 min window).
- `hasFreshTranscodeRequest()` — permanent failures need new `requestedTranscodeAt`.
- `claimLegacyTranscodeJob()` — Firestore transaction for atomic claim.
- `transcodeRequeueExhausted` flag when cap hit.
- Clear `legacyRawFallback` on permanent / exhausted failure.

---

### Issue #3 — Raw videos never transcoded ✅ Fixed

**Symptoms:** May 2026 posts had `media[].videoUrl` but no `rawVideoUrl`, no `processed` flag; pipeline never ran.

**Root cause:** `shouldRequeueNow()` only treated `rawVideoUrl` as a new upload, not `videoUrl` / `media.url`.

**Fix:**

- **Backend:** `hasTranscodableRawSource()`, expanded `isNewUpload`, migration pass 3 (scan by `timestamp` / `createdAt`).
- **Client:** `VideoTranscodeQueueService` — flags docs when Explore detects legacy raw.
- **Client:** `isRawUploadStorageUrl()` recognizes flat legacy paths.

**Affected post IDs (examples):** `4apvIYtE`, `LmLKOPqR`, `Ey36U66Q`, `bQ5KpVyW`, `ipOcJStn`, `g2cI3lXn`

---

### Issue #4 — Legacy HLS `index.m3u8` ✅ Already handled (client)

**Symptoms:** Post `g2cI3lXn` had `hlsUrl` pointing to `videos/reel1/index.m3u8`.

**Behavior:** `isLegacyOrInvalidHlsUrl()` in `video_playback_resolver.dart` **rejects** old playlist URLs. App falls back to raw / re-transcoded `master.m3u8`.

**Migration:** Clears stale legacy `hlsUrl` when queuing; successful transcode overwrites with `master.m3u8`.

---

### Issue #5 — Legacy flat Storage paths ✅ Fixed

**Symptoms:** Feb–Apr posts used `users/{uid}/posts/{postId}-{timestamp}.mp4` instead of `video.mp4`. `processVideo` never matched.

**Fix:** Extended `parseUploadContext()` for:

- `users/{uid}/posts/{postId}-{timestamp}.mp4`
- `posts/{postId}-{timestamp}.mp4` (root fallback)

**Affected post IDs (examples):** `8URpLtnz`, `Iz7gfmjf`, `cGaiDEOn`, `hIXKmmwk`, `oOEff6zi`, `tywvWScP`, `xtLIeUxa`

---

### Issue #6 — Migration dialog buttons not working ✅ Fixed

**Symptoms:** Long-press Explore → AlertDialog; Cancel / Run / Retry did nothing; `migrateLegacyVideos` showed 0 requests.

**Root cause:** `AlertDialog` with three horizontal action buttons — broken touch targets on mobile.

**Fix:**

- Replaced with **`showModalBottomSheet`** + full-width buttons.
- Added visible **sync icon (↻)** on Explore header.
- `VideoMigrationService` uses `FirebaseFunctions.instanceFor(region: 'us-central1')` + 10 min timeout.

---

### Issue #7 — Healthy processed posts corrupted after playback ✅ Fixed

**Symptoms:** Post `k9KvQsooxxlt8YlSOgnV` (and others) played once, then Home showed videocam-off, Explore showed Processing/Unavailable — despite `processed: true` and valid `master.m3u8` in Firestore.

**Root cause chain:**

1. HLS player error (often **empty error message** on transient failure).
2. `_VideoCell._recordCapabilityFailure()` treated it as decoder failure.
3. Wrote to Firestore: `transcodeError: exceeds_capabilities`, `requestedTranscodeAt`, `legacyRawFallback`.
4. Resolver saw `transcodeError` → empty playback URL.
5. URL added to `BlockedUrlMemory` (persists in SharedPreferences).

**Fix:**

- Never write `transcodeError` to **`processed: true`** posts (or posts with `master.m3u8`).
- Do not treat empty errors on **HLS URLs** as permanent decoder failure.
- Resolver ignores spurious `exceeds_capabilities` when processed outputs exist.
- Fall back to processed MP4 when HLS is blocklisted.
- `hasTranscodeFailure` on Explore grid ignores spurious client error on processed posts.

**Manual cleanup for corrupted docs:** Delete `transcodeError`, `legacyRawFallback`, `requestedTranscodeAt` (keep `processed`, `hlsUrl`, etc.).

---

## Client UI: Processing vs Unavailable

Explore grid overlay (`ExplorePage.dart` → `_InstagramGridTile`):

```dart
showExploreGridProcessingOverlay = isVideo && !isInstantPlayableForExplore()
```

| Label | Condition |
|-------|-----------|
| **Processing** | Video + not instant-playable + **no** `transcodeError` (or spurious error ignored) |
| **Unavailable** | Video + not instant-playable + **real** `transcodeError` |

**Instant-playable** requires a non-blocked URL and status `readyHls`, `readyMp4`, or safe raw `processing`.

**Home feed:** Shows “Processing video…” spinner or videocam-off when `playback.primaryUrl` is empty or player init fails.

**Important:** Explore uses **paginated fetch**, not live Firestore listeners. After transcode completes, users must **pull-to-refresh** to see updated grid state.

---

## Migration tool (`migrateLegacyVideos`)

### From the app

1. Open **Explore**.
2. Tap **sync icon (↻)** top-right (or long-press “Explore”).
3. **Run migration** — legacy / never-processed posts.
4. **Retry failed transcodes** — posts with permanent FFmpeg errors (after deploying fixes).
5. Wait for snackbar: `Migration done: { posts: { queued: N, ... } }`.
6. **Pull to refresh** Explore.

### From CLI (no app)

```bash
cd functions
npx firebase login   # if needed
node scripts/run_migrate_local.js
```

Env: `MAX_DOCS=200`, `RETRY_PERMANENT=1` for retry-failed mode.

### Deploy functions

```bash
firebase deploy --only functions:processVideo,functions:requeueLegacyPost,functions:migrateLegacyVideos
```

### App Check warnings in logs

```
Failed to validate AppCheck token … Allowing request with invalid AppCheck token because enforcement is disabled
```

Safe in **debug** builds. Callable still returns 200. Enable enforcement only after registering debug tokens in Firebase Console.

---

## Key files

| Area | Path |
|------|------|
| Cloud Functions pipeline | `functions/index.js` |
| FFmpeg / requeue tests | `functions/scripts/test_vf.js` |
| Local migration script | `functions/scripts/run_migrate_local.js` |
| Playback resolver | `lib/services/video_playback_resolver.dart` |
| Blocked URL persistence | `lib/services/blocked_url_memory.dart` |
| Auto-queue legacy raw | `lib/services/video_transcode_queue_service.dart` |
| Migration callable client | `lib/services/video_migration_service.dart` |
| Explore grid + reels + migration UI | `lib/Bottom Pages/ExplorePage.dart` |
| Home feed video | `lib/Bottom Pages/HomePage.dart` |
| Upload paths | `lib/services/upload_service.dart` |
| HLS design notes | `functions/ADAPTIVE_HLS.md` |

---

## Firestore fields reference

| Field | Meaning |
|-------|---------|
| `processed` | `true` when transcode succeeded |
| `processing` | `true` while pipeline running |
| `hlsUrl` | Should point to `…/master.m3u8` when done |
| `qualities` | Map of tier → optimized MP4 URLs |
| `previewUrl` | Short MP4 for fast grid/reel start |
| `rawVideoUrl` | Original upload (kept for re-transcode) |
| `transcodeError` | Failure message; blocks playback in resolver |
| `transcodeErrorCategory` | `permanent` \| `transient` |
| `transcodeAttemptCount` | Requeue cycles (cap: 12) |
| `transcodeRequeueExhausted` | `true` when cap hit |
| `legacyRawFallback` | Client/migration flag to trigger requeue |
| `requestedTranscodeAt` | Fresh requeue request timestamp |
| `requeuedAt` | Last claim timestamp (dedup) |

**Do not** set `transcodeError: exceeds_capabilities` on posts that already have `processed: true` and `master.m3u8`.

---

## Successful post example

Post **`1U7cGFMOhBtEnDMcaJJl`** (“testing sunday 3”) — reference for a healthy doc:

- `processed: true`, `processing: false`
- `hlsUrl` → `videos/processed/posts/{id}/0/master.m3u8`
- `qualities`: 360 / 480 / 720
- `previewUrl`, `thumbnailUrl`, `videoUrl` (optimized MP4)
- Source HEVC 720×1280 → normalized to H.264 HLS

Post **`k9KvQsooxxlt8YlSOgnV`** (“testing sunday 4”) — same successful transcode pattern; was temporarily broken by client-side error handler (Issue #7).

---

## Operational runbook

### Rehydrate posts (HLS in Storage, bad Firestore)

If Storage has `master.m3u8` but Firestore failed to update:

1. Delete `transcodeError*` fields.
2. Set `legacyRawFallback: true`, `requestedTranscodeAt: serverTimestamp`.
3. Optionally reset `transcodeAttemptCount: 0`.
4. `requeueLegacyPost` will rehydrate without re-encoding.

### Stuck at `processing: true`

Use migration with `includeStuckProcessing: true` (default in app) or `migrateStuckProcessing` in functions.

### Verify transcode in logs

Firebase Console → Functions → **`requeueLegacyPost`** → Logs:

- `[LEGACY_REQUEUE]` — picked up doc
- `[PROCESS_COMPLETE]` — success
- `[PROCESS_FAILED_FINAL]` — failure (check error text)

### Timing expectations

| Step | Duration |
|------|----------|
| Migration Firestore writes | ~5–30 s |
| Per-video transcode | ~2–8 min (540 s CF timeout) |
| UI update | After **pull-to-refresh** on Explore |

---

## Remaining backlog

| # | Topic | Status |
|---|--------|--------|
| 6 | Dual image storage (Cloudinary vs Firebase WebP) | Not started |
| 7 | Placeholder URL post `ZhrRJOv2` | Not started |
| 8 | Schema inconsistencies (`userId`, `hasMedia`, etc.) | Not started |
| 9 | Failed transcode UX (blank player improvements) | Partially addressed |
| — | Live Firestore listener on Explore (auto-refresh grid) | Suggested |
| — | Home feed MP4 fallback when HLS fails | Suggested |
| — | Bulk rehydrate script for known stuck post IDs | Manual / migration |

---

## Recommendations for future work

### High priority

1. **Never corrupt Firestore from client player errors** — server-owned `transcodeError` only; client uses local `BlockedUrlMemory` + MP4 fallback.
2. **Home `_NetworkVideo` fallback** — on HLS init failure, retry `fallbackUrl` (processed MP4) before showing error icon.
3. **Explore live updates** — optional Firestore snapshot on visible posts or refresh after `processing → processed` transition.
4. **App Check** — register debug tokens for dev; enable enforcement in production when stable.

### Medium priority

5. **Admin-only migration** — restrict `migrateLegacyVideos` via `ADMIN_UIDS` in `functions/index.js`.
6. **Rehydrate callable** — one-shot function for posts with HLS in Storage but bad Firestore (avoid manual Console edits).
7. **Metrics** — alert on `transcodeAttemptCount > 5` or `requeueLegacyPost` error rate.

### Low priority / architecture

8. **CDN** — Storage in `us-central1`; consider CDN if most users are in India.
9. **Consolidate `reels` vs `posts`** — today video is in `posts`; `reels` collection adds confusion.
10. **Remove dead code** — `ReelSourceResolver`, unused `CloudinaryService` in main upload path.

### Testing checklist for new video features

- [ ] Upload new video → `processVideo` → `processed: true` within ~10 min
- [ ] Explore grid shows play icon (not Processing) after refresh
- [ ] Reel viewer plays HLS; falls back to MP4 if HLS blocked
- [ ] No `transcodeError` written after transient player error on processed post
- [ ] Migration Run queues legacy flat-path posts
- [ ] Migration Retry failed clears permanent errors and re-transcodes
- [ ] `node functions/scripts/test_vf.js` passes (requeue guards)

---

## Git / deploy note

Changes from this session span **`functions/index.js`**, **`lib/Bottom Pages/ExplorePage.dart`**, **`lib/services/*`**, and **`functions/scripts/`**. Deploy Cloud Functions and ship a new app build together when testing end-to-end migration and playback fixes.

For questions about schema details, see also `FIREBASE_SCHEMA.md` and `functions/ADAPTIVE_HLS.md`.
