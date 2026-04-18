// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayResourceIngressDispatcher] — the thin glue
/// between `OverlayLinkEngine.events.dataDelivered` and
/// `OverlayResourceEngine.handleInbound`.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_ingress_dispatcher.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

/// Build a live link-engine pre-activated on one linkId, plus a
/// resource engine + an ingress dispatcher bound to both.
Future<
  ({
    OverlayLinkEngine link,
    OverlayResourceEngine resource,
    OverlayResourceIngressDispatcher ingress,
    RecordingOverlayResourceEgress resourceEgress,
    int linkId,
  })
>
_rig({int linkId = 0x0001}) async {
  final linkStore = await openInMemoryStore();
  final linkEgress = RecordingOverlayLinkEgress();
  final linkEngine = OverlayLinkEngine(
    store: linkStore,
    egress: linkEgress,
    clock: FakeClock().now,
  );
  await linkEngine.handleInbound(
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
    99,
  );

  final resourceStore = await openInMemoryResourceStore();
  final resourceEgress = RecordingOverlayResourceEgress();
  final resourceEngine = OverlayResourceEngine(
    store: resourceStore,
    egress: resourceEgress,
    clock: FakeClock().now,
  );

  final ingress = OverlayResourceIngressDispatcher(
    linkEngine: linkEngine,
    resourceEngine: resourceEngine,
  );
  ingress.start();
  return (
    link: linkEngine,
    resource: resourceEngine,
    ingress: ingress,
    resourceEgress: resourceEgress,
    linkId: linkId,
  );
}

/// Build + inject a LINK_DATA frame carrying [payload] into the
/// rig's link engine, so the ingress dispatcher hears the
/// `dataDelivered` event.
Future<void> _deliverLinkData({
  required OverlayLinkEngine linkEngine,
  required int linkId,
  required int seq,
  required Uint8List payload,
}) async {
  await linkEngine.handleInbound(
    OverlayLinkFrame(
      msgType: OverlayLinkMsgType.linkData,
      flags: OverlayLinkFlags.linkFrame,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: payload.length,
      linkId: linkId,
      seq: seq,
      ackHi: 0,
      payload: payload,
    ),
    99,
  );
}

void main() {
  setUpAll(initFfi);

  test('valid resource frame routes to resource engine', () async {
    final r = await _rig();
    final offer = OverlayResourceFrame(
      type: OverlayResourceMsgType.offer,
      resourceId: 0x11,
      chunkCount: 1,
      payload: Uint8List.fromList(<int>[
        // total(4) chunkSize(2) sha(32) mimeLen(0) nameLen(0)
        0, 0, 0, 0, 0, 0,
        ...List<int>.filled(32, 0),
        0,
        0,
      ]),
    );
    final wire = OverlayResourceCodec.encode(offer)!;

    // Inbound chunk arrives on the link — seq 1 matches rxExpectedSeq.
    await _deliverLinkData(
      linkEngine: r.link,
      linkId: r.linkId,
      seq: 1,
      payload: wire,
    );
    await Future<void>.delayed(Duration.zero);
    // Drain the resource engine's mutex so any in-flight write
    // completes before teardown closes the store.
    await r.resource.tick();

    expect(r.ingress.handledCount, 1);
    expect(r.ingress.nonResourcePayloads, 0);

    await r.ingress.stop();
    await r.link.dispose();
    await r.resource.dispose();
  });

  test(
    'non-resource payload is dropped silently; link state unaffected',
    () async {
      final r = await _rig();
      final junk = Uint8List.fromList(<int>[0xFF, 0x00, 0x99]);
      await _deliverLinkData(
        linkEngine: r.link,
        linkId: r.linkId,
        seq: 1,
        payload: junk,
      );
      await Future<void>.delayed(Duration.zero);

      expect(r.ingress.handledCount, 0);
      expect(r.ingress.nonResourcePayloads, 1);

      // Link should still accept the NEXT legitimate frame in sequence
      // (seq 2), confirming link state was not poisoned.
      final offer = OverlayResourceFrame(
        type: OverlayResourceMsgType.offer,
        resourceId: 0x22,
        chunkCount: 1,
        payload: Uint8List.fromList(<int>[
          0,
          0,
          0,
          0,
          0,
          0,
          ...List<int>.filled(32, 0),
          0,
          0,
        ]),
      );
      await _deliverLinkData(
        linkEngine: r.link,
        linkId: r.linkId,
        seq: 2,
        payload: OverlayResourceCodec.encode(offer)!,
      );
      await Future<void>.delayed(Duration.zero);
      await r.resource.tick();
      expect(r.ingress.handledCount, 1);

      await r.ingress.stop();
      await r.link.dispose();
      await r.resource.dispose();
    },
  );

  test('empty payload is counted but not dispatched', () async {
    final r = await _rig();
    await _deliverLinkData(
      linkEngine: r.link,
      linkId: r.linkId,
      seq: 1,
      payload: Uint8List(0),
    );
    await Future<void>.delayed(Duration.zero);
    expect(r.ingress.handledCount, 0);
    expect(r.ingress.emptyPayloadDrops, 1);
    await r.ingress.stop();
    await r.link.dispose();
    await r.resource.dispose();
  });

  test('stop() cancels the subscription and nulls the ref', () async {
    final r = await _rig();
    expect(r.ingress.isRunning, isTrue);
    await r.ingress.stop();
    expect(r.ingress.isRunning, isFalse);

    // After stop, further LINK_DATA deliveries must not increment
    // counters.
    final offer = OverlayResourceFrame(
      type: OverlayResourceMsgType.offer,
      resourceId: 0x33,
      chunkCount: 1,
      payload: Uint8List.fromList(<int>[
        0,
        0,
        0,
        0,
        0,
        0,
        ...List<int>.filled(32, 0),
        0,
        0,
      ]),
    );
    await _deliverLinkData(
      linkEngine: r.link,
      linkId: r.linkId,
      seq: 1,
      payload: OverlayResourceCodec.encode(offer)!,
    );
    await Future<void>.delayed(Duration.zero);
    expect(r.ingress.handledCount, 0);

    await r.link.dispose();
    await r.resource.dispose();
  });

  test('re-starting is idempotent', () async {
    final r = await _rig();
    r.ingress.start();
    r.ingress.start();
    expect(r.ingress.isRunning, isTrue);
    await r.ingress.stop();
    await r.link.dispose();
    await r.resource.dispose();
  });
}
