import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuruClassesSection extends StatelessWidget {
  final String guruid;
  final bool isOwnProfile;
  final List<Map<String, dynamic>> classes;
  final List<String> specialties;
  final VoidCallback? onManage;

  const GuruClassesSection({
    Key? key,
    required this.guruid,
    required this.isOwnProfile,
    required this.classes,
    required this.specialties,
    this.onManage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Classes & Batches',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              if (isOwnProfile)
                TextButton(
                  onPressed: onManage ?? () {
                    // Default: show manage classes dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Manage Classes'),
                        content: const Text('Class management feature coming soon! You can create, edit, and manage your batches here.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Manage'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (specialties.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: specialties
                  .map((s) => Chip(
                label: Text(
                  s,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                  ),
                ),
              ))
                  .toList(),
            ),
          const SizedBox(height: 10),
          if (classes.isEmpty)
            Text(
              isOwnProfile
                  ? 'No active batches. Create your first batch!'
                  : 'No active batches right now.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
            )
          else
            ...classes.take(3).map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: const Icon(Icons.group, color: Colors.black87),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['name']?.toString() ?? 'Batch',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c['schedule']?.toString() ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c['enrolled'] ?? 0} enrolled • Max ${c['capacity'] ?? '-'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
