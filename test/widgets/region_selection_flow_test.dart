import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/device/region_selection_screen.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Continue shows spinner and disables button while applying region',
    (tester) async {
      final fakeProtocol = _FakeRegionProtocolService();
      final settings = SettingsService();
      await settings.init();

      final container = ProviderContainer(
        overrides: [
          protocolServiceProvider.overrideWithValue(fakeProtocol),
          settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
        ],
      );
      addTearDown(container.dispose);

      container.read(deviceConnectionProvider.notifier).state =
          DeviceConnectionState2(
        state: DevicePairingState.connected,
        device: DeviceInfo(
          id: 'device-alpha',
          name: 'Region Device',
          type: TransportType.ble,
        ),
        lastConnectedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RegionSelectionScreen(isInitialSetup: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('United States'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final continueButton = find.byKey(regionSelectionApplyButtonKey);
      expect(continueButton, findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(continueButton).onPressed,
        isNotNull,
      );

      await tester.tap(continueButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(continueButton).onPressed,
        isNull,
      );

      await fakeProtocol.regionSetCompleter.future;
      container.read(deviceConnectionProvider.notifier).state =
          DeviceConnectionState2(
        state: DevicePairingState.connected,
        device: DeviceInfo(
          id: 'device-alpha',
          name: 'Region Device',
          type: TransportType.ble,
        ),
        lastConnectedAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      await tester.pump();
    },
  );

  testWidgets(
    'Region screen pops after reconnection completes',
    (tester) async {
      final fakeProtocol = _FakeRegionProtocolService();
      final settings = SettingsService();
      await settings.init();

      final container = ProviderContainer(
        overrides: [
          protocolServiceProvider.overrideWithValue(fakeProtocol),
          settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
        ],
      );
      addTearDown(container.dispose);

      container.read(deviceConnectionProvider.notifier).state =
          DeviceConnectionState2(
        state: DevicePairingState.connected,
        device: DeviceInfo(
          id: 'device-alpha',
          name: 'Region Device',
          type: TransportType.ble,
        ),
        lastConnectedAt: DateTime.now(),
      );

      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [observer],
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
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('United States'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pump();

      await fakeProtocol.regionSetCompleter.future;
      container.read(deviceConnectionProvider.notifier).state =
          DeviceConnectionState2(
        state: DevicePairingState.connected,
        device: DeviceInfo(
          id: 'device-alpha',
          name: 'Region Device',
          type: TransportType.ble,
        ),
        lastConnectedAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(observer.didPopRoute, isTrue);
    },
  );
}

class _TestNavigatorObserver extends NavigatorObserver {
  bool didPopRoute = false;

  @override
  void didPop(Route route, Route? previousRoute) {
    didPopRoute = true;
    super.didPop(route, previousRoute);
  }
}

class _FakeRegionProtocolService extends ProtocolService {
  final Completer<void> regionSetCompleter = Completer<void>();
  config_pbenum.Config_LoRaConfig_RegionCode? _currentRegion;

  _FakeRegionProtocolService()
      : super(
          _FakeDeviceTransport(),
          dedupeStore: _FakeMeshPacketDedupeStore(),
        );

  @override
  config_pbenum.Config_LoRaConfig_RegionCode? get currentRegion =>
      _currentRegion;

  @override
  Future<void> setRegion(
    config_pbenum.Config_LoRaConfig_RegionCode region,
  ) async {
    _currentRegion = region;
    if (!regionSetCompleter.isCompleted) {
      regionSetCompleter.complete();
    }
    await Future<void>.value();
  }
}

class _FakeMeshPacketDedupeStore extends MeshPacketDedupeStore {
  @override
  Future<void> cleanup({Duration? ttl}) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasSeen(
    MeshPacketKey key, {
    Duration? ttl,
  }) async =>
      false;

  @override
  Future<void> init() async {}

  @override
  Future<void> markSeen(
    MeshPacketKey key, {
    Duration? ttl,
  }) async {}
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
