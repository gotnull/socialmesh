// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for Mesh Explorer UI state.
///
/// Composes SIP discovery, MRRP service cache, identity store,
/// and NodeDex data into public-facing view models for the
/// Mesh Explorer screen.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../features/mesh_explorer/models/interaction_tier.dart';
import '../features/mesh_explorer/models/mesh_explorer_peer.dart';
import '../features/mesh_services/models/mesh_service_template.dart';
import '../services/protocol/sip/mrrp_advert_engine.dart';
import '../services/protocol/sip/mrrp_types.dart';
import '../services/protocol/sip/sip_handshake.dart';
import '../services/protocol/sip/sip_types.dart';
import 'mrrp_providers.dart';
import 'sip_providers.dart';

/// Derive a stable 32-bit sigil seed from a 16-byte persona_id.
///
/// Uses the first 4 bytes as a little-endian uint32. Falls back to 0
/// if the persona_id is too short (should never happen for valid records).
int _sigilSeedFromPersonaId(Uint8List personaId) {
  if (personaId.length < 4) return 0;
  return ByteData.sublistView(personaId).getUint32(0, Endian.little);
}

/// Whether Mesh Explorer is available (feature flag check).
final meshExplorerEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isMeshExplorerEnabled;
});

/// Combined peer list for Mesh Explorer.
///
/// Merges SIP discovered peers with MRRP service advertisers to produce
/// a list of [MeshExplorerPeer] objects sorted by tier then proximity.
///
/// Peers can appear via two paths:
/// 1. **SIP CAP_BEACON** — discovered via periodic beacon exchange (300s+jitter).
/// 2. **MRRP SERVICE_ADVERT** — nodes that advertised services but haven't
///    exchanged a beacon yet. These are added as [AnonymousPeer] entries so
///    that service advertisers are immediately visible in the NEARBY section.
final meshExplorerPeersProvider = Provider<List<MeshExplorerPeer>>((ref) {
  final enabled = ref.watch(meshExplorerEnabledProvider);
  if (!enabled) return const [];

  // Watch epoch providers to rebuild on discovery/handshake/identity/DM/advert
  // changes.
  ref.watch(sipPeerCacheEpochProvider);
  ref.watch(sipHandshakeEpochProvider);
  ref.watch(sipDmEpochProvider);
  ref.watch(mrrpAdvertEpochProvider);

  final peers = ref.watch(sipDiscoveredPeersProvider);
  final cachedServices = ref.watch(mrrpCachedServicesProvider);
  final identityStore = ref.watch(sipIdentityStoreProvider);
  final handshake = ref.watch(sipHandshakeProvider);
  final activeDmSessions = ref.watch(sipActiveSessionsProvider);

  final result = <MeshExplorerPeer>[];

  for (final peer in peers) {
    // Get services advertised by this peer
    final peerServices = cachedServices[peer.nodeId] ?? <MrrpCachedService>[];
    final serviceIds = peerServices
        .where(
          (s) => _isPublicService(
            s.descriptor.serviceId,
            s.descriptor.serviceFlags,
          ),
        )
        .map((s) => s.descriptor.serviceId)
        .toList();

    // Check identity state
    final identity = identityStore.getByNodeId(peer.nodeId);
    final hsState = handshake?.getState(peer.nodeId) ?? SipHandshakeState.idle;
    // A peer is handshaked if their result is still pending consumption OR
    // if a DM session already exists (result was consumed but session lives on).
    final hasDmSession = activeDmSessions.any(
      (s) => s.peerNodeId == peer.nodeId,
    );

    if (identity != null &&
        (identity.state == SipIdentityState.verifiedTofu ||
            identity.state == SipIdentityState.pinned)) {
      // Identified or pinned peer
      final tier = identity.state == SipIdentityState.pinned
          ? InteractionTier.pinned
          : InteractionTier.identified;

      result.add(
        IdentifiedPeer(
          nodeId: peer.nodeId,
          displayName: identity.displayName.isNotEmpty
              ? identity.displayName
              : null,
          sigilSeed: _sigilSeedFromPersonaId(identity.personaId),
          tier: tier,
          lastSeenMs: peer.lastSeenMs,
          mrrpServiceIds: serviceIds,
        ),
      );
    } else if (hsState == SipHandshakeState.accepted || hasDmSession) {
      // Handshaked but not yet identified
      result.add(
        IdentifiedPeer(
          nodeId: peer.nodeId,
          sigilSeed: peer.nodeId,
          tier: InteractionTier.handshaked,
          lastSeenMs: peer.lastSeenMs,
          mrrpServiceIds: serviceIds,
        ),
      );
    } else {
      // Anonymous peer
      result.add(
        AnonymousPeer(
          nodeId: peer.nodeId,
          ambientId: peer.capsHash, // Use caps hash as ambient sigil seed
          lastSeenMs: peer.lastSeenMs,
          features: peer.features,
          mrrpServiceIds: serviceIds,
        ),
      );
    }
  }

  // Synthesize peers from MRRP SERVICE_ADVERT cache for nodes that were NOT
  // already discovered via SIP CAP_BEACON. A SERVICE_ADVERT proves the node
  // is nearby and advertising services — it should appear in the peer list
  // even without a beacon exchange.
  final sipNodeIds = peers.map((p) => p.nodeId).toSet();
  for (final entry in cachedServices.entries) {
    final nodeId = entry.key;
    if (sipNodeIds.contains(nodeId)) continue; // already in result

    final peerServices = entry.value;
    final serviceIds = peerServices
        .where(
          (s) => _isPublicService(
            s.descriptor.serviceId,
            s.descriptor.serviceFlags,
          ),
        )
        .map((s) => s.descriptor.serviceId)
        .toList();

    if (serviceIds.isEmpty) continue; // no public services, skip

    // Use the most recent cachedAt timestamp as lastSeenMs.
    final latestCachedAt = peerServices
        .map((s) => s.cachedAt.millisecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);

    result.add(
      AnonymousPeer(
        nodeId: nodeId,
        ambientId: nodeId, // use nodeId as sigil seed (no beacon caps hash)
        lastSeenMs: latestCachedAt,
        features: 0, // unknown — no beacon received
        mrrpServiceIds: serviceIds,
      ),
    );
  }

  // Sort: pinned first, then identified, handshaked, anonymous.
  // Within same tier, sort by most recently seen.
  result.sort((a, b) {
    final tierCmp = b.tier.index.compareTo(a.tier.index);
    if (tierCmp != 0) return tierCmp;
    return b.lastSeenMs.compareTo(a.lastSeenMs);
  });

  AppLogging.meshExplorer(
    'peers rebuilt: ${result.length} total', // lint-allow: hardcoded-string
  );

  return result;
});

