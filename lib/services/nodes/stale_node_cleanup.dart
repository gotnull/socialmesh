// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart';

import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import '../protocol/admin_ack_tracker.dart';
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

/// How long the radio gets to confirm one removal. The firmware rewrites
/// its whole node database to flash for every removal, so a large
/// database on a slow flash chip takes well over a second.
const Duration kStaleNodeRemovalAckTimeout = Duration(seconds: 10);

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

  /// Nodes the radio did not confirm removing while the link was still
  /// up: the send failed, the radio refused, or the radio stopped
  /// answering.
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
/// local admin write at a time.
///
/// Each write waits for the radio to confirm it, up to [ackTimeout],
/// before the next is sent. Some radios queue only a few writes from the
/// phone and drop the rest, so the radio's answer, not a fixed pause,
/// sets the pace. A node counts as removed only once confirmed.
///
/// Only nodes the radio reported this session ([ProtocolService.nodes])
/// get a write; the rest are app-only and count as removed straight
/// away. Stops at the first node after the link drops. Once a write goes
/// unanswered, no further writes are sent and the remaining radio nodes
/// count as failed. [onProgress] receives the number of nodes handled so
/// far.
Future<StaleNodeRemovalResult> removeStaleNodesFromRadio(
  ProtocolService protocol,
  List<int> nodeNums, {
  Duration ackTimeout = kStaleNodeRemovalAckTimeout,
  void Function(int handled)? onProgress,
}) async {
  final radioNodes = protocol.nodes;
  final removed = <int>[];
  var failed = 0;
  var handled = 0;
  var stoppedOnDisconnect = false;
  var radioUnresponsive = false;
  var sent = 0;

  for (final nodeNum in nodeNums) {
    if (!radioNodes.containsKey(nodeNum)) {
      removed.add(nodeNum);
    } else if (radioUnresponsive) {
      failed++;
    } else {
      if (!protocol.isConnected) {
        stoppedOnDisconnect = true;
        break;
      }
      sent++;
      try {
        final ack = await protocol.removeNode(nodeNum, ackTimeout: ackTimeout);
        switch (ack) {
          case AdminAckSuccess():
            removed.add(nodeNum);
          case AdminAckFailure(:final error):
            failed++;
            AppLogging.nodes(
              'STALE_NODES: radio refused node $nodeNum: ${error.name}',
            );
          case AdminAckCancelled():
            stoppedOnDisconnect = true;
          case AdminAckTimeout() || null:
            if (!protocol.isConnected) {
              stoppedOnDisconnect = true;
            } else {
              failed++;
              radioUnresponsive = true;
              AppLogging.nodes(
                'STALE_NODES: no answer for node $nodeNum after '
                '${ackTimeout.inSeconds}s, stopping writes',
              );
            }
        }
        if (stoppedOnDisconnect) break;
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
    'stoppedOnDisconnect=$stoppedOnDisconnect '
    'radioUnresponsive=$radioUnresponsive',
  );
  return StaleNodeRemovalResult(
    removed: removed,
    failed: failed,
    stoppedOnDisconnect: stoppedOnDisconnect,
  );
}
