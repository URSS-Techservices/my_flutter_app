// HomePage.dart — clean Instagram-style home feed for Halo
// Full rewrite. No pool complexity, no opaque-route bugs, no stale controllers.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:halo/Bottom%20Pages/AddPostPage.dart';
import 'package:halo/Bottom%20Pages/NotificationPage.dart';
import 'package:halo/Bottom%20Pages/SettingsPage.dart';
import 'package:halo/Bottom%20Pages/SearchPage.dart';
import 'package:halo/Bottom%20Pages/ExplorePage.dart';
import 'package:halo/Bottom%20Pages/saved_posts_page.dart';
import 'package:halo/Profile%20Pages/aspirant_profile_page.dart' as aspirant;
import 'package:halo/Profile%20Pages/guru_profile_page.dart' as guru;
import 'package:halo/Profile%20Pages/wellness_profile_page.dart' as wellness;
import 'package:halo/chat/chat_list_page.dart';
import 'package:halo/interest_selection_page.dart';
import 'package:halo/models/story_model.dart';
import 'package:halo/models/post_place.dart';
import 'package:halo/services/feed_service.dart';
import 'package:halo/services/save_service.dart';
import 'package:halo/services/story_service.dart';
import 'package:halo/services/app_video_focus.dart';
import 'package:halo/services/reel_preload_policy.dart';
import 'package:halo/services/video_decoder_budget.dart';
import 'package:halo/services/video_dispose_serial.dart';
import 'package:halo/services/video_playback_resolver.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/story/story_upload_sheet.dart';
import 'package:halo/story/story_viewer_page.dart';
import 'package:halo/utils/story_utils.dart';
import 'package:halo/widgets/save_button.dart';

// ─── theme ───────────────────────────────────────────────────────────────────

const Color kPrimaryColor   = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color _kBgColor       = Color(0xFFF4F1FB); // app lavender background
const Color _kCardBg        = Colors.white;
const Color _kLikeRed       = Color(0xFFED4956);
const Color _kText          = Color(0xFF262626);
const Color _kSubText       = Color(0xFF8E8E8E);

// ─── helpers ─────────────────────────────────────────────────────────────────

String _profilePhotoUrl(Map<String, dynamic>? d) {
  if (d == null) return '';
  for (final k in ['profilePhoto', 'photoURL', 'profile_photo', 'avatar']) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)   return 'Just now';
  if (diff.inMinutes < 60)   return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24)   return '${diff.inHours}h ago';
  if (diff.inDays    < 7)    return '${diff.inDays}d ago';
  if (diff.inDays    < 30)   return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays    < 365)  return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

/// Post tags (AddPostPage) vs interest keys (InterestSelectionPage) use different
/// labels — normalize both sides before comparing.
String _normalizeInterestToken(String value) =>
    value.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');

/// Maps common post-tag labels to interest-selection keys.
const Map<String, String> _postTagToInterestKey = {
  'wellness': 'mental_health',
  'spirituality': 'mental_health',
  'mindset': 'mental_health',
  'study': 'reading',
  'lifestyle': 'travel',
  'career': 'productivity',
  'finance': 'productivity',
  'relationships': 'mental_health',
};

bool _postMatchesInterests(
  Map<String, dynamic> data,
  List<String> interests,
  String currentUserId,
) {
  final postUserId = (data['userId'] ?? '').toString();
  if (currentUserId.isNotEmpty && postUserId == currentUserId) return true;
  if (interests.isEmpty) return true;
  if ((data['accountType'] ?? '').toString().toLowerCase() == 'guru') return true;

  final tags = (data['tags'] as List?)
          ?.map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      [];
  if (tags.isEmpty) return true;

  final normalizedInterests = interests.map(_normalizeInterestToken).toSet();
  for (final tag in tags) {
    final token = _normalizeInterestToken(tag);
    if (normalizedInterests.contains(token)) return true;
    final mapped = _postTagToInterestKey[token];
    if (mapped != null && normalizedInterests.contains(mapped)) return true;
  }
  return false;
}

// User-doc cache — avoids a Firestore read per post card on every scroll
class _UserCache {
  static final Map<String, _Entry> _m = {};
  static const Duration _ttl = Duration(minutes: 5);

  static Future<Map<String, dynamic>?> get(String uid) async {
    final e = _m[uid];
    if (e != null && DateTime.now().difference(e.at) < _ttl) return e.data;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      _m[uid] = _Entry(data, DateTime.now());
      return data;
    } catch (_) { return null; }
  }
}

class _Entry {
  final Map<String, dynamic>? data;
  final DateTime at;
  _Entry(this.data, this.at);
}

