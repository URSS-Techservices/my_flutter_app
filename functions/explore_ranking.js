/**
 * Server-side global Explore ranking scores (non-personalized).
 * Written to posts/{id}.exploreRankScore and trendingVelocity.
 */

function toInt(value) {
  if (value == null) return 0;
  if (typeof value === 'number') return Math.trunc(value);
  const parsed = parseInt(String(value).trim(), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function toDate(value) {
  if (!value) return new Date();
  if (typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
}

function engagementScore(likes, comments, saves) {
  const raw = (likes + comments * 2 + saves * 3) / 100;
  return Math.min(1, Math.max(0, raw));
}

function recencyScore(createdAt) {
  const hours = (Date.now() - createdAt.getTime()) / 3600000;
  return 1 / (Math.max(hours, 0) + 1);
}

function trendingVelocity(likes, comments, saves, createdAt) {
  const hours = (Date.now() - createdAt.getTime()) / 3600000;
  const engagement = likes + comments * 2 + saves * 3;
  return engagement / (hours + 2);
}

function videoQualityScore(post) {
  const views = toInt(post.views ?? post.viewCount);
  if (views <= 0) return 0;
  const duration = Math.max(toInt(post.durationSeconds ?? post.duration), 1);
  const totalWatch = toInt(post.totalWatchTime);
  const ratio = Math.min(1, Math.max(0, totalWatch / (views * duration)));
  return ratio;
}

/**
 * Global virality score 0..1 (no personalization).
 */
function computeGlobalExploreScores(post) {
  const likes = toInt(post.likeCount ?? post.likesCount);
  const comments = toInt(post.commentCount ?? post.commentsCount);
  const saves = toInt(post.saveCount ?? post.savesCount);
  const createdAt = toDate(post.createdAt);

  const eng = engagementScore(likes, comments, saves);
  const rec = recencyScore(createdAt);
  const video = post.isVideo === true ? videoQualityScore(post) * 0.1 : 0;

  const exploreRankScore = Math.min(1, Math.max(0, eng * 0.55 + rec * 0.35 + video));
  const trendingVelocityScore = trendingVelocity(likes, comments, saves, createdAt);

  return {
    exploreRankScore,
    trendingVelocity: trendingVelocityScore,
    exploreRankUpdatedAt: new Date(),
  };
}

function rankFieldsChanged(before, after) {
  if (!before) return true;
  const keys = [
    'likeCount',
    'likesCount',
    'commentCount',
    'commentsCount',
    'saveCount',
    'savesCount',
    'createdAt',
    'isVideo',
    'views',
    'totalWatchTime',
    'durationSeconds',
  ];
  for (const key of keys) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
      return true;
    }
  }
  return false;
}

module.exports = {
  computeGlobalExploreScores,
  rankFieldsChanged,
};
