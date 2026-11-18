// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../models/social.dart';
import '../services/social_service.dart';
import '../services/content_moderation_service.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'profile_providers.dart';

// ===========================================================================
// SERVICE PROVIDERS
// ===========================================================================

/// Provider for the SocialService singleton.
final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService();
});

/// Provider for the ContentModerationService singleton.
final contentModerationServiceProvider = Provider<ContentModerationService>((
  ref,
) {
  return ContentModerationService();
});

// ===========================================================================
// PROFILE BY NODE ID & LINKED NODES
// ===========================================================================

/// Provider to find a user's public profile by their linked mesh node ID.
/// Returns null if no user has this node in their linkedNodeIds.
final profileByNodeIdProvider = FutureProvider.autoDispose
    .family<PublicProfile?, int>((ref, nodeId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getProfileByNodeId(nodeId);
    });

/// Provider for current user's linked node IDs with real-time updates.
/// Uses local profile data as fallback when Firestore is unavailable.
final linkedNodeIdsProvider = StreamProvider.autoDispose<List<int>>((ref) {
  final service = ref.watch(socialServiceProvider);
  try {
    return service.watchLinkedNodeIds();
  } catch (e) {
    // Fallback to local profile if Firestore is unavailable
    final localProfile = ref.read(userProfileProvider).value;
    return Stream.value(localProfile?.linkedNodeIds ?? []);
  }
});

/// Provider to check if a specific node is linked to current user's profile.
/// Now watches the linkedNodeIds stream for real-time updates.
final isNodeLinkedProvider = StreamProvider.autoDispose.family<bool, int>((
  ref,
  nodeId,
) {
  final service = ref.watch(socialServiceProvider);
  return service.watchLinkedNodeIds().map(
    (linkedNodes) => linkedNodes.contains(nodeId),
  );
});

/// Link a node to current user's profile
Future<void> linkNode(
  WidgetRef ref,
  int nodeId, {
  bool setPrimary = false,
}) async {
  final service = ref.read(socialServiceProvider);

  // Get node metadata to cache for display when node isn't in local store
  final nodes = ref.read(nodesProvider);
  final node = nodes[nodeId];

  await service.linkNodeToProfile(
    nodeId,
    setPrimary: setPrimary,
    longName: node?.longName,
    shortName: node?.shortName,
    avatarColor: node?.avatarColor,
  );

  // Update local profile storage to persist linked nodes across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  if (currentProfile != null) {
    final updatedLinkedNodes = [...currentProfile.linkedNodeIds];
    if (!updatedLinkedNodes.contains(nodeId)) {
      updatedLinkedNodes.add(nodeId);
    }
    await userProfileNotifier.updateLinkedNodes(
      updatedLinkedNodes,
      primaryNodeId: setPrimary || updatedLinkedNodes.length == 1
          ? nodeId
          : currentProfile.primaryNodeId,
    );
  }

  // Invalidate providers to refresh state
  ref.invalidate(linkedNodeIdsProvider);
  ref.invalidate(isNodeLinkedProvider(nodeId));
  ref.invalidate(profileByNodeIdProvider(nodeId));
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

/// Refresh cached metadata for all linked nodes using current mesh data.
/// Call this when connecting to a device to ensure cached info is current.
/// This updates Firestore with the latest node names so they display correctly
/// even when viewing the profile from a different device.
Future<void> refreshLinkedNodeMetadata(Ref ref) async {
  final currentUser = ref.read(currentUserProvider);
  if (currentUser == null) return;

  final service = ref.read(socialServiceProvider);
  final nodes = ref.read(nodesProvider);
  final linkedNodeIds = ref.read(linkedNodeIdsProvider).asData?.value ?? [];

  if (linkedNodeIds.isEmpty) return;

  var updated = false;
  for (final nodeId in linkedNodeIds) {
    final node = nodes[nodeId];
    // Only update if we have meaningful node data (not just the ID)
    if (node != null && (node.longName != null || node.shortName != null)) {
      try {
        await service.updateLinkedNodeMetadata(
          nodeId,
          longName: node.longName,
          shortName: node.shortName,
          avatarColor: node.avatarColor,
        );
        updated = true;
      } catch (e) {
        // Silently fail - this is opportunistic refresh
        AppLogging.social(
          'Failed to update linked node metadata for $nodeId: $e',
        );
      }
    }
  }

  // If we updated any metadata, invalidate the profile to pick up changes
  if (updated) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

/// Check if a node's identity fields have changed in a way that requires
/// updating the cached metadata. Only compares display-relevant fields.
bool _hasIdentityChanged(MeshNode node, MeshNode? previousNode) {
  if (previousNode == null) {
    // New node with identity data = changed
    return node.longName != null || node.shortName != null;
  }
  return node.longName != previousNode.longName ||
      node.shortName != previousNode.shortName ||
      node.avatarColor != previousNode.avatarColor;
}

/// Event-driven handler for node updates. Called from NodesNotifier when
/// a node is updated. If the node is linked to the current user's profile
/// and its identity fields have changed, updates the cached metadata in Firestore.
///
/// This is the primary mechanism for keeping linked node metadata current.
/// The connection-triggered refresh serves as a bootstrap fallback.
void onLinkedNodeUpdated(Ref ref, MeshNode node, MeshNode? previousNode) {
  // Skip if no identity change
  if (!_hasIdentityChanged(node, previousNode)) return;

  // Skip if user not signed in
  final currentUser = ref.read(currentUserProvider);
  if (currentUser == null) return;

  // Check if this node is linked to the current user (async lookup)
  final linkedNodeIds = ref.read(linkedNodeIdsProvider).asData?.value;
  if (linkedNodeIds == null || !linkedNodeIds.contains(node.nodeNum)) return;

  // Update metadata in Firestore (fire-and-forget)
  final service = ref.read(socialServiceProvider);
  service
      .updateLinkedNodeMetadata(
        node.nodeNum,
        longName: node.longName,
        shortName: node.shortName,
        avatarColor: node.avatarColor,
      )
      .then((_) {
        // Invalidate profile to pick up new metadata
        ref.invalidate(publicProfileProvider(currentUser.uid));
        AppLogging.social(
          'Updated linked node metadata for ${node.displayName} (${node.nodeNum})',
        );
      })
      .catchError((e) {
        // Silently fail - opportunistic update
        AppLogging.social('Failed to update linked node metadata: $e');
      });
}

/// Set a linked node as the primary node
Future<void> setPrimaryNode(WidgetRef ref, int nodeId) async {
  final service = ref.read(socialServiceProvider);
  await service.setPrimaryNode(nodeId);

  // Update local profile storage to persist primary node across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  if (currentProfile != null) {
    await userProfileNotifier.updateLinkedNodes(
      currentProfile.linkedNodeIds,
      primaryNodeId: nodeId,
    );
  }

  // Invalidate providers to refresh state
  ref.invalidate(linkedNodeIdsProvider);
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
    ref.invalidate(publicProfileStreamProvider(currentUser.uid));
  }
}

// ===========================================================================
// PUBLIC PROFILE
// ===========================================================================

/// Provider for a public profile (async).
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile?, String>((ref, userId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getPublicProfile(userId);
    });

/// Stream provider for real-time public profile updates.
/// Not auto-disposed to keep stream active across navigation.
final publicProfileStreamProvider =
    StreamProvider.family<PublicProfile?, String>((ref, userId) {
      final service = ref.watch(socialServiceProvider);
      return service.watchPublicProfile(userId);
    });
