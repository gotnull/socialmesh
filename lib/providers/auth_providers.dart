import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/notifications/push_notification_service.dart';

/// Exception thrown when account linking is required
/// (e.g., GitHub sign-in with an email that's already linked to Google)
class AccountLinkingRequiredException implements Exception {
  final String email;
  final AuthCredential pendingCredential;
  final List<String> existingProviders;

  AccountLinkingRequiredException({
    required this.email,
    required this.pendingCredential,
    required this.existingProviders,
  });

  String get message =>
      'Account exists with different credential. Sign in with ${existingProviders.join(" or ")} to link GitHub.';
}

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

  /// Sign in with GitHub
  /// Note: GitHub is an "untrusted" provider in Firebase Auth.
  /// If the user already signed in with a "trusted" provider (Google, Apple)
  /// using the same email, this will throw 'account-exists-with-different-credential'.
  /// In that case, we need to link the GitHub credential to the existing account.
  Future<UserCredential> signInWithGitHub() async {
    final githubProvider = GithubAuthProvider();
    githubProvider.addScope('read:user');
    githubProvider.addScope('user:email');

    try {
      // Use redirect on web, popup on mobile
      if (Platform.isIOS || Platform.isAndroid) {
        return await _auth.signInWithProvider(githubProvider);
      } else {
        return await _auth.signInWithPopup(githubProvider);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' &&
          e.credential != null) {
        final email = e.email;
        if (email != null) {
          // Store credential for linking after user signs in with existing provider
          // We infer the providers from the error - typically google.com or apple.com
          throw AccountLinkingRequiredException(
            email: email,
            pendingCredential: e.credential!,
            existingProviders: [
              'google.com',
              'apple.com',
            ], // Most likely providers
          );
        }
      }
      rethrow;
    }
  }

  /// Link a pending credential to the current user
  Future<UserCredential> linkPendingCredential(
    AuthCredential credential,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in',
      );
    }
    return user.linkWithCredential(credential);
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
    // Remove FCM token before signing out
    await PushNotificationService().onUserSignOut();
    await _auth.signOut();
  }

  /// Re-authenticate the current user with Google
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'reauthentication-cancelled',
        message: 'Google re-authentication was cancelled',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  /// Re-authenticate the current user with Apple
  Future<void> reauthenticateWithApple() async {
    final user = _auth.currentUser;
    if (user == null) return;

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

    await user.reauthenticateWithCredential(oauthCredential);
  }

  /// Re-authenticate the current user with their primary provider
  Future<void> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final providers = user.providerData.map((info) => info.providerId).toList();

    if (providers.contains('google.com')) {
      await reauthenticateWithGoogle();
    } else if (providers.contains('apple.com')) {
      await reauthenticateWithApple();
    } else {
      throw FirebaseAuthException(
        code: 'no-supported-provider',
        message: 'No supported provider found for re-authentication',
      );
    }
  }

  /// Delete the current user's account (with automatic re-authentication)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // Re-authenticate and try again
          await reauthenticate();
          await user.delete();
        } else {
          rethrow;
        }
      }
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
