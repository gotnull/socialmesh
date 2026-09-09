// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/settings/security_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// The packet authentication block is gated on the firmware capability the
// radio reports in DeviceMetadata. A radio that verifies XEdDSA signatures
// gets the three policy chips with the loaded policy selected; a radio
// that does not report the capability never sees the block.

const _myNodeNum = 0x1001;

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({this.cachedConfig}) : super(_FakeTransport());

  config_pb.Config_SecurityConfig? cachedConfig;
  final StreamController<config_pb.Config_SecurityConfig> _ctrl =
      StreamController<config_pb.Config_SecurityConfig>.broadcast();

  @override
  config_pb.Config_SecurityConfig? get currentSecurityConfig => cachedConfig;

  @override
  Stream<config_pb.Config_SecurityConfig> get securityConfigStream =>
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

Widget _wrap({
  required _FakeProtocolService protocol,
  required bool hasXeddsa,
}) {
  return ProviderScope(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      nodesProvider.overrideWith(
        () => _StaticNodes({
          _myNodeNum: MeshNode(
            nodeNum: _myNodeNum,
            longName: 'Local',
            hasXeddsa: hasXeddsa,
          ),
        }),
      ),
      myNodeNumProvider.overrideWith(_StaticMyNodeNum.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const SecurityConfigScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows the policy chips with the loaded policy on a radio '
      'that verifies signatures', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_SecurityConfig()
        ..packetSignaturePolicy = config_pbenum
            .Config_SecurityConfig_PacketSignaturePolicy
            .PACKET_SIGNATURE_POLICY_BALANCED,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol, hasXeddsa: true));
    await _settle(tester);

    expect(find.text('Packet Authentication'), findsOneWidget);
    expect(find.text('Compatible'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Strict'), findsOneWidget);
    expect(
      find.text(
        'Recommended. Reject unsigned downgrade attempts from nodes known '
        'to sign.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Strict'));
    await _settle(tester);

    expect(
      find.text(
        'Only show and process cryptographically authenticated mesh '
        'packets. Older nodes and oversized packets may disappear.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides the block when the radio does not report the capability', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_SecurityConfig(),
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol, hasXeddsa: false));
    await _settle(tester);

    expect(find.text('Packet Authentication'), findsNothing);
    expect(find.text('Strict'), findsNothing);
  });
}
