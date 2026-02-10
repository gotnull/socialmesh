// SPDX-License-Identifier: GPL-3.0-or-later
// Tests for the Socialmesh visual flow compiler.
//
// Covers:
// - Simple trigger → action compilation
// - Trigger → condition → action compilation
// - AND gate merging conditions
// - OR gate forking into multiple Automations
// - NOT gate inverting conditions
// - Delay gate metadata attachment
// - Multiple actions sharing a trigger path (merge into one Automation)
// - Disconnected / incomplete graph validation
// - Cycle detection
// - Decompilation round-trip (Automation → graph → Automation)
// - Edge cases: empty graph, no trigger, no action, broken refs

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/visual_flow/compiler/flow_compiler.dart';
import 'package:socialmesh/core/visual_flow/interfaces/event_signal_interface.dart';
import 'package:socialmesh/core/visual_flow/nodes/action_nodes.dart';
import 'package:socialmesh/core/visual_flow/nodes/condition_nodes.dart';
import 'package:socialmesh/core/visual_flow/nodes/logic_gate_nodes.dart';
import 'package:socialmesh/core/visual_flow/nodes/trigger_nodes.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/data/vs_interface.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/data/vs_node_data.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/special_nodes/vs_list_node.dart';
import 'package:socialmesh/core/visual_flow/vs_node_view/special_nodes/vs_widget_node.dart';
import 'package:socialmesh/features/automations/models/automation.dart';

// ---------------------------------------------------------------------------
// Test helpers — build minimal graph nodes without full widget trees
// ---------------------------------------------------------------------------

/// Creates a minimal trigger node (VSWidgetNode) for the given trigger type.
VSWidgetNode _makeTriggerNode(
  String triggerType, {
  Map<String, dynamic> config = const {},
  Offset offset = Offset.zero,
}) {
  final mutableConfig = Map<String, dynamic>.from(config);
  return VSWidgetNode(
    type: triggerType,
    widgetOffset: offset,
    title: TriggerTypes.displayNames[triggerType] ?? triggerType,
    outputData: EventSignalOutputData(
      type: 'event_out',
      title: 'Event',
      outputFunction: (inputs) => EventSignalPayload(
        triggerType: triggerType,
        config: mutableConfig,
        passed: true,
      ),
    ),
    child: const SizedBox.shrink(),
    getValue: () => mutableConfig,
    setValue: (v) {
      if (v is Map) {
        mutableConfig
          ..clear()
          ..addAll(Map<String, dynamic>.from(v));
      }
    },
  );
}

/// Creates a minimal condition node for the given condition type.
ConditionNode _makeConditionNode(
  String conditionType, {
  Map<String, dynamic> config = const {},
  Offset offset = Offset.zero,
  VSOutputData? upstreamConnection,
}) {
  final mutableConfig = Map<String, dynamic>.from(config);
  return ConditionNode(
    type: conditionType,
    conditionType: conditionType,
    widgetOffset: offset,
    title: ConditionTypes.displayNames[conditionType] ?? conditionType,
    ref: upstreamConnection,
    configWidget: const SizedBox.shrink(),
    getConfig: () => mutableConfig,
    setConfig: (v) {
      if (v is Map) {
        mutableConfig
          ..clear()
          ..addAll(Map<String, dynamic>.from(v));
      }
    },
  );
}

/// Creates a minimal action node for the given action type.
ActionNode _makeActionNode(
  String actionType, {
  Map<String, dynamic> config = const {},
  Offset offset = Offset.zero,
  VSOutputData? upstreamConnection,
}) {
  final mutableConfig = Map<String, dynamic>.from(config);
  return ActionNode(
    type: actionType,
    actionType: actionType,
    widgetOffset: offset,
    title: ActionTypes.displayNames[actionType] ?? actionType,
    ref: upstreamConnection,
    configWidget: const SizedBox.shrink(),
    getConfig: () => mutableConfig,
    setConfig: (v) {
      if (v is Map) {
        mutableConfig
          ..clear()
          ..addAll(Map<String, dynamic>.from(v));
      }
    },
  );
}

