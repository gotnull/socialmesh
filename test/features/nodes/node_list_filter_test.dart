// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';

/// Applies the same filter logic used by the NodesScreen._applyFilter method.
/// Extracted here so we can unit-test filtering without widget dependencies.
List<MeshNode> applyTransportFilter(
  List<MeshNode> nodes, {
  required bool rfOnly,
  required bool mqttOnly,
}) {
  if (rfOnly) return nodes.where((n) => !n.viaMqtt).toList();
  if (mqttOnly) return nodes.where((n) => n.viaMqtt).toList();
  return nodes;
}

void main() {
  late List<MeshNode> testNodes;

  setUp(() {
    testNodes = [
      MeshNode(
        nodeNum: 1,
        longName: 'RF Direct',
        shortName: 'RF1',
        viaMqtt: false,
        rssi: -75,
        hopCount: 0,
      ),
      MeshNode(
        nodeNum: 2,
        longName: 'RF Relay',
        shortName: 'RF2',
        viaMqtt: false,
        rssi: -92,
        hopCount: 2,
      ),
      MeshNode(
        nodeNum: 3,
        longName: 'MQTT Cloud',
        shortName: 'MQ1',
        viaMqtt: true,
        rssi: null,
        hopCount: null,
      ),
      MeshNode(
        nodeNum: 4,
        longName: 'MQTT Bridge',
        shortName: 'MQ2',
        viaMqtt: true,
        rssi: -88,
        hopCount: 1,
      ),
      MeshNode(
        nodeNum: 5,
        longName: 'RF Distant',
        shortName: 'RF3',
        viaMqtt: false,
        rssi: -110,
        hopCount: 5,
      ),
    ];
  });

  group('NodeFilter — All', () {
    test('returns full list when no transport filter is applied', () {
      final result = applyTransportFilter(
        testNodes,
        rfOnly: false,
        mqttOnly: false,
      );

      expect(result.length, testNodes.length);
      expect(result, testNodes);
    });

    test('returns empty list when source list is empty', () {
      final result = applyTransportFilter([], rfOnly: false, mqttOnly: false);

      expect(result, isEmpty);
    });
  });

  group('NodeFilter — RF only', () {
    test('returns only RF nodes (viaMqtt == false)', () {
      final result = applyTransportFilter(
        testNodes,
        rfOnly: true,
        mqttOnly: false,
      );

      expect(result.length, 3);
      expect(result.every((n) => !n.viaMqtt), isTrue);
      expect(result.map((n) => n.nodeNum).toList(), [1, 2, 5]);
    });

    test('returns all nodes when all are RF', () {
      final allRf = [
        MeshNode(nodeNum: 10, viaMqtt: false),
        MeshNode(nodeNum: 11, viaMqtt: false),
      ];

      final result = applyTransportFilter(allRf, rfOnly: true, mqttOnly: false);

      expect(result.length, 2);
    });

    test('returns empty list when no RF nodes exist', () {
      final allMqtt = [
        MeshNode(nodeNum: 20, viaMqtt: true),
        MeshNode(nodeNum: 21, viaMqtt: true),
      ];

      final result = applyTransportFilter(
        allMqtt,
        rfOnly: true,
        mqttOnly: false,
      );

      expect(result, isEmpty);
    });

    test('does not include MQTT nodes', () {
      final result = applyTransportFilter(
        testNodes,
        rfOnly: true,
        mqttOnly: false,
      );

      for (final node in result) {
        expect(
          node.viaMqtt,
          isFalse,
          reason: 'Node ${node.nodeNum} should not be viaMqtt',
        );
      }
    });
  });

  group('NodeFilter — MQTT only', () {
    test('returns only MQTT nodes (viaMqtt == true)', () {
      final result = applyTransportFilter(
        testNodes,
        rfOnly: false,
        mqttOnly: true,
      );

      expect(result.length, 2);
      expect(result.every((n) => n.viaMqtt), isTrue);
      expect(result.map((n) => n.nodeNum).toList(), [3, 4]);
    });

    test('returns all nodes when all are MQTT', () {
      final allMqtt = [
        MeshNode(nodeNum: 30, viaMqtt: true),
        MeshNode(nodeNum: 31, viaMqtt: true),
        MeshNode(nodeNum: 32, viaMqtt: true),
      ];

      final result = applyTransportFilter(
        allMqtt,
        rfOnly: false,
        mqttOnly: true,
      );

      expect(result.length, 3);
    });

    test('returns empty list when no MQTT nodes exist', () {
      final allRf = [
        MeshNode(nodeNum: 40, viaMqtt: false),
        MeshNode(nodeNum: 41, viaMqtt: false),
      ];

      final result = applyTransportFilter(allRf, rfOnly: false, mqttOnly: true);

      expect(result, isEmpty);
    });

    test('does not include RF nodes', () {
      final result = applyTransportFilter(
        testNodes,
        rfOnly: false,
        mqttOnly: true,
      );

      for (final node in result) {
        expect(
          node.viaMqtt,
          isTrue,
          reason: 'Node ${node.nodeNum} should be viaMqtt',
        );
      }
    });
  });

  group('NodeFilter — does not mutate source', () {
    test('RF filter does not modify the original list', () {
      final originalLength = testNodes.length;
      final originalNodeNums = testNodes.map((n) => n.nodeNum).toList();

      applyTransportFilter(testNodes, rfOnly: true, mqttOnly: false);

      expect(testNodes.length, originalLength);
      expect(testNodes.map((n) => n.nodeNum).toList(), originalNodeNums);
    });

    test('MQTT filter does not modify the original list', () {
      final originalLength = testNodes.length;
      final originalNodeNums = testNodes.map((n) => n.nodeNum).toList();

      applyTransportFilter(testNodes, rfOnly: false, mqttOnly: true);

      expect(testNodes.length, originalLength);
      expect(testNodes.map((n) => n.nodeNum).toList(), originalNodeNums);
    });
  });

  group('NodeFilter — viaMqtt default', () {
    test('nodes default to viaMqtt=false (RF) when not specified', () {
      final node = MeshNode(nodeNum: 99);
      expect(node.viaMqtt, isFalse);
    });

    test('default nodes are included in RF filter', () {
      final defaultNodes = [MeshNode(nodeNum: 50), MeshNode(nodeNum: 51)];

      final result = applyTransportFilter(
        defaultNodes,
        rfOnly: true,
        mqttOnly: false,
      );

      expect(result.length, 2);
    });

    test('default nodes are excluded from MQTT filter', () {
      final defaultNodes = [MeshNode(nodeNum: 60), MeshNode(nodeNum: 61)];

      final result = applyTransportFilter(
        defaultNodes,
        rfOnly: false,
        mqttOnly: true,
      );

      expect(result, isEmpty);
    });
  });

  group('NodeFilter — large lists', () {
    test('filters 500+ nodes without error', () {
      final largeList = List.generate(
        600,
        (i) => MeshNode(
          nodeNum: i,
          viaMqtt: i % 3 == 0, // Every 3rd node is MQTT
        ),
      );

      final rfResult = applyTransportFilter(
        largeList,
        rfOnly: true,
        mqttOnly: false,
      );
      final mqttResult = applyTransportFilter(
        largeList,
        rfOnly: false,
        mqttOnly: true,
      );
      final allResult = applyTransportFilter(
        largeList,
        rfOnly: false,
        mqttOnly: false,
      );

      expect(allResult.length, 600);
      expect(rfResult.length, 400);
      expect(mqttResult.length, 200);
      expect(rfResult.length + mqttResult.length, allResult.length);
    });
  });

  group('NodeFilter — RF + MQTT partition', () {
    test('RF and MQTT filters are a complete partition of all nodes', () {
      final rfResult = applyTransportFilter(
        testNodes,
        rfOnly: true,
        mqttOnly: false,
      );
      final mqttResult = applyTransportFilter(
        testNodes,
        rfOnly: false,
        mqttOnly: true,
      );

      final combinedNums = {
        ...rfResult.map((n) => n.nodeNum),
        ...mqttResult.map((n) => n.nodeNum),
      };

      expect(combinedNums.length, testNodes.length);
      expect(combinedNums, testNodes.map((n) => n.nodeNum).toSet());
    });

    test('RF and MQTT filters have no overlap', () {
      final rfNums = applyTransportFilter(
        testNodes,
        rfOnly: true,
        mqttOnly: false,
      ).map((n) => n.nodeNum).toSet();

      final mqttNums = applyTransportFilter(
        testNodes,
        rfOnly: false,
        mqttOnly: true,
      ).map((n) => n.nodeNum).toSet();

      expect(rfNums.intersection(mqttNums), isEmpty);
    });
  });

  group('MeshNode.copyWith — viaMqtt and hopCount', () {
    test('copyWith preserves viaMqtt when not overridden', () {
      final node = MeshNode(nodeNum: 1, viaMqtt: true);
      final copy = node.copyWith(longName: 'Updated');

      expect(copy.viaMqtt, isTrue);
    });

    test('copyWith can change viaMqtt', () {
      final node = MeshNode(nodeNum: 1, viaMqtt: false);
      final copy = node.copyWith(viaMqtt: true);

      expect(copy.viaMqtt, isTrue);
    });

    test('copyWith preserves hopCount when not overridden', () {
      final node = MeshNode(nodeNum: 1, hopCount: 3);
      final copy = node.copyWith(longName: 'Updated');

      expect(copy.hopCount, 3);
    });

    test('copyWith can change hopCount', () {
      final node = MeshNode(nodeNum: 1, hopCount: 3);
      final copy = node.copyWith(hopCount: 5);

      expect(copy.hopCount, 5);
    });
  });
}
