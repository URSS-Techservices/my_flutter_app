// HomePage.dart — Instagram-style (2025–2026) feed for Halo
//
// Implemented improvements:
// 1. Flatter post cards: white, minimal shadow, ~10px radius
// 2. Double-tap → animated heart overlay on post media (scale + fade, ~700ms, elastic)
// 3. Like button: red when liked (#ED4956), Icons.favorite / favorite_border
// 4. Natural like count: "Be the first to like this" / "Liked by you" / "Liked by you and X others" / "Liked by X people"
// 5. Pull-to-refresh (RefreshIndicator) on main feed
// 6. Segmented control at top: "For you" | "Following" (UI only — same feed for both)
// 7. Stories ring gradient: #F56040 → #F77737 → #E1306C → #C13584
// 8. CachedNetworkImage for profile photos and post images
// 9. Instagram-style colors: #262626, #8E8E8E, #ED4956, white
// 10. Typography/spacing: larger usernames/captions, padding, icon sizes ~26–28px
//
// Trade-off: For you/Following tabs do not change the query (UI only).

import 'package:halo/Bottom%20Pages/AddPostPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/chat/chat_list_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:halo/Profile%20Pages/wellness_profile_page.dart'
as wellness_profile;
import 'package:halo/interest_selection_page.dart';
import 'package:halo/services/story_service.dart';
import 'package:halo/models/story_model.dart';
import 'package:halo/utils/story_utils.dart';
import 'package:halo/story/story_viewer_page.dart';
import 'package:halo/story/story_upload_sheet.dart';

import 'package:halo/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart'
as guru_profile;

import 'dart:async';
import 'package:halo/services/feed_service.dart';
import 'package:halo/services/save_service.dart';
import 'package:halo/Bottom%20Pages/SettingsPage.dart';
import 'package:halo/Bottom%20Pages/saved_posts_page.dart';
import 'package:halo/Bottom%20Pages/NotificationPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/widgets/save_button.dart';

import 'NotificationPage.dart';
import 'SearchPage.dart';
import 'ExplorePage.dart';

// ---- THEME COLORS ----
const Color kPrimaryColor = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBackgroundColor = Color(0xFFF4F1FB);

// Instagram-style (2025) feed colors
const Color kIgPrimaryText = Color(0xFF262626);
const Color kIgSecondaryText = Color(0xFF8E8E8E);
const Color kIgLikeRed = Color(0xFFED4956);
const Color kIgPostBackground = Colors.white;
/// Home feed stability switch:
/// Inline autoplay in a long, shrink-wrapped feed can spawn too many decoders
/// on MTK devices (pipelineFull / resources:6). Keep feed videos as lightweight
/// thumbnails and play in the dedicated reel viewer instead.
const bool kEnableInlineFeedVideoAutoplay = false;