// ═══════════════════════════════════════════════════════════════════════════
// HomePage — bottom nav shell
// ═══════════════════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _refreshKey  = GlobalKey<RefreshIndicatorState>();
  final _scrollCtrl  = ScrollController();
  final _feedSvc     = FeedService();

  int _navIndex = 0;
  bool _locationPrompted = false;
  List<String> _interests = const [];
  Map<String, dynamic> _savedMap = const {};
  StreamSubscription<Map<String, dynamic>>? _savedSub;
  StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _feedSub;

  // Feed pagination
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _feed = const [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _feedExtra = const [];
  bool _feedLoading = false;
  bool _feedError   = false;
  bool _feedHasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _feedCursor;

  // Pages created once — avoids InheritedWidget teardown assertion
  late final Widget _searchPage;
  late final Widget _explorePage;
  late final Widget _notifPage;
  late final Widget _profilePage;

  void _goHomeTab() {
    if (!mounted || _navIndex == 0) return;
    setState(() => _navIndex = 0);
  }

  @override
  void initState() {
    super.initState();
    _searchPage  = SearchPage(onBackToHome: _goHomeTab);
    _explorePage = const ExplorePage();
    _notifPage   = NotificationPage(onBackToHome: _goHomeTab);
    _profilePage = _ProfileTab(onBackToHome: _goHomeTab);
    _scrollCtrl.addListener(_onScroll);
    _loadInterests();
    _initSaved();
    _startFeedStream();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    _feedSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── data loading ─────────────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 600 &&
        !_feedLoading && _feedHasMore) {
      _loadFeed();
    }
  }

  void _startFeedStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _feedSub?.cancel();
    if (_feed.isEmpty) {
      setState(() {
        _feedLoading = true;
        _feedError = false;
      });
    }
    _feedSub = _feedSvc.getRankedFeedStream(currentUserId: uid).listen(
      (docs) {
        if (!mounted) return;
        setState(() {
          _feed = docs;
          _feedCursor = docs.isNotEmpty ? docs.last : null;
          _feedExtra = const [];
          _feedHasMore = docs.length >= 50;
          _feedLoading = false;
          _feedError = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() { _feedLoading = false; _feedError = true; });
      },
    );
  }

  Future<void> _refreshFeed() async {
    _feedCursor = null;
    _feedExtra = const [];
    _feedHasMore = true;
    _startFeedStream();
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (refresh) {
      await _refreshFeed();
      return;
    }
    if (_feedLoading) return;
    setState(() { _feedLoading = true; _feedError = false; });
    try {
      final uid    = FirebaseAuth.instance.currentUser?.uid ?? '';
      final result = await _feedSvc.getRankedFeedPage(
        currentUserId: uid,
        userPreference: '',
        limit: 20,
        startAfterDoc: _feedCursor,
      );
      if (!mounted) return;
      final seen = {..._feed.map((d) => d.id), ..._feedExtra.map((d) => d.id)};
      final extra = result.docs.where((d) => !seen.contains(d.id)).toList();
      setState(() {
        _feedExtra = [..._feedExtra, ...extra];
        _feedCursor = result.lastDoc;
        _feedHasMore = result.hasMore;
        _feedLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _feedLoading = false; _feedError = true; });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _allFeedDocs =>
      [..._feed, ..._feedExtra];

  void _initSaved() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _savedSub = SaveService().savedPostsStream(uid).listen((m) {
      if (mounted) setState(() => _savedMap = m);
    });
  }

  Future<void> _loadInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList('user_interests') ?? const [];
    if (mounted) setState(() => _interests = list);
  }

  Future<void> _maybePromptLocation() async {
    if (_locationPrompted) return;
    _locationPrompted = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('location_prompt_shown') ?? false) return;
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) { await prefs.setBool('location_prompt_shown', true); return; }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Allow Location Access'),
        content: const Text('Halo uses your location to enhance discovery.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Permission.locationWhenInUse.request();
              await prefs.setBool('location_prompt_shown', true);
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await prefs.setBool('location_prompt_shown', true);
  }

  // ── feed body ────────────────────────────────────────────────────────────

  Widget _buildFeed() {
    if (_feedLoading && _feed.isEmpty) {
      return Column(children: List.generate(3, (_) => const _PostSkeleton()));
    }
    if (_feedError && _feed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadFeed(refresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSecondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ]),
      );
    }

    // Soft interest filter — always show the current user's own posts.
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    var visible = _allFeedDocs;
    if (_interests.isNotEmpty) {
      visible = _allFeedDocs
          .where((d) => _postMatchesInterests(d.data(), _interests, uid))
          .toList();
    }

    if (visible.isEmpty && !_feedLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _interests.isNotEmpty
              ? 'No posts match your interests yet. Pull down to refresh.'
              : 'No posts yet. Follow people to see their posts.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 14),
        ),
      );
    }

    // Pre-collect all video docs so the fullscreen button can open the right reel
    final allVideoDocs = visible.where((d) {
      final m = d.data()['media'];
      if (m is List) return m.any((item) => (item as Map?)?['type'] == 'video');
      final t = (d.data()['type'] ?? '').toString();
      return t == 'video' || (d.data()['videoUrl'] ?? d.data()['hlsUrl'] ?? '').toString().isNotEmpty;
    }).toList(growable: false);

    return Column(
      children: [
        ...visible.map((doc) => _PostCard(
          key: ValueKey(doc.id),
          postId: doc.id,
          data: doc.data(),
          savedMap: _savedMap,
          allVideoDocs: allVideoDocs,
        )),
        if (_feedHasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _feedLoading
                ? const CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)
                : TextButton(
                    onPressed: _loadFeed,
                    child: const Text('Load more', style: TextStyle(color: kSecondaryColor)),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text("You're all caught up!",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ),
      ],
    );
  }

  // ── drawer actions ────────────────────────────────────────────────────────

  void _onDrawer(_DrawerAction a) {
    switch (a) {
      case _DrawerAction.home:
        setState(() => _navIndex = 0);
        _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      case _DrawerAction.explore:
        setState(() => _navIndex = 2);
      case _DrawerAction.saved:
        Navigator.push(context, MaterialPageRoute(builder: (_) => SavedPostsPage()));
      case _DrawerAction.settings:
        Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
      case _DrawerAction.logout:
        _confirmLogout();
      case _DrawerAction.share:
        launchUrl(Uri.parse('https://halo.app'), mode: LaunchMode.externalApplication);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async { Navigator.pop(context); await FirebaseAuth.instance.signOut(); },
            child: const Text('Log out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _navIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _navIndex != 0) _goHomeTab();
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBgColor,
      drawer: _Drawer(onSelect: _onDrawer),
      appBar: _navIndex == 0 ? AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _kBgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text('Halo', style: GoogleFonts.pacifico(fontSize: 24, color: kSecondaryColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.black87),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const InterestSelectionPage(isFromSettings: true)));
              _loadInterests();
            },
          ),
          IconButton(
            icon: const Icon(Icons.forum_rounded, color: Colors.black87),
            onPressed: () {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatListPage(currentUserId: uid)));
            },
          ),
        ],
      ) : null,
      body: IndexedStack(
        index: _navIndex,
        children: [
          // 0 — Home feed
          SafeArea(
            top: _navIndex == 0,
            child: RefreshIndicator(
              key: _refreshKey,
              color: kPrimaryColor,
              onRefresh: _refreshFeed,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _StoriesStrip(),
                    Divider(height: 0.5, thickness: 0.5, color: kPrimaryColor.withValues(alpha: 0.15)),
                    _buildFeed(),
                  ],
                ),
              ),
            ),
          ),
          // 1 — Search
          _searchPage,
          // 2 — Explore
          _explorePage,
          // 3 — Add Post (placeholder — opened as modal)
          const SizedBox.shrink(),
          // 4 — Notifications
          _notifPage,
          // 5 — Profile
          _profilePage,
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: _kCardBg,
        elevation: 12,
        selectedItemColor: kSecondaryColor,
        unselectedItemColor: Colors.grey.shade500,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _navIndex,
        onTap: (i) async {
          if (i == 3) {
            await Navigator.push(context, MaterialPageRoute(
              fullscreenDialog: true, builder: (_) => AddPostPage()));
            if (mounted) await _refreshFeed();
            return;
          }
          if (i == 0 && _navIndex == 0) {
            _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
            Future.delayed(const Duration(milliseconds: 450),
              () => _refreshKey.currentState?.show());
            return;
          }
          final wasHome = _navIndex == 0;
          setState(() => _navIndex = i);
          if (i == 0 && !wasHome) {
            unawaited(_refreshFeed());
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.favorite_border_rounded), label: ''),
          const BottomNavigationBarItem(
            icon: _ProfileNavAvatar(selected: false),
            activeIcon: _ProfileNavAvatar(selected: true),
            label: '',
          ),
        ],
      ),
    ),
    );
  }
}

