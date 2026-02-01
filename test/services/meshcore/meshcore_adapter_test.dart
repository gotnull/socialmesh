// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/services/meshcore/meshcore_adapter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';

// MeshCore adapter tests using real protocol commands.
//
// Startup sequence (from meshcore-open):
// - Send cmdDeviceQuery (0x16) + cmdAppStart (0x01)
// - Wait for respSelfInfo (0x05)
//
// Ping alternative: Battery request cmdGetBattAndStorage (0x14) -> respBattAndStorage (0x0C)

/// Build a minimal valid SELF_INFO response payload.
///
/// SELF_INFO format (payload after code byte):
/// [0] = ADV_TYPE
/// [1] = tx_power_dbm
/// [2] = MAX_LORA_TX_POWER
/// [3-34] = pub_key (32 bytes)
/// [35-38] = lat (int32 LE)
/// [39-42] = lon (int32 LE)
/// ... more fields ...
/// [57+] = node_name (null-terminated)
List<int> buildSelfInfoResponse(String nodeName) {
  final payload = <int>[
    MeshCoreResponses.selfInfo, // code
    0x01, // ADV_TYPE (chat)
    20, // tx_power_dbm
    22, // MAX_LORA_TX_POWER
    ...List.filled(meshCorePubKeySize, 0xAA), // pub_key (32 bytes)
    0, 0, 0, 0, // lat
    0, 0, 0, 0, // lon
    0, // multi_acks
    0, // advert_loc_policy
    0, // telemetry modes
    0, // manual_add_contacts
    0, 0, 0, 0, // freq (uint32 LE)
    0, 0, 0, 0, // bw (uint32 LE)
    12, // sf
    5, // cr
  ];

  // Pad to offset 57 where node_name starts (in full frame)
  // Since payload includes code at [0], this means payload[57] = node_name start
  // After MeshCoreFrame.fromBytes strips the code, it will be at payload offset 56
  while (payload.length < 58) {
    payload.add(0);
  }

  // Add node name (null-terminated)
  payload.addAll(nodeName.codeUnits);
  payload.add(0); // null terminator

  return payload;
}

/// Build a BATT_AND_STORAGE response.
List<int> buildBattAndStorageResponse() {
  return [
    MeshCoreResponses.battAndStorage,
    0x00, 0x10, // battery millivolts (4096 = 0x1000)
    0x00, 0x01, // storage used
    0x00, 0x04, // storage total
  ];
}

