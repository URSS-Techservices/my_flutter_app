import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/feed/domain/post_data.dart';
import 'package:halo/features/feed/presentation/feed_data.dart';
import 'package:halo/features/feed/presentation/home_layout.dart';

class SearchBar extends ConsumerWidget {
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  const SearchBar({
    super.key,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = HomeLayout.pagePad(context);
    final config = ref.watch(homeConfigProvider).valueOrNull ?? HomeConfig.defaults;
    final hint = config.searchPlaceholder;
    final radius = BorderRadius.circular(22);

    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 12),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              borderRadius: radius,
              child: InkWell(
                onTap: onSearch,
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onFilter,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.tune_rounded, color: Color(0xFF2D2D2D)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
