import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/drawer/data/feedback_repository.dart';
import 'package:halo/profile_feature/presentation/profile_providers.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(FirebaseFirestore.instance),
);

/// Store / website link sent by "Share App". Empty until the app is
/// published; then only the text is shared.
const kAppShareLink = '';

/// Shown at the bottom of the drawer. Keep in step with pubspec.yaml.
const kAppVersion = '1.0.0';

/// Colors matching the home page: white page, light grey cards.
abstract final class _C {
  static const page = Colors.white;
  static const card = Color(0xFFF5F5F7);
  static const text = Color(0xFF111111);
  static const muted = Color(0xFF8E8E8E);
  static const separator = Color(0xFFE5E5EA);
  static const red = Color(0xFFFF3B30);
  static const accent = Color(0xFF8B6FD6);
}

/// Sizes worked out from the screen, so the drawer fits small phones and
/// does not look oversized on big ones.
class _Size {
  _Size.of(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    drawerWidth = (w * 0.78).clamp(256.0, 320.0);
    rowHeight = (w * 0.105).clamp(40.0, 46.0);
    iconBox = (w * 0.066).clamp(24.0, 28.0);
    font = (w * 0.037).clamp(14.0, 15.5);
    side = (w * 0.035).clamp(12.0, 16.0);
    coverHeight = (drawerWidth * 0.46).clamp(118.0, 150.0);
    avatarRadius = (drawerWidth * 0.11).clamp(28.0, 36.0);
  }

  late final double drawerWidth;
  late final double rowHeight;
  late final double iconBox;
  late final double font;
  late final double side;

  late final double coverHeight;
  late final double avatarRadius;
}

