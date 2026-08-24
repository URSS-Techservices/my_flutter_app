import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/screens/profile/profile_theme.dart';
import 'package:halo/services/wellness_check_in_service.dart';

/// Lets visitors check in at a wellness facility (one per day).
class WellnessCheckInBanner extends StatelessWidget {
  final String? currentUserId;
  final String wellnessUserId;
  final String wellnessName;

  const WellnessCheckInBanner({
    super.key,
    required this.currentUserId,
    required this.wellnessUserId,
    required this.wellnessName,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null || currentUserId!.isEmpty || currentUserId == wellnessUserId) {
      return const SizedBox.shrink();
    }

    final service = WellnessCheckInService();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: StreamBuilder<bool>(
        stream: service.hasCheckedInTodayStream(
          aspirantId: currentUserId!,
          wellnessUserId: wellnessUserId,
        ),
        builder: (context, snapshot) {
          final checkedIn = snapshot.data ?? false;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ProfileLayout.deepLavender, ProfileLayout.lavender],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(checkedIn ? Icons.check_circle : Icons.location_on, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkedIn ? 'Checked in today' : 'Visiting today?',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        checkedIn ? 'Great job showing up!' : 'Check in to build your visit streak',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!checkedIn)
                  TextButton(
                    onPressed: () async {
                      final ok = await service.checkInToday(
                        aspirantId: currentUserId!,
                        wellnessUserId: wellnessUserId,
                        wellnessName: wellnessName,
                      );
                      Fluttertoast.showToast(
                        msg: ok ? 'Checked in at $wellnessName' : 'Already checked in today',
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ProfileLayout.deepLavender,
                    ),
                    child: const Text('Check in'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
