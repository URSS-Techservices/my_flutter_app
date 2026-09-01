import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:halo/core/session.dart';
import 'package:halo/features/auth/domain/auth_repository.dart';
import 'package:halo/features/auth/domain/phone_otp_session.dart';
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

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return;
    try {
      await _ensureEmailUserDoc(user);
    } catch (_) {}
    // Do not swallow this — a silent catch made signup look successful
    // while no email was actually sent.
    await user.sendEmailVerification();
  }

  /// Stub HALO doc for a brand-new email user. No accountType and
  /// onboardingCompleted stays false, so the gate sends them to categories
  /// after they verify.
  Future<void> _ensureEmailUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (doc.exists) return;
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      if (user.email != null) 'email_lower': user.email!.toLowerCase(),
      'loginType': 'email',
      'onboardingCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    await user.sendEmailVerification();
  }

  @override
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    final verified = refreshed?.emailVerified ?? false;
    // reload() does not fire authStateChanges, so nudge watchSession to
    // re-evaluate with the refreshed verification flag.
    if (!_refresh.isClosed) _refresh.add(null);
    return verified;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final name = username.trim();
    if (name.isEmpty) return false;
    final uid = _auth.currentUser?.uid;
    final lower = name.toLowerCase();
    final byLower = await _firestore
        .collection('users')
        .where('username_lower', isEqualTo: lower)
        .limit(1)
        .get();
    if (byLower.docs.any((d) => d.id != uid)) return false;
    // Older docs stored only the raw `username`.
    final byExact = await _firestore
        .collection('users')
        .where('username', isEqualTo: name)
        .limit(1)
        .get();
    return byExact.docs.every((d) => d.id == uid);
  }

  @override
  Future<void> completeProfileOnboarding(Map<String, dynamic> profile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final payload = <String, dynamic>{
      ...profile,
      'uid': user.uid,
      if (user.email != null) 'email': user.email,
      if (user.email != null) 'email_lower': user.email!.toLowerCase(),
      // Only flips true because the write below succeeded.
      'onboardingCompleted': true,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    };
    // Passwords are Firebase Auth's job. Never persist them on the user doc,
    // even if a caller accidentally includes them.
    payload.remove('password');
    payload.remove('confirmPassword');
    payload.remove('confirm_password');
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  /// Broadcasts a manual re-evaluation request (after an email reload).
  final StreamController<void> _refresh = StreamController<void>.broadcast();

  /// Only password-provider accounts must verify their email. Provider logins
  /// (Google / Apple / Phone) and custom-token OTP logins are already trusted.
  static bool _needsEmailVerification(User user) {
    final isPasswordUser =
        user.providerData.any((p) => p.providerId == 'password');
    return isPasswordUser && !user.emailVerified;
  }

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static bool _looksLikeOtp(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim());

  @override
  Stream<Session> watchSession() {
    // IMPORTANT: `asyncExpand` waits for the *previous* inner stream to finish
    // before consuming the next auth event. The Firestore `snapshots()` stream
    // below never completes, so a `null` user event from `signOut()` would be
    // buffered forever and the UI would stay logged in until the app is killed.
    // We therefore switch to explicit switchMap semantics: every auth change
    // cancels the previous user-doc subscription and starts a fresh one.
    final controller = StreamController<Session>();
    StreamSubscription<User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<void>? refreshSub;
    String? activeUid;
    Map<String, dynamic>? lastData;

    // Re-derive the session from the freshest Firebase user plus the last-known
    // user doc. Called on every auth change, doc change, and manual refresh.
    void emitForCurrentUser() {
      if (controller.isClosed) return;
      final user = _auth.currentUser;
      if (user == null) {
        controller.add(const Session.loggedOut());
        return;
      }
      controller.add(
        sessionFromUserDoc(
          user.uid,
          lastData,
          email: user.email,
          requiresEmailVerification: _needsEmailVerification(user),
        ),
      );
    }

    controller.onListen = () {
      refreshSub = _refresh.stream.listen((_) => emitForCurrentUser());

      authSub = _auth.authStateChanges().listen(
        (user) {
          // Cancel the previous user doc listener before starting a new one.
          userSub?.cancel();
          userSub = null;
          lastData = null;

          if (user == null) {
            activeUid = null;
            if (!controller.isClosed) {
              controller.add(const Session.loggedOut());
            }
            return;
          }

          final uid = user.uid;
          activeUid = uid;
          userSub = _firestore
              .collection('users')
              .doc(uid)
              .snapshots()
              .listen(
            (snap) {
              // Ignore late events from a doc we've since switched away from.
              if (activeUid != uid || controller.isClosed) return;
              lastData = snap.data();
              emitForCurrentUser();
            },
            onError: (Object e, StackTrace st) {
              if (!controller.isClosed) controller.addError(e, st);
            },
          );
        },
        onError: (Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
        },
      );
    };

    controller.onCancel = () async {
      await refreshSub?.cancel();
      await userSub?.cancel();
      await authSub?.cancel();
      activeUid = null;
    };

    return controller.stream;
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
  Future<void> clearAccountType() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    return _firestore.collection('users').doc(uid).set(
      {
        'accountType': FieldValue.delete(),
        'category': FieldValue.delete(),
        'profileType': FieldValue.delete(),
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
    if (googleAuth.idToken == null) {
      // Usually a SHA-1 / OAuth client mismatch for this build.
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Google sign-in failed. Check the app SHA-1 in Firebase.',
      );
    }
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
        if (user.email != null) 'email_lower': user.email!.toLowerCase(),
        'photoUrl': user.photoURL,
        'loginType': 'google',
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> signInWithApple() async {
    // No extra plugin needed: firebase_auth runs this natively on iOS 13+ and
    // hands off to a Custom Tab on Android.
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    try {
      final userCred = await _auth.signInWithProvider(provider);
      final user = userCred.user;
      if (user == null) return;
      await _ensureAppleUserDoc(user, userCred);
    } on FirebaseAuthException catch (e) {
      // Backing out of the Apple sheet or browser tab is not a failure.
      if (_isUserCancellation(e.code)) return;
      rethrow;
    }
  }

  Future<void> _ensureAppleUserDoc(User user, UserCredential cred) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    // Apple sends the real name only on the very first authorization, so it has
    // to be persisted now or it is gone for good. Email may be a
    // @privaterelay.appleid.com alias if the user chose to hide it.
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : _appleFullName(cred);

    if (!doc.exists) {
      await ref.set({
        'uid': user.uid,
        'name': name,
        'email': user.email,
        if (user.email != null) 'email_lower': user.email!.toLowerCase(),
        'loginType': 'apple',
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } else {
      final existingName = doc.data()?['name'];
      final hasName = existingName is String && existingName.trim().isNotEmpty;
      await ref.set(
        {
          // Never clobber a name the user has since edited themselves.
          if (!hasName && name != null) 'name': name,
          if (user.email != null) 'email': user.email,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    if (name != null && (user.displayName?.isEmpty ?? true)) {
      await user.updateDisplayName(name);
    }
  }

  /// Apple delivers the name split across the raw provider profile rather than
  /// on the Firebase user.
  static String? _appleFullName(UserCredential cred) {
    final profile = cred.additionalUserInfo?.profile;
    if (profile == null) return null;
    final parts = <String>[];
    for (final key in const ['given_name', 'givenName']) {
      final value = profile[key];
      if (value is String && value.trim().isNotEmpty) {
        parts.add(value.trim());
        break;
      }
    }
    for (final key in const ['family_name', 'familyName']) {
      final value = profile[key];
      if (value is String && value.trim().isNotEmpty) {
        parts.add(value.trim());
        break;
      }
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  static bool _isUserCancellation(String code) {
    return code == 'web-context-canceled' ||
        code == 'web-context-cancelled' ||
        code == 'canceled' ||
        code == 'cancelled' ||
        code == 'user-canceled' ||
        code == 'user-cancelled';
  }

  @override
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
    void Function(String verificationId)? onVerificationId,
  }) {
    final completer = Completer<PhoneOtpSession>();

    void settle(PhoneOtpSession session) {
      if (!completer.isCompleted) completer.complete(session);
    }

    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      // Android only: the SMS was read for us, so sign in without an OTP step.
      verificationCompleted: (credential) async {
        try {
          final cred = await _auth.signInWithCredential(credential);
          await _ensurePhoneUserDoc(cred.user!);
          settle(const PhoneOtpSession(autoVerified: true));
        } catch (_) {
          // Fall back to manual entry; codeSent/timeout still settles below.
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, token) {
        onVerificationId?.call(verificationId);
        settle(
          PhoneOtpSession(verificationId: verificationId, resendToken: token),
        );
      },
      // Fires ~60s after codeSent. This id supersedes the codeSent one, so it
      // must reach the caller even though the future already resolved.
      codeAutoRetrievalTimeout: (verificationId) {
        onVerificationId?.call(verificationId);
        settle(PhoneOtpSession(verificationId: verificationId));
      },
    );

    return completer.future;
  }

  @override
  Future<void> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final cred = await _auth.signInWithCredential(credential);
    await _ensurePhoneUserDoc(cred.user!);
  }

  /// First phone login creates the doc without an accountType, so
  /// OnboardingGate sends the user to the 3-category page.
  Future<void> _ensurePhoneUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    final phone = user.phoneNumber;
    if (!doc.exists) {
      await ref.set({
        'uid': user.uid,
        'phone': phone,
        // Existing screens look up accounts by `mobile`; keep both in sync.
        'mobile': phone,
        'loginType': 'phone',
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return;
    }
    await ref.set(
      {
        if (phone != null) 'phone': phone,
        if (phone != null) 'mobile': phone,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
