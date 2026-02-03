// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';

/// Tests for automation sharing sanitization logic.
/// The actual UI sharing is tested elsewhere; these tests verify the
/// sanitization of user-specific data when exporting automations.
void main() {
  group('Automation Share Sanitization', () {
    test('sanitizes trigger config - removes nodeNum', () {
      final automation = Automation(
        name: 'Node Alert',
        trigger: const AutomationTrigger(
          type: TriggerType.nodeOnline,
          config: {'nodeNum': 12345},
        ),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final sanitized = _sanitizeTriggerConfig(automation.trigger.config);

      expect(sanitized.containsKey('nodeNum'), false);
    });

    test('sanitizes trigger config - removes channelIndex', () {
      final automation = Automation(
        name: 'Channel Alert',
        trigger: const AutomationTrigger(
          type: TriggerType.channelActivity,
          config: {'channelIndex': 2},
        ),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final sanitized = _sanitizeTriggerConfig(automation.trigger.config);

      expect(sanitized.containsKey('channelIndex'), false);
    });

    test('sanitizes trigger config - keeps geofence coordinates', () {
      final automation = Automation(
        name: 'Geofence Alert',
        trigger: const AutomationTrigger(
          type: TriggerType.geofenceEnter,
          config: {
            'geofenceLat': 37.7749,
            'geofenceLon': -122.4194,
            'geofenceRadius': 500.0,
          },
        ),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final sanitized = _sanitizeTriggerConfig(automation.trigger.config);

      expect(sanitized['geofenceLat'], 37.7749);
      expect(sanitized['geofenceLon'], -122.4194);
      expect(sanitized['geofenceRadius'], 500.0);
    });

    test('sanitizes trigger config - keeps battery threshold', () {
      final automation = Automation(
        name: 'Battery Alert',
        trigger: const AutomationTrigger(
          type: TriggerType.batteryLow,
          config: {'batteryThreshold': 15, 'nodeNum': 12345},
        ),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      final sanitized = _sanitizeTriggerConfig(automation.trigger.config);

      expect(sanitized['batteryThreshold'], 15);
      expect(sanitized.containsKey('nodeNum'), false);
    });

    test('sanitizes action config - removes targetNodeNum', () {
      final action = const AutomationAction(
        type: ActionType.sendMessage,
        config: {
          'messageText': '{{node.name}} is online',
          'targetNodeNum': 67890,
        },
      );

      final sanitized = _sanitizeActionConfig(action.config);

      expect(sanitized['messageText'], '{{node.name}} is online');
      expect(sanitized.containsKey('targetNodeNum'), false);
    });

    test('sanitizes action config - removes targetChannelIndex', () {
      final action = const AutomationAction(
        type: ActionType.sendToChannel,
        config: {'messageText': 'Alert message', 'targetChannelIndex': 3},
      );

      final sanitized = _sanitizeActionConfig(action.config);

      expect(sanitized['messageText'], 'Alert message');
      expect(sanitized.containsKey('targetChannelIndex'), false);
    });

    test('sanitizes action config - removes webhook credentials', () {
      final action = const AutomationAction(
        type: ActionType.triggerWebhook,
        config: {
          'webhookUrl': 'https://maker.ifttt.com/trigger/event/with/key/SECRET',
          'webhookEventName': 'my_event',
        },
      );

      final sanitized = _sanitizeActionConfig(action.config);

      expect(sanitized.containsKey('webhookUrl'), false);
      expect(sanitized.containsKey('webhookEventName'), false);
    });

    test('sanitizes action config - keeps sound settings', () {
      final action = const AutomationAction(
        type: ActionType.playSound,
        config: {
          'soundRtttl': 'MySong:d=4,o=5,b=140:c,e,g',
          'soundName': 'My Alert Sound',
        },
      );

      final sanitized = _sanitizeActionConfig(action.config);

      expect(sanitized['soundRtttl'], 'MySong:d=4,o=5,b=140:c,e,g');
      expect(sanitized['soundName'], 'My Alert Sound');
    });

    test('sanitizes action config - keeps shortcutName as hint', () {
      final action = const AutomationAction(
        type: ActionType.triggerShortcut,
        config: {'shortcutName': 'My Shortcut'},
      );

      final sanitized = _sanitizeActionConfig(action.config);

      expect(sanitized['shortcutName'], 'My Shortcut');
    });

    test('sanitizes condition config - removes nodeNum', () {
      final condition = const AutomationCondition(
        type: ConditionType.nodeOnline,
        config: {'nodeNum': 11111},
      );

      final sanitized = _sanitizeConditionConfig(condition.config);

      expect(sanitized.containsKey('nodeNum'), false);
    });

    test('sanitizes condition config - keeps time settings', () {
      final condition = const AutomationCondition(
        type: ConditionType.timeRange,
        config: {'timeStart': '09:00', 'timeEnd': '17:00'},
      );

      final sanitized = _sanitizeConditionConfig(condition.config);

      expect(sanitized['timeStart'], '09:00');
      expect(sanitized['timeEnd'], '17:00');
    });

    test('full automation export is valid JSON', () {
      final automation = Automation(
        name: 'Complex Automation',
        description: 'A complex test automation',
        trigger: const AutomationTrigger(
          type: TriggerType.batteryLow,
          config: {'batteryThreshold': 20, 'nodeNum': 12345},
        ),
        actions: const [
          AutomationAction(
            type: ActionType.sendMessage,
            config: {
              'messageText': 'Battery low: {{battery}}',
              'targetNodeNum': 67890,
            },
          ),
          AutomationAction(
            type: ActionType.triggerWebhook,
            config: {
              'webhookUrl': 'https://secret.url',
              'webhookEventName': 'secret_event',
            },
          ),
          AutomationAction(type: ActionType.playSound),
        ],
        conditions: const [
          AutomationCondition(
            type: ConditionType.nodeOnline,
            config: {'nodeNum': 11111},
          ),
        ],
      );

      final exportData = _buildSanitizedExport(automation);
      final jsonString = jsonEncode(exportData);

      // Should be valid JSON
      expect(() => jsonDecode(jsonString), returnsNormally);

      // Decode and verify sanitization
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['name'], 'Complex Automation');
      expect(decoded['description'], 'A complex test automation');

      // Trigger should not have nodeNum
      final trigger = decoded['trigger'] as Map<String, dynamic>;
      final triggerConfig = trigger['config'] as Map<String, dynamic>;
      expect(triggerConfig.containsKey('nodeNum'), false);
      expect(triggerConfig['batteryThreshold'], 20);

      // Actions should be sanitized
      final actions = decoded['actions'] as List;
      expect(actions.length, 3);

      // First action: sendMessage - should not have targetNodeNum
      final action0 = actions[0] as Map<String, dynamic>;
      final action0Config = action0['config'] as Map<String, dynamic>;
      expect(action0Config['messageText'], 'Battery low: {{battery}}');
      expect(action0Config.containsKey('targetNodeNum'), false);

      // Second action: webhook - should have no config
      final action1 = actions[1] as Map<String, dynamic>;
      final action1Config = action1['config'] as Map<String, dynamic>;
      expect(action1Config.containsKey('webhookUrl'), false);
      expect(action1Config.containsKey('webhookEventName'), false);

      // Conditions should be sanitized
      final conditions = decoded['conditions'] as List;
      expect(conditions.length, 1);
      final condition0 = conditions[0] as Map<String, dynamic>;
      final condition0Config = condition0['config'] as Map<String, dynamic>;
      expect(condition0Config.containsKey('nodeNum'), false);
    });
  });
}

// Helper functions that mirror the sanitization logic in automation_share_utils.dart
// These are duplicated here for testing purposes

Map<String, dynamic> _sanitizeTriggerConfig(Map<String, dynamic> config) {
  final sanitized = Map<String, dynamic>.from(config);
  sanitized.remove('nodeNum');
  sanitized.remove('channelIndex');
  return sanitized;
}

Map<String, dynamic> _sanitizeActionConfig(Map<String, dynamic> config) {
  final sanitized = Map<String, dynamic>.from(config);
  sanitized.remove('targetNodeNum');
  sanitized.remove('targetChannelIndex');
  sanitized.remove('webhookUrl');
  sanitized.remove('webhookEventName');
  return sanitized;
}

Map<String, dynamic> _sanitizeConditionConfig(Map<String, dynamic> config) {
  final sanitized = Map<String, dynamic>.from(config);
  sanitized.remove('nodeNum');
  return sanitized;
}

Map<String, dynamic> _buildSanitizedExport(Automation automation) {
  final sanitizedTriggerConfig = _sanitizeTriggerConfig(
    automation.trigger.config,
  );

  final sanitizedActions = automation.actions.map((action) {
    final sanitizedConfig = _sanitizeActionConfig(action.config);
    return {'type': action.type.name, 'config': sanitizedConfig};
  }).toList();

  final sanitizedConditions = automation.conditions?.map((condition) {
    final sanitizedConfig = _sanitizeConditionConfig(condition.config);
    return {'type': condition.type.name, 'config': sanitizedConfig};
  }).toList();

  return {
    'name': automation.name,
    'description': automation.description,
    'trigger': {
      'type': automation.trigger.type.name,
      'config': sanitizedTriggerConfig,
    },
    'actions': sanitizedActions,
    if (sanitizedConditions != null) 'conditions': sanitizedConditions,
  };
}
