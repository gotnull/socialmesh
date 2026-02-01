// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

/// Fake transport for testing MeshCoreSession.
class FakeMeshCoreTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rxController =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sentData = [];
  bool _isConnected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rxController.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    if (!_isConnected) {
      throw StateError('Transport not connected');
    }
    sentData.add(data);
  }

  @override
  bool get isConnected => _isConnected;

  /// Simulate receiving data from device.
  void simulateReceive(Uint8List data) {
    _rxController.add(data);
  }

  /// Simulate receiving a frame from device.
  void simulateReceiveFrame(MeshCoreFrame frame) {
    _rxController.add(frame.toBytes());
  }

  /// Simulate disconnection.
  void disconnect() {
    _isConnected = false;
  }

  /// Simulate connection.
  void connect() {
    _isConnected = true;
  }

  /// Simulate transport error.
  void simulateError(Object error) {
    _rxController.addError(error);
  }

  Future<void> dispose() async {
    await _rxController.close();
  }
}

void main() {
  group('FakeMeshCoreTransport', () {
    test('tracks connection state', () {
      final transport = FakeMeshCoreTransport();

      expect(transport.isConnected, isTrue);

      transport.disconnect();
      expect(transport.isConnected, isFalse);

      transport.connect();
      expect(transport.isConnected, isTrue);
    });

    test('records sent data', () async {
      final transport = FakeMeshCoreTransport();

      await transport.sendRaw(Uint8List.fromList([1, 2, 3]));
      await transport.sendRaw(Uint8List.fromList([4, 5]));

      expect(transport.sentData.length, 2);
      expect(transport.sentData[0], Uint8List.fromList([1, 2, 3]));
      expect(transport.sentData[1], Uint8List.fromList([4, 5]));
    });

    test('throws when sending while disconnected', () async {
      final transport = FakeMeshCoreTransport();
      transport.disconnect();

      expect(
        () => transport.sendRaw(Uint8List.fromList([1])),
        throwsStateError,
      );
    });
  });

  group('MeshCoreSession', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;

    setUp(() {
      transport = FakeMeshCoreTransport();
      session = MeshCoreSession(transport);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    test('initial state is active when transport connected', () {
      expect(session.state, MeshCoreSessionState.active);
      expect(session.isActive, isTrue);
    });

    test('initial state is disconnected when transport not connected', () {
      transport.disconnect();
      final disconnectedSession = MeshCoreSession(transport);

      expect(disconnectedSession.state, MeshCoreSessionState.disconnected);
      expect(disconnectedSession.isActive, isFalse);
    });

    test('receives frames from transport', () async {
      final receivedFrames = <MeshCoreFrame>[];
      session.frameStream.listen(receivedFrames.add);

      // Give stream time to set up
      await Future<void>.delayed(Duration.zero);

      transport.simulateReceive(Uint8List.fromList([0x05, 1, 2, 3]));

      // Give stream time to process
      await Future<void>.delayed(Duration.zero);

      expect(receivedFrames.length, 1);
      expect(receivedFrames[0].command, 0x05);
      expect(receivedFrames[0].payload, Uint8List.fromList([1, 2, 3]));
    });

    test('receives multiple frames', () async {
      final receivedFrames = <MeshCoreFrame>[];
      session.frameStream.listen(receivedFrames.add);

      await Future<void>.delayed(Duration.zero);

      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x05));
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x80, payload: Uint8List.fromList([1, 2])),
      );

      await Future<void>.delayed(Duration.zero);

      expect(receivedFrames.length, 2);
      expect(receivedFrames[0].command, 0x05);
      expect(receivedFrames[1].command, 0x80);
      expect(receivedFrames[1].isPush, isTrue);
    });

    test('sends frame via transport', () async {
      final frame = MeshCoreFrame(
        command: 0x04,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      await session.sendFrame(frame);

      expect(transport.sentData.length, 1);
      expect(transport.sentData[0], frame.toBytes());
    });

    test('sendCommand sends simple frame', () async {
      await session.sendCommand(0x04);

      expect(transport.sentData.length, 1);
      expect(transport.sentData[0], Uint8List.fromList([0x04]));
    });

    test('sendCommandWithByte sends frame with arg', () async {
      await session.sendCommandWithByte(0x1F, 0x02);

      expect(transport.sentData.length, 1);
      expect(transport.sentData[0], Uint8List.fromList([0x1F, 0x02]));
    });

    test('sendCommandWithPayload sends frame with payload', () async {
      await session.sendCommandWithPayload(0x05, Uint8List.fromList([1, 2]));

      expect(transport.sentData.length, 1);
      expect(transport.sentData[0], Uint8List.fromList([0x05, 1, 2]));
    });

    test('waitForResponse returns matching frame', () async {
      // Start waiting before simulating response
      final responseFuture = session.waitForResponse(0x05);

      // Delay then send response
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x05, payload: Uint8List.fromList([0xAA])),
      );

      final response = await responseFuture;

      expect(response, isNotNull);
      expect(response!.command, 0x05);
      expect(response.payload[0], 0xAA);
    });

    test('waitForResponse ignores non-matching frames', () async {
      final responseFuture = session.waitForResponse(0x05);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x06)); // wrong code
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x07)); // wrong code
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x05)); // match!

      final response = await responseFuture;

      expect(response, isNotNull);
      expect(response!.command, 0x05);
    });

    test('waitForResponse times out', () async {
      final response = await session.waitForResponse(
        0x05,
        timeout: const Duration(milliseconds: 50),
      );

      expect(response, isNull);
    });

    test('sendAndWait sends and receives', () async {
      // Start send and wait
      final responseFuture = session.sendAndWait(
        0x04,
        expectedResponse: 0x05,
        timeout: const Duration(seconds: 1),
      );

      // Delay then send response
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x05, payload: Uint8List.fromList([0xBB])),
      );

      final response = await responseFuture;

      // Verify command was sent
      expect(transport.sentData.length, 1);
      expect(transport.sentData[0], Uint8List.fromList([0x04]));

      // Verify response received
      expect(response, isNotNull);
      expect(response!.command, 0x05);
    });

    test('reports decode errors', () async {
      final errors = <String>[];
      session.errorStream.listen(errors.add);

      await Future<void>.delayed(Duration.zero);

      // Send oversized frame
      transport.simulateReceive(Uint8List(200));

      await Future<void>.delayed(Duration.zero);

      expect(errors.length, 1);
      expect(errors[0], contains('exceeds max size'));
    });

    test('reports transport errors', () async {
      final errors = <String>[];
      session.errorStream.listen(errors.add);

      await Future<void>.delayed(Duration.zero);

      transport.simulateError(Exception('BLE disconnected'));

      await Future<void>.delayed(Duration.zero);

      expect(errors.length, 1);
      expect(errors[0], contains('Transport error'));
    });

    test('updateState syncs with transport', () {
      expect(session.state, MeshCoreSessionState.active);

      transport.disconnect();
      session.updateState();

      expect(session.state, MeshCoreSessionState.disconnected);

      transport.connect();
      session.updateState();

      expect(session.state, MeshCoreSessionState.active);
    });

    test('resetCodec clears decoder state', () {
      // This is mainly for USB buffered mode, but verify it doesn't crash
      session.resetCodec();
      // No error = success
    });

    test('dispose stops receiving frames', () async {
      final receivedFrames = <MeshCoreFrame>[];
      session.frameStream.listen(receivedFrames.add);

      await Future<void>.delayed(Duration.zero);

      await session.dispose();

      // This should not reach the disposed session
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x05));

      await Future<void>.delayed(Duration.zero);

      expect(receivedFrames.isEmpty, isTrue);
    });
  });

  group('MeshCoreSession frame routing', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;

    setUp(() {
      transport = FakeMeshCoreTransport();
      session = MeshCoreSession(transport);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    test('routes response codes (< 0x80)', () async {
      final frames = <MeshCoreFrame>[];
      session.frameStream.listen(frames.add);

      await Future<void>.delayed(Duration.zero);

      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x00)); // ok
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x05)); // selfInfo
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x0D)); // deviceInfo

      await Future<void>.delayed(Duration.zero);

      expect(frames.length, 3);
      expect(frames.every((f) => f.isResponse), isTrue);
      expect(frames.every((f) => !f.isPush), isTrue);
    });

    test('routes push codes (>= 0x80)', () async {
      final frames = <MeshCoreFrame>[];
      session.frameStream.listen(frames.add);

      await Future<void>.delayed(Duration.zero);

      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x80)); // advert
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x81)); // pathUpdated
      transport.simulateReceiveFrame(
        MeshCoreFrame.simple(0x82),
      ); // sendConfirmed

      await Future<void>.delayed(Duration.zero);

      expect(frames.length, 3);
      expect(frames.every((f) => f.isPush), isTrue);
      expect(frames.every((f) => !f.isResponse), isTrue);
    });

    test('handles rapid frame sequence', () async {
      final frames = <MeshCoreFrame>[];
      session.frameStream.listen(frames.add);

      await Future<void>.delayed(Duration.zero);

      // Rapid sequence of frames
      for (int i = 0; i < 20; i++) {
        transport.simulateReceiveFrame(
          MeshCoreFrame(command: i, payload: Uint8List.fromList([i, i, i])),
        );
      }

      // Need longer delay for 20 frames
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(frames.length, 20);
      for (int i = 0; i < 20; i++) {
        expect(frames[i].command, i);
        expect(frames[i].payload[0], i);
      }
    });
  });

  group('MeshCoreSession high-level primitives', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;

    setUp(() {
      transport = FakeMeshCoreTransport();
      session = MeshCoreSession(transport);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    /// Build a valid SELF_INFO response payload.
    Uint8List buildSelfInfoPayload(String nodeName) {
      final payload = <int>[
        0x01, // ADV_TYPE
        20, // tx_power
        22, // MAX_LORA_TX_POWER
        ...List.filled(32, 0xAA), // pub_key (32 bytes)
        0, 0, 0, 0, // lat
        0, 0, 0, 0, // lon
        0, // multi_acks
        0, // advert_loc_policy
        0, // telemetry modes
        0, // manual_add_contacts
        0, 0, 0, 0, // freq
        0, 0, 0, 0, // bw
        12, // sf
        5, // cr
      ];
      // Pad to offset 57 where node_name starts
      while (payload.length < 57) {
        payload.add(0);
      }
      payload.addAll(nodeName.codeUnits);
      payload.add(0); // null terminator
      return Uint8List.fromList(payload);
    }

    /// Build a BATT_AND_STORAGE response payload.
    Uint8List buildBattAndStoragePayload({
      int batteryMv = 3700,
      int used = 100,
      int total = 1000,
    }) {
      return Uint8List.fromList([
        batteryMv & 0xFF,
        (batteryMv >> 8) & 0xFF,
        used & 0xFF,
        (used >> 8) & 0xFF,
        total & 0xFF,
        (total >> 8) & 0xFF,
      ]);
    }

    test('getSelfInfo sends correct command sequence', () async {
      // Start getSelfInfo, then simulate response
      final selfInfoFuture = session.getSelfInfo(
        timeout: const Duration(seconds: 1),
      );

      // Small delay to let commands send
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify startup sequence sent: deviceQuery (0x16) then appStart (0x01)
      expect(transport.sentData.length, 2);
      expect(transport.sentData[0], Uint8List.fromList([0x16])); // deviceQuery
      expect(transport.sentData[1], Uint8List.fromList([0x01])); // appStart

      // Simulate selfInfo response (code 0x05)
      final responsePayload = buildSelfInfoPayload('TestDevice');
      transport.simulateReceive(Uint8List.fromList([0x05, ...responsePayload]));

      final result = await selfInfoFuture;

      expect(result, isNotNull);
      expect(result!.nodeName, equals('TestDevice'));
    });

    test('getSelfInfo parses node name correctly', () async {
      final selfInfoFuture = session.getSelfInfo();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Simulate response with specific node name
      final responsePayload = buildSelfInfoPayload('MyCoolNode');
      transport.simulateReceive(Uint8List.fromList([0x05, ...responsePayload]));

      final result = await selfInfoFuture;

      expect(result, isNotNull);
      expect(result!.nodeName, equals('MyCoolNode'));
      expect(result.advType, equals(0x01));
      expect(result.txPowerDbm, equals(20));
    });

    test('getSelfInfo returns null on timeout', () async {
      final result = await session.getSelfInfo(
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isNull);
    });

    test('getBattAndStorage sends correct command', () async {
      final battFuture = session.getBattAndStorage(
        timeout: const Duration(seconds: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify getBattAndStorage command sent (0x14)
      expect(transport.sentData.length, 1);
      expect(transport.sentData[0], Uint8List.fromList([0x14]));

      // Simulate battAndStorage response (code 0x0C)
      final responsePayload = buildBattAndStoragePayload(
        batteryMv: 3800,
        used: 50,
        total: 200,
      );
      transport.simulateReceive(Uint8List.fromList([0x0C, ...responsePayload]));

      final result = await battFuture;

      expect(result, isNotNull);
      expect(result!.batteryMillivolts, equals(3800));
      expect(result.storageUsed, equals(50));
      expect(result.storageTotal, equals(200));
    });

    test('getBattAndStorage returns null on timeout', () async {
      final result = await session.getBattAndStorage(
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isNull);
    });

    test('ping returns latency using battery request', () async {
      final pingFuture = session.ping(timeout: const Duration(seconds: 1));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify battery command sent
      expect(transport.sentData[0], Uint8List.fromList([0x14]));

      // Simulate response
      transport.simulateReceive(
        Uint8List.fromList([0x0C, ...buildBattAndStoragePayload()]),
      );

      final latency = await pingFuture;

      expect(latency, isNotNull);
      expect(latency!.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('ping returns null on timeout', () async {
      final result = await session.ping(
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isNull);
    });
  });

  group('MeshCoreSession race-safe response handling', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;

    setUp(() {
      transport = FakeMeshCoreTransport();
      session = MeshCoreSession(transport);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    test('handles response arriving immediately after send', () async {
      // This tests the race condition where response arrives quickly
      // The waiter is registered BEFORE sending, so even fast responses are caught

      // Start getSelfInfo which registers waiter before sending
      final selfInfoFuture = session.getSelfInfo(
        timeout: const Duration(seconds: 1),
      );

      // Give minimal time for send
      await Future<void>.delayed(const Duration(milliseconds: 1));

      // Immediately simulate response (response arriving very quickly)
      transport.simulateReceive(
        Uint8List.fromList([
          0x05, // selfInfo response code
          0x01, 20, 22, // ADV_TYPE, tx_power, max_lora_tx
          ...List.filled(32, 0xAA), // pub_key (32 bytes)
          0, 0, 0, 0, 0, 0, 0, 0, // lat/lon
          ...List.filled(14, 0), // padding to offset 57
          ...'FastNode'.codeUnits, 0, // node name
        ]),
      );

      // This should still work because waiter was registered before sending
      final result = await selfInfoFuture;

      expect(result, isNotNull);
      expect(result!.advType, equals(0x01));
      expect(result.nodeName, equals('FastNode'));
    });

    test('single-flight policy: second waiter throws StateError', () async {
      // Register first waiter
      final future1 = session.waitForResponse(0x05);

      // Second waiter for same code should throw
      expect(
        () => session.waitForResponse(0x05),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Single-flight violation'),
          ),
        ),
      );

      // Clean up first waiter
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x05, payload: Uint8List.fromList([0x01])),
      );
      await future1;
    });

    test('clearPendingResponses errors all waiters', () async {
      final future1 = session.waitForResponse(0x05);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      session.clearPendingResponses();

      // Should complete with StateError
      expect(
        future1,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    });
  });

  group('MeshCoreSession push code protection', () {
    late FakeMeshCoreTransport transport;
    late MeshCoreSession session;

    setUp(() {
      transport = FakeMeshCoreTransport();
      session = MeshCoreSession(transport);
    });

    tearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    test('registering waiter for push code throws ArgumentError', () {
      // Push codes are 0x80+, cannot be waited on
      expect(
        () => session.waitForResponse(0x80),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Cannot wait for push codes'),
          ),
        ),
      );
      expect(
        () => session.waitForResponse(0x85),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => session.waitForResponse(0xFF),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('push codes do not satisfy response waiters', () async {
      // Register waiter for SELF_INFO (0x05)
      final selfInfoFuture = session.waitForResponse(
        0x05,
        timeout: const Duration(milliseconds: 200),
      );

      // Inject push frames - these should NOT satisfy the waiter
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x80)); // advert
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x81)); // pathUpdated
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x82)); // confirmed

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Waiter should still be pending
      expect(session.hasWaiter(0x05), isTrue);

      // Now send the real response
      transport.simulateReceiveFrame(
        MeshCoreFrame(command: 0x05, payload: Uint8List.fromList([0x01])),
      );

      final result = await selfInfoFuture;
      expect(result, isNotNull);
      expect(result!.command, equals(0x05));
    });

    test('push codes still emitted to frameStream', () async {
      final frames = <MeshCoreFrame>[];
      session.frameStream.listen(frames.add);

      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x80));
      transport.simulateReceiveFrame(MeshCoreFrame.simple(0x05));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(frames.length, equals(2));
      expect(frames[0].command, equals(0x80));
      expect(frames[1].command, equals(0x05));
    });
  });
}
