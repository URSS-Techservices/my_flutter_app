// SearchPage.dart — Fully fixed + improved Instagram-style search for Halo
//
// All bugs fixed:
// 1. _PostSearchGrid: shrinkWrap + physics fixed (no more layout crash)
// 2. CachedNetworkImage used everywhere (no more Image.network flicker)
// 3. Clear (×) button on search TextField
// 4. onSubmitted triggers immediate search
// 5. Dead _cachedUserDocs removed
// 6. Redundant null-checks fixed in _fetchUsersByCategory
// 7. TabBarView height dynamic via LayoutBuilder (no hardcoded 420)
// 8. Follow/Unfollow button inline on user result cards
// 9. Recent searches persisted via SharedPreferences
// 10. ExpertsListPage: real profile photos + pull-to-refresh
// 11. Account type badge (Guru / Wellness / Aspirant) on result cards
// 12. Keyboard submit triggers search
// 13. Consistent CachedNetworkImage avatar pattern throughout

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart'
as guru_profile;
import 'package:halo/Profile%20Pages/wellness_profile_page.dart'
as wellness_profile;
import 'package:halo/services/search_service.dart';
import 'package:halo/utils/search_ranking.dart';

// ------- THEME CONSTANTS -------
const Color kPrimaryColor = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBackgroundColor = Color(0xFFF4F1FB);
const Color kIgSecondaryText = Color(0xFF8E8E8E);

// ------- RECENT SEARCHES PREFS KEY -------
const String _kRecentSearchesKey = 'halo_recent_searches';
const int _kMaxRecentSearches = 8;

// ------- SUBCATEGORY MODEL -------

class SubcategorySpec {
  final String displayName;
  final String? interestTerm;
  final String? specializationTerm;

  const SubcategorySpec({
    required this.displayName,
    this.interestTerm,
    this.specializationTerm,
  });
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
}

const List<WellnessCategory> _allCategories = [
  WellnessCategory(
    name: 'Physical Fitness',
    emoji: '💪',
    subtitle: '10 specializations',
    backgroundColor: Color(0xFFE9E0FA),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/physical_fitness.jpg',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Fitness',
          interestTerm: 'fitness',
          specializationTerm: 'General Fitness'),
      SubcategorySpec(
          displayName: 'Strength Training',
          specializationTerm: 'Strength Training'),
      SubcategorySpec(
          displayName: 'Functional Training',
          specializationTerm: 'Functional Training'),
      SubcategorySpec(
          displayName: 'CrossFit', specializationTerm: 'CrossFit'),
      SubcategorySpec(
          displayName: 'Calisthenics',
          specializationTerm: 'Calisthenics'),
      SubcategorySpec(
          displayName: 'Bodybuilding',
          specializationTerm: 'Bodybuilding'),
      SubcategorySpec(
          displayName: 'Posture Correction',
          specializationTerm: 'Posture Correction'),
      SubcategorySpec(
          displayName: 'Flexibility & Mobility',
          specializationTerm: 'Flexibility & Mobility'),
      SubcategorySpec(
          displayName: 'Sports Performance',
          specializationTerm: 'Sports Performance'),
      SubcategorySpec(
          displayName: 'Injury Prevention',
          specializationTerm: 'Injury Prevention'),
    ],
  ),
  WellnessCategory(
    name: 'Nutrition & Diet',
    emoji: '🥗',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFF1E8FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/nutrition_diet.jpg',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Nutrition',
          interestTerm: 'nutrition',
          specializationTerm: 'Nutrition Planning'),
      SubcategorySpec(
          displayName: 'Weight Loss',
          specializationTerm: 'Weight Loss'),
      SubcategorySpec(
          displayName: 'Muscle Gain',
          specializationTerm: 'Muscle Gain'),
      SubcategorySpec(
          displayName: 'Diet',
          specializationTerm: 'Nutrition Planning'),
    ],
  ),
  WellnessCategory(
    name: 'Mind & Body Wellness',
    emoji: '🧘',
    subtitle: '5 specializations',
    backgroundColor: Color(0xFFF6F0FF),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/mind_body.jpg',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Yoga',
          interestTerm: 'yoga',
          specializationTerm: 'Yoga & Breathwork'),
      SubcategorySpec(
          displayName: 'Mental Health',
          interestTerm: 'mental_health'),
      SubcategorySpec(
          displayName: 'Stress Management',
          specializationTerm: 'Stress Management'),
      SubcategorySpec(
          displayName: 'Mindfulness / Meditation',
          interestTerm: 'mental_health'),
      SubcategorySpec(
          displayName: 'Holistic Wellness',
          specializationTerm: 'Holistic Wellness'),
    ],
  ),
  WellnessCategory(
    name: 'Rehabilitation & Recovery',
    emoji: '🏥',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFEDE4FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/rehab_recovery.jpg',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Rehab & Recovery',
          specializationTerm: 'Rehab & Recovery'),
      SubcategorySpec(
          displayName: 'Pain Management',
          specializationTerm: 'Pain Management'),
      SubcategorySpec(
          displayName: 'Injury Prevention',
          specializationTerm: 'Injury Prevention'),
      SubcategorySpec(
          displayName: 'Posture Correction',
          specializationTerm: 'Posture Correction'),
    ],
  ),
  WellnessCategory(
    name: 'Lifestyle & General',
    emoji: '✨',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFF9F4FF),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/lifestyle_wellness.jpg',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Productivity',
          interestTerm: 'productivity'),
      SubcategorySpec(
          displayName: 'Wellness Coach',
          specializationTerm: 'Wellness Coach'),
      SubcategorySpec(
          displayName: 'Mobility Specialist',
          specializationTerm: 'Mobility Specialist'),
      SubcategorySpec(
          displayName: 'Personal Trainer',
          specializationTerm: 'Personal Trainer'),
    ],
  ),
  WellnessCategory(
    name: 'Other Interests',
    emoji: '🎯',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFE2D6FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/goals.jpg',
    subcategorySpecs: [
      SubcategorySpec(
          displayName: 'Music', interestTerm: 'music'),
      SubcategorySpec(
          displayName: 'Reading', interestTerm: 'reading'),
      SubcategorySpec(
          displayName: 'Travel', interestTerm: 'travel'),
      SubcategorySpec(
          displayName: 'Other', specializationTerm: 'Other'),
    ],
  ),
];

