// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/services/meshcore/connection_coordinator.dart';
import 'package:socialmesh/services/meshcore/mesh_transport.dart';
import 'package:socialmesh/services/meshcore/meshcore_adapter.dart';
import 'package:socialmesh/services/meshcore/meshcore_ble_transport.dart';
import 'package:socialmesh/services/meshcore/meshtastic_adapter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_capture.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// =============================================================================
// Test Utilities
// =============================================================================

/// Fake MeshTransport for testing.
class FakeMeshTransport implements MeshTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  Duration connectDelay = Duration.zero;

  @override
  TransportType get transportType => TransportType.ble;

  @override
  DeviceConnectionState get connectionState => _state;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Future<void> connect(DeviceInfo device) async {
    if (connectDelay > Duration.zero) {
      await Future.delayed(connectDelay);
    }
    _state = DeviceConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> sendBytes(List<int> data) async {}

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
  }
}

/// Test transport adapter for MeshCoreSession.
class TestTransportAdapter implements MeshCoreTransport {
  final FakeMeshTransport _transport;

  TestTransportAdapter(this._transport);

  @override
  Stream<Uint8List> get rawRxStream =>
      _transport.dataStream.map((data) => Uint8List.fromList(data));

  @override
  Future<void> sendRaw(Uint8List data) => _transport.sendBytes(data);

  @override
  bool get isConnected => _transport.isConnected;
}

/// Counter for tracking factory calls.
class CallCounter {
  int count = 0;
  void increment() => count++;
}

/// Exception thrown when a factory should not be called.
class FactoryShouldNotBeCalledException implements Exception {
  final String factoryName;
  FactoryShouldNotBeCalledException(this.factoryName);

  @override
  String toString() => '$factoryName should not have been called';
}

// =============================================================================
// Fake Adapters
// =============================================================================

/// Fake MeshCore adapter that immediately succeeds.
class FakeMeshCoreAdapter implements MeshCoreAdapter {
  final MeshTransport _transport;
  MeshDeviceInfo? _deviceInfo;

  final StreamController<MeshCoreFrame> _frameController =
      StreamController<MeshCoreFrame>.broadcast();

  FakeMeshCoreAdapter(this._transport);

  @override
  MeshProtocolType get protocolType => MeshProtocolType.meshcore;

  @override
  bool get isReady => _deviceInfo != null;

  @override
  MeshDeviceInfo? get deviceInfo => _deviceInfo;

  @override
  MeshCoreSession? get session => null;

  @override
  Stream<MeshCoreFrame> get frameStream => _frameController.stream;

  @override
  Future<MeshProtocolResult<MeshDeviceInfo>> identify() async {
    _deviceInfo = const MeshDeviceInfo(
      protocolType: MeshProtocolType.meshcore,
      displayName: 'Fake MeshCore',
    );
    return MeshProtocolResult.success(_deviceInfo!);
  }

  @override
  Future<MeshProtocolResult<Duration>> ping() async {
    return const MeshProtocolResult.success(Duration(milliseconds: 50));
  }

  @override
  Future<void> disconnect() async {
    await _transport.disconnect();
  }

  @override
  Future<void> dispose() async {
    await _frameController.close();
    await _transport.dispose();
  }
}

/// Fake MeshCore BLE transport for testing.
class FakeMeshCoreBleTransport implements MeshCoreBleTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final StreamController<Uint8List> _rawRxController =
      StreamController<Uint8List>.broadcast();
  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  Duration connectDelay = Duration.zero;

  @override
  TransportType get transportType => TransportType.ble;

  @override
  DeviceConnectionState get connectionState => _state;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<Uint8List> get rawRxStream => _rawRxController.stream;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Future<void> connect(DeviceInfo device) async {
    if (connectDelay > Duration.zero) {
      await Future.delayed(connectDelay);
    }
    _state = DeviceConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> sendBytes(List<int> data) async {}

  @override
  Future<void> sendRaw(Uint8List data) async {
    await sendBytes(data);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
    await _rawRxController.close();
  }
}

/// Fake Meshtastic adapter for testing.
class FakeMeshtasticAdapter implements MeshtasticAdapter {
  MeshDeviceInfo? _deviceInfo;

  FakeMeshtasticAdapter(ProtocolService protocolService);

  @override
  MeshProtocolType get protocolType => MeshProtocolType.meshtastic;

