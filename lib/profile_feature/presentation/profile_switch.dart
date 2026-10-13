import 'package:flutter/widgets.dart';
import 'package:halo/profile_feature/presentation/aspirant_page.dart';
import 'package:halo/profile_feature/presentation/guru_page.dart';
import 'package:halo/profile_feature/presentation/profile_skeleton.dart';
import 'package:halo/profile_feature/presentation/wellness_page.dart';

/// Turn a new profile page on per account type. While a flag is false the
/// old page is shown, so nothing else in the app is affected.
const useNewAspirantPage = true;
const useNewGuruPage = true;
const useNewWellnessPage = true;

/// The new page for [accountType], or null to keep the old one.
/// [onBack] is for the Profile tab, where back should go to Home.
Widget? newProfilePageFor(
  String accountType,
  String profileUserId, {
  VoidCallback? onBack,
}) {
  return switch (accountType.toLowerCase()) {
    'guru' when useNewGuruPage =>
      GuruPage(profileUserId: profileUserId, onBack: onBack),
    'wellness' when useNewWellnessPage =>
      WellnessPage(profileUserId: profileUserId, onBack: onBack),
    'wellness' => null,
    'guru' => null,
    _ when useNewAspirantPage =>
      AspirantPage(profileUserId: profileUserId, onBack: onBack),
    _ => null,
  };
}

/// Loading look while the account type is checked: the same skeleton the
/// new pages show, so opening a profile looks like one smooth step.
/// Null keeps the old loader.
Widget? newProfileLoading() =>
    useNewAspirantPage || useNewGuruPage || useNewWellnessPage
        ? const ProfileSkeleton()
        : null;