/// A single service entry visible in the Mesh Explorer.
///
/// Each entry represents one distinct service instance from one peer.
/// For user-created services (all sharing [kMeshServicesInstanceServiceId]),
/// each active instance with unique metadata appears as a separate entry.
class MeshExplorerServiceInfo {
  /// Number of peers advertising this exact service instance.
  final int peerCount;

  /// User-provided display title decoded from SERVICE_ADVERT.
  /// Null when no metadata is present (built-in services typically have none).
  final String? metadata;

  /// Canonical capability for user-created mesh services, if available.
  final MeshServiceType? canonicalType;

  /// Optional preset flavor for user-created mesh services.
  final MeshServicePresetId? presetId;

  /// The MRRP service ID.
  final int serviceId;

  /// Node ID of the first peer advertising this service (for tap routing).
  final int nodeId;

  /// When this service was last advertised (for freshness display).
  final DateTime cachedAt;

  /// Display name of the creator peer (null if anonymous).
  final String? creatorName;

  /// Whether the creator has a verified identity.
  final bool isCreatorIdentified;

  /// Sigil seed for the creator (for avatar rendering).
  final int creatorSigilSeed;

  const MeshExplorerServiceInfo({
    required this.peerCount,
    required this.serviceId,
    required this.nodeId,
    required this.cachedAt,
    this.metadata,
    this.canonicalType,
    this.presetId,
    this.creatorName,
    this.isCreatorIdentified = false,
    this.creatorSigilSeed = 0,
  });
}

