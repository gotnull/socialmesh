// SPDX-License-Identifier: GPL-3.0-or-later

/// Legal document versioning and anchor constants.
///
/// [termsVersion] and [privacyVersion] must be bumped when the website
/// content changes in a way that requires user re-acceptance.
/// Format: YYYY-MM-DD of the effective date matching the "Last Updated"
/// date on the corresponding web page.
class LegalConstants {
  LegalConstants._();

  /// Current Terms of Service version (matches "Last Updated" on website).
  /// Bump this value when Terms content changes materially.
  static const String termsVersion = '2026-02-20';

  /// Current Privacy Policy version (matches "Last Updated" on website).
  /// Bump this value when Privacy Policy content changes materially.
  static const String privacyVersion = '2026-02-20';

  // ---------------------------------------------------------------------------
  // SharedPreferences keys
  // ---------------------------------------------------------------------------

  /// Version string of the Terms the user last accepted.
  static const String acceptedTermsVersionKey = 'accepted_terms_version';

  /// Version string of the Privacy Policy the user last accepted.
  static const String acceptedPrivacyVersionKey = 'accepted_privacy_version';

  /// ISO-8601 timestamp of when the user accepted.
  static const String acceptedAtKey = 'terms_accepted_at';

  /// App build number at the time of acceptance (optional metadata).
  static const String acceptedBuildKey = 'terms_accepted_build';

  /// Platform identifier at the time of acceptance (ios / android).
  static const String acceptedPlatformKey = 'terms_accepted_platform';

  // ---------------------------------------------------------------------------
  // HTML section anchors (must match id= attributes in terms-of-service.html)
  // ---------------------------------------------------------------------------

  /// Agreement to Terms
  static const String anchorAgreement = 'agreement';

  /// Description of Service
  static const String anchorDescription = 'description';

  /// License Grant (Section A)
  static const String anchorLicenseGrant = 'license-grant';

  /// Use of the Service / Acceptable Use
  static const String anchorAcceptableUse = 'acceptable-use';

  /// Radio and Legal Compliance (Section I)
  static const String anchorRadioCompliance = 'radio-compliance';

  /// Payments, Subscriptions, and Refunds (Section G)
  static const String anchorPayments = 'payments';

  /// Intellectual Property
  static const String anchorIntellectualProperty = 'intellectual-property';

  /// Privacy Policy Incorporation (Section E)
  static const String anchorPrivacyIncorporation = 'privacy-incorporation';

  /// Third-Party Services and Dependencies (Section F)
  static const String anchorThirdPartyServices = 'third-party-services';

  /// Disclaimer of Warranties
  static const String anchorDisclaimer = 'disclaimer';

  /// Limitation of Liability
  static const String anchorLiability = 'liability';

  /// Indemnification (Section C)
  static const String anchorIndemnification = 'indemnification';

  /// Termination (Section B)
  static const String anchorTermination = 'termination';

  /// Governing Law and Jurisdiction (Section D)
  static const String anchorGoverningLaw = 'governing-law';

  /// Changes to Terms (Section J)
  static const String anchorChanges = 'changes';

  /// Contact and Notices (Section H)
  static const String anchorContact = 'contact';

  /// All anchor constants for validation and testing.
  static const List<String> allAnchors = [
    anchorAgreement,
    anchorDescription,
    anchorLicenseGrant,
    anchorAcceptableUse,
    anchorRadioCompliance,
    anchorPayments,
    anchorIntellectualProperty,
    anchorPrivacyIncorporation,
    anchorThirdPartyServices,
    anchorDisclaimer,
    anchorLiability,
    anchorIndemnification,
    anchorTermination,
    anchorGoverningLaw,
    anchorChanges,
    anchorContact,
  ];

  /// Version date format regex for validation.
  /// Matches YYYY-MM-DD where YYYY >= 2020.
  static final RegExp versionDateFormat = RegExp(
    r'^20[2-9]\d-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])$',
  );

  /// Validates that a version string matches the expected YYYY-MM-DD format.
  static bool isValidVersion(String version) =>
      versionDateFormat.hasMatch(version);

  /// Valid HTML id pattern: lowercase letters, digits, and hyphens only,
  /// must start with a letter.
  static final RegExp validAnchorPattern = RegExp(r'^[a-z][a-z0-9-]*$');

  /// Validates that an anchor string is a valid HTML id attribute value.
  static bool isValidAnchor(String anchor) =>
      anchor.isNotEmpty && validAnchorPattern.hasMatch(anchor);
}
