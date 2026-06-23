const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { randomUUID } = require('crypto');

const {
  computeGlobalExploreScores,
  rankFieldsChanged,
} = require('./explore_ranking');

const admin = require('firebase-admin');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('ffmpeg-static');
const ffprobePath = require('@ffprobe-installer/ffprobe').path;

const path = require('path');
const os = require('os');
const fs = require('fs');

admin.initializeApp();

ffmpeg.setFfmpegPath(ffmpegPath);
ffmpeg.setFfprobePath(ffprobePath);

/**
 * Instagram-tuned mobile ladder (1080 / 720 / 480).
 * 360p was dropped: at 2-sec GOP it adds latency without bandwidth savings.
 */
const TIER_KEYS = ['1080', '720', '480', '360'];

const BITRATE_BY_KEY = {
  1080: {
    videoBitrate: '3500k',
    maxrate: '3850k',
    bufsize: '7000k',
    bandwidth: 3850000,
  },
  720: {
    videoBitrate: '1800k',
    maxrate: '1980k',
    bufsize: '3600k',
    bandwidth: 1980000,
  },
  480: {
    videoBitrate: '900k',
    maxrate: '990k',
    bufsize: '1800k',
    bandwidth: 990000,
  },
  360: {
   videoBitrate:'500k',
   maxrate:'550k',
   bufsize:'1000k',
   bandwidth:550000
  },
};

const LADDER_LANDSCAPE = [
  { key: '1080', width: 1920, height: 1080 },
  { key: '720', width: 1280, height: 720 },
  { key: '480', width: 854, height: 480 },
  { key: '360', width: 640, height: 360 },
].map((t) => ({ ...t, ...BITRATE_BY_KEY[t.key] }));

const LADDER_PORTRAIT = [
  { key: '1080', width: 1080, height: 1920 },
  { key: '720', width: 720, height: 1280 },
  { key: '480', width: 480, height: 854 },
  { key: '360', width: 360, height: 640 },
].map((t) => ({ ...t, ...BITRATE_BY_KEY[t.key] }));

function ladderForOrientation(orientation) {
  return orientation === 'portrait' ? LADDER_PORTRAIT : LADDER_LANDSCAPE;
}

function tierLongEdge(tier) {
  return Math.max(tier.width, tier.height);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Firebase may send gs:// URIs, leading slashes, or URL-encoded paths. */
function normalizeStorageObjectPath(rawPath) {
  if (!rawPath) return '';
  let p = String(rawPath).trim();
  const gsMatch = p.match(/^gs:\/\/[^/]+\/(.+)$/i);
  if (gsMatch) p = gsMatch[1];
  while (p.startsWith('/')) p = p.slice(1);
  try {
    p = decodeURIComponent(p);
  } catch (_) {
    /* keep original */
  }
  return p.replace(/\\/g, '/');
}

function shouldSkipPath(filePath) {
  if (!filePath) return true;
  const lower = filePath.toLowerCase();
  if (lower.includes('/videos/processed/')) return true;
  if (lower.includes('/segments/')) return true;
  if (lower.endsWith('.m3u8') || lower.endsWith('.ts')) return true;
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
    return true;
  }
  if (lower.includes('/video_thumb')) return true;
  if (/\/optimized_\d+\.mp4$/i.test(filePath)) return true;
  if (lower.endsWith('/master.m3u8')) return true;
  return false;
}

/**
 * Post uploads: users/{uid}/posts/{postId}/video.mp4 | video_1.mp4 | video_2.mp4
 * Legacy flat: users/{uid}/posts/{postId}-{timestamp}.mp4  OR  posts/{postId}-{timestamp}.mp4
 * Reels: videos/raw/{id}.mp4
 */
function parseUploadContext(rawPath) {
  const filePath = normalizeStorageObjectPath(rawPath);
  if (!filePath) return null;

  if (shouldSkipPath(filePath)) {
    console.log(`[skip] non-source object: ${filePath}`);
    return null;
  }

  const reelMatch = filePath.match(
    /^videos\/raw\/(.+\.(mp4|mov|m4v|webm))$/i,
  );
  if (reelMatch) {
    const fileName = path.basename(filePath);
    const videoId = path.parse(fileName).name;
    return {
      kind: 'reel',
      storagePath: filePath,
      jobId: videoId,
      videoKey: '0',
      fileName,
    };
  }

  const postMatch = filePath.match(
    /^users\/([^/]+)\/posts\/([^/]+)\/(video(?:_(\d+))?)\.(mp4|mov|m4v|webm)$/i,
  );
  if (postMatch) {
    const uid = postMatch[1];
    const postId = postMatch[2];
    const videoStem = postMatch[3];
    const indexSuffix = postMatch[4];
    const ext = postMatch[5];
    const videoKey =
      videoStem === 'video' && (indexSuffix === undefined || indexSuffix === '')
        ? '0'
        : indexSuffix || videoStem.replace(/^video_/, '');
    const fileName = `${videoStem}.${ext}`;
    return {
      kind: 'post',
      uid,
      postId,
      videoKey,
      storagePath: filePath,
      fileName,
      jobId: `${postId}_${videoKey}`,
    };
  }

  const legacyFlatUserMatch = filePath.match(
    /^users\/([^/]+)\/posts\/(.+)-(\d+)\.(mp4|mov|m4v|webm)$/i,
  );
  if (legacyFlatUserMatch) {
    const uid = legacyFlatUserMatch[1];
    const postId = legacyFlatUserMatch[2];
    const ts = legacyFlatUserMatch[3];
    const ext = legacyFlatUserMatch[4];
    const fileName = `${postId}-${ts}.${ext}`;
    return {
      kind: 'post',
      uid,
      postId,
      videoKey: '0',
      storagePath: filePath,
      fileName,
      jobId: `${postId}_0`,
    };
  }

  const legacyFlatRootMatch = filePath.match(
    /^posts\/(.+)-(\d+)\.(mp4|mov|m4v|webm)$/i,
  );
  if (legacyFlatRootMatch) {
    const postId = legacyFlatRootMatch[1];
    const ts = legacyFlatRootMatch[2];
    const ext = legacyFlatRootMatch[3];
    const fileName = `${postId}-${ts}.${ext}`;
    return {
      kind: 'post',
      uid: '',
      postId,
      videoKey: '0',
      storagePath: filePath,
      fileName,
      jobId: `${postId}_0`,
    };
  }

  return null;
}

function parseVideoIndexFromKey(videoKey) {
  const n = parseInt(videoKey, 10);
  return Number.isNaN(n) ? 0 : n;
}

