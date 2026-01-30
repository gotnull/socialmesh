import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/automations/models/automation.dart';

void main() {
  group('Automation', () {
    test('creates with required fields and generates ID', () {
      final automation = Automation(
        name: 'Test Automation',
        trigger: const AutomationTrigger(type: TriggerType.messageReceived),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );

      expect(automation.name, 'Test Automation');
      expect(automation.id, isNotEmpty);
      expect(automation.enabled, true);
      expect(automation.triggerCount, 0);
      expect(automation.lastTriggered, isNull);
    });

    test('creates with explicit ID', () {
      final automation = Automation(
        id: 'custom-id',
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );

      expect(automation.id, 'custom-id');
    });

    test('copyWith preserves unchanged fields', () {
      final original = Automation(
        id: 'test-id',
        name: 'Original',
        description: 'Description',
        enabled: true,
        trigger: const AutomationTrigger(type: TriggerType.batteryLow),
        actions: const [AutomationAction(type: ActionType.vibrate)],
        triggerCount: 5,
      );

      final modified = original.copyWith(name: 'Modified');

      expect(modified.id, original.id);
      expect(modified.name, 'Modified');
      expect(modified.description, original.description);
      expect(modified.enabled, original.enabled);
      expect(modified.triggerCount, original.triggerCount);
    });

    test('toJson and fromJson round-trip', () {
      final original = Automation(
        id: 'test-id',
        name: 'Test Automation',
        description: 'A test description',
        enabled: true,
        trigger: const AutomationTrigger(
          type: TriggerType.batteryLow,
          config: {'batteryThreshold': 15, 'nodeNum': 12345},
        ),
        actions: const [
          AutomationAction(
            type: ActionType.pushNotification,
            config: {
              'notificationTitle': 'Battery Low',
              'notificationBody': '{{node.name}} is at {{battery}}',
            },
          ),
          AutomationAction(type: ActionType.vibrate),
        ],
        conditions: const [
          AutomationCondition(
            type: ConditionType.timeRange,
            config: {'timeStart': '09:00', 'timeEnd': '17:00'},
          ),
        ],
        triggerCount: 10,
      );

      final json = original.toJson();
      final restored = Automation.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.enabled, original.enabled);
      expect(restored.trigger.type, original.trigger.type);
      expect(restored.trigger.batteryThreshold, 15);
      expect(restored.trigger.nodeNum, 12345);
      expect(restored.actions.length, 2);
      expect(restored.actions[0].type, ActionType.pushNotification);
      expect(restored.actions[0].notificationTitle, 'Battery Low');
      expect(restored.conditions?.length, 1);
      expect(restored.conditions![0].type, ConditionType.timeRange);
      expect(restored.triggerCount, 10);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test',
        'name': 'Test',
        'trigger': {'type': 'messageReceived', 'config': {}},
        'actions': [],
        'createdAt': DateTime.now().toIso8601String(),
      };

      final automation = Automation.fromJson(json);

      expect(automation.description, isNull);
      expect(automation.enabled, true);
      expect(automation.conditions, isNull);
      expect(automation.lastTriggered, isNull);
      expect(automation.triggerCount, 0);
    });
  });

  group('AutomationTrigger', () {
    test('creates with defaults', () {
      const trigger = AutomationTrigger(type: TriggerType.nodeOnline);

      expect(trigger.type, TriggerType.nodeOnline);
      expect(trigger.config, isEmpty);
      expect(trigger.nodeNum, isNull);
      expect(trigger.batteryThreshold, 20); // default
    });

    test('nodeNum filter from config', () {
      const trigger = AutomationTrigger(
        type: TriggerType.nodeOffline,
        config: {'nodeNum': 999},
      );

      expect(trigger.nodeNum, 999);
    });

    test('batteryThreshold from config', () {
      const trigger = AutomationTrigger(
        type: TriggerType.batteryLow,
        config: {'batteryThreshold': 10},
      );

      expect(trigger.batteryThreshold, 10);
    });

    test('keyword from config for messageContains', () {
      const trigger = AutomationTrigger(
        type: TriggerType.messageContains,
        config: {'keyword': 'SOS'},
      );

      expect(trigger.keyword, 'SOS');
    });

    test('geofence parameters from config', () {
      const trigger = AutomationTrigger(
        type: TriggerType.geofenceEnter,
        config: {
          'geofenceLat': -33.8688,
          'geofenceLon': 151.2093,
          'geofenceRadius': 1000.0,
        },
      );

      expect(trigger.geofenceLat, -33.8688);
      expect(trigger.geofenceLon, 151.2093);
      expect(trigger.geofenceRadius, 1000.0);
    });

    test('geofenceRadius has default value', () {
      const trigger = AutomationTrigger(type: TriggerType.geofenceEnter);

      expect(trigger.geofenceRadius, 500); // default
    });

    test('silentMinutes from config', () {
      const trigger = AutomationTrigger(
        type: TriggerType.nodeSilent,
        config: {'silentMinutes': 60},
      );

      expect(trigger.silentMinutes, 60);
    });

    test('silentMinutes has default value', () {
      const trigger = AutomationTrigger(type: TriggerType.nodeSilent);

      expect(trigger.silentMinutes, 30); // default
    });

    test('signalThreshold from config', () {
      const trigger = AutomationTrigger(
        type: TriggerType.signalWeak,
        config: {'signalThreshold': -15},
      );

      expect(trigger.signalThreshold, -15);
    });

    test('channelIndex from config', () {
      const trigger = AutomationTrigger(
        type: TriggerType.channelActivity,
        config: {'channelIndex': 2},
      );

      expect(trigger.channelIndex, 2);
    });

    test('toJson and fromJson round-trip', () {
      const original = AutomationTrigger(
        type: TriggerType.geofenceExit,
        config: {
          'nodeNum': 123,
          'geofenceLat': -37.0,
          'geofenceLon': 145.0,
          'geofenceRadius': 250.0,
        },
      );

      final json = original.toJson();
      final restored = AutomationTrigger.fromJson(json);

      expect(restored.type, TriggerType.geofenceExit);
      expect(restored.nodeNum, 123);
      expect(restored.geofenceLat, -37.0);
      expect(restored.geofenceLon, 145.0);
      expect(restored.geofenceRadius, 250.0);
    });

    test('fromJson handles unknown trigger type gracefully', () {
      final json = {'type': 'unknownType', 'config': {}};

      final trigger = AutomationTrigger.fromJson(json);

      expect(trigger.type, TriggerType.messageReceived); // fallback
    });

    test('copyWith creates new instance with updated values', () {
      const original = AutomationTrigger(
        type: TriggerType.batteryLow,
        config: {'batteryThreshold': 20},
      );

      final modified = original.copyWith(
        config: {'batteryThreshold': 10, 'nodeNum': 999},
      );

      expect(modified.type, TriggerType.batteryLow);
      expect(modified.batteryThreshold, 10);
      expect(modified.nodeNum, 999);
    });

    group('validate', () {
      test('returns null for triggers without required config', () {
        // These triggers don't require specific config
        const triggers = [
          AutomationTrigger(type: TriggerType.nodeOnline),
          AutomationTrigger(type: TriggerType.nodeOffline),
          AutomationTrigger(type: TriggerType.batteryLow),
          AutomationTrigger(type: TriggerType.batteryFull),
          AutomationTrigger(type: TriggerType.messageReceived),
          AutomationTrigger(type: TriggerType.positionChanged),
          AutomationTrigger(type: TriggerType.nodeSilent),
          AutomationTrigger(type: TriggerType.signalWeak),
          AutomationTrigger(type: TriggerType.channelActivity),
          AutomationTrigger(type: TriggerType.manual),
        ];

        for (final trigger in triggers) {
          expect(
            trigger.validate(),
            isNull,
            reason: '${trigger.type} should not require validation',
          );
        }
      });

      test('messageContains requires keyword', () {
        const emptyKeyword = AutomationTrigger(
          type: TriggerType.messageContains,
          config: {},
        );
        expect(emptyKeyword.validate(), isNotNull);

        const blankKeyword = AutomationTrigger(
          type: TriggerType.messageContains,
          config: {'keyword': '   '},
        );
        expect(blankKeyword.validate(), isNotNull);

        const validKeyword = AutomationTrigger(
          type: TriggerType.messageContains,
          config: {'keyword': 'SOS'},
        );
        expect(validKeyword.validate(), isNull);
      });

      test('geofenceEnter requires lat/lon', () {
        const noCoords = AutomationTrigger(
          type: TriggerType.geofenceEnter,
          config: {},
        );
        expect(noCoords.validate(), isNotNull);

        const onlyLat = AutomationTrigger(
          type: TriggerType.geofenceEnter,
          config: {'geofenceLat': 37.0},
        );
        expect(onlyLat.validate(), isNotNull);

        const onlyLon = AutomationTrigger(
          type: TriggerType.geofenceEnter,
          config: {'geofenceLon': -122.0},
        );
        expect(onlyLon.validate(), isNotNull);

        const validCoords = AutomationTrigger(
          type: TriggerType.geofenceEnter,
          config: {'geofenceLat': 37.0, 'geofenceLon': -122.0},
        );
        expect(validCoords.validate(), isNull);
      });

      test('geofenceExit requires lat/lon', () {
        const noCoords = AutomationTrigger(
          type: TriggerType.geofenceExit,
          config: {},
        );
        expect(noCoords.validate(), isNotNull);

        const validCoords = AutomationTrigger(
          type: TriggerType.geofenceExit,
          config: {'geofenceLat': 37.0, 'geofenceLon': -122.0},
        );
        expect(validCoords.validate(), isNull);
      });

      test('scheduled requires schedule', () {
        const noSchedule = AutomationTrigger(
          type: TriggerType.scheduled,
          config: {},
        );
        expect(noSchedule.validate(), isNotNull);

        const blankSchedule = AutomationTrigger(
          type: TriggerType.scheduled,
          config: {'schedule': '   '},
        );
        expect(blankSchedule.validate(), isNotNull);

        const validSchedule = AutomationTrigger(
          type: TriggerType.scheduled,
          config: {'schedule': '0 9 * * *'},
        );
        expect(validSchedule.validate(), isNull);
      });
    });
  });

  group('AutomationAction', () {
    test('creates with defaults', () {
      const action = AutomationAction(type: ActionType.vibrate);

      expect(action.type, ActionType.vibrate);
      expect(action.config, isEmpty);
    });

    test('messageText from config', () {
      const action = AutomationAction(
        type: ActionType.sendMessage,
        config: {'messageText': 'Hello {{node.name}}!'},
      );

      expect(action.messageText, 'Hello {{node.name}}!');
    });

    test('targetNodeNum from config', () {
      const action = AutomationAction(
        type: ActionType.sendMessage,
        config: {'targetNodeNum': 12345},
      );

      expect(action.targetNodeNum, 12345);
    });

    test('targetChannelIndex from config', () {
      const action = AutomationAction(
        type: ActionType.sendToChannel,
        config: {'targetChannelIndex': 1},
      );

      expect(action.targetChannelIndex, 1);
    });

    test('webhook config from config', () {
      const action = AutomationAction(
        type: ActionType.triggerWebhook,
        config: {
          'webhookUrl': 'https://example.com/webhook',
          'webhookEventName': 'test_event',
        },
      );

      expect(action.webhookUrl, 'https://example.com/webhook');
      expect(action.webhookEventName, 'test_event');
    });

    test('notification config from config', () {
      const action = AutomationAction(
        type: ActionType.pushNotification,
        config: {
          'notificationTitle': 'Alert!',
          'notificationBody': 'Something happened',
        },
      );

      expect(action.notificationTitle, 'Alert!');
      expect(action.notificationBody, 'Something happened');
    });

    test('shortcutName from config', () {
      const action = AutomationAction(
        type: ActionType.triggerShortcut,
        config: {'shortcutName': 'My Shortcut'},
      );

      expect(action.shortcutName, 'My Shortcut');
    });

    test('toJson and fromJson round-trip', () {
      const original = AutomationAction(
        type: ActionType.sendMessage,
        config: {'messageText': 'Test message', 'targetNodeNum': 999},
      );

      final json = original.toJson();
      final restored = AutomationAction.fromJson(json);

      expect(restored.type, ActionType.sendMessage);
      expect(restored.messageText, 'Test message');
      expect(restored.targetNodeNum, 999);
    });

    test('fromJson handles unknown action type gracefully', () {
      final json = {'type': 'unknownAction', 'config': {}};

      final action = AutomationAction.fromJson(json);

      expect(action.type, ActionType.pushNotification); // fallback
    });

    test('copyWith creates new instance with updated values', () {
      const original = AutomationAction(
        type: ActionType.sendMessage,
        config: {'messageText': 'Original'},
      );

      final modified = original.copyWith(
        config: {'messageText': 'Modified', 'targetNodeNum': 123},
      );

      expect(modified.type, ActionType.sendMessage);
      expect(modified.messageText, 'Modified');
      expect(modified.targetNodeNum, 123);
    });

    group('validate', () {
      test('returns null for actions without required config', () {
        // These actions don't require specific config
        const actions = [
          AutomationAction(type: ActionType.playSound),
          AutomationAction(type: ActionType.vibrate),
          AutomationAction(type: ActionType.pushNotification),
          AutomationAction(type: ActionType.logEvent),
          AutomationAction(type: ActionType.updateWidget),
        ];

        for (final action in actions) {
          expect(
            action.validate(),
            isNull,
            reason: '${action.type} should not require validation',
          );
        }
      });

      test('sendMessage requires messageText and targetNodeNum', () {
        const noConfig = AutomationAction(
          type: ActionType.sendMessage,
          config: {},
        );
        expect(noConfig.validate(), isNotNull);

        const onlyMessage = AutomationAction(
          type: ActionType.sendMessage,
          config: {'messageText': 'Hello'},
        );
        expect(onlyMessage.validate(), isNotNull);

        const onlyTarget = AutomationAction(
          type: ActionType.sendMessage,
          config: {'targetNodeNum': 123},
        );
        expect(onlyTarget.validate(), isNotNull);

        const blankMessage = AutomationAction(
          type: ActionType.sendMessage,
          config: {'messageText': '   ', 'targetNodeNum': 123},
        );
        expect(blankMessage.validate(), isNotNull);

        const valid = AutomationAction(
          type: ActionType.sendMessage,
          config: {'messageText': 'Hello', 'targetNodeNum': 123},
        );
        expect(valid.validate(), isNull);
      });

      test('sendToChannel requires messageText', () {
        const noMessage = AutomationAction(
          type: ActionType.sendToChannel,
          config: {},
        );
        expect(noMessage.validate(), isNotNull);

        const blankMessage = AutomationAction(
          type: ActionType.sendToChannel,
          config: {'messageText': '   '},
        );
        expect(blankMessage.validate(), isNotNull);

        const valid = AutomationAction(
          type: ActionType.sendToChannel,
          config: {'messageText': 'Broadcast message'},
        );
        expect(valid.validate(), isNull);
      });

      test('triggerWebhook requires webhookEventName', () {
        const noEventName = AutomationAction(
          type: ActionType.triggerWebhook,
          config: {},
        );
        expect(noEventName.validate(), isNotNull);

        const blankEventName = AutomationAction(
          type: ActionType.triggerWebhook,
          config: {'webhookEventName': '   '},
        );
        expect(blankEventName.validate(), isNotNull);

        const valid = AutomationAction(
          type: ActionType.triggerWebhook,
          config: {'webhookEventName': 'battery_low'},
        );
        expect(valid.validate(), isNull);
      });

      test('triggerShortcut requires shortcutName', () {
        const noName = AutomationAction(
          type: ActionType.triggerShortcut,
          config: {},
        );
        expect(noName.validate(), isNotNull);

        const blankName = AutomationAction(
          type: ActionType.triggerShortcut,
          config: {'shortcutName': '   '},
        );
        expect(blankName.validate(), isNotNull);

        const valid = AutomationAction(
          type: ActionType.triggerShortcut,
          config: {'shortcutName': 'Alert Shortcut'},
        );
        expect(valid.validate(), isNull);
      });
    });
  });

  group('AutomationCondition', () {
    test('creates with defaults', () {
      const condition = AutomationCondition(type: ConditionType.nodeOnline);

      expect(condition.type, ConditionType.nodeOnline);
      expect(condition.config, isEmpty);
    });

    test('timeRange config', () {
      const condition = AutomationCondition(
        type: ConditionType.timeRange,
        config: {'timeStart': '08:00', 'timeEnd': '18:00'},
      );

      expect(condition.timeStart, '08:00');
      expect(condition.timeEnd, '18:00');
    });

    test('daysOfWeek config', () {
      const condition = AutomationCondition(
        type: ConditionType.dayOfWeek,
        config: {
          'daysOfWeek': [1, 2, 3, 4, 5],
        }, // Mon-Fri
      );

      expect(condition.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('batteryThreshold from config', () {
      const condition = AutomationCondition(
        type: ConditionType.batteryAbove,
        config: {'batteryThreshold': 80},
      );

      expect(condition.batteryThreshold, 80);
    });

    test('batteryThreshold has default value', () {
      const condition = AutomationCondition(type: ConditionType.batteryBelow);

      expect(condition.batteryThreshold, 50); // default
    });

    test('nodeNum from config', () {
      const condition = AutomationCondition(
        type: ConditionType.nodeOnline,
        config: {'nodeNum': 456},
      );

      expect(condition.nodeNum, 456);
    });

    test('toJson and fromJson round-trip', () {
      const original = AutomationCondition(
        type: ConditionType.timeRange,
        config: {'timeStart': '09:00', 'timeEnd': '17:00'},
      );

      final json = original.toJson();
      final restored = AutomationCondition.fromJson(json);

      expect(restored.type, ConditionType.timeRange);
      expect(restored.timeStart, '09:00');
      expect(restored.timeEnd, '17:00');
    });

    test('fromJson handles unknown condition type gracefully', () {
      final json = {'type': 'unknownCondition', 'config': {}};

      final condition = AutomationCondition.fromJson(json);

      expect(condition.type, ConditionType.nodeOnline); // fallback
    });
  });

  group('AutomationEvent', () {
    test('creates with required fields', () {
      final event = AutomationEvent(type: TriggerType.nodeOnline, nodeNum: 123);

      expect(event.type, TriggerType.nodeOnline);
      expect(event.nodeNum, 123);
      expect(event.timestamp, isNotNull);
    });

    test('creates with all fields', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final event = AutomationEvent(
        type: TriggerType.positionChanged,
        nodeNum: 456,
        nodeName: 'Test Node',
        batteryLevel: 85,
        latitude: -37.8136,
        longitude: 144.9631,
        messageText: 'Hello',
        channelIndex: 0,
        snr: -5,
        timestamp: timestamp,
      );

      expect(event.nodeNum, 456);
      expect(event.nodeName, 'Test Node');
      expect(event.batteryLevel, 85);
      expect(event.latitude, -37.8136);
      expect(event.longitude, 144.9631);
      expect(event.messageText, 'Hello');
      expect(event.channelIndex, 0);
      expect(event.snr, -5);
      expect(event.timestamp, timestamp);
    });
  });

  group('AutomationLogEntry', () {
    test('creates successfully', () {
      final entry = AutomationLogEntry(
        automationId: 'auto-1',
        automationName: 'Test Automation',
        timestamp: DateTime(2024, 1, 15, 10, 30),
        success: true,
        triggerDetails: 'Node came online',
        actionsExecuted: ['Push notification', 'Vibrate'],
      );

      expect(entry.automationId, 'auto-1');
      expect(entry.automationName, 'Test Automation');
      expect(entry.success, true);
      expect(entry.actionsExecuted.length, 2);
      expect(entry.errorMessage, isNull);
    });

    test('creates with error message', () {
      final entry = AutomationLogEntry(
        automationId: 'auto-1',
        automationName: 'Test',
        timestamp: DateTime.now(),
        success: false,
        actionsExecuted: [],
        errorMessage: 'Failed to send message',
      );

      expect(entry.success, false);
      expect(entry.errorMessage, 'Failed to send message');
    });

    test('toJson and fromJson round-trip', () {
      final original = AutomationLogEntry(
        automationId: 'auto-1',
        automationName: 'Test',
        timestamp: DateTime(2024, 1, 15, 10, 30),
        success: true,
        triggerDetails: 'Battery at 15%',
        actionsExecuted: ['Push notification'],
      );

      final json = original.toJson();
      final restored = AutomationLogEntry.fromJson(json);

      expect(restored.automationId, original.automationId);
      expect(restored.automationName, original.automationName);
      expect(restored.success, original.success);
      expect(restored.triggerDetails, original.triggerDetails);
      expect(restored.actionsExecuted, original.actionsExecuted);
    });
  });

  group('TriggerType', () {
    test('all trigger types have display names', () {
      for (final type in TriggerType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('all trigger types have icons', () {
      for (final type in TriggerType.values) {
        expect(type.icon, isNotNull);
      }
    });

    test('all trigger types have categories', () {
      for (final type in TriggerType.values) {
        expect(type.category, isNotEmpty);
      }
    });

    test('categories are valid', () {
      final validCategories = {
        'Node Status',
        'Battery',
        'Messages',
        'Location',
        'Time',
        'Signal',
        'Sensors',
        'Manual',
      };
      for (final type in TriggerType.values) {
        expect(
          validCategories.contains(type.category),
          isTrue,
          reason: '${type.name} has invalid category: ${type.category}',
        );
      }
    });
  });

  group('ActionType', () {
    test('all action types have display names', () {
      for (final type in ActionType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('all action types have icons', () {
      for (final type in ActionType.values) {
        expect(type.icon, isNotNull);
      }
    });
  });

  group('ConditionType', () {
    test('all condition types have display names', () {
      for (final type in ConditionType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('all condition types have icons', () {
      for (final type in ConditionType.values) {
        expect(type.icon, isNotNull);
      }
    });
  });
}
