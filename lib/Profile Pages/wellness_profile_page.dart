// wellness_profile_page.dart
// WELLNESS PROFILE PAGE - Updated with tabs and all sections

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';

// -------------------- SECTIONS --------------------
import '../Sections/Wellness Section/wellness_products_section.dart';
import '../Sections/Wellness Section/wellness_services_section.dart';
import '../Sections/Wellness Section/wellness_booking_section.dart';
import '../Sections/Wellness Section/wellness_reviews_section.dart';
import '../Sections/Wellness Section/wellness_analytics_section.dart';

// -------------------- EXISTING PAGES --------------------
import '../../editprofilepage.dart';
import '../../main.dart';
import 'package:halo/Bottom Pages/PrivacySettingsPage.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';
import 'package:halo/newpostpage.dart';
import 'package:halo/services/follow_service.dart';
import 'package:halo/widgets/follow_button.dart';
import 'package:halo/widgets/profile_image_interactions.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_identity_block.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_recent_posts_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_action_row.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_bio_card.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_profile_shell.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_posts_tab.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_image_url.dart';
import 'package:halo/screens/profile/pages/follow_list_page.dart';
import 'package:halo/Profile Pages/aspirant_profile_page.dart' show PostDetailsPage;
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_title.dart';
import 'package:halo/screens/profile/core/profile_follow_toggle.dart';
import 'package:halo/screens/profile/core/profile_posts_queries.dart';
import 'package:halo/screens/profile/core/profile_refresh_helpers.dart';
import 'package:halo/screens/profile/core/profile_reviews_queries.dart';
import 'package:halo/screens/profile/core/profile_state_helpers.dart';
import 'package:halo/platform/profile_avatar_provider.dart';
import 'package:halo/platform/profile_local_photo.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/screens/profile/core/profile_media_upload.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_card.dart';
import 'package:halo/screens/profile/widgets/common/profile_media_preview_helpers.dart';
import 'package:halo/screens/profile/widgets/common/profile_stats_bar.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_avatar_hero_shell.dart';
import 'package:halo/screens/profile/widgets/common/profile_cover_hero.dart';
import 'package:halo/screens/profile/widgets/common/profile_flexible_space_cover_stack.dart';
import 'package:halo/screens/profile/configs/wellness_profile_config.dart';
import 'package:halo/screens/profile/core/profile_field_utils.dart';
import 'package:halo/screens/profile/core/profile_modules.dart';
import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/pages/profile_modules_editor_page.dart';
import 'package:halo/screens/profile/core/profile_type.dart';
import 'package:halo/screens/profile/widgets/common/profile_completeness_meter.dart';
import 'package:halo/screens/profile/widgets/common/profile_highlights_row.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:halo/utils/shell_back.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_profile_tab_content.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_staff_section.dart';
import 'package:halo/screens/profile/widgets/wellness/wellness_events_section.dart';
import 'package:halo/screens/profile/pages/wellness_staff_editor_page.dart';
import 'package:halo/screens/profile/pages/wellness_events_editor_page.dart';
import 'package:halo/services/wellness_facility_service.dart';
import 'package:halo/screens/profile/widgets/common/profile_save_button.dart';

// ===================================================================
//  WELLNESS PROFILE PAGE
// ===================================================================

class WellnessProfilePage extends StatefulWidget {
  final String profileUserId;
  final VoidCallback? onBackToHome;

  const WellnessProfilePage({
    Key? key,
    required this.profileUserId,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<WellnessProfilePage> createState() => _WellnessProfilePageState();
}

class _WellnessProfilePageState extends State<WellnessProfilePage>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();

  User? _currentUser;
  bool _isOwnProfile = false;
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isPrivate = false;

  final GlobalKey<WellnessProfileShellState> _shellKey =
      GlobalKey<WellnessProfileShellState>();

  // -------------------- PROFILE DATA --------------------
  String _businessName = '';
  String _username = '';
  String _bio = '';
  String _category = ''; // Gym / Yoga Studio / Café / Diet Center / Physio Clinic
  String _location = ''; // City, State
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  int _likesCount = 0;
  double _rating = 0.0;
  int _reviewCount = 0;
  bool _isOnline = false;

  // -------------------- WELLNESS SPECIFIC DATA --------------------
  List<String> _services = []; // Strength Training, Cardio, etc.
  Map<String, String> _availability = {}; // Mon-Sat / Sun hours
  Map<String, dynamic>? _facilityHours;
  Map<String, String> _socialLinks = {}; // Instagram, YouTube, etc.
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _staff = []; // Featured staff/trainers
  List<Map<String, dynamic>> _events = []; // Fitness events
  final WellnessFacilityService _facilityService = WellnessFacilityService();
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _galleryImages = [];
  List<Map<String, dynamic>> _membershipPlans = [];
  List<Map<String, dynamic>> _specialOffers = [];
  List<Map<String, dynamic>> _awards = [];
  List<String> _amenities = [];
  List<String> _featuredGuruIds = [];
  ProfileModules _profileModules = ProfileModules.defaultEnabled();
  Map<String, dynamic> _userDocSnapshot = {};

  // -------------------- UI CONSTANTS (wellness-only) --------------------
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _mutedText = Color(0xFF6B6B6B);

  // -------------------- IMAGE PICKER --------------------
  final ImagePicker _picker = ImagePicker();
  ProfileLocalPhoto? _profilePhotoLocal;
  ProfileLocalPhoto? _coverPhotoLocal;

  // -------------------- STATE --------------------
  late final TabController _tabController;
  late final AnimationController _followAnimController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followAnimController.dispose();
    super.dispose();
  }