/// Service instances across all nearby peers.
///
/// Returns a list of service entries. User-created services (which share
/// a single MRRP service ID) are expanded into separate entries per
/// instance based on their metadata (title).
final meshExplorerServicesProvider = Provider<List<MeshExplorerServiceInfo>>((
  ref,
) {
  final enabled = ref.watch(meshExplorerEnabledProvider);
  if (!enabled) return const [];

  ref.watch(mrrpAdvertEpochProvider);
  final cachedServices = ref.watch(mrrpCachedServicesProvider);
  final peers = ref.watch(meshExplorerPeersProvider);

  // Build a lookup for peer identity by nodeId.
  final peerLookup = <int, MeshExplorerPeer>{};
  for (final peer in peers) {
    peerLookup[peer.nodeId] = peer;
  }

  final entries = <MeshExplorerServiceInfo>[];

  for (final entry in cachedServices.entries) {
    final nodeId = entry.key;
    for (final service in entry.value) {
      if (!_isPublicService(
        service.descriptor.serviceId,
        service.descriptor.serviceFlags,
      )) {
        continue;
      }

      String? metadata;
      MeshServiceType? canonicalType;
      MeshServicePresetId? presetId;
      if (service.descriptor.metadata.isNotEmpty) {
        final decoded = MeshServiceAdvertMetadata.decode(
          service.descriptor.metadata,
        );
        metadata = decoded.title.isEmpty ? null : decoded.title;
        canonicalType = decoded.canonicalType;
        presetId = decoded.presetId;
      }

      // Resolve creator identity from the peer list.
      final peer = peerLookup[nodeId];
      final String? creatorName;
      final bool isCreatorIdentified;
      final int creatorSigilSeed;
      if (peer is IdentifiedPeer) {
        creatorName = peer.displayName;
        isCreatorIdentified = true;
        creatorSigilSeed = peer.sigilSeed;
      } else if (peer is AnonymousPeer) {
        creatorName = null;
        isCreatorIdentified = false;
        creatorSigilSeed = peer.ambientId;
      } else {
        creatorName = null;
        isCreatorIdentified = false;
        creatorSigilSeed = nodeId;
      }

      entries.add(
        MeshExplorerServiceInfo(
          peerCount: 1,
          serviceId: service.descriptor.serviceId,
          nodeId: nodeId,
          cachedAt: service.cachedAt,
          metadata: metadata,
          canonicalType: canonicalType,
          presetId: presetId,
          creatorName: creatorName,
          isCreatorIdentified: isCreatorIdentified,
          creatorSigilSeed: creatorSigilSeed,
        ),
      );
    }
  }

  // Sort by freshness (most recent first).
  entries.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));

  return entries;
});

/// Summary counts for the Mesh Explorer hero section.
class MeshExplorerSummary {
  final int nearbyPeers;
  final int activeServices;
  final bool isConnected;

  const MeshExplorerSummary({
    required this.nearbyPeers,
    required this.activeServices,
    required this.isConnected,
  });
}

/// Summary provider for the hero area.
final meshExplorerSummaryProvider = Provider<MeshExplorerSummary>((ref) {
  final peers = ref.watch(meshExplorerPeersProvider);
  final services = ref.watch(meshExplorerServicesProvider);
  final connected = ref.watch(sipDiscoveryProvider) != null;

  return MeshExplorerSummary(
    nearbyPeers: peers.length,
    activeServices: services.length,
    isConnected: connected,
  );
});

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Check if a service should appear in public UI.
///
/// Only services with the [MrrpServiceFlags.userVisible] flag AND without
/// the [MrrpServiceFlags.testOnly] flag are shown. Built-in protocol
/// services (meetup, profile, board, incident) are infrastructure and
/// should NOT be marked userVisible.
bool _isPublicService(int serviceId, int serviceFlags) {
  if (serviceFlags & MrrpServiceFlags.testOnly != 0) return false;
  if (serviceFlags & MrrpServiceFlags.userVisible == 0) return false;
  return true;
}

// ---------------------------------------------------------------------------
// New-peer badge counter
// ---------------------------------------------------------------------------

/// Tracks the count of newly discovered peers that have not yet been seen
/// by the user in Mesh Explorer. Used to drive the hamburger badge and
/// drawer item indicator.
class NewMeshPeerCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
  void clear() => state = 0;
}

final newMeshPeerCountProvider =
    NotifierProvider<NewMeshPeerCountNotifier, int>(
      NewMeshPeerCountNotifier.new,
    );
