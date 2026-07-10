// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/telemetry/air_quality_log_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';

// Air Quality Log screen: node attribution, merged gas readings, and
// the tap-to-map affordance that must only be live for nodes with a
// usable position (map centring silently no-ops without one).

const _kPositionedNode = 0x0101;
const _kUnpositionedNode = 0x0202;

class _FakeNodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {
    _kPositionedNode: MeshNode(
      nodeNum: _kPositionedNode,
      longName: 'Solar Roof Node',
      shortName: 'ROOF',
      latitude: 52.52,
      longitude: 13.405,
    ),
    _kUnpositionedNode: MeshNode(
      nodeNum: _kUnpositionedNode,
      longName: 'Basement Sensor',
      shortName: 'BASE',
    ),
  };
}

Widget _wrap({
  required List<AirQualityMetricsLog> airLogs,
  required List<EnvironmentMetricsLog> envLogs,
}) {
  return ProviderScope(
    overrides: [
      nodesProvider.overrideWith(_FakeNodes.new),
      airQualityMetricsLogsProvider.overrideWith((ref) async => airLogs),
      environmentMetricsLogsProvider.overrideWith((ref) async => envLogs),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AirQualityLogScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime.utc(2026, 7, 1, 12);

  testWidgets('cards show the sharing node name and merged gas value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        airLogs: [
          AirQualityMetricsLog(
            nodeNum: _kPositionedNode,
            timestamp: t0,
            iaq: 60,
          ),
        ],
        envLogs: [
          EnvironmentMetricsLog(
            nodeNum: _kPositionedNode,
            timestamp: t0.add(const Duration(seconds: 3)),
            gasResistance: 3141,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solar Roof Node'), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AirQualityLogScreen)),
    );
    expect(
      find.text(l10n.telemetryEnvGasResistanceValue('3141')),
      findsOneWidget,
      reason:
          'The gas reading rides in an environment row and must merge '
          'into the same air-quality card, not render a second card.',
    );
    expect(
      find.text(l10n.telemetryAirQualityGasResistanceLabel),
      findsOneWidget,
    );
  });

  testWidgets('standalone gas-only reading renders its own card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        airLogs: const [],
        envLogs: [
          EnvironmentMetricsLog(
            nodeNum: _kUnpositionedNode,
            timestamp: t0,
            gasResistance: 2718,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basement Sensor'), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AirQualityLogScreen)),
    );
    expect(
      find.text(l10n.telemetryEnvGasResistanceValue('2718')),
      findsOneWidget,
    );
  });

  testWidgets('tap-to-map is wired only for nodes with a position', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        airLogs: [
          AirQualityMetricsLog(
            nodeNum: _kPositionedNode,
            timestamp: t0,
            iaq: 60,
          ),
          AirQualityMetricsLog(
            nodeNum: _kUnpositionedNode,
            timestamp: t0.subtract(const Duration(minutes: 1)),
            iaq: 70,
          ),
        ],
        envLogs: const [],
      ),
    );
    await tester.pumpAndSettle();

    // Do NOT tap - pumping MapScreen (flutter_map) is heavy in tests;
    // asserting onTap nullability pins the guard.
    final inkWells = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .where((w) => w.borderRadius != null)
        .toList();
    expect(inkWells, hasLength(2));

    final tappable = inkWells.where((w) => w.onTap != null);
    final inert = inkWells.where((w) => w.onTap == null);
    expect(
      tappable,
      hasLength(1),
      reason: 'only the positioned node gets a live tap',
    );
    expect(inert, hasLength(1), reason: 'no-position node must not no-op tap');

    expect(
      find.byIcon(Icons.map_outlined),
      findsOneWidget,
      reason: 'map affordance appears only on the tappable card',
    );
  });
}
