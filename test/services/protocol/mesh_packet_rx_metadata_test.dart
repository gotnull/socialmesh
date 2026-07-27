// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/protocol/mesh_packet_rx_metadata.dart';

void main() {
  group('computeHopCount', () {
    test('hopStart - hopLimit when hopStart present', () {
      final packet = pb.MeshPacket(hopStart: 5, hopLimit: 1);
      expect(computeHopCount(packet), 4);
    });

    test('clamps negative differences to 0', () {
      final packet = pb.MeshPacket(hopStart: 2, hopLimit: 5);
      expect(computeHopCount(packet), 0);
    });

    test('null when hop info absent', () {
      expect(computeHopCount(pb.MeshPacket()), isNull);
    });
  });

  group('receiveViaMqtt', () {
    test('true when the packet passed through an MQTT gateway', () {
      final packet = pb.MeshPacket(viaMqtt: true);
      expect(receiveViaMqtt(packet), isTrue);
    });

    test('false when the field is absent (proto3: absence IS false, '
        'i.e. RF delivery)', () {
      expect(receiveViaMqtt(pb.MeshPacket()), isFalse);
    });

    test('explicit false still reads as RF after a wire round-trip', () {
      final packet = pb.MeshPacket(from: 1, id: 2)..viaMqtt = false;
      final decoded = pb.MeshPacket.fromBuffer(packet.writeToBuffer());
      expect(receiveViaMqtt(decoded), isFalse);
    });

    test('wire round-trip preserves true', () {
      final packet = pb.MeshPacket(from: 1, id: 2, viaMqtt: true);
      final decoded = pb.MeshPacket.fromBuffer(packet.writeToBuffer());
      expect(receiveViaMqtt(decoded), isTrue);
    });
  });
}