function storageDownloadUrl(bucketName, storagePath, token) {
  const encoded = encodeURIComponent(storagePath);
  return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encoded}?alt=media&token=${token}`;
}

async function setDownloadUrl(bucket, storagePath, contentType, sharedToken) {
  const file = bucket.file(storagePath);
  const token = sharedToken || randomUUID();
  await file.setMetadata({
    contentType,
    metadata: {
      firebaseStorageDownloadTokens: token,
    },
  });
  return storageDownloadUrl(bucket.name, storagePath, token);
}

/** Resolve relative FFmpeg HLS paths to Storage object paths under [processedBase]. */
function resolveHlsStoragePath(processedBase, line, tierKey) {
  const trimmed = line.trim().replace(/^\.\//, '');
  if (!trimmed || trimmed.startsWith('#')) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return null;

  if (trimmed.endsWith('.ts')) {
    if (trimmed.startsWith('segments/')) {
      return `${processedBase}/${trimmed}`;
    }
    if (trimmed.includes('/')) {
      return `${processedBase}/${trimmed}`;
    }
    if (tierKey) {
      return `${processedBase}/segments/${tierKey}/${trimmed}`;
    }
    return `${processedBase}/${trimmed}`;
  }

  if (trimmed.endsWith('.m3u8')) {
    if (trimmed.includes('/')) {
      return `${processedBase}/${trimmed}`;
    }
    return `${processedBase}/${trimmed}`;
  }

  return `${processedBase}/${trimmed}`;
}

/** Rewrite every .m3u8 / .ts reference to absolute Firebase download URLs (shared token). */
async function rewriteM3u8Playlists(bucket, processedBase, sharedToken) {
  const bucketName = bucket.name;
  const variantNames = TIER_KEYS.map((k) => `${k}p.m3u8`);
  const paths = [`${processedBase}/master.m3u8`, ...variantNames.map((n) => `${processedBase}/${n}`)];

  for (const storagePath of paths) {
    const file = bucket.file(storagePath);
    const [exists] = await file.exists();
    if (!exists) continue;

    const [buf] = await file.download();
    const tierMatch = storagePath.match(/\/(\d+)p\.m3u8$/);
    const tierKey = tierMatch ? tierMatch[1] : null;

    const rewritten = buf
      .toString()
      .split('\n')
      .map((line) => {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) return line;
        if (!trimmed.endsWith('.m3u8') && !trimmed.endsWith('.ts')) return line;

        const storagePathResolved = resolveHlsStoragePath(
          processedBase,
          trimmed,
          tierKey,
        );
        if (!storagePathResolved) return line;

        const downloadUrl = storageDownloadUrl(
          bucketName,
          storagePathResolved,
          sharedToken,
        );
        console.log(
          `[HLS rewrite] ${storagePath} :: ${trimmed} -> ${downloadUrl}`,
        );
        return downloadUrl;
      })
      .join('\n');

    await file.save(rewritten, {
      metadata: {
        contentType: 'application/vnd.apple.mpegurl',
        metadata: { firebaseStorageDownloadTokens: sharedToken },
      },
    });
  }
}

/** Relative `seg_000.ts` or Firebase URL `.../seg_000.ts?alt=media&token=`. */
function isHlsSegmentRef(line) {
  const trimmed = (line || '').trim();
  if (!trimmed || trimmed.startsWith('#')) return false;
  return /\.ts(\?|$)/i.test(trimmed);
}

/** Relative `720p.m3u8` or Firebase URL `.../720p.m3u8?alt=media&token=`. */
function isHlsPlaylistRef(line) {
  const trimmed = (line || '').trim();
  if (!trimmed || trimmed.startsWith('#')) return false;
  return /\.m3u8(\?|$)/i.test(trimmed);
}

async function httpStatusForUrl(url) {
  try {
    const head = await fetch(url, { method: 'HEAD', redirect: 'follow' });
    if (head.status === 200 || head.status === 206) return head.status;
    if (head.status === 405 || head.status === 501) {
      const getRes = await fetch(url, {
        method: 'GET',
        headers: { Range: 'bytes=0-1' },
        redirect: 'follow',
      });
      return getRes.status;
    }
    return head.status;
  } catch (err) {
    console.warn(`[HLS validate] request failed ${url}: ${err.message}`);
    return 0;
  }
}

/** Fail transcode if rewritten playlists or segments are not publicly readable (200). */
async function validateHlsOutput(bucket, processedBase, sharedToken) {
  const bucketName = bucket.name;
  const masterPath = `${processedBase}/master.m3u8`;
  const [masterExists] = await bucket.file(masterPath).exists();
  if (!masterExists) {
    throw new Error(`[HLS validate] missing master.m3u8 at ${processedBase}`);
  }
  console.log(`[PLAYLIST_FOUND] master.m3u8 ${processedBase}`);

  const masterUrl = storageDownloadUrl(bucketName, masterPath, sharedToken);
  console.log(`[HLS validate] master playlist ${masterUrl}`);

  const failures = [];

  const [masterBuf] = await bucket.file(masterPath).download();
  for (const line of masterBuf.toString().split('\n')) {
    const trimmed = line.trim();
    if (!isHlsPlaylistRef(trimmed)) {
      continue;
    }
    if (!trimmed.startsWith('http')) {
      failures.push({ playlist: masterPath, line: trimmed, error: 'missing_token' });
      continue;
    }
    const status = await httpStatusForUrl(trimmed);
    console.log(`[HLS validate] master variant status=${status} url=${trimmed}`);
    if (status !== 200 && status !== 206) {
      failures.push({ url: trimmed, status, playlist: masterPath });
    }
  }

  for (const tierKey of TIER_KEYS) {
    const variantPath = `${processedBase}/${tierKey}p.m3u8`;
    const file = bucket.file(variantPath);
    const [exists] = await file.exists();
    if (!exists) continue;

    const playlistUrl = storageDownloadUrl(bucketName, variantPath, sharedToken);
    console.log(`[PLAYLIST_FOUND] ${tierKey}p.m3u8 ${playlistUrl}`);

    const [buf] = await file.download();
    let segmentCount = 0;
    for (const line of buf.toString().split('\n')) {
      const trimmed = line.trim();
      if (!isHlsSegmentRef(trimmed)) continue;
      segmentCount++;
      if (!trimmed.startsWith('http')) {
        failures.push({
          playlist: variantPath,
          line: trimmed,
          error: 'segment_not_absolute',
        });
        console.error(
          `[HLS validate] segment missing token in ${variantPath}: ${trimmed}`,
        );
        continue;
      }
      const status = await httpStatusForUrl(trimmed);
      if (status !== 200 && status !== 206) {
        failures.push({ url: trimmed, status, playlist: variantPath });
      }
    }
    console.log(`[SEGMENT_COUNT] ${tierKey}p segments=${segmentCount}`);
    if (segmentCount === 0) {
      failures.push({
        playlist: variantPath,
        error: 'zero_segments',
      });
    }

    // Confirm every advertised segment file actually exists in Storage.
    const [segFiles] = await bucket.getFiles({
      prefix: `${processedBase}/segments/${tierKey}/`,
    });
    const tsFiles = segFiles.filter((f) => f.name.endsWith('.ts'));
    console.log(
      `[SEGMENT_COUNT] storage ${tierKey}p tsFiles=${tsFiles.length}`,
    );
    if (tsFiles.length === 0) {
      failures.push({
        playlist: variantPath,
        error: 'no_ts_files_in_storage',
      });
    }
  }

  if (failures.length > 0) {
    console.error('[HLS validate] failures', JSON.stringify(failures, null, 2));
    throw new Error(
      `HLS validation failed (${failures.length} bad URLs). First: ${failures[0].url || failures[0].line} status=${failures[0].status || failures[0].error}`,
    );
  }

  console.log(`[HLS validate] OK ${processedBase}`);
}

function runFfmpeg(inputPath, outputPath, outputOptions, inputOptions = []) {
  return new Promise((resolve, reject) => {
    const cmd = ffmpeg(inputPath);
    if (inputOptions && inputOptions.length > 0) {
      cmd.inputOptions(inputOptions);
    }
    cmd
      .outputOptions(outputOptions)
      .output(outputPath)
      .on('end', resolve)
      .on('error', reject)
      .run();
  });
}

function parseRotationDegrees(video) {
  if (!video) return 0;
  for (const side of video.side_data_list || []) {
    if (side.rotation != null) return Number(side.rotation);
    if (side.side_data_type === 'Display Matrix' && side.rotation != null) {
      return Number(side.rotation);
    }
  }
  const tag = video.tags?.rotate ?? video.tags?.ROTATE;
  if (tag != null) {
    const n = Number(tag);
    if (!Number.isNaN(n)) return n;
  }
  return 0;
}

/** Display size after rotation (portrait reels often store 1920×1080 + rotate 90). */
function displayDimensions(codedW, codedH, rotationDeg) {
  const rot = ((Math.round(rotationDeg) % 360) + 360) % 360;
  if (rot === 90 || rot === 270) {
    return { width: codedH, height: codedW, rotation: rot };
  }
  return { width: codedW, height: codedH, rotation: rot };
}

function parseVideoFps(video) {
  if (!video) return 0;
  const rate = video.avg_frame_rate || video.r_frame_rate || '0/0';
  const parts = String(rate).split('/');
  if (parts.length === 2) {
    const num = parseFloat(parts[0]);
    const den = parseFloat(parts[1]) || 1;
    if (!Number.isNaN(num) && den > 0) return num / den;
  }
  const single = parseFloat(rate);
  return Number.isNaN(single) ? 0 : single;
}

/**
 * "1080p" = 1080 lines of *vertical* resolution.
 * For portrait clips (1080×1920) that is the **short edge**, not the long edge.
 * Validating the long edge would reject every portrait video and stall the pipeline.
 */
const MAX_OUTPUT_SHORT_EDGE = 1080;
const MAX_OUTPUT_LONG_EDGE = 1920;
const MAX_OUTPUT_FPS = 30;

async function validateTranscodeOutput(filePath, label) {
  const probe = await probeVideo(filePath);
  const shortEdge = Math.min(probe.width, probe.height);
  const longEdge = Math.max(probe.width, probe.height);
  console.log(
    `[transcode validate] ${label} ${probe.width}x${probe.height} @ ${probe.fps.toFixed(2)}fps short=${shortEdge} long=${longEdge}`,
  );
  if (shortEdge > MAX_OUTPUT_SHORT_EDGE) {
    throw new Error(
      `[transcode validate] ${label} short edge ${shortEdge} exceeds ${MAX_OUTPUT_SHORT_EDGE}`,
    );
  }
  if (longEdge > MAX_OUTPUT_LONG_EDGE) {
    throw new Error(
      `[transcode validate] ${label} long edge ${longEdge} exceeds ${MAX_OUTPUT_LONG_EDGE}`,
    );
  }
  if (probe.fps > MAX_OUTPUT_FPS + 0.5) {
    throw new Error(
      `[transcode validate] ${label} fps ${probe.fps.toFixed(2)} exceeds ${MAX_OUTPUT_FPS}`,
    );
  }
}

function probeVideo(localInput) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(localInput, (err, meta) => {
      if (err) return reject(err);
      const video = (meta.streams || []).find((s) => s.codec_type === 'video');
      const audio = (meta.streams || []).find((s) => s.codec_type === 'audio');
      const codedW = video?.width || 0;
      const codedH = video?.height || 0;
      const rotation = parseRotationDegrees(video);
      const display = displayDimensions(codedW, codedH, rotation);
      const fps = parseVideoFps(video);
      const orientation =
        display.height > display.width ? 'portrait' : 'landscape';

      const codec = (video?.codec_name || '').toLowerCase();
      const transfer = (video?.color_transfer || '').toLowerCase();
      const primaries = (video?.color_primaries || '').toLowerCase();
      const sideTypes = (video?.side_data_list || [])
        .map((s) => (s.side_data_type || '').toLowerCase());
      const hasDoviSideData = sideTypes.some((t) => t.includes('dolby'));
      const isHevc = codec === 'hevc' || codec === 'h265';
      const isHdr =
        transfer.includes('smpte2084') ||
        transfer.includes('arib-std-b67') ||
        primaries.includes('bt2020');
      const isDolbyVision = hasDoviSideData || codec === 'dolbyvision';

      resolve({
        codedWidth: codedW,
        codedHeight: codedH,
        width: display.width,
        height: display.height,
        rotation: display.rotation,
        orientation,
        fps,
        durationSec: Number(meta.format?.duration || video?.duration || 0),
        codec,
        audioCodec: (audio?.codec_name || '').toLowerCase(),
        bitrate: Number(meta.format?.bit_rate || 0),
        isHevc,
        isHdr,
        isDolbyVision,
      });
    });
  });
}

/** Skip renditions larger than source long edge (always keep 360p). */
function selectRenditions(sourceW, sourceH, ladder) {
  const longEdge = Math.max(sourceW, sourceH);
  let selected = ladder.filter((r) => longEdge >= tierLongEdge(r) * 0.75);
  if (selected.length === 0) {
    selected = [ladder[ladder.length - 1]];
  }
  const keys = new Set(selected.map((r) => r.key));
  if (!keys.has('360')) {
    keys.add('360');
  }
  return ladder.filter((r) => keys.has(r.key));
}

/** Rotation filters applied before scale (paired with -noautorotate on input). */
function rotationFilters(rotationDeg) {
  const rot = ((Math.round(rotationDeg) % 360) + 360) % 360;
  if (rot === 90) return ['transpose=1'];
  if (rot === 270) return ['transpose=2'];
  if (rot === 180) return ['hflip', 'vflip'];
  return [];
}

/**
 * Fit inside tier box; letterbox pad — no stretch.
 * Each filter is a separate array entry so join(',') never produces empty
 * filter names (leading/trailing/double commas → "Filter not found").
 */
function scalePadFilter(tier, rotationDeg = 0) {
  return [
    ...rotationFilters(rotationDeg),
    `scale=${tier.width}:${tier.height}:force_original_aspect_ratio=decrease`,
    `pad=${tier.width}:${tier.height}:(ow-iw)/2:(oh-ih)/2:color=black`,
    'fps=30',
    'format=yuv420p',
  ].join(',');
}

/** Pixels are display-oriented; clear stale rotate tags on output. */
const ORIENTATION_OUTPUT_OPTS = [
  '-metadata:s:v:0',
  'rotate=0',
];

/**
 * H.264 high profile @ level 4.1, 2-sec GOP (matches hls_time), iOS-friendly.
 * Strip HDR / DV / HEVC sidedata before encode so output is universally playable.
 */
/** Must be applied as INPUT options (before -i). */
const ORIENTATION_INPUT_OPTS = ['-noautorotate'];

function baseVideoOptions(tier, rotationDeg = 0) {
  return [
    '-vf',
    scalePadFilter(tier, rotationDeg),
    '-c:v',
    'libx264',
    '-profile:v',
    'high',
    '-level',
    '4.1',
    '-preset',
    'veryfast',
    '-pix_fmt',
    'yuv420p',
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    '-b:v',
    tier.videoBitrate,
    '-maxrate',
    tier.maxrate,
    '-bufsize',
    tier.bufsize,
    '-colorspace',
    'bt709',
    '-color_primaries',
    'bt709',
    '-color_trc',
    'bt709',
    '-avoid_negative_ts',
    'make_zero',
    '-fflags',
    '+genpts',
    ...ORIENTATION_OUTPUT_OPTS,
  ];
}

const AUDIO_OPTIONS = ['-c:a', 'aac', '-b:a', '128k', '-ar', '44100', '-ac', '2'];

/**
 * Single normalize pass — accepts ANY input (HEVC / H.264 / HDR10 / Dolby Vision /
 * ProRes / AV1 / iPhone cinematic / 4K60 / portrait) and emits an SDR H.264 MP4
 * clamped to short edge ≤ 1080 + long edge ≤ 1920 @ 30 fps.
 */
async function normalizeSource(localInput, tempDir, topTier, rotationDeg) {
  const out = path.join(tempDir, '_normalized.mp4');
  const vf = scalePadFilter(topTier, rotationDeg);
  console.log(`[FFMPEG_START] normalize tier=${topTier.key} (${topTier.width}x${topTier.height})`);
  await runFfmpeg(
    localInput,
    out,
    [
    '-vf',
    vf,
    '-c:v',
    'libx264',
    '-profile:v',
    'high',
    '-level',
    '4.1',
    '-preset',
    'veryfast',
    '-pix_fmt',
    'yuv420p',
    '-g',
    '60',
    '-keyint_min',
    '60',
    '-sc_threshold',
    '0',
    '-b:v',
    '4500k',
    '-maxrate',
    '5000k',
    '-bufsize',
    '9000k',
    '-colorspace',
    'bt709',
    '-color_primaries',
    'bt709',
    '-color_trc',
    'bt709',
    '-map_metadata',
    '-1',
    '-map_chapters',
    '-1',
    '-avoid_negative_ts',
    'make_zero',
    '-fflags',
    '+genpts',
    ...AUDIO_OPTIONS,
    ...ORIENTATION_OUTPUT_OPTS,
    '-movflags',
    '+faststart',
    ],
    ORIENTATION_INPUT_OPTS,
  );
  console.log('[FFMPEG_END] normalize ok');
  return out;
}

async function encodeRendition(inputPath, workDir, tier, rotationDeg = 0) {
  const segDir = path.join(workDir, 'segments', tier.key);
  fs.mkdirSync(segDir, { recursive: true });

  const mp4Out = path.join(workDir, `optimized_${tier.key}.mp4`);
  const playlistPath = path.join(workDir, `${tier.key}p.m3u8`);
  const segmentPattern = path.join(segDir, 'seg_%03d.ts');

  const videoOpts = baseVideoOptions(tier, rotationDeg);

  console.log(`[FFMPEG_START] tier=${tier.key} ${tier.width}x${tier.height}`);
  await runFfmpeg(
    inputPath,
    mp4Out,
    [
      ...videoOpts,
      ...AUDIO_OPTIONS,
      ...ORIENTATION_OUTPUT_OPTS,
      '-movflags',
      '+faststart',
    ],
    ORIENTATION_INPUT_OPTS,
  );

  await runFfmpeg(
    inputPath,
    playlistPath,
    [
      ...videoOpts,
      ...AUDIO_OPTIONS,
      ...ORIENTATION_OUTPUT_OPTS,
      '-hls_time',
      '1',
      '-hls_playlist_type',
      'vod',
      '-hls_list_size',
      '0',
      '-hls_flags',
      'independent_segments+temp_file',
      '-hls_segment_type',
      'mpegts',
      '-hls_segment_filename',
      segmentPattern,
      '-f',
      'hls',
    ],
    ORIENTATION_INPUT_OPTS,
  );

  const localSegments = fs.existsSync(segDir)
    ? fs.readdirSync(segDir).filter((f) => f.endsWith('.ts'))
    : [];
  console.log(
    `[FFMPEG_END] tier=${tier.key} segments=${localSegments.length}`,
  );
  if (localSegments.length === 0) {
    throw new Error(
      `[FFMPEG_END] tier=${tier.key} produced zero .ts segments`,
    );
  }

  return { tier, mp4Out, playlistPath, segmentCount: localSegments.length };
}

function writeMasterPlaylist(workDir, variants) {
  const lines = ['#EXTM3U', '#EXT-X-VERSION:3'];
  const sorted = [...variants].sort(
    (a, b) => tierLongEdge(b.tier) - tierLongEdge(a.tier),
  );
  for (const v of sorted) {
    lines.push(
      `#EXT-X-STREAM-INF:BANDWIDTH=${v.tier.bandwidth},RESOLUTION=${v.tier.width}x${v.tier.height},CODECS="avc1.4d401f,mp4a.40.2"`,
    );
    lines.push(`${v.tier.key}p.m3u8`);
  }
  const masterPath = path.join(workDir, 'master.m3u8');
  fs.writeFileSync(masterPath, `${lines.join('\n')}\n`);
  return masterPath;
}

