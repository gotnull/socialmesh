// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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

  /// Whether the currently accepted versions are at least as new as required.
  ///
  /// Comparison is `stored >= required` using lexicographic order, which is
  /// correct because version strings are YYYY-MM-DD (ISO-8601 sortable).
  /// A stored version *higher* than required must NOT trigger re-acceptance:
  /// that case happens when the user previously accepted a Firestore-bumped
  /// version on an older app build whose hardcoded floor was lower, and we
  /// then resolve `effective` from the hardcoded floor while the Firestore
  /// fetch is still loading. Strict equality would re-prompt them on every
  /// cold launch.
  bool isCurrentWith({
    required String requiredTermsVersion,
    required String requiredPrivacyVersion,
  }) {
    final terms = acceptedTermsVersion;
    final privacy = acceptedPrivacyVersion;
    if (terms == null || privacy == null) return false;
    return terms.compareTo(requiredTermsVersion) >= 0 &&
        privacy.compareTo(requiredPrivacyVersion) >= 0;
  }

  /// Whether the user needs to accept (or re-accept) the current terms.
  ///
  /// Returns true when:
  /// - The user has never accepted terms, or
  /// - The accepted terms version is older than [LegalConstants.termsVersion], or
  /// - The accepted privacy version is older than [LegalConstants.privacyVersion].
  bool get needsAcceptance {
    return !isCurrentWith(
      requiredTermsVersion: LegalConstants.termsVersion,
      requiredPrivacyVersion: LegalConstants.privacyVersion,
    );
  }

  /// Whether the accepted terms are older than the current required version.
  bool get termsVersionChanged =>
      acceptedTermsVersion != null &&
      acceptedTermsVersion!.compareTo(LegalConstants.termsVersion) < 0;

  /// Whether the accepted privacy is older than the current required version.
  bool get privacyVersionChanged =>
      acceptedPrivacyVersion != null &&
      acceptedPrivacyVersion!.compareTo(LegalConstants.privacyVersion) < 0;

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
