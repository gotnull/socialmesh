// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/map/nodedex_map_adapter.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/models/mesh_models.dart';

NodeDexEntry _entry({
  required int nodeNum,
  required DateTime lastSeen,
  List<EncounterRecord> encounters = const [],
  String? lastKnownName,
}) {
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: lastSeen,
    lastSeen: lastSeen,
    encounters: encounters,
    lastKnownName: lastKnownName,
  );
}

MeshNode _node({
  required int nodeNum,
  double? lat,
  double? lon,
  DateTime? lastHeard,
  bool isFavorite = false,
  String? shortName,
  String? longName,
  double? distance,
}) {
  return MeshNode(
    nodeNum: nodeNum,
    latitude: lat,
    longitude: lon,
    lastHeard: lastHeard,
    positionTimestamp: lastHeard,
    isFavorite: isFavorite,
    shortName: shortName,
    longName: longName,
    distance: distance,
  );
}

void main() {
  final now = DateTime.utc(2026, 4, 29, 12);

  group('NodeDexMapAdapter.project', () {
    test('uses live MeshNode position when available', () {
      final entry = _entry(nodeNum: 1, lastSeen: now);
      final node = _node(nodeNum: 1, lat: 37.4, lon: -122.1, lastHeard: now);

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, node)],
        myNodeNum: null,
        now: now,
      );

      expect(result.markers, hasLength(1));
      expect(result.markers.first.latitude, 37.4);
      expect(result.markers.first.longitude, -122.1);
      expect(result.excludedNoPosition, 0);
    });

    test('falls back to most recent encounter with coordinates', () {
      final older = now.subtract(const Duration(hours: 6));
      final newer = now.subtract(const Duration(hours: 1));
      final entry = _entry(
        nodeNum: 2,
        lastSeen: newer,
        encounters: [
          EncounterRecord(timestamp: older, latitude: 1.0, longitude: 2.0),
          EncounterRecord(timestamp: newer, latitude: 10.0, longitude: 20.0),
        ],
      );

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, null)],
        myNodeNum: null,
        now: now,
      );

      expect(result.markers, hasLength(1));
      expect(result.markers.first.latitude, 10.0);
      expect(result.markers.first.longitude, 20.0);
    });

    test('excludes entries with no resolvable position', () {
      final entry = _entry(
        nodeNum: 3,
        lastSeen: now,
        encounters: [EncounterRecord(timestamp: now)],
      );

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, null)],
        myNodeNum: null,
        now: now,
      );

      expect(result.markers, isEmpty);
      expect(result.excludedNoPosition, 1);
    });

    test('excludes the (0,0) Apple-Park / null-island sentinel', () {
      final entry = _entry(nodeNum: 4, lastSeen: now);
      final node = _node(nodeNum: 4, lat: 0.0, lon: 0.0, lastHeard: now);

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, node)],
        myNodeNum: null,
        now: now,
      );

      expect(result.markers, isEmpty);
      expect(result.excludedNoPosition, 1);
    });

    test('marks isSelf when nodeNum matches myNodeNum', () {
      final entry = _entry(nodeNum: 99, lastSeen: now);
      final node = _node(nodeNum: 99, lat: 1.0, lon: 1.0, lastHeard: now);

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, node)],
        myNodeNum: 99,
        now: now,
      );

      expect(result.markers.first.isSelf, isTrue);
    });

    test('preserves favourite flag from live MeshNode', () {
      final entry = _entry(nodeNum: 5, lastSeen: now);
      final node = _node(
        nodeNum: 5,
        lat: 1.0,
        lon: 1.0,
        lastHeard: now,
        isFavorite: true,
      );

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, node)],
        myNodeNum: null,
        now: now,
      );

      expect(result.markers.first.isFavourite, isTrue);
    });

    test('falls back to NodeDexEntry.lastKnownName when no live node', () {
      final entry = _entry(
        nodeNum: 6,
        lastSeen: now,
        encounters: [
          EncounterRecord(timestamp: now, latitude: 5.0, longitude: 5.0),
        ],
        lastKnownName: 'Cached Name',
      );

      final result = NodeDexMapAdapter.project(
        pairs: [(entry, null)],
        myNodeNum: null,
        now: now,
      );

      expect(result.markers.first.shortName, 'Cached Name');
      expect(result.markers.first.longName, 'Cached Name');
    });
  });

  group('NodeDexMapAdapter.classifyStaleness', () {
    test('within 1h is recent', () {
      expect(
        NodeDexMapAdapter.classifyStaleness(
          now.subtract(const Duration(minutes: 30)),
          now: now,
        ),
        NodeDexMapStaleness.recent,
      );
    });

    test('within 24h is fading', () {
      expect(
        NodeDexMapAdapter.classifyStaleness(
          now.subtract(const Duration(hours: 12)),
          now: now,
        ),
        NodeDexMapStaleness.fading,
      );
    });

    test('within 7d is stale', () {
      expect(
        NodeDexMapAdapter.classifyStaleness(
          now.subtract(const Duration(days: 3)),
          now: now,
        ),
        NodeDexMapStaleness.stale,
      );
    });

    test('older than 7d is unknown', () {
      expect(
        NodeDexMapAdapter.classifyStaleness(
          now.subtract(const Duration(days: 30)),
          now: now,
        ),
        NodeDexMapStaleness.unknown,
      );
    });

    test('future timestamps are treated as recent', () {
      expect(
        NodeDexMapAdapter.classifyStaleness(
          now.add(const Duration(minutes: 5)),
          now: now,
        ),
        NodeDexMapStaleness.recent,
      );
    });
  });

  group('NodeDexMapAdapter.applyFilter', () {
    NodeDexMapMarker buildMarker({
      required int nodeNum,
      required DateTime lastHeard,
      bool isSelf = false,
      bool isFavourite = false,
    }) {
      return NodeDexMapMarker(
        nodeNum: nodeNum,
        shortName: null,
        longName: null,
        latitude: 1.0,
        longitude: 1.0,
        lastHeard: lastHeard,
        isSelf: isSelf,
        isFavourite: isFavourite,
        distanceMeters: null,
        staleness: NodeDexMapAdapter.classifyStaleness(lastHeard, now: now),
        liveNode: null,
      );
    }

    test('1h window keeps only nodes heard within the last hour', () {
      final markers = [
        buildMarker(
          nodeNum: 1,
          lastHeard: now.subtract(const Duration(minutes: 30)),
        ),
        buildMarker(
          nodeNum: 2,
          lastHeard: now.subtract(const Duration(hours: 5)),
        ),
      ];

      final filtered = NodeDexMapAdapter.applyFilter(
        markers: markers,
        filter: const NodeDexMapFilter(timeWindow: NodeDexMapTimeWindow.hour1),
        now: now,
      );

      expect(filtered.map((m) => m.nodeNum), [1]);
    });

    test('all window keeps every marker', () {
      final markers = [
        buildMarker(
          nodeNum: 1,
          lastHeard: now.subtract(const Duration(days: 30)),
        ),
        buildMarker(nodeNum: 2, lastHeard: now),
      ];

      final filtered = NodeDexMapAdapter.applyFilter(
        markers: markers,
        filter: const NodeDexMapFilter(timeWindow: NodeDexMapTimeWindow.all),
        now: now,
      );

      expect(filtered, hasLength(2));
    });

    test('self marker is always kept regardless of time window', () {
      final markers = [
        buildMarker(
          nodeNum: 1,
          lastHeard: now.subtract(const Duration(days: 365)),
          isSelf: true,
        ),
        buildMarker(
          nodeNum: 2,
          lastHeard: now.subtract(const Duration(days: 365)),
        ),
      ];

      final filtered = NodeDexMapAdapter.applyFilter(
        markers: markers,
        filter: const NodeDexMapFilter(timeWindow: NodeDexMapTimeWindow.hour1),
        now: now,
      );

      expect(filtered.map((m) => m.nodeNum), [1]);
    });

    test('favouritesOnly filter excludes non-favourites', () {
      final markers = [
        buildMarker(nodeNum: 1, lastHeard: now, isFavourite: true),
        buildMarker(nodeNum: 2, lastHeard: now, isFavourite: false),
      ];

      final filtered = NodeDexMapAdapter.applyFilter(
        markers: markers,
        filter: const NodeDexMapFilter(favouritesOnly: true),
        now: now,
      );

      expect(filtered.map((m) => m.nodeNum), [1]);
    });

    test('favouritesOnly still keeps the self marker', () {
      final markers = [
        buildMarker(nodeNum: 1, lastHeard: now, isSelf: true),
        buildMarker(nodeNum: 2, lastHeard: now),
      ];

      final filtered = NodeDexMapAdapter.applyFilter(
        markers: markers,
        filter: const NodeDexMapFilter(favouritesOnly: true),
        now: now,
      );

      expect(filtered.map((m) => m.nodeNum), [1]);
    });
  });

  group('NodeDexMapFilter', () {
    test('copyWith preserves untouched fields', () {
      const filter = NodeDexMapFilter(
        timeWindow: NodeDexMapTimeWindow.hours24,
        favouritesOnly: true,
      );
      final next = filter.copyWith(timeWindow: NodeDexMapTimeWindow.all);
      expect(next.timeWindow, NodeDexMapTimeWindow.all);
      expect(next.favouritesOnly, isTrue);
    });

    test('equality and hashCode match by value', () {
      const a = NodeDexMapFilter(timeWindow: NodeDexMapTimeWindow.days7);
      const b = NodeDexMapFilter(timeWindow: NodeDexMapTimeWindow.days7);
      const c = NodeDexMapFilter(favouritesOnly: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
