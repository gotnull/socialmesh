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

    test('second openLocal for same peer returns existing canonical record '
        'without sending a duplicate LINK_OPEN', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[1, 2]).next,
      );
      final hint = Uint8List.fromList(List<int>.filled(8, 7));
      final first = await engine.openLocal(
        peerPersonaHint: hint,
        peerNodeNum: 1,
      );
      final second = await engine.openLocal(
        peerPersonaHint: hint,
        peerNodeNum: 1,
      );
      expect(second.linkId, equals(first.linkId));
      // Only the first call should have emitted a LINK_OPEN.
      expect(egress.sent, hasLength(1));
      expect(
        egress.sent.first.frame.msgType,
        equals(OverlayLinkMsgType.linkOpen),
      );
      await engine.dispose();
      await store.close();
    });

    test(
      'second openLocal with DIFFERENT hint but same peerNodeNum still '
      'returns existing canonical record (bridges synthetic↔real hint)',
      () async {
        final store = await openInMemoryStore();
        final egress = RecordingOverlayLinkEgress();
        final engine = OverlayLinkEngine(
          store: store,
          egress: egress,
          clock: FakeClock().now,
          linkIdGenerator: SequenceLinkIdGen(<int>[1, 2]).next,
        );
        final syntheticHint = Uint8List.fromList(List<int>.filled(8, 7));
        final realHint = Uint8List.fromList(List<int>.filled(8, 0xAA));
        final first = await engine.openLocal(
          peerPersonaHint: syntheticHint,
          peerNodeNum: 1,
        );
        final second = await engine.openLocal(
          peerPersonaHint: realHint,
          peerNodeNum: 1,
        );
        expect(second.linkId, equals(first.linkId));
        expect(egress.sent, hasLength(1));
        await engine.dispose();
        await store.close();
      },
    );

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

  // -------------------------------------------------------------------
  // Canonical-link tie-break (sim-open race)
  // -------------------------------------------------------------------

  group('sim-open tie-break', () {
    test('incoming LINK_OPEN with lower linkId supersedes our initiator '
        'record and installs the responder', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[0x0200]).next,
      );
      final events = <OverlayLinkEvent>[];
      final sub = engine.events.listen(events.add);

      // We open with linkId=0x0200.
      final ourRecord = await engine.openLocal(
        peerPersonaHint: Uint8List.fromList(List<int>.filled(8, 9)),
        peerNodeNum: 42,
      );
      expect(ourRecord.linkId, 0x0200);

      // Peer races with a lower linkId=0x0100 → peer wins.
      await engine.handleInbound(_mkLinkOpen(linkId: 0x0100), 42);

      final superseded = await store.getByLinkId(0x0200);
      expect(superseded!.state, OverlayLinkState.failed);
      expect(superseded.closeReason, OverlayLinkCloseReason.collision);

      final winner = await store.getByLinkId(0x0100);
      expect(winner, isNotNull);
      expect(winner!.state, OverlayLinkState.active);
      expect(winner.isInitiator, isFalse);

      expect(
        events.map((e) => e.kind),
        containsAllInOrder([
          OverlayLinkEventKind.opened, // our openLocal
          OverlayLinkEventKind.terminated, // our 0x0200 superseded
          OverlayLinkEventKind.opened, // inbound 0x0100 responder
          OverlayLinkEventKind.activated, // inbound 0x0100 active
        ]),
      );

      await sub.cancel();
      await engine.dispose();
      await store.close();
    });

    test('incoming LINK_OPEN with higher linkId is silently dropped; our '
        'initiator record is left untouched', () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[0x0100]).next,
      );

      // We open with linkId=0x0100.
      await engine.openLocal(
        peerPersonaHint: Uint8List.fromList(List<int>.filled(8, 9)),
        peerNodeNum: 42,
      );
      egress.sent.clear();

      // Peer races with higher linkId=0x0200 → we win, drop inbound.
      await engine.handleInbound(_mkLinkOpen(linkId: 0x0200), 42);

      final winner = await store.getByLinkId(0x0100);
      expect(winner!.state, OverlayLinkState.opening);
      expect(winner.isInitiator, isTrue);

      final loser = await store.getByLinkId(0x0200);
      expect(loser, isNull); // no responder record created

      // No LINK_OPEN_OK / LINK_OPEN_NO emitted for the loser.
      expect(egress.sent, isEmpty);

      await engine.dispose();
      await store.close();
    });

    test('sim-open is symmetric: two engines with different linkIds both '
        'converge on the lower-linkId record', () async {
      final storeA = await openInMemoryStore();
      final storeB = await openInMemoryStore();
      final egressA = RecordingOverlayLinkEgress();
      final egressB = RecordingOverlayLinkEgress();
      final engineA = OverlayLinkEngine(
        store: storeA,
        egress: egressA,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[0x1111]).next,
      );
      final engineB = OverlayLinkEngine(
        store: storeB,
        egress: egressB,
        clock: FakeClock().now,
        linkIdGenerator: SequenceLinkIdGen(<int>[0x2222]).next,
      );

      // A opens targeting B (nodeNum=7). B opens targeting A (nodeNum=3).
      await engineA.openLocal(
        peerPersonaHint: Uint8List.fromList(List<int>.filled(8, 0xB)),
        peerNodeNum: 7,
      );
      await engineB.openLocal(
        peerPersonaHint: Uint8List.fromList(List<int>.filled(8, 0xA)),
        peerNodeNum: 3,
      );

      // Cross-deliver the LINK_OPEN frames.
      await engineA.handleInbound(egressB.sent.single.frame, 7);
      await engineB.handleInbound(egressA.sent.single.frame, 3);

      // A's 0x1111 wins on both sides.
      final aSelf = await storeA.getByLinkId(0x1111);
      expect(aSelf!.state, OverlayLinkState.opening);
      expect(aSelf.isInitiator, isTrue);
      final aDropped = await storeA.getByLinkId(0x2222);
      expect(aDropped, isNull);

      final bWinner = await storeB.getByLinkId(0x1111);
      expect(bWinner!.state, OverlayLinkState.active);
      expect(bWinner.isInitiator, isFalse);
      final bSuperseded = await storeB.getByLinkId(0x2222);
      expect(bSuperseded!.state, OverlayLinkState.failed);
      expect(bSuperseded.closeReason, OverlayLinkCloseReason.collision);

      await engineA.dispose();
      await engineB.dispose();
      await storeA.close();
      await storeB.close();
    });
  });

  group('canonical reuse from restored state', () {
    test('openLocal against a stale canonical record promotes it to active '
        'and emits an activation event', () async {
      final store = await openInMemoryStore();
      final engine = OverlayLinkEngine(
        store: store,
        egress: RecordingOverlayLinkEgress(),
        clock: FakeClock().now,
      );
      final events = <OverlayLinkEvent>[];
      final sub = engine.events.listen(events.add);

      // Pre-seed a stale canonical record for peerNodeNum=42 — the
      // pattern `restore()` produces for non-terminal rows after an
      // app restart.
      final stale = OverlayLinkRecord(
        linkId: 0xDEADBEEF,
        peerPersonaHint: Uint8List.fromList(List<int>.filled(8, 0xAA)),
        peerNodeNum: 42,
        state: OverlayLinkState.stale,
        isInitiator: true,
        capabilities: OverlayLinkCapabilities.none,
        openedAtMs: 0,
        lastActivityMs: 0,
        expiresAtMs: 1 << 40,
        txNextSeq: 0,
        txAckHi: 0,
        rxExpectedSeq: 0,
        retryCount: 0,
      );
      await store.upsert(stale);

      final reused = await engine.openLocal(
        peerPersonaHint: Uint8List.fromList(List<int>.filled(8, 0xBB)),
        peerNodeNum: 42,
      );
      expect(reused.linkId, 0xDEADBEEF);
      expect(reused.state, OverlayLinkState.active);

      final persisted = await store.getByLinkId(0xDEADBEEF);
      expect(persisted!.state, OverlayLinkState.active);

      // Activation event fires so the secure-session manager hook
      // can attach on canonical reuse, not only on fresh opens.
      expect(
        events.map((e) => e.kind),
        contains(OverlayLinkEventKind.activated),
      );

      await sub.cancel();
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
