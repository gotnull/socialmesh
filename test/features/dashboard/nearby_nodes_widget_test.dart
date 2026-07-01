// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/dashboard/widgets/nearby_nodes_widget.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/presence_providers.dart';

// The dashboard "Nearby Nodes" list used to compute each row's "Xh ago" via
// DateTime.now() at build time and only rebuilt when a packet arrived, so on a
// quiet mesh every label froze. It now reuses presenceMapProvider (a periodic,
// lifecycle-aware ticker) for both the refresh cadence and a recency cap, so
// labels advance on their own and stale nodes fall off. These tests pin that.

class _TestNodesNotifier extends NodesNotifier {
  _TestNodesNotifier(this._nodes);

  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  _TestMyNodeNumNotifier(this._nodeNum);

  final int? _nodeNum;

  @override
  int? build() => _nodeNum;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Map<int, MeshNode> nodes,
  required DateTime Function() clock,
  int? myNodeNum = 999,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nodesProvider.overrideWith(() => _TestNodesNotifier(nodes)),
        myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(myNodeNum)),
        presenceClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: NearbyNodesContent()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(NearbyNodesContent)),
    listen: false,
  );
}

// Unmount the tree so the ProviderScope disposes its container and cancels the
// presence 30s timer before the binding's pending-timer invariant check runs.
Future<void> _teardown(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setPreferredLocaleOverride(const Locale('en'));
  });
  tearDown(() => setPreferredLocaleOverride(null));

  testWidgets(
    'shows only nodes heard within the recency window, strongest signal first',
    (tester) async {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      await _pump(
        tester,
        clock: () => now,
        nodes: {
          1: MeshNode(
            nodeNum: 1,
            longName: 'Alpha',
            lastHeard: now.subtract(const Duration(minutes: 5)),
            rssi: -70,
          ),
          2: MeshNode(
            nodeNum: 2,
            longName: 'Bravo',
            lastHeard: now.subtract(const Duration(minutes: 40)),
            rssi: -55,
          ),
          3: MeshNode(
            nodeNum: 3,
            longName: 'Charlie',
            lastHeard: now.subtract(const Duration(minutes: 90)),
            rssi: -40,
          ),
        },
      );

      // Within the 60-min staleWindow: rendered with canonical presence copy.
      expect(find.text('Seen 5m ago'), findsOneWidget); // Alpha, fading
      expect(find.text('Quiet'), findsOneWidget); // Bravo, stale

      // Beyond the window -> dropped from "Nearby".
      expect(find.text('-40'), findsNothing); // Charlie excluded

      // Sorted by RSSI descending: Bravo (-55) sits above Alpha (-70).
      expect(
        tester.getTopLeft(find.text('-55')).dy,
        lessThan(tester.getTopLeft(find.text('-70')).dy),
      );

      await _teardown(tester);
    },
  );

  testWidgets(
    'relative-time label advances on a presence tick with no node update',
    (tester) async {
      var now = DateTime(2026, 1, 24, 12, 0, 0);
      final container = await _pump(
        tester,
        clock: () => now,
        nodes: {
          1: MeshNode(
            nodeNum: 1,
            longName: 'Alpha',
            lastHeard: now.subtract(const Duration(minutes: 5)),
            rssi: -70,
          ),
        },
      );
      expect(find.text('Seen 5m ago'), findsOneWidget);

      // Advance wall-clock and tick presence the way the periodic timer does.
      // No node/packet update occurs.
      final nodesBefore = container.read(nodesProvider);
      now = now.add(const Duration(minutes: 1));
      container.read(presenceMapProvider.notifier).recomputeNow();
      await tester.pump();

      expect(find.text('Seen 6m ago'), findsOneWidget);
      expect(find.text('Seen 5m ago'), findsNothing);
      expect(
        identical(nodesBefore, container.read(nodesProvider)),
        isTrue,
        reason: 'label advanced from a presence tick, not a node/packet update',
      );

      await _teardown(tester);
    },
  );

  testWidgets('nodes beyond the recency window collapse to the empty state', (
    tester,
  ) async {
    final now = DateTime(2026, 1, 24, 12, 0, 0);
    await _pump(
      tester,
      clock: () => now,
      nodes: {
        1: MeshNode(
          nodeNum: 1,
          longName: 'Old',
          lastHeard: now.subtract(const Duration(hours: 3)),
          rssi: -50,
        ),
      },
    );

    expect(find.text('No nearby nodes detected'), findsOneWidget);
    expect(find.text('-50'), findsNothing);

    await _teardown(tester);
  });
}
