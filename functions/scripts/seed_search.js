/**
 * One-time setup for the search feature (safe to re-run).
 *
 *   1. Creates `search_config/main` and `search_categories/*` if missing, so an
 *      admin can edit them in the Firebase console afterwards.
 *   2. Backfills `users/{uid}.interestTags` for people who signed up before the
 *      field existed.
 *
 * Usage (from /functions, after `npx firebase-tools login`):
 *   node scripts/seed_search.js              # seed + backfill
 *   node scripts/seed_search.js --backfill   # only backfill users
 *   node scripts/seed_search.js --seed       # only seed config/categories
 *   node scripts/seed_search.js --force      # overwrite existing seed docs
 */
const admin = require('firebase-admin');
const { buildInterestTags } = require('../interest_tags_core');

const projectId = process.env.GCLOUD_PROJECT || 'halo-fb212';
if (!admin.apps.length) admin.initializeApp({ projectId });
const db = admin.firestore();

const args = new Set(process.argv.slice(2));
const onlySeed = args.has('--seed');
const onlyBackfill = args.has('--backfill');
const force = args.has('--force');

const CONFIG = {
  sectionOrder: ['network', 'interest', 'popular', 'fresh', 'nearby', 'others'],
  enabledSections: {
    network: true, interest: true, popular: true, fresh: true, nearby: false, others: true,
  },
  sectionLimit: 20,
  othersLimit: 40,
  newDays: 30,
  titles: {
    network: 'People you know',
    interest: 'Matches your interests',
    popular: 'Popular',
    fresh: 'New on Halo',
    nearby: 'Near you',
    others: 'More people',
  },
};

// `tags` are the raw option labels used in the profile forms; the app
// normalizes them ("Yoga & Breathwork" -> yoga_breathwork).
const s = (name, emoji, tags = [], extra = {}) => ({ name, emoji, tags, isActive: true, ...extra });

