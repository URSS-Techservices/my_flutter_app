import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class GuruSuccessStoriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  final bool isOwnProfile;
  final VoidCallback? onAdd;
  final void Function(int index, Map<String, dynamic> story)? onEdit;
  final void Function(int index)? onDelete;

  const GuruSuccessStoriesSection({
    super.key,
    required this.stories,
    required this.isOwnProfile,
    this.onAdd,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && stories.isEmpty) return const SizedBox.shrink();

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
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.celebration, color: Colors.green.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Success Stories', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              if (isOwnProfile && onAdd != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: ProfileLayout.lavender),
                  onPressed: onAdd,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              final story = stories[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.green.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(story['clientName']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              Text(story['achievement']?.toString() ?? '', style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                        if (isOwnProfile)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') onEdit?.call(index, story);
                              if (value == 'delete') onDelete?.call(index);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      story['testimonial']?.toString() ?? '',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      maxLines: 3,
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
}
