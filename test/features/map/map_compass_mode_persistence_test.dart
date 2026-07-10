// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/widgets/map_controls.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// Map compass mode persistence.
//
// The Map tab's State is recreated on every tab switch (the shell renders a
// fresh MapScreen rather than an IndexedStack), so an in-memory compass mode
// snaps back to north-locked every visit. The mode is persisted by enum name
// and restored in _loadMapStyle so free-rotate / follow-heading survive both
// tab switches and app relaunches.
void main() {
  group('SettingsService - mapCompassModeName', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to null (north-locked) for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.mapCompassModeName, isNull);
      expect(
        mapCompassModeFromName(s.mapCompassModeName),
        MapCompassMode.northLocked,
      );
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setMapCompassModeName(MapCompassMode.freeRotate.name);

      final b = SettingsService();
      await b.init();
      expect(
        mapCompassModeFromName(b.mapCompassModeName),
        MapCompassMode.freeRotate,
      );
    });
  });

  group('mapCompassModeFromName', () {
    test('parses every enum name', () {
      for (final mode in MapCompassMode.values) {
        expect(mapCompassModeFromName(mode.name), mode);
      }
    });

    test('unknown or null names fall back to north-locked', () {
      expect(mapCompassModeFromName(null), MapCompassMode.northLocked);
      expect(mapCompassModeFromName('bogus'), MapCompassMode.northLocked);
      expect(mapCompassModeFromName(''), MapCompassMode.northLocked);
    });
  });

  group('map_screen compass-mode wiring - source pins', () {
    final mapFile = File('lib/features/map/map_screen.dart');
    late String source;

    setUpAll(() {
      expect(mapFile.existsSync(), true);
      source = mapFile.readAsStringSync();
    });

    test('settings load restores the saved compass mode', () {
      expect(
        source.contains('_restoreCompassMode(settings.mapCompassModeName)'),
        true,
        reason:
            '_loadMapStyle must re-apply the persisted compass mode when the '
            'Map tab State is recreated, otherwise the mode silently resets '
            'to north-locked on every tab switch.',
      );
    });

    test('every user-driven mode change persists', () {
      final persistCalls = 'unawaited(_persistCompassMode())'
          .allMatches(source)
          .length;
      expect(
        persistCalls >= 3,
        true,
        reason:
            'The three user-driven transitions (north-locked -> free-rotate '
            'in _onCompassTap, follow-heading in _enableHeadingUp, and the '
            'reset in _resetToNorthLocked) must each persist the new mode; '
            'found $persistCalls persist call(s).',
      );
    });
  });
}
