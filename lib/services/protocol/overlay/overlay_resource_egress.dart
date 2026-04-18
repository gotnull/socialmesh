// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Narrow outbound contract used by `OverlayResourceEngine`.
///
/// The engine never touches [OverlayLinkEngine] or [ProtocolService]
/// directly. Outbound SPP v0.2 frames are handed to an implementation
/// of [OverlayResourceEgress], which is responsible for wrapping them
/// in a `LINK_DATA` frame (when a live link exists for the peer) and
/// forwarding them. P4 defines only the contract and a recording
/// test adapter. The production wiring adapter lands in P5.
library;

import 'dart:typed_data';

import 'overlay_resource_codec.dart';

/// Outbound delivery surface. Implementations may drop frames (rate
/// limit, offline, link expired) and return `false` — the engine
/// tracks this and retries via its own backoff policy.
abstract class OverlayResourceEgress {
  /// Send [frame] to the peer identified by [peerEndpointHint].
  ///
  /// [linkId] is an advisory current-session hint; the egress
  /// implementation may use it to pick an existing link, or fall
  /// back to endpoint-hint lookup.
  ///
  /// [peerNodeNum] is the ephemeral transport address — used by the
  /// production adapter when no link is active.
  Future<bool> sendFrame({
    required OverlayResourceFrame frame,
    required Uint8List peerEndpointHint,
    required int peerNodeNum,
    int? linkId,
  });
}

/// In-memory recorder used by tests.
class RecordingOverlayResourceEgress extends OverlayResourceEgress {
  /// Frames the engine has handed to egress, in send order.
  final List<RecordingResourceFrameEvent> sent = [];

  /// When `false`, every call returns false (simulating a dropped
  /// transport). Default true.
  bool delivering = true;

  @override
  Future<bool> sendFrame({
    required OverlayResourceFrame frame,
    required Uint8List peerEndpointHint,
    required int peerNodeNum,
    int? linkId,
  }) async {
    sent.add(
      RecordingResourceFrameEvent(
        frame: frame,
        peerEndpointHint: Uint8List.fromList(peerEndpointHint),
        peerNodeNum: peerNodeNum,
        linkId: linkId,
      ),
    );
    return delivering;
  }
}

/// One captured outbound SPP frame.
class RecordingResourceFrameEvent {
  final OverlayResourceFrame frame;
  final Uint8List peerEndpointHint;
  final int peerNodeNum;
  final int? linkId;

  const RecordingResourceFrameEvent({
    required this.frame,
    required this.peerEndpointHint,
    required this.peerNodeNum,
    this.linkId,
  });
}
