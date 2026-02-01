import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'Region apply sets applying and disconnect-reconnect completes successfully',
    () async {
      final fakeProtocol = _FakeRegionProtocolService(
        initialRegion: config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
      );

      final container = ProviderContainer(
        overrides: [protocolServiceProvider.overrideWithValue(fakeProtocol)],
      );
      addTearDown(container.dispose);

      // Use setTestState to set connection state directly
      container
          .read(deviceConnectionProvider.notifier)
          .setTestState(
            DeviceConnectionState2(
              state: DevicePairingState.connected,
              device: DeviceInfo(
                id: 'device-alpha',
                name: 'Region Device',
                type: TransportType.ble,
              ),
              connectionSessionId: 1,
              lastConnectedAt: DateTime.now(),
            ),
          );

      final regionFuture = container
          .read(regionConfigProvider.notifier)
          .applyRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);

      // Let the event loop run so applyRegion progresses past setRegion
      // and registers its confirmation listener
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(regionConfigProvider).applyStatus,
        RegionApplyStatus.applying,
      );

      // Simulate disconnect (device reboot) - status should STAY applying, not fail
      container
          .read(deviceConnectionProvider.notifier)
          .setTestState(
            DeviceConnectionState2(
              state: DevicePairingState.disconnected,
              device: DeviceInfo(
                id: 'device-alpha',
                name: 'Region Device',
                type: TransportType.ble,
              ),
              connectionSessionId: 1,
              lastConnectedAt: DateTime.now(),
            ),
          );

      await Future<void>.delayed(Duration.zero);

      // Status should still be applying - disconnect during region apply is expected
      expect(
        container.read(regionConfigProvider).applyStatus,
        RegionApplyStatus.applying,
      );

      // Simulate reconnect after device reboot - this completes the region apply
      container
          .read(deviceConnectionProvider.notifier)
          .setTestState(
            DeviceConnectionState2(
              state: DevicePairingState.connected,
              device: DeviceInfo(
                id: 'device-alpha',
                name: 'Region Device',
                type: TransportType.ble,
              ),
              connectionSessionId: 2, // New session after reconnect
              lastConnectedAt: DateTime.now(),
            ),
          );

      // Pump event loop to process reconnection
      await Future<void>.delayed(Duration.zero);

      // Wait for the region apply to complete
      await regionFuture;

      expect(
        container.read(regionConfigProvider).applyStatus,
        RegionApplyStatus.applied,
      );
      expect(container.read(needsRegionSetupProvider), isFalse);
    },
  );

  test('Region picker stays closed until new session id', () async {
    final fakeProtocol = _FakeRegionProtocolService(
      initialRegion: config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
    );

    final container = ProviderContainer(
      overrides: [protocolServiceProvider.overrideWithValue(fakeProtocol)],
    );
    addTearDown(container.dispose);

    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.connected,
            device: DeviceInfo(
              id: 'device-alpha',
              name: 'Region Device',
              type: TransportType.ble,
            ),
            connectionSessionId: 1,
            lastConnectedAt: DateTime.now(),
          ),
        );

    final regionSub = container.listen(
      deviceRegionProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    fakeProtocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(needsRegionSetupProvider), isTrue);
    regionSub.close();

    final regionFuture = container
        .read(regionConfigProvider.notifier)
        .applyRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);

    // Let the event loop run so applyRegion progresses past setRegion
    // and registers its confirmation listener
    await Future<void>.delayed(Duration.zero);

    // Simulate disconnect (device reboot) - status should stay applying
    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.disconnected,
            device: DeviceInfo(
              id: 'device-alpha',
              name: 'Region Device',
              type: TransportType.ble,
            ),
            connectionSessionId: 1,
            lastConnectedAt: DateTime.now(),
          ),
        );

    await Future<void>.delayed(Duration.zero);

    // Status should still be applying during disconnect
    expect(
      container.read(regionConfigProvider).applyStatus,
      RegionApplyStatus.applying,
    );
    expect(container.read(needsRegionSetupProvider), isFalse);

    // Simulate reconnect with new session - this completes the region apply
    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.connected,
            device: DeviceInfo(
              id: 'device-alpha',
              name: 'Region Device',
              type: TransportType.ble,
            ),
            connectionSessionId: 2,
            lastConnectedAt: DateTime.now().add(const Duration(seconds: 1)),
          ),
        );

    // Pump event loop to process reconnection
    await Future<void>.delayed(Duration.zero);

    await regionFuture;

    // After successful region apply, needsRegionSetup should be false
    expect(container.read(needsRegionSetupProvider), isFalse);
    expect(
      container.read(regionConfigProvider).applyStatus,
      RegionApplyStatus.applied,
    );
  });

  test('Region state resets when connecting to different device', () async {
    final fakeProtocol = _FakeRegionProtocolService(
      initialRegion: config_pbenum.Config_LoRaConfig_RegionCode.UNSET,
    );

    final container = ProviderContainer(
      overrides: [protocolServiceProvider.overrideWithValue(fakeProtocol)],
    );
    addTearDown(container.dispose);

    // Connect to Device A
    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.connected,
            device: DeviceInfo(
              id: 'device-A',
              name: 'Device A',
              type: TransportType.ble,
            ),
            connectionSessionId: 1,
            lastConnectedAt: DateTime.now(),
          ),
        );

    final regionSub = container.listen(
      deviceRegionProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    fakeProtocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await Future<void>.delayed(Duration.zero);

    // Apply region on Device A
    final regionFuture = container
        .read(regionConfigProvider.notifier)
        .applyRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);

    await Future<void>.delayed(Duration.zero);

    // Simulate disconnect (device reboot)
    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.disconnected,
            device: DeviceInfo(
              id: 'device-A',
              name: 'Device A',
              type: TransportType.ble,
            ),
            connectionSessionId: 1,
            lastConnectedAt: DateTime.now(),
          ),
        );

    await Future<void>.delayed(Duration.zero);

    // Simulate reconnect after reboot (same device)
    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.connected,
            device: DeviceInfo(
              id: 'device-A',
              name: 'Device A',
              type: TransportType.ble,
            ),
            connectionSessionId: 2,
            lastConnectedAt: DateTime.now(),
          ),
        );

    await regionFuture;
    expect(
      container.read(regionConfigProvider).applyStatus,
      RegionApplyStatus.applied,
    );
    expect(container.read(regionConfigProvider).targetDeviceId, 'device-A');

    // Now connect to Device B (different device)
    container
        .read(deviceConnectionProvider.notifier)
        .setTestState(
          DeviceConnectionState2(
            state: DevicePairingState.connected,
            device: DeviceInfo(
              id: 'device-B',
              name: 'Device B',
              type: TransportType.ble,
            ),
            connectionSessionId: 3,
            lastConnectedAt: DateTime.now(),
          ),
        );

    await Future<void>.delayed(Duration.zero);

    // State should reset to idle for the new device
    expect(
      container.read(regionConfigProvider).applyStatus,
      RegionApplyStatus.idle,
    );
    expect(container.read(regionConfigProvider).targetDeviceId, 'device-B');

    // Since region is still UNSET and we're idle for Device B, need setup should be true
    expect(container.read(needsRegionSetupProvider), isTrue);

    regionSub.close();
  });
}

