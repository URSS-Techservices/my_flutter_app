import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/app_theme_mode.dart';
import 'package:halo/core/halo_theme.dart';
import 'package:halo/core/halo_toast.dart';
import 'package:halo/features/auth/presentation/auth_gate.dart';

/// Root MaterialApp: theme + top-level route. UI-only, no side effects.
class HaloApp extends StatelessWidget {
  const HaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: HaloToast.navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

ThemeData _lightTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: kLightBackground,
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: GoogleFonts.poppins(color: Colors.white),
      labelStyle: GoogleFonts.poppins(color: Colors.black87),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: kSecondaryColor,
      selectionColor: kPrimaryColor,
      selectionHandleColor: kSecondaryColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kSecondaryColor,
        side: const BorderSide(color: kSecondaryColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    ),
  );
}

ThemeData _darkTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: kDarkBackgroundBottom,
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade900,
      hintStyle: GoogleFonts.poppins(color: Colors.white70),
      labelStyle: GoogleFonts.poppins(color: Colors.white),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: kPrimaryColor,
      selectionColor: kPrimaryColor,
      selectionHandleColor: kPrimaryColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    ),
  );
}