async function generateThumbnail(localInput, workDir, isPortrait) {
  const thumbnailPath = path.join(workDir, 'thumb.jpg');
  const size = isPortrait ? '?x1280' : '1280x?';
  await new Promise((resolve, reject) => {
    ffmpeg(localInput)
      .screenshots({
        timestamps: ['1'],
        filename: 'thumb.jpg',
        folder: workDir,
        size,
      })
      .on('end', resolve)
      .on('error', reject);
  });
  return thumbnailPath;
}

/**
 * 1-second silent preview MP4 used as the feed poster while the master.m3u8
 * is still buffering — gives Instagram-style "instant first frame" feel.
 */
async function generatePreviewClip(localInput, workDir, isPortrait) {
  const previewPath = path.join(workDir, 'preview.mp4');
  const size = isPortrait ? '480:854' : '854:480';
  await runFfmpeg(localInput, previewPath, [
    '-ss',
    '0',
    '-t',
    '1',
    '-an',
    '-vf',
    `scale=${size}:force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2:(ow-iw)/2:(oh-ih)/2:color=black,format=yuv420p`,
    '-c:v',
    'libx264',
    '-profile:v',
    'baseline',
    '-level',
    '3.1',
    '-preset',
    'veryfast',
    '-pix_fmt',
    'yuv420p',
    '-b:v',
    '350k',
    '-maxrate',
    '400k',
    '-bufsize',
    '700k',
    '-movflags',
    '+faststart',
  ]);
  return previewPath;
}

/**
 * Adaptive HLS ladder + per-tier MP4 (replaces single 720p transcode).
 * Output layout under workDir:
 *   master.m3u8, {1080,720,480,360}p.m3u8, segments/{tier}/, optimized_{tier}.mp4, thumb.jpg
 */
async function transcodeToAdaptiveHls(localInput, tempDir) {
  const workDir = path.join(tempDir, 'out');
  fs.mkdirSync(workDir, { recursive: true });

  const probe = await probeVideo(localInput);
  const ladder = ladderForOrientation(probe.orientation);
  const tiers = selectRenditions(probe.width, probe.height, ladder);
  console.log(
    `[probe] codec=${probe.codec} ${probe.width}x${probe.height} fps=${probe.fps.toFixed(2)} ` +
      `hdr=${probe.isHdr} hevc=${probe.isHevc} dv=${probe.isDolbyVision} ` +
      `orientation=${probe.orientation} duration=${probe.durationSec.toFixed(2)}s`,
  );
  console.log(
    `[ladder] ${tiers.map((t) => `${t.key}p→${t.width}x${t.height}@${t.videoBitrate}`).join(', ')}`,
  );

  const topTier = ladder[0];
  const normalized = await normalizeSource(
    localInput,
    tempDir,
    topTier,
    probe.rotation,
  );
  await validateTranscodeOutput(normalized, 'normalized');

  const encoded = [];
  for (const tier of tiers) {
    const result = await encodeRendition(normalized, workDir, tier, 0);
    encoded.push(result);
  }

  writeMasterPlaylist(workDir, encoded);
  const masterFile = path.join(workDir, 'master.m3u8');
  if (!fs.existsSync(masterFile) || fs.statSync(masterFile).size < 20) {
    throw new Error('[FFMPEG_END] master.m3u8 missing or empty after write');
  }

  const thumbnailPath = await generateThumbnail(
    normalized,
    workDir,
    probe.orientation === 'portrait',
  );
  let previewPath = '';
  try {
    previewPath = await generatePreviewClip(
      normalized,
      workDir,
      probe.orientation === 'portrait',
    );
  } catch (e) {
    console.warn('[preview] generation failed (non-fatal):', e?.message || e);
  }

  return {
    workDir,
    tiers,
    encoded,
    thumbnailPath,
    previewPath,
    orientation: probe.orientation,
    sourceProbe: probe,
  };
}

async function walkFiles(dir, baseDir = dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walkFiles(full, baseDir)));
    } else {
      files.push({ localPath: full, relativePath: path.relative(baseDir, full) });
    }
  }
  return files;
}

