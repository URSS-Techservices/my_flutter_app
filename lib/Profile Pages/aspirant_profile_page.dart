// profile_page_improved.dart  (Aspirant Profile)

// -------------------- IMPORTS --------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/newpostpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:halo/screens/profile/core/profile_follow_toggle.dart';
import 'package:halo/platform/profile_avatar_provider.dart';
import 'package:halo/platform/profile_local_photo.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/screens/profile/core/profile_media_upload.dart';
import 'package:halo/screens/profile/profile_router_screen.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_image_url.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';


// Local pages (paths adjust kar lena agar different ho)
import '../editprofilepage.dart';
import '../main.dart'; // LoginPage
import 'package:halo/Bottom Pages/PrivacySettingsPage.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:halo/Bottom Pages/saved_posts_page.dart';
import 'package:halo/utils/search_utils.dart';
import 'package:halo/utils/shell_back.dart';
import 'package:halo/services/follow_service.dart';
import 'package:halo/widgets/profile_image_interactions.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_identity_block.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_action_row.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_bio_card.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_fitness_goals_section.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state_rich.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_card.dart';
import 'package:halo/screens/profile/widgets/common/profile_avatar_hero_shell.dart';
import 'package:halo/screens/profile/widgets/common/profile_cover_hero.dart';
import 'package:halo/screens/profile/widgets/common/profile_flexible_space_cover_stack.dart';
import 'package:halo/screens/profile/widgets/common/profile_media_preview_helpers.dart';
import 'package:halo/screens/profile/widgets/common/profile_stats_bar.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_profile_shell.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_profile_tab_content.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_posts_tab.dart';
import 'package:halo/screens/profile/widgets/common/profile_inline_tab_chip.dart';
import 'package:halo/screens/profile/pages/follow_list_page.dart';
import 'package:halo/models/aspirant_profile_model.dart';
import 'package:halo/models/post_place.dart';
import 'package:halo/screens/profile/configs/aspirant_profile_config.dart';
import 'package:halo/screens/profile/core/profile_field_utils.dart';
import 'package:halo/screens/profile/core/profile_posts_queries.dart';
import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/pages/aspirant_edit_profile_hub.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_progress_hub.dart';
import 'package:halo/screens/profile/widgets/common/profile_completeness_meter.dart';
import 'package:halo/screens/profile/widgets/common/profile_highlights_row.dart';
import 'package:halo/Bottom Pages/SearchPage.dart';
import 'package:halo/screens/profile/pages/profile_modules_editor_page.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_gate.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_recent_posts_grid.dart';
import 'edit_profile_sections.dart';

// ===================================================================
//  ASPIRANT PROFILE PAGE (HALO – HOBBY BASED ASPIRANT)
// ===================================================================

/// Wrapper class
class ProfilePage extends StatelessWidget {
  final String profileUserId; // Jis aspirant ki profile dekhni hai
  final VoidCallback? onBackToHome;

  const ProfilePage({Key? key, required this.profileUserId, this.onBackToHome})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfilePageImproved(
      profileUserId: profileUserId,
      onBackToHome: onBackToHome,
    );
  }
}

class ProfilePageImproved extends StatefulWidget {
  final String profileUserId;
  final VoidCallback? onBackToHome;

  const ProfilePageImproved({
    Key? key,
    required this.profileUserId,
    this.onBackToHome,
  }) : super(key: key);

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
  List<FitnessGoalItem> _fitnessGoalItems = [];
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
  // Image picker
  final ImagePicker _picker = ImagePicker();
  ProfileLocalPhoto? _profilePhotoLocal;
  ProfileLocalPhoto? _coverPhotoLocal;

  List<int> _workoutCalendarDays = [];
  AspirantProfileModules _profileModules = const AspirantProfileModules();
  List<Map<String, dynamic>> _highlightPosts = [];
  Map<String, dynamic> _userDocSnapshot = {};

  // Animations
  late final AnimationController _followAnimController;
  final GlobalKey<AspirantProfileShellState> _shellKey =
      GlobalKey<AspirantProfileShellState>();

