// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

// Node overlay opacity ("Node transparency" map layer option).
//
// Peer markers on the Mesh Map are wrapped in Opacity(_nodeOverlayOpacity).
// The per-node marker cache reuses built Marker instances, so the cache key
// must include the opacity: markers built during the async gap between
// initState and the settings load are cached at the default 1.0, and if the
// key ignored opacity they would stay opaque after the saved value (e.g.
// 0.65) arrives, while nodes that update later rebuild faded. That mix is
// exactly the reported symptom - some nodes transparent, some opaque after
// reopening the app with no settings changed.
void main() {
  group('SettingsService - mapNodeOverlayOpacity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to fully opaque for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.mapNodeOverlayOpacity, 1.0);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setMapNodeOverlayOpacity(0.65);

      final b = SettingsService();
      await b.init();
      expect(b.mapNodeOverlayOpacity, 0.65);
    });

    test('setter clamps to the 0.2-1.0 slider range', () async {
      final s = SettingsService();
      await s.init();

      await s.setMapNodeOverlayOpacity(0.05);
      expect(s.mapNodeOverlayOpacity, 0.2);

      await s.setMapNodeOverlayOpacity(1.5);
      expect(s.mapNodeOverlayOpacity, 1.0);
    });
  });

  group('map_screen overlay-opacity wiring - source pins', () {
    final mapFile = File('lib/features/map/map_screen.dart');
    late String source;

    setUpAll(() {
      expect(mapFile.existsSync(), true);
      source = mapFile.readAsStringSync();
    });

    test('marker cache key tracks overlay opacity', () {
      expect(
        source.contains('required double overlayOpacity,'),
        true,
        reason:
            '_CachedNodeMarker.matches must take the current overlay opacity. '
            'Without it, markers cached at the default 1.0 before the async '
            'settings load survive the load and render opaque next to peers '
            'rebuilt at the saved opacity.',
      );
      expect(
        source.contains('this.overlayOpacity == overlayOpacity'),
        true,
        reason:
            'matches must compare the cached opacity against the current '
            'screen value so an opacity change invalidates every entry.',
      );
    });

    test('_markersFor passes the live opacity into the cache', () {
      expect(
        source.contains('overlayOpacity: _nodeOverlayOpacity,'),
        true,
        reason:
            'Both the matches() call and the _CachedNodeMarker construction '
            'must use _nodeOverlayOpacity, otherwise the key check above is '
            'dead code.',
      );
    });

    test('settings load restores the saved opacity', () {
      expect(
        source.contains('_nodeOverlayOpacity = settings.mapNodeOverlayOpacity'),
        true,
        reason:
            '_loadMapStyle must seed the screen field from SettingsService so '
            'the saved transparency survives an app relaunch.',
      );
    });
  });
}
