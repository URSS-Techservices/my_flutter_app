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
    final height =
        ((compact ? 60.0 : 68.0) + (scale - 1) * 18).clamp(60.0, 88.0);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
      ),
      child: Builder(
        builder: (context) => Padding(
          // Sit above the system navigation (gesture bar / 3 buttons).
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? bottom + 4 : 10),
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
      ),
    );
  }

  /// Plain plus, a little smaller than the other icons but in the same
  /// style and color, so the bar looks even.
  Widget _add(bool compact) => _item(
        Icons.add_rounded,
        'Create',
        on: index == 3,
        compact: compact,
        onTap: onAdd,
        iconSize: compact ? 22 : 24,
      );

  Widget _tab(IconData icon, String label, int i, bool compact) => _item(
        icon,
        label,
        on: index == i,
        compact: compact,
        onTap: () => onSelect(i),
      );

  Widget _item(
    IconData icon,
    String label, {
    required bool on,
    required bool compact,
    required VoidCallback onTap,
    double? iconSize,
  }) {
    final box = compact ? 24.0 : 26.0;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fixed box so a smaller icon keeps labels in line.
              SizedBox.square(
                dimension: box,
                child: Icon(
                  icon,
                  size: iconSize ?? box,
                  color: on ? kSecondaryColor : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 11.5,
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
