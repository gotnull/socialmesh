// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Cross-peer linkId collision invariants.
///
/// Pin two distinct collision modes inside [OverlayLinkEngine._handleLinkOpen]:
///
///   1. **same peer + same linkId** — peer retransmit / duplicate
///      LINK_OPEN. Pre-existing behaviour (reply collision) preserved.
///
///   2. **different peer + same linkId** — cross-peer collision in a
///      multi-device mesh. The engine MUST:
///        - reject the inbound LINK_OPEN with `linkOpenNo collision`,
///        - never mutate the existing record (no peerNodeNum change,
///          no state change, no seq leak),
///        - emit the `overlay_link_collision_cross_peer` log line.
///
/// The on-device manifestation of the bug this protects against:
/// `secure_decrypt_dropped reason=no_dm_session peer=<wrong_peer>`
/// after a successful AEAD decrypt — the link store had been
/// silently re-attributed to the new peer's node id, poisoning every
/// downstream `linkId → peerNodeNum → SipDmSession` lookup.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkFrame _mkLinkOpen({required int linkId, int seq = 0}) =>
    OverlayLinkFrame(
      msgType: OverlayLinkMsgType.linkOpen,
      flags: OverlayLinkFlags.linkFrame | OverlayLinkFlags.ackRequired,
      requestId: 0x11223344,
      serviceId: 0,
      actionId: 0,
      payloadLen: 0,
      linkId: linkId,
      seq: seq,
      ackHi: 0,
      payload: Uint8List(0),
    );

