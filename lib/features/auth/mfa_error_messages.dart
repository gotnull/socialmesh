// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../core/logging.dart';

/// Maps Firebase Auth error codes to friendly, user-facing messages
/// for MFA enrollment, verification, and management flows.
///
/// Error codes sourced from:
/// - Firebase Auth JS SDK reference (AuthErrorCodes)
/// - firebase_auth Flutter plugin (FlutterFirebaseAuthPluginException.java)
/// - firebase_auth_platform_interface (exception.dart)
String friendlyMFAErrorCode(String code) {
  return switch (code) {
    // ── Wrong / invalid verification code ─────────────────────────────
    'invalid-verification-code' =>
      'That code is incorrect. Please check and try again.',

    // Newer Firebase SDK versions may unify under invalid-credential
    'invalid-credential' || 'INVALID_CREDENTIAL' =>
      'The code you entered is incorrect or has expired. Please try again.',

    // ── Code expired ──────────────────────────────────────────────────
    'session-expired' || 'code-expired' =>
      'The verification code has expired. Please request a new one.',

    // ── Invalid session / verification ID ─────────────────────────────
    'invalid-verification-id' || 'missing-verification-id' =>
      'Your verification session has expired. Please request a new code.',

    'invalid-multi-factor-session' || 'missing-multi-factor-session' =>
      'Your sign-in session has expired. Please start the sign-in again.',

    // ── Phone provider not enabled ────────────────────────────────────
    'operation-not-allowed' =>
      'Phone verification is not enabled. Please contact support.',

    // ── Invalid phone number format ───────────────────────────────────
    'invalid-phone-number' =>
      'Please enter a valid phone number with country code '
          '(e.g. +1 234 567 890).',

    // ── Rate limiting ─────────────────────────────────────────────────
    'too-many-requests' =>
      'Too many attempts. Please wait a few minutes and try again.',

    // ── No user signed in ─────────────────────────────────────────────
    'no-current-user' => 'Please sign in first to manage two-factor auth.',

    // ── MFA already enrolled ──────────────────────────────────────────
    'second-factor-already-in-use' =>
      'This phone number is already enrolled for two-factor auth.',

    // ── Max second factors reached ────────────────────────────────────
    'maximum-second-factor-count-exceeded' =>
      'You have reached the maximum number of second factors.',

    // ── Unsupported first factor ──────────────────────────────────────
    'unsupported-first-factor' =>
      'Your sign-in method does not support two-factor auth.',

    // ── Phone number already linked ───────────────────────────────────
    'credential-already-in-use' =>
      'This phone number is already used by another account.',

    // ── Re-authentication required ────────────────────────────────────
    // Auto-re-auth is attempted first; this message is a fallback if it fails.
    'requires-recent-login' || 'unenroll-failed' =>
      'Re-authentication failed. Please sign out, sign back in, '
          'and try again.',

    // ── User cancelled re-authentication ──────────────────────────────
    'reauthentication-cancelled' =>
      'Re-authentication was cancelled. Please try again.',

    // ── Wrong account selected during re-authentication ───────────────
    'wrong-account-selected' || 'user-mismatch' =>
      'That account doesn\'t match the one you\'re signed into. '
          'Please try again and select the correct account.',

    // ── Network issues ────────────────────────────────────────────────
    'network-request-failed' =>
      'No internet connection. Please check your network and try again.',

    // ── App verification / reCAPTCHA ──────────────────────────────────
    'app-not-authorized' ||
    'captcha-check-failed' => 'App verification failed. Please try again.',

    // ── Missing phone number ──────────────────────────────────────────
    'missing-phone-number' => 'Please enter your phone number.',

    // ── Missing verification code ─────────────────────────────────────
    'missing-verification-code' =>
      'Please enter the verification code sent to your phone.',

    // ── Verification failed ───────────────────────────────────────────
    'verification-failed' =>
      'Phone verification failed. Please check your number and try again.',

    // ── User disabled ─────────────────────────────────────────────────
    'user-disabled' =>
      'This account has been disabled. Please contact support.',

    // ── User cancelled ────────────────────────────────────────────────
    'web-context-cancelled' ||
    'user-cancelled' => 'Verification was cancelled.',

    // ── Quota exceeded ────────────────────────────────────────────────
    'quota-exceeded' =>
      'Service temporarily unavailable. Please try again later.',

    // ── MFA info not found ────────────────────────────────────────────
    'multi-factor-info-not-found' =>
      'Two-factor authentication info not found. '
          'Please re-enroll your second factor.',

    // ── Second factor required (should not normally surface to user) ──
    'second-factor-required' =>
      'Two-factor verification is required to complete sign-in.',

    // ── MFA sign-in resolution failed ─────────────────────────────────
    'resolve-signin-failed' =>
      'The verification code is incorrect or has expired. '
          'Please try again or request a new code.',

    // ── Invalid app credential (APNs / reCAPTCHA) ─────────────────────
    'invalid-app-credential' =>
      'App verification failed. Please restart the app and try again.',

    'missing-app-credential' =>
      'App verification is not configured. Please try again later.',

    // ── Missing client identifier ─────────────────────────────────────
    'missing-client-identifier' =>
      'App verification failed. Please restart the app and try again.',

    // ── Provider already linked ───────────────────────────────────────
    'provider-already-linked' =>
      'This sign-in method is already linked to your account.',

    // ── Email already in use ──────────────────────────────────────────
    'email-already-in-use' =>
      'This email is already associated with another account.',

    // ── Account exists with different credential ──────────────────────
    'account-exists-with-different-credential' =>
      'An account already exists with the same email but a different '
          'sign-in method. Please sign in with your original method.',

    // ── Invalid cert hash (Android SHA mismatch) ──────────────────────
    'invalid-cert-hash' =>
      'App signing verification failed. This build may not be properly '
          'configured for phone authentication.',

    // ── Timeout ───────────────────────────────────────────────────────
    'timeout' => 'The request timed out. Please try again.',

    // ── Internal / unknown ────────────────────────────────────────────
    'internal-error' => 'An internal error occurred. Please try again.',

    // ── TOTP-related errors ───────────────────────────────────────────
    'invalid-totp-code' =>
      'That authenticator code is incorrect. Please check and try again.',

    'missing-totp-code' => 'Please enter the code from your authenticator app.',

    // ── Catch-all with error code for debugging ───────────────────────
    final String unknownCode =>
      'Verification failed (error: $unknownCode). Please try again.',
  };
}

