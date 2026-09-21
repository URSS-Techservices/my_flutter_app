import 'package:flutter/material.dart';
import 'package:halo/features/search/domain/interest_tags.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH RESULT MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// How the signed-in user is connected to a person. [unknown] means we have not
/// looked it up (e.g. plain search results); the feed always sets a real value.
enum FollowRelation { unknown, none, following, follower, mutual }

class UserResult {
  final String userId;
  final String name;
  final String username;
  final String? profilePhoto;
  final String accountType;
  final int followersCount;
  final List<String> interestTags;
  final String location;
  final DateTime? joinedAt;
  final bool isFeatured;
  final bool isVerified;
  final FollowRelation relation;

  const UserResult({
    required this.userId,
    required this.name,
    required this.username,
    this.profilePhoto,
    required this.accountType,
    this.followersCount = 0,
    this.interestTags = const [],
    this.location = '',
    this.joinedAt,
    this.isFeatured = false,
    this.isVerified = false,
    this.relation = FollowRelation.unknown,
  });

  UserResult copyWith({FollowRelation? relation}) => UserResult(
        userId: userId,
        name: name,
        username: username,
        profilePhoto: profilePhoto,
        accountType: accountType,
        followersCount: followersCount,
        interestTags: interestTags,
        location: location,
        joinedAt: joinedAt,
        isFeatured: isFeatured,
        isVerified: isVerified,
        relation: relation ?? this.relation,
      );
}

class PostResult {
  final String postId;
  final String? imageUrl;
  final String caption;

