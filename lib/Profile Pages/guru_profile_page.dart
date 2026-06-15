// guru_profile_page.dart  (Guru Profile – advanced features)

// -------------------- IMPORTS --------------------
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

// local pages
import '../../editprofilepage.dart';
import '../../main.dart'; // LoginPage
import 'package:halo/Bottom Pages/PrivacySettingsPage.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:halo/utils/search_utils.dart';
import 'package:halo/utils/shell_back.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';
import 'package:halo/services/follow_service.dart';
import 'package:halo/widgets/follow_button.dart';
import 'package:halo/widgets/profile_image_interactions.dart';
import 'package:halo/screens/profile/widgets/guru/guru_identity_block.dart';
import 'package:halo/screens/profile/widgets/guru/guru_recent_posts_section.dart';
import 'package:halo/screens/profile/widgets/guru/guru_action_row.dart';
import 'package:halo/screens/profile/widgets/guru/guru_bio_card.dart';
import 'package:halo/screens/profile/widgets/guru/guru_cta_row.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_title.dart';
import 'package:halo/screens/profile/widgets/common/profile_section_card.dart';
import 'package:halo/screens/profile/widgets/common/profile_empty_state.dart';
import 'package:halo/screens/profile/core/profile_follow_toggle.dart';
import 'package:halo/screens/profile/core/profile_posts_queries.dart';
import 'package:halo/screens/profile/core/profile_reviews_queries.dart';
import 'package:halo/platform/profile_avatar_provider.dart';
import 'package:halo/platform/profile_local_photo.dart';
import 'package:halo/platform/storage_upload.dart';
import 'package:halo/screens/profile/core/profile_media_upload.dart';
import 'package:halo/screens/profile/widgets/common/profile_avatar_hero_shell.dart';
import 'package:halo/screens/profile/widgets/common/profile_cover_hero.dart';
import 'package:halo/screens/profile/widgets/common/profile_flexible_space_cover_stack.dart';
import 'package:halo/screens/profile/widgets/common/profile_media_preview_helpers.dart';
import 'package:halo/screens/profile/widgets/common/profile_stats_bar.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/screens/profile/widgets/common/profile_post_image_url.dart';
import 'package:halo/screens/profile/widgets/guru/guru_profile_shell.dart';
import 'package:halo/screens/profile/widgets/aspirant/aspirant_posts_tab.dart';
import 'package:halo/screens/profile/pages/follow_list_page.dart';
import 'package:halo/Profile Pages/aspirant_profile_page.dart' show PostDetailsPage;

// GURU SECTIONS
import '../Sections/Guru Section/guru_booking_section.dart';
import '../Sections/Guru Section/guru_classes_section.dart';
import '../Sections/Guru Section/guru_earnings_section.dart';
import '../Sections/Guru Section/guru_students_section.dart';
import '../Sections/Guru Section/guru_analytics_section.dart';

// ===================================================================
//  GURU PROFILE PAGE
// ===================================================================

class GuruProfilePage extends StatelessWidget {
  final String profileUserId;
  final VoidCallback? onBackToHome;

  const GuruProfilePage({
    Key? key,
    required this.profileUserId,
    this.onBackToHome,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _GuruProfilePageStateful(
      profileUserId: profileUserId,
      onBackToHome: onBackToHome,
    );
  }
}

class _GuruProfilePageStateful extends StatefulWidget {
  final String profileUserId;
  final VoidCallback? onBackToHome;

  const _GuruProfilePageStateful({
    Key? key,
    required this.profileUserId,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<_GuruProfilePageStateful> createState() =>
      _GuruProfilePageState();
}

class _GuruProfilePageState extends State<_GuruProfilePageStateful>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();
  User? _currentUser;
  bool _isOwnProfile = false;

  // -------------------- USER DATA --------------------
  String _fullName = '';
  String _username = '';
  String _primaryCategory = ''; // yoga / cricket / dance
  String _city = '';
  int? _experienceYears;
  String _bio = '';
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  double _rating = 0.0;
  int _reviewCount = 0;
  bool _isPrivate = false;

  // extra profile info
  List<String> _languages = [];
  String _trainingStyle = ''; // soft / hard / hybrid
  List<String> _badges = [];
  List<String> _specialties = [];
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _achievements = [];

  // -------------------- GURU SECTIONS DATA --------------------
  // booking
  Map<String, dynamic> _bookingSettings = {};
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _pastSessions = [];

  // earnings
  Map<String, dynamic> _earningsSummary = {};
  List<Map<String, dynamic>> _recentEarnings = [];

  // classes
  List<Map<String, dynamic>> _classes = [];

  // students
  List<Map<String, dynamic>> _students = [];

  // analytics
  Map<String, dynamic> _analytics = {};

  // -------------------- SOCIAL & MEDIA --------------------
  Map<String, String> _socialLinks = {};
  List<String> _galleryImages = [];

  // -------------------- FIRST TAB DATA --------------------
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _lastWorkouts = [];

  // -------------------- STATE --------------------
  bool _isFollowing = false;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();
  ProfileLocalPhoto? _profilePhotoLocal;
  ProfileLocalPhoto? _coverPhotoLocal;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  late final AnimationController _followAnimController;
  late final TabController _tabController;
  final GlobalKey<GuruProfileShellState> _shellKey =
      GlobalKey<GuruProfileShellState>();

  @override
  void initState() {
    super.initState();
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _followAnimController.dispose();
    _tabController.dispose();
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

        // --------- DEBUG: account type (with fallbacks) ----------
        final rawAccountType = (data['accountType'] ?? 'guru').toString();
        final accountType = rawAccountType.toLowerCase();
        debugPrint('🔍 Guru Profile Page - Account Type: $accountType');
        debugPrint('🔍 Guru Profile Page - Is Own Profile: $_isOwnProfile');
        // ---------------------------------------------------------
        if (_isOwnProfile && mounted && _tabController.index == 0) {
          _tabController.animateTo(1);
        }

        // Guru signup uses full_name; also support name / business_name
        final nameRaw = data['full_name'] ?? data['name'] ?? data['business_name'] ?? '';
        _fullName = (nameRaw is String ? nameRaw : nameRaw.toString()).trim();
        _username = (data['username'] ?? '') as String;
        _primaryCategory = (data['primaryCategory'] ?? '') as String;
        _city = (data['city'] ?? '') as String;
        _experienceYears =
        data['experienceYears'] is int ? data['experienceYears'] as int : null;

        _bio = (data['bio'] ?? '') as String;
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;

        _followersCount = (data['followersCount'] ?? 0) as int;
        _followingCount = (data['followingCount'] ?? 0) as int;
        _postsCount = (data['postsCount'] ?? 0) as int;
        _isPrivate = (data['isPrivate'] ?? false) as bool;

        _rating = (data['rating'] is num)
            ? (data['rating'] as num).toDouble()
            : 0.0;
        _reviewCount = (data['reviewCount'] ?? 0) as int;

        _languages = List<String>.from(data['languages'] ?? []);
        _trainingStyle = (data['trainingStyle'] ?? '') as String;
        _badges = List<String>.from(data['badges'] ?? []);
        _specialties = List<String>.from(data['specialties'] ?? []);

        final certRaw = data['certifications'];
        if (certRaw is List) {
          _certifications = certRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _certifications = [];
        }

        final achRaw = data['achievements'];
        if (achRaw is List) {
          _achievements =
              achRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _achievements = [];
        }

        // booking - load from user doc or subcollection
        final bs = data['bookingSettings'];
        _bookingSettings =
        bs is Map ? Map<String, dynamic>.from(bs) : <String, dynamic>{};

        // ================== SESSIONS (UPDATED – NO COMPOSITE INDEX NEEDED) ==================
        try {
          final sessionsRef = _firestore
              .collection('users')
              .doc(widget.profileUserId)
              .collection('sessions');

          // Upcoming: only where, NO orderBy -> composite index nahi lagega
          final upcomingSnapshot = await sessionsRef
              .where('status', isEqualTo: 'upcoming')
              .limit(10)
              .get();

          if (upcomingSnapshot.docs.isNotEmpty) {
            _upcomingSessions = upcomingSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'title': d['title'] ?? 'Session',
                'time': d['sessionDate'] != null
                    ? _formatDateTime(d['sessionDate'])
                    : d['time']?.toString() ?? '',
                'studentName': d['studentName'] ?? '',
                'type': d['type'] ?? 'offline',
              };
            }).toList();
          } else {
            final upcomingRaw = data['upcomingSessions'];
            _upcomingSessions = upcomingRaw is List
                ? upcomingRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
                : [];
          }

