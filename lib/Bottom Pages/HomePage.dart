// HomePage.dart — Instagram-style feed for Halo
// Fixed version — all bugs resolved

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
import 'package:halo/story/story_viewer_page.dart';
import 'package:halo/story/story_upload_sheet.dart';

import 'package:halo/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart'
as guru_profile;

import 'package:halo/services/feed_service.dart';
import 'package:halo/widgets/save_button.dart';

import 'NotificationPage.dart';
import 'SearchPage.dart';
import 'ExplorePage.dart';

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

  // FIX #5: Use a key to force StreamBuilder rebuild on refresh
  int _feedRefreshKey = 0;

  // FIX #4: Compute feed stream once; update only on explicit refresh
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _feedStream;

  @override
  void initState() {
    super.initState();
    _initFeedStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForLocation();
    });
    _loadInterests();
  }

  // FIX #4: stable stream, not re-created on every auth event
  void _initFeedStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _feedStream = _feedService.getRankedFeedStream(
      currentUserId: uid,
      userPreference: _contentPreference,
    );
  }

  Future<void> _loadInterests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interests = prefs.getStringList('user_interests') ?? const [];
      if (!mounted) return;
      setState(() => _interests = interests);
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
                  const SnackBar(
                      content: Text('Location permission granted')),
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

  void _onMenuAction(_HaloMenuAction action) {
    switch (action) {
      case _HaloMenuAction.home:
        return;
      default:
        _showFeaturePlaceholder(action.name);
    }
  }

  void _showFeaturePlaceholder(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature coming soon!')));
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
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to use chat')));
              return;
            }
            Navigator.pushReplacement(
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
                    Navigator.pushReplacement(
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
                // FIX #5: Refresh re-creates the feed stream
                onRefresh: () async {
                  setState(() {
                    _feedRefreshKey++;
                    _initFeedStream();
                  });
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    children: [
                      // FIX #3: _StoriesStrip now a StatefulWidget (stream stable)
                      const _StoriesStrip(),
                      const SizedBox(height: 12),
                      _buildFeedSegmentedControl(),
                      const SizedBox(height: 8),
                      // FIX #4 + #5: stable stream + refresh key
                      StreamBuilder<
                          List<
                              QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        key: ValueKey(_feedRefreshKey),
                        stream: _feedStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                  'Error loading posts: ${snapshot.error}'),
                            );
                          }

                          final rankedDocs = snapshot.data ?? [];
                          List<QueryDocumentSnapshot<Map<String, dynamic>>>
                          filtered = rankedDocs;

                          if (_interests.isNotEmpty) {
                            filtered = rankedDocs.where((d) {
                              final data = d.data();
                              final accountType =
                              (data['accountType'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              if (accountType == 'guru') return true;
                              final tags = (data['tags'] as List?)
                                  ?.map((e) => e.toString())
                                  .toList() ??
                                  [];
                              if (tags.isEmpty) return true;
                              return tags
                                  .any((t) => _interests.contains(t));
                            }).toList();
                          }

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 40,
                                      color: Colors.grey.shade500),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No posts yet',
                                    style: textTheme.titleMedium?.copyWith(
                                        color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Follow more people or add your first post.',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final data = filtered[index].data();
                              final media =
                                  (data['media'] as List?)
                                      ?.cast<dynamic>() ??
                                      const [];
                              final images = List<String>.from(
                                  data['images'] ?? const []);
                              final imageUrl =
                                  (data['imageUrl'] as String?)
                                      ?.trim() ??
                                      '';
                              final caption =
                              (data['caption'] ?? '').toString();
                              final location =
                              (data['location'] ?? '').toString();
                              final createdAt =
                              data['createdAt'] as Timestamp?;
                              final createdText = createdAt != null
                                  ? createdAt
                                  .toDate()
                                  .toLocal()
                                  .toString()
                                  .substring(0, 16)
                                  : '';
                              final userId =
                              (data['userId'] ?? '').toString();

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0, vertical: 6.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: kIgPostBackground,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        userId.isNotEmpty
                                            ? StreamBuilder<
                                            DocumentSnapshot<
                                                Map<String,
                                                    dynamic>>>(
                                          stream: FirebaseFirestore
                                              .instance
                                              .collection('users')
                                              .doc(userId)
                                              .snapshots(),
                                          builder:
                                              (context, userSnap) {
                                            final doc =
                                                userSnap.data;
                                            final uData =
                                            doc?.data();
                                            final username = (doc !=
                                                null &&
                                                doc.exists)
                                                ? (uData?[
                                            'username'] ??
                                                uData?['name'] ??
                                                uData?[
                                                'full_name'] ??
                                                'User')
                                                : 'User';
                                            final profilePhotoUrl =
                                            _profilePhotoUrlFromUser(
                                                uData);
                                            final accountType =
                                                (uData?['accountType']
                                                as String?)
                                                    ?.toLowerCase() ??
                                                    'aspirant';

                                            return _PostHeader(
                                              username: username
                                                  .toString(),
                                              profilePhotoUrl:
                                              profilePhotoUrl,
                                              subtitle: location
                                                  .isNotEmpty
                                                  ? location
                                                  : createdText,
                                              onTap: () {
                                                if (userId
                                                    .isEmpty) return;
                                                if (accountType ==
                                                    'wellness') {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          wellness_profile
                                                              .WellnessProfilePage(
                                                              profileUserId:
                                                              userId),
                                                    ),
                                                  );
                                                } else if (accountType ==
                                                    'guru') {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          guru_profile
                                                              .GuruProfilePage(
                                                              profileUserId:
                                                              userId),
                                                    ),
                                                  );
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          aspirant_profile
                                                              .ProfilePage(
                                                              profileUserId:
                                                              userId),
                                                    ),
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        )
                                            : _PostHeader(
                                          username: 'User',
                                          profilePhotoUrl: '',
                                          subtitle: location
                                              .isNotEmpty
                                              ? location
                                              : createdText,
                                          onTap: null,
                                        ),

                                        // Media with double-tap heart
                                        _DoubleTapHeartOverlay(
                                          postId: filtered[index].id,
                                          child: media.isNotEmpty
                                              ? _PostMedia(media: media)
                                              : (images.isNotEmpty &&
                                              images.first
                                                  .trim()
                                                  .isNotEmpty
                                              ? _PostImage(
                                              url: images.first)
                                              : imageUrl
                                              .trim()
                                              .isNotEmpty
                                              ? _PostImage(
                                              url: imageUrl)
                                              : const SizedBox
                                              .shrink()),
                                        ),

                                        // FIX #2: single combined widget for actions + counts
                                        _PostActions(
                                          postId: filtered[index].id,
                                          postData: data,
                                        ),

                                        // Caption
                                        if (caption.isNotEmpty)
                                          Padding(
                                            padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 10.0),
                                            child: Text(
                                              caption,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
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
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          bottomNavigationBar:
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: (() {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null || uid.isEmpty) {
                return const Stream<
                    DocumentSnapshot<Map<String, dynamic>>>.empty();
              }
              return FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots();
            })(),
            builder: (context, snap) {
              final userProfileUrl =
              _profilePhotoUrlFromUser(snap.data?.data());
              return BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: 0,
                backgroundColor: Colors.white,
                elevation: 12,
                selectedItemColor: kSecondaryColor,
                unselectedItemColor: Colors.grey.shade500,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                onTap: (index) async {
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
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please sign in to view profile')));
                      return;
                    }
                    try {
                      final doc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .get();
                      final accountType =
                          doc.data()?['accountType']
                              ?.toString()
                              .toLowerCase() ??
                              'aspirant';
                      if (accountType == 'wellness') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                wellness_profile.WellnessProfilePage(
                                    profileUserId: uid),
                          ),
                        );
                      } else if (accountType == 'guru') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                guru_profile.GuruProfilePage(
                                    profileUserId: uid),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                aspirant_profile.ProfilePage(
                                    profileUserId: uid),
                          ),
                        );
                      }
                    } catch (_) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => aspirant_profile.ProfilePage(
                              profileUserId: uid),
                        ),
                      );
                    }
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
                      icon: Icon(Icons.favorite_outline_rounded),
                      label: ''),
                  BottomNavigationBarItem(
                    icon: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey.shade200,
                      // FIX #6: clean avatar logic
                      child: ClipOval(
                        child: userProfileUrl.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: userProfileUrl,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------- Extracted reusable post header ----------------------

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
        // FIX #6: clean CircleAvatar logic — no conflicting backgroundImage + child
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
              errorWidget: (_, __, ___) =>
                  Image.asset('assets/images/Profile.png',
                      width: 40, height: 40, fit: BoxFit.cover),
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
        style:
        textTheme.bodySmall?.copyWith(color: kIgSecondaryText, fontSize: 12),
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

// ---------------------- Extracted post image widget ----------------------

class _PostImage extends StatelessWidget {
  final String url;
  const _PostImage({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 300,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 300,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 300,
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }
}

// ---------------------- Stories Strip ----------------------
// FIX #3: converted to StatefulWidget so stream is stable across rebuilds

class _StoriesStrip extends StatefulWidget {
  const _StoriesStrip({Key? key}) : super(key: key);

  @override
  State<_StoriesStrip> createState() => _StoriesStripState();
}

class _StoriesStripState extends State<_StoriesStrip> {
  Stream<RankedStoriesResult>? _rankedStream;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    if (_myUid != null && _myUid!.isNotEmpty) {
      // FIX #3: stream created once in initState, not on every build()
      _rankedStream = StoryService().fetchStoriesRanked(_myUid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    if (_myUid == null || _myUid!.isEmpty) {
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
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'See all',
                  style: textTheme.bodySmall?.copyWith(
                      color: kSecondaryColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: StreamBuilder<RankedStoriesResult>(
            stream: _rankedStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }

              final result = snapshot.data!;
              final groupedStories = result.grouped;
              final userIds = <String>[
                _myUid!,
                ...result.orderedUserIds
                    .where((id) => id != _myUid),
              ];

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: userIds.length,
                itemBuilder: (context, index) {
                  final userId = userIds[index];

                  if (userId == _myUid) {
                    final myStories =
                        groupedStories[_myUid!] ?? [];
                    final hasStories = myStories.isNotEmpty;
                    final hasUnseen = myStories
                        .any((s) => !s.viewers.contains(_myUid));
                    final photoUrl =
                    hasStories ? myStories.first.userPhotoUrl : null;

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
                              builder: (_) =>
                                  StoryViewerPage(stories: myStories)),
                        );
                      },
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 6),
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

                  final hasUnseen =
                  stories.any((s) => !s.viewers.contains(_myUid));
                  final first = stories.first;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                StoryViewerPage(stories: stories)),
                      );
                    },
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6),
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
                              first.username.isNotEmpty
                                  ? first.username
                                  : 'User',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall
                                  ?.copyWith(fontSize: 12, color: Colors.black87),
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
        // FIX #6: consistent avatar pattern used here too
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
              errorWidget: (_, __, ___) =>
              const Icon(Icons.person, size: 28, color: Colors.white70),
            )
                : const Icon(Icons.person, size: 28, color: Colors.white70),
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
              child: Icon(data.icon, color: kSecondaryColor, size: 20),
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

  const _PostMedia({Key? key, required this.media}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final first = Map<String, dynamic>.from(media.first as Map);
    final type = (first['type'] ?? 'image').toString();
    final url = (first['url'] ?? '').toString().trim();

    if (type == 'video') {
      return SizedBox(
          height: 300,
          width: double.infinity,
          child: _NetworkVideo(url: url));
    }

    if (url.isEmpty) {
      return Container(
          height: 300,
          color: Colors.grey.shade200,
          child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey)));
    }

    return _PostImage(url: url);
  }
}

