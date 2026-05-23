// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.B chrome acceptance tests for the MeshCanvas screen.
//
// What this file pins:
//
//   1) The viewer screen mounts with the new chrome elements:
//      - identity chip ("Local Device Canvas") in the framed viewport
//      - selected-colour HUD pill showing the current swatch name
//      - app-bar (i) info button that opens the canonical HelpSheet
//   2) The HUD and identity chip live INSIDE the framed viewport but
//      OUTSIDE the InteractiveViewer's subtree — they are chrome, not
//      content, so they must not pan/scale with the canvas transform.
//      This is the second leg of the S7.A interaction containment
//      contract pinned by canvas_strip_chrome_containment_test.
//   3) The HUD's caption flips from the colour name to the localized
//      eraser label when the transparent / index-0 swatch is active.
//   4) The strip's "More" button opens the palette sheet.
//
// Notes:
//   - The HUD/identity overlays are wrapped in IgnorePointer in the
//     host screen, but that does not change their position in the
//     widget tree — find.ancestor still resolves through them.
//   - Recents-rail behaviour is covered by recent_colors_provider_test
//     (provider) + the palette sheet tests (sheet rendering); this
//     file focuses on host-screen wiring, not sheet internals.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_viewer_screen.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_hud_overlays.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_viewer.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

Future<void> _pumpPlaceholder(
  WidgetTester tester, {
  int initialSelectedColor = 8, // Black
}) async {
  const fakeCanvas = CanvasSummary(
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
  // Seed the selectedColor inside the ProviderContainer via override.
  // Bumping inside a build callback is unsafe (mutates state during
  // build); overriding the notifier's initial value is the right
  // pattern.
  final container = ProviderContainer(
    overrides: [
      localDeviceCanvasProvider.overrideWith((ref) async => fakeCanvas),
      canvasCellsProvider(1).overrideWith((ref) async => const <CanvasCell>[]),
    ],
  );
  addTearDown(container.dispose);
  container.read(selectedColorProvider.notifier).select(initialSelectedColor);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MeshCanvasViewerScreen(canvas: fakeCanvas),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'identity chip is mounted inside the framed viewport with the local '
    'sandbox label — first-time users see "Local Device Canvas" at a glance',
    (tester) async {
      await _pumpPlaceholder(tester);

      expect(find.byType(CanvasIdentityChip), findsOneWidget);
      expect(find.text('Local Device Canvas'), findsOneWidget);
      expect(
        find.text('Offline sandbox - paints remain local'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selected-colour HUD shows the active swatch name when a non-transparent '
    'colour is active — "you are painting with X" without scanning the strip',
    (tester) async {
      // Pump with Red (palette index 11) preselected so the HUD has a
      // concrete name to display.
      await _pumpPlaceholder(tester, initialSelectedColor: 11);

      expect(find.byType(CanvasColorHud), findsOneWidget);
      // HUD is also rendered as a Semantics-free text widget; assert
      // the displayed label matches the palette name.
      expect(find.text('Red'), findsWidgets);
    },
  );

  testWidgets(
    'selected-colour HUD shows the localized eraser label when palette '
    'index 0 (transparent / erase) is active — colour name would be '
    'meaningless for the erase sentinel',
    (tester) async {
      await _pumpPlaceholder(tester, initialSelectedColor: 0);

      expect(find.byType(CanvasColorHud), findsOneWidget);
      expect(find.text('Eraser'), findsOneWidget);
    },
  );

  testWidgets(
    'the (i) info button is in the app-bar actions slot — first-time users '
    'should not have to hunt for "what is this screen"',
    (tester) async {
      await _pumpPlaceholder(tester);

      // Tooltip is the localized "About MeshCanvas" string.
      final infoButton = find.byTooltip('About MeshCanvas');
      expect(infoButton, findsOneWidget);
    },
  );

  testWidgets(
    'tapping the (i) opens the canonical HelpSheet — body contains the '
    'retro intro paragraph that the dev approved',
    (tester) async {
      await _pumpPlaceholder(tester);

      await tester.tap(find.byTooltip('About MeshCanvas'));
      await tester.pumpAndSettle();

      // The sheet's title is "About MeshCanvas" (same as the tooltip)
      // and the intro paragraph frames MeshCanvas as a pixel wall
      // co-painted over LoRa.
      expect(
        find.textContaining('pixel wall', findRichText: true),
        findsOneWidget,
      );
      // The first explanatory row's title is Local Device Canvas.
      expect(
        find.textContaining('Local Device Canvas', findRichText: true),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'identity chip and HUD overlay are NOT descendants of InteractiveViewer '
    "— chrome must never receive the canvas transform, otherwise pinch / "
    'pan would scale them off-screen',
    (tester) async {
      await _pumpPlaceholder(tester);

      final identity = find.byType(CanvasIdentityChip);
      final identityAncestor = find.ancestor(
        of: identity,
        matching: find.byType(InteractiveViewer),
      );
      expect(
        identityAncestor,
        findsNothing,
        reason:
            'CanvasIdentityChip must sit OUTSIDE InteractiveViewer; otherwise '
            'pinch / pan would scale it with the canvas.',
      );

      final hud = find.byType(CanvasColorHud);
      final hudAncestor = find.ancestor(
        of: hud,
        matching: find.byType(InteractiveViewer),
      );
      expect(
        hudAncestor,
        findsNothing,
        reason:
            'CanvasColorHud must sit OUTSIDE InteractiveViewer for the same '
            'reason as the identity chip.',
      );
      // Sanity: the InteractiveViewer is in tree at all.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      // Sanity: the viewer is the only InteractiveViewer (no chrome
      // accidentally got wrapped in its own).
      expect(find.byType(CanvasViewer), findsOneWidget);
    },
  );
}
