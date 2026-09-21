import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECENT SEARCHES PANEL
// Shows when search bar is focused and query is empty.
// ─────────────────────────────────────────────────────────────────────────────

class SearchRecents extends ConsumerWidget {
  const SearchRecents({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents =
        ref.watch(searchNotifierProvider.select((s) => s.recentSearches));
    final notifier = ref.read(searchNotifierProvider.notifier);

    if (recents.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.s(16)),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                size: context.s(18), color: Colors.grey.shade400),
            SizedBox(width: context.s(8)),
            Text(
              'No recent searches',
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500, fontSize: context.sp(13)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: context.sp(15),
                color: const Color(0xFF1F1033),
              ),
            ),
            TextButton(
              onPressed: notifier.clearAllRecents,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: context.s(8)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Clear all',
                style: GoogleFonts.poppins(
                  color: kSearchSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(12),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.s(6)),

        // Recent search chips
        ...recents.map((term) => _RecentTile(
              term: term,
              onTap: () => notifier.applyRecentSearch(term),
              onRemove: () => notifier.removeRecent(term),
            )),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentTile({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.s(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: context.s(10), horizontal: context.s(4)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.s(7)),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded,
                  size: context.s(16), color: Colors.grey.shade500),
            ),
            SizedBox(width: context.s(12)),
            Expanded(
              child: Text(
                term,
                style: GoogleFonts.poppins(
                    fontSize: context.sp(14), color: const Color(0xFF1F1033)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  size: context.s(16), color: Colors.grey.shade400),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
