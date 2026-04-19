// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Abstract egress contract for [OverlayLinkEngine].
///
/// The engine never imports `ProtocolService` or the Meshtastic
/// transport directly. Outbound link frames are handed to an
/// implementation of [OverlayLinkEgress], which is responsible for
/// wrapping them in SIP + MRRP + Meshtastic envelopes and dispatching
/// via the SIP rate limiter. P1 uses a test-only implementation; P2
/// lands the production adapter.
library;

import 'overlay_link_codec.dart';

/// Outbound delivery surface used by [OverlayLinkEngine].
abstract class OverlayLinkEgress {
  /// Send [frame] to the peer addressed by [peerNodeNum].
  ///
  /// Implementations SHOULD:
  /// - Encode via [OverlayLinkCodec.encode] and wrap in SIP/MRRP.
  /// - Account the bytes against the SIP rate limiter.
  /// - Tolerate transient failures (log + return `false`); the engine
  ///   will retry via its own backoff.
  ///
  /// Returns `true` if the frame was handed to the transport, `false`
  /// if it was dropped (rate limited, transport offline, encoder
  /// refused).
  Future<bool> send(OverlayLinkFrame frame, int peerNodeNum);
}

/// An in-memory egress used by tests. Captures every outbound frame in
/// [sent] for assertion.
class RecordingOverlayLinkEgress extends OverlayLinkEgress {
  /// Frames the engine has handed to egress, in send order.
  final List<RecordingLinkFrameEvent> sent = <RecordingLinkFrameEvent>[];

  /// When set, every call returns false (simulating a dropped
  /// transport). Defaults to true.
  bool delivering = true;

  @override
  Future<bool> send(OverlayLinkFrame frame, int peerNodeNum) async {
    sent.add(RecordingLinkFrameEvent(frame: frame, peerNodeNum: peerNodeNum));
    return delivering;
  }
}

/// Record of a single outbound frame captured by
/// [RecordingOverlayLinkEgress].
class RecordingLinkFrameEvent {
  /// The frame that was sent.
  final OverlayLinkFrame frame;

  /// The destination node num.
  final int peerNodeNum;

  const RecordingLinkFrameEvent({
    required this.frame,
    required this.peerNodeNum,
  });
}
