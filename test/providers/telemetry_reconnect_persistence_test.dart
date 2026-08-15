// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression test for: telemetry history empty after closing and reopening
// the app.
//
// Root cause: clearDeviceDataBeforeConnect[Ref] ran telemetryStorage
// .clearAllData() (and routeStorage.clearAllRoutes()) on EVERY connection,
// unconditionally — not gated behind clearNodeData the way persistent node
// storage already was. Reopening the app triggers an auto-reconnect to the
// same radio, so all collected device metrics, position logs, and sensor
// data were wiped on restart even though nothing was switched.
//
// Fix: the connect path no longer deletes persisted stores at all. Telemetry
// survives every reconnect, and cross-radio isolation comes from storage
// scoping instead — each radio's telemetry lives in its own scope, so a
// switch swaps the dataset rather than erasing the previous radio's history.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/nodes/node_identity_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/route_storage_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';

// ---------------------------------------------------------------------------
// Minimal fake transport for provider wiring
// ---------------------------------------------------------------------------
class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  bool get isConnected => false;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late TelemetryDatabase telemetry;
  late RouteStorageService routes;
  late NodeStorageService nodeStorage;
  late NodeIdentityStore identityStore;
  late ProtocolService protocol;
  late ProviderContainer container;
  late Ref capturedRef;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Distinct on-disk temp files per store: sqflite caches databases by
    // path, so two stores both opening ':memory:' would collide on a single
    // handle and the second store's onCreate would never run.
    tempDir = Directory.systemTemp.createTempSync('telemetry_reconnect_test');
    telemetry = TelemetryDatabase(
      testDbPath: p.join(tempDir.path, 'telemetry.db'),
    );
    await telemetry.init();
    routes = RouteStorageService(testDbPath: p.join(tempDir.path, 'routes.db'));
    await routes.init();
    nodeStorage = NodeStorageService();
    await nodeStorage.init();
    identityStore = NodeIdentityStore();
    await identityStore.init();
    protocol = ProtocolService(_FakeTransport());

    // A throwaway provider whose build captures a usable Ref so the test can
    // invoke clearDeviceDataBeforeConnectRef (which takes a Ref) directly.
    final capture = Provider<void>((ref) {
      capturedRef = ref;
    });

    container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        telemetryStorageProvider.overrideWith((ref) async => telemetry),
        routeStorageProvider.overrideWith((ref) async => routes),
        nodeStorageProvider.overrideWith((ref) async => nodeStorage),
        deviceFavoritesProvider.overrideWith((ref) async {
          final service = DeviceFavoritesService();
          await service.init();
          return service;
        }),
        nodeIdentityStoreProvider.overrideWith((ref) async => identityStore),
      ],
    );

    await container.read(telemetryStorageProvider.future);
    await container.read(routeStorageProvider.future);
    await container.read(nodeStorageProvider.future);
    await container.read(deviceFavoritesProvider.future);
    await container.read(nodeIdentityStoreProvider.future);
    container.read(capture);
  });

  tearDown(() async {
    container.dispose();
    await telemetry.close();
    await routes.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // Seed one entry per user-visible telemetry category: device data,
  // sensor data, and location.
  Future<void> seedTelemetry() async {
    await telemetry.addDeviceMetrics(
      DeviceMetricsLog(nodeNum: 0x1234, batteryLevel: 88, voltage: 4.0),
    );
    await telemetry.addEnvironmentMetrics(
      EnvironmentMetricsLog(nodeNum: 0x1234, temperature: 21.5, humidity: 55),
    );
    await telemetry.addPositionLog(
      PositionLog(nodeNum: 0x1234, latitude: 1.0, longitude: 2.0),
    );
  }

  group('Telemetry reconnect persistence (regression)', () {
    test(
      'same-device reconnect (clearNodeData: false) preserves telemetry history',
      () async {
        await seedTelemetry();
        expect(await telemetry.getAllDeviceMetrics(), isNotEmpty);

        // Reopening the app reconnects to the same radio — same device id,
        // clearNodeData defaults to false.
        await clearDeviceDataBeforeConnectRef(
          capturedRef,
          clearNodeData: false,
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          newDeviceId: 'AA:BB:CC:DD:EE:01',
        );

        expect(
          await telemetry.getAllDeviceMetrics(),
          isNotEmpty,
          reason: 'device metrics must survive a same-device reconnect',
        );
        expect(
          await telemetry.getAllEnvironmentMetrics(),
          isNotEmpty,
          reason: 'sensor data must survive a same-device reconnect',
        );
        expect(
          await telemetry.getAllPositionLogs(),
          isNotEmpty,
          reason: 'location history must survive a same-device reconnect',
        );
      },
    );

    test(
      'a device switch does not delete the previous radio\'s telemetry',
      () async {
        // Isolation is a storage-scope concern now: the previous radio's
        // history stays in its own scope so returning to that radio still
        // shows it. Deleting here would make the switch lossy.
        await seedTelemetry();

        await clearDeviceDataBeforeConnectRef(
          capturedRef,
          clearNodeData: false,
          previousDeviceId: 'AA:BB:CC:DD:EE:01',
          newDeviceId: 'AA:BB:CC:DD:EE:99',
        );

        expect(
          await telemetry.getAllDeviceMetrics(),
          isNotEmpty,
          reason: "a switch must not destroy the previous radio's telemetry",
        );
      },
    );

    test('an explicit forget does not delete telemetry either', () async {
      await seedTelemetry();

      await clearDeviceDataBeforeConnectRef(
        capturedRef,
        clearNodeData: true,
        previousDeviceId: 'AA:BB:CC:DD:EE:01',
        newDeviceId: 'AA:BB:CC:DD:EE:01',
      );

      expect(
        await telemetry.getAllDeviceMetrics(),
        isNotEmpty,
        reason:
            'forgetting a pairing is not a request to erase its history; '
            'deleting a radio profile is an explicit user action',
      );
    });

    test('telemetry collected on one radio is invisible on another', () async {
      final scopeRoot = Directory.systemTemp.createTempSync('telemetry_scope');
      addTearDown(() async {
        RadioScope.instance.debugSetRoot(null);
        try {
          scopeRoot.deleteSync(recursive: true);
        } on FileSystemException {
          // Already gone.
        }
      });
      RadioScope.instance.debugSetRoot(scopeRoot);
      await RadioScope.instance.init();

      await RadioScope.instance.useNodeNum(0x1234abcd);
      final radioA = TelemetryDatabase();
      await radioA.init();
      await radioA.addDeviceMetrics(
        DeviceMetricsLog(nodeNum: 0x1234, batteryLevel: 88, voltage: 4.0),
      );
      expect(await radioA.getAllDeviceMetrics(), isNotEmpty);
      await radioA.close();

      await RadioScope.instance.useNodeNum(0x9999beef);
      final radioB = TelemetryDatabase();
      await radioB.init();
      expect(await radioB.getAllDeviceMetrics(), isEmpty);
      await radioB.close();

      await RadioScope.instance.useNodeNum(0x1234abcd);
      final radioAAgain = TelemetryDatabase();
      await radioAAgain.init();
      expect(await radioAAgain.getAllDeviceMetrics(), isNotEmpty);
      await radioAAgain.close();
    });
  });
}
