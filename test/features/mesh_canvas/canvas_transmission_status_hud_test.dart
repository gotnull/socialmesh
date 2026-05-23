// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the MeshCanvas transmission-status HUD pill.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §3.1 + §7.
//
// Coverage:
//   - Idle severity → HUD is structurally absent (zero footprint).
//   - Queued severity → HUD shows the queued label.
//   - Cooling severity → HUD shows the cooling label.
//   - Full severity → HUD shows the queue-full label.
//   - HUD is NOT a descendant of InteractiveViewer when mounted in
//     the canvas viewport body (regression pin: anchored chrome).
//
// The HUD reads `meshCanvasTransmissionStatusProvider`; tests
// override the provider directly with a synthetic value rather than
// spinning up the repository / coordinator / governor chain.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/transmission_status_providers.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_transmission_status_hud.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_transmission_status_models.dart';

const int _kCanvas = 7;

Future<void> _pumpHud(
  WidgetTester tester,
  MeshCanvasTransmissionStatus status,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        meshCanvasTransmissionStatusProvider(_kCanvas).overrideWith(
          (ref) => Stream<MeshCanvasTransmissionStatus>.value(status),
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
        home: const Scaffold(
          body: Center(
            child: CanvasTransmissionStatusHud(canvasLocalId: _kCanvas),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('idle severity renders nothing — happy-path zero footprint', (
    tester,
  ) async {
    await _pumpHud(tester, MeshCanvasTransmissionStatus.idle);
    await tester.pumpAndSettle();

    // No labels of any severity should appear.
    expect(find.text('queued'), findsNothing);
    expect(find.text('cooling'), findsNothing);
    expect(find.textContaining('queue full'), findsNothing);
  });

  testWidgets('queued severity shows the queued label', (tester) async {
    await _pumpHud(
      tester,
      const MeshCanvasTransmissionStatus(
        pendingCount: 5,
        oldestPendingAtMs: 1_000,
        nextAttemptAtMs: 1_500,
        isCanvasBudgetCooling: false,
        isSipBudgetCooling: false,
        canPaint: true,
        severity: MeshCanvasTransmissionSeverity.queued,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5 queued'), findsOneWidget);
  });

  testWidgets('cooling severity shows the cooling label', (tester) async {
    await _pumpHud(
      tester,
      const MeshCanvasTransmissionStatus(
        pendingCount: 3,
        oldestPendingAtMs: 1_000,
        nextAttemptAtMs: 1_500,
        isCanvasBudgetCooling: true,
        isSipBudgetCooling: false,
        canPaint: true,
        severity: MeshCanvasTransmissionSeverity.cooling,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('cooling'), findsOneWidget);
  });

  testWidgets('full severity shows the queue-full label', (tester) async {
    await _pumpHud(
      tester,
      const MeshCanvasTransmissionStatus(
        pendingCount: 32,
        oldestPendingAtMs: 1_000,
        nextAttemptAtMs: 1_500,
        isCanvasBudgetCooling: false,
        isSipBudgetCooling: false,
        canPaint: false,
        severity: MeshCanvasTransmissionSeverity.full,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('queue full'), findsOneWidget);
  });

  testWidgets(
    'I2 regression: HUD is NOT a descendant of InteractiveViewer when '
    'used as a sibling — anchored chrome stays still under pan/zoom',
    (tester) async {
      // Mount a synthetic Stack mirroring the viewport body shape:
      // viewer transform on one branch, HUD on the other. The widget
      // tree must show HUD as NOT descended from InteractiveViewer.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCanvasTransmissionStatusProvider(_kCanvas).overrideWith(
              (ref) => Stream<MeshCanvasTransmissionStatus>.value(
                const MeshCanvasTransmissionStatus(
                  pendingCount: 1,
                  oldestPendingAtMs: 1_000,
                  nextAttemptAtMs: 1_500,
                  isCanvasBudgetCooling: false,
                  isSipBudgetCooling: false,
                  canPaint: true,
                  severity: MeshCanvasTransmissionSeverity.queued,
                ),
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
                    child: CanvasTransmissionStatusHud(canvasLocalId: _kCanvas),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate the HUD and verify no InteractiveViewer ancestor.
      final hud = find.byType(CanvasTransmissionStatusHud);
      expect(hud, findsOneWidget);
      final interactiveAncestor = find.ancestor(
        of: hud,
        matching: find.byType(InteractiveViewer),
      );
      expect(
        interactiveAncestor,
        findsNothing,
        reason:
            'transmission HUD must be anchored chrome — never descended '
            'from InteractiveViewer, otherwise pan/zoom would move it',
      );
    },
  );
}
