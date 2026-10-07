import 'package:flutter/widgets.dart';
import 'package:halo/profile_feature/presentation/aspirant_page.dart';
import 'package:halo/profile_feature/presentation/profile_skeleton.dart';

/// Turn a new profile page on per account type. While a flag is false the
/// old page is shown, so nothing else in the app is affected.
const useNewAspirantPage = true;

/// The new page for [accountType], or null to keep the old one.
/// [onBack] is for the Profile tab, where back should go to Home.
Widget? newProfilePageFor(
  String accountType,
  String profileUserId, {
  VoidCallback? onBack,
}) {
  final type = accountType.toLowerCase();
  if (useNewAspirantPage && type != 'guru' && type != 'wellness') {
    return AspirantPage(profileUserId: profileUserId, onBack: onBack);
  }
  return null;
}

/// Loading look while the account type is checked: the same skeleton the
/// new page shows, so opening a profile looks like one smooth step.
/// Null keeps the old loader.
Widget? newProfileLoading() =>
    useNewAspirantPage ? const ProfileSkeleton() : null;
