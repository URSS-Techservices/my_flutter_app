import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/create_post/domain/media_asset.dart';
import 'package:halo/features/create_post/domain/mention_parser.dart';
import 'package:halo/features/create_post/domain/post_draft_state.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';
import 'package:halo/features/create_post/presentation/mention_controller.dart';
import 'package:halo/features/create_post/presentation/widgets/caption_field.dart';
import 'package:halo/features/create_post/presentation/widgets/media_grid.dart';
import 'package:halo/features/create_post/presentation/widgets/media_picker_actions.dart';
import 'package:halo/features/create_post/presentation/widgets/media_quality_selector.dart';
import 'package:halo/features/create_post/presentation/widgets/mention_suggestions_list.dart';
import 'package:halo/features/create_post/presentation/widgets/post_button.dart';
import 'package:halo/features/create_post/presentation/widgets/post_preview_card.dart';
import 'package:halo/features/create_post/presentation/widgets/tag_selector.dart';
import 'package:halo/features/create_post/presentation/widgets/upload_progress.dart';
import 'package:halo/features/create_post/services/media_picker_service.dart';

class AddPostPage extends ConsumerStatefulWidget {
  const AddPostPage({super.key});

  @override
  ConsumerState<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends ConsumerState<AddPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final MediaPickerService _mediaPicker = MediaPickerService();

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _processAndAdd(MediaAsset asset) async {
    final error = await ref.read(addPostControllerProvider.notifier).processAndAddAsset(
      asset,
      resolveQuality: (a, originalBytes) =>
          showMediaQualitySelector(context, isVideo: a.isVideo, originalBytes: originalBytes),
    );
    if (error != null && mounted) HaloToast.show(error);
  }

  Future<void> _pickGallery() async {
    final assets = await _mediaPicker.pickImagesFromGallery();
    if (!mounted) return;
    for (final asset in assets) {
      await _processAndAdd(asset);
    }
  }

  Future<void> _pickCamera() async {
    final asset = await _mediaPicker.captureFromCamera(context);
    if (!mounted || asset == null) return;
    await _processAndAdd(asset);
  }

  Future<void> _pickVideo() async {
    final asset = await _mediaPicker.pickVideoFromGallery(context);
    if (!mounted || asset == null) return;
    await _processAndAdd(asset);
  }

  void _insertMention(String username) {
    final text = _captionController.text;
    final cursor = _captionController.selection.baseOffset;
    final safeCursor = cursor < 0 || cursor > text.length ? text.length : cursor;
    final before = text.substring(0, safeCursor);
    final at = before.lastIndexOf('@');
    if (at == -1) return;

    final newBefore = text.substring(0, at + 1);
    final after = text.substring(safeCursor);
    final insertedPrefix = '$newBefore$username ';
    final newText = '$insertedPrefix$after';

    _captionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertedPrefix.length),
    );
    ref.read(addPostControllerProvider.notifier).setCaption(newText);
    ref.read(mentionControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PostDraftState>(addPostControllerProvider, (previous, next) {
      final status = next.submitStatus;
      if (status is PostSubmitSuccess) {
        HaloToast.show('Post uploaded successfully!');
        _captionController.clear();
        _locationController.clear();
        ref.read(addPostControllerProvider.notifier).resetSubmitStatus();
        if (Navigator.canPop(context)) Navigator.pop(context);
      } else if (status is PostSubmitFailure) {
        HaloToast.show(status.message);
      }
    });

    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Create Post',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [kSecondaryColor, kPrimaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5EDFF), Color(0xFFE8E4FF), kLightBackground],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(blurRadius: 32, spreadRadius: -10, offset: const Offset(0, 18), color: Colors.black.withValues(alpha: 0.10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLocationField(),
                        const SizedBox(height: 24),
                        _sectionHeader(Icons.photo_library_rounded, 'Add Media'),
                        const SizedBox(height: 12),
                        MediaPickerActions(
                          onGallery: _pickGallery,
                          onCamera: _pickCamera,
                          onVideo: _pickVideo,
                        ),
                        const MediaGrid(),
                        const SizedBox(height: 24),
                        _sectionHeader(Icons.edit_note_rounded, 'Caption'),
                        const SizedBox(height: 12),
                        CaptionField(controller: _captionController),
                        MentionSuggestionsList(onSelect: _insertMention),
                        const SizedBox(height: 24),
                        _sectionHeader(Icons.tag_rounded, 'Tags / Interests'),
                        const SizedBox(height: 12),
                        const TagSelector(),
                        const SizedBox(height: 24),
                        const PostPreviewCard(),
                        const UploadProgress(),
                        const SizedBox(height: 24),
                        PostButton(
                          onPressed: () => ref
                              .read(addPostControllerProvider.notifier)
                              .submit(extractMentions(_captionController.text.trim())),
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

  Widget _sectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: kSecondaryColor, size: 20),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildLocationField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _locationController,
        style: const TextStyle(color: Colors.black),
        onChanged: (v) => ref.read(addPostControllerProvider.notifier).setLocation(v),
        decoration: InputDecoration(
          labelText: '📍 Location',
          hintText: 'Where are you?',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
