// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the MeshCanvas hydration HUD pill.
//
// Spec: docs/canvas/CANVAS_SYNC_V0_1.md §6.1 + §10.8.
//
// Coverage:
//   - idle → HUD is structurally absent (zero footprint).
//   - recovering / syncing / quiet → HUD shows the matching label.
//   - HUD is NOT a descendant of InteractiveViewer when used as a
//     sibling — anchored chrome regression pin.
//
// The HUD reads `meshCanvasHydrationStatusProvider`; tests override
// the provider directly with a synthetic state rather than wiring
// the full coordinator chain.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/hydration_status_providers.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_hydration_status_hud.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_sync_coordinator.dart';

const int _kCanvas = 11;

Future<void> _pumpHud(WidgetTester tester, MeshCanvasHydrationState state) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        meshCanvasHydrationStatusProvider(
          _kCanvas,
        ).overrideWith((ref) => Stream<MeshCanvasHydrationState>.value(state)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: CanvasHydrationStatusHud(canvasLocalId: _kCanvas),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('idle state renders nothing — happy-path zero footprint', (
    tester,
  ) async {
    await _pumpHud(tester, MeshCanvasHydrationState.idle);
    await tester.pumpAndSettle();

    expect(find.text('recovering paint'), findsNothing);
    expect(find.text('syncing tiles'), findsNothing);
    expect(find.text('mesh quiet'), findsNothing);
  });

  testWidgets('recovering state shows the recovering label', (tester) async {
    await _pumpHud(tester, MeshCanvasHydrationState.recovering);
    await tester.pumpAndSettle();
    expect(find.text('recovering paint'), findsOneWidget);
  });

  testWidgets('syncing state shows the syncing label', (tester) async {
    await _pumpHud(tester, MeshCanvasHydrationState.syncing);
    await tester.pumpAndSettle();
    expect(find.text('syncing tiles'), findsOneWidget);
  });

  testWidgets('quiet state shows the quiet label', (tester) async {
    await _pumpHud(tester, MeshCanvasHydrationState.quiet);
    await tester.pumpAndSettle();
    expect(find.text('mesh quiet'), findsOneWidget);
  });

  testWidgets(
    'I6 regression: HUD is NOT a descendant of InteractiveViewer when '
    'used as a sibling — anchored chrome stays still under pan/zoom',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCanvasHydrationStatusProvider(_kCanvas).overrideWith(
              (ref) => Stream<MeshCanvasHydrationState>.value(
                MeshCanvasHydrationState.recovering,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      child: const SizedBox(width: 200, height: 200),
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: CanvasHydrationStatusHud(canvasLocalId: _kCanvas),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hud = find.byType(CanvasHydrationStatusHud);
      expect(hud, findsOneWidget);
      final interactiveAncestor = find.ancestor(
        of: hud,
        matching: find.byType(InteractiveViewer),
      );
      expect(
        interactiveAncestor,
        findsNothing,
        reason: 'hydration HUD must be anchored chrome',
      );
    },
  );
}
