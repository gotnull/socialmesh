// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import '../protocol/protocol_service.dart';

/// Shortest age threshold offered for clearing stale nodes, in days.
const int kStaleNodeMinDays = 1;

/// Longest age threshold offered for clearing stale nodes, in days.
const int kStaleNodeMaxDays = 180;

/// Threshold used when clearing is first turned on, in days.
const int kStaleNodeDefaultDays = 7;

/// Nodes that advertised a public key are kept at least this long, so a
/// short threshold cannot drop the key a DM to that node needs.
const int kStaleNodePublicKeyFloorDays = 7;

/// Pause between two node removals sent to the radio. One admin write
/// per node; the pause keeps a large cleanup from queueing hundreds of
/// writes on the link at once.
const Duration kStaleNodeRemovalPause = Duration(milliseconds: 100);

/// Node numbers in [nodes] that were last heard more than [days] days
/// before [now].
///
/// Kept: favourites, ignored nodes, [localNodeNum], and nodes with no
/// last-heard time. Nodes that advertised a public key are only stale
/// after at least [kStaleNodePublicKeyFloorDays] days. [days] of zero
/// or less selects nothing.
List<int> selectStaleNodeNums(
  Iterable<MeshNode> nodes, {
  required int days,
  required DateTime now,
  int? localNodeNum,
}) {
  if (days <= 0) return const [];
  final cutoff = now.subtract(Duration(days: days));
  final keyedCutoff = now.subtract(
    Duration(
      days: days < kStaleNodePublicKeyFloorDays
          ? kStaleNodePublicKeyFloorDays
          : days,
    ),
  );
  return [
    for (final node in nodes)
      if (node.nodeNum != localNodeNum &&
          !node.isFavorite &&
          !node.isIgnored &&
          node.lastHeard != null &&
          node.lastHeard!.isBefore(node.hasPublicKey ? keyedCutoff : cutoff))
        node.nodeNum,
  ];
}

/// Outcome of [removeStaleNodesFromRadio].
@immutable
class StaleNodeRemovalResult {
  /// Nodes that are gone from the radio, or that the radio never
  /// reported this session and so had nothing to remove there.
  final List<int> removed;

  /// Nodes the radio send failed for while the link was still up.
  final int failed;

  /// True when the link dropped before every node was handled.
  final bool stoppedOnDisconnect;

  const StaleNodeRemovalResult({
    required this.removed,
    required this.failed,
    required this.stoppedOnDisconnect,
  });
}

/// Removes [nodeNums] from the connected radio's node database, one
/// local admin write at a time with [pause] between writes.
///
/// Only nodes the radio reported this session ([ProtocolService.nodes])
/// get a write; the rest are app-only and count as removed straight
/// away. Stops at the first node after the link drops. [onProgress]
/// receives the number of nodes handled so far.
Future<StaleNodeRemovalResult> removeStaleNodesFromRadio(
  ProtocolService protocol,
  List<int> nodeNums, {
  Duration pause = kStaleNodeRemovalPause,
  void Function(int handled)? onProgress,
}) async {
  final radioNodes = protocol.nodes;
  final removed = <int>[];
  var failed = 0;
  var handled = 0;
  var stoppedOnDisconnect = false;
  var sent = 0;

  for (final nodeNum in nodeNums) {
    if (!radioNodes.containsKey(nodeNum)) {
      removed.add(nodeNum);
    } else {
      if (!protocol.isConnected) {
        stoppedOnDisconnect = true;
        break;
      }
      if (sent > 0) await Future<void>.delayed(pause);
      sent++;
      try {
        await protocol.removeNode(nodeNum);
        removed.add(nodeNum);
      } catch (e) {
        if (!protocol.isConnected) {
          AppLogging.nodes(
            'STALE_NODES: link dropped removing node $nodeNum: $e',
          );
          stoppedOnDisconnect = true;
          break;
        }
        failed++;
        AppLogging.nodes('STALE_NODES: remove failed node $nodeNum: $e');
      }
    }
    handled++;
    onProgress?.call(handled);
  }

  AppLogging.nodes(
    'STALE_NODES: removed=${removed.length} failed=$failed '
    'radioWrites=$sent of=${nodeNums.length} '
    'stoppedOnDisconnect=$stoppedOnDisconnect',
  );
  return StaleNodeRemovalResult(
    removed: removed,
    failed: failed,
    stoppedOnDisconnect: stoppedOnDisconnect,
  );
}
