// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the bounded config-timeout teardown in DeviceConnectionNotifier:
// when a restore attempt fails without an auth error while the link is
// still up, the notifier forces a transport disconnect (tagged
// config_timeout_retry) so the auto-reconnect manager re-enters the
// canonical reconnect pipeline - but at most 3 consecutive times, and
// never while a region apply is in flight or the link is already down.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:socialmesh/services/storage/route_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath(String prefix) {
  final dir = Directory.systemTemp.path;
  return p.join(dir, '${prefix}_cfg_teardown_${_testPid}_${_testDbSeq++}.db');
}

class _DiagnosticsFakeTransport extends DeviceTransport
    implements ReceiveDiagnosticsSupport {
  bool connected = true;
  int disconnectCalls = 0;
  final List<String> notedCauses = <String>[];

  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => connected
      ? DeviceConnectionState.connected
      : DeviceConnectionState.disconnected;

  @override
  bool get isConnected => connected;

  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

  @override
  Future<void> connect(DeviceInfo device) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    connected = false;
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
    await _dataController.close();
  }

  // ReceiveDiagnosticsSupport
  @override
  DateTime? get lastNotificationAt => null;

  @override
  int get fromNumNotificationCount => 0;

  @override
  int get rxBytesReadCount => 0;

  @override
  int get rxReadFailureCount => 0;

  @override
  int get refreshNotificationsCount => 0;

  @override
  int get refreshNotificationsFailureCount => 0;

  @override
  BleDisconnectDetail? get lastDisconnectDetail => null;

  @override
  void noteDisconnectCause(String cause) {
    notedCauses.add(cause);
  }
}

Future<ProviderContainer> _buildContainer(
  _DiagnosticsFakeTransport transport,
) async {
  final s = SettingsService();
  await s.init();

  final messageStorage = MessageDatabase(testDbPath: _uniqueTestDbPath('msg'));
  await messageStorage.init();

  final nodeStorage = NodeStorageService();
  await nodeStorage.init();

  final telemetryStorage = TelemetryDatabase(
    testDbPath: _uniqueTestDbPath('telem'),
  );
  await telemetryStorage.init();

  final routeStorage = RouteStorageService(testDbPath: inMemoryDatabasePath);
  await routeStorage.init();

  final container = ProviderContainer(
    overrides: [
      transportProvider.overrideWithValue(transport),
      meshPacketDedupeStoreProvider.overrideWithValue(
        MeshPacketDedupeStore(dbPathOverride: ':memory:'),
      ),
      settingsServiceProvider.overrideWithValue(AsyncValue.data(s)),
      messageStorageProvider.overrideWithValue(AsyncValue.data(messageStorage)),
      nodeStorageProvider.overrideWithValue(AsyncValue.data(nodeStorage)),
      telemetryStorageProvider.overrideWithValue(
        AsyncValue.data(telemetryStorage),
      ),
      routeStorageProvider.overrideWithValue(AsyncValue.data(routeStorage)),
    ],
  );
  return container;
}

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

  test('non-auth restore failure with link up forces one tagged '
      'teardown', () async {
    final transport = _DiagnosticsFakeTransport();
    final container = await _buildContainer(transport);
    addTearDown(container.dispose);

    final notifier = container.read(deviceConnectionProvider.notifier);
    await notifier.debugHandleNonAuthRestoreFailureForTest();

    expect(transport.disconnectCalls, 1);
    expect(transport.notedCauses, ['config_timeout_retry']);
    expect(notifier.configTimeoutTeardownsForTesting, 1);
  });

  test('teardown budget caps at 3 consecutive failures', () async {
    final transport = _DiagnosticsFakeTransport();
    final container = await _buildContainer(transport);
    addTearDown(container.dispose);

    final notifier = container.read(deviceConnectionProvider.notifier);
    for (var i = 0; i < 3; i++) {
      transport.connected = true; // simulate the reconnect between failures
      await notifier.debugHandleNonAuthRestoreFailureForTest();
    }
    expect(transport.disconnectCalls, 3);
    expect(notifier.configTimeoutTeardownsForTesting, 3);

    // Fourth consecutive failure: budget exhausted, link stays up so the
    // user can Retry from the banner.
    transport.connected = true;
    await notifier.debugHandleNonAuthRestoreFailureForTest();
    expect(transport.disconnectCalls, 3);
    expect(transport.connected, isTrue);
    expect(notifier.configTimeoutTeardownsForTesting, 3);
  });

  test('region apply in flight suppresses the teardown', () async {
    final transport = _DiagnosticsFakeTransport();
    final container = await _buildContainer(transport);
    addTearDown(container.dispose);

    container.read(regionApplyInFlightProvider.notifier).setActive(true);
    final notifier = container.read(deviceConnectionProvider.notifier);
    await notifier.debugHandleNonAuthRestoreFailureForTest();

    expect(transport.disconnectCalls, 0);
    expect(transport.notedCauses, isEmpty);
    expect(notifier.configTimeoutTeardownsForTesting, 0);
  });

  test('link already down means nothing to tear down', () async {
    final transport = _DiagnosticsFakeTransport();
    transport.connected = false;
    final container = await _buildContainer(transport);
    addTearDown(container.dispose);

    final notifier = container.read(deviceConnectionProvider.notifier);
    await notifier.debugHandleNonAuthRestoreFailureForTest();

    expect(transport.disconnectCalls, 0);
    expect(notifier.configTimeoutTeardownsForTesting, 0);
  });
}
