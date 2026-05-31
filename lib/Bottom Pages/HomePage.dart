// HomePage.dart — Instagram-style feed for Halo
// All bugs fixed — see fix comments tagged [FIX-n]

import 'dart:async';
import 'dart:collection';

import 'package:halo/Bottom%20Pages/AddPostPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/chat/chat_list_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/interest_selection_page.dart';
import 'package:halo/services/story_service.dart';
import 'package:halo/services/app_cache_manager.dart';
import 'package:halo/services/reel_player_lifecycle.dart';
import 'package:halo/services/video_playback_resolver.dart';
import 'package:halo/services/video_transcode_queue_service.dart';
import 'package:halo/models/story_model.dart';
import 'package:halo/models/media_model.dart';
import 'package:halo/utils/story_ranking.dart';
import 'package:halo/utils/story_utils.dart';
import 'package:halo/story/story_viewer_page.dart';
import 'package:halo/story/story_upload_sheet.dart';

import 'package:halo/services/feed_service.dart';
import 'package:halo/widgets/save_button.dart';
import 'package:halo/services/save_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'NotificationPage.dart';
import 'SearchPage.dart';
import 'ExplorePage.dart';
import 'SettingsPage.dart';
import 'saved_posts_page.dart';

// ---- THEME COLORS ----
const Color kPrimaryColor = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBackgroundColor = Color(0xFFF4F1FB);

const Color kIgPrimaryText = Color(0xFF262626);
const Color kIgSecondaryText = Color(0xFF8E8E8E);
const Color kIgLikeRed = Color(0xFFED4956);
const Color kIgPostBackground = Colors.white;

