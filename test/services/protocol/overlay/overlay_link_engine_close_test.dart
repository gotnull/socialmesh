// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Close-flow tests for OverlayLinkEngine.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

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

OverlayLinkFrame _mkLinkClose(int linkId, OverlayLinkCloseReason reason) =>
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
      payload: Uint8List.fromList(<int>[reason.code]),
    );

void main() {
  setUpAll(initFfi);

  test('local close transitions to closed and emits LINK_CLOSE', () async {
    final store = await openInMemoryStore();
    final egress = RecordingOverlayLinkEgress();
    final engine = OverlayLinkEngine(
      store: store,
      egress: egress,
      clock: FakeClock().now,
    );
    await engine.handleInbound(_mkLinkOpen(0x10), 7);
    egress.sent.clear();
    final events = <OverlayLinkEvent>[];
    final sub = engine.events.listen(events.add);

    await engine.close(0x10, OverlayLinkCloseReason.normal);

    final loaded = await store.getByLinkId(0x10);
    expect(loaded!.state, OverlayLinkState.closed);
    expect(loaded.closeReason, OverlayLinkCloseReason.normal);
    expect(egress.sent, hasLength(1));
    expect(egress.sent.first.frame.msgType, OverlayLinkMsgType.linkClose);
    expect(
      egress.sent.first.frame.payload[0],
      OverlayLinkCloseReason.normal.code,
    );
    expect(events.last.kind, OverlayLinkEventKind.terminated);
    await sub.cancel();
    await engine.dispose();
    await store.close();
  });

  test(
    'inbound LINK_CLOSE transitions to closed with payload reason',
    () async {
      final store = await openInMemoryStore();
      final engine = OverlayLinkEngine(
        store: store,
        egress: RecordingOverlayLinkEgress(),
        clock: FakeClock().now,
      );
      await engine.handleInbound(_mkLinkOpen(0x20), 7);
      await engine.handleInbound(
        _mkLinkClose(0x20, OverlayLinkCloseReason.busy),
        7,
      );
      final loaded = await store.getByLinkId(0x20);
      expect(loaded!.state, OverlayLinkState.closed);
      expect(loaded.closeReason, OverlayLinkCloseReason.busy);
      await engine.dispose();
      await store.close();
    },
  );

  test('close on terminal link is a no-op (idempotent)', () async {
    final store = await openInMemoryStore();
    final egress = RecordingOverlayLinkEgress();
    final engine = OverlayLinkEngine(
      store: store,
      egress: egress,
      clock: FakeClock().now,
    );
    await engine.handleInbound(_mkLinkOpen(0x30), 7);
    await engine.close(0x30, OverlayLinkCloseReason.normal);
    egress.sent.clear();
    await engine.close(0x30, OverlayLinkCloseReason.busy);
    expect(egress.sent, isEmpty);
    final loaded = await store.getByLinkId(0x30);
    expect(loaded!.closeReason, OverlayLinkCloseReason.normal);
    await engine.dispose();
    await store.close();
  });

  test('LINK_DATA on closed link is dropped (no delivery)', () async {
    final store = await openInMemoryStore();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: FakeClock().now,
    );
    await engine.handleInbound(_mkLinkOpen(0x40), 7);
    await engine.close(0x40, OverlayLinkCloseReason.normal);
    final events = <OverlayLinkEvent>[];
    final sub = engine.events.listen(events.add);
    await engine.handleInbound(
      OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkData,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 1,
        linkId: 0x40,
        seq: 1,
        ackHi: 0,
        payload: Uint8List.fromList(<int>[0xFF]),
      ),
      7,
    );
    expect(
      events.where((e) => e.kind == OverlayLinkEventKind.dataDelivered),
      isEmpty,
    );
    await sub.cancel();
    await engine.dispose();
    await store.close();
  });
}
