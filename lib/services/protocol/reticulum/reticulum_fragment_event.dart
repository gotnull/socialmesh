// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

/// One inbound port-76 (`RETICULUM_TUNNEL_APP`) fragment as seen on the mesh.
///
/// Phase 1 treats every payload as an opaque fragment. No reassembly, no
/// header parsing — that is Phase 2 work driven by a captured corpus and
/// a published spec.
class ReticulumFragmentEvent {
  ReticulumFragmentEvent({
    required this.timestampMs,
    required this.fromNode,
    required this.toNode,
    required this.packetId,
    required this.channel,
    required this.rssi,
    required this.snr,
    required this.payload,
  }) : payloadLen = payload.length;

  final int timestampMs;
  final int fromNode;
  final int toNode;
  final int packetId;
  final int channel;
  final int? rssi;
  final double? snr;
  final Uint8List payload;
  final int payloadLen;

  @override
  String toString() =>
      'ReticulumFragmentEvent(ts=$timestampMs, from=$fromNode, to=$toNode, '
      'pid=$packetId, ch=$channel, rssi=$rssi, snr=$snr, len=$payloadLen)';
}