  const PostResult({
    required this.postId,
    this.imageUrl,
    required this.caption,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CAROUSEL BANNER MODEL
// Admin uploads these from Firebase console → search_banners collection
// ─────────────────────────────────────────────────────────────────────────────

class CarouselBanner {
  final String id;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String ctaText;
  final String? ctaRoute;
  final int order;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;

  const CarouselBanner({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    this.ctaRoute,
    required this.order,
    required this.isActive,
    this.startDate,
    this.endDate,
  });

  factory CarouselBanner.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      try {
        return (v as dynamic).toDate() as DateTime?;
      } catch (_) {
        return null;
      }
    }

    return CarouselBanner(
      id: id,
      imageUrl: data['imageUrl'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      ctaText: data['ctaText'] as String? ?? 'Explore Now',
      ctaRoute: data['ctaRoute'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
    );
  }

  bool get isCurrentlyValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WELLNESS CATEGORY MODELS
// ─────────────────────────────────────────────────────────────────────────────

class SubcategorySpec {
  final String displayName;
  final String emoji;

  /// Raw option labels (as chosen in the profile forms) that belong to this
  /// subcategory, e.g. 'Yoga & Breathwork'. Normalized at query time.
  final List<String> tags;

  /// Legacy fields, still queried so people who signed up before
  /// `interestTags` existed are found.
  final String? interestTerm;
  final String? specializationTerm;

  const SubcategorySpec({
    required this.displayName,
    required this.emoji,
    this.tags = const [],
    this.interestTerm,
    this.specializationTerm,
  });

  factory SubcategorySpec.fromMap(Map<String, dynamic> m) {
    String? str(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return SubcategorySpec(
      displayName: str(m['name']) ?? 'Unnamed',
      emoji: str(m['emoji']) ?? '✨',
      tags: (m['tags'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      interestTerm: str(m['interestTerm']),
      specializationTerm: str(m['specializationTerm']),
    );
  }

  /// Normalized tags used for the Firestore `arrayContainsAny` query
  /// (Firestore allows at most 30 values).
  List<String> get matchTags {
    final all = <String>{
      for (final t in tags) normalizeTag(t),
      if (interestTerm != null) normalizeTag(interestTerm!),
      if (specializationTerm != null) normalizeTag(specializationTerm!),
    }..remove('');
    return all.take(30).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is SubcategorySpec &&
      other.displayName == displayName &&
      other.interestTerm == interestTerm &&
      other.specializationTerm == specializationTerm &&
      other.matchTags.join(',') == matchTags.join(',');

  @override
  int get hashCode => Object.hash(
      displayName, interestTerm, specializationTerm, matchTags.join(','));
}

class WellnessCategory {
  final String name;
  final String emoji;
  final String subtitle;
  final Color backgroundColor;
  final Color accentColor;
  final List<SubcategorySpec> subcategorySpecs;
  final String? backgroundImage;

  const WellnessCategory({
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.backgroundColor,
    required this.accentColor,
    required this.subcategorySpecs,
    this.backgroundImage,
  });

  List<String> get subcategories =>
      subcategorySpecs.map((s) => s.displayName).toList();

  /// Builds a category from a Firestore `search_categories` document. Colors
  /// and image are optional; missing ones borrow the built-in look for the
  /// same position so an admin only has to fill in names and tags.
  factory WellnessCategory.fromMap(Map<String, dynamic> m, int index) {
    final base = kAllCategories[index % kAllCategories.length];

    String? str(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    Color color(Object? v, Color fallback) =>
        v is num ? Color(v.toInt()) : fallback;

    final specs = (m['subcategories'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['isActive'] != false)
            .map(SubcategorySpec.fromMap)
            .toList() ??
        const <SubcategorySpec>[];

    final image = str(m['backgroundImage']);

    return WellnessCategory(
      name: str(m['name']) ?? base.name,
      emoji: str(m['emoji']) ?? base.emoji,
      subtitle: str(m['subtitle']) ?? '${specs.length} specializations',
      backgroundColor: color(m['bgColor'], base.backgroundColor),
      accentColor: color(m['accentColor'], base.accentColor),
      // The card renders bundled assets only for now; anything else falls back.
      backgroundImage: (image != null && image.startsWith('assets/'))
          ? image
          : base.backgroundImage,
      subcategorySpecs: specs,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATIC CATEGORY DATA
// ─────────────────────────────────────────────────────────────────────────────

const Color kSearchPrimary = Color(0xFFA58CE3);
const Color kSearchSecondary = Color(0xFF5B3FA3);
const Color kSearchBackground = Color(0xFFF4F1FB);

const List<WellnessCategory> kAllCategories = [
  WellnessCategory(
    name: 'Physical Fitness',
    emoji: '💪',
    subtitle: '10 specializations',
    backgroundColor: Color(0xFFE9E0FA),
    accentColor: kSearchSecondary,
    backgroundImage: 'assets/images/fitness.png',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Fitness',
          emoji: '🏋️',
          tags: [
            'General Fitness',
            'Personal Trainer',
            'Gym',
            'Fitness Studio',
            'Endurance',
            'Body Toning',
            'Cardio Equipment',
            'Strength Equipment',
            'Personal Training'
          ],
          interestTerm: 'fitness',
          specializationTerm: 'General Fitness'),
      SubcategorySpec(
          displayName: 'Strength Training',
          emoji: '💪',
          tags: [
            'Strength Training',
            'Strength Building',
            'Strength & Conditioning Coach',
            'Strength Equipment'
          ],
          specializationTerm: 'Strength Training'),
      SubcategorySpec(
          displayName: 'Functional Training',
          emoji: '🤸',
          tags: ['Functional Training', 'Group Classes'],
          specializationTerm: 'Functional Training'),
      SubcategorySpec(
          displayName: 'CrossFit',
          emoji: '🔥',
          tags: ['CrossFit'],
          specializationTerm: 'CrossFit'),
      SubcategorySpec(
          displayName: 'Calisthenics',
          emoji: '🏃',
          tags: ['Calisthenics'],
          specializationTerm: 'Calisthenics'),
      SubcategorySpec(
          displayName: 'Bodybuilding',
          emoji: '🦾',
          tags: ['Bodybuilding', 'Muscle Gain'],
          specializationTerm: 'Bodybuilding'),
      SubcategorySpec(
          displayName: 'Posture Correction',
          emoji: '🧍',
          tags: ['Posture Correction'],
          specializationTerm: 'Posture Correction'),
      SubcategorySpec(
          displayName: 'Flexibility & Mobility',
          emoji: '🤸‍♀️',
          tags: [
            'Flexibility & Mobility',
            'Flexibility / Yoga',
            'Mobility Specialist'
          ],
          specializationTerm: 'Flexibility & Mobility'),
      SubcategorySpec(
          displayName: 'Sports Performance',
          emoji: '⚡',
          tags: ['Sports Performance', 'Sports Therapist'],
          specializationTerm: 'Sports Performance'),
      SubcategorySpec(
          displayName: 'Injury Prevention',
          emoji: '🩹',
          tags: ['Injury Prevention', 'Sports Rehab Center'],
          specializationTerm: 'Injury Prevention'),
    ],
  ),
  WellnessCategory(
    name: 'Nutrition & Diet',
    emoji: '🥗',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFF1E8FF),
    accentColor: kSearchPrimary,
    backgroundImage: 'assets/images/diet.png',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Nutrition',
          emoji: '🥗',
          tags: [
            'Nutrition Planning',
            'Nutritionist / Dietician',
            'Diet Clinic',
            'Nutrition Consultation',
            'Supplement Store',
            'Supplements Available'
          ],
          interestTerm: 'nutrition',
          specializationTerm: 'Nutrition Planning'),
      SubcategorySpec(
          displayName: 'Weight Loss',
          emoji: '⚖️',
          tags: ['Weight Loss'],
          specializationTerm: 'Weight Loss'),
      SubcategorySpec(
          displayName: 'Muscle Gain',
          emoji: '💥',
          tags: ['Muscle Gain'],
          specializationTerm: 'Muscle Gain'),
      SubcategorySpec(
          displayName: 'Diet',
          emoji: '🍽️',
          tags: [
            'Nutrition Planning',
            'Nutritionist / Dietician',
            'Diet Clinic',
            'Food and drinks',
            'Café/Restaurant'
          ],
          specializationTerm: 'Nutrition Planning'),
    ],
  ),
  WellnessCategory(
    name: 'Mind & Body Wellness',
    emoji: '🧘',
    subtitle: '5 specializations',
    backgroundColor: Color(0xFFF6F0FF),
    accentColor: kSearchSecondary,
    backgroundImage: 'assets/images/mind.png',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Yoga',
          emoji: '🧘',
          tags: [
            'Yoga & Breathwork',
            'Yoga Instructor',
            'Yoga Studio',
            'Flexibility / Yoga',
            'Yoga Classes'
          ],
          interestTerm: 'yoga',
          specializationTerm: 'Yoga & Breathwork'),
      SubcategorySpec(
          displayName: 'Mental Health',
          emoji: '🧠',
          tags: ['Mental Wellness', 'Stress Management'],
          interestTerm: 'mental_health'),
      SubcategorySpec(
          displayName: 'Stress Management',
          emoji: '😌',
          tags: ['Stress Management'],
          specializationTerm: 'Stress Management'),
      SubcategorySpec(
          displayName: 'Mindfulness / Meditation',
          emoji: '🌿',
          tags: ['Mindfulness / Meditation Coach', 'Mental Wellness'],
          interestTerm: 'mental_health'),
      SubcategorySpec(
          displayName: 'Holistic Wellness',
          emoji: '✨',
          tags: [
            'Holistic Wellness',
            'Spa / Wellness Center',
            'Massage Therapy',
            'Steam / Sauna'
          ],
          specializationTerm: 'Holistic Wellness'),
    ],
  ),
  WellnessCategory(
    name: 'Rehabilitation & Recovery',
    emoji: '🏥',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFEDE4FF),
    accentColor: kSearchPrimary,
    backgroundImage: 'assets/images/recovery.png',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Rehab & Recovery',
          emoji: '🏥',
          tags: [
            'Rehab & Recovery',
            'Physiotherapist',
            'Physiotherapy Clinic',
            'Sports Rehab Center',
            'Physiotherapy',
            'Rehab & Recovery Sessions'
          ],
          specializationTerm: 'Rehab & Recovery'),
      SubcategorySpec(
          displayName: 'Pain Management',
          emoji: '💆',
          tags: ['Pain Management', 'Physiotherapist', 'Massage Therapy'],
          specializationTerm: 'Pain Management'),
      SubcategorySpec(
          displayName: 'Injury Prevention',
          emoji: '🩹',
          tags: ['Injury Prevention', 'Sports Rehab Center'],
          specializationTerm: 'Injury Prevention'),
      SubcategorySpec(
          displayName: 'Posture Correction',
          emoji: '🧍',
          tags: ['Posture Correction'],
          specializationTerm: 'Posture Correction'),
    ],
  ),
  WellnessCategory(
    name: 'Lifestyle & General',
    emoji: '✨',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFF9F4FF),
    accentColor: kSearchSecondary,
    backgroundImage: 'assets/images/lifestyle.png',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Productivity',
          emoji: '📈',
          interestTerm: 'productivity'),
      SubcategorySpec(
          displayName: 'Wellness Coach',
          emoji: '🌟',
          tags: ['Wellness Coach'],
          specializationTerm: 'Wellness Coach'),
      SubcategorySpec(
          displayName: 'Mobility Specialist',
          emoji: '🤸',
          tags: ['Mobility Specialist'],
          specializationTerm: 'Mobility Specialist'),
      SubcategorySpec(
          displayName: 'Personal Trainer',
          emoji: '🏋️',
          tags: ['Personal Trainer', 'Personal Training'],
          specializationTerm: 'Personal Trainer'),
    ],
  ),
  WellnessCategory(
    name: 'Other Interests',
    emoji: '🎯',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFE2D6FF),
    accentColor: kSearchPrimary,
    backgroundImage: 'assets/images/lifestyle.png',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Music', emoji: '🎵', interestTerm: 'music'),
      SubcategorySpec(
          displayName: 'Reading', emoji: '📚', interestTerm: 'reading'),
      SubcategorySpec(
          displayName: 'Travel', emoji: '✈️', interestTerm: 'travel'),
      SubcategorySpec(
          displayName: 'Other',
          emoji: '🎯',
          tags: ['Other'],
          specializationTerm: 'Other'),
    ],
  ),
];