/// Reads profile photo URL from user document (tries profilePhoto, photoURL, profile_photo, avatar).
String _profilePhotoUrlFromUser(Map<String, dynamic>? data) {
  if (data == null) return '';
  final v = data['profilePhoto'] ?? data['photoURL'] ?? data['profile_photo'] ?? data['avatar'];
  if (v == null) return '';
  final s = v.toString().trim();
  return s.isEmpty ? '' : s;
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  final ScrollController _feedScrollController = ScrollController();
  final FeedService _feedService = FeedService();
  bool _promptedLocation = false;
  List<String> _interests = const [];
  int _feedTabIndex = 0;
  String _contentPreference = '';
  int _navIndex = 0;

  // Single shared saved-posts map
  Map<String, dynamic> _savedPostsMap = const {};
  StreamSubscription<Map<String, dynamic>>? _savedSub;

  // Paginated feed state — replaces live stream
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _feedDocs = const [];
  bool _feedLoading = false;
  bool _feedError = false;
  bool _feedHasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _feedLastDoc;

  // Tab pages created once — never recreated on setState.
  // Recreating them on every build causes InheritedWidget dependent assertion failures.
  late final Widget _searchPage;
  late final Widget _explorePage;
  late final Widget _notificationPage;
  late final Widget _profileTab;

  @override
  void initState() {
    super.initState();
    _searchPage     = SearchPage();
    _explorePage    = ExplorePage();
    _notificationPage = NotificationPage();
    _profileTab     = const _ProfileTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForLocation();
    });
    _loadInterests();
    _initSavedPosts();
    _loadFeed();
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_feedLoading) return;
    setState(() { _feedLoading = true; _feedError = false; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final result = await _feedService.getRankedFeedPage(
        currentUserId: uid,
        userPreference: _contentPreference,
        limit: 20,
        startAfterDoc: refresh ? null : _feedLastDoc,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _feedDocs = result.docs;
        } else {
          _feedDocs = [..._feedDocs, ...result.docs];
        }
        _feedLastDoc = result.lastDoc;
        _feedHasMore = result.hasMore;
        _feedLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _feedLoading = false; _feedError = true; });
    }
  }

  void _initSavedPosts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _savedSub = SaveService().savedPostsStream(uid).listen((map) {
      if (mounted) setState(() => _savedPostsMap = map);
    });
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    _feedScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInterests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interests = prefs.getStringList('user_interests') ?? const [];
      if (!mounted) return;
      setState(() {
        _interests = interests;
      });
    } catch (_) {}
  }

  Future<void> _maybePromptForLocation() async {
    if (_promptedLocation) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool('location_prompt_shown') ?? false;
    if (alreadyRequested) return;

    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      await prefs.setBool('location_prompt_shown', true);
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Allow Location Access'),
          content: const Text(
              'Halo uses your location to enhance discovery and local features.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final result = await Permission.locationWhenInUse.request();
                if (!mounted) return;
                if (result.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Location permission granted')),
                  );
                  await prefs.setBool('location_prompt_shown', true);
                } else if (result.isPermanentlyDenied) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Location permission permanently denied. Open settings to enable.'),
                      action: SnackBarAction(
                        label: 'Settings',
                        onPressed: openAppSettings,
                      ),
                    ),
                  );
                  await prefs.setBool('location_prompt_shown', true);
                }
              },
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    await prefs.setBool('location_prompt_shown', true);
  }

  Widget _buildFeedBody(TextTheme textTheme) {
    // Show skeleton shimmer on initial load
    if (_feedLoading && _feedDocs.isEmpty) {
      return Column(
        children: List.generate(3, (_) => const _PostSkeleton()),
      );
    }

    if (_feedError && _feedDocs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Could not load posts',
                style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadFeed(refresh: true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kSecondaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // Apply interest filter
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = _feedDocs;
    if (_interests.isNotEmpty) {
      filtered = _feedDocs.where((d) {
        final data = d.data();
        final accountType = (data['accountType'] ?? '').toString().toLowerCase();
        if (accountType == 'guru') return true;
        final tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (tags.isEmpty) return true;
        return tags.any((t) => _interests.contains(t));
      }).toList();
    }

    if (filtered.isEmpty && !_feedLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No posts yet', style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('Follow more people or add your first post.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    final videoDocs = filtered.where((d) {
      final m = (d.data()['media'] as List?)?.cast<dynamic>() ?? [];
      return m.any((item) => (Map<String, dynamic>.from(item as Map)['type'] ?? '') == 'video');
    }).toList(growable: false);

    return Column(
      children: [
        // Posts
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            return _PostCard(
              key: ValueKey(doc.id),
              postId: doc.id,
              data: doc.data(),
              savedPostsMap: _savedPostsMap,
              allVideoDocs: videoDocs,
            );
          },
        ),
        // Load more button / loading indicator
        if (_feedHasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _feedLoading
                ? const CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)
                : TextButton(
                    onPressed: _loadFeed,
                    child: const Text('Load more',
                        style: TextStyle(color: kSecondaryColor, fontWeight: FontWeight.w600)),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text("You're all caught up!",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
      ],
    );
  }

  void _onMenuAction(_HaloMenuAction action) {
    switch (action) {
      case _HaloMenuAction.home:
        // Scroll to top and refresh
        _feedScrollController.animateTo(0,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        Future.delayed(const Duration(milliseconds: 450),
            () => _refreshKey.currentState?.show());
        setState(() => _navIndex = 0);
        return;

      case _HaloMenuAction.feed:
        // Switch to Explore tab (index 2)
        setState(() => _navIndex = 2);
        return;

      case _HaloMenuAction.premium:
        _showComingSoonSheet('Premium Content & Features',
            'Unlock exclusive content, badges, and features.\nComing very soon!',
            Icons.star_rounded);
        return;

      case _HaloMenuAction.wellness:
        // Switch to Explore and filter to wellness content
        setState(() => _navIndex = 2);
        return;

      case _HaloMenuAction.challenges:
        _showComingSoonSheet('Challenges',
            'Daily fitness and wellness challenges with leaderboards.\nComing soon!',
            Icons.emoji_events_rounded);
        return;

      case _HaloMenuAction.profileSettings:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => SettingsPage()));
        return;

      case _HaloMenuAction.events:
        _showComingSoonSheet('Events',
            'Local and online wellness events near you.\nComing soon!',
            Icons.event_rounded);
        return;

      case _HaloMenuAction.analytics:
        _openAnalytics();
        return;

      case _HaloMenuAction.savedPosts:
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => SavedPostsPage()));
        return;

      case _HaloMenuAction.gurus:
        // Navigate to explore with a search for gurus
        setState(() => _navIndex = 2);
        return;

      case _HaloMenuAction.logout:
        _confirmLogout();
        return;

      case _HaloMenuAction.email:
        launchUrl(Uri.parse('mailto:support@halo.app'),
            mode: LaunchMode.externalApplication);
        return;

      case _HaloMenuAction.share:
        _shareApp();
        return;

      case _HaloMenuAction.customerCare:
        _showCustomerCare();
        return;
    }
  }

  Future<void> _openAnalytics() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final accountType = doc.data()?['accountType']?.toString().toLowerCase() ?? 'aspirant';
      if (!mounted) return;
      if (accountType == 'guru') {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => guru_profile.GuruProfilePage(profileUserId: uid)));
      } else if (accountType == 'wellness') {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => wellness_profile.WellnessProfilePage(profileUserId: uid)));
      } else {
        _showComingSoonSheet('Analytics',
            'Post performance insights and audience analytics.\nComing soon!',
            Icons.bar_chart_rounded);
      }
    } catch (_) {}
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out of Halo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Log out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Share Halo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Invite your friends to join Halo — your wellness community.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E8E))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share App Link'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B3FA3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  Navigator.pop(context);
                  // Share deep link — replace with actual app store URL when published
                  launchUrl(
                    Uri.parse('https://halo.app'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCustomerCare() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Customer Care',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _CareOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@halo.app',
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('mailto:support@halo.app'),
                    mode: LaunchMode.externalApplication);
              },
            ),
            const Divider(height: 1),
            _CareOption(
              icon: Icons.help_outline_rounded,
              title: 'Help Center',
              subtitle: 'Browse FAQs and guides',
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://halo.app/help'),
                    mode: LaunchMode.externalApplication);
              },
            ),
            const Divider(height: 1),
            _CareOption(
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Tell us what went wrong',
              onTap: () {
                Navigator.pop(context);
                launchUrl(
                    Uri.parse('mailto:support@halo.app?subject=Bug Report'),
                    mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSheet(String title, String message, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(icon, size: 48, color: const Color(0xFF5B3FA3)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF8E8E8E), fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B3FA3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Got it!',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedSegmentedControl() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFeedTab(0, 'For you'),
          _buildFeedTab(1, 'Following'),
        ],
      ),
    );
  }

  Widget _buildFeedTab(int index, String label) {
    final selected = _feedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _feedTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? kIgPrimaryText : kIgSecondaryText,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in to use chat')),
              );
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => ChatListPage(currentUserId: uid)),
            );
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          drawer: _HaloDrawer(onSelect: _onMenuAction),
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(52.0),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                'Halo',
                style: GoogleFonts.pacifico(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: 'Edit interests',
                  icon: const Icon(Icons.tune, color: Colors.black87),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const InterestSelectionPage(isFromSettings: true)),
                    );
                    if (!mounted) return;
                    await _loadInterests();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forum, color: Colors.black87),
                  onPressed: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please sign in to use chat')),
                      );
                      return;
                    }
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatListPage(currentUserId: uid),
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: Container(color: Colors.white),
            ),
          ),
          // IndexedStack keeps all pages alive — no lag when switching tabs
          body: IndexedStack(
            index: _navIndex,
            children: [
              // 0 — Home feed
              Container(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: RefreshIndicator(
                    key: _refreshKey,
                    onRefresh: () async {
                      _feedLastDoc = null;
                      await _loadFeed(refresh: true);
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        _VideoVisibilityNotifier.notify();
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _feedScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _StoriesStrip(),
                            const SizedBox(height: 4),
                            _buildFeedBody(textTheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 1 — Search
              _searchPage,

              // 2 — Explore
              _explorePage,

              // 3 — Add Post placeholder (opened as modal, never shown in stack)
              const SizedBox.shrink(),

              // 4 — Notifications
              _notificationPage,

              // 5 — Profile
              _profileTab,
            ],
          ),

          // Bottom Navigation Bar
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 12,
            selectedItemColor: kSecondaryColor,
            unselectedItemColor: Colors.grey.shade500,
            showUnselectedLabels: true,
            currentIndex: _navIndex,
            onTap: (index) {
              if (index == 3) {
                // Add Post — open as a full-screen modal so the camera works
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => AddPostPage(),
                  ),
                );
                return;
              }
              if (index == 0 && _navIndex == 0) {
                // Re-tapping Home: scroll to top then refresh
                _feedScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
                Future.delayed(const Duration(milliseconds: 450), () {
                  _refreshKey.currentState?.show();
                });
                return;
              }
              setState(() => _navIndex = index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_rounded),
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                label: 'Add Post',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_outline_rounded),
                label: 'Notifications',
              ),
              BottomNavigationBarItem(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundImage: AssetImage('assets/images/Profile.png'),
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile tab — lazy loads the right profile type on first show ────────────
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loaded = false;
  String _accountType = 'aspirant';
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final type = doc.data()?['accountType']?.toString().toLowerCase() ?? 'aspirant';
      if (!mounted) return;
      setState(() { _uid = uid; _accountType = type; _loaded = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _uid = uid; _loaded = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _uid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_accountType == 'wellness') {
      return wellness_profile.WellnessProfilePage(profileUserId: _uid);
    } else if (_accountType == 'guru') {
      return guru_profile.GuruProfilePage(profileUserId: _uid);
    }
    return aspirant_profile.ProfilePage(profileUserId: _uid);
  }
}

// ---------------------- Stories Strip ----------------------

class _StoriesStrip extends StatelessWidget {
  const _StoriesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid.isEmpty) {
      return const SizedBox(height: 110);
    }

    final storyService = StoryService();
    final rankedStream = storyService.fetchStoriesRanked(myUid);

    // 🔹 Stories list (ranked: current user first, then by storyScore desc)
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEBEBEB), width: 0.5)),
      ),
      child: SizedBox(
        height: 100,
        child: StreamBuilder<RankedStoriesResult>(
            stream: rankedStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              final result = snapshot.data!;
              final groupedStories = result.grouped;

              // Always put the current user first, then friends sorted by storyScore
              final friendIds = result.orderedUserIds
                  .where((id) => id != myUid)
                  .toList(growable: false);

              // Total items = 1 (self) + friends
              final totalCount = 1 + friendIds.length;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: totalCount,
                itemBuilder: (context, index) {

                  // ── Index 0: ALWAYS self story ──────────────────────────
                  if (index == 0) {
                    final myStories = groupedStories[myUid] ?? [];
                    final hasStories = myStories.isNotEmpty;
                    final hasUnseen = hasStories &&
                        myStories.any((s) => !s.viewers.contains(myUid));

                    // Fetch current user's photo from Firestore for accuracy
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(myUid)
                          .get(),
                      builder: (_, snap) {
                        final udata = snap.data?.data();
                        final photoUrl = _profilePhotoUrlFromUser(udata);

                        return GestureDetector(
                          onTap: () {
                            if (hasStories) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => StoryViewerPage(stories: myStories)));
                            } else {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const StoryUploadSheet(),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Avatar — only show story ring when has stories
                                    _StoryAvatar(
                                      imageUrl: photoUrl.isNotEmpty ? photoUrl : null,
                                      hasUnseen: hasStories && hasUnseen,
                                      isSeen: hasStories && !hasUnseen,
                                    ),
                                    // Always show + badge (Instagram style)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0095F6),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.add,
                                            size: 13, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Your story',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF262626),
                                      fontWeight: FontWeight.w400,
                                      height: 1.2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // ── Index 1+: friends ───────────────────────────────────
                  final userId = friendIds[index - 1];
                  final stories = groupedStories[userId] ?? [];
                  if (stories.isEmpty) return const SizedBox.shrink();

                  final hasUnseen =
                      stories.any((s) => !s.viewers.contains(myUid));
                  final first = stories.first;

                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StoryViewerPage(stories: stories))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StoryAvatar(
                            imageUrl: (first.userPhotoUrl?.isNotEmpty == true)
                                ? first.userPhotoUrl
                                : null,
                            hasUnseen: hasUnseen,
                            isSeen: !hasUnseen,
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 64,
                            child: Text(
                              first.username.isNotEmpty ? first.username : 'User',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF262626),
                                  height: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
    );
  }
}

/// 🔹 Reusable avatar with Instagram-style ring
class _StoryAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool hasUnseen;
  final bool isSeen;

  const _StoryAvatar({
    required this.imageUrl,
    required this.hasUnseen,
    required this.isSeen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnseen
            ? const LinearGradient(
          colors: [
            Color(0xFFF56040),
            Color(0xFFF77737),
            Color(0xFFE1306C),
            Color(0xFFC13584),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isSeen ? Colors.grey.shade400 : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
          (imageUrl ?? '').isNotEmpty
              ? CachedNetworkImageProvider(imageUrl ?? '')
              : null,
          child: (imageUrl ?? '').isEmpty
              ? const Icon(
            Icons.person,
            size: 28,
            color: Colors.white70,
          )
              : null,
        ),
      ),
    );
  }
}

// ---------------------- Drawer -----------------------------

enum _HaloMenuAction {
  home,
  feed,
  premium,
  wellness,
  challenges,
  profileSettings,
  events,
  analytics,
  savedPosts,
  gurus,
  logout,
  email,
  share,
  customerCare,
}

class _DrawerItemData {
  final IconData icon;
  final String label;
  final _HaloMenuAction action;

  const _DrawerItemData({
    required this.icon,
    required this.label,
    required this.action,
  });
}

class _HaloDrawer extends StatelessWidget {
  final ValueChanged<_HaloMenuAction> onSelect;

  const _HaloDrawer({Key? key, required this.onSelect}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryItems = [
      _DrawerItemData(
          icon: Icons.home_filled,
          label: 'Home',
          action: _HaloMenuAction.home),
      _DrawerItemData(
          icon: Icons.explore_outlined,
          label: 'Explore Feed',
          action: _HaloMenuAction.feed),
      _DrawerItemData(
          icon: Icons.bookmark_border_rounded,
          label: 'Saved Posts',
          action: _HaloMenuAction.savedPosts),
      _DrawerItemData(
          icon: Icons.local_fire_department,
          label: 'Premium Features',
          action: _HaloMenuAction.premium),
      _DrawerItemData(
          icon: Icons.self_improvement,
          label: 'Wellness',
          action: _HaloMenuAction.wellness),
      _DrawerItemData(
          icon: Icons.emoji_events_outlined,
          label: 'Challenges',
          action: _HaloMenuAction.challenges),
      _DrawerItemData(
          icon: Icons.manage_accounts_outlined,
          label: 'Profile Settings',
          action: _HaloMenuAction.profileSettings),
      _DrawerItemData(
          icon: Icons.event_outlined,
          label: 'Events',
          action: _HaloMenuAction.events),
      _DrawerItemData(
          icon: Icons.bar_chart_rounded,
          label: 'Analytics',
          action: _HaloMenuAction.analytics),
      _DrawerItemData(
          icon: Icons.school_outlined,
          label: 'Find Gurus',
          action: _HaloMenuAction.gurus),
      _DrawerItemData(
          icon: Icons.logout_rounded,
          label: 'Log Out',
          action: _HaloMenuAction.logout),
    ];

    const secondaryItems = [
      _DrawerItemData(
          icon: Icons.mail_outline_rounded,
          label: 'Email Us',
          action: _HaloMenuAction.email),
      _DrawerItemData(
          icon: Icons.share_rounded,
          label: 'Share App',
          action: _HaloMenuAction.share),
      _DrawerItemData(
          icon: Icons.headset_mic_rounded,
          label: 'Customer Care',
          action: _HaloMenuAction.customerCare),
    ];

    final headerTextStyle = GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: kSecondaryColor,
    );

    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF3EDFF),
                Color(0xFFE5E0FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Row(
                  children: [
                    Text('MENU', style: headerTextStyle),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    ...primaryItems.map(
                          (item) => _HaloDrawerTile(
                        data: item,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(item.action);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(thickness: 1.0),
                    ),
                    ...secondaryItems.map(
                          (item) => _HaloDrawerTile(
                        data: item,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(item.action);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Text(
                  'Version 1.013',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HaloDrawerTile extends StatelessWidget {
  final _DrawerItemData data;
  final VoidCallback onTap;

  const _HaloDrawerTile({
    Key? key,
    required this.data,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                color: kSecondaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Old PostWidget (still available) -------------------

class PostWidget extends StatelessWidget {
  final int index;

  const PostWidget({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundImage: AssetImage('assets/images/Profile.png'),
          ),
          title: Text('User $index'),
          subtitle: Text('Location $index'),
          trailing: const Icon(Icons.more_vert),
        ),
        Image.asset(
          'assets/images/Halo.png',
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.message_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () {},
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Liked by 99 others',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'User: This is a caption for the post.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'View all comments',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------- Double-tap heart overlay (Instagram-style) -----

class _DoubleTapHeartOverlay extends StatefulWidget {
  final String postId;
  final Widget child;

  const _DoubleTapHeartOverlay({
    Key? key,
    required this.postId,
    required this.child,
  }) : super(key: key);

  @override
  State<_DoubleTapHeartOverlay> createState() => _DoubleTapHeartOverlayState();
}

class _DoubleTapHeartOverlayState extends State<_DoubleTapHeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDoubleTap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('likes')
            .doc(uid)
            .set({
          'userId': uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    if (!mounted) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.value == 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Icon(
                      Icons.favorite,
                      size: 100,
                      color: kIgLikeRed,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------- Post Card ---------------------------

class _PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> savedPostsMap;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> allVideoDocs;
  const _PostCard({
    Key? key,
    required this.postId,
    required this.data,
    this.savedPostsMap = const {},
    this.allVideoDocs = const [],
  }) : super(key: key);
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _captionExpanded = false;
  String? _cachedUsername;

  String _resolveImageUrl() {
    final media = (widget.data['media'] as List?)?.cast<dynamic>() ?? [];
    final images = List<String>.from(widget.data['images'] ?? []);
    final imageUrl = (widget.data['imageUrl'] as String?)?.trim() ?? '';
    if (media.isNotEmpty) {
      final first = Map<String, dynamic>.from(media.first as Map);
      if ((first['type'] ?? '') == 'image') return (first['url'] ?? '').toString().trim();
    }
    if (images.isNotEmpty && images.first.trim().isNotEmpty) return images.first.trim();
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final media = (data['media'] as List?)?.cast<dynamic>() ?? [];
    final caption = (data['caption'] ?? '').toString().trim();
    final location = (data['location'] ?? '').toString().trim();
    final tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final userId = (data['userId'] ?? '').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final timeText = createdAt != null ? _timeAgo(createdAt.toDate().toLocal()) : '';

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header — one-shot get() instead of snapshots() to avoid
          // 20+ live Firestore streams on the home feed. ───────────────
          userId.isNotEmpty
              ? FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: _PostUserCache.get(userId),
                  builder: (context, snap) {
                    final udata = snap.data?.data();
                    final username = (udata?['username'] ?? udata?['name'] ?? 'User').toString();
                    _cachedUsername = username;
                    final photoUrl = _profilePhotoUrlFromUser(udata);
                    final accountType = (udata?['accountType'] as String?)?.toLowerCase() ?? 'aspirant';
                    return _IgPostHeader(
                      username: username,
                      photoUrl: photoUrl,
                      subtitle: location.isNotEmpty ? location : null,
                      accountType: accountType,
                      userId: userId,
                    );
                  },
                )
              : _IgPostHeader(
                  username: 'User', photoUrl: '', subtitle: null,
                  accountType: 'aspirant', userId: userId),

          // ── Media ────────────────────────────────────────────────────
          _DoubleTapHeartOverlay(
            postId: widget.postId,
            child: media.isNotEmpty
                ? _PostMedia(
                    media: media,
                    postId: widget.postId,
                    allVideoDocs: widget.allVideoDocs,
                  )
                : _resolveImageUrl().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _resolveImageUrl(),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 300,
                          color: const Color(0xFFF0F0F0),
                          child: const Center(child: CircularProgressIndicator(
                              color: Color(0xFFA58CE3), strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 300, color: const Color(0xFFF0F0F0),
                          child: const Center(child: Icon(Icons.broken_image,
                              color: Color(0xFFCCCCCC), size: 40)),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),

          // ── Action buttons ───────────────────────────────────────────
          _IgPostActions(postId: widget.postId, savedPostsMap: widget.savedPostsMap),

          // ── Like count ───────────────────────────────────────────────
          _IgLikeCount(postId: widget.postId, postData: data),

          // ── Caption ──────────────────────────────────────────────────
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: GestureDetector(
                onTap: () => setState(() => _captionExpanded = !_captionExpanded),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${_cachedUsername ?? ''} ',
                      style: const TextStyle(
                        fontFamily: 'sans-serif',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Color(0xFF262626),
                      ),
                    ),
                    TextSpan(
                      text: caption,
                      style: const TextStyle(
                        fontFamily: 'sans-serif',
                        fontWeight: FontWeight.w400,
                        fontSize: 13.5,
                        color: Color(0xFF262626),
                        height: 1.4,
                      ),
                    ),
                  ]),
                  maxLines: _captionExpanded ? null : 2,
                  overflow: _captionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ),
            ),

          // ── "more" expand hint ───────────────────────────────────────
          if (caption.isNotEmpty && !_captionExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: GestureDetector(
                onTap: () => setState(() => _captionExpanded = true),
                child: const Text('more',
                    style: TextStyle(
                        color: Color(0xFF8E8E8E), fontSize: 13.5,
                        fontWeight: FontWeight.w400)),
              ),
            ),

          // ── Tags ─────────────────────────────────────────────────────
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 4,
                children: tags.map((t) => Text('#$t',
                    style: const TextStyle(
                        color: Color(0xFF00376B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400))).toList(),
              ),
            ),

          // ── Comments link ────────────────────────────────────────────
          _IgCommentsLink(postId: widget.postId, postData: data),

          // ── Timestamp ────────────────────────────────────────────────
          if (timeText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(timeText,
                  style: const TextStyle(
                      color: Color(0xFF8E8E8E), fontSize: 10,
                      letterSpacing: 0.2)),
            ),

          // ── Divider ──────────────────────────────────────────────────
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEBEBEB)),
        ],
      ),
    );
  }
}

// Instagram post header: avatar + username + subtitle + •••
class _IgPostHeader extends StatelessWidget {
  final String username;
  final String photoUrl;
  final String? subtitle;
  final String accountType;
  final String userId;

  const _IgPostHeader({
    required this.username,
    required this.photoUrl,
    required this.subtitle,
    required this.accountType,
    required this.userId,
  });

  void _openProfile(BuildContext context) {
    if (userId.isEmpty) return;
    if (accountType == 'wellness') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => wellness_profile.WellnessProfilePage(profileUserId: userId)));
    } else if (accountType == 'guru') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => guru_profile.GuruProfilePage(profileUserId: userId)));
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => aspirant_profile.ProfilePage(profileUserId: userId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Avatar with story-ring gradient
          GestureDetector(
            onTap: () => _openProfile(context),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF56040), Color(0xFFE1306C), Color(0xFFC13584)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFEFEF),
                  backgroundImage: photoUrl.isEmpty
                      ? const AssetImage('assets/images/Profile.png')
                          as ImageProvider
                      : null,
                  child: photoUrl.isNotEmpty
                      ? ClipOval(child: CachedNetworkImage(
                          imageUrl: photoUrl, width: 32, height: 32,
                          fit: BoxFit.cover))
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _openProfile(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(username,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: Color(0xFF262626))),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF8E8E8E))),
                ],
              ),
            ),
          ),
          // ··· menu
          GestureDetector(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.more_horiz, color: Color(0xFF262626), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------- Post Media Carousel ---------------------
// Instagram-style: horizontal PageView, page dots + "1/N" counter,
// only the active page's video plays — all others are paused.

class _PostMedia extends StatefulWidget {
  final List<dynamic> media;
  final String postId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> allVideoDocs;

  const _PostMedia({
    Key? key,
    required this.media,
    this.postId = '',
    this.allVideoDocs = const [],
  }) : super(key: key);

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _openReelViewer(BuildContext context, String tappedUrl) {
    final allDocs = widget.allVideoDocs;
    if (allDocs.isEmpty) return;

    // Build the ordered list of feed-reel items from allVideoDocs
    final reelItems = allDocs.map((doc) {
      final d = doc.data();
      final m = (d['media'] as List?)?.cast<dynamic>() ?? [];
      final videoItem = m.firstWhere(
        (item) => (Map<String, dynamic>.from(item as Map)['type'] ?? '') == 'video',
        orElse: () => null,
      );
      if (videoItem == null) return null;
      final vm = Map<String, dynamic>.from(videoItem as Map);
      final hlsUrl = (vm['hlsUrl'] ?? '').toString().trim();
      final mp4Url = (vm['videoUrl'] ?? vm['url'] ?? '').toString().trim();
      final processing = vm['processing'] == true;
      final processed = vm['processed'] == true;
      final videoUrl = hlsUrl.isNotEmpty ? hlsUrl : mp4Url;
      if (videoUrl.isEmpty) return null;
      // Skip transient/incomplete entries in reel viewer source list.
      if (processing || !processed) return null;
      return _FeedReelItem(
        postId: doc.id,
        videoUrl: videoUrl,
        caption: (d['caption'] ?? '').toString(),
        userId: (d['userId'] ?? '').toString(),
        thumbnailUrl: (vm['thumbnail'] ?? vm['thumbnailUrl'] ?? '').toString(),
      );
    }).whereType<_FeedReelItem>().toList(growable: false);

    if (reelItems.isEmpty) return;

    // Find which index the tapped video is
    int startIndex = reelItems.indexWhere((r) => r.postId == widget.postId);
    if (startIndex < 0) startIndex = 0;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _FeedReelViewer(
          reels: reelItems,
          initialIndex: startIndex,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.media;
    if (items.isEmpty) return const SizedBox.shrink();

    final count = items.length;
    final screenW = MediaQuery.of(context).size.width;
    // Square-ish: full width, 4:5 aspect like Instagram
    final h = (screenW * 5 / 4).clamp(280.0, 480.0);

    return Stack(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _pc,
            itemCount: count,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) {
              final item = Map<String, dynamic>.from(items[i] as Map);
              final type = (item['type'] ?? 'image').toString();
              final url = (item['url'] ?? '').toString().trim();

              if (type == 'video') {
                final thumb = (item['thumbnail'] ?? item['thumbnailUrl'] ?? '')
                    .toString()
                    .trim();
                return GestureDetector(
                  onTap: () => _openReelViewer(context, url),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (kEnableInlineFeedVideoAutoplay)
                        _NetworkVideo(
                          url: url,
                          isActiveInCarousel: i == _page,
                        )
                      else if (thumb.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: h,
                          placeholder: (_, __) =>
                              const ColoredBox(color: Colors.black),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Colors.black),
                        )
                      else
                        const ColoredBox(color: Colors.black),
                      // Play icon overlay hint (tap to fullscreen)
                      const Positioned.fill(
                        child: Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white70, size: 64),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Image
              if (url.isEmpty) {
                return Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        color: Colors.black26, size: 40),
                  ),
                );
              }
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: h,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFA58CE3), strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.black26, size: 40)),
                ),
              );
            },
          ),
        ),

        // ── "1/N" counter (top-right) — only when multiple items ──
        if (count > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_page + 1}/$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // ── Dot indicators (bottom-centre) ────────────────────────
        if (count > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count.clamp(0, 10), (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFA58CE3)
                        : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ── Post skeleton — shown while the initial feed page is loading ──────────────
class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            _Shimmer(width: 36, height: 36, radius: 18),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Shimmer(width: 120, height: 12, radius: 4),
              const SizedBox(height: 4),
              _Shimmer(width: 80, height: 10, radius: 4),
            ]),
          ]),
        ),
        // Media
        _Shimmer(width: double.infinity, height: 280, radius: 0),
        // Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            _Shimmer(width: 28, height: 28, radius: 14),
            const SizedBox(width: 12),
            _Shimmer(width: 28, height: 28, radius: 14),
            const SizedBox(width: 12),
            _Shimmer(width: 28, height: 28, radius: 14),
          ]),
        ),
        // Caption
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Shimmer(width: double.infinity, height: 11, radius: 4),
            const SizedBox(height: 6),
            _Shimmer(width: 200, height: 11, radius: 4),
          ]),
        ),
        const Divider(height: 1, thickness: 0.5, color: Color(0xFFEBEBEB)),
      ],
    );
  }
}

