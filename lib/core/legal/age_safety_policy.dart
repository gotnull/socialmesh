// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'age_group.dart';

/// Central capability adapter derived from a user's age group.
///
/// All feature-gating decisions are expressed as named boolean accessors
/// on this class rather than raw booleans scattered across the UI. UI code
/// and providers read from this object; they do not evaluate age rules
/// themselves.
///
/// Conservative default: when [ageGroup] is [AgeGroup.unknown] the policy
/// treats the user as a minor and activates safe defaults. This ensures
/// protection during loading and for any user who has not yet completed the
/// eligibility gate.
class AgeSafetyPolicy {
  final AgeGroup ageGroup;
  final AgeSource source;

  const AgeSafetyPolicy({required this.ageGroup, required this.source});

  /// Conservative safe defaults — used while the eligibility state is
  /// loading or whenever the age group is indeterminate.
  static const AgeSafetyPolicy safe = AgeSafetyPolicy(
    ageGroup: AgeGroup.unknown,
    source: AgeSource.unknown,
  );

  /// Whether the user is classified as a minor (under 18).
  ///
  /// True for [AgeGroup.under13] and [AgeGroup.teen].
  /// [AgeGroup.unknown] is treated conservatively as a minor.
  bool get isMinor =>
      ageGroup == AgeGroup.under13 ||
      ageGroup == AgeGroup.teen ||
      ageGroup == AgeGroup.unknown;

  /// Whether precise coordinates should be replaced with a coarsened
  /// location that has a larger blur radius.
  bool get shouldHidePreciseLocation => isMinor;

  /// Whether unsolicited peer-contact surfaces (e.g. incoming DMs from
  /// unknown nodes) should be suppressed.
  bool get shouldRestrictUnsolicitedContact =>
      ageGroup == AgeGroup.under13 || ageGroup == AgeGroup.teen;

  /// Whether the app should apply safe defaults globally
  /// (location coarsening, restricted discovery visibility, etc.).
  bool get shouldRequireSafeDefaults => isMinor;

  @override
  bool operator ==(Object other) =>
      other is AgeSafetyPolicy &&
      other.ageGroup == ageGroup &&
      other.source == source;

  @override
  int get hashCode => Object.hash(ageGroup, source);

  @override
  String toString() =>
      'AgeSafetyPolicy(ageGroup=$ageGroup, source=$source, '
      'isMinor=$isMinor)';
}
