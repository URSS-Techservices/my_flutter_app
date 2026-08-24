import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';

class WellnessMembershipPlansSection extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final bool isOwnProfile;
  final VoidCallback? onAdd;
  final void Function(int index, Map<String, dynamic> plan)? onEdit;
  final void Function(int index)? onDelete;
  final void Function(Map<String, dynamic> plan)? onSubscribe;

  const WellnessMembershipPlansSection({
    super.key,
    required this.plans,
    required this.isOwnProfile,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onSubscribe,
  });

  static List<String> _features(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile && plans.isEmpty) return const SizedBox.shrink();
    if (plans.isEmpty) return const SizedBox.shrink();

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
                      color: ProfileLayout.lavender.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.card_membership, color: ProfileLayout.lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Membership Plans', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
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
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final features = _features(plan['features']);
              final isPopular = index == 1;
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPopular ? ProfileLayout.lavender.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPopular ? ProfileLayout.lavender : Colors.grey.shade300,
                    width: isPopular ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['name']?.toString() ?? 'Plan',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${plan['price'] ?? ''}/${plan['duration'] ?? ''}',
                      style: GoogleFonts.poppins(fontSize: 14, color: ProfileLayout.deepLavender),
                    ),
                    const SizedBox(height: 8),
                    ...features.take(3).map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $f', style: GoogleFonts.poppins(fontSize: 11)),
                      ),
                    ),
                    const Spacer(),
                    if (isOwnProfile)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: onEdit == null ? null : () => onEdit!(index, plan),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                            onPressed: onDelete == null ? null : () => onDelete!(index),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        onPressed: onSubscribe == null ? null : () => onSubscribe!(plan),
                        child: const Text('Subscribe'),
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
