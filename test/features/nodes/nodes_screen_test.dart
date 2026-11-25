// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/nodedex/providers/node_groups_provider.dart';
import 'package:socialmesh/features/nodes/nodes_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/presence_providers.dart';
import 'package:socialmesh/providers/social_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _Nodes extends NodesNotifier {
  _Nodes(this._nodes);
  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _Groups extends NodeGroupsNotifier {
  @override
  Future<NodeGroupsState> build() async => const NodeGroupsState();
}

class _Presence extends PresenceNotifier {
  @override
  Map<int, NodePresence> build() => {};
}

class _MyNode extends MyNodeNumNotifier {
  @override
  int? build() => null;
}

Future<void> _pumpNodes(WidgetTester tester, List<MeshNode> nodes) async {
  SharedPreferences.setMockInitialValues({});
  dotenv.loadFromString(envString: 'AETHER_ENABLED=false');
  final settings = SettingsService();
  await settings.init();
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        connectionStateProvider.overrideWith(
          (ref) => Stream.value(DeviceConnectionState.connected),
        ),
        nodesProvider.overrideWith(
          () => _Nodes({for (final n in nodes) n.nodeNum: n}),
        ),
        myNodeNumProvider.overrideWith(_MyNode.new),
        nodeGroupsProvider.overrideWith(_Groups.new),
        presenceMapProvider.overrideWith(_Presence.new),
        linkedNodeIdsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.green),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NodesScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('node card shows the hardware model a node announced', (
    tester,
  ) async {
    await _pumpNodes(tester, [
      MeshNode(
        nodeNum: 0x1234,
        longName: 'Hilltop Repeater',
        shortName: 'HILL',
        hardwareModel: 'Heltec V3',
      ),
    ]);

    expect(find.text('Hilltop Repeater'), findsOneWidget);
    expect(find.text('Heltec V3'), findsOneWidget);
    expect(find.byIcon(Icons.memory), findsOneWidget);
  });

  testWidgets('node card has no hardware row when the model is unknown', (
    tester,
  ) async {
    await _pumpNodes(tester, [
      MeshNode(nodeNum: 0x5678, longName: 'Quiet Node', shortName: 'QUIE'),
    ]);

    expect(find.text('Quiet Node'), findsOneWidget);
    expect(find.byIcon(Icons.memory), findsNothing);
  });
}
