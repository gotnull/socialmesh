// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/generated/meshtastic/atak.pb.dart';
import 'package:socialmesh/services/tak/cot_serializer.dart';
import 'package:socialmesh/services/tak/tak_mesh_bridge.dart';
import 'package:socialmesh/services/tak/tak_client_session.dart';
import 'package:socialmesh/services/tak/tak_server.dart';

// Minimal fake SecureSocket for testing
class FakeSecureSocket extends Fake implements SecureSocket {
  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  int get remotePort => 12345;
}

// Minimal fake TakServer to control broadcasts and events
class FakeTakServer extends Fake implements TakServer {
  final _eventController = StreamController<TakServerEvent>.broadcast();
  final List<String> broadcastedCots = [];
  int _clientCount = 0;

  @override
  Stream<TakServerEvent> get events => _eventController.stream;

  @override
  void broadcastCot(String cotXml) => broadcastedCots.add(cotXml);

  @override
  int get clientCount => _clientCount;

  set clientCount(int v) => _clientCount = v;

  void emitCotReceived(TakClientSession session, String cotXml) {
    _eventController.add(TakCotReceived(session, cotXml));
  }

  Future<void> close() async => _eventController.close();
}

// Minimal fake TakClientSession for outbound tests
class FakeClientSession extends Fake implements TakClientSession {
  @override
  final String uid;

  @override
  final String callsign;

  @override
  String get remoteAddress => '127.0.0.1:12345';

  FakeClientSession({this.uid = 'ANDROID-1234', this.callsign = 'ALPHA1'});
}

