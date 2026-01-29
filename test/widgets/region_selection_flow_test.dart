import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/device/region_selection_screen.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/help_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Region selection applies region and handles reboot cycle', (
    tester,
  ) async {
    final fakeProtocol = _FakeRegionProtocolService();
    final settings = SettingsService();
    await settings.init();

    final container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(fakeProtocol),
        settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
        // Disable help animations to allow pumpAndSettle to complete
        helpAnimationsEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    container.read(deviceConnectionProvider.notifier).setTestState(
      DeviceConnectionState2(
        state: DevicePairingState.connected,
        device: DeviceInfo(
          id: 'device-alpha',
          name: 'Region Device',
          type: TransportType.ble,
        ),
        lastConnectedAt: DateTime.now(),
        connectionSessionId: 1,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // Provide routes so navigation doesn't crash
          routes: {
            '/main': (context) => const Scaffold(body: Text('Main')),
          },
          home: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegionSelectionScreen(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Navigate to region screen
    await tester.tap(find.text('Open'));
    // Pump enough frames for route transition (can't use pumpAndSettle due to
    // infinite animation in IcoHelpAppBarButton)
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Select a region
    await tester.tap(find.text('United States'));
    await tester.pump();

    // Tap Save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();

    // A confirmation dialog should appear
    expect(find.text('Apply Region'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap Continue in the dialog
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // For non-initial setup, the screen immediately navigates to /main
    // before applying the region
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Should have navigated to main screen
    expect(find.text('Main'), findsOneWidget);

    // Wait for setRegion to be called in the background
    await fakeProtocol.regionSetCompleter.future;

    // Now simulate the disconnect/reconnect cycle that happens during region apply
    // First, simulate disconnect (device reboot)
    container.read(deviceConnectionProvider.notifier).setTestState(
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

    // Pump to process disconnect
    await tester.pump();

    // Simulate reconnect after device reboot
    container.read(deviceConnectionProvider.notifier).setTestState(
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

    // Pump to process reconnect
    await tester.pump();

    // Use runAsync to allow the applyRegion future to complete
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

    // Verify region was applied
    expect(
      container.read(regionConfigProvider).applyStatus,
      RegionApplyStatus.applied,
    );
  });
}

class _FakeRegionProtocolService extends ProtocolService {
  final Completer<void> regionSetCompleter = Completer<void>();
  config_pbenum.Config_LoRaConfig_RegionCode? _currentRegion;
  final StreamController<config_pbenum.Config_LoRaConfig_RegionCode>
      _regionController = StreamController.broadcast();
  final StreamController<config_pb.Config_LoRaConfig> _loraController =
      StreamController.broadcast();

  _FakeRegionProtocolService()
    : super(_FakeDeviceTransport(), dedupeStore: _FakeMeshPacketDedupeStore());

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
    if (!regionSetCompleter.isCompleted) {
      regionSetCompleter.complete();
    }
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
  Future<void> dispose() async {
    await _stateController.close();
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;
}