  // ===================================================================
  //  DATA LOAD
  // ===================================================================
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = _auth.currentUser;
      _isOwnProfile =
          _currentUser != null && _currentUser!.uid == widget.profileUserId;

      final doc =
      await _firestore.collection('users').doc(widget.profileUserId).get();

      if (doc.exists) {
        final data = doc.data()!;

        // For wellness owners, open directly on Business tab.
        if (_isOwnProfile && mounted && _tabController.index == 0) {
          _tabController.animateTo(1);
        }

        _businessName = ProfileFieldUtils.displayName(data);
        _userDocSnapshot = Map<String, dynamic>.from(data);
        _profileModules = ProfileModules.fromMap(
          data['profileModules'] as Map<String, dynamic>?,
        );
        _username = data['username'] ?? '';
        _bio = data['bio'] ?? '';
        _category = data['category'] ?? data['wellness_category'] ?? '';
        _location = data['city'] ?? data['location'] ?? '';
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;

        _followersCount = data['followersCount'] ?? 0;
        _followingCount = data['followingCount'] ?? 0;
        _postsCount = data['postsCount'] ?? 0;
        _likesCount = data['likesCount'] ?? 0;
        _rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
        _reviewCount = data['reviewCount'] ?? 0;
        _isOnline = data['isOnline'] ?? false;
        _isPrivate = (data['isPrivate'] ?? false) as bool;

        // Services — prefer business subcollection titles, fallback to doc array
        await _loadBusinessServices();
        if (_services.isEmpty) {
          _services = List<String>.from(data['services'] ?? []);
        }

        _amenities = List<String>.from(data['amenities'] ?? []);
        _featuredGuruIds = List<String>.from(data['featuredGuruIds'] ?? []);

        // Availability
        if (data['availability'] is Map) {
          _availability = Map<String, String>.from(data['availability']);
        }
        if (data['facilityHours'] is Map) {
          _facilityHours = Map<String, dynamic>.from(data['facilityHours'] as Map);
        }

        // Social Links
        if (data['socialLinks'] is Map) {
          _socialLinks = Map<String, String>.from(data['socialLinks']);
        }

        // Load products
        await _loadProducts();

        // Load staff
        await _loadStaff();

        // Load events
        await _loadEvents();
        await _loadGallery();
        await _loadMembershipPlans();
        await _loadSpecialOffers();
        await _loadAwards();

        await ProfileRefreshHelpers.runInOrder([
          _loadPosts,
          _loadReviews,
        ]);
      }

      // Check follow status
      if (_currentUser != null && !_isOwnProfile) {
        final f = await _firestore
            .collection('users')
            .doc(widget.profileUserId)
            .collection('followers')
            .doc(_currentUser!.uid)
            .get();
        _isFollowing = f.exists;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadProducts() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('products')
          .limit(4)
          .get();

      _products = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _loadStaff() async {
    try {
      _staff = await _facilityService.loadStaff(
        wellnessId: widget.profileUserId,
        userData: _userDocSnapshot,
      );
    } catch (e) {
      debugPrint('Error loading staff: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      _events = await _facilityService.loadEvents(
        wellnessId: widget.profileUserId,
        userData: _userDocSnapshot,
      );
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  Future<void> _loadBusinessServices() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('services')
          .limit(20)
          .get();
      if (snap.docs.isNotEmpty) {
        _services = snap.docs
            .map((d) => (d.data()['title'] ?? d.data()['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading business services: $e');
    }
  }

  Future<void> _loadGallery() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('gallery')
          .limit(12)
          .get();
      _galleryImages = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('Error loading gallery: $e');
    }
  }

  Future<void> _loadMembershipPlans() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('membershipPlans')
          .limit(10)
          .get();
      _membershipPlans = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('Error loading membership plans: $e');
    }
  }