async function uploadProcessedTree(bucket, processedBase, localWorkDir) {
  const sharedToken = randomUUID();
  const files = await walkFiles(localWorkDir);
  for (const { localPath, relativePath } of files) {
    const dest = `${processedBase}/${relativePath.replace(/\\/g, '/')}`;
    let contentType = 'application/octet-stream';
    if (relativePath.endsWith('.m3u8')) {
      contentType = 'application/vnd.apple.mpegurl';
    } else if (relativePath.endsWith('.ts')) {
      contentType = 'video/mp2t';
    } else if (relativePath.endsWith('.mp4')) {
      contentType = 'video/mp4';
    } else if (relativePath.endsWith('.jpg')) {
      contentType = 'image/jpeg';
    }
    await bucket.upload(localPath, {
      destination: dest,
      metadata: {
        contentType,
        metadata: { firebaseStorageDownloadTokens: sharedToken },
      },
    });
  }
  await rewriteM3u8Playlists(bucket, processedBase, sharedToken);
  await validateHlsOutput(bucket, processedBase, sharedToken);
  console.log(`[UPLOAD_HLS_SUCCESS] ${processedBase}`);
  return sharedToken;
}

async function buildPublicUrls(bucket, processedBase, tiers, sharedToken) {
  const masterUrl = await setDownloadUrl(
    bucket,
    `${processedBase}/master.m3u8`,
    'application/vnd.apple.mpegurl',
    sharedToken,
  );
  const thumbUrl = await setDownloadUrl(
    bucket,
    `${processedBase}/thumb.jpg`,
    'image/jpeg',
    sharedToken,
  );

  const qualities = {};
  for (const tier of tiers) {
    qualities[tier.key] = await setDownloadUrl(
      bucket,
      `${processedBase}/optimized_${tier.key}.mp4`,
      'video/mp4',
      sharedToken,
    );
  }

  let previewUrl = '';
  const previewFile = bucket.file(`${processedBase}/preview.mp4`);
  const [previewExists] = await previewFile.exists();
  if (previewExists) {
    previewUrl = await setDownloadUrl(
      bucket,
      `${processedBase}/preview.mp4`,
      'video/mp4',
      sharedToken,
    );
  }

  const mp4720 =
    qualities['720'] ||
    qualities['1080'] ||
    qualities['480'] ||
    '';

  return {
    mp4: mp4720,
    hls: masterUrl,
    thumb: thumbUrl,
    preview: previewUrl,
    qualities,
  };
}

async function isAlreadyProcessed(bucket, processedBase) {
  const [masterExists] = await bucket
    .file(`${processedBase}/master.m3u8`)
    .exists();
  return masterExists;
}

function buildSourceMetadataPatch(probe) {
  if (!probe) return {};
  return {
    sourceCodec: probe.codec || '',
    sourceWidth: probe.width || 0,
    sourceHeight: probe.height || 0,
    sourceFps: Math.round(probe.fps || 0),
    sourceDurationSec: Math.round(probe.durationSec || 0),
    sourceIsHdr: !!probe.isHdr,
    sourceIsHevc: !!probe.isHevc,
    sourceIsDolbyVision: !!probe.isDolbyVision,
    sourceOrientation: probe.orientation || '',
  };
}

async function updateReelDoc(videoId, urls, probe) {
  const ref = admin.firestore().collection('reels').doc(videoId);
  const snap = await ref.get();
  if (!snap.exists) {
    console.warn(`Reel doc missing: ${videoId}`);
    return;
  }

  // Phase 6 denormalization: fetch the author once at transcode-finish time
  // and stamp username / profilePic onto the reel doc, so the client never
  // has to issue per-reel users/{uid}.get() requests. Best-effort: if the
  // user lookup fails we still finalize the transcode.
  const reelData = snap.data() || {};
  const authorPatch = await buildAuthorPatch(reelData);

  await ref.update({
    processed: true,
    processing: false,
    transcodeError: admin.firestore.FieldValue.delete(),
    transcodeErrorAt: admin.firestore.FieldValue.delete(),
    transcodeErrorCategory: admin.firestore.FieldValue.delete(),
    legacyRawFallback: admin.firestore.FieldValue.delete(),
    videoUrl: urls.mp4,
    hlsUrl: urls.hls,
    thumbnailUrl: urls.thumb,
    previewUrl: urls.preview || '',
    qualities: urls.qualities || {},
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...buildSourceMetadataPatch(probe),
    ...authorPatch,
  });
  console.log(`[process finish] processed=true reelId=${videoId}`);
}

/**
 * Returns a patch object with `username` / `displayName` / `profilePic` that
 * should be merged into a reel doc. Skips fields that already exist on the
 * reel (so a user renaming themselves doesn't retroactively rewrite old
 * reels) and silently returns {} on any error.
 */
async function buildAuthorPatch(reelData) {
  try {
    const uid = (reelData.userId || reelData.uid || '').toString();
    if (!uid) return {};

    const userSnap = await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .get();
    if (!userSnap.exists) return {};

    const u = userSnap.data() || {};
    const username = (
      u.username || u.userName || u.handle || ''
    ).toString();
    const displayName = (
      u.displayName || u.name || u.full_name || u.fullName || ''
    ).toString();
    const profilePic = (
      u.profilePhoto || u.photoUrl || u.photoURL || u.profilePic || u.avatar || ''
    ).toString();

    const patch = {};
    if (username && !reelData.username) patch.username = username;
    if (displayName && !reelData.displayName) patch.displayName = displayName;
    if (profilePic && !reelData.profilePic) patch.profilePic = profilePic;
    return patch;
  } catch (e) {
    console.warn('buildAuthorPatch failed:', e.message);
    return {};
  }
}

/** Firestore rejects FieldValue.delete() inside array elements — omit keys instead. */
function omitTranscodeErrorFields(item) {
  if (!item || typeof item !== 'object') return item;
  const {
    transcodeError: _te,
    transcodeErrorAt: _tea,
    transcodeErrorCategory: _tec,
    ...rest
  } = item;
  return rest;
}

async function updatePostDoc(postId, videoKey, urls, rawStoragePath, probe) {
  const ref = admin.firestore().collection('posts').doc(postId);
  const videoIndex = parseVideoIndexFromKey(videoKey);

  for (let attempt = 0; attempt < 24; attempt++) {
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`Post ${postId} not found yet, retry ${attempt + 1}/24`);
      await sleep(5000);
      continue;
    }

    const data = snap.data();
    const media = Array.isArray(data.media)
      ? data.media.map((m) => ({ ...m }))
      : [];

    let targetIdx = -1;
    let videoOrdinal = 0;
    for (let i = 0; i < media.length; i++) {
      const m = media[i];
      if ((m.type || '').toString() === 'video') {
        if (videoOrdinal === videoIndex) {
          targetIdx = i;
          break;
        }
        videoOrdinal++;
      }
    }

    if (targetIdx < 0) {
      for (let i = 0; i < media.length; i++) {
        const m = media[i];
        if ((m.type || '').toString() !== 'video') continue;
        const u = (m.videoUrl || m.url || '').toString();
        if (u.includes(rawStoragePath) || m.processing === true) {
          targetIdx = i;
          break;
        }
      }
    }

    if (targetIdx < 0) {
      console.warn(`No media slot for post ${postId} videoKey ${videoKey}`);
      return;
    }

    const prev = media[targetIdx];

    // Clear videoUrl while we are about to overwrite with processed URLs.
    // Without this there is a small race where an old client reads the raw
    // URL between our two Firestore writes and tries to decode it.
    const exoticFlags = prev.isDolbyVision || prev.isHevc || prev.isHdr;
    const oversized =
      (prev.sourceWidth && prev.sourceWidth > 1920) ||
      (prev.sourceHeight && prev.sourceHeight > 1920);
    if ((exoticFlags || oversized) && prev.processing === true) {
      try {
        const clearMedia = data.media.map((m, i) => {
          if (i !== targetIdx) return m;
          return { ...m, videoUrl: '', url: '' };
        });
        await ref.update({ media: clearMedia });
      } catch (_) {
        // Best-effort; the full update below will overwrite either way.
      }
    }

    const rawUrl = (prev.rawVideoUrl || prev.videoUrl || prev.url || '').toString();

    media[targetIdx] = {
      ...omitTranscodeErrorFields(prev),
      type: 'video',
      videoUrl: urls.mp4,
      url: urls.mp4,
      hlsUrl: urls.hls,
      previewUrl: urls.preview || '',
      qualities: urls.qualities || {},
      rawVideoUrl: rawUrl || prev.videoUrl || prev.url,
      thumbnail: urls.thumb || prev.thumbnail || prev.thumbnailUrl || '',
      thumbnailUrl: urls.thumb || prev.thumbnailUrl || prev.thumbnail || '',
      processed: true,
      processing: false,
      ...buildSourceMetadataPatch(probe),
    };

    const videoItems = media.filter((m) => (m.type || '').toString() === 'video');
    const allProcessed =
      videoItems.length > 0 && videoItems.every((m) => m.processed === true);
    const anyProcessing = videoItems.some((m) => m.processing === true);

    const firstVideo = videoItems[0];
    const update = {
      media,
      processing: anyProcessing,
      processed: allProcessed,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      legacyRawFallback: admin.firestore.FieldValue.delete(),
      transcodeError: admin.firestore.FieldValue.delete(),
      transcodeErrorAt: admin.firestore.FieldValue.delete(),
      transcodeErrorCategory: admin.firestore.FieldValue.delete(),
      ...buildSourceMetadataPatch(probe),
    };

    if (firstVideo) {
      update.videoUrl = firstVideo.videoUrl || firstVideo.url || '';
      update.hlsUrl = firstVideo.hlsUrl || '';
      update.previewUrl = firstVideo.previewUrl || urls.preview || '';
      update.qualities = firstVideo.qualities || urls.qualities || {};
      const thumb =
        firstVideo.thumbnail ||
        firstVideo.thumbnailUrl ||
        urls.thumb ||
        '';
      if (thumb) update.thumbnailUrl = thumb;
    }

    await ref.update(update);
    console.log(
      `[process finish] processed=true postId=${postId} videoIndex=${videoKey}`,
    );
    return;
  }

  console.error(`Timed out waiting for post doc ${postId}`);
}

/** Must match Flutter [storageBucket] (halo-fb212.firebasestorage.app). */
function getStorageBucket() {
  try {
    const cfg = process.env.FIREBASE_CONFIG
      ? JSON.parse(process.env.FIREBASE_CONFIG)
      : {};
    if (cfg.storageBucket) return cfg.storageBucket;
  } catch (_) {
    /* fall through */
  }
  return 'halo-fb212.firebasestorage.app';
}

