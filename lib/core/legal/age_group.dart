// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Proportional age buckets for safe-defaults policy decisions.
///
/// [unknown] is used when no signal is available (e.g. loading state or a
/// first-run user before the gate is completed). The capability layer treats
/// [unknown] conservatively and applies safe defaults.
enum AgeGroup {
  /// Age is not yet known — conservative safe defaults apply.
  unknown,

  /// User is under 13. App is not available in this age group.
  under13,

  /// User is 13–17 (adolescent). Privacy-enhanced defaults apply.
  teen,

  /// User is 18 or older. Standard app experience.
  adult,
}

/// Source of the age determination.
///
/// Distinguishes between user self-attestation and platform-provided
/// signals such as the Google Play Age Signals API.
enum AgeSource {
  /// Source is not known.
  unknown,

  /// User explicitly confirmed their age range via the in-app gate.
  selfAttestation,

  /// Platform age signal received from Google Play (Android only).
  /// Requires the Play Age Signals API to be active.
  playAgeSignals,
}
