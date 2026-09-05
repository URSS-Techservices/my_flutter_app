import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';

/// Reusable Halo top bar. Use on home or any other screen.
class AppBarUi extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenu;
  final VoidCallback? onBell;
  final VoidCallback? onChat;
  final VoidCallback? onPhoto;
  final bool showBell;
  final bool showChat;
  final bool showPhoto;
  final List<Widget>? extraActions;
  final Color backgroundColor;

  const AppBarUi({
    super.key,
    this.title = 'Halo',
    this.onMenu,
    this.onBell,
    this.onChat,
    this.onPhoto,
    this.showBell = true,
    this.showChat = true,
    this.showPhoto = true,
    this.extraActions,
    this.backgroundColor = Colors.white,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = HomeLayout.textScale(context);
    final iconSize = (22.0 * scale).clamp(20.0, 28.0);
    final unread = showBell ? (ref.watch(unreadDotProvider).valueOrNull ?? false) : false;
    final photo = showPhoto ? (ref.watch(myPhotoProvider).valueOrNull ?? '') : '';

    return Material(
      color: backgroundColor,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25),
        ),
        child: SizedBox(
        height: 56 * scale.clamp(1.0, 1.25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
              children: [
                if (onMenu != null)
                  _icon(Icons.menu_rounded, onMenu!, iconSize)
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: GoogleFonts.pacifico(
                        fontSize: 28,
                        color: kSecondaryColor,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                if (extraActions != null) ...extraActions!,
                if (showBell && onBell != null)
                  _icon(Icons.notifications_none_rounded, onBell!, iconSize, dot: unread),
                if (showChat && onChat != null)
                  _icon(Icons.chat_bubble_outline_rounded, onChat!, iconSize),
                if (showPhoto && onPhoto != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onPhoto,
                    child: FeedAvatar(url: photo, radius: 16),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(IconData icon, VoidCallback onTap, double size, {bool dot = false}) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: size, color: const Color(0xFF2D2D2D)),
          if (dot)
            const Positioned(
              right: 0,
              top: 0,
              child: SizedBox(
                width: 8,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF6B4EFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
