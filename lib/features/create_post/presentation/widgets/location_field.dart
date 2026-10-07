import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:halo/core/halo_theme.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/create_post/presentation/add_post_controller.dart';
import 'package:halo/features/create_post/services/location_service.dart';
import 'package:halo/features/create_post/services/places_service.dart';

const Color _fieldFill = Color(0xFFF7F4FE);
const Color _mutedText = Color(0xFF8A8499);

/// Location input. Typing searches Google Places ("Luck" → "Lucknow,
/// Uttar Pradesh"); the locate button fills it from the device's GPS.
class LocationField extends ConsumerStatefulWidget {
  final TextEditingController controller;

  const LocationField({super.key, required this.controller});

  @override
  ConsumerState<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends ConsumerState<LocationField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  int _queryId = 0;

  bool _isFetchingGps = false;
  bool _isSearching = false;
  List<PlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _clearSuggestions();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _setLocation(String value) =>
      ref.read(addPostControllerProvider.notifier).setLocation(value);

  void _clearSuggestions() {
    _debounce?.cancel();
    _queryId++;
    if (_suggestions.isEmpty && !_isSearching) return;
    setState(() {
      _suggestions = const [];
      _isSearching = false;
    });
  }

  void _onChanged(String value) {
    _setLocation(value);
    _debounce?.cancel();
    if (!PlacesService.isConfigured || value.trim().length < 2) {
      _clearSuggestions();
      setState(() {}); // refresh the clear button
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final id = ++_queryId;
    try {
      final results = await PlacesService.autocomplete(value);
      if (!mounted || id != _queryId) return;
      setState(() {
        _suggestions = results.take(5).toList();
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('LocationField: $e');
      if (!mounted || id != _queryId) return;
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
    }
  }

  void _select(PlaceSuggestion s) {
    final label = s.label;
    widget.controller
      ..text = label
      ..selection = TextSelection.collapsed(offset: label.length);
    _setLocation(label);
    _clearSuggestions();
    _focusNode.unfocus();
  }

  void _clearText() {
    widget.controller.clear();
    _setLocation('');
    _clearSuggestions();
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetchingGps) return;
    _focusNode.unfocus();
    _clearSuggestions();
    setState(() => _isFetchingGps = true);
    final result = await LocationService.fetchCurrentPlace();
    if (!mounted) return;
    setState(() => _isFetchingGps = false);

    if (!result.isSuccess) {
      HaloToast.show(result.error ?? 'Could not fetch location.');
      return;
    }
    widget.controller.text = result.place!;
    _setLocation(result.place!);
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: focused ? Colors.white : _fieldFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: focused ? kPrimaryColor : kPrimaryColor.withValues(alpha: 0.18),
              width: focused ? 1.6 : 1,
            ),
            boxShadow: focused
                ? [BoxShadow(color: kPrimaryColor.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))]
                : const [],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.location_on_rounded, color: focused ? kSecondaryColor : kPrimaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search a city or place',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: _mutedText),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor)),
                )
              else if (hasText)
                IconButton(
                  tooltip: 'Clear',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: _mutedText),
                  onPressed: _clearText,
                ),
              _LocateButton(loading: _isFetchingGps, onTap: _useCurrentLocation),
              const SizedBox(width: 8),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _suggestions.isEmpty || !focused
              ? const SizedBox(width: double.infinity)
              : _SuggestionList(suggestions: _suggestions, onSelect: _select),
        ),
      ],
    );
  }
}

class _LocateButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _LocateButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Use current location',
      child: Material(
        color: kPrimaryColor.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onTap,
          child: SizedBox(
            height: 38,
            width: 38,
            child: Center(
              child: loading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kSecondaryColor))
                  : const Icon(Icons.my_location_rounded, size: 19, color: kSecondaryColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelect;

  const _SuggestionList({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.14)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 62, color: kPrimaryColor.withValues(alpha: 0.10)),
            _SuggestionTile(suggestion: suggestions[i], onTap: () => onSelect(suggestions[i])),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('powered by Google', style: GoogleFonts.poppins(fontSize: 10, color: _mutedText)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({required this.suggestion, required this.onTap});

  /// Bolds the part of the name that matched what the user typed.
  List<TextSpan> _highlighted(String text) {
    final base = GoogleFonts.poppins(fontSize: 14.5, color: Colors.black87, fontWeight: FontWeight.w400);
    final bold = base.copyWith(fontWeight: FontWeight.w700, color: kSecondaryColor);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in suggestion.matches) {
      if (start < cursor || end > text.length || start >= end) continue;
      if (start > cursor) spans.add(TextSpan(text: text.substring(cursor, start), style: base));
      spans.add(TextSpan(text: text.substring(start, end), style: bold));
      cursor = end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(color: _fieldFill, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.place_outlined, size: 18, color: kSecondaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: _highlighted(suggestion.mainText)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (suggestion.secondaryText.isNotEmpty)
                    Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: _mutedText),
                    ),
                ],
              ),
            ),
            const Icon(Icons.north_west_rounded, size: 16, color: _mutedText),
          ],
        ),
      ),
    );
  }
}
