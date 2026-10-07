import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuruEarningsSection extends StatelessWidget {
  final String guruid;
  final bool isOwnProfile;
  final Map<String, dynamic> earningsSummary;
  final List<Map<String, dynamic>> recentEarnings;
  final VoidCallback? onViewPayoutDetails;

  const GuruEarningsSection({
    Key? key,
    required this.guruid,
    required this.isOwnProfile,
    required this.earningsSummary,
    required this.recentEarnings,
    this.onViewPayoutDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile) return const SizedBox.shrink();

    final String total =
    (earningsSummary['total'] ?? 0).toString();
    final String month =
    (earningsSummary['thisMonth'] ?? 0).toString();
    final String pending =
    (earningsSummary['pending'] ?? 0).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Overview',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _earningCard('Total', '₹$total'),
              _earningCard('This month', '₹$month'),
              _earningCard('Pending', '₹$pending'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recent earnings',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          if (recentEarnings.isEmpty)
            Text(
              'No earnings yet.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
            )
          else
            ...recentEarnings.take(5).map((e) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  e['label']?.toString() ?? 'Session',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  e['date']?.toString() ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                trailing: Text(
                  '₹${e['amount'] ?? 0}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewPayoutDetails ?? () {
                // Default: show payout details dialog
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Payout Details'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Earnings: ₹${earningsSummary['total'] ?? 0}'),
                        const SizedBox(height: 8),
                        Text('This Month: ₹${earningsSummary['thisMonth'] ?? 0}'),
                        const SizedBox(height: 8),
                        Text('Pending: ₹${earningsSummary['pending'] ?? 0}'),
                        const SizedBox(height: 16),
                        const Text(
                          'Full payout details and withdrawal options coming soon!',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('View payout details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
