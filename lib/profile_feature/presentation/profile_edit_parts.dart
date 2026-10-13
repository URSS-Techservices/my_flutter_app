import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/profile_feature/domain/social_link.dart';
import 'package:halo/profile_feature/presentation/profile_social_links.dart';
import 'package:halo/profile_feature/presentation/profile_style.dart';

/// Building blocks for Edit Profile screens (aspirant now, guru and
/// wellness later).

/// Cover with "Change Cover" and avatar with "Change Photo".
class EditPhotoHeader extends StatelessWidget {
  const EditPhotoHeader({
    super.key,
    required this.coverUrl,
    required this.coverFile,
    required this.photoUrl,
    required this.photoFile,
    required this.onChangeCover,
    required this.onChangePhoto,
  });

  final String coverUrl;
  final File? coverFile;
  final String photoUrl;
  final File? photoFile;
  final VoidCallback onChangeCover;
  final VoidCallback onChangePhoto;

  static const _coverHeight = 150.0;
  static const _avatar = 120.0;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      height: _coverHeight + _avatar / 2 + 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _coverHeight,
            child: _image(
              url: coverUrl,
              file: coverFile,
              cacheWidth: (width * dpr).round(),
              fallback: const ColoredBox(color: Color(0xFF334155)),
            ),
          ),
          Positioned(
            right: 12,
            bottom: _avatar / 2 + 28 + 8,
            child: _ChangeCoverButton(onPressed: onChangeCover),
          ),
          Positioned(
            left: ProfileStyle.sideGap,
            top: _coverHeight - _avatar / 2,
            child: GestureDetector(
              onTap: onChangePhoto,
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: _avatar,
                        height: _avatar,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: ProfileStyle.page,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: _image(
                            url: photoUrl,
                            file: photoFile,
                            cacheWidth: (_avatar * dpr).round(),
                            fallback: const ColoredBox(
                              color: ProfileStyle.primaryLight,
                              child: Icon(Icons.person,
                                  size: 52, color: ProfileStyle.primaryDark),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: ProfileStyle.page, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Change Photo',
                    style: ProfileStyle.small.copyWith(color: ProfileStyle.primaryDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A just-picked file wins over the saved URL.
  static Widget _image({
    required String url,
    required File? file,
    required int cacheWidth,
    required Widget fallback,
  }) {
    if (file != null) {
      return Image.file(file, fit: BoxFit.cover, cacheWidth: cacheWidth);
    }
    if (url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _ChangeCoverButton extends StatelessWidget {
  const _ChangeCoverButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              Text(
                'Change Cover',
                style: ProfileStyle.small.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditSectionTitle extends StatelessWidget {
  const EditSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ProfileStyle.sideGap, 24, ProfileStyle.sideGap, 8),
      child: Text(text, style: ProfileStyle.name.copyWith(fontSize: 18)),
    );
  }
}

/// "Label    [ field ]" row, as in the design.
class EditTextRow extends StatelessWidget {
  const EditTextRow({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileStyle.sideGap,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(label, style: ProfileStyle.body),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              minLines: 1,
              maxLength: maxLength,
              keyboardType: keyboardType,
              validator: validator,
              style: ProfileStyle.body,
              decoration: editFieldDecoration(hint: hint, icon: icon),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration editFieldDecoration({String? hint, IconData? icon}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: ProfileStyle.divider),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: ProfileStyle.small,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    prefixIcon:
        icon == null ? null : Icon(icon, size: 20, color: ProfileStyle.mutedText),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: ProfileStyle.primary),
    ),
  );
}

/// Saved social link in Edit Profile. Tap to edit, swipe left to remove.
/// A row for something that cannot be edited yet: icon, label and a
/// "Coming Soon" tag. Tapping says so.
class EditComingSoonRow extends StatelessWidget {
  const EditComingSoonRow({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: ProfileStyle.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: ProfileStyle.action),
      ),
      title: Text(label, style: ProfileStyle.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ProfileStyle.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Coming Soon',
              style: ProfileStyle.small.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: ProfileStyle.mutedText),
        ],
      ),
      onTap: () => HaloToast.show('Editing $label is coming soon'),
    );
  }
}

class SocialEditRow extends StatelessWidget {
  const SocialEditRow({
    super.key,
    required this.platform,
    required this.stored,
    required this.onTap,
    required this.onRemove,
  });

  final SocialPlatform platform;
  final String stored;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('social-${platform.key}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: const Color(0xFFEF4444),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: ProfileStyle.sideGap),
        leading: SocialPlatformIcon(platform),
        title: Text(platform.label, style: ProfileStyle.body),
        subtitle: Text(platform.display(stored), style: ProfileStyle.small),
        trailing: const Icon(Icons.chevron_right, color: ProfileStyle.mutedText),
        onTap: onTap,
      ),
    );
  }
}

/// Bottom sheet with one field for a social handle. The platform's address
/// is shown before the field, so users only type their handle (pasting a
/// full link also works). Returns the text, '' to remove, or null if closed.
Future<String?> showSocialLinkSheet(
  BuildContext context, {
  required SocialPlatform platform,
  required String initialText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SocialLinkSheet(platform: platform, initialText: initialText),
  );
}

class _SocialLinkSheet extends StatefulWidget {
  const _SocialLinkSheet({required this.platform, required this.initialText});

  final SocialPlatform platform;
  final String initialText;

  @override
  State<_SocialLinkSheet> createState() => _SocialLinkSheetState();
}

class _SocialLinkSheetState extends State<_SocialLinkSheet> {
  late final _controller = TextEditingController(text: widget.initialText);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context, '');
      return;
    }
    final target = SocialPlatform.detect(text) ?? widget.platform;
    final error = target.validate(target.toStored(text));
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.platform;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ProfileStyle.sideGap,
        16,
        ProfileStyle.sideGap,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SocialPlatformIcon(p),
              const SizedBox(width: 10),
              Text(p.label, style: ProfileStyle.name.copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            style: ProfileStyle.body,
            decoration: editFieldDecoration(
              hint: p == SocialPlatform.netflix ? 'Profile name' : 'yourhandle',
            ).copyWith(
              prefixText: p.fieldPrefix.isEmpty ? null : p.fieldPrefix,
              prefixStyle: ProfileStyle.small,
              errorText: _error,
              helperText: 'Type your handle or paste the full link',
              helperStyle: ProfileStyle.small,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _done,
              style: FilledButton.styleFrom(
                backgroundColor: ProfileStyle.primary,
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text('Done', style: ProfileStyle.button),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + label + number field, used under Fitness Stats.
class EditStatRow extends StatelessWidget {
  const EditStatRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.controller,
  });

  final IconData icon;
  final Color color;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileStyle.sideGap,
        vertical: 6,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: ProfileStyle.body)),
          SizedBox(
            width: 140,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              style: ProfileStyle.body,
              decoration: editFieldDecoration(hint: '0'),
            ),
          ),
        ],
      ),
    );
  }
}