          // Past: only where, NO orderBy -> composite index nahi lagega
          final pastSnapshot = await sessionsRef
              .where('status', isEqualTo: 'completed')
              .limit(10)
              .get();

          if (pastSnapshot.docs.isNotEmpty) {
            _pastSessions = pastSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'title': d['title'] ?? 'Session',
                'time': d['sessionDate'] != null
                    ? _formatDateTime(d['sessionDate'])
                    : d['time']?.toString() ?? '',
                'studentName': d['studentName'] ?? '',
                'type': d['type'] ?? 'offline',
              };
            }).toList();
          } else {
            final pastRaw = data['pastSessions'];
            _pastSessions = pastRaw is List
                ? pastRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading sessions: $e');
          final upcomingRaw = data['upcomingSessions'];
          _upcomingSessions = upcomingRaw is List
              ? upcomingRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
              : [];

          final pastRaw = data['pastSessions'];
          _pastSessions = pastRaw is List
              ? pastRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
              : [];
        }
        // ===========================================================================

        // earnings - load from subcollection or calculate
        try {
          if (_isOwnProfile) {
            final earningsSnapshot = await _firestore
                .collection('users')
                .doc(widget.profileUserId)
                .collection('earnings')
                .orderBy('date', descending: true)
                .limit(10)
                .get();

            _recentEarnings = earningsSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'label': d['label'] ?? 'Session',
                'amount': d['amount'] ?? 0,
                'date': d['date'] != null
                    ? _formatDateTime(d['date'])
                    : d['date']?.toString() ?? '',
              };
            }).toList();

            double total = 0;
            double thisMonth = 0;
            double pending = 0;
            final now = DateTime.now();

            for (var doc in earningsSnapshot.docs) {
              final d = doc.data();
              final amount = (d['amount'] ?? 0).toDouble();
              total += amount;

              if (d['date'] != null) {
                final date = (d['date'] as Timestamp).toDate();
                if (date.year == now.year && date.month == now.month) {
                  thisMonth += amount;
                }
              }

              if (d['status'] == 'pending') {
                pending += amount;
              }
            }

            _earningsSummary = {
              'total': total,
              'thisMonth': thisMonth,
              'pending': pending,
            };
          } else {
            final es = data['earningsSummary'];
            _earningsSummary =
            es is Map ? Map<String, dynamic>.from(es) : <String, dynamic>{};

            final er = data['recentEarnings'];
            _recentEarnings = er is List
                ? er.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading earnings: $e');
          final es = data['earningsSummary'];
          _earningsSummary =
          es is Map ? Map<String, dynamic>.from(es) : <String, dynamic>{};

          final er = data['recentEarnings'];
          _recentEarnings = er is List
              ? er.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        }

        // classes - load from subcollection
        try {
          final classesSnapshot = await _firestore
              .collection('users')
              .doc(widget.profileUserId)
              .collection('classes')
              .where('isActive', isEqualTo: true)
              .limit(10)
              .get();

          if (classesSnapshot.docs.isNotEmpty) {
            _classes = classesSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'name': d['name'] ?? 'Batch',
                'schedule': d['schedule'] ?? '',
                'enrolled': d['enrolled'] ?? 0,
                'capacity': d['capacity'] ?? 0,
                'price': d['price'] ?? 0,
              };
            }).toList();
          } else {
            final cls = data['classes'];
            _classes = cls is List
                ? cls.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading classes: $e');
          final cls = data['classes'];
          _classes = cls is List
              ? cls.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        }

        // students - load from subcollection
        try {
          final studentsSnapshot = await _firestore
              .collection('users')
              .doc(widget.profileUserId)
              .collection('students')
              .limit(10)
              .get();

          if (studentsSnapshot.docs.isNotEmpty) {
            final studentsFutures = studentsSnapshot.docs.map((doc) async {
              final d = doc.data();
              final studentId = d['studentId'] ?? doc.id;

              try {
                final studentDoc =
                await _firestore.collection('users').doc(studentId).get();
                final studentData = studentDoc.data() ?? {};

                return {
                  'id': doc.id,
                  'studentId': studentId,
                  'name': studentData['name'] ?? d['name'] ?? 'Student',
                  'level': d['level'] ?? 'Beginner',
                  'progress': d['progress'] ?? 0,
                  'goal': d['goal'] ?? '',
                };
              } catch (_) {
                return {
                  'id': doc.id,
                  'studentId': studentId,
                  'name': d['name'] ?? 'Student',
                  'level': d['level'] ?? 'Beginner',
                  'progress': d['progress'] ?? 0,
                  'goal': d['goal'] ?? '',
                };
              }
            }).toList();

            _students = await Future.wait(studentsFutures);
          } else {
            final stu = data['students'];
            _students = stu is List
                ? stu.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading students: $e');
          final stu = data['students'];
          _students = stu is List
              ? stu.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        }

        // analytics - load from user doc
        final an = data['analytics'];
        _analytics =
        an is Map ? Map<String, dynamic>.from(an) : <String, dynamic>{};

        // social + gallery
        final sl = data['socialLinks'] as Map<String, dynamic>?;
        _socialLinks = sl != null
            ? sl.map((k, v) => MapEntry(k, v.toString()))
            : {
          'instagram': 'Instagram',
          'telegram': 'Telegram',
        };

        final gal = data['galleryImages'];
        _galleryImages = gal is List
            ? gal.map((e) => e.toString()).toList()
            : <String>[];

        // Load posts for first tab
        _recentPosts = await ProfilePostsQueries.fetchGuruProfilePostsPreview(
          firestore: _firestore,
          profileUserId: widget.profileUserId,
        );

        // Load reviews for first tab
        _reviews = await ProfileReviewsQueries.fetchGuruProfileReviewsPreview(
          firestore: _firestore,
          profileUserId: widget.profileUserId,
        );

        // Load programs/services (from classes or popularProducts)
        try {
          if (_classes.isNotEmpty) {
            _programs = _classes.take(5).map((cls) {
              return <String, dynamic>{
                'id': cls['id'] ?? '',
                'name': cls['name'] ?? 'Program',
                'duration': cls['schedule'] ?? 'Ongoing',
                'imageUrl': cls['imageUrl'],
                'price': cls['price'] ?? 0,
              };
            }).toList();
          } else {
            final productsRaw = data['popularProducts'];
            if (productsRaw is List && productsRaw.isNotEmpty) {
              _programs = productsRaw.take(5).map((p) {
                return Map<String, dynamic>.from(p as Map);
              }).toList();
            } else {
              _programs = [];
            }
          }
        } catch (e) {
          debugPrint('Error loading programs: $e');
          _programs = [];
        }

        // Load last workouts
        try {
          final workoutsRaw = data['lastWorkouts'];
          if (workoutsRaw is List && workoutsRaw.isNotEmpty) {
            _lastWorkouts = workoutsRaw.take(3).map((w) {
              return Map<String, dynamic>.from(w as Map);
            }).toList();
          } else {
            _lastWorkouts = [];
          }
        } catch (e) {
          debugPrint('Error loading workouts: $e');
          _lastWorkouts = [];
        }
      }

      // follow status
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
      debugPrint('guru profile load error: $e');
      Fluttertoast.showToast(msg: 'Failed to load profile');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      if (dateTime is Timestamp) {
        final date = dateTime.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (dateTime is String) {
        return dateTime;
      }
      return dateTime.toString();
    } catch (e) {
      return dateTime.toString();
    }
  }

  // ===================================================================
  //  CAMERA / IMAGES
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
    if (!_isOwnProfile || _currentUser == null) return;
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
    await _uploadAndSavePhoto(edited, isCover: false);
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
    await _uploadAndSavePhoto(edited, isCover: true);
  }

  void _previewCoverImage() {
    openProfileStoredImagePreview(
      context: context,
      localPath: _coverPhotoLocal?.path,
      localBytes: _coverPhotoLocal?.previewBytes,
      remoteUrl: _coverPhotoUrl,
      heroTag: 'guru-cover-${widget.profileUserId}',
    );
  }

  void _previewProfileImage() {
    openProfileStoredImagePreview(
      context: context,
      localPath: _profilePhotoLocal?.path,
      localBytes: _profilePhotoLocal?.previewBytes,
      remoteUrl: _profilePhotoUrl,
      heroTag: 'guru-avatar-${widget.profileUserId}',
    );
  }

  Future<void> _uploadAndSavePhoto(
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
  //  FOLLOW / MESSAGE
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
      errorToast: 'Something went wrong. Please try again later.',
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
  //  POSTS
  // ===================================================================
  Future<void> _openGalleryForPost() async {
    if (!_isOwnProfile) return;
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

  // ===================================================================
  //  GURU SECTION HANDLERS
  // ===================================================================
  Future<void> _handleManageSlots() async {
    if (!_isOwnProfile || _currentUser == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: ProfileLayout.bg,
          appBar: AppBar(
            title: const Text('Booking Management'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: GuruBookingSection(
              guruid: _currentUser!.uid,
              isOwnProfile: true,
              bookingSettings: _bookingSettings,
              upcomingSessions: _upcomingSessions,
              pastSessions: _pastSessions,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBookNow() async {
    if (_isOwnProfile) return;

    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to book a session');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: ProfileLayout.bg,
          appBar: AppBar(
            title: Text('Book with $_fullName'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: GuruBookingSection(
              guruid: widget.profileUserId,
              isOwnProfile: false,
              bookingSettings: _bookingSettings,
              upcomingSessions: _upcomingSessions,
              pastSessions: _pastSessions,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleManageClasses() async {
    if (!_isOwnProfile || _currentUser == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: ProfileLayout.bg,
          appBar: AppBar(
            title: const Text('Classes & Batches'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: GuruClassesSection(
              guruid: _currentUser!.uid,
              isOwnProfile: true,
              classes: _classes,
              specialties: _specialties,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleViewPayoutDetails() async {
    if (!_isOwnProfile || _currentUser == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: ProfileLayout.bg,
          appBar: AppBar(
            title: const Text('Earnings Overview'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: GuruEarningsSection(
              guruid: _currentUser!.uid,
              isOwnProfile: true,
              earningsSummary: _earningsSummary,
              recentEarnings: _recentEarnings,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  //  EDIT PROFILE / SETTINGS / LOGOUT
  // ===================================================================)
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
          initialprofessiontype: _primaryCategory,
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
      heroTag: 'guru-cover-${widget.profileUserId}',
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
      heroTag: 'guru-avatar-${widget.profileUserId}',
      onTap: _isOwnProfile ? _pickProfileImage : _previewProfileImage,
      onLongPress: _previewProfileImage,
    );
  }

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
      onTapPosts: () {
        final postsTabIndex = _isOwnProfile ? 0 : 1;
        _shellKey.currentState?.jumpToTab(postsTabIndex);
      },
    );
  }

  Widget _buildActionButtons() {
    return GuruActionRow(
      isOwnProfile: _isOwnProfile,
      isFollowing: _isFollowing,
      onToggleFollow: _toggleFollow,
      onMessage: _openMessage,
      onEditProfile: _handleEditProfile,
      lavender: ProfileLayout.lavender,
      deepLavender: ProfileLayout.deepLavender,
    );
  }

  Widget _buildBadgesRow() {
    if (_badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: _badges
            .map(
              (b) => Chip(
            label: Text(
              b,
              style: GoogleFonts.poppins(
                color: ProfileLayout.textPrimary,
                fontSize: 12,
              ),
            ),
            backgroundColor: ProfileLayout.chipBg,
            side: BorderSide(
              color: ProfileLayout.deepLavender.withValues(alpha: 0.15),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildBioCard() {
    return GuruBioCard(
      bio: _bio,
      isOwnProfile: _isOwnProfile,
    );
  }

  Widget _buildProfileHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: ProfileLayout.identityColumnTopInset),
        GuruIdentityBlock(
          avatar: _avatarWidget(),
          profileUserId: widget.profileUserId,
          fullName: _fullName,
          username: _username,
          primaryCategory: _primaryCategory,
          city: _city,
          experienceYears: _experienceYears,
          languages: _languages,
          trainingStyle: _trainingStyle,
          rating: _rating,
          reviewCount: _reviewCount,
        ),
        const SizedBox(height: 6),
        _buildBadgesRow(),
        const SizedBox(height: 10),
        _buildStatsCard(),
        const SizedBox(height: 12),
        _buildActionButtons(),
        _buildBioCard(),
        const SizedBox(height: 4),
      ],
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
                Fluttertoast.showToast(msg: 'Failed to update privacy');
              }
            }
          } else if (value == 'Settings') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => SettingsPage()),
            );
            if (result == 'logout') await _signOut();
          } else if (value == 'Logout') {
            await _signOut();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'Settings', child: Text('Settings')),
          PopupMenuItem(value: 'Privacy', child: Text('Privacy')),
          PopupMenuItem(value: 'Edit Profile', child: Text('Edit Profile')),
          PopupMenuItem(value: 'Logout', child: Text('Logout')),
        ],
      ),
    ];
  }

  Widget _buildProfileTabContent() {
    return ColoredBox(
      color: ProfileLayout.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          if (_isOwnProfile) ...[
            _buildCTAButtons(),
            const SizedBox(height: 12),
            _buildBusinessFeaturesShortcut(),
            const SizedBox(height: 24),
          ],
          _buildPopularProductsSection(),
          const SizedBox(height: 24),
          _buildLastWorkoutsSection(),
          const SizedBox(height: 24),
          if (_isOwnProfile) _buildRecentPostsSection(),
          if (_isOwnProfile) const SizedBox(height: 24),
          _buildSpecializationsSection(),
          const SizedBox(height: 24),
          _buildReviewsSection(),
          const SizedBox(height: 24),
          _buildSocialLinksSection(),
          const SizedBox(height: 24),
          _buildTestimonialsSection(),
          _buildCertificationsDisplaySection(),
          _buildTrainingProgramsShowcase(),
          _buildSuccessStoriesSection(),
          _buildVideoTutorialsPreview(),
          const SizedBox(height: 24),
          _buildFooter(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBusinessTabContent() {
    return ColoredBox(
      color: ProfileLayout.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          GuruBookingSection(
            guruid: widget.profileUserId,
            isOwnProfile: _isOwnProfile,
            bookingSettings: _bookingSettings,
            upcomingSessions: _upcomingSessions,
            pastSessions: _pastSessions,
            onManageSlots: _isOwnProfile ? _handleManageSlots : null,
            onBookNow: !_isOwnProfile ? _handleBookNow : null,
          ),
          GuruClassesSection(
            guruid: widget.profileUserId,
            isOwnProfile: _isOwnProfile,
            classes: _classes,
            specialties: _specialties,
            onManage: _isOwnProfile ? _handleManageClasses : null,
          ),
          GuruEarningsSection(
            guruid: widget.profileUserId,
            isOwnProfile: _isOwnProfile,
            earningsSummary: _earningsSummary,
            recentEarnings: _recentEarnings,
            onViewPayoutDetails:
                _isOwnProfile ? _handleViewPayoutDetails : null,
          ),
          GuruStudentsSection(
            guruid: widget.profileUserId,
            isOwnProfile: _isOwnProfile,
            students: _students,
          ),
          GuruAnalyticsSection(
            guruid: widget.profileUserId,
            isOwnProfile: _isOwnProfile,
            analytics: _analytics,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGuruPostsTab() {
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

  // ===================================================================
  //  BUILD
  // ===================================================================
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
            _buildGuruPostsTab(),
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
          child: GuruProfileShell(
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
  //  FIRST TAB SECTION BUILDERS
  // ===================================================================
  Widget _buildCTAButtons() {
    return GuruCtaRow(
      isOwnProfile: _isOwnProfile,
      isFollowing: _isFollowing,
      onToggleFollow: _toggleFollow,
      onMessage: _openMessage,
      onBook: _handleBookNow,
      lavender: ProfileLayout.lavender,
      deepLavender: ProfileLayout.deepLavender,
    );
  }

  Widget _buildBioSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                'About',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _editBio,
                  color: ProfileLayout.lavender,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bio.isNotEmpty)
            Text(
              _bio,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            )
          else if (_isOwnProfile)
            TextButton.icon(
              onPressed: _editBio,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add bio'),
              style: TextButton.styleFrom(foregroundColor: ProfileLayout.lavender),
            )
          else
            Text(
              'No bio available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_bio.isNotEmpty) const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (_experienceYears != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        size: 16, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Experience: $_experienceYears years',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              if (_languages.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_outlined,
                        size: 16, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Languages: ${_languages.join(', ')}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              if (_city.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Location: $_city',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

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
            hintText: 'Tell people about yourself...',
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

  Widget _buildSpecializationsSection() {
    // Mock ratings for specialties (can be stored in Firestore)
    final specialtyRatings = [3.5, 4.0, 3.0, 2.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: const ProfileSectionTitle(
            title: 'Specialties (with certification)',
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        if (_specialties.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _editSpecializations,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add specializations'),
                    style: TextButton.styleFrom(foregroundColor: ProfileLayout.lavender),
                  )
                : const ProfileEmptyState(text: 'No specializations yet'),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _specialties.asMap().entries.map((entry) {
                final index = entry.key;
                final specialty = entry.value;
                final rating = index < specialtyRatings.length
                    ? specialtyRatings[index]
                    : 4.0;
                
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _specialties.length - 1 ? 12 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          specialty,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          return Icon(
                            i < rating.floor()
                                ? Icons.star
                                : (i < rating
                                    ? Icons.star_half
                                    : Icons.star_border),
                            size: 16,
                            color: Colors.amber[700],
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _editSpecializations() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final controller = TextEditingController(
        text: _specialties.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Specializations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter specializations separated by commas',
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
      final specialties = result
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'specialties': specialties});
        setState(() => _specialties = specialties);
        Fluttertoast.showToast(msg: 'Specializations updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update specializations');
      }
    }
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gallery',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  onPressed: _addGalleryImage,
                  color: ProfileLayout.lavender,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_galleryImages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _addGalleryImage,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add gallery images'),
                    style: TextButton.styleFrom(foregroundColor: ProfileLayout.lavender),
                  )
                : Text(
                    'No gallery images',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _galleryImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _galleryImages[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _addGalleryImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    try {
      final fileName =
          'gallery_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_currentUser!.uid)
          .child('gallery')
          .child(fileName);
      final url = await uploadReferenceXFileAndGetUrl(
        ref,
        picked,
        metadata: SettableMetadata(contentType: 'image/jpeg'),
      );

      final updated = List<String>.from(_galleryImages)..add(url);
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'galleryImages': updated});
      setState(() => _galleryImages = updated);
      Fluttertoast.showToast(msg: 'Image added to gallery');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to add image');
    }
  }

  Widget _buildPopularProductsSection() {
    // Load products from user data
    final products = _programs.isNotEmpty 
        ? _programs 
        : (widget.profileUserId == _currentUser?.uid 
            ? [] 
            : []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Popular Products',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Check out my recommended fitness gear',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _addProgram,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add products'),
                    style: TextButton.styleFrom(foregroundColor: ProfileLayout.lavender),
                  )
                : Text(
                    'No products available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildProductCard(
                    products[0],
                    tag: products[0]['tag']?.toString() ?? 'Best Seller',
                  ),
                ),
                const SizedBox(width: 12),
                if (products.length > 1)
                  Expanded(
                    child: _buildProductCard(
                      products[1],
                      tag: products[1]['tag']?.toString() ?? 'New Arrival',
                    ),
                  )
                else
                  Expanded(child: Container()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, {required String tag}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 140,
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
                            child: Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Image-url',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag == 'Best Seller' ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
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
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Price: ${product['price']?.toString() ?? 'Rs 0.00'}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: const ProfileSectionTitle(
            title: 'Last workouts',
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        if (_lastWorkouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const ProfileEmptyState(text: 'No workouts yet'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: _lastWorkouts.map((workout) {
                final title = workout['title']?.toString() ?? 'Workout';
                final duration = workout['duration']?.toString() ?? '0 mins';
                final intensity = workout['intensity']?.toString() ?? '';
                final calories = workout['calories']?.toString() ?? '';
                
                // Determine icon based on workout title
                IconData workoutIcon = Icons.fitness_center;
                Color iconColor = Colors.grey;
                if (title.toLowerCase().contains('cardio') || 
                    title.toLowerCase().contains('run')) {
                  workoutIcon = Icons.directions_run;
                  iconColor = Colors.orange;
                } else if (title.toLowerCase().contains('zumba') || 
                           title.toLowerCase().contains('dance')) {
                  workoutIcon = Icons.music_note;
                  iconColor = Colors.orange;
                } else if (title.toLowerCase().contains('leg')) {
                  workoutIcon = Icons.accessibility_new;
                  iconColor = Colors.grey;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(workoutIcon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: $duration',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (intensity.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: intensity.toLowerCase() == 'high'
                                ? Colors.red[50]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Intensity: $intensity',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: intensity.toLowerCase() == 'high'
                                  ? Colors.red[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        )
                      else if (calories.isNotEmpty)
                        Text(
                          'Calories Burned: $calories',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _addProgram() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameController = TextEditingController();
    final durationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Program',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Program Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duration (e.g., 4 weeks)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ProfileLayout.lavender),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final newProgram = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': nameController.text,
          'duration': durationController.text.isNotEmpty
              ? durationController.text
              : 'Ongoing',
          'createdAt': FieldValue.serverTimestamp(),
        };

        final updated = List<Map<String, dynamic>>.from(_programs)..add(newProgram);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'popularProducts': updated});
        setState(() => _programs = updated);
        Fluttertoast.showToast(msg: 'Program added');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to add program');
      }
    }
  }

  Widget _buildRecentPostsSection() {
    return GuruRecentPostsSection(
      profileUserId: widget.profileUserId,
      isOwnProfile: _isOwnProfile,
      accentColor: ProfileLayout.lavender,
      onCreatePost: _openGalleryForPost,
      profilePhotoUrl: _profilePhotoUrl,
      username: _username,
      city: _city,
      formatPostTime: _formatPostTime,
      imageResolver: profilePostImageUrlFromMap,
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Reviews & Ratings',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_isOwnProfile)
                TextButton(
                  onPressed: () => _showWriteReviewDialog(),
                  child: Text(
                    'Write a Review',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('reviews')
              .where('guruId', isEqualTo: widget.profileUserId)
              .snapshots()
              .handleError((error) {
            debugPrint('Error in reviews stream: $error');
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              debugPrint('Reviews stream error: ${snapshot.error}');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading reviews',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final sortedDocs = List.from(allDocs)
              ..sort((a, b) {
                try {
                  final aTime = a.data();
                  final bTime = b.data();
                  if (aTime is! Map<String, dynamic> || bTime is! Map<String, dynamic>) {
                    return 0;
                  }
                  final aTimestamp = aTime['createdAt'];
                  final bTimestamp = bTime['createdAt'];
                  if (aTimestamp == null) return 1;
                  if (bTimestamp == null) return -1;
                  if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                    return bTimestamp.compareTo(aTimestamp);
                  }
                  return 0;
                } catch (e) {
                  debugPrint('Error sorting reviews: $e');
                  return 0;
                }
              });
            final docs = sortedDocs.take(2).toList();
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: const ProfileEmptyState(text: 'No reviews yet'),
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: docs.map((doc) {
                  final review = doc.data() as Map<String, dynamic>;
                  final name = review['userName']?.toString() ??
                      review['name']?.toString() ??
                      'User';
                  final rating = (review['rating'] ?? 4).toDouble();
                  final text = review['text']?.toString() ?? '';
                  
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: docs.indexOf(doc) < docs.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < rating.floor()
                                      ? Icons.star
                                      : (i < rating
                                          ? Icons.star_half
                                          : Icons.star_border),
                                  size: 16,
                                  color: Colors.amber[700],
                                );
                              }),
                            ),
                          ],
                        ),
                        if (text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achievements',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _addAchievement,
                  color: ProfileLayout.lavender,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_achievements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _addAchievement,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add achievements'),
                    style: TextButton.styleFrom(foregroundColor: ProfileLayout.lavender),
                  )
                : const ProfileEmptyState(text: 'No achievements yet'),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final achievement = _achievements[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events,
                          size: 32, color: Colors.amber[700]),
                      const SizedBox(height: 8),
                      Text(
                        achievement['title']?.toString() ?? 'Achievement',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Future<void> _addAchievement() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Achievement',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'Achievement Title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ProfileLayout.lavender),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      try {
        final newAchievement = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': titleController.text,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final updated =
            List<Map<String, dynamic>>.from(_achievements)..add(newAchievement);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'achievements': updated});
        setState(() => _achievements = updated);
        Fluttertoast.showToast(msg: 'Achievement added');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to add achievement');
      }
    }
  }

  Widget _buildSocialLinksSection() {
    return ProfileSectionCard(
      title: 'Social Links',
      titleFontSize: 18,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // YouTube Section
          if (_socialLinks.containsKey('youtube') ||
              _socialLinks.containsKey('YouTube'))
            _buildYouTubeSection(),
          // Apple Music Section
          if (_socialLinks.containsKey('appleMusic') ||
              _socialLinks.containsKey('Apple Music') ||
              _socialLinks.containsKey('spotify'))
            _buildAppleMusicSection(),
          // Instagram Section
          if (_socialLinks.containsKey('instagram') ||
              _socialLinks.containsKey('Instagram'))
            _buildInstagramSection(),
        ],
      ),
    );
  }

  Widget _buildYouTubeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_filled, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            Text(
              'Youtube',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: GestureDetector(
                onTap: () => _openSocialLink('youtube', _socialLinks['youtube'] ?? _socialLinks['YouTube'] ?? ''),
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Youtube Thumbnail',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAppleMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, color: Colors.pink[300], size: 24),
            const SizedBox(width: 8),
            Text(
              'Apple music',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Playlist names
        Text(
          'Playlist names',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildRadioOption('Beast workout', false),
            _buildRadioOption('Anna\'s playlist', false),
          ],
        ),
        const SizedBox(height: 16),
        // Top artist names
        Text(
          'Top artist names',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildRadioOption('Drake', false),
            _buildRadioOption('Travis Scott', false),
            _buildRadioOption('Diljit Dosanjh', false),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRadioOption(String label, bool selected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2),
            color: selected ? ProfileLayout.lavender : Colors.transparent,
          ),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInstagramSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.pink, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Instagram',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Recent posts',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: GestureDetector(
                onTap: () => _openSocialLink('instagram', _socialLinks['instagram'] ?? _socialLinks['Instagram'] ?? ''),
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: Colors.grey, size: 32),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            ProfileLayout.bg,
            ProfileLayout.lavender.withOpacity(0.1),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  NEW PROFESSIONAL FEATURES FOR GURUS
  // ===================================================================

  Widget _buildTestimonialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ProfileLayout.lavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.format_quote, color: ProfileLayout.lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Client Testimonials',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_reviews.isNotEmpty)
                TextButton(
                  onPressed: () => _showAllTestimonials(),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const ProfileEmptyState(
              text: 'No testimonials yet',
              card: true,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: _reviews.take(2).map((review) {
                final name = review['name']?.toString() ?? 'Client';
                final rating = (review['rating'] ?? 5).toDouble();
                final text = review['text']?.toString() ?? '';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: ProfileLayout.lavender.withOpacity(0.2),
                            child: Text(
                              name[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: ProfileLayout.lavender,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < rating.floor()
                                          ? Icons.star
                                          : (i < rating ? Icons.star_half : Icons.star_border),
                                      size: 14,
                                      color: Colors.amber[700],
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          text,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCertificationsDisplaySection() {
    if (_certifications.isEmpty && !_isOwnProfile) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ProfileLayout.lavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.verified, color: ProfileLayout.lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Certifications & Credentials',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: ProfileLayout.lavender),
                  onPressed: _addCertification,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_certifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.school_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      _isOwnProfile 
                          ? 'Add your certifications to build trust'
                          : 'No certifications listed',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _certifications.map((cert) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ProfileLayout.lavender.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ProfileLayout.lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.verified_user, color: ProfileLayout.lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cert['name']?.toString() ?? 'Certification',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (cert['issuer'] != null)
                              Text(
                                cert['issuer'].toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_isOwnProfile)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                          onSelected: (value) {
                            final index = _certifications.indexOf(cert);
                            if (value == 'edit') {
                              _editCertification(index, cert);
                            } else if (value == 'delete') {
                              _deleteCertification(index);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTrainingProgramsShowcase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ProfileLayout.lavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fitness_center, color: ProfileLayout.lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Training Programs',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_programs.isNotEmpty)
                TextButton(
                  onPressed: () => _showAllPrograms(),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_programs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.list_alt, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      _isOwnProfile 
                          ? 'Create training programs for your clients'
                          : 'No programs available',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isOwnProfile) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addTrainingProgram,
                        icon: Icon(Icons.add, size: 18),
                        label: Text('Add Program'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProfileLayout.lavender,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _programs.length,
                itemBuilder: (context, index) {
                  final program = _programs[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ProfileLayout.lavender.withOpacity(0.1), ProfileLayout.deepLavender.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ProfileLayout.lavender.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.play_circle_outline, color: ProfileLayout.lavender, size: 24),
                            const Spacer(),
                            if (program['price'] != null && (program['price'] as num) > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ProfileLayout.lavender,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '₹${program['price']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          program['name']?.toString() ?? 'Program',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          program['duration']?.toString() ?? 'Ongoing',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (_isOwnProfile)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                                onPressed: () => _editTrainingProgram(index, program),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                                onPressed: () => _deleteTrainingProgram(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _showProgramDetails(program),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ProfileLayout.lavender,
                              foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'View Details',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSuccessStoriesSection() {
    // Mock success stories - in real app, load from Firestore
    final successStories = [
      {
        'clientName': 'Rajesh K.',
        'achievement': 'Lost 15kg in 3 months',
        'beforeAfter': 'Before/After photos',
        'testimonial': 'Amazing transformation with personalized training!',
      },
      {
        'clientName': 'Priya M.',
        'achievement': 'Completed first marathon',
        'beforeAfter': 'Race day photos',
        'testimonial': 'Best coach ever! Achieved my dream goal.',
      },
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.celebration, color: Colors.green[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Success Stories',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: ProfileLayout.lavender),
                  onPressed: _addSuccessStory,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: successStories.length,
              itemBuilder: (context, index) {
                final story = successStories[index];
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.emoji_events, color: Colors.green[700], size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  story['clientName'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  story['achievement'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isOwnProfile)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editSuccessStory(index, story);
                                } else if (value == 'delete') {
                                  _deleteSuccessStory(index);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            story['beforeAfter'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story['testimonial'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTutorialsPreview() {
    // Mock video tutorials - in real app, load from Firestore
    final tutorials = [
      {'title': 'Proper Form: Deadlift', 'duration': '5:30', 'views': '1.2K'},
      {'title': 'Cardio HIIT Workout', 'duration': '12:15', 'views': '3.5K'},
      {'title': 'Yoga for Flexibility', 'duration': '20:00', 'views': '890'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.play_circle_filled, color: Colors.red[700], size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Video Tutorials',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: ProfileLayout.lavender),
                  onPressed: _addVideoTutorial,
                )
              else if (tutorials.isNotEmpty)
                TextButton(
                  onPressed: () => _showAllVideos(tutorials),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ProfileLayout.lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tutorials.length,
              itemBuilder: (context, index) {
                final tutorial = tutorials[index];
                return Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Video thumbnail placeholder
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 48,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      if (_isOwnProfile)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.more_vert, size: 16, color: Colors.white),
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editVideoTutorial(index, tutorial);
                              } else if (value == 'delete') {
                                _deleteVideoTutorial(index);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tutorial['title'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    tutorial['duration'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.visibility, size: 12, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    tutorial['views'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatReviewDate(dynamic date) {
    if (date == null) return '';
    try {
      if (date is Timestamp) {
        final reviewDate = date.toDate();
        final now = DateTime.now();
        final difference = now.difference(reviewDate);

        if (difference.inDays == 0) {
          return 'Today';
        } else if (difference.inDays == 1) {
          return 'Yesterday';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else if (difference.inDays < 30) {
          return '${(difference.inDays / 7).floor()} weeks ago';
        } else {
          return '${reviewDate.day}/${reviewDate.month}/${reviewDate.year}';
        }
      }
      return date.toString();
    } catch (e) {
      return '';
    }
  }

  String _formatPostTime(dynamic date) {
    if (date == null) return 'Just now';
    try {
      if (date is Timestamp) {
        final postDate = date.toDate();
        final now = DateTime.now();
        final difference = now.difference(postDate);

        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes} minutes ago';
        } else if (difference.inHours < 24) {
          return '${difference.inHours} hours ago';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else {
          return '${postDate.day}/${postDate.month}/${postDate.year}';
        }
      }
      return date.toString();
    } catch (e) {
      return 'Just now';
    }
  }

  // ===================================================================
  //  EDIT FUNCTIONS FOR NEW FEATURES
  // ===================================================================

  Future<void> _addCertification() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Certification',
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
                  labelText: 'Certification Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.verified_user, color: ProfileLayout.lavender),
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
                final newCert = {
                  'name': nameCtrl.text.trim(),
                  'issuer': issuerCtrl.text.trim(),
                  if (yearCtrl.text.trim().isNotEmpty) 'year': int.tryParse(yearCtrl.text.trim()),
                };
                
                final updatedCerts = List<Map<String, dynamic>>.from(_certifications)..add(newCert);
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'certifications': updatedCerts});
                
                setState(() => _certifications = updatedCerts);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Certification added successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding certification: $e');
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

  Future<void> _editCertification(int index, Map<String, dynamic> cert) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController(text: cert['name']?.toString() ?? '');
    final issuerCtrl = TextEditingController(text: cert['issuer']?.toString() ?? '');
    final yearCtrl = TextEditingController(text: cert['year']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Certification',
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
                  labelText: 'Certification Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.verified_user, color: ProfileLayout.lavender),
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
                final updatedCert = {
                  'name': nameCtrl.text.trim(),
                  'issuer': issuerCtrl.text.trim(),
                  if (yearCtrl.text.trim().isNotEmpty) 'year': int.tryParse(yearCtrl.text.trim()),
                };
                
                final updatedCerts = List<Map<String, dynamic>>.from(_certifications);
                updatedCerts[index] = updatedCert;
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'certifications': updatedCerts});
                
                setState(() => _certifications = updatedCerts);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Certification updated successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating certification: $e');
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

  Future<void> _deleteCertification(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Certification',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this certification?',
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
        final updatedCerts = List<Map<String, dynamic>>.from(_certifications)..removeAt(index);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'certifications': updatedCerts});
        
        setState(() => _certifications = updatedCerts);
        Fluttertoast.showToast(msg: 'Certification deleted successfully!');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting certification: $e');
      }
    }
  }

  Future<void> _addTrainingProgram() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    final descriptionCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Training Program',
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
                  labelText: 'Program Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.fitness_center, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: 'Duration (e.g., 12 weeks)',
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
                controller: descriptionCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.description, color: ProfileLayout.lavender),
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
              if (nameCtrl.text.trim().isEmpty) return;
              
              try {
                final newProgram = {
                  'name': nameCtrl.text.trim(),
                  'duration': durationCtrl.text.trim().isEmpty ? 'Ongoing' : durationCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                  'description': descriptionCtrl.text.trim(),
                };
                
                final updatedPrograms = List<Map<String, dynamic>>.from(_programs)..add(newProgram);
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'trainingPrograms': updatedPrograms});
                
                setState(() => _programs = updatedPrograms);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Training program added successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding program: $e');
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

  Future<void> _editTrainingProgram(int index, Map<String, dynamic> program) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController(text: program['name']?.toString() ?? '');
    final durationCtrl = TextEditingController(text: program['duration']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: (program['price'] ?? 0).toString());
    final descriptionCtrl = TextEditingController(text: program['description']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Training Program',
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
                  labelText: 'Program Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.fitness_center, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
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
                controller: descriptionCtrl,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.description, color: ProfileLayout.lavender),
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
              if (nameCtrl.text.trim().isEmpty) return;
              
              try {
                final updatedProgram = {
                  'name': nameCtrl.text.trim(),
                  'duration': durationCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                  'description': descriptionCtrl.text.trim(),
                };
                
                final updatedPrograms = List<Map<String, dynamic>>.from(_programs);
                updatedPrograms[index] = updatedProgram;
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'trainingPrograms': updatedPrograms});
                
                setState(() => _programs = updatedPrograms);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Program updated successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating program: $e');
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

  Future<void> _deleteTrainingProgram(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Program',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this program?',
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
        final updatedPrograms = List<Map<String, dynamic>>.from(_programs)..removeAt(index);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'trainingPrograms': updatedPrograms});
        
        setState(() => _programs = updatedPrograms);
        Fluttertoast.showToast(msg: 'Program deleted successfully!');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting program: $e');
      }
    }
  }

  Future<void> _addSuccessStory() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final clientNameCtrl = TextEditingController();
    final achievementCtrl = TextEditingController();
    final testimonialCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Success Story',
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
                controller: clientNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Client Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: achievementCtrl,
                decoration: InputDecoration(
                  labelText: 'Achievement',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.emoji_events, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: testimonialCtrl,
                decoration: InputDecoration(
                  labelText: 'Testimonial',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.format_quote, color: ProfileLayout.lavender),
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
              if (clientNameCtrl.text.trim().isEmpty || achievementCtrl.text.trim().isEmpty) return;
              
              try {
                final newStory = {
                  'clientName': clientNameCtrl.text.trim(),
                  'achievement': achievementCtrl.text.trim(),
                  'testimonial': testimonialCtrl.text.trim(),
                  'beforeAfter': 'Before/After photos',
                };
                
                // Save to Firestore - you can create a successStories collection
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('successStories')
                    .add(newStory);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Success story added successfully!');
                await _loadProfileData(); // Reload to show updated data
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding story: $e');
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

  Future<void> _editSuccessStory(int index, Map<String, dynamic> story) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final clientNameCtrl = TextEditingController(text: story['clientName']?.toString() ?? '');
    final achievementCtrl = TextEditingController(text: story['achievement']?.toString() ?? '');
    final testimonialCtrl = TextEditingController(text: story['testimonial']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Success Story',
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
                controller: clientNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Client Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.person, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: achievementCtrl,
                decoration: InputDecoration(
                  labelText: 'Achievement',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.emoji_events, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: testimonialCtrl,
                decoration: InputDecoration(
                  labelText: 'Testimonial',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.format_quote, color: ProfileLayout.lavender),
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
              if (clientNameCtrl.text.trim().isEmpty || achievementCtrl.text.trim().isEmpty) return;
              
              try {
                final updatedStory = {
                  'clientName': clientNameCtrl.text.trim(),
                  'achievement': achievementCtrl.text.trim(),
                  'testimonial': testimonialCtrl.text.trim(),
                };
                
                // Update in Firestore - you'll need to track document IDs
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Success story updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating story: $e');
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

  Future<void> _deleteSuccessStory(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Success Story',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this success story?',
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
        Fluttertoast.showToast(msg: 'Success story deleted successfully!');
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting story: $e');
      }
    }
  }

  Future<void> _addVideoTutorial() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Video Tutorial',
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
                  labelText: 'Video Title',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.play_circle_outline, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: 'Duration (e.g., 5:30)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.access_time, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Video URL (Optional)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.link, color: ProfileLayout.lavender),
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
              if (titleCtrl.text.trim().isEmpty) return;
              
              try {
                final newTutorial = {
                  'title': titleCtrl.text.trim(),
                  'duration': durationCtrl.text.trim(),
                  'url': urlCtrl.text.trim(),
                  'views': '0',
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('videoTutorials')
                    .add(newTutorial);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Video tutorial added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding tutorial: $e');
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

  Future<void> _editVideoTutorial(int index, Map<String, dynamic> tutorial) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleCtrl = TextEditingController(text: tutorial['title']?.toString() ?? '');
    final durationCtrl = TextEditingController(text: tutorial['duration']?.toString() ?? '');
    final urlCtrl = TextEditingController(text: tutorial['url']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Video Tutorial',
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
                  labelText: 'Video Title',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.play_circle_outline, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
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
                  prefixIcon: Icon(Icons.access_time, color: ProfileLayout.lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ProfileLayout.lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Video URL',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.link, color: ProfileLayout.lavender),
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
              if (titleCtrl.text.trim().isEmpty) return;
              
              try {
                // Update in Firestore - you'll need to track document IDs
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Video tutorial updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating tutorial: $e');
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

  Future<void> _deleteVideoTutorial(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Video Tutorial',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this video tutorial?',
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
        Fluttertoast.showToast(msg: 'Video tutorial deleted successfully!');
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting tutorial: $e');
      }
    }
  }

  // ===================================================================
  //  HELPER FUNCTIONS FOR STATIC FEATURES
  // ===================================================================
  
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
          case 'spotify':
          case 'applemusic':
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
  
  Future<void> _showWriteReviewDialog() async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to write a review');
      return;
    }
    
    final ratingCtrl = TextEditingController(text: '5');
    final reviewCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Write a Review',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ProfileLayout.lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rate this Guru',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ratingCtrl,
                decoration: InputDecoration(
                  labelText: 'Rating (1-5)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.star, color: ProfileLayout.lavender),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewCtrl,
                decoration: InputDecoration(
                  labelText: 'Your Review',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.rate_review, color: ProfileLayout.lavender),
                ),
                maxLines: 4,
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
              if (reviewCtrl.text.trim().isEmpty) {
                Fluttertoast.showToast(msg: 'Please write a review');
                return;
              }
              
              try {
                final rating = double.tryParse(ratingCtrl.text) ?? 5.0;
                final ratingClamped = rating.clamp(1.0, 5.0);
                
                // Get current user name
                final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
                final userName = userDoc.data()?['name'] ?? 'Anonymous';
                
                await _firestore.collection('reviews').add({
                  'guruId': widget.profileUserId,
                  'userId': _currentUser!.uid,
                  'userName': userName,
                  'rating': ratingClamped,
                  'text': reviewCtrl.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                
                // Update guru's rating
                final reviewsSnapshot = await _firestore
                    .collection('reviews')
                    .where('guruId', isEqualTo: widget.profileUserId)
                    .get();
                
                final totalRating = reviewsSnapshot.docs
                    .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a + b);
                final avgRating = totalRating / reviewsSnapshot.docs.length;
                
                await _firestore.collection('users').doc(widget.profileUserId).update({
                  'rating': avgRating,
                  'reviewCount': reviewsSnapshot.docs.length,
                });
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Review submitted successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error submitting review: $e');
              }
            },
            child: Text(
              'Submit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showAllTestimonials() async {
    if (_reviews.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllTestimonialsPage(reviews: _reviews),
    );
  }
  
  Future<void> _showAllPrograms() async {
    if (_programs.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllProgramsPage(
        programs: _programs,
        isOwnProfile: _isOwnProfile,
        onProgramTap: (program) => _showProgramDetails(program),
      ),
    );
  }
  
  Future<void> _showProgramDetails(Map<String, dynamic> program) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProgramDetailsPage(program: program),
    );
  }
  
  Future<void> _showAllVideos(List<Map<String, dynamic>> tutorials) async {
    if (tutorials.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllVideosPage(tutorials: tutorials),
    );
  }

  Widget _buildBusinessFeaturesShortcut() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _tabController.animateTo(1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ProfileLayout.lavender.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ProfileLayout.lavender.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, color: ProfileLayout.deepLavender),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Open Business Tools: Booking, Classes, Earnings, Students, Analytics',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfileLayout.deepLavender,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ProfileLayout.deepLavender),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
//  MODAL PAGES FOR GURU FEATURES
// ===================================================================

class _AllTestimonialsPage extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  
  const _AllTestimonialsPage({required this.reviews});
  
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
                  'All Testimonials',
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
                final name = review['userName']?.toString() ?? review['name']?.toString() ?? 'User';
                final rating = (review['rating'] ?? 5).toDouble();
                final text = review['text']?.toString() ?? '';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (i) {
                              return Icon(
                                i < rating.floor()
                                    ? Icons.star
                                    : (i < rating
                                        ? Icons.star_half
                                        : Icons.star_border),
                                size: 16,
                                color: Colors.amber[700],
                              );
                            }),
                          ),
                        ],
                      ),
                      if (text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          text,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
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

class _AllProgramsPage extends StatelessWidget {
  final List<Map<String, dynamic>> programs;
  final bool isOwnProfile;
  final Function(Map<String, dynamic>) onProgramTap;
  
  const _AllProgramsPage({
    required this.programs,
    required this.isOwnProfile,
    required this.onProgramTap,
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
                  'All Training Programs',
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
              itemCount: programs.length,
              itemBuilder: (context, index) {
                final program = programs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(
                      program['name']?.toString() ?? 'Program',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      program['description']?.toString() ?? '',
                      style: GoogleFonts.poppins(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      onProgramTap(program);
                    },
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

class _ProgramDetailsPage extends StatelessWidget {
  final Map<String, dynamic> program;
  
  const _ProgramDetailsPage({required this.program});
  
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
                    program['name']?.toString() ?? 'Program Details',
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
                  if (program['description'] != null)
                    Text(
                      program['description']?.toString() ?? '',
                      style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                    ),
                  if (program['duration'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Duration: ${program['duration']}',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (program['price'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Price: ₹${program['price']}',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllVideosPage extends StatelessWidget {
  final List<Map<String, dynamic>> tutorials;
  
  const _AllVideosPage({required this.tutorials});
  
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
                  'All Video Tutorials',
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
                childAspectRatio: 0.8,
              ),
              itemCount: tutorials.length,
              itemBuilder: (context, index) {
                final tutorial = tutorials[index];
                return GestureDetector(
                  onTap: () async {
                    final url = tutorial['url']?.toString() ?? tutorial['link']?.toString();
                    if (url != null && url.isNotEmpty) {
                      try {
                        String videoUrl = url;
                        if (!videoUrl.startsWith('http://') && !videoUrl.startsWith('https://')) {
                          videoUrl = 'https://$videoUrl';
                        }
                        
                        final uri = Uri.parse(videoUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          Fluttertoast.showToast(msg: 'Could not open video');
                        }
                      } catch (e) {
                        Fluttertoast.showToast(msg: 'Failed to open video');
                      }
                    } else {
                      Fluttertoast.showToast(msg: 'Video link not available');
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            tutorial['title']?.toString() ?? 'Video Tutorial',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
}


