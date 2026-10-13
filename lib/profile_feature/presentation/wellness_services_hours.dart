import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/domain/wellness_profile.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// "Services & Availability": facilities / services and opening hours the
/// owner filled in at signup. Read only for now.
class WellnessServicesHours extends ConsumerWidget {
  const WellnessServicesHours({super.key, required this.wellnessId});

  final String wellnessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wellness = ref.watch(wellnessProfileProvider(wellnessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(title: 'Services & Availability'),
        wellness.when(
          loading: () => const SizedBox(height: 72),
          error: (_, __) => const ProfileEmptyMessage(
            icon: Icons.error_outline,
            text: 'Could not load services',
          ),
          data: (w) => w == null || !w.hasServicesInfo
              ? const ProfileEmptyMessage(
                  icon: Icons.spa_outlined,
                  text: 'Services not added yet',
                )
              : _Content(wellness: w),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.wellness});

  final WellnessProfile wellness;

  @override
  Widget build(BuildContext context) {
    final hasHours =
        wellness.workingHours.isNotEmpty || wellness.availability.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wellness.services.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in wellness.services)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: ProfileStyle.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s,
                      style: ProfileStyle.small.copyWith(
                        color: ProfileStyle.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          if (wellness.services.isNotEmpty && hasHours)
            const SizedBox(height: 14),
          if (hasHours)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: ProfileStyle.divider),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          size: 18, color: ProfileStyle.action),
                      const SizedBox(width: 8),
                      Text('Opening hours',
                          style: ProfileStyle.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (wellness.workingHours.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(wellness.workingHours, style: ProfileStyle.body),
                  ],
                  for (final e in wellness.availability.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(e.key, style: ProfileStyle.small),
                          ),
                          Expanded(
                            child: Text(e.value, style: ProfileStyle.body),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
