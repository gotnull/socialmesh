// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

/// Mesh-map clustering (Section E follow-up).
///
/// Covers:
/// - The `mapClusterMarkers` SharedPreferences setting round-trip on
///   [SettingsService].
/// - Source pins on `map_screen.dart` for the cluster wiring: the
///   `MarkerClusterLayerWidget` import, the menu toggle, the
///   `_buildClusterLayer` helper, and the `_ClusterListSheet` widget.
void main() {
  group('SettingsService — mapClusterMarkers', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false for fresh installs', () async {
      final s = SettingsService();
      await s.init();
      expect(s.mapClusterMarkers, false);
    });

    test('setter round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setMapClusterMarkers(true);

      final b = SettingsService();
      await b.init();
      expect(b.mapClusterMarkers, true);
    });
  });

  group('map_screen clustering wiring — source pins', () {
    final mapFile = File('lib/features/map/map_screen.dart');
    late String source;

    setUpAll(() {
      expect(mapFile.existsSync(), true);
      source = mapFile.readAsStringSync();
    });

    test('imports flutter_map_marker_cluster', () {
      expect(
        source.contains(
          "import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';",
        ),
        true,
        reason:
            'Clustering requires the dedicated package import (same one the '
            'World Map uses). Without it the layer cannot be constructed.',
      );
    });

    test(
      'state field _clusterMarkers exists + persists via SettingsService',
      () {
        expect(
          source.contains('bool _clusterMarkers = false;'),
          true,
          reason:
              'The cluster toggle must hold its state on the screen so the '
              'menu can flip it without rebuilding the entire MapScreen.',
        );
        expect(
          source.contains('settings.mapClusterMarkers'),
          true,
          reason:
              'On load, the screen must read the setting so the user-saved '
              'preference is restored.',
        );
        expect(
          source.contains('settings.setMapClusterMarkers(_clusterMarkers)'),
          true,
          reason:
              '_saveMapLayerSettings must persist the toggle alongside the '
              'other map-layer prefs.',
        );
      },
    );

    test('menu emits the toggle case + popup item', () {
      expect(source.contains("case 'cluster_markers':"), true);
      expect(source.contains("value: 'cluster_markers',"), true);
      expect(
        source.contains('context.l10n.mapHideClusterMarkers') &&
            source.contains('context.l10n.mapShowClusterMarkers'),
        true,
        reason:
            'Both label states must be wired so the menu reads "Show ..." '
            'when off and "Hide ..." when on.',
      );
    });

    test('_buildClusterLayer is defined + invoked when clustering is on', () {
      expect(
        source.contains(
          'Widget _buildClusterLayer({\n'
          '    required BuildContext context,\n'
          '    required List<Marker> markers,\n'
          '    required Map<int, _NodeWithPosition> nodesByNum,\n'
          '  })',
        ),
        true,
        reason:
            '_buildClusterLayer must take the markers list AND a lookup '
            'map (nodeNum → _NodeWithPosition) so the cluster-list sheet '
            'can recover the underlying nodes from each marker via '
            'ValueKey<int>.',
      );
      expect(source.contains('MarkerClusterLayerWidget('), true);
      expect(
        source.contains('return _buildClusterLayer('),
        true,
        reason:
            'The marker render must dispatch to _buildClusterLayer when '
            '_clusterMarkers is true.',
      );
    });

    test('cluster tap opens the tap-to-list sheet (no zoom-on-click)', () {
      expect(
        source.contains('zoomToBoundsOnClick: false'),
        true,
        reason:
            'Default zoom-on-click is disabled so taps surface the list '
            'sheet instead of camera-jumping.',
      );
      expect(
        source.contains('_showClusterListSheet('),
        true,
        reason: 'The cluster builder must wire its onTap to the list sheet.',
      );
      expect(
        source.contains('class _ClusterListSheet extends StatelessWidget'),
        true,
        reason:
            'The list sheet widget must exist as a private class in this '
            'file.',
      );
    });

    test(
      'markers carry ValueKey<int>(nodeNum) so the sheet can recover nodes',
      () {
        expect(
          source.contains('key: ValueKey<int>(n.node.nodeNum),'),
          true,
          reason:
              'Each Marker must encode its source node id via ValueKey<int> '
              'so the cluster-list sheet can map back from cluster.markers '
              'to MeshNode without doing fragile lat/lng comparison.',
        );
      },
    );
  });
}
