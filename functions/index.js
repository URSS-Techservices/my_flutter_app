const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { randomUUID } = require('crypto');

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

const TIER_KEYS = ['1080', '720', '480', '360'];

const BITRATE_BY_KEY = {
  1080: {
    videoBitrate: '5000k',
    maxrate: '5500k',
    bufsize: '10000k',
    bandwidth: 5500000,
  },
  720: {
    videoBitrate: '3000k',
    maxrate: '3300k',
    bufsize: '6000k',
    bandwidth: 3300000,
  },
  480: {
    videoBitrate: '1500k',
    maxrate: '1650k',
    bufsize: '3000k',
    bandwidth: 1650000,
  },
  360: {
    videoBitrate: '800k',
    maxrate: '880k',
    bufsize: '1600k',
    bandwidth: 880000,
  },
};

/** Landscape max boxes (never stretched; pad only to even dimensions). */
const LADDER_LANDSCAPE = [
  { key: '1080', width: 1920, height: 1080 },
  { key: '720', width: 1280, height: 720 },
  { key: '480', width: 854, height: 480 },
  { key: '360', width: 640, height: 360 },
].map((t) => ({ ...t, ...BITRATE_BY_KEY[t.key] }));

/** Portrait max boxes (reels / vertical). */
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

function shouldSkipPath(filePath) {
  if (!filePath) return true;
  if (filePath.includes('/videos/processed/')) return true;
  if (filePath.includes('optimized')) return true;
  if (filePath.includes('/segments/')) return true;
  if (filePath.includes('master.m3u8')) return true;
  if (filePath.includes('video_thumb')) return true;
  if (filePath.endsWith('.jpg') || filePath.endsWith('.webp')) return true;
  if (filePath.endsWith('.m3u8') || filePath.endsWith('.ts')) return true;
  return false;
}