const MAX_TRANSCODE_ATTEMPTS = 3;
const TRANSCODE_RETRY_DELAYS_MS = [0, 8000, 20000];
/** Max Firestore-triggered requeue cycles per doc (distinct from in-pipeline retries). */
const MAX_REQUEUE_ATTEMPTS = 12;
/** Ignore duplicate requeue triggers while a transcode is in flight (CF timeout is 540s). */
const TRANSCODE_IN_FLIGHT_MS = 11 * 60 * 1000;
/** Docs stuck in processing longer than this can be re-queued via migrateLegacyVideos. */
const STUCK_PROCESSING_MS = 2 * 60 * 60 * 1000;

function getProcessedBase(ctx) {
  return ctx.kind === 'post'
    ? `videos/processed/posts/${ctx.postId}/${ctx.videoKey}`
    : `videos/processed/${ctx.jobId}`;
}

function ladderTiersFromKeys() {
  return TIER_KEYS.map((k) => {
    return (
      LADDER_PORTRAIT.find((t) => t.key === k) ||
      LADDER_LANDSCAPE.find((t) => t.key === k)
    );
  }).filter(Boolean);
}

function isTransientTranscodeError(err) {
  const msg = (err && err.message ? err.message : String(err)).toLowerCase();
  if (msg.includes('no space') || msg.includes('enospc')) return false;
  if (msg.includes('invalid data') || msg.includes('codec not found')) {
    return false;
  }
  if (msg.includes('filter not found') || msg.includes('error opening output')) {
    return false;
  }
  return (
    msg.includes('econnreset') ||
    msg.includes('etimedout') ||
    msg.includes('socket hang up') ||
    msg.includes('503') ||
    msg.includes('429') ||
    msg.includes('unavailable') ||
    msg.includes('deadline exceeded') ||
    msg.includes('temporarily unavailable') ||
    msg.includes('connection reset') ||
    msg.includes('network')
  );
}

/**
 * If Storage already has master.m3u8, patch Firestore without re-encoding.
 * @returns {Promise<boolean>} true when rehydration succeeded
 */
async function rehydrateFirestoreFromStorage(ctx, bucket, processedBase, storagePath) {
  try {
    const ref = ctx.kind === 'post'
      ? admin.firestore().collection('posts').doc(ctx.postId)
      : admin.firestore().collection('reels').doc(ctx.jobId);
    const snap = await ref.get();
    if (!snap.exists) return false;

    const d = snap.data() || {};
    const needsRehydration = ctx.kind === 'post'
      ? (Array.isArray(d.media) &&
          d.media.some((m) => m && (m.processing === true || !m.processed)))
      : (d.processing === true || !d.processed);

    if (!needsRehydration) return true;

    const [masterMeta] = await bucket
      .file(`${processedBase}/master.m3u8`)
      .getMetadata();
    const sharedToken =
      masterMeta &&
      masterMeta.metadata &&
      masterMeta.metadata.firebaseStorageDownloadTokens;
    if (!sharedToken) {
      console.warn(
        `[rehydrate] missing download token on ${processedBase}/master.m3u8`,
      );
      return false;
    }

    const tiers = ladderTiersFromKeys();
    const urls = await buildPublicUrls(
      bucket, processedBase, tiers, sharedToken,
    );
    if (ctx.kind === 'reel') {
      await updateReelDoc(ctx.jobId, urls, null);
    } else {
      await updatePostDoc(
        ctx.postId, ctx.videoKey, urls, storagePath, null,
      );
    }
    console.log(`[rehydrate] Firestore updated from ${processedBase}`);
    return true;
  } catch (rehydrateErr) {
    console.warn(
      '[rehydrate] failed:',
      rehydrateErr && rehydrateErr.message,
    );
    return false;
  }
}

async function markTranscodeStarted(ctx) {
  const patch = {
    processing: true,
    transcodeStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    transcodeError: admin.firestore.FieldValue.delete(),
    transcodeErrorAt: admin.firestore.FieldValue.delete(),
    transcodeErrorCategory: admin.firestore.FieldValue.delete(),
  };
  if (ctx.kind === 'post') {
    await admin.firestore().collection('posts').doc(ctx.postId).set(
      patch,
      { merge: true },
    );
  } else {
    await admin.firestore().collection('reels').doc(ctx.jobId).set(
      patch,
      { merge: true },
    );
  }
}

async function readTranscodeStartedMs(ctx) {
  const ref = ctx.kind === 'post'
    ? admin.firestore().collection('posts').doc(ctx.postId)
    : admin.firestore().collection('reels').doc(ctx.jobId);
  const snap = await ref.get();
  if (!snap.exists) return null;
  const ts = snap.data() && snap.data().transcodeStartedAt;
  if (ts && typeof ts.toMillis === 'function') return ts.toMillis();
  return null;
}

async function recordTranscodeFailure(ctx, errMessage, { transient }) {
  const docRef = ctx.kind === 'post'
    ? admin.firestore().collection('posts').doc(ctx.postId)
    : admin.firestore().collection('reels').doc(ctx.jobId);
  const priorSnap = await docRef.get();
  const priorData = priorSnap.exists ? (priorSnap.data() || {}) : {};
  const nextAttempts = Number(priorData.transcodeAttemptCount || 0) + 1;
  const exhausted = nextAttempts >= MAX_REQUEUE_ATTEMPTS;

  const failurePatch = {
    processing: false,
    processed: false,
    transcodeError: errMessage,
    transcodeErrorAt: admin.firestore.FieldValue.serverTimestamp(),
    transcodeErrorCategory: transient ? 'transient' : 'permanent',
    transcodeAttemptCount: admin.firestore.FieldValue.increment(1),
  };
  // Stop the Firestore re-queue loop on permanent failures — user must re-run
  // migration (writes a fresh requestedTranscodeAt) to retry.
  if (!transient) {
    failurePatch.requestedTranscodeAt = admin.firestore.FieldValue.delete();
    failurePatch.legacyRawFallback = admin.firestore.FieldValue.delete();
  }
  if (exhausted) {
    failurePatch.transcodeRequeueExhausted = true;
    failurePatch.requestedTranscodeAt = admin.firestore.FieldValue.delete();
    failurePatch.legacyRawFallback = admin.firestore.FieldValue.delete();
  }
  if (ctx.kind === 'post') {
    const ref = docRef;
    const snap = priorSnap;
    if (!snap.exists) return;
    const data = priorData;
    const media = Array.isArray(data.media)
      ? data.media.map((m) => ({ ...m }))
      : [];
    const videoIndex = parseVideoIndexFromKey(ctx.videoKey);
    let videoOrdinal = 0;
    for (let i = 0; i < media.length; i++) {
      if ((media[i].type || '').toString() !== 'video') continue;
      if (videoOrdinal === videoIndex) {
        media[i] = {
          ...media[i],
          processing: false,
          processed: false,
          transcodeError: errMessage,
        };
        break;
      }
      videoOrdinal++;
    }
    await ref.update({ ...failurePatch, media });
  } else {
    await admin
      .firestore()
      .collection('reels')
      .doc(ctx.jobId)
      .update(failurePatch);
  }
}

/**
 * Core transcode pipeline. Pulls a raw file from Storage, normalises +
 * adaptive-HLS-encodes it, uploads outputs, and updates Firestore.
 *
 * Used by both the Storage `onObjectFinalized` trigger and the Firestore
 * legacy-requeue trigger below.
 */
async function runTranscodePipeline({
  ctx,
  bucketName,
  storagePath,
  skipMarkStarted = false,
}) {
  const bucket = admin.storage().bucket(bucketName);
  const tempDir = path.join(os.tmpdir(), ctx.jobId);

  try {
    if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

    const processedBase = getProcessedBase(ctx);

    if (await isAlreadyProcessed(bucket, processedBase)) {
      console.log(`[skip] duplicate transcode: ${processedBase}`);
      await rehydrateFirestoreFromStorage(
        ctx, bucket, processedBase, storagePath,
      );
      return null;
    }

    if (ctx.kind === 'post') {
      console.log(
        `[process start] uid=${ctx.uid} postId=${ctx.postId} videoIndex=${ctx.videoKey} src=${storagePath}`,
      );
    } else {
      console.log(`[process start] reelId=${ctx.jobId} src=${storagePath}`);
    }

    if (!skipMarkStarted) {
      await markTranscodeStarted(ctx);
    }
    const pipelineStartedAt = Date.now();

    let lastErr = null;
    for (let attempt = 0; attempt < MAX_TRANSCODE_ATTEMPTS; attempt++) {
      if (attempt > 0) {
        const delay = TRANSCODE_RETRY_DELAYS_MS[attempt] || 15000;
        console.log(
          `[PROCESS_RETRY] jobId=${ctx.jobId} attempt=${attempt + 1}/` +
            `${MAX_TRANSCODE_ATTEMPTS} delayMs=${delay}`,
        );
        await sleep(delay);
      }

      try {
        const localInput = path.join(tempDir, ctx.fileName);
        await bucket.file(storagePath).download({ destination: localInput });
        console.log(`Downloaded ${storagePath} → ${processedBase}`);

        const { workDir, tiers, sourceProbe } = await transcodeToAdaptiveHls(
          localInput,
          tempDir,
        );

        const sharedToken = await uploadProcessedTree(
          bucket,
          processedBase,
          workDir,
        );
        const urls = await buildPublicUrls(
          bucket,
          processedBase,
          tiers,
          sharedToken,
        );
        urls.thumb = await setDownloadUrl(
          bucket,
          `${processedBase}/thumb.jpg`,
          'image/jpeg',
          sharedToken,
        );

        if (ctx.kind === 'reel') {
          await updateReelDoc(ctx.jobId, urls, sourceProbe);
        } else {
          await updatePostDoc(
            ctx.postId,
            ctx.videoKey,
            urls,
            storagePath,
            sourceProbe,
          );
        }

        const startedMs = await readTranscodeStartedMs(ctx);
        const durationMs = startedMs != null
          ? Date.now() - startedMs
          : Date.now() - pipelineStartedAt;
        console.log(
          `[PROCESS_COMPLETE] jobId=${ctx.jobId} processed=true ` +
            `processing=false transcode_duration_ms=${durationMs}`,
        );
        console.log(
          `[METRIC] transcode_duration_ms=${durationMs} kind=${ctx.kind} ` +
            `jobId=${ctx.jobId}`,
        );
        fs.rmSync(tempDir, { recursive: true, force: true });
        return null;
      } catch (err) {
        lastErr = err;
        const errMessage = err && err.message ? err.message : 'Transcode failed';
        const transient = isTransientTranscodeError(err);
        console.error(
          `[PROCESS_FAILED] jobId=${ctx.jobId} attempt=${attempt + 1} ` +
            `transient=${transient} error=${errMessage}`,
        );
        if (transient && attempt < MAX_TRANSCODE_ATTEMPTS - 1) {
          continue;
        }
        break;
      }
    }

    const errMessage =
      lastErr && lastErr.message ? lastErr.message : 'Transcode failed';
    const transient = isTransientTranscodeError(lastErr);
    console.error(
      `[PROCESS_FAILED_FINAL] jobId=${ctx.jobId} kind=${ctx.kind} ` +
        `category=${transient ? 'transient' : 'permanent'} error=${errMessage}`,
    );
    if (lastErr) console.error(lastErr);
    await recordTranscodeFailure(ctx, errMessage, { transient });
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
    return null;
  } catch (err) {
    const errMessage = err && err.message ? err.message : 'Transcode failed';
    console.error(
      `[PROCESS_FAILED] jobId=${ctx.jobId} kind=${ctx.kind} error=${errMessage}`,
    );
    console.error(err);
    await recordTranscodeFailure(ctx, errMessage, {
      transient: isTransientTranscodeError(err),
    });
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
    return null;
  }
}

