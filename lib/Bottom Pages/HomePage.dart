// HomePage.dart — app shell (tabs). Home feed UI lives in features/feed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'package:halo/features/feed/presentation/home_page.dart' as feed;
import 'package:halo/features/feed/presentation/nav_bar.dart';

const Color kPrimaryColor = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);

class _UserCache {
  static final Map<String, _Entry> _m = {};
  static const Duration _ttl = Duration(minutes: 5);

  static Future<Map<String, dynamic>?> get(String uid) async {
    final e = _m[uid];
    if (e != null && DateTime.now().difference(e.at) < _ttl) return e.data;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      _m[uid] = _Entry(data, DateTime.now());
      return data;
    } catch (_) {
      return null;
    }
  }
}

class _Entry {
  final Map<String, dynamic>? data;
  final DateTime at;
  _Entry(this.data, this.at);
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int _navIndex = 0;
  bool _locationPrompted = false;

  late final Widget _searchPage;
  late final Widget _explorePage;
  late final Widget _notifPage;
  late final Widget _profilePage;

  @override
  void initState() {
    super.initState();
    _searchPage = const SearchPage();
    _explorePage = const ExplorePage();
    _notifPage = NotificationPage();
    _profilePage = const _ProfileTab();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
  }

  Future<void> _maybePromptLocation() async {
    if (_locationPrompted) return;
    _locationPrompted = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('location_prompt_shown') == true) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Location', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Halo can show nearby posts more accurately if location is on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Permission.location.request();
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await prefs.setBool('location_prompt_shown', true);
  }

  void _onDrawer(_DrawerAction a) {
    switch (a) {
      case _DrawerAction.home:
        setState(() => _navIndex = 0);
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
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openChat() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatListPage(currentUserId: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _Drawer(onSelect: _onDrawer),
      body: IndexedStack(
        index: _navIndex == 3 ? 0 : _navIndex.clamp(0, 5),
        children: [
          SafeArea(
            child: feed.HomePage(
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onBell: () => setState(() => _navIndex = 4),
              onChat: _openChat,
              onPhoto: () => setState(() => _navIndex = 5),
            ),
          ),
          _searchPage,
          _explorePage,
          const SizedBox.shrink(),
          _notifPage,
          _profilePage,
        ],
      ),
      bottomNavigationBar: NavBar(
        index: _navIndex == 3 ? 0 : _navIndex,
        onSelect: (i) {
          if (i == 0 && _navIndex == 0) {
            return;
          }
          setState(() => _navIndex = i);
        },
        onAdd: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => AddPostPage(),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loaded = false;
  String _type = 'aspirant';
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
      final data = await _UserCache.get(uid);
      final type = data?['accountType']?.toString().toLowerCase() ?? 'aspirant';
      if (mounted) {
        setState(() {
          _uid = uid;
          _type = type;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _uid = uid;
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }
    if (_type == 'wellness') return wellness.WellnessProfilePage(profileUserId: _uid);
    if (_type == 'guru') return guru.GuruProfilePage(profileUserId: _uid);
    return aspirant.ProfilePage(profileUserId: _uid);
  }
}

enum _DrawerAction { home, explore, saved, settings, logout, share }

class _Drawer extends StatelessWidget {
  final void Function(_DrawerAction) onSelect;
  const _Drawer({required this.onSelect});

  static const List<List<dynamic>> _items = [
    [Icons.home_filled, 'Home', _DrawerAction.home],
    [Icons.explore_outlined, 'Explore', _DrawerAction.explore],
    [Icons.bookmark_border, 'Saved Posts', _DrawerAction.saved],
    [Icons.settings_outlined, 'Settings', _DrawerAction.settings],
    [Icons.share_rounded, 'Share App', _DrawerAction.share],
    [Icons.logout_rounded, 'Log Out', _DrawerAction.logout],
  ];

  @override
  Widget build(BuildContext context) {
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'MENU',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: kSecondaryColor,
                      ),
                    ),
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
                    final icon = item[0] as IconData;
                    final label = item[1] as String;
                    final action = item[2] as _DrawerAction;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: kSecondaryColor, size: 20),
                      ),
                      title: Text(
                        label,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(action);
                      },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Version 1.0',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
