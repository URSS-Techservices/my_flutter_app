import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/Sections/Guru Section/guru_booking_section.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// "Book" from a guru profile. Shows the existing booking section from the
/// old guru page, with its data loaded through the profile repository.
class GuruBookingPage extends ConsumerWidget {
  const GuruBookingPage({
    super.key,
    required this.guruId,
    required this.guruName,
  });

  final String guruId;
  final String guruName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(guruBookingProvider(guruId));

    return Scaffold(
      backgroundColor: ProfileStyle.page,
      appBar: AppBar(
        backgroundColor: ProfileStyle.page,
        surfaceTintColor: ProfileStyle.page,
        title: Text(
          guruName.isEmpty ? 'Book a session' : 'Book with $guruName',
          style: ProfileStyle.name.copyWith(fontSize: 18),
        ),
      ),
      body: booking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(guruBookingProvider(guruId)),
            child: const Text('Could not load booking. Tap to retry'),
          ),
        ),
        data: (b) => SingleChildScrollView(
          child: GuruBookingSection(
            guruid: guruId,
            isOwnProfile: false,
            bookingSettings: b.settings,
            upcomingSessions: b.upcomingSessions,
            pastSessions: b.pastSessions,
          ),
        ),
      ),
    );
  }
}
