// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for Mesh Explorer UI state.
///
/// Composes SIP discovery, MRRP service cache, identity store,
/// and NodeDex data into public-facing view models for the
/// Mesh Explorer screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../features/mesh_explorer/models/interaction_tier.dart';
import '../features/mesh_explorer/models/mesh_explorer_peer.dart';
import '../services/protocol/sip/mrrp_advert_engine.dart';
import '../services/protocol/sip/mrrp_types.dart';
import '../services/protocol/sip/sip_handshake.dart';
import '../services/protocol/sip/sip_types.dart';
import 'mrrp_providers.dart';
import 'sip_providers.dart';

/// Whether Mesh Explorer is available (feature flag check).
final meshExplorerEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isMeshExplorerEnabled;
});

/// Combined peer list for Mesh Explorer.
///
/// Merges SIP discovered peers with identity store records to produce
/// a list of [MeshExplorerPeer] objects sorted by tier then proximity.
final meshExplorerPeersProvider = Provider<List<MeshExplorerPeer>>((ref) {
  final enabled = ref.watch(meshExplorerEnabledProvider);
  if (!enabled) return const [];

  // Watch epoch providers to rebuild on discovery/handshake/identity/DM changes
  ref.watch(sipPeerCacheEpochProvider);
  ref.watch(sipHandshakeEpochProvider);
  ref.watch(sipDmEpochProvider);

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
          sigilSeed: peer.nodeId,
          tier: tier,
          hopCount: 1, // Default; real hop from Meshtastic envelope
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
          hopCount: 1,
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
          hopCount: 1,
          lastSeenMs: peer.lastSeenMs,
          features: peer.features,
          mrrpServiceIds: serviceIds,
        ),
      );
    }
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

/// Aggregated service availability across all nearby peers.
///
/// Returns a map of service ID to the count of peers offering that service.
final meshExplorerServicesProvider = Provider<Map<int, int>>((ref) {
  final enabled = ref.watch(meshExplorerEnabledProvider);
  if (!enabled) return const {};

  ref.watch(mrrpAdvertEpochProvider);
  final cachedServices = ref.watch(mrrpCachedServicesProvider);

  final serviceCounts = <int, int>{};
  for (final entry in cachedServices.entries) {
    for (final service in entry.value) {
      if (!_isPublicService(
        service.descriptor.serviceId,
        service.descriptor.serviceFlags,
      )) {
        continue;
      }
      serviceCounts[service.descriptor.serviceId] =
          (serviceCounts[service.descriptor.serviceId] ?? 0) + 1;
    }
  }

  return serviceCounts;
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
bool _isPublicService(int serviceId, int serviceFlags) {
  if (serviceFlags & MrrpServiceFlags.testOnly != 0) return false;
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