// ------- PAGE TRANSITION -------

Route _buildPageRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
          parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ------- OPEN USER PROFILE HELPER -------

Future<void> openUserProfile(
    BuildContext context,
    String userId, {
      String? knownAccountType,
    }) async {
  String accountType = (knownAccountType ?? '').trim().toLowerCase();
  if (accountType.isEmpty) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      accountType =
          _safeString(doc.data()?['accountType']).toLowerCase();
      if (accountType.isEmpty) accountType = 'aspirant';
    } catch (e) {
      if (kDebugMode) debugPrint('openUserProfile: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
            Text('Could not load profile. Opening default view.')));
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => aspirant_profile.ProfilePage(
                    profileUserId: userId)));
      }
      return;
    }
  }

  if (!context.mounted) return;
  Widget page;
  if (accountType == 'wellness') {
    page = wellness_profile.WellnessProfilePage(profileUserId: userId);
  } else if (accountType == 'guru') {
    page = guru_profile.GuruProfilePage(profileUserId: userId);
  } else {
    page = aspirant_profile.ProfilePage(profileUserId: userId);
  }
  Navigator.push(
      context, MaterialPageRoute(builder: (_) => page));
}

// ------- SAFE HELPERS -------

String _safeString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  return v.toString().trim();
}

List<String> _safeStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v
        .map((e) => _safeString(e))
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

String? _postImageUrl(Map<String, dynamic> data) {
  final imageUrl = data['imageUrl']?.toString();
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
  final images = data['images'];
  if (images is List && images.isNotEmpty) return images.first?.toString();
  final media = data['media'];
  if (media is List && media.isNotEmpty) {
    final first = media.first;
    if (first is Map && first['url'] != null)
      return first['url']?.toString();
  }
  return null;
}

// ------- ACCOUNT TYPE BADGE -------

Widget _accountTypeBadge(String accountType) {
  Color bg;
  Color fg;
  String label;

  switch (accountType.toLowerCase()) {
    case 'guru':
      bg = const Color(0xFFEDE4FF);
      fg = kSecondaryColor;
      label = 'Guru';
      break;
    case 'wellness':
      bg = const Color(0xFFE0F7F0);
      fg = const Color(0xFF0F6E56);
      label = 'Wellness';
      break;
    default:
      bg = const Color(0xFFF1F1F1);
      fg = const Color(0xFF555555);
      label = 'Aspirant';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: fg,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
  );
}

