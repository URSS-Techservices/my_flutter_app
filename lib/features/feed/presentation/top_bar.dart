import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';

class TopBar extends ConsumerWidget {
  final VoidCallback onMenu;
  final VoidCallback onBell;
  final VoidCallback onChat;
  final VoidCallback onPhoto;

  const TopBar({
    super.key,
    required this.onMenu,
    required this.onBell,
    required this.onChat,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = HomeLayout.pagePad(context);
    final unread = ref.watch(unreadDotProvider).valueOrNull ?? false;
    final photo = ref.watch(myPhotoProvider).valueOrNull ?? '';
    final iconSize = MediaQuery.sizeOf(context).width < 360 ? 22.0 : 24.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left, 4, pad.right, 8),
      child: Row(
        children: [
          _iconBtn(Icons.menu_rounded, onMenu, iconSize),
          Expanded(
            child: Text(
              'Halo',
              textAlign: TextAlign.center,
              style: GoogleFonts.pacifico(
                fontSize: MediaQuery.sizeOf(context).width < 360 ? 26 : 30,
                color: kSecondaryColor,
                height: 1.1,
              ),
            ),
          ),
          _iconBtn(Icons.notifications_none_rounded, onBell, iconSize, dot: unread),
          _iconBtn(Icons.chat_bubble_outline_rounded, onChat, iconSize),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onPhoto,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE8E6F0),
              backgroundImage: photo.isNotEmpty
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, double size, {bool dot = false}) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: size, color: const Color(0xFF2D2D2D)),
          if (dot)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B4EFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
