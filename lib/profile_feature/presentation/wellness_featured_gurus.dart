import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:halo/profile_feature/presentation/wellness_guru_picker_page.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

/// "Featured Gurus": guru accounts the wellness owner promotes on their
/// page. Tapping one opens that guru's profile. The owner gets "Manage".
class WellnessFeaturedGurus extends ConsumerWidget {
  const WellnessFeaturedGurus({super.key, required this.wellnessId});

  final String wellnessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(myUserIdProvider) == wellnessId;
    final gurus = ref.watch(featuredGurusProvider(wellnessId));

    void manage() => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WellnessGuruPickerPage(wellnessId: wellnessId),
        ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: 'Featured Gurus',
          onSeeAll: isOwner ? manage : null,
          actionLabel: 'Manage',
        ),
        gurus.when(
          loading: () => const SizedBox(height: 132),
          error: (_, __) => const ProfileEmptyMessage(
            icon: Icons.error_outline,
            text: 'Could not load gurus',
          ),
          data: (list) {
            if (list.isEmpty) {
              final empty = ProfileEmptyMessage(
                icon: Icons.groups_outlined,
                text: isOwner
                    ? 'Tap to feature gurus who train here'
                    : 'No featured gurus yet',
              );
              return isOwner
                  ? GestureDetector(onTap: manage, child: empty)
                  : empty;
            }
            return SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: ProfileStyle.sideGap),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _GuruCard(person: list[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GuruCard extends StatelessWidget {
  const _GuruCard({required this.person});

  final ProfilePerson person;

  static const _radius = 32.0;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: 104,
      child: Material(
        color: ProfileStyle.page,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ProfileStyle.divider),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DynamicProfilePage(profileUserId: person.id),
          )),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                CircleAvatar(
                  radius: _radius,
                  backgroundColor: ProfileStyle.surface,
                  backgroundImage: person.photoUrl.isEmpty
                      ? null
                      : CachedNetworkImageProvider(
                          person.photoUrl,
                          maxWidth: (_radius * 2 * dpr).round(),
                        ),
                  child: person.photoUrl.isEmpty
                      ? const Icon(Icons.person,
                          size: _radius, color: ProfileStyle.mutedText)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  person.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileStyle.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Guru',
                  maxLines: 1,
                  style: ProfileStyle.small.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