class _FakeRegionProtocolService extends ProtocolService {
  config_pbenum.Config_LoRaConfig_RegionCode? _currentRegion;
  final StreamController<config_pbenum.Config_LoRaConfig_RegionCode>
  _regionController = StreamController.broadcast();
  final StreamController<config_pb.Config_LoRaConfig> _loraController =
      StreamController.broadcast();

  _FakeRegionProtocolService({
    config_pbenum.Config_LoRaConfig_RegionCode? initialRegion,
  }) : _currentRegion = initialRegion,
       super(_FakeDeviceTransport(), dedupeStore: _FakeMeshPacketDedupeStore());

  @override
  config_pbenum.Config_LoRaConfig_RegionCode? get currentRegion =>
      _currentRegion;

  @override
  Stream<config_pbenum.Config_LoRaConfig_RegionCode> get regionStream =>
      _regionController.stream;

  @override
  Stream<config_pb.Config_LoRaConfig> get loraConfigStream =>
      _loraController.stream;

  @override
  Future<void> setRegion(
    config_pbenum.Config_LoRaConfig_RegionCode region,
  ) async {
    // Don't immediately set _currentRegion - the real flow waits for device reboot
    // Region will be set when emitRegion() is called manually in tests
  }

  void emitRegion(config_pbenum.Config_LoRaConfig_RegionCode region) {
    _currentRegion = region;
    if (!_regionController.isClosed) {
      _regionController.add(region);
    }
    if (!_loraController.isClosed) {
      _loraController.add(config_pb.Config_LoRaConfig()..region = region);
    }
  }
}

class _FakeMeshPacketDedupeStore extends MeshPacketDedupeStore {
  @override
  Future<void> cleanup({Duration? ttl}) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasSeen(MeshPacketKey key, {Duration? ttl}) async => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> markSeen(MeshPacketKey key, {Duration? ttl}) async {}
}

class _FakeDeviceTransport implements DeviceTransport {
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

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}