exports.processVideo = onObjectFinalized(
  {
    memory: '2GiB',
    timeoutSeconds: 540,
    cpu: 2,
    bucket: getStorageBucket(),
  },
  async (event) => {
    const object = event.data;
    const rawPath = object.name || '';
    const filePath = normalizeStorageObjectPath(rawPath);

    console.log(
      `[UPLOAD_START] bucket=${object.bucket} raw=${rawPath} normalized=${filePath} size=${object.size}`,
    );

    const ctx = parseUploadContext(rawPath);
    if (!ctx) {
      console.log(`[skip] unsupported path: ${filePath || rawPath}`);
      return null;
    }

    console.log(
      `[TRIGGER_MATCH] kind=${ctx.kind}` +
        (ctx.kind === 'post'
          ? ` uid=${ctx.uid} postId=${ctx.postId} videoIndex=${ctx.videoKey}`
          : ` reelId=${ctx.jobId}`),
    );

    return runTranscodePipeline({
      ctx,
      bucketName: object.bucket,
      storagePath: ctx.storagePath,
    });
  },
);

// ---------------------------------------------------------------------------
// Legacy re-queue trigger.
//
// Old reels uploaded before the transcode pipeline existed (or whose Storage
// trigger silently failed) sit forever at `processed=false processing=false`.
// The client tags them with `requestedTranscodeAt = serverTimestamp` (and
// `legacyRawFallback=true`) the moment it sees a doc that needs help, or when
// ExoPlayer reports `NO_EXCEEDS_CAPABILITIES`. This trigger picks them up and
// pumps them through the normal pipeline.
//
// IMPORTANT design notes:
//  * We DO NOT gate on the rising edge of `legacyRawFallback` — old reels were
//    already flagged in previous sessions, so a rising-edge gate would never
//    fire for them again. Instead we dedup with `requeuedAt`.
//  * `extractStoragePathFromUrl` uses a greedy regex stopping at `?` (the
//    previous lazy regex `(.+?)(?:\/?|$)` matched only ONE character → all
//    re-queues silently no-op'd).
// ---------------------------------------------------------------------------

const LEGACY_REQUEUE_DEDUP_MS = 15 * 60 * 1000; // 15 minutes

function readTimestampMs(ts) {
  if (ts && typeof ts.toMillis === 'function') return ts.toMillis();
  return null;
}

function isPermanentTranscodeDoc(doc) {
  if (!doc || !doc.transcodeError) return false;
  if (doc.transcodeErrorCategory === 'permanent') return true;
  if (doc.transcodeErrorCategory === 'transient') return false;
  // Legacy docs may lack category — infer from the error text.
  return !isTransientTranscodeError({ message: String(doc.transcodeError) });
}

function hasFreshTranscodeRequest(doc) {
  if (!doc || !doc.requestedTranscodeAt) return false;
  const requestedMs = readTimestampMs(doc.requestedTranscodeAt);
  if (requestedMs == null) return true;
  const requeuedMs = readTimestampMs(doc.requeuedAt);
  const startedMs = readTimestampMs(doc.transcodeStartedAt);
  const baseline = Math.max(requeuedMs || 0, startedMs || 0);
  return requestedMs > baseline;
}

function isTranscodeInFlight(doc) {
  if (!doc || doc.processing !== true) return false;
  const startedMs = readTimestampMs(doc.transcodeStartedAt);
  if (startedMs == null) return true;
  return Date.now() - startedMs < TRANSCODE_IN_FLIGHT_MS;
}

function extractStoragePathFromUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return null;
  try {
    const url = new URL(rawUrl);
    // firebasestorage.googleapis.com /v0/b/<bucket>/o/<encoded-path>?alt=…
    // Greedy, but bounded by end of path (URL.pathname strips query string).
    const m = url.pathname.match(/\/o\/(.+)$/);
    if (!m || !m[1]) return null;
    return decodeURIComponent(m[1]);
  } catch (_) {
    return null;
  }
}

function buildCtxFromStoragePath(rawPath) {
  return parseUploadContext(rawPath);
}

function collectRawCandidates(collection, doc) {
  const candidates = [];
  if (!doc) return candidates;
  if (collection === 'reels') {
    candidates.push(doc.rawVideoUrl, doc.videoUrl);
  } else {
    const media = Array.isArray(doc.media) ? doc.media : [];
    for (const m of media) {
      if (!m || typeof m !== 'object') continue;
      candidates.push(m.rawVideoUrl, m.videoUrl, m.url);
    }
    candidates.push(doc.videoUrl, doc.rawVideoUrl);
  }
  return candidates.filter((u) => typeof u === 'string' && u.length > 0);
}

function hasAdaptiveProcessedHls(doc) {
  const isMaster = (u) =>
    typeof u === 'string' &&
    u.length > 0 &&
    u.toLowerCase().includes('master.m3u8');
  if (isMaster(doc.hlsUrl)) return true;
  const media = Array.isArray(doc.media) ? doc.media : [];
  for (const m of media) {
    if (m && isMaster(m.hlsUrl)) return true;
  }
  return false;
}

function isLegacyInvalidHlsUrl(url) {
  if (!url || typeof url !== 'string') return false;
  const lower = url.toLowerCase();
  if (lower.includes('index.m3u8')) return true;
  if (lower.includes('/hls/playlist.m3u8')) return true;
  if (lower.includes('playlist.m3u8') && !lower.includes('master.m3u8')) {
    return true;
  }
  return false;
}

function docHasVideoMedia(doc) {
  if (!Array.isArray(doc.media)) return false;
  return doc.media.some(
    (m) => m && (m.type || '').toString() === 'video',
  );
}

/** True when a Firebase Storage URL on the doc maps to a transcode trigger path. */
function hasTranscodableRawSource(doc, collection) {
  const candidates = collectRawCandidates(collection, doc);
  return candidates.some((u) => {
    const p = extractStoragePathFromUrl(u);
    if (!p || shouldSkipPath(p)) return false;
    return parseUploadContext(p) != null;
  });
}

function shouldRequeueNow(after, collection = 'posts') {
  if (!after) return false;

  if (after.processed === true) return false;
  if (after.transcodeRequeueExhausted === true) return false;

  const attempts = Number(after.transcodeAttemptCount || 0);
  if (attempts >= MAX_REQUEUE_ATTEMPTS) return false;

  if (isTranscodeInFlight(after)) return false;

  const freshRequest = hasFreshTranscodeRequest(after);
  if (isPermanentTranscodeDoc(after) && !freshRequest) return false;

  if (!hasTranscodableRawSource(after, collection)) return false;

  const explicitlyFlagged =
    after.legacyRawFallback === true ||
    after.transcodeError === 'exceeds_capabilities' ||
    !!after.requestedTranscodeAt;

  // Legacy posts often have media.videoUrl but no rawVideoUrl / processed flags.
  const isNewUpload =
    !after.processing &&
    after.processed !== true &&
    !hasAdaptiveProcessedHls(after) &&
    hasTranscodableRawSource(after, collection);

  if (!explicitlyFlagged && !isNewUpload) return false;

  if (after.processing === true && !freshRequest) return false;

  const requeuedMs = readTimestampMs(after.requeuedAt);
  if (requeuedMs != null && !freshRequest) {
    const ageMs = Date.now() - requeuedMs;
    if (ageMs >= 0 && ageMs < LEGACY_REQUEUE_DEDUP_MS) {
      const isTransientFailure = after.transcodeErrorCategory === 'transient';
      if (!after.transcodeError || !isTransientFailure) {
        return false;
      }
    }
  }

  return true;
}

/**
 * Atomically claim a legacy requeue job so concurrent onDocumentWritten
 * invocations cannot start parallel transcode pipelines on the same doc.
 */
async function claimLegacyTranscodeJob({ collection, docId }) {
  const ref = admin.firestore().collection(collection).doc(docId);
  try {
    return await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        return { claimed: false, reason: 'missing' };
      }
      const after = snap.data() || {};

      if (!shouldRequeueNow(after, collection)) {
        return { claimed: false, reason: 'should_not_requeue' };
      }

      const attempts = Number(after.transcodeAttemptCount || 0);
      if (attempts >= MAX_REQUEUE_ATTEMPTS) {
        tx.set(ref, { transcodeRequeueExhausted: true }, { merge: true });
        return { claimed: false, reason: 'max_attempts' };
      }

      tx.set(
        ref,
        {
          processing: true,
          transcodeStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          requeuedAt: admin.firestore.FieldValue.serverTimestamp(),
          transcodeError: admin.firestore.FieldValue.delete(),
          transcodeErrorAt: admin.firestore.FieldValue.delete(),
          transcodeErrorCategory: admin.firestore.FieldValue.delete(),
        },
        { merge: true },
      );

      return { claimed: true };
    });
  } catch (err) {
    console.warn(
      `[LEGACY_REQUEUE] claim failed ${collection}/${docId}:`,
      err && err.message ? err.message : err,
    );
    return { claimed: false, reason: 'transaction_failed' };
  }
}