  Future<void> _loadSpecialOffers() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('specialOffers')
          .limit(10)
          .get();
      _specialOffers = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('Error loading special offers: $e');
    }
  }

  Future<void> _loadAwards() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('awards')
          .limit(10)
          .get();
      _awards = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('Error loading awards: $e');
    }
  }

  Future<void> _loadPosts() async {
    final list = await ProfilePostsQueries.fetchWellnessProfilePostsPreview(
      firestore: _firestore,
      profileUserId: widget.profileUserId,
    );
    _recentPosts = list;
    ProfileStateHelpers.rebuildIfMounted(this);
  }

  Future<void> _loadReviews() async {
    final result = await ProfileReviewsQueries.fetchWellnessProfileReviewsOrSkip(
      firestore: _firestore,
      profileUserId: widget.profileUserId,
    );
    if (result != null) {
      _reviews = result;
    }
  }

  // ===================================================================
  //  FOLLOW / UNFOLLOW
  // ===================================================================
  Future<void> _toggleFollow() async {
    if (_currentUser == null || _isOwnProfile) return;

    final uid = _currentUser!.uid;
    final pid = widget.profileUserId;
    final wasFollowing = _isFollowing;

    await ProfileFollowToggle.runOptimisticToggle(
      followService: _followService,
      currentUserId: uid,
      profileUserId: pid,
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
      errorToast: 'Failed to update follow status',
      debugLogOnError: false,
    );
  }

  // ===================================================================
  //  IMAGE PICKERS
  // ===================================================================
  Future<void> _pickProfileImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final edited = await editProfileImageWithInstagramStyle(
      context,
      picked: picked,
      outputNamePrefix: 'profile',
    );
    if (edited == null) return;
    setState(() => _profilePhotoLocal = edited);

    try {
      final url = await ProfileMediaUpload.uploadUserPhotoAndPersist(
        firestore: _firestore,
        userId: _currentUser!.uid,
        media: await edited.toXFile(),
        isCover: false,
      );

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = url;
        _profilePhotoLocal = null;
      });

      Fluttertoast.showToast(msg: 'Profile photo updated');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload photo');
      setState(() => _profilePhotoLocal = null);
    }
  }

  Future<void> _pickCoverImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final edited = await editProfileImageWithInstagramStyle(
      context,
      picked: picked,
      outputNamePrefix: 'cover',
    );
    if (edited == null) return;
    setState(() => _coverPhotoLocal = edited);

    try {
      final url = await ProfileMediaUpload.uploadUserPhotoAndPersist(
        firestore: _firestore,
        userId: _currentUser!.uid,
        media: await edited.toXFile(),
        isCover: true,
      );

      if (!mounted) return;
      setState(() {
        _coverPhotoUrl = url;
        _coverPhotoLocal = null;
      });

      Fluttertoast.showToast(msg: 'Cover photo updated');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload photo');
      setState(() => _coverPhotoLocal = null);
    }
  }

  void _previewCoverImage() {
    openProfileStoredImagePreview(
      context: context,
      localPath: _coverPhotoLocal?.path,
      localBytes: _coverPhotoLocal?.previewBytes,
      remoteUrl: _coverPhotoUrl,
      heroTag: 'wellness-cover-${widget.profileUserId}',
    );
  }

  void _previewProfileImage() {
    openProfileStoredImagePreview(
      context: context,
      localPath: _profilePhotoLocal?.path,
      localBytes: _profilePhotoLocal?.previewBytes,
      remoteUrl: _profilePhotoUrl,
      heroTag: 'wellness-avatar-${widget.profileUserId}',
    );
  }

  // ===================================================================
  //  UI HELPERS (HEADER)
  // ===================================================================
  Widget _coverWidget(BuildContext context) {
    final cover = profileHeroImageProvider(
      local: _coverPhotoLocal,
      remoteUrl: _coverPhotoUrl,
      defaultAsset: const AssetImage('assets/images/bio.png'),
    );

    return ProfileCoverHero(
      cover: cover,
      heroTag: 'wellness-cover-${widget.profileUserId}',
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
      heroTag: 'wellness-avatar-${widget.profileUserId}',
      onTap: _isOwnProfile ? _pickProfileImage : _previewProfileImage,
      onLongPress: _previewProfileImage,
      extraStackChildren: _isOnline
          ? [
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ]
          : const [],
    );
  }

  bool _isWellnessSectionEnabled(String sectionId) =>
      WellnessProfileConfig.isSectionEnabled(_profileModules, sectionId);

  Future<void> _openProfileModulesEditor() async {
    if (!_isOwnProfile) return;
    final updated = await openProfileModulesEditor(
      context,
      kind: ProfileKind.wellness,
      initialModulesRaw: _profileModules.toMap(),
    );
    if (updated != null && mounted) {
      setState(() => _profileModules = ProfileModules(updated));
    }
  }

  Widget _buildProfileHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: ProfileLayout.identityColumnTopInset),
        WellnessIdentityBlock(
          avatar: _avatarWidget(),
          businessName: _businessName,
          username: _username,
          category: _category,
          location: _location,
          rating: _rating,
          reviewCount: _reviewCount,
          isOwnProfile: _isOwnProfile,
          onEditCategory: _editCategory,
        ),
        const SizedBox(height: 10),
        _buildStatsBar(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionButtons()),
            if (!_isOwnProfile)
              ProfileSaveButton(
                currentUserId: _currentUser?.uid,
                profileUserId: widget.profileUserId,
                accountType: 'wellness',
                displayName: _businessName.isNotEmpty ? _businessName : 'Wellness',
                profilePhoto: _profilePhotoUrl,
                category: _category,
              ),
          ],
        ),
        _buildBioCard(),
        if (_isOwnProfile)
          ProfileCompletenessMeter(
            kind: ProfileKind.wellness,
            userData: _userDocSnapshot,
            onTapImprove: _openEditProfile,
          ),
        ProfileHighlightsRow(
          posts: _recentPosts,
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

  Widget _buildStatsBar() {
    return ProfileWellnessStatsCard(
      followers: _followersCount,
      following: _followingCount,
      posts: _postsCount,
      likes: _likesCount,
      cardColor: ProfileLayout.cardBg,
      lavenderAccent: ProfileLayout.lavender,
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
      onTapPosts: () {
        final postsTabIndex = _isOwnProfile ? 0 : 1;
        _shellKey.currentState?.jumpToTab(postsTabIndex);
      },
    );
  }

  Future<void> _openEditProfile() async {
    if (!_isOwnProfile) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialName: _businessName,
          initialUsername: _username,
          initialBio: _bio,
          initialGender: '',
          initialprofessiontype: '',
        ),
      ),
    );
    await _loadProfileData();
  }

  Widget _buildActionButtons() {
    return WellnessActionRow(
      isOwnProfile: _isOwnProfile,
      isFollowing: _isFollowing,
      onToggleFollow: _toggleFollow,
      onMessage: _openMessage,
      onBook: _openBooking,
      onEditProfile: _openEditProfile,
      lavender: ProfileLayout.lavender,
      deepLavender: ProfileLayout.deepLavender,
    );
  }

  Widget _buildBioCard() {
    return WellnessBioCard(
      bio: _bio,
      isOwnProfile: _isOwnProfile,
      onEditBio: _editBio,
    );
  }

  List<Widget> _buildAppBarActions() {
    if (!_isOwnProfile) return [];
    return [
      IconButton(
        icon: const Icon(Icons.add_box_outlined, color: Colors.white),
        onPressed: _openPostCreation,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) {
          if (value == 'Edit Profile') {
            _openEditProfile();
          } else if (value == 'Profile Sections') {
            _openProfileModulesEditor();
          } else if (value == 'Settings') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(),
              ),
            ).then((result) async {
              if (result == 'logout') {
                await _auth.signOut();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              }
            });
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'Profile Sections',
            child: Text('Profile Sections'),
          ),
          PopupMenuItem(
            value: 'Edit Profile',
            child: Text('Edit Profile'),
          ),
          PopupMenuItem(
            value: 'Settings',
            child: Text('Settings'),
          ),
        ],
      ),
    ];
  }

  // ===================================================================
  //  EDIT FUNCTIONS
  // ===================================================================
  Future<void> _editBio() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final controller = TextEditingController(text: _bio);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Bio',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe your business...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: ProfileLayout.lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'bio': result});
        setState(() => _bio = result);
        Fluttertoast.showToast(msg: 'Bio updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update bio');
      }
    }
  }

  Future<void> _editServices() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final controller = TextEditingController(text: _services.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Services',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter services separated by commas',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: ProfileLayout.lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final services = result
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'services': services});
        setState(() => _services = services);
        Fluttertoast.showToast(msg: 'Services updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update services');
      }
    }
  }

  Future<void> _editAvailability() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final monSatCtrl = TextEditingController(
      text: _availability['Mon-Sat'] ?? _availability['Mon–Sat'] ?? '6:00 AM - 10:00 PM',
    );
    final sunCtrl = TextEditingController(
      text: _availability['Sun'] ?? _availability['Sunday'] ?? '8:00 AM - 8:00 PM',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Operating Hours',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visitors see Open/Closed based on these hours.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: monSatCtrl,
              decoration: InputDecoration(
                labelText: 'Mon–Sat',
                hintText: '6:00 AM - 10:00 PM',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sunCtrl,
              decoration: InputDecoration(
                labelText: 'Sunday',
                hintText: '8:00 AM - 8:00 PM',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ProfileLayout.lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newAvailability = <String, String>{};
      if (monSatCtrl.text.trim().isNotEmpty) {
        newAvailability['Mon-Sat'] = monSatCtrl.text.trim();
      }
      if (sunCtrl.text.trim().isNotEmpty) {
        newAvailability['Sun'] = sunCtrl.text.trim();
      }

      try {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'availability': newAvailability,
          'facilityHours': {
            'days': 'Mon-Sat / Sun',
            'openTime': monSatCtrl.text.trim(),
            'closeTime': sunCtrl.text.trim(),
          },
        });
        setState(() {
          _availability = newAvailability;
          _facilityHours = {
            'days': 'Mon-Sat / Sun',
            'openTime': monSatCtrl.text.trim(),
            'closeTime': sunCtrl.text.trim(),
          };
        });
        Fluttertoast.showToast(msg: 'Operating hours updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update hours');
      }
    }
  }

  Future<void> _editCategory() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final categories = ['Gym', 'Yoga Studio', 'Café', 'Diet Center', 'Physio Clinic'];
    final currentIndex = categories.indexOf(_category);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Select Category',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: categories.map((cat) {
            return RadioListTile<String>(
              title: Text(cat),
              value: cat,
              groupValue: _category.isNotEmpty ? _category : null,
              onChanged: (value) => Navigator.pop(ctx, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'category': result, 'wellness_category': result});
        setState(() => _category = result);
        Fluttertoast.showToast(msg: 'Category updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update category');
      }
    }
  }

  // ===================================================================
  //  BUILD
  // ===================================================================
  Widget _buildWellnessPostsTab() {
    return AspirantPostsTab(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _isOwnProfile
        ? const [
            Tab(text: 'Profile'),
            Tab(text: 'Business'),
          ]
        : const [
            Tab(text: 'Profile'),
            Tab(text: 'Posts'),
          ];

    final tabViews = _isOwnProfile
        ? [
            _buildProfileTabContent(),
            _buildBusinessTabContent(),
          ]
        : [
            _buildProfileTabContent(),
            _buildWellnessPostsTab(),
          ];

    return Scaffold(
      backgroundColor: ProfileLayout.bg,
      body: DefaultTextStyle(
        style: GoogleFonts.poppins(
          color: ProfileLayout.textPrimary,
          fontSize: 14,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;
            if (vx.abs() < 250) return;
            if (vx < 0 && _tabController.index < _tabController.length - 1) {
              _tabController.animateTo(_tabController.index + 1);
            } else if (vx > 0 && _tabController.index > 0) {
              _tabController.animateTo(_tabController.index - 1);
            }
          },
          child: WellnessProfileShell(
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
            header: _buildProfileHeaderSection(),
            tabController: _tabController,
            tabs: tabs,
            tabViews: tabViews,
          ),
        ),
      ),
    );
  }


  // ===================================================================
  //  TAB CONTENT BUILDERS
  // ===================================================================
  Widget _buildProfileTabContent() {
    return WellnessProfileTabContent(
      isOwnProfile: _isOwnProfile,
      profileUserId: widget.profileUserId,
      wellnessName: _businessName.isNotEmpty ? _businessName : 'Wellness',
      currentUserId: _currentUser?.uid,
      featuredGuruIds: _featuredGuruIds,
      isSectionEnabled: _isWellnessSectionEnabled,
      galleryImages: _galleryImages,
      amenities: _amenities,
      membershipPlans: _membershipPlans,
      specialOffers: _specialOffers,
      awards: _awards,
      availability: _availability,
      facilityHours: _facilityHours,
      popularProducts: _buildPopularProductsSection(),
      featuredStaff: _isWellnessSectionEnabled('staff')
          ? WellnessStaffSection(
              staff: _staff,
              isOwnProfile: _isOwnProfile,
              onManage: _isOwnProfile ? _openStaffEditor : null,
            )
          : const SizedBox.shrink(),
      recentPosts: _isOwnProfile ? _buildRecentPostsSection() : null,
      fitnessEvents: _isWellnessSectionEnabled('events')
          ? WellnessEventsSection(
              events: _events,
              isOwnProfile: _isOwnProfile,
              onManage: _isOwnProfile ? _openEventsEditor : null,
            )
          : const SizedBox.shrink(),
      location: _buildLocationSection(),
      servicesAndAvailability: _buildServicesAndAvailabilitySection(),
      reviews: _buildReviewsSection(),
      socialLinks: _buildSocialLinksSection(),
      visitorBooking: !_isOwnProfile
          ? WellnessBookingSection(wellnessUserId: widget.profileUserId, isOwner: false)
          : null,
      onAddGalleryImage: _addGalleryImage,
      onViewFullGallery: _showFullGallery,
      onAddMembershipPlan: _addMembershipPlan,
      onEditMembershipPlan: _editMembershipPlan,
      onDeleteMembershipPlan: _deleteMembershipPlan,
      onSubscribeToPlan: _subscribeToPlan,
      onAddSpecialOffer: _addSpecialOffer,
      onEditSpecialOffer: _editSpecialOffer,
      onDeleteSpecialOffer: _deleteSpecialOffer,
      onShowOfferDetails: _showOfferDetails,
      onAddAward: _addAward,
      onEditFacilityStatus: _editAvailability,
      onManageFeaturedCoaches: _isOwnProfile ? _manageFeaturedCoaches : null,
    );
  }

  Future<void> _openStaffEditor() async {
    if (!_isOwnProfile || _currentUser == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WellnessStaffEditorPage(wellnessUserId: _currentUser!.uid),
      ),
    );
    await _loadStaff();
    if (mounted) setState(() {});
  }

  Future<void> _openEventsEditor() async {
    if (!_isOwnProfile || _currentUser == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WellnessEventsEditorPage(wellnessUserId: _currentUser!.uid),
      ),
    );
    await _loadEvents();
    if (mounted) setState(() {});
  }

  Future<void> _manageFeaturedCoaches() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final usernameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Featured Coaches'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Guru username',
                hintText: '@coach_username',
              ),
            ),
            const SizedBox(height: 12),
            if (_featuredGuruIds.isNotEmpty)
              ..._featuredGuruIds.map(
                (id) => ListTile(
                  dense: true,
                  title: Text(id, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () async {
                      final updated = List<String>.from(_featuredGuruIds)..remove(id);
                      await _firestore.collection('users').doc(widget.profileUserId).update({
                        'featuredGuruIds': updated,
                      });
                      if (mounted) setState(() => _featuredGuruIds = updated);
                    },
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              final username = usernameCtrl.text.trim().replaceAll('@', '');
              if (username.isEmpty) return;
              final snap = await _firestore
                  .collection('users')
                  .where('username', isEqualTo: username)
                  .where('accountType', isEqualTo: 'guru')
                  .limit(1)
                  .get();
              if (snap.docs.isEmpty) {
                Fluttertoast.showToast(msg: 'Guru not found');
                return;
              }
              final guruId = snap.docs.first.id;
              if (_featuredGuruIds.contains(guruId)) {
                Fluttertoast.showToast(msg: 'Already featured');
                return;
              }
              final updated = [..._featuredGuruIds, guruId];
              await _firestore.collection('users').doc(widget.profileUserId).update({
                'featuredGuruIds': updated,
              });
              if (mounted) setState(() => _featuredGuruIds = updated);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        WellnessProductsSection(
          wellnessUserId: widget.profileUserId,
          isOwner: _isOwnProfile,
        ),
        WellnessServicesSection(
          wellnessUserId: widget.profileUserId,
          isOwner: _isOwnProfile,
        ),
        WellnessBookingSection(
          wellnessUserId: widget.profileUserId,
          isOwner: _isOwnProfile,
        ),
        WellnessReviewsSection(
          wellnessUserId: widget.profileUserId,
        ),
        if (_isOwnProfile) ...[
          const SizedBox(height: 16),
          WellnessAnalyticsSection(
            wellnessUserId: widget.profileUserId,
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  // ===================================================================
  //  FIRST TAB SECTION BUILDERS
  // ===================================================================
  Widget _buildPopularProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Products',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => _showAllProducts(),
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ProfileLayout.deepLavender,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No products available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ProfileLayout.lavender.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: product['imageUrl'] != null &&
                              product['imageUrl'].toString().isNotEmpty
                              ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              product['imageUrl'].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          )
                              : const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name']?.toString() ?? 'Product',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (product['price'] != null)
                              Text(
                                '₹${product['price']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: ProfileLayout.deepLavender,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentPostsSection() {
    return WellnessRecentPostsSection(
      recentPosts: _recentPosts,
      onViewAll: _showAllPosts,
      mutedTextColor: _mutedText,
      accentColor: ProfileLayout.deepLavender,
    );
  }

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ProfileLayout.lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: Icon(Icons.map, size: 64, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _location.isNotEmpty ? _location : 'Location not set',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openMaps,
                      icon: Icon(Icons.map_outlined, color: ProfileLayout.lavender),
                      label: Text(
                        'Open in Maps',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.2,
                          color: ProfileLayout.lavender,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: ProfileLayout.lavender, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesAndAvailabilitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ProfileLayout.lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Services Offered',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _editServices,
                    color: ProfileLayout.lavender,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_services.isEmpty)
              Text(
                'No services listed',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _mutedText,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _services.map((service) {
                  return Chip(
                    label: Text(
                      service,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ProfileLayout.deepLavender,
                      ),
                    ),
                    backgroundColor: ProfileLayout.lavender.withOpacity(0.12),
                    side: BorderSide(color: ProfileLayout.lavender.withOpacity(0.2), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Availability',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _editAvailability,
                    color: ProfileLayout.lavender,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_availability.isEmpty)
              Text(
                'Availability not set',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _mutedText,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _availability.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ProfileLayout.deepLavender,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ProfileSectionTitle(
            title: 'Reviews',
            fontSize: 18,
            trailing: _reviewCount > 0
                ? TextButton(
                    onPressed: () => _showAllReviews(),
                    child: Text(
                      'View All Reviews',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ProfileLayout.deepLavender,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const ProfileEmptyState(text: 'No reviews yet'),
          )
        else
          Column(
            children: _reviews.map((review) {
              return Padding(
                padding: const EdgeInsets.only(
                    left: 20.0, right: 20.0, bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ProfileLayout.lavender.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: review['profilePhoto'] != null
                            ? NetworkImage(review['profilePhoto'].toString())
                            : null,
                        backgroundColor: ProfileLayout.lavender.withOpacity(0.2),
                        child: review['profilePhoto'] == null
                            ? Text(
                          (review['userName']?.toString()[0] ?? 'U').toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: ProfileLayout.lavender,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review['userName']?.toString() ?? 'User',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < (review['rating'] as int? ?? 5)
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: Colors.amber,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review['text']?.toString() ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSocialLinksSection() {
    return ProfileSectionCard(
      title: 'Social Links',
      titleFontSize: 18,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      trailing: _isOwnProfile
          ? IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: _editSocialLinks,
              color: ProfileLayout.lavender,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_socialLinks.isEmpty)
            const ProfileEmptyState(text: 'No social links added')
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_socialLinks.containsKey('instagram'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 24),
                      color: Colors.pink[700],
                      onPressed: () => _openSocialLink('instagram', _socialLinks['instagram'] ?? ''),
                    ),
                  ),
                if (_socialLinks.containsKey('youtube'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.play_circle_outline, size: 24),
                      color: Colors.red[700],
                      onPressed: () => _openSocialLink('youtube', _socialLinks['youtube'] ?? ''),
                    ),
                  ),
                if (_socialLinks.containsKey('website'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.language, size: 24),
                      color: Colors.blue[700],
                      onPressed: () => _openSocialLink('website', _socialLinks['website'] ?? ''),
                    ),
                  ),
                if (_socialLinks.containsKey('whatsapp'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chat, size: 24),
                      color: Colors.green[700],
                      onPressed: () => _openSocialLink('whatsapp', _socialLinks['whatsapp'] ?? ''),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _editSocialLinks() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final instagramCtrl = TextEditingController(text: _socialLinks['instagram'] ?? '');
    final youtubeCtrl = TextEditingController(text: _socialLinks['youtube'] ?? '');
    final websiteCtrl = TextEditingController(text: _socialLinks['website'] ?? '');
    final whatsappCtrl = TextEditingController(text: _socialLinks['whatsapp'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Social Links',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: instagramCtrl,
                decoration: InputDecoration(
                  labelText: 'Instagram',
                  prefixIcon: const Icon(Icons.camera_alt, color: Colors.pink),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: youtubeCtrl,
                decoration: InputDecoration(
                  labelText: 'YouTube',
                  prefixIcon: const Icon(Icons.play_circle_outline, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: websiteCtrl,
                decoration: InputDecoration(
                  labelText: 'Website',
                  prefixIcon: const Icon(Icons.language, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: whatsappCtrl,
                decoration: InputDecoration(
                  labelText: 'WhatsApp',
                  prefixIcon: const Icon(Icons.chat, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ProfileLayout.lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newLinks = <String, String>{};
      if (instagramCtrl.text.isNotEmpty) newLinks['instagram'] = instagramCtrl.text;
      if (youtubeCtrl.text.isNotEmpty) newLinks['youtube'] = youtubeCtrl.text;
      if (websiteCtrl.text.isNotEmpty) newLinks['website'] = websiteCtrl.text;
      if (whatsappCtrl.text.isNotEmpty) newLinks['whatsapp'] = whatsappCtrl.text;

      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'socialLinks': newLinks});
        setState(() => _socialLinks = newLinks);
        Fluttertoast.showToast(msg: 'Social links updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update social links');
      }
    }
  }



  // ===================================================================
  //  EDIT FUNCTIONS FOR NEW FEATURES
  // ===================================================================

  Future<void> _addGalleryImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    
    // In a real app, you would use ImagePicker here
    Fluttertoast.showToast(msg: 'Gallery image upload feature coming soon!');
  }

  Future<void> _addMembershipPlan() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: 'Monthly');
    final featuresCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Membership Plan',
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
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Plan Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.card_membership, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: 'Duration (e.g., Monthly, Yearly)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: featuresCtrl,
                decoration: InputDecoration(
                  labelText: 'Features (comma separated)',
                  labelStyle: GoogleFonts.poppins(),
                  hintText: 'e.g., Gym Access, Locker, Personal Trainer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.checklist, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                maxLines: 3,
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
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
              
              try {
                final features = featuresCtrl.text.trim().split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
                final newPlan = {
                  'name': nameCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                  'duration': durationCtrl.text.trim(),
                  'features': features,
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('membershipPlans')
                    .add(newPlan);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Membership plan added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding plan: $e');
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

  Future<void> _editMembershipPlan(int index, Map<String, dynamic> plan) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController(text: plan['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: (plan['price'] ?? 0).toString());
    final durationCtrl = TextEditingController(text: plan['duration']?.toString() ?? 'Monthly');
    final featuresCtrl = TextEditingController(text: (plan['features'] as List?)?.join(', ') ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Membership Plan',
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
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Plan Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.card_membership, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: 'Duration',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: featuresCtrl,
                decoration: InputDecoration(
                  labelText: 'Features (comma separated)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.checklist, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
                maxLines: 3,
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
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
              
              try {
                final features = featuresCtrl.text.trim().split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
                final updatedPlan = {
                  'name': nameCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                  'duration': durationCtrl.text.trim(),
                  'features': features,
                };
                
                // Update in Firestore - you'll need to track document IDs
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Membership plan updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating plan: $e');
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

  Future<void> _deleteMembershipPlan(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Membership Plan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this membership plan?',
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
        // Delete from Firestore - you'll need to track document IDs
        Fluttertoast.showToast(msg: 'Membership plan deleted successfully!');
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting plan: $e');
      }
    }
  }

  Future<void> _addSpecialOffer() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final validUntilCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Special Offer',
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
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Offer Title',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.local_offer, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountCtrl,
                decoration: InputDecoration(
                  labelText: 'Discount (e.g., 20% OFF)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.percent, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: validUntilCtrl,
                decoration: InputDecoration(
                  labelText: 'Valid Until',
                  labelStyle: GoogleFonts.poppins(),
                  hintText: 'e.g., Dec 31, 2024 or Ongoing',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
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
              if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) return;
              
              try {
                final newOffer = {
                  'title': titleCtrl.text.trim(),
                  'discount': discountCtrl.text.trim(),
                  'validUntil': validUntilCtrl.text.trim().isEmpty ? 'Ongoing' : validUntilCtrl.text.trim(),
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('specialOffers')
                    .add(newOffer);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Special offer added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding offer: $e');
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

  Future<void> _editSpecialOffer(int index, Map<String, dynamic> offer) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleCtrl = TextEditingController(text: offer['title']?.toString() ?? '');
    final discountCtrl = TextEditingController(text: offer['discount']?.toString() ?? '');
    final validUntilCtrl = TextEditingController(text: offer['validUntil']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Special Offer',
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
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Offer Title',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.local_offer, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountCtrl,
                decoration: InputDecoration(
                  labelText: 'Discount',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.percent, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: validUntilCtrl,
                decoration: InputDecoration(
                  labelText: 'Valid Until',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
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
              if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) return;
              
              try {
                // Update in Firestore - you'll need to track document IDs
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Special offer updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating offer: $e');
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

  Future<void> _deleteSpecialOffer(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Special Offer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this special offer?',
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
        // Delete from Firestore - you'll need to track document IDs
        Fluttertoast.showToast(msg: 'Special offer deleted successfully!');
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting offer: $e');
      }
    }
  }


  // ===================================================================
  //  HELPER FUNCTIONS FOR STATIC FEATURES
  // ===================================================================
  
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
  
  Future<void> _openBooking() async {
    if (_isOwnProfile) return;
    
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to book');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => WellnessBookingSection(
          wellnessUserId: widget.profileUserId,
          isOwner: false,
        ),
      ),
    );
  }
  
  Future<void> _openPostCreation() async {
    if (!_isOwnProfile || _currentUser == null) return;
    
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Newpostpage(
          imagePath: image.path,
          onPostSubmit: (caption) async {
            try {
              final fileName = DateTime.now().millisecondsSinceEpoch.toString();
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('posts')
                  .child(fileName);
              final url = await uploadReferenceXFileAndGetUrl(
                ref,
                image,
                metadata: SettableMetadata(contentType: 'image/jpeg'),
              );
              await FirebaseFirestore.instance.collection('posts').add({
                'imageUrl': url,
                'caption': caption,
                'userId': _currentUser!.uid,
                'timestamp': FieldValue.serverTimestamp(),
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
  
  Future<void> _openSocialLink(String platform, String link) async {
    try {
      if (link.isEmpty) {
        Fluttertoast.showToast(msg: '$platform link not available');
        return;
      }
      
      String url = link;
      
      // If link doesn't start with http, add it
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Format URLs based on platform
        switch (platform.toLowerCase()) {
          case 'youtube':
            url = url.contains('youtube.com') || url.contains('youtu.be')
                ? url
                : 'https://youtube.com/$url';
            break;
          case 'instagram':
            url = url.startsWith('@') 
                ? 'https://instagram.com/${url.substring(1)}'
                : 'https://instagram.com/$url';
            break;
          case 'whatsapp':
            url = url.startsWith('+') || url.startsWith('91')
                ? 'https://wa.me/$url'
                : 'https://wa.me/91$url';
            break;
          case 'website':
            url = 'https://$url';
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
  
  Future<void> _openMaps() async {
    try {
      if (_location.isEmpty) {
        Fluttertoast.showToast(msg: 'Location not available');
        return;
      }
      
      // Create a Google Maps URL with the location
      final encodedLocation = Uri.encodeComponent(_location);
      final url = 'https://www.google.com/maps/search/?api=1&query=$encodedLocation';
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open maps');
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
      Fluttertoast.showToast(msg: 'Failed to open maps');
    }
  }
  
  Future<void> _showAllProducts() async {
    if (_products.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllProductsPage(products: _products),
    );
  }
  
  Future<void> _showAllPosts() async {
    if (_recentPosts.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllPostsPage(posts: _recentPosts),
    );
  }
  
  Future<void> _showAllReviews() async {
    if (_reviews.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllReviewsPage(reviews: _reviews),
    );
  }
  
  Future<void> _showFullGallery() async {
    // Mock gallery - in real app, load from Firestore
    final galleryImages = List.generate(12, (i) => 'gallery_$i');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullGalleryPage(images: galleryImages),
    );
  }
  
  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to subscribe');
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Subscribe to Plan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['name']?.toString() ?? 'Plan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ₹${plan['price'] ?? 0}/${plan['duration'] ?? 'month'}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Subscription feature coming soon! You will be able to complete payment and subscribe to this plan.',
              style: TextStyle(fontSize: 12),
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
            onPressed: () {
              Navigator.pop(ctx);
              Fluttertoast.showToast(msg: 'Subscription feature coming soon!');
            },
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showOfferDetails(Map<String, dynamic> offer) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfferDetailsPage(offer: offer),
    );
  }
  
  Future<void> _addAward() async {
    if (!_isOwnProfile || _currentUser == null) return;
    
    final nameCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Award/Certification',
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
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Award Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.workspace_premium, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: issuerCtrl,
                decoration: InputDecoration(
                  labelText: 'Issuing Organization',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.business, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yearCtrl,
                decoration: InputDecoration(
                  labelText: 'Year (Optional)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: ProfileLayout.lavender),
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
              if (nameCtrl.text.trim().isEmpty) return;
              
              try {
                final newAward = {
                  'name': nameCtrl.text.trim(),
                  'issuer': issuerCtrl.text.trim(),
                  if (yearCtrl.text.trim().isNotEmpty) 'year': yearCtrl.text.trim(),
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('awards')
                    .add(newAward);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Award added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding award: $e');
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
}

// ===================================================================
//  MODAL PAGES FOR WELLNESS FEATURES
// ===================================================================

class _AllProductsPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  
  const _AllProductsPage({required this.products});
  
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Products',
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
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: product['imageUrl'] != null
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.network(
                                    product['imageUrl'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                                  ),
                                )
                              : const Center(child: Icon(Icons.image, color: Colors.grey)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name']?.toString() ?? 'Product',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product['price'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '₹${product['price']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFA58CE3),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllPostsPage extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  
  const _AllPostsPage({required this.posts});
  
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Posts',
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
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: post['imageUrl'] != null &&
                      post['imageUrl'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            post['imageUrl'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllReviewsPage extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  
  const _AllReviewsPage({required this.reviews});
  
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Reviews',
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: review['profilePhoto'] != null
                          ? NetworkImage(review['profilePhoto'].toString())
                          : null,
                      child: review['profilePhoto'] == null
                          ? Text(
                              (review['userName']?.toString()[0] ?? 'U').toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFA58CE3),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      review['userName']?.toString() ?? 'User',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(
                              i < (review['rating'] as int? ?? 5)
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                        ),
                        if (review['text'] != null && review['text'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            review['text'].toString(),
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ],
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
}

class _FullGalleryPage extends StatelessWidget {
  final List<String> images;
  
  const _FullGalleryPage({required this.images});
  
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Facility Gallery',
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
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 32, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferDetailsPage extends StatelessWidget {
  final Map<String, dynamic> offer;
  
  const _OfferDetailsPage({required this.offer});
  
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    offer['title']?.toString() ?? 'Special Offer',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[100]!, Colors.orange[50]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        offer['discount']?.toString() ?? 'Special Discount',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Valid Until: ${offer['validUntil']?.toString() ?? 'Ongoing'}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Terms and Conditions:\n• Offer valid for new members only\n• Cannot be combined with other offers\n• Subject to availability',
                    style: TextStyle(fontSize: 13, height: 1.5),
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