// ─── Bottom-nav profile avatar (live user photo) ─────────────────────────────

class _ProfileNavAvatar extends StatelessWidget {
  final bool selected;
  const _ProfileNavAvatar({this.selected = false});

  static const _fallback = AssetImage('assets/images/Profile.png');

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _wrap(_avatar(null));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (_, snap) {
        final photo = _profilePhotoUrl(snap.data?.data());
        return _wrap(_avatar(photo));
      },
    );
  }

  Widget _avatar(String? photoUrl) {
    final url = photoUrl?.trim() ?? '';
    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: url.isNotEmpty
          ? CachedNetworkImageProvider(url)
          : _fallback,
    );
  }

  Widget _wrap(Widget avatar) {
    if (!selected) return avatar;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kSecondaryColor, width: 2),
      ),
      child: avatar,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Profile tab
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const _ProfileTab({this.onBackToHome});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loaded = false;
  String _type = 'aspirant';
  String _uid  = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final data = await _UserCache.get(uid);
      final type = data?['accountType']?.toString().toLowerCase() ?? 'aspirant';
      if (mounted) setState(() { _uid = uid; _type = type; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() { _uid = uid ?? ''; _loaded = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    final onBack = widget.onBackToHome;
    if (_type == 'wellness') {
      return wellness.WellnessProfilePage(profileUserId: _uid, onBackToHome: onBack);
    }
    if (_type == 'guru') {
      return guru.GuruProfilePage(profileUserId: _uid, onBackToHome: onBack);
    }
    return aspirant.ProfilePage(profileUserId: _uid, onBackToHome: onBack);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stories strip
// ═══════════════════════════════════════════════════════════════════════════

class _StoriesStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox(height: 100);
    return SizedBox(
      height: 100,
      child: StreamBuilder<RankedStoriesResult>(
        stream: StoryService().fetchStoriesRanked(uid),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor));
          }
          final result    = snap.data!;
          final grouped   = result.grouped;
          final friendIds = result.orderedUserIds.where((id) => id != uid).toList();
          final total     = 1 + friendIds.length;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: total,
            itemBuilder: (_, i) {
              // Self story
              if (i == 0) {
                final myStories = grouped[uid] ?? [];
                return FutureBuilder<Map<String, dynamic>?>(
                  future: _UserCache.get(uid),
                  builder: (_, s) {
                    final photo = _profilePhotoUrl(s.data);
                    final hasUnseen = myStories.any((x) => !x.viewers.contains(uid));
                    return _StoryBubble(
                      photoUrl: photo,
                      label: 'Your story',
                      hasUnseen: myStories.isNotEmpty && hasUnseen,
                      isSeen: myStories.isNotEmpty && !hasUnseen,
                      showAdd: true,
                      onTap: () {
                        if (myStories.isNotEmpty) {
                          Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => StoryViewerPage(stories: myStories)));
                        } else {
                          showModalBottomSheet(
                            context: ctx,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => const StoryUploadSheet(),
                          );
                        }
                      },
                    );
                  },
                );
              }
              // Friend stories
              final fid     = friendIds[i - 1];
              final stories = grouped[fid] ?? [];
              if (stories.isEmpty) return const SizedBox.shrink();
              final first    = stories.first;
              final hasUnseen = stories.any((s) => !s.viewers.contains(uid));
              return _StoryBubble(
                photoUrl: first.userPhotoUrl ?? '',
                label: first.username.isNotEmpty ? first.username : 'User',
                hasUnseen: hasUnseen,
                isSeen: !hasUnseen,
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => StoryViewerPage(stories: stories))),
              );
            },
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final String photoUrl;
  final String label;
  final bool hasUnseen;
  final bool isSeen;
  final bool showAdd;
  final VoidCallback onTap;

  const _StoryBubble({
    required this.photoUrl,
    required this.label,
    required this.hasUnseen,
    required this.isSeen,
    required this.onTap,
    this.showAdd = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnseen
                        ? const LinearGradient(
                            colors: [Color(0xFFF56040), Color(0xFFE1306C), Color(0xFFC13584)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight)
                        : null,
                    color: isSeen ? Colors.grey.shade400 : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? const Icon(Icons.person, size: 26, color: Colors.white70) : null,
                    ),
                  ),
                ),
                if (showAdd)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0095F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _kText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Post card
