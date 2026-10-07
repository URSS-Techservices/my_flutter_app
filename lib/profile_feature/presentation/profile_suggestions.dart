import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

const _cardWidth = 136.0;
const _rowHeight = 196.0;

/// "Suggested for you" with Aspirants / Coaches / Wellness chips and a
/// horizontal row of people. All three lists load together, so switching
/// chips is instant.
class ProfileSuggestions extends ConsumerStatefulWidget {
  const ProfileSuggestions({super.key, required this.profileUserId});

  final String profileUserId;

  @override
  ConsumerState<ProfileSuggestions> createState() => _ProfileSuggestionsState();
}

class _ProfileSuggestionsState extends ConsumerState<ProfileSuggestions> {
  SuggestionType _selected = SuggestionType.aspirants;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(myUserIdProvider) == null) return const SizedBox.shrink();

    final lists = {
      for (final type in SuggestionType.values)
        type: ref.watch(suggestionsProvider(
          (type: type, profileUserId: widget.profileUserId),
        )),
    };
    final dismissed = ref.watch(dismissedSuggestionsProvider);
    final current = lists[_selected]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(title: 'Suggested for you'),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
            children: [
              for (final type in SuggestionType.values) ...[
                ChoiceChip(
                  label: Text(type.label),
                  selected: type == _selected,
                  showCheckmark: false,
                  labelStyle: ProfileStyle.small.copyWith(
                    color: type == _selected ? Colors.white : ProfileStyle.text,
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: ProfileStyle.primary,
                  backgroundColor: ProfileStyle.primaryLight,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onSelected: (_) => setState(() => _selected = type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _rowHeight,
          child: current.when(
            loading: () => _row(List.filled(4, null)),
            error: (_, __) => Center(
              child: Text('Could not load suggestions', style: ProfileStyle.small),
            ),
            data: (people) {
              final visible =
                  people.where((p) => !dismissed.contains(p.id)).toList();
              if (visible.isEmpty) {
                return Center(
                  child: Text('No suggestions right now',
                      style: ProfileStyle.small),
                );
              }
              return _row(visible);
            },
          ),
        ),
      ],
    );
  }

  /// `null` entries draw grey placeholder cards of the same size.
  Widget _row(List<ProfilePerson?> people) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final person = people[i];
        if (person == null) {
          return Container(
            width: _cardWidth,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
          );
        }
        return _SuggestionCard(
          key: ValueKey(person.id),
          person: person,
          onDismiss: () => ref
              .read(dismissedSuggestionsProvider.notifier)
              .update((s) => {...s, person.id}),
        );
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.person,
    required this.onDismiss,
  });

  final ProfilePerson person;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final subtitle = person.city.isNotEmpty
        ? person.city
        : (person.username.isNotEmpty ? '@${person.username}' : '');

    return SizedBox(
      width: _cardWidth,
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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: ProfileStyle.primaryLight,
                      backgroundImage: person.photoUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(
                              person.photoUrl,
                              maxWidth: (64 * dpr).round(),
                            ),
                      child: person.photoUrl.isEmpty
                          ? const Icon(Icons.person,
                              size: 32, color: ProfileStyle.primaryDark)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      person.displayName,
                      style: ProfileStyle.body.copyWith(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: ProfileStyle.small.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    _FollowButton(personId: person.id),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Hide',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      size: 16, color: ProfileStyle.mutedText),
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starts as "Follow" (suggestions never include people already followed),
/// flips instantly on tap and rolls back if saving fails. No live listener.
class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.personId});

  final String personId;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _following = false;
  bool _busy = false;

  Future<void> _toggle() async {
    final myId = ref.read(myUserIdProvider);
    if (_busy || myId == null) return;
    final next = !_following;
    setState(() {
      _following = next;
      _busy = true;
    });
    try {
      await ref.read(followRepositoryProvider).setFollowing(
            myId: myId,
            theirId: widget.personId,
            follow: next,
          );
    } catch (_) {
      if (mounted) setState(() => _following = !next);
      HaloToast.show('Could not update follow. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = Size.fromHeight(32);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    final label = Text(
      _following ? 'Following' : 'Follow',
      style: ProfileStyle.small.copyWith(
        fontWeight: FontWeight.w600,
        color: _following ? ProfileStyle.text : Colors.white,
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: _following
          ? OutlinedButton(
              onPressed: _toggle,
              style: OutlinedButton.styleFrom(
                foregroundColor: ProfileStyle.text,
                side: const BorderSide(color: ProfileStyle.divider),
                minimumSize: size,
                padding: EdgeInsets.zero,
                shape: shape,
              ),
              child: label,
            )
          : FilledButton(
              onPressed: _toggle,
              style: FilledButton.styleFrom(
                backgroundColor: ProfileStyle.primary,
                foregroundColor: Colors.white,
                minimumSize: size,
                padding: EdgeInsets.zero,
                shape: shape,
              ),
              child: label,
            ),
    );
  }
}