function parseUploadContext(filePath) {
  if (shouldSkipPath(filePath)) return null;

  const reelMatch = filePath.match(/^videos\/raw\/(.+\.(mp4|mov|m4v|webm))$/i);
  if (reelMatch) {
    const fileName = path.basename(filePath);
    const videoId = path.parse(fileName).name;
    return {
      kind: 'reel',
      jobId: videoId,
      videoKey: '0',
      fileName,
    };
  }

  const postMatch = filePath.match(
    /^users\/[^/]+\/posts\/([^/]+)\/(video(?:_\d+)?)\.(mp4|mov|m4v|webm)$/i,
  );
  if (postMatch) {
    const postId = postMatch[1];
    const videoStem = postMatch[2];
    const videoKey =
      videoStem === 'video' ? '0' : videoStem.replace('video_', '');
    const fileName = `${videoStem}.${postMatch[3]}`;
    return {
      kind: 'post',
      jobId: `${postId}_${videoKey}`,
      postId,
      videoKey,
      fileName,
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

/** Firebase Storage: relative HLS segment paths need absolute tokenized URLs. */
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
        if (trimmed.endsWith('.m3u8') || trimmed.endsWith('.ts')) {
          let absolutePath;
          if (trimmed.includes('/')) {
            absolutePath = `${processedBase}/${trimmed}`;
          } else if (trimmed.endsWith('.ts') && tierKey) {
            absolutePath = `${processedBase}/segments/${tierKey}/${trimmed}`;
          } else {
            absolutePath = `${processedBase}/${trimmed}`;
          }
          return storageDownloadUrl(bucketName, absolutePath, sharedToken);
        }
        return line;
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

function runFfmpeg(inputPath, outputPath, outputOptions) {
  return new Promise((resolve, reject) => {
    ffmpeg(inputPath)
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

function probeVideo(localInput) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(localInput, (err, meta) => {
      if (err) return reject(err);
      const video = (meta.streams || []).find((s) => s.codec_type === 'video');
      const codedW = video?.width || 0;
      const codedH = video?.height || 0;
      const rotation = parseRotationDegrees(video);
      const display = displayDimensions(codedW, codedH, rotation);
      const orientation =
        display.height > display.width ? 'portrait' : 'landscape';
      resolve({
        codedWidth: codedW,
        codedHeight: codedH,
        width: display.width,
        height: display.height,
        rotation: display.rotation,
        orientation,
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

/** Apply display-matrix / tag rotation before scale (paired with -noautorotate on input). */
function rotationFilterPrefix(rotationDeg) {
  const rot = ((Math.round(rotationDeg) % 360) + 360) % 360;
  if (rot === 90) return 'transpose=1,';
  if (rot === 270) return 'transpose=2,';
  if (rot === 180) return 'hflip,vflip,';
  return '';
}

/** Fit inside max box; letterbox pad to even size only — no stretch, no square forcing. */
function scalePadFilter(tier, rotationDeg = 0) {
  return [
    rotationFilterPrefix(rotationDeg),
    `scale='min(${tier.width},iw)':'min(${tier.height},ih)':force_original_aspect_ratio=decrease`,
    `pad=ceil(iw/2)*2:ceil(ih/2)*2:(ow-iw)/2:(oh-ih)/2:color=black`,
    'fps=30',
    'format=yuv420p',
    'setsar=1',
  ].join(',');
}

/** Pixels are display-oriented; clear stale rotate tags on output. */
const ORIENTATION_OUTPUT_OPTS = [
  '-metadata:s:v:0',
  'rotate=0',
];

function baseVideoOptions(tier, rotationDeg = 0) {
  return [
    '-noautorotate',
    '-vf',
    scalePadFilter(tier, rotationDeg),
    '-c:v',
    'libx264',
    '-profile:v',
    'main',
    '-level',
    '4.0',
    '-preset',
    'veryfast',
    '-pix_fmt',
    'yuv420p',
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

/** One-time normalize: SDR 8-bit yuv420p (HDR/HEVC/DV → SDR), orientation-aware max box. */
async function normalizeSource(localInput, tempDir, topTier, rotationDeg) {
  const out = path.join(tempDir, '_normalized.mp4');
  const vf = scalePadFilter(topTier, rotationDeg);
  await runFfmpeg(localInput, out, [
    '-noautorotate',
    '-vf',
    vf,
    '-c:v',
    'libx264',
    '-profile:v',
    'main',
    '-level',
    '4.0',
    '-preset',
    'veryfast',
    '-pix_fmt',
    'yuv420p',
    '-b:v',
    '5000k',
    '-maxrate',
    '5500k',
    '-bufsize',
    '10000k',
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
    ...AUDIO_OPTIONS,
    ...ORIENTATION_OUTPUT_OPTS,
    '-movflags',
    '+faststart',
  ]);
  return out;
}

async function encodeRendition(inputPath, workDir, tier, rotationDeg = 0) {
  const segDir = path.join(workDir, 'segments', tier.key);
  fs.mkdirSync(segDir, { recursive: true });

  const mp4Out = path.join(workDir, `optimized_${tier.key}.mp4`);
  const playlistPath = path.join(workDir, `${tier.key}p.m3u8`);
  const segmentPattern = path.join(segDir, 'seg_%03d.ts');

  const videoOpts = baseVideoOptions(tier, rotationDeg);

  await runFfmpeg(inputPath, mp4Out, [
    ...videoOpts,
    ...AUDIO_OPTIONS,
    ...ORIENTATION_OUTPUT_OPTS,
    '-movflags',
    '+faststart',
  ]);

  await runFfmpeg(inputPath, playlistPath, [
    ...videoOpts,
    ...AUDIO_OPTIONS,
    ...ORIENTATION_OUTPUT_OPTS,
    '-hls_time',
    '4',
    '-hls_playlist_type',
    'vod',
    '-hls_list_size',
    '0',
    '-hls_segment_filename',
    segmentPattern,
    '-f',
    'hls',
  ]);

  return { tier, mp4Out, playlistPath };
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
    `Orientation ${probe.orientation} (${probe.width}x${probe.height}, rotate=${probe.rotation}); renditions: ${tiers.map((t) => `${t.key}→${t.width}x${t.height}`).join(', ')}`,
  );

  const topTier = ladder[0];
  const normalized = await normalizeSource(
    localInput,
    tempDir,
    topTier,
    probe.rotation,
  );
  const encoded = [];
  for (const tier of tiers) {
    console.log(`Encoding ${tier.key}p (${tier.width}x${tier.height})…`);
    const result = await encodeRendition(normalized, workDir, tier, 0);
    encoded.push(result);
  }

  writeMasterPlaylist(workDir, encoded);
  const thumbnailPath = await generateThumbnail(
    normalized,
    workDir,
    probe.orientation === 'portrait',
  );

  return { workDir, tiers, encoded, thumbnailPath, orientation: probe.orientation };
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

  const mp4720 =
    qualities['720'] ||
    qualities['1080'] ||
    qualities['480'] ||
    qualities['360'] ||
    '';

  return { mp4: mp4720, hls: masterUrl, thumb: thumbUrl, qualities };
}

async function isAlreadyProcessed(bucket, processedBase) {
  const [masterExists] = await bucket
    .file(`${processedBase}/master.m3u8`)
    .exists();
  if (masterExists) return true;
  const [legacyExists] = await bucket
    .file(`${processedBase}/hls/playlist.m3u8`)
    .exists();
  return legacyExists;
}

async function updateReelDoc(videoId, urls) {
  const ref = admin.firestore().collection('reels').doc(videoId);
  const snap = await ref.get();
  if (!snap.exists) {
    console.warn(`Reel doc missing: ${videoId}`);
    return;
  }
  await ref.update({
    processed: true,
    processing: false,
    videoUrl: urls.mp4,
    hlsUrl: urls.hls,
    thumbnailUrl: urls.thumb,
    qualities: urls.qualities || {},
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function updatePostDoc(postId, videoKey, urls, rawStoragePath) {
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
    const rawUrl = (prev.rawVideoUrl || prev.videoUrl || prev.url || '').toString();

    media[targetIdx] = {
      ...prev,
      type: 'video',
      videoUrl: urls.mp4,
      url: urls.mp4,
      hlsUrl: urls.hls,
      qualities: urls.qualities || {},
      rawVideoUrl: rawUrl || prev.videoUrl || prev.url,
      thumbnail: urls.thumb || prev.thumbnail || prev.thumbnailUrl || '',
      thumbnailUrl: urls.thumb || prev.thumbnailUrl || prev.thumbnail || '',
      processed: true,
      processing: false,
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
    };

    if (firstVideo) {
      update.videoUrl = firstVideo.videoUrl || firstVideo.url || '';
      update.hlsUrl = firstVideo.hlsUrl || '';
      update.qualities = firstVideo.qualities || urls.qualities || {};
      const thumb =
        firstVideo.thumbnail ||
        firstVideo.thumbnailUrl ||
        urls.thumb ||
        '';
      if (thumb) update.thumbnailUrl = thumb;
    }

    await ref.update(update);
    console.log(`Post ${postId} media[${targetIdx}] marked processed`);
    return;
  }

  console.error(`Timed out waiting for post doc ${postId}`);
}

exports.processVideo = onObjectFinalized(
  {
    memory: '2GiB',
    timeoutSeconds: 540,
    cpu: 2,
  },
  async (event) => {
    const object = event.data;
    const filePath = object.name;

    const ctx = parseUploadContext(filePath);
    if (!ctx) {
      return null;
    }

    const bucket = admin.storage().bucket(object.bucket);
    const tempDir = path.join(os.tmpdir(), ctx.jobId);

    try {
      if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

      const processedBase =
        ctx.kind === 'post'
          ? `videos/processed/posts/${ctx.postId}/${ctx.videoKey}`
          : `videos/processed/${ctx.jobId}`;

      if (await isAlreadyProcessed(bucket, processedBase)) {
        console.log(`Skip duplicate transcode: ${processedBase}`);
        return null;
      }

      const localInput = path.join(tempDir, ctx.fileName);
      await bucket.file(filePath).download({ destination: localInput });
      console.log(`Downloaded ${filePath} for ${ctx.kind} job ${ctx.jobId}`);

      const { workDir, tiers, thumbnailPath } = await transcodeToAdaptiveHls(
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
        await updateReelDoc(ctx.jobId, urls);
      } else {
        await updatePostDoc(ctx.postId, ctx.videoKey, urls, filePath);
      }

      fs.rmSync(tempDir, { recursive: true, force: true });
      console.log(`Transcode complete for ${ctx.jobId}`);
      return null;
    } catch (err) {
      console.error('PROCESS VIDEO ERROR:', err);
      try {
        if (ctx.kind === 'post') {
          const ref = admin.firestore().collection('posts').doc(ctx.postId);
          const snap = await ref.get();
          if (snap.exists) {
            await ref.update({
              processing: false,
              transcodeError: err.message || 'Transcode failed',
            });
          }
        }
      } catch (updateErr) {
        console.error('Failed to write transcode error:', updateErr);
      }
      if (fs.existsSync(tempDir)) {
        fs.rmSync(tempDir, { recursive: true, force: true });
      }
      return null;
    }
  },
);
