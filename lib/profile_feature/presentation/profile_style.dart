import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';

/// Colors, text styles and sizes for the new profile pages.
/// Text styles are created once here instead of on every build.
abstract final class ProfileStyle {
  // Colors
  static const text = Color(0xFF111827);
  static const mutedText = Color(0xFF6B7280);
  static const divider = Color(0xFFE5E7EB);
  static const online = Color(0xFF22C55E);
  static const page = Colors.white;

  /// App brand colors (lavender). [primary] fills buttons; [primaryDark]
  /// is for text and icons on white so they stay readable.
  static const primary = HaloTheme.primary;
  static const primaryDark = HaloTheme.secondary;
  static const primaryLight = Color(0xFFEDE7F6);

  /// Text links: See All, Show more, Edit Links, Add Social Link.
  static const link = Color(0xFF1877F2);

  /// Edit button: pale sky-blue pill with iOS system blue text and icon.
  static const editBlue = Color(0xFF007AFF);
  static const editBlueLight = Color(0xFFE5F1FF);

  // Sizes
  static const coverHeight = 190.0;
  static const avatarSize = 112.0;
  static const sideGap = 16.0;
  static const cardRadius = 24.0;

  // Text
  static final name = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: text,
  );
  static final username = GoogleFonts.inter(fontSize: 14, color: mutedText);
  static final body = GoogleFonts.inter(fontSize: 14, height: 1.4, color: text);
  static final small = GoogleFonts.inter(fontSize: 13, color: mutedText);
  static final statNumber = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: text,
  );
  static final statLabel = GoogleFonts.inter(fontSize: 13, color: mutedText);
  static final button = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}
