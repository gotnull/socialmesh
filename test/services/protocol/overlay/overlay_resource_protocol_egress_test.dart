// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayResourceProtocolEgress] — the production
/// adapter that wraps resource frames in LINK_DATA via
/// [OverlayLinkEngine.sendData].
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_feature_flag.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_protocol_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

OverlayResourceFrame _mkChunkFrame({int resourceId = 1}) =>
    OverlayResourceFrame(
      type: OverlayResourceMsgType.chunk,
      resourceId: resourceId,
      chunkIndex: 0,
      chunkCount: 1,
      payload: Uint8List.fromList(<int>[1, 2, 3]),
    );

Future<(OverlayLinkEngine, RecordingOverlayLinkEgress, int)> _activeLink({
  int linkId = 0x123456,
}) async {
  final store = await openInMemoryStore();
  final egress = RecordingOverlayLinkEgress();
  final engine = OverlayLinkEngine(
    store: store,
    egress: egress,
    clock: FakeClock().now,
  );
  // Drive link to active via a peer-initiated LINK_OPEN.
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
    55,
  );
  egress.sent.clear();
  return (engine, egress, linkId);
}

void main() {
  setUpAll(initFfi);

  test('short-circuits when resourceActive=false', () async {
    final (engine, linkEgress, linkId) = await _activeLink();
    final adapter = OverlayResourceProtocolEgress(
      linkEngine: engine,
      flags: () => const OverlayFeatureFlags(linkEnabled: false),
    );
    final ok = await adapter.sendFrame(
      frame: _mkChunkFrame(),
      peerEndpointHint: Uint8List(8),
      peerNodeNum: 1,
      linkId: linkId,
    );
    expect(ok, isFalse);
    expect(linkEgress.sent, isEmpty);
    await engine.dispose();
  });

  test('refuses when linkId is null (no active link)', () async {
    final (engine, linkEgress, _) = await _activeLink();
    final adapter = OverlayResourceProtocolEgress(
      linkEngine: engine,
      flags: () =>
          const OverlayFeatureFlags(linkEnabled: true, resourceEnabled: true),
    );
    final ok = await adapter.sendFrame(
      frame: _mkChunkFrame(),
      peerEndpointHint: Uint8List(8),
      peerNodeNum: 1,
      linkId: null,
    );
    expect(ok, isFalse);
    expect(linkEgress.sent, isEmpty);
    await engine.dispose();
  });

  test(
    'happy path: resource frame is encoded and emitted as LINK_DATA',
    () async {
      final (engine, linkEgress, linkId) = await _activeLink();
      final adapter = OverlayResourceProtocolEgress(
        linkEngine: engine,
        flags: () =>
            const OverlayFeatureFlags(linkEnabled: true, resourceEnabled: true),
      );
      final ok = await adapter.sendFrame(
        frame: _mkChunkFrame(resourceId: 0xABCD),
        peerEndpointHint: Uint8List(8),
        peerNodeNum: 1,
        linkId: linkId,
      );
      expect(ok, isTrue);
      // LinkEngine should have emitted one LINK_DATA.
      expect(linkEgress.sent, hasLength(1));
      final linkFrame = linkEgress.sent.single.frame;
      expect(linkFrame.msgType, OverlayLinkMsgType.linkData);
      expect(linkFrame.linkId, linkId);
      // The LINK_DATA payload is the encoded SPP frame.
      expect(OverlayResourceCodec.isResourceFrame(linkFrame.payload), isTrue);
      final decoded = OverlayResourceCodec.decode(linkFrame.payload);
      expect(decoded.isOk, isTrue);
      expect(decoded.frame!.resourceId, 0xABCD);
      await engine.dispose();
    },
  );

  test('propagates false when linkEngine.sendData returns null '
      '(e.g. link not active)', () async {
    final (engine, _, _) = await _activeLink();
    final adapter = OverlayResourceProtocolEgress(
      linkEngine: engine,
      flags: () =>
          const OverlayFeatureFlags(linkEnabled: true, resourceEnabled: true),
    );
    // Pass a linkId that doesn't exist in the engine's store.
    final ok = await adapter.sendFrame(
      frame: _mkChunkFrame(),
      peerEndpointHint: Uint8List(8),
      peerNodeNum: 1,
      linkId: 0xDEADBEEF,
    );
    expect(ok, isFalse);
    await engine.dispose();
  });
}
