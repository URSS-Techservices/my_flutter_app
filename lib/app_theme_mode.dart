import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kDarkModeKey = 'darkMode';

/// Global theme mode notifier. MyApp listens to this so the whole app
/// switches light/dark when the user toggles in Settings.
final ValueNotifier<ThemeMode> appThemeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

/// Loads saved dark mode from SharedPreferences and updates the notifier.
/// Call from main() before runApp so the app starts with the user's choice.
Future<void> loadAppThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_kDarkModeKey);
    if (dark == true) {
      appThemeModeNotifier.value = ThemeMode.dark;
    } else if (dark == false) {
      appThemeModeNotifier.value = ThemeMode.light;
    } else {
      appThemeModeNotifier.value = ThemeMode.system;
    }
  } catch (_) {
    appThemeModeNotifier.value = ThemeMode.system;
  }
}

/// Saves dark mode to SharedPreferences and updates the notifier (UI applies immediately).
void setAppThemeMode(bool darkMode) {
  appThemeModeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
  SharedPreferences.getInstance().then((prefs) {
    prefs.setBool(_kDarkModeKey, darkMode);
  });
}
