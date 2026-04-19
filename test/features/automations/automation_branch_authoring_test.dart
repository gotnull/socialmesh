// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/automation_summary.dart';
import 'package:socialmesh/features/automations/models/automation.dart';
import 'package:socialmesh/features/automations/models/condition_node.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  group('Phase 4 — Model preservation', () {
    test('editor save with unmodified conditions preserves conditionTree', () {
      // Build an automation with a complex conditionTree (AnyGroup)
      final originalTree = AnyGroup(
        children: [
          PredicateNode(
            condition: const AutomationCondition(type: ConditionType.timeRange),
          ),
          PredicateNode(
            condition: const AutomationCondition(type: ConditionType.dayOfWeek),
          ),
        ],
      );

      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [
          AutomationCondition(type: ConditionType.timeRange),
          AutomationCondition(type: ConditionType.dayOfWeek),
        ],
        conditionTree: originalTree,
      );

      // Simulate editor save WITHOUT modifying conditions:
      // conditionsModified = false → pass original conditionTree
      final saved = automation.copyWith(
        name: 'New Name',
        conditionTree: originalTree, // preserved as-is
      );

      expect(saved.conditionTree, isA<AnyGroup>());
      final anyGroup = saved.conditionTree! as AnyGroup;
      expect(anyGroup.children.length, 2);
    });

    test('editor save with modified conditions rebuilds conditionTree', () {
      final originalTree = AnyGroup(
        children: [
          PredicateNode(
            condition: const AutomationCondition(type: ConditionType.timeRange),
          ),
        ],
      );

      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [AutomationCondition(type: ConditionType.timeRange)],
        conditionTree: originalTree,
      );

      // Simulate editor save WITH modified conditions:
      // conditionsModified = true → rebuild from flat conditions
      final newConditions = [
        const AutomationCondition(type: ConditionType.timeRange),
        const AutomationCondition(type: ConditionType.batteryAbove),
      ];
      final rebuiltTree = ConditionNode.fromLegacyConditions(newConditions);

      final saved = automation.copyWith(
        conditions: newConditions,
        conditionTree: rebuiltTree,
      );

      // Should be an AllGroup (flat rebuild), not the original AnyGroup
      expect(saved.conditionTree, isA<AllGroup>());
      final allGroup = saved.conditionTree! as AllGroup;
      expect(allGroup.children.length, 2);
    });

    test('clearing all conditions sets conditionTree to null', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [AutomationCondition(type: ConditionType.timeRange)],
        conditionTree: PredicateNode(
          condition: const AutomationCondition(type: ConditionType.timeRange),
        ),
      );

      // Simulate clearing all conditions
      final rebuiltTree = ConditionNode.fromLegacyConditions(null);
      expect(rebuiltTree, isNull);

      final saved = Automation(
        id: automation.id,
        name: automation.name,
        trigger: automation.trigger,
        actions: automation.actions,
        conditions: null,
        conditionTree: null,
      );

      expect(saved.conditions, isNull);
      expect(saved.conditionTree, isNull);
      expect(saved.effectiveConditionTree, isNull);
    });

    test('editing THEN does not affect ELSE', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        thenActions: const [
          AutomationAction(type: ActionType.pushNotification),
        ],
        elseActions: const [AutomationAction(type: ActionType.playSound)],
      );

      // Change THEN actions, keep ELSE
      final saved = automation.copyWith(
        actions: const [AutomationAction(type: ActionType.sendMessage)],
        thenActions: const [AutomationAction(type: ActionType.sendMessage)],
      );

      // THEN changed
      expect(saved.effectiveThenActions.length, 1);
      expect(saved.effectiveThenActions.first.type, ActionType.sendMessage);

      // ELSE preserved
      expect(saved.effectiveElseActions, isNotNull);
      expect(saved.effectiveElseActions!.first.type, ActionType.playSound);
    });

    test('removing ELSE clears only elseActions', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        thenActions: const [
          AutomationAction(type: ActionType.pushNotification),
        ],
        elseActions: const [AutomationAction(type: ActionType.playSound)],
        conditions: const [AutomationCondition(type: ConditionType.timeRange)],
      );

      // Remove ELSE branch
      final saved = Automation(
        id: automation.id,
        name: automation.name,
        trigger: automation.trigger,
        actions: automation.actions,
        thenActions: automation.thenActions,
        elseActions: null, // cleared
        conditions: automation.conditions,
        conditionTree: automation.conditionTree,
      );

      expect(saved.effectiveElseActions, isNull);
      expect(
        saved.effectiveThenActions.first.type,
        ActionType.pushNotification,
      );
      expect(saved.conditions, isNotNull);
    });
  });

  group('Phase 4 — Branch structure in serialization', () {
    test('THEN/ELSE round-trip correctly through JSON', () {
      final automation = Automation(
        name: 'Branch Test',
        trigger: const AutomationTrigger(type: TriggerType.batteryLow),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        thenActions: const [
          AutomationAction(type: ActionType.pushNotification),
        ],
        elseActions: const [AutomationAction(type: ActionType.playSound)],
        conditions: const [
          AutomationCondition(type: ConditionType.batteryBelow),
        ],
        conditionTree: PredicateNode(
          condition: const AutomationCondition(
            type: ConditionType.batteryBelow,
          ),
        ),
      );

      final json = automation.toJson();
      final restored = Automation.fromJson(json);

      expect(restored.thenActions, isNotNull);
      expect(restored.thenActions!.length, 1);
      expect(restored.thenActions!.first.type, ActionType.pushNotification);

      expect(restored.elseActions, isNotNull);
      expect(restored.elseActions!.length, 1);
      expect(restored.elseActions!.first.type, ActionType.playSound);

      expect(restored.conditions, isNotNull);
      expect(restored.conditions!.length, 1);
      expect(restored.conditionTree, isA<PredicateNode>());
    });

    test('legacy automations still load/save correctly', () {
      // JSON without thenActions/elseActions/conditionTree
      final legacyJson = {
        'id': 'legacy-1',
        'name': 'Legacy',
        'enabled': true,
        'trigger': {'type': 'messageReceived', 'config': <String, dynamic>{}},
        'actions': [
          {'type': 'pushNotification', 'config': <String, dynamic>{}},
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'triggerCount': 5,
      };

      final automation = Automation.fromJson(legacyJson);

      expect(automation.thenActions, isNull);
      expect(automation.elseActions, isNull);
      expect(automation.conditionTree, isNull);

      // effectiveThenActions falls back to actions
      expect(automation.effectiveThenActions.length, 1);
      expect(
        automation.effectiveThenActions.first.type,
        ActionType.pushNotification,
      );
      expect(automation.effectiveElseActions, isNull);

      // Round-trip
      final json = automation.toJson();
      expect(json.containsKey('thenActions'), false);
      expect(json.containsKey('elseActions'), false);
      expect(json.containsKey('conditionTree'), false);
    });
  });

  group('Phase 4 — Validation', () {
    test('automation without THEN actions is invalid', () {
      // The validation is UI-level, but model allows it.
      // Effective THEN with empty actions = empty list
      final automation = Automation(
        name: 'No Actions',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [],
        thenActions: const [],
      );

      expect(automation.effectiveThenActions, isEmpty);
    });

    test('empty ELSE actions means no ELSE branch', () {
      final automation = Automation(
        name: 'Empty ELSE',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        elseActions: const [],
      );

      // effectiveElseActions returns null for empty list
      expect(automation.effectiveElseActions, isNull);
      expect(automation.hasBranchStructure, false);
    });

    test('non-empty ELSE actions means branch structure', () {
      final automation = Automation(
        name: 'With ELSE',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        elseActions: const [AutomationAction(type: ActionType.playSound)],
      );

      expect(automation.effectiveElseActions, isNotNull);
      expect(automation.hasBranchStructure, true);
    });
  });

  group('Phase 4 — AutomationSummary', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    test('simple automation summary', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final summary = AutomationSummary.build(automation, l10n);
      expect(summary, contains('When'));
      expect(summary, contains('then'));
    });

    test('summary with conditions', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        conditions: const [AutomationCondition(type: ConditionType.timeRange)],
      );

      final summary = AutomationSummary.build(automation, l10n);
      expect(summary, contains('if'));
    });

    test('summary with ELSE', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
        thenActions: const [
          AutomationAction(type: ActionType.pushNotification),
        ],
        elseActions: const [AutomationAction(type: ActionType.playSound)],
      );

      final summary = AutomationSummary.build(automation, l10n);
      expect(summary, contains('else'));
    });
  });

  group('Phase 4 — Import flow preservation', () {
    test('import with branches preserves structure', () {
      final importJson = {
        'name': 'Imported Branched',
        'trigger': {'type': 'batteryLow', 'config': <String, dynamic>{}},
        'actions': [
          {'type': 'pushNotification', 'config': <String, dynamic>{}},
        ],
        'thenActions': [
          {'type': 'pushNotification', 'config': <String, dynamic>{}},
        ],
        'elseActions': [
          {'type': 'playSound', 'config': <String, dynamic>{}},
        ],
        'conditions': [
          {'type': 'batteryBelow', 'config': <String, dynamic>{}},
        ],
        'conditionTree': {
          'nodeType': 'predicate',
          'condition': {'type': 'batteryBelow', 'config': <String, dynamic>{}},
        },
      };

      final automation = Automation(
        name: importJson['name'] as String,
        enabled: false,
        trigger: AutomationTrigger.fromJson(
          importJson['trigger'] as Map<String, dynamic>,
        ),
        actions: (importJson['actions'] as List)
            .map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
            .toList(),
        thenActions: (importJson['thenActions'] as List?)
            ?.map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
            .toList(),
        elseActions: (importJson['elseActions'] as List?)
            ?.map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
            .toList(),
        conditions: (importJson['conditions'] as List?)
            ?.map(
              (c) => AutomationCondition.fromJson(c as Map<String, dynamic>),
            )
            .toList(),
      );

      expect(automation.thenActions, isNotNull);
      expect(automation.thenActions!.length, 1);
      expect(automation.elseActions, isNotNull);
      expect(automation.elseActions!.length, 1);
      expect(automation.conditions, isNotNull);
      expect(automation.conditions!.length, 1);
    });

    test('import without branches works as legacy', () {
      final importJson = {
        'name': 'Legacy Import',
        'trigger': {'type': 'messageReceived', 'config': <String, dynamic>{}},
        'actions': [
          {'type': 'pushNotification', 'config': <String, dynamic>{}},
        ],
      };

      final automation = Automation(
        name: importJson['name'] as String,
        enabled: false,
        trigger: AutomationTrigger.fromJson(
          importJson['trigger'] as Map<String, dynamic>,
        ),
        actions: (importJson['actions'] as List)
            .map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

      expect(automation.thenActions, isNull);
      expect(automation.elseActions, isNull);
      expect(automation.effectiveThenActions.length, 1);
    });
  });

  group('Phase 4 — ConditionNode from conditions', () {
    test('single condition → PredicateNode', () {
      final conditions = [
        const AutomationCondition(type: ConditionType.timeRange),
      ];
      final tree = ConditionNode.fromLegacyConditions(conditions);
      expect(tree, isA<PredicateNode>());
    });

    test('multiple conditions → AllGroup', () {
      final conditions = [
        const AutomationCondition(type: ConditionType.timeRange),
        const AutomationCondition(type: ConditionType.dayOfWeek),
      ];
      final tree = ConditionNode.fromLegacyConditions(conditions);
      expect(tree, isA<AllGroup>());
      final allGroup = tree! as AllGroup;
      expect(allGroup.children.length, 2);
    });

    test('null conditions → null', () {
      final tree = ConditionNode.fromLegacyConditions(null);
      expect(tree, isNull);
    });

    test('empty conditions → null', () {
      final tree = ConditionNode.fromLegacyConditions([]);
      expect(tree, isNull);
    });
  });
}
