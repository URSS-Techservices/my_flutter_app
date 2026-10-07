import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/core/halo_theme.dart';

/// Shared light, modern look for category + profile onboarding.
abstract final class OnboardingUi {
  static const Color pageBg = Color(0xFFF9F7FC);
  static const Color fieldFill = Color(0xFFF7F5FA);
  static const Color fieldBorder = Color(0xFFE7E3ED);
  static const Color text = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF6B7280);
  static const double maxWidth = 560;

  static InputDecoration field({
    required BuildContext context,
    required String label,
    String? hint,
    IconData? icon,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(color: Colors.black38),
      filled: true,
      fillColor: fieldFill,
      prefixIcon: prefixIcon ??
          (icon == null ? null : Icon(icon, color: muted)),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorMaxLines: 4,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static Widget datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: kPrimaryColor,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: text,
        ),
      ),
      child: child!,
    );
  }

  static double pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 720) return 32;
    if (width >= 400) return 20;
    return 16;
  }
}
