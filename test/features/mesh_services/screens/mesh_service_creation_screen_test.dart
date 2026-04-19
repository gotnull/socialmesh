// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/screens/mesh_service_creation_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp({
    required MeshServiceType type,
    MeshServicePresetId? presetId,
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MeshServiceCreationScreen(
          canonicalType: type,
          presetId: presetId,
        ),
      ),
    );
  }

  testWidgets('advanced sharing details stay collapsed by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        type: MeshServiceType.feed,
        presetId: MeshServicePresetId.bulletinBoard,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sharing details'), findsOneWidget);
    expect(
      find.text('You can change how long this stays visible on the mesh.'),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Sharing details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sharing details'));
    await tester.pumpAndSettle();

    expect(
      find.text('You can change how long this stays visible on the mesh.'),
      findsOneWidget,
    );
  });
}