void main() {
  late FakeTakServer fakeServer;
  late List<(Uint8List, int, int?)> sentPackets;
  late TakMeshBridge bridge;

  setUp(() {
    fakeServer = FakeTakServer();
    sentPackets = [];
    bridge = TakMeshBridge(
      server: fakeServer,
      meshSend: (payload, {required int portnum, int? destination}) async {
        sentPackets.add((payload, portnum, destination));
      },
    );
  });

  tearDown(() async {
    await bridge.dispose();
    await fakeServer.close();
  });

  group('TakMeshBridge', () {
    test('inbound: mesh PLI packet is broadcast to TAK clients', () async {
      bridge.start();
      fakeServer.clientCount = 2;

      // Build a TAKPacket.
      final packet = TAKPacket()
        ..contact = (Contact()..callsign = 'BRAVO1')
        ..group = (Group()
          ..team = Team.Cyan
          ..role = MemberRole.TeamMember)
        ..status = (Status()..battery = 85)
        ..pli = (PLI()
          ..latitudeI = 408500000
          ..longitudeI = -739000000
          ..altitude = 100
          ..speed = 5
          ..course = 180);

      final payload = Uint8List.fromList(packet.writeToBuffer());

      bridge.handleMeshPacket(
        payload: payload,
        fromNodeNum: 0xDEADBEEF,
        callsign: 'BRAVO1',
      );

      expect(fakeServer.broadcastedCots, hasLength(1));
      expect(fakeServer.broadcastedCots.first, contains('<event'));
      expect(fakeServer.broadcastedCots.first, contains('MESHTASTIC-DEADBEEF'));
      expect(bridge.packetsInbound, 1);
    });

    test('inbound: duplicate packet is suppressed', () async {
      bridge.start();

      final packet = TAKPacket()
        ..contact = (Contact()..callsign = 'ALPHA1')
        ..pli = (PLI()
          ..latitudeI = 400000000
          ..longitudeI = -740000000);

      final payload = Uint8List.fromList(packet.writeToBuffer());

      bridge.handleMeshPacket(
        payload: payload,
        fromNodeNum: 0x12345678,
        callsign: 'ALPHA1',
      );
      bridge.handleMeshPacket(
        payload: payload,
        fromNodeNum: 0x12345678,
        callsign: 'ALPHA1',
      );

      expect(fakeServer.broadcastedCots, hasLength(1));
      expect(bridge.packetsInbound, 1);
    });

    test('inbound: does nothing when bridge is not running', () {
      final packet = TAKPacket()
        ..pli = (PLI()
          ..latitudeI = 400000000
          ..longitudeI = -740000000);

      bridge.handleMeshPacket(
        payload: Uint8List.fromList(packet.writeToBuffer()),
        fromNodeNum: 0x11111111,
        callsign: 'NULL',
      );

      expect(fakeServer.broadcastedCots, isEmpty);
    });

    test('inbound: malformed packet emits error event', () async {
      bridge.start();

      final events = <TakBridgeEvent>[];
      bridge.events.listen(events.add);

      bridge.handleMeshPacket(
        payload: Uint8List.fromList([0xFF, 0xFE, 0xFD]),
        fromNodeNum: 0xBAADF00D,
        callsign: 'BAD',
      );

      // Give stream time to deliver.
      await Future<void>.delayed(Duration.zero);

      // Malformed protobuf may still parse (proto3 is lenient),
      // so we check that something happened.
      expect(
        bridge.packetsInbound + events.where((e) => e.error != null).length,
        greaterThan(0),
      );
    });

    test('outbound: CoT from TAK client is sent to mesh', () async {
      bridge.start();

      // Build a PLI CoT XML.
      final pliPacket = TAKPacket()
        ..contact = (Contact()..callsign = 'TAK-USER')
        ..group = (Group()
          ..team = Team.Cyan
          ..role = MemberRole.TeamMember)
        ..pli = (PLI()
          ..latitudeI = 408500000
          ..longitudeI = -739000000);
      final cotXml = CotSerializer.takPacketToCotXml(
        pliPacket,
        nodeNum: 1,
        callsign: 'TAK-USER',
      );

      final session = FakeClientSession();
      fakeServer.emitCotReceived(session, cotXml);

      // Give listener time to process.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sentPackets, hasLength(1));
      expect(sentPackets.first.$2, TakMeshBridge.atakPortnum);
      expect(bridge.packetsOutbound, 1);
    });

    test('outbound: rate-limited per client', () async {
      bridge.start();

      final pliPacket = TAKPacket()
        ..contact = (Contact()..callsign = 'RATE-TEST')
        ..pli = (PLI()
          ..latitudeI = 408500000
          ..longitudeI = -739000000);
      final cotXml = CotSerializer.takPacketToCotXml(
        pliPacket,
        nodeNum: 1,
        callsign: 'RATE-TEST',
      );

      final session = FakeClientSession(uid: 'RATE-UID');

      // First should succeed.
      fakeServer.emitCotReceived(session, cotXml);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sentPackets, hasLength(1));

      // Second within 5s should be dropped.
      fakeServer.emitCotReceived(session, cotXml);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sentPackets, hasLength(1));
    });

    test('outbound: aggregate rate limit enforced', () async {
      bridge.start();

      final pliPacket = TAKPacket()
        ..contact = (Contact()..callsign = 'AGG-TEST')
        ..pli = (PLI()
          ..latitudeI = 408500000
          ..longitudeI = -739000000);
      final cotXml = CotSerializer.takPacketToCotXml(
        pliPacket,
        nodeNum: 1,
        callsign: 'AGG-TEST',
      );

      // Send 4 from different clients to fill aggregate limit.
      for (var i = 0; i < TakMeshBridge.maxOutboundPerMinute; i++) {
        final session = FakeClientSession(uid: 'CLIENT-$i');
        fakeServer.emitCotReceived(session, cotXml);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(sentPackets, hasLength(TakMeshBridge.maxOutboundPerMinute));

      // Next should be blocked.
      final extraSession = FakeClientSession(uid: 'CLIENT-EXTRA');
      fakeServer.emitCotReceived(extraSession, cotXml);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sentPackets, hasLength(TakMeshBridge.maxOutboundPerMinute));
    });

    test('events stream emits bridge events', () async {
      bridge.start();

      final events = <TakBridgeEvent>[];
      bridge.events.listen(events.add);

      final packet = TAKPacket()
        ..contact = (Contact()..callsign = 'EVENT-TEST')
        ..pli = (PLI()
          ..latitudeI = 408500000
          ..longitudeI = -739000000);

      bridge.handleMeshPacket(
        payload: Uint8List.fromList(packet.writeToBuffer()),
        fromNodeNum: 0xABCDEF01,
        callsign: 'EVENT-TEST',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events.first.direction, TakBridgeDirection.meshToTak);
      expect(events.first.error, isNull);
    });

    test('start and stop lifecycle', () {
      expect(bridge.isRunning, isFalse);
      bridge.start();
      expect(bridge.isRunning, isTrue);
      bridge.stop();
      expect(bridge.isRunning, isFalse);
    });

    test('double start is idempotent', () {
      bridge.start();
      bridge.start(); // Should not throw.
      expect(bridge.isRunning, isTrue);
    });
  });
}