void main() {
  group('MeshCoreAdapter', () {
    late FakeMeshTransport fakeTransport;
    late MeshCoreAdapter adapter;

    setUp(() async {
      fakeTransport = FakeMeshTransport();
      adapter = MeshCoreAdapter(fakeTransport);

      // Connect the fake transport
      await fakeTransport.connect(
        DeviceInfo(
          id: 'test-device',
          name: 'Test MeshCore',
          type: TransportType.ble,
        ),
      );
    });

    tearDown(() async {
      await adapter.dispose();
    });

    group('identify()', () {
      test('returns success with device info on valid response', () async {
        // Queue SELF_INFO response
        final responsePayload = buildSelfInfoResponse('TestNode');
        fakeTransport.queueResponse(responsePayload);

        final result = await adapter.identify();

        expect(result.isSuccess, isTrue);
        expect(result.value, isNotNull);
        expect(result.value!.protocolType, equals(MeshProtocolType.meshcore));
        expect(result.value!.displayName, equals('TestNode'));
      });

      test('sends correct startup sequence', () async {
        // Queue response to complete the call
        final responsePayload = buildSelfInfoResponse('Test');
        fakeTransport.queueResponse(responsePayload);

        await adapter.identify();

        // Verify startup sequence was sent:
        // 1. cmdDeviceQuery (0x16)
        // 2. cmdAppStart (0x01)
        expect(fakeTransport.sentData.length, greaterThanOrEqualTo(2));

        // First should be deviceQuery
        expect(fakeTransport.sentData[0].length, equals(1));
        expect(
          fakeTransport.sentData[0][0],
          equals(MeshCoreCommands.deviceQuery),
        );

        // Second should be appStart
        expect(fakeTransport.sentData[1].length, equals(1));
        expect(fakeTransport.sentData[1][0], equals(MeshCoreCommands.appStart));
      });

      test('returns error on timeout', () async {
        // Don't queue any response - will timeout
        final result = await adapter.identify().timeout(
          const Duration(seconds: 8),
          onTimeout: () => const MeshProtocolResult.failure(
            MeshProtocolError.timeout,
            'Test timeout',
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.error, equals(MeshProtocolError.timeout));
      });

      test('returns error when transport not connected', () async {
        await fakeTransport.disconnect();

        final result = await adapter.identify();

        expect(result.isFailure, isTrue);
        expect(result.error, equals(MeshProtocolError.communicationError));
      });

      test('updates deviceInfo after successful identify', () async {
        expect(adapter.deviceInfo, isNull);

        final responsePayload = buildSelfInfoResponse('MyDevice');
        fakeTransport.queueResponse(responsePayload);

        await adapter.identify();

        expect(adapter.deviceInfo, isNotNull);
        expect(adapter.deviceInfo!.displayName, equals('MyDevice'));
      });

      test('handles short response gracefully', () async {
        // Queue a too-short response
        fakeTransport.queueResponse([
          MeshCoreResponses.selfInfo,
          0x01, // Just ADV_TYPE, not enough data
        ]);

        final result = await adapter.identify();

        expect(result.isFailure, isTrue);
        expect(result.error, equals(MeshProtocolError.identificationFailed));
      });
    });

    group('ping()', () {
      test('returns success with latency using battery request', () async {
        // MeshCore has no ping/pong - uses battery request instead
        final responsePayload = buildBattAndStorageResponse();
        fakeTransport.queueResponse(responsePayload);

        final result = await adapter.ping();

        expect(result.isSuccess, isTrue);
        expect(result.value, isNotNull);
        expect(result.value!.inMilliseconds, greaterThanOrEqualTo(0));
      });

      test('sends getBattAndStorage command', () async {
        fakeTransport.queueResponse(buildBattAndStorageResponse());

        await adapter.ping();

        expect(fakeTransport.sentData.length, equals(1));

        // Should be getBattAndStorage command
        final sent = fakeTransport.sentData[0];
        expect(sent.length, equals(1));
        expect(sent[0], equals(MeshCoreCommands.getBattAndStorage));
      });

      test('returns error on timeout', () async {
        // Don't queue response - will timeout
        final result = await adapter.ping().timeout(
          const Duration(seconds: 12),
          onTimeout: () => const MeshProtocolResult.failure(
            MeshProtocolError.timeout,
            'Test timeout',
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.error, equals(MeshProtocolError.timeout));
      });

      test('returns error when transport not connected', () async {
        await fakeTransport.disconnect();

        final result = await adapter.ping();

        expect(result.isFailure, isTrue);
        expect(result.error, equals(MeshProtocolError.communicationError));
      });
    });

    group('isReady', () {
      test('returns false before identify', () {
        expect(adapter.isReady, isFalse);
      });

      test('returns true after successful identify', () async {
        fakeTransport.queueResponse(buildSelfInfoResponse('Ready'));

        await adapter.identify();

        expect(adapter.isReady, isTrue);
      });

      test('returns false after disconnect', () async {
        fakeTransport.queueResponse(buildSelfInfoResponse('Ready'));

        await adapter.identify();
        expect(adapter.isReady, isTrue);

        await adapter.disconnect();
        expect(adapter.isReady, isFalse);
      });
    });

    group('protocolType', () {
      test('returns meshcore', () {
        expect(adapter.protocolType, equals(MeshProtocolType.meshcore));
      });
    });

    group('disconnect()', () {
      test('clears device info', () async {
        fakeTransport.queueResponse(buildSelfInfoResponse('ToDisconnect'));

        await adapter.identify();
        expect(adapter.deviceInfo, isNotNull);

        await adapter.disconnect();
        expect(adapter.deviceInfo, isNull);
      });
    });

    group('frameStream', () {
      test('emits frames when data received', () async {
        final frames = <MeshCoreFrame>[];
        adapter.frameStream.listen(frames.add);

        // Simulate receiving a frame
        fakeTransport.simulateReceive([
          0x80,
          0x01,
          0x02,
        ]); // Push code with payload

        await Future.delayed(const Duration(milliseconds: 50));

        expect(frames.length, equals(1));
        expect(frames[0].command, equals(0x80));
        expect(frames[0].payload.length, equals(2));
      });
    });
  });

  group('MeshCore BLE protocol behavior', () {
    test('BLE notifications are treated as complete frames', () async {
      final fakeTransport = FakeMeshTransport();
      final adapter = MeshCoreAdapter(fakeTransport);

      await fakeTransport.connect(
        DeviceInfo(id: 'ble-test', name: 'BLE Test', type: TransportType.ble),
      );

      // Simulate receiving raw payload directly (as BLE would deliver)
      fakeTransport.queueResponse(buildBattAndStorageResponse());

      final result = await adapter.ping();

      expect(result.isSuccess, isTrue);

      // Verify sent data was raw frame (no extra framing)
      expect(fakeTransport.sentData[0].length, equals(1));
      expect(
        fakeTransport.sentData[0][0],
        equals(MeshCoreCommands.getBattAndStorage),
      );

      await adapter.dispose();
    });

    test('frames are sent as [command][payload]', () async {
      final fakeTransport = FakeMeshTransport();
      final adapter = MeshCoreAdapter(fakeTransport);

      await fakeTransport.connect(
        DeviceInfo(id: 'ble-test', name: 'BLE Test', type: TransportType.ble),
      );

      // Queue response to satisfy any response waiters
      fakeTransport.queueResponse(buildSelfInfoResponse('Test'));

      await adapter.identify();

      // Check the frame format: deviceQuery is just [0x16]
      expect(fakeTransport.sentData[0], equals([MeshCoreCommands.deviceQuery]));
      expect(fakeTransport.sentData[1], equals([MeshCoreCommands.appStart]));

      await adapter.dispose();
    });
  });

  group('FakeMeshTransport', () {
    late FakeMeshTransport transport;

    setUp(() {
      transport = FakeMeshTransport();
    });

    tearDown(() async {
      await transport.dispose();
    });

    test('connects successfully by default', () async {
      final device = DeviceInfo(
        id: 'test',
        name: 'Test',
        type: TransportType.ble,
      );

      await transport.connect(device);

      expect(transport.isConnected, isTrue);
    });

    test('fails connection when configured', () async {
      transport.connectSucceeds = false;

      final device = DeviceInfo(
        id: 'test',
        name: 'Test',
        type: TransportType.ble,
      );

      expect(() => transport.connect(device), throwsException);
    });

    test('emits state changes', () async {
      final states = <DeviceConnectionState>[];
      transport.connectionStateStream.listen(states.add);

      final device = DeviceInfo(
        id: 'test',
        name: 'Test',
        type: TransportType.ble,
      );

      await transport.connect(device);
      await transport.disconnect();

      await Future.delayed(const Duration(milliseconds: 50));

      expect(states, contains(DeviceConnectionState.connecting));
      expect(states, contains(DeviceConnectionState.connected));
      expect(states, contains(DeviceConnectionState.disconnected));
    });

    test('queues and sends responses', () async {
      final device = DeviceInfo(
        id: 'test',
        name: 'Test',
        type: TransportType.ble,
      );
      await transport.connect(device);

      final response = [0x01, 0x02, 0x03];
      transport.queueResponse(response);

      final receivedData = <List<int>>[];
      transport.dataStream.listen(receivedData.add);

      await transport.sendBytes([0xFF]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedData.length, equals(1));
      expect(receivedData[0], equals(response));
    });

    test('captures sent data', () async {
      final device = DeviceInfo(
        id: 'test',
        name: 'Test',
        type: TransportType.ble,
      );
      await transport.connect(device);

      await transport.sendBytes([0x11, 0x22]);
      await transport.sendBytes([0x33, 0x44, 0x55]);

      expect(transport.sentData.length, equals(2));
      expect(transport.sentData[0], equals([0x11, 0x22]));
      expect(transport.sentData[1], equals([0x33, 0x44, 0x55]));
    });

    test('simulateReceive emits data', () async {
      final receivedData = <List<int>>[];
      transport.dataStream.listen(receivedData.add);

      transport.simulateReceive([0xAA, 0xBB]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedData.length, equals(1));
      expect(receivedData[0], equals([0xAA, 0xBB]));
    });
  });

  // ---------------------------------------------------------------------------
  // Phase 6: identify() mapping tests
  // ---------------------------------------------------------------------------

  group('identify() mapping', () {
    late FakeMeshTransport fakeTransport;
    late MeshCoreAdapter adapter;

    setUp(() async {
      fakeTransport = FakeMeshTransport();
      adapter = MeshCoreAdapter(fakeTransport);

      await fakeTransport.connect(
        DeviceInfo(
          id: 'test-device',
          name: 'Test MeshCore',
          type: TransportType.ble,
        ),
      );
    });

    tearDown(() async {
      await adapter.dispose();
    });

    test('maps nodeName to displayName with trim', () async {
      // Build self info with whitespace in node name
      final responsePayload = buildSelfInfoResponseWithPubKey('  MyNode  ', [
        0x12,
        0x34,
        0x56,
        0x78,
      ]);
      fakeTransport.queueResponse(responsePayload);
      // Queue battery response (identify fetches battery too)
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(3700));

      final result = await adapter.identify();

      expect(result.isSuccess, isTrue);
      expect(result.value!.displayName, equals('MyNode'));
    });

    test('uses fallback displayName for empty nodeName', () async {
      final responsePayload = buildSelfInfoResponseWithPubKey('', [
        0xAA,
        0xBB,
        0xCC,
        0xDD,
      ]);
      fakeTransport.queueResponse(responsePayload);
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(4000));

      final result = await adapter.identify();

      expect(result.isSuccess, isTrue);
      expect(result.value!.displayName, equals('MeshCore'));
    });

    test('uses fallback displayName for whitespace-only nodeName', () async {
      final responsePayload = buildSelfInfoResponseWithPubKey('   ', [
        0xAA,
        0xBB,
        0xCC,
        0xDD,
      ]);
      fakeTransport.queueResponse(responsePayload);
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(4000));

      final result = await adapter.identify();

      expect(result.isSuccess, isTrue);
      expect(result.value!.displayName, equals('MeshCore'));
    });

    test('extracts nodeId from pubKey hex prefix', () async {
      // Use specific pubKey bytes: 0xDE 0xAD 0xBE 0xEF -> nodeId "DEADBEEF"
      final responsePayload = buildSelfInfoResponseWithPubKey('TestNode', [
        0xDE,
        0xAD,
        0xBE,
        0xEF,
      ]);
      fakeTransport.queueResponse(responsePayload);
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(3800));

      final result = await adapter.identify();

      expect(result.isSuccess, isTrue);
      expect(result.value!.nodeId, equals('DEADBEEF'));
    });

    test('maps battery percentage from voltage', () async {
      final responsePayload = buildSelfInfoResponseWithPubKey('Test', [
        0x11,
        0x22,
        0x33,
        0x44,
      ]);
      fakeTransport.queueResponse(responsePayload);
      // 3600mV should map to ~50% (3000=0%, 4200=100%)
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(3600));

      final result = await adapter.identify();

      expect(result.isSuccess, isTrue);
      expect(result.value!.batteryPercentage, isNotNull);
      expect(result.value!.batteryPercentage, equals(50));
    });

    test('includes batteryVoltageMillivolts in deviceInfo', () async {
      final responsePayload = buildSelfInfoResponseWithPubKey('Test', [
        0x11,
        0x22,
        0x33,
        0x44,
      ]);
      fakeTransport.queueResponse(responsePayload);
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(4100));

      final result = await adapter.identify();

      expect(result.isSuccess, isTrue);
      expect(result.value!.batteryVoltageMillivolts, equals(4100));
    });

    test('handles missing battery gracefully (battery fields null)', () async {
      final responsePayload = buildSelfInfoResponseWithPubKey('NoBattery', [
        0x11,
        0x22,
        0x33,
        0x44,
      ]);
      fakeTransport.queueResponse(responsePayload);
      // Don't queue battery response - will timeout

      final result = await adapter.identify().timeout(
        const Duration(seconds: 8),
        onTimeout: () => const MeshProtocolResult.failure(
          MeshProtocolError.timeout,
          'Test timeout',
        ),
      );

      // Identify should still succeed even if battery times out
      expect(result.isSuccess, isTrue);
      expect(result.value!.displayName, equals('NoBattery'));
      // Battery fields should be null
      expect(result.value!.batteryPercentage, isNull);
      expect(result.value!.batteryVoltageMillivolts, isNull);
    });

    test('parse failure returns identificationFailed', () async {
      // Queue a too-short response that will fail to parse
      fakeTransport.queueResponse([
        MeshCoreResponses.selfInfo,
        0x01, // Just ADV_TYPE, not enough data
      ]);

      final result = await adapter.identify();

      expect(result.isFailure, isTrue);
      expect(result.error, equals(MeshProtocolError.identificationFailed));
    });
  });

  group('refreshBattery()', () {
    late FakeMeshTransport fakeTransport;
    late MeshCoreAdapter adapter;

    setUp(() async {
      fakeTransport = FakeMeshTransport();
      adapter = MeshCoreAdapter(fakeTransport);

      await fakeTransport.connect(
        DeviceInfo(
          id: 'test-device',
          name: 'Test MeshCore',
          type: TransportType.ble,
        ),
      );

      // Initial identify to populate deviceInfo
      fakeTransport.queueResponse(
        buildSelfInfoResponseWithPubKey('TestDevice', [0x11, 0x22, 0x33, 0x44]),
      );
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(3600));
      await adapter.identify();
    });

    tearDown(() async {
      await adapter.dispose();
    });

    test('returns updated battery percentage', () async {
      // Queue new battery response with different voltage
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(4000));

      final result = await adapter.refreshBattery();

      // 4000mV should be ~83% (3000=0%, 4200=100%)
      expect(result, isNotNull);
      expect(result, equals(83));
    });

    test('updates deviceInfo with new battery values', () async {
      // Initial deviceInfo should have first battery values
      expect(adapter.deviceInfo!.batteryPercentage, equals(50));
      expect(adapter.deviceInfo!.batteryVoltageMillivolts, equals(3600));

      // Refresh with new values
      fakeTransport.queueResponse(buildBattAndStorageResponseWithVoltage(4200));
      await adapter.refreshBattery();

      // deviceInfo should be updated
      expect(adapter.deviceInfo!.batteryPercentage, equals(100));
      expect(adapter.deviceInfo!.batteryVoltageMillivolts, equals(4200));
    });

    test('returns null when not connected', () async {
      await fakeTransport.disconnect();

      final result = await adapter.refreshBattery();

      expect(result, isNull);
    });

    test('returns null on timeout', () async {
      // Don't queue response - will timeout
      final result = await adapter.refreshBattery();

      expect(result, isNull);
    });
  });
}