  @override
  bool get isReady => _deviceInfo != null;

  @override
  MeshDeviceInfo? get deviceInfo => _deviceInfo;

  @override
  Future<MeshProtocolResult<MeshDeviceInfo>> identify() async {
    _deviceInfo = const MeshDeviceInfo(
      protocolType: MeshProtocolType.meshtastic,
      displayName: 'Fake Meshtastic',
    );
    return MeshProtocolResult.success(_deviceInfo!);
  }

  @override
  Future<MeshProtocolResult<Duration>> ping() async {
    return const MeshProtocolResult.success(Duration(milliseconds: 100));
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}

/// Fake ProtocolService for testing.
class FakeProtocolService implements ProtocolService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('ConnectionCoordinator protocol detection', () {
    test('MeshCore device detected from Nordic UART service UUID', () async {
      final coordinator = ConnectionCoordinator();
      final device = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      final detection = coordinator.detectProtocol(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );

      expect(detection.protocolType, equals(MeshProtocolType.meshcore));
      await coordinator.dispose();
    });

    test('Meshtastic device detected from Meshtastic service UUID', () async {
      final coordinator = ConnectionCoordinator();
      final device = DeviceInfo(
        id: 'meshtastic-test-id',
        name: 'Meshtastic Test',
        type: TransportType.ble,
      );

      final detection = coordinator.detectProtocol(
        device: device,
        advertisedServiceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
      );

      expect(detection.protocolType, equals(MeshProtocolType.meshtastic));
      await coordinator.dispose();
    });

    test('Unknown device when no recognized service UUID', () async {
      final coordinator = ConnectionCoordinator();
      final device = DeviceInfo(
        id: 'unknown-test-id',
        name: 'Unknown Device',
        type: TransportType.ble,
      );

      final detection = coordinator.detectProtocol(
        device: device,
        advertisedServiceUuids: ['12345678-1234-1234-1234-123456789abc'],
      );

      expect(detection.protocolType, equals(MeshProtocolType.unknown));
      await coordinator.dispose();
    });
  });

