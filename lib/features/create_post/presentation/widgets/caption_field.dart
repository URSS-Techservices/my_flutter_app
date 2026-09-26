import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';
import 'package:halo/features/create_post/presentation/mention_controller.dart';

/// Caption input. Only this widget rebuilds on keystroke — media grid, tag
/// selector, etc. are untouched — and only pushes a debounced mention search
/// (see [MentionController]) instead of one Firestore query per keystroke.
class CaptionField extends ConsumerWidget {
  final TextEditingController controller;

  const CaptionField({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Share your thoughts... Use @username to mention someone',
          hintStyle: const TextStyle(color: Colors.black54),
          alignLabelWithHint: true,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [kPrimaryColor.withValues(alpha: 0.2), kPrimaryColor.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.text_fields_rounded, color: kSecondaryColor, size: 20),
          ),
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
        onChanged: (value) {
          ref.read(addPostControllerProvider.notifier).setCaption(value);
          ref
              .read(mentionControllerProvider.notifier)
              .onCaptionChanged(value, controller.selection.baseOffset);
        },
      ),
    );
  }
}
