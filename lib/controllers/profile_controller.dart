import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/models/user_model.dart';
import 'package:halo/repositories/profile_repository.dart';

class ProfileState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const ProfileState({
    required this.user,
    required this.loading,
    required this.error,
  });

  factory ProfileState.initial() =>
      const ProfileState(user: null, loading: true, error: null);
}

class ProfileController extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  ProfileController(this._repository) : super(ProfileState.initial());

  Future<void> load(String userId) async {
    try {
      state = const ProfileState(user: null, loading: true, error: null);
      await _repository.watchUser(userId).first.then((u) {
        state = ProfileState(user: u, loading: false, error: null);
      });
    } catch (e) {
      state = ProfileState(user: null, loading: false, error: e.toString());
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  return ProfileController(ref.watch(profileRepositoryProvider));
});

final profileStreamProvider =
    StreamProvider.family<UserModel?, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).watchUser(userId);
});
