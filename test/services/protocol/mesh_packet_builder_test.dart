// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/mesh.pbenum.dart' as pbenum;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/mesh_packet_builder.dart';

void main() {
  group('MeshPacketBuilder.localAdmin', () {
    test('sets from and to to myNodeNum', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: 42,
        data: data,
        packetId: 100,
      );

      expect(packet.from, 42);
      expect(packet.to, 42);
      expect(packet.id, 100);
      expect(packet.decoded, data);
    });

    test('does not set wantAck', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: 42,
        data: data,
        packetId: 100,
      );

      expect(packet.wantAck, isFalse);
    });

    test('does not set priority to RELIABLE', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: 42,
        data: data,
        packetId: 100,
      );

      expect(packet.priority, isNot(pbenum.MeshPacket_Priority.RELIABLE));
    });

    test('does not set hopLimit', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: 42,
        data: data,
        packetId: 100,
      );

      // hopLimit should be at default value (0)
      expect(packet.hopLimit, 0);
    });

    test('does not set channel', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: 42,
        data: data,
        packetId: 100,
      );

      expect(packet.channel, 0);
    });
  });

  group('MeshPacketBuilder.remoteAdmin', () {
    test('sets from to myNodeNum and to to targetNodeNum', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.remoteAdmin(
        myNodeNum: 42,
        targetNodeNum: 99,
        data: data,
        packetId: 200,
      );

      expect(packet.from, 42);
      expect(packet.to, 99);
      expect(packet.id, 200);
    });

    test('sets wantAck to true', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.remoteAdmin(
        myNodeNum: 42,
        targetNodeNum: 99,
        data: data,
        packetId: 200,
      );

      expect(packet.wantAck, isTrue);
    });

    test('sets priority to RELIABLE', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.remoteAdmin(
        myNodeNum: 42,
        targetNodeNum: 99,
        data: data,
        packetId: 200,
      );

      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
    });
  });

  group('MeshPacketBuilder.admin (auto-branching)', () {
    test('local target produces clean packet without routing flags', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.admin(
        myNodeNum: 42,
        targetNodeNum: 42,
        data: data,
        packetId: 300,
      );

      expect(packet.from, 42);
      expect(packet.to, 42);
      expect(packet.wantAck, isFalse);
      expect(packet.priority, isNot(pbenum.MeshPacket_Priority.RELIABLE));
    });

    test('remote target produces packet with RELIABLE and wantAck', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.admin(
        myNodeNum: 42,
        targetNodeNum: 99,
        data: data,
        packetId: 300,
      );

      expect(packet.from, 42);
      expect(packet.to, 99);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
    });
  });

  group('MeshPacketBuilder.userPayload', () {
    test('sets from, to, data, packetId', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 42,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 400,
      );

      expect(packet.from, 42);
      expect(packet.to, 0xFFFFFFFF);
      expect(packet.id, 400);
    });

    test('defaults to no wantAck and channel 0', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 42,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 400,
      );

      expect(packet.wantAck, isFalse);
      expect(packet.channel, 0);
    });

    test('sets wantAck when requested', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 42,
        to: 99,
        data: data,
        packetId: 400,
        wantAck: true,
      );

      expect(packet.wantAck, isTrue);
    });

    test('sets channel when non-zero', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 42,
        to: 99,
        data: data,
        packetId: 400,
        channel: 3,
      );

      expect(packet.channel, 3);
    });

    test('does not set RELIABLE priority', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 42,
        to: 99,
        data: data,
        packetId: 400,
        wantAck: true,
      );

      // User payloads should not have RELIABLE priority
      // (that is reserved for admin packets)
      expect(packet.priority, isNot(pbenum.MeshPacket_Priority.RELIABLE));
    });
  });

  group('Golden invariant: localAdmin never sets routing flags', () {
    // This test codifies the critical invariant that was the root cause
    // of the config-not-persisting bug. Any future change that adds
    // wantAck or RELIABLE priority to localAdmin packets would break
    // config persistence on the device.

    test('wantAck is never true on a localAdmin packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [0xFF];

      // Test with various node numbers to ensure no edge cases
      for (final nodeNum in [1, 42, 0x12345678, 0xFFFFFFFF - 1]) {
        final packet = MeshPacketBuilder.localAdmin(
          myNodeNum: nodeNum,
          data: data,
          packetId: 1,
        );

        expect(
          packet.wantAck,
          isFalse,
          reason:
              'localAdmin packet for node $nodeNum must not set wantAck. '
              'wantAck causes firmware to route through mesh stack instead of '
              'processing directly as a local admin command.',
        );
      }
    });

    test('priority is never RELIABLE on a localAdmin packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [0xFF];

      for (final nodeNum in [1, 42, 0x12345678, 0xFFFFFFFF - 1]) {
        final packet = MeshPacketBuilder.localAdmin(
          myNodeNum: nodeNum,
          data: data,
          packetId: 1,
        );

        expect(
          packet.priority,
          isNot(pbenum.MeshPacket_Priority.RELIABLE),
          reason:
              'localAdmin packet for node $nodeNum must not set RELIABLE '
              'priority. RELIABLE causes firmware to route through mesh stack.',
        );
      }
    });

    test('from always equals to on a localAdmin packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [0xFF];

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: 42,
        data: data,
        packetId: 1,
      );

      expect(
        packet.from,
        equals(packet.to),
        reason: 'localAdmin packet from must equal to (self-addressed)',
      );
    });
  });

  group('Golden invariant: remoteAdmin always sets routing flags', () {
    test('wantAck is always true on a remoteAdmin packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [0xFF];

      final packet = MeshPacketBuilder.remoteAdmin(
        myNodeNum: 42,
        targetNodeNum: 99,
        data: data,
        packetId: 1,
      );

      expect(
        packet.wantAck,
        isTrue,
        reason:
            'remoteAdmin packet must set wantAck for mesh delivery assurance',
      );
    });

    test('priority is always RELIABLE on a remoteAdmin packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [0xFF];

      final packet = MeshPacketBuilder.remoteAdmin(
        myNodeNum: 42,
        targetNodeNum: 99,
        data: data,
        packetId: 1,
      );

      expect(
        packet.priority,
        pbenum.MeshPacket_Priority.RELIABLE,
        reason:
            'remoteAdmin packet must set RELIABLE priority for mesh delivery',
      );
    });
  });

  group('MeshPacketBuilder.adminWithTarget', () {
    test(
      'local AdminTarget produces clean packet (no wantAck, no RELIABLE)',
      () {
        final data = pb.Data()
          ..portnum = pn.PortNum.ADMIN_APP
          ..payload = [1, 2, 3];

        final packet = MeshPacketBuilder.adminWithTarget(
          myNodeNum: 42,
          target: const AdminTarget.local(),
          data: data,
          packetId: 100,
        );

        expect(packet.from, 42);
        expect(packet.to, 42);
        expect(packet.wantAck, isFalse);
        expect(packet.priority, isNot(pbenum.MeshPacket_Priority.RELIABLE));
      },
    );

    test('remote AdminTarget produces packet with RELIABLE + wantAck', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.adminWithTarget(
        myNodeNum: 42,
        target: const AdminTarget.remote(99),
        data: data,
        packetId: 200,
      );

      expect(packet.from, 42);
      expect(packet.to, 99);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
    });

    test('AdminTarget.fromNullable(null) produces local packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.adminWithTarget(
        myNodeNum: 42,
        target: AdminTarget.fromNullable(null),
        data: data,
        packetId: 300,
      );

      expect(packet.from, 42);
      expect(packet.to, 42);
      expect(packet.wantAck, isFalse);
    });

    test('AdminTarget.fromNullable(nodeNum) produces remote packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = [1, 2, 3];

      final packet = MeshPacketBuilder.adminWithTarget(
        myNodeNum: 42,
        target: AdminTarget.fromNullable(99),
        data: data,
        packetId: 400,
      );

      expect(packet.from, 42);
      expect(packet.to, 99);
      expect(packet.wantAck, isTrue);
      expect(packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
    });
  });
}
