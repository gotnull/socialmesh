import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_device_id': 'device-alpha',
      'last_device_type': 'ble',
      'last_device_name': 'Alpha Unit',
    });
  });

  test('saved device invalidates after repeated missing scans', () async {
    final s = SettingsService();
    await s.init();

    final container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(_TestTransport()),
        meshPacketDedupeStoreProvider.overrideWithValue(
          MeshPacketDedupeStore(dbPathOverride: ':memory:'),
        ),
        settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
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

      final container = ProviderContainer(
        overrides: [
          transportProvider.overrideWithValue(_TestTransport()),
          meshPacketDedupeStoreProvider.overrideWithValue(
            MeshPacketDedupeStore(dbPathOverride: ':memory:'),
          ),
          settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
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
  Stream<DeviceInfo> scan({Duration? timeout}) => const Stream.empty();

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
