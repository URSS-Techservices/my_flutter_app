import 'package:flutter/material.dart';
import 'package:halo/features/search/presentation/search_responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/features/search/domain/search_models.dart';
import 'package:halo/features/search/presentation/search_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR WIDGET
// Pill-shaped input with purple search icon button. Clears via X icon.
// ─────────────────────────────────────────────────────────────────────────────

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      ref
          .read(searchNotifierProvider.notifier)
          .onFocusChanged(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Called from parent when a recent search is applied
  void setQuery(String text) {
    _controller.text = text;
  }

  @override
  Widget build(BuildContext context) {
    // Keep controller in sync if notifier clears the query
    ref.listen(searchNotifierProvider.select((s) => s.query), (_, newQuery) {
      if (newQuery.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
      } else if (_controller.text != newQuery && newQuery.isNotEmpty) {
        _controller.text = newQuery;
        _controller.selection =
            TextSelection.collapsed(offset: newQuery.length);
      }
    });

    final hasText =
        ref.watch(searchNotifierProvider.select((s) => s.query.isNotEmpty));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.s(32)),
        boxShadow: [
          BoxShadow(
            color: kSearchSecondary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Input field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.poppins(
                  color: Colors.black87, fontSize: context.sp(14)),
              onChanged: (val) => ref
                  .read(searchNotifierProvider.notifier)
                  .onQueryChanged(val, hasFocus: _focusNode.hasFocus),
              onSubmitted: (val) => ref
                  .read(searchNotifierProvider.notifier)
                  .onSearchSubmitted(val),
              decoration: InputDecoration(
                hintText: 'Search by name, service, or expertise...',
                hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade400, fontSize: context.sp(14)),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey.shade400, size: context.s(22)),
                suffixIcon: hasText
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey.shade400, size: context.s(20)),
                        onPressed: () {
                          ref
                              .read(searchNotifierProvider.notifier)
                              .clearSearch();
                          _focusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                    vertical: context.s(16), horizontal: context.s(4)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.s(32)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.s(32)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.s(32)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Purple search button
          GestureDetector(
            onTap: () {
              final q = _controller.text;
              ref.read(searchNotifierProvider.notifier).onSearchSubmitted(q);
              _focusNode.unfocus();
            },
            child: Container(
              margin: EdgeInsets.all(context.s(6)),
              width: context.s(44),
              height: context.s(44),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kSearchSecondary, kSearchPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(context.s(26)),
                boxShadow: [
                  BoxShadow(
                    color: kSearchSecondary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.search_rounded,
                  color: Colors.white, size: context.s(22)),
            ),
          ),
        ],
      ),
    );
  }
}
