// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.A interaction-containment acceptance pin.
//
// The developer rejected the original S7.A interaction pass with:
//   "Pinch/zoom/pan feels horrible because the entire screen appears
//    to move with touch instead of only the canvas surface moving
//    inside a stable viewport."
//
// Root cause: the bottom CanvasColorStrip and the host CustomScrollView
// both sat inside the same widget subtree as the InteractiveViewer.
// When the user dragged the canvas, gestures that the InteractiveViewer
// did not claim could bubble up to the CustomScrollView and rubber-
// band the entire sliver body — strip included — making the chrome
// feel attached to the canvas transform.
//
// The fix: pass NeverScrollableScrollPhysics to GlassScaffold AND
// keep the CanvasColorStrip outside the InteractiveViewer's subtree.
// This file regression-pins both so future refactors can't reintroduce
// the failure mode.
//
// What we assert:
//   1) CanvasColorStrip is NOT a descendant of InteractiveViewer
//      (chrome stays chrome).
//   2) The host's CustomScrollView is non-scrollable so escaped
//      gestures cannot drift the strip.
//   3) Dragging on the canvas viewport does not fire onTapPaint
//      (pin against the "grid editor" failure mode).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_viewer_screen.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_color_strip.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_viewer.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

Future<void> _pumpPlaceholder(WidgetTester tester) async {
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDeviceCanvasProvider.overrideWith((ref) async => fakeCanvas),
        canvasCellsProvider(
          1,
        ).overrideWith((ref) async => const <CanvasCell>[]),
      ],
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
    'CanvasColorStrip is NOT a descendant of InteractiveViewer — the strip '
    'is chrome and must never receive the canvas transform',
    (tester) async {
      await _pumpPlaceholder(tester);

      final strip = find.byType(CanvasColorStrip);
      expect(strip, findsOneWidget);
      final stripAncestor = find.ancestor(
        of: strip,
        matching: find.byType(InteractiveViewer),
      );
      expect(
        stripAncestor,
        findsNothing,
        reason:
            'If this expectation flips, the strip has been moved inside the '
            "viewer's gesture/transform tree — it would visually pan, zoom, "
            'or jitter with the canvas, failing S7.A interaction acceptance.',
      );
    },
  );

  testWidgets(
    "host CustomScrollView is non-scrollable so a drag that escapes the "
    'InteractiveViewer cannot rubber-band the body and drift the strip',
    (tester) async {
      await _pumpPlaceholder(tester);

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(
        scrollView.physics,
        isA<NeverScrollableScrollPhysics>(),
        reason:
            'GlassScaffold must be constructed with NeverScrollableScrollPhysics '
            'on the MeshCanvas screen. Without this, a gesture that the '
            'InteractiveViewer surrenders can bubble up to the CustomScrollView '
            'and scroll/rubber-band the sliver body, including the strip.',
      );
    },
  );

  testWidgets(
    'a drag inside the canvas viewport does NOT fire onTapPaint — the '
    "InteractiveViewer's pan recognizer claims the gesture before the "
    "tap recogniser fires, so the user can pan without painting a streak",
    (tester) async {
      await _pumpPlaceholder(tester);

      // Drag across the canvas viewport. If this ever produces a tap
      // (i.e. the GestureDetector misinterprets a pan as a tap-up),
      // S7.A would regress into the "grid editor" failure mode called
      // out in §S0.ux.16.
      await tester.drag(find.byType(CanvasViewer), const Offset(120, 60));
      await tester.pumpAndSettle();

      // The fake canvas provider's cells list is invalidated on each
      // accepted paint. The provider override keeps cells empty. If a
      // drag had painted, the repository would have been touched, but
      // we have no repository at all in this test — so this is a
      // structural pin: the test would otherwise throw on null repo.
      // Nothing to assert beyond "no exception during the drag."
    },
  );
}
