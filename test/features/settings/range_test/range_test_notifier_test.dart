// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins RangeTestNotifier end to end: a RANGE_TEST_APP packet heard while
// recording is stored with its signal, the receiver position (the phone's
// fix, or the radio's own position without one) and the distance to the
// sender; nothing is stored outside a recording; Stop ends the session.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/settings/range_test/range_test_database.dart';
import 'package:socialmesh/features/settings/range_test/range_test_models.dart';
import 'package:socialmesh/features/settings/range_test/range_test_providers.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/location/location_service.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

const _sender = 0x51;
const _ownRadio = 0x99;

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

class _FakeLocation extends LocationService {
  _FakeLocation(super.protocol, {required this.allowed, this.fix});

  final bool allowed;
  final Position? fix;

  @override
  Future<bool> checkPermissions() async => allowed;

  int requests = 0;
  Completer<Position?>? _pending;

  // Like the iOS plugin, keeps one pending one-shot request: a new request
  // strands the previous caller, which never completes.
  @override
  Future<Position?> getCurrentPosition() {
    requests++;
    final completer = Completer<Position?>();
    _pending = completer;
    Timer(const Duration(milliseconds: 20), () {
      if (identical(_pending, completer)) completer.complete(fix);
    });
    return completer.future;
  }
}

class _Nodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {
    _sender: MeshNode(
      nodeNum: _sender,
      longName: 'Home base',
      latitude: -33.8700,
      longitude: 151.2100,
    ),
    _ownRadio: MeshNode(
      nodeNum: _ownRadio,
      longName: 'Pocket',
      latitude: -33.8600,
      longitude: 151.2100,
      altitude: 12,
    ),
  };
}

class _NodeNum extends MyNodeNumNotifier {
  @override
  int? build() => _ownRadio;
}

