// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Wire coverage for the on-demand telemetry pull (`requestTelemetry`).
///
/// Since firmware 2.7.13 nodes no longer broadcast telemetry by default, so
/// the app pulls it explicitly by sending an empty `Telemetry` with the
/// requested variant set and `wantResponse = true`. The firmware's matching
/// telemetry module keys its reply off which variant is present, so this test
/// pins: portnum `TELEMETRY_APP`, `wantResponse == true`, `to == nodeNum`, and
/// exactly the requested variant present (and only that one) in the payload.

class _RecordingFakeTransport extends DeviceTransport {
  bool connected = true;
  final List<List<int>> sent = <List<int>>[];
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;

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
  Future<void> send(List<int> data) async {
    sent.add(List<int>.of(data));
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
  }
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('request_telemetry');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _freshProtocol(
  String dir,
  _RecordingFakeTransport transport,
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

/// Decode the single telemetry-request packet the transport captured.
/// Returns the decoded [pb.MeshPacket] for the first `TELEMETRY_APP` send.
pb.MeshPacket _firstTelemetryPacket(_RecordingFakeTransport transport) {
  for (final bytes in transport.sent) {
    final toRadio = pb.ToRadio.fromBuffer(bytes);
    if (!toRadio.hasPacket()) continue;
    final packet = toRadio.packet;
    if (packet.decoded.portnum == pn.PortNum.TELEMETRY_APP) return packet;
  }
  fail('No TELEMETRY_APP packet was sent on the wire.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const myNodeNum = 0xA6960864;
  const targetNodeNum = 0x1234ABCD;

  final cases = <TelemetryRequestType, telemetry.Telemetry_Variant>{
    TelemetryRequestType.device: telemetry.Telemetry_Variant.deviceMetrics,
    TelemetryRequestType.environment:
        telemetry.Telemetry_Variant.environmentMetrics,
    TelemetryRequestType.airQuality:
        telemetry.Telemetry_Variant.airQualityMetrics,
  };

  for (final entry in cases.entries) {
    final type = entry.key;
    final expectedVariant = entry.value;

    test(
      'requestTelemetry(${type.name}) sends a TELEMETRY_APP request with '
      'wantResponse and only the ${expectedVariant.name} variant set',
      () async {
        await _withTempDirectory((dir) async {
          final transport = _RecordingFakeTransport();
          final protocol = await _freshProtocol(dir, transport);
          try {
            await protocol.handleIncomingPacket(
              pb.FromRadio(
                myInfo: pb.MyNodeInfo(myNodeNum: myNodeNum),
              ).writeToBuffer(),
            );

            await protocol.requestTelemetry(targetNodeNum, type: type);

            final packet = _firstTelemetryPacket(transport);

            expect(
              packet.to,
              targetNodeNum,
              reason: 'Request must be addressed to the target node.',
            );
            expect(
              packet.decoded.wantResponse,
              isTrue,
              reason:
                  'wantResponse must be set so the node replies with its '
                  'current telemetry.',
            );

            final telem = telemetry.Telemetry.fromBuffer(
              packet.decoded.payload,
            );
            expect(
              telem.whichVariant(),
              expectedVariant,
              reason:
                  'The requested variant determines which telemetry module '
                  'replies — it must be the only one present.',
            );
          } finally {
            protocol.stop();
            await transport.dispose();
          }
        });
      },
    );
  }
}
