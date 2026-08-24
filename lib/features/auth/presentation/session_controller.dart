import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/data/firebase_auth_repository.dart';
import 'package:halo/features/auth/domain/auth_repository.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

/// One stream for routing: logged out / pick type / home.
final sessionProvider = StreamProvider<Session>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});

final authActionProvider =
    StateNotifierProvider<AuthActionController, AsyncValue<void>>((ref) {
  return AuthActionController(ref.watch(authRepositoryProvider));
});

class AuthActionController extends StateNotifier<AsyncValue<void>> {
  AuthActionController(this._repo) : super(const AsyncData(null));

  final AuthRepository _repo;

  Future<void> setAccountType(ProfileKind kind) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.setAccountType(kind));
  }

  Future<void> signOut() => _repo.signOut();
}
