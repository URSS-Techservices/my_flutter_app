import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/services/cloudinary_service.dart'; // Cloudinary helper class
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/Bottom Pages/full_screen_camera_page.dart';
import 'package:firebase_storage/firebase_storage.dart';



import 'package:halo/core/halo_toast.dart';
// THEME CONSTANTS (match Login / Home)
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray

class AddPostPage extends StatefulWidget {
  @override
  _AddPostPageState createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  List<XFile> _selectedImages = [];
  List<XFile> _selectedVideos = [];
  bool _isLoading = false;

  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _showCameraPreview = false;

  // Tags / interests
  final List<String> _availableTags = const [
    'Career',
    'Wellness',
    'Fitness',
    'Spirituality',
    'Study',
    'Finance',
    'Mindset',
    'Relationships',
    'Productivity',
    'Lifestyle',
  ];
  final List<String> _selectedTags = [];

  // @mention auto-suggestions
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentionSuggestions = false;
  String _currentMentionQuery = '';
  int _mentionRequestId = 0; // to avoid race conditions

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Initialize camera
  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        HaloToast.show("Camera permission is required to take photos and videos.");
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _openFullScreenCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullScreenCameraPage(cameras: _cameras!),
      ),
    );

    if (result is XFile) {
      setState(() {
        if (result.path.endsWith('.mp4')) {
          _selectedVideos = [result];
        } else {
          _selectedImages.add(result);
        }
      });
    }
  }

  void _hideCamera() {
    setState(() {
      _showCameraPreview = false;
      _isRecording = false;
    });
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _selectedImages.add(photo);
      });
      _hideCamera();
    } catch (_) {}
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (_) {}
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || !_isRecording) {
      return;
    }

    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      setState(() {
        _selectedVideos = [video];
        _isRecording = false;
      });
      _hideCamera();
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideos = [video];
      });
    }
  }

  /// Parse @mentions from caption and return lowercase usernames
  List<String> _extractMentions(String caption) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(caption);
    final set = <String>{};
    for (final m in matches) {
      final username = m.group(1);
      if (username != null && username.trim().isNotEmpty) {
        set.add(username.toLowerCase());
      }
    }
    return set.toList();
  }

  /// Upload and save post
  Future<void> _submitPost() async {
    if (_selectedImages.isEmpty && _selectedVideos.isEmpty) {
      HaloToast.show("Please select at least one image or a video.");
      return;
    }

    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      HaloToast.show("Please enter a caption.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        HaloToast.show("Please sign in to post");
        setState(() => _isLoading = false);
        return;
      }

      final postId = FirebaseFirestore.instance
          .collection("posts")
          .doc()
          .id;

      List<Map<String, dynamic>> mediaList = [];

      // Upload images
      for (var image in _selectedImages) {
        final ref = FirebaseStorage.instance.ref(
            'users/$userId/posts/$postId-${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(
          File(image.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final imageUrl = await ref.getDownloadURL();
        mediaList.add({'type': 'image', 'url': imageUrl});
      }

      // Upload videos with explicit content-type so both iOS and Android can play
      for (var video in _selectedVideos) {
        final ref = FirebaseStorage.instance.ref(
            'users/$userId/posts/$postId-${DateTime.now().millisecondsSinceEpoch}.mp4');
        await ref.putFile(
          File(video.path),
          SettableMetadata(
            contentType: 'video/mp4',
            customMetadata: {'uploaded_by': userId},
          ),
        );
        final videoUrl = await ref.getDownloadURL();
        mediaList.add({'type': 'video', 'url': videoUrl});
      }


      final mentions = _extractMentions(caption);

      await FirebaseFirestore.instance
          .collection("posts")
          .doc(postId)
          .set({
        "userId": userId,
        "media": mediaList,
        "images": mediaList
            .where((m) => m['type'] == 'image')
            .map<String>((m) => m['url'] as String)
            .toList(),
        "caption": caption,
        "location": _locationController.text.trim(),
        "tags": _selectedTags,
        "mentions": mentions,
        "createdAt": FieldValue.serverTimestamp(),
        "timestamp": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'postsCount': FieldValue.increment(1),
      });

      if (!mounted) return;

      HaloToast.show("Post uploaded successfully!");

      setState(() {
        _selectedImages = [];
        _selectedVideos = [];
        _captionController.clear();
        _locationController.clear();
        _selectedTags.clear();
        _mentionSuggestions = [];
        _showMentionSuggestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      HaloToast.show("Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---- @MENTION LOGIC ----

  void _onCaptionChanged(String value) {
    setState(() {}); // update preview

    final selection = _captionController.selection;
    final cursorPos = selection.baseOffset;
    if (cursorPos <= 0 || cursorPos > value.length) {
      _hideMentionSuggestions();
      return;
    }

    // Find last '@' before cursor
    final textBeforeCursor = value.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      _hideMentionSuggestions();
      return;
    }

    // Ensure '@' is start or previous char is whitespace
    if (atIndex > 0) {
      final prevChar = textBeforeCursor[atIndex - 1];
      if (!RegExp(r'\s').hasMatch(prevChar)) {
        _hideMentionSuggestions();
        return;
      }
    }

    final mentionText = textBeforeCursor.substring(atIndex + 1);
    if (mentionText.isEmpty) {
      _hideMentionSuggestions();
      return;
    }

    // Only search when at least 2 chars typed
    if (mentionText.length < 2) {
      _hideMentionSuggestions();
      return;
    }

    _currentMentionQuery = mentionText.toLowerCase();
    _fetchMentionSuggestions(_currentMentionQuery);
  }

  void _hideMentionSuggestions() {
    if (_showMentionSuggestions || _mentionSuggestions.isNotEmpty) {
      setState(() {
        _showMentionSuggestions = false;
        _mentionSuggestions = [];
      });
    }
  }

  Future<void> _fetchMentionSuggestions(String query) async {
    final int requestId = ++_mentionRequestId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower',
          isGreaterThanOrEqualTo: query,
          isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();

      if (!mounted || requestId != _mentionRequestId) return;

      final results = snap.docs
          .map((d) => d.data()..['id'] = d.id)
          .toList(growable: false);

      setState(() {
        _mentionSuggestions = results;
        _showMentionSuggestions = results.isNotEmpty;
      });
    } catch (_) {
      if (!mounted || requestId != _mentionRequestId) return;
      setState(() {
        _mentionSuggestions = [];
        _showMentionSuggestions = false;
      });
    }
  }

  void _insertMention(String username) {
    final text = _captionController.text;
    final selection = _captionController.selection;
    final cursorPos = selection.baseOffset;

    if (cursorPos < 0 || cursorPos > text.length) return;

    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    final before = text.substring(0, atIndex + 1); // includes '@'
    final after = text.substring(cursorPos);

    final newText = '$before$username $after';
    final newCursorPos = (before + username + ' ').length;

    _captionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    setState(() {
      _currentMentionQuery = '';
      _mentionSuggestions = [];
      _showMentionSuggestions = false;
    });
  }

  // ---- UI HELPERS ----

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final isDisabled = onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 100,
          decoration: BoxDecoration(
            gradient: color != null
                ? LinearGradient(
              colors: [
                color.withValues(alpha: 0.9),
                color.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [
                kPrimaryColor.withValues(alpha: 0.15),
                kPrimaryColor.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey.shade300
                  : (color ?? kPrimaryColor).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: isDisabled
                ? []
                : [
              BoxShadow(
                color: (color ?? kPrimaryColor).withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isDisabled
                        ? Colors.grey.shade400
                        : (color ?? kSecondaryColor),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? Colors.grey.shade400
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build preview caption with @mentions highlighted
  Widget _buildPreviewCaption(TextStyle baseStyle) {
    final text = _captionController.text;
    if (text.isEmpty) return const SizedBox.shrink();

    final words = text.split(' ');
    return Text.rich(
      TextSpan(
        children: words.map((w) {
          if (w.startsWith('@') && w.length > 1) {
            return TextSpan(
              text: '$w ',
              style: baseStyle.copyWith(
                color: kSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            );
          }
          return TextSpan(text: '$w ', style: baseStyle);
        }).toList(),
      ),
    );
  }

  /// Live preview card – roughly matches Home feed UI
  Widget _buildPreviewCard(TextTheme textTheme) {
    final hasMedia =
        _selectedImages.isNotEmpty || _selectedVideos.isNotEmpty;
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasLocation = _locationController.text.trim().isNotEmpty;

    if (!hasMedia && !hasCaption && !hasLocation && _selectedTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                spreadRadius: -12,
                offset: const Offset(0, 16),
                color: Colors.black.withOpacity(0.08),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  leading: const CircleAvatar(
                    backgroundImage:
                    AssetImage('assets/images/Profile.png'),
                    radius: 18,
                  ),
                  title: Text(
                    hasLocation ? _locationController.text.trim() : 'Location',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Just now',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  trailing: const Icon(Icons.more_horiz_rounded),
                ),

                // Media preview (first image or video placeholder)
                if (hasMedia)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _selectedImages.isNotEmpty
                        ? Image.file(
                      File(_selectedImages.first.path),
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      height: 260,
                      width: double.infinity,
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                // Actions row (static icons for preview)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 4, right: 4, top: 4, bottom: 4),
                  child: Row(
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
                ),

                // Tags
                if (_selectedTags.isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: -4,
                      children: _selectedTags
                          .map(
                            (tag) => Chip(
                          label: Text(
                            tag,
                            style: textTheme.bodySmall?.copyWith(
                              color: kSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor:
                          kPrimaryColor.withOpacity(0.10),
                          side: BorderSide(
                            color: kPrimaryColor.withOpacity(0.4),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                          .toList(),
                    ),
                  ),

                // Caption with mentions highlighted
                if (hasCaption)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: _buildPreviewCaption(
                      textTheme.bodyMedium!.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (_showCameraPreview && !_isCameraInitialized) {
      return const Padding(
        padding: EdgeInsets.only(top: 12.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_showCameraPreview || !_isCameraInitialized) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _hideCamera,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isRecording
                        ? _stopVideoRecording
                        : _startVideoRecording,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.videocam,
                        color: _isRecording ? Colors.white : Colors.black,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isRecording)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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

  Widget _buildMentionSuggestions(TextTheme textTheme) {
    if (!_showMentionSuggestions || _mentionSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _mentionSuggestions.length,
        separatorBuilder: (_, __) => Divider(
          height: 0,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          final user = _mentionSuggestions[index];
          final username = (user['username'] ?? '').toString();
          final fullName = (user['fullname'] ?? '').toString();

          return ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: user['photoUrl'] != null
                  ? NetworkImage(user['photoUrl'])
                  : const AssetImage('assets/images/Profile.png')
              as ImageProvider,
            ),
            title: Text(
              '@$username',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: fullName.isNotEmpty
                ? Text(
              fullName,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.black87,
              ),
            )
                : null,
            onTap: () => _insertMention(username),
          );
        },
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
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Create Post',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kSecondaryColor, kPrimaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 18.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 32,
                          spreadRadius: -10,
                          offset: const Offset(0, 18),
                          color: Colors.black.withOpacity(0.10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header row with improved design
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      kPrimaryColor.withOpacity(0.2),
                                      kPrimaryColor.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: kPrimaryColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 18,
                                      color: kSecondaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Create Post",
                                      style: textTheme.labelMedium?.copyWith(
                                        color: kSecondaryColor,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimaryColor.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Halo',
                                  style: GoogleFonts.pacifico(
                                    fontSize: 22,
                                    color: kSecondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Location with improved styling
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _locationController,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: '📍 Location',
                              hintText: 'Where are you?',
                              hintStyle: textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                              labelStyle: textTheme.labelMedium?.copyWith(
                                color: kSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      kPrimaryColor.withOpacity(0.2),
                                      kPrimaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: kSecondaryColor,
                                  size: 20,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: kPrimaryColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: kPrimaryColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: kPrimaryColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Media selection section with improved design
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: kSecondaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Add Media",
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Media selection buttons row - removed duplicate camera
                        Row(
                          children: [
                            _buildMediaButton(
                              icon: Icons.photo_library_rounded,
                              label: 'Gallery',
                              onTap: _pickImages,
                              color: kPrimaryColor,
                            ),
                            const SizedBox(width: 12),
                            _buildMediaButton(
                              icon: Icons.camera_alt_rounded,
                              label: 'Camera',
                              onTap: _isCameraInitialized ? _openFullScreenCamera : null,
                              color: kSecondaryColor,
                            ),
                            const SizedBox(width: 12),
                            _buildMediaButton(
                              icon: Icons.video_library_rounded,
                              label: 'Video',
                              onTap: _pickVideo,
                              color: const Color(0xFFD3F8E2),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Selected Images Preview with improved design
                        if (_selectedImages.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: kPrimaryColor.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 110,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  final img = _selectedImages[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0),
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Image.file(
                                              File(img.path),
                                              width: 110,
                                              height: 110,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedImages.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
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

                        if (_selectedVideos.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.withOpacity(0.1),
                                  Colors.red.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.videocam_rounded,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '1 video selected',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedVideos = [];
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_selectedImages.isEmpty &&
                            _selectedVideos.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  color: Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'No media selected yet',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Camera preview (if open)
                        // _buildCameraPreview(),

                        const SizedBox(height: 24),

                        // Caption with improved styling
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: kSecondaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Caption",
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _captionController,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText:
                              'Share your thoughts... Use @username to mention someone',
                              hintStyle: textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                              alignLabelWithHint: true,
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      kPrimaryColor.withOpacity(0.2),
                                      kPrimaryColor.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.text_fields_rounded,
                                  color: kSecondaryColor,
                                  size: 20,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: kPrimaryColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: kPrimaryColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: kPrimaryColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: _onCaptionChanged,
                          ),
                        ),

                        // @mention suggestions dropdown
                        _buildMentionSuggestions(textTheme),

                        const SizedBox(height: 24),

                        // Tags selection with improved design
                        Row(
                          children: [
                            Icon(
                              Icons.tag_rounded,
                              color: kSecondaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Tags / Interests",
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: kPrimaryColor.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimaryColor.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _availableTags.map((tag) {
                              final selected = _selectedTags.contains(tag);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selected
                                        ? _selectedTags.remove(tag)
                                        : _selectedTags.add(tag);
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: selected
                                        ? LinearGradient(
                                      colors: [
                                        kPrimaryColor.withOpacity(0.25),
                                        kPrimaryColor.withOpacity(0.15),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: selected ? null : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? kPrimaryColor
                                          : Colors.grey.shade300,
                                      width: selected ? 2 : 1.5,
                                    ),
                                    boxShadow: selected
                                        ? [
                                      BoxShadow(
                                        color: kPrimaryColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: kSecondaryColor,
                                        ),
                                      if (selected) const SizedBox(width: 6),
                                      Text(
                                        tag,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: selected
                                              ? kSecondaryColor
                                              : Colors.black87,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Preview card
                        _buildPreviewCard(textTheme),

                        const SizedBox(height: 24),

                        // Submit button with improved design
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: kSecondaryColor.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPost,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kPrimaryColor, kSecondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Post to Halo',
                                      style:
                                      textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
