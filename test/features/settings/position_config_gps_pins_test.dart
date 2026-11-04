// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/settings/position_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/generated/meshtastic/hardware_model_metadata.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pbenum.dart' as mesh_pb;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// The GPS pin settings only apply to boards whose GPS wiring is left to the
// builder. Boards tagged oem_fixed_gps in mesh.proto hide them; a board whose
// model is not known yet keeps them, so nothing is hidden on a guess.

const _myNodeNum = 0x1001;

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService() : super(_FakeTransport());

  final StreamController<config_pb.Config_PositionConfig> _ctrl =
      StreamController<config_pb.Config_PositionConfig>.broadcast();

  @override
  config_pb.Config_PositionConfig? get currentPositionConfig =>
      config_pb.Config_PositionConfig()
        ..gpsMode = config_pbenum.Config_PositionConfig_GpsMode.ENABLED;

  @override
  Stream<config_pb.Config_PositionConfig> get positionConfigStream =>
      _ctrl.stream;

  // Skip the get-config-from-device branch.
  @override
  bool get isConnected => false;

  Future<void> closeStreams() async {
    await _ctrl.close();
  }
}

class _FakeTransport extends DeviceTransport {
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

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

class _StaticNodes extends NodesNotifier {
  _StaticNodes(this._nodes);
  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _StaticMyNodeNum extends MyNodeNumNotifier {
  @override
  int? build() => _myNodeNum;
}

Future<void> _pumpScreen(WidgetTester tester, {int? hwModelId}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final protocol = _FakeProtocolService();
  addTearDown(protocol.closeStreams);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        nodesProvider.overrideWith(
          () => _StaticNodes({
            _myNodeNum: MeshNode(
              nodeNum: _myNodeNum,
              longName: 'Local',
              hwModelId: hwModelId,
            ),
          }),
        ),
        myNodeNumProvider.overrideWith(_StaticMyNodeNum.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const PositionConfigScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('hides the GPS pins on a board with maker-wired GPS', (
    tester,
  ) async {
    await _pumpScreen(tester, hwModelId: mesh_pb.HardwareModel.TBEAM.value);

    expect(find.text('GPS GPIO'), findsNothing);
    expect(find.text('GPS RX GPIO'), findsNothing);
  });

  testWidgets('shows the GPS pins on a board without fixed GPS wiring', (
    tester,
  ) async {
    await _pumpScreen(tester, hwModelId: mesh_pb.HardwareModel.HELTEC_V3.value);

    expect(find.text('GPS GPIO'), findsOneWidget);
    expect(find.text('GPS RX GPIO'), findsOneWidget);
  });

  testWidgets('shows the GPS pins while the board model is unknown', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('GPS GPIO'), findsOneWidget);
  });

  test('the generated list matches the oem_fixed_gps tags in mesh.proto', () {
    final proto = File('protos/meshtastic/mesh.proto').readAsStringSync();
    final tagged = RegExp(
      r'(\w+)\s*=\s*(\d+)\s*\[[^\]]*oem_fixed_gps\s*:\s*true[^\]]*\]',
    ).allMatches(proto).map((m) => int.parse(m.group(2)!)).toSet();

    expect(tagged, isNotEmpty);
    expect(
      kOemFixedGpsHardwareModels,
      tagged,
      reason: 'run ./scripts/generate_protos.sh generate after a proto update',
    );
  });
}
