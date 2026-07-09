import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import 'package:documents_organizer/providers/auth_provider.dart';

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive',
    ],
  );
});

final authServiceProvider = Provider((ref) {
  final googleSignIn = ref.watch(googleSignInProvider);
  return AuthService(googleSignIn);
});

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