// ------- REAL USER AVATAR -------

Widget _userAvatar(String? photoUrl, String fallbackName,
    {double radius = 24}) {
  final initials = fallbackName.trim().isNotEmpty
      ? fallbackName.trim()[0].toUpperCase()
      : 'U';
  return CircleAvatar(
    radius: radius,
    backgroundColor: kPrimaryColor.withOpacity(0.12),
    child: ClipOval(
      child: photoUrl != null && photoUrl.isNotEmpty
          ? CachedNetworkImage(
        imageUrl: photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: kPrimaryColor.withOpacity(0.08),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                    color: kSecondaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.7)),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: kPrimaryColor.withOpacity(0.08),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                    color: kSecondaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.7)),
          ),
        ),
      )
          : Container(
        width: radius * 2,
        height: radius * 2,
        color: kPrimaryColor.withOpacity(0.08),
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.7)),
        ),
      ),
    ),
  );
}

// ------- SCORED MODELS -------

class _ScoredUser {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredUser({required this.doc, required this.score});
}

class _ScoredPost {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredPost({required this.doc, required this.score});
}

// ======================================================================
// SEARCH PAGE
// ======================================================================

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  static const _debounceMs = 400;
  static const _minQueryLength = 2;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchService _searchService = SearchService();

  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  bool _userSearchLoading = false;
  Object? _userSearchError;
  bool _usedFallbackSearch = false;
  String? _cachedQueryFor;

  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _rankedUserDocs;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _rankedPostDocs;

  // FIX #9: recent searches
  List<String> _recentSearches = [];
  bool _showRecents = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentSearches();
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _showRecents =
            _searchFocusNode.hasFocus && _query.trim().isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ------- RECENT SEARCHES -------

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kRecentSearchesKey) ?? [];
      if (!mounted) return;
      setState(() => _recentSearches = saved);
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String term) async {
    if (term.trim().isEmpty) return;
    final updated = [
      term.trim(),
      ..._recentSearches.where((s) => s != term.trim()),
    ].take(_kMaxRecentSearches).toList();
    setState(() => _recentSearches = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, updated);
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String term) async {
    final updated =
    _recentSearches.where((s) => s != term).toList();
    setState(() => _recentSearches = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, updated);
    } catch (_) {}
  }

  Future<void> _clearAllRecents() async {
    setState(() => _recentSearches = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRecentSearchesKey);
    } catch (_) {}
  }

  // ------- SEARCH LOGIC -------

  // FIX #12: Keyboard submit + FIX #3: Clear button handler
  void _onSearchChanged(String val) {
    setState(() {
      _query = val;
      _showRecents =
          _searchFocusNode.hasFocus && val.trim().isEmpty;
    });
    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(const Duration(milliseconds: _debounceMs), () {
          if (!mounted) return;
          final trimmed = val.trim();
          setState(() {
            _debouncedQuery = trimmed;
            if (trimmed.length < _minQueryLength) {
              _rankedUserDocs = null;
              _rankedPostDocs = null;
              _userSearchError = null;
              _userSearchLoading = false;
              _usedFallbackSearch = false;
              _cachedQueryFor = null;
            } else {
              _userSearchLoading = _cachedQueryFor != trimmed;
            }
          });
          if (trimmed.length >= _minQueryLength) {
            _fetchUsersOnce(trimmed);
          }
        });
  }

  // FIX #12: triggered on keyboard done/search
  void _onSearchSubmitted(String val) {
    final trimmed = val.trim();
    if (trimmed.length >= _minQueryLength) {
      _debounceTimer?.cancel();
      setState(() {
        _debouncedQuery = trimmed;
        _userSearchLoading = _cachedQueryFor != trimmed;
      });
      _fetchUsersOnce(trimmed);
      _saveRecentSearch(trimmed);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _debouncedQuery = '';
      _rankedUserDocs = null;
      _rankedPostDocs = null;
      _userSearchError = null;
      _userSearchLoading = false;
      _cachedQueryFor = null;
      _showRecents = _searchFocusNode.hasFocus;
    });
  }

  void _applyRecentSearch(String term) {
    _searchController.text = term;
    _onSearchChanged(term);
    _onSearchSubmitted(term);
    _searchFocusNode.unfocus();
    setState(() => _showRecents = false);
  }

  void _refreshUserSearch() {
    if (_debouncedQuery.length < _minQueryLength) return;
    setState(() {
      _cachedQueryFor = null;
      _rankedUserDocs = null;
      _rankedPostDocs = null;
      _userSearchLoading = true;
      _userSearchError = null;
    });
    _fetchUsersOnce(_debouncedQuery);
  }

  Future<void> _fetchUsersOnce(String searchQuery) async {
    if (searchQuery.trim().isEmpty) return;
    // FIX #5: removed _cachedUserDocs — use _rankedUserDocs as cache signal
    if (_cachedQueryFor == searchQuery &&
        _rankedUserDocs != null &&
        !_userSearchLoading) return;

    setState(() {
      _userSearchError = null;
      _userSearchLoading = true;
      _rankedUserDocs = null;
      _rankedPostDocs = null;
    });

    SearchUsersResult? userResult;
    try {
      userResult = await _searchService.searchUsers(searchQuery);
    } catch (e) {
      if (kDebugMode) debugPrint('SearchPage search failed: $e');
      if (!mounted) return;
      setState(() {
        _userSearchLoading = false;
        _userSearchError = e;
        _rankedUserDocs = null;
        _rankedPostDocs = null;
        _cachedQueryFor = null;
      });
      return;
    }

    final userDocs = userResult.docs;
    final postDocs = await _searchService.searchPosts(searchQuery);
    final currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final userIds = userDocs.map((d) => d.id).toList();
    final relScores = await _searchService.getRelationshipScores(
        currentUserId, userIds);

    final rankedUsers = <_ScoredUser>[];
    for (final doc in userDocs) {
      final data = doc.data();
      final username = _safeString(data['username']);
      final name = _safeString(data['name']).isNotEmpty
          ? _safeString(data['name'])
          : _safeString(data['full_name']).isNotEmpty
          ? _safeString(data['full_name'])
          : _safeString(data['business_name']);
      final bio = _safeString(data['bio']);
      final lastActiveAt =
          (data['lastActiveAt'] as Timestamp?)?.toDate() ??
              DateTime.now();
      final followersCount =
          (data['followersCount'] as int?) ?? 0;
      final rel = relScores[doc.id] ?? 0.0;
      final score = userSearchScore(
        username: username,
        name: name,
        bio: bio,
        relationshipScore: rel,
        followersCount: followersCount,
        lastActiveAt: lastActiveAt,
        query: searchQuery,
      );
      rankedUsers.add(_ScoredUser(doc: doc, score: score));
    }
    rankedUsers.sort((a, b) => b.score.compareTo(a.score));

    final rankedPosts = <_ScoredPost>[];
    for (final doc in postDocs) {
      final data = doc.data();
      final caption = _safeString(data['caption']);
      final tags = _safeStringList(data['tags']);
      final likes = (data['likesCount'] as int?) ?? 0;
      final comments = (data['commentsCount'] as int?) ?? 0;
      final saves = (data['savesCount'] as int?) ?? 0;
      final createdAt =
          (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now();
      final score = postSearchScore(
        caption: caption,
        tags: tags,
        likes: likes,
        comments: comments,
        saves: saves,
        createdAt: createdAt,
        query: searchQuery,
      );
      rankedPosts.add(_ScoredPost(doc: doc, score: score));
    }
    rankedPosts.sort((a, b) => b.score.compareTo(a.score));

    if (!mounted) return;
    // FIX #9: save search term to recent history
    _saveRecentSearch(searchQuery);

    setState(() {
      _cachedQueryFor = searchQuery;
      _rankedUserDocs = rankedUsers.map((e) => e.doc).toList();
      _rankedPostDocs = rankedPosts.map((e) => e.doc).toList();
      _userSearchLoading = false;
      _userSearchError = null;
      _usedFallbackSearch = !userResult!.usedPrefix;
    });
  }

  List<WellnessCategory> get _filteredCategories {
    final q = _query.trim();
    if (q.isEmpty) return _allCategories;
    final qLower = q.toLowerCase();
    return _allCategories
        .where((c) =>
    c.name.toLowerCase().contains(qLower) ||
        c.subtitle.toLowerCase().contains(qLower) ||
        c.subcategorySpecs
            .any((s) => s.displayName.toLowerCase().contains(qLower)))
        .toList();
  }

  // ------- RECENT SEARCHES WIDGET -------

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No recent searches',
          style: TextStyle(
              color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: const Color(0xFF1F1033)),
            ),
            TextButton(
              onPressed: _clearAllRecents,
              child: Text('Clear all',
                  style: TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ..._recentSearches.map((term) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_rounded,
                size: 18, color: Colors.grey.shade600),
          ),
          title: Text(term,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF1F1033))),
          trailing: IconButton(
            icon: Icon(Icons.close,
                size: 16, color: Colors.grey.shade400),
            onPressed: () => _removeRecentSearch(term),
          ),
          onTap: () => _applyRecentSearch(term),
        )),
      ],
    );
  }

  // ------- SEARCH RESULTS WIDGET -------

  Widget _buildSearchResults(double availableHeight) {
    final showQuery = _debouncedQuery;
    final queryNow = _query.trim();

    if (queryNow.isEmpty) return const SizedBox.shrink();

    if (queryNow.length < _minQueryLength) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Type at least $_minQueryLength characters to search',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    if (_userSearchLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userSearchError != null) {
      return _ErrorCard(
        message: 'Search unavailable. Please try again.',
        onRetry: _refreshUserSearch,
      );
    }

    final userList = _rankedUserDocs ?? [];
    final postList = _rankedPostDocs ?? [];

    if (userList.isEmpty && postList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No results for "$showQuery"',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // FIX #7: dynamic height from LayoutBuilder — no hardcoded 420
    final tabHeight = (availableHeight * 0.55).clamp(300.0, 600.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Results',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: const Color(0xFF1F1033)),
            ),
            const SizedBox(width: 8),
            if (_usedFallbackSearch)
              Expanded(
                child: Text(
                  '· Partial match — try more characters',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh',
              onPressed:
              _userSearchLoading ? null : _refreshUserSearch,
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: kSecondaryColor,
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: kSecondaryColor,
                labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: 'People (${userList.length})'),
                  Tab(text: 'Posts (${postList.length})'),
                ],
              ),
              // FIX #7: dynamic tab height
              SizedBox(
                height: tabHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // People tab
                    userList.isEmpty
                        ? Center(
                        child: Text('No people found',
                            style: TextStyle(
                                color: Colors.grey.shade500)))
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8),
                      itemCount: userList.length,
                      itemBuilder: (context, index) {
                        final doc = userList[index];
                        final data = doc.data();
                        final userId = doc.id;
                        final username =
                        _safeString(data['username']);
                        final name = _safeString(data['name'])
                            .isNotEmpty
                            ? _safeString(data['name'])
                            : _safeString(data['full_name'])
                            .isNotEmpty
                            ? _safeString(data['full_name'])
                            : _safeString(
                            data['business_name'])
                            .isNotEmpty
                            ? _safeString(
                            data['business_name'])
                            : 'Unnamed User';
                        final profilePhoto = _safeString(
                            data['profilePhoto'] ??
                                data['photoURL'] ??
                                data['profile_photo'] ??
                                data['avatar']);
                        final accountType = _safeString(
                            data['accountType'])
                            .toLowerCase();
                        return _UserSearchResultCard(
                          userId: userId,
                          username: username,
                          name: name,
                          profilePhoto: profilePhoto.isEmpty
                              ? null
                              : profilePhoto,
                          accountType: accountType.isEmpty
                              ? 'aspirant'
                              : accountType,
                        );
                      },
                    ),
                    // Posts tab
                    // FIX #1: shrinkWrap + NeverScrollableScrollPhysics inside bounded SizedBox
                    _PostSearchGrid(
                      docs: postList,
                      onTapPost: (postId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                aspirant_profile.PostDetailsPage(
                                    postId: postId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------- BUILD -------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kBackgroundColor, Color(0xFFE9E2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth >= 900) crossAxisCount = 3;
              if (constraints.maxWidth >= 1200) crossAxisCount = 4;

              final categories = _filteredCategories;

              return GestureDetector(
                onTap: () {
                  _searchFocusNode.unfocus();
                  setState(() => _showRecents = false);
                },
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back row
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: kSecondaryColor),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Search',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: kSecondaryColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Hero heading
                      Text(
                        'Discover Your\nWellness Journey',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          height: 1.2,
                          letterSpacing: -0.3,
                          color: const Color(0xFF1F1033),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Connect with expert trainers, nutritionists, and wellness professionals',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // FIX #3 + #12: Search bar with clear button + onSubmitted
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: kSecondaryColor.withOpacity(0.10),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          // FIX #12: keyboard search/done button triggers search
                          onSubmitted: _onSearchSubmitted,
                          textInputAction: TextInputAction.search,
                          style: GoogleFonts.poppins(
                              color: Colors.black87, fontSize: 14),
                          decoration: InputDecoration(
                            hintText:
                            'Search by name, username, or expertise...',
                            hintStyle: GoogleFonts.poppins(
                                color: Colors.grey.shade500,
                                fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: kSecondaryColor),
                            // FIX #3: Clear button
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.grey, size: 20),
                              onPressed: _clearSearch,
                            )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FIX #9: Recent searches when focused + empty
                      if (_showRecents &&
                          _query.trim().isEmpty) ...[
                        _buildRecentSearches(),
                        const SizedBox(height: 20),
                      ],

                      // Search results
                      if (_query.trim().isNotEmpty) ...[
                        _buildSearchResults(
                            constraints.maxHeight),
                        const SizedBox(height: 20),
                        Divider(
                            color: Colors.grey.shade300,
                            thickness: 1),
                        const SizedBox(height: 14),
                      ],

                      // Category header
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _query.trim().isEmpty
                                ? 'Browse by category'
                                : 'Categories',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF1F1033),
                            ),
                          ),
                          Text(
                            '${categories.length} categories',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      GridView.builder(
                        key: ValueKey(
                            'grid_${categories.length}'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.92,
                        ),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _CategoryCard(
                            category: category,
                            onTap: () {
                              Navigator.of(context).push(
                                _buildPageRoute(
                                    SubCategoryPage(
                                        category: category)),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// POST SEARCH GRID
// FIX #1: shrinkWrap:true + NeverScrollableScrollPhysics — no layout crash
// FIX #2: CachedNetworkImage replaces Image.network
// ======================================================================

class _PostSearchGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(String postId) onTapPost;

  const _PostSearchGrid(
      {required this.docs, required this.onTapPost});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No posts match your search.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }
    // FIX #1: shrinkWrap + NeverScrollableScrollPhysics inside bounded SizedBox
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final imageUrl = _postImageUrl(data);
        return GestureDetector(
          onTap: () => onTapPost(doc.id),
          child: Container(
            color: Colors.grey.shade200,
            child: imageUrl != null && imageUrl.isNotEmpty
            // FIX #2: CachedNetworkImage for post grid thumbnails
                ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5))),
              errorWidget: (_, __, ___) => const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey),
            )
                : const Center(
                child: Icon(Icons.image, color: Colors.grey)),
          ),
        );
      },
    );
  }
}