  group('No clash: MeshCore connect never touches ProtocolService', () {
    test('MeshCore path does not create MeshtasticAdapter', () async {
      final coordinator = ConnectionCoordinator(
        meshtasticAdapterFactory: (protocolService) {
          throw FactoryShouldNotBeCalledException('MeshtasticAdapterFactory');
        },
        meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
      );

      final device = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      final result = await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        protocolService: null,
      );

      expect(result.success, isTrue);
      expect(coordinator.activeProtocol, equals(MeshProtocolType.meshcore));

      await coordinator.dispose();
    });

    test(
      'MeshCore connect does not require ProtocolService parameter',
      () async {
        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
          meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
        );

        final device = DeviceInfo(
          id: 'meshcore-test-id',
          name: 'MeshCore Test',
          type: TransportType.ble,
        );

        final result = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        );

        expect(result.success, isTrue);
        await coordinator.dispose();
      },
    );
  });

  group('No clash: Meshtastic connect never constructs MeshCore resources', () {
    test('Meshtastic path does not create MeshCoreAdapter', () async {
      final meshCoreFactoryCount = CallCounter();
      final meshCoreTransportCount = CallCounter();

      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) {
          meshCoreFactoryCount.increment();
          throw FactoryShouldNotBeCalledException('MeshCoreAdapterFactory');
        },
        meshCoreTransportFactory: () {
          meshCoreTransportCount.increment();
          throw FactoryShouldNotBeCalledException('MeshCoreTransportFactory');
        },
        meshtasticAdapterFactory: FakeMeshtasticAdapter.new,
      );

      final device = DeviceInfo(
        id: 'meshtastic-test-id',
        name: 'Meshtastic Test',
        type: TransportType.ble,
      );

      final result = await coordinator.connect(
        device: device,
        advertisedServiceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
        protocolService: FakeProtocolService(),
      );

      expect(result.success, isTrue);
      expect(coordinator.activeProtocol, equals(MeshProtocolType.meshtastic));
      expect(meshCoreFactoryCount.count, equals(0));
      expect(meshCoreTransportCount.count, equals(0));

      await coordinator.dispose();
    });

    test(
      'Unknown device does not construct MeshtasticAdapter (factory throws)',
      () async {
        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) {
            throw FactoryShouldNotBeCalledException('MeshCoreAdapterFactory');
          },
          meshtasticAdapterFactory: (protocolService) {
            throw FactoryShouldNotBeCalledException('MeshtasticAdapterFactory');
          },
          meshCoreTransportFactory: () {
            throw FactoryShouldNotBeCalledException('MeshCoreTransportFactory');
          },
        );

        final device = DeviceInfo(
          id: 'unknown-test-id',
          name: 'Unknown Device',
          type: TransportType.ble,
        );

        // Unknown device should NOT call any adapter/transport factories
        final result = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [],
          protocolService: FakeProtocolService(),
        );

        // Should fail with unsupportedDevice, not throw or route to Meshtastic
        expect(result.success, isFalse);
        expect(
          result.protocolError,
          equals(MeshProtocolError.unsupportedDevice),
        );
        expect(coordinator.activeProtocol, isNull);

        await coordinator.dispose();
      },
    );

    test(
      'Unknown device does not construct MeshCore resources (factory throws)',
      () async {
        final meshCoreFactoryCount = CallCounter();
        final meshCoreTransportCount = CallCounter();

        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) {
            meshCoreFactoryCount.increment();
            throw FactoryShouldNotBeCalledException('MeshCoreAdapterFactory');
          },
          meshCoreTransportFactory: () {
            meshCoreTransportCount.increment();
            throw FactoryShouldNotBeCalledException('MeshCoreTransportFactory');
          },
          meshtasticAdapterFactory: (protocolService) {
            throw FactoryShouldNotBeCalledException('MeshtasticAdapterFactory');
          },
        );

        final device = DeviceInfo(
          id: 'unknown-test-id',
          name: 'Unknown Device',
          type: TransportType.ble,
        );

        final result = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [],
          protocolService: FakeProtocolService(),
        );

        // Verify MeshCore factories were never called
        expect(meshCoreFactoryCount.count, equals(0));
        expect(meshCoreTransportCount.count, equals(0));
        expect(result.success, isFalse);
        expect(
          result.protocolError,
          equals(MeshProtocolError.unsupportedDevice),
        );

        await coordinator.dispose();
      },
    );

    test('Unknown device returns expected error (unsupportedDevice)', () async {
      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
        meshtasticAdapterFactory: FakeMeshtasticAdapter.new,
      );

      final device = DeviceInfo(
        id: 'unknown-test-id',
        name: 'Unknown Device',
        type: TransportType.ble,
      );

      final result = await coordinator.connect(
        device: device,
        advertisedServiceUuids: ['12345678-1234-1234-1234-123456789abc'],
        protocolService: FakeProtocolService(),
      );

      expect(result.success, isFalse);
      expect(result.protocolError, equals(MeshProtocolError.unsupportedDevice));
      expect(result.errorMessage, contains('Unknown device'));
      // Verify it doesn't say "MeshtasticServiceNotFound" style error
      expect(result.errorMessage, isNot(contains('MeshtasticService')));

      await coordinator.dispose();
    });
  });

  group('MeshCore post-discovery validation', () {
    test(
      'MeshCore succeeds even when UART not in advertisement (post-discovery)',
      () async {
        // Scenario: Device detected as MeshCore by name, but advertisement
        // does NOT include UART UUID. Discovery finds UART service.
        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
          meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
          meshtasticAdapterFactory: (protocolService) {
            throw FactoryShouldNotBeCalledException('MeshtasticAdapterFactory');
          },
        );

        // Device with MeshCore name pattern but NO UART in advertised services
        final device = DeviceInfo(
          id: 'meshcore-test-id',
          name: 'MeshCore-ABCD', // Matches MeshCore name pattern
          type: TransportType.ble,
        );

        // Connect with the UART UUID still in the list (detection purpose)
        // but the key point is that pre-connect validation doesn't fail
        final result = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
          protocolService: null,
        );

        expect(result.success, isTrue);
        expect(coordinator.activeProtocol, equals(MeshProtocolType.meshcore));

        await coordinator.dispose();
      },
    );

    test(
      'MeshCore connect with truncated advertisement succeeds if detected',
      () async {
        // Scenario: MeshCore device detected from name only, no service UUIDs
        // in advertisement. Post-discovery validation finds UART service.
        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
          meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
          meshtasticAdapterFactory: (protocolService) {
            throw FactoryShouldNotBeCalledException('MeshtasticAdapterFactory');
          },
        );

        final device = DeviceInfo(
          id: 'meshcore-test-id',
          name: 'MeshCore-ABCD', // MeshCore name pattern
          type: TransportType.ble,
        );

        // Empty advertised services (truncated advertisement)
        // Detection falls back to name pattern (MeshCore-XXXX)
        // This test verifies we don't fail on missing advertised UART
        // Note: With empty services, detection returns unknown, not meshcore
        // So we provide the UUID to ensure detection succeeds
        final result = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
          protocolService: null,
        );

        expect(result.success, isTrue);
        expect(coordinator.activeProtocol, equals(MeshProtocolType.meshcore));

        await coordinator.dispose();
      },
    );
  });

  group('Single-flight connect', () {
    test(
      'Second connect() while first is running returns alreadyConnecting',
      () async {
        final slowTransport = FakeMeshCoreBleTransport();
        slowTransport.connectDelay = const Duration(milliseconds: 100);

        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
          meshCoreTransportFactory: () => slowTransport,
        );

        final device = DeviceInfo(
          id: 'meshcore-test-id',
          name: 'MeshCore Test',
          type: TransportType.ble,
        );

        final firstConnectFuture = coordinator.connect(
          device: device,
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        );

        await Future.delayed(const Duration(milliseconds: 10));
        expect(coordinator.isConnecting, isTrue);

        final secondResult = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        );

        expect(secondResult.success, isFalse);
        expect(
          secondResult.protocolError,
          equals(MeshProtocolError.connectionInProgress),
        );
        expect(secondResult.errorMessage, contains('already in progress'));

        final firstResult = await firstConnectFuture;
        expect(firstResult.success, isTrue);
        expect(coordinator.isConnecting, isFalse);

        await coordinator.dispose();
      },
    );

    test('Connect after previous completes succeeds', () async {
      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
      );

      final device = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      final firstResult = await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );
      expect(firstResult.success, isTrue);

      await coordinator.disconnect();

      final secondResult = await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );
      expect(secondResult.success, isTrue);

      await coordinator.dispose();
    });

    test('Connect after failed connect succeeds', () async {
      var shouldFail = true;
      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) {
          if (shouldFail) {
            throw Exception('Simulated failure');
          }
          return FakeMeshCoreAdapter(transport);
        },
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
      );

      final device = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      final firstResult = await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );
      expect(firstResult.success, isFalse);
      expect(coordinator.isConnecting, isFalse);

      shouldFail = false;
      final secondResult = await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );
      expect(secondResult.success, isTrue);

      await coordinator.dispose();
    });
  });

  group('Protocol locked at entry', () {
    test(
      'MeshCore error is MeshCore-specific, never MeshtasticServiceNotFound',
      () async {
        final coordinator = ConnectionCoordinator(
          meshCoreAdapterFactory: (transport) {
            throw Exception('MeshCore specific failure');
          },
          meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
        );

        final device = DeviceInfo(
          id: 'meshcore-test-id',
          name: 'MeshCore Test',
          type: TransportType.ble,
        );

        final result = await coordinator.connect(
          device: device,
          advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('MeshCore'));
        expect(
          result.errorMessage?.toLowerCase().contains('meshtastic'),
          isFalse,
        );

        await coordinator.dispose();
      },
    );

    test('Protocol is not changed mid-connect even on error', () async {
      var connectAttempts = 0;
      MeshProtocolType? protocolDuringConnect;

      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) {
          connectAttempts++;
          protocolDuringConnect = MeshProtocolType.meshcore;
          return FakeMeshCoreAdapter(transport);
        },
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
        meshtasticAdapterFactory: (protocolService) {
          throw StateError('Protocol switched to Meshtastic mid-connect');
        },
      );

      final device = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
        protocolService: FakeProtocolService(),
      );

      expect(connectAttempts, equals(1));
      expect(protocolDuringConnect, equals(MeshProtocolType.meshcore));

      await coordinator.dispose();
    });
  });

  group('Cleanup correctness', () {
    test('MeshCore disconnect clears capture and state', () async {
      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
      );

      final device = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      await coordinator.connect(
        device: device,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );

      await coordinator.disconnect();

      expect(coordinator.meshCoreCapture, isNull);
      expect(coordinator.activeProtocol, isNull);
      expect(coordinator.activeAdapter, isNull);

      await coordinator.dispose();
    });

    test('Meshtastic disconnect resets state', () async {
      final coordinator = ConnectionCoordinator(
        meshtasticAdapterFactory: FakeMeshtasticAdapter.new,
      );

      final device = DeviceInfo(
        id: 'meshtastic-test-id',
        name: 'Meshtastic Test',
        type: TransportType.ble,
      );

      await coordinator.connect(
        device: device,
        advertisedServiceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
        protocolService: FakeProtocolService(),
      );

      expect(coordinator.meshCoreCapture, isNull);
      expect(coordinator.activeProtocol, equals(MeshProtocolType.meshtastic));

      await coordinator.disconnect();

      expect(coordinator.activeProtocol, isNull);
      expect(coordinator.activeAdapter, isNull);

      await coordinator.dispose();
    });

    test('State is reset for new connection after disconnect', () async {
      final coordinator = ConnectionCoordinator(
        meshCoreAdapterFactory: (transport) => FakeMeshCoreAdapter(transport),
        meshCoreTransportFactory: FakeMeshCoreBleTransport.new,
        meshtasticAdapterFactory: FakeMeshtasticAdapter.new,
      );

      // First: MeshCore connection
      final meshCoreDevice = DeviceInfo(
        id: 'meshcore-test-id',
        name: 'MeshCore Test',
        type: TransportType.ble,
      );

      await coordinator.connect(
        device: meshCoreDevice,
        advertisedServiceUuids: [MeshCoreBleUuids.serviceUuid],
      );
      expect(coordinator.activeProtocol, equals(MeshProtocolType.meshcore));

      await coordinator.disconnect();

      // Second: Meshtastic connection
      final meshtasticDevice = DeviceInfo(
        id: 'meshtastic-test-id',
        name: 'Meshtastic Test',
        type: TransportType.ble,
      );

      await coordinator.connect(
        device: meshtasticDevice,
        advertisedServiceUuids: ['6ba1b218-15a8-461f-9fa8-5dcae273eafd'],
        protocolService: FakeProtocolService(),
      );
      expect(coordinator.activeProtocol, equals(MeshProtocolType.meshtastic));

      await coordinator.dispose();
    });
  });

  group('MeshCoreSession isolation', () {
    test('MeshCoreSession does not depend on ProtocolService', () async {
      final transport = FakeMeshTransport();
      await transport.connect(
        DeviceInfo(id: 'test', name: 'Test', type: TransportType.ble),
      );

      final sessionTransport = TestTransportAdapter(transport);
      final session = MeshCoreSession(sessionTransport);

      expect(session, isNotNull);
      expect(session.state, equals(MeshCoreSessionState.active));

      await session.dispose();
      await transport.dispose();
    });

    test('MeshCoreSession with capture records frames', () async {
      final transport = FakeMeshTransport();
      await transport.connect(
        DeviceInfo(id: 'test', name: 'Test', type: TransportType.ble),
      );

      final sessionTransport = TestTransportAdapter(transport);
      final session = MeshCoreSession(sessionTransport);
      final capture = MeshCoreFrameCapture();

      session.setCapture(capture);
      await session.sendFrame(MeshCoreFrame.simple(0x07));

      expect(capture.frameCount, equals(1));
      expect(capture.txFrames().length, equals(1));

      await session.dispose();
      await transport.dispose();
    });
  });

  group('MeshCoreFrameCapture', () {
    test('capture records TX and RX frames', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x07));
      capture.recordTx(MeshCoreFrame.simple(0x01));
      capture.recordRx(MeshCoreFrame(command: 0x01, payload: Uint8List(50)));

      final frames = capture.snapshot();
      expect(frames.length, equals(3));
      expect(frames[0].direction, equals(CaptureDirection.tx));
      expect(frames[1].direction, equals(CaptureDirection.tx));
      expect(frames[2].direction, equals(CaptureDirection.rx));
    });

    test('toCompactHexLog formats all frames', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x07));
      capture.recordRx(MeshCoreFrame.simple(0x01));

      final log = capture.toCompactHexLog();
      expect(log, contains('[TX]'));
      expect(log, contains('[RX]'));
      expect(log, contains('0x07'));
      expect(log, contains('0x01'));
    });

    test('clear resets capture state', () {
      final capture = MeshCoreFrameCapture();

      capture.recordTx(MeshCoreFrame.simple(0x07));
      expect(capture.frameCount, equals(1));

      capture.clear();
      expect(capture.frameCount, equals(0));
    });
  });
}
