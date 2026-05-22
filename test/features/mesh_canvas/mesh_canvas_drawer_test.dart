// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Smoke tests for the S6 MeshCanvas placeholder screen + drawer
// isolation invariants. Full drawer-rendering interaction tests live
// in S7 once the production UI lands; for S6 we only need to confirm:
//   - the placeholder screen renders without crashing,
//   - the MeshCore shell does NOT import or reference the placeholder.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_placeholder_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

void main() {
  testWidgets('MeshCanvasPlaceholderScreen renders without exceptions', (
    tester,
  ) async {
    // S7.A replaced the placeholder body with the live r/place viewer
    // over the Local Device Canvas. To smoke-test "renders without
    // throwing" without opening a real SQLite file, override the
    // canvas + cells providers with synthetic data.
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
          home: const MeshCanvasPlaceholderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The app-bar title renders the brand string.
    expect(find.text('MeshCanvas'), findsOneWidget);
  });

  test(
    'MeshCoreShell does not import or reference MeshCanvasPlaceholderScreen',
    () {
      // Static source-scan: assert by file content rather than
      // import-graph analysis since the import graph would only show
      // transitive references.
      final file = File(
        'lib/features/navigation/meshcore_shell.dart',
      ).readAsStringSync();
      expect(
        file,
        isNot(contains('MeshCanvasPlaceholderScreen')),
        reason:
            'MeshCanvas is Meshtastic-only in v0.1; MeshCoreShell must not '
            'reference the placeholder screen.',
      );
      expect(
        file,
        isNot(contains('mesh_canvas_placeholder_screen')),
        reason: 'No transitive imports of the placeholder either.',
      );
      expect(
        file,
        isNot(contains('isMeshCanvasEnabled')),
        reason: 'MeshCore shell must not check the canvas feature flag.',
      );
    },
  );
}
