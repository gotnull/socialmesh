import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/automations/automation_repository.dart';
import 'package:socialmesh/features/automations/models/automation.dart';

void main() {
  late AutomationRepository repository;

  setUp(() async {
    // Initialize SharedPreferences with empty values
    SharedPreferences.setMockInitialValues({});
    repository = AutomationRepository();
    await repository.init();
  });

  group('AutomationRepository - Basic CRUD', () {
    test('starts with empty automations list', () {
      expect(repository.automations, isEmpty);
    });

    test('addAutomation adds to list', () async {
      final automation = Automation(
        name: 'Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );

      await repository.addAutomation(automation);

      expect(repository.automations.length, 1);
      expect(repository.automations.first.name, 'Test');
    });

    test('updateAutomation updates existing automation', () async {
      final automation = Automation(
        id: 'test-id',
        name: 'Original',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );
      await repository.addAutomation(automation);

      final updated = automation.copyWith(name: 'Updated');
      await repository.updateAutomation(updated);

      expect(repository.automations.length, 1);
      expect(repository.automations.first.name, 'Updated');
    });

    test('deleteAutomation removes from list', () async {
      final automation = Automation(
        id: 'delete-me',
        name: 'To Delete',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );
      await repository.addAutomation(automation);
      expect(repository.automations.length, 1);

      await repository.deleteAutomation('delete-me');

      expect(repository.automations, isEmpty);
    });

    test('getAutomation returns correct automation', () async {
      final automation1 = Automation(
        id: 'auto-1',
        name: 'First',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );
      final automation2 = Automation(
        id: 'auto-2',
        name: 'Second',
        trigger: const AutomationTrigger(type: TriggerType.nodeOffline),
        actions: const [],
      );
      await repository.addAutomation(automation1);
      await repository.addAutomation(automation2);

      final result = repository.getAutomation('auto-2');

      expect(result, isNotNull);
      expect(result!.name, 'Second');
    });

    test('getAutomation returns null for non-existent ID', () async {
      final result = repository.getAutomation('non-existent');

      expect(result, isNull);
    });
  });

  group('AutomationRepository - Toggle and Stats', () {
    test('toggleAutomation changes enabled state', () async {
      final automation = Automation(
        id: 'toggle-test',
        name: 'Toggle Test',
        enabled: true,
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
      );
      await repository.addAutomation(automation);

      await repository.toggleAutomation('toggle-test', false);

      expect(repository.automations.first.enabled, false);

      await repository.toggleAutomation('toggle-test', true);

      expect(repository.automations.first.enabled, true);
    });

    test('recordTrigger updates lastTriggered and triggerCount', () async {
      final automation = Automation(
        id: 'trigger-test',
        name: 'Trigger Test',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [],
        triggerCount: 0,
      );
      await repository.addAutomation(automation);

      await repository.recordTrigger('trigger-test');

      final updated = repository.getAutomation('trigger-test');
      expect(updated!.triggerCount, 1);
      expect(updated.lastTriggered, isNotNull);

      await repository.recordTrigger('trigger-test');
      final updated2 = repository.getAutomation('trigger-test');
      expect(updated2!.triggerCount, 2);
    });
  });

  group('AutomationRepository - Query Methods', () {
    test('getAutomationsByTrigger returns filtered list', () async {
      await repository.addAutomation(
        Automation(
          name: 'Online 1',
          trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
          actions: const [],
        ),
      );
      await repository.addAutomation(
        Automation(
          name: 'Offline 1',
          trigger: const AutomationTrigger(type: TriggerType.nodeOffline),
          actions: const [],
        ),
      );
      await repository.addAutomation(
        Automation(
          name: 'Online 2',
          trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
          actions: const [],
        ),
      );

      final onlineAutomations = repository.getAutomationsByTrigger(
        TriggerType.nodeOnline,
      );

      expect(onlineAutomations.length, 2);
      expect(
        onlineAutomations.every(
          (a) => a.trigger.type == TriggerType.nodeOnline,
        ),
        true,
      );
    });

    test('enabledAutomations returns only enabled', () async {
      await repository.addAutomation(
        Automation(
          name: 'Enabled',
          enabled: true,
          trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
          actions: const [],
        ),
      );
      await repository.addAutomation(
        Automation(
          name: 'Disabled',
          enabled: false,
          trigger: const AutomationTrigger(type: TriggerType.nodeOffline),
          actions: const [],
        ),
      );

      final enabled = repository.enabledAutomations;

      expect(enabled.length, 1);
      expect(enabled.first.name, 'Enabled');
    });
  });

  group('AutomationRepository - Log Management', () {
    test('starts with empty log', () {
      expect(repository.log, isEmpty);
    });

    test('addLogEntry adds to beginning of log', () async {
      final entry1 = AutomationLogEntry(
        automationId: 'auto-1',
        automationName: 'First',
        timestamp: DateTime(2024, 1, 1, 10, 0),
        success: true,
        actionsExecuted: ['Action 1'],
      );
      final entry2 = AutomationLogEntry(
        automationId: 'auto-2',
        automationName: 'Second',
        timestamp: DateTime(2024, 1, 1, 11, 0),
        success: true,
        actionsExecuted: ['Action 2'],
      );

      await repository.addLogEntry(entry1);
      await repository.addLogEntry(entry2);

      expect(repository.log.length, 2);
      expect(
        repository.log.first.automationName,
        'Second',
      ); // Most recent first
    });

    test('log is limited to max entries', () async {
      // Add more than max entries (100)
      for (int i = 0; i < 110; i++) {
        await repository.addLogEntry(
          AutomationLogEntry(
            automationId: 'auto-$i',
            automationName: 'Entry $i',
            timestamp: DateTime.now(),
            success: true,
            actionsExecuted: [],
          ),
        );
      }

      expect(repository.log.length, 100); // Max is 100
    });

    test('clearLog empties the log', () async {
      await repository.addLogEntry(
        AutomationLogEntry(
          automationId: 'auto-1',
          automationName: 'Test',
          timestamp: DateTime.now(),
          success: true,
          actionsExecuted: [],
        ),
      );
      expect(repository.log, isNotEmpty);

      await repository.clearLog();

      expect(repository.log, isEmpty);
    });
  });

  group('AutomationRepository - Persistence', () {
    test('automations persist across instances', () async {
      // Add automation
      await repository.addAutomation(
        Automation(
          id: 'persist-test',
          name: 'Persistent',
          trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
          actions: const [AutomationAction(type: ActionType.vibrate)],
        ),
      );

      // Create new repository instance (simulates app restart)
      final repository2 = AutomationRepository();
      await repository2.init();

      expect(repository2.automations.length, 1);
      expect(repository2.automations.first.id, 'persist-test');
      expect(repository2.automations.first.name, 'Persistent');
    });

    test('log persists across instances', () async {
      await repository.addLogEntry(
        AutomationLogEntry(
          automationId: 'auto-1',
          automationName: 'Logged',
          timestamp: DateTime(2024, 1, 15, 10, 30),
          success: true,
          actionsExecuted: ['Test Action'],
        ),
      );

      // Create new repository instance
      final repository2 = AutomationRepository();
      await repository2.init();

      expect(repository2.log.length, 1);
      expect(repository2.log.first.automationName, 'Logged');
    });
  });

  group('AutomationRepository - Import/Export', () {
    test('exportAutomations returns valid JSON', () async {
      await repository.addAutomation(
        Automation(
          id: 'export-test',
          name: 'Export Test',
          trigger: const AutomationTrigger(
            type: TriggerType.batteryLow,
            config: {'batteryThreshold': 15},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.pushNotification,
              config: {'notificationTitle': 'Low Battery'},
            ),
          ],
        ),
      );

      final json = repository.exportAutomations();

      expect(json, isNotEmpty);
      expect(json, contains('Export Test'));
      expect(json, contains('batteryLow'));
      expect(json, contains('batteryThreshold'));
    });

    test('importAutomations adds automations from JSON', () async {
      const json = '''[
        {
          "id": "import-1",
          "name": "Imported Automation",
          "trigger": {"type": "nodeOnline", "config": {}},
          "actions": [{"type": "vibrate", "config": {}}],
          "createdAt": "2024-01-15T10:00:00.000"
        }
      ]''';

      final count = await repository.importAutomations(json);

      expect(count, 1);
      expect(repository.automations.length, 1);
      expect(repository.automations.first.name, 'Imported Automation');
      // Note: Imported automations get new IDs to avoid conflicts
      expect(repository.automations.first.id, isNot('import-1'));
    });

    test('importAutomations handles multiple automations', () async {
      const json = '''[
        {
          "id": "import-1",
          "name": "First",
          "trigger": {"type": "nodeOnline", "config": {}},
          "actions": [],
          "createdAt": "2024-01-15T10:00:00.000"
        },
        {
          "id": "import-2",
          "name": "Second",
          "trigger": {"type": "nodeOffline", "config": {}},
          "actions": [],
          "createdAt": "2024-01-15T10:00:00.000"
        }
      ]''';

      final count = await repository.importAutomations(json);

      expect(count, 2);
      expect(repository.automations.length, 2);
    });

    test('importAutomations returns 0 for invalid JSON', () async {
      const invalidJson = 'not valid json';

      final count = await repository.importAutomations(invalidJson);

      expect(count, 0);
    });

    test('export then import roundtrip', () async {
      await repository.addAutomation(
        Automation(
          name: 'Roundtrip Test',
          description: 'Testing export/import',
          trigger: const AutomationTrigger(
            type: TriggerType.messageContains,
            config: {'keyword': 'test'},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'targetNodeNum': 123, 'messageText': 'Reply'},
            ),
          ],
        ),
      );

      final exported = repository.exportAutomations();

      // Clear and import
      await repository.deleteAutomation(repository.automations.first.id);
      expect(repository.automations, isEmpty);

      await repository.importAutomations(exported);

      expect(repository.automations.length, 1);
      expect(repository.automations.first.name, 'Roundtrip Test');
      expect(repository.automations.first.trigger.keyword, 'test');
    });
  });

  group('AutomationRepository - Templates', () {
    test('createTemplate returns valid low_battery_alert', () {
      final automation = AutomationRepository.createTemplate(
        'low_battery_alert',
      );

      expect(automation.name, 'Low Battery Alert');
      expect(automation.trigger.type, TriggerType.batteryLow);
      expect(automation.trigger.batteryThreshold, 20);
      expect(automation.actions, isNotEmpty);
      expect(automation.actions.first.type, ActionType.pushNotification);
    });

    test('createTemplate returns valid node_offline_alert', () {
      final automation = AutomationRepository.createTemplate(
        'node_offline_alert',
      );

      expect(automation.name, 'Node Offline Alert');
      expect(automation.trigger.type, TriggerType.nodeOffline);
      expect(automation.actions.first.type, ActionType.pushNotification);
    });

    test('createTemplate returns valid geofence_exit', () {
      final automation = AutomationRepository.createTemplate('geofence_exit');

      expect(automation.name, 'Geofence Exit Alert');
      expect(automation.trigger.type, TriggerType.geofenceExit);
      expect(automation.trigger.geofenceRadius, 500);
    });

    test('createTemplate returns valid sos_response', () {
      final automation = AutomationRepository.createTemplate('sos_response');

      expect(automation.name, 'SOS Auto-Response');
      expect(automation.trigger.type, TriggerType.messageContains);
      expect(automation.trigger.keyword, 'SOS');
      expect(automation.actions.length, 2); // notification + vibrate
    });

    test('createTemplate returns valid dead_mans_switch', () {
      final automation = AutomationRepository.createTemplate(
        'dead_mans_switch',
      );

      expect(automation.name, contains("Dead Man"));
      expect(automation.trigger.type, TriggerType.nodeSilent);
      expect(automation.trigger.silentMinutes, 30);
    });

    test('createTemplate returns default for unknown template', () {
      final automation = AutomationRepository.createTemplate('unknown');

      expect(automation.name, 'New Automation');
      expect(automation.trigger.type, TriggerType.messageReceived);
    });

    test('templates list has correct entries', () {
      final templates = AutomationRepository.templates;

      expect(templates.length, 5);
      expect(templates.any((t) => t.id == 'low_battery_alert'), true);
      expect(templates.any((t) => t.id == 'node_offline_alert'), true);
      expect(templates.any((t) => t.id == 'geofence_exit'), true);
      expect(templates.any((t) => t.id == 'sos_response'), true);
      expect(templates.any((t) => t.id == 'dead_mans_switch'), true);
    });

    test('all templates have required fields', () {
      for (final template in AutomationRepository.templates) {
        expect(template.id, isNotEmpty);
        expect(template.name, isNotEmpty);
        expect(template.description, isNotEmpty);
        expect(template.icon, isNotNull);
      }
    });
  });

  group('AutomationRepository - Cloud Sync', () {
    test('toJsonString exports all automations', () async {
      final automation1 = Automation(
        id: 'auto-1',
        name: 'First',
        trigger: const AutomationTrigger(type: TriggerType.nodeOnline),
        actions: const [AutomationAction(type: ActionType.pushNotification)],
      );
      final automation2 = Automation(
        id: 'auto-2',
        name: 'Second',
        trigger: const AutomationTrigger(
          type: TriggerType.batteryLow,
          config: {'batteryThreshold': 15},
        ),
        actions: const [AutomationAction(type: ActionType.vibrate)],
      );
      await repository.addAutomation(automation1);
      await repository.addAutomation(automation2);

      final jsonString = repository.toJsonString();

      expect(jsonString, contains('auto-1'));
      expect(jsonString, contains('auto-2'));
      expect(jsonString, contains('First'));
      expect(jsonString, contains('Second'));
      expect(jsonString, contains('batteryThreshold'));
    });

    test('toJsonString returns empty array when no automations', () {
      final jsonString = repository.toJsonString();

      expect(jsonString, '[]');
    });

    test('loadFromJson restores automations from JSON', () async {
      // First add some automations
      final automation1 = Automation(
        id: 'restore-1',
        name: 'Restore Test 1',
        trigger: const AutomationTrigger(type: TriggerType.nodeOffline),
        actions: const [AutomationAction(type: ActionType.logEvent)],
      );
      final automation2 = Automation(
        id: 'restore-2',
        name: 'Restore Test 2',
        trigger: const AutomationTrigger(
          type: TriggerType.geofenceExit,
          config: {'geofenceLat': 37.0, 'geofenceLon': -122.0},
        ),
        actions: const [
          AutomationAction(
            type: ActionType.pushNotification,
            config: {'notificationTitle': 'Alert'},
          ),
        ],
      );
      await repository.addAutomation(automation1);
      await repository.addAutomation(automation2);

      // Export to JSON
      final jsonString = repository.toJsonString();

      // Clear and verify empty
      await repository.deleteAutomation('restore-1');
      await repository.deleteAutomation('restore-2');
      expect(repository.automations, isEmpty);

      // Restore from JSON
      await repository.loadFromJson(jsonString);

      // Verify restored
      expect(repository.automations.length, 2);
      final restored1 = repository.getAutomation('restore-1');
      final restored2 = repository.getAutomation('restore-2');
      expect(restored1, isNotNull);
      expect(restored1!.name, 'Restore Test 1');
      expect(restored2, isNotNull);
      expect(restored2!.trigger.geofenceLat, 37.0);
      expect(restored2.actions.first.notificationTitle, 'Alert');
    });

    test('loadFromJson handles empty JSON array', () async {
      await repository.loadFromJson('[]');

      expect(repository.automations, isEmpty);
    });

    test('loadFromJson handles invalid JSON gracefully', () async {
      // Add an automation first
      final automation = Automation(
        id: 'keep-me',
        name: 'Should Remain',
        trigger: const AutomationTrigger(type: TriggerType.manual),
        actions: const [],
      );
      await repository.addAutomation(automation);

      // Try to load invalid JSON - should not crash
      await repository.loadFromJson('not valid json');

      // Existing automation should remain (loadFromJson should fail gracefully)
      expect(repository.automations.length, 1);
    });

    test(
      'toJsonString and loadFromJson round-trip preserves all data',
      () async {
        final original = Automation(
          id: 'roundtrip-test',
          name: 'Round Trip Test',
          description: 'Testing full data preservation',
          enabled: false,
          trigger: const AutomationTrigger(
            type: TriggerType.messageContains,
            config: {'keyword': 'HELP', 'nodeNum': 12345},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.sendMessage,
              config: {'messageText': 'Response message', 'targetNodeNum': 999},
            ),
            AutomationAction(type: ActionType.vibrate),
          ],
        );
        await repository.addAutomation(original);

        // Round trip
        final jsonString = repository.toJsonString();
        await repository.deleteAutomation('roundtrip-test');
        await repository.loadFromJson(jsonString);

        // Verify all data preserved
        final restored = repository.getAutomation('roundtrip-test');
        expect(restored, isNotNull);
        expect(restored!.name, original.name);
        expect(restored.description, original.description);
        expect(restored.enabled, original.enabled);
        expect(restored.trigger.type, original.trigger.type);
        expect(restored.trigger.keyword, 'HELP');
        expect(restored.trigger.nodeNum, 12345);
        expect(restored.actions.length, 2);
        expect(restored.actions[0].type, ActionType.sendMessage);
        expect(restored.actions[0].messageText, 'Response message');
        expect(restored.actions[0].targetNodeNum, 999);
        expect(restored.actions[1].type, ActionType.vibrate);
      },
    );
  });
}
