import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/storage/telemetry_storage_service.dart';
import 'package:socialmesh/services/storage/route_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_device_id': 'device-alpha',
      'last_device_type': 'ble',
      'last_device_name': 'Alpha Unit',
    });
  });

  // Protocol-aware markAsPaired tests
  _protocolAwareMarkAsPairedTests();

  test('saved device invalidates after repeated missing scans', () async {
    final s = SettingsService();
    await s.init();

    final prefs = await SharedPreferences.getInstance();

    // Initialize storage services with in-memory databases
    final messageStorage = MessageStorageService();
    await messageStorage.init();

    final nodeStorage = NodeStorageService();
    await nodeStorage.init();

    final telemetryStorage = TelemetryStorageService(prefs);

    final routeStorage = RouteStorageService(testDbPath: inMemoryDatabasePath);
    await routeStorage.init();

    final container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(_TestTransport()),
        meshPacketDedupeStoreProvider.overrideWithValue(
          MeshPacketDedupeStore(dbPathOverride: ':memory:'),
        ),
        settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
        messageStorageProvider.overrideWithValue(
          AsyncValue.data(messageStorage),
        ),
        nodeStorageProvider.overrideWithValue(AsyncValue.data(nodeStorage)),
        telemetryStorageProvider.overrideWithValue(
          AsyncValue.data(telemetryStorage),
        ),
        routeStorageProvider.overrideWithValue(AsyncValue.data(routeStorage)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(deviceConnectionProvider.notifier);
    final deviceInfo = DeviceInfo(
      id: 'device-alpha',
      name: 'Alpha Unit',
      type: TransportType.ble,
    );

    notifier.state = DeviceConnectionState2(
      state: DevicePairingState.disconnected,
      device: deviceInfo,
    );

    final settings = await container.read(settingsServiceProvider.future);
    expect(settings.lastDeviceId, 'device-alpha');

    expect(await notifier.reportMissingSavedDevice(), isFalse);
    expect(await notifier.reportMissingSavedDevice(), isFalse);
    expect(await notifier.reportMissingSavedDevice(), isTrue);

    expect(notifier.state.state, DevicePairingState.pairedDeviceInvalidated);
    expect(settings.lastDeviceId, isNull);
    expect(settings.lastDeviceName, isNull);
    expect(settings.lastDeviceType, isNull);
  });

  test(
    'peer reset invalidation clears saved device and blocks reconnect',
    () async {
      final s = SettingsService();
      await s.init();

      final prefs = await SharedPreferences.getInstance();

      // Initialize storage services with in-memory databases
      final messageStorage = MessageStorageService();
      await messageStorage.init();

      final nodeStorage = NodeStorageService();
      await nodeStorage.init();

      final telemetryStorage = TelemetryStorageService(prefs);

      final routeStorage = RouteStorageService(
        testDbPath: inMemoryDatabasePath,
      );
      await routeStorage.init();

      final container = ProviderContainer(
        overrides: [
          transportProvider.overrideWithValue(_TestTransport()),
          meshPacketDedupeStoreProvider.overrideWithValue(
            MeshPacketDedupeStore(dbPathOverride: ':memory:'),
          ),
          settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
          messageStorageProvider.overrideWithValue(
            AsyncValue.data(messageStorage),
          ),
          nodeStorageProvider.overrideWithValue(AsyncValue.data(nodeStorage)),
          telemetryStorageProvider.overrideWithValue(
            AsyncValue.data(telemetryStorage),
          ),
          routeStorageProvider.overrideWithValue(AsyncValue.data(routeStorage)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deviceConnectionProvider.notifier);
      final deviceInfo = DeviceInfo(
        id: 'device-alpha',
        name: 'Alpha Unit',
        type: TransportType.ble,
      );

      notifier.state = DeviceConnectionState2(
        state: DevicePairingState.disconnected,
        device: deviceInfo,
      );

      final settings = await container.read(settingsServiceProvider.future);
      expect(settings.lastDeviceId, 'device-alpha');

      await notifier.handlePairingInvalidation(
        PairingInvalidationReason.peerReset,
        appleCode: 14,
      );

      expect(notifier.state.state, DevicePairingState.pairedDeviceInvalidated);
      expect(settings.lastDeviceId, isNull);
      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.failed,
      );
      expect(
        container.read(deviceConnectionProvider).isTerminalInvalidated,
        isTrue,
      );
    },
  );

  test('pairing invalidation detection matches apple peer reset errors', () {
    expect(
      isPairingInvalidationError(
        FlutterBluePlusException(
          ErrorPlatform.apple,
          'connect',
          14,
          'Peer removed pairing information',
        ),
      ),
      isTrue,
    );

    expect(
      pairingInvalidationAppleCode(
        FlutterBluePlusException(
          ErrorPlatform.apple,
          'connect',
          14,
          'Peer removed pairing information',
        ),
      ),
      14,
    );
  });
}

class _TestTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  String? get bleManufacturerName => null;

  @override
  String? get bleModelNumber => null;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {
    _state = DeviceConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  /// Simulate setting state for testing disconnect trigger
  void simulateDisconnect() {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

/// Tests for protocol-aware markAsPaired behavior
void _protocolAwareMarkAsPairedTests() {
  group('markAsPaired protocol awareness', () {
    test(
      'MeshCore markAsPaired does not subscribe to Meshtastic transport',
      () async {
        final s = SettingsService();
        await s.init();

        final prefs = await SharedPreferences.getInstance();
        final testTransport = _TestTransport();

        final messageStorage = MessageStorageService();
        await messageStorage.init();

        final nodeStorage = NodeStorageService();
        await nodeStorage.init();

        final telemetryStorage = TelemetryStorageService(prefs);

        final routeStorage = RouteStorageService(
          testDbPath: inMemoryDatabasePath,
        );
        await routeStorage.init();

        final container = ProviderContainer(
          overrides: [
            transportProvider.overrideWithValue(testTransport),
            meshPacketDedupeStoreProvider.overrideWithValue(
              MeshPacketDedupeStore(dbPathOverride: ':memory:'),
            ),
            settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
            messageStorageProvider.overrideWithValue(
              AsyncValue.data(messageStorage),
            ),
            nodeStorageProvider.overrideWithValue(AsyncValue.data(nodeStorage)),
            telemetryStorageProvider.overrideWithValue(
              AsyncValue.data(telemetryStorage),
            ),
            routeStorageProvider.overrideWithValue(
              AsyncValue.data(routeStorage),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(deviceConnectionProvider.notifier);
        final deviceInfo = DeviceInfo(
          id: 'meshcore-device-1',
          name: 'MeshCore Device',
          type: TransportType.ble,
        );

        // Mark as paired with isMeshCore=true
        // This should NOT set up a listener on the Meshtastic transport
        notifier.markAsPaired(deviceInfo, 0x12345678, isMeshCore: true);

        // Verify state is connected
        expect(notifier.state.state, DevicePairingState.connected);
        expect(notifier.state.device?.id, 'meshcore-device-1');

        // Now simulate the Meshtastic transport emitting disconnected
        // For MeshCore, this should NOT trigger a state change
        testTransport.simulateDisconnect();

        // Give time for any async event handlers to run
        await Future.delayed(const Duration(milliseconds: 50));

        // State should still be connected since MeshCore doesn't listen to Meshtastic transport
        expect(
          notifier.state.state,
          DevicePairingState.connected,
          reason:
              'MeshCore connection should not react to Meshtastic transport events',
        );
      },
    );

    test(
      'Meshtastic markAsPaired subscribes to transport and reacts to disconnect',
      () async {
        final s = SettingsService();
        await s.init();

        final prefs = await SharedPreferences.getInstance();
        final testTransport = _TestTransport();

        final messageStorage = MessageStorageService();
        await messageStorage.init();

        final nodeStorage = NodeStorageService();
        await nodeStorage.init();

        final telemetryStorage = TelemetryStorageService(prefs);

        final routeStorage = RouteStorageService(
          testDbPath: inMemoryDatabasePath,
        );
        await routeStorage.init();

        final container = ProviderContainer(
          overrides: [
            transportProvider.overrideWithValue(testTransport),
            meshPacketDedupeStoreProvider.overrideWithValue(
              MeshPacketDedupeStore(dbPathOverride: ':memory:'),
            ),
            settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
            messageStorageProvider.overrideWithValue(
              AsyncValue.data(messageStorage),
            ),
            nodeStorageProvider.overrideWithValue(AsyncValue.data(nodeStorage)),
            telemetryStorageProvider.overrideWithValue(
              AsyncValue.data(telemetryStorage),
            ),
            routeStorageProvider.overrideWithValue(
              AsyncValue.data(routeStorage),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(deviceConnectionProvider.notifier);
        final deviceInfo = DeviceInfo(
          id: 'meshtastic-device-1',
          name: 'Meshtastic Device',
          type: TransportType.ble,
        );

        // First connect the test transport (so it's in connected state)
        await testTransport.connect(deviceInfo);

        // Mark as paired WITHOUT isMeshCore (defaults to Meshtastic behavior)
        notifier.markAsPaired(deviceInfo, 0x87654321);

        // Verify state is connected
        expect(notifier.state.state, DevicePairingState.connected);
        expect(notifier.state.device?.id, 'meshtastic-device-1');

        // Now simulate the transport disconnecting
        testTransport.simulateDisconnect();

        // Give time for the stream listener to process
        await Future.delayed(const Duration(milliseconds: 50));

        // State should change to disconnected for Meshtastic
        expect(
          notifier.state.state,
          DevicePairingState.disconnected,
          reason: 'Meshtastic connection should react to transport disconnect',
        );
      },
    );
  });

  group('initialize protocol awareness', () {
    test(
      'MeshCore device on initialize skips Meshtastic transport listener',
      () async {
        // Set up with MeshCore as last protocol
        SharedPreferences.setMockInitialValues({
          'last_device_id': 'meshcore-device-test',
          'last_device_type': 'ble',
          'last_device_name': 'MeshCore Device',
          'last_device_protocol': 'meshcore',
        });

        final s = SettingsService();
        await s.init();

        final prefs = await SharedPreferences.getInstance();
        final testTransport = _TestTransport();

        final messageStorage = MessageStorageService();
        await messageStorage.init();

        final nodeStorage = NodeStorageService();
        await nodeStorage.init();

        final telemetryStorage = TelemetryStorageService(prefs);

        final routeStorage = RouteStorageService(
          testDbPath: inMemoryDatabasePath,
        );
        await routeStorage.init();

        final container = ProviderContainer(
          overrides: [
            transportProvider.overrideWithValue(testTransport),
            meshPacketDedupeStoreProvider.overrideWithValue(
              MeshPacketDedupeStore(dbPathOverride: ':memory:'),
            ),
            settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
            messageStorageProvider.overrideWithValue(
              AsyncValue.data(messageStorage),
            ),
            nodeStorageProvider.overrideWithValue(AsyncValue.data(nodeStorage)),
            telemetryStorageProvider.overrideWithValue(
              AsyncValue.data(telemetryStorage),
            ),
            routeStorageProvider.overrideWithValue(
              AsyncValue.data(routeStorage),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(deviceConnectionProvider.notifier);

        // Initialize - should detect MeshCore and skip transport listener
        await notifier.initialize();

        // State should be disconnected (previous device found)
        expect(notifier.state.state, DevicePairingState.disconnected);

        // Now simulate the Meshtastic transport emitting events
        // For MeshCore, these should NOT trigger any state changes
        testTransport.simulateDisconnect();

        // Give time for any async event handlers
        await Future.delayed(const Duration(milliseconds: 50));

        // State should still be disconnected (not changed by transport event)
        expect(
          notifier.state.state,
          DevicePairingState.disconnected,
          reason:
              'MeshCore device should not react to Meshtastic transport on init',
        );
      },
    );
  });
}
