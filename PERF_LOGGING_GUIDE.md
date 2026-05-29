# Performance logging guide (Explore + Reels)

This project uses a **central logger** so the console stays quiet unless you turn channels on. Perf lines are also appended to a **session file** on the phone for sharing with debugging sessions.

## Quick start (profile mode on your Samsung)

```powershell
cd "C:\Users\Rohan\Documents\all vs code\tushar mobile application\my_flutter_app"
flutter devices
flutter run -d YOUR_DEVICE_ID --profile
```

On first launch you should see one line like:

```text
[PERF_FILE] writing to /data/user/0/.../app_flutter/perf_logs/perf_session_....log
```

## Control log noise

Edit **`lib/services/logging_config.dart`**, then hot restart (`R` in the `flutter run` terminal).

| Preset | Call in code (optional) | Console |
|--------|-------------------------|---------|
| Quiet (default in debug) | `LoggingConfig.applyQuietDefaults()` | Errors + warnings only |
| **Profile perf (default in profile)** | `LoggingConfig.applyProfilePerfDefaults()` | PERF, METRIC, EXPLORE, REEL, MEM, POOL warnings |
| Verbose firehose | `LoggingConfig.applyVerboseDefaults()` | Everything including lifecycle + resolver |

### Knobs

```dart
LoggingConfig.enabled = true;                    // master off switch
LoggingConfig.minConsoleLevel = LogLevel.info;   // error | warning | info | debug
LoggingConfig.categories = { LogCategory.perf, LogCategory.reel, ... }; // empty = all
LoggingConfig.writePerfToFile = true;            // append perf/metric to file
```

**Examples**

- Only errors: `minConsoleLevel = LogLevel.error`, `categories = {}`
- Perf only: `categories = { LogCategory.perf, LogCategory.metric }`
- No file I/O: `writePerfToFile = false`

Categories: `perf`, `metric`, `explore`, `reel`, `pool`, `lifecycle`, `memory`, `firebase`, `resolver`, `error`, `warning`, `general`.

## What to do in the app (2–3 minutes)

1. Open **Explore** — scroll the grid 10–15 seconds.
2. Tap a **video** — full-screen reels viewer opens; swipe 3–5 reels.
3. (Optional) Open standalone **Reels** tab if your app has one.
4. Leave Explore (back) — a **summary** prints in the terminal and the session file keeps all PERF lines.

## Log lines you should see

| Tag | Meaning |
|-----|---------|
| `[PERF] explore_page_open` | Explore mounted |
| `[PERF] explore_fetch_start` / `explore_firestore_done` | Firestore page load + `ms=` timing |
| `[PERF] explore_setState` | Rebuild after fetch (`reason=fetchFinally`) |
| `[PERF] explore_reels_open` | User opened reel viewer |
| `[PERF] explore_reels_close` | Reel viewer disposed; pool cleared |
| `[PERF] video_memory_bridge_installed` | RSS watchdog active (profile/debug) |
| `[PERF] memory_soft` / `memory_hard` / `memory_critical` | Heap pressure actions |
| `[METRIC] tap_to_first_frame_ms` | Tap → first decoded frame (Explore reels) |
| `[PERF] reels_feed_open` | Standalone reels feed |
| `[PERF] reels_firestore_ready` | Ranked reels list size |
| `[PERF] reels_controller_created` | New BetterPlayer instance |
| `[PERF] reels_first_frame` | First frame in standalone reels |
| `[WARN] state=soft` … | Memory watchdog (RSS MB) |

## Share logs with us

### Option A — Pull the session file (best)

1. After reproducing slowness, note the path from `[PERF_FILE] writing to ...` in the terminal, **or** leave Explore (back) and look for `=== PERF SESSION SUMMARY ===` with `file:` path.
2. On PC (USB debugging on):

```powershell
adb shell run-as in.urss.halo cat app_flutter/perf_logs/perf_session_*.log
```

Application id: `in.urss.halo` (`android/app/build.gradle`). If `run-as` fails, use Android Studio **Device File Explorer** → `data/data/in.urss.halo/app_flutter/perf_logs/` → download the `.log` file.

3. Attach the `.log` file or paste the last ~200 lines in chat.

### Option B — Terminal filter

While `flutter run --profile` is running:

```powershell
# PowerShell — only our tags
flutter run -d DEVICE --profile 2>&1 | Select-String '\[PERF\]|\[METRIC\]|\[EXPLORE\]|\[REEL\]|\[MEM\]|\[WARN\]'
```

Or copy the block under `=== PERF SESSION SUMMARY ===` from the console.

### Option C — Paste template

Copy this into your message and fill timings from logs:

```text
Device: SM G990B2
Mode: profile
Logging: applyProfilePerfDefaults

Explore scroll: smooth / janky
explore_firestore_done ms=???
explore_setState ms=???

Reels tap: tap_to_first_frame_ms=??? postId=???
reels_first_frame reelId=??? (if using Reels tab)

Memory: RSS climbed / dropped after leaving reels
Session file: (path or attach)
```

## Tracking over multiple runs

Session files live under:

`app_flutter/perf_logs/perf_session_<timestamp>.log`

Each profile run creates a **new** file (timestamp in name). Keep the files you care about and compare `explore_firestore_done ms=` and `tap_to_first_frame_ms` across runs after code changes.

## Implementation files

| File | Role |
|------|------|
| `lib/services/logging_config.dart` | **You edit this** — levels & categories |
| `lib/services/app_logger.dart` | `AppLogger.perf / .metric / .debug / .warning / .error` |
| `lib/services/perf_session_log.dart` | Ring buffer + on-disk append |
| `lib/Bottom Pages/ExplorePage.dart` | Explore + inline reels perf |
| `lib/reels/reels_feed.dart` | Standalone reels perf |
| `lib/services/reel_player_lifecycle.dart` | Lifecycle (debug level — off unless verbose) |
| `lib/services/video_memory_bridge.dart` | RSS watchdog → pool + home cache eviction |
| `lib/services/reel_streaming_coordinator.dart` | Prefetch window (current + next only) |

## Release builds

In release mode, `LoggingConfig.applyForCurrentMode()` turns logging **off** automatically so users never pay the cost.
