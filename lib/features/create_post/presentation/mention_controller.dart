import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MentionState {
  final List<Map<String, dynamic>> suggestions;
  final bool isLoading;

  const MentionState({this.suggestions = const [], this.isLoading = false});

  bool get isVisible => suggestions.isNotEmpty;
}

/// Debounced `@mention` username search, isolated from the rest of the post
/// draft so typing in the caption doesn't rebuild the media grid or vice
/// versa, and so a fast typist doesn't fire a Firestore query per keystroke.
class MentionController extends StateNotifier<MentionState> {
  MentionController() : super(const MentionState());

  Timer? _debounce;
  int _requestId = 0;

  void onCaptionChanged(String text, int cursorPos) {
    if (cursorPos <= 0 || cursorPos > text.length) {
      _reset();
      return;
    }
    final before = text.substring(0, cursorPos);
    final at = before.lastIndexOf('@');
    if (at == -1) {
      _reset();
      return;
    }
    if (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1])) {
      _reset();
      return;
    }
    final query = before.substring(at + 1);
    if (query.length < 2) {
      _reset();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query.toLowerCase()));
  }

  void _reset() {
    _debounce?.cancel();
    if (state.suggestions.isNotEmpty || state.isLoading) {
      state = const MentionState();
    }
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower', isGreaterThanOrEqualTo: query, isLessThanOrEqualTo: '$query')
          .limit(5)
          .get();
      if (requestId != _requestId) return;
      final results = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(growable: false);
      state = MentionState(suggestions: results);
    } catch (_) {
      if (requestId != _requestId) return;
      state = const MentionState();
    }
  }

  void clear() {
    _debounce?.cancel();
    state = const MentionState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final mentionControllerProvider =
    StateNotifierProvider.autoDispose<MentionController, MentionState>(
  (ref) => MentionController(),
);
