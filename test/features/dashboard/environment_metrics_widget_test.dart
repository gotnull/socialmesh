// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dashboard Environment Metrics widget', () {
    final widgetFile = File(
      'lib/features/dashboard/widgets/environment_metrics_widget.dart',
    );
    final dashboardFile = File(
      'lib/features/dashboard/widget_dashboard_screen.dart',
    );
    final modelFile = File(
      'lib/features/dashboard/models/dashboard_widget_config.dart',
    );

    late String widgetSource;
    late String dashboardSource;
    late String modelSource;

    setUpAll(() {
      expect(widgetFile.existsSync(), true);
      expect(dashboardFile.existsSync(), true);
      expect(modelFile.existsSync(), true);
      widgetSource = widgetFile.readAsStringSync();
      dashboardSource = dashboardFile.readAsStringSync();
      modelSource = modelFile.readAsStringSync();
    });

    test('environmentMetrics enum value is registered', () {
      expect(
        modelSource.contains('environmentMetrics'),
        true,
        reason:
            'DashboardWidgetType must include environmentMetrics so the '
            'widget can be added to the dashboard.',
      );
      expect(
        modelSource.contains('type: DashboardWidgetType.environmentMetrics'),
        true,
        reason:
            'WidgetRegistry must contain a WidgetTypeInfo for '
            'environmentMetrics so the dashboard knows its name and icon.',
      );
    });

    test('dashboard switch wires the widget content', () {
      expect(
        dashboardSource.contains(
          "import 'widgets/environment_metrics_widget.dart';",
        ),
        true,
        reason:
            'widget_dashboard_screen must import environment_metrics_widget '
            'so the switch can construct EnvironmentMetricsContent.',
      );
      expect(
        dashboardSource.contains(
          'case DashboardWidgetType.environmentMetrics:',
        ),
        true,
        reason: 'Dashboard switch must handle environmentMetrics.',
      );
      expect(
        dashboardSource.contains('EnvironmentMetricsContent()'),
        true,
        reason: 'Switch must instantiate EnvironmentMetricsContent.',
      );
    });

    test('widget opens the EnvironmentMetricsLogScreen on tap', () {
      expect(
        widgetSource.contains(
          "import '../../telemetry/environment_metrics_log_screen.dart';",
        ),
        true,
        reason:
            'Widget must import EnvironmentMetricsLogScreen so taps can '
            'navigate to the full log.',
      );
      expect(
        widgetSource.contains('EnvironmentMetricsLogScreen()'),
        true,
        reason:
            'Widget must navigate to EnvironmentMetricsLogScreen — that is '
            'the entire point of the quick-access tile.',
      );
    });

    test('widget watches environmentMetricsLogsProvider', () {
      expect(
        widgetSource.contains('environmentMetricsLogsProvider'),
        true,
        reason:
            'Widget must watch environmentMetricsLogsProvider so the latest '
            'reading on the dashboard updates as new metrics arrive.',
      );
    });
  });
}