Position _phoneFix() => Position(
  latitude: -33.8650,
  longitude: 151.2100,
  timestamp: DateTime(2026, 11, 24),
  accuracy: 5,
  altitude: 30.4,
  altitudeAccuracy: 3,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

List<int> _frame(int id, String text, {double snr = -6, int rssi = -101}) {
  final data = pb.Data()
    ..portnum = pn.PortNum.RANGE_TEST_APP
    ..payload = utf8.encode(text);
  final packet = pb.MeshPacket()
    ..from = _sender
    ..to = 0xFFFFFFFF
    ..id = id
    ..rxSnr = snr
    ..rxRssi = rssi
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
    Future<void> Function(
      ProviderContainer c,
      ProtocolService p,
      RangeTestDatabase db,
    )
    body, {
    bool phoneAllowed = true,
    Position? phoneFix,
    void Function(_FakeLocation)? onLocation,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('range_test_notifier');
    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(dir.path, 'dedupe.db'),
    );
    await dedupeStore.init();
    final protocol = ProtocolService(
      _SilentTransport(),
      dedupeStore: dedupeStore,
    );
    final db = RangeTestDatabase(testDbPath: inMemoryDatabasePath);
    final location = _FakeLocation(
      protocol,
      allowed: phoneAllowed,
      fix: phoneFix,
    );
    onLocation?.call(location);
    final container = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        rangeTestDatabaseProvider.overrideWithValue(db),
        locationServiceProvider.overrideWithValue(location),
        nodesProvider.overrideWith(_Nodes.new),
        myNodeNumProvider.overrideWith(_NodeNum.new),
      ],
    );
    final keepAlive = container.listen(rangeTestProvider, (_, _) {});
    try {
      await container.read(rangeTestProvider.future);
      await body(container, protocol, db);
    } finally {
      keepAlive.close();
      container.dispose();
      protocol.stop();
      await dedupeStore.dispose();
      await db.close();
      await dir.delete(recursive: true);
    }
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('records a packet with the phone fix and distance', () async {
    await run(phoneFix: _phoneFix(), (c, protocol, db) async {
      await c.read(rangeTestProvider.notifier).start();
      final sessionId = c.read(rangeTestProvider).value!.activeSessionId!;

      await protocol.handleIncomingPacket(_frame(1, 'seq 4'));
      await settle();

      final readings = await db.readings(sessionId);
      expect(readings, hasLength(1));
      final r = readings.single;
      expect(r.sequence, 4);
      expect(r.rxSnr, -6);
      expect(r.rxRssi, -101);
      expect(r.senderName, 'Home base');
      expect(r.rxPositionSource, RangeTestPositionSource.phone);
      expect(r.rxLatitude, -33.8650);
      expect(r.rxAltitude, 30);
      expect(r.senderLatitude, -33.8700);
      // 0.005 degrees of latitude at this latitude is about 554.6 m.
      expect(r.distanceMeters, closeTo(554.6, 0.5));
      expect(c.read(rangeTestProvider).value!.activeSession!.readingCount, 1);
    });
  });

  test('packets arriving together share one phone fix', () async {
    late _FakeLocation location;
    await run(phoneFix: _phoneFix(), onLocation: (l) => location = l, (
      c,
      protocol,
      db,
    ) async {
      await c.read(rangeTestProvider.notifier).start();
      final sessionId = c.read(rangeTestProvider).value!.activeSessionId!;

      await protocol.handleIncomingPacket(_frame(1, 'seq 1'));
      await protocol.handleIncomingPacket(_frame(2, 'seq 2'));
      await protocol.handleIncomingPacket(_frame(3, 'seq 3'));
      await settle();

      expect(location.requests, 1);
      final readings = await db.readings(sessionId);
      expect(readings, hasLength(3));
      expect(
        readings.map((r) => r.rxPositionSource),
        everyElement(RangeTestPositionSource.phone),
      );
    });
  });

  test('uses the radio position when the phone has no fix', () async {
    await run(phoneAllowed: false, (c, protocol, db) async {
      await c.read(rangeTestProvider.notifier).start();
      final sessionId = c.read(rangeTestProvider).value!.activeSessionId!;

      await protocol.handleIncomingPacket(_frame(1, 'seq 1'));
      await settle();

      final r = (await db.readings(sessionId)).single;
      expect(r.rxPositionSource, RangeTestPositionSource.radio);
      expect(r.rxLatitude, -33.8600);
      expect(r.rxAltitude, 12);
      expect(r.distanceMeters, closeTo(1109.2, 0.5));
    });
  });

  test('nothing is stored outside a recording', () async {
    await run((c, protocol, db) async {
      await protocol.handleIncomingPacket(_frame(1, 'seq 1'));
      await settle();
      expect(await db.sessions(), isEmpty);

      await c.read(rangeTestProvider.notifier).start();
      await protocol.handleIncomingPacket(_frame(2, 'seq 2'));
      await settle();
      await c.read(rangeTestProvider.notifier).stop();
      await protocol.handleIncomingPacket(_frame(3, 'seq 3'));
      await settle();

      final state = c.read(rangeTestProvider).value!;
      expect(state.isRecording, isFalse);
      final session = state.sessions.single;
      expect(session.endedAt, isNotNull);
      expect(session.readingCount, 1);
      expect((await db.readings(session.id)).map((r) => r.sequence), [2]);
    });
  });

  test('delete removes a finished session', () async {
    await run((c, protocol, db) async {
      final notifier = c.read(rangeTestProvider.notifier);
      await notifier.start();
      final sessionId = c.read(rangeTestProvider).value!.activeSessionId!;

      await notifier.delete(sessionId);
      expect(c.read(rangeTestProvider).value!.sessions, hasLength(1));

      await notifier.stop();
      await notifier.delete(sessionId);
      expect(c.read(rangeTestProvider).value!.sessions, isEmpty);
      expect(await db.sessions(), isEmpty);
    });
  });
}
