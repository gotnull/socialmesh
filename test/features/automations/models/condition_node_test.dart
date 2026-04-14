// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/models/condition_node.dart';

void main() {
  group('ConditionNode', () {
    // -----------------------------------------------------------------------
    // PredicateNode
    // -----------------------------------------------------------------------
    group('PredicateNode', () {
      test('serializes and deserializes', () {
        const node = PredicateNode(
          condition: AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '08:00', 'timeEnd': '18:00'},
          ),
        );

        final json = node.toJson();
        expect(json['nodeType'], 'predicate');
        expect(json['condition'], isNotNull);

        final restored = ConditionNode.fromJson(json);
        expect(restored, isA<PredicateNode>());
        final pred = restored! as PredicateNode;
        expect(pred.condition.type, ConditionType.timeRange);
        expect(pred.condition.config['timeStart'], '08:00');
        expect(pred.type, ConditionNodeType.predicate);
      });
    });

    // -----------------------------------------------------------------------
    // AllGroup
    // -----------------------------------------------------------------------
    group('AllGroup', () {
      test('serializes and deserializes', () {
        const node = AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(type: ConditionType.nodeOnline),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.dayOfWeek,
                config: {
                  'daysOfWeek': [1, 2, 3],
                },
              ),
            ),
          ],
        );

        final json = node.toJson();
        expect(json['nodeType'], 'all');
        expect((json['children'] as List).length, 2);

        final restored = ConditionNode.fromJson(json);
        expect(restored, isA<AllGroup>());
        final all = restored! as AllGroup;
        expect(all.children.length, 2);
        expect(all.children[0], isA<PredicateNode>());
        expect(all.type, ConditionNodeType.all);
      });
    });

    // -----------------------------------------------------------------------
    // AnyGroup
    // -----------------------------------------------------------------------
    group('AnyGroup', () {
      test('serializes and deserializes', () {
        const node = AnyGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.batteryAbove,
                config: {'batteryThreshold': 80},
              ),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.batteryBelow,
                config: {'batteryThreshold': 20},
              ),
            ),
          ],
        );

        final json = node.toJson();
        expect(json['nodeType'], 'any');

        final restored = ConditionNode.fromJson(json);
        expect(restored, isA<AnyGroup>());
        final any = restored! as AnyGroup;
        expect(any.children.length, 2);
        expect(any.type, ConditionNodeType.any);
      });
    });

    // -----------------------------------------------------------------------
    // NotGroup
    // -----------------------------------------------------------------------
    group('NotGroup', () {
      test('serializes and deserializes', () {
        const node = NotGroup(
          child: PredicateNode(
            condition: AutomationCondition(type: ConditionType.nodeOffline),
          ),
        );

        final json = node.toJson();
        expect(json['nodeType'], 'not');
        expect(json['child'], isNotNull);

        final restored = ConditionNode.fromJson(json);
        expect(restored, isA<NotGroup>());
        final notNode = restored! as NotGroup;
        expect(notNode.child, isA<PredicateNode>());
        expect(notNode.type, ConditionNodeType.not);
      });
    });

    // -----------------------------------------------------------------------
    // Nested tree
    // -----------------------------------------------------------------------
    group('Nested tree', () {
      test('deep nesting round-trips correctly', () {
        const tree = AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '09:00', 'timeEnd': '17:00'},
              ),
            ),
            AnyGroup(
              children: [
                PredicateNode(
                  condition: AutomationCondition(
                    type: ConditionType.batteryAbove,
                    config: {'batteryThreshold': 50},
                  ),
                ),
                NotGroup(
                  child: PredicateNode(
                    condition: AutomationCondition(
                      type: ConditionType.nodeOffline,
                      config: {'nodeNum': 42},
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        final json = tree.toJson();
        final restored = ConditionNode.fromJson(json)! as AllGroup;
        expect(restored.children.length, 2);
        expect(restored.children[0], isA<PredicateNode>());
        final anyChild = restored.children[1] as AnyGroup;
        expect(anyChild.children.length, 2);
        expect(anyChild.children[1], isA<NotGroup>());
      });
    });

    // -----------------------------------------------------------------------
    // Malformed payloads
    // -----------------------------------------------------------------------
    group('Malformed payloads', () {
      test('returns null for missing nodeType', () {
        final result = ConditionNode.fromJson({'foo': 'bar'});
        expect(result, isNull);
      });

      test('returns null for unknown nodeType', () {
        final result = ConditionNode.fromJson({'nodeType': 'xor'});
        expect(result, isNull);
      });

      test('returns null for predicate without condition', () {
        final result = ConditionNode.fromJson({'nodeType': 'predicate'});
        expect(result, isNull);
      });

      test('returns null for all with empty children', () {
        final result = ConditionNode.fromJson({
          'nodeType': 'all',
          'children': [],
        });
        expect(result, isNull);
      });

      test('returns null for any with null children', () {
        final result = ConditionNode.fromJson({'nodeType': 'any'});
        expect(result, isNull);
      });

      test('returns null for not without child', () {
        final result = ConditionNode.fromJson({'nodeType': 'not'});
        expect(result, isNull);
      });

      test('returns null for not with malformed child', () {
        final result = ConditionNode.fromJson({
          'nodeType': 'not',
          'child': {'nodeType': 'predicate'}, // missing condition
        });
        expect(result, isNull);
      });

      test('skips malformed children in group and fails if none valid', () {
        final result = ConditionNode.fromJson({
          'nodeType': 'all',
          'children': [
            {'nodeType': 'predicate'}, // malformed - no condition
            'not-a-map', // invalid type
          ],
        });
        expect(result, isNull);
      });

      test('partial valid children in group produce valid tree', () {
        final result = ConditionNode.fromJson({
          'nodeType': 'all',
          'children': [
            {'nodeType': 'predicate'}, // malformed
            {
              'nodeType': 'predicate',
              'condition': {'type': 'nodeOnline', 'config': {}},
            },
          ],
        });
        expect(result, isA<AllGroup>());
        expect((result! as AllGroup).children.length, 1);
      });
    });

    // -----------------------------------------------------------------------
    // Legacy compatibility
    // -----------------------------------------------------------------------
    group('fromLegacyConditions', () {
      test('returns null for null input', () {
        expect(ConditionNode.fromLegacyConditions(null), isNull);
      });

      test('returns null for empty list', () {
        expect(ConditionNode.fromLegacyConditions([]), isNull);
      });

      test('single condition becomes PredicateNode', () {
        const conditions = [AutomationCondition(type: ConditionType.timeRange)];
        final tree = ConditionNode.fromLegacyConditions(conditions);
        expect(tree, isA<PredicateNode>());
        expect(
          (tree! as PredicateNode).condition.type,
          ConditionType.timeRange,
        );
      });

      test('multiple conditions become AllGroup', () {
        const conditions = [
          AutomationCondition(type: ConditionType.timeRange),
          AutomationCondition(type: ConditionType.dayOfWeek),
          AutomationCondition(type: ConditionType.batteryAbove),
        ];
        final tree = ConditionNode.fromLegacyConditions(conditions);
        expect(tree, isA<AllGroup>());
        final all = tree! as AllGroup;
        expect(all.children.length, 3);
        for (final child in all.children) {
          expect(child, isA<PredicateNode>());
        }
      });
    });

    // -----------------------------------------------------------------------
    // toLegacyConditions
    // -----------------------------------------------------------------------
    group('toLegacyConditions', () {
      test('PredicateNode produces single condition', () {
        const node = PredicateNode(
          condition: AutomationCondition(type: ConditionType.nodeOnline),
        );
        final conditions = node.toLegacyConditions();
        expect(conditions.length, 1);
        expect(conditions[0].type, ConditionType.nodeOnline);
      });

      test('AllGroup produces flat list', () {
        const node = AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(type: ConditionType.timeRange),
            ),
            PredicateNode(
              condition: AutomationCondition(type: ConditionType.dayOfWeek),
            ),
          ],
        );
        final conditions = node.toLegacyConditions();
        expect(conditions.length, 2);
        expect(conditions[0].type, ConditionType.timeRange);
        expect(conditions[1].type, ConditionType.dayOfWeek);
      });
    });
  });

  // =========================================================================
  // Automation model integration with conditionTree
  // =========================================================================
  group('Automation conditionTree integration', () {
    test('toJson includes conditionTree when set', () {
      final automation = Automation(
        id: 'tree-test',
        name: 'Tree Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditionTree: const AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '08:00', 'timeEnd': '18:00'},
              ),
            ),
          ],
        ),
      );

      final json = automation.toJson();
      expect(json.containsKey('conditionTree'), isTrue);
      expect(json['conditionTree']['nodeType'], 'all');
    });

    test('toJson omits conditionTree when null', () {
      final automation = Automation(
        id: 'no-tree',
        name: 'No Tree',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [],
      );

      final json = automation.toJson();
      expect(json.containsKey('conditionTree'), isFalse);
    });

    test('fromJson restores conditionTree', () {
      final json = {
        'id': 'tree-roundtrip',
        'name': 'Round Trip',
        'trigger': {'type': 'messageReceived', 'config': {}},
        'actions': [],
        'conditionTree': {
          'nodeType': 'any',
          'children': [
            {
              'nodeType': 'predicate',
              'condition': {
                'type': 'batteryAbove',
                'config': {'batteryThreshold': 80},
              },
            },
          ],
        },
        'createdAt': DateTime.now().toIso8601String(),
      };

      final automation = Automation.fromJson(json);
      expect(automation.conditionTree, isA<AnyGroup>());
      expect((automation.conditionTree! as AnyGroup).children.length, 1);
    });

    test('fromJson without conditionTree remains null', () {
      final json = {
        'id': 'legacy',
        'name': 'Legacy',
        'trigger': {'type': 'nodeOnline', 'config': {}},
        'actions': [],
        'createdAt': DateTime.now().toIso8601String(),
      };

      final automation = Automation.fromJson(json);
      expect(automation.conditionTree, isNull);
    });

    test('effectiveConditionTree prefers conditionTree over legacy', () {
      final automation = Automation(
        id: 'prefer-tree',
        name: 'Prefer Tree',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
        conditions: const [AutomationCondition(type: ConditionType.timeRange)],
        conditionTree: const AnyGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(type: ConditionType.batteryAbove),
            ),
          ],
        ),
      );

      final tree = automation.effectiveConditionTree;
      expect(tree, isA<AnyGroup>());
    });

    test('effectiveConditionTree falls back to legacy conditions', () {
      final automation = Automation(
        id: 'fallback',
        name: 'Fallback',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
        conditions: const [
          AutomationCondition(type: ConditionType.timeRange),
          AutomationCondition(type: ConditionType.dayOfWeek),
        ],
      );

      final tree = automation.effectiveConditionTree;
      expect(tree, isA<AllGroup>());
      expect((tree! as AllGroup).children.length, 2);
    });

    test('effectiveConditionTree returns null when no conditions', () {
      final automation = Automation(
        id: 'empty',
        name: 'Empty',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );

      expect(automation.effectiveConditionTree, isNull);
    });

    test('legacy flat conditions still deserialize correctly', () {
      final json = {
        'id': 'legacy-with-conds',
        'name': 'Legacy Conditions',
        'trigger': {'type': 'nodeOnline', 'config': {}},
        'actions': [],
        'conditions': [
          {
            'type': 'timeRange',
            'config': {'timeStart': '06:00', 'timeEnd': '22:00'},
          },
          {
            'type': 'dayOfWeek',
            'config': {
              'daysOfWeek': [1, 2, 3, 4, 5],
            },
          },
        ],
        'createdAt': DateTime.now().toIso8601String(),
      };

      final automation = Automation.fromJson(json);
      expect(automation.conditions, isNotNull);
      expect(automation.conditions!.length, 2);
      expect(automation.conditionTree, isNull);

      // effectiveConditionTree lifts them
      final tree = automation.effectiveConditionTree;
      expect(tree, isA<AllGroup>());
      final allGroup = tree! as AllGroup;
      expect(allGroup.children.length, 2);
    });

    test('copyWith preserves conditionTree', () {
      final original = Automation(
        id: 'copy-test',
        name: 'Copy Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
        conditionTree: const PredicateNode(
          condition: AutomationCondition(type: ConditionType.batteryAbove),
        ),
      );

      final copy = original.copyWith(name: 'Modified');
      expect(copy.conditionTree, isA<PredicateNode>());
    });

    test('full round-trip: toJson -> fromJson preserves both fields', () {
      final original = Automation(
        id: 'full-roundtrip',
        name: 'Full Round Trip',
        trigger: const AutomationTrigger(
          type: TriggerType.batteryLow,
          config: {'batteryThreshold': 20},
        ),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [
          AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '08:00', 'timeEnd': '18:00'},
          ),
        ],
        conditionTree: const AllGroup(
          children: [
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.timeRange,
                config: {'timeStart': '08:00', 'timeEnd': '18:00'},
              ),
            ),
            PredicateNode(
              condition: AutomationCondition(
                type: ConditionType.dayOfWeek,
                config: {
                  'daysOfWeek': [1, 2, 3, 4, 5],
                },
              ),
            ),
          ],
        ),
      );

      final json = original.toJson();
      final restored = Automation.fromJson(json);
      expect(restored.conditions!.length, 1);
      expect(restored.conditionTree, isA<AllGroup>());
      expect((restored.conditionTree! as AllGroup).children.length, 2);
    });
  });
}
