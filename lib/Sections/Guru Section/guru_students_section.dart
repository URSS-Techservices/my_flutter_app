import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuruStudentsSection extends StatelessWidget {
  final String guruid;
  final bool isOwnProfile;
  final List<Map<String, dynamic>> students;

  const GuruStudentsSection({
    Key? key,
    required this.guruid,
    required this.isOwnProfile,
    required this.students,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Always show for own profile, or if there are students
    // Only hide if viewing someone else's profile AND they have no students
    if (!isOwnProfile && students.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Students & Progress',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (students.isEmpty)
            Text(
              'No students yet. When people book you, they will show here.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
            )
          else
            ...students.take(5).map((s) {
              final String name = s['name']?.toString() ?? 'Student';
              final String level = s['level']?.toString() ?? 'Beginner';
              final int progress = (s['progress'] ?? 0) as int;
              final String goal = s['goal']?.toString() ?? '';

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
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$level • $goal',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: (progress.clamp(0, 100)) / 100,
                              minHeight: 6,
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