const CATEGORIES = [
  {
    id: 'physical_fitness', name: 'Physical Fitness', emoji: '💪', order: 1,
    subcategories: [
      s('Fitness', '🏋️', ['General Fitness', 'Personal Trainer', 'Gym', 'Fitness Studio', 'Endurance', 'Body Toning', 'Cardio Equipment', 'Strength Equipment', 'Personal Training'], { interestTerm: 'fitness', specializationTerm: 'General Fitness' }),
      s('Strength Training', '💪', ['Strength Training', 'Strength Building', 'Strength & Conditioning Coach', 'Strength Equipment'], { specializationTerm: 'Strength Training' }),
      s('Functional Training', '🤸', ['Functional Training', 'Group Classes'], { specializationTerm: 'Functional Training' }),
      s('CrossFit', '🔥', ['CrossFit'], { specializationTerm: 'CrossFit' }),
      s('Calisthenics', '🏃', ['Calisthenics'], { specializationTerm: 'Calisthenics' }),
      s('Bodybuilding', '🦾', ['Bodybuilding', 'Muscle Gain'], { specializationTerm: 'Bodybuilding' }),
      s('Posture Correction', '🧍', ['Posture Correction'], { specializationTerm: 'Posture Correction' }),
      s('Flexibility & Mobility', '🤸‍♀️', ['Flexibility & Mobility', 'Flexibility / Yoga', 'Mobility Specialist'], { specializationTerm: 'Flexibility & Mobility' }),
      s('Sports Performance', '⚡', ['Sports Performance', 'Sports Therapist'], { specializationTerm: 'Sports Performance' }),
      s('Injury Prevention', '🩹', ['Injury Prevention', 'Sports Rehab Center'], { specializationTerm: 'Injury Prevention' }),
    ],
  },
  {
    id: 'nutrition_diet', name: 'Nutrition & Diet', emoji: '🥗', order: 2,
    subcategories: [
      s('Nutrition', '🥗', ['Nutrition Planning', 'Nutritionist / Dietician', 'Diet Clinic', 'Nutrition Consultation', 'Supplement Store', 'Supplements Available'], { interestTerm: 'nutrition', specializationTerm: 'Nutrition Planning' }),
      s('Weight Loss', '⚖️', ['Weight Loss'], { specializationTerm: 'Weight Loss' }),
      s('Muscle Gain', '💥', ['Muscle Gain'], { specializationTerm: 'Muscle Gain' }),
      s('Diet', '🍽️', ['Nutrition Planning', 'Nutritionist / Dietician', 'Diet Clinic', 'Food and drinks', 'Café/Restaurant'], { specializationTerm: 'Nutrition Planning' }),
    ],
  },
  {
    id: 'mind_body', name: 'Mind & Body Wellness', emoji: '🧘', order: 3,
    subcategories: [
      s('Yoga', '🧘', ['Yoga & Breathwork', 'Yoga Instructor', 'Yoga Studio', 'Flexibility / Yoga', 'Yoga Classes'], { interestTerm: 'yoga', specializationTerm: 'Yoga & Breathwork' }),
      s('Mental Health', '🧠', ['Mental Wellness', 'Stress Management'], { interestTerm: 'mental_health' }),
      s('Stress Management', '😌', ['Stress Management'], { specializationTerm: 'Stress Management' }),
      s('Mindfulness / Meditation', '🌿', ['Mindfulness / Meditation Coach', 'Mental Wellness'], { interestTerm: 'mental_health' }),
      s('Holistic Wellness', '✨', ['Holistic Wellness', 'Spa / Wellness Center', 'Massage Therapy', 'Steam / Sauna'], { specializationTerm: 'Holistic Wellness' }),
    ],
  },
  {
    id: 'rehab_recovery', name: 'Rehabilitation & Recovery', emoji: '🏥', order: 4,
    subcategories: [
      s('Rehab & Recovery', '🏥', ['Rehab & Recovery', 'Physiotherapist', 'Physiotherapy Clinic', 'Sports Rehab Center', 'Physiotherapy', 'Rehab & Recovery Sessions'], { specializationTerm: 'Rehab & Recovery' }),
      s('Pain Management', '💆', ['Pain Management', 'Physiotherapist', 'Massage Therapy'], { specializationTerm: 'Pain Management' }),
      s('Injury Prevention', '🩹', ['Injury Prevention', 'Sports Rehab Center'], { specializationTerm: 'Injury Prevention' }),
      s('Posture Correction', '🧍', ['Posture Correction'], { specializationTerm: 'Posture Correction' }),
    ],
  },
  {
    id: 'lifestyle', name: 'Lifestyle & General', emoji: '✨', order: 5,
    subcategories: [
      s('Productivity', '📈', [], { interestTerm: 'productivity' }),
      s('Wellness Coach', '🌟', ['Wellness Coach'], { specializationTerm: 'Wellness Coach' }),
      s('Mobility Specialist', '🤸', ['Mobility Specialist'], { specializationTerm: 'Mobility Specialist' }),
      s('Personal Trainer', '🏋️', ['Personal Trainer', 'Personal Training'], { specializationTerm: 'Personal Trainer' }),
    ],
  },
  {
    id: 'other_interests', name: 'Other Interests', emoji: '🎯', order: 6,
    subcategories: [
      s('Music', '🎵', [], { interestTerm: 'music' }),
      s('Reading', '📚', [], { interestTerm: 'reading' }),
      s('Travel', '✈️', [], { interestTerm: 'travel' }),
      s('Other', '🎯', ['Other'], { specializationTerm: 'Other' }),
    ],
  },
];

async function seed() {
  const configRef = db.collection('search_config').doc('main');
  if (force || !(await configRef.get()).exists) {
    await configRef.set(CONFIG);
    console.log('search_config/main written');
  } else {
    console.log('search_config/main exists (use --force to overwrite)');
  }

  for (const { id, ...category } of CATEGORIES) {
    const ref = db.collection('search_categories').doc(id);
    if (force || !(await ref.get()).exists) {
      await ref.set({ ...category, isActive: true });
      console.log(`search_categories/${id} written`);
    } else {
      console.log(`search_categories/${id} exists (use --force to overwrite)`);
    }
  }
}

async function backfill() {
  let last = null;
  let scanned = 0;
  let updated = 0;

  for (;;) {
    let q = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(300);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    let writes = 0;
    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data();
      const next = buildInterestTags(data);
      const prev = Array.isArray(data.interestTags) ? [...data.interestTags].sort() : [];
      if (next.length === prev.length && next.every((v, i) => v === prev[i])) continue;
      batch.update(doc.ref, { interestTags: next });
      writes += 1;
    }
    if (writes) await batch.commit();
    updated += writes;
    last = snap.docs[snap.docs.length - 1];
  }
  console.log(`backfill done: scanned ${scanned} users, updated ${updated}`);
}

(async () => {
  if (!onlyBackfill) await seed();
  if (!onlySeed) await backfill();
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
