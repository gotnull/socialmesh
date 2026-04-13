// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Avatar Stack — co-seen avatar cluster for NodeDex cards.
//
// This file provides:
// - nodeDexAvatarStackProvider: selects and orders co-seen nodes for a
//   given NodeDex entry, producing AvatarStackItem view models.
// - NodeDexAvatarStack: a ConsumerWidget that wires the provider
//   to the reusable AnimatedAvatarStack component.
//
// The provider does all the data selection and ordering. The widget
// is a thin bridge that reads the provider and feeds the result
// to the generic AnimatedAvatarStack.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/animated_avatar_stack.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/app_providers.dart';
import '../../nodes/node_display_name_resolver.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import 'sigil_painter.dart';

/// Provider that builds [AvatarStackItem] view models for a given node's
/// co-seen peers.
///
/// Selection logic:
/// 1. Read the recent eligible co-seen links provider.
/// 2. Filter to peers that also exist in the NodeDex.
/// 3. Preserve the provider's deterministic ordering.
/// 4. Map to [AvatarStackItem] with sigil rendering and display name.
///
/// This is a family provider keyed by nodeNum.
final nodeDexAvatarStackProvider = Provider.family<List<AvatarStackItem>, int>((
  ref,
  nodeNum,
) {
  final coSeenLinks = ref.watch(nodeDexRecentCoSeenLinksProvider(nodeNum));
  if (coSeenLinks.isEmpty) return const [];

  final allEntries = ref.watch(nodeDexProvider);
  final liveNodes = ref.watch(nodesProvider);

  // Build sortable list of co-seen peers that exist in the NodeDex.
  final peers = <_CoSeenPeer>[];
  for (final link in coSeenLinks) {
    final peerNum = link.otherNodeNum;
    final peerEntry = allEntries[peerNum];
    if (peerEntry == null) continue;
    peers.add(
      _CoSeenPeer(
        nodeNum: peerNum,
        entry: peerEntry,
        relationship: link.relationship,
      ),
    );
  }

  if (peers.isEmpty) return const [];

  // Build view models.
  return peers.map((peer) {
    final liveNode = liveNodes[peer.nodeNum];
    final displayName =
        peer.entry.localNickname ??
        liveNode?.displayName ??
        peer.entry.lastKnownName ??
        NodeDisplayNameResolver.defaultName(peer.nodeNum);

    final sigil = peer.entry.sigil ?? SigilGenerator.generate(peer.nodeNum);

    return AvatarStackItem(
      id: peer.nodeNum.toString(),
      child: SigilAvatar(
        sigil: sigil,
        nodeNum: peer.nodeNum,
        size:
            AvatarStackDefaults.avatarSize -
            AvatarStackDefaults.borderWidth * 2,
      ),
      tooltip: displayName,
      semanticLabel: displayName,
    );
  }).toList();
});

/// Internal sortable peer record used during provider computation.
class _CoSeenPeer {
  final int nodeNum;
  final NodeDexEntry entry;
  final CoSeenRelationship relationship;

  const _CoSeenPeer({
    required this.nodeNum,
    required this.entry,
    required this.relationship,
  });
}

/// A NodeDex-specific wrapper that wires [nodeDexAvatarStackProvider]
/// to the reusable [AnimatedAvatarStack] component.
///
/// Drop this into any NodeDex card layout:
///
/// ```dart
/// NodeDexAvatarStack(nodeNum: entry.nodeNum)
/// ```
///
/// It handles provider wiring, reduced-motion, and semantics.
/// If the node has no co-seen peers, it renders [SizedBox.shrink].
class NodeDexAvatarStack extends ConsumerWidget {
  /// The node number to display co-seen peers for.
  final int nodeNum;

  /// Maximum number of avatars to show.
  final int maxVisible;

  /// Avatar diameter.
  final double avatarSize;

  /// Optional callback when an individual avatar is tapped.
  /// Receives the node number of the tapped peer.
  final void Function(int peerNodeNum)? onPeerTap;

  const NodeDexAvatarStack({
    super.key,
    required this.nodeNum,
    this.maxVisible = AvatarStackDefaults.maxVisible,
    this.avatarSize = AvatarStackDefaults.avatarSize,
    this.onPeerTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(nodeDexAvatarStackProvider(nodeNum));
    if (items.isEmpty) return const SizedBox.shrink();

    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    // Attach tap handlers if the consumer provided onPeerTap.
    final itemsWithTap = onPeerTap != null
        ? items.map((item) {
            final peerNodeNum = int.parse(item.id);
            return AvatarStackItem(
              id: item.id,
              child: item.child,
              tooltip: item.tooltip,
              semanticLabel: item.semanticLabel,
              onTap: () => onPeerTap!(peerNodeNum),
            );
          }).toList()
        : items;

    return AnimatedAvatarStack(
      items: itemsWithTap,
      maxVisible: maxVisible,
      avatarSize: avatarSize,
      animationEnabled: !reduceMotion,
      semanticLabel: context.l10n.avatarStackCoSeenLabel(items.length),
    );
  }
}
