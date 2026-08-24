import 'package:flutter/material.dart';

/// Shared HALO color tokens. Import this instead of copying hex values.
abstract final class HaloTheme {
  static const Color primary = Color(0xFFA58CE3);
  static const Color secondary = Color(0xFF5B3FA3);
  static const Color lightBackground = Color(0xFFF4F1FB);
  static const Color darkTop = Color(0xFF111111);
  static const Color darkBottom = Color(0xFF050505);
}

const Color kPrimaryColor = HaloTheme.primary;
const Color kSecondaryColor = HaloTheme.secondary;
const Color kLightBackground = HaloTheme.lightBackground;
const Color kDarkBackgroundTop = HaloTheme.darkTop;
const Color kDarkBackgroundBottom = HaloTheme.darkBottom;
