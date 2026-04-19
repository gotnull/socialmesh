// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Sequencing + dedupe tests for OverlayLinkEngine.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkFrame _mkData({
  required int linkId,
  required int seq,
  int ackHi = 0,
  List<int> payload = const <int>[0x41],
  bool ackRequired = false,
}) {
  final bytes = Uint8List.fromList(payload);
  return OverlayLinkFrame(
    msgType: OverlayLinkMsgType.linkData,
    flags:
        OverlayLinkFlags.linkFrame |
        (ackRequired ? OverlayLinkFlags.ackRequired : 0),
    requestId: 0,
    serviceId: 0,
    actionId: 0,
    payloadLen: bytes.length,
    linkId: linkId,
    seq: seq,
    ackHi: ackHi,
    payload: bytes,
  );
}

OverlayLinkFrame _mkLinkOpen(int linkId) => OverlayLinkFrame(
  msgType: OverlayLinkMsgType.linkOpen,
  flags: OverlayLinkFlags.linkFrame,
  requestId: 0,
  serviceId: 0,
  actionId: 0,
  payloadLen: 0,
  linkId: linkId,
  seq: 0,
  ackHi: 0,
  payload: Uint8List(0),
);

OverlayLinkFrame _mkLinkAck(int linkId, int ackHi) => OverlayLinkFrame(
  msgType: OverlayLinkMsgType.linkAck,
  flags: OverlayLinkFlags.linkFrame,
  requestId: 0,
  serviceId: 0,
  actionId: 0,
  payloadLen: 0,
  linkId: linkId,
  seq: 0,
  ackHi: ackHi,
  payload: Uint8List(0),
);

Future<(OverlayLinkStore, OverlayLinkEngine, RecordingOverlayLinkEgress)>
_openActiveInboundLink(int linkId) async {
  final store = await openInMemoryStore();
  final egress = RecordingOverlayLinkEgress();
  final engine = OverlayLinkEngine(
    store: store,
    egress: egress,
    clock: FakeClock().now,
  );
  // Remote peer opens; engine snaps to active and rxExpectedSeq=1.
  await engine.handleInbound(_mkLinkOpen(linkId), 7);
  egress.sent.clear();
  return (store, engine, egress);
}

void main() {
  setUpAll(initFfi);

  group('LINK_DATA in-order delivery', () {
    test('accepts frames in monotonic order and emits dataDelivered', () async {
      final (store, engine, _) = await _openActiveInboundLink(0x0100);
      final events = <OverlayLinkEvent>[];
      final sub = engine.events.listen(events.add);

      // First inbound data seq must equal rxExpectedSeq = 1.
      await engine.handleInbound(_mkData(linkId: 0x0100, seq: 1), 7);
      await engine.handleInbound(_mkData(linkId: 0x0100, seq: 2), 7);

      final delivered = events
          .where((e) => e.kind == OverlayLinkEventKind.dataDelivered)
          .toList();
      expect(delivered, hasLength(2));
      expect(delivered.map((e) => e.payload![0]), equals([0x41, 0x41]));
      expect((await store.getByLinkId(0x0100))!.rxExpectedSeq, 3);
      await sub.cancel();
      await engine.dispose();
      await store.close();
    });

    test(
      'drops duplicates with detail=duplicate and does not advance',
      () async {
        final (store, engine, _) = await _openActiveInboundLink(0x0200);
        final events = <OverlayLinkEvent>[];
        final sub = engine.events.listen(events.add);

        await engine.handleInbound(_mkData(linkId: 0x0200, seq: 1), 7);
        // Replay seq=1 → duplicate drop.
        await engine.handleInbound(_mkData(linkId: 0x0200, seq: 1), 7);

        final drops = events
            .where((e) => e.kind == OverlayLinkEventKind.dataDropped)
            .toList();
        expect(drops, hasLength(1));
        expect(drops.first.detail, 'duplicate');
        // rxExpectedSeq advanced once (to 2).
        expect((await store.getByLinkId(0x0200))!.rxExpectedSeq, 2);
        await sub.cancel();
        await engine.dispose();
        await store.close();
      },
    );

    test('drops future seq with detail=future_seq', () async {
      final (store, engine, _) = await _openActiveInboundLink(0x0300);
      final events = <OverlayLinkEvent>[];
      final sub = engine.events.listen(events.add);

      // rxExpectedSeq = 1, but seq=5 arrives first.
      await engine.handleInbound(_mkData(linkId: 0x0300, seq: 5), 7);

      final drops = events
          .where((e) => e.kind == OverlayLinkEventKind.dataDropped)
          .toList();
      expect(drops, hasLength(1));
      expect(drops.first.detail, 'future_seq');
      expect((await store.getByLinkId(0x0300))!.rxExpectedSeq, 1);
      await sub.cancel();
      await engine.dispose();
      await store.close();
    });

    test('LINK_DATA with ackRequired emits a LINK_ACK', () async {
      final (store, engine, egress) = await _openActiveInboundLink(0x0400);
      await engine.handleInbound(
        _mkData(linkId: 0x0400, seq: 1, ackRequired: true),
        7,
      );
      expect(egress.sent, hasLength(1));
      expect(egress.sent.first.frame.msgType, OverlayLinkMsgType.linkAck);
      await engine.dispose();
      await store.close();
    });
  });

  group('LINK_ACK ack_hi advance', () {
    test('advances txAckHi monotonically within forward half', () async {
      final (store, engine, _) = await _openActiveInboundLink(0x0500);
      await engine.handleInbound(_mkLinkAck(0x0500, 0x0010), 7);
      expect((await store.getByLinkId(0x0500))!.txAckHi, 0x0010);
      await engine.handleInbound(_mkLinkAck(0x0500, 0x0020), 7);
      expect((await store.getByLinkId(0x0500))!.txAckHi, 0x0020);
      await engine.dispose();
      await store.close();
    });

    test('ignores ack_hi that sits in the backward half (stale)', () async {
      final (store, engine, _) = await _openActiveInboundLink(0x0600);
      await engine.handleInbound(_mkLinkAck(0x0600, 0x0020), 7);
      // Backwards ack: diff = (0x0010 - 0x0020) & 0xFFFF = 0xFFF0 → ignored.
      await engine.handleInbound(_mkLinkAck(0x0600, 0x0010), 7);
      expect((await store.getByLinkId(0x0600))!.txAckHi, 0x0020);
      await engine.dispose();
      await store.close();
    });
  });

  group('sendData', () {
    test('assigns seq monotonically and persists txNextSeq', () async {
      final (store, engine, egress) = await _openActiveInboundLink(0x0700);
      await engine.sendData(0x0700, Uint8List.fromList(<int>[1, 2]));
      await engine.sendData(0x0700, Uint8List.fromList(<int>[3, 4]));
      final seqs = egress.sent.map((e) => e.frame.seq).toList(growable: false);
      expect(seqs, equals([0, 1]));
      expect((await store.getByLinkId(0x0700))!.txNextSeq, 2);
      await engine.dispose();
      await store.close();
    });

    test('refuses to send when link is not active', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[0x0800]).next,
      );
      await engine.openLocal(peerPersonaHint: Uint8List(8), peerNodeNum: 1);
      // Still in `opening`, not active.
      final wire = await engine.sendData(0x0800, Uint8List.fromList(<int>[9]));
      expect(wire, isNull);
      await engine.dispose();
      await store.close();
    });
  });
}
