// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'age_group.dart';
import 'age_safety_policy.dart';
import 'legal_constants.dart';

/// Tracks whether the user has confirmed age eligibility and at which
/// policy version, together with the age group and signal source captured
/// at confirmation time.
///
/// The gate is shown when [hasConfirmed] is false or when [policyVersion]
/// is less than [LegalConstants.ageEligibilityPolicyVersion].
class AgeEligibilityState {
  /// Whether the user has ever confirmed age eligibility.
  final bool hasConfirmed;

  /// UTC timestamp of when the user confirmed.
  final DateTime? confirmedAt;

  /// The age-eligibility policy version at the time of confirmation.
  final int policyVersion;

  /// The age group selected by the user (or provided by a platform signal).
  final AgeGroup ageGroup;

  /// How the age group was determined.
  final AgeSource source;

  const AgeEligibilityState({
    this.hasConfirmed = false,
    this.confirmedAt,
    this.policyVersion = 0,
    this.ageGroup = AgeGroup.unknown,
    this.source = AgeSource.unknown,
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

  /// Capability policy derived from this eligibility state.
  AgeSafetyPolicy get safetyPolicy =>
      AgeSafetyPolicy(ageGroup: ageGroup, source: source);

  @override
  bool operator ==(Object other) {
    return other is AgeEligibilityState &&
        other.hasConfirmed == hasConfirmed &&
        other.confirmedAt == confirmedAt &&
        other.policyVersion == policyVersion &&
        other.ageGroup == ageGroup &&
        other.source == source;
  }

  @override
  int get hashCode =>
      Object.hash(hasConfirmed, confirmedAt, policyVersion, ageGroup, source);

  @override
  String toString() =>
      'AgeEligibilityState(confirmed=$hasConfirmed, '
      'at=$confirmedAt, policyVersion=$policyVersion, '
      'ageGroup=$ageGroup, source=$source)';
}