class _NetworkVideo extends StatefulWidget {
  final String url;
  const _NetworkVideo({Key? key, required this.url}) : super(key: key);

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isEmpty) {
      setState(() => _error = true);
      return;
    }
    try {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller!.initialize().then((_) {
        if (!mounted) return;
        _controller!
          ..setLooping(true)
          ..play();
        setState(() => _initialized = true);
      }).catchError((Object e) {
        if (!mounted) return;
        setState(() => _error = true);
      });
    } catch (_) {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: const Center(child: CircularProgressIndicator()));
    }

    final c = _controller!;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            c.value.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: Colors.white,
            size: 48,
          ),
          onPressed: () => setState(
                  () => c.value.isPlaying ? c.pause() : c.play()),
        ),
      ],
    );
  }
}

// ---------------------- Post Actions ----------------------
// FIX #2: All 3 streams merged into one StreamBuilder tree,
//         and like/comment counts are fetched together to avoid flicker.

class _PostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const _PostActions(
      {Key? key, required this.postId, required this.postData})
      : super(key: key);

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;

  Future<void> _toggleLike() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like posts')));
      return;
    }
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(_currentUserId!);
      final likeDoc = await likeRef.get();
      if (likeDoc.exists) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'userId': _currentUserId,
          'likedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: $e')));
    }
  }

  void _showComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CommentsPage(
            postId: widget.postId, postData: widget.postData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    // FIX #2: Single StreamBuilder on likes collection.
    // My own like status derived from the same snapshot — no extra stream.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .snapshots(),
      builder: (context, likeSnap) {
        final likeDocs = likeSnap.data?.docs ?? [];
        final likeCount = likeDocs.length;
        final isLiked = _currentUserId != null &&
            likeDocs.any((d) => d.id == _currentUserId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .snapshots(),
          builder: (context, commentSnap) {
            final commentCount = commentSnap.data?.docs.length ?? 0;

            String likeText;
            if (likeCount == 0) {
              likeText = 'Be the first to like this';
            } else if (isLiked && likeCount == 1) {
              likeText = 'Liked by you';
            } else if (isLiked && likeCount >= 2) {
              likeText = 'Liked by you and ${likeCount - 1} others';
            } else if (likeCount == 1) {
              likeText = 'Liked by 1 person';
            } else {
              likeText = 'Liked by $likeCount people';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isLiked ? kIgLikeRed : kIgPrimaryText,
                        size: 28,
                      ),
                      onPressed: _toggleLike,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline,
                          size: 26, color: kIgPrimaryText),
                      onPressed: _showComments,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    IconButton(
                      icon: Icon(Icons.send_outlined,
                          size: 26, color: kIgPrimaryText),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Share functionality coming soon!')));
                      },
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    const Spacer(),
                    SaveButton(
                      postId: widget.postId,
                      currentUserId: _currentUserId,
                      iconSize: 26,
                      color: kIgPrimaryText,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        likeText,
                        style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kIgPrimaryText,
                            fontSize: 14),
                      ),
                      if (commentCount > 0) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showComments,
                          child: Text(
                            'View all $commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                            style: textTheme.bodyMedium?.copyWith(
                                color: kIgSecondaryText, fontSize: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------- Comments Page ----------------------
// FIX #8: shows commenter username + avatar

class _CommentsPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const _CommentsPage(
      {Key? key, required this.postId, required this.postData})
      : super(key: key);

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
          SnackBar(content: Text('Error adding comment: $e')));
    }
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
                          style: TextStyle(color: Colors.grey.shade600)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index].data();
                      final commentUserId =
                      (comment['userId'] ?? '').toString();
                      final commentText =
                      (comment['text'] ?? '').toString();
                      final ts =
                      comment['createdAt'] as Timestamp?;
                      final timeStr = ts != null
                          ? ts
                          .toDate()
                          .toLocal()
                          .toString()
                          .substring(0, 16)
                          : '';

                      // FIX #8: fetch commenter username + photo
                      return FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        future: commentUserId.isNotEmpty
                            ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(commentUserId)
                            .get()
                            : null,
                        builder: (context, userSnap) {
                          final uData = userSnap.data?.data();
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
                                  backgroundColor:
                                  Colors.grey.shade200,
                                  child: ClipOval(
                                    child: photoUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) =>
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
                                            style:
                                            textTheme.bodySmall?.copyWith(
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
                  );
                },
              ),
            ),
            // Comment input bar — Instagram style
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
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
                          contentPadding: const EdgeInsets.symmetric(
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