async function handleLegacyRequeue({ collection, docId, after }) {
  if (!shouldRequeueNow(after, collection)) return;

  const candidates = collectRawCandidates(collection, after);
  let storagePath = null;
  let ctx = null;
  for (const url of candidates) {
    const p = extractStoragePathFromUrl(url);
    if (!p) continue;
    const c = buildCtxFromStoragePath(p);
    if (c) {
      storagePath = p;
      ctx = c;
      break;
    }
  }

  if (!ctx || !storagePath) {
    console.warn(
      `[LEGACY_REQUEUE] no usable raw path for ${collection}/${docId}; ` +
        `candidates=${candidates.length}`,
    );
    return;
  }

  console.log(
    `[LEGACY_REQUEUE] ${collection}/${docId} → kind=${ctx.kind} ` +
      `path=${storagePath}`,
  );

  // ── Storage-first check: if processed files already exist, skip the
  // pipeline and just rehydrate Firestore. This handles the case where
  // the CF ran successfully but the Firestore write failed (or where the
  // doc was wiped/re-flagged later). Avoids paying for a re-transcode and
  // gets the reel playable immediately.
  const bucket = admin.storage().bucket(getStorageBucket());
  const processedBase = getProcessedBase(ctx);

  const alreadyInStorage = await isAlreadyProcessed(bucket, processedBase);
  if (alreadyInStorage) {
    console.log(
      `[LEGACY_REQUEUE] ${docId} already processed in Storage — ` +
        `rehydrating Firestore without re-transcoding`,
    );
    const ok = await rehydrateFirestoreFromStorage(
      ctx, bucket, processedBase, storagePath,
    );
    if (ok) {
      console.log(`[LEGACY_REQUEUE] rehydrated ${docId} successfully`);
    }
    return;
  }
  // ── end Storage-first check ──

  const claim = await claimLegacyTranscodeJob({ collection, docId });
  if (!claim.claimed) {
    if (claim.reason !== 'should_not_requeue') {
      console.log(
        `[LEGACY_REQUEUE] skip ${collection}/${docId} reason=${claim.reason}`,
      );
    }
    return;
  }

  await runTranscodePipeline({
    ctx,
    bucketName: getStorageBucket(),
    storagePath,
    skipMarkStarted: true,
  });
}

exports.requeueLegacyReel = onDocumentWritten(
  {
    document: 'reels/{reelId}',
    memory: '2GiB',
    timeoutSeconds: 540,
    cpu: 2,
  },
  async (event) => {
    const after = event.data && event.data.after ? event.data.after.data() : null;
    await handleLegacyRequeue({
      collection: 'reels',
      docId: event.params.reelId,
      after,
    });
  },
);

exports.requeueLegacyPost = onDocumentWritten(
  {
    document: 'posts/{postId}',
    memory: '2GiB',
    timeoutSeconds: 540,
    cpu: 2,
  },
  async (event) => {
    const after = event.data && event.data.after ? event.data.after.data() : null;
    await handleLegacyRequeue({
      collection: 'posts',
      docId: event.params.postId,
      after,
    });
  },
);

// ---------------------------------------------------------------------------
// One-shot admin migration callable.
//
// Walks `posts` (and optionally `reels`) where `processed=false` and either
// no transcode has been requested yet OR the last requeue was a long time
// ago, and writes `requestedTranscodeAt = serverTimestamp` on each doc. The
// triggers above then pick them up and run the pipeline.
//
// Invoke from the client (admin only):
//   await FirebaseFunctions.instance.httpsCallable('migrateLegacyVideos').call({
//     'maxDocs': 200,
//     'collection': 'posts',          // or 'reels' or 'both'
//   });
//
// Returns `{ scanned, queued, skipped }`.
// ---------------------------------------------------------------------------

const ADMIN_UIDS = new Set([
  // Add admin uids here if you want to restrict the callable. Empty = open.
]);

async function migrateOneCollection(collection, maxDocs, { retryPermanentFailures = false } = {}) {
  const fs = admin.firestore();
  const seen = new Set();
  let scanned = 0;
  let queued = 0;
  let skipped = 0;
  let batch = fs.batch();
  let pending = 0;

  const tryQueueDoc = (docRef, data) => {
    if (seen.has(docRef.id)) return;
    seen.add(docRef.id);
    scanned++;

    if (data.processing === true) {
      skipped++;
      return;
    }
    const isPermanentFailure =
      data.transcodeError && data.transcodeErrorCategory === 'permanent';
    if (isPermanentFailure && !retryPermanentFailures) {
      skipped++;
      return;
    }
    if (Number(data.transcodeAttemptCount || 0) >= MAX_REQUEUE_ATTEMPTS) {
      skipped++;
      return;
    }
    if (data.transcodeRequeueExhausted === true) {
      skipped++;
      return;
    }
    if (data.processed === true || hasAdaptiveProcessedHls(data)) {
      skipped++;
      return;
    }
    if (!hasTranscodableRawSource(data, collection)) {
      skipped++;
      return;
    }

    const patch = {
      legacyRawFallback: true,
      requestedTranscodeAt: admin.firestore.FieldValue.serverTimestamp(),
      requeuedAt: admin.firestore.FieldValue.delete(),
      processed: false,
    };
    if (docHasVideoMedia(data) || hasTranscodableRawSource(data, collection)) {
      patch.isVideo = true;
      patch.hasMedia = true;
    }
    if (isLegacyInvalidHlsUrl(data.hlsUrl)) {
      patch.hlsUrl = admin.firestore.FieldValue.delete();
    }
    if (isPermanentFailure && retryPermanentFailures) {
      patch.transcodeError = admin.firestore.FieldValue.delete();
      patch.transcodeErrorCategory = admin.firestore.FieldValue.delete();
      patch.transcodeErrorAt = admin.firestore.FieldValue.delete();
      patch.transcodeRequeueExhausted = admin.firestore.FieldValue.delete();
      patch.transcodeAttemptCount = 0;
    }
    batch.set(docRef, patch, { merge: true });
    queued++;
    pending++;
  };

  const commitIfNeeded = async (force = false) => {
    if (pending >= 400 || (force && pending > 0)) {
      await batch.commit();
      batch = fs.batch();
      pending = 0;
    }
  };

  const snapProcessedFalse = await fs
    .collection(collection)
    .where('processed', '==', false)
    .limit(maxDocs)
    .get();

  for (const doc of snapProcessedFalse.docs) {
    tryQueueDoc(doc.ref, doc.data() || {});
    if (pending >= 400) await commitIfNeeded(true);
  }

  // Pass 2: docs missing `processed` (common on May 2026 uploads).
  if (seen.size < maxDocs) {
    const snapIsVideo = await fs
      .collection(collection)
      .where('isVideo', '==', true)
      .limit(maxDocs)
      .get();
    for (const doc of snapIsVideo.docs) {
      if (seen.size >= maxDocs) break;
      tryQueueDoc(doc.ref, doc.data() || {});
      if (pending >= 400) await commitIfNeeded(true);
    }
  }

  // Pass 3: Feb–Apr legacy flat-path uploads (often missing isVideo/processed).
  if (seen.size < maxDocs) {
    for (const orderField of ['timestamp', 'createdAt']) {
      try {
        const snapRecent = await fs
          .collection(collection)
          .orderBy(orderField, 'desc')
          .limit(maxDocs)
          .get();
        for (const doc of snapRecent.docs) {
          if (seen.size >= maxDocs) break;
          tryQueueDoc(doc.ref, doc.data() || {});
          if (pending >= 400) await commitIfNeeded(true);
        }
        break;
      } catch (_) {
        /* try next order field */
      }
    }
  }

  await commitIfNeeded(true);
  return { scanned, queued, skipped };
}

/**
 * Re-queue docs stuck at processing=true (CF crash / stale Firestore).
 */
async function migrateStuckProcessing(collection, maxDocs) {
  const fsDb = admin.firestore();
  const snap = await fsDb
    .collection(collection)
    .where('processing', '==', true)
    .limit(maxDocs)
    .get();

  const cutoffMs = Date.now() - STUCK_PROCESSING_MS;
  let queued = 0;
  let skipped = 0;
  const batch = fsDb.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.processed === true) {
      skipped++;
      continue;
    }
    const started = data.transcodeStartedAt;
    const startedMs =
      started && typeof started.toMillis === 'function'
        ? started.toMillis()
        : null;
    if (startedMs != null && startedMs > cutoffMs) {
      skipped++;
      continue;
    }
    if (
      data.transcodeError &&
      data.transcodeErrorCategory === 'permanent'
    ) {
      skipped++;
      continue;
    }
    const candidates = collectRawCandidates(collection, data);
    if (!candidates.some((u) => extractStoragePathFromUrl(u))) {
      skipped++;
      continue;
    }
    batch.set(
      doc.ref,
      {
        legacyRawFallback: true,
        requestedTranscodeAt: admin.firestore.FieldValue.serverTimestamp(),
        requeuedAt: admin.firestore.FieldValue.delete(),
        transcodeError: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );
    queued++;
    pending++;
    if (pending >= 400) {
      await batch.commit();
      pending = 0;
    }
  }
  if (pending > 0) {
    await batch.commit();
  }
  return { scanned: snap.size, queued, skipped };
}

exports.migrateLegacyVideos = onCall(
  { memory: '512MiB', timeoutSeconds: 540 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    if (ADMIN_UIDS.size > 0 && !ADMIN_UIDS.has(uid)) {
      throw new HttpsError('permission-denied', 'Admin only.');
    }

    const data = request.data || {};
    const maxDocs = Math.min(
      Math.max(parseInt(data.maxDocs, 10) || 200, 1),
      500,
    );
    const which = (data.collection || 'both').toString();
    const includeStuck = data.includeStuckProcessing === true;
    const retryPermanentFailures = data.retryPermanentFailures === true;

    const result = { posts: null, reels: null, stuck: null };
    if (which === 'posts' || which === 'both') {
      result.posts = await migrateOneCollection('posts', maxDocs, {
        retryPermanentFailures,
      });
    }
    if (which === 'reels' || which === 'both') {
      result.reels = await migrateOneCollection('reels', maxDocs, {
        retryPermanentFailures,
      });
    }
    if (includeStuck) {
      result.stuck = { posts: null, reels: null };
      if (which === 'posts' || which === 'both') {
        result.stuck.posts = await migrateStuckProcessing('posts', maxDocs);
      }
      if (which === 'reels' || which === 'both') {
        result.stuck.reels = await migrateStuckProcessing('reels', maxDocs);
      }
    }
    console.log('[MIGRATE_LEGACY_VIDEOS]', JSON.stringify(result));
    return result;
  },
);

