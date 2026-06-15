import 'package:flutter/widgets.dart';

/// Low-level helpers for profile `State` classes (no UI).
abstract final class ProfileStateHelpers {
  ProfileStateHelpers._();

  /// Triggers a rebuild if [state] is still mounted (same as `if (mounted) setState(() {})`).
  static void rebuildIfMounted(State state) {
    if (!state.mounted) return;
    state.setState(() {});
  }
}
