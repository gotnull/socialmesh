// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../features/nodedex/providers/nodedex_providers.dart';
import '../providers/app_providers.dart';

/// The source that successfully resolved a mesh node's identity.
///
/// Used for telemetry to measure how many nodes are resolved from each
/// source, which informs whether the backfill script needs to be run
/// and how effective NodeDex caching is.
enum IdentityResolutionSource {
  /// Resolved from live mesh node data (nodesProvider).
  /// Best case — the node is currently visible on the mesh.
  liveMesh,

  /// Resolved from NodeDex cached name (lastKnownName in local SQLite).
  /// Good case — node was seen before and name was persisted locally.
  nodeDexCached,

  /// Fell back to hex ID (e.g. "!81C42D94").
  /// Acceptable for nodes never seen with a human-readable name.
  hexFallback,
}

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

  /// Which resolution source provided the identity.
  /// Null only when no mesh node number was available at all
  /// (pure profile/actorId fallback outside the mesh identity chain).
  final IdentityResolutionSource? source;

  const MeshIdentity({
    required this.displayName,
    this.nodeNum,
    this.isLive = false,
    this.source,
  });
}

/// Telemetry counters for mesh identity resolution.
///
/// These are session-scoped (reset on app restart) and logged
/// periodically to help measure how many nodes are resolved from
/// each source. Use [IdentityResolutionTelemetry.snapshot] to get
/// a point-in-time summary for logging or diagnostics.
class IdentityResolutionTelemetry {
  IdentityResolutionTelemetry._();

  static int _liveMeshCount = 0;
  static int _nodeDexCachedCount = 0;
  static int _hexFallbackCount = 0;
  static int _totalResolutions = 0;

  /// Interval (in resolution count) at which a summary is logged.
  /// Every Nth resolution triggers a telemetry breadcrumb.
  static const int _logInterval = 50;

  /// Record a resolution event from the given source.
  static void record(IdentityResolutionSource source, int nodeNum) {
    _totalResolutions++;

    switch (source) {
      case IdentityResolutionSource.liveMesh:
        _liveMeshCount++;
      case IdentityResolutionSource.nodeDexCached:
        _nodeDexCachedCount++;
      case IdentityResolutionSource.hexFallback:
        _hexFallbackCount++;
    }

    // Periodic summary — avoids log spam while still providing visibility.
    if (_totalResolutions % _logInterval == 0) {
      AppLogging.nodeDex(
        'IdentityResolution telemetry '
        '(session total: $_totalResolutions): '
        'liveMesh=$_liveMeshCount, '
        'nodeDexCached=$_nodeDexCachedCount, '
        'hexFallback=$_hexFallbackCount',
      );
    }
  }

  /// Returns a snapshot of current telemetry counters.
  static Map<String, int> snapshot() {
    return {
      'total': _totalResolutions,
      'liveMesh': _liveMeshCount,
      'nodeDexCached': _nodeDexCachedCount,
      'hexFallback': _hexFallbackCount,
    };
  }

  /// Reset all counters (used in tests).
  static void reset() {
    _liveMeshCount = 0;
    _nodeDexCachedCount = 0;
    _hexFallbackCount = 0;
    _totalResolutions = 0;
  }
}

/// Resolves the best display name for a mesh node number.
///
/// Resolution chain (first non-null wins):
/// 1. Live node from [nodesProvider] (longName or shortName)
/// 2. Cached name from NodeDex [lastKnownName]
/// 3. Hex ID fallback (e.g. "!81C42D94")
///
/// This function is fully offline — it never makes network requests.
/// All data sources are local: live mesh telemetry and local SQLite.
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
    if (long != null && long.isNotEmpty) {
      IdentityResolutionTelemetry.record(
        IdentityResolutionSource.liveMesh,
        nodeNum,
      );
      return long;
    }
    if (short != null && short.isNotEmpty) {
      IdentityResolutionTelemetry.record(
        IdentityResolutionSource.liveMesh,
        nodeNum,
      );
      return short;
    }
  }

  // 2. NodeDex cached name — persisted from a previous session.
  // Fully local (SQLite), works offline and without sign-in.
  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry?.lastKnownName != null) {
    IdentityResolutionTelemetry.record(
      IdentityResolutionSource.nodeDexCached,
      nodeNum,
    );
    return entry!.lastKnownName!;
  }

  // 3. Hex ID fallback.
  IdentityResolutionTelemetry.record(
    IdentityResolutionSource.hexFallback,
    nodeNum,
  );
  return _hexName(nodeNum);
}

/// Resolves full mesh identity (name + nodeNum + liveness) for a node.
///
/// Same resolution chain as [resolveMeshNodeName] but returns
/// structured data so callers can make decisions based on source.
///
/// This function is fully offline — it never makes network requests.
MeshIdentity resolveMeshIdentity(WidgetRef ref, int nodeNum) {
  final nodes = ref.watch(nodesProvider);
  final node = nodes[nodeNum];
  if (node != null) {
    final long = node.longName;
    final short = node.shortName;
    if (long != null && long.isNotEmpty) {
      IdentityResolutionTelemetry.record(
        IdentityResolutionSource.liveMesh,
        nodeNum,
      );
      return MeshIdentity(
        displayName: long,
        nodeNum: nodeNum,
        isLive: true,
        source: IdentityResolutionSource.liveMesh,
      );
    }
    if (short != null && short.isNotEmpty) {
      IdentityResolutionTelemetry.record(
        IdentityResolutionSource.liveMesh,
        nodeNum,
      );
      return MeshIdentity(
        displayName: short,
        nodeNum: nodeNum,
        isLive: true,
        source: IdentityResolutionSource.liveMesh,
      );
    }
  }

  final entry = ref.watch(nodeDexEntryProvider(nodeNum));
  if (entry?.lastKnownName != null) {
    IdentityResolutionTelemetry.record(
      IdentityResolutionSource.nodeDexCached,
      nodeNum,
    );
    return MeshIdentity(
      displayName: entry!.lastKnownName!,
      nodeNum: nodeNum,
      isLive: false,
      source: IdentityResolutionSource.nodeDexCached,
    );
  }

  IdentityResolutionTelemetry.record(
    IdentityResolutionSource.hexFallback,
    nodeNum,
  );
  return MeshIdentity(
    displayName: _hexName(nodeNum),
    nodeNum: nodeNum,
    isLive: false,
    source: IdentityResolutionSource.hexFallback,
  );
}

/// Resolves the short name (4-char hex suffix) for a mesh node.
///
/// Resolution chain:
/// 1. Live node shortName
/// 2. Last 4 hex digits of node number
///
/// This function is fully offline.
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
