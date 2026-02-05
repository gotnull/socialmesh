// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/logging.dart';
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

  /// Log user info for debugging (masks sensitive data)
  void _logUserInfo(String context, User? user) {
    if (user == null) {
      AppLogging.auth('$context - User: null');
      return;
    }
    final email = user.email;
    final maskedEmail = email != null
        ? '${email.substring(0, email.indexOf('@').clamp(0, 3))}***@${email.split('@').last}'
        : 'none';
    AppLogging.auth(
      '$context - User: uid=${user.uid.substring(0, 8)}..., '
      'email=$maskedEmail, isAnonymous=${user.isAnonymous}, '
      'providers=${user.providerData.map((p) => p.providerId).join(", ")}',
    );
  }

  /// Get the current user's ID token for API requests
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.auth('getIdToken - No user signed in');
      return null;
    }
    AppLogging.auth(
      'getIdToken - Fetching token (forceRefresh=$forceRefresh) for uid=${user.uid.substring(0, 8)}...',
    );
    try {
      final token = await user.getIdToken(forceRefresh);
      AppLogging.auth(
        'getIdToken - ✅ Token fetched (length=${token?.length ?? 0})',
      );
      return token;
    } catch (e) {
      AppLogging.auth('getIdToken - ❌ Error: $e');
      rethrow;
    }
  }

  /// Sign in anonymously (for basic functionality)
  Future<UserCredential> signInAnonymously() async {
    AppLogging.auth('signInAnonymously - START');
    try {
      final credential = await _auth.signInAnonymously();
      _logUserInfo('signInAnonymously - ✅ SUCCESS', credential.user);
      return credential;
    } catch (e) {
      AppLogging.auth('signInAnonymously - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final maskedEmail =
        '${email.substring(0, email.indexOf('@').clamp(0, 3))}***@${email.split('@').last}';
    AppLogging.auth('signInWithEmail - START - email=$maskedEmail');
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logUserInfo('signInWithEmail - ✅ SUCCESS', credential.user);
      return credential;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('signInWithEmail - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('signInWithEmail - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Create a new account with email and password
  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    final maskedEmail =
        '${email.substring(0, email.indexOf('@').clamp(0, 3))}***@${email.split('@').last}';
    AppLogging.auth('createAccount - START - email=$maskedEmail');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logUserInfo('createAccount - ✅ SUCCESS', credential.user);
      return credential;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('createAccount - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('createAccount - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Sign in with Google using google_sign_in v7 API
  ///
  /// v7 separates authentication (identity) from authorization (access tokens).
  /// For Firebase Auth, we only need the idToken (identity proof).
  /// The accessToken is optional and only needed for Google API access.
  ///
  /// This implementation uses idToken-only authentication to avoid
  /// showing two separate sign-in prompts to the user.
  Future<UserCredential> signInWithGoogle() async {
    AppLogging.auth('signInWithGoogle - START');

    // Step 1: Get the singleton and initialize
    // initialize() is idempotent - safe to call multiple times
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();
    AppLogging.auth('signInWithGoogle - GoogleSignIn initialized');

    // Step 2: Authenticate - this proves user identity and returns idToken
    // authenticate() shows the Google sign-in UI if needed
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        AppLogging.auth('signInWithGoogle - ❌ CANCELLED by user');
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google sign in was cancelled',
        );
      }
      AppLogging.auth('signInWithGoogle - ❌ GoogleSignInException: ${e.code}');
      rethrow;
    }
    AppLogging.auth(
      'signInWithGoogle - Google user obtained: ${googleUser.email}',
    );

    // Step 3: Get idToken from authentication
    // In v7, authentication provides idToken (identity proof)
    // This is sufficient for Firebase Auth - no accessToken needed
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      AppLogging.auth('signInWithGoogle - ❌ No idToken received');
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google sign in did not return an ID token',
      );
    }
    AppLogging.auth('signInWithGoogle - idToken obtained');

    // Step 4: Create Firebase credential with idToken only
    // accessToken is null - Firebase Auth works fine without it
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    try {
      final userCredential = await _auth.signInWithCredential(credential);
      _logUserInfo('signInWithGoogle - ✅ SUCCESS', userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('signInWithGoogle - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('signInWithGoogle - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<UserCredential> signInWithApple() async {
    AppLogging.auth('signInWithApple - START');

    // Generate nonce for security
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);
    AppLogging.auth('signInWithApple - Nonce generated');

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      AppLogging.auth(
        'signInWithApple - Apple credential obtained (email provided: ${appleCredential.email != null})',
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      _logUserInfo('signInWithApple - ✅ SUCCESS', userCredential.user);

      // Apple only sends name on first sign-in, so save it if available
      if (appleCredential.givenName != null &&
          userCredential.user?.displayName == null) {
        final fullName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (fullName.isNotEmpty) {
          AppLogging.auth(
            'signInWithApple - Updating display name to: $fullName',
          );
          await userCredential.user?.updateDisplayName(fullName);
        }
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      AppLogging.auth('signInWithApple - ❌ APPLE ERROR: code=${e.code}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('signInWithApple - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('signInWithApple - ❌ ERROR: $e');
      rethrow;
    }
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
    AppLogging.auth('signInWithGitHub - START');
    final githubProvider = GithubAuthProvider();
    githubProvider.addScope('read:user');
    githubProvider.addScope('user:email');

    try {
      UserCredential userCredential;
      // Use redirect on web, popup on mobile
      if (Platform.isIOS || Platform.isAndroid) {
        AppLogging.auth('signInWithGitHub - Using signInWithProvider (mobile)');
        userCredential = await _auth.signInWithProvider(githubProvider);
      } else {
        AppLogging.auth('signInWithGitHub - Using signInWithPopup (web)');
        userCredential = await _auth.signInWithPopup(githubProvider);
      }
      _logUserInfo('signInWithGitHub - ✅ SUCCESS', userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('signInWithGitHub - ❌ AUTH ERROR: code=${e.code}');
      if (e.code == 'account-exists-with-different-credential' &&
          e.credential != null) {
        final email = e.email;
        if (email != null) {
          AppLogging.auth(
            'signInWithGitHub - Account linking required for email: $email',
          );
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
    } catch (e) {
      AppLogging.auth('signInWithGitHub - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Link a pending credential to the current user
  Future<UserCredential> linkPendingCredential(
    AuthCredential credential,
  ) async {
    AppLogging.auth('linkPendingCredential - START');
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.auth('linkPendingCredential - ❌ No current user');
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in',
      );
    }
    try {
      final userCredential = await user.linkWithCredential(credential);
      _logUserInfo('linkPendingCredential - ✅ SUCCESS', userCredential.user);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('linkPendingCredential - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('linkPendingCredential - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Check if Apple Sign-In is available (iOS/macOS only)
  Future<bool> isAppleSignInAvailable() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      AppLogging.auth('isAppleSignInAvailable - false (not iOS/macOS)');
      return false;
    }
    final available = await SignInWithApple.isAvailable();
    AppLogging.auth('isAppleSignInAvailable - $available');
    return available;
  }

  /// Update the user's display name
  Future<void> updateDisplayName(String displayName) async {
    AppLogging.auth('updateDisplayName - START - newName=$displayName');
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.updateDisplayName(displayName);
        await user.reload();
        AppLogging.auth('updateDisplayName - ✅ SUCCESS');
      } catch (e) {
        AppLogging.auth('updateDisplayName - ❌ ERROR: $e');
        rethrow;
      }
    } else {
      AppLogging.auth('updateDisplayName - ❌ No current user');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final maskedEmail =
        '${email.substring(0, email.indexOf('@').clamp(0, 3))}***@${email.split('@').last}';
    AppLogging.auth('sendPasswordResetEmail - START - email=$maskedEmail');
    try {
      await _auth.sendPasswordResetEmail(email: email);
      AppLogging.auth('sendPasswordResetEmail - ✅ SUCCESS');
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('sendPasswordResetEmail - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('sendPasswordResetEmail - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    final user = _auth.currentUser;
    _logUserInfo('signOut - START', user);
    try {
      // Remove FCM token before signing out
      AppLogging.auth('signOut - Removing FCM token...');
      await PushNotificationService().onUserSignOut();
      AppLogging.auth('signOut - FCM token removed, signing out...');
      await _auth.signOut();
      AppLogging.auth('signOut - ✅ SUCCESS');
    } catch (e) {
      AppLogging.auth('signOut - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Re-authenticate the current user with Google using v7 API
  ///
  /// Re-authentication is required for sensitive operations like:
  /// - Deleting account
  /// - Changing email/password
  /// - Linking new auth providers
  ///
  /// Uses the same v7 flow as signInWithGoogle but calls
  /// reauthenticateWithCredential instead of signInWithCredential.
  ///
  /// Uses idToken-only authentication to avoid double sign-in prompts.
  Future<void> reauthenticateWithGoogle() async {
    AppLogging.auth('reauthenticateWithGoogle - START');
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.auth('reauthenticateWithGoogle - ❌ No current user');
      return;
    }

    // Step 1: Initialize singleton
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();

    // Step 2: Authenticate to get user identity
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        AppLogging.auth('reauthenticateWithGoogle - ❌ CANCELLED by user');
        throw FirebaseAuthException(
          code: 'reauthentication-cancelled',
          message: 'Google re-authentication was cancelled',
        );
      }
      rethrow;
    }
    AppLogging.auth('reauthenticateWithGoogle - Google user obtained');

    // Step 3: Get idToken from authentication
    // idToken is sufficient for Firebase - no accessToken needed
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      AppLogging.auth('reauthenticateWithGoogle - ❌ No idToken received');
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google sign in did not return an ID token',
      );
    }

    // Step 4: Create credential with idToken only and re-authenticate
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    try {
      await user.reauthenticateWithCredential(credential);
      AppLogging.auth('reauthenticateWithGoogle - ✅ SUCCESS');
    } on FirebaseAuthException catch (e) {
      AppLogging.auth(
        'reauthenticateWithGoogle - ❌ AUTH ERROR: code=${e.code}',
      );
      rethrow;
    } catch (e) {
      AppLogging.auth('reauthenticateWithGoogle - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Re-authenticate the current user with Apple
  Future<void> reauthenticateWithApple() async {
    AppLogging.auth('reauthenticateWithApple - START');
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.auth('reauthenticateWithApple - ❌ No current user');
      return;
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      AppLogging.auth('reauthenticateWithApple - Apple credential obtained');

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      await user.reauthenticateWithCredential(oauthCredential);
      AppLogging.auth('reauthenticateWithApple - ✅ SUCCESS');
    } on SignInWithAppleAuthorizationException catch (e) {
      AppLogging.auth(
        'reauthenticateWithApple - ❌ APPLE ERROR: code=${e.code}',
      );
      rethrow;
    } on FirebaseAuthException catch (e) {
      AppLogging.auth('reauthenticateWithApple - ❌ AUTH ERROR: code=${e.code}');
      rethrow;
    } catch (e) {
      AppLogging.auth('reauthenticateWithApple - ❌ ERROR: $e');
      rethrow;
    }
  }

  /// Re-authenticate the current user with their primary provider
  Future<void> reauthenticate() async {
    AppLogging.auth('reauthenticate - START');
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.auth('reauthenticate - ❌ No current user');
      return;
    }

    final providers = user.providerData.map((info) => info.providerId).toList();
    AppLogging.auth('reauthenticate - User providers: $providers');

    if (providers.contains('google.com')) {
      AppLogging.auth('reauthenticate - Using Google provider');
      await reauthenticateWithGoogle();
    } else if (providers.contains('apple.com')) {
      AppLogging.auth('reauthenticate - Using Apple provider');
      await reauthenticateWithApple();
    } else {
      AppLogging.auth('reauthenticate - ❌ No supported provider found');
      throw FirebaseAuthException(
        code: 'no-supported-provider',
        message: 'No supported provider found for re-authentication',
      );
    }
  }

  /// Delete the current user's account (with automatic re-authentication)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    _logUserInfo('deleteAccount - START', user);
    if (user != null) {
      try {
        AppLogging.auth('deleteAccount - Attempting direct deletion...');
        await user.delete();
        AppLogging.auth('deleteAccount - ✅ SUCCESS (direct deletion)');
      } on FirebaseAuthException catch (e) {
        AppLogging.auth('deleteAccount - AUTH ERROR: code=${e.code}');
        if (e.code == 'requires-recent-login') {
          AppLogging.auth(
            'deleteAccount - Requires recent login, re-authenticating...',
          );
          // Re-authenticate and try again
          await reauthenticate();
          AppLogging.auth(
            'deleteAccount - Re-authenticated, attempting deletion again...',
          );
          await user.delete();
          AppLogging.auth(
            'deleteAccount - ✅ SUCCESS (after re-authentication)',
          );
        } else {
          AppLogging.auth('deleteAccount - ❌ AUTH ERROR: code=${e.code}');
          rethrow;
        }
      } catch (e) {
        AppLogging.auth('deleteAccount - ❌ ERROR: $e');
        rethrow;
      }
    } else {
      AppLogging.auth('deleteAccount - ❌ No current user to delete');
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
