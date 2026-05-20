// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for the channel-chat ordering bug where buffered
// MeshPackets with broken or missing rxTime (e.g. a peer radio that
// has no GPS / no phone time sync) were re-stamped to DateTime.now()
// during decode, pushing them past freshly-sent local outbound
// messages in the timeline. With useChronologicalFallback the chat
// decode path now sinks unknown-time packets to the _minPlausibleEpoch
// sentinel (2020-01-01) so they sort as old, not as "just received".

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/protocol_service.dart';

pb.MeshPacket _textPacket({
  required int from,
  required int packetId,
  int? rxTime,
  String text = 'hi',
}) {
  final packet = pb.MeshPacket(
    from: from,
    to: 0xFFFFFFFF,
    id: packetId,
    decoded: pb.Data(
      portnum: pn.PortNum.TEXT_MESSAGE_APP,
      payload: List<int>.from(text.codeUnits),
    ),
  );
  if (rxTime != null) {
    packet.rxTime = rxTime;
  }
  return packet;
}

void main() {
  group('ProtocolService.debugPlausibleTimestamp', () {
    final sentinel = ProtocolService.debugChronologicalFallbackSentinel;

    test('preserves a valid rxTime regardless of fallback mode', () {
      final validEpoch =
          DateTime(2026, 5, 1, 12, 0, 0).millisecondsSinceEpoch ~/ 1000;
      final packet = _textPacket(from: 1, packetId: 1, rxTime: validEpoch);

      final ts = ProtocolService.debugPlausibleTimestamp(packet);
      expect(ts.millisecondsSinceEpoch, validEpoch * 1000);

      final tsChrono = ProtocolService.debugPlausibleTimestamp(
        packet,
        useChronologicalFallback: true,
      );
      expect(
        tsChrono.millisecondsSinceEpoch,
        validEpoch * 1000,
        reason: 'Valid rxTime must win over the chronological sentinel',
      );
    });

    test('rxTime == 0 with chronological fallback returns sentinel', () {
      final packet = _textPacket(from: 1, packetId: 2, rxTime: 0);

      final ts = ProtocolService.debugPlausibleTimestamp(
        packet,
        useChronologicalFallback: true,
      );

      expect(ts, sentinel);
    });

    test('missing rxTime with chronological fallback returns sentinel', () {
      final packet = _textPacket(from: 1, packetId: 3);

      final ts = ProtocolService.debugPlausibleTimestamp(
        packet,
        useChronologicalFallback: true,
      );

      expect(ts, sentinel);
    });

    test(
      'rxTime below _minPlausibleEpoch with chronological fallback returns sentinel',
      () {
        // Pre-2020 epoch (e.g. radio uptime-second since boot).
        final packet = _textPacket(from: 1, packetId: 4, rxTime: 12345);

        final ts = ProtocolService.debugPlausibleTimestamp(
          packet,
          useChronologicalFallback: true,
        );

        expect(ts, sentinel);
      },
    );

    test(
      'rxTime far in the future with chronological fallback returns sentinel',
      () {
        final farFutureEpoch =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + (7 * 24 * 60 * 60);
        final packet = _textPacket(
          from: 1,
          packetId: 5,
          rxTime: farFutureEpoch,
        );

        final ts = ProtocolService.debugPlausibleTimestamp(
          packet,
          useChronologicalFallback: true,
        );

        expect(ts, sentinel);
      },
    );

    test(
      'rxTime == 0 without chronological fallback still returns DateTime.now()',
      () {
        final packet = _textPacket(from: 1, packetId: 6, rxTime: 0);

        final before = DateTime.now();
        final ts = ProtocolService.debugPlausibleTimestamp(packet);
        final after = DateTime.now();

        expect(
          ts.isAtSameMomentAs(before) ||
              (ts.isAfter(before) && ts.isBefore(after)) ||
              ts.isAtSameMomentAs(after),
          isTrue,
          reason:
              'Default fallback path (used by lastHeard) must preserve '
              'DateTime.now() semantics so brand-new nodes still surface '
              'as freshly heard',
        );
        expect(
          ts.isAtSameMomentAs(sentinel),
          isFalse,
          reason: 'Default fallback must not return the chronological sentinel',
        );
      },
    );

    test('sentinel sorts before a freshly-sent local outbound message', () {
      // The bug: an inbound packet with broken rxTime, decoded *after*
      // the user typed and sent their own message, used to get
      // DateTime.now() and sort *after* the local outbound row.
      final outboundSendTime = DateTime.now();
      final fallback = ProtocolService.debugPlausibleTimestamp(
        _textPacket(from: 1, packetId: 7, rxTime: 0),
        useChronologicalFallback: true,
      );

      expect(
        fallback.isBefore(outboundSendTime),
        isTrue,
        reason:
            'Unknown-time inbound must sink to the top of the conversation, '
            'never out-sort a freshly-sent outbound message',
      );
    });
  });
}
