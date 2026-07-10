import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInit;

  AuthService(this._googleSignIn) {
    _googleSignInInit = _initializeGoogleSignIn();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
    } catch (e) {
      debugPrint('Google Sign-In initialization failed: $e');
    }
  }

  Future<void> _ensureGoogleSignInReady() async {
    await _googleSignInInit;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInReady();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['https://www.googleapis.com/auth/drive'],
      );

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) return null;

      final authClient = googleUser.authorizationClient;
      final granted = await authClient.authorizeScopes(
        ['https://www.googleapis.com/auth/drive'],
      );
      if (granted == null) return null;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _googleSignInInit = _initializeGoogleSignIn();
    await _auth.signOut();
  }
}
