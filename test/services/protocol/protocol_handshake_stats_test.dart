// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/channel.pb.dart' as channel_pb;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

const int _nonceInitialConfig = 69420;
const int _nonceQueueDrain = 69421;

// A BLE-shaped transport whose read window is scripted per phase, so the
// HANDSHAKE_STATS line can be checked for the exact reads-to-frames ratio
// it reports. Store builds carry no flag-gated BLE lines, so this session
// line is the only read-level evidence an exported app log can hold.
class _StatsFakeTransport extends DeviceTransport
    implements ReceiveDiagnosticsSupport {
  bool connected = true;
  int notificationCount = 0;
  TransportReadStats window = TransportReadStats.empty;
  final List<TransportReadStats> takenWindows = <TransportReadStats>[];

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
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {
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

  @override
  DateTime? get lastNotificationAt => null;

  @override
  int get fromNumNotificationCount => notificationCount;

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
  void noteDisconnectCause(String cause) {}

  @override
  TransportReadStats takeReadStats() {
    final taken = window;
    takenWindows.add(taken);
    window = TransportReadStats.empty;
    return taken;
  }
}

List<int> _configCompleteFrame(int nonce) =>
    (pb.FromRadio()..configCompleteId = nonce).writeToBuffer();

List<int> _channelFrame(int index) {
  final channel = channel_pb.Channel()
    ..index = index
    ..role = channel_pb.Channel_Role.SECONDARY;
  return (pb.FromRadio()..channel = channel).writeToBuffer();
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_stats');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _freshProtocol(
  String dir,
  _StatsFakeTransport transport,
) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(
      dir,
      'dedupe_store_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  );
  await dedupeStore.init();
  return ProtocolService(transport, dedupeStore: dedupeStore);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> sessionLines;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    AppLogging.reset();
    sessionLines = [];
    AppLogging.setAppLogSink((level, source, message) {
      if (source == 'session') sessionLines.add(message);
    });
  });

  tearDown(AppLogging.reset);

  test('each handshake phase logs frames against the read window', () async {
    await _withTempDirectory((dir) async {
      final transport = _StatsFakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        // Reads before phase 1 belong to the wake-up, not the handshake.
        transport.window = TransportReadStats.empty.recordRead(
          byteCount: 4,
          latencyMs: 900,
          viaPoll: true,
        );
        await protocol.sendInitialConfigRequestForTest();
        expect(
          transport.takenWindows,
          hasLength(1),
          reason: 'phase-1 start discards the pre-handshake read window',
        );

        // Phase 1: two channel frames and the completion, delivered by
        // three notification reads plus one empty poll read.
        transport.notificationCount = 2;
        transport.window = TransportReadStats.empty
            .recordRead(byteCount: 20, latencyMs: 30, viaPoll: false)
            .recordRead(byteCount: 20, latencyMs: 50, viaPoll: false)
            .recordRead(byteCount: 0, latencyMs: 400, viaPoll: true)
            .recordRead(byteCount: 6, latencyMs: 40, viaPoll: false);
        await protocol.handleIncomingPacket(_channelFrame(1));
        await protocol.handleIncomingPacket(_channelFrame(2));
        await protocol.handleIncomingPacket(
          _configCompleteFrame(_nonceInitialConfig),
        );

        final phase1 = sessionLines.where(
          (l) => l.startsWith('HANDSHAKE_STATS: phase=1 '),
        );
        expect(phase1, hasLength(1));
        final line1 = phase1.single;
        expect(line1, contains('transport=ble'));
        expect(line1, contains(' frames=3 '));
        expect(line1, contains(' reads=4 dataReads=3 emptyReads=1 '));
        expect(line1, contains(' bytes=46 notifyReads=3 pollReads=1 '));
        expect(line1, contains(' readLatencyMs=min:30 avg:130 max:400 '));
        expect(line1, contains('notifications=2'));
        expect(line1, matches(RegExp(r' elapsed=\d+ms ')));

        // Phase 2 starts a fresh window: the phase-1 reads are not
        // counted twice and the notification baseline moves.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        transport.notificationCount = 3;
        transport.window = TransportReadStats.empty.recordRead(
          byteCount: 6,
          latencyMs: 25,
          viaPoll: false,
        );
        await protocol.handleIncomingPacket(
          _configCompleteFrame(_nonceQueueDrain),
        );

        final phase2 = sessionLines.where(
          (l) => l.startsWith('HANDSHAKE_STATS: phase=2 '),
        );
        expect(phase2, hasLength(1));
        final line2 = phase2.single;
        expect(line2, contains(' frames=1 '));
        expect(line2, contains(' reads=1 dataReads=1 emptyReads=0 '));
        expect(line2, contains(' readLatencyMs=min:25 avg:25 max:25 '));
        expect(line2, contains('notifications=1'));
      } finally {
        protocol.stop();
      }
    });
  });
}
