# Phase 4 — iOS / AVPlayer lifecycle hardening

## Changed files

| File | Changes |
|------|---------|
| `lib/services/reel_player_lifecycle.dart` | **New** — platform policy, generation helpers, fallback tracker, `[ReelLifecycle]` logs |
| `lib/services/video_playback_resolver.dart` | iOS reels: HLS primary; Android reels: MP4 primary |
| `lib/reels/reels_feed.dart` | Pool limits, generation guards, poster-until-first-frame, memory pressure |
| `lib/Bottom Pages/ExplorePage.dart` | `VideoControllerPool` generation + iOS pool size 2; prefetch window; `_VideoCell` poster |
| `lib/Bottom Pages/HomePage.dart` | `_NetworkVideo` init generation + iOS cache limit 2 |

**Not modified:** Cloud Functions, FFmpeg, Firestore, upload, adaptive ladder.

## iOS-specific logic

- **Pool:** max **2** slots (current + next). No `+2`, no ahead warm surfaces, no muted preload `play()`.
- **Playback URLs:** `resolveReelPlayback` keeps **HLS → MP4 (720) → raw** on iOS (AVPlayer adaptive).
- **Android:** max **3** pool slots (current, prev, next, +2 warm); MP4-first for startup; optional ahead warm surfaces.
- **Memory:** `didHaveMemoryPressure` clears pool except active reel.

## Pool limits

| Platform | Max pooled players | Warm indices |
|----------|-------------------|--------------|
| iOS | 2 | `center`, `center+1` |
| Android | 3 | `center-1` … `center+2` |

LRU evicts oldest when over limit.

## Lifecycle rules

1. Each pool slot has a **generation**; dispose increments it — async `setupDataSource` / `play` / `seek` abort if stale.
2. Each `ReelItem` has **bind generation**; unbind/dispose bumps it.
3. **Fallback:** `ReelPlaybackFallbackTracker` records attempted URLs — one alternate only, no HLS↔MP4 loops.
4. **Poster** stays until `initialized` **and** first frame (`play` / `progress` while active).
5. **Inactive:** volume 0 + pause; no autoplay on warm-only slots (iOS: prepare only).

## Debug logs

Filter Xcode/console: `[ReelLifecycle]`

## Manual validation checklist

- [ ] Android upload → iPhone playback (processed HLS)
- [ ] iPhone upload → iPhone playback
- [ ] Fast swipe 10 reels — no crash, no duplicate audio
- [ ] Background → resume — active reel only plays
- [ ] Explore → Home → Reels — no disposed controller errors
- [ ] No black flash (poster until first frame)

Automated stress tests were not run in CI; verify on physical iPhone + Android devices.
