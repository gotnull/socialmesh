// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Cross-feature composition providers that project existing mesh-services
/// and MRRP advert state into views the SIP Hub needs.
///
/// Lives in `lib/providers/` rather than `lib/features/sip/providers/`
/// because it bridges two features (`sip/` and `mesh_services/`). Direct
/// feature→feature imports are banned; this file is the sanctioned
/// composition layer, analogous to [`mesh_explorer_providers.dart`].
///
/// No new subscriptions. No new transport. No protocol change. These
/// providers are pure projections of:
///
/// - [`meshServiceActiveInstancesProvider`] (local services owned by user)
/// - [`mrrpCachedServicesProvider`] (remote peers' advertised services)
///
/// Watched by the SIP Hub "Your Services" section and the peer detail
/// sheet's services section.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/mesh_services/models/mesh_service_instance.dart';
import '../features/mesh_services/providers/mesh_service_providers.dart';
import '../services/protocol/sip/mrrp_advert_engine.dart';
import '../services/protocol/sip/mrrp_messages_advert.dart';
import '../services/protocol/sip/mrrp_types.dart';
import 'mrrp_providers.dart';

/// Maximum service chips shown inline on a peer tile before we switch
/// to a "+N more" indicator. Scannable-by-design ceiling.
const int peerServicePreviewMax = 3;

// ---------------------------------------------------------------------------
// Local services (the user's own published instances)
// ---------------------------------------------------------------------------

/// Summary of the local user's active services. Watched by the SIP Hub
/// "Your Services" section header.
///
/// Emits `AsyncValue<List<MeshServiceInstance>>` — the UI layer handles
/// loading/error gracefully and renders an empty section when the
/// feature is disabled or the list is empty.
final localServicesSummaryProvider = FutureProvider<List<MeshServiceInstance>>((
  ref,
) async {
  // Reuses the authoritative mesh-services provider. No duplicate
  // subscription — this is just a re-surfacing for the SIP Hub UI.
  return ref.watch(meshServiceActiveInstancesProvider.future);
});

/// Count of active local services. Small, cheap scalar for the section
/// header badge. Derived from [localServicesSummaryProvider].
final localServicesCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(localServicesSummaryProvider)
      .whenData((list) => list.length);
});

// ---------------------------------------------------------------------------
// Remote peer services (what this peer advertises to us)
// ---------------------------------------------------------------------------

/// Services advertised by the given peer (deduplicated, non-expired,
/// public-only). Capped at [peerServicePreviewMax] for inline use on
/// the peer tile.
///
/// Returns an empty list if the peer has no advertised services OR is
/// not in the advert cache yet. The full (uncapped) list is available
/// via [peerServicesFullProvider].
final peerServicesPreviewProvider =
    Provider.family<List<MrrpCachedService>, int>((ref, peerNodeId) {
      return _filterPeerServices(
        ref.watch(mrrpCachedServicesProvider)[peerNodeId],
        limit: peerServicePreviewMax,
      );
    });

/// Full deduplicated list of services advertised by a peer. Used in the
/// peer detail sheet's services section.
final peerServicesFullProvider = Provider.family<List<MrrpCachedService>, int>((
  ref,
  peerNodeId,
) {
  return _filterPeerServices(
    ref.watch(mrrpCachedServicesProvider)[peerNodeId],
    limit: null,
  );
});

/// Total count of advertised services for a peer (after dedup + expiry
/// + public filter). Used by the peer tile to render a "+N more" tag
/// when the preview is truncated.
final peerServicesCountProvider = Provider.family<int, int>((ref, peerNodeId) {
  return ref.watch(peerServicesFullProvider(peerNodeId)).length;
});

// ---------------------------------------------------------------------------
// Filtering rules
// ---------------------------------------------------------------------------

/// Apply uniform dedup + expiry + public-only filtering to a peer's
/// raw advert cache. Kept as a pure function so tests can verify the
/// rules independently of the Riverpod graph.
///
/// [limit] null returns the full filtered list; non-null caps at that
/// many entries, preserving insertion order from the advert cache.
List<MrrpCachedService> _filterPeerServices(
  List<MrrpCachedService>? raw, {
  required int? limit,
}) {
  if (raw == null || raw.isEmpty) return const <MrrpCachedService>[];
  final seen = <_ServiceKey>{};
  final out = <MrrpCachedService>[];
  for (final entry in raw) {
    if (entry.isExpired) continue;
    if (!_isPublicService(entry.descriptor)) continue;
    final key = _ServiceKey(
      serviceId: entry.descriptor.serviceId,
      versionMajor: entry.descriptor.versionMajor,
      versionMinor: entry.descriptor.versionMinor,
    );
    if (!seen.add(key)) continue;
    out.add(entry);
    if (limit != null && out.length >= limit) break;
  }
  return List<MrrpCachedService>.unmodifiable(out);
}

/// A service is "public" (shown in the peer-services view) when its
/// descriptor does NOT mark it invisible / internal-only. Matches the
/// same semantics used by [`mesh_explorer_providers.dart`] so the two
/// surfaces stay consistent.
bool _isPublicService(MrrpAdvertDescriptor d) {
  // Hide ephemeral-only without user-visible flag. Those are plumbing
  // services (echo harness etc.) that users should not see.
  final userVisible =
      (d.serviceFlags & MrrpServiceFlags.userVisible) ==
      MrrpServiceFlags.userVisible;
  return userVisible;
}

class _ServiceKey {
  final int serviceId;
  final int versionMajor;
  final int versionMinor;

  const _ServiceKey({
    required this.serviceId,
    required this.versionMajor,
    required this.versionMinor,
  });

  @override
  bool operator ==(Object other) =>
      other is _ServiceKey &&
      other.serviceId == serviceId &&
      other.versionMajor == versionMajor &&
      other.versionMinor == versionMinor;

  @override
  int get hashCode => Object.hash(serviceId, versionMajor, versionMinor);
}
