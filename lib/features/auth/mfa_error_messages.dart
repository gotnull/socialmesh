// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_auth/firebase_auth.dart';

/// Maps Firebase Auth error codes to friendly, user-facing messages
/// for MFA enrollment, verification, and management flows.
String friendlyMFAErrorCode(String code) {
  return switch (code) {
    // Phone provider not enabled in Firebase Console
    'operation-not-allowed' =>
      'Phone verification is not enabled. Please contact support.',

    // Invalid phone number format
    'invalid-phone-number' =>
      'Please enter a valid phone number with country code (e.g. +1 234 567 890).',

    // SMS quota exceeded
    'too-many-requests' =>
      'Too many attempts. Please wait a few minutes and try again.',

    // Invalid or expired verification code
    'invalid-verification-code' =>
      'That code is incorrect. Please check and try again.',

    // Verification code expired
    'session-expired' || 'code-expired' =>
      'The verification code has expired. Please request a new one.',

    // No user signed in
    'no-current-user' => 'Please sign in first to manage two-factor auth.',

    // MFA already enrolled
    'second-factor-already-in-use' =>
      'This phone number is already enrolled for two-factor auth.',

    // Unsupported second factor
    'unsupported-first-factor' =>
      'Your sign-in method does not support two-factor auth.',

    // Phone number already linked to another account
    'credential-already-in-use' =>
      'This phone number is already used by another account.',

    // User needs to re-authenticate
    'requires-recent-login' =>
      'For security, please sign out and sign in again before changing 2FA settings.',

    // Network issues
    'network-request-failed' =>
      'No internet connection. Please check your network and try again.',

    // App verification failed (reCAPTCHA)
    'app-not-authorized' ||
    'captcha-check-failed' => 'App verification failed. Please try again.',

    // Missing phone number
    'missing-phone-number' => 'Please enter your phone number.',

    // Verification failed or timed out
    'verification-failed' =>
      'Phone verification failed. Please check your number and try again.',

    // User disabled
    'user-disabled' =>
      'This account has been disabled. Please contact support.',

    // Web context cancelled (user closed the popup)
    'web-context-cancelled' => 'Verification was cancelled.',

    // Quota exceeded for project
    'quota-exceeded' =>
      'Service temporarily unavailable. Please try again later.',

    // Catch-all
    _ => 'Something went wrong. Please try again.',
  };
}

/// Converts any exception to a friendly MFA error message.
/// Extracts the Firebase error code when available.
String friendlyMFAError(Object error) {
  if (error is FirebaseAuthException) {
    return friendlyMFAErrorCode(error.code);
  }
  return 'Something went wrong. Please try again.';
}