/// Side menu: my cover + profile photo header, then compact grouped cards
/// on white, like the home page. Account Type is a dropdown in the last
/// card.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    required this.onExplore,
    required this.onSaved,
    required this.onNotifications,
    required this.onSettings,
    required this.onHelp,
    required this.onLogout,
    required this.onProfile,
  });

  final VoidCallback onExplore;
  final VoidCallback onSaved;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  /// Runs after the user confirms and the drawer has closed.
  final VoidCallback onLogout;

  /// Tapping the header (cover, photo, name) opens my profile.
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = _Size.of(context);
    final myId = ref.watch(myUserIdProvider);
    final role = myId == null
        ? null
        : ref.watch(
            profileProvider(myId).select((a) => a.valueOrNull?.accountType));

    /// Closes the drawer, then runs [action].
    VoidCallback go(VoidCallback action) => () {
          HapticFeedback.selectionClick();
          Navigator.pop(context);
          action();
        };

    Widget row(IconData icon, Color color, String label, VoidCallback onTap) =>
        _Row(
          size: size,
          icon: icon,
          color: color,
          label: label,
          onTap: onTap,
        );

    return Drawer(
      width: size.drawerWidth,
      backgroundColor: _C.page,
      shape: const RoundedRectangleBorder(),
      child: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 20,
        ),
        children: [
          _DrawerHeader(size: size, onTap: go(onProfile)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.side),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Group(size: size, children: [
                  row(Icons.explore_rounded, const Color(0xFF007AFF), 'Explore',
                      go(onExplore)),
                  row(Icons.bookmark_rounded, const Color(0xFFFF9500),
                      'Saved Posts', go(onSaved)),
                  row(Icons.notifications_rounded, const Color(0xFFFF3B30),
                      'Notifications', go(onNotifications)),
                ]),
                const SizedBox(height: 16),
                _Group(size: size, children: [
                  row(Icons.settings_rounded, const Color(0xFF8E8E93),
                      'Settings', go(onSettings)),
                  row(Icons.help_rounded, const Color(0xFF5AC8FA), 'Help',
                      go(onHelp)),
                  row(
                      Icons.star_rounded,
                      const Color(0xFFFFB800),
                      'Rate & Feedback',
                      () => _showFeedbackSheet(context, ref)),
                  row(Icons.ios_share_rounded, const Color(0xFF5856D6),
                      'Share App', () => _shareApp(context)),
                ]),
                const SizedBox(height: 16),
                _Group(size: size, children: [
                  _AccountTypeDropdown(
                      size: size, current: _AccountType.from(role)),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    minimumSize: Size(0, size.rowHeight),
                    onPressed: () => _confirmLogout(context),
                    child: Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: size.font,
                        fontWeight: FontWeight.w600,
                        color: _C.red,
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Version $kAppVersion',
                    style: TextStyle(fontSize: 11, color: _C.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    const text = 'Join me on Halo — find coaches, wellness centres and '
        'people on the same fitness journey.';
    await Share.share(
      kAppShareLink.isEmpty ? text : '$text\n$kAppShareLink',
      subject: 'Halo',
      // iPad needs an anchor for the share popover.
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  void _confirmLogout(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Log out of Halo?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheet);
              Navigator.pop(context); // close the drawer
              onLogout();
            },
            child: const Text('Log Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// ───────── header ─────────

/// My cover photo with my profile photo overlapping it, then name,
/// @username and account type — the same look as the profile page.
class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader({required this.size, required this.onTap});

  final _Size size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myUserIdProvider);
    final me =
        myId == null ? null : ref.watch(profileProvider(myId)).valueOrNull;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final coverH = size.coverHeight + top;
    final r = size.avatarRadius;
    final type = _AccountType.from(me?.accountType);

    final cover = (me?.coverPhoto ?? '').isEmpty
        ? const DecoratedBox(
            // Same fallback as the profile page cover.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF475569)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          )
        : CachedNetworkImage(
            imageUrl: me!.coverPhoto,
            fit: BoxFit.cover,
            memCacheWidth: (size.drawerWidth * dpr).round(),
            placeholder: (_, __) => const ColoredBox(color: _C.card),
            errorWidget: (_, __, ___) => const ColoredBox(color: _C.card),
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: coverH + r,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: coverH,
                    child: cover,
                  ),
                  // Soft shade under the status bar so its icons stay readable.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: top + 24,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x40000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: size.side,
                    top: coverH - r,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _C.page,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: r,
                        backgroundColor: _C.card,
                        backgroundImage: (me?.profilePhoto ?? '').isEmpty
                            ? null
                            : CachedNetworkImageProvider(
                                me!.profilePhoto,
                                maxWidth: (r * 2 * dpr).round(),
                              ),
                        child: (me?.profilePhoto ?? '').isEmpty
                            ? Icon(Icons.person_rounded,
                                size: r, color: _C.muted)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size.side),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (me?.name ?? '').isNotEmpty ? me!.name : 'Halo user',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: size.font + 2,
                            fontWeight: FontWeight.w700,
                            color: _C.text,
                          ),
                        ),
                        if ((me?.username ?? '').isNotEmpty)
                          Text(
                            '@${me!.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: size.font - 1.5,
                              color: _C.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (type != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type.label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _C.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── account type ─────────

enum _AccountType {
  aspirant('Aspirant', Icons.directions_run_rounded),
  guru('Guru', Icons.sports_gymnastics_rounded),
  wellness('Wellness', Icons.spa_rounded);

  const _AccountType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Null while the profile is loading.
  static _AccountType? from(String? accountType) => switch (accountType) {
        null => null,
        'guru' => guru,
        'wellness' => wellness,
        _ => aspirant,
      };
}

/// "Account Type   Guru ⌄": tap to open the three types underneath. The
/// current one is ticked; the others say Coming Soon.
class _AccountTypeDropdown extends StatefulWidget {
  const _AccountTypeDropdown({required this.size, required this.current});

  final _Size size;
  final _AccountType? current;

  @override
  State<_AccountTypeDropdown> createState() => _AccountTypeDropdownState();
}

class _AccountTypeDropdownState extends State<_AccountTypeDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final current = widget.current;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          _Row(
            size: size,
            icon: Icons.person_rounded,
            color: _C.accent,
            label: 'Account Type',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current?.label ?? '',
                  style: TextStyle(fontSize: size.font - 1, color: _C.muted),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(CupertinoIcons.chevron_down,
                      size: 14, color: Color(0xFFC7C7CC)),
                ),
              ],
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _open = !_open);
            },
          ),
          if (_open)
            for (final t in _AccountType.values) ...[
              Padding(
                padding: EdgeInsets.only(left: size.iconBox + 24),
                child: const Divider(
                    height: 0.5, thickness: 0.5, color: _C.separator),
              ),
              _AccountTypeOption(size: size, type: t, current: current),
            ],
        ],
      ),
    );
  }
}

