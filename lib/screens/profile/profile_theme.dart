import 'package:flutter/material.dart';

/// Shared layout and accent tokens for aspirant, guru, and wellness profile headers.
abstract final class ProfileLayout {
  static const double coverHeight = 220;
  static const double avatarSize = 90;
  static const double avatarOverlap = 30;

  /// Space below the collapsed cover before identity row (shared by all profiles).
  static const double identityColumnTopInset = avatarOverlap + 18;
  static const Color lavender = Color(0xFFA58CE3);
  static const Color deepLavender = Color(0xFF6D4DB3);
  static const Color bg = Color(0xFFF4F1FB);
  static const Color chipBg = Color(0xFFEDE7F6);
}