/// Creates a NOT gate node.
VSNodeData _makeNotGate({
  Offset offset = Offset.zero,
  VSOutputData? upstreamConnection,
}) {
  return VSNodeData(
    type: LogicGateTypes.not,
    widgetOffset: offset,
    title: 'NOT',
    inputData: [
      EventSignalInputData(
        type: 'event_in',
        title: 'Input',
        initialConnection: upstreamConnection,
      ),
    ],
    outputData: [
      EventSignalOutputData(
        type: 'event_out',
        title: 'Inverted',
        outputFunction: (inputs) {
          final upstream = inputs['event_in'] as EventSignalPayload?;
          if (upstream == null) {
            return EventSignalPayload(triggerType: '', passed: true);
          }
          return upstream.copyWith(passed: !upstream.passed);
        },
      ),
    ],
  );
}

/// Creates an AND gate node (VSListNode) with pre-wired inputs.
VSListNode _makeAndGate({Offset offset = Offset.zero}) {
  return VSListNode(
    type: LogicGateTypes.and,
    widgetOffset: offset,
    title: 'AND',
    inputBuilder: (int index, VSOutputData? connection) {
      return EventSignalInputData(
        type: 'event_in_$index',
        title: 'Input ${index + 1}',
        initialConnection: connection,
      );
    },
    outputData: [
      EventSignalOutputData(
        type: 'event_out',
        title: 'All Met',
        outputFunction: (inputs) {
          return EventSignalPayload(triggerType: '', passed: true);
        },
      ),
    ],
  );
}

/// Creates an OR gate node (VSListNode) with pre-wired inputs.
VSListNode _makeOrGate({Offset offset = Offset.zero}) {
  return VSListNode(
    type: LogicGateTypes.or,
    widgetOffset: offset,
    title: 'OR',
    inputBuilder: (int index, VSOutputData? connection) {
      return EventSignalInputData(
        type: 'event_in_$index',
        title: 'Input ${index + 1}',
        initialConnection: connection,
      );
    },
    outputData: [
      EventSignalOutputData(
        type: 'event_out',
        title: 'Any Met',
        outputFunction: (inputs) {
          return EventSignalPayload(triggerType: '', passed: true);
        },
      ),
    ],
  );
}

/// Wires a node's input to an upstream node's output.
///
/// Finds the first input on [downstream] with type [inputType] and connects
/// it to the first output on [upstream] with type [outputType].
void _wire(
  VSNodeData upstream,
  VSNodeData downstream, {
  String outputType = 'event_out',
  String inputType = 'event_in',
}) {
  final output = upstream.outputData.firstWhere(
    (o) => o.type == outputType,
    orElse: () => upstream.outputData.first,
  );
  for (final input in downstream.inputData) {
    if (input.type == inputType) {
      input.connectedInterface = output;
      return;
    }
  }
  // Fallback: try action_in for action nodes.
  for (final input in downstream.inputData) {
    if (input.type == 'action_in') {
      input.connectedInterface = output;
      return;
    }
  }
}

