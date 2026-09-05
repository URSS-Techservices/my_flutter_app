import 'package:flutter/material.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';

class NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  const NavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final scale = HomeLayout.textScale(context);
    final height = ((compact ? 56.0 : 62.0) + (scale - 1) * 18).clamp(56.0, 84.0);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? 4 : 10),
        child: Material(
          color: Colors.white,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                _tab(Icons.home_rounded, 'Home', 0, compact),
                _tab(Icons.search_rounded, 'Search', 1, compact),
                _tab(Icons.explore_rounded, 'Explore', 2, compact),
                _add(compact),
                _tab(Icons.favorite_border_rounded, 'Activity', 4, compact),
                _tab(Icons.person_outline_rounded, 'Profile', 5, compact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _add(bool compact) {
    final size = compact ? 44.0 : 50.0;
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xFF6B4EFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x406B4EFF),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _tab(IconData icon, String label, int i, bool compact) {
    final on = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(i),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: compact ? 22 : 24,
                color: on ? kSecondaryColor : Colors.grey.shade500,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? kSecondaryColor : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
