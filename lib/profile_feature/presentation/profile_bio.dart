import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:intl/intl.dart';

final _joinedFormat = DateFormat('MMM yyyy');

/// Bio text, location and join date.
class ProfileBio extends ConsumerWidget {
  const ProfileBio({super.key, required this.profileUserId});

  final String profileUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bio = ref.watch(aspirantProfileProvider(profileUserId).select(
      (async) {
        final b = async.valueOrNull?.basics;
        return (
          text: b?.bio ?? '',
          location: b?.location ?? '',
          joined: b?.joinedAt,
        );
      },
    ));

    final details = <Widget>[
      if (bio.location.isNotEmpty)
        _Detail(icon: Icons.location_on_outlined, text: bio.location),
      if (bio.joined != null)
        _Detail(
          icon: Icons.calendar_today_outlined,
          text: 'Joined ${_joinedFormat.format(bio.joined!)}',
        ),
    ];

    if (bio.text.isEmpty && details.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.text.isNotEmpty) Text(bio.text, style: ProfileStyle.body),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 16, runSpacing: 4, children: details),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ProfileStyle.mutedText),
        const SizedBox(width: 4),
        Text(text, style: ProfileStyle.small),
      ],
    );
  }
}
