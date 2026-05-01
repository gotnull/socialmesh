// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/world_mesh/world_mesh_filters.dart';
import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/models/world_mesh_node.dart';

WorldMeshNode _node({
  required int nodeNum,
  String longName = 'Node',
  String shortName = 'NODE',
  String hwModel = 'TBEAM',
  String role = 'CLIENT',
  String? fwVersion,
  String? region,
  String? modemPreset,
  int? batteryLevel,
  double? temperature,
  double? relativeHumidity,
  // Recent lastHeard so presenceConfidence is `active`.
  int? lastHeard,
}) {
  return WorldMeshNode(
    nodeNum: nodeNum,
    longName: longName,
    shortName: shortName,
    hwModel: hwModel,
    role: role,
    latitude: 0,
    longitude: 0,
    fwVersion: fwVersion,
    region: region,
    modemPreset: modemPreset,
    batteryLevel: batteryLevel,
    temperature: temperature,
    relativeHumidity: relativeHumidity,
    lastDeviceMetrics: lastHeard,
    seenBy: const {},
  );
}

void main() {
  group('WorldMeshFilters.apply (single-pass)', () {
    final nodes = [
      _node(
        nodeNum: 1,
        longName: 'Alpha Tower',
        hwModel: 'TBEAM',
        region: 'EU_868',
        role: 'ROUTER',
        fwVersion: '2.5.0',
        modemPreset: 'LONG_FAST',
        batteryLevel: 80,
        temperature: 21.0,
      ),
      _node(
        nodeNum: 2,
        longName: 'Bravo Mobile',
        hwModel: 'HELTEC_V3',
        region: 'US',
        role: 'CLIENT',
        fwVersion: '2.4.0',
        modemPreset: 'MEDIUM_SLOW',
      ),
      _node(
        nodeNum: 3,
        longName: 'Charlie Sensor',
        hwModel: 'TBEAM',
        region: 'EU_868',
        role: 'ROUTER',
        fwVersion: '2.5.0',
        modemPreset: 'LONG_FAST',
        batteryLevel: 50,
        temperature: 18.0,
        relativeHumidity: 60.0,
      ),
    ];

    test('returns same instance when no filters and no search', () {
      const filters = WorldMeshFilters();
      final out = filters.apply(nodes);
      expect(identical(out, nodes), isTrue);
    });

    test('applies search query against multiple fields', () {
      final filtered = const WorldMeshFilters(
        searchQuery: 'bravo',
      ).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [2]);
    });

    test('applies hardware filter', () {
      final filtered = const WorldMeshFilters(
        hardwareFilter: {'TBEAM'},
      ).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [1, 3]);
    });

    test('combines multiple filters with AND semantics', () {
      final filtered = const WorldMeshFilters(
        hardwareFilter: {'TBEAM'},
        regionFilter: {'EU_868'},
        roleFilter: {'ROUTER'},
        firmwareFilter: {'2.5.0'},
        modemPresetFilter: {'LONG_FAST'},
      ).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [1, 3]);
    });

    test('hasBattery=true keeps only nodes with batteryLevel set', () {
      final filtered = const WorldMeshFilters(hasBattery: true).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [1, 3]);
    });

    test('hasBattery=false keeps only nodes without batteryLevel', () {
      final filtered = const WorldMeshFilters(hasBattery: false).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [2]);
    });

    test('hasEnvironmentSensors=true matches any env sensor field', () {
      final filtered = const WorldMeshFilters(
        hasEnvironmentSensors: true,
      ).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [1, 3]);
    });

    test('search + hardware combine', () {
      final filtered = const WorldMeshFilters(
        searchQuery: 'charlie',
        hardwareFilter: {'TBEAM'},
      ).apply(nodes);
      expect(filtered.map((n) => n.nodeNum), [3]);
    });

    test('no match returns empty list', () {
      final filtered = const WorldMeshFilters(
        hardwareFilter: {'NRF52'},
      ).apply(nodes);
      expect(filtered, isEmpty);
    });

    test('status filter respects presenceConfidence', () {
      final filtered = WorldMeshFilters(
        statusFilter: const {PresenceConfidence.unknown},
      ).apply(nodes);
      // All test nodes lack lastDeviceMetrics → presenceConfidence==unknown.
      expect(filtered.length, nodes.length);
    });
  });
}
