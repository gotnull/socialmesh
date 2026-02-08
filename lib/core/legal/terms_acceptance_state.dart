// SPDX-License-Identifier: GPL-3.0-or-later

import 'legal_constants.dart';

/// Immutable record of the user's terms and privacy policy acceptance.
///
/// Stored locally via [SharedPreferences] through [SettingsService].
/// The app checks this state during initialisation to decide whether
/// the user needs to (re-)accept updated legal documents.
class TermsAcceptanceState {
  /// Version string of the Terms the user last accepted, or null if never.
  final String? acceptedTermsVersion;

  /// Version string of the Privacy Policy the user last accepted, or null if never.
  final String? acceptedPrivacyVersion;

  /// Timestamp when the user accepted, or null if never.
  final DateTime? acceptedAt;

  /// App build number at the time of acceptance (optional metadata).
  final String? acceptedBuild;

  /// Platform identifier at the time of acceptance (ios / android).
  final String? acceptedPlatform;

  const TermsAcceptanceState({
    this.acceptedTermsVersion,
    this.acceptedPrivacyVersion,
    this.acceptedAt,
    this.acceptedBuild,
    this.acceptedPlatform,
  });

  /// Initial state representing a user who has never accepted any terms.
  static const TermsAcceptanceState empty = TermsAcceptanceState();

  /// Whether the user has ever accepted any version of the terms.
  bool get hasAccepted =>
      acceptedTermsVersion != null && acceptedPrivacyVersion != null;

  /// Whether the currently accepted versions match the required versions.
  bool isCurrentWith({
    required String requiredTermsVersion,
    required String requiredPrivacyVersion,
  }) {
    return acceptedTermsVersion == requiredTermsVersion &&
        acceptedPrivacyVersion == requiredPrivacyVersion;
  }

  /// Whether the user needs to accept (or re-accept) the current terms.
  ///
  /// Returns true when:
  /// - The user has never accepted terms, or
  /// - The accepted terms version differs from [LegalConstants.termsVersion], or
  /// - The accepted privacy version differs from [LegalConstants.privacyVersion].
  bool get needsAcceptance {
    return !isCurrentWith(
      requiredTermsVersion: LegalConstants.termsVersion,
      requiredPrivacyVersion: LegalConstants.privacyVersion,
    );
  }

  /// Whether only the terms version changed (privacy stayed the same).
  bool get termsVersionChanged =>
      acceptedTermsVersion != null &&
      acceptedTermsVersion != LegalConstants.termsVersion;

  /// Whether only the privacy version changed (terms stayed the same).
  bool get privacyVersionChanged =>
      acceptedPrivacyVersion != null &&
      acceptedPrivacyVersion != LegalConstants.privacyVersion;

  /// Create a copy with updated fields.
  TermsAcceptanceState copyWith({
    String? acceptedTermsVersion,
    String? acceptedPrivacyVersion,
    DateTime? acceptedAt,
    String? acceptedBuild,
    String? acceptedPlatform,
  }) {
    return TermsAcceptanceState(
      acceptedTermsVersion: acceptedTermsVersion ?? this.acceptedTermsVersion,
      acceptedPrivacyVersion:
          acceptedPrivacyVersion ?? this.acceptedPrivacyVersion,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBuild: acceptedBuild ?? this.acceptedBuild,
      acceptedPlatform: acceptedPlatform ?? this.acceptedPlatform,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TermsAcceptanceState &&
        other.acceptedTermsVersion == acceptedTermsVersion &&
        other.acceptedPrivacyVersion == acceptedPrivacyVersion &&
        other.acceptedAt == acceptedAt &&
        other.acceptedBuild == acceptedBuild &&
        other.acceptedPlatform == acceptedPlatform;
  }

  @override
  int get hashCode => Object.hash(
    acceptedTermsVersion,
    acceptedPrivacyVersion,
    acceptedAt,
    acceptedBuild,
    acceptedPlatform,
  );

  @override
  String toString() {
    return 'TermsAcceptanceState('
        'termsVersion: $acceptedTermsVersion, '
        'privacyVersion: $acceptedPrivacyVersion, '
        'acceptedAt: $acceptedAt, '
        'platform: $acceptedPlatform'
        ')';
  }
}
