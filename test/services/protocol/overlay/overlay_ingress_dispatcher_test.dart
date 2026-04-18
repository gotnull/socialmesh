// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Integration tests for [OverlayIngressDispatcher] — the thin glue
/// between `ProtocolService.attachOverlayInbound` and
/// [OverlayLinkEngine].
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_capability_coordinator.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_ingress_dispatcher.dart';
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

void main() {
  setUpAll(initFfi);

  test(
    'well-formed v0.2 frame routes to engine and records capability',
    () async {
      final store = await openInMemoryStore();
      final egress = RecordingOverlayLinkEgress();
      final engine = OverlayLinkEngine(
        store: store,
        egress: egress,
        clock: FakeClock().now,
      );
      final coordinator = OverlayCapabilityCoordinator(clock: FakeClock().now);
      final dispatcher = OverlayIngressDispatcher(
        engine: engine,
        coordinator: coordinator,
      );
      final events = <OverlayLinkEvent>[];
      final sub = engine.events.listen(events.add);

      final wire = OverlayLinkCodec.encode(_mkLinkOpen(0xF00D))!;
      await dispatcher.handleInboundMrrpBytes(42, wire);
      // Broadcast stream dispatch happens in the next microtask.
      await Future<void>.delayed(Duration.zero);

      expect(dispatcher.handledCount, 1);
      expect(dispatcher.decodeFailures, 0);
      expect(coordinator.isLinkCapable(42), isTrue);
      expect(
        events.map((e) => e.kind),
        contains(OverlayLinkEventKind.activated),
      );

      await sub.cancel();
      await engine.dispose();
      await store.close();
    },
  );

  test(
    'malformed bytes are counted as decode failures, do not poison state',
    () async {
      final store = await openInMemoryStore();
      final engine = OverlayLinkEngine(
        store: store,
        egress: RecordingOverlayLinkEgress(),
        clock: FakeClock().now,
      );
      final coordinator = OverlayCapabilityCoordinator(clock: FakeClock().now);
      final dispatcher = OverlayIngressDispatcher(
        engine: engine,
        coordinator: coordinator,
      );

      await dispatcher.handleInboundMrrpBytes(
        42,
        Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]), // short + bad magic
      );

      expect(dispatcher.handledCount, 0);
      expect(dispatcher.decodeFailures, 1);
      expect(coordinator.isLinkCapable(42), isFalse);
      expect(await store.count(), 0);

      await engine.dispose();
      await store.close();
    },
  );

  test('same frame delivered twice is handled exactly twice by the dispatcher '
      '(dedupe is engine-level, not dispatcher-level)', () async {
    final store = await openInMemoryStore();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: FakeClock().now,
    );
    final coordinator = OverlayCapabilityCoordinator(clock: FakeClock().now);
    final dispatcher = OverlayIngressDispatcher(
      engine: engine,
      coordinator: coordinator,
    );

    final wire = OverlayLinkCodec.encode(_mkLinkOpen(0xABCD))!;
    await dispatcher.handleInboundMrrpBytes(42, wire);
    await dispatcher.handleInboundMrrpBytes(42, wire);

    // Dispatcher is a thin proxy — both calls are handed off. The
    // engine's collision handler is what replies LINK_OPEN_NO the
    // second time (covered in P1 tests).
    expect(dispatcher.handledCount, 2);

    await engine.dispose();
    await store.close();
  });

  test('dispose stops further callbacks without throwing', () async {
    final store = await openInMemoryStore();
    final engine = OverlayLinkEngine(
      store: store,
      egress: RecordingOverlayLinkEgress(),
      clock: FakeClock().now,
    );
    final coordinator = OverlayCapabilityCoordinator(clock: FakeClock().now);
    final dispatcher = OverlayIngressDispatcher(
      engine: engine,
      coordinator: coordinator,
    );

    dispatcher.dispose();
    expect(dispatcher.isDisposed, isTrue);

    final wire = OverlayLinkCodec.encode(_mkLinkOpen(1))!;
    await dispatcher.handleInboundMrrpBytes(42, wire);
    expect(dispatcher.handledCount, 0);

    await engine.dispose();
    await store.close();
  });
}
