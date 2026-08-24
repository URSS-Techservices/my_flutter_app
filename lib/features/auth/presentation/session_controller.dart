import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  return ref.watch(authRepositoryProvider).authState().asyncExpand((user) {
    if (user == null) {
      return Stream.value(const Session.loggedOut());
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snap) => _sessionFromUserDoc(user.uid, snap.data()));
  });
});

Session _sessionFromUserDoc(String uid, Map<String, dynamic>? data) {
  final raw = data == null
      ? null
      : (data['accountType'] ?? data['category'] ?? data['profileType'])
          ?.toString();
  // final kind = tryProfileKindFromAccountType(raw);
  var kind;
  if (kind == null) {
    return Session(status: SessionStatus.needsAccountType, uid: uid);
  }
  return Session(
    status: SessionStatus.ready,
    uid: uid,
    accountType: accountTypeString(kind),
  );
}

final authActionProvider =
    StateNotifierProvider<AuthActionController, AsyncValue<void>>((ref) {
  return AuthActionController(ref.watch(authRepositoryProvider));
});

class AuthActionController extends StateNotifier<AsyncValue<void>> {
  AuthActionController(this._repo) : super(const AsyncData(null));

  final AuthRepository _repo;

  Future<void> setAccountType(ProfileKind kind) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.setAccountType(uid: uid, kind: kind),
    );
  }

  Future<void> signOut() => _repo.signOut();
}
