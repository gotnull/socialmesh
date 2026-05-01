// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the NodeDex Constellation domain layer (provider builder
// + adapter). Exercises the contract documented in
// CLAUDE.md / the feature spec: deterministic ordering, stable IDs,
// safe handling of missing/sparse data, RF-only and inferred-edge
// filters, and message-content non-leakage.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/node_constellation/node_constellation_models.dart';
import 'package:socialmesh/features/nodedex/node_constellation/node_constellation_provider.dart';
import 'package:socialmesh/models/mesh_models.dart';

NodeDexEntry _makeEntry({
  int nodeNum = 0x1111,
  DateTime? firstSeen,
  DateTime? lastSeen,
  int encounterCount = 0,
  int messageCount = 0,
  List<EncounterRecord> encounters = const [],
}) {
  final first = firstSeen ?? DateTime(2026, 1, 1);
  final last = lastSeen ?? DateTime(2026, 1, 1);
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: first,
    lastSeen: last,
    encounterCount: encounterCount,
    messageCount: messageCount,
    encounters: encounters,
  );
}

MeshNode _makeNode({
  int nodeNum = 0x1111,
  DateTime? lastHeard,
  bool viaMqtt = false,
  int? hopCount,
  int? lastHeardChannel,
  double? latitude,
  double? longitude,
  int? batteryLevel,
  bool isFavorite = false,
}) {
  return MeshNode(
    nodeNum: nodeNum,
    lastHeard: lastHeard,
    hopCount: hopCount,
    viaMqtt: viaMqtt,
    lastHeardChannel: lastHeardChannel,
    latitude: latitude,
    longitude: longitude,
    batteryLevel: batteryLevel,
    isFavorite: isFavorite,
  );
}

const _now = NodeDexConstellationTimeWindow.all;
final _testNow = DateTime(2026, 5, 1, 12, 0, 0);

NodeDexConstellation _build({
  required int centerNodeNum,
  NodeDexEntry? entry,
  MeshNode? node,
  List<ChannelConfig> channels = const [],
  NodeDexConstellationFilter filter = const NodeDexConstellationFilter(
    timeWindow: _now,
  ),
}) {
  return buildNodeDexConstellation(
    centerNodeNum: centerNodeNum,
    entry: entry,
    node: node,
    channels: channels,
    filter: filter,
    now: _testNow,
  );
}