class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _Shimmer({required this.width, required this.height, required this.radius});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(_anim.value * 0.35),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

// ── User profile cache — avoids re-fetching the same user doc on every
// scroll rebuild. TTL: 5 minutes per entry. ──────────────────────────────────
class _PostUserCache {
  static final Map<String, _CachedUserDoc> _cache = {};
  static const Duration _ttl = Duration(minutes: 5);

  static Future<DocumentSnapshot<Map<String, dynamic>>> get(String uid) {
    final entry = _cache[uid];
    if (entry != null && DateTime.now().difference(entry.fetchedAt) < _ttl) {
      return entry.future;
    }
    final future = FirebaseFirestore.instance.collection('users').doc(uid).get();
    _cache[uid] = _CachedUserDoc(future: future, fetchedAt: DateTime.now());
    return future;
  }
}

class _CachedUserDoc {
  final Future<DocumentSnapshot<Map<String, dynamic>>> future;
  final DateTime fetchedAt;
  _CachedUserDoc({required this.future, required this.fetchedAt});
}

// ── Global mute state shared across ALL feed videos ──────────────────────────
final _globalMuted = ValueNotifier<bool>(true);

/// Called by VideoMemoryBridge on critical memory pressure.
/// Notifies all active video controllers to re-check visibility so off-screen
/// ones pause and release their decode buffers.
void evictHomeFeedVideoCache() {
  _VideoVisibilityNotifier.notify();
}

