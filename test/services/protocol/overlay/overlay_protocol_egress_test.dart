// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayProtocolEgress].
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_feature_flag.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_protocol_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

OverlayLinkFrame _mkLinkOpen() => OverlayLinkFrame(
  msgType: OverlayLinkMsgType.linkOpen,
  flags: OverlayLinkFlags.linkFrame | OverlayLinkFlags.ackRequired,
  requestId: 0,
  serviceId: 0,
  actionId: 0,
  payloadLen: 0,
  linkId: 0xABCDEF01,
  seq: 0,
  ackHi: 0,
  payload: Uint8List(0),
);

void main() {
  group('OverlayProtocolEgress', () {
    test('send returns false when flag is disabled', () async {
      var calls = 0;
      final egress = OverlayProtocolEgress(
        sipSink: (bytes, type) async {
          calls++;
          return true;
        },
        flags: () => OverlayFeatureFlags.disabled,
      );
      final ok = await egress.send(_mkLinkOpen(), 42);
      expect(ok, isFalse);
      expect(calls, 0);
    });

    test(
      'send hands encoded wire bytes to sip sink with mrrpData type',
      () async {
        Uint8List? captured;
        SipMessageType? capturedType;
        final egress = OverlayProtocolEgress(
          sipSink: (bytes, type) async {
            captured = bytes;
            capturedType = type;
            return true;
          },
          flags: () => const OverlayFeatureFlags(linkEnabled: true),
        );
        final frame = _mkLinkOpen();
        final ok = await egress.send(frame, 42);
        expect(ok, isTrue);
        expect(capturedType, SipMessageType.mrrpData);

        // The sink payload is the raw MRRP v0.2 wire bytes.
        expect(captured, isNotNull);
        expect(OverlayLinkCodec.isLinkFrame(captured!), isTrue);
        final decoded = OverlayLinkCodec.decode(captured!);
        expect(decoded.isOk, isTrue);
        expect(decoded.frame!.linkId, frame.linkId);
      },
    );

    test('propagates sip sink false result', () async {
      final egress = OverlayProtocolEgress(
        sipSink: (_, _) async => false,
        flags: () => const OverlayFeatureFlags(linkEnabled: true),
      );
      expect(await egress.send(_mkLinkOpen(), 1), isFalse);
    });

    test('swallows sip sink exceptions and returns false', () async {
      final egress = OverlayProtocolEgress(
        sipSink: (_, _) async => throw StateError('transport down'),
        flags: () => const OverlayFeatureFlags(linkEnabled: true),
      );
      expect(await egress.send(_mkLinkOpen(), 1), isFalse);
    });

    test(
      'returns false if the frame encode itself fails (codec validation)',
      () async {
        // Frame with linkFrame flag unset — codec rejects it.
        final bad = OverlayLinkFrame(
          msgType: OverlayLinkMsgType.linkPing,
          flags: 0,
          requestId: 0,
          serviceId: 0,
          actionId: 0,
          payloadLen: 0,
          linkId: 1,
          seq: 0,
          ackHi: 0,
          payload: Uint8List(0),
        );
        final egress = OverlayProtocolEgress(
          sipSink: (_, _) async => true,
          flags: () => const OverlayFeatureFlags(linkEnabled: true),
        );
        expect(await egress.send(bad, 1), isFalse);
      },
    );
  });
}
