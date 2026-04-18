// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// OverlayLinkEngine open-flow tests.
///
/// Covers local-initiator open, remote-responder open, accept-policy
/// decline, LINK_OPEN collision, and LINK_OPEN_OK / LINK_OPEN_NO
/// handling.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkFrame _mkLinkOpen({int linkId = 0xDEADBEEF, int seq = 0}) =>
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

OverlayLinkFrame _mkLinkOpenOk({required int linkId, int seq = 0}) =>
    OverlayLinkFrame(
      msgType: OverlayLinkMsgType.linkOpenOk,
      flags: OverlayLinkFlags.linkFrame,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: 0,
      linkId: linkId,
      seq: seq,
      ackHi: 0,
      payload: Uint8List(0),
    );

OverlayLinkFrame _mkLinkOpenNo({
  required int linkId,
  required OverlayLinkCloseReason reason,
}) => OverlayLinkFrame(
  msgType: OverlayLinkMsgType.linkOpenNo,
  flags: OverlayLinkFlags.linkFrame,
  requestId: 0,
  serviceId: 0,
  actionId: 0,
  payloadLen: 1,
  linkId: linkId,
  seq: 0,
  ackHi: 0,
  payload: Uint8List.fromList(<int>[reason.code]),
);

void main() {
  setUpAll(initFfi);

  group('openLocal (initiator)', () {
    test('creates an opening record and sends LINK_OPEN', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final clock = FakeClock();
      final ids = SequenceLinkIdGen(<int>[0x12345678]);
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: clock.now,
        linkIdGenerator: ids.next,
      );

      final hint = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      final record = await engine.openLocal(
        peerPersonaHint: hint,
        peerNodeNum: 42,
      );

      expect(record.linkId, 0x12345678);
      expect(record.state, OverlayLinkState.opening);
      expect(record.isInitiator, isTrue);
      expect(egress.sent, hasLength(1));
      expect(egress.sent.first.frame.msgType, OverlayLinkMsgType.linkOpen);
      expect(egress.sent.first.peerNodeNum, 42);
      // Persisted.
      final loaded = await store.getByLinkId(0x12345678);
      expect(loaded!.state, OverlayLinkState.opening);
      await engine.dispose();
      await store.close();
    });

    test('throws if an active record already exists for peer', () async {
      final store = await openInMemoryStore();
      final engine = OverlayLinkEngine(
        store: store,
        egress: RecordingOverlayLinkEgress(),
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[1, 2]).next,
      );
      final hint = Uint8List.fromList(List<int>.filled(8, 7));
      await engine.openLocal(peerPersonaHint: hint, peerNodeNum: 1);
      expect(
        () => engine.openLocal(peerPersonaHint: hint, peerNodeNum: 1),
        throwsStateError,
      );
      await engine.dispose();
      await store.close();
    });

    test('LINK_OPEN_OK transitions opening → active', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[0xAAAA0001]).next,
      );
      final events = <OverlayLinkEvent>[];
      final sub = engine.events.listen(events.add);

      final hint = Uint8List.fromList(List<int>.filled(8, 1));
      await engine.openLocal(peerPersonaHint: hint, peerNodeNum: 5);
      await engine.handleInbound(_mkLinkOpenOk(linkId: 0xAAAA0001), 5);

      final loaded = await store.getByLinkId(0xAAAA0001);
      expect(loaded!.state, OverlayLinkState.active);
      expect(
        events.map((e) => e.kind),
        containsAllInOrder([
          OverlayLinkEventKind.opened,
          OverlayLinkEventKind.activated,
        ]),
      );
      await sub.cancel();
      await engine.dispose();
      await store.close();
    });

    test(
      'LINK_OPEN_NO transitions opening → failed with payload reason',
      () async {
        final store = await openInMemoryStore();
        final engine = OverlayLinkEngine(
          store: store,
          egress: RecordingOverlayLinkEgress(),
          clock: FakeClock().now,
          linkIdGenerator: SequenceLinkIdGen(<int>[0xBBBB0002]).next,
        );
        final hint = Uint8List.fromList(List<int>.filled(8, 2));
        await engine.openLocal(peerPersonaHint: hint, peerNodeNum: 7);
        await engine.handleInbound(
          _mkLinkOpenNo(
            linkId: 0xBBBB0002,
            reason: OverlayLinkCloseReason.busy,
          ),
          7,
        );
        final loaded = await store.getByLinkId(0xBBBB0002);
        expect(loaded!.state, OverlayLinkState.failed);
        expect(loaded.closeReason, OverlayLinkCloseReason.busy);
        await engine.dispose();
        await store.close();
      },
    );
  });

  group('responder (inbound LINK_OPEN)', () {
    test(
      'accept policy default: creates active record + replies LINK_OPEN_OK',
      () async {
        final store = await openInMemoryStore();
        final egress = RecordingOverlayLinkEgress();
        final engine = OverlayLinkEngine(
          store: store,
          egress: egress,
          clock: FakeClock().now,
        );
        final events = <OverlayLinkEvent>[];
        final sub = engine.events.listen(events.add);

        await engine.handleInbound(_mkLinkOpen(linkId: 0xFACE), 99);

        final loaded = await store.getByLinkId(0xFACE);
        expect(loaded, isNotNull);
        expect(loaded!.state, OverlayLinkState.active);
        expect(loaded.isInitiator, isFalse);
        expect(loaded.rxExpectedSeq, 1); // frame.seq(0) + 1
        expect(egress.sent, hasLength(1));
        expect(egress.sent.first.frame.msgType, OverlayLinkMsgType.linkOpenOk);
        expect(
          events.map((e) => e.kind),
          containsAllInOrder([
            OverlayLinkEventKind.opened,
            OverlayLinkEventKind.activated,
          ]),
        );
        await sub.cancel();
        await engine.dispose();
        await store.close();
      },
    );

    test(
      'accept policy decline: replies LINK_OPEN_NO, no record persisted',
      () async {
        final store = await openInMemoryStore();
        final egress = RecordingOverlayLinkEgress();
        final engine = OverlayLinkEngine(
          store: store,
          egress: egress,
          acceptPolicy: (_) => OverlayLinkCloseReason.busy,
          clock: FakeClock().now,
        );
        final events = <OverlayLinkEvent>[];
        final sub = engine.events.listen(events.add);

        await engine.handleInbound(_mkLinkOpen(linkId: 0xCAFE), 12);

        // No row persisted for declined peers (avoid DB noise).
        expect(await store.getByLinkId(0xCAFE), isNull);
        expect(egress.sent.single.frame.msgType, OverlayLinkMsgType.linkOpenNo);
        expect(
          egress.sent.single.frame.payload[0],
          OverlayLinkCloseReason.busy.code,
        );
        expect(
          events.map((e) => e.kind),
          equals([OverlayLinkEventKind.rejected]),
        );
        await sub.cancel();
        await engine.dispose();
        await store.close();
      },
    );

    test('duplicate LINK_OPEN on existing link replies collision', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
      );
      await engine.handleInbound(_mkLinkOpen(linkId: 0x5555), 1);
      egress.sent.clear();

      await engine.handleInbound(_mkLinkOpen(linkId: 0x5555), 1);

      expect(egress.sent, hasLength(1));
      expect(egress.sent.first.frame.msgType, OverlayLinkMsgType.linkOpenNo);
      expect(
        egress.sent.first.frame.payload[0],
        OverlayLinkCloseReason.collision.code,
      );
      await engine.dispose();
      await store.close();
    });
  });

  group('disposed engine', () {
    test('serialised calls after dispose reject with StateError', () async {
      final store = await openInMemoryStore();
      final engine = OverlayLinkEngine(
        store: store,
        egress: RecordingOverlayLinkEgress(),
        clock: FakeClock().now,
      );
      await engine.dispose();
      expect(engine.tick(), throwsStateError);
      await store.close();
    });
  });
}
