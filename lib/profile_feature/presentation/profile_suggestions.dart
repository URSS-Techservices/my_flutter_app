import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_section_header.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:halo/screens/profile/pages/dynamic_profile_page.dart';

final _nameStyle =
    ProfileStyle.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13);
final _cityStyle = ProfileStyle.small.copyWith(fontSize: 12);

/// Every size of a suggestion card, worked out from the screen width and
/// the phone's text size ([MediaQuery.of]). The row height is the exact sum
/// of the card's parts, so the card can never overflow.
class _CardSize {
  _CardSize._({
    required this.width,
    required this.avatarRadius,
    required this.padding,
    required this.avatarGap,
    required this.buttonGap,
    required this.buttonHeight,
    required this.rowHeight,
  });

  factory _CardSize.of(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size.width;
    final scaler = media.textScaler;

    // About 3 cards on screen; bigger phones get bigger cards.
    final width = (screen * 0.31).clamp(108.0, 156.0);
    final avatarRadius = (width * 0.22).clamp(24.0, 34.0);
    final padding = (width * 0.08).clamp(8.0, 12.0);
    final avatarGap = (screen * 0.015).clamp(4.0, 8.0);
    // Space between the name / city and the Follow button.
    final buttonGap = (screen * 0.022).clamp(6.0, 12.0);
    final buttonHeight =
        (screen * 0.078).clamp(28.0, 36.0) + (scaler.scale(13) - 13);

    double lineHeight(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final h = painter.height;
      painter.dispose();
      return h;
    }

    final rowHeight = padding +
        avatarRadius * 2 +
        avatarGap +
        lineHeight(_nameStyle) +
        lineHeight(_cityStyle) +
        buttonGap +
        buttonHeight +
        padding +
        2; // card border

    return _CardSize._(
      width: width,
      avatarRadius: avatarRadius,
      padding: padding,
      avatarGap: avatarGap,
      buttonGap: buttonGap,
      buttonHeight: buttonHeight,
      rowHeight: rowHeight.ceilToDouble(),
    );
  }

  final double width;
  final double avatarRadius;
  final double padding;
  final double avatarGap;
  final double buttonGap;
  final double buttonHeight;
  final double rowHeight;
}

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
    final size = _CardSize.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(title: 'Suggested for you'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
          child: Row(
            children: [
              for (final type in SuggestionType.values) ...[
                _FilterPill(
                  label: type.label,
                  selected: type == _selected,
                  onTap: () => setState(() => _selected = type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: size.rowHeight,
          child: current.when(
            loading: () => _row(List.filled(4, null), size),
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
              return _row(visible, size);
            },
          ),
        ),
      ],
    );
  }

  /// `null` entries draw grey placeholder cards of the same size.
  Widget _row(List<ProfilePerson?> people, _CardSize size) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      itemCount: people.length,
      separatorBuilder: (_, __) => SizedBox(width: size.padding),
      itemBuilder: (_, i) {
        final person = people[i];
        if (person == null) {
          return Container(
            width: size.width,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
          );
        }
        return _SuggestionCard(
          key: ValueKey(person.id),
          person: person,
          size: size,
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
    required this.size,
    required this.onDismiss,
  });

  final ProfilePerson person;
  final _CardSize size;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final subtitle = person.city.isNotEmpty
        ? person.city
        : (person.username.isNotEmpty ? '@${person.username}' : '');

    return SizedBox(
      width: size.width,
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
                padding: EdgeInsets.all(size.padding),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: size.avatarRadius,
                      backgroundColor: ProfileStyle.surface,
                      backgroundImage: person.photoUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(
                              person.photoUrl,
                              maxWidth: (size.avatarRadius * 2 * dpr).round(),
                            ),
                      child: person.photoUrl.isEmpty
                          ? Icon(Icons.person,
                              size: size.avatarRadius,
                              color: ProfileStyle.mutedText)
                          : null,
                    ),
                    SizedBox(height: size.avatarGap),
                    Text(
                      person.displayName,
                      style: _nameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: _cityStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: size.buttonGap),
                    _FollowButton(
                      personId: person.id,
                      height: size.buttonHeight,
                    ),
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
                      size: 14, color: ProfileStyle.mutedText),
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
  const _FollowButton({required this.personId, required this.height});

  final String personId;
  final double height;

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
    // Exact height: no hidden 48px minimum tap area stretching the card.
    final size = Size.fromHeight(widget.height);
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        _following ? 'Following' : 'Follow',
        maxLines: 1,
        style: ProfileStyle.small.copyWith(
          fontWeight: FontWeight.w600,
          color: _following ? ProfileStyle.text : Colors.white,
        ),
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: _following
          ? OutlinedButton(
              onPressed: _toggle,
              style: OutlinedButton.styleFrom(
                foregroundColor: ProfileStyle.text,
                side: const BorderSide(color: ProfileStyle.divider),
                minimumSize: size,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
              ),
              child: label,
            )
          : FilledButton(
              onPressed: _toggle,
              style: FilledButton.styleFrom(
                backgroundColor: ProfileStyle.action,
                foregroundColor: Colors.white,
                minimumSize: size,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
              ),
              child: label,
            ),
    );
  }
}

/// Aspirants / Coaches / Wellness filter. Sized by its text, so the label
/// is never cut off at any text size.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? ProfileStyle.action : ProfileStyle.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: ProfileStyle.small.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : ProfileStyle.text,
            ),
          ),
        ),
      ),
    );
  }
}