void main() {
  group('buildNodeDexConstellation — sparse data', () {
    test('node with no entry and no live mesh node returns missingEntry', () {
      final c = _build(centerNodeNum: 0x9999);
      expect(c.isEmpty, isTrue);
      expect(c.emptyReason, NodeDexConstellationEmptyReason.missingEntry);
      expect(c.nodes, isEmpty);
      expect(c.edges, isEmpty);
    });

    test(
      'entry with no extra data still produces identity + safe action nodes',
      () {
        final entry = _makeEntry();
        final c = _build(centerNodeNum: entry.nodeNum, entry: entry);
        expect(c.isEmpty, isFalse);
        expect(c.centerNode, isNotNull);
        expect(c.centerNode!.type, NodeDexGraphNodeType.identity);
        // No messages/encounters: only identity card + the always-on
        // action cards (message, favourite, inspect — no map without
        // coordinates).
        final actionTypes = c.nodes
            .where((n) => n.type == NodeDexGraphNodeType.action)
            .map((n) => n.action)
            .toSet();
        expect(actionTypes, contains(NodeDexGraphAction.message));
        expect(actionTypes, contains(NodeDexGraphAction.toggleFavourite));
        expect(actionTypes, contains(NodeDexGraphAction.inspectDetails));
        expect(actionTypes, isNot(contains(NodeDexGraphAction.viewOnMap)));
      },
    );

    test('missing telemetry does not crash', () {
      final entry = _makeEntry();
      final node = _makeNode(); // no telemetry fields set
      final c = _build(centerNodeNum: entry.nodeNum, entry: entry, node: node);
      // Telemetry node should be absent when no telemetry data is
      // available, and the build should still succeed.
      expect(
        c.nodes.where((n) => n.type == NodeDexGraphNodeType.telemetry),
        isEmpty,
      );
    });

    test(
      'missing encounters produces partial state with no encounter card',
      () {
        final entry = _makeEntry();
        final node = _makeNode(batteryLevel: 87);
        final c = _build(
          centerNodeNum: entry.nodeNum,
          entry: entry,
          node: node,
        );
        // entry.encounterCount is 0, so encounter card is suppressed.
        expect(
          c.nodes.where((n) => n.type == NodeDexGraphNodeType.encounter),
          isEmpty,
        );
        // Telemetry still surfaces from the live node.
        expect(
          c.nodes.where((n) => n.type == NodeDexGraphNodeType.telemetry),
          hasLength(1),
        );
      },
    );
  });

  group('filters', () {
    test(
      'rfOnly hides MQTT route evidence and MQTT-tagged surrounding cards',
      () {
        final entry = _makeEntry(encounterCount: 3);
        final node = _makeNode(
          viaMqtt: true,
          hopCount: 2,
          batteryLevel: 50,
          lastHeard: _testNow,
        );
        final all = _build(
          centerNodeNum: entry.nodeNum,
          entry: entry,
          node: node,
        );
        // With MQTT included we should see a "MQTT path" route node.
        expect(
          all.nodes.where((n) => n.type == NodeDexGraphNodeType.routeEvidence),
          isNotEmpty,
        );
        final rfOnly = _build(
          centerNodeNum: entry.nodeNum,
          entry: entry,
          node: node,
          filter: const NodeDexConstellationFilter(
            rfOnly: true,
            timeWindow: _now,
          ),
        );
        expect(
          rfOnly.nodes.where(
            (n) => n.type == NodeDexGraphNodeType.routeEvidence,
          ),
          isEmpty,
        );
        // No edge in the rfOnly graph is allowed to carry MQTT-sourced
        // evidence.
        expect(rfOnly.edges.any((e) => e.viaMqtt), isFalse);
        // Centre identity must remain even with rfOnly.
        expect(rfOnly.centerNode, isNotNull);
      },
    );

    test('inferred edges are hidden when showInferred=false', () {
      // When the route-evidence card is present, the builder also
      // creates an inferred edge from route → encounter. We seed
      // both sides of that edge.
      final entry = _makeEntry(
        encounterCount: 4,
        encounters: [EncounterRecord(timestamp: _testNow)],
        lastSeen: _testNow,
      );
      final node = _makeNode(hopCount: 1, lastHeard: _testNow);
      final withInferred = _build(
        centerNodeNum: entry.nodeNum,
        entry: entry,
        node: node,
      );
      expect(
        withInferred.edges.any((e) => e.type == NodeDexGraphEdgeType.inferred),
        isTrue,
      );
      final hidden = _build(
        centerNodeNum: entry.nodeNum,
        entry: entry,
        node: node,
        filter: const NodeDexConstellationFilter(
          showInferred: false,
          timeWindow: _now,
        ),
      );
      expect(
        hidden.edges.any((e) => e.type == NodeDexGraphEdgeType.inferred),
        isFalse,
      );
    });
  });

  group('determinism', () {
    test('graph IDs are stable across rebuilds', () {
      final entry = _makeEntry(encounterCount: 1, lastSeen: _testNow);
      final node = _makeNode(hopCount: 0, lastHeard: _testNow);
      final a = _build(centerNodeNum: entry.nodeNum, entry: entry, node: node);
      final b = _build(centerNodeNum: entry.nodeNum, entry: entry, node: node);
      expect(
        a.nodes.map((n) => n.id).toList(),
        equals(b.nodes.map((n) => n.id).toList()),
      );
      expect(
        a.edges.map((e) => e.id).toList(),
        equals(b.edges.map((e) => e.id).toList()),
      );
    });

    test('graph node order matches the documented sort priority', () {
      final entry = _makeEntry(encounterCount: 2, lastSeen: _testNow);
      final node = _makeNode(
        hopCount: 1,
        lastHeard: _testNow,
        latitude: 1,
        longitude: 1,
        batteryLevel: 80,
      );
      final c = _build(centerNodeNum: entry.nodeNum, entry: entry, node: node);
      // Verify the comparator is honoured pairwise.
      for (var i = 1; i < c.nodes.length; i++) {
        expect(
          NodeDexGraphSortPriority.compare(c.nodes[i - 1], c.nodes[i]),
          lessThanOrEqualTo(0),
          reason:
              'Nodes must be in non-decreasing comparator order at index $i',
        );
      }
    });
  });

  group('action node generation', () {
    test('viewOnMap is only generated when coordinates exist', () {
      final entry = _makeEntry();
      final withoutCoords = _build(
        centerNodeNum: entry.nodeNum,
        entry: entry,
        node: _makeNode(),
      );
      expect(
        withoutCoords.nodes.any(
          (n) => n.action == NodeDexGraphAction.viewOnMap,
        ),
        isFalse,
      );
      final withCoords = _build(
        centerNodeNum: entry.nodeNum,
        entry: entry,
        node: _makeNode(latitude: 51.5, longitude: -0.12),
      );
      expect(
        withCoords.nodes.any((n) => n.action == NodeDexGraphAction.viewOnMap),
        isTrue,
      );
    });

    test('every action node has its action and target set', () {
      final entry = _makeEntry();
      final c = _build(centerNodeNum: entry.nodeNum, entry: entry);
      for (final n in c.nodes.where(
        (n) => n.type == NodeDexGraphNodeType.action,
      )) {
        expect(n.action, isNotNull);
        expect(n.targetNodeNum, equals(entry.nodeNum));
      }
    });
  });

  group('privacy', () {
    test('no message body or content is leaked into graph labels', () {
      final entry = _makeEntry(messageCount: 5, lastSeen: _testNow);
      final c = _build(centerNodeNum: entry.nodeNum, entry: entry);
      final messageNodes = c.nodes.where(
        (n) => n.type == NodeDexGraphNodeType.message,
      );
      expect(messageNodes, hasLength(1));
      final m = messageNodes.first;
      // Subtitle conveys count only, not body. Label is generic.
      expect(m.label.toLowerCase(), 'messages');
      expect(m.subtitle, contains('5'));
      // Details must not contain message text.
      for (final d in m.details) {
        expect(d.value, isNot(contains('hello')));
      }
    });
  });
}
