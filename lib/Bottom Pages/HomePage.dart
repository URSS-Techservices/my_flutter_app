// HomePage.dart — app shell (tabs). Home feed UI lives in features/feed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:halo/profile_feature/presentation/profile_switch.dart';
import 'package:halo/features/auth/presentation/logout.dart';
import 'package:halo/features/drawer/presentation/app_drawer.dart';
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

  /// Built the first time Create is opened, then kept so a half-written
  /// post survives switching tabs.
  Widget? _addPostPage;

  @override
  void initState() {
    super.initState();
    _searchPage = const SearchPage();
    _explorePage = const ExplorePage();
    _notifPage = NotificationPage(onBack: _backFromNotifications);
    _profilePage = _ProfileTab(onBack: () => setState(() => _navIndex = 0));
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
        title: const Text('Location',
            style: TextStyle(fontWeight: FontWeight.w700)),
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

  /// Notifications opened from the drawer: back returns to the drawer.
  bool _notifFromDrawer = false;

  /// Opens a page from the drawer; back from it shows the drawer again.
  Future<void> _pushFromDrawer(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _scaffoldKey.currentState?.openDrawer();
  }

  void _openNotifications({required bool fromDrawer}) {
    _notifFromDrawer = fromDrawer;
    setState(() => _navIndex = 4);
  }

  void _backFromNotifications() {
    setState(() => _navIndex = 0);
    if (_notifFromDrawer) {
      _notifFromDrawer = false;
      _scaffoldKey.currentState?.openDrawer();
    }
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
      drawer: AppDrawer(
        onExplore: () => setState(() => _navIndex = 2),
        onSaved: () => _pushFromDrawer(const SavedPostsPage()),
        onNotifications: () => _openNotifications(fromDrawer: true),
        onSettings: () => _pushFromDrawer(SettingsPage()),
        onHelp: () => _pushFromDrawer(HelpCenterPage()),
        onLogout: () => logout(context),
        onProfile: () => setState(() => _navIndex = 5),
      ),
      body: IndexedStack(
        index: _navIndex.clamp(0, 5),
        children: [
          SafeArea(
            child: feed.HomePage(
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onBell: () => _openNotifications(fromDrawer: false),
              onChat: _openChat,
              onPhoto: () => setState(() => _navIndex = 5),
            ),
          ),
          _searchPage,
          _explorePage,
          _addPostPage ?? const SizedBox.shrink(),
          _notifPage,
          _profilePage,
        ],
      ),
      bottomNavigationBar: NavBar(
        index: _navIndex,
        onSelect: (i) {
          _notifFromDrawer = false;
          if (i == 0 && _navIndex == 0) {
            return;
          }
          setState(() => _navIndex = i);
        },
        onAdd: () {
          _notifFromDrawer = false;
          setState(() {
            _addPostPage ??= AddPostPage(
              onClose: () => setState(() => _navIndex = 0),
            );
            _navIndex = 3;
          });
        },
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.onBack});

  /// Back button on the profile goes to the Home tab.
  final VoidCallback onBack;

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
      return newProfileLoading() ??
          const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }
    final newPage = newProfilePageFor(_type, _uid, onBack: widget.onBack);
    if (newPage != null) return newPage;
    if (_type == 'wellness')
      return wellness.WellnessProfilePage(profileUserId: _uid);
    if (_type == 'guru') return guru.GuruProfilePage(profileUserId: _uid);
    return aspirant.ProfilePage(profileUserId: _uid);
  }
}
