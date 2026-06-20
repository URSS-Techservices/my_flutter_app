import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

/// Horizontal team strip for wellness facility profiles.
class WellnessStaffSection extends StatelessWidget {
  final List<Map<String, dynamic>> staff;
  final bool isOwnProfile;
  final VoidCallback? onManage;

  const WellnessStaffSection({
    super.key,
    required this.staff,
    required this.isOwnProfile,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && staff.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Our Team',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isOwnProfile && onManage != null)
                TextButton(onPressed: onManage, child: const Text('Manage')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (staff.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Introduce your trainers and front-desk team.',
                  style: GoogleFonts.poppins(fontSize: 14, color: ProfileLayout.textSecondary),
                ),
                if (onManage != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add team members'),
                  ),
                ],
              ],
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: staff.length,
              itemBuilder: (context, index) {
                final member = staff[index];
                final name = member['name']?.toString() ?? 'Staff';
                final role = member['role']?.toString() ?? '';
                return Container(
                  width: 72,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: member['photoUrl'] != null
                            ? NetworkImage(member['photoUrl'].toString())
                            : null,
                        backgroundColor: ProfileLayout.chipBg,
                        child: member['photoUrl'] == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                style: GoogleFonts.poppins(
                                  color: ProfileLayout.deepLavender,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (role.isNotEmpty)
                        Text(
                          role,
                          style: GoogleFonts.poppins(fontSize: 10, color: ProfileLayout.textSecondary),
                          textAlign: TextAlign.center,
                          maxLines: 1,
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
