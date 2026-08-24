// profile_page_improved.dart  (Aspirant Profile)

// -------------------- IMPORTS --------------------
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:halo/newpostpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:halo/screens/profile/core/profile_follow_toggle.dart';
import 'package:halo/screens/profile/core/profile_media_upload.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_image_url.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';


// Local pages (paths adjust kar lena agar different ho)
import '../editprofilepage.dart';
import 'package:halo/features/auth/presentation/login_page.dart';
import 'package:halo/Bottom Pages/PrivacySettingsPage.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:halo/Bottom Pages/saved_posts_page.dart';
import 'package:halo/utils/search_utils.dart';
import 'package:halo/services/follow_service.dart';
import 'package:halo/widgets/profile_image_interactions.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_identity_block.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_recent_posts_grid.dart';
import 'package:halo/screens/profile/widgets/common/profile_action_row.dart';
import 'package:halo/screens/profile/widgets/common/profile_bio_card.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_fitness_goals_section.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_title.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_card.dart';
import 'package:halo/screens/profile/widgets/common/profile_avatar_hero_shell.dart';
import 'package:halo/screens/profile/widgets/common/profile_cover_hero.dart';
import 'package:halo/screens/profile/widgets/common/profile_flexible_space_cover_stack.dart';
import 'package:halo/screens/profile/widgets/common/profile_loading_gate.dart';
import 'package:halo/screens/profile/widgets/common/profile_media_preview_helpers.dart';
import 'package:halo/screens/profile/widgets/common/profile_stats_bar.dart';
import 'edit_profile_sections.dart'; // Edit pages for profile sections

// ===================================================================
//  ASPIRANT PROFILE PAGE (HALO – HOBBY BASED ASPIRANT)
// ===================================================================

/// Wrapper class
class ProfilePage extends StatelessWidget {
  final String profileUserId; // Jis aspirant ki profile dekhni hai

  const ProfilePage({Key? key, required this.profileUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfilePageImproved(profileUserId: profileUserId);
  }
}

class ProfilePageImproved extends StatefulWidget {
  final String profileUserId;