  @override
  void initState() {
    super.initState();
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadProfileData(); // aspirant data load
  }

  @override
  void dispose() {
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
        _fullName = ProfileFieldUtils.displayName(data);
        _username = (data['username'] ?? '') as String;
        _fitnessTag = (data['fitnessTag'] ?? 'Explorer on Halo') as String;
        _city = (data['city'] ?? '') as String;
        _age = data['age'] is int ? data['age'] as int : null;
        _bio = (data['bio'] ?? '') as String;
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;
        _fitnessGoalItems = parseFitnessGoals(data['fitnessGoals']);
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
            'currentWeight': data['currentWeight'] ?? 0,
            'targetWeight': data['targetWeight'] ?? 0,
            'bodyFat': data['bodyFat'] ?? 0,
            'targetBodyFat': data['targetBodyFat'] ?? 0,
            'currentStreak': data['currentStreak'] ?? 0,
            'longestStreak': data['longestStreak'] ?? 0,
          };
        }

        final recordsRaw = data['personalRecords'] as List<dynamic>?;
        _personalRecords = parseRecordList(recordsRaw);

        final weeklyRaw = data['weeklyProgressData'] as List<dynamic>?;
        _weeklyProgressData = parseWeeklyProgress(weeklyRaw);

        final calRaw = data['workoutCalendarDays'] as List<dynamic>?;
        _workoutCalendarDays = calRaw
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [];

        final modulesRaw =
            data['profileModules'] as Map<String, dynamic>?;
        _profileModules = AspirantProfileModules.fromMap(modulesRaw);
        _userDocSnapshot = Map<String, dynamic>.from(data);

        // Social links
        final sl = data['socialLinks'] as Map<String, dynamic>?;
        _socialLinks = sl != null
            ? sl.map((k, v) => MapEntry(k, v.toString()))
            : {};
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

      _highlightPosts = await ProfilePostsQueries.fetchAspirantProfilePostsPreview(
        firestore: _firestore,
        profileUserId: widget.profileUserId,
      );
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
  Future<void> _pickProfileImage() async {
    if (!_isOwnProfile || _currentUser == null) return; // sirf apni profile edit
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final edited = await editProfileImageWithInstagramStyle(
      context,
      picked: picked,
      outputNamePrefix: 'profile',
    );
    if (edited == null) return;
    setState(() => _profilePhotoLocal = edited);
    await _uploadAndSaveProfilePhoto(edited, isCover: false);
  }

  Future<void> _pickCoverImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final edited = await editProfileImageWithInstagramStyle(
      context,
      picked: picked,
      outputNamePrefix: 'cover',
    );
    if (edited == null) return;
    setState(() => _coverPhotoLocal = edited);
    await _uploadAndSaveProfilePhoto(edited, isCover: true);
  }

  void _previewCoverImage() {
    openProfileStoredImagePreview(
      context: context,
      localPath: _coverPhotoLocal?.path,
      localBytes: _coverPhotoLocal?.previewBytes,
      remoteUrl: _coverPhotoUrl,
      heroTag: 'aspirant-cover-${widget.profileUserId}',
    );
  }

  void _previewProfileImage() {
    openProfileStoredImagePreview(
      context: context,
      localPath: _profilePhotoLocal?.path,
      localBytes: _profilePhotoLocal?.previewBytes,
      remoteUrl: _profilePhotoUrl,
      heroTag: 'profile-avatar-${widget.profileUserId}',
    );
  }

  Future<void> _uploadAndSaveProfilePhoto(
    ProfileLocalPhoto local, {
    required bool isCover,
  }) async {
    if (_currentUser == null) return;
    try {
      final url = await ProfileMediaUpload.uploadUserPhotoAndPersist(
        firestore: _firestore,
        userId: _currentUser!.uid,
        media: await local.toXFile(),
        isCover: isCover,
      );

      if (!mounted) return;
      setState(() {
        if (isCover) {
          _coverPhotoUrl = url;
          _coverPhotoLocal = null;
        } else {
          _profilePhotoUrl = url;
          _profilePhotoLocal = null;
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
              final url = await uploadReferenceXFileAndGetUrl(
                ref,
                image,
                metadata: SettableMetadata(contentType: 'image/jpeg'),
              );
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
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => AspirantEditProfileHub(initialData: _userDocSnapshot),
      ),
    );
    if (saved == true) {
      await _loadProfileData();
    }
  }

  void _openSearchForGoal(FitnessGoalItem goal, {required String accountType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(initialQuery: '${goal.name} $accountType'),
      ),
    );
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
    final cover = profileHeroImageProvider(
      local: _coverPhotoLocal,
      remoteUrl: _coverPhotoUrl,
      defaultAsset: const AssetImage('assets/images/bio.png'),
    );

    return ProfileCoverHero(
      cover: cover,
      heroTag: 'aspirant-cover-${widget.profileUserId}',
      onTap: _isOwnProfile ? _pickCoverImage : _previewCoverImage,
      onLongPress: _previewCoverImage,
    );
  }

  Widget _avatarWidget() {
    final avatar = profileHeroImageProvider(
      local: _profilePhotoLocal,
      remoteUrl: _profilePhotoUrl,
      defaultAsset: const AssetImage('assets/images/Profile.png'),
    );

    return ProfileAvatarHeroShell(
      avatar: avatar,
      heroTag: 'profile-avatar-${widget.profileUserId}',
      onTap: _isOwnProfile ? _pickProfileImage : _previewProfileImage,
      onLongPress: _previewProfileImage,
    );
  }

  bool _isSectionEnabled(String sectionId) =>
      AspirantProfileConfig.isSectionEnabled(_profileModules, sectionId);

  Widget _buildStatsCard() {
    return ProfileThreeColumnStatsCard(
      followers: _followersCount,
      following: _followingCount,
      posts: _postsCount,
      onTapFollowers: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FollowListPage(
              userId: widget.profileUserId,
              kind: FollowListKind.followers,
            ),
          ),
        );
      },
      onTapFollowing: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FollowListPage(
              userId: widget.profileUserId,
              kind: FollowListKind.following,
            ),
          ),
        );
      },
      onTapPosts: () => _shellKey.currentState?.jumpToPostsTab(),
    );
  }

  Widget _buildActionButtons() {
    return AspirantActionRow(
      isOwnProfile: _isOwnProfile,
      isFollowing: _isFollowing,
      onToggleFollow: _toggleFollow,
      onMessage: _openMessage,
      onEditProfile: _handleEditProfile,
      onSavedPosts: _isOwnProfile
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedPostsPage(),
                ),
              );
            }
          : null,
      accentColor: ProfileLayout.lavender,
    );
  }

  Widget _buildBioCard() {
    return AspirantBioCard(
      bio: _bio,
      isOwnProfile: _isOwnProfile,
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      body: DefaultTextStyle(
        style: GoogleFonts.poppins(
          color: ProfileLayout.textPrimary,
          fontSize: 14,
        ),
        child: AspirantProfileShell(
          key: _shellKey,
          loading: _isLoading,
          onBack: () => popOrGoHome(
            context,
            onBackToHome: widget.onBackToHome,
          ),
          cover: ProfileFlexibleSpaceCoverStack(
            cover: _coverWidget(context),
          ),
          appBarActions: _buildAppBarActions(),
          header: _buildProfileHeader(),
          profileTab: _buildProfileTabContent(),
          postsTab: AspirantPostsTab(
            profileUserId: widget.profileUserId,
            isPrivate: _isPrivate,
            isFollowing: _isFollowing,
            isOwnProfile: _isOwnProfile,
            imageResolver: profilePostImageUrlFromMap,
            onTapPost: (postId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailsPage(postId: postId),
                ),
              );
            },
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

  Future<void> _openProfileModules() async {
    if (!_isOwnProfile) return;
    final updated = await openProfileModulesEditor(
      context,
      kind: ProfileKind.aspirant,
      initialModulesRaw: _profileModules.toMap(),
    );
    if (updated != null && mounted) {
      setState(() {
        _profileModules = AspirantProfileModules.fromMap(updated);
      });
    }
  }

  void _openInterestExplore(String interest) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(initialQuery: interest),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (!_isOwnProfile) return [];
    return [
      IconButton(
        icon: const Icon(Icons.add_box_outlined, color: Colors.white),
        onPressed: _openGalleryForPost,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) async {
          if (value == 'Edit Profile') {
            await _handleEditProfile();
          } else if (value == 'Profile Sections') {
            await _openProfileModules();
          } else if (value == 'Privacy') {
            if (_currentUser == null) return;
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => PrivacySettingsPage(initialPrivacy: _isPrivate),
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
                Fluttertoast.showToast(msg: 'Failed to update privacy');
              }
            }
          } else if (value == 'Saved') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedPostsPage()),
            );
          } else if (value == 'Settings') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage()),
            );
            if (result == 'logout') await _signOut();
          } else if (value == 'Logout') {
            await _signOut();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'Saved', child: Text('Saved')),
          PopupMenuItem(value: 'Settings', child: Text('Settings')),
          PopupMenuItem(value: 'Privacy', child: Text('Privacy')),
          PopupMenuItem(
              value: 'Profile Sections', child: Text('Profile Sections')),
          PopupMenuItem(value: 'Edit Profile', child: Text('Edit Profile')),
          PopupMenuItem(value: 'Logout', child: Text('Logout')),
        ],
      ),
    ];
  }

  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: ProfileLayout.identityColumnTopInset),
        AspirantIdentityBlock(
          avatar: _avatarWidget(),
          profileUserId: widget.profileUserId,
          fullName: _fullName,
          username: _username,
          interests: _interests,
          fitnessTag: _fitnessTag,
          city: _city,
          age: _age,
          primaryCategory: _primaryCategory,
          fitnessLevel: _fitnessLevel,
          healthNotes: _healthNotes,
          showHealthNotes: _isOwnProfile,
          onInterestTap: _openInterestExplore,
        ),
        const SizedBox(height: 14),
        _buildStatsCard(),
        const SizedBox(height: 12),
        _buildActionButtons(),
        _buildBioCard(),
        if (_isOwnProfile)
          ProfileCompletenessMeter(
            kind: ProfileKind.aspirant,
            userData: _userDocSnapshot,
            onTapImprove: _handleEditProfile,
          ),
        ProfileHighlightsRow(
          posts: _highlightPosts,
          onTapPost: (postId) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailsPage(postId: postId)),
            );
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildProfileTabContent() {
    return AspirantProfileTabContent(
      profileUserId: widget.profileUserId,
      currentUserId: _currentUser?.uid,
      isOwnProfile: _isOwnProfile,
      isPrivate: _isPrivate,
      isFollowing: _isFollowing,
      interests: _interests,
      primaryCategory: _primaryCategory,
      eventsChallenges: _eventsChallenges,
      socialLinks: _socialLinks,
      badges: _badges,
      lastWorkouts: _lastWorkouts,
      fitnessArticles: _fitnessArticles,
      fitnessStats: _fitnessStats,
      fitnessGoals: _fitnessGoalItems,
      personalRecords: _personalRecords,
      weeklyProgressData: _weeklyProgressData,
      workoutCalendarDays: _workoutCalendarDays,
      isSectionEnabled: _isSectionEnabled,
      monthName: _getMonthName,
      workoutDaysForMonth: workoutDaysForMonth,
      onOpenInterestExplore: _openInterestExplore,
      onOpenSocialLink: _openSocialLink,
      onEditEvents: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => EditEventsChallengesPage(initialEvents: _eventsChallenges),
          ),
        );
        if (updated != null && mounted) {
          setState(() => _eventsChallenges = List<Map<String, dynamic>>.from(updated));
        }
      },
      onEditSocialLinks: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => EditSocialLinksPage(initialLinks: _socialLinks),
          ),
        );
        if (updated != null && mounted) {
          setState(() => _socialLinks = Map<String, String>.from(updated));
        }
      },
      onOpenProfileModules: _openProfileModules,
      onEditActivities: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => EditWorkoutsPage(
              initialWorkouts: _lastWorkouts,
              userType: 'aspirant',
            ),
          ),
        );
        if (updated != null && mounted) {
          setState(() => _lastWorkouts = List<Map<String, dynamic>>.from(updated));
        }
      },
      onEditFitnessStats: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => EditFitnessStatsPage(initialStats: _fitnessStats),
          ),
        );
        await _loadProfileData();
      },
      onOpenArticle: _openArticle,
      onViewFullProgress: _navigateToFullProgressPage,
      onEditProgress: _editProgress,
      onAddGoal: _addNewGoal,
      onEditGoal: _editGoal,
      onDeleteGoal: _deleteGoal,
      onFindCoachesForGoal: (goal) => _openSearchForGoal(goal, accountType: 'guru'),
      onFindWellnessForGoal: (goal) => _openSearchForGoal(goal, accountType: 'wellness'),
      onEditPersonalRecord: _editPersonalRecord,
      onAddWorkoutFromCalendar: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => EditWorkoutsPage(
              initialWorkouts: _lastWorkouts,
              userType: 'aspirant',
            ),
          ),
        );
        if (updated != null && mounted) {
          setState(() => _lastWorkouts = List<Map<String, dynamic>>.from(updated));
        }
      },
      postImageResolver: profilePostImageUrlFromMap,
      onTapPost: (postId) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailsPage(postId: postId)),
        );
      },
      onTapViewAllPosts: () => _shellKey.currentState?.jumpToPostsTab(),
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
                final updated = List<FitnessGoalItem>.from(_fitnessGoalItems)
                  ..add(FitnessGoalItem(name: goalCtrl.text.trim()));
                await _firestore.collection('users').doc(_currentUser!.uid).update({
                  'fitnessGoals': updated.map((g) => g.toMap()).toList(),
                });

                setState(() => _fitnessGoalItems = updated);
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

  Future<void> _editGoal(FitnessGoalItem oldGoal) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final goalCtrl = TextEditingController(text: oldGoal.name);
    final progressCtrl = TextEditingController(
      text: (oldGoal.progress * 100).round().toString(),
    );
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: goalCtrl,
              decoration: InputDecoration(
                labelText: 'Goal Description',
                labelStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.flag, color: ProfileLayout.lavender),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: progressCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Progress (%)',
                labelStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon:
                    Icon(Icons.percent, color: ProfileLayout.lavender),
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
              if (goalCtrl.text.trim().isEmpty) return;

              try {
                final pct =
                    (double.tryParse(progressCtrl.text.trim()) ?? 0) / 100;
                final updated = List<FitnessGoalItem>.from(_fitnessGoalItems);
                final index = updated.indexWhere((g) => g.name == oldGoal.name);
                if (index != -1) {
                  updated[index] = FitnessGoalItem(
                    name: goalCtrl.text.trim(),
                    progress: pct.clamp(0.0, 1.0),
                  );
                  await _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({
                    'fitnessGoals': updated.map((g) => g.toMap()).toList(),
                  });

                  setState(() => _fitnessGoalItems = updated);
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

  Future<void> _deleteGoal(FitnessGoalItem goal) async {
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
          'Are you sure you want to delete "${goal.name}"?',
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
        final updated = List<FitnessGoalItem>.from(_fitnessGoalItems)
          ..removeWhere((g) => g.name == goal.name);
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'fitnessGoals': updated.map((g) => g.toMap()).toList(),
        });

        setState(() => _fitnessGoalItems = updated);
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
        fitnessGoals: _fitnessGoalItems.map((g) => g.name).toList(),
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
      backgroundColor: ProfileLayout.bg,
      appBar: AppBar(
        backgroundColor: ProfileLayout.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text('Post', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ProfileLayout.lavender),
            );
          }
          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text('Post not found'));
          }
          final caption = (data['caption'] ?? '').toString();
          final location = PostPlace.labelFromPostData(data);
          final imageUrl = profilePostImageUrlFromMap(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: ProfileLayout.deepLavender),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: ProfileLayout.deepLavender,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(caption, style: GoogleFonts.poppins(fontSize: 14)),
              ],
            ],
          );
        },
      ),
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
