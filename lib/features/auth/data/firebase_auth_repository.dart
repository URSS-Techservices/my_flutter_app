import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/domain/auth_repository.dart';
import 'package:halo/features/auth/domain/session_mapper.dart';
import 'package:halo/screens/profile/core/profile_type.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn =
            googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static bool _looksLikeOtp(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim());

  @override
  Stream<Session> watchSession() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(const Session.loggedOut());
      }
      return _firestore.collection('users').doc(user.uid).snapshots().map(
            (snap) => sessionFromUserDoc(user.uid, snap.data()),
          );
    });
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google sign-out is best-effort. Firebase sign-out below is what actually
      // clears the session for our OnboardingGate.
    }
    await _auth.signOut();
  }

  @override
  Future<void> setAccountType(ProfileKind kind) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final type = accountTypeString(kind);
    final label = type[0].toUpperCase() + type.substring(1);
    return _firestore.collection('users').doc(uid).set(
      {
        'uid': uid,
        'accountType': type,
        'category': label,
        'profileType': type,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> sendLoginOtp({required String identifier}) async {
    try {
      await _functions.httpsCallable('sendLoginOtp').call({
        'identifier': identifier.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'Could not send OTP.',
      );
    }
  }

  @override
  Future<void> signInWithEmailOrUsername({
    required String identifier,
    required String password,
  }) async {
    final secret = password.trim();
    if (_looksLikeOtp(secret)) {
      await _signInWithOtp(identifier: identifier, otp: secret);
      return;
    }
    final id = identifier.trim();
    final email = id.contains('@') ? id : await _resolveEmail(id);
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _touchLastSeen(cred.user!.uid);
  }

  Future<void> _signInWithOtp({
    required String identifier,
    required String otp,
  }) async {
    try {
      final result = await _functions.httpsCallable('verifyLoginOtp').call({
        'identifier': identifier.trim(),
        'otp': otp,
      });
      final data = result.data;
      final token = data is Map ? data['token']?.toString() : null;
      if (token == null || token.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid OTP.',
        );
      }
      final cred = await _auth.signInWithCustomToken(token);
      await _touchLastSeen(cred.user!.uid);
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'Invalid OTP.',
      );
    }
  }

  Future<void> _touchLastSeen(String uid) {
    return _firestore.collection('users').doc(uid).set(
      {'lastSeen': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<String> _resolveEmail(String identifier) async {
    var snap = await _firestore
        .collection('users')
        .where('username', isEqualTo: identifier)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      snap = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: identifier)
          .limit(1)
          .get();
    }
    if (snap.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not found.',
      );
    }
    final data = snap.docs.first.data();
    final email = data['email'];
    if (email is! String || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Account has no email on file.',
      );
    }
    return email;
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user!;
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'loginType': 'google',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
