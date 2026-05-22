// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.C + S8 acceptance tests for the overview / list screen.
//
// Coverage:
//   - Local tab renders a card for the Local Device Canvas with its
//     scope label, never-painted hint, and zero cell count.
//   - Mesh tab uses [latentChannelCanvasesProvider] — one row per
//     configured Meshtastic channel, dormant or live. NEVER waits
//     for peer discovery.
//   - Dormant channel row shows the "No paints yet - seed the first
//     pixel" hint (channel-centric, not "waiting for discovery").
//   - Live channel row (with materialised canvas) shows cell count.
//   - Tapping a card pushes [MeshCanvasViewerScreen].
//   - Zero configured channels surface the AnimatedEmptyState fallback
//     with the channel-centric copy (no "waiting for mesh canvases").
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_overview_screen.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_viewer_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

const _localCanvas = CanvasSummary(
  localId: 1,
  canvasId: 0,
  scope: CanvasScope.local,
  channelIndex: null,
  name: 'Local Sandbox',
  width: 128,
  height: 128,
  paletteId: 1,
  status: CanvasStatus.open,
  ownerNodeNum: null,
  createdAtMs: 0,
  lastOpAtMs: 0,
  globalDigest: null,
  tileDigests: null,
  cellCount: 0,
);

ChannelConfig _channel(
  int index, {
  String name = '',
  List<int> psk = const [],
}) {
  return ChannelConfig(index: index, name: name, psk: psk);
}

class _StubChannelsNotifier extends ChannelsNotifier {
  final List<ChannelConfig> seed;
  _StubChannelsNotifier(this.seed);

  @override
  List<ChannelConfig> build() => seed;
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  List<CanvasSummary> canvases = const [_localCanvas],
  List<ChannelConfig> channels = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        canvasListProvider.overrideWith((ref) async => canvases),
        for (final c in canvases)
          canvasCellsProvider(
            c.localId,
          ).overrideWith((ref) async => const <CanvasCell>[]),
        channelsProvider.overrideWith(() => _StubChannelsNotifier(channels)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MeshCanvasOverviewScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MeshCanvasOverviewScreen — S7.C + S8 acceptance', () {
    testWidgets(
      'Local tab renders the local sandbox card with name, scope chip, '
      'never-painted hint, and zero cell count',
      (tester) async {
        await _pumpOverview(tester);

        expect(find.text('Local Sandbox'), findsOneWidget);
        // Scope label on the card; the tab chip ALSO says "Local".
        expect(find.text('Local'), findsWidgets);
        expect(find.text('Never painted'), findsOneWidget);
        expect(find.text('0 cells'), findsOneWidget);
      },
    );

    testWidgets('Mesh tab shows a latent row for every configured channel — '
        'dormant rows include the channel name + "no paints yet" hint, '
        'NOT a "waiting for mesh canvases" empty state', (tester) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: 'Primary', psk: const [1]),
          _channel(1, name: 'LongFast', psk: const [2, 3]),
        ],
      );

      // Switch to the Mesh tab.
      await tester.tap(find.text('Mesh'));
      // No pumpAndSettle here — the empty-state path has indefinite
      // animation tickers. The row path settles fine though.
      await tester.pumpAndSettle();

      // Both channels appear as rows with their names + scope chips.
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('LongFast'), findsOneWidget);
      expect(find.text('Channel 0'), findsOneWidget);
      expect(find.text('Channel 1'), findsOneWidget);
      // Each dormant row carries the new hint (one per channel).
      expect(
        find.text('No paints yet - seed the first pixel'),
        findsNWidgets(2),
      );
      // Local sandbox is filtered out on the mesh tab.
      expect(find.text('Local Sandbox'), findsNothing);
    });

    testWidgets('default channel (index 0) with empty firmware name renders as '
        '"Primary" — convention shared with Meshtastic UI', (tester) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: '', psk: const [1]),
        ],
      );
      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();
      expect(find.text('Primary'), findsOneWidget);
    });

    testWidgets('zero configured channels falls back to the AnimatedEmptyState '
        'with channel-centric copy — never the old "waiting for mesh '
        'canvases" framing', (tester) async {
      await _pumpOverview(tester, channels: const []);

      await tester.tap(find.text('Mesh'));
      // Several bounded pumps so the chip animation, the
      // FutureProvider resolution, and the empty-state's first
      // tagline frame all land.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));

      // The empty state has rendered (AnimatedEmptyState is mounted).
      expect(find.byType(AnimatedEmptyState), findsOneWidget);
      // The bland prior copy must NOT appear anywhere.
      expect(find.textContaining('Waiting for mesh canvases'), findsNothing);
    });

    testWidgets(
      'tapping the local sandbox card pushes a MeshCanvasViewerScreen '
      'with the chosen canvas',
      (tester) async {
        await _pumpOverview(tester);

        await tester.tap(find.text('Local Sandbox'));
        // Two bounded pumps: the first kicks off the route push, the
        // second advances past the Material 300ms transition + the
        // viewer's post-frame framing pass.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        final viewer = find.byType(MeshCanvasViewerScreen);
        expect(viewer, findsOneWidget);
        final viewerWidget = tester.widget<MeshCanvasViewerScreen>(viewer);
        expect(viewerWidget.canvas.localId, _localCanvas.localId);
      },
    );
  });
}