/// Converts any exception to a friendly MFA error message.
/// Extracts the Firebase error code when available from all known
/// exception types: [FirebaseAuthException], [FirebaseException],
/// and [PlatformException].
String friendlyMFAError(Object error) {
  if (error is FirebaseAuthException) {
    AppLogging.mfa(
      'MFA error: FirebaseAuthException code=${error.code}, '
      'message=${error.message}',
    );
    return friendlyMFAErrorCode(error.code);
  }

  if (error is FirebaseException) {
    AppLogging.mfa(
      'MFA error: FirebaseException code=${error.code}, '
      'message=${error.message}',
    );
    return friendlyMFAErrorCode(error.code);
  }

  if (error is PlatformException) {
    final code = error.code
        .replaceAll('ERROR_', '')
        .toLowerCase()
        .replaceAll('_', '-');
    AppLogging.mfa(
      'MFA error: PlatformException code=${error.code} (normalized=$code), '
      'message=${error.message}',
    );
    return friendlyMFAErrorCode(code);
  }

  if (error is ArgumentError) {
    AppLogging.mfa('MFA error: ArgumentError message=${error.message}');
    return 'Invalid verification data. Please request a new code.';
  }

  AppLogging.mfa('MFA error: ${error.runtimeType} — $error');
  return 'Verification failed. Please try again.';
}