String _profilePhotoUrlFromUser(Map<String, dynamic>? data) {
  if (data == null) return '';
  final v = data['profilePhoto'] ??
      data['photoURL'] ??
      data['profile_photo'] ??
      data['avatar'];
  if (v == null) return '';
  final s = v.toString().trim();
  return s.isEmpty ? '' : s;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
  GlobalKey<RefreshIndicatorState>();
  final FeedService _feedService = FeedService();

  bool _promptedLocation = false;
  List<String> _interests = const [];
  int _feedTabIndex = 0;
  String _contentPreference = '';

  static const int _pageSize = 12;
  final ScrollController _feedScrollController = ScrollController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _posts = [];
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMoreUndated = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _undatedLastDoc;
  double _lastScrollOffset = 0;
  bool _scrollingDown = true;
  Timer? _precacheDebounce;
  int _activeDecodes = 0;
  static const int _maxConcurrentDecodes = 1;

  Future<RankedStoriesResult>? _storiesFuture;

  // [FIX-7] Store SaveService stream and BottomNav user stream in state —
  // never create streams inside build() because each call creates a new
  // subscription and defeats StreamBuilder's internal caching.
  final ValueNotifier<Map<String, dynamic>> _savedPostsNotifier =
      ValueNotifier<Map<String, dynamic>>(const <String, dynamic>{});
  StreamSubscription<Map<String, dynamic>>? _savedPostsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  // [FIX-4] Cache accountType so the BottomNav profile tap doesn't need
  // a Firestore read on every press.
  String _accountType = 'aspirant';
  String _userProfileUrl = '';

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_onFeedScroll);
    _initSideStreams();
    _storiesFuture = _loadStories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForLocation();
    });
    _loadInterests();
  }

  // [FIX-7] Streams are created once here, not in build().
  void _initSideStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    _savedPostsSub = SaveService().savedPostsStream(uid).listen((savedMap) {
      _savedPostsNotifier.value = savedMap;
    });

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      final nextType =
          (data?['accountType'] as String?)?.toLowerCase() ?? 'aspirant';
      final nextPhoto = _profilePhotoUrlFromUser(data);
      if (nextType == _accountType && nextPhoto == _userProfileUrl) return;
      setState(() {
        _accountType = nextType;
        _userProfileUrl = nextPhoto;
      });
    });
  }

  @override
  void dispose() {
    _feedScrollController.dispose();
    _precacheDebounce?.cancel();
    _savedPostsSub?.cancel();
    _userDocSub?.cancel();
    _savedPostsNotifier.dispose();
    super.dispose();
  }

  Future<RankedStoriesResult> _loadStories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const RankedStoriesResult(orderedUserIds: [], grouped: {});
    }
    final stories = await StoryService().fetchActiveStories().first;
    final grouped = groupStoriesByUser(stories);
    final userIds = grouped.keys.where((id) => id.isNotEmpty).toList();
    final relScores = await StoryService().getRelationshipScores(uid, userIds);
    final scored = <MapEntry<String, double>>[];
    for (final storyUid in userIds) {
      final list = grouped[storyUid] ?? const <StoryModel>[];
      if (list.isEmpty) continue;
      final newest = list.reduce(
          (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      final allViewers = list.expand((s) => s.viewers).toSet().toList();
      final score = storyScore(
        createdAt: newest.createdAt,
        viewers: allViewers,
        relationshipScore: relScores[storyUid] ?? 0.0,
        currentUserId: uid,
      );
      scored.add(MapEntry(storyUid, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final ordered = scored.map((e) => e.key).toList();
    if (ordered.contains(uid)) {
      ordered.remove(uid);
    }
    ordered.insert(0, uid);
    return RankedStoriesResult(orderedUserIds: ordered, grouped: grouped);
  }

  void _onFeedScroll() {
    if (!_feedScrollController.hasClients ||
        _isLoadingMore ||
        (!_hasMore && !_hasMoreUndated)) {
      return;
    }
    final position = _feedScrollController.position;
    final currentOffset = position.pixels;
    _scrollingDown = currentOffset >= _lastScrollOffset;
    _lastScrollOffset = currentOffset;

    _precacheDebounce?.cancel();
    _precacheDebounce = Timer(const Duration(milliseconds: 90), () {
      _precacheUpcomingImages();
    });
    if (position.pixels >= position.maxScrollExtent - 900) {
      _loadMorePosts();
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _isLoadingFirstPage = true;
      _isLoadingMore = false;
      _hasMore = true;
      _hasMoreUndated = true;
      _lastDoc = null;
      _undatedLastDoc = null;
      _posts.clear();
    });
    await _loadMorePosts(isRefresh: true);
    if (mounted) {
      setState(() {
        _storiesFuture = _loadStories();
      });
    }
  }

  Future<void> _loadMorePosts({bool isRefresh = false}) async {
    if ((_isLoadingMore && !isRefresh) ||
        (!_hasMore && !_hasMoreUndated && !isRefresh)) return;
    if (!mounted) return;

    setState(() {
      if (!isRefresh) _isLoadingMore = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final existingIds = _posts.map((p) => p.id).toSet();
      var addedCount = 0;

      final remainingBase = _pageSize;
      var toAppend = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      // 1) Fetch dated posts (createdAt exists)
      if (_hasMore) {
        final page = await _feedService.getRankedFeedPage(
          currentUserId: uid,
          userPreference: _contentPreference,
          followingOnly: _feedTabIndex == 1,
          limit: _pageSize,
          startAfterDoc: _lastDoc,
        );
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;

        var nextDocs = page.docs;
        if (_interests.isNotEmpty) {
          nextDocs = nextDocs.where((d) {
            final data = d.data();
            final accountType = (data['accountType'] ?? '')
                .toString()
                .toLowerCase();
            if (accountType == 'guru') return true;
            final tags = (data['tags'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
            if (tags.isEmpty) return true;
            return tags.any((t) => _interests.contains(t));
          }).toList();
        }

        for (final d in nextDocs) {
          if (existingIds.contains(d.id)) continue;
          existingIds.add(d.id);
          toAppend.add(d);
          addedCount++;
        }
      }

      // 2) Fetch undated posts (createdAt is null) with their own cursor.
      final remaining = remainingBase - addedCount;
      if (_hasMoreUndated && remaining > 0) {
        final undatedPage = await _feedService.getRankedUndatedFeedPage(
          currentUserId: uid,
          userPreference: _contentPreference,
          followingOnly: _feedTabIndex == 1,
          limit: remaining,
          startAfterDoc: _undatedLastDoc,
        );
        _undatedLastDoc = undatedPage.lastDoc;
        _hasMoreUndated = undatedPage.hasMore;

        var undatedDocs = undatedPage.docs;
        if (_interests.isNotEmpty) {
          undatedDocs = undatedDocs.where((d) {
            final data = d.data();
            final accountType = (data['accountType'] ?? '')
                .toString()
                .toLowerCase();
            if (accountType == 'guru') return true;
            final tags = (data['tags'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
            if (tags.isEmpty) return true;
            return tags.any((t) => _interests.contains(t));
          }).toList();
        }

        for (final d in undatedDocs) {
          if (existingIds.contains(d.id)) continue;
          existingIds.add(d.id);
          toAppend.add(d);
          addedCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _posts.addAll(toAppend);
        _isLoadingFirstPage = false;
        _isLoadingMore = false;
      });
      _precacheUpcomingImages();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFirstPage = false;
        _isLoadingMore = false;
      });
    }
  }

  void _precacheUpcomingImages() {
    if (!mounted || !_feedScrollController.hasClients || _posts.isEmpty) return;
    final isLargeDevice = MediaQuery.of(context).size.width >= 900;
    const estimatedItemHeight = 520.0;
    final anchor = (_feedScrollController.offset / estimatedItemHeight).floor();
    final nextIndexes = _scrollingDown
        ? <int>[anchor + 1, anchor + 2]
        : <int>[anchor - 1, anchor - 2];
    final valid = nextIndexes.where((i) => i >= 0 && i < _posts.length).toList(growable: false);
    for (var i = 0; i < valid.length; i++) {
      final postIndex = valid[i];
      final data = _posts[postIndex].data();
      final media = MediaModel.parsePostMedia(data);
      if (media.isNotEmpty) {
        final first = media.first;
        if (first.isVideo) {
          final thumb = first.thumbnail.trim().isNotEmpty
              ? first.thumbnail.trim()
              : (data['thumbnailUrl'] ?? data['thumbUrl'] ?? '').toString().trim();
          if (thumb.isNotEmpty) {
            if (i == 0) {
              unawaited(_throttledPrecacheImageUrl(thumb));
            } else {
              SchedulerBinding.instance.scheduleTask<void>(
                () async {
                  await Future<void>.delayed(const Duration(milliseconds: 60));
                  await _throttledPrecacheImageUrl(thumb);
                },
                Priority.idle,
              );
            }
          }
          continue;
        }
        final url = first.image.forFeedByDevice(isLargeDevice);
        if (url.isNotEmpty) {
          if (i == 0) {
            unawaited(_throttledPrecacheImageUrl(url));
          } else {
            SchedulerBinding.instance.scheduleTask<void>(
              () async {
                await Future<void>.delayed(const Duration(milliseconds: 60));
                await _throttledPrecacheImageUrl(url);
              },
              Priority.idle,
            );
          }
        }
        continue;
      }
      final images = List<String>.from(data['images'] ?? const []);
      final imageUrl = images.isNotEmpty ? images.first.trim() : '';
      final fallback = (data['imageUrl'] as String?)?.trim() ?? '';
      var url = imageUrl.isNotEmpty ? imageUrl : fallback;
      final lower = url.toLowerCase();
      if (url.isNotEmpty &&
          (lower.contains('.mp4') || lower.contains('.m3u8'))) {
        final th = (data['thumbnailUrl'] ?? data['thumbUrl'] ?? '').toString().trim();
        if (th.isNotEmpty) url = th;
      }
      if (url.isNotEmpty) {
        if (i == 0) {
          unawaited(_throttledPrecacheImageUrl(url));
        } else {
          SchedulerBinding.instance.scheduleTask<void>(
            () async {
              await Future<void>.delayed(const Duration(milliseconds: 60));
              await _throttledPrecacheImageUrl(url);
            },
            Priority.idle,
          );
        }
      }
    }
  }

  /// Same [AppCacheManager.media] + decode size as feed [CachedNetworkImage] tiles.
  Future<void> _throttledPrecacheImageUrl(String url) async {
    if (!mounted || url.isEmpty) return;
    if (_activeDecodes >= _maxConcurrentDecodes) return;
    _activeDecodes++;
    try {
      final mq = MediaQuery.of(context);
      final provider = CachedNetworkImageProvider(
        url,
        cacheManager: AppCacheManager.media,
      );
      await precacheImage(
        provider,
        context,
        size: Size(mq.size.width, 300),
      );
    } finally {
      _activeDecodes--;
    }
  }

  Future<void> _loadInterests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interests = prefs.getStringList('user_interests') ?? const [];
      if (!mounted) return;
      setState(() => _interests = interests);
    } catch (_) {}
    if (mounted) {
      await _refreshFeed();
    }
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
      builder: (context) => AlertDialog(
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
                  const SnackBar(content: Text('Location permission granted')),
                );
              } else if (result.isPermanentlyDenied) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Location permission permanently denied. Open settings to enable.'),
                    action: SnackBarAction(
                        label: 'Settings', onPressed: openAppSettings),
                  ),
                );
              }
              await prefs.setBool('location_prompt_shown', true);
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await prefs.setBool('location_prompt_shown', true);
  }

  // [FIX-13] Logout is now handled explicitly instead of falling through
  // to _showFeaturePlaceholder.
  Future<void> _onMenuAction(_HaloMenuAction action) async {
    switch (action) {
      case _HaloMenuAction.home:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already on Home')),
        );
        return;
      case _HaloMenuAction.feed:
        if (!mounted) return;
        setState(() => _feedTabIndex = 0);
        await _refreshFeed();
        return;
      case _HaloMenuAction.premium:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedPostsPage()),
        );
        return;
      case _HaloMenuAction.wellness:
        if (!mounted) return;
        _openMyProfile();
        return;
      case _HaloMenuAction.challenges:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InterestSelectionPage(isFromSettings: true),
          ),
        );
        if (!mounted) return;
        await _loadInterests();
        return;
      case _HaloMenuAction.profileSettings:
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettingsPage()),
        );
        if (!mounted) return;
        if (result == 'logout') {
          await _onMenuAction(_HaloMenuAction.logout);
        } else if (result == 'edit_profile') {
          _openMyProfile();
        }
        return;
      case _HaloMenuAction.events:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NotificationPage()),
        );
        return;
      case _HaloMenuAction.analytics:
        if (!mounted) return;
        _openMyProfile();
        return;
      case _HaloMenuAction.gurus:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SearchPage()),
        );
        return;
      case _HaloMenuAction.logout:
        try {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          // AuthGate listens to authStateChanges and will render LoginPage.
          Navigator.of(context).popUntil((route) => route.isFirst);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sign-out failed: $e')));
        }
        return;
      case _HaloMenuAction.email:
        await _openSupportEmail();
        return;
      case _HaloMenuAction.share:
        await _shareAppLink();
        return;
      case _HaloMenuAction.customerCare:
        await _openCustomerCare();
        return;
      default:
        _showFeaturePlaceholder(action.name);
    }
  }

  void _showFeaturePlaceholder(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature coming soon!')));
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri.parse(
      'mailto:support@haloapp.in?subject=${Uri.encodeComponent('Halo Support')}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  Future<void> _shareAppLink() async {
    const appLink = 'https://haloapp.in';
    const message = 'Check out Halo: https://haloapp.in';
    await Clipboard.setData(const ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App link copied to clipboard')),
    );
    final uri = Uri.parse(
      'sms:?body=${Uri.encodeComponent('Check out Halo: $appLink')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCustomerCare() async {
    final phoneUri = Uri.parse('tel:+919999999999');
    final openedDialer = await launchUrl(
      phoneUri,
      mode: LaunchMode.externalApplication,
    );
    if (openedDialer || !mounted) return;
    await _openSupportEmail();
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
              offset: const Offset(0, 2)),
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
        onTap: () {
          if (_feedTabIndex == index) return;
          setState(() => _feedTabIndex = index);
          _refreshFeed();
        },
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

  // [FIX-3] Navigate to profile using cached _accountType — no Firestore
  // read at tap time.
  Future<void> _openMyProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to view profile')));
      return;
    }
    var effectiveType = _accountType;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final freshType =
          (doc.data()?['accountType'] as String?)?.toLowerCase().trim();
      if (freshType != null && freshType.isNotEmpty) {
        effectiveType = freshType;
        if (mounted && effectiveType != _accountType) {
          setState(() => _accountType = effectiveType);
        }
      }
    } catch (_) {
      // Use cached account type if profile fetch fails.
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileRouterScreen(profileUserId: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: GestureDetector(
        // [FIX-14] Use push instead of pushReplacement so the back-stack
        // is preserved when opening chat via swipe or icon.
        onHorizontalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to use chat')));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatListPage(currentUserId: uid)),
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
                    color: kSecondaryColor),
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
                          builder: (_) => const InterestSelectionPage(
                              isFromSettings: true)),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please sign in to use chat')));
                      return;
                    }
                    // [FIX-14] push, not pushReplacement
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatListPage(currentUserId: uid)),
                    );
                  },
                ),
              ],
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF5EDFF), Color(0xFFE8E4FF)],
                  ),
                ),
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF5EDFF),
                  Color(0xFFE8E4FF),
                  kBackgroundColor,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                key: _refreshKey,
                onRefresh: _refreshFeed,
                child: ListView.builder(
                  controller: _feedScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: 1100,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
                  itemCount: 2 + (_posts.isEmpty ? 1 : _posts.length) + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          _StoriesStrip(future: _storiesFuture),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    if (index == 1) {
                      return Column(
                        children: [
                          _buildFeedSegmentedControl(),
                          const SizedBox(height: 8),
                        ],
                      );
                    }

                    if (_posts.isEmpty) {
                      if (_isLoadingFirstPage) {
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 40, color: Colors.grey.shade500),
                            const SizedBox(height: 8),
                            Text(
                              'No posts yet',
                              style: textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Follow more people or add your first post.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    final footerIndex = 2 + _posts.length;
                    if (index == footerIndex) {
                      if (_isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return const SizedBox(height: 8);
                    }

                    final feedIndex = index - 2;
                    return _PostItem(
                      key: ValueKey(_posts[feedIndex].id),
                      postDoc: _posts[feedIndex],
                      savedPostsListenable: _savedPostsNotifier,
                    );
                  },
                ),
              ),
            ),
          ),

          // [FIX-8] BottomNav no longer has a StreamBuilder — user data is
          // already cached in _userProfileUrl and _accountType via the
          // listener set up in _initSideStreams().
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: 0,
            backgroundColor: Colors.white,
            elevation: 12,
            selectedItemColor: kSecondaryColor,
            unselectedItemColor: Colors.grey.shade500,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: (index) {
              if (index == 0) return;
              if (index == 1) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SearchPage()));
              } else if (index == 2) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ExplorePage()));
              } else if (index == 3) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddPostPage()));
              } else if (index == 4) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NotificationPage()));
              } else if (index == 5) {
                // [FIX-4] No Firestore call — use cached _accountType
                _openMyProfile();
              }
            },
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.explore_rounded), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add_box_outlined), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_outline_rounded), label: ''),
              BottomNavigationBarItem(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey.shade200,
                  child: ClipOval(
                    child: _userProfileUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: _userProfileUrl,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey),
                    )
                        : const Icon(Icons.person,
                        size: 16, color: Colors.grey),
                  ),
                ),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------- Post Header ----------------------

