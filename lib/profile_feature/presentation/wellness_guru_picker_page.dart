import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/profile_person.dart';
import 'package:halo/profile_feature/domain/wellness_profile.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// Owner screen for "Featured Gurus": gurus who follow this account, with
/// Add / Remove. A search box filters them by name or username. Each tap
/// saves at once.
class WellnessGuruPickerPage extends ConsumerStatefulWidget {
  const WellnessGuruPickerPage({super.key, required this.wellnessId});

  final String wellnessId;

  @override
  ConsumerState<WellnessGuruPickerPage> createState() =>
      _WellnessGuruPickerPageState();
}

class _WellnessGuruPickerPageState
    extends ConsumerState<WellnessGuruPickerPage> {
  final _search = TextEditingController();
  String _query = '';

  /// Ids being saved right now, so their button shows a spinner.
  final _busy = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ProfilePerson p) {
    final q = _query.toLowerCase().replaceFirst('@', '');
    return q.isEmpty ||
        p.name.toLowerCase().contains(q) ||
        p.username.toLowerCase().contains(q);
  }

  Future<void> _toggle(ProfilePerson guru, {required bool add}) async {
    if (_busy.contains(guru.id)) return;
    final count = ref
            .read(wellnessProfileProvider(widget.wellnessId))
            .valueOrNull
            ?.featuredGuruIds
            .length ??
        0;
    if (add && count >= WellnessProfile.maxFeaturedGurus) {
      HaloToast.show(
          'You can feature up to ${WellnessProfile.maxFeaturedGurus} gurus');
      return;
    }
    setState(() => _busy.add(guru.id));
    final repo = ref.read(wellnessRepositoryProvider);
    try {
      add
          ? await repo.addFeaturedGuru(widget.wellnessId, guru.id)
          : await repo.removeFeaturedGuru(widget.wellnessId, guru.id);
    } catch (_) {
      HaloToast.error('Could not save. Try again');
    } finally {
      if (mounted) setState(() => _busy.remove(guru.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final featuredIds = ref.watch(wellnessProfileProvider(widget.wellnessId)
            .select((a) => a.valueOrNull?.featuredGuruIds)) ??
        const <String>[];
    final featured = ref.watch(featuredGurusProvider(widget.wellnessId));
    final followers = ref.watch(guruFollowersProvider(widget.wellnessId));

    Widget row(ProfilePerson p) => _GuruRow(
          person: p,
          featured: featuredIds.contains(p.id),
          busy: _busy.contains(p.id),
          onToggle: (add) => _toggle(p, add: add),
        );

    return Scaffold(
      backgroundColor: ProfileStyle.page,
      appBar: AppBar(
        backgroundColor: ProfileStyle.page,
        surfaceTintColor: ProfileStyle.page,
        title: Text('Featured Gurus',
            style: ProfileStyle.name.copyWith(fontSize: 18)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  ProfileStyle.sideGap, 4, ProfileStyle.sideGap, 8),
              child: CupertinoSearchTextField(
                controller: _search,
                placeholder: 'Search your guru followers',
                onChanged: (text) => setState(() => _query = text.trim()),
              ),
            ),
            if (_query.isEmpty) ...[
              _Label(
                  'On your page (${featuredIds.length}/${WellnessProfile.maxFeaturedGurus})'),
              featured.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CupertinoActivityIndicator(),
                ),
                error: (_, __) => const _Hint('Could not load'),
                data: (list) => list.isEmpty
                    ? const _Hint('No gurus featured yet')
                    : Column(children: [for (final p in list) row(p)]),
              ),
            ],
            _Label(_query.isEmpty ? 'Gurus who follow you' : 'Results'),
            followers.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(),
              ),
              error: (_, __) => const _Hint('Could not load. Try again'),
              data: (list) {
                // Featured ones are already listed above when not searching.
                final shown = [
                  for (final p in list)
                    if (_matches(p) &&
                        (_query.isNotEmpty || !featuredIds.contains(p.id)))
                      p,
                ];
                if (shown.isNotEmpty) {
                  return Column(children: [for (final p in shown) row(p)]);
                }
                return _Hint(_query.isNotEmpty
                    ? 'No guru follower found with "$_query"'
                    : list.isEmpty
                        ? 'No gurus follow you yet. When a guru follows '
                            'your page, you can feature them here.'
                        : 'All your guru followers are featured');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            ProfileStyle.sideGap, 16, ProfileStyle.sideGap, 4),
        child: Text(text,
            style: ProfileStyle.small.copyWith(fontWeight: FontWeight.w600)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ProfileStyle.sideGap, vertical: 12),
        child: Text(text, style: ProfileStyle.small),
      );
}

class _GuruRow extends StatelessWidget {
  const _GuruRow({
    required this.person,
    required this.featured,
    required this.busy,
    required this.onToggle,
  });

  final ProfilePerson person;
  final bool featured;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      leading: CircleAvatar(
        backgroundColor: ProfileStyle.surface,
        backgroundImage: person.photoUrl.isEmpty
            ? null
            : CachedNetworkImageProvider(person.photoUrl),
        child: person.photoUrl.isEmpty
            ? const Icon(Icons.person, color: ProfileStyle.mutedText)
            : null,
      ),
      title: Text(person.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ProfileStyle.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: person.username.isEmpty
          ? null
          : Text('@${person.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ProfileStyle.small),
      trailing: SizedBox(
        width: 92,
        height: 32,
        child: busy
            ? const Center(child: CupertinoActivityIndicator())
            : FilledButton(
                onPressed: () => onToggle(!featured),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      featured ? ProfileStyle.surface : ProfileStyle.action,
                  foregroundColor:
                      featured ? ProfileStyle.text : Colors.white,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(featured ? 'Remove' : 'Add',
                    style: ProfileStyle.button.copyWith(fontSize: 13)),
              ),
      ),
    );
  }
}
