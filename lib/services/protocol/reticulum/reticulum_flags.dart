// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Four independent feature flags for the Reticulum tunnel subsystem.
///
/// Each flag is independently toggleable so individual layers can be
/// disabled in the field without taking the whole subsystem down.
class ReticulumFlags {
  const ReticulumFlags({
    this.diagnosticsEnabled = false,
    this.captureEnabled = false,
    this.reassemblyEnabled = false,
    this.bridgeEnabled = false,
  });

  static const empty = ReticulumFlags();

  final bool diagnosticsEnabled;
  final bool captureEnabled;
  final bool reassemblyEnabled;
  final bool bridgeEnabled;

  ReticulumFlags copyWith({
    bool? diagnosticsEnabled,
    bool? captureEnabled,
    bool? reassemblyEnabled,
    bool? bridgeEnabled,
  }) {
    return ReticulumFlags(
      diagnosticsEnabled: diagnosticsEnabled ?? this.diagnosticsEnabled,
      captureEnabled: captureEnabled ?? this.captureEnabled,
      reassemblyEnabled: reassemblyEnabled ?? this.reassemblyEnabled,
      bridgeEnabled: bridgeEnabled ?? this.bridgeEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReticulumFlags &&
          diagnosticsEnabled == other.diagnosticsEnabled &&
          captureEnabled == other.captureEnabled &&
          reassemblyEnabled == other.reassemblyEnabled &&
          bridgeEnabled == other.bridgeEnabled;

  @override
  int get hashCode => Object.hash(
    diagnosticsEnabled,
    captureEnabled,
    reassemblyEnabled,
    bridgeEnabled,
  );

  @override
  String toString() =>
      'ReticulumFlags(diag=$diagnosticsEnabled, cap=$captureEnabled, '
      'reasm=$reassemblyEnabled, bridge=$bridgeEnabled)';
}