class _PostHeader extends StatelessWidget {
  final String username;
  final String profilePhotoUrl;
  final String subtitle;
  final VoidCallback? onTap;

  const _PostHeader({
    Key? key,
    required this.username,
    required this.profilePhotoUrl,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: profilePhotoUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: profilePhotoUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Icon(Icons.person,
                  color: Colors.grey, size: 24),
              errorWidget: (_, __, ___) => Image.asset(
                  'assets/images/Profile.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover),
            )
                : Image.asset('assets/images/Profile.png',
                width: 40, height: 40, fit: BoxFit.cover),
          ),
        ),
      ),
      title: GestureDetector(
        onTap: onTap,
        child: Text(
          username,
          style: (textTheme.labelLarge ?? textTheme.bodyLarge)?.copyWith(
              fontWeight: FontWeight.w600,
              color: kIgPrimaryText,
              fontSize: 15),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall
            ?.copyWith(color: kIgSecondaryText, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz_rounded),
        iconSize: 26,
        onPressed: () {},
      ),
      onTap: onTap,
    );
  }
}

// ---------------------- Post Image ----------------------

class _PostImage extends StatelessWidget {
  final String url;
  final String thumbUrl;
  const _PostImage({Key? key, required this.url, this.thumbUrl = ''}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dpr = mq.devicePixelRatio;
    final decodeWidth = (mq.size.width * dpr).round();
    final decodeHeight = (300 * dpr).round();
    final deferLoading = Scrollable.recommendDeferredLoadingForContext(context);
    final fallbackUrl = url.replaceAll('.webp', '.jpg');
    return RepaintBoundary(
      child: deferLoading
          ? (thumbUrl.isNotEmpty
          ? CachedNetworkImage(
        imageUrl: thumbUrl,
        cacheManager: AppCacheManager.media,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        memCacheWidth: decodeWidth,
      )
          : Container(height: 250, color: Colors.grey.shade200))
          : CachedNetworkImage(
        imageUrl: url,
        cacheManager: AppCacheManager.media,
        width: double.infinity,
        memCacheWidth: decodeWidth,
        fit: BoxFit.fitWidth,
        fadeInDuration: const Duration(milliseconds: 140),
        placeholder: (_, __) => thumbUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: thumbUrl,
          cacheManager: AppCacheManager.media,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          memCacheWidth: decodeWidth,
          placeholder: (_, __) => Container(height: 250, color: Colors.grey.shade200),
          errorWidget: (_, __, ___) => Container(height: 250, color: Colors.grey.shade200),
        )
            : Container(height: 250, color: Colors.grey.shade200),
        errorWidget: (_, __, ___) => fallbackUrl != url
            ? Image.network(
          fallbackUrl,
          width: double.infinity,
          fit: BoxFit.fitWidth,
        )
            : Container(
          height: 250,
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }
}

// ---------------------- Stories Strip ----------------------

class _StoriesStrip extends StatelessWidget {
  final Future<RankedStoriesResult>? future;
  const _StoriesStrip({Key? key, required this.future}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid.isEmpty) {
      return const SizedBox(height: 110);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                'Stories',
                style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.grey.shade900),
              ),
              const Spacer(),
              Text(
                'See all',
                style: textTheme.bodySmall?.copyWith(
                    color: kSecondaryColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: FutureBuilder<RankedStoriesResult>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }
              final result = snapshot.data ??
                  const RankedStoriesResult(orderedUserIds: [], grouped: {});
              final groupedStories = result.grouped;
              final userIds = <String>[
                myUid,
                ...result.orderedUserIds.where((id) => id != myUid),
              ];

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: userIds.length,
                itemBuilder: (context, index) {
                  final userId = userIds[index];
                  if (userId == myUid) {
                    final myStories = groupedStories[myUid] ?? [];
                    final hasStories = myStories.isNotEmpty;
                    final hasUnseen =
                        myStories.any((s) => !s.viewers.contains(myUid));
                    final photoUrl = hasStories ? myStories.first.userPhotoUrl : null;
                    return GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const StoryUploadSheet(),
                        );
                      },
                      onLongPress: () {
                        if (!hasStories) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => StoryViewerPage(stories: myStories)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                _StoryAvatar(
                                  imageUrl: photoUrl,
                                  hasUnseen: hasStories && hasUnseen,
                                  isSeen: hasStories && !hasUnseen,
                                ),
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.blue,
                                    child: Icon(Icons.add,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text('Your story',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  }

                  final stories = groupedStories[userId] ?? [];
                  if (stories.isEmpty) return const SizedBox.shrink();
                  final hasUnseen = stories.any((s) => !s.viewers.contains(myUid));
                  final first = stories.first;
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StoryViewerPage(stories: stories)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StoryAvatar(
                            imageUrl: first.userPhotoUrl,
                            hasUnseen: hasUnseen,
                            isSeen: !hasUnseen,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 70,
                            child: Text(
                              first.username.isNotEmpty ? first.username : 'User',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                  fontSize: 12, color: Colors.black87),
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
      ],
    );
  }
}

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
            shape: BoxShape.circle, color: Colors.white),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: (imageUrl ?? '').isNotEmpty
                ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.person,
                  size: 28, color: Colors.white70),
            )
                : const Icon(Icons.person,
                size: 28, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

// ---------------------- Drawer ----------------------

enum _HaloMenuAction {
  home,
  feed,
  premium,
  wellness,
  challenges,
  profileSettings,
  events,
  analytics,
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

  const _DrawerItemData(
      {required this.icon, required this.label, required this.action});
}

class _HaloDrawer extends StatelessWidget {
  final Future<void> Function(_HaloMenuAction) onSelect;

  const _HaloDrawer({Key? key, required this.onSelect}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryItems = [
      _DrawerItemData(
          icon: Icons.home_filled,
          label: 'Home',
          action: _HaloMenuAction.home),
      _DrawerItemData(
          icon: Icons.article_outlined,
          label: 'Feed',
          action: _HaloMenuAction.feed),
      _DrawerItemData(
          icon: Icons.local_fire_department,
          label: 'Premium Content & Features',
          action: _HaloMenuAction.premium),
      _DrawerItemData(
          icon: Icons.self_improvement,
          label: 'Wellness',
          action: _HaloMenuAction.wellness),
      _DrawerItemData(
          icon: Icons.timer_outlined,
          label: 'Challenges',
          action: _HaloMenuAction.challenges),
      _DrawerItemData(
          icon: Icons.person_outline,
          label: 'Profile Settings',
          action: _HaloMenuAction.profileSettings),
      _DrawerItemData(
          icon: Icons.public,
          label: 'Events',
          action: _HaloMenuAction.events),
      _DrawerItemData(
          icon: Icons.bar_chart,
          label: 'Analytics & Insight',
          action: _HaloMenuAction.analytics),
      _DrawerItemData(
          icon: Icons.school_outlined,
          label: 'Gurus',
          action: _HaloMenuAction.gurus),
      _DrawerItemData(
          icon: Icons.logout,
          label: 'Log Out',
          action: _HaloMenuAction.logout),
    ];

    const secondaryItems = [
      _DrawerItemData(
          icon: Icons.mail_outline,
          label: 'Email',
          action: _HaloMenuAction.email),
      _DrawerItemData(
          icon: Icons.ios_share,
          label: 'Share',
          action: _HaloMenuAction.share),
      _DrawerItemData(
          icon: Icons.headset_mic,
          label: 'Customer Care',
          action: _HaloMenuAction.customerCare),
    ];

    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF3EDFF), Color(0xFFE5E0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      'MENU',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: kSecondaryColor),
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    ...primaryItems.map((item) => _HaloDrawerTile(
                      data: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(item.action);
                      },
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(thickness: 1.0),
                    ),
                    ...secondaryItems.map((item) => _HaloDrawerTile(
                      data: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(item.action);
                      },
                    )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16),
                child: Text(
                  'Version 1.013',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.black54),
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

  const _HaloDrawerTile(
      {Key? key, required this.data, required this.onTap})
      : super(key: key);

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
              child:
              Icon(data.icon, color: kSecondaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Double-tap heart overlay ----------------------

class _DoubleTapHeartOverlay extends StatefulWidget {
  final String postId;
  final Widget child;

  const _DoubleTapHeartOverlay(
      {Key? key, required this.postId, required this.child})
      : super(key: key);

  @override
  State<_DoubleTapHeartOverlay> createState() =>
      _DoubleTapHeartOverlayState();
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
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
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
        final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);
        final likeRef = postRef.collection('likes').doc(uid);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final likeSnap = await tx.get(likeRef);
          if (likeSnap.exists) return;
          tx.set(likeRef, {
            'userId': uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
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
                    child: const Icon(Icons.favorite,
                        size: 100, color: kIgLikeRed),
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

// ---------------------- Post Media ----------------------

class _PostMedia extends StatelessWidget {
  final List<dynamic> media;
  final Map<String, dynamic> postData;
  final VoidCallback? onVideoTap;

  const _PostMedia({
    Key? key,
    required this.media,
    required this.postData,
    this.onVideoTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final first = Map<String, dynamic>.from(media.first as Map);
    final type = (first['type'] ?? 'image').toString();
    var thumbUrl = (first['thumb'] ?? first['thumbnail'] ?? first['thumbnailUrl'] ?? '')
        .toString()
        .trim();
    if (thumbUrl.contains('.mp4') || isRawUploadStorageUrl(thumbUrl)) {
      thumbUrl = (postData['thumbnailUrl'] ?? '').toString().trim();
    }
    final trimStartMs = _asIntNullable(first['trimStartMs']);
    final trimEndMs = _asIntNullable(first['trimEndMs']);

    if (type == 'video') {
      final playback = resolveVideoPlayback(
        postData: postData,
        mediaItem: first,
      );
      if (playback.legacyRawFallback) {
        final postId = (postData['postId'] ?? '').toString();
        if (postId.isNotEmpty) {
          unawaited(
            VideoTranscodeQueueService.instance.maybeRequestTranscode(
              postId: postId,
              playback: playback,
            ),
          );
        }
      }
      final url = playback.primaryUrl;

      if (playback.showProcessingOverlay || url.isEmpty) {
        return SizedBox(
          height: 300,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  cacheManager: AppCacheManager.media,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
              else
                ColoredBox(color: Colors.grey.shade900),
              const ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Processing video…',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (url.isEmpty) {
        return Container(
          height: 300,
          color: Colors.grey.shade900,
          child: const Center(
            child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
          ),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onVideoTap,
        child: SizedBox(
            height: 300,
            width: double.infinity,
            child: _NetworkVideo(
              url: url,
              fallbackUrl: playback.fallbackUrl,
              trimStartMs: trimStartMs,
              trimEndMs: trimEndMs,
            )),
      );
    }

    final url = (first['medium'] ?? first['full'] ?? first['thumb'] ?? first['url'] ?? '')
        .toString()
        .trim();

    if (url.isEmpty) {
      return Container(
          height: 300,
          color: Colors.grey.shade200,
          child: const Center(
              child:
              Icon(Icons.image_not_supported, color: Colors.grey)));
    }

    return _PostImage(url: url, thumbUrl: thumbUrl);
  }
}

// ---------------------- Network Video ----------------------

/// Clears every decoder in the home-feed static cache (memory watchdog).
void evictHomeFeedVideoCache() =>
    _NetworkVideoState.evictAllUnderMemoryPressure();

class _NetworkVideo extends StatefulWidget {
  final String url;
  final String fallbackUrl;
  final int? trimStartMs;
  final int? trimEndMs;
  const _NetworkVideo({
    Key? key,
    required this.url,
    this.fallbackUrl = '',
    this.trimStartMs,
    this.trimEndMs,
  }) : super(key: key);

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  // Honor the central policy (currently 2 on every platform). Was 3 on
  // Android, which contributed to the 256 MB heap OOM when a 4K HEVC clip
  // and a 1080p clip were decoded simultaneously.
  static int get _maxCachedControllers => ReelPlatformPolicy.maxPoolSlots;
  static final LinkedHashMap<String, VideoPlayerController> _videoCache =
      LinkedHashMap<String, VideoPlayerController>();
  static final Set<String> _visibleKeys = <String>{};

  VideoPlayerController? _controller;
  bool _initStarted = false;
  bool _initialized = false;
  bool _error = false;
  bool _isVisible = false;
  Duration _effectiveTrimStart = Duration.zero;
  Duration? _effectiveTrimEnd;
  Timer? _initDebounce;
  String? _cacheKey;
  int _initGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isEmpty) {
      setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(covariant _NetworkVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trimStartMs != widget.trimStartMs ||
        oldWidget.trimEndMs != widget.trimEndMs) {
      _updateTrimBounds();
      _syncPlayback();
    }
  }

  void _initIfNeeded() {
    if (_initStarted || widget.url.trim().isEmpty) return;
    if (shouldBlockPlaybackUrl(widget.url.trim(), postData: const {})) {
      return;
    }
    _initStarted = true;
    final initGen = ++_initGeneration;
    try {
      final key = widget.url.trim();
      _cacheKey = key;
      final cachedController = _videoCache[key];
      final controller = cachedController ??
          VideoPlayerController.networkUrl(
            Uri.parse(widget.url),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
      _videoCache.remove(key);
      _videoCache[key] = controller;
      _evictIfNeeded(excludeKey: key);
      _controller = controller;
      ReelLifecycleLog.bind(key, generation: initGen);
      if (controller.value.isInitialized) {
        if (initGen != _initGeneration || !mounted) return;
        _updateTrimBounds();
        controller
          ..setLooping(false)
          ..addListener(_enforceTrimWindow);
        _initialized = true;
        _syncPlayback();
        if (mounted) setState(() {});
        return;
      }
      controller.initialize().then((_) {
        if (initGen != _initGeneration || !mounted) {
          _pauseAndHide();
          return;
        }
        _updateTrimBounds();
        controller
          ..setLooping(false)
          ..addListener(_enforceTrimWindow);
        if (_effectiveTrimStart > Duration.zero) {
          controller.seekTo(_effectiveTrimStart);
        }
        setState(() => _initialized = true);
        _syncPlayback();
      }).catchError((Object e) {
        ReelLifecycleLog.playerException(key, e);
        if (initGen != _initGeneration) return;
        _removeControllerFromCache();
        _controller = null;
        if (!mounted) return;
        setState(() => _error = true);
      });
    } catch (e) {
      ReelLifecycleLog.playerException(widget.url, e);
      if (initGen != _initGeneration) return;
      _removeControllerFromCache();
      _controller = null;
      if (mounted) setState(() => _error = true);
    }
  }

  void _removeControllerFromCache() {
    final key = _cacheKey;
    if (key == null) return;
    final controller = _videoCache[key];
    if (controller != null) {
      _videoCache.remove(key);
      controller.dispose();
    }
    _visibleKeys.remove(key);
    _cacheKey = null;
  }

  void _evictIfNeeded({required String excludeKey}) {
    while (_videoCache.length > _maxCachedControllers) {
      String? evictionKey;
      for (final key in _videoCache.keys) {
        if (key == excludeKey) continue;
        if (_visibleKeys.contains(key)) continue;
        evictionKey = key;
        break;
      }
      evictionKey ??= _videoCache.keys.firstWhere(
        (k) => k != excludeKey,
        orElse: () => excludeKey,
      );
      if (evictionKey == excludeKey) break;
      final controller = _videoCache.remove(evictionKey);
      _visibleKeys.remove(evictionKey);
      controller?.dispose();
    }
  }

  void _pauseAndHide() {
    final key = _cacheKey;
    if (key != null) {
      _visibleKeys.remove(key);
    }
    _controller?.pause();
  }

  /// Drops this widget's hold on the shared cache entry. Disposes the decoder
  /// when no other [_NetworkVideo] still marks the URL visible.
  void _releaseCacheEntry() {
    final key = _cacheKey;
    if (key == null) return;
    _visibleKeys.remove(key);
    _controller?.removeListener(_enforceTrimWindow);
    _controller = null;
    _initStarted = false;
    _initialized = false;
    _cacheKey = null;

    if (_visibleKeys.contains(key)) return;

    final cached = _videoCache.remove(key);
    if (cached != null) {
      unawaited(cached.dispose());
    }
  }

  /// Called from [MemoryWatchdog] on critical RSS — frees every home-feed decoder.
  static void evictAllUnderMemoryPressure() {
    for (final c in _videoCache.values) {
      unawaited(c.dispose());
    }
    _videoCache.clear();
    _visibleKeys.clear();
  }

  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !mounted) return;
    if (_cacheKey != widget.url.trim()) return;
    try {
      if (_isVisible) {
        ReelLifecycleLog.activate(widget.url);
        if (c.value.position < _effectiveTrimStart) {
          c.seekTo(_effectiveTrimStart);
        }
        c.play();
      } else {
        ReelLifecycleLog.deactivate(widget.url);
        c.pause();
      }
    } catch (e) {
      ReelLifecycleLog.playerException(widget.url, e);
    }
  }

  void _updateTrimBounds() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final maxMs = c.value.duration.inMilliseconds;
    var start = widget.trimStartMs ?? 0;
    if (start < 0) start = 0;
    if (start > maxMs) start = maxMs;
    int? end = widget.trimEndMs;
    if (end != null) {
      if (end <= start) {
        end = maxMs;
      } else if (end > maxMs) {
        end = maxMs;
      }
    }
    _effectiveTrimStart = Duration(milliseconds: start);
    _effectiveTrimEnd =
    end != null ? Duration(milliseconds: end) : null;
  }

  void _enforceTrimWindow() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_effectiveTrimEnd == null) return;
    if (c.value.position >= _effectiveTrimEnd!) {
      c.seekTo(_effectiveTrimStart);
      if (_isVisible) c.play();
    }
  }

  @override
  void dispose() {
    _initDebounce?.cancel();
    _initGeneration++;
    ReelLifecycleLog.dispose(widget.url, reason: 'home_network_video');
    _releaseCacheEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('home_video_${widget.url.hashCode}'),
      onVisibilityChanged: (info) {
        final visibleNow = info.visibleFraction > 0.6;
        if (visibleNow && !_initStarted && _initDebounce == null) {
          _initDebounce = Timer(const Duration(milliseconds: 220), () {
            _initDebounce = null;
            if (!mounted || !_isVisible) return;
            _initIfNeeded();
          });
        }
        if (!visibleNow) {
          _initDebounce?.cancel();
          _initDebounce = null;
        }
        if (_isVisible != visibleNow) {
          _isVisible = visibleNow;
          final key = _cacheKey;
          if (key != null) {
            if (visibleNow) {
              _visibleKeys.add(key);
            } else {
              _visibleKeys.remove(key);
              if (!_visibleKeys.contains(key)) {
                _releaseCacheEntry();
                if (mounted) setState(() {});
              }
            }
          }
          _syncPlayback();
        }
      },
      child: Builder(
        builder: (context) {
          if (_error) {
            return Container(
                height: 300,
                color: Colors.black26,
                child: const Center(
                    child: Icon(Icons.videocam_off,
                        color: Colors.white54, size: 48)));
          }
          if (!_initialized ||
              _controller == null ||
              !_controller!.value.isInitialized) {
            return Container(
                height: 300,
                color: Colors.black12,
                child:
                const Center(child: CircularProgressIndicator()));
          }

          final c = _controller!;
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------- Post user header (with in-memory cache) ----------------------

class _UserLite {
  final String username;
  final String profilePhotoUrl;
  final String accountType;
  // [FIX-5] Timestamp for TTL-based cache invalidation (5 min).
  final DateTime fetchedAt;

  const _UserLite({
    required this.username,
    required this.profilePhotoUrl,
    required this.accountType,
    required this.fetchedAt,
  });

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inMinutes >= 5;
}

class _PostUserHeader extends StatefulWidget {
  final String userId;
  final String subtitle;

  const _PostUserHeader({
    Key? key,
    required this.userId,
    required this.subtitle,
  }) : super(key: key);

  @override
  State<_PostUserHeader> createState() => _PostUserHeaderState();
}

class _PostUserHeaderState extends State<_PostUserHeader> {
  // [FIX-5] Cache now has a 5-minute TTL. Stale entries are re-fetched
  // so profile photo / username updates eventually propagate.
  static final Map<String, _UserLite> _cache = {};
  _UserLite? _user;

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.userId];
    if (cached != null && !cached.isStale) {
      _user = cached;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = doc.data();
      final user = _UserLite(
        username: (data?['username'] ??
            data?['name'] ??
            data?['full_name'] ??
            'User')
            .toString(),
        profilePhotoUrl: _profilePhotoUrlFromUser(data),
        accountType:
        (data?['accountType'] as String?)?.toLowerCase() ?? 'aspirant',
        fetchedAt: DateTime.now(),
      );
      _cache[widget.userId] = user;
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  void _openProfile() {
    final user = _user;
    if (user == null || widget.userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileRouterScreen(profileUserId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return _PostHeader(
      username: user?.username ?? 'User',
      profilePhotoUrl: user?.profilePhotoUrl ?? '',
      subtitle: widget.subtitle,
      onTap: user == null ? null : _openProfile,
    );
  }
}

class _PostItem extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> postDoc;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;

  const _PostItem({
    Key? key,
    required this.postDoc,
    required this.savedPostsListenable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final data = postDoc.data();
    final parsedMedia = MediaModel.parsePostMedia(data);
    final media = parsedMedia
        .map((m) => <String, dynamic>{
              'type': m.type,
              'url': m.isVideo ? m.videoUrl : m.image.forFeed(),
              'videoUrl': m.videoUrl,
              'hlsUrl': m.hlsUrl,
              'rawVideoUrl': m.rawVideoUrl,
              'processed': m.processed,
              'processing': m.processing,
              'thumb': m.image.thumb,
              'medium': m.image.medium,
              'full': m.image.full,
              'thumbnail': m.thumbnail,
              if (m.trimStartMs != null) 'trimStartMs': m.trimStartMs,
              if (m.trimEndMs != null) 'trimEndMs': m.trimEndMs,
            })
        .toList(growable: false);
    final images = List<String>.from(data['images'] ?? const []);
    final imageUrl = (data['imageUrl'] as String?)?.trim() ?? '';
    final videoUrl = (data['videoUrl'] ?? data['mediaUrl'] ?? data['reelUrl'] ?? '')
        .toString()
        .trim();
    final thumbnailUrl =
        (data['thumbnailUrl'] ?? data['thumbUrl'] ?? '').toString().trim();
    final trimStartMs = _asIntNullable(data['trimStartMs']);
    final trimEndMs = _asIntNullable(data['trimEndMs']);
    final isLargeDevice = MediaQuery.of(context).size.width >= 900;
    final parsedFirstImage = parsedMedia
        .firstWhere(
          (m) => m.isImage && m.image.hasAny,
          orElse: () => const MediaModel(
            type: 'image',
            image: MediaVariant(thumb: '', medium: '', full: ''),
            videoUrl: '',
            hlsUrl: '',
            thumbnail: '',
          ),
        )
        .image
        .forFeedByDevice(isLargeDevice);
    final mediaForPost = media.isNotEmpty
        ? media
        : (videoUrl.isNotEmpty
            ? [
                <String, dynamic>{
                  'type': 'video',
                  'url': videoUrl,
                  'trimStartMs': trimStartMs,
                  'trimEndMs': trimEndMs,
                }
              ]
            : const []);
    final effectiveImageUrl = parsedFirstImage.isNotEmpty
        ? parsedFirstImage
        : (imageUrl.isNotEmpty
            ? imageUrl
            : (thumbnailUrl.isNotEmpty ? thumbnailUrl : ''));
    final caption = (data['caption'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final createdText = createdAt != null
        ? createdAt.toDate().toLocal().toString().substring(0, 16)
        : '';
    final userId = (data['userId'] ?? '').toString();

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        color: kIgPostBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            userId.isNotEmpty
                ? _PostUserHeader(
              userId: userId,
              subtitle:
              location.isNotEmpty ? location : createdText,
            )
                : _PostHeader(
              username: 'User',
              profilePhotoUrl: '',
              subtitle:
              location.isNotEmpty ? location : createdText,
              onTap: null,
            ),

            _DoubleTapHeartOverlay(
              postId: postDoc.id,
              child: mediaForPost.isNotEmpty
                  ? _PostMedia(
                media: mediaForPost,
                postData: {
                  'postId': postDoc.id,
                  'processed': data['processed'] == true,
                  'processing': data['processing'] == true,
                  'videoUrl': videoUrl,
                  'hlsUrl': (data['hlsUrl'] ?? '').toString(),
                },
                onVideoTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExplorePage(
                        openReelsOnStart: true,
                        initialReelPostId: postDoc.id,
                      ),
                    ),
                  );
                },
              )
                  : (images.isNotEmpty &&
                  images.first.trim().isNotEmpty
                  ? _PostImage(url: images.first)
                  : effectiveImageUrl.trim().isNotEmpty
                  ? _PostImage(url: effectiveImageUrl)
                  : const SizedBox.shrink()),
            ),

            _PostActions(
              postId: postDoc.id,
              initialLikeCount: _asInt(data['likeCount']),
              initialCommentCount: _asInt(data['commentCount']),
              savedPostsListenable: savedPostsListenable,
            ),

            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: kIgPrimaryText,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Post Actions ----------------------
// [FIX-2] postData prop removed. likeCount and commentCount are now fetched
// from a live stream on the post document so counts never go stale.

class _PostActions extends StatefulWidget {
  final String postId;
  final int initialLikeCount;
  final int initialCommentCount;
  final ValueListenable<Map<String, dynamic>> savedPostsListenable;

  const _PostActions({
    Key? key,
    required this.postId,
    required this.initialLikeCount,
    required this.initialCommentCount,
    required this.savedPostsListenable,
  }) : super(key: key);

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;
  late int _likeCount;
  late int _commentCount;
  bool _isLiked = false;
  bool _isLikeBusy = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.initialLikeCount;
    _commentCount = widget.initialCommentCount;
    _loadInitialLikeStatus();
  }

  Future<void> _loadInitialLikeStatus() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(currentUserId)
          .get();
      if (!mounted) return;
      setState(() => _isLiked = likeDoc.exists);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_isLikeBusy) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like posts')));
      return;
    }
    final nextLikeValue = !_isLiked;
    setState(() {
      _isLikeBusy = true;
      _isLiked = nextLikeValue;
      _likeCount += nextLikeValue ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    try {
      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final likeRef = postRef.collection('likes').doc(currentUserId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final likeDoc = await tx.get(likeRef);
        if (likeDoc.exists) {
          tx.delete(likeRef);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(likeRef, {
            'userId': currentUserId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !nextLikeValue;
          _likeCount += nextLikeValue ? -1 : 1;
          if (_likeCount < 0) _likeCount = 0;
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating like: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLikeBusy = false);
      }
    }
  }

  Future<void> _showComments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CommentsPage(postId: widget.postId),
      ),
    );
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      if (!mounted) return;
      final freshCount = _asInt(postDoc.data()?['commentCount']);
      setState(() => _commentCount = freshCount);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final likeCount = _likeCount;
    final commentCount = _commentCount;
    final isLiked = _isLiked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? kIgLikeRed : kIgPrimaryText,
                size: 28,
              ),
              onPressed: _toggleLike,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, size: 26, color: kIgPrimaryText),
              onPressed: _showComments,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            IconButton(
              icon: Icon(Icons.send_outlined, size: 26, color: kIgPrimaryText),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Share functionality coming soon!')));
              },
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            const Spacer(),
            ValueListenableBuilder<Map<String, dynamic>>(
              valueListenable: widget.savedPostsListenable,
              builder: (_, savedMap, __) {
                return SaveButton(
                  postId: widget.postId,
                  currentUserId: _currentUserId,
                  savedPostsMap: savedMap,
                  iconSize: 26,
                  color: kIgPrimaryText,
                );
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: kIgPrimaryText,
                    fontSize: 14),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _showComments,
                child: Text(
                  'View all $commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: kIgSecondaryText, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------- Comments Page ----------------------
// [FIX-3] All comment user docs are fetched in a single whereIn query
// instead of one FutureBuilder per row.

class _CommentsPage extends StatefulWidget {
  final String postId;

  const _CommentsPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // [FIX-3] In-memory user data cache keyed by uid, populated in batch.
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')));
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a comment')));
      return;
    }
    try {
      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final commentRef = postRef.collection('comments').doc();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(commentRef, {
          'userId': _currentUserId,
          'text': _commentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'commentCount': FieldValue.increment(1)});
      });
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')));
    }
  }

  // [FIX-3] Batch-fetch all user docs for a list of comment documents.
  Future<void> _prefetchUsers(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> comments) async {
    final uids = comments
        .map((c) => (c.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty && !_userCache.containsKey(id))
        .toSet()
        .toList();

    if (uids.isEmpty) return;

    // Firestore whereIn supports up to 30 values per call.
    const chunkSize = 30;
    for (var i = 0; i < uids.length; i += chunkSize) {
      final chunk = uids.sublist(
          i, i + chunkSize > uids.length ? uids.length : i + chunkSize);
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in result.docs) {
        _userCache[doc.id] = doc.data();
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
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
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
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
                      child: Text('No comments yet',
                          style: TextStyle(
                              color: Colors.grey.shade600)),
                    );
                  }

                  // [FIX-3] Trigger a batch user fetch whenever the
                  // comment list changes. Uses addPostFrameCallback so
                  // we don't call setState during build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _prefetchUsers(comments);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index].data();
                      final commentUserId =
                      (comment['userId'] ?? '').toString();
                      final commentText =
                      (comment['text'] ?? '').toString();
                      final ts = comment['createdAt'] as Timestamp?;
                      final timeStr = ts != null
                          ? ts
                          .toDate()
                          .toLocal()
                          .toString()
                          .substring(0, 16)
                          : '';

                      // [FIX-3] Read from local cache — no FutureBuilder.
                      final uData = _userCache[commentUserId];
                      final username = (uData?['username'] ??
                          uData?['name'] ??
                          'User')
                          .toString();
                      final photoUrl =
                      _profilePhotoUrlFromUser(uData);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.grey.shade200,
                              child: ClipOval(
                                child: photoUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Image.asset(
                                        'assets/images/Profile.png',
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                      ),
                                )
                                    : Image.asset(
                                  'assets/images/Profile.png',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: textTheme.bodyMedium
                                          ?.copyWith(
                                          color: kIgPrimaryText,
                                          fontSize: 14),
                                      children: [
                                        TextSpan(
                                          text: '$username ',
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w600),
                                        ),
                                        TextSpan(text: commentText),
                                      ],
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(top: 4),
                                      child: Text(
                                        timeStr,
                                        style: textTheme.bodySmall
                                            ?.copyWith(
                                            color: kIgSecondaryText,
                                            fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(Icons.person,
                          size: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: textTheme.bodyMedium
                              ?.copyWith(color: kIgSecondaryText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    TextButton(
                      onPressed: _addComment,
                      child: Text(
                        'Post',
                        style: textTheme.bodyMedium?.copyWith(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}