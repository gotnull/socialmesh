// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/nodedex/providers/nodedex_providers.dart';
import '../providers/app_providers.dart';

/// Resolved mesh identity for a node, containing both the display name
/// and the node number for sigil rendering.
class MeshIdentity {
  /// The best available display name for this node.
  final String displayName;

  /// The mesh node number (for SigilAvatar rendering).
  /// Null only when no mesh node could be resolved at all.
  final int? nodeNum;

  /// Whether this identity was resolved from a live node (currently
  /// visible on the mesh) vs a cached/fallback source.
  final bool isLive;

  const MeshIdentity({
    required this.displayName,
    this.nodeNum,
    this.isLive = false,
  });
}

/// Resolves the best display name for a mesh node number.
///
/// Resolution chain (first non-null wins):
/// 1. Live node from [nodesProvider] (longName or shortName)
/// 2. Cached name from NodeDex [lastKnownName]
/// 3. Hex ID fallback (e.g. "!81C42D94")
///
/// Use this everywhere a mesh node name is displayed to ensure
/// consistency across Activity, Signals, NodeDex, and any other
/// screen that shows node identities.
String resolveMeshNodeName(WidgetRef ref, int nodeNum) {
  // 1. Live node — most accurate, real-time from the mesh.
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];
  if (node != null) {
    final long = node.longName;
    final short = node.shortName;
    if (long != null && long.isNotEmpty) return long;
    if (short != null && short.isNotEmpty) return short;
  }

  // 2. NodeDex cached name — persisted from a previous session.
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry?.lastKnownName != null) return entry!.lastKnownName!;

  // 3. Hex ID fallback.
  return _hexName(nodeNum);
}

/// Resolves full mesh identity (name + nodeNum + liveness) for a node.
///
/// Same resolution chain as [resolveMeshNodeName] but returns
/// structured data so callers can make decisions based on source.
MeshIdentity resolveMeshIdentity(WidgetRef ref, int nodeNum) {
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];
  if (node != null) {
    final long = node.longName;
    final short = node.shortName;
    if (long != null && long.isNotEmpty) {
      return MeshIdentity(displayName: long, nodeNum: nodeNum, isLive: true);
    }
    if (short != null && short.isNotEmpty) {
      return MeshIdentity(displayName: short, nodeNum: nodeNum, isLive: true);
    }
  }

  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry?.lastKnownName != null) {
    return MeshIdentity(
      displayName: entry!.lastKnownName!,
      nodeNum: nodeNum,
      isLive: false,
    );
  }

  return MeshIdentity(
    displayName: _hexName(nodeNum),
    nodeNum: nodeNum,
    isLive: false,
  );
}

/// Resolves the short name (4-char hex suffix) for a mesh node.
///
/// Resolution chain:
/// 1. Live node shortName
/// 2. Last 4 hex digits of node number
String resolveMeshShortName(WidgetRef ref, int nodeNum) {
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];
  if (node != null) {
    final short = node.shortName;
    if (short != null && short.isNotEmpty) return short;
  }

  final hexId = nodeNum.toRadixString(16).toUpperCase();
  return hexId.length >= 4 ? hexId.substring(hexId.length - 4) : hexId;
}

/// Formats a node number as a hex ID string (e.g. "!81C42D94").
String _hexName(int nodeNum) {
  return '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}
