// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Smoke tests for the MeshCanvas overview screen + drawer isolation
// invariants. As of S7.C the drawer entry points to the overview
// screen (the prior placeholder/viewer was renamed and pulled inside
// the list cards). We pin:
//   - the overview screen renders without crashing,
//   - the MeshCore shell does NOT import or reference any MeshCanvas
//     screen or transitive identifier (Meshtastic-only invariant).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_overview_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

void main() {
  testWidgets('MeshCanvasOverviewScreen renders without exceptions', (
    tester,
  ) async {
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
          // Short-circuit the full provider chain (db open → list)
          // so the test doesn't have to touch sqflite-FFI.
          canvasListProvider.overrideWith(
            (ref) async => const <CanvasSummary>[fakeCanvas],
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
          home: const MeshCanvasOverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The app-bar title renders the brand string.
    expect(find.text('MeshCanvas'), findsOneWidget);
    // The Local Sandbox row from the fake list renders.
    expect(find.text('Local Sandbox'), findsOneWidget);
  });

  test('MeshCoreShell does not import or reference any MeshCanvas screen', () {
    final file = File(
      'lib/features/navigation/meshcore_shell.dart',
    ).readAsStringSync();
    expect(
      file,
      isNot(contains('MeshCanvasOverviewScreen')),
      reason:
          'MeshCanvas is Meshtastic-only in v0.1; MeshCoreShell must not '
          'reference the overview screen.',
    );
    expect(
      file,
      isNot(contains('MeshCanvasViewerScreen')),
      reason:
          'MeshCanvas is Meshtastic-only in v0.1; MeshCoreShell must not '
          'reference the viewer screen.',
    );
    expect(
      file,
      isNot(contains('mesh_canvas/')),
      reason: 'No transitive imports of the mesh_canvas feature.',
    );
    expect(
      file,
      isNot(contains('isMeshCanvasEnabled')),
      reason: 'MeshCore shell must not check the canvas feature flag.',
    );
  });
}
