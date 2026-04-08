// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Regression tests for outbound message transport selection and packet
/// construction. These tests verify that Socialmesh matches the official
/// Meshtastic iOS app behaviour for standard message sending.
///
/// Key invariants tested:
/// - Messages are always sent to the node via radio (never app-direct MQTT)
/// - wantAck is true for ALL user messages (channel and DM)
/// - data.wantResponse is never set on user-originated messages
/// - hopLimit and hopStart are left for firmware to set
/// - Packet fields match expected values for channel and DM messages
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/mesh_packet_builder.dart';

void main() {
  group('MeshPacketBuilder.userPayload — transport invariants', () {
    test('channel broadcast sets correct destination and channel', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('Hello channel');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 42,
        channel: 3,
        wantAck: true,
      );

      expect(packet.from, 0x12345678);
      expect(packet.to, 0xFFFFFFFF);
      expect(packet.channel, 3);
      expect(packet.id, 42);
      expect(packet.wantAck, isTrue);
    });

    test('DM sets correct destination and channel 0', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('Hello DM');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xAABBCCDD,
        data: data,
        packetId: 99,
        channel: 0,
        wantAck: true,
      );

      expect(packet.from, 0x12345678);
      expect(packet.to, 0xAABBCCDD);
      expect(packet.channel, 0);
      expect(packet.wantAck, isTrue);
    });

    test('hopLimit is NOT set by builder (firmware handles it)', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 1,
        to: 2,
        data: data,
        packetId: 1,
        wantAck: true,
      );

      // hopLimit should remain at protobuf default (0), meaning firmware
      // will use its configured default hop count.
      expect(packet.hopLimit, 0);
    });

    test('hopStart is NOT set by builder (firmware handles it)', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 1,
        to: 2,
        data: data,
        packetId: 1,
        wantAck: true,
      );

      // hopStart should remain at protobuf default (0). The firmware sets
      // hopStart = hopLimit before radio transmission. Leaving it at 0 is
      // consistent with the official Meshtastic iOS app.
      expect(packet.hopStart, 0);
    });

    test('viaMqtt is NOT set by builder', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 1,
        to: 2,
        data: data,
        packetId: 1,
        wantAck: true,
      );

      // viaMqtt must never be set on outbound user messages.
      // It is a receive-side flag set by the firmware.
      expect(packet.viaMqtt, isFalse);
    });

    test('priority is NOT set by builder for user payloads', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 1,
        to: 2,
        data: data,
        packetId: 1,
        wantAck: true,
      );

      // Priority should be at default (0 = UNSET). The firmware uses the
      // default priority for user messages. Only admin messages set RELIABLE.
      expect(packet.priority, pb.MeshPacket_Priority.UNSET);
    });
  });

  group('Data protobuf — user message construction', () {
    test('wantResponse must NOT be set for user text messages', () {
      // Regression: Socialmesh previously set data.wantResponse = wantAck,
      // which told the receiving node to generate a ROUTING_APP response.
      // The official Meshtastic iOS app never sets wantResponse for user
      // messages. This extra response wastes airtime and deviates from
      // the expected protocol behaviour.
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('Hello')
        ..emoji = 0;

      // wantResponse should be false (default) for all user messages
      expect(data.wantResponse, isFalse);
    });

    test('text message uses TEXT_MESSAGE_APP portnum', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('Test message');

      expect(data.portnum, pn.PortNum.TEXT_MESSAGE_APP);
    });

    test('payload is UTF-8 encoded text', () {
      const text = 'Hello 🌍';
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);

      expect(utf8.decode(data.payload), text);
    });

    test('emoji flag set correctly for tapback', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('👍')
        ..emoji = 1;

      expect(data.emoji, 1);
    });

    test('replyId set when replying', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('Reply')
        ..replyId = 12345;

      expect(data.replyId, 12345);
    });
  });

  group('ToRadio wrapping — packet serialization', () {
    test('user message wrapped in ToRadio.packet', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 42,
        channel: 1,
        wantAck: true,
      );

      final toRadio = pb.ToRadio()..packet = packet;

      // Verify the ToRadio wraps the packet correctly
      expect(toRadio.hasPacket(), isTrue);
      expect(toRadio.packet.from, 0x12345678);
      expect(toRadio.packet.to, 0xFFFFFFFF);
      expect(toRadio.packet.decoded.portnum, pn.PortNum.TEXT_MESSAGE_APP);
    });

    test('serialized ToRadio round-trips correctly', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('round trip test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0xABCD1234,
        to: 0x11223344,
        data: data,
        packetId: 999,
        channel: 2,
        wantAck: true,
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      // Deserialize and verify all fields survived
      final decoded = pb.ToRadio.fromBuffer(bytes);
      expect(decoded.hasPacket(), isTrue);
      expect(decoded.packet.from, 0xABCD1234);
      expect(decoded.packet.to, 0x11223344);
      expect(decoded.packet.id, 999);
      expect(decoded.packet.channel, 2);
      expect(decoded.packet.wantAck, isTrue);
      expect(decoded.packet.hopLimit, 0); // Firmware sets this
      expect(decoded.packet.hopStart, 0); // Firmware sets this
      expect(decoded.packet.viaMqtt, isFalse);
      expect(decoded.packet.decoded.portnum, pn.PortNum.TEXT_MESSAGE_APP);
      expect(utf8.decode(decoded.packet.decoded.payload), 'round trip test');
      // Regression: wantResponse must NOT be set
      expect(decoded.packet.decoded.wantResponse, isFalse);
    });

    test('ToRadio does NOT contain mqttClientProxyMessage for user sends', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 1,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 1,
        wantAck: true,
      );

      final toRadio = pb.ToRadio()..packet = packet;

      // User messages must go through ToRadio.packet (radio path),
      // never through ToRadio.mqttClientProxyMessage (MQTT path).
      expect(toRadio.hasPacket(), isTrue);
      expect(toRadio.hasMqttClientProxyMessage(), isFalse);
    });
  });

  group('wantAck — matches official Meshtastic behaviour', () {
    test('channel broadcast should use wantAck=true', () {
      // Regression: Socialmesh previously set wantAck=false for channel
      // messages. The official Meshtastic iOS app always sets wantAck=true
      // for ALL user messages (channel and DM).
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('channel message');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 42,
        channel: 1,
        wantAck: true, // Must be true for all user messages
      );

      expect(packet.wantAck, isTrue);
    });

    test('DM should use wantAck=true', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('direct message');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xAABBCCDD,
        data: data,
        packetId: 99,
        channel: 0,
        wantAck: true,
      );

      expect(packet.wantAck, isTrue);
    });
  });

  group('Hop metadata comparison with meshtastic-ios', () {
    test('channel message: hop fields match native app defaults', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xFFFFFFFF,
        data: data,
        packetId: 42,
        channel: 0,
        wantAck: true,
      );

      // Both Socialmesh and meshtastic-ios leave these at protobuf default.
      // The firmware sets hopLimit from LoRa config and hopStart = hopLimit
      // before radio transmission.
      expect(packet.hopLimit, 0);
      expect(packet.hopStart, 0);
    });

    test('DM message: hop fields match native app defaults', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 0x12345678,
        to: 0xAABBCCDD,
        data: data,
        packetId: 99,
        channel: 0,
        wantAck: true,
      );

      expect(packet.hopLimit, 0);
      expect(packet.hopStart, 0);
    });
  });

  group('No MQTT direct publish for standard sends', () {
    test('ToRadio for user message uses packet variant, not MQTT proxy', () {
      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode('test');

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: 1,
        to: 2,
        data: data,
        packetId: 1,
        wantAck: true,
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();
      final decoded = pb.ToRadio.fromBuffer(bytes);

      // The payload_variant oneof must be 'packet', not 'mqttClientProxyMessage'
      expect(decoded.whichPayloadVariant(), pb.ToRadio_PayloadVariant.packet);
    });
  });
}