// ═══════════════════════════════════════════════════════════════════════════

class _PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> savedMap;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> allVideoDocs;

  const _PostCard({
    super.key,
    required this.postId,
    required this.data,
    required this.savedMap,
    this.allVideoDocs = const [],
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d        = widget.data;
    final userId   = (d['userId'] ?? '').toString();
    final caption  = (d['caption'] ?? '').toString().trim();
    final location = PostPlace.labelFromPostData(d);
    final tags     = (d['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate().toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: _kCardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          FutureBuilder<Map<String, dynamic>?>(
            future: userId.isNotEmpty ? _UserCache.get(userId) : Future.value(null),
            builder: (_, snap) {
              final u        = snap.data;
              final name     = (u?['username'] ?? u?['name'] ?? 'User').toString();
              final photo    = _profilePhotoUrl(u);
              final accType  = (u?['accountType'] ?? 'aspirant').toString().toLowerCase();
              return _PostHeader(
                username: name, photoUrl: photo,
                subtitle: location.isNotEmpty ? location : null,
                accountType: accType, userId: userId,
              );
            },
          ),

          // Media
          _PostMedia(postId: widget.postId, data: d, allVideoDocs: widget.allVideoDocs),

          // Actions
          _PostActions(postId: widget.postId, savedMap: widget.savedMap),

          // Like count
          _LikeCount(postId: widget.postId, data: d),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  caption,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, color: _kText, height: 1.4),
                ),
              ),
            ),

          // Tags
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 4,
                children: tags.map((t) => Text('#$t',
                  style: const TextStyle(color: Color(0xFF00376B), fontSize: 13.5))).toList(),
              ),
            ),

          // Timestamp
          if (createdAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Text(_timeAgo(createdAt),
                style: const TextStyle(color: _kSubText, fontSize: 10)),
            ),

        ],
      ),
    );
  }
}

// ─── Post header ──────────────────────────────────────────────────────────────

class _PostHeader extends StatelessWidget {
  final String username, photoUrl, accountType, userId;
  final String? subtitle;

  const _PostHeader({
    required this.username,
    required this.photoUrl,
    required this.accountType,
    required this.userId,
    this.subtitle,
  });

  void _openProfile(BuildContext ctx) {
    if (userId.isEmpty) return;
    Widget page;
    if (accountType == 'wellness')    page = wellness.WellnessProfilePage(profileUserId: userId);
    else if (accountType == 'guru')   page = guru.GuruProfilePage(profileUserId: userId);
    else                              page = aspirant.ProfilePage(profileUserId: userId);
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openProfile(context),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white70) : null,
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
                  Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _kText)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: _kSubText)),
                ],
              ),
            ),
          ),
          const Icon(Icons.more_horiz, size: 20, color: _kText),
        ],
      ),
    );
  }
}

// ─── Post media ───────────────────────────────────────────────────────────────

