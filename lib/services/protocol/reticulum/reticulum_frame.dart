// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

/// A fully reassembled RNS frame — the byte-stream that
/// `landandair/RNS_Over_Meshtastic`'s `PacketHandler.split_data()`
/// was originally handed by RNS, before fragmentation.
///
/// Phase 2 stops here: a [ReticulumFrame] is opaque RNS bytes. It is
/// not interpreted further by SocialMesh. A future Phase 3 TCP bridge
/// would HDLC-encode `body` and ship it to a host-side `rnsd` for
/// RNS itself to process.
class ReticulumFrame {
  const ReticulumFrame({
    required this.fromNode,
    required this.index,
    required this.fragmentCount,
    required this.body,
    required this.firstSeenMs,
    required this.lastSeenMs,
  });

  /// The Meshtastic source node ID this frame was assembled from.
  final int fromNode;

  /// The 1-byte frame identifier (`index` byte) that all fragments
  /// of this frame shared. Cycles 0..255 per sender.
  final int index;

  /// Total fragment count `N`. Equals `abs(last_fragment.position)`
  /// per the spec.
  final int fragmentCount;

  /// Concatenated body bytes from all N fragments, in order
  /// (`fragments[1] .. fragments[N]` per §11.6.2). This is a complete
  /// RNS frame ready to hand to RNS for further processing.
  final Uint8List body;

  /// Wall-clock timestamp (ms since epoch) when the FIRST fragment
  /// of this frame was observed.
  final int firstSeenMs;

  /// Wall-clock timestamp when the LAST fragment arrived (i.e.
  /// when this frame became complete and was emitted).
  final int lastSeenMs;

  int get bodyLen => body.length;

  /// How long this frame took to assemble, end-to-end.
  Duration get assemblyDuration =>
      Duration(milliseconds: lastSeenMs - firstSeenMs);

  @override
  String toString() =>
      'ReticulumFrame(from=0x${fromNode.toRadixString(16)}, '
      'index=$index, N=$fragmentCount, body_len=$bodyLen)';
}