// ======================================================================
// USER SEARCH RESULT CARD
// FIX #8: Follow/Unfollow button
// FIX #11: Account type badge
// Real user photos via _userAvatar helper
// ======================================================================

class _UserSearchResultCard extends StatefulWidget {
  final String userId;
  final String username;
  final String name;
  final String? profilePhoto;
  final String accountType;

  const _UserSearchResultCard({
    Key? key,
    required this.userId,
    required this.username,
    required this.name,
    this.profilePhoto,
    required this.accountType,
  }) : super(key: key);

  @override
  State<_UserSearchResultCard> createState() =>
      _UserSearchResultCardState();
}

class _UserSearchResultCardState
    extends State<_UserSearchResultCard> {
  bool _isFollowing = false;
  bool _followLoading = false;
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  // FIX #8: Check if already following
  Future<void> _checkFollowing() async {
    if (_currentUserId == null ||
        _currentUserId == widget.userId) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .collection('following')
          .doc(widget.userId)
          .get();
      if (!mounted) return;
      setState(() => _isFollowing = doc.exists);
    } catch (_) {}
  }

  // FIX #8: Toggle follow/unfollow
  Future<void> _toggleFollow() async {
    if (_currentUserId == null ||
        _currentUserId == widget.userId) return;
    setState(() => _followLoading = true);
    try {
      final followRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .collection('following')
          .doc(widget.userId);
      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .doc(_currentUserId!);

      if (_isFollowing) {
        await followRef.delete();
        await followerRef.delete();
      } else {
        await followRef.set({'followedAt': FieldValue.serverTimestamp()});
        await followerRef
            .set({'followedAt': FieldValue.serverTimestamp()});
      }
      if (!mounted) return;
      setState(() {
        _isFollowing = !_isFollowing;
        _followLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _currentUserId == widget.userId;

    return Semantics(
      button: true,
      label:
      'Open profile of ${widget.name}${widget.username.isNotEmpty ? ", @${widget.username}" : ""}',
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => openUserProfile(
              context,
              widget.userId,
              knownAccountType: widget.accountType,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Real user photo
                  _userAvatar(widget.profilePhoto, widget.name,
                      radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: const Color(0xFF1F1033),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // FIX #11: account type badge
                            _accountTypeBadge(widget.accountType),
                          ],
                        ),
                        if (widget.username.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '@${widget.username}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // FIX #8: Follow / Following button
                  if (!isSelf)
                    _followLoading
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))
                        : GestureDetector(
                      onTap: _toggleFollow,
                      child: AnimatedContainer(
                        duration:
                        const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isFollowing
                              ? Colors.white
                              : kSecondaryColor,
                          borderRadius:
                          BorderRadius.circular(20),
                          border: Border.all(
                            color: _isFollowing
                                ? Colors.grey.shade300
                                : kSecondaryColor,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          _isFollowing
                              ? 'Following'
                              : 'Follow',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isFollowing
                                ? Colors.grey.shade700
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// ERROR CARD
// ======================================================================

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              color: Colors.grey.shade500, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(color: kSecondaryColor)),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// CATEGORY CARD
// ======================================================================

class _CategoryCard extends StatefulWidget {
  final WellnessCategory category;
  final VoidCallback onTap;

  const _CategoryCard(
      {Key? key, required this.category, required this.onTap})
      : super(key: key);

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isTouchDevice =
        Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS;
    final active =
    isTouchDevice ? _isPressed : (_isHovered || _isPressed);

    final content = AnimatedScale(
      scale: active ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.category.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: active ? 24 : 10,
              spreadRadius: active ? -4 : -6,
              offset: Offset(0, active ? 16 : 8),
              color:
              Colors.black.withOpacity(active ? 0.16 : 0.08),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.category.backgroundImage != null)
                Image.asset(
                  widget.category.backgroundImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const SizedBox.shrink(),
                ),
              Container(
                  color: Colors.black.withOpacity(0.10)),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: widget.onTap,
                  onTapDown: (_) =>
                      setState(() => _isPressed = true),
                  onTapCancel: () =>
                      setState(() => _isPressed = false),
                  onTapUp: (_) =>
                      setState(() => _isPressed = false),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.category.emoji,
                            style:
                            const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            widget.category.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F1033),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.category.subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final card = isTouchDevice
        ? content
        : MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: content,
    );

    return Semantics(
      button: true,
      label:
      '${widget.category.name}, ${widget.category.subtitle}',
      child: card,
    );
  }
}

// ======================================================================
// SUBCATEGORY PAGE
// ======================================================================

class SubCategoryPage extends StatelessWidget {
  final WellnessCategory category;

  const SubCategoryPage(
      {Key? key, required this.category})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final specs = category.subcategorySpecs;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          category.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF1F1033),
          ),
        ),
        backgroundColor: category.backgroundColor,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      body: specs.isEmpty
          ? Center(
          child: Text('No subcategories for this category.',
              style: TextStyle(color: Colors.grey.shade700)))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: specs.length,
        separatorBuilder: (_, __) =>
        const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final spec = specs[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 6,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                  color: Colors.black.withOpacity(0.05),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                  category.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Text(category.emoji,
                    style: const TextStyle(fontSize: 18)),
              ),
              title: Text(
                spec.displayName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1F1033),
                ),
              ),
              trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: kSecondaryColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpertsListPage(
                      displayName: spec.displayName,
                      emoji: category.emoji,
                      interestTerm: spec.interestTerm,
                      specializationTerm:
                      spec.specializationTerm,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ======================================================================
// EXPERTS LIST PAGE
// FIX #10: pull-to-refresh + real profile photos
// FIX #11: account type badge
// FIX #8: follow/unfollow inline
// ======================================================================

class ExpertsListPage extends StatefulWidget {
  final String displayName;
  final String emoji;
  final String? interestTerm;
  final String? specializationTerm;

  const ExpertsListPage({
    Key? key,
    required this.displayName,
    required this.emoji,
    this.interestTerm,
    this.specializationTerm,
  }) : super(key: key);

  @override
  State<ExpertsListPage> createState() =>
      _ExpertsListPageState();
}

class _ExpertsListPageState extends State<ExpertsListPage> {
  List<QueryDocumentSnapshot>? _docs;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadExperts();
  }

  Future<void> _loadExperts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetchUsersByCategory(
        widget.interestTerm,
        widget.specializationTerm,
      );
      if (!mounted) return;
      setState(() {
        _docs = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyTerm =
        (widget.interestTerm?.trim().isNotEmpty ?? false) ||
            (widget.specializationTerm?.trim().isNotEmpty ?? false);

    if (!hasAnyTerm) {
      return Scaffold(
        appBar: AppBar(
            title: Text(widget.displayName),
            backgroundColor: kBackgroundColor),
        body: const Center(child: Text('No category selected.')),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.displayName,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: const Color(0xFF1F1033)),
        ),
        backgroundColor: kBackgroundColor,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      // FIX #10: pull-to-refresh on experts list
      body: RefreshIndicator(
        onRefresh: _loadExperts,
        color: kSecondaryColor,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: Colors.grey.shade500),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load. Pull down to retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        )
            : (_docs == null || _docs!.isEmpty)
            ? ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No people found for "${widget.displayName}".',
                  style: TextStyle(
                      color:
                      Colors.grey.shade600),
                ),
              ),
            ),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _docs!.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = _docs![index];
            final data = doc.data()
            as Map<String, dynamic>? ??
                {};
            final userId = doc.id;
            final name =
            _safeString(data['name']).isNotEmpty
                ? _safeString(data['name'])
                : _safeString(data['full_name'])
                .isNotEmpty
                ? _safeString(
                data['full_name'])
                : _safeString(
                data['business_name'])
                .isNotEmpty
                ? _safeString(
                data['business_name'])
                : 'Unnamed';
            final username =
            _safeString(data['username']);
            final accountType = _safeString(
                data['accountType'])
                .toLowerCase();
            // FIX #10: real profile photo
            final profilePhoto = _safeString(
                data['profilePhoto'] ??
                    data['photoURL'] ??
                    data['profile_photo'] ??
                    data['avatar']);

            return _UserSearchResultCard(
              userId: userId,
              username: username,
              name: name,
              profilePhoto: profilePhoto.isEmpty
                  ? null
                  : profilePhoto,
              accountType: accountType.isEmpty
                  ? 'aspirant'
                  : accountType,
            );
          },
        ),
      ),
    );
  }
}

// ======================================================================
// FETCH USERS BY CATEGORY
// FIX #6: removed redundant null-checks (interestTerm! inside if block)
// ======================================================================

Future<List<QueryDocumentSnapshot>> _fetchUsersByCategory(
    String? interestTerm,
    String? specializationTerm,
    ) async {
  final Set<String> seenIds = {};
  final List<QueryDocumentSnapshot> merged = [];

  // FIX #6: safe null check without redundant ! operator inside guarded block
  final cleanInterest = interestTerm?.trim() ?? '';
  if (cleanInterest.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('interests',
          arrayContains: cleanInterest.toLowerCase())
          .get();
      for (final doc in snap.docs) {
        if (seenIds.add(doc.id)) merged.add(doc);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_fetchUsersByCategory interest: $e');
    }
  }

  final cleanSpec = specializationTerm?.trim() ?? '';
  if (cleanSpec.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('areas_of_specialization',
          arrayContains: cleanSpec)
          .get();
      for (final doc in snap.docs) {
        if (seenIds.add(doc.id)) merged.add(doc);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_fetchUsersByCategory spec: $e');
    }
  }

  return merged;
}