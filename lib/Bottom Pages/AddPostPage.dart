import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:halo/models/post_place.dart';
import 'package:halo/Bottom Pages/location_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:halo/services/upload_service.dart';
import 'package:halo/services/video_upload_policy.dart';
import 'video_quick_edit_page.dart';
import 'video_thumbnail_picker.dart';

// ── Theme (aligned with app-wide lavender / purple palette) ───────────────
const Color kPrimaryColor   = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBgColor        = Color(0xFFF4F1FB);
const Color _kSurface       = Color(0xFFEFECF8);
const Color _kCardBg        = Colors.white;
const Color _kBorder        = Color(0xFFE8E4F0);
const Color _kTextPrimary   = Color(0xFF1A1A2E);
const Color _kTextSecondary = Color(0xFF888899);

// ══════════════════════════════════════════════════════════════════════════
//  MediaItem – wraps an XFile + optional VideoPlayerController
// ══════════════════════════════════════════════════════════════════════════
enum MediaType { image, video }

class MediaItem {
  final XFile file;
  final MediaType type;
  final Uint8List? videoCoverBytes;
  final int? trimStartMs;
  final int? trimEndMs;
  VideoPlayerController? videoController;

  MediaItem({
    required this.file,
    required this.type,
    this.videoCoverBytes,
    this.trimStartMs,
    this.trimEndMs,
    this.videoController,
  });

  bool get isVideo => type == MediaType.video;
}

