import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class GuruVideoTutorialsSection extends StatelessWidget {
  final List<Map<String, dynamic>> tutorials;
  final bool isOwnProfile;
  final VoidCallback? onAdd;
  final VoidCallback? onViewAll;
  final void Function(int index, Map<String, dynamic> tutorial)? onEdit;
  final void Function(int index)? onDelete;

  const GuruVideoTutorialsSection({
    super.key,
    required this.tutorials,
    required this.isOwnProfile,
    this.onAdd,
    this.onViewAll,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && tutorials.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.play_circle_filled, color: Colors.red.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Video Tutorials', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              if (isOwnProfile && onAdd != null)
                IconButton(icon: const Icon(Icons.add_circle_outline, color: ProfileLayout.lavender), onPressed: onAdd)
              else if (tutorials.isNotEmpty && onViewAll != null)
                TextButton(onPressed: onViewAll, child: const Text('View All')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tutorials.length,
            itemBuilder: (context, index) {
              final tutorial = tutorials[index];
              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12)),
                child: Stack(
                  children: [
                    Center(child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white.withValues(alpha: 0.8))),
                    if (isOwnProfile)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 16, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call(index, tutorial);
                            if (value == 'delete') onDelete?.call(index);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Text(
                        tutorial['title']?.toString() ?? '',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
}
