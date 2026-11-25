// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/units/distance_format.dart';
import 'package:socialmesh/features/telemetry/environment_metrics_log_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';

class _Nodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
}

Future<void> _pumpScreen(
  WidgetTester tester,
  List<EnvironmentMetricsLog> logs,
) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        environmentMetricsLogsProvider.overrideWith((ref) async => logs),
        nodesProvider.overrideWith(_Nodes.new),
        measurementUnitsProvider.overrideWithValue(MeasurementUnits.metric),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.green),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EnvironmentMetricsLogScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('an entry shows its radiation reading in µR/h', (tester) async {
    await _pumpScreen(tester, [
      EnvironmentMetricsLog(nodeNum: 0x1234, radiation: 12.5),
    ]);

    expect(find.text('12.5 µR/h'), findsOneWidget);
  });

  testWidgets('an entry without radiation shows no radiation chip', (
    tester,
  ) async {
    await _pumpScreen(tester, [
      EnvironmentMetricsLog(nodeNum: 0x1234, temperature: 21.0),
    ]);

    expect(find.textContaining('µR/h'), findsNothing);
  });
}