void main() {
  setUpAll(initFfi);

  group('cross-peer linkId collision', () {
    test('different peer reusing an existing non-terminal linkId is rejected '
        'and the existing record is left untouched', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
      );

      // Peer A opens the link first. The engine accepts and stores
      // the record with peerNodeNum = A.
      const peerA = 0xB15E74DB;
      const peerB = 0x9C3A29A9;
      const sharedLinkId = 0x3468E0;

      await engine.handleInbound(_mkLinkOpen(linkId: sharedLinkId), peerA);
      egress.sent.clear();

      // Capture the canonical state for peer A so we can prove the
      // engine doesn't mutate it when peer B's collision arrives.
      final beforeBytes = await store.getByLinkId(sharedLinkId);
      expect(beforeBytes, isNotNull);
      expect(
        beforeBytes!.peerNodeNum,
        equals(peerA),
        reason: 'precondition: link is owned by peer A',
      );
      expect(beforeBytes.state, equals(OverlayLinkState.active));

      // Peer B fires LINK_OPEN with the same linkId. The current
      // (poisoned) bug would have either replaced the record's
      // peerNodeNum or accepted the new link silently. The fix:
      // reject deterministically with no mutation.
      await engine.handleInbound(_mkLinkOpen(linkId: sharedLinkId), peerB);

      final after = await store.getByLinkId(sharedLinkId);
      expect(after, isNotNull);
      expect(
        after!.peerNodeNum,
        equals(peerA),
        reason:
            'cross-peer collision must NOT re-attribute the link record '
            'to peer B — that is the exact bug that poisoned the store',
      );
      expect(
        after.state,
        equals(beforeBytes.state),
        reason: 'state must not transition because of a rejected inbound',
      );
      expect(
        after.openedAtMs,
        equals(beforeBytes.openedAtMs),
        reason: 'openedAtMs must not roll forward',
      );
      expect(
        after.txNextSeq,
        equals(beforeBytes.txNextSeq),
        reason: 'send-seq must not be reset',
      );

      // Exactly one frame fired in response: a linkOpenNo collision
      // routed to peer B (the inbound sender), NOT to peer A.
      expect(egress.sent, hasLength(1));
      final reply = egress.sent.single;
      expect(reply.peerNodeNum, equals(peerB));
      expect(reply.frame.msgType, equals(OverlayLinkMsgType.linkOpenNo));
      expect(
        reply.frame.payload[0],
        equals(OverlayLinkCloseReason.collision.code),
      );
      expect(
        reply.frame.linkId,
        equals(sharedLinkId),
        reason: 'rejection carries the contested linkId',
      );

      await engine.dispose();
      await store.close();
    });

    test('rejection frame is built fresh — does not leak the existing '
        'record\'s seq/peerPersonaHint to the wrong peer', () async {
      // Defence-in-depth: even though the rejection routes via
      // _sendFrame(..., senderNodeNum), the FRAME contents should
      // be a clean rejection (linkId + reason byte only), not a
      // copy of the existing record's bookkeeping. Otherwise a
      // colliding peer could observe seq/persona hint of the
      // legitimate peer.
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
      );

      const peerA = 0x1111;
      const peerB = 0x2222;
      const sharedLinkId = 0xABCDEF;

      await engine.handleInbound(_mkLinkOpen(linkId: sharedLinkId), peerA);
      egress.sent.clear();

      await engine.handleInbound(_mkLinkOpen(linkId: sharedLinkId), peerB);

      expect(egress.sent, hasLength(1));
      final reply = egress.sent.single.frame;
      // The rejection's seq/ackHi must be 0 (per _buildRejectionFrame),
      // not the existing record's seq state.
      expect(
        reply.seq,
        equals(0),
        reason: 'rejection seq must be 0, not existing.txNextSeq',
      );
      expect(
        reply.ackHi,
        equals(0),
        reason: 'rejection ackHi must be 0, not existing.txAckHi',
      );
      expect(reply.payloadLen, equals(1));
      expect(
        reply.payload,
        equals(
          Uint8List.fromList(<int>[OverlayLinkCloseReason.collision.code]),
        ),
      );

      await engine.dispose();
      await store.close();
    });

    test('same peer reusing the same linkId still hits the existing collision '
        'path (peer-retransmit / duplicate semantics preserved)', () async {
      // Regression: must not treat a same-peer retransmit as a
      // cross-peer collision, otherwise the log line + frame source
      // would be wrong for the common retransmit case.
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
      );

      const peer = 0x55AA;
      const linkId = 0x12345;

      await engine.handleInbound(_mkLinkOpen(linkId: linkId), peer);
      egress.sent.clear();

      // SAME peer, SAME linkId — duplicate / retransmit.
      await engine.handleInbound(_mkLinkOpen(linkId: linkId), peer);

      expect(egress.sent, hasLength(1));
      final reply = egress.sent.single;
      expect(reply.peerNodeNum, equals(peer));
      expect(reply.frame.msgType, equals(OverlayLinkMsgType.linkOpenNo));
      expect(
        reply.frame.payload[0],
        equals(OverlayLinkCloseReason.collision.code),
      );

      // The existing record stays under the original peer.
      final after = await store.getByLinkId(linkId);
      expect(after!.peerNodeNum, equals(peer));

      await engine.dispose();
      await store.close();
    });

    test('cross-peer LINK_OPEN against a TERMINAL existing record is allowed '
        'to proceed (the dead record is replaceable)', () async {
      // Negative test for the cross-peer rule: if the existing
      // record is in a terminal state (failed/closed), it's already
      // dead — there's nothing to protect by rejecting. Letting the
      // new peer open through is correct and matches pre-existing
      // semantics for terminal-record replacement.
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
      );

      const peerA = 0xAAAA;
      const peerB = 0xBBBB;
      const linkId = 0x77;

      await engine.handleInbound(_mkLinkOpen(linkId: linkId), peerA);
      // Terminate peer A's record by sending LINK_CLOSE.
      await engine.handleInbound(
        OverlayLinkFrame(
          msgType: OverlayLinkMsgType.linkClose,
          flags: OverlayLinkFlags.linkFrame,
          requestId: 0,
          serviceId: 0,
          actionId: 0,
          payloadLen: 1,
          linkId: linkId,
          seq: 0,
          ackHi: 0,
          payload: Uint8List.fromList(<int>[
            OverlayLinkCloseReason.normal.code,
          ]),
        ),
        peerA,
      );
      egress.sent.clear();

      final terminal = await store.getByLinkId(linkId);
      expect(terminal!.isTerminal, isTrue);

      // Peer B opens with the same linkId. Existing record is
      // terminal → engine should accept (replacing the dead record).
      await engine.handleInbound(_mkLinkOpen(linkId: linkId), peerB);

      final after = await store.getByLinkId(linkId);
      expect(after, isNotNull);
      expect(
        after!.peerNodeNum,
        equals(peerB),
        reason: 'terminal records are replaceable — peer B owns it now',
      );
      expect(after.state, equals(OverlayLinkState.active));
      // No collision rejection emitted.
      expect(
        egress.sent.any(
          (e) =>
              e.frame.msgType == OverlayLinkMsgType.linkOpenNo &&
              e.frame.payload[0] == OverlayLinkCloseReason.collision.code,
        ),
        isFalse,
      );

      await engine.dispose();
      await store.close();
    });
  });
}
