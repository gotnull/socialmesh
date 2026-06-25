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
///   `_buildClusterLayer` helper, and the shared `ClusterListSheet` widget
///   (now in `mesh_map_widget.dart` so the route map reuses it).
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
          '    required MapTileStyle mapStyle,\n'
          '  })',
        ),
        true,
        reason:
            '_buildClusterLayer must take the markers list, a lookup '
            'map (nodeNum → _NodeWithPosition) so the cluster-list sheet '
            'can recover the underlying nodes from each marker via '
            'ValueKey<int>, AND the current MapTileStyle so the cluster '
            'disable-zoom can vary per style.',
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

    test('cluster disable-zoom is per-style and correctly wired', () {
      expect(
        source.contains(
          'disableClusteringAtZoom: MapConfig.clusterDisableZoom(mapStyle)',
        ),
        true,
        reason:
            'Clustering must disable above a per-style zoom via the package '
            "parameter that actually drives it — `disableClusteringAtZoom`. "
            'The old `maxZoom:` only affected the disabled tap-to-zoom path '
            '(zoomToBoundsOnClick: false) and was dead.',
      );
      expect(
        source.contains('maxZoom: 15'),
        false,
        reason:
            'The dead `maxZoom: 15` (no-op while zoomToBoundsOnClick is false) '
            'must be gone so future readers are not misled.',
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
        source.contains('child: ClusterListSheet('),
        true,
        reason:
            'The cluster sheet was promoted to the shared ClusterListSheet in '
            'mesh_map_widget.dart so the route map reuses it; map_screen must '
            'present that shared widget.',
      );
    });

    test('shared ClusterListSheet lives in mesh_map_widget for reuse', () {
      final widgetFile = File('lib/core/widgets/mesh_map_widget.dart');
      expect(widgetFile.existsSync(), true);
      final widgetSource = widgetFile.readAsStringSync();
      expect(
        widgetSource.contains('class ClusterListSheet extends StatelessWidget'),
        true,
        reason:
            'The tap-to-list sheet must be a shared public widget so both the '
            'main map and the route detail map render an identical sheet.',
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