// ══════════════════════════════════════════════════════════════════════════
//  AddPostPage
// ══════════════════════════════════════════════════════════════════════════
class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});
  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage>
    with SingleTickerProviderStateMixin {
  static const int _maxMediaItems = 4;

  // Controllers
  final _captionCtrl      = TextEditingController();
  final _captionFocusNode = FocusNode();
  final _picker            = ImagePicker();
  final UploadService _uploadService = UploadService();

  // Media
  final List<MediaItem> _media = [];

  // Temp file tracking for cleanup
  final List<String> _tempFilePaths = [];

  // Upload state
  bool   _isUploading      = false;
  bool   _isMigratingPosts = false;
  double _uploadProgress   = 0;
  String _uploadStatusMsg  = '';
  int    _currentUploadIdx = 0;

  // Camera
  List<CameraDescription>? _cameras;
  bool _cameraPermissionDenied = false;
  bool _cameraInitializing     = false;

  // @mention
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions  = false;
  int  _mentionReqId  = 0;

  PostPlace? _selectedPlace;

  // Tab animation
  late final AnimationController _tabAnim;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _initCamera();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _captionFocusNode.dispose();
    _tabAnim.dispose();
    for (final m in _media) {
      m.videoController?.dispose();
    }
    _cleanupTempFiles(List.from(_tempFilePaths));
    super.dispose();
  }

  // ── Temp file cleanup ────────────────────────────────────────────────────
  void _cleanupTempFiles(List<String> paths) {
    for (final p in paths) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  // ── Camera init (list only — full-screen page initializes the controller) ─
  Future<void> _initCamera() async {
    if (_cameras != null && _cameras!.isNotEmpty) return;
    if (_cameraInitializing) return;
    _cameraInitializing = true;
    if (mounted) setState(() {});

    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _cameraPermissionDenied = true;
          _cameraInitializing = false;
        });
      }
      return;
    }
    try {
      final list = await availableCameras();
      if (mounted) {
        setState(() {
          _cameras = list;
          _cameraInitializing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cameraInitializing = false);
    }
  }

  // ── Pick ONE image from gallery (prevents bulk memory spike) ─────────────
  Future<void> _pickImages() async {
    try {
      final remaining = _maxMediaItems - _media.length;
      if (remaining <= 0) {
        _showSnack('Maximum $_maxMediaItems media items allowed.');
        return;
      }

      // FIX: Use pickImage (single) instead of pickMultiImage to avoid
      // loading all images into memory simultaneously.
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,   // lower quality = much smaller in-memory size
        maxWidth: 1280,     // was 1920 — halving pixel count cuts memory ~56%
        maxHeight: 1280,
      );
      if (file == null || !mounted) return;

      final edited = await _openImageEditor(file);
      if (edited == null || !mounted) return;

      setState(() {
        _media.add(MediaItem(file: edited, type: MediaType.image));
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to pick image: $e');
    }
  }

  // ── Open image editor with output size constraint ─────────────────────────
  Future<XFile?> _openImageEditor(XFile file) async {
    final editedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AdvancedImageEditorPage(imagePath: file.path),
      ),
    );
    if (editedBytes == null) return null;

    final newPath =
        '${Directory.systemTemp.path}/halo_edit_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final editedFile = File(newPath);
    await editedFile.writeAsBytes(editedBytes, flush: true);

    // Track for cleanup AFTER confirming write succeeded
    _tempFilePaths.add(newPath);

    return XFile(newPath);
  }

  Future<void> _pickVideo() async {
    if (_media.length >= _maxMediaItems) {
      _showSnack('Maximum $_maxMediaItems media items allowed.');
      return;
    }

    // STEP 1: Pick video
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );

    if (file == null) return;

    // STEP 2: Open edit screen
    final edited = await Navigator.push<VideoQuickEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoQuickEditPage(file: File(file.path)),
      ),
    );

    // ✅ Important null check
    if (edited == null || !mounted) return;

    if (!await _ensureVideoAllowed(edited.file)) return;

    // STEP 3: Open thumbnail picker (AFTER edited)
    final thumbBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoThumbnailPicker(videoPath: edited.file.path),
      ),
    );

    // STEP 4: Save media
    setState(() {
      _media.add(
        MediaItem(
          file: XFile(edited.file.path),
          type: MediaType.video,
          videoCoverBytes: thumbBytes ?? edited.coverBytes,
          trimStartMs: edited.trimStartMs,
          trimEndMs: edited.trimEndMs,
        ),
      );
    });
  }

  // ── Open full-screen camera ───────────────────────────────────────────────
  Future<void> _openCamera() async {
    if (_cameraPermissionDenied) return;
    if (_cameras == null || _cameras!.isEmpty) {
      await _initCamera();
    }
    if (_cameras == null || _cameras!.isEmpty) {
      _showSnack('Camera not available on this device.');
      return;
    }
    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenCamera(cameras: _cameras!),
      ),
    );
    if (result == null) return;
    final isVideo = result.path.endsWith('.mp4');
    if (isVideo) {
      final edited = await Navigator.push<VideoQuickEditResult>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoQuickEditPage(file: File(result.path)),
        ),
      );
      if (edited == null || !mounted) return;
      if (!await _ensureVideoAllowed(edited.file)) return;
      setState(() => _media.add(
            MediaItem(
              file: XFile(edited.file.path),
              type: MediaType.video,
              videoCoverBytes: edited.coverBytes,
              trimStartMs: edited.trimStartMs,
              trimEndMs: edited.trimEndMs,
            ),
          ));
    } else {
      setState(() =>
          _media.add(MediaItem(file: result, type: MediaType.image)));
    }
  }

  Future<void> _openLocationPicker() async {
    final outcome = await LocationPickerSheet.show(
      context,
      initial: _selectedPlace,
    );
    if (!mounted) return;
    switch (outcome) {
      case LocationPickerCleared():
        setState(() => _selectedPlace = null);
      case LocationPickerSelected(:final place) when place.isValid:
        setState(() => _selectedPlace = place);
      case LocationPickerDismissed():
      case LocationPickerSelected():
        break;
    }
  }

  Widget _buildLocationSection(TextTheme tt) {
    final place = _selectedPlace;
    final hasPlace = place != null && place.isValid;

    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _openLocationPicker,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                hasPlace ? Icons.location_on_rounded : Icons.location_on_outlined,
                color: kSecondaryColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPlace ? place.name : 'Add a location…',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            hasPlace ? FontWeight.w600 : FontWeight.w500,
                        color: hasPlace ? _kTextPrimary : _kTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasPlace && place.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.address,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _kTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (!hasPlace) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Search cafés, venues, and places',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _kTextSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasPlace)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: Colors.grey.shade600),
                  onPressed: () => setState(() => _selectedPlace = null),
                  tooltip: 'Remove location',
                )
              else
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ── Remove media ──────────────────────────────────────────────────────────
  void _removeMedia(int index) {
    final item = _media[index];
    item.videoController?.dispose();

    // Clean up temp file if it was editor-generated
    if (_tempFilePaths.contains(item.file.path)) {
      try {
        final f = File(item.file.path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      _tempFilePaths.remove(item.file.path);
    }

    setState(() => _media.removeAt(index));
  }

  Future<void> _editImageAt(int index) async {
    final item = _media[index];
    if (item.isVideo) {
      _showSnack('Editing is currently available for images only.');
      return;
    }

    final oldPath     = item.file.path;
    final wasTempFile = _tempFilePaths.contains(oldPath);

    final edited = await _openImageEditor(item.file);
    if (edited == null || !mounted) return;

    // Delete old temp file after successful re-edit
    if (wasTempFile) {
      try {
        final old = File(oldPath);
        if (old.existsSync()) old.deleteSync();
      } catch (_) {}
      _tempFilePaths.remove(oldPath);
    }

    setState(() {
      _media[index] = MediaItem(file: edited, type: MediaType.image);
    });
  }

  // ── Reorder media ─────────────────────────────────────────────────────────
  void _reorderMedia(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _media.removeAt(oldIndex);
      _media.insert(newIndex, item);
    });
  }

  // ── @mention logic ────────────────────────────────────────────────────────
  void _onCaptionChanged(String value) {
    setState(() {});
    final cursor = _captionCtrl.selection.baseOffset;
    if (cursor <= 0 || cursor > value.length) { _hideMentions(); return; }
    final before = value.substring(0, cursor);
    final atIdx  = before.lastIndexOf('@');
    if (atIdx == -1) { _hideMentions(); return; }
    if (atIdx > 0 && !RegExp(r'\s').hasMatch(before[atIdx - 1])) {
      _hideMentions();
      return;
    }
    final query = before.substring(atIdx + 1);
    if (query.length < 2) { _hideMentions(); return; }
    _fetchMentions(query.toLowerCase());
  }

  void _hideMentions() {
    if (_showMentions || _mentionSuggestions.isNotEmpty) {
      setState(() {
        _showMentions       = false;
        _mentionSuggestions = [];
      });
    }
  }

  Future<void> _fetchMentions(String q) async {
    final id = ++_mentionReqId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower',
          isGreaterThanOrEqualTo: q, isLessThanOrEqualTo: '$q\uf8ff')
          .limit(5)
          .get();
      if (!mounted || id != _mentionReqId) return;
      final results =
      snap.docs.map((d) => d.data()..['id'] = d.id).toList();
      setState(() {
        _mentionSuggestions = results;
        _showMentions       = results.isNotEmpty;
      });
    } catch (_) {
      if (!mounted || id != _mentionReqId) return;
      setState(() {
        _mentionSuggestions = [];
        _showMentions       = false;
      });
    }
  }

  void _insertMention(String username) {
    final text   = _captionCtrl.text;
    final cursor = _captionCtrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;
    final before        = text.substring(0, cursor);
    final atIdx         = before.lastIndexOf('@');
    if (atIdx == -1) return;
    final usernameLower = username.toLowerCase();
    final newText =
        '${text.substring(0, atIdx + 1)}$usernameLower ${text.substring(cursor)}';
    final newPos = atIdx + 1 + usernameLower.length + 1;
    _captionCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newPos));
    setState(() {
      _mentionSuggestions = [];
      _showMentions       = false;
    });
  }

  List<String> _extractMentions(String caption) {
    final set = <String>{};
    for (final m in RegExp(r'@(\w+)').allMatches(caption)) {
      final u = m.group(1);
      if (u != null && u.isNotEmpty) set.add(u.toLowerCase());
    }
    return set.toList();
  }

  // ── Navigate to Preview ───────────────────────────────────────────────────
  void _openPreview() {
    if (_media.isEmpty) {
      _showSnack('Add at least one photo or video first.');
      return;
    }
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty) {
      _showSnack('Please enter a caption before previewing.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostPreviewPage(
          media:    _media,
          caption:  caption,
          location: _selectedPlace?.displayLabel ?? '',
          onPost:   _submitPost,
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitPost() async {
    if (_media.isEmpty) { _showSnack('Add at least one photo or video.'); return; }

    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty) { _showSnack('Please enter a caption.'); return; }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) { _showSnack('Please sign in to post.'); return; }

    setState(() {
      _isUploading      = true;
      _uploadProgress   = 0;
      _currentUploadIdx = 0;
    });

    try {
      final postId    = FirebaseFirestore.instance.collection('posts').doc().id;
      final mediaList = <Map<String, dynamic>>[];
      String firstThumbUrl = '';
      String legacyFirstImageUrl = '';
      String legacyFirstVideoUrl = '';

      for (int i = 0; i < _media.length; i++) {
        final item = _media[i];

        setState(() {
          _currentUploadIdx = i + 1;
          _uploadStatusMsg  =
          'Uploading ${item.isVideo ? "video" : "photo"} ${i + 1} of ${_media.length}…';
        });

        Map<String, dynamic> uploaded;
        if (item.isVideo) {
          uploaded = await _uploadService.uploadVideoWithThumbnail(
            videoFile: File(item.file.path),
            postId: postId,
            index: i,
            thumbnailBytes: item.videoCoverBytes,
            trimStartMs: item.trimStartMs,
            trimEndMs: item.trimEndMs,
          );
          if (legacyFirstVideoUrl.isEmpty) {
            legacyFirstVideoUrl = (uploaded['videoUrl'] ?? '').toString();
          }
          if (firstThumbUrl.isEmpty) {
            firstThumbUrl =
                (uploaded['thumbnail'] ?? uploaded['thumbnailUrl'] ?? '')
                    .toString()
                    .trim();
          }
        } else {
          uploaded = await _uploadService.uploadAdaptivePostImage(
            imageFile: File(item.file.path),
            postId: postId,
            index: i,
          );
          if (legacyFirstImageUrl.isEmpty) {
            legacyFirstImageUrl = (uploaded['medium'] ?? uploaded['url'] ?? '')
                .toString()
                .trim();
          }
          if (firstThumbUrl.isEmpty) {
            firstThumbUrl = (uploaded['thumb'] ??
                    uploaded['medium'] ??
                    uploaded['full'] ??
                    uploaded['url'] ??
                    '')
                .toString()
                .trim();
          }
        }
        mediaList.add(uploaded);

        if (mounted) {
          setState(() => _uploadProgress = (i + 1) / _media.length);
        }
      }

      setState(() {
        _uploadStatusMsg = 'Saving post…';
        _uploadProgress  = 1;
      });

      final hasVideo = mediaList.any((m) => (m['type'] ?? '') == 'video');

      final placeFields = _selectedPlace?.isValid == true
          ? _selectedPlace!.toFirestore()
          : const <String, dynamic>{'location': ''};

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .set({
        'userId'   : userId,
        'media'    : mediaList,
        'images'   : mediaList
            .where((m) => m['type'] == 'image')
            .map<String>((m) => m['url'] as String)
            .toList(),
        'caption'  : caption,
        ...placeFields,
        'mentions' : _extractMentions(caption),
        'thumbnailUrl': firstThumbUrl,
        if (legacyFirstImageUrl.isNotEmpty) 'imageUrl': legacyFirstImageUrl,
        if (legacyFirstVideoUrl.isNotEmpty) 'videoUrl': legacyFirstVideoUrl,
        'hasMedia': mediaList.isNotEmpty,
        'isVideo': hasVideo,
        'processing': hasVideo,
        'processed': !hasVideo,
        'likeCount': 0,
        'commentCount': 0,
        // Keep createdAt always non-null for feed queries.
        'createdAt': Timestamp.now(),
        'createdAtServer': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'postsCount': FieldValue.increment(1)});

      if (!mounted) return;
      _showSnack('Post shared successfully!');
      _reset();
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on VideoUploadRejectedException catch (e) {
      if (!mounted) return;
      _showSnack(e.rejection.userMessage);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _reset() {
    for (final m in _media) m.videoController?.dispose();
    _cleanupTempFiles(List.from(_tempFilePaths));
    setState(() {
      _media.clear();
      _tempFilePaths.clear();
      _captionCtrl.clear();
      _selectedPlace = null;
      _mentionSuggestions.clear();
      _showMentions   = false;
      _uploadProgress = 0;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Reject unsupported videos before thumbnail picker / upload.
  Future<bool> _ensureVideoAllowed(File videoFile) async {
    final rejection = await VideoUploadPolicy.validateFile(videoFile);
    if (rejection == null) return true;
    _showSnack(rejection.userMessage);
    return false;
  }

  Future<void> _runPostsBackfill() async {
    if (_isUploading || _isMigratingPosts) return;
    final shouldRun = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backfill posts?'),
        content: const Text(
          'This will update existing posts with thumbnailUrl, likeCount, and commentCount. '
          'Run this once and keep the app open until it finishes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Run'),
          ),
        ],
      ),
    );

    if (shouldRun != true || !mounted) return;
    setState(() => _isMigratingPosts = true);

    try {
      const batchSize = 25;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      int scanned = 0;
      int updated = 0;

      while (true) {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('posts')
            .orderBy(FieldPath.documentId)
            .limit(batchSize);
        if (cursor != null) query = query.startAfterDocument(cursor);

        final page = await query.get();
        if (page.docs.isEmpty) break;
        cursor = page.docs.last;

        for (final doc in page.docs) {
          scanned++;
          final data = doc.data();
          final postRef = doc.reference;

          final media = data['media'];
          final images = data['images'];
          final fallbackImageUrl = (data['imageUrl'] ?? '').toString().trim();
          final existingThumb = (data['thumbnailUrl'] ?? '').toString().trim();

          String computedThumb = existingThumb;
          if (computedThumb.isEmpty) {
            if (media is List) {
              for (final item in media) {
                if (item is Map) {
                  final type = (item['type'] ?? '').toString().toLowerCase();
                  final url = (item['url'] ?? '').toString().trim();
                  if (type == 'image' && url.isNotEmpty) {
                    computedThumb = url;
                    break;
                  }
                }
              }
            }
            if (computedThumb.isEmpty && images is List && images.isNotEmpty) {
              computedThumb = images.first.toString().trim();
            }
            if (computedThumb.isEmpty) computedThumb = fallbackImageUrl;
          }

          final likeAgg = await postRef.collection('likes').count().get();
          final commentAgg = await postRef.collection('comments').count().get();
          final likeCount = likeAgg.count;
          final commentCount = commentAgg.count;

          final oldLike = data['likeCount'];
          final oldComment = data['commentCount'];
          final oldLikeInt = oldLike is int ? oldLike : int.tryParse('$oldLike') ?? -1;
          final oldCommentInt =
              oldComment is int ? oldComment : int.tryParse('$oldComment') ?? -1;

          if (existingThumb != computedThumb ||
              oldLikeInt != likeCount ||
              oldCommentInt != commentCount) {
            await postRef.update({
              'thumbnailUrl': computedThumb,
              'likeCount': likeCount,
              'commentCount': commentCount,
            });
            updated++;
          }
        }
      }

      if (!mounted) return;
      _showSnack('Backfill done. Scanned $scanned posts, updated $updated.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Backfill failed: $e');
    } finally {
      if (mounted) setState(() => _isMigratingPosts = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final tt = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return Theme(
      data: Theme.of(context).copyWith(textTheme: tt),
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildBody(tt),
            if (_isUploading) _buildUploadOverlay(tt),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    backgroundColor: _kCardBg,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.close_rounded, color: _kTextPrimary, size: 26),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Text(
      'New Post',
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _kTextPrimary,
        letterSpacing: -0.2,
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _kBorder),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TextButton(
          onPressed: (_isUploading || _isMigratingPosts) ? null : _openPreview,
          style: TextButton.styleFrom(
            foregroundColor: kSecondaryColor,
            backgroundColor: _kSurface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.35)),
            ),
          ),
          child: Text(
            'Preview',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, color: _kTextPrimary, size: 22),
        onSelected: (value) {
          if (value == 'backfill') _runPostsBackfill();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'backfill',
            enabled: !_isUploading && !_isMigratingPosts,
            child: Text(
              'Backfill post counts',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(width: 8),
    ],
  );

  Widget _buildBody(TextTheme tt) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share photos and videos with your community',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: _kTextSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          tt: tt,
          icon: Icons.perm_media_outlined,
          title: 'Media',
          subtitle: 'Up to $_maxMediaItems items · drag to reorder',
          child: Column(
            children: [
              _buildMediaRow(),
              const SizedBox(height: 14),
              _buildMediaGrid(tt),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          tt: tt,
          icon: Icons.location_on_outlined,
          title: 'Location',
          subtitle: 'Optional · tap to search places',
          child: _buildLocationSection(tt),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          tt: tt,
          icon: Icons.edit_outlined,
          title: 'Caption',
          subtitle: 'Use @username to mention someone',
          child: Column(
            children: [
              _buildCaptionField(tt),
              if (_showMentions) _buildMentionList(tt),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPostButton(tt),
      ],
    ),
  );

  Widget _sectionCard({
    required TextTheme tt,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title, tt, subtitle: subtitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String label,
    TextTheme tt, {
    String? subtitle,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kSecondaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  // ── Media picker row ──────────────────────────────────────────────────────
  Widget _buildMediaRow() => Row(children: [
    Expanded(
      child: _mediaTileWidget(
        Icons.photo_library_rounded,
        'Gallery',
        _pickImages,
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: _cameraPermissionDenied
          ? Tooltip(
              message: 'Camera permission denied. Enable it in Settings.',
              child: _mediaTileWidget(
                Icons.camera_alt_rounded,
                'Camera',
                null,
              ),
            )
          : _mediaTileWidget(
              Icons.camera_alt_rounded,
              'Camera',
              _openCamera,
              loading: _cameraInitializing,
            ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Tooltip(
        message: 'Supported: ${VideoUploadLimits.supportedSummary}',
        child: _mediaTileWidget(
          Icons.videocam_rounded,
          'Video',
          _pickVideo,
        ),
      ),
    ),
  ]);

  Widget _mediaTileWidget(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool loading = false,
  }) {
    final disabled = onTap == null;
    const iconColor = kSecondaryColor;
    final circleBg = kPrimaryColor.withValues(alpha: 0.18);
    final tileBorder = kPrimaryColor.withValues(alpha: 0.28);
    final showActive = !disabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: kPrimaryColor.withValues(alpha: 0.12),
        highlightColor: kPrimaryColor.withValues(alpha: 0.06),
        child: Ink(
          height: 88,
          decoration: BoxDecoration(
            color: showActive ? _kCardBg : _kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: showActive ? tileBorder : _kBorder,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: showActive ? circleBg : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kSecondaryColor.withValues(alpha: 0.85),
                        ),
                      )
                    : Icon(
                        icon,
                        color: showActive ? iconColor : Colors.grey.shade400,
                        size: 22,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: showActive ? _kTextPrimary : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Media grid ────────────────────────────────────────────────────────────
  Widget _buildMediaGrid(TextTheme tt) {
    if (_media.isEmpty) {
      return Container(
        height: 128,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.22), width: 1),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: kSecondaryColor.withValues(alpha: 0.75), size: 24),
            ),
            const SizedBox(height: 10),
            Text('No media selected',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kTextSecondary,
                )),
            const SizedBox(height: 4),
            Text('Choose from gallery, camera, or video',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                )),
          ]),
        ),
      );
    }

    // FIX: RepaintBoundary prevents thumbnail repaints from cascading
    return RepaintBoundary(
      child: SizedBox(
        height: 160,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          onReorder: _reorderMedia,
          itemCount: _media.length,
          itemBuilder: (ctx, index) {
            final item = _media[index];
            return ReorderableDragStartListener(
              key: ValueKey(item.file.path),
              index: index,
              child: _MediaThumbnail(
                item: item,
                index: index,
                isFirst: index == 0,
                onRemove: () => _removeMedia(index),
                onEdit: () => _editImageAt(index),
                onTap: () => _openMediaViewer(index),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openMediaViewer(int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                _MediaViewerPage(media: _media, initialIndex: index)));
  }

  // ── Caption field ─────────────────────────────────────────────────────────
  Widget _buildCaptionField(TextTheme tt) => _styledField(
    controller: _captionCtrl,
    hint: 'Share your thoughts… use @username to mention',
    maxLines: 5,
    tt: tt,
    focusNode: _captionFocusNode,
    onTap: () => _captionFocusNode.requestFocus(),
    onChanged: _onCaptionChanged,
    showBorder: false,
  );

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    required int maxLines,
    required TextTheme tt,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    bool showBorder = true,
  }) {
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    final neutralBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.22), width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kSecondaryColor, width: 1.5),
    );

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: showBorder ? null : Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        showCursor: true,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: GoogleFonts.poppins(fontSize: 14, color: _kTextPrimary),
        cursorColor: kSecondaryColor,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: _kTextSecondary, fontSize: 14),
          prefixIcon: icon != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: kSecondaryColor, size: 20),
                )
              : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _kSurface,
          border: showBorder ? neutralBorder : fieldBorder,
          enabledBorder: showBorder ? neutralBorder : fieldBorder,
          focusedBorder: showBorder ? focusedBorder : fieldBorder,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: icon != null ? 14 : 16,
          ),
        ),
      ),
    );
  }

  // ── @mention list ─────────────────────────────────────────────────────────
  Widget _buildMentionList(TextTheme tt) => Container(
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 1),
    ),
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mentionSuggestions.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (_, i) {
        final u = _mentionSuggestions[i];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: u['photoUrl'] != null
                ? NetworkImage(u['photoUrl'] as String) as ImageProvider
                : const AssetImage('assets/images/Profile.png'),
          ),
          title: Text(
            '@${u['username'] ?? ''}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _kTextPrimary,
            ),
          ),
          subtitle: u['fullname'] != null
              ? Text(
                  u['fullname'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _kTextSecondary,
                  ),
                )
              : null,
          onTap: () => _insertMention(u['username'] as String? ?? ''),
        );
      },
    ),
  );

  // ── Post button ───────────────────────────────────────────────────────────
  Widget _buildPostButton(TextTheme tt) => SizedBox(
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSecondaryColor, kPrimaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kSecondaryColor.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isUploading ? null : _submitPost,
        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
        label: Text(
          'Share Post',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: Colors.white,
        ),
      ),
    ),
  );

  // ── Upload overlay ────────────────────────────────────────────────────────
  Widget _buildUploadOverlay(TextTheme tt) => Positioned.fill(
    child: Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 5,
                  backgroundColor: const Color(0xFFEEF0F4),
                  valueColor: const AlwaysStoppedAnimation(kSecondaryColor),
                ),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: kSecondaryColor,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Text(
              'Uploading your post',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _uploadStatusMsg,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _kTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_media.length, (i) {
                final done = i < _currentUploadIdx;
                final active = i == _currentUploadIdx - 1 && !done;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done
                        ? kSecondaryColor
                        : (active ? kPrimaryColor : const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
//  _MediaThumbnail
// ══════════════════════════════════════════════════════════════════════════
class _MediaThumbnail extends StatelessWidget {
  final MediaItem item;
  final int index;
  final bool isFirst;
  final VoidCallback onRemove;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _MediaThumbnail({
    required this.item,
    required this.index,
    required this.isFirst,
    required this.onRemove,
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFirst ? 200 : 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: isFirst
              ? Border.all(color: kSecondaryColor, width: 2)
              : Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isFirst ? 12 : 13),
          child: Stack(fit: StackFit.expand, children: [
            item.isVideo
                ? Container(
              color: Colors.black87,
              child: const Center(
                child: Icon(Icons.videocam_rounded,
                    color: Colors.white70, size: 34),
              ),
            )
                : Image.file(
              File(item.file.path),
              fit: BoxFit.cover,
              // FIX: reduced from 600 to 300 — thumbnails are small,
              // 300px decode width is more than enough and cuts memory ~75%
              cacheWidth: 300,
              cacheHeight: 300,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
            ),

            if (item.isVideo)
              const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 40)),

            if (isFirst)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cover',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: item.isVideo ? onTap : onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.isVideo
                        ? Icons.open_in_full_rounded
                        : Icons.tune_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),

            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade800,
                    size: 14,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _MediaViewerPage
// ══════════════════════════════════════════════════════════════════════════
class _MediaViewerPage extends StatefulWidget {
  final List<MediaItem> media;
  final int initialIndex;
  const _MediaViewerPage(
      {required this.media, required this.initialIndex});

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current  = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    // FIX: do NOT dispose or pause the parent's video controllers here.
    // The parent _AddPostPageState owns those controllers.
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_current + 1} / ${widget.media.length}',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final item = widget.media[i];
          if (item.isVideo) {
            // FIX: create a local controller for the viewer — never reuse parent's
            return _VideoViewerItem(filePath: item.file.path);
          }
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                File(item.file.path),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildDots(),
    );
  }

  Widget _buildDots() => Container(
    height: 40,
    color: Colors.black,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.media.length,
            (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _current ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _current ? kPrimaryColor : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}

// ── Isolated video viewer widget (owns its own controller) ─────────────────
class _VideoViewerItem extends StatefulWidget {
  final String filePath;
  const _VideoViewerItem({required this.filePath});

  @override
  State<_VideoViewerItem> createState() => _VideoViewerItemState();
}

class _VideoViewerItemState extends State<_VideoViewerItem> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.filePath));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _ctrl.play();
        _ctrl.setLooping(true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryColor));
    }
    return GestureDetector(
      onTap: () => setState(() {
        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
      }),
      child: Center(
        child: AspectRatio(
          aspectRatio: _ctrl.value.aspectRatio,
          child: VideoPlayer(_ctrl),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _PostPreviewPage
// ══════════════════════════════════════════════════════════════════════════
class _PostPreviewPage extends StatefulWidget {
  final List<MediaItem> media;
  final String caption;
  final String location;
  final Future<void> Function() onPost;

  const _PostPreviewPage({
    required this.media,
    required this.caption,
    required this.location,
    required this.onPost,
  });

  @override
  State<_PostPreviewPage> createState() => _PostPreviewPageState();
}

class _PostPreviewPageState extends State<_PostPreviewPage> {
  int  _currentIndex    = 0;
  bool _isPosting       = false;
  bool _isMuted         = false;
  bool _captionExpanded = false;

  // FIX: own independent VideoPlayerControllers — never share with parent
  late List<VideoPlayerController?> _videoControllers;
  late final PageController _pageCtrl;

  VideoPlayerController? get _activeVideo =>
      _videoControllers.isNotEmpty
          ? _videoControllers[_currentIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _pageCtrl         = PageController();
    _videoControllers = List.filled(widget.media.length, null);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final ctrl in _videoControllers) {
      ctrl?.dispose();
    }
    super.dispose();
  }

  void _playCurrentVideo() {
    final ctrl = _activeVideo;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    ctrl.setVolume(_isMuted ? 0 : 1);
    ctrl.setLooping(true);
    ctrl.play();
  }

  void _disposeVideo(int index) {
    if (index < _videoControllers.length) {
      _videoControllers[index]?.pause();
      _videoControllers[index]?.dispose();
      _videoControllers[index] = null;
    }
  }

  void _onPageChanged(int i) {
    _disposeVideo(_currentIndex);
    setState(() => _currentIndex = i);
    _playCurrentVideo();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _activeVideo?.setVolume(_isMuted ? 0 : 1);
  }

  void _togglePlayPause() {
    final ctrl = _activeVideo;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
  }

  Future<void> _post() async {
    if (_isPosting) return;
    setState(() => _isPosting = true);
    try {
      await widget.onPost();
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt   = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Preview',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _isPosting
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                              Colors.white))),
                )
                    : TextButton(
                  onPressed: _post,
                  style: TextButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Share',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(children: [
                    const CircleAvatar(
                      backgroundImage:
                      AssetImage('assets/images/Profile.png'),
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You',
                                style: tt.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            if (widget.location.isNotEmpty)
                              Text(widget.location,
                                  style: tt.bodySmall?.copyWith(
                                      color: Colors.white70,
                                      fontSize: 11)),
                          ]),
                    ),
                    const Icon(Icons.more_horiz_rounded,
                        color: Colors.white),
                  ]),
                ),

                // Media pager
                if (widget.media.isNotEmpty)
                  SizedBox(
                    width: size.width,
                    height: size.width,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageCtrl,
                          itemCount: widget.media.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (_, i) {
                            final item = widget.media[i];
                            if (item.isVideo) {
                              _videoControllers[i] ??=
                                  VideoPlayerController.file(
                                      File(item.file.path));

                              final ctrl = _videoControllers[i]!;
                              if (!ctrl.value.isInitialized) {
                                ctrl.initialize().then((_) {
                                  if (mounted) setState(() {});
                                });
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              return _VideoPreviewItem(
                                controller: ctrl,
                                isCurrent: i == _currentIndex,
                                isMuted: _isMuted,
                                onTap: _togglePlayPause,
                              );
                            }
                            return Image.file(
                              File(item.file.path),
                              fit: BoxFit.cover,
                              width: size.width,
                              height: size.width,
                              cacheWidth: 1080,
                              filterQuality: FilterQuality.low,
                            );
                          },
                        ),

                        // Mute button (video only)
                        if (_currentIndex < _videoControllers.length &&
                            _videoControllers[_currentIndex] != null)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: Icon(
                                  _isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),

                        // Media counter badge
                        if (widget.media.length > 1)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius:
                                  BorderRadius.circular(20)),
                              child: Text(
                                  '${_currentIndex + 1}/${widget.media.length}',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Dot indicators
                if (widget.media.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.media.length,
                            (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentIndex ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _currentIndex
                                ? kPrimaryColor
                                : Colors.white30,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Action icons
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                        icon: const Icon(Icons.favorite_border_rounded,
                            color: Colors.white, size: 26),
                        onPressed: () {}),
                    IconButton(
                        icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white,
                            size: 24),
                        onPressed: () {}),
                    IconButton(
                        icon: const Icon(Icons.send_outlined,
                            color: Colors.white, size: 24),
                        onPressed: () {}),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.bookmark_border_rounded,
                            color: Colors.white, size: 26),
                        onPressed: () {}),
                  ]),
                ),

                // Caption
                if (widget.caption.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(
                            () => _captionExpanded = !_captionExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _buildRichCaption(
                          widget.caption, tt, _captionExpanded),
                    ),
                  ),

                // Preview notice
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text('This is a preview — not posted yet',
                        style: tt.bodySmall?.copyWith(
                            color: Colors.white38, fontSize: 11)),
                  ]),
                ),

                const SizedBox(height: 24),

                // Bottom action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text('Edit post',
                            style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                              color: Colors.white38, width: 1.5),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [kSecondaryColor, kPrimaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                                color: kSecondaryColor.withOpacity(0.50),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isPosting ? null : _post,
                          icon: _isPosting
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white)))
                              : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                          label: Text(
                              _isPosting ? 'Posting…' : 'Post',
                              style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.4)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(28)),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichCaption(
      String text, TextTheme tt, bool expanded) {
    final words = text.split(' ');
    final spans = words
        .map((w) => TextSpan(
      text: '$w ',
      style: (w.startsWith('@') && w.length > 1)
          ? tt.bodyMedium?.copyWith(
          color: kPrimaryColor, fontWeight: FontWeight.w700)
          : tt.bodyMedium?.copyWith(color: Colors.white),
    ))
        .toList();

    if (expanded || text.length < 120) {
      return Text.rich(TextSpan(children: spans));
    }

    final short      = text.substring(0, 100);
    final shortWords = short.split(' ');
    final shortSpans = shortWords
        .map((w) => TextSpan(
      text: '$w ',
      style: (w.startsWith('@') && w.length > 1)
          ? tt.bodyMedium?.copyWith(
          color: kPrimaryColor, fontWeight: FontWeight.w700)
          : tt.bodyMedium?.copyWith(color: Colors.white),
    ))
        .toList();

    return Text.rich(TextSpan(children: [
      ...shortSpans,
      TextSpan(
        text: '… more',
        style: tt.bodyMedium?.copyWith(
            color: Colors.white54, fontWeight: FontWeight.w600),
      ),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _VideoPreviewItem — receives controller directly, owns nothing
// ══════════════════════════════════════════════════════════════════════════
class _VideoPreviewItem extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool isCurrent;
  final bool isMuted;
  final VoidCallback onTap;

  const _VideoPreviewItem({
    required this.controller,
    required this.isCurrent,
    required this.isMuted,
    required this.onTap,
  });

  @override
  State<_VideoPreviewItem> createState() => _VideoPreviewItemState();
}

class _VideoPreviewItemState extends State<_VideoPreviewItem> {
  VideoPlayerController? get _ctrl => widget.controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl?.addListener(_onVideoUpdate);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // Re-attach listener when controller instance changes
  @override
  void didUpdateWidget(_VideoPreviewItem old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onVideoUpdate);
      widget.controller?.addListener(_onVideoUpdate);
    }
  }

  @override
  void dispose() {
    // FIX: remove listener only — do NOT dispose (owner disposes it)
    _ctrl?.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _onTap() {
    widget.onTap();
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl    = _ctrl;
    final isReady = ctrl != null && ctrl.value.isInitialized;

    if (!isReady) {
      return Container(
        color: Colors.black,
        child: const Center(
            child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final duration  = ctrl.value.duration;
    final position  = ctrl.value.position;
    final progress  = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        : 0.0;
    final isPlaying = ctrl.value.isPlaying;

    return GestureDetector(
      onTap: _onTap,
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.size.width,
            height: ctrl.value.size.height,
            child: VideoPlayer(ctrl),
          ),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),

        // Play/pause overlay
        AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Colors.black45, shape: BoxShape.circle),
              child: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),

        // Seek bar + timestamps
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: kPrimaryColor,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: kPrimaryColor.withOpacity(0.3),
                ),
                child: Slider(
                  value: progress.toDouble(),
                  onChanged: (v) {
                    final seekTo = Duration(
                        milliseconds:
                        (v * duration.inMilliseconds).toInt());
                    ctrl.seekTo(seekTo);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  Text(_formatDuration(position),
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text(_formatDuration(duration),
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _AdvancedImageEditorPage — with output resolution constraint
// ══════════════════════════════════════════════════════════════════════════
class _AdvancedImageEditorPage extends StatelessWidget {
  final String imagePath;
  const _AdvancedImageEditorPage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ProImageEditor.file(
        File(imagePath),
        configs: ProImageEditorConfigs(
          // FIX: correct parameter name is 'imageGeneration', not 'imageGenerationConfigs'
          imageGeneration: const ImageGenerationConfigs(
            outputFormat: OutputFormat.jpg,
            maxOutputSize: Size(1280, 1280),
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            if (!context.mounted) return;
            Navigator.pop(context, bytes);
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _FullScreenCamera
// ══════════════════════════════════════════════════════════════════════════
class _FullScreenCamera extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _FullScreenCamera({required this.cameras});
  @override
  State<_FullScreenCamera> createState() => _FullScreenCameraState();
}

class _FullScreenCameraState extends State<_FullScreenCamera> {
  late CameraController _ctrl;
  int  _camIdx      = 0;
  bool _ready       = false;
  bool _recording   = false;
  bool _isVideo     = false;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _initCtrl(0);
  }

  Future<void> _initCtrl(int idx) async {
    setState(() { _ready = false; _isSwitching = true; });
    final ctrl = CameraController(
        widget.cameras[idx], ResolutionPreset.high, enableAudio: true);
    await ctrl.initialize();
    if (!mounted) { ctrl.dispose(); return; }
    _ctrl = ctrl;
    setState(() { _camIdx = idx; _ready = true; _isSwitching = false; });
  }

  // Await dispose before reinitialising to prevent use-after-dispose
  Future<void> _flipCamera() async {
    if (_isSwitching) return;
    final next = (_camIdx + 1) % widget.cameras.length;
    final old  = _ctrl;
    await _initCtrl(next);
    await old.dispose();
  }

  Future<void> _capture() async {
    if (!_ready || _isSwitching) return;
    if (_isVideo) {
      if (_recording) {
        final file = await _ctrl.stopVideoRecording();
        if (!mounted) return;
        Navigator.pop(context, file);
      } else {
        await _ctrl.startVideoRecording();
        setState(() => _recording = true);
      }
    } else {
      final photo = await _ctrl.takePicture();
      if (!mounted) return;
      Navigator.pop(context, photo);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          if (_ready) Positioned.fill(child: CameraPreview(_ctrl)),
          if (!_ready)
            const Center(
                child: CircularProgressIndicator(color: kPrimaryColor)),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent
                  ],
                ),
              ),
              child: Row(children: [
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 28)),
                const Spacer(),
                if (widget.cameras.length > 1)
                  GestureDetector(
                    onTap: _isSwitching ? null : _flipCamera,
                    child: Icon(Icons.flip_camera_ios_rounded,
                        color: _isSwitching
                            ? Colors.white38
                            : Colors.white,
                        size: 28),
                  ),
              ]),
            ),
          ),

          // Bottom bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 32, top: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent
                  ],
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ModeButton(
                          label: 'Photo',
                          selected: !_isVideo,
                          onTap: () =>
                              setState(() => _isVideo = false)),
                      const SizedBox(width: 24),
                      _ModeButton(
                          label: 'Video',
                          selected: _isVideo,
                          onTap: () =>
                              setState(() => _isVideo = true)),
                    ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _isSwitching ? null : _capture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 4),
                      color: _isSwitching
                          ? Colors.grey.withOpacity(0.5)
                          : (_recording
                          ? Colors.red
                          : Colors.white.withOpacity(0.9)),
                    ),
                    child: _recording
                        ? const Icon(Icons.stop_rounded,
                        color: Colors.white, size: 32)
                        : Icon(
                        _isVideo
                            ? Icons.videocam_rounded
                            : Icons.camera_alt_rounded,
                        color: Colors.black87,
                        size: 32),
                  ),
                ),
              ]),
            ),
          ),

          // REC badge
          if (_recording)
            Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('REC',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Text(label,
          style: GoogleFonts.poppins(
            color: selected ? Colors.white : Colors.white60,
            fontWeight:
            selected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 14,
          )),
      const SizedBox(height: 4),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: selected ? 24 : 0,
        height: 2,
        decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(1)),
      ),
    ]),
  );
}


