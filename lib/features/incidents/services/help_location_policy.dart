// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Single source of truth for the Help Mode location-sharing decision.
///
/// PR-7C established that precise [IncidentLocation] cannot be sent safely over
/// the current incident.v1 path: the MRRP/SIP transport is broadcast-only and
/// channel-encrypted only, so any same-channel node can decode a payload, and
/// there is no app-level recipient-sealed layer for MRRP service payloads.
///
/// This policy centralises that decision so widgets and the controller never
/// scatter it. Precise location sending stays OFF until a recipient-sealed /
/// encrypted MRRP payload path AND a dedicated capability/flag exist.
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (Location policy)
library;

/// Why precise location sharing is in its current state.
enum HelpLocationStatus {
  /// No privacy-safe (recipient-sealed) transport is available, so precise
  /// location is not sent over the mesh.
  unsupportedTransport,
}

abstract final class HelpLocationPolicy {
  /// Whether a recipient-sealed transport exists for precise location. False
  /// until sealed MRRP payloads are implemented.
  ///
  /// Implemented as a getter (not a `const`) on purpose: callers may branch on
  /// it without triggering dead-code analysis, keeping the future-ready path
  /// compiling.
  static bool get preciseLocationSendingSupported => false;

  /// Whether the app may currently put precise coordinates on the wire.
  static bool get canSendPreciseLocation => preciseLocationSendingSupported;

  /// The current location-sharing status, for UI copy selection.
  static HelpLocationStatus get status =>
      HelpLocationStatus.unsupportedTransport;
}
