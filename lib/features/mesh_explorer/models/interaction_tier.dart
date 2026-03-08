// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Interaction tier state machine for Mesh Explorer peers.
///
/// Determines what actions and information are available for a
/// given peer based on the current consent/handshake/identity state.
library;

/// Represents the level of trust/consent established with a peer.
///
/// anonymous → handshaked → identified → pinned
enum InteractionTier {
  /// CAP_BEACON only; no handshake performed.
  anonymous,

  /// SIP handshake complete; no identity exchange.
  handshaked,

  /// Identity verified via Ed25519 signature.
  identified,

  /// User explicitly pinned in NodeDex.
  pinned;

  /// Whether profile information can be viewed.
  bool get canViewProfile => index >= identified.index;

  /// Whether board posts from this peer can be seen.
  bool get canViewBoard => index >= handshaked.index;

  /// Whether DM is possible (also requires dmAvailable setting).
  bool get canDm => index >= identified.index;

  /// Whether this peer can be pinned in NodeDex.
  bool get canPin => this == identified;

  /// Whether this peer has a persistent record in NodeDex.
  bool get hasPersistentRecord => index >= handshaked.index;
}
