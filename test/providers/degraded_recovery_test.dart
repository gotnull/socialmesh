// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the degraded-readiness recovery listener in
// DeviceConnectionNotifier: when the protocol surfaces `degraded` while
// the transport link is still up (phase-2 handshake exhausted its
// retries), the notifier drives ONE bounded teardown tagged
// phase2_degraded_teardown through the existing config-timeout recovery
// path. The teardown budget resets ONLY on `ready` - a device that
// always passes phase-1 but never phase-2 must not refill its own
// budget by merely reconnecting.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:socialmesh/services/storage/route_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath(String prefix) {
  final dir = Directory.systemTemp.path;
  return p.join(dir, '${prefix}_degraded_${_testPid}_${_testDbSeq++}.db');
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

// Let the readiness stream event reach the notifier's listener.
Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 20));

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

  test('degraded while link up drives one tagged teardown', () async {
    final transport = _DiagnosticsFakeTransport();
    final container = await _buildContainer(transport);
    addTearDown(container.dispose);

    // Build the notifier (wires the readiness listener), then surface
    // degraded from the protocol while the link is up.
    container.read(deviceConnectionProvider.notifier);
    final protocol = container.read(protocolServiceProvider);
    protocol.debugForceReadinessForTesting(OperationalReadiness.degraded);
    await _pump();

    expect(transport.disconnectCalls, 1);
    expect(transport.notedCauses, ['phase2_degraded_teardown']);
  });

  test('degraded while link already down is ignored', () async {
    final transport = _DiagnosticsFakeTransport();
    transport.connected = false;
    final container = await _buildContainer(transport);
    addTearDown(container.dispose);

    container.read(deviceConnectionProvider.notifier);
    final protocol = container.read(protocolServiceProvider);
    protocol.debugForceReadinessForTesting(OperationalReadiness.degraded);
    await _pump();

    expect(transport.disconnectCalls, 0);
    expect(transport.notedCauses, isEmpty);
  });

  test(
    'budget caps at 3 degraded teardowns and resets only on ready',
    () async {
      final transport = _DiagnosticsFakeTransport();
      final container = await _buildContainer(transport);
      addTearDown(container.dispose);

      final notifier = container.read(deviceConnectionProvider.notifier);
      final protocol = container.read(protocolServiceProvider);

      // Three degraded episodes (with the link restored between them) spend
      // the whole budget. Bounce through handshakePhase2 so each degraded
      // is a real transition (readiness emissions are deduped).
      for (var i = 0; i < 3; i++) {
        transport.connected = true;
        protocol.debugForceReadinessForTesting(
          OperationalReadiness.handshakePhase2,
        );
        protocol.debugForceReadinessForTesting(OperationalReadiness.degraded);
        await _pump();
      }
      expect(transport.disconnectCalls, 3);
      expect(notifier.configTimeoutTeardownsForTesting, 3);

      // Fourth episode: budget exhausted - link stays up for manual Retry.
      transport.connected = true;
      protocol.debugForceReadinessForTesting(
        OperationalReadiness.handshakePhase2,
      );
      protocol.debugForceReadinessForTesting(OperationalReadiness.degraded);
      await _pump();
      expect(transport.disconnectCalls, 3);
      expect(transport.connected, isTrue);

      // Only `ready` (phase-2 actually completed) refills the budget.
      protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
      await _pump();
      expect(notifier.configTimeoutTeardownsForTesting, 0);

      protocol.debugForceReadinessForTesting(OperationalReadiness.degraded);
      await _pump();
      expect(transport.disconnectCalls, 4);
      expect(transport.notedCauses, everyElement('phase2_degraded_teardown'));
    },
  );
}