// ─── Place search (Google Places API New, Nominatim fallback) ───────────────

const PLACES_USER_AGENT = 'HaloApp/1.0 (cloud function)';

function placesApiKey() {
  return process.env.GOOGLE_PLACES_API_KEY || '';
}

function toPlaceDto({ id, name, address, latitude, longitude }) {
  return {
    id: id || '',
    name: name || '',
    address: address || '',
    latitude: latitude ?? 0,
    longitude: longitude ?? 0,
    placeId: id || '',
    locationName: name || '',
    locationAddress: address || '',
  };
}

function googlePlaceToDto(place) {
  if (!place) return null;
  const lat = place.location?.latitude;
  const lng = place.location?.longitude;
  const name = (place.displayName?.text || '').trim();
  if (!name || lat == null || lng == null) return null;
  return toPlaceDto({
    id: (place.id || '').trim(),
    name,
    address: (place.formattedAddress || '').trim(),
    latitude: lat,
    longitude: lng,
  });
}

async function googleTextSearch(query, latitude, longitude) {
  const key = placesApiKey();
  if (!key) return null;

  const body = {
    textQuery: query,
    maxResultCount: 15,
  };
  if (latitude != null && longitude != null) {
    body.locationBias = {
      circle: {
        center: { latitude, longitude },
        radius: 50000,
      },
    };
  }

  const res = await fetch('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask':
        'places.id,places.displayName,places.formattedAddress,places.location',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    console.warn('[searchPlaces] Google HTTP', res.status);
    return null;
  }

  const data = await res.json();
  const places = Array.isArray(data.places) ? data.places : [];
  return places.map(googlePlaceToDto).filter(Boolean);
}

async function googleNearbySearch(latitude, longitude) {
  const key = placesApiKey();
  if (!key) return null;

  const body = {
    includedTypes: [
      'restaurant',
      'cafe',
      'bar',
      'park',
      'shopping_mall',
      'hotel',
      'gym',
      'store',
    ],
    maxResultCount: 15,
    locationRestriction: {
      circle: {
        center: { latitude, longitude },
        radius: 3000,
      },
    },
  };

  const res = await fetch('https://places.googleapis.com/v1/places:searchNearby', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': key,
      'X-Goog-FieldMask':
        'places.id,places.displayName,places.formattedAddress,places.location',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    console.warn('[nearbyPlaces] Google HTTP', res.status);
    return null;
  }

  const data = await res.json();
  const places = Array.isArray(data.places) ? data.places : [];
  return places.map(googlePlaceToDto).filter(Boolean);
}

async function nominatimSearch(query, latitude, longitude) {
  const params = new URLSearchParams({
    q: query,
    format: 'jsonv2',
    addressdetails: '1',
    limit: '15',
    dedupe: '1',
  });
  if (latitude != null && longitude != null) {
    const delta = 0.12;
    params.set(
      'viewbox',
      `${longitude - delta},${latitude + delta},${longitude + delta},${latitude - delta}`,
    );
  }

  const res = await fetch(
    `https://nominatim.openstreetmap.org/search?${params.toString()}`,
    { headers: { 'User-Agent': PLACES_USER_AGENT } },
  );
  if (!res.ok) return [];

  const raw = await res.json();
  if (!Array.isArray(raw)) return [];

  const seen = new Set();
  const out = [];
  for (const item of raw) {
    const lat = parseFloat(item.lat);
    const lon = parseFloat(item.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;

    const osmType = (item.osm_type || '').toString();
    const osmId = (item.osm_id || '').toString();
    const id = osmId ? `osm:${osmType}:${osmId}` : `nominatim:${lat},${lon}`;

    let name = (item.name || '').toString().trim();
    const display = (item.display_name || '').toString().trim();
    if (!name && display) name = display.split(',')[0].trim();
    if (!name) continue;

    let address = '';
    if (item.address && typeof item.address === 'object') {
      const parts = [];
      for (const k of [
        'house_number',
        'road',
        'suburb',
        'neighbourhood',
        'city',
        'town',
        'village',
        'state',
        'country',
      ]) {
        const v = (item.address[k] || '').toString().trim();
        if (v && !parts.includes(v)) parts.push(v);
      }
      address = parts.join(', ');
    }
    if (!address && display.includes(',')) {
      address = display.split(',').slice(1).join(',').trim();
    }

    if (seen.has(id)) continue;
    seen.add(id);
    out.push(toPlaceDto({ id, name, address, latitude: lat, longitude: lon }));
  }
  return out;
}

async function nominatimNearby(latitude, longitude) {
  const terms = [
    'cafe',
    'restaurant',
    'coffee',
    'park',
    'mall',
    'hotel',
    'gym',
    'store',
  ];
  const delta = 0.018;
  const viewbox = `${longitude - delta},${latitude + delta},${longitude + delta},${latitude - delta}`;

  const seen = new Set();
  const out = [];

  for (const term of terms) {
    const params = new URLSearchParams({
      q: term,
      format: 'jsonv2',
      addressdetails: '1',
      limit: '6',
      viewbox,
      bounded: '1',
      dedupe: '1',
    });
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?${params.toString()}`,
        { headers: { 'User-Agent': PLACES_USER_AGENT } },
      );
      if (!res.ok) continue;
      const raw = await res.json();
      if (!Array.isArray(raw)) continue;
      for (const item of raw) {
        const lat = parseFloat(item.lat);
        const lon = parseFloat(item.lon);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
        const osmType = (item.osm_type || '').toString();
        const osmId = (item.osm_id || '').toString();
        const id = osmId ? `osm:${osmType}:${osmId}` : `nominatim:${lat},${lon}`;
        if (seen.has(id)) continue;

        let name = (item.name || '').toString().trim();
        const display = (item.display_name || '').toString().trim();
        if (!name && display) name = display.split(',')[0].trim();
        if (!name) continue;

        let address = '';
        if (item.address && typeof item.address === 'object') {
          const parts = [];
          for (const k of ['road', 'suburb', 'city', 'town', 'state', 'country']) {
            const v = (item.address[k] || '').toString().trim();
            if (v && !parts.includes(v)) parts.push(v);
          }
          address = parts.join(', ');
        }

        seen.add(id);
        out.push(toPlaceDto({ id, name, address, latitude: lat, longitude: lon }));
        if (out.length >= 20) break;
      }
    } catch (e) {
      console.warn('[nearbyPlaces] Nominatim term failed', term, e.message);
    }
    if (out.length >= 20) break;
  }

  return out.slice(0, 15);
}

exports.searchPlaces = onCall(async (request) => {
  const query = (request.data?.query || '').toString().trim();
  if (query.length < 2) {
    throw new HttpsError('invalid-argument', 'Query must be at least 2 characters.');
  }

  const latitude = request.data?.latitude;
  const longitude = request.data?.longitude;
  const lat = latitude != null ? Number(latitude) : null;
  const lng = longitude != null ? Number(longitude) : null;

  let places = await googleTextSearch(query, lat, lng);
  if (!places) {
    places = await nominatimSearch(query, lat, lng);
  }

  return { places: places || [] };
});

exports.nearbyPlaces = onCall(async (request) => {
  const latitude = Number(request.data?.latitude);
  const longitude = Number(request.data?.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpsError('invalid-argument', 'latitude and longitude are required.');
  }

  let places = await googleNearbySearch(latitude, longitude);
  if (!places) {
    places = await nominatimNearby(latitude, longitude);
  }

  return { places: places || [] };
});

// ─── Explore global ranking (server-side virality scores) ───────────────────

const exploreDb = admin.firestore();

async function writeExploreRankForPost(postRef, postData) {
  const scores = computeGlobalExploreScores(postData || {});
  await postRef.set(
    {
      exploreRankScore: scores.exploreRankScore,
      trendingVelocity: scores.trendingVelocity,
      exploreRankUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

exports.refreshPostExploreRank = onDocumentWritten(
  {
    document: 'posts/{postId}',
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async (event) => {
    const afterSnap = event.data && event.data.after;
    if (!afterSnap || !afterSnap.exists) return;

    const before = event.data.before && event.data.before.exists
      ? event.data.before.data()
      : null;
    const after = afterSnap.data();
    if (!after) return;

    if (before && !rankFieldsChanged(before, after)) {
      const rankOnly = ['exploreRankScore', 'trendingVelocity', 'exploreRankUpdatedAt'];
      const changedKeys = Object.keys(after).filter(
        (k) => JSON.stringify(before[k]) !== JSON.stringify(after[k]),
      );
      if (changedKeys.length > 0 && changedKeys.every((k) => rankOnly.includes(k))) {
        return;
      }
    }

    const scores = computeGlobalExploreScores(after);
    const current = Number(after.exploreRankScore || 0);
    if (
      Math.abs(current - scores.exploreRankScore) < 0.0005 &&
      Math.abs(Number(after.trendingVelocity || 0) - scores.trendingVelocity) < 0.0005
    ) {
      return;
    }

    await writeExploreRankForPost(afterSnap.ref, after);
  },
);

exports.scheduledExploreRankRefresh = onSchedule(
  {
    schedule: 'every 6 hours',
    timeZone: 'UTC',
    memory: '512MiB',
    timeoutSeconds: 540,
  },
  async () => {
    const snap = await exploreDb
      .collection('posts')
      .orderBy('createdAt', 'desc')
      .limit(400)
      .get();

    let batch = exploreDb.batch();
    let ops = 0;

    for (const doc of snap.docs) {
      const scores = computeGlobalExploreScores(doc.data());
      batch.set(
        doc.ref,
        {
          exploreRankScore: scores.exploreRankScore,
          trendingVelocity: scores.trendingVelocity,
          exploreRankUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      ops += 1;
      if (ops >= 400) {
        await batch.commit();
        batch = exploreDb.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    console.log(`[scheduledExploreRankRefresh] updated ${snap.size} posts`);
  },
);
