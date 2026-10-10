// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/glass_scaffold.dart';
import 'package:socialmesh/features/incidents/providers/mesh_incident_providers.dart';
import 'package:socialmesh/features/navigation/main_shell.dart';
import 'package:socialmesh/features/nodedex/providers/node_groups_provider.dart';
import 'package:socialmesh/features/nodes/nodes_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/countdown_providers.dart';
import 'package:socialmesh/providers/mesh_explorer_providers.dart';
import 'package:socialmesh/providers/presence_providers.dart';
import 'package:socialmesh/providers/social_providers.dart';
import 'package:socialmesh/providers/splash_mesh_provider.dart';
import 'package:socialmesh/providers/whats_new_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _Device extends DeviceConnectionNotifier {
  @override
  DeviceConnectionState2 build() =>
      const DeviceConnectionState2(state: DevicePairingState.connected);
}

class _Nodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
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

class _Peers extends NewMeshPeerCountNotifier {
  @override
  int build() => 0;
}

void main() {
  testWidgets('Nodes consumes the keyboard inset only once inside the shell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: 'AETHER_ENABLED=false');
    final settings = SettingsService();
    await settings.init();
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          connectionStateProvider.overrideWith(
            (ref) => Stream.value(DeviceConnectionState.connected),
          ),
          deviceConnectionProvider.overrideWith(_Device.new),
          needsRegionSetupProvider.overrideWithValue(false),
          firestoreConfigWatcherProvider.overrideWith((ref) => Stream.empty()),
          clientNotificationStreamProvider.overrideWith(
            (ref) => Stream.empty(),
          ),
          activeHelpRequestsProvider.overrideWith((ref) async => []),
          hasActiveCountdownsProvider.overrideWithValue(false),
          nodesProvider.overrideWith(_Nodes.new),
          myNodeNumProvider.overrideWith(_MyNode.new),
          nodeGroupsProvider.overrideWith(_Groups.new),
          presenceMapProvider.overrideWith(_Presence.new),
          linkedNodeIdsProvider.overrideWith((ref) => Stream.value([])),
          newMeshPeerCountProvider.overrideWith(_Peers.new),
          whatsNewHasUnseenProvider.overrideWithValue(false),
          splashMeshConfigProvider.overrideWith(
            (ref) async => SplashMeshConfig.defaultConfig,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(AccentColors.green),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    final viewport = find.descendant(
      of: find.byType(NodesScreen),
      matching: find.byType(CustomScrollView),
    );
    final initialHeight = tester.getSize(viewport).height;
    final initialBottomGap =
        tester.view.physicalSize.height - tester.getRect(viewport).bottom;

    tester.view.viewInsets = const FakeViewPadding(bottom: 216);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(
      initialHeight - tester.getSize(viewport).height,
      closeTo(216 - initialBottomGap, 1),
    );
    final screenContext = tester.element(find.byType(GlassScaffold).first);
    expect(MediaQuery.viewInsetsOf(screenContext).bottom, 0);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(viewport).height, closeTo(initialHeight, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
