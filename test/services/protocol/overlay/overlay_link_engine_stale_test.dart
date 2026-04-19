// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Stale-transition + expiry tick tests.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_constants.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayLinkFrame _mkPing(int linkId) => OverlayLinkFrame(
  msgType: OverlayLinkMsgType.linkPing,
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

Future<
  (OverlayLinkStore, OverlayLinkEngine, FakeClock, RecordingOverlayLinkEgress)
>
_activeLink(int linkId) async {
  final store = await openInMemoryStore();
  final egress = RecordingOverlayLinkEgress();
  final clock = FakeClock();
  final engine = OverlayLinkEngine(
    store: store,
    egress: egress,
    clock: clock.now,
  );
  // Responder path: accept LINK_OPEN, snap to active.
  await engine.handleInbound(
    OverlayLinkFrame(
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
    ),
    12,
  );
  egress.sent.clear();
  return (store, engine, clock, egress);
}

void main() {
  setUpAll(initFfi);

  test('tick transitions active → stale after staleThresholdSec', () async {
    final (store, engine, clock, _) = await _activeLink(0x01);
    final events = <OverlayLinkEvent>[];
    final sub = engine.events.listen(events.add);

    clock.advanceMs(OverlayLinkConstants.staleThresholdSec * 1000 + 1);
    await engine.tick();

    expect((await store.getByLinkId(0x01))!.state, OverlayLinkState.stale);
    expect(events.map((e) => e.kind), contains(OverlayLinkEventKind.staled));
    await sub.cancel();
    await engine.dispose();
    await store.close();
  });

  test('tick stays active while within stale window', () async {
    final (store, engine, clock, _) = await _activeLink(0x02);
    clock.advanceMs(OverlayLinkConstants.staleThresholdSec * 1000 - 1);
    await engine.tick();
    expect((await store.getByLinkId(0x02))!.state, OverlayLinkState.active);
    await engine.dispose();
    await store.close();
  });

  test('LINK_PING on stale link restores to active and replies PONG', () async {
    final (store, engine, clock, egress) = await _activeLink(0x03);
    clock.advanceMs(OverlayLinkConstants.staleThresholdSec * 1000 + 10);
    await engine.tick();
    expect((await store.getByLinkId(0x03))!.state, OverlayLinkState.stale);

    await engine.handleInbound(_mkPing(0x03), 12);
    expect((await store.getByLinkId(0x03))!.state, OverlayLinkState.active);
    expect(
      egress.sent.map((e) => e.frame.msgType),
      contains(OverlayLinkMsgType.linkPong),
    );
    await engine.dispose();
    await store.close();
  });

  test('stale for 2× threshold with no traffic → failed(timeout)', () async {
    final (store, engine, clock, _) = await _activeLink(0x04);
    clock.advanceMs(OverlayLinkConstants.staleThresholdSec * 1000 + 1);
    await engine.tick(); // active → stale
    clock.advanceMs(OverlayLinkConstants.staleThresholdSec * 1000 + 1);
    await engine.tick(); // stale → failed
    final loaded = await store.getByLinkId(0x04);
    expect(loaded!.state, OverlayLinkState.failed);
    expect(loaded.closeReason, OverlayLinkCloseReason.timeout);
    await engine.dispose();
    await store.close();
  });

  test(
    'expiresAtMs crossing transitions to failed(timeout) regardless of state',
    () async {
      final (store, engine, clock, _) = await _activeLink(0x05);
      clock.advanceMs(OverlayLinkConstants.linkMaxLifetimeSec * 1000 + 1);
      await engine.tick();
      final loaded = await store.getByLinkId(0x05);
      expect(loaded!.state, OverlayLinkState.failed);
      expect(loaded.closeReason, OverlayLinkCloseReason.timeout);
      await engine.dispose();
      await store.close();
    },
  );

  test('tick GCs closed rows past closedRetentionSec', () async {
    final store = await openInMemoryStore();
    final clock = FakeClock();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: clock.now,
    );
    // Seed a long-past closed row.
    await store.upsert(
      OverlayLinkRecord(
        linkId: 0x99,
        peerPersonaHint: Uint8List(8),
        peerNodeNum: 0,
        state: OverlayLinkState.closed,
        isInitiator: true,
        capabilities: OverlayLinkCapabilities.none,
        openedAtMs: clock.now() - 48 * 60 * 60 * 1000,
        lastActivityMs: clock.now() - 48 * 60 * 60 * 1000,
        expiresAtMs: clock.now() + 1000,
        txNextSeq: 0,
        txAckHi: 0,
        rxExpectedSeq: 0,
        retryCount: 0,
        closeReason: OverlayLinkCloseReason.normal,
        closedAtMs: clock.now() - 48 * 60 * 60 * 1000,
      ),
    );
    await engine.tick();
    expect(await store.getByLinkId(0x99), isNull);
    await engine.dispose();
    await store.close();
  });
}
