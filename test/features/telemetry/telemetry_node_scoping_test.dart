// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies that DeviceMetricsLogScreen and EnvironmentMetricsLogScreen
/// accept an optional `nodeNum` and scope their provider watches + header
/// subtitle when it is supplied.
///
/// These are source-level invariants — the feature depends on them so
/// per-node navigation from NodeDetailScreen can open a filtered view.
void main() {
  group('DeviceMetricsLogScreen nodeNum scoping', () {
    final file = File('lib/features/telemetry/device_metrics_log_screen.dart');

    late String source;

    setUpAll(() {
      expect(file.existsSync(), true);
      source = file.readAsStringSync();
    });

    test('exposes an optional nodeNum constructor parameter', () {
      expect(
        source.contains('final int? nodeNum;'),
        true,
        reason:
            'DeviceMetricsLogScreen must expose nodeNum so Node Details can '
            'open a per-node view.',
      );
      expect(
        source.contains(
          'const DeviceMetricsLogScreen({super.key, this.nodeNum})',
        ),
        true,
        reason: 'Constructor must accept nodeNum as an optional named arg.',
      );
    });

    test('routes to the per-node provider when scoped', () {
      expect(
        source.contains('nodeDeviceMetricsLogsProvider'),
        true,
        reason:
            'Scoped builds must read from nodeDeviceMetricsLogsProvider, '
            'not the global deviceMetricsLogsProvider.',
      );
    });
  });

  group('EnvironmentMetricsLogScreen nodeNum scoping', () {
    final file = File(
      'lib/features/telemetry/environment_metrics_log_screen.dart',
    );

    late String source;

    setUpAll(() {
      expect(file.existsSync(), true);
      source = file.readAsStringSync();
    });

    test('exposes an optional nodeNum constructor parameter', () {
      expect(
        source.contains('final int? nodeNum;'),
        true,
        reason:
            'EnvironmentMetricsLogScreen must expose nodeNum so Node Details '
            'can open a per-node view.',
      );
      expect(
        source.contains(
          'const EnvironmentMetricsLogScreen({super.key, this.nodeNum})',
        ),
        true,
        reason: 'Constructor must accept nodeNum as an optional named arg.',
      );
    });

    test('routes to the per-node provider when scoped', () {
      expect(
        source.contains('nodeEnvironmentMetricsLogsProvider'),
        true,
        reason:
            'Scoped builds must read from nodeEnvironmentMetricsLogsProvider, '
            'not the global environmentMetricsLogsProvider.',
      );
    });
  });
}