/// Build SELF_INFO response with configurable pubKey prefix.
///
/// The [pubKeyPrefix] is used for the first 4 bytes of pubKey (used for nodeId).
/// Remaining pubKey bytes are filled with 0x00.
List<int> buildSelfInfoResponseWithPubKey(
  String nodeName,
  List<int> pubKeyPrefix,
) {
  // Build full pubKey: prefix + padding
  final pubKey = List<int>.filled(meshCorePubKeySize, 0x00);
  for (var i = 0; i < pubKeyPrefix.length && i < meshCorePubKeySize; i++) {
    pubKey[i] = pubKeyPrefix[i];
  }

  final payload = <int>[
    MeshCoreResponses.selfInfo, // code
    0x01, // ADV_TYPE (chat)
    20, // tx_power_dbm
    22, // MAX_LORA_TX_POWER
    ...pubKey, // pub_key (32 bytes)
    0, 0, 0, 0, // lat
    0, 0, 0, 0, // lon
    0, // multi_acks
    0, // advert_loc_policy
    0, // telemetry modes
    0, // manual_add_contacts
    0, 0, 0, 0, // freq (uint32 LE)
    0, 0, 0, 0, // bw (uint32 LE)
    12, // sf
    5, // cr
  ];

  // Pad to offset 57 where node_name starts
  while (payload.length < 58) {
    payload.add(0);
  }

  // Add node name (null-terminated)
  payload.addAll(nodeName.codeUnits);
  payload.add(0); // null terminator

  return payload;
}

/// Build BATT_AND_STORAGE response with configurable voltage.
List<int> buildBattAndStorageResponseWithVoltage(int voltageMillivolts) {
  return [
    MeshCoreResponses.battAndStorage,
    voltageMillivolts & 0xFF, // low byte
    (voltageMillivolts >> 8) & 0xFF, // high byte
    0x00, 0x01, // storage used
    0x00, 0x04, // storage total
  ];
}