class _PostMedia extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> allVideoDocs;
  const _PostMedia({
    required this.postId,
    required this.data,
    this.allVideoDocs = const [],
  });
  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  void _openReelViewer(BuildContext context, String tappedPostId) {
    // Build reel list from allVideoDocs — every video post regardless of processed status
    final reels = widget.allVideoDocs.map((doc) {
      final d = doc.data();
      final urls = resolveFeedVideoUrls(postData: d);
      if (urls.primary.isEmpty) return null;

      var thumb = '';
      final mediaItem = firstVideoMediaItem(d);
      if (mediaItem != null) {
        for (final k in ['thumbnail', 'thumbnailUrl', 'previewUrl']) {
          final v = (mediaItem[k] ?? '').toString().trim();
          if (v.isNotEmpty) { thumb = v; break; }
        }
      }
      if (thumb.isEmpty) {
        for (final k in ['thumbnailUrl', 'previewUrl', 'thumbnail']) {
          final v = (d[k] ?? '').toString().trim();
          if (v.isNotEmpty) { thumb = v; break; }
        }
      }

      return _FeedReelItem(
        postId: doc.id,
        videoUrl: urls.primary,
        fallbackVideoUrl: urls.fallback,
        thumbUrl: thumb,
        caption: (d['caption'] ?? '').toString(),
        userId: (d['userId'] ?? '').toString(),
      );
    }).whereType<_FeedReelItem>().toList(growable: false);

    if (reels.isEmpty) return;
    int start = reels.indexWhere((r) => r.postId == tappedPostId);
    if (start < 0) start = 0;

    AppVideoFocus.instance.enterFullscreenReel();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FeedReelViewer(reels: reels, initialIndex: start),
    )).whenComplete(AppVideoFocus.instance.exitFullscreenReel);
  }

  // Extract media items from the post doc
  List<Map<String, dynamic>> _mediaItems() {
    final raw = widget.data['media'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    // Legacy: single image
    final imgUrl = (widget.data['imageUrl'] ?? widget.data['photoUrl'] ?? '').toString().trim();
    if (imgUrl.isNotEmpty) return [{'type': 'image', 'url': imgUrl}];
    return [];
  }

  String _thumbOf(Map<String, dynamic> m) {
    for (final k in ['thumbnail', 'thumbnailUrl', 'previewUrl']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    // Fallback to doc-level
    for (final k in ['thumbnailUrl', 'previewUrl']) {
      final v = (widget.data[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// Processed MP4 first on iOS and Android; HLS only when no MP4 exists.
  String _videoOf(Map<String, dynamic> m) {
    return resolveFeedVideoUrls(postData: widget.data, mediaItem: m).primary;
  }

  @override
  Widget build(BuildContext context) {
    final items = _mediaItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final count = items.length;
    final w = MediaQuery.of(context).size.width;
    final h = (w * 5 / 4).clamp(260.0, 480.0);

    return Stack(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _pc,
            itemCount: count,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final m    = items[i];
              final type = (m['type'] ?? 'image').toString();
              if (type == 'video') {
                final urls = resolveFeedVideoUrls(postData: widget.data, mediaItem: m);
                final vUrl  = urls.primary;
                final thumb = _thumbOf(m);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _InlineVideoPlayer(
                      videoUrl: vUrl,
                      fallbackVideoUrl: urls.fallback,
                      thumbUrl: thumb,
                      postId: widget.postId,
                    ),
                    // Fullscreen button — top-right — opens reel viewer
                    Positioned(
                      top: 10, right: 10,
                      child: GestureDetector(
                        onTap: () => _openReelViewer(context, widget.postId),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.open_in_full_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              }
              final url = (m['url'] ?? '').toString().trim();
              if (url.isEmpty) return const ColoredBox(color: Color(0xFFF0F0F0));
              return CachedNetworkImage(
                imageUrl: url, fit: BoxFit.cover,
                width: double.infinity, height: h,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFF0F0F0)),
                errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFEEEEEE)),
              );
            },
          ),
        ),
        if (count > 1) ...[
          // Counter top-right
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('${_page + 1}/$count',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          // Dot indicators
          Positioned(
            left: 0, right: 0, bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count.clamp(0, 10), (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? kPrimaryColor : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Inline video player — plays inside the feed card ────────────────────────

class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String fallbackVideoUrl;
  final String thumbUrl;
  final String postId;
  const _InlineVideoPlayer({
    required this.videoUrl,
    this.fallbackVideoUrl = '',
    required this.thumbUrl,
    this.postId = '',
  });
  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  static const double _kInitFraction = 0.12;
  static const double _kTeardownFraction = 0.04;
  static const Duration _kTeardownDelay = Duration(milliseconds: 450);
  static const Duration _kInitRetryDelay = Duration(milliseconds: 120);

  String get _owner => widget.postId.isNotEmpty
      ? 'home_inline:${widget.postId}'
      : 'home_inline';

  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _initing = false;
  bool _error = false;
  bool _acquired = false;
  bool _initRetryScheduled = false;
  double _lastVisibleFraction = 0;
  Timer? _teardownTimer;

  @override
  void initState() {
    super.initState();
    AppVideoFocus.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _teardownTimer?.cancel();
    AppVideoFocus.instance.removeListener(_onFocusChange);
    final c = _ctrl;
    _ctrl = null;
    c?.removeListener(_onCtrl);
    try {
      c?.pause();
      c?.dispose();
    } catch (_) {}
    if (_acquired) {
      VideoDecoderBudget.instance.release(_owner);
      _acquired = false;
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (AppVideoFocus.instance.isFullscreenReel) {
      _teardownTimer?.cancel();
      unawaited(_teardown(keepError: false));
    } else if (_lastVisibleFraction >= _kInitFraction &&
        _ctrl == null &&
        !_error &&
        !_initing) {
      _init();
    }
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted || AppVideoFocus.instance.isFullscreenReel) return;
    _lastVisibleFraction = info.visibleFraction;
    final v = info.visibleFraction;

    if (v >= _kInitFraction) {
      _teardownTimer?.cancel();
      if (_ctrl == null && !_error && !_initing) {
        _init();
      }
      return;
    }

    if (v < _kTeardownFraction && _ctrl != null) {
      _scheduleTeardown();
    }
  }

  void _scheduleTeardown() {
    if (_teardownTimer?.isActive ?? false) return;
    _teardownTimer = Timer(_kTeardownDelay, () {
      if (!mounted) return;
      if (_lastVisibleFraction < _kTeardownFraction && _ctrl != null) {
        unawaited(_teardown(keepError: false));
      }
    });
  }

  void _scheduleInitRetry() {
    if (_initRetryScheduled || _ctrl != null || _initing) return;
    _initRetryScheduled = true;
    Future.delayed(_kInitRetryDelay, () {
      _initRetryScheduled = false;
      if (!mounted || _ctrl != null || _error || _initing) return;
      if (AppVideoFocus.instance.isFullscreenReel) return;
      if (_lastVisibleFraction >= _kInitFraction) _init();
    });
  }

  Future<void> _teardown({required bool keepError}) async {
    _teardownTimer?.cancel();
    _initing = false;
    final c = _ctrl;
    _ctrl = null;
    if (c != null) {
      c.removeListener(_onCtrl);
      await VideoDisposeSerial.instance.run(() async {
        try {
          c.pause();
          await c.dispose();
        } catch (_) {}
      });
    }
    if (_acquired) {
      VideoDecoderBudget.instance.release(_owner);
      _acquired = false;
    }
    if (mounted) {
      setState(() {
        _ready = false;
        if (!keepError) _error = false;
      });
    }
  }

  void _init() {
    if (AppVideoFocus.instance.isFullscreenReel) return;
    if (widget.videoUrl.isEmpty) {
      setState(() => _error = true);
      return;
    }
    if (_ctrl != null || _initing) return;
    if (!VideoDecoderBudget.instance.tryAcquire(_owner)) {
      _scheduleInitRetry();
      return;
    }
    _acquired = true;
    _initing = true;
    if (mounted) setState(() {});

    _createAndInitController(widget.videoUrl.trim());
  }

  void _createAndInitController(String url) {
    if (url.isEmpty) {
      if (_acquired) {
        VideoDecoderBudget.instance.release(_owner);
        _acquired = false;
      }
      if (mounted) setState(() { _initing = false; _error = true; });
      return;
    }

    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    _ctrl = c;
    c.addListener(_onCtrl);
    c.initialize().catchError((_) async {
      final alt = widget.fallbackVideoUrl.trim();
      if (alt.isNotEmpty && alt != url) {
        try {
          c.removeListener(_onCtrl);
          await c.dispose();
        } catch (_) {}
        _ctrl = null;
        if (mounted) _createAndInitController(alt);
        return;
      }
      if (_acquired) {
        VideoDecoderBudget.instance.release(_owner);
        _acquired = false;
      }
      if (mounted) setState(() { _initing = false; _error = true; });
    });
  }

  void _onCtrl() {
    if (!mounted) return;
    final c = _ctrl;
    if (c == null) return;
    if (!_ready && c.value.isInitialized) {
      c.setLooping(true);
      c.setVolume(0.0);
      c.play();
      setState(() { _ready = true; _initing = false; });
    }
    if (c.value.hasError && !_error) {
      setState(() { _error = true; _initing = false; });
    }
  }

  bool _showHeart = false;

  void _toggle() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    setState(() { c.value.isPlaying ? c.pause() : c.play(); });
  }

  Future<void> _doubleTapLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
    try {
      await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('likes').doc(uid)
          .set({'userId': uid, 'likedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.thumbUrl;
    return VisibilityDetector(
      key: Key('home_inline_${widget.postId}_${widget.videoUrl.hashCode}'),
      onVisibilityChanged: _onVisibility,
      child: GestureDetector(
      onTap: _toggle,
      onDoubleTap: _doubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail always shown (instant background)
          if (thumb.isNotEmpty)
            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black))
          else
            const ColoredBox(color: Colors.black),

          // Video on top when ready
          if (_ready && _ctrl != null)
            Builder(builder: (_) {
              final c = _ctrl;
              if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              );
            }),

          // Buffering / init progress at top
          if (_initing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                minHeight: 2,
              ),
            )
          else if (_ready && _ctrl != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _ctrl!,
                builder: (_, val, __) {
                  if (!val.isBuffering) return const SizedBox(height: 2);
                  return const LinearProgressIndicator(
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                    minHeight: 2,
                  );
                },
              ),
            ),

          // Play icon — shown when idle (not loading)
          if (!_error && !_ready && !_initing)
            const Center(child: Icon(Icons.play_circle_fill_rounded,
                color: Colors.white70, size: 56)),
          if (!_error && _ready && _ctrl != null)
            Builder(builder: (_) {
              final c = _ctrl;
              if (c == null) return const SizedBox.shrink();
              return ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, val, __) => val.isPlaying
                    ? const SizedBox.shrink()
                    : const Center(child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white70, size: 56)),
              );
            }),

          if (_error)
            const Center(child: Icon(Icons.videocam_off, color: Colors.white38, size: 40)),

          // Double-tap heart animation
          if (_showHeart)
            Center(
              child: AnimatedOpacity(
                opacity: _showHeart ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.favorite, color: Colors.white, size: 90,
                    shadows: [Shadow(blurRadius: 12, color: Colors.black54)]),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

// ─── Post actions ─────────────────────────────────────────────────────────────

class _PostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> savedMap;
  const _PostActions({required this.postId, required this.savedMap});
  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> with SingleTickerProviderStateMixin {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  Future<void> _toggleLike() async {
    if (_uid == null) return;
    _anim.forward(from: 0);
    final ref = FirebaseFirestore.instance
        .collection('posts').doc(widget.postId)
        .collection('likes').doc(_uid);
    final doc = await ref.get();
    doc.exists ? await ref.delete()
               : await ref.set({'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          // Like
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _uid != null
                ? FirebaseFirestore.instance
                    .collection('posts').doc(widget.postId)
                    .collection('likes').doc(_uid!).snapshots()
                : const Stream.empty(),
            builder: (_, snap) {
              final liked = snap.data?.exists ?? false;
              return ScaleTransition(
                scale: _scale,
                child: IconButton(
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? _kLikeRed : _kText, size: 26),
                  onPressed: _toggleLike,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              );
            },
          ),
          // Comment
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: _kText, size: 24),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _CommentsPage(postId: widget.postId))),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          // Share
          IconButton(
            icon: const Icon(Icons.send_outlined, color: _kText, size: 23),
            onPressed: () {},
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          // Save
          SaveButton(
            postId: widget.postId,
            currentUserId: _uid,
            savedPostsMap: widget.savedMap,
            iconSize: 24,
            color: _kText,
          ),
        ],
      ),
    );
  }
}

