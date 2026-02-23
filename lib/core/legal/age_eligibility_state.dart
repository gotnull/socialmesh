// SPDX-License-Identifier: GPL-3.0-or-later

import 'legal_constants.dart';

/// Tracks whether the user has confirmed they are 16+ and at which
/// policy version.
///
/// The gate is shown when [hasConfirmed] is false or when
/// [policyVersion] is less than [LegalConstants.ageEligibilityPolicyVersion].
class AgeEligibilityState {
  /// Whether the user has ever confirmed age eligibility.
  final bool hasConfirmed;

  /// UTC timestamp of when the user confirmed.
  final DateTime? confirmedAt;

  /// The age-eligibility policy version at the time of confirmation.
  final int policyVersion;

  const AgeEligibilityState({
    this.hasConfirmed = false,
    this.confirmedAt,
    this.policyVersion = 0,
  });

  /// Unconfirmed default state.
  static const AgeEligibilityState empty = AgeEligibilityState();

  /// Whether the user must (re-)confirm eligibility.
  ///
  /// True when the user has never confirmed or when the persisted policy
  /// version is older than the current required version.
  bool get needsConfirmation =>
      !hasConfirmed ||
      policyVersion < LegalConstants.ageEligibilityPolicyVersion;

  @override
  bool operator ==(Object other) {
    return other is AgeEligibilityState &&
        other.hasConfirmed == hasConfirmed &&
        other.confirmedAt == confirmedAt &&
        other.policyVersion == policyVersion;
  }

  @override
  int get hashCode => Object.hash(hasConfirmed, confirmedAt, policyVersion);

  @override
  String toString() =>
      'AgeEligibilityState(confirmed=$hasConfirmed, '
      'at=$confirmedAt, policyVersion=$policyVersion)';
}
