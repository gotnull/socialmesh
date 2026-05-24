// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

// Inter-node distance label toggle.
//
// _buildDistanceLabels draws pink pill-shaped distance badges at the
// midpoint of each line between the user's node and every neighbour
// within 15km. Pre-toggle the layer was unconditional and the pills
// frequently covered satellite-mode place names. The toggle defaults
// to ON so existing users see the same behaviour; turning it OFF
// hides the layer without affecting range circles or connection
// lines.
void main() {
  group('SettingsService — mapShowDistanceLabels', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to true for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.mapShowDistanceLabels, true);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setMapShowDistanceLabels(false);

      final b = SettingsService();
      await b.init();
      expect(b.mapShowDistanceLabels, false);
    });
  });

  group('map_screen distance-labels wiring — source pins', () {
    final mapFile = File('lib/features/map/map_screen.dart');
    late String source;

    setUpAll(() {
      expect(mapFile.existsSync(), true);
      source = mapFile.readAsStringSync();
    });

    test(
      'state field _showDistanceLabels exists + persists via SettingsService',
      () {
        expect(
          source.contains('bool _showDistanceLabels = true;'),
          true,
          reason:
              'The toggle must default to true so users who never open the '
              'menu keep seeing the inter-node distance pills.',
        );
        expect(
          source.contains('settings.mapShowDistanceLabels'),
          true,
          reason:
              'On load, the screen must read the setting so the user-saved '
              'preference is restored.',
        );
        expect(
          source.contains(
            'settings.setMapShowDistanceLabels(_showDistanceLabels)',
          ),
          true,
          reason:
              '_saveMapLayerSettings must persist the toggle alongside the '
              'other map-layer prefs.',
        );
      },
    );

    test('menu emits the toggle case + popup item', () {
      expect(source.contains("case 'distance_labels':"), true);
      expect(source.contains("value: 'distance_labels',"), true);
      expect(
        source.contains('context.l10n.mapHideDistanceLabels') &&
            source.contains('context.l10n.mapShowDistanceLabels'),
        true,
        reason:
            'Both label states must be wired so the menu reads "Show ..." '
            'when off and "Hide ..." when on.',
      );
    });

    test('distance labels MarkerLayer is gated on _showDistanceLabels', () {
      expect(
        source.contains('if (!widget.locationOnlyMode && _showDistanceLabels)'),
        true,
        reason:
            'The MarkerLayer that renders _buildDistanceLabels must check the '
            'toggle in addition to the existing locationOnlyMode guard. '
            'Without this pin, a refactor could quietly drop the toggle and '
            'the layer would render unconditionally again.',
      );
    });
  });
}
