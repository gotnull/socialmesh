// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

import '../../core/logging.dart';

/// Maps Firebase Auth error codes to friendly, localized user-facing messages
/// for MFA enrollment, verification, and management flows.
///
/// Error codes sourced from:
/// - Firebase Auth JS SDK reference (AuthErrorCodes)
/// - firebase_auth Flutter plugin (FlutterFirebaseAuthPluginException.java)
/// - firebase_auth_platform_interface (exception.dart)
String friendlyMFAErrorCode(String code, AppLocalizations l10n) {
  return switch (code) {
    // ── Wrong / invalid verification code ─────────────────────────────
    'invalid-verification-code' => l10n.authMfaErrorInvalidCode,

    // Newer Firebase SDK versions may unify under invalid-credential
    'invalid-credential' ||
    'INVALID_CREDENTIAL' => l10n.authMfaErrorInvalidCredential,

    // ── Code expired ──────────────────────────────────────────────────
    'session-expired' || 'code-expired' => l10n.authMfaErrorCodeExpired,

    // ── Invalid session / verification ID ─────────────────────────────
    'invalid-verification-id' ||
    'missing-verification-id' => l10n.authMfaErrorSessionExpired,

    'invalid-multi-factor-session' ||
    'missing-multi-factor-session' => l10n.authMfaErrorSignInSessionExpired,

    // ── Phone provider not enabled ────────────────────────────────────
    'operation-not-allowed' => l10n.authMfaErrorPhoneNotEnabled,

    // ── Invalid phone number format ───────────────────────────────────
    'invalid-phone-number' => l10n.authMfaErrorInvalidPhoneNumber,

    // ── Rate limiting ─────────────────────────────────────────────────
    'too-many-requests' => l10n.authMfaErrorTooManyRequests,

    // ── No user signed in ─────────────────────────────────────────────
    'no-current-user' => l10n.authMfaErrorNoCurrentUser,

    // ── MFA already enrolled ──────────────────────────────────────────
    'second-factor-already-in-use' => l10n.authMfaErrorAlreadyEnrolled,

    // ── Max second factors reached ────────────────────────────────────
    'maximum-second-factor-count-exceeded' => l10n.authMfaErrorMaxFactors,

    // ── Unsupported first factor ──────────────────────────────────────
    'unsupported-first-factor' => l10n.authMfaErrorUnsupportedFirstFactor,

    // ── Phone number already linked ───────────────────────────────────
    'credential-already-in-use' => l10n.authMfaErrorCredentialInUse,

    // ── Re-authentication required ────────────────────────────────────
    // Auto-re-auth is attempted first; this message is a fallback if it fails.
    'requires-recent-login' ||
    'unenroll-failed' => l10n.authMfaErrorReauthFailed,

    // ── User cancelled re-authentication ──────────────────────────────
    'reauthentication-cancelled' => l10n.authMfaErrorReauthCancelled,

    // ── Wrong account selected during re-authentication ───────────────
    'wrong-account-selected' ||
    'user-mismatch' => l10n.authMfaErrorWrongAccount,

    // ── Network issues ────────────────────────────────────────────────
    'network-request-failed' => l10n.authMfaErrorNoInternet,

    // ── App verification / reCAPTCHA ──────────────────────────────────
    'app-not-authorized' ||
    'captcha-check-failed' => l10n.authMfaErrorAppVerificationFailed,

    // ── Missing phone number ──────────────────────────────────────────
    'missing-phone-number' => l10n.authMfaErrorMissingPhone,

    // ── Missing verification code ─────────────────────────────────────
    'missing-verification-code' => l10n.authMfaErrorMissingCode,

    // ── Verification failed ───────────────────────────────────────────
    'verification-failed' => l10n.authMfaErrorVerificationFailed,

    // ── User disabled ─────────────────────────────────────────────────
    'user-disabled' => l10n.authMfaErrorUserDisabled,

    // ── User cancelled ────────────────────────────────────────────────
    'web-context-cancelled' || 'user-cancelled' => l10n.authMfaErrorCancelled,

    // ── Quota exceeded ────────────────────────────────────────────────
    'quota-exceeded' => l10n.authMfaErrorQuotaExceeded,

    // ── MFA info not found ────────────────────────────────────────────
    'multi-factor-info-not-found' => l10n.authMfaErrorInfoNotFound,

    // ── Second factor required (should not normally surface to user) ──
    'second-factor-required' => l10n.authMfaErrorSecondFactorRequired,

    // ── MFA sign-in resolution failed ─────────────────────────────────
    'resolve-signin-failed' => l10n.authMfaErrorResolveSignInFailed,

    // ── Invalid app credential (APNs / reCAPTCHA) ─────────────────────
    'invalid-app-credential' => l10n.authMfaErrorInvalidAppCredential,

    'missing-app-credential' => l10n.authMfaErrorMissingAppCredential,

    // ── Missing client identifier ─────────────────────────────────────
    'missing-client-identifier' => l10n.authMfaErrorMissingClientId,

    // ── Provider already linked ───────────────────────────────────────
    'provider-already-linked' => l10n.authMfaErrorProviderAlreadyLinked,

    // ── Email already in use ──────────────────────────────────────────
    'email-already-in-use' => l10n.authMfaErrorEmailInUse,

    // ── Account exists with different credential ──────────────────────
    'account-exists-with-different-credential' =>
      l10n.authMfaErrorAccountExistsDifferentCredential,

    // ── Invalid cert hash (Android SHA mismatch) ──────────────────────
    'invalid-cert-hash' => l10n.authMfaErrorInvalidCertHash,

    // ── Timeout ───────────────────────────────────────────────────────
    'timeout' => l10n.authMfaErrorTimeout,

    // ── Internal / unknown ────────────────────────────────────────────
    'internal-error' => l10n.authMfaErrorInternal,

    // ── TOTP-related errors ───────────────────────────────────────────
    'invalid-totp-code' => l10n.authMfaErrorInvalidTotpCode,

    'missing-totp-code' => l10n.authMfaErrorMissingTotpCode,

    // ── Catch-all with error code for debugging ───────────────────────
    final String unknownCode => l10n.authMfaErrorUnknown(unknownCode),
  };
}

/// Converts any exception to a friendly, localized MFA error message.
/// Extracts the Firebase error code when available from all known
/// exception types: [FirebaseAuthException], [FirebaseException],
/// and [PlatformException].
String friendlyMFAError(Object error, AppLocalizations l10n) {
  if (error is FirebaseAuthException) {
    AppLogging.mfa(
      'MFA error: FirebaseAuthException code=${error.code}, '
      'message=${error.message}',
    );
    return friendlyMFAErrorCode(error.code, l10n);
  }

  if (error is FirebaseException) {
    AppLogging.mfa(
      'MFA error: FirebaseException code=${error.code}, '
      'message=${error.message}',
    );
    return friendlyMFAErrorCode(error.code, l10n);
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
    return friendlyMFAErrorCode(code, l10n);
  }

  if (error is ArgumentError) {
    AppLogging.mfa('MFA error: ArgumentError message=${error.message}');
    return l10n.authMfaErrorInvalidData;
  }

  AppLogging.mfa('MFA error: ${error.runtimeType} - $error');
  return l10n.authMfaErrorGeneric;
}
