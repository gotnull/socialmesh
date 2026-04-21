// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetryHubScreen', () {
    final hubFile = File('lib/features/telemetry/telemetry_hub_screen.dart');

    late String source;

    setUpAll(() {
      expect(
        hubFile.existsSync(),
        true,
        reason: 'telemetry_hub_screen.dart must exist',
      );
      source = hubFile.readAsStringSync();
    });

    test('uses GlassScaffold (no raw Scaffold)', () {
      expect(
        source.contains('GlassScaffold'),
        true,
        reason: 'Hub screen must use GlassScaffold per the UI invariant.',
      );
      expect(
        source.contains('class TelemetryHubScreen extends StatelessWidget'),
        true,
        reason: 'Hub screen must be a StatelessWidget (pure UI, no state).',
      );
    });

    test('navigates to every telemetry log screen', () {
      const expectedTargets = <String>[
        'DeviceMetricsLogScreen',
        'EnvironmentMetricsLogScreen',
        'AirQualityLogScreen',
        'PositionLogScreen',
        'TraceRouteLogScreen',
        'PaxCounterLogScreen',
        'DetectionSensorLogScreen',
        'RoutesScreen',
      ];

      for (final target in expectedTargets) {
        expect(
          source.contains('const $target('),
          true,
          reason:
              'Hub must expose a tile that navigates to $target so that '
              'Settings > Telemetry Logs and the new drawer path stay in parity.',
        );
      }
    });

    test(
      'reuses the existing settingsTile* ARB keys (no new tile strings)',
      () {
        const expectedKeys = <String>[
          'settingsTileDeviceMetricsTitle',
          'settingsTileEnvironmentMetricsTitle',
          'settingsTileAirQualityTitle',
          'settingsTilePositionHistoryTitle',
          'settingsTileTracerouteHistoryTitle',
          'settingsTilePaxCounterLogsTitle',
          'settingsTileDetectionSensorLogsTitle',
          'settingsTileRoutesTitle',
        ];

        for (final key in expectedKeys) {
          expect(
            source.contains('l10n.$key'),
            true,
            reason:
                'Hub must reuse the ARB key $key so translators do not have '
                'to re-translate identical tile copy.',
          );
        }
      },
    );
  });
}
