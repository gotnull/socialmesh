// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the WaypointsNotifier reconciliation rules (mirroring the official
// Meshtastic clients):
//   - unknown id -> insert
//   - known id, unlocked -> update
//   - known id, locked -> reject unless the update comes from the lock owner
//   - expire == 1 -> delete locally

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/waypoints/providers/waypoint_providers.dart';
import 'package:socialmesh/features/waypoints/services/waypoint_database.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _SilentTransport extends DeviceTransport {
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
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();
  @override
  Stream<List<int>> get dataStream => const Stream<List<int>>.empty();
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();
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
  Future<void> dispose() async {}
}

List<int> _waypointFrame({
  required int from,
  required int id,
  String name = 'wp',
  int lockedTo = 0,
  int expire = 0,
}) {
  final waypoint = pb.Waypoint()
    ..id = id
    ..latitudeI = (1.0 * 1e7).round()
    ..longitudeI = (2.0 * 1e7).round()
    ..name = name;
  if (lockedTo != 0) waypoint.lockedTo = lockedTo;
  if (expire != 0) waypoint.expire = expire;
  final data = pb.Data()
    ..portnum = pn.PortNum.WAYPOINT_APP
    ..payload = waypoint.writeToBuffer();
  final packet = pb.MeshPacket()
    ..from = from
    ..to = 0xFFFFFFFF
    ..id = id
    ..decoded = data;
  return (pb.FromRadio()..packet = packet).writeToBuffer();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> run(
    Future<void> Function(ProviderContainer c, ProtocolService p) body,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('wp_notifier');
    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(tempDir.path, 'dedupe.db'),
    );
    await dedupeStore.init();
    final protocol = ProtocolService(
      _SilentTransport(),
      dedupeStore: dedupeStore,
    );
    final db = WaypointDatabase(testDbPath: inMemoryDatabasePath);
    final container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        waypointDatabaseProvider.overrideWithValue(db),
      ],
    );
    try {
      await container.read(waypointsNotifierProvider.future);
      await body(container, protocol);
    } finally {
      container.dispose();
      protocol.stop();
      await dedupeStore.dispose();
      await db.close();
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test('unknown id inserts a new waypoint', () async {
    await run((c, protocol) async {
      await protocol.handleIncomingPacket(_waypointFrame(from: 0x10, id: 1));
      await settle();
      final list = c.read(meshWaypointsProvider);
      expect(list.map((w) => w.id), [1]);
      expect(list.single.name, 'wp');
    });
  });

  test('known unlocked id updates in place', () async {
    await run((c, protocol) async {
      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x10, id: 1, name: 'first'),
      );
      await settle();
      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x20, id: 1, name: 'second'),
      );
      await settle();
      final list = c.read(meshWaypointsProvider);
      expect(list, hasLength(1));
      expect(list.single.name, 'second');
    });
  });

  test('locked waypoint rejects updates from non-owner', () async {
    await run((c, protocol) async {
      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x50, id: 1, name: 'owned', lockedTo: 0x50),
      );
      await settle();
      // Non-owner tries to overwrite.
      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x99, id: 1, name: 'hijack', lockedTo: 0x50),
      );
      await settle();
      final list = c.read(meshWaypointsProvider);
      expect(list.single.name, 'owned');
    });
  });

  test('locked waypoint accepts updates from the lock owner', () async {
    await run((c, protocol) async {
      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x50, id: 1, name: 'owned', lockedTo: 0x50),
      );
      await settle();
      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x50, id: 1, name: 'renamed', lockedTo: 0x50),
      );
      await settle();
      final list = c.read(meshWaypointsProvider);
      expect(list.single.name, 'renamed');
    });
  });

  test('expire == 1 deletes the waypoint locally', () async {
    await run((c, protocol) async {
      await protocol.handleIncomingPacket(_waypointFrame(from: 0x10, id: 1));
      await settle();
      expect(c.read(meshWaypointsProvider), hasLength(1));

      await protocol.handleIncomingPacket(
        _waypointFrame(from: 0x10, id: 1, expire: 1),
      );
      await settle();
      expect(c.read(meshWaypointsProvider), isEmpty);
    });
  });
}