// ── Visibility pub-sub (scroll → check play/pause) ───────────────────────────
class _VideoVisibilityNotifier {
  static final List<VoidCallback> _ls = [];
  static void add(VoidCallback cb) => _ls.add(cb);
  static void remove(VoidCallback cb) => _ls.remove(cb);
  static void notify() { for (final cb in List.of(_ls)) cb(); }
}

// ── Helper: relative time string ─────────────────────────────────────────────
String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
  return '${(d.inDays / 365).floor()}y ago';
}

// ── Feed reel data model ──────────────────────────────────────────────────────
class _FeedReelItem {
  final String postId;
  final String videoUrl;
  final String caption;
  final String userId;
  final String thumbnailUrl;
  const _FeedReelItem({
    required this.postId,
    required this.videoUrl,
    required this.caption,
    required this.userId,
    required this.thumbnailUrl,
  });
}

// ── Full-screen reel viewer opened from home feed ─────────────────────────────
// Vertical PageView, auto-plays current, prefetches next 2.
class _FeedReelViewer extends StatefulWidget {
  final List<_FeedReelItem> reels;
  final int initialIndex;
  const _FeedReelViewer({
    Key? key,
    required this.reels,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<_FeedReelViewer> createState() => _FeedReelViewerState();
}

class _FeedReelViewerState extends State<_FeedReelViewer> {
  late final PageController _pc;
  int _current = 0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pc = PageController(initialPage: widget.initialIndex);
    // Prefetch next 2 on open
    _prefetchAhead(_current);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _prefetchAhead(int index) {
    for (int off = 1; off <= 2; off++) {
      final i = index + off;
      if (i < widget.reels.length) {
        final url = widget.reels[i].videoUrl;
        if (url.isNotEmpty) {
          // Warm up using the same pool so controllers are ready before swipe
          _FeedVideoPool.instance.preload(url);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
            itemCount: widget.reels.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _prefetchAhead(i);
            },
            itemBuilder: (_, index) {
              final reel = widget.reels[index];
              return _FeedReelPage(
                key: ValueKey(reel.postId),
                reel: reel,
                isActive: index == _current,
                muted: _muted,
                onMuteToggle: () => setState(() => _muted = !_muted),
              );
            },
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single reel page inside _FeedReelViewer ───────────────────────────────────
class _FeedReelPage extends StatefulWidget {
  final _FeedReelItem reel;
  final bool isActive;
  final bool muted;
  final VoidCallback onMuteToggle;

  const _FeedReelPage({
    Key? key,
    required this.reel,
    required this.isActive,
    required this.muted,
    required this.onMuteToggle,
  }) : super(key: key);

  @override
  State<_FeedReelPage> createState() => _FeedReelPageState();
}

class _FeedReelPageState extends State<_FeedReelPage> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.reel.videoUrl.isEmpty) {
      setState(() => _error = true);
      return;
    }
    try {
      // Try pool first (may already be preloaded)
      var ctrl = _FeedVideoPool.instance.get(widget.reel.videoUrl);
      if (ctrl == null) {
        ctrl = await _FeedVideoPool.instance.preload(widget.reel.videoUrl);
      }
      if (!mounted || ctrl == null) return;
      _ctrl = ctrl;
      if (!_ctrl!.value.isInitialized) {
        await _ctrl!.initialize();
      }
      if (!mounted) return;
      _ctrl!.setLooping(true);
      _ctrl!.setVolume(widget.muted ? 0 : 1);
      if (widget.isActive) _ctrl!.play();
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(_FeedReelPage old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      if (widget.isActive) {
        _ctrl?.play();
      } else {
        _ctrl?.pause();
      }
    }
    if (old.muted != widget.muted) {
      _ctrl?.setVolume(widget.muted ? 0 : 1);
    }
  }

  @override
  void dispose() {
    _ctrl?.pause();
    // Return to pool (don't dispose — pool manages lifecycle)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_ctrl == null) return;
        setState(() {
          _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail while loading
          if (widget.reel.thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.reel.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            ),

          // Video
          if (_ready && _ctrl != null && _ctrl!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _ctrl!.value.size.width,
                height: _ctrl!.value.size.height,
                child: VideoPlayer(_ctrl!),
              ),
            ),

          // Loading
          if (!_ready && !_error)
            const Center(child: CircularProgressIndicator(
                color: Colors.white54, strokeWidth: 2.5)),

          // Error
          if (_error)
            const Center(child: Icon(Icons.videocam_off,
                color: Colors.white38, size: 56)),

          // Pause icon
          if (_ready && _ctrl != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _ctrl!,
              builder: (_, val, __) => AnimatedOpacity(
                opacity: val.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: const Center(child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white70, size: 72)),
              ),
            ),

          // Bottom gradient + caption
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 60, 60, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Username
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: widget.reel.userId.isNotEmpty
                        ? _PostUserCache.get(widget.reel.userId)
                        : null,
                    builder: (_, snap) {
                      final udata = snap.data?.data();
                      final username = (udata?['username'] ?? udata?['name'] ?? '').toString();
                      if (username.isEmpty) return const SizedBox.shrink();
                      return Text('@$username',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54)]));
                    },
                  ),
                  if (widget.reel.caption.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(widget.reel.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.4,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                  ],
                ],
              ),
            ),
          ),

          // Mute button
          Positioned(
            bottom: 28,
            right: 14,
            child: GestureDetector(
              onTap: widget.onMuteToggle,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Progress bar
          if (_ready && _ctrl != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: VideoProgressIndicator(
                _ctrl!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFA58CE3),
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white10,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Lightweight video pool for the feed reel viewer ───────────────────────────
// Keeps up to 3 initialized controllers (current + next 2).
class _FeedVideoPool {
  _FeedVideoPool._();
  static final _FeedVideoPool instance = _FeedVideoPool._();

  static const int _maxSize = 3;
  final Map<String, VideoPlayerController> _pool = {};
  final List<String> _lru = [];

  VideoPlayerController? get(String url) {
    final c = _pool[url];
    if (c != null && c.value.isInitialized) {
      _touch(url);
      return c;
    }
    return null;
  }

  Future<VideoPlayerController?> preload(String url) async {
    if (url.isEmpty) return null;
    if (_pool.containsKey(url)) {
      _touch(url);
      return _pool[url];
    }
    _evictIfNeeded();
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: false),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    _pool[url] = ctrl;
    _lru.add(url);
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      await ctrl.pause();
    } catch (_) {
      _remove(url);
      return null;
    }
    return ctrl;
  }

  void _touch(String url) {
    _lru.remove(url);
    _lru.add(url);
  }

  void _evictIfNeeded() {
    while (_pool.length >= _maxSize && _lru.isNotEmpty) {
      _remove(_lru.first);
    }
  }

  void _remove(String url) {
    _pool[url]?.pause();
    _pool[url]?.dispose();
    _pool.remove(url);
    _lru.remove(url);
  }
}

// ── Video player: progressive (starts as soon as buffering begins) ────────────
class _NetworkVideo extends StatefulWidget {
  final String url;
  // When inside a carousel, the parent tells us if this slide is active.
  // null = not in a carousel (standalone, visibility-only control).
  final bool? isActiveInCarousel;
  const _NetworkVideo({Key? key, required this.url, this.isActiveInCarousel})
      : super(key: key);
  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  VideoPlayerController? _ctrl;
  bool _ready = false;       // true once isInitialized
  bool _error = false;
  bool _manualPause = false;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _VideoVisibilityNotifier.add(_onScroll);
    _globalMuted.addListener(_onGlobalMuteChange);
    _initController();
  }

  void _onGlobalMuteChange() {
    _ctrl?.setVolume(_globalMuted.value ? 0.0 : 1.0);
  }

  void _initController() {
    if (widget.url.trim().isEmpty) {
      setState(() => _error = true);
      return;
    }
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
      // Keep-alive so segments reuse the TCP connection → faster first byte
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    _ctrl = ctrl;

    // Listen for isInitialized rather than awaiting the whole future.
    // AVPlayer / ExoPlayer will fire this as soon as the moov/init segment
    // arrives — so progressive MP4s and HLS start playing almost immediately.
    ctrl.addListener(_onControllerUpdate);
    ctrl.initialize().catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;

    if (!_ready && c.value.isInitialized) {
      c.setLooping(true);
      c.setVolume(_globalMuted.value ? 0.0 : 1.0);
      setState(() => _ready = true);
      _playIfVisible();
    }

    if (c.value.hasError && !_error) {
      setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(_NetworkVideo old) {
    super.didUpdateWidget(old);
    // Carousel page changed — play or pause based on active slot
    if (widget.isActiveInCarousel != old.isActiveInCarousel && _ready && !_manualPause) {
      if (widget.isActiveInCarousel == true) {
        _onScroll(); // re-check scroll visibility then play if on screen
      } else if (widget.isActiveInCarousel == false) {
        _ctrl?.pause();
      }
    }
  }

  // Returns true if this video should be playing given carousel + scroll state.
  bool get _shouldPlay {
    // Inside carousel: only play if this is the active slide
    if (widget.isActiveInCarousel == false) return false;
    return true;
  }

  void _onScroll() {
    if (!_ready || _ctrl == null || _manualPause) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Carousel: if not active slide, always pause
      if (!_shouldPlay) {
        if (_ctrl!.value.isPlaying) _ctrl!.pause();
        return;
      }
      final ctx = _key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      final sh = MediaQuery.of(ctx).size.height;
      final visible = bottom > sh * 0.15 && top < sh * 0.85;
      if (visible && !_ctrl!.value.isPlaying) {
        _ctrl!.play();
      } else if (!visible && _ctrl!.value.isPlaying) {
        _ctrl!.pause();
      }
    });
  }

  void _playIfVisible() => _onScroll();

  @override
  void dispose() {
    _VideoVisibilityNotifier.remove(_onScroll);
    _globalMuted.removeListener(_onGlobalMuteChange);
    _ctrl?.removeListener(_onControllerUpdate);
    _ctrl?.pause();
    _ctrl?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    // Toggle the global notifier → all videos react
    _globalMuted.value = !_globalMuted.value;
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    setState(() {
      if (_ctrl!.value.isPlaying) {
        _ctrl!.pause();
        _manualPause = true;
      } else {
        _ctrl!.play();
        _manualPause = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        height: 300,
        color: Colors.black12,
        child: const Center(child: Icon(Icons.videocam_off, color: Colors.black26, size: 40)),
      );
    }

    // Skeleton shimmer while buffering
    if (!_ready || _ctrl == null || !_ctrl!.value.isInitialized) {
      return Container(
        key: _key,
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFFA58CE3),
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(height: 8),
              Text('Loading video…',
                  style: TextStyle(color: Colors.black38, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final c = _ctrl!;
    return ValueListenableBuilder<bool>(
      valueListenable: _globalMuted,
      builder: (_, muted, __) {
        return GestureDetector(
          key: _key,
          onTap: _togglePlay,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Video frame ──────────────────────────────────────────
              SizedBox(
                height: 300,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              ),

              // ── Buffering spinner overlay ────────────────────────────
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, val, __) {
                  if (!val.isBuffering) return const SizedBox.shrink();
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: Colors.white70, strokeWidth: 2.5),
                    ),
                  );
                },
              ),

              // ── Play/pause icon (fades while playing) ────────────────
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, val, __) => AnimatedOpacity(
                  opacity: val.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
              ),

              // ── Mute button (bottom-right) ───────────────────────────
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // ── Progress bar ─────────────────────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFFA58CE3),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


// ── Instagram-style action bar: heart · comment · send · bookmark ──
class _IgPostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> savedPostsMap;
  const _IgPostActions({
    Key? key,
    required this.postId,
    this.savedPostsMap = const {},
  }) : super(key: key);
  @override
  State<_IgPostActions> createState() => _IgPostActionsState();
}

class _IgPostActionsState extends State<_IgPostActions>
    with SingleTickerProviderStateMixin {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late AnimationController _heartAnim;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heartAnim.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_uid == null) return;
    _heartAnim.forward(from: 0);
    final ref = FirebaseFirestore.instance
        .collection('posts').doc(widget.postId)
        .collection('likes').doc(_uid);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
    }
  }

  void _openComments() {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _CommentsPage(postId: widget.postId, postData: const {})));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          // Heart
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _uid != null
                ? FirebaseFirestore.instance
                    .collection('posts').doc(widget.postId)
                    .collection('likes').doc(_uid!).snapshots()
                : const Stream.empty(),
            builder: (_, snap) {
              final liked = snap.hasData && (snap.data?.exists ?? false);
              return ScaleTransition(
                scale: _heartScale,
                child: IconButton(
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFFED4956) : const Color(0xFF262626),
                    size: 26,
                  ),
                  onPressed: _toggleLike,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              );
            },
          ),
          // Comment
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFF262626), size: 25),
            onPressed: _openComments,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          // Send/share
          IconButton(
            icon: const Icon(Icons.send_outlined,
                color: Color(0xFF262626), size: 24),
            onPressed: () {},
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          // Bookmark — uses shared map, no per-post stream
          SaveButton(
            postId: widget.postId,
            currentUserId: _uid,
            savedPostsMap: widget.savedPostsMap,
            iconSize: 25,
            color: const Color(0xFF262626),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Like count — reads from post document field (no subcollection stream) ──
// Only the current user's own like doc is streamed (single doc, minimal cost).
class _IgLikeCount extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  const _IgLikeCount({Key? key, required this.postId, required this.postData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Use stored count from post document — avoids fetching all like docs.
    final storedCount = _asIntSafe(postData['likesCount'] ?? postData['likeCount']) ;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid != null
          ? FirebaseFirestore.instance
              .collection('posts').doc(postId)
              .collection('likes').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (_, snap) {
        final myLike = snap.hasData && (snap.data?.exists ?? false);
        final count = storedCount;
        if (count == 0 && !myLike) return const SizedBox.shrink();
        String text;
        if (myLike && count <= 1) {
          text = 'Liked by you';
        } else if (myLike && count > 1) {
          text = 'Liked by you and ${count - 1} ${count - 1 == 1 ? 'other' : 'others'}';
        } else if (count > 0) {
          text = '$count ${count == 1 ? 'like' : 'likes'}';
        } else {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: Color(0xFF262626))),
        );
      },
    );
  }

  static int _asIntSafe(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ── "View all X comments" — reads count from post document field ──
class _IgCommentsLink extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  const _IgCommentsLink({Key? key, required this.postId, required this.postData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final count = _asIntSafe(postData['commentsCount'] ?? postData['commentCount']);
    if (count == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _CommentsPage(postId: postId, postData: postData))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Text(
          'View all $count ${count == 1 ? 'comment' : 'comments'}',
          style: const TextStyle(
              color: Color(0xFF8E8E8E), fontSize: 13.5),
        ),
      ),
    );
  }

  static int _asIntSafe(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ── Customer care option tile ─────────────────────────────────────────────────
class _CareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF5B3FA3), size: 24),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Color(0xFF8E8E8E)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }
}

// ---------------------- Comments Page -----------------------

class _CommentsPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const _CommentsPage({
    Key? key,
    required this.postId,
    required this.postData,
  }) : super(key: key);

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final TextEditingController _commentController =
  TextEditingController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _addComment() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': _currentUserId,
        'text': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comments'),
          backgroundColor: kSecondaryColor,
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading comments'));
                  }

                  final comments = snapshot.data?.docs ?? [];

                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index].data();
                      return ListTile(
                        title: Text(comment['text'] ?? ''),
                        subtitle: Text(
                          comment['createdAt'] != null
                              ? (comment['createdAt'] as Timestamp)
                              .toDate()
                              .toString()
                              .substring(0, 16)
                              : '',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