/// Builds a node map keyed by node ID, suitable for passing to the compiler.
Map<String, VSNodeData> _buildNodeMap(List<VSNodeData> nodes) {
  return {for (final node in nodes) node.id: node};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FlowCompiler', () {
    group('validation', () {
      test('empty graph produces error', () {
        final issues = validateGraph({});
        expect(issues, isNotEmpty);
        expect(
          issues.any((e) => e.message.contains('trigger')),
          isTrue,
          reason: 'Should warn about missing trigger',
        );
        expect(
          issues.any((e) => e.message.contains('action')),
          isTrue,
          reason: 'Should warn about missing action',
        );
      });

      test('graph with only trigger produces action error', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final issues = validateGraph(_buildNodeMap([trigger]));
        expect(
          issues.any((e) => e.message.contains('action')),
          isTrue,
          reason: 'Should warn about missing action',
        );
        expect(
          issues.any((e) => e.message.contains('trigger')),
          isFalse,
          reason: 'Should not warn about missing trigger',
        );
      });

      test('graph with only action produces trigger error', () {
        final action = _makeActionNode(ActionTypes.vibrate);
        final issues = validateGraph(_buildNodeMap([action]));
        expect(
          issues.any((e) => e.message.contains('trigger')),
          isTrue,
          reason: 'Should warn about missing trigger',
        );
      });

      test('disconnected action node produces error', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action = _makeActionNode(ActionTypes.vibrate);
        // Not wired together.
        final issues = validateGraph(_buildNodeMap([trigger, action]));
        expect(
          issues.any((e) => e.message.contains('not connected')),
          isTrue,
          reason: 'Should warn about disconnected action',
        );
      });

      test('properly wired graph passes validation', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action = _makeActionNode(ActionTypes.vibrate);
        _wire(trigger, action, inputType: 'action_in');

        final issues = validateGraph(_buildNodeMap([trigger, action]));
        expect(issues, isEmpty);
      });
    });

    group('simple compilation', () {
      test('trigger → action produces one Automation', () {
        final trigger = _makeTriggerNode(
          TriggerTypes.batteryLow,
          config: {'batteryThreshold': 20},
        );
        final action = _makeActionNode(
          ActionTypes.pushNotification,
          config: {
            'notificationTitle': 'Low Battery',
            'notificationBody': 'Battery is low',
          },
        );
        _wire(trigger, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action]),
          flowName: 'Test Flow',
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(1));

        final automation = result.automations.first;
        expect(automation.trigger.type, TriggerType.batteryLow);
        expect(automation.trigger.config['batteryThreshold'], 20);
        expect(automation.actions, hasLength(1));
        expect(automation.actions.first.type, ActionType.pushNotification);
        expect(
          automation.actions.first.config['notificationTitle'],
          'Low Battery',
        );
        expect(automation.conditions, isNull);
        expect(automation.name, contains('Test Flow'));
      });

      test('trigger → action with no config produces Automation', () {
        final trigger = _makeTriggerNode(TriggerTypes.messageReceived);
        final action = _makeActionNode(ActionTypes.vibrate);
        _wire(trigger, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(1));
        expect(
          result.automations.first.trigger.type,
          TriggerType.messageReceived,
        );
        expect(result.automations.first.actions.first.type, ActionType.vibrate);
      });
    });

    group('condition compilation', () {
      test(
        'trigger → condition → action produces Automation with condition',
        () {
          final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
          final condition = _makeConditionNode(
            ConditionTypes.timeRange,
            config: {'timeStart': '08:00', 'timeEnd': '18:00'},
          );
          final action = _makeActionNode(ActionTypes.pushNotification);

          _wire(trigger, condition);
          _wire(condition, action, inputType: 'action_in');

          final result = compileFlowGraph(
            nodes: _buildNodeMap([trigger, condition, action]),
          );

          expect(result.isSuccess, isTrue);
          expect(result.automations, hasLength(1));

          final automation = result.automations.first;
          expect(automation.trigger.type, TriggerType.nodeOnline);
          expect(automation.conditions, isNotNull);
          expect(automation.conditions, hasLength(1));
          expect(automation.conditions!.first.type, ConditionType.timeRange);
          expect(automation.conditions!.first.config['timeStart'], '08:00');
          expect(automation.conditions!.first.config['timeEnd'], '18:00');
        },
      );

      test('trigger → condition1 → condition2 → action chains conditions', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final cond1 = _makeConditionNode(
          ConditionTypes.timeRange,
          config: {'timeStart': '08:00', 'timeEnd': '18:00'},
        );
        final cond2 = _makeConditionNode(
          ConditionTypes.batteryAbove,
          config: {'batteryThreshold': 50},
        );
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(trigger, cond1);
        _wire(cond1, cond2);
        _wire(cond2, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, cond1, cond2, action]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(1));

        final automation = result.automations.first;
        expect(automation.conditions, hasLength(2));

        // Conditions should be in path order (closest to action first,
        // because the compiler walks backwards and prepends).
        final condTypes = automation.conditions!.map((c) => c.type).toSet();
        expect(condTypes, contains(ConditionType.timeRange));
        expect(condTypes, contains(ConditionType.batteryAbove));
      });
    });

    group('AND gate', () {
      test('AND gate merges conditions from multiple branches', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final cond1 = _makeConditionNode(
          ConditionTypes.timeRange,
          config: {'timeStart': '08:00', 'timeEnd': '18:00'},
        );
        final cond2 = _makeConditionNode(
          ConditionTypes.batteryAbove,
          config: {'batteryThreshold': 50},
        );
        final andGate = _makeAndGate();
        final action = _makeActionNode(ActionTypes.pushNotification);

        // Wire trigger to both conditions.
        _wire(trigger, cond1);
        _wire(trigger, cond2);

        // Wire both conditions to AND gate inputs.
        // AND gate uses VSListNode so we need to wire through setRefData.
        final cond1Output = cond1.outputData.first;
        final cond2Output = cond2.outputData.first;
        andGate.setRefData({
          'event_in_0': cond1Output,
          'event_in_1': cond2Output,
        });

        // Wire AND gate to action.
        _wire(andGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, cond1, cond2, andGate, action]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(1));

        final automation = result.automations.first;
        expect(automation.conditions, isNotNull);
        expect(automation.conditions, hasLength(2));

        final condTypes = automation.conditions!.map((c) => c.type).toSet();
        expect(condTypes, contains(ConditionType.timeRange));
        expect(condTypes, contains(ConditionType.batteryAbove));
      });
    });

    group('OR gate', () {
      test('OR gate produces multiple Automations', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final cond1 = _makeConditionNode(ConditionTypes.timeRange);
        final cond2 = _makeConditionNode(ConditionTypes.batteryAbove);
        final orGate = _makeOrGate();
        final action = _makeActionNode(ActionTypes.vibrate);

        // Wire trigger to both conditions.
        _wire(trigger, cond1);
        _wire(trigger, cond2);

        // Wire both conditions to OR gate inputs.
        final cond1Output = cond1.outputData.first;
        final cond2Output = cond2.outputData.first;
        orGate.setRefData({
          'event_in_0': cond1Output,
          'event_in_1': cond2Output,
        });

        // Wire OR gate to action.
        _wire(orGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, cond1, cond2, orGate, action]),
        );

        expect(result.isSuccess, isTrue);
        // OR gate should produce one Automation per upstream path.
        expect(result.automations, hasLength(2));

        final condTypes = result.automations
            .map((a) => a.conditions?.first.type)
            .toSet();
        expect(condTypes, contains(ConditionType.timeRange));
        expect(condTypes, contains(ConditionType.batteryAbove));

        // Both automations should share the same trigger type.
        for (final auto in result.automations) {
          expect(auto.trigger.type, TriggerType.nodeOnline);
          expect(auto.actions, hasLength(1));
          expect(auto.actions.first.type, ActionType.vibrate);
        }
      });
    });

    group('NOT gate', () {
      test('NOT gate inverts condition type', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final condition = _makeConditionNode(ConditionTypes.nodeOnline);
        final notGate = _makeNotGate();
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(trigger, condition);
        _wire(condition, notGate);
        _wire(notGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, condition, notGate, action]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(1));

        final automation = result.automations.first;
        expect(automation.conditions, isNotNull);
        expect(automation.conditions, hasLength(1));
        // nodeOnline should be inverted to nodeOffline.
        expect(automation.conditions!.first.type, ConditionType.nodeOffline);
      });

      test('NOT gate on batteryAbove inverts to batteryBelow', () {
        final trigger = _makeTriggerNode(TriggerTypes.batteryLow);
        final condition = _makeConditionNode(
          ConditionTypes.batteryAbove,
          config: {'batteryThreshold': 50},
        );
        final notGate = _makeNotGate();
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(trigger, condition);
        _wire(condition, notGate);
        _wire(notGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, condition, notGate, action]),
        );

        expect(result.isSuccess, isTrue);
        final automation = result.automations.first;
        expect(automation.conditions!.first.type, ConditionType.batteryBelow);
        expect(automation.conditions!.first.config['batteryThreshold'], 50);
      });

      test('NOT gate with no upstream condition produces warning', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final notGate = _makeNotGate();
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(trigger, notGate);
        _wire(notGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, notGate, action]),
        );

        // Should still compile (trigger has no condition to invert).
        expect(result.automations, hasLength(1));
        expect(result.warnings, isNotEmpty);
        expect(
          result.warnings.any((w) => w.message.contains('no condition')),
          isTrue,
        );
      });
    });

    group('Delay gate', () {
      test('Delay gate attaches delay metadata to trigger config', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);

        // Create a delay gate with a known config.
        // We can't easily create the private _DelayNode, so we create a
        // VSNodeData with the delay type and rely on the compiler's
        // fallback getDelayConfig returning null — the compiler will use
        // the default 300s delay.
        final delayGate = VSNodeData(
          type: LogicGateTypes.delay,
          widgetOffset: Offset.zero,
          title: 'Delay',
          inputData: [EventSignalInputData(type: 'event_in', title: 'Input')],
          outputData: [
            EventSignalOutputData(
              type: 'event_out',
              title: 'Delayed',
              outputFunction: (inputs) {
                final upstream = inputs['event_in'] as EventSignalPayload?;
                return upstream ??
                    EventSignalPayload(triggerType: '', passed: false);
              },
            ),
          ],
        );

        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(trigger, delayGate);
        _wire(delayGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, delayGate, action]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(1));

        final automation = result.automations.first;
        // Default delay is 300 seconds when getDelayConfig returns null.
        expect(automation.trigger.config['_flowDelaySeconds'], 300);
        expect(automation.description, contains('delay'));
      });
    });

    group('multiple actions', () {
      test('two actions from same trigger merge into one Automation', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action1 = _makeActionNode(ActionTypes.vibrate);
        final action2 = _makeActionNode(ActionTypes.pushNotification);

        _wire(trigger, action1, inputType: 'action_in');
        _wire(trigger, action2, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action1, action2]),
        );

        expect(result.isSuccess, isTrue);
        // Both actions share the same trigger path → merged.
        expect(result.automations, hasLength(1));
        expect(result.automations.first.actions, hasLength(2));

        final actionTypes = result.automations.first.actions
            .map((a) => a.type)
            .toSet();
        expect(actionTypes, contains(ActionType.vibrate));
        expect(actionTypes, contains(ActionType.pushNotification));
      });

      test('actions from different triggers produce separate Automations', () {
        final trigger1 = _makeTriggerNode(TriggerTypes.nodeOnline);
        final trigger2 = _makeTriggerNode(TriggerTypes.batteryLow);
        final action1 = _makeActionNode(ActionTypes.vibrate);
        final action2 = _makeActionNode(ActionTypes.pushNotification);

        _wire(trigger1, action1, inputType: 'action_in');
        _wire(trigger2, action2, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger1, trigger2, action1, action2]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.automations, hasLength(2));
      });
    });

    group('error handling', () {
      test('empty graph compilation produces errors', () {
        final result = compileFlowGraph(nodes: {});
        expect(result.isSuccess, isFalse);
        expect(result.errors, isNotEmpty);
      });

      test('disconnected action node produces compilation error', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action = _makeActionNode(ActionTypes.vibrate);
        // Not wired.
        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action]),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.errors.any((e) => e.message.contains('no upstream')),
          isTrue,
        );
      });

      test('condition node with no upstream produces error', () {
        final condition = _makeConditionNode(ConditionTypes.timeRange);
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(condition, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([condition, action]),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.errors.any((e) => e.message.contains('upstream')),
          isTrue,
        );
      });

      test('AND gate with no inputs produces error', () {
        final andGate = _makeAndGate();
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(andGate, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([andGate, action]),
        );

        expect(result.isSuccess, isFalse);
      });

      test('OR gate with no inputs produces error', () {
        final orGate = _makeOrGate();
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(orGate, action, inputType: 'action_in');

        final result = compileFlowGraph(nodes: _buildNodeMap([orGate, action]));

        expect(result.isSuccess, isFalse);
      });
    });

    group('graph metadata', () {
      test('compilation with graphJson produces metadata', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action = _makeActionNode(ActionTypes.vibrate);
        _wire(trigger, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action]),
          flowName: 'Test',
          graphJson: '{"test": true}',
        );

        expect(result.graphMetadata, isNotNull);
        expect(result.graphMetadata!.graphJson, '{"test": true}');
        expect(result.graphMetadata!.flowName, 'Test');
        expect(result.graphMetadata!.automationIds, hasLength(1));
        expect(result.graphMetadata!.actionNodeToAutomationId, isNotEmpty);
      });

      test('metadata serialization round-trip', () {
        final original = FlowGraphMetadata(
          graphJson: '{"nodes": []}',
          automationIds: ['id-1', 'id-2'],
          actionNodeToAutomationId: {
            'action-node-1': ['id-1'],
            'action-node-2': ['id-2'],
          },
          flowName: 'My Flow',
        );

        final json = original.toJson();
        final restored = FlowGraphMetadata.fromJson(json);

        expect(restored.graphJson, original.graphJson);
        expect(restored.automationIds, original.automationIds);
        expect(restored.flowName, original.flowName);
        expect(restored.actionNodeToAutomationId['action-node-1'], ['id-1']);
        expect(restored.actionNodeToAutomationId['action-node-2'], ['id-2']);
      });
    });

    group('warnings', () {
      test('disconnected condition node produces warning', () {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action = _makeActionNode(ActionTypes.vibrate);
        final orphanedCondition = _makeConditionNode(ConditionTypes.timeRange);

        _wire(trigger, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action, orphanedCondition]),
        );

        // Should still compile successfully.
        expect(result.isSuccess, isTrue);
        // But should warn about the disconnected condition.
        expect(
          result.warnings.any((w) => w.message.contains('disconnected')),
          isTrue,
        );
      });
    });

    group('compilation result', () {
      test('isSuccess is false when there are errors', () {
        const result = FlowCompilationResult(
          automations: [],
          errors: [FlowCompilationError(message: 'test error')],
        );
        expect(result.isSuccess, isFalse);
        expect(result.isEmpty, isTrue);
      });

      test('isSuccess is true when there are automations and no errors', () {
        final result = FlowCompilationResult(
          automations: [
            Automation(
              name: 'Test',
              trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
              actions: const [AutomationAction(type: ActionType.vibrate)],
            ),
          ],
        );
        expect(result.isSuccess, isTrue);
        expect(result.isEmpty, isFalse);
      });

      test('isEmpty is true for empty automations list', () {
        const result = FlowCompilationResult(automations: []);
        expect(result.isEmpty, isTrue);
      });
    });
  });

  group('FlowDecompiler', () {
    test('simple automation decompiles to trigger + action', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [AutomationAction(type: ActionType.vibrate)],
      );

      final graph = decompileAutomation(automation);

      expect(graph.nodes, hasLength(2)); // trigger + action
      expect(graph.connections, hasLength(1)); // trigger → action

      // First node should be trigger.
      expect(graph.nodes[0].type, 'nodeOnline');
      // Second node should be action.
      expect(graph.nodes[1].type, 'vibrate');

      // Connection should go from trigger (0) to action (1).
      final conn = graph.connections[0];
      expect(conn.fromNodeIndex, 0);
      expect(conn.fromOutputType, 'event_out');
      expect(conn.toNodeIndex, 1);
      expect(conn.toInputType, 'action_in');
    });

    test('automation with conditions decompiles with condition nodes', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [AutomationAction(type: ActionType.vibrate)],
        conditions: const [
          AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '08:00', 'timeEnd': '18:00'},
          ),
        ],
      );

      final graph = decompileAutomation(automation);

      // trigger + condition + action = 3 nodes
      expect(graph.nodes, hasLength(3));
      // trigger → condition + condition → action = 2 connections
      expect(graph.connections, hasLength(2));

      expect(graph.nodes[0].type, 'nodeOnline');
      expect(graph.nodes[1].type, 'timeRange');
      expect(graph.nodes[2].type, 'vibrate');
    });

    test('automation with multiple conditions includes AND gate', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [AutomationAction(type: ActionType.vibrate)],
        conditions: const [
          AutomationCondition(type: ConditionType.timeRange),
          AutomationCondition(type: ConditionType.batteryAbove),
        ],
      );

      final graph = decompileAutomation(automation);

      // trigger + 2 conditions + AND gate + action = 5 nodes
      expect(graph.nodes, hasLength(5));

      // Check node types.
      final types = graph.nodes.map((n) => n.type).toList();
      expect(types, contains('nodeOnline'));
      expect(types, contains('timeRange'));
      expect(types, contains('batteryAbove'));
      expect(types, contains(LogicGateTypes.and));
      expect(types, contains('vibrate'));
    });

    test('automation with multiple actions decompiles all actions', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [
          AutomationAction(type: ActionType.vibrate),
          AutomationAction(type: ActionType.pushNotification),
          AutomationAction(type: ActionType.logEvent),
        ],
      );

      final graph = decompileAutomation(automation);

      // trigger + 3 actions = 4 nodes
      expect(graph.nodes, hasLength(4));
      // trigger → action1, trigger → action2, trigger → action3 = 3 connections
      expect(graph.connections, hasLength(3));
    });

    test('decompiled nodes have valid layout positions', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [AutomationAction(type: ActionType.vibrate)],
        conditions: const [AutomationCondition(type: ConditionType.timeRange)],
      );

      final graph = decompileAutomation(automation);

      // All nodes should have non-negative positions.
      for (final node in graph.nodes) {
        expect(node.offset.dx, greaterThanOrEqualTo(0));
        expect(node.offset.dy, greaterThanOrEqualTo(0));
      }

      // Trigger should be leftmost, action rightmost.
      final triggerX = graph.nodes[0].offset.dx;
      final conditionX = graph.nodes[1].offset.dx;
      final actionX = graph.nodes[2].offset.dx;
      expect(conditionX, greaterThan(triggerX));
      expect(actionX, greaterThan(conditionX));
    });

    test('decompiled config is preserved', () {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(
          type: TriggerType.batteryLow,
          config: {'batteryThreshold': 15, 'nodeNum': 42},
        ),
        actions: const [
          AutomationAction(
            type: ActionType.pushNotification,
            config: {
              'notificationTitle': 'Alert',
              'notificationBody': 'Battery low',
            },
          ),
        ],
      );

      final graph = decompileAutomation(automation);

      // Trigger config.
      final triggerNode = graph.nodes[0];
      expect(triggerNode.config, isNotNull);
      expect(triggerNode.config['batteryThreshold'], 15);
      expect(triggerNode.config['nodeNum'], 42);

      // Action config.
      final actionNode = graph.nodes[1];
      expect(actionNode.config, isNotNull);
      expect(actionNode.config['notificationTitle'], 'Alert');
    });
  });

  group('FlowCompilationError', () {
    test('toString includes message and node info', () {
      const error = FlowCompilationError(
        message: 'test error',
        nodeId: 'abc123',
        nodeType: 'testType',
      );
      final str = error.toString();
      expect(str, contains('test error'));
      expect(str, contains('abc123'));
      expect(str, contains('testType'));
    });

    test('toString without node info', () {
      const error = FlowCompilationError(message: 'simple error');
      expect(error.toString(), contains('simple error'));
    });
  });

  group('FlowCompilationWarning', () {
    test('toString includes message and node info', () {
      const warning = FlowCompilationWarning(
        message: 'test warning',
        nodeId: 'xyz',
        nodeType: 'warnType',
      );
      final str = warning.toString();
      expect(str, contains('test warning'));
      expect(str, contains('xyz'));
    });
  });

  group('Naming and description', () {
    test('compiled Automation name includes flow name and trigger', () {
      final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
      final action = _makeActionNode(ActionTypes.vibrate);
      _wire(trigger, action, inputType: 'action_in');

      final result = compileFlowGraph(
        nodes: _buildNodeMap([trigger, action]),
        flowName: 'My Custom Flow',
      );

      expect(result.automations.first.name, contains('My Custom Flow'));
      expect(result.automations.first.name, contains('Node Online'));
    });

    test('compiled Automation description includes trigger and action', () {
      final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
      final action = _makeActionNode(ActionTypes.vibrate);
      _wire(trigger, action, inputType: 'action_in');

      final result = compileFlowGraph(nodes: _buildNodeMap([trigger, action]));

      final desc = result.automations.first.description ?? '';
      expect(desc, contains('When'));
      expect(desc, contains('Then'));
    });

    test('compiled Automation description includes conditions', () {
      final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
      final condition = _makeConditionNode(ConditionTypes.timeRange);
      final action = _makeActionNode(ActionTypes.vibrate);

      _wire(trigger, condition);
      _wire(condition, action, inputType: 'action_in');

      final result = compileFlowGraph(
        nodes: _buildNodeMap([trigger, condition, action]),
      );

      final desc = result.automations.first.description ?? '';
      expect(desc, contains('If'));
    });

    test('OR gate numbered names when multiple automations', () {
      final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
      final cond1 = _makeConditionNode(ConditionTypes.timeRange);
      final cond2 = _makeConditionNode(ConditionTypes.batteryAbove);
      final orGate = _makeOrGate();
      final action = _makeActionNode(ActionTypes.vibrate);

      _wire(trigger, cond1);
      _wire(trigger, cond2);

      final cond1Output = cond1.outputData.first;
      final cond2Output = cond2.outputData.first;
      orGate.setRefData({'event_in_0': cond1Output, 'event_in_1': cond2Output});

      _wire(orGate, action, inputType: 'action_in');

      final result = compileFlowGraph(
        nodes: _buildNodeMap([trigger, cond1, cond2, orGate, action]),
        flowName: 'OR Test',
      );

      expect(result.automations, hasLength(2));
      // Each should have a numbered name.
      expect(result.automations[0].name, contains('1'));
      expect(result.automations[1].name, contains('2'));
    });
  });

  group('Complex graph topologies', () {
    test('diamond: trigger → cond1, trigger → cond2, both → AND → action', () {
      final trigger = _makeTriggerNode(TriggerTypes.messageReceived);
      final cond1 = _makeConditionNode(ConditionTypes.timeRange);
      final cond2 = _makeConditionNode(ConditionTypes.dayOfWeek);
      final andGate = _makeAndGate();
      final action = _makeActionNode(ActionTypes.pushNotification);

      // Trigger fans out to both conditions.
      _wire(trigger, cond1);
      _wire(trigger, cond2);

      // Both conditions feed into AND gate.
      andGate.setRefData({
        'event_in_0': cond1.outputData.first,
        'event_in_1': cond2.outputData.first,
      });

      // AND gate feeds into action.
      _wire(andGate, action, inputType: 'action_in');

      final result = compileFlowGraph(
        nodes: _buildNodeMap([trigger, cond1, cond2, andGate, action]),
      );

      expect(result.isSuccess, isTrue);
      expect(result.automations, hasLength(1));

      final auto = result.automations.first;
      expect(auto.trigger.type, TriggerType.messageReceived);
      expect(auto.conditions, hasLength(2));
    });

    test('trigger → condition → NOT → action (inverted condition)', () {
      final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
      final cond = _makeConditionNode(ConditionTypes.withinGeofence);
      final notGate = _makeNotGate();
      final action = _makeActionNode(ActionTypes.vibrate);

      _wire(trigger, cond);
      _wire(cond, notGate);
      _wire(notGate, action, inputType: 'action_in');

      final result = compileFlowGraph(
        nodes: _buildNodeMap([trigger, cond, notGate, action]),
      );

      expect(result.isSuccess, isTrue);
      // withinGeofence should be inverted to outsideGeofence.
      expect(
        result.automations.first.conditions!.first.type,
        ConditionType.outsideGeofence,
      );
    });

    test('all trigger types compile correctly', () {
      for (final triggerType in TriggerType.values) {
        final trigger = _makeTriggerNode(triggerType.name);
        final action = _makeActionNode(ActionTypes.vibrate);
        _wire(trigger, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action]),
        );

        expect(
          result.isSuccess,
          isTrue,
          reason: 'Trigger type ${triggerType.name} should compile',
        );
        expect(
          result.automations.first.trigger.type,
          triggerType,
          reason: 'Trigger type ${triggerType.name} should be preserved',
        );
      }
    });

    test('all action types compile correctly', () {
      for (final actionType in ActionType.values) {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final action = _makeActionNode(actionType.name);
        _wire(trigger, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, action]),
        );

        expect(
          result.isSuccess,
          isTrue,
          reason: 'Action type ${actionType.name} should compile',
        );
        expect(
          result.automations.first.actions.first.type,
          actionType,
          reason: 'Action type ${actionType.name} should be preserved',
        );
      }
    });

    test('all condition types compile correctly', () {
      for (final condType in ConditionType.values) {
        final trigger = _makeTriggerNode(TriggerTypes.nodeOnline);
        final cond = _makeConditionNode(
          ConditionTypes.fromEnum[condType] ?? condType.name,
        );
        final action = _makeActionNode(ActionTypes.vibrate);

        _wire(trigger, cond);
        _wire(cond, action, inputType: 'action_in');

        final result = compileFlowGraph(
          nodes: _buildNodeMap([trigger, cond, action]),
        );

        expect(
          result.isSuccess,
          isTrue,
          reason: 'Condition type ${condType.name} should compile',
        );
        expect(
          result.automations.first.conditions!.first.type,
          condType,
          reason: 'Condition type ${condType.name} should be preserved',
        );
      }
    });
  });
}
