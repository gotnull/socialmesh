// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies NodeDetailScreen exposes a Telemetry section that links to
/// every per-node telemetry log screen. This is a wire-up invariant —
/// users should be able to jump from a node to its telemetry history
/// without going through the global Settings / drawer hub.
void main() {
  final file = File('lib/features/nodes/node_detail_screen.dart');

  late String source;

  setUpAll(() {
    expect(file.existsSync(), true);
    source = file.readAsStringSync();
  });

  group('Node Detail telemetry section', () {
    test('imports every per-node telemetry log screen', () {
      const requiredImports = <String>[
        "import '../telemetry/air_quality_log_screen.dart';",
        "import '../telemetry/detection_sensor_log_screen.dart';",
        "import '../telemetry/device_metrics_log_screen.dart';",
        "import '../telemetry/environment_metrics_log_screen.dart';",
        "import '../telemetry/pax_counter_log_screen.dart';",
        "import '../telemetry/position_log_screen.dart';",
        "import '../telemetry/traceroute_log_screen.dart';",
      ];

      for (final imp in requiredImports) {
        expect(
          source.contains(imp),
          true,
          reason:
              'NodeDetailScreen must import $imp to render a per-node '
              'navigation tile for it.',
        );
      }
    });

    test('renders the Telemetry section in the sliver list', () {
      expect(
        source.contains('_buildTelemetrySection(context, node)'),
        true,
        reason:
            'NodeDetailScreen build() must call _buildTelemetrySection so '
            'the per-node telemetry links actually render.',
      );
      expect(
        source.contains('l10n.nodeDetailSectionTelemetry'),
        true,
        reason:
            'Section must use the nodeDetailSectionTelemetry ARB key for '
            'its header label.',
      );
    });

    test('scopes every per-node log screen to the current node', () {
      // Each per-node screen must be pushed with the current nodeNum so
      // users see only that node's history, not the global log.
      const expectedLaunches = <String>[
        'DeviceMetricsLogScreen(nodeNum: nodeNum)',
        'EnvironmentMetricsLogScreen(nodeNum: nodeNum)',
        'AirQualityLogScreen(nodeNum: nodeNum)',
        'PositionLogScreen(initialNodeNum: nodeNum)',
        'TraceRouteLogScreen(nodeNum: nodeNum)',
        'PaxCounterLogScreen(nodeNum: nodeNum)',
        'DetectionSensorLogScreen(nodeNum: nodeNum)',
      ];

      for (final launch in expectedLaunches) {
        expect(
          source.contains(launch),
          true,
          reason:
              'Telemetry section must open $launch so the log is filtered '
              'to the current node.',
        );
      }
    });

    test('omits Routes from the per-node section (not node-scoped)', () {
      // Routes is user-local (the phone\'s recorded GPS tracks) not per-node.
      // The section should NOT launch RoutesScreen from within _buildTelemetrySection.
      final sectionStart = source.indexOf('_buildTelemetrySection(');
      expect(
        sectionStart > 0,
        true,
        reason: 'telemetry section builder must exist',
      );
      final sectionEnd = source.indexOf(
        '/// Network stats section',
        sectionStart,
      );
      expect(sectionEnd > sectionStart, true);
      final sectionBody = source.substring(sectionStart, sectionEnd);
      expect(
        sectionBody.contains('RoutesScreen'),
        false,
        reason:
            'Routes is user-local (phone GPS tracks), not node-scoped — it '
            'does not belong in the per-node telemetry section.',
      );
    });
  });
}
