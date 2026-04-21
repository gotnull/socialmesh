// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Telemetry drawer entry', () {
    final mainShellFile = File('lib/features/navigation/main_shell.dart');

    late String source;

    setUpAll(() {
      expect(
        mainShellFile.existsSync(),
        true,
        reason: 'main_shell.dart must exist',
      );
      source = mainShellFile.readAsStringSync();
    });

    test('imports the TelemetryHubScreen', () {
      expect(
        source.contains("import '../telemetry/telemetry_hub_screen.dart';"),
        true,
        reason:
            'main_shell must import TelemetryHubScreen so the drawer entry can navigate to it.',
      );
    });

    test('renders the Telemetry drawer entry unconditionally', () {
      expect(
        source.contains('label: l10n.navigationTelemetry'),
        true,
        reason:
            'Drawer entry must use the localized navigationTelemetry label.',
      );
      expect(
        source.contains('screen: const TelemetryHubScreen()'),
        true,
        reason: 'Drawer entry must navigate to TelemetryHubScreen.',
      );
    });

    test('owns the Tools section header', () {
      // Find the Telemetry entry and assert it sets sectionHeader=Tools.
      final telemetryBlockStart = source.indexOf(
        'label: l10n.navigationTelemetry',
      );
      expect(
        telemetryBlockStart > 0,
        true,
        reason: 'Telemetry drawer entry must exist.',
      );

      // Look within a small window around the entry for the section header.
      final windowStart = (telemetryBlockStart - 200).clamp(0, source.length);
      final windowEnd = (telemetryBlockStart + 400).clamp(0, source.length);
      final window = source.substring(windowStart, windowEnd);
      expect(
        window.contains('sectionHeader: l10n.navigationSectionTools'),
        true,
        reason:
            'Telemetry entry must own the Tools section header so downstream '
            'items do not need cascading fallbacks.',
      );
    });
  });
}