// ─── Like count ────────────────────────────────────────────────────────────────

class _LikeCount extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  const _LikeCount({required this.postId, required this.data});

  @override
  Widget build(BuildContext context) {
    final uid   = FirebaseAuth.instance.currentUser?.uid;
    final count = _asInt(data['likeCount'] ?? data['likesCount']);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid != null
          ? FirebaseFirestore.instance
              .collection('posts').doc(postId)
              .collection('likes').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (_, snap) {
        final myLike = snap.data?.exists ?? false;
        if (count == 0 && !myLike) return const SizedBox.shrink();
        final text = myLike && count <= 1 ? 'Liked by you'
          : myLike ? 'Liked by you and ${count - 1} ${count - 1 == 1 ? 'other' : 'others'}'
          : '$count ${count == 1 ? 'like' : 'likes'}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: _kText)),
        );
      },
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ─── Feed reel model ──────────────────────────────────────────────────────────

class _FeedReelItem {
  final String postId;
  final String videoUrl;
  final String fallbackVideoUrl;
  final String thumbUrl;
  final String caption;
  final String userId;
  const _FeedReelItem({
    required this.postId,
    required this.videoUrl,
    this.fallbackVideoUrl = '',
    required this.thumbUrl,
    required this.caption,
    required this.userId,
  });
}

