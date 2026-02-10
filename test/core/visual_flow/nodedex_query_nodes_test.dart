// SPDX-License-Identifier: GPL-3.0-or-later
// Tests for NodeDex query node builders and their compile-time behavior.
//
// These tests verify:
// - All NodeDex query node builders produce correctly typed nodes
// - Filter nodes chain filters into NodeListPayload
// - Sort and limit nodes modify payload metadata
// - Config serialization round-trips correctly
// - isNodeDexQueryNode identification works for all types
// - The subgroup and flat builder lists contain all expected node types

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/visual_flow/interfaces/node_list_interface.dart';
import 'package:socialmesh/core/visual_flow/nodes/nodedex_query_nodes.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/data/vs_node_data.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/data/vs_subgroup.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/special_nodes/vs_widget_node.dart';

void main() {
  const testOffset = Offset(100, 100);

  // -------------------------------------------------------------------------
  // Helper to evaluate a node's first output with given inputs
  // -------------------------------------------------------------------------
  dynamic evaluateOutput(VSNodeData node, Map<String, dynamic> inputs) {
    final output = node.outputData.first;
    return output.outputFunction?.call(inputs);
  }

  // -------------------------------------------------------------------------
  // Builder registration
  // -------------------------------------------------------------------------
  group('Builder registration', () {
    test('nodeDexQueryNodeSubgroup returns a VSSubgroup', () {
      final subgroup = nodeDexQueryNodeSubgroup();
      expect(subgroup, isA<VSSubgroup>());
      expect(subgroup.name, 'NodeDex');
    });

    test('subgroup contains 9 builders', () {
      final subgroup = nodeDexQueryNodeSubgroup();
      expect(subgroup.subgroup.length, 9);
    });

    test('allNodeDexQueryNodeBuilders returns 9 builders', () {
      final builders = allNodeDexQueryNodeBuilders();
      expect(builders.length, 9);
    });

    test('all builders produce valid VSNodeData', () {
      final builders = allNodeDexQueryNodeBuilders();
      for (final builder in builders) {
        final node = builder(testOffset, null);
        expect(node, isA<VSNodeData>());
        expect(node.widgetOffset, testOffset);
      }
    });

    test('all builders produce nodes with correct types', () {
      final builders = allNodeDexQueryNodeBuilders();
      final types = builders.map((b) => b(testOffset, null).type).toSet();

      expect(types, contains(NodeDexQueryTypes.allNodes));
      expect(types, contains(NodeDexQueryTypes.traitFilter));
      expect(types, contains(NodeDexQueryTypes.distanceFilter));
      expect(types, contains(NodeDexQueryTypes.encounterFilter));
      expect(types, contains(NodeDexQueryTypes.onlineFilter));
      expect(types, contains(NodeDexQueryTypes.batteryFilter));
      expect(types, contains(NodeDexQueryTypes.nameFilter));
      expect(types, contains(NodeDexQueryTypes.sortNodes));
      expect(types, contains(NodeDexQueryTypes.limitNodes));
    });
  });

  // -------------------------------------------------------------------------
  // Type identification
  // -------------------------------------------------------------------------
  group('isNodeDexQueryNode', () {
    test('returns true for all NodeDex query node types', () {
      final builders = allNodeDexQueryNodeBuilders();
      for (final builder in builders) {
        final node = builder(testOffset, null);
        expect(
          isNodeDexQueryNode(node),
          isTrue,
          reason:
              'Expected ${node.type} to be identified as NodeDex query node',
        );
      }
    });

    test('returns false for non-query nodes', () {
      final fakeNode = VSNodeData(
        type: 'some_other_type',
        widgetOffset: testOffset,
        inputData: [],
        outputData: [],
      );
      expect(isNodeDexQueryNode(fakeNode), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // All Nodes source node
  // -------------------------------------------------------------------------
  group('All Nodes source node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.allNodes);
    });

    test('has no inputs', () {
      expect(node.inputData, isEmpty);
    });

    test('has one NodeList output', () {
      expect(node.outputData.length, 1);
      expect(node.outputData.first, isA<NodeListOutputData>());
    });

    test('is a VSWidgetNode', () {
      expect(node, isA<VSWidgetNode>());
    });

    test('output produces a NodeListPayload with "All Nodes" description', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.queryDescription, 'All Nodes');
      expect(payload.filters, isEmpty);
      expect(payload.nodeNums, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Trait Filter node
  // -------------------------------------------------------------------------
  group('Trait Filter node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
    });

    test('has one NodeList input and one NodeList output', () {
      expect(node.inputData.length, 1);
      expect(node.inputData.first, isA<NodeListInputData>());
      expect(node.outputData.length, 1);
      expect(node.outputData.first, isA<NodeListOutputData>());
    });

    test('output chains a trait filter onto upstream payload', () {
      final upstream = const NodeListPayload(
        queryDescription: 'All Nodes',
        filters: [],
      );
      final result = evaluateOutput(node, {'node_list_in': upstream});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'trait');
      expect(payload.filters.first.operator, 'eq');
      // Default trait is 'beacon'
      expect(payload.filters.first.value, 'beacon');
      expect(payload.queryDescription, contains('Trait'));
      expect(payload.queryDescription, contains('Beacon'));
    });

    test('output handles null upstream', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'trait');
    });

    test('serialization includes config', () {
      final json = node.toJson();
      expect(json.containsKey('value'), isTrue);
      final config = json['value'];
      expect(config, isA<Map>());
      expect(config['selectedTrait'], 'beacon');
    });
  });

  // -------------------------------------------------------------------------
  // Distance Filter node
  // -------------------------------------------------------------------------
  group('Distance Filter node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.distanceFilter);
    });

    test('output chains a distance filter', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'distance');
      expect(payload.filters.first.operator, 'lt');
      expect(payload.filters.first.value, 10000.0);
      expect(payload.queryDescription, contains('Distance'));
      expect(payload.queryDescription, contains('km'));
    });

    test('serialization includes distance config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['operator'], 'lt');
      expect(config['distanceMeters'], 10000.0);
    });
  });

  // -------------------------------------------------------------------------
  // Encounter Filter node
  // -------------------------------------------------------------------------
  group('Encounter Filter node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.encounterFilter);
    });

    test('output chains an encounter filter', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'encounters');
      expect(payload.filters.first.operator, 'gte');
      expect(payload.filters.first.value, 5);
      expect(payload.queryDescription, contains('Encounters'));
    });

    test('serialization includes encounter config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['operator'], 'gte');
      expect(config['threshold'], 5);
    });
  });

  // -------------------------------------------------------------------------
  // Online Filter node
  // -------------------------------------------------------------------------
  group('Online Filter node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.onlineFilter);
    });

    test('output chains an online filter', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'online');
      expect(payload.filters.first.operator, 'eq');
      expect(payload.filters.first.value, true);
      expect(payload.queryDescription, contains('Online'));
    });

    test('serialization includes online config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['onlineOnly'], true);
    });
  });

  // -------------------------------------------------------------------------
  // Battery Filter node
  // -------------------------------------------------------------------------
  group('Battery Filter node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.batteryFilter);
    });

    test('output chains a battery filter', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'batteryLevel');
      expect(payload.filters.first.operator, 'lte');
      expect(payload.filters.first.value, 20);
      expect(payload.queryDescription, contains('Battery'));
    });

    test('serialization includes battery config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['operator'], 'lte');
      expect(config['threshold'], 20);
    });
  });

  // -------------------------------------------------------------------------
  // Name Filter node
  // -------------------------------------------------------------------------
  group('Name Filter node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.nameFilter);
    });

    test('output chains a name filter', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.filters.length, 1);
      expect(payload.filters.first.field, 'name');
      expect(payload.filters.first.operator, 'contains');
    });

    test('serialization includes name config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['substring'], '');
    });
  });

  // -------------------------------------------------------------------------
  // Sort node
  // -------------------------------------------------------------------------
  group('Sort node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.sortNodes);
    });

    test('has one NodeList input and one NodeList output', () {
      expect(node.inputData.length, 1);
      expect(node.inputData.first, isA<NodeListInputData>());
      expect(node.outputData.length, 1);
      expect(node.outputData.first, isA<NodeListOutputData>());
    });

    test('output applies sort metadata to upstream payload', () {
      final upstream = const NodeListPayload(
        queryDescription: 'All Nodes',
        filters: [],
        nodeNums: [1, 2, 3],
      );
      final result = evaluateOutput(node, {'node_list_in': upstream});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.sortField, 'lastSeen');
      expect(payload.sortAscending, false);
      expect(payload.queryDescription, contains('sorted by'));
      expect(payload.queryDescription, contains('Last Seen'));
      // Should preserve upstream nodeNums
      expect(payload.nodeNums, [1, 2, 3]);
    });

    test('output handles null upstream', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.sortField, 'lastSeen');
      expect(payload.sortAscending, false);
      expect(payload.queryDescription, contains('Sorted by'));
    });

    test('serialization includes sort config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['sortField'], 'lastSeen');
      expect(config['ascending'], false);
    });
  });

  // -------------------------------------------------------------------------
  // Limit node
  // -------------------------------------------------------------------------
  group('Limit node', () {
    late VSNodeData node;

    setUp(() {
      final builders = allNodeDexQueryNodeBuilders();
      node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.limitNodes);
    });

    test('has one NodeList input and one NodeList output', () {
      expect(node.inputData.length, 1);
      expect(node.inputData.first, isA<NodeListInputData>());
      expect(node.outputData.length, 1);
      expect(node.outputData.first, isA<NodeListOutputData>());
    });

    test('output applies limit to upstream payload', () {
      final upstream = const NodeListPayload(
        queryDescription: 'All Nodes',
        filters: [],
        nodeNums: [1, 2, 3, 4, 5],
      );
      final result = evaluateOutput(node, {'node_list_in': upstream});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.limit, 10);
      expect(payload.queryDescription, contains('top 10'));
      // Should preserve upstream nodeNums
      expect(payload.nodeNums, [1, 2, 3, 4, 5]);
    });

    test('output handles null upstream', () {
      final result = evaluateOutput(node, {});
      expect(result, isA<NodeListPayload>());
      final payload = result as NodeListPayload;
      expect(payload.limit, 10);
      expect(payload.queryDescription, contains('Top 10'));
    });

    test('serialization includes limit config', () {
      final json = node.toJson();
      final config = json['value'] as Map;
      expect(config['limit'], 10);
    });
  });

  // -------------------------------------------------------------------------
  // Filter chaining
  // -------------------------------------------------------------------------
  group('Filter chaining', () {
    test('chaining two filters accumulates both in the payload', () {
      final builders = allNodeDexQueryNodeBuilders();
      final traitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final onlineNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.onlineFilter);

      // First filter: trait
      final afterTrait = evaluateOutput(traitNode, {}) as NodeListPayload;
      expect(afterTrait.filters.length, 1);
      expect(afterTrait.filters.first.field, 'trait');

      // Second filter: online (using first filter's output as upstream)
      final afterOnline =
          evaluateOutput(onlineNode, {'node_list_in': afterTrait})
              as NodeListPayload;
      expect(afterOnline.filters.length, 2);
      expect(afterOnline.filters[0].field, 'trait');
      expect(afterOnline.filters[1].field, 'online');

      // Description should contain both
      expect(afterOnline.queryDescription, contains('Trait'));
      expect(afterOnline.queryDescription, contains('Online'));
    });

    test('chaining three filters produces three-element filter list', () {
      final builders = allNodeDexQueryNodeBuilders();
      final traitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final distanceNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.distanceFilter);
      final encounterNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.encounterFilter);

      final afterTrait = evaluateOutput(traitNode, {}) as NodeListPayload;
      final afterDistance =
          evaluateOutput(distanceNode, {'node_list_in': afterTrait})
              as NodeListPayload;
      final afterEncounter =
          evaluateOutput(encounterNode, {'node_list_in': afterDistance})
              as NodeListPayload;

      expect(afterEncounter.filters.length, 3);
      expect(afterEncounter.filters[0].field, 'trait');
      expect(afterEncounter.filters[1].field, 'distance');
      expect(afterEncounter.filters[2].field, 'encounters');
    });

    test('filter then sort then limit produces complete pipeline', () {
      final builders = allNodeDexQueryNodeBuilders();
      final traitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final sortNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.sortNodes);
      final limitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.limitNodes);

      final afterTrait = evaluateOutput(traitNode, {}) as NodeListPayload;
      final afterSort =
          evaluateOutput(sortNode, {'node_list_in': afterTrait})
              as NodeListPayload;
      final afterLimit =
          evaluateOutput(limitNode, {'node_list_in': afterSort})
              as NodeListPayload;

      expect(afterLimit.filters.length, 1);
      expect(afterLimit.filters.first.field, 'trait');
      expect(afterLimit.sortField, 'lastSeen');
      expect(afterLimit.limit, 10);
      expect(afterLimit.queryDescription, contains('Trait'));
      expect(afterLimit.queryDescription, contains('sorted by'));
      expect(afterLimit.queryDescription, contains('top 10'));
    });
  });

  // -------------------------------------------------------------------------
  // getNodeDexQueryConfig
  // -------------------------------------------------------------------------
  group('getNodeDexQueryConfig', () {
    test('returns config for filter nodes', () {
      final builders = allNodeDexQueryNodeBuilders();
      final traitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final config = getNodeDexQueryConfig(traitNode);
      expect(config, isNotNull);
      expect(config!['selectedTrait'], 'beacon');
    });

    test('returns config for sort nodes', () {
      final builders = allNodeDexQueryNodeBuilders();
      final sortNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.sortNodes);
      final config = getNodeDexQueryConfig(sortNode);
      expect(config, isNotNull);
      expect(config!['sortField'], 'lastSeen');
    });

    test('returns config for limit nodes', () {
      final builders = allNodeDexQueryNodeBuilders();
      final limitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.limitNodes);
      final config = getNodeDexQueryConfig(limitNode);
      expect(config, isNotNull);
      expect(config!['limit'], 10);
    });

    test('returns null for All Nodes source (VSWidgetNode)', () {
      final builders = allNodeDexQueryNodeBuilders();
      final allNodes = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.allNodes);
      final config = getNodeDexQueryConfig(allNodes);
      expect(config, isNull);
    });

    test('returns null for non-query nodes', () {
      final fakeNode = VSNodeData(
        type: 'something',
        widgetOffset: testOffset,
        inputData: [],
        outputData: [],
      );
      expect(getNodeDexQueryConfig(fakeNode), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // NodeListFilter
  // -------------------------------------------------------------------------
  group('NodeListFilter', () {
    test('toJson round-trips correctly', () {
      const filter = NodeListFilter(
        field: 'trait',
        operator: 'eq',
        value: 'beacon',
      );
      final json = filter.toJson();
      final restored = NodeListFilter.fromJson(json);
      expect(restored.field, 'trait');
      expect(restored.operator, 'eq');
      expect(restored.value, 'beacon');
    });

    test('displayDescription formats correctly for eq', () {
      const filter = NodeListFilter(
        field: 'trait',
        operator: 'eq',
        value: 'beacon',
      );
      expect(filter.displayDescription, 'trait = beacon');
    });

    test('displayDescription formats correctly for gt', () {
      const filter = NodeListFilter(
        field: 'distance',
        operator: 'gt',
        value: 10000,
      );
      expect(filter.displayDescription, 'distance > 10000');
    });

    test('displayDescription formats correctly for contains', () {
      const filter = NodeListFilter(
        field: 'name',
        operator: 'contains',
        value: 'relay',
      );
      expect(filter.displayDescription, 'name contains relay');
    });

    test('equality works correctly', () {
      const a = NodeListFilter(field: 'trait', operator: 'eq', value: 'beacon');
      const b = NodeListFilter(field: 'trait', operator: 'eq', value: 'beacon');
      const c = NodeListFilter(field: 'trait', operator: 'eq', value: 'ghost');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });

  // -------------------------------------------------------------------------
  // NodeListPayload
  // -------------------------------------------------------------------------
  group('NodeListPayload', () {
    test('isEmpty and isNotEmpty work correctly', () {
      const empty = NodeListPayload();
      const nonEmpty = NodeListPayload(nodeNums: [1, 2, 3]);
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
      expect(nonEmpty.isEmpty, isFalse);
      expect(nonEmpty.isNotEmpty, isTrue);
    });

    test('count returns correct length', () {
      const payload = NodeListPayload(nodeNums: [1, 2, 3, 4, 5]);
      expect(payload.count, 5);
    });

    test('copyWith creates modified copy', () {
      const original = NodeListPayload(
        nodeNums: [1, 2],
        queryDescription: 'original',
        sortField: 'lastSeen',
        sortAscending: true,
        limit: 5,
      );
      final modified = original.copyWith(
        nodeNums: [3, 4, 5],
        sortAscending: false,
        limit: 10,
      );
      expect(modified.nodeNums, [3, 4, 5]);
      expect(modified.queryDescription, 'original');
      expect(modified.sortField, 'lastSeen');
      expect(modified.sortAscending, false);
      expect(modified.limit, 10);
    });

    test('equality and hashCode work correctly', () {
      const a = NodeListPayload(
        nodeNums: [1, 2, 3],
        queryDescription: 'test',
        sortField: 'lastSeen',
        sortAscending: true,
        limit: 10,
      );
      const b = NodeListPayload(
        nodeNums: [1, 2, 3],
        queryDescription: 'test',
        sortField: 'lastSeen',
        sortAscending: true,
        limit: 10,
      );
      const c = NodeListPayload(nodeNums: [1, 2], queryDescription: 'test');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString is informative', () {
      const payload = NodeListPayload(
        nodeNums: [1, 2],
        queryDescription: 'Trait = Beacon',
      );
      expect(payload.toString(), contains('Trait = Beacon'));
      expect(payload.toString(), contains('2 nodes'));
    });
  });

  // -------------------------------------------------------------------------
  // Node interface types
  // -------------------------------------------------------------------------
  group('Node interface types', () {
    test('All Nodes output is NodeListOutputData', () {
      final builders = allNodeDexQueryNodeBuilders();
      final allNodes = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.allNodes);
      expect(allNodes.outputData.first, isA<NodeListOutputData>());
    });

    test('Filter node input accepts NodeListOutputData', () {
      final builders = allNodeDexQueryNodeBuilders();
      final filterNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final input = filterNode.inputData.first;
      expect(input, isA<NodeListInputData>());
      expect(input.acceptedTypes, contains(NodeListOutputData));
    });

    test('Sort node input accepts NodeListOutputData', () {
      final builders = allNodeDexQueryNodeBuilders();
      final sortNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.sortNodes);
      final input = sortNode.inputData.first;
      expect(input, isA<NodeListInputData>());
    });

    test('Limit node input accepts NodeListOutputData', () {
      final builders = allNodeDexQueryNodeBuilders();
      final limitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.limitNodes);
      final input = limitNode.inputData.first;
      expect(input, isA<NodeListInputData>());
    });

    test('NodeListInputData has purple interface color', () {
      final input = NodeListInputData(type: 'test');
      expect(input.interfaceColor, kNodeListColor);
    });

    test('NodeListOutputData has purple interface color', () {
      final output = NodeListOutputData(type: 'test');
      expect(output.interfaceColor, kNodeListColor);
    });
  });

  // -------------------------------------------------------------------------
  // Node width
  // -------------------------------------------------------------------------
  group('Node dimensions', () {
    test('all query nodes have width 220', () {
      final builders = allNodeDexQueryNodeBuilders();
      for (final builder in builders) {
        final node = builder(testOffset, null);
        expect(
          node.nodeWidth,
          220.0,
          reason: '${node.type} should have width 220',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // NodeDexQueryTypes constants
  // -------------------------------------------------------------------------
  group('NodeDexQueryTypes', () {
    test('displayNames has entry for every type', () {
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.allNodes],
        'All Nodes',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.traitFilter],
        'Trait Filter',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.distanceFilter],
        'Distance Filter',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.encounterFilter],
        'Encounter Filter',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.onlineFilter],
        'Online Filter',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.batteryFilter],
        'Battery Filter',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.nameFilter],
        'Name Filter',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.sortNodes],
        'Sort',
      );
      expect(
        NodeDexQueryTypes.displayNames[NodeDexQueryTypes.limitNodes],
        'Limit',
      );
    });

    test('icons has entry for every type', () {
      expect(NodeDexQueryTypes.icons[NodeDexQueryTypes.allNodes], isNotNull);
      expect(NodeDexQueryTypes.icons[NodeDexQueryTypes.traitFilter], isNotNull);
      expect(
        NodeDexQueryTypes.icons[NodeDexQueryTypes.distanceFilter],
        isNotNull,
      );
      expect(
        NodeDexQueryTypes.icons[NodeDexQueryTypes.encounterFilter],
        isNotNull,
      );
      expect(
        NodeDexQueryTypes.icons[NodeDexQueryTypes.onlineFilter],
        isNotNull,
      );
      expect(
        NodeDexQueryTypes.icons[NodeDexQueryTypes.batteryFilter],
        isNotNull,
      );
      expect(NodeDexQueryTypes.icons[NodeDexQueryTypes.nameFilter], isNotNull);
      expect(NodeDexQueryTypes.icons[NodeDexQueryTypes.sortNodes], isNotNull);
      expect(NodeDexQueryTypes.icons[NodeDexQueryTypes.limitNodes], isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Default config values
  // -------------------------------------------------------------------------
  group('Default config values', () {
    test('trait filter defaults to beacon', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['selectedTrait'], 'beacon');
    });

    test('distance filter defaults to lt 10000m', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.distanceFilter);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['operator'], 'lt');
      expect(config['distanceMeters'], 10000.0);
    });

    test('encounter filter defaults to gte 5', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.encounterFilter);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['operator'], 'gte');
      expect(config['threshold'], 5);
    });

    test('online filter defaults to online only', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.onlineFilter);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['onlineOnly'], true);
    });

    test('battery filter defaults to lte 20%', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.batteryFilter);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['operator'], 'lte');
      expect(config['threshold'], 20);
    });

    test('sort defaults to lastSeen descending', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.sortNodes);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['sortField'], 'lastSeen');
      expect(config['ascending'], false);
    });

    test('limit defaults to 10', () {
      final builders = allNodeDexQueryNodeBuilders();
      final node = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.limitNodes);
      final config = getNodeDexQueryConfig(node)!;
      expect(config['limit'], 10);
    });
  });

  // -------------------------------------------------------------------------
  // Upstream preservation
  // -------------------------------------------------------------------------
  group('Upstream preservation', () {
    test('filter preserves upstream sort field', () {
      const upstream = NodeListPayload(
        queryDescription: 'All Nodes',
        sortField: 'encounters',
        sortAscending: true,
      );
      final builders = allNodeDexQueryNodeBuilders();
      final filterNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.traitFilter);
      final result =
          evaluateOutput(filterNode, {'node_list_in': upstream})
              as NodeListPayload;
      expect(result.sortField, 'encounters');
      expect(result.sortAscending, true);
    });

    test('filter preserves upstream limit', () {
      const upstream = NodeListPayload(queryDescription: 'All Nodes', limit: 5);
      final builders = allNodeDexQueryNodeBuilders();
      final filterNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.batteryFilter);
      final result =
          evaluateOutput(filterNode, {'node_list_in': upstream})
              as NodeListPayload;
      expect(result.limit, 5);
    });

    test('sort preserves upstream filters', () {
      const upstream = NodeListPayload(
        queryDescription: 'Trait = Beacon',
        filters: [
          NodeListFilter(field: 'trait', operator: 'eq', value: 'beacon'),
        ],
      );
      final builders = allNodeDexQueryNodeBuilders();
      final sortNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.sortNodes);
      final result =
          evaluateOutput(sortNode, {'node_list_in': upstream})
              as NodeListPayload;
      expect(result.filters.length, 1);
      expect(result.filters.first.field, 'trait');
    });

    test('limit preserves upstream filters and sort', () {
      const upstream = NodeListPayload(
        queryDescription: 'Trait = Beacon, sorted by Last Seen (desc)',
        filters: [
          NodeListFilter(field: 'trait', operator: 'eq', value: 'beacon'),
        ],
        sortField: 'lastSeen',
        sortAscending: false,
      );
      final builders = allNodeDexQueryNodeBuilders();
      final limitNode = builders
          .map((b) => b(testOffset, null))
          .firstWhere((n) => n.type == NodeDexQueryTypes.limitNodes);
      final result =
          evaluateOutput(limitNode, {'node_list_in': upstream})
              as NodeListPayload;
      expect(result.filters.length, 1);
      expect(result.sortField, 'lastSeen');
      expect(result.sortAscending, false);
      expect(result.limit, 10);
    });
  });
}
