// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/telemetry/device_metrics_log_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/splash_mesh_provider.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';

class _Nodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final voltages in [
    [3.91, 4.12],
    [3.84],
    [0.01, 0.02],
    [12.01, 14.08],
  ]) {
    testWidgets('voltage ticks are evenly spaced for $voltages', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            splashMeshConfigProvider.overrideWith(
              (ref) async => SplashMeshConfig.defaultConfig,
            ),
            nodesProvider.overrideWith(_Nodes.new),
            deviceMetricsLogsProvider.overrideWith(
              (ref) async => [
                for (final (index, voltage) in voltages.indexed)
                  DeviceMetricsLog(
                    nodeNum: 1,
                    timestamp: DateTime(2026, 10, 3, 12, index),
                    voltage: voltage,
                    batteryLevel: 64,
                  ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme(AccentColors.green),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeviceMetricsLogScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      final labels =
          tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data ?? '')
              .where((text) => RegExp(r'^\d+\.\dV$').hasMatch(text))
              .map((text) => double.parse(text.substring(0, text.length - 1)))
              .toList()
            ..sort();
      expect(labels, hasLength(5));
      expect(labels.first, greaterThanOrEqualTo(0));
      expect(
        labels.first,
        lessThanOrEqualTo(voltages.reduce((a, b) => a < b ? a : b)),
      );
      expect(
        labels.last,
        greaterThanOrEqualTo(voltages.reduce((a, b) => a > b ? a : b)),
      );
      final interval = labels[1] - labels[0];
      for (var i = 2; i < labels.length; i++) {
        expect(labels[i] - labels[i - 1], closeTo(interval, 0.0001));
      }
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = chart.data.lineBarsData.last;
      final colour = chart.data.lineTouchData.touchTooltipData.getTooltipColor(
        LineBarSpot(bar, chart.data.lineBarsData.length - 1, bar.spots.first),
      );
      expect(colour.a, closeTo(0.75, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