// ─── Full-screen reel viewer (opened from home feed) ─────────────────────────

class _FeedReelViewer extends StatefulWidget {
  final List<_FeedReelItem> reels;
  final int initialIndex;
  const _FeedReelViewer({required this.reels, required this.initialIndex});
  @override
  State<_FeedReelViewer> createState() => _FeedReelViewerState();
}

class _FeedReelViewerState extends State<_FeedReelViewer> {
  static const String _kOwner = 'feed_reel_viewer';
  late PageController _pc;
  int _page = 0;
  final Map<int, VideoPlayerController> _ctrls = {};
  final Set<int> _initing = {};
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _pc = PageController(initialPage: _page);
    AppVideoFocus.instance.enterFullscreenReel();
    // Start the tapped reel immediately — no waiting for a frame
    if (widget.reels[_page].videoUrl.isNotEmpty &&
        VideoDecoderBudget.instance.tryAcquire(_kOwner)) {
      _initing.add(_page);
      unawaited(_initCtrl(_page, widget.reels[_page], true));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    AppVideoFocus.instance.exitFullscreenReel();
    _pc.dispose();
    for (final c in _ctrls.values) { c.pause(); c.dispose(); VideoDecoderBudget.instance.release(_kOwner); }
    _ctrls.clear();
    VideoDecoderBudget.instance.releaseAll(_kOwner);
    super.dispose();
  }

  Set<int> _win() =>
      ReelPreloadPolicy.warmIndices(_page, widget.reels.length);

  Future<void> _sync() async {
    if (!mounted || _syncing) return;
    _syncing = true;
    try {
      final keep = _win();
      for (final idx in _ctrls.keys.where((k) => !keep.contains(k)).toList()) {
        final c = _ctrls.remove(idx);
        _initing.remove(idx);
        await VideoDisposeSerial.instance.run(() async {
          try {
            await c?.dispose();
          } catch (_) {}
          VideoDecoderBudget.instance.release(_kOwner);
        });
      }
      for (final idx in ReelPreloadPolicy.initOrder(_page, widget.reels.length)) {
        if (!mounted) break;
        if (!keep.contains(idx)) continue;
        if (_ctrls.containsKey(idx) || _initing.contains(idx)) continue;
        if (_ctrls.length + _initing.length >= ReelPreloadPolicy.maxWarmSlots) {
          break;
        }
        final reel = widget.reels[idx];
        if (reel.videoUrl.isEmpty) continue;
        if (!VideoDecoderBudget.instance.tryAcquire(_kOwner)) break;
        _initing.add(idx);
        if (mounted) setState(() {});
        await _initCtrl(idx, reel, idx == _page);
      }
      _applyPlayback();
      if (mounted) setState(() {});
    } finally {
      _syncing = false;
    }
  }

  Future<void> _initCtrl(int idx, _FeedReelItem reel, bool active) async {
    var url = reel.videoUrl.trim();
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    try {
      await c.initialize();
      if (!mounted) { c.dispose(); VideoDecoderBudget.instance.release(_kOwner); return; }
      await c.setLooping(true);
      await c.setVolume(active ? 1.0 : 0.0);
      if (active) await c.play();
      _ctrls[idx] = c;
      if (mounted) setState(() {});
    } catch (_) {
      final alt = reel.fallbackVideoUrl.trim();
      if (alt.isNotEmpty && alt != url) {
        try {
          await c.dispose();
        } catch (_) {}
        url = alt;
        final c2 = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
          httpHeaders: const {'Connection': 'keep-alive'},
        );
        try {
          await c2.initialize();
          if (!mounted) {
            await c2.dispose();
            VideoDecoderBudget.instance.release(_kOwner);
            return;
          }
          await c2.setLooping(true);
          await c2.setVolume(active ? 1.0 : 0.0);
          if (active) await c2.play();
          _ctrls[idx] = c2;
          if (mounted) setState(() {});
        } catch (_) {
          try {
            await c2.dispose();
          } catch (_) {}
          VideoDecoderBudget.instance.release(_kOwner);
        }
      } else {
        try {
          await c.dispose();
        } catch (_) {}
        VideoDecoderBudget.instance.release(_kOwner);
      }
    } finally {
      _initing.remove(idx);
      if (mounted) setState(() {});
    }
  }

  void _applyPlayback() {
    for (final e in _ctrls.entries) {
      try {
        if (e.key == _page) { e.value.setVolume(1.0); if (!e.value.value.isPlaying) e.value.play(); }
        else                { e.value.setVolume(0.0); if (e.value.value.isPlaying) e.value.pause(); }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pc,
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: false,
        itemCount: widget.reels.length,
        onPageChanged: (i) {
          setState(() => _page = i);
          unawaited(_sync());
        },
        itemBuilder: (_, i) {
          final reel  = widget.reels[i];
          final c     = _ctrls[i];
          final ready = c != null && c.value.isInitialized;
          return _FeedReelPage(
            key: ValueKey(reel.postId),
            reel: reel,
            ctrl: c,
            ready: ready,
            preloadSurface: i == _page || i == _page + 1,
            loading: _initing.contains(i),
            onToggle: () {
              if (c == null || !c.value.isInitialized) return;
              setState(() { c.value.isPlaying ? c.pause() : c.play(); });
            },
          );
        },
      ),
    );
  }
}