class _AccountTypeOption extends StatelessWidget {
  const _AccountTypeOption({
    required this.size,
    required this.type,
    required this.current,
  });

  final _Size size;
  final _AccountType type;
  final _AccountType? current;

  @override
  Widget build(BuildContext context) {
    final isCurrent = type == current;
    return Material(
      color: _C.card,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        highlightColor: const Color(0xFFE5E5EA),
        onTap: () {
          HapticFeedback.selectionClick();
          HaloToast.show(isCurrent
              ? 'You are a ${type.label}'
              : 'Switching to ${type.label} is coming soon');
        },
        child: SizedBox(
          height: size.rowHeight - 4,
          child: Padding(
            padding: EdgeInsets.only(left: size.iconBox + 24, right: 12),
            child: Row(
              children: [
                Icon(type.icon,
                    size: size.font + 2,
                    color: isCurrent ? _C.accent : _C.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: size.font - 0.5,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: _C.text,
                    ),
                  ),
                ),
                if (isCurrent)
                  const Icon(CupertinoIcons.checkmark_alt,
                      size: 18, color: _C.accent)
                else
                  const _Pill('Coming Soon'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── sheets ─────────

Future<void> _showFeedbackSheet(BuildContext context, WidgetRef ref) {
  return _showIosSheet(
    context,
    child: _FeedbackSheet(
      onSend: (stars, message) => ref.read(feedbackRepositoryProvider).send(
            userId: FirebaseAuth.instance.currentUser!.uid,
            stars: stars,
            message: message,
          ),
    ),
  );
}

Future<void> _showIosSheet(BuildContext context, {required Widget child}) {
  if (FirebaseAuth.instance.currentUser == null) {
    HaloToast.show('Please log in first');
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _C.page,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: child,
    ),
  );
}

/// Grabber, title and Cancel / action buttons, like an iOS sheet.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.actionLabel,
    required this.canSend,
    required this.sending,
    required this.onSend,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final bool canSend;
  final bool sending;
  final VoidCallback onSend;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFC7C7CC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: _C.accent)),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _C.text,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: canSend && !sending ? onSend : null,
                child: sending
                    ? const CupertinoActivityIndicator()
                    : Text(
                        actionLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: canSend ? _C.accent : _C.muted,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.onSend});

  /// Stars are null when the user did not rate.
  final Future<void> Function(int? stars, String message) onSend;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

/// Optional 1–5 stars plus a message; either one is enough to send.
class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _text = TextEditingController();
  int _stars = 0;
  bool _sending = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.onSend(_stars == 0 ? null : _stars, _text.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      HaloToast.success('Thanks for your feedback!');
    } catch (_) {
      if (mounted) setState(() => _sending = false);
      HaloToast.error('Could not send. Try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Rate & Feedback',
      actionLabel: 'Send',
      canSend: _stars > 0 || _text.text.trim().isNotEmpty,
      sending: _sending,
      onSend: _send,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'How are you enjoying Halo?',
            style: TextStyle(fontSize: 15, color: _C.muted),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _stars = i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i <= _stars
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      size: 36,
                      color: const Color(0xFFFFCC00),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                _labels[_stars],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _text,
            minLines: 4,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            placeholder: 'Tell us what you like, what is not working, '
                'or what we should add…',
            onChanged: (_) => setState(() {}),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── building blocks ─────────

class _Group extends StatelessWidget {
  const _Group({required this.size, required this.children});

  final _Size size;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.only(left: size.iconBox + 24),
                child: const Divider(
                    height: 0.5, thickness: 0.5, color: _C.separator),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Small colored icon square, label, and a trailing widget (chevron by
/// default).
class _Row extends StatelessWidget {
  const _Row({
    required this.size,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final _Size size;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.card,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: const Color(0xFFE5E5EA),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: size.iconBox,
                  height: size.iconBox,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(size.iconBox * 0.24),
                  ),
                  child: Icon(icon,
                      size: size.iconBox * 0.62, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: size.font, color: _C.text),
                  ),
                ),
                trailing ??
                    const Icon(CupertinoIcons.chevron_forward,
                        size: 14, color: Color(0xFFC7C7CC)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _C.page,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: _C.muted,
          ),
        ),
      );
}
