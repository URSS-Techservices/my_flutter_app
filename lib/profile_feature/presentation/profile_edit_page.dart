import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/aspirant_fitness_stats.dart';
import 'package:halo/profile_feature/domain/profile_basics.dart';
import 'package:halo/profile_feature/domain/social_link.dart';
import 'package:halo/profile_feature/presentation/profile_edit_parts.dart';
import 'package:halo/profile_feature/presentation/profile_social_links.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';
import 'package:image_picker/image_picker.dart';

/// Edit Profile for every account type: photos, basic info and social
/// links, saved together with the Save button. Aspirants also get the
/// Fitness Stats section (pass [fitnessStats]).
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.basics,
    this.fitnessStats,
    this.focusSocialLinks = false,
  });

  /// The profile as it was when the user tapped Edit.
  final ProfileBasics basics;

  /// Aspirants only; null hides the Fitness Stats section.
  final AspirantFitnessStats? fitnessStats;

  /// Open already scrolled to Social Links (from "+ Add social links").
  final bool focusSocialLinks;

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  static const _bioLimit = 200;
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9._]{3,30}$');

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _location;
  late final TextEditingController _website;
  late final TextEditingController _workouts;
  late final TextEditingController _calories;
  late final TextEditingController _hours;
  late final TextEditingController _streak;

  /// Saved short handles per platform, in display order.
  final Map<SocialPlatform, String> _links = {};
  final _socialKey = GlobalKey();

  File? _photoFile;
  File? _coverFile;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final b = widget.basics;
    final s = widget.fitnessStats ?? AspirantFitnessStats.empty;
    _name = TextEditingController(text: b.name);
    _username = TextEditingController(text: b.username);
    _bio = TextEditingController(text: b.bio);
    _location = TextEditingController(text: b.location);
    _website = TextEditingController(text: b.website);
    _workouts = TextEditingController(text: _num(s.workouts));
    _calories = TextEditingController(text: _num(s.calories));
    _hours = TextEditingController(text: _num(s.hours));
    _streak = TextEditingController(text: _num(s.dayStreak));
    for (final platform in SocialPlatform.values) {
      final link = b.socialLinks[platform.key];
      if (link != null) {
        _links[platform] = platform.toStored(link);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.focusSocialLinks && !_scrolledToSocial) {
      _scrolledToSocial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _socialKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  bool _scrolledToSocial = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _username,
      _bio,
      _location,
      _website,
      _workouts,
      _calories,
      _hours,
      _streak,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _num(int value) => value == 0 ? '' : '$value';

  // ---------------------------------------------------------------- photos

  Future<void> _pickPhoto({required bool isCover}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Resized on pick so we never upload or decode a full camera photo.
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: isCover ? 1600 : 600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _changed = true;
      if (isCover) {
        _coverFile = File(picked.path);
      } else {
        _photoFile = File(picked.path);
      }
    });
  }

  // ---------------------------------------------------------- social links

  Future<void> _addSocialLink() async {
    final remaining =
        SocialPlatform.values.where((p) => !_links.containsKey(p)).toList();
    if (remaining.isEmpty) {
      HaloToast.show('All social links are already added');
      return;
    }
    final platform = await showModalBottomSheet<SocialPlatform>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in remaining)
              ListTile(
                leading: SocialPlatformIcon(p),
                title: Text(p.label),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (platform == null || !mounted) return;
    await _editSocialLink(platform);
  }

  /// One-field sheet. A pasted link from another platform is filed under
  /// that platform instead.
  Future<void> _editSocialLink(SocialPlatform platform) async {
    final current = _links[platform];
    final input = await showSocialLinkSheet(
      context,
      platform: platform,
      initialText: current == null ? '' : platform.editText(current),
    );
    if (input == null || !mounted) return;

    final target = SocialPlatform.detect(input) ?? platform;
    final stored = target.toStored(input);
    setState(() {
      _changed = true;
      if (target != platform) _links.remove(platform);
      if (stored.isEmpty) {
        _links.remove(target);
      } else {
        _links[target] = stored;
      }
    });
  }

  void _removeSocialLink(SocialPlatform platform) {
    setState(() {
      _changed = true;
      _links.remove(platform);
    });
  }

  // ------------------------------------------------------------ validation

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name';
    if (v.length > 50) return 'Name is too long';
    return null;
  }

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (!_usernamePattern.hasMatch(v)) {
      return '3–30 letters, numbers, . or _';
    }
    return null;
  }

  String? _validateUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(_withScheme(v));
    if (uri == null || !uri.host.contains('.')) return 'Enter a valid link';
    return null;
  }

  static String _withScheme(String url) =>
      url.startsWith('http://') || url.startsWith('https://')
          ? url
          : 'https://$url';

  // ------------------------------------------------------------------ save

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    final myId = ref.read(myUserIdProvider);
    final userId = widget.basics.id;
    if (myId != userId) {
      HaloToast.show('You can only edit your own profile');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    try {
      final username = _username.text.trim();
      if (username.toLowerCase() !=
              widget.basics.username.toLowerCase() &&
          !await repo.isUsernameFree(username, myId: myId!)) {
        HaloToast.show('That username is taken');
        return;
      }

      // Upload both photos at the same time.
      final uploads = await Future.wait([
        if (_photoFile != null)
          repo.uploadPhoto(userId: userId, file: _photoFile!, isCover: false)
        else
          Future<String?>.value(null),
        if (_coverFile != null)
          repo.uploadPhoto(userId: userId, file: _coverFile!, isCover: true)
        else
          Future<String?>.value(null),
      ]);

      // Keep links for platforms this screen does not manage (e.g. telegram).
      final links = Map<String, String>.of(widget.basics.socialLinks)
        ..removeWhere(
            (key, _) => SocialPlatform.values.any((p) => p.key == key));
      for (final entry in _links.entries) {
        links[entry.key.key] = entry.value;
      }

      final website = _website.text.trim();
      await repo.saveProfile(
        userId: userId,
        name: _name.text.trim(),
        username: username,
        bio: _bio.text.trim(),
        location: _location.text.trim(),
        website: website.isEmpty ? '' : _withScheme(website),
        socialLinks: links,
        fitnessStats: widget.fitnessStats == null
            ? null
            : AspirantFitnessStats(
                workouts: int.tryParse(_workouts.text) ?? 0,
                calories: int.tryParse(_calories.text) ?? 0,
                hours: int.tryParse(_hours.text) ?? 0,
                dayStreak: int.tryParse(_streak.text) ?? 0,
              ),
        profilePhotoUrl: uploads[0],
        coverPhotoUrl: uploads[1],
      );

      if (!mounted) return;
      HaloToast.show('Profile updated');
      // The profile page listens live, so it updates on its own.
      _changed = false;
      Navigator.of(context).pop();
    } catch (_) {
      HaloToast.show('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _changed = false;
      Navigator.of(context).pop();
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final b = widget.basics;

    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: ProfileStyle.page,
        appBar: AppBar(
          backgroundColor: ProfileStyle.page,
          surfaceTintColor: ProfileStyle.page,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text('Edit Profile',
              style: ProfileStyle.name.copyWith(fontSize: 18)),
          actions: [
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(
                      'Save',
                      style: ProfileStyle.button.copyWith(
                        color: ProfileStyle.primaryDark,
                        fontSize: 17,
                      ),
                    ),
                  ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_changed) setState(() => _changed = true);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                EditPhotoHeader(
                  coverUrl: b.coverPhoto,
                  coverFile: _coverFile,
                  photoUrl: b.profilePhoto,
                  photoFile: _photoFile,
                  onChangeCover: () => _pickPhoto(isCover: true),
                  onChangePhoto: () => _pickPhoto(isCover: false),
                ),
                EditTextRow(
                  label: 'Name',
                  controller: _name,
                  validator: _validateName,
                ),
                EditTextRow(
                  label: 'Username',
                  controller: _username,
                  validator: _validateUsername,
                ),
                EditTextRow(
                  label: 'Bio',
                  controller: _bio,
                  maxLines: 4,
                  maxLength: _bioLimit,
                  hint: 'Tell people about yourself',
                ),
                EditTextRow(
                  label: 'Location',
                  controller: _location,
                  icon: Icons.location_on_outlined,
                  hint: 'City, State',
                ),
                EditTextRow(
                  label: 'Website',
                  controller: _website,
                  icon: Icons.link,
                  hint: 'https://',
                  keyboardType: TextInputType.url,
                  validator: _validateUrl,
                ),
                EditSectionTitle('Social Links', key: _socialKey),
                for (final entry in _links.entries)
                  SocialEditRow(
                    key: ValueKey(entry.key),
                    platform: entry.key,
                    stored: entry.value,
                    onTap: () => _editSocialLink(entry.key),
                    onRemove: () => _removeSocialLink(entry.key),
                  ),
                if (_links.length < SocialPlatform.values.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addSocialLink,
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text('Add Social Link',
                            style: ProfileStyle.button),
                        style: TextButton.styleFrom(
                          foregroundColor: ProfileStyle.link,
                        ),
                      ),
                    ),
                  ),
                if (widget.fitnessStats != null) ...[
                  const EditSectionTitle('Fitness Stats'),
                  EditStatRow(
                    icon: Icons.fitness_center,
                    color: ProfileStyle.primary,
                    label: 'Total Workouts',
                    controller: _workouts,
                  ),
                  EditStatRow(
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFEF4444),
                    label: 'Total Calories',
                    controller: _calories,
                  ),
                  EditStatRow(
                    icon: Icons.schedule,
                    color: const Color(0xFF22C55E),
                    label: 'Total Hours',
                    controller: _hours,
                  ),
                  EditStatRow(
                    icon: Icons.emoji_events,
                    color: const Color(0xFFF59E0B),
                    label: 'Day Streak',
                    controller: _streak,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