class _FeedReelPage extends StatelessWidget {
  final _FeedReelItem reel;
  final VideoPlayerController? ctrl;
  final bool ready;
  final bool preloadSurface;
  final bool loading;
  final VoidCallback onToggle;

  const _FeedReelPage({
    super.key,
    required this.reel,
    required this.ctrl,
    required this.ready,
    this.preloadSurface = false,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = ctrl;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (reel.thumbUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: reel.thumbUrl, fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black))
          else
            const ColoredBox(color: Colors.black),

          if (ready &&
              c != null &&
              c.value.isInitialized &&
              preloadSurface)
            FittedBox(fit: BoxFit.cover,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height,
                child: VideoPlayer(c))),

          // Loading bar at top while buffering
          if (loading || (ready && c != null && c.value.isBuffering))
            Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                minHeight: 2,
              ),
            ),

          // Play/pause icon
          if (ready && c != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (_, val, __) => AnimatedOpacity(
                opacity: val.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: const Center(child: Icon(Icons.play_circle_filled, color: Colors.white70, size: 72)),
              ),
            ),

          // Gradient + caption
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.65)],
              stops: const [0, 0.45, 1])))),

          Positioned(left: 14, right: 14, bottom: 48,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                if (reel.userId.isNotEmpty)
                  Text('@${reel.userId}', // userId as fallback label
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 14, shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
                if (reel.caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(reel.caption, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
                ],
              ])),

          if (ready && c != null)
            Positioned(left: 0, right: 0, bottom: 0,
              child: VideoProgressIndicator(c, allowScrubbing: false,
                colors: const VideoProgressColors(
                  playedColor: kPrimaryColor, bufferedColor: Colors.white24, backgroundColor: Colors.white12),
                padding: EdgeInsets.zero)),
        ],
      ),
    );
  }
}

// ─── Comments page ─────────────────────────────────────────────────────────────

class _CommentsPage extends StatefulWidget {
  final String postId;
  const _CommentsPage({required this.postId});
  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final _ctrl = TextEditingController();
  final _uid  = FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _uid == null) return;
    _ctrl.clear();
    await FirebaseFirestore.instance
        .collection('posts').doc(widget.postId)
        .collection('comments')
        .add({'userId': _uid, 'text': text, 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: kSecondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts').doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('No comments yet',
                  style: TextStyle(color: _kSubText)));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final c = docs[i].data();
                    return ListTile(
                      title: Text(c['text'] ?? '',
                        style: const TextStyle(color: _kText, fontSize: 14)),
                      subtitle: c['createdAt'] != null
                          ? Text(_timeAgo((c['createdAt'] as Timestamp).toDate().toLocal()),
                              style: const TextStyle(fontSize: 11, color: _kSubText))
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _post,
                    icon: const Icon(Icons.send_rounded, color: kSecondaryColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ──────────────────────────────────────────────────────────────────

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            _Box(w: 36, h: 36, r: 18),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Box(w: 120, h: 11, r: 4),
              const SizedBox(height: 4),
              _Box(w: 80, h: 10, r: 4),
            ]),
          ]),
        ),
        _Box(w: double.infinity, h: 280, r: 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [_Box(w: 28, h: 28, r: 14), const SizedBox(width: 10), _Box(w: 28, h: 28, r: 14)]),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFEBEBEB)),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  final double w, h, r;
  const _Box({required this.w, required this.h, required this.r});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}

// ─── Drawer ────────────────────────────────────────────────────────────────────

enum _DrawerAction { home, explore, saved, settings, logout, share }

class _Drawer extends StatelessWidget {
  final void Function(_DrawerAction) onSelect;
  const _Drawer({required this.onSelect});

  static const List<List<dynamic>> _items = [
    [Icons.home_filled,         'Home',        _DrawerAction.home],
    [Icons.explore_outlined,    'Explore',     _DrawerAction.explore],
    [Icons.bookmark_border,     'Saved Posts', _DrawerAction.saved],
    [Icons.settings_outlined,   'Settings',    _DrawerAction.settings],
    [Icons.share_rounded,       'Share App',   _DrawerAction.share],
    [Icons.logout_rounded,      'Log Out',     _DrawerAction.logout],
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF3EDFF), Color(0xFFE5E0FF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Text('MENU', style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w600, color: kSecondaryColor)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _items.map((item) {
                    final icon   = item[0] as IconData;
                    final label  = item[1] as String;
                    final action = item[2] as _DrawerAction;
                    return ListTile(
                      textColor: Colors.black,
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: kSecondaryColor, size: 20),
                      ),
                      title: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      onTap: () { Navigator.pop(context); onSelect(action); },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Version 1.0', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
