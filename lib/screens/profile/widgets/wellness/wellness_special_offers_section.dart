import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessSpecialOffersSection extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final bool isOwnProfile;
  final VoidCallback? onAdd;
  final void Function(int index, Map<String, dynamic> offer)? onEdit;
  final void Function(int index)? onDelete;
  final void Function(Map<String, dynamic> offer)? onViewDetails;

  const WellnessSpecialOffersSection({
    super.key,
    required this.offers,
    required this.isOwnProfile,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && offers.isEmpty) return const SizedBox.shrink();
    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Special Offers', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                if (isOwnProfile && onAdd != null)
                  IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.orange.shade900), onPressed: onAdd),
              ],
            ),
            const SizedBox(height: 16),
            ...offers.asMap().entries.map((entry) {
              final index = entry.key;
              final offer = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Text(
                      offer['discount']?.toString() ?? '',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer['title']?.toString() ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          Text('Valid until: ${offer['validUntil'] ?? ''}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (isOwnProfile)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') onEdit?.call(index, offer);
                          if (value == 'delete') onDelete?.call(index);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange.shade700),
                        onPressed: onViewDetails == null ? null : () => onViewDetails!(offer),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
