import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessAwardsSection extends StatelessWidget {
  final List<Map<String, dynamic>> awards;
  final bool isOwnProfile;
  final VoidCallback? onAdd;

  const WellnessAwardsSection({
    super.key,
    required this.awards,
    required this.isOwnProfile,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && awards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.amber.shade50, Colors.amber.shade100]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Awards & Certifications', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                if (isOwnProfile && onAdd != null)
                  IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.amber.shade900), onPressed: onAdd),
              ],
            ),
            const SizedBox(height: 16),
            if (awards.isEmpty)
              Text(
                isOwnProfile ? 'Add your awards and certifications' : 'No awards listed',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              )
            else
              ...awards.map(
                (award) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.amber.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(award['name']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            Text(
                              '${award['issuer'] ?? ''} • ${award['year'] ?? ''}',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
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
}
