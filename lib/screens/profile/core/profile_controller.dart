import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/controllers/profile_controller.dart';
import 'package:halo/screens/profile/core/profile_model.dart';

/// Full `users/{id}` document as [ProfileData] (includes `extra` for guru/wellness fields).
/// Uses the same [ProfileRepository] instance as [profileStreamProvider].
final unifiedProfileDataProvider =
    StreamProvider.family<ProfileData?, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).watchProfileData(userId);
});
