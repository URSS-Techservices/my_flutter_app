import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';

const kAvailablePostTags = [
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

class TagSelector extends ConsumerWidget {
  const TagSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTags = ref.watch(addPostControllerProvider.select((s) => s.tags));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kAvailablePostTags.map((tag) {
          final selected = selectedTags.contains(tag);
          return GestureDetector(
            onTap: () => ref.read(addPostControllerProvider.notifier).toggleTag(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: [kPrimaryColor.withValues(alpha: 0.25), kPrimaryColor.withValues(alpha: 0.15)])
                    : null,
                color: selected ? null : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? kPrimaryColor : Colors.grey.shade300, width: selected ? 2 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) Icon(Icons.check_circle_rounded, size: 16, color: kSecondaryColor),
                  if (selected) const SizedBox(width: 6),
                  Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: selected ? kSecondaryColor : Colors.black87,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