  const ProfilePageImproved({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  _ProfilePageImprovedState createState() => _ProfilePageImprovedState();
}

class _ProfilePageImprovedState extends State<ProfilePageImproved>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser; // logged in user
  final FollowService _followService = FollowService();
  bool _isOwnProfile = false; // current user == profile user ?

  // -------------------- USER DATA (ASPIRANT) --------------------
  String _fullName = '';
  String _username = '';
  String _fitnessTag = ''; // legacy field, use as "tagline" if needed
  String _city = '';
  int? _age;
  String _bio = '';
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;
  List<String> _fitnessGoals = [];
  String? _fitnessLevel;
  List<String> _interests = []; // Hobbies / categories (cricket, dance, yoga...)
  List<String> _healthNotes = [];

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  // ---- Aspirant extra UI data ----
  List<Map<String, dynamic>> _lastWorkouts = [];        // now "Recent Activities"
  List<Map<String, dynamic>> _eventsChallenges = [];
  List<Map<String, dynamic>> _fitnessArticles = [];     // now "Learning Resources"
  Map<String, dynamic> _fitnessStats = {};              // now "Activity Stats"
  Map<String, String> _socialLinks = {};
  List<String> _badges = [];                            // Achievements / badges
  String? _primaryCategory;                             // main hobby (e.g. Cricket)
  List<Map<String, dynamic>> _personalRecords = [];     // Personal fitness records
  List<Map<String, dynamic>> _weeklyProgressData = [];  // Weekly progress data

  // -------------------- INTERACTION STATE --------------------
  bool _isFollowing = false;
  bool _isPrivate = false;
  bool _isLoading = true;
  int _selectedAspirantTab = 0;
  final Map<String, bool> _suggestedFollowLoading = {};

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _profilePhotoFile;
  File? _coverPhotoFile;

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Animations
  late final AnimationController _followAnimController;

  @override
  void initState() {
    super.initState();
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadProfileData(); // aspirant data load
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _followAnimController.dispose();
    super.dispose();
  }

  // ===================================================================
  //  DATA LOAD (ASPIRANT + FOLLOW STATUS)
  // ===================================================================
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = _auth.currentUser;
      _isOwnProfile =
          _currentUser != null && _currentUser!.uid == widget.profileUserId;

      // Aspirant user document
      final doc =
      await _firestore.collection('users').doc(widget.profileUserId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _fullName = (data['full_name'] ?? '') as String;
        _username = (data['username'] ?? '') as String;
        _fitnessTag = (data['fitnessTag'] ?? 'Explorer on Halo') as String;
        _city = (data['city'] ?? '') as String;
        _age = data['age'] is int ? data['age'] as int : null;
        _bio = (data['bio'] ?? '') as String;
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;
        _fitnessGoals = List<String>.from(data['fitnessGoals'] ?? []);
        _fitnessLevel = data['fitnessLevel'] as String?;
        _interests = List<String>.from(data['interests'] ?? []);
        _healthNotes = List<String>.from(data['healthNotes'] ?? []);
        _followersCount = (data['followersCount'] ?? 0) as int;
        _followingCount = (data['followingCount'] ?? 0) as int;
        _postsCount = (data['postsCount'] ?? 0) as int;
        _isPrivate = (data['isPrivate'] ?? false) as bool;
        _primaryCategory = data['primaryCategory'] as String?;
        _badges = List<String>.from(data['badges'] ?? []);

        // ---- Aspirant extra UI data ----

        // Last workouts / activities
        final lastWorkoutsRaw = data['lastWorkouts'] as List<dynamic>?;
        if (lastWorkoutsRaw != null && lastWorkoutsRaw.isNotEmpty) {
          _lastWorkouts = lastWorkoutsRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _lastWorkouts = [];
        }

        // Events & Challenges
        final eventsRaw = data['eventsChallenges'] as List<dynamic>?;
        if (eventsRaw != null && eventsRaw.isNotEmpty) {
          _eventsChallenges = eventsRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _eventsChallenges = [];
        }

        // Articles / learning resources
        final articlesRaw = data['fitnessArticles'] as List<dynamic>?;
        if (articlesRaw != null && articlesRaw.isNotEmpty) {
          _fitnessArticles = articlesRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _fitnessArticles = [];
        }

        // Stats
        final statsRaw = data['fitnessStats'] as Map<String, dynamic>?;
        if (statsRaw != null) {
          _fitnessStats = Map<String, dynamic>.from(statsRaw);
        } else {
          _fitnessStats = {
            'steps': 0,
            'caloriesBurned': 0,
            'workouts': 0,
            'currentWeight': data['currentWeight'] ?? 70,
            'targetWeight': data['targetWeight'] ?? 65,
            'bodyFat': data['bodyFat'] ?? 18,
            'targetBodyFat': data['targetBodyFat'] ?? 15,
            'currentStreak': data['currentStreak'] ?? 0,
            'longestStreak': data['longestStreak'] ?? 0,
          };
        }

        // Social links
        final sl = data['socialLinks'] as Map<String, dynamic>?;
        _socialLinks = sl != null
            ? sl.map((k, v) => MapEntry(k, v.toString()))
            : {
          'instagram': 'Instagram',
          'spotify': 'Spotify',
          'telegram': 'Telegram',
        };
      }

      // Follow status: kya current user is aspirant ko follow karta hai?
      if (_currentUser != null && !_isOwnProfile) {
        final followDoc = await _firestore
            .collection('users')
            .doc(widget.profileUserId)
            .collection('followers')
            .doc(_currentUser!.uid)
            .get();

        _isFollowing = followDoc.exists;
      }
    } catch (e) {
      debugPrint('profile load error: $e');
      Fluttertoast.showToast(msg: 'Failed to load profile');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ===================================================================
  //  CAMERA / IMAGE HANDLING (PROFILE + COVER)
  // ===================================================================
  Future<void> _initializeCamera() async {
    try {
      final currentStatus = await Permission.camera.status;
      if (currentStatus != PermissionStatus.granted) {
        final status = await Permission.camera.request();
        if (status != PermissionStatus.granted) return;
      }

      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController =
            CameraController(_cameras![0], ResolutionPreset.high);
        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('camera init error: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    if (!_isOwnProfile || _currentUser == null) return; // sirf apni profile edit
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final edited = await editProfileImageWithInstagramStyle(
      context,
      imagePath: picked.path,
      outputNamePrefix: 'profile',
    );
    if (edited == null) return;
    setState(() => _profilePhotoFile = edited);
    await _uploadAndSaveProfilePhoto(_profilePhotoFile!, isCover: false);
  }

  Future<void> _pickCoverImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final edited = await editProfileImageWithInstagramStyle(
      context,
      imagePath: picked.path,
      outputNamePrefix: 'cover',
    );
    if (edited == null) return;
    setState(() => _coverPhotoFile = edited);
    await _uploadAndSaveProfilePhoto(_coverPhotoFile!, isCover: true);
  }

  void _previewCoverImage() {
    openProfileStoredImagePreview(
      context: context,
      localFile: _coverPhotoFile,
      remoteUrl: _coverPhotoUrl,
      heroTag: 'aspirant-cover-${widget.profileUserId}',
    );
  }

  void _previewProfileImage() {
    openProfileStoredImagePreview(
      context: context,
      localFile: _profilePhotoFile,
      remoteUrl: _profilePhotoUrl,
      heroTag: 'profile-avatar-${widget.profileUserId}',
    );
  }

  Future<void> _uploadAndSaveProfilePhoto(File file,
      {required bool isCover}) async {
    if (_currentUser == null) return;
    try {
      final url = await ProfileMediaUpload.uploadUserPhotoAndPersist(
        firestore: _firestore,
        userId: _currentUser!.uid,
        file: file,
        isCover: isCover,
      );

      if (!mounted) return;
      setState(() {
        if (isCover) {
          _coverPhotoUrl = url;
        } else {
          _profilePhotoUrl = url;
        }
      });
      Fluttertoast.showToast(msg: 'Photo updated');
    } catch (e) {
      debugPrint('upload error: $e');
      Fluttertoast.showToast(msg: 'Upload failed');
    }
  }

  // ===================================================================
  //  FOLLOW / UNFOLLOW (INSTAGRAM STYLE)
  // ===================================================================
  Future<void> _toggleFollow() async {
    if (_currentUser == null || _isOwnProfile) return;

    final String currentUserId = _currentUser!.uid;
    final String profileUserId = widget.profileUserId;
    final bool wasFollowing = _isFollowing;

    await ProfileFollowToggle.runOptimisticToggle(
      followService: _followService,
      currentUserId: currentUserId,
      profileUserId: profileUserId,
      wasFollowing: wasFollowing,
      applyOptimisticUi: () => setState(() {
        _isFollowing = !wasFollowing;
        _followersCount += wasFollowing ? -1 : 1;
        if (_followersCount < 0) _followersCount = 0;
      }),
      rollbackUi: () => setState(() {
        _isFollowing = wasFollowing;
        _followersCount += wasFollowing ? 1 : -1;
        if (_followersCount < 0) _followersCount = 0;
      }),
      afterOptimisticUi: () => _followAnimController.forward(from: 0),
      errorToast: 'Something went wrong. Please try again.',
    );
  }

  Future<void> _openMessage() async {
    if (_isOwnProfile || _currentUser == null) return;
    
    try {
      final chatService = ChatService();
      final chatId = await chatService.getOrCreateChatId(
        _currentUser!.uid,
        widget.profileUserId,
      );
      
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ChatScreen(
            chatId: chatId,
            currentUserId: _currentUser!.uid,
            otherUserId: widget.profileUserId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat: $e');
      Fluttertoast.showToast(msg: 'Failed to open chat. Please try again.');
    }
  }

  // ===================================================================
  //  POST CREATION (ASPIRANT FEED)
  // ===================================================================
  Future<void> _openGalleryForPost() async {
    if (!_isOwnProfile) return; // sirf apne profile se post
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please sign in to post');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Newpostpage(
          imagePath: image.path,
          onPostSubmit: (caption) async {
            try {
              final fileName =
              DateTime.now().millisecondsSinceEpoch.toString();
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('posts')
                  .child(fileName);
              final snap = await ref.putFile(File(image.path));
              final url = await snap.ref.getDownloadURL();
              final uid = FirebaseAuth.instance.currentUser!.uid;
              print('uid: $uid');
// 🔹 get accountType from users collection
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();

              final accountType =
                  userDoc.data()?['accountType']?.toString().toLowerCase() ?? 'aspirant';

// 🔹 now save post (image URL from upload above)
              await FirebaseFirestore.instance.collection('posts').add({
                'userId': uid,
                'accountType': accountType,
                'caption': caption,
                'tags': [],
                'imageUrl': url,
                'timestamp': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              await _firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .update({
                'postsCount': FieldValue.increment(1),
              });
              Fluttertoast.showToast(msg: 'Post uploaded');
              await _loadProfileData();
            } catch (e) {
              debugPrint('post upload error: $e');
              Fluttertoast.showToast(msg: 'Upload failed');
            }
          },
        ),
      ),
    );
  }

  // ===================================================================
  //  EDIT PROFILE / SETTINGS / LOGOUT (ONLY OWN PROFILE)
  // ===================================================================
  Future<void> _handleEditProfile() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EditProfilePage(
          initialUsername: _username,
          initialName: _fullName,
          initialBio: _bio,
          initialGender: '',
          initialprofessiontype: '',
        ),
      ),
    );
    if (updatedData != null) {
      try {
        final username = updatedData['username']?.toString().trim() ?? '';
        final name = updatedData['name']?.toString().trim() ?? '';
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'username': username,
          'name': name,
          'bio': updatedData['bio'],
          'searchTerms': buildSearchTerms(name: name, username: username),
        });
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to save profile');
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (ctx) => LoginPage()),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Logout failed');
    }
  }

  // ===================================================================
  //  UI HELPERS (HEADER PARTS)
  // ===================================================================
  Widget _coverWidget(BuildContext context) {
    final ImageProvider cover = _coverPhotoFile != null
        ? FileImage(_coverPhotoFile!)
        : (_coverPhotoUrl != null
        ? NetworkImage(_coverPhotoUrl!)
        : const AssetImage('assets/images/bio.png')) as ImageProvider;

    return ProfileCoverHero(
      cover: cover,
      heroTag: 'aspirant-cover-${widget.profileUserId}',
      onTap: _isOwnProfile ? _pickCoverImage : _previewCoverImage,
      onLongPress: _previewCoverImage,
    );
  }

  Widget _avatarWidget() {
    final ImageProvider avatar = _profilePhotoFile != null
        ? FileImage(_profilePhotoFile!)
        : (_profilePhotoUrl != null
        ? NetworkImage(_profilePhotoUrl!)
        : const AssetImage('assets/images/Profile.png')) as ImageProvider;

    return ProfileAvatarHeroShell(
      avatar: avatar,
      heroTag: 'profile-avatar-${widget.profileUserId}',
      onTap: _isOwnProfile ? _pickProfileImage : _previewProfileImage,
      onLongPress: _previewProfileImage,
    );
  }

  Widget _buildStatsCard() {
    return ProfileThreeColumnStatsCard(
      followers: _followersCount,
      following: _followingCount,
      posts: _postsCount,
    );
  }

  Widget _buildActionButtons() {
    return ProfileActionRow(
      isOwnProfile: _isOwnProfile,
      isFollowing: _isFollowing,
      onToggleFollow: _toggleFollow,
      onMessage: _openMessage,
      onEditProfile: _handleEditProfile,
      accentColor: ProfileLayout.lavender,
    );
  }

  Widget _buildBioCard() {
    return ProfileBioCard(
      bio: _bio,
      isOwnProfile: _isOwnProfile,
      emptyHint:
          'Add a short bio — tell people what you love (cricket, dance, yoga, etc.).',
    );
  }

  // ===================================================================
  //  NEW ASPIRANT UI SECTIONS (HOBBY FOCUSED)
  // ===================================================================

  /// Aspirant profile tabs
  Widget _buildAspirantTabsRow() {
    final tabs = ['Aspirant', 'Coaches', 'Wellness', 'Community'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedAspirantTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedAspirantTab == index) return;
                setState(() => _selectedAspirantTab = index);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAspirantTabContent() {
    switch (_selectedAspirantTab) {
      case 0: // Aspirant
        return Column(
          children: [
            _buildSimilarAspirantsSection(),
            _buildHobbiesSection(),
          ],
        );
      case 1: // Coaches
        return _buildSuggestedGurusSection();
      case 2: // Wellness
        return _buildSuggestedWellnessSection();
      case 3: // Community
        return Column(
          children: [
            _buildEventsChallengesSection(),
            _buildSocialLinksSection(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<String> _toLowerTrimmedList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _commonMatchText(Map<String, dynamic> data) {
    final mine = _interests
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final theirs = <String>{
      ..._toLowerTrimmedList(data['interests']),
      ..._toLowerTrimmedList(data['specialties']),
      ..._toLowerTrimmedList(data['services']),
      (data['primaryCategory'] ?? '').toString().trim().toLowerCase(),
      (data['category'] ?? '').toString().trim().toLowerCase(),
      (data['wellness_category'] ?? '').toString().trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    final common = mine.intersection(theirs).toList();
    if (common.isNotEmpty) {
      final first = common.first;
      return '${first[0].toUpperCase()}${first.substring(1)} in common';
    }

    final fallback = (data['primaryCategory'] ??
            data['category'] ??
            data['wellness_category'] ??
            '')
        .toString()
        .trim();
    return fallback.isNotEmpty ? fallback : 'Suggested for you';
  }

  void _openSuggestedUserProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileRouterScreen(profileUserId: userId),
      ),
    );
  }

  Future<void> _toggleSuggestedFollow({
    required String profileUserId,
    required bool isCurrentlyFollowing,
  }) async {
    final currentUid = _currentUser?.uid;
    if (currentUid == null || profileUserId.isEmpty || profileUserId == currentUid) {
      return;
    }
    setState(() => _suggestedFollowLoading[profileUserId] = true);
    try {
      await _followService.setFollowState(
        currentUserId: currentUid,
        profileUserId: profileUserId,
        shouldFollow: !isCurrentlyFollowing,
      );
    } catch (_) {
      Fluttertoast.showToast(msg: 'Could not update follow right now');
    } finally {
      if (!mounted) return;
      setState(() => _suggestedFollowLoading[profileUserId] = false);
    }
  }

  Widget _buildSuggestedFollowButton(String targetUserId) {
    final currentUid = _currentUser?.uid;
    if (currentUid == null || currentUid == targetUserId) {
      return const SizedBox.shrink();
    }
    final loading = _suggestedFollowLoading[targetUserId] == true;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data?.exists ?? false;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUid)
                  .collection('followers')
                  .doc(targetUserId)
                  .snapshots(),
              builder: (context, reverseSnap) {
                final followsYou = reverseSnap.data?.exists ?? false;
                final isFollowBack = followsYou && !isFollowing;
                final topLabel = isFollowBack ? 'Follow back' : null;
                return Column(
                  children: [
                    if (topLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          topLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            color: ProfileLayout.deepLavender,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 26,
                      child: OutlinedButton(
                        onPressed: loading
                            ? null
                            : () => _toggleSuggestedFollow(
                                  profileUserId: targetUserId,
                                  isCurrentlyFollowing: isFollowing,
                                ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          side: BorderSide(
                            color: isFollowing ? Colors.grey.shade400 : ProfileLayout.deepLavender,
                          ),
                          backgroundColor: isFollowing ? Colors.white : ProfileLayout.deepLavender,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: isFollowing ? Colors.black87 : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    if (followsYou)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Follows you',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  // -------------------- Suggested Gurus --------------------
  Widget _buildSuggestedGurusSection() {
    // users collection standard field: accountType == 'guru'
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'guru');

    if (_interests.isNotEmpty) {
      final List<String> topInterests = _interests.length > 5
          ? _interests.sublist(0, 5)
          : _interests;
      query = query.where('interests', arrayContainsAny: topInterests);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Suggested Gurus (Coaches)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_primaryCategory != null && _primaryCategory!.isNotEmpty)
                Flexible(
                  child: Text(
                    _primaryCategory!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(10).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const ProfileEmptyState(
                    text: 'No gurus found yet for your interests.',
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = (data['name'] ?? 'Guru') as String;
                    final category =
                    (data['primaryCategory'] ?? '') as String;
                    final photo = data['profilePhoto'] as String?;
                    final matchText = _commonMatchText(data);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openSuggestedUserProfile(d.id),
                      child: Container(
                        width: 110,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage: photo != null
                                  ? NetworkImage(photo)
                                  : const AssetImage(
                                      'assets/images/Profile.png',
                                    ) as ImageProvider,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              category.isNotEmpty ? category : matchText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              matchText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildSuggestedFollowButton(d.id),
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
      ),
    );
  }

  // -------------------- Suggested Wellness --------------------
  Widget _buildSuggestedWellnessSection() {
    // users collection standard field: accountType == 'wellness'
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'wellness');

    if (_interests.isNotEmpty) {
      final List<String> topInterests = _interests.length > 5
          ? _interests.sublist(0, 5)
          : _interests;
      query = query.where('interests', arrayContainsAny: topInterests);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Wellness (Shops / Places)',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(10).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const ProfileEmptyState(
                    text: 'No wellness profiles yet. They will appear here.',
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = (data['name'] ?? 'Wellness') as String;
                    final category =
                    (data['primaryCategory'] ?? '') as String;
                    final photo = data['profilePhoto'] as String?;
                    final matchText = _commonMatchText(data);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openSuggestedUserProfile(d.id),
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: photo != null
                                  ? NetworkImage(photo)
                                  : const AssetImage(
                                      'assets/images/Profile.png',
                                    ) as ImageProvider,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    category.isNotEmpty ? category : matchText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    matchText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildSuggestedFollowButton(d.id),
                                ],
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
      ),
    );
  }

  // -------------------- Similar Aspirants --------------------
  Widget _buildSimilarAspirantsSection() {
    // users collection standard field: accountType == 'aspirant'
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('accountType', isEqualTo: 'aspirant');

    if (_primaryCategory != null && _primaryCategory!.isNotEmpty) {
      query = query.where('primaryCategory', isEqualTo: _primaryCategory);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People Like You',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(15).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                // current user ko list se hata do
                docs = docs
                    .where((d) => d.id != widget.profileUserId)
                    .toList();
                if (docs.isEmpty) {
                  return Text(
                    'We will suggest other aspirants here.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = (data['name'] ?? 'User') as String;
                    final username = (data['username'] ?? '') as String;
                    final photo = data['profilePhoto'] as String?;
                    final matchText = _commonMatchText(data);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openSuggestedUserProfile(d.id),
                      child: Container(
                        width: 110,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundImage: photo != null
                                  ? NetworkImage(photo)
                                  : const AssetImage(
                                      'assets/images/Profile.png',
                                    ) as ImageProvider,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              username.isNotEmpty ? '@$username' : matchText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              matchText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildSuggestedFollowButton(d.id),
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
      ),
    );
  }

  // -------------------- Achievements & Badges --------------------
  Widget _buildAchievementsSection() {
    if (_badges.isEmpty && !_isOwnProfile) {
      return const SizedBox.shrink();
    }

    final displayBadges = _badges.isNotEmpty
        ? _badges
        : ['New to Halo'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Achievements & Badges',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isOwnProfile)
                Flexible(
                  child: Text(
                    'Auto-unlocks as you use Halo',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayBadges
                .map(
                  (b) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ProfileLayout.chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      b,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  // -------------------- Recent Activities --------------------
  Widget _buildLastWorkoutsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activities',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isOwnProfile)
                TextButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditWorkoutsPage(
                          initialWorkouts: _lastWorkouts,
                          userType: 'aspirant',
                        ),
                      ),
                    );
                    if (updated != null) {
                      setState(() {
                        _lastWorkouts =
                        List<Map<String, dynamic>>.from(updated);
                      });
                      // Data is already saved to Firebase by EditWorkoutsPage
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_lastWorkouts.isEmpty && _isOwnProfile)
            const ProfileEmptyStateRich(
              text: 'No activities yet. Add your first match, session or practice!',
              icon: Icons.star_border,
              card: true,
            )
          else if (_lastWorkouts.isEmpty)
            const SizedBox.shrink()
          else
            ..._lastWorkouts.map((w) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w['title']?.toString() ?? 'Activity',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 12,
                            runSpacing: 2,
                            children: [
                              if (w['intensity'] != null)
                                _smallTag(w['intensity'].toString()),
                              if (w['calories'] != null)
                                _smallTag(w['calories'].toString()),
                              if (w['duration'] != null)
                                _smallTag(w['duration'].toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _smallTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }

  Widget _buildEventsChallengesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Events & Challenges',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_isOwnProfile)
                  TextButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => EditEventsChallengesPage(
                            initialEvents: _eventsChallenges,
                          ),
                        ),
                      );
                      if (updated != null) {
                        setState(() {
                          _eventsChallenges =
                          List<Map<String, dynamic>>.from(updated);
                        });
                        // Data is already saved to Firebase by EditEventsChallengesPage
                      }
                    },
                    icon:
                    const Icon(Icons.edit, size: 18, color: Colors.white),
                    label: const Text('Edit',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_eventsChallenges.isEmpty && _isOwnProfile)
              const ProfileEmptyStateRich(
                text: 'No events yet. Add your first tournament, show or meetup!',
                textColor: Colors.white70,
              )
            else if (_eventsChallenges.isEmpty)
              const SizedBox.shrink()
            else
              ..._eventsChallenges.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${e['type'] ?? ''}: ${e['name'] ?? ''}  (${e['status'] ?? ''})',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    return ProfileSectionCard(
      title: 'Social Links',
      trailing: _isOwnProfile
          ? TextButton.icon(
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => EditSocialLinksPage(
                      initialLinks: _socialLinks,
                    ),
                  ),
                );
                if (updated != null) {
                  setState(() {
                    _socialLinks = Map<String, String>.from(updated);
                  });
                }
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_socialLinks.isEmpty && _isOwnProfile)
            const ProfileEmptyState(
              text: 'No social links yet. Add your links!',
              card: true,
            )
          else if (_socialLinks.isEmpty)
            const SizedBox.shrink()
          else
            Row(
              children: [
                if (_socialLinks['instagram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openSocialLink('instagram', _socialLinks['instagram']!),
                      child: const Text('Instagram'),
                    ),
                  ),
                if (_socialLinks['instagram'] != null)
                  const SizedBox(width: 8),
                if (_socialLinks['spotify'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openSocialLink('spotify', _socialLinks['spotify']!),
                      child: const Text('Spotify'),
                    ),
                  ),
                if (_socialLinks['spotify'] != null)
                  const SizedBox(width: 8),
                if (_socialLinks['telegram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openSocialLink('telegram', _socialLinks['telegram']!),
                      child: const Text('Telegram'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHobbiesSection() {
    if (_interests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hobbies & Mood',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map(
                  (i) => Chip(
                label: Text(i),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessArticlesSection() {
    if (_fitnessArticles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Resources',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._fitnessArticles.map((a) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                a['title']?.toString() ?? '',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                a['source']?.toString() ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openArticle(a),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFitnessStatsSection() {
    final steps = _fitnessStats['steps'] ?? 0;
    final calories = _fitnessStats['caloriesBurned'] ?? 0;
    final workouts = _fitnessStats['workouts'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Stats',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isOwnProfile)
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditFitnessStatsPage(
                          initialStats: _fitnessStats,
                        ),
                      ),
                    );
                    await _loadProfileData();
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Steps', steps.toString(), 'Today'),
              _buildStatCard('Calories', calories.toString(), 'Today'),
              _buildStatCard('Sessions', workouts.toString(), 'This week'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  NEW PROFESSIONAL FEATURES FOR ASPIRANTS
  // ===================================================================

  Widget _buildProgressTrackingSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ProfileLayout.lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.trending_up, color: ProfileLayout.lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Progress Tracking',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToFullProgressPage(),
                  child: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isOwnProfile ? () => _editProgress('weight') : null,
                    child: _buildProgressCard(
                      'Weight',
                      '${(_fitnessStats['currentWeight'] ?? 70).toString()} kg',
                      'Goal: ${(_fitnessStats['targetWeight'] ?? 65).toString()} kg',
                      Icons.monitor_weight,
                      Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _isOwnProfile ? () => _editProgress('bodyFat') : null,
                    child: _buildProgressCard(
                      'Body Fat',
                      '${(_fitnessStats['bodyFat'] ?? 18).toString()}%',
                      'Target: ${(_fitnessStats['targetBodyFat'] ?? 15).toString()}%',
                      Icons.analytics,
                      Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_fitnessGoals.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Goals',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._fitnessGoals.take(3).map((goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: ProfileLayout.lavender),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            goal,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                        if (_isOwnProfile)
                          IconButton(
                            icon: Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                            onPressed: () => _editGoal(goal),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCalendarSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final workoutDays = List.generate(7, (i) => (i * 4) + 1); // Mock workout days
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ProfileLayout.lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.calendar_today, color: ProfileLayout.lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Workout Calendar',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    '${_getMonthName(currentMonth)} $currentYear',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) => 
                Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(daysInMonth, (index) {
                final day = index + 1;
                final isWorkoutDay = workoutDays.contains(day);
                final isToday = day == now.day;
                
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isToday 
                        ? ProfileLayout.lavender 
                        : isWorkoutDay 
                            ? ProfileLayout.lavender.withOpacity(0.2)
                            : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: isToday 
                        ? Border.all(color: ProfileLayout.lavender, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday 
                            ? Colors.white 
                            : isWorkoutDay 
                                ? ProfileLayout.lavender 
                                : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildLegendItem(ProfileLayout.lavender, 'Workout'),
                const SizedBox(width: 16),
                _buildLegendItem(ProfileLayout.lavender.withOpacity(0.3), 'Today'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildFitnessGoalsSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    return AspirantFitnessGoalsSection(
      goals: _fitnessGoals,
      onAddGoal: _addNewGoal,
      onEditGoal: _editGoal,
      onDeleteGoal: _deleteGoal,
      accentColor: ProfileLayout.lavender,
      accentDarkColor: ProfileLayout.deepLavender,
    );
  }

  Widget _buildWorkoutStreakSection() {
    final currentStreak = _fitnessStats['currentStreak'] ?? 5;
    final longestStreak = _fitnessStats['longestStreak'] ?? 12;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[100]!, Colors.orange[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange[700], size: 32),
                const SizedBox(width: 12),
                Text(
                  '$currentStreak',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Day Streak!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Keep it up! Your longest streak is $longestStreak days',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.orange[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalRecordsSection() {
    // Use Firebase data if available, otherwise use defaults
    final defaultRecords = [
      {'name': 'Fastest 5K', 'value': '28:45', 'icon': Icons.directions_run, 'color': Colors.blue},
      {'name': 'Max Bench Press', 'value': '85 kg', 'icon': Icons.fitness_center, 'color': Colors.red},
      {'name': 'Longest Plank', 'value': '3:15', 'icon': Icons.timer, 'color': Colors.green},
    ];
    
    final records = _personalRecords.isNotEmpty ? _personalRecords : defaultRecords;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ProfileLayout.lavender.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.emoji_events, color: ProfileLayout.lavender, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Personal Records',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return GestureDetector(
                  onTap: _isOwnProfile ? () => _editPersonalRecord(index, record) : null,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              record['icon'] is IconData 
                                  ? record['icon'] as IconData
                                  : _getIconFromString(record['icon']?.toString() ?? 'fitness_center'),
                              color: record['color'] is Color
                                  ? record['color'] as Color
                                  : _getColorFromString(record['color']?.toString() ?? 'blue'),
                              size: 24,
                            ),
                            if (_isOwnProfile)
                              Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            record['name']?.toString() ?? 'Record',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record['value']?.toString() ?? '0',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: record['color'] is Color
                                ? record['color'] as Color
                                : _getColorFromString(record['color']?.toString() ?? 'blue'),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    // Use Firebase data if available, otherwise use defaults
    final weeklyData = _weeklyProgressData.isNotEmpty
        ? _weeklyProgressData
        : [
            {'day': 'Mon', 'workouts': 2, 'calories': 450},
            {'day': 'Tue', 'workouts': 1, 'calories': 320},
            {'day': 'Wed', 'workouts': 3, 'calories': 680},
            {'day': 'Thu', 'workouts': 2, 'calories': 520},
            {'day': 'Fri', 'workouts': 1, 'calories': 380},
            {'day': 'Sat', 'workouts': 2, 'calories': 490},
            {'day': 'Sun', 'workouts': 0, 'calories': 0},
          ];
    
    final maxCalories = weeklyData.isNotEmpty
        ? weeklyData.map((d) => (d['calories'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b)
        : 680;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ProfileLayout.lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.bar_chart, color: ProfileLayout.lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Weekly Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    'This Week',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weeklyData.map((data) {
                final calories = (data['calories'] as num?)?.toInt() ?? 0;
                final height = maxCalories > 0 
                    ? (calories / maxCalories * 100).clamp(0.0, 100.0)
                    : 0.0;
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: calories > 0 
                            ? ProfileLayout.lavender 
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['day']?.toString() ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$calories',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeeklyStat('Total Workouts', '${weeklyData.map((d) => (d['workouts'] as num?)?.toInt() ?? 0).reduce((a, b) => a + b)}'),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildWeeklyStat('Calories Burned', '${weeklyData.map((d) => (d['calories'] as num?)?.toInt() ?? 0).reduce((a, b) => a + b)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ProfileLayout.lavender,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  //  POSTS GRID
  // ===================================================================
  /// Resolves post image URL from AddPostPage format (images/media) or legacy (imageUrl).
  Widget _buildRecentPostsGrid() {
    return AspirantRecentPostsGrid(
      isPrivate: _isPrivate,
      isFollowing: _isFollowing,
      isOwnProfile: _isOwnProfile,
      profileUserId: widget.profileUserId,
      accentColor: ProfileLayout.lavender,
      imageResolver: profilePostImageUrlFromMap,
      onTapPost: (postId) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PostDetailsPage(postId: postId),
          ),
        );
      },
      onTapViewAll: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => UserAllPostsPage(userId: widget.profileUserId),
          ),
        );
      },
    );
  }

  // ===================================================================
  //  BUILD  (Yahin se text ka color global dark ho raha hai)
// ===================================================================
  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);

    // 🔥 Detect background brightness
    final isDarkBg =
        ThemeData.estimateBrightnessForColor(ProfileLayout.bg) == Brightness.dark;

    // 🔥 Dynamic text color
    final textColor = isDarkBg ? Colors.white : Colors.black87;

    // 🔥 Apply dynamic text theme
    final textTheme = baseTheme.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: ProfileLayout.bg,
        body: ProfileLoadingGate(
          loading: _isLoading,
          child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: ProfileLayout.coverHeight,
              backgroundColor: ProfileLayout.lavender,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkBg ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (_isOwnProfile) ...[
                  IconButton(
                    icon: Icon(
                      Icons.add_box_outlined,
                      color: isDarkBg ? Colors.white : Colors.black,
                    ),
                    onPressed: _openGalleryForPost,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDarkBg ? Colors.white : Colors.black,
                    ),
                    onSelected: (value) async {
                      if (value == 'Edit Profile') {
                        await _handleEditProfile();
                      } else if (value == 'Privacy') {
                        if (_currentUser == null) return;
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PrivacySettingsPage(
                              initialPrivacy: _isPrivate,
                            ),
                          ),
                        );
                        if (updated != null) {
                          try {
                            await _firestore
                                .collection('users')
                                .doc(_currentUser!.uid)
                                .update({'isPrivate': updated});
                            setState(() => _isPrivate = updated);
                          } catch (e) {
                            Fluttertoast.showToast(
                                msg: 'Failed to update privacy');
                          }
                        }
                      } else if (value == 'Saved') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const SavedPostsPage(),
                          ),
                        );
                      } else if (value == 'Settings') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => SettingsPage(),
                          ),
                        );
                        if (result == 'logout') {
                          await _signOut();
                        }
                      } else if (value == 'Logout') {
                        await _signOut();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'Saved',
                        child: Text('Saved'),
                      ),
                      PopupMenuItem(
                        value: 'Settings',
                        child: Text('Settings'),
                      ),
                      PopupMenuItem(
                        value: 'Privacy',
                        child: Text('Privacy'),
                      ),
                      PopupMenuItem(
                        value: 'Edit Profile',
                        child: Text('Edit Profile'),
                      ),
                      PopupMenuItem(
                        value: 'Logout',
                        child: Text('Logout'),
                      ),
                    ],
                  ),
                ],
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: ProfileFlexibleSpaceCoverStack(
                  cover: _coverWidget(context),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ProfileLayout.identityColumnTopInset),

                  // Avatar + Name row (header)
                  AspirantIdentityBlock(
                    avatar: _avatarWidget(),
                    profileUserId: widget.profileUserId,
                    fullName: _fullName,
                    username: _username,
                    interests: _interests,
                    fitnessTag: _fitnessTag,
                    city: _city,
                    age: _age,
                  ),

                  const SizedBox(height: 14),
                  _buildStatsCard(),
                  const SizedBox(height: 12),
                  _buildActionButtons(),
                  _buildBioCard(),

                  // Halo-style sections
                  _buildAspirantTabsRow(),
                  _buildAspirantTabContent(),
                  _buildAchievementsSection(),
                  _buildLastWorkoutsSection(),
                  _buildRecentPostsGrid(),
                  _buildFitnessArticlesSection(),
                  _buildFitnessStatsSection(),
                  
                  // New Professional Features for Aspirants
                  _buildProgressTrackingSection(),
                  _buildWorkoutCalendarSection(),
                  _buildFitnessGoalsSection(),
                  _buildWorkoutStreakSection(),
                  _buildPersonalRecordsSection(),
                  _buildWeeklyProgressSection(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ===================================================================
  //  EDIT FUNCTIONS FOR NEW FEATURES
  // ===================================================================

  Future<void> _editProgress(String type) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final currentWeightCtrl = TextEditingController(
      text: (_fitnessStats['currentWeight'] ?? 70).toString(),
    );
    final targetWeightCtrl = TextEditingController(
      text: (_fitnessStats['targetWeight'] ?? 65).toString(),
    );
    final bodyFatCtrl = TextEditingController(
      text: (_fitnessStats['bodyFat'] ?? 18).toString(),
    );
    final targetBodyFatCtrl = TextEditingController(
      text: (_fitnessStats['targetBodyFat'] ?? 15).toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Progress',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentWeightCtrl,
                decoration: InputDecoration(
                  labelText: 'Current Weight (kg)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.monitor_weight, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetWeightCtrl,
                decoration: InputDecoration(
                  labelText: 'Target Weight (kg)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.flag, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyFatCtrl,
                decoration: InputDecoration(
                  labelText: 'Current Body Fat (%)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.analytics, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetBodyFatCtrl,
                decoration: InputDecoration(
                  labelText: 'Target Body Fat (%)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.track_changes, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ProfileLayout.lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              try {
                final updatedStats = {
                  ..._fitnessStats,
                  'currentWeight': double.tryParse(currentWeightCtrl.text) ?? _fitnessStats['currentWeight'] ?? 70,
                  'targetWeight': double.tryParse(targetWeightCtrl.text) ?? _fitnessStats['targetWeight'] ?? 65,
                  'bodyFat': double.tryParse(bodyFatCtrl.text) ?? _fitnessStats['bodyFat'] ?? 18,
                  'targetBodyFat': double.tryParse(targetBodyFatCtrl.text) ?? _fitnessStats['targetBodyFat'] ?? 15,
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'fitnessStats': updatedStats});
                
                setState(() => _fitnessStats = updatedStats);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Progress updated successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating progress: $e');
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewGoal() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final goalCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Fitness Goal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: TextField(
          controller: goalCtrl,
          decoration: InputDecoration(
            labelText: 'Goal Description',
            labelStyle: GoogleFonts.poppins(),
            hintText: 'e.g., Lose 10kg, Run a marathon',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: Icon(Icons.flag, color: ProfileLayout.lavender),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
            ),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ProfileLayout.lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (goalCtrl.text.trim().isEmpty) return;
              
              try {
                final updatedGoals = List<String>.from(_fitnessGoals)..add(goalCtrl.text.trim());
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'fitnessGoals': updatedGoals});
                
                setState(() => _fitnessGoals = updatedGoals);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Goal added successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding goal: $e');
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(String oldGoal) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final goalCtrl = TextEditingController(text: oldGoal);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Goal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: TextField(
          controller: goalCtrl,
          decoration: InputDecoration(
            labelText: 'Goal Description',
            labelStyle: GoogleFonts.poppins(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: Icon(Icons.flag, color: ProfileLayout.lavender),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
            ),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ProfileLayout.lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (goalCtrl.text.trim().isEmpty) return;
              
              try {
                final updatedGoals = List<String>.from(_fitnessGoals);
                final index = updatedGoals.indexOf(oldGoal);
                if (index != -1) {
                  updatedGoals[index] = goalCtrl.text.trim();
                  await _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({'fitnessGoals': updatedGoals});
                  
                  setState(() => _fitnessGoals = updatedGoals);
                  Navigator.pop(ctx);
                  Fluttertoast.showToast(msg: 'Goal updated successfully!');
                }
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating goal: $e');
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(String goal) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Goal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$goal"?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedGoals = List<String>.from(_fitnessGoals)..remove(goal);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'fitnessGoals': updatedGoals});
        
        setState(() => _fitnessGoals = updatedGoals);
        Fluttertoast.showToast(msg: 'Goal deleted successfully!');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting goal: $e');
      }
    }
  }

  // ===================================================================
  //  HELPER FUNCTIONS FOR STATIC FEATURES
  // ===================================================================
  
  Future<void> _openSocialLink(String platform, String link) async {
    try {
      String url = link;
      
      // If link doesn't start with http, add it
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Format URLs based on platform
        switch (platform.toLowerCase()) {
          case 'instagram':
            url = url.startsWith('@') 
                ? 'https://instagram.com/${url.substring(1)}'
                : 'https://instagram.com/$url';
            break;
          case 'spotify':
            url = 'https://open.spotify.com/user/$url';
            break;
          case 'telegram':
            url = url.startsWith('@')
                ? 'https://t.me/${url.substring(1)}'
                : 'https://t.me/$url';
            break;
          default:
            url = 'https://$url';
        }
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open $platform link');
      }
    } catch (e) {
      debugPrint('Error opening social link: $e');
      Fluttertoast.showToast(msg: 'Failed to open link');
    }
  }
  
  Future<void> _openArticle(Map<String, dynamic> article) async {
    try {
      final url = article['url']?.toString() ?? article['link']?.toString();
      if (url == null || url.isEmpty) {
        Fluttertoast.showToast(msg: 'Article link not available');
        return;
      }
      
      String articleUrl = url;
      if (!articleUrl.startsWith('http://') && !articleUrl.startsWith('https://')) {
        articleUrl = 'https://$articleUrl';
      }
      
      final uri = Uri.parse(articleUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open article');
      }
    } catch (e) {
      debugPrint('Error opening article: $e');
      Fluttertoast.showToast(msg: 'Failed to open article');
    }
  }
  
  Future<void> _navigateToFullProgressPage() async {
    if (!_isOwnProfile) return;
    
    // Show a detailed progress page with charts and history
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullProgressPage(
        fitnessStats: _fitnessStats,
        fitnessGoals: _fitnessGoals,
        onUpdate: () async {
          await _loadProfileData();
        },
      ),
    );
  }

  Future<void> _editPersonalRecord(int index, Map<String, dynamic> record) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController(text: record['name'] as String);
    final valueCtrl = TextEditingController(text: record['value'] as String);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Personal Record',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Record Name',
                labelStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(record['icon'] as IconData, color: record['color'] as Color),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueCtrl,
              decoration: InputDecoration(
                labelText: 'Record Value',
                labelStyle: GoogleFonts.poppins(),
                hintText: 'e.g., 28:45, 85 kg, 3:15',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.edit, color: ProfileLayout.lavender),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ProfileLayout.lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || valueCtrl.text.trim().isEmpty) return;
              
              try {
                // Update in main user document
                final updatedRecords = List<Map<String, dynamic>>.from(_personalRecords);
                if (index < updatedRecords.length) {
                  updatedRecords[index] = {
                    'name': nameCtrl.text.trim(),
                    'value': valueCtrl.text.trim(),
                    'icon': record['icon']?.toString() ?? 'fitness_center',
                    'color': record['color']?.toString() ?? 'blue',
                  };
                } else {
                  updatedRecords.add({
                    'name': nameCtrl.text.trim(),
                    'value': valueCtrl.text.trim(),
                    'icon': record['icon']?.toString() ?? 'fitness_center',
                    'color': record['color']?.toString() ?? 'blue',
                  });
                }
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({
                      'personalRecords': updatedRecords,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                
                setState(() => _personalRecords = updatedRecords);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Record updated successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating record: $e');
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper functions for Personal Records
  IconData _getIconFromString(String iconStr) {
    switch (iconStr.toLowerCase()) {
      case 'directions_run':
      case 'directionsrun':
        return Icons.directions_run;
      case 'fitness_center':
      case 'fitnesscenter':
        return Icons.fitness_center;
      case 'timer':
        return Icons.timer;
      default:
        return Icons.fitness_center;
    }
  }
  
  Color _getColorFromString(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

// ===================================================================
//  FULL PROGRESS PAGE (Modal Bottom Sheet)
// ===================================================================

class _FullProgressPage extends StatelessWidget {
  final Map<String, dynamic> fitnessStats;
  final List<String> fitnessGoals;
  final VoidCallback onUpdate;
  
  const _FullProgressPage({
    required this.fitnessStats,
    required this.fitnessGoals,
    required this.onUpdate,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Full Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weight Progress
                  _buildProgressCard(
                    'Weight Progress',
                    'Current: ${fitnessStats['currentWeight'] ?? 70} kg',
                    'Target: ${fitnessStats['targetWeight'] ?? 65} kg',
                    Icons.monitor_weight,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  // Body Fat Progress
                  _buildProgressCard(
                    'Body Fat Progress',
                    'Current: ${fitnessStats['bodyFat'] ?? 18}%',
                    'Target: ${fitnessStats['targetBodyFat'] ?? 15}%',
                    Icons.analytics,
                    Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  // Goals Section
                  if (fitnessGoals.isNotEmpty) ...[
                    Text(
                      'Active Goals',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...fitnessGoals.map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: const Color(0xFFA58CE3), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              goal,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressCard(String title, String current, String target, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            current,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            target,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
//  PLACEHOLDER PAGES
// ===================================================================

class PostDetailsPage extends StatelessWidget {
  final String postId;
  const PostDetailsPage({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Center(child: Text('Post: $postId')),
    );
  }
}

class UserAllPostsPage extends StatelessWidget {
  final String userId;
  const UserAllPostsPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Posts')),
      body: Center(child: Text('All posts for $userId')),
    );
  }
}
