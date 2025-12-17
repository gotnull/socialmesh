import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Provider for the Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Stream provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Provider for the current user (nullable)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Provider to check if user is signed in
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Service for authentication operations
class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => currentUser != null;

  /// Get the current user's ID token for API requests
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  /// Sign in anonymously (for basic functionality)
  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Create a new account with email and password
  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign in was cancelled',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  /// Sign in with Apple
  Future<UserCredential> signInWithApple() async {
    // Generate nonce for security
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // Apple only sends name on first sign-in, so save it if available
    if (appleCredential.givenName != null &&
        userCredential.user?.displayName == null) {
      final fullName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();
      if (fullName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(fullName);
      }
    }

    return userCredential;
  }

  /// Generate a random nonce string
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// SHA256 hash of a string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if Apple Sign-In is available (iOS/macOS only)
  Future<bool> isAppleSignInAvailable() async {
    if (!Platform.isIOS && !Platform.isMacOS) return false;
    return SignInWithApple.isAvailable();
  }

  /// Update the user's display name
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.reload();
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete the current user's account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}

/// Provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AuthService(auth);
});

/// Provider to get user's display name
final userDisplayNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 'Anonymous';
  return user.displayName ?? user.email?.split('@').first ?? 'Anonymous';
});
