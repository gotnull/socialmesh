// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// A connect/reconnect config dump replays NodeDB NodeInfo frames whose
// deviceMetrics are the radio's cached copy - values from before the
// disconnect. Logging those as fresh samples re-charts the old battery
// level at the current wall clock, drawing a spurious flat step on the
// Battery % chart at every reconnect (issue #285). Only live telemetry
// packets may create device-metrics history rows.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeTransport extends DeviceTransport {
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

  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

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
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

class _TestProtocolService extends ProtocolService {
  _TestProtocolService() : super(_FakeTransport());

  final StreamController<MeshNode> nodeController =
      StreamController<MeshNode>.broadcast();

  @override
  Stream<MeshNode> get nodeStream => nodeController.stream;

  void emit(MeshNode node) => nodeController.add(node);
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('NodeDB-replayed battery is not logged; live telemetry is', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
    await storage.init();

    final protocol = _TestProtocolService();
    final container = ProviderContainer(
      overrides: [
        telemetryStorageProvider.overrideWith((ref) async => storage),
        protocolServiceProvider.overrideWithValue(protocol),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(protocol.nodeController.close);

    // Keep the logger alive and let its build observe the resolved
    // storage future before emitting nodes.
    final subscription = container.listen(telemetryLoggerProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(telemetryStorageProvider.future);
    await _settle();
    expect(container.read(telemetryLoggerProvider), isTrue);

    // Reconnect config dump: NodeDB NodeInfo carries the cached
    // pre-disconnect battery. Must not create a history row.
    protocol.emit(
      MeshNode(nodeNum: 42, batteryLevel: 80, deviceMetricsFromNodeDb: true),
    );
    await _settle();
    expect(await storage.getDeviceMetrics(42), isEmpty);

    // A live device-telemetry packet logs normally, even with the same
    // battery value the replay carried.
    protocol.emit(
      MeshNode(nodeNum: 42, batteryLevel: 80, voltage: 4.1, uptimeSeconds: 60),
    );
    await _settle();
    var rows = await storage.getDeviceMetrics(42);
    expect(rows, hasLength(1));
    expect(rows.single.batteryLevel, 80);

    // Unchanged live values stay fingerprint-deduped.
    protocol.emit(
      MeshNode(nodeNum: 42, batteryLevel: 80, voltage: 4.1, uptimeSeconds: 60),
    );
    await _settle();
    expect(await storage.getDeviceMetrics(42), hasLength(1));

    // A later reconnect replay never writes, even though its field set
    // differs from the last logged fingerprint (NodeInfo carries only
    // battery, so voltage/uptime read as null).
    protocol.emit(
      MeshNode(nodeNum: 42, batteryLevel: 80, deviceMetricsFromNodeDb: true),
    );
    await _settle();
    rows = await storage.getDeviceMetrics(42);
    expect(rows, hasLength(1));
  });

  test('replayed live packets are filed at their rxTime, once', () async {
    SharedPreferences.setMockInitialValues({});

    final storage = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
    await storage.init();
    addTearDown(storage.close);

    final protocol = _TestProtocolService();
    final container = ProviderContainer(
      overrides: [
        telemetryStorageProvider.overrideWith((ref) async => storage),
        protocolServiceProvider.overrideWithValue(protocol),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(protocol.nodeController.close);

    final subscription = container.listen(telemetryLoggerProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(telemetryStorageProvider.future);
    await _settle();
    expect(container.read(telemetryLoggerProvider), isTrue);

    // The radio hands over a packet it heard the day before, which the
    // protocol layer has stamped from the packet's rxTime. The history row
    // must carry that time, not the moment the phone connected.
    // Whole seconds, like a packet rxTime; the row stores milliseconds.
    final heardAt = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now()
              .subtract(const Duration(days: 1, hours: 16))
              .millisecondsSinceEpoch ~/
          1000 *
          1000,
    );
    final replayed = MeshNode(
      nodeNum: 43,
      batteryLevel: 64,
      voltage: 3.84,
      uptimeSeconds: 6199200,
      metricsTimestamp: heardAt,
    );
    protocol.emit(replayed);
    await _settle();
    var rows = await storage.getDeviceMetrics(43);
    expect(rows, hasLength(1));
    expect(rows.single.timestamp, heardAt);
    expect(rows.single.voltage, closeTo(3.84, 0.0001));

    // A live sample after it logs normally at its own time.
    final liveAt = DateTime.now();
    protocol.emit(
      MeshNode(
        nodeNum: 43,
        batteryLevel: 91,
        voltage: 4.07,
        uptimeSeconds: 6343200,
        metricsTimestamp: liveAt,
      ),
    );
    await _settle();
    rows = await storage.getDeviceMetrics(43);
    expect(rows, hasLength(2));

    // The same buffered packet delivered again on a later connect differs
    // from the last logged fingerprint but is the same sample: no new row.
    protocol.emit(replayed);
    await _settle();
    rows = await storage.getDeviceMetrics(43);
    expect(rows, hasLength(2));
  });
}
