// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh Explorer peer model hierarchy.
///
/// Sealed type that represents nearby peers at different interaction tiers.
/// Used by the Mesh Explorer screen to render peer tiles appropriately.
library;

import 'interaction_tier.dart';

/// Base type for all peers visible in Mesh Explorer.
sealed class MeshExplorerPeer {
  /// The peer's Meshtastic node ID.
  int get nodeId;

  /// Hop count (1 = direct RF, 2 = one relay, 3+ = two+ relays).
  /// Null when hop data is not available from the transport layer.
  int? get hopCount;

  /// When this peer was last seen (ms since epoch, monotonic).
  int get lastSeenMs;

  /// The interaction tier for this peer.
  InteractionTier get tier;

  /// Number of MRRP services advertised by this peer.
  int get serviceCount;
}

/// An anonymous peer seen via CAP_BEACON only.
class AnonymousPeer extends MeshExplorerPeer {
  @override
  final int nodeId;

  /// Ambient identity seed for sigil generation.
  final int ambientId;

  @override
  final int? hopCount;

  @override
  final int lastSeenMs;

  /// SIP feature bitmap from beacon.
  final int features;

  /// List of advertised MRRP service IDs (from advert cache).
  final List<int> mrrpServiceIds;

  AnonymousPeer({
    required this.nodeId,
    required this.ambientId,
    this.hopCount,
    required this.lastSeenMs,
    required this.features,
    this.mrrpServiceIds = const [],
  });

  @override
  InteractionTier get tier => InteractionTier.anonymous;

  @override
  int get serviceCount => mrrpServiceIds.length;
}

/// A peer with an established SIP handshake and/or verified identity.
class IdentifiedPeer extends MeshExplorerPeer {
  @override
  final int nodeId;

  /// Display name from NodeDex or identity exchange.
  final String? displayName;

  /// Sigil seed derived from persona_id (stable identity).
  final int sigilSeed;

  @override
  final InteractionTier tier;

  @override
  final int? hopCount;

  @override
  final int lastSeenMs;

  /// List of advertised MRRP service IDs.
  final List<int> mrrpServiceIds;

  IdentifiedPeer({
    required this.nodeId,
    this.displayName,
    required this.sigilSeed,
    required this.tier,
    this.hopCount,
    required this.lastSeenMs,
    this.mrrpServiceIds = const [],
  });

  @override
  int get serviceCount => mrrpServiceIds.length;
}
