// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.C / S8 acceptance tests for the overview screen.
//
// IA invariants (load-bearing — see screen header doc):
//   - LOCAL tab renders the Local Device Canvas viewport DIRECTLY
//     (no intermediary card, no navigation push). Identity chip
//     reads "Local Device Canvas".
//   - MESH tab lists per-channel latent canvases. Channel names
//     appear ONLY here.
//   - Channel names NEVER appear in Local mode.
//   - "Local Device Canvas" framing NEVER appears around a mesh
//     canvas.
//   - Tapping a Mesh channel row pushes the channel canvas viewer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_overview_screen.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_viewer_screen.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_hud_overlays.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_viewport_body.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/channel_canvas_thumbnail.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';
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
  // Build a unique set of canvas-cell overrides — the Local tab reads
  // canvasCellsProvider(_localCanvas.localId) AND every canvas in the
  // fixture; dedupe so Riverpod doesn't reject a double-override.
  final cellOverrideIds = <int>{
    _localCanvas.localId,
    for (final c in canvases) c.localId,
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        canvasListProvider.overrideWith((ref) async => canvases),
        localDeviceCanvasProvider.overrideWith((ref) async => _localCanvas),
        for (final id in cellOverrideIds)
          canvasCellsProvider(
            id,
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
  // Two pumps: chip animation + viewport's post-frame framing pass.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('MeshCanvasOverviewScreen — IA acceptance', () {
    testWidgets('Local tab renders the Local Device Canvas viewport DIRECTLY '
        '(no card, no Primary, no channel name)', (tester) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: 'Primary', psk: const [1]),
          _channel(1, name: 'LongFast', psk: const [2]),
        ],
      );

      // The viewport body is mounted inline under the Local tab.
      expect(find.byType(CanvasViewportBody), findsOneWidget);
      // Identity chip on the Local viewport says "Local Device Canvas".
      expect(find.byType(CanvasIdentityChip), findsOneWidget);
      expect(find.text('Local Device Canvas'), findsWidgets);
      // Channel names MUST NOT leak into Local mode.
      expect(find.text('Primary'), findsNothing);
      expect(find.text('LongFast'), findsNothing);
      expect(find.text('Channel 0'), findsNothing);
      // The old card-list copy must not appear.
      expect(find.text('Local Sandbox'), findsNothing);
    });

    testWidgets('each Mesh channel row renders a ChannelCanvasThumbnail '
        '(canvas-artifact preview, not a settings list tile) and the '
        'dormant hint copy', (tester) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: 'Primary', psk: const [1]),
        ],
      );

      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Primary channel (index 0) is treated as the commons; gets its
      // own pinned section header.
      expect(find.text('PRIMARY COMMONS'), findsOneWidget);
      // The dominant Primary card still uses a ChannelCanvasThumbnail.
      expect(find.byType(ChannelCanvasThumbnail), findsOneWidget);
      // Dormant Primary commons surfaces the CTA + hint pair from the
      // v0.1 hierarchy brief.
      expect(find.text('Seed the first pixel'), findsOneWidget);
      expect(find.text('First paint wakes the board'), findsOneWidget);
      // With only the Primary channel present, the secondary section
      // must not render.
      expect(find.text('OTHER CHANNELS'), findsNothing);
    });

    testWidgets('Mesh tab lists channel canvases — channel names appear only '
        'in Mesh mode and the viewport from Local mode is gone', (
      tester,
    ) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: 'Primary', psk: const [1]),
          _channel(1, name: 'LongFast', psk: const [2]),
        ],
      );

      await tester.tap(find.text('Mesh'));
      // pumpAndSettle is safe here — the channel-list path has no
      // indefinite tickers.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Channel rows visible.
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('LongFast'), findsOneWidget);
      // Local viewport is gone — no viewport body in tree.
      expect(find.byType(CanvasViewportBody), findsNothing);
      // No "Local Device Canvas" framing anywhere in Mesh mode.
      expect(find.text('Local Device Canvas'), findsNothing);
    });

    testWidgets('switching Local -> Mesh -> Local does not leak channel state '
        'into Local mode (no Primary, no channel rows)', (tester) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: 'Primary', psk: const [1]),
        ],
      );

      // Local tab is the default; switch to Mesh and back.
      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Primary'), findsOneWidget);

      await tester.tap(find.text('Local'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Back in Local mode. Channel name MUST be gone; viewport
      // is rendered again.
      expect(find.text('Primary'), findsNothing);
      expect(find.byType(CanvasViewportBody), findsOneWidget);
    });

    testWidgets('default channel (index 0) with empty firmware name renders as '
        '"Primary" inside the Mesh tab', (tester) async {
      await _pumpOverview(
        tester,
        channels: [
          _channel(0, name: '', psk: const [1]),
        ],
      );
      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Primary'), findsOneWidget);
    });

    testWidgets(
      'zero configured channels in Mesh mode shows AnimatedEmptyState '
      'with channel-centric copy — never "waiting for mesh canvases"',
      (tester) async {
        await _pumpOverview(tester, channels: const []);

        await tester.tap(find.text('Mesh'));
        // pumpAndSettle would hang on AnimatedEmptyState's cycling
        // tickers; bounded pumps instead.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AnimatedEmptyState), findsOneWidget);
        expect(find.textContaining('Waiting for mesh canvases'), findsNothing);
      },
    );

    testWidgets('tapping a Mesh channel row pushes the MeshCanvasViewerScreen '
        'carrying the channel canvas', (tester) async {
      // The latent provider keys materialised rows by
      // (channelIndex, derived canvasId). For the materialised-path
      // tap test we need the fixture canvas's canvas_id to MATCH
      // what the provider derives from (psk, name) — otherwise the
      // row is dormant and the tap hits the get-or-create branch,
      // which needs a real repository.
      const psk = <int>[1, 2, 3];
      const channelName = 'Primary';
      final derivedId = deriveCanvasIdFromChannel(
        channelPsk: psk,
        canvasName: channelName,
      );
      final liveMesh = CanvasSummary(
        localId: 2,
        canvasId: derivedId,
        scope: CanvasScope.mesh,
        channelIndex: 3,
        name: channelName,
        width: 128,
        height: 128,
        paletteId: 1,
        status: CanvasStatus.open,
        ownerNodeNum: null,
        createdAtMs: 0,
        lastOpAtMs: 0,
        globalDigest: null,
        tileDigests: null,
        cellCount: 17,
      );
      await _pumpOverview(
        tester,
        canvases: [_localCanvas, liveMesh],
        channels: [_channel(3, name: channelName, psk: psk)],
      );

      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Primary'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // A MeshCanvasViewerScreen route was pushed.
      expect(find.byType(MeshCanvasViewerScreen), findsOneWidget);
    });
  });
}
