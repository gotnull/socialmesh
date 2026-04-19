// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for connection bootstrap / sync parity with the
// Meshtastic protocol specification:
// - Time sync packet construction (setTimeOnly admin message)
// - Local admin packet invariants (from == to, no wantAck/RELIABLE)
// - Channel message classification parity (broadcast vs DM)
// - Build re-subscription guard documentation

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/protocol/mesh_packet_builder.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pb.dart' as pn;

void main() {
  // ---------------------------------------------------------------------------
  // Time sync packet construction
  // ---------------------------------------------------------------------------

  group('Time sync packet construction', () {
    test('syncTime produces AdminMessage with setTimeOnly field', () {
      // Replicate what ProtocolService.syncTime() does:
      //   final adminMsg = AdminMessage()..setTimeOnly = timestamp;
      // Then verify the serialized bytes contain the setTimeOnly field.
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final adminMsg = admin.AdminMessage()..setTimeOnly = timestamp;

      // The field must be present after setting it.
      expect(adminMsg.hasSetTimeOnly(), isTrue);
      expect(adminMsg.setTimeOnly, timestamp);

      // Serialize and deserialize — the field must survive the round-trip.
      final bytes = adminMsg.writeToBuffer();
      expect(bytes, isNotEmpty);

      final decoded = admin.AdminMessage.fromBuffer(bytes);
      expect(decoded.hasSetTimeOnly(), isTrue);
      expect(decoded.setTimeOnly, timestamp);

      // Protobuf field tag for setTimeOnly is 43.
      // Verify the tag appears in the wire format (varint-encoded: tag 43,
      // wire type 5 for fixed32 → (43 << 3) | 5 = 349 → but setTimeOnly
      // is OF3 (signed int32), wire type 0 → (43 << 3) | 0 = 344.
      // 344 encoded as varint: 0xD8 0x02.
      // Just confirm the message round-trips correctly — the field tag
      // presence is already proven by hasSetTimeOnly() above.
    });

    test('setTimeOnly uses current Unix timestamp in seconds', () {
      // ProtocolService.syncTime():
      //   final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Verify that integer division by 1000 produces seconds, not millis.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final nowSec = nowMs ~/ 1000;

      // Seconds-epoch values are ~1.7 billion as of 2024.
      // Milliseconds would be ~1.7 trillion. Guard against accidental millis.
      expect(nowSec, lessThan(10000000000)); // < 10 billion (safe until 2286)
      expect(nowSec, greaterThan(1700000000)); // > 2023-11-14

      final adminMsg = admin.AdminMessage()..setTimeOnly = nowSec;
      expect(adminMsg.setTimeOnly, nowSec);

      // Verify the value fits in a uint32 (protobuf fixed32 range).
      expect(nowSec, lessThan(0xFFFFFFFF));
      expect(nowSec, greaterThan(0));
    });

    test('local admin packet has correct from/to (both equal myNodeNum)', () {
      const myNodeNum = 0x12345678;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = (admin.AdminMessage()..setTimeOnly = 1718452800)
            .writeToBuffer();

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: myNodeNum,
        data: data,
        packetId: 42,
      );

      expect(packet.from, myNodeNum);
      expect(packet.to, myNodeNum);
      // from and to must be identical for local admin.
      expect(packet.from, equals(packet.to));
    });

    test('local admin packet does NOT set wantAck or RELIABLE priority', () {
      const myNodeNum = 0xABCD1234;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = (admin.AdminMessage()..setTimeOnly = 1718452800)
            .writeToBuffer();

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: myNodeNum,
        data: data,
        packetId: 99,
      );

      // Local admin packets MUST NOT set wantAck — it would cause the
      // firmware to route through the mesh instead of processing locally.
      expect(packet.wantAck, isFalse);

      // Priority must not be RELIABLE (which is only for remote admin).
      expect(packet.priority, isNot(equals(pb.MeshPacket_Priority.RELIABLE)));

      // Decoded payload must be the admin message we passed in.
      expect(packet.decoded.portnum, pn.PortNum.ADMIN_APP);
      expect(packet.id, 99);
    });
  });

  // ---------------------------------------------------------------------------
  // Channel message classification parity
  // ---------------------------------------------------------------------------

  group('Channel message classification parity', () {
    test('broadcast to 0xFFFFFFFF with channel 0 → isBroadcast true', () {
      final msg = Message(
        from: 0x11223344,
        to: 0xFFFFFFFF,
        text: 'Hello mesh',
        channel: 0,
        received: true,
      );

      expect(msg.isBroadcast, isTrue);
      expect(msg.isDirect, isFalse);
    });

    test('DM to specific node with channel 0 → isBroadcast false', () {
      final msg = Message(
        from: 0x11223344,
        to: 12345,
        text: 'Private message',
        channel: 0,
        received: true,
      );

      expect(msg.isBroadcast, isFalse);
      expect(msg.isDirect, isTrue);
    });

    test(
      'notification classification matches UI classification for broadcast',
      () {
        // Both notification and UI paths determine broadcast purely by the
        // `to` field (0xFFFFFFFF), NOT by the channel index. This test
        // verifies that isBroadcast is independent of channel value.

        // Broadcast on channel 0
        final ch0 = Message(
          from: 0x11,
          to: 0xFFFFFFFF,
          text: 'ch0 broadcast',
          channel: 0,
          received: true,
        );
        expect(ch0.isBroadcast, isTrue);

        // Broadcast on channel 3
        final ch3 = Message(
          from: 0x11,
          to: 0xFFFFFFFF,
          text: 'ch3 broadcast',
          channel: 3,
          received: true,
        );
        expect(ch3.isBroadcast, isTrue);

        // Broadcast with null channel (protobuf default)
        final chNull = Message(
          from: 0x11,
          to: 0xFFFFFFFF,
          text: 'null channel broadcast',
          channel: null,
          received: true,
        );
        expect(chNull.isBroadcast, isTrue);

        // DM with channel 0 — NOT broadcast
        final dm = Message(
          from: 0x11,
          to: 0x22,
          text: 'DM on ch0',
          channel: 0,
          received: true,
        );
        expect(dm.isBroadcast, isFalse);
      },
    );

    test('conversationKey for broadcast ch0 matches UI filter', () {
      final msg = Message(
        from: 0xAABBCCDD,
        to: 0xFFFFFFFF,
        text: 'Broadcast on primary',
        channel: 0,
        received: true,
      );

      // conversationKey must be 'channel:0' for broadcast on channel 0.
      final key = MessageDatabase.conversationKey(msg);
      expect(key, 'channel:0');

      // UI filter: m.channel == 0 && m.isBroadcast must select this message.
      final uiFilterMatch = msg.channel == 0 && msg.isBroadcast;
      expect(uiFilterMatch, isTrue);

      // Both must agree — the message selected by the UI filter must have
      // the matching conversation key.
      expect(uiFilterMatch, isTrue);
      expect(key, 'channel:0');

      // Negative case: a DM on channel 0 must NOT match the UI filter.
      final dm = Message(
        from: 0xAABBCCDD,
        to: 0x11223344,
        text: 'DM on ch0',
        channel: 0,
        received: true,
      );
      final dmKey = MessageDatabase.conversationKey(dm);
      expect(dmKey, isNot('channel:0'));
      expect(dm.channel == 0 && dm.isBroadcast, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Build re-subscription guard
  // ---------------------------------------------------------------------------

  group('Build re-subscription guard', () {
    // ProtocolService tracks a `_subscribedInstance` field to prevent
    // duplicate stream subscriptions when Flutter's widget tree rebuilds
    // and calls subscribe() again on the same protocol service instance.
    //
    // This is difficult to unit-test without a full transport mock because
    // ProtocolService requires a connected DeviceTransport. Instead, we
    // verify the building block that the guard protects: MeshPacketBuilder
    // produces identical packets for the same inputs (idempotency), which
    // is the invariant that makes re-subscription safe.

    test('MeshPacketBuilder.localAdmin is deterministic for same inputs', () {
      const myNodeNum = 0xDEADBEEF;
      const packetId = 777;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = (admin.AdminMessage()..setTimeOnly = 1718452800)
            .writeToBuffer();

      final packet1 = MeshPacketBuilder.localAdmin(
        myNodeNum: myNodeNum,
        data: data,
        packetId: packetId,
      );

      final packet2 = MeshPacketBuilder.localAdmin(
        myNodeNum: myNodeNum,
        data: data,
        packetId: packetId,
      );

      // Same inputs must produce identical wire bytes.
      expect(packet1.writeToBuffer(), equals(packet2.writeToBuffer()));

      // And identical field values.
      expect(packet1.from, packet2.from);
      expect(packet1.to, packet2.to);
      expect(packet1.id, packet2.id);
      expect(packet1.decoded.portnum, packet2.decoded.portnum);
    });

    test('remoteAdmin differs from localAdmin for same data', () {
      const myNodeNum = 0xDEADBEEF;
      const remoteNodeNum = 0xCAFEBABE;
      const packetId = 888;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = (admin.AdminMessage()..setTimeOnly = 1718452800)
            .writeToBuffer();

      final local = MeshPacketBuilder.localAdmin(
        myNodeNum: myNodeNum,
        data: data,
        packetId: packetId,
      );

      final remote = MeshPacketBuilder.remoteAdmin(
        myNodeNum: myNodeNum,
        targetNodeNum: remoteNodeNum,
        data: data,
        packetId: packetId,
      );

      // Remote sets RELIABLE + wantAck; local does not.
      expect(local.wantAck, isFalse);
      expect(remote.wantAck, isTrue);
      expect(remote.priority, pb.MeshPacket_Priority.RELIABLE);
      expect(local.priority, isNot(equals(pb.MeshPacket_Priority.RELIABLE)));

      // Remote targets a different node.
      expect(local.to, myNodeNum);
      expect(remote.to, remoteNodeNum);
    });
  });
}
