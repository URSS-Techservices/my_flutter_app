import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:halo/config/firebase_web_config.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.onSignedIn});

  /// Called after Firebase auth succeeds (e.g. reset startup routing cache).
  final VoidCallback? onSignedIn;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isSigningIn = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _googleSignIn = FirebaseWebConfig.createGoogleSignIn();

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);

    try {
      // 1️⃣ Google Account Picker
      final GoogleSignInAccount? googleUser =
      await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isSigningIn = false);
        return;
      }

      // 2️⃣ Authentication
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // 3️⃣ Firebase Credential (OLD SAFE WAY)
      final AuthCredential credential =
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // 4️⃣ Sign in to Firebase
      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);

      final User user = userCredential.user!;

      // 5️⃣ Save to Firestore (first login only)
      final userRef =
      _firestore.collection('users').doc(user.uid);

      final doc = await userRef.get();

      if (!doc.exists) {
        await userRef.set({
          'uid': user.uid,
          'name': user.displayName,
          'email': user.email,
          'photoUrl': user.photoURL,
          'loginType': 'google',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      widget.onSignedIn?.call();
      // AuthGate listens to authStateChanges and routes automatically.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_googleAuthMessage(e))),
      );
      debugPrint('❌ Google Sign-In Error: $e');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed')),
      );
      debugPrint('❌ Google Sign-In Error: $e');
    } finally {
      setState(() => _isSigningIn = false);
    }
  }

  String _googleAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email.';
      case 'invalid-credential':
        return 'Google sign-in credentials are invalid. Try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled for this app.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Google Sign-In failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSigningIn ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.grey),
        ),
        child: _isSigningIn
            ? const CircularProgressIndicator()
            : const Text('Sign in with Google'),
      ),
    );
  }
}
