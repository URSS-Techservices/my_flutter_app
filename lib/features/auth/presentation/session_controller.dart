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

  Future<void> clearAccountType() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.clearAccountType());
  }

  Future<void> signInWithEmailOrUsername({
    required String identifier,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.signInWithEmailOrUsername(
        identifier: identifier,
        password: password,
      ),
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.signUpWithEmail(email: email, password: password),
    );
  }

  Future<void> sendEmailVerification() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendEmailVerification());
  }

  /// Reloads the user and returns whether the email is verified now. Errors are
  /// still surfaced through [state] for the UI to react to.
  Future<bool> reloadAndCheckEmailVerified() async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => _repo.reloadAndCheckEmailVerified());
    state = result.hasError ? AsyncError(result.error!, StackTrace.current)
        : const AsyncData(null);
    return result.value ?? false;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.sendPasswordResetEmail(email),
    );
  }

  Future<void> sendLoginOtp({required String identifier}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.sendLoginOtp(identifier: identifier),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithGoogle());
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithApple());
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signOut());
  }
}

/// Drives HALO profile onboarding (the step after the category page). Keeps the
/// business rule — only mark onboarding complete once the profile write
/// succeeds — out of the profile widgets.
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, AsyncValue<void>>((ref) {
  return OnboardingController(ref.watch(authRepositoryProvider));
});

class OnboardingController extends StateNotifier<AsyncValue<void>> {
  OnboardingController(this._repo) : super(const AsyncData(null));

  final AuthRepository _repo;

  Future<bool> isUsernameAvailable(String username) {
    return _repo.isUsernameAvailable(username);
  }

  /// Saves the profile and flips `onboardingCompleted`. Returns true only on a
  /// successful Firestore write, so callers can keep the user on the form and
  /// let them retry when it fails.
  Future<bool> completeOnboarding(Map<String, dynamic> profile) async {
    state = const AsyncLoading();
    final result =
        await AsyncValue.guard(() => _repo.completeProfileOnboarding(profile));
    state = result;
    return !result.hasError;
  }
}
