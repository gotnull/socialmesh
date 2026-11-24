// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../models/meshcore_contact.dart';

/// A `CMD_SEND_TRACE_PATH` request: the path of hop hashes and the flags
/// byte whose low two bits give the hash width as `1 << path_sz`.
class MeshCoreTraceRequest {
  const MeshCoreTraceRequest({required this.path, required this.flags});

  final Uint8List path;
  final int flags;

  /// Bytes per hop hash.
  int get hashSize => 1 << (flags & 0x03);
}

/// Builds a round-trip trace to [target] along its route, as meshcore-open
/// does: out through each repeater on the contact's path (or its forced
/// path), to the target, and back through the same repeaters in reverse.
/// Every node on the way must retransmit the trace (`allowPacketForward`),
/// so a chat contact answers only when it repeats packets.
///
/// Trace hashes are 1, 2 or 4 bytes wide; a 3-byte route is traced with
/// 4-byte key prefixes, each hop expanded from a known contact. Returns
/// null when a hop cannot be expanded.
MeshCoreTraceRequest? buildMeshCoreTraceRequest({
  required MeshCoreContact target,
  required List<MeshCoreContact> contacts,
}) {
  final Uint8List routeBytes;
  final int hopWidth;
  final override = target.pathOverride;
  if (override != null) {
    // A forced path is entered one byte per hop; forced flood or direct
    // carries no hops.
    routeBytes = override > 0
        ? (target.pathOverrideBytes ?? Uint8List(0))
        : Uint8List(0);
    hopWidth = 1;
  } else if (target.pathLength > 0) {
    routeBytes = target.path;
    hopWidth = target.pathHashSize;
  } else {
    routeBytes = Uint8List(0);
    hopWidth = 1;
  }

  final traceWidth = hopWidth <= 1 ? 1 : (hopWidth == 2 ? 2 : 4);
  final flags = traceWidth == 1 ? 0 : (traceWidth == 2 ? 1 : 2);

  final outbound = <Uint8List>[];
  for (var i = 0; i + hopWidth <= routeBytes.length; i += hopWidth) {
    final hop = Uint8List.sublistView(routeBytes, i, i + hopWidth);
    final expanded = hopWidth == traceWidth
        ? Uint8List.fromList(hop)
        : _expandHop(hop, traceWidth, contacts);
    if (expanded == null) return null;
    outbound.add(expanded);
  }

  if (target.publicKey.length < traceWidth) return null;
  final targetHash = Uint8List.fromList(
    target.publicKey.sublist(0, traceWidth),
  );
  if (outbound.isEmpty || !_sameBytes(outbound.last, targetHash)) {
    outbound.add(targetHash);
  }

  final hops = [
    ...outbound,
    ...outbound.sublist(0, outbound.length - 1).reversed,
  ];
  return MeshCoreTraceRequest(
    path: Uint8List.fromList([for (final h in hops) ...h]),
    flags: flags,
  );
}

// The full prefix of the newest heard contact whose key starts with [hop].
Uint8List? _expandHop(
  Uint8List hop,
  int width,
  List<MeshCoreContact> contacts,
) {
  MeshCoreContact? best;
  for (final c in contacts) {
    if (c.publicKey.length < width) continue;
    if (!_sameBytes(Uint8List.sublistView(c.publicKey, 0, hop.length), hop)) {
      continue;
    }
    if (best == null || c.lastSeen.isAfter(best.lastSeen)) best = c;
  }
  return best == null
      ? null
      : Uint8List.fromList(best.publicKey.sublist(0, width));
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
