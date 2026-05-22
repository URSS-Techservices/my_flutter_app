# Adaptive HLS transcoding pipeline

## Storage layout

```
videos/processed/posts/{postId}/{index}/
  master.m3u8
  1080p.m3u8
  720p.m3u8
  480p.m3u8
  360p.m3u8
  optimized_1080.mp4
  optimized_720.mp4
  optimized_480.mp4
  optimized_360.mp4
  thumb.jpg
  segments/
    1080/seg_000.ts …
    720/seg_000.ts …
    480/…
    360/…
```

Reels: `videos/processed/{reelId}/` (same structure).

## Firestore (posts / reels)

| Field | Value |
|--------|--------|
| `processed` | `true` |
| `processing` | `false` |
| `hlsUrl` | `master.m3u8` download URL |
| `videoUrl` | `optimized_720.mp4` (MP4 fallback) |
| `thumbnailUrl` | `thumb.jpg` |
| `qualities` | `{ "1080": url, "720": url, "480": url, "360": url }` |
| `media[].hlsUrl` / `qualities` | Same per video item |

Legacy posts with `hls/playlist.m3u8` or `optimized.mp4` still play via the client resolver.

## FFmpeg (per tier)

- **Video:** H.264 Main, yuv420p, 30 fps, bt709 (SDR), scale+pad inside max box (aspect preserved, no stretch)
- **Orientation:** ffprobe display size (rotation 90/270 → portrait); ladder picks portrait or landscape targets
- **Landscape boxes:** 1920×1080, 1280×720, 854×480, 640×360
- **Portrait boxes:** 1080×1920, 720×1280, 480×854, 360×640
- **Output:** `rotate=0` on encoded streams (pixels already upright; avoids double-rotate in players)
- **Audio:** AAC 128 kbps, 44.1 kHz stereo
- **Bitrates:** 1080 ~5 Mbps, 720 ~3 Mbps, 480 ~1.5 Mbps, 360 ~800 kbps
- **Normalize pass:** single decode from camera master → `_normalized.mp4` (top-tier max box for detected orientation), then ladder encodes

## npm packages

- `ffmpeg-static` — FFmpeg binary
- `@ffprobe-installer/ffprobe` — source dimensions for ladder selection
- `fluent-ffmpeg` — Node wrapper
- `firebase-admin`, `firebase-functions` — unchanged

## Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions:processVideo
```

## Migration

- **New uploads:** automatic adaptive output after deploy.
- **Old single-720p assets:** no re-transcode required; resolver still uses `optimized.mp4` / `hls/playlist.m3u8`.
- **Optional backfill:** re-upload raw file or copy raw to trigger path to regenerate `master.m3u8`.

## Duplicate processing

Skipped if `master.m3u8` or legacy `hls/playlist.m3u8` already exists under `processedBase`.

## Firebase HLS tokens

All files in a transcode job share one `firebaseStorageDownloadTokens` value. Variant and master `.m3u8` playlists are rewritten to **absolute** download URLs so ExoPlayer / AVPlayer can fetch `.ts` segments (relative paths do not inherit the token).
