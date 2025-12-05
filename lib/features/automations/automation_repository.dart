import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/automation.dart';

/// Repository for storing and retrieving automations
class AutomationRepository {
  static const String _automationsKey = 'automations';
  static const String _logKey = 'automation_log';
  static const int _maxLogEntries = 100;

  SharedPreferences? _prefs;
  List<Automation> _automations = [];
  List<AutomationLogEntry> _log = [];

  List<Automation> get automations => List.unmodifiable(_automations);
  List<AutomationLogEntry> get log => List.unmodifiable(_log);

  /// Initialize the repository
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAutomations();
    await _loadLog();
  }

  Future<void> _loadAutomations() async {
    final jsonString = _prefs?.getString(_automationsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = jsonDecode(jsonString) as List;
        _automations = list
            .map((item) => Automation.fromJson(item as Map<String, dynamic>))
            .toList();
        debugPrint(
          'AutomationRepository: Loaded ${_automations.length} automations',
        );
      } catch (e) {
        debugPrint('AutomationRepository: Error loading automations: $e');
        _automations = [];
      }
    }
  }

  Future<void> _loadLog() async {
    final jsonString = _prefs?.getString(_logKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = jsonDecode(jsonString) as List;
        _log = list
            .map(
              (item) =>
                  AutomationLogEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } catch (e) {
        debugPrint('AutomationRepository: Error loading log: $e');
        _log = [];
      }
    }
  }

  Future<void> _saveAutomations() async {
    final jsonString = jsonEncode(_automations.map((a) => a.toJson()).toList());
    await _prefs?.setString(_automationsKey, jsonString);
  }

  Future<void> _saveLog() async {
    final jsonString = jsonEncode(_log.map((l) => l.toJson()).toList());
    await _prefs?.setString(_logKey, jsonString);
  }

  /// Add a new automation
  Future<void> addAutomation(Automation automation) async {
    _automations.add(automation);
    await _saveAutomations();
    debugPrint('AutomationRepository: Added automation "${automation.name}"');
  }

  /// Update an existing automation
  Future<void> updateAutomation(Automation automation) async {
    final index = _automations.indexWhere((a) => a.id == automation.id);
    if (index != -1) {
      _automations[index] = automation;
      await _saveAutomations();
      debugPrint(
        'AutomationRepository: Updated automation "${automation.name}"',
      );
    }
  }

  /// Delete an automation
  Future<void> deleteAutomation(String id) async {
    _automations.removeWhere((a) => a.id == id);
    await _saveAutomations();
    debugPrint('AutomationRepository: Deleted automation $id');
  }

  /// Get an automation by ID
  Automation? getAutomation(String id) {
    try {
      return _automations.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Toggle automation enabled state
  Future<void> toggleAutomation(String id, bool enabled) async {
    final index = _automations.indexWhere((a) => a.id == id);
    if (index != -1) {
      _automations[index] = _automations[index].copyWith(enabled: enabled);
      await _saveAutomations();
    }
  }

  /// Record that an automation was triggered
  Future<void> recordTrigger(String id) async {
    final index = _automations.indexWhere((a) => a.id == id);
    if (index != -1) {
      final automation = _automations[index];
      _automations[index] = automation.copyWith(
        lastTriggered: DateTime.now(),
        triggerCount: automation.triggerCount + 1,
      );
      await _saveAutomations();
    }
  }

  /// Add a log entry
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _log.insert(0, entry);
    // Keep only last N entries
    if (_log.length > _maxLogEntries) {
      _log = _log.sublist(0, _maxLogEntries);
    }
    await _saveLog();
  }

  /// Clear the log
  Future<void> clearLog() async {
    _log.clear();
    await _saveLog();
  }

  /// Get automations by trigger type
  List<Automation> getAutomationsByTrigger(TriggerType type) {
    return _automations.where((a) => a.trigger.type == type).toList();
  }

  /// Get enabled automations
  List<Automation> get enabledAutomations {
    return _automations.where((a) => a.enabled).toList();
  }

  /// Import automations from JSON
  Future<int> importAutomations(String jsonString) async {
    try {
      final list = jsonDecode(jsonString) as List;
      final imported = list
          .map((item) => Automation.fromJson(item as Map<String, dynamic>))
          .toList();

      // Add imported automations (with new IDs to avoid conflicts)
      for (final automation in imported) {
        final newAutomation = Automation(
          name: automation.name,
          description: automation.description,
          enabled: automation.enabled,
          trigger: automation.trigger,
          actions: automation.actions,
          conditions: automation.conditions,
        );
        _automations.add(newAutomation);
      }

      await _saveAutomations();
      return imported.length;
    } catch (e) {
      debugPrint('AutomationRepository: Error importing: $e');
      return 0;
    }
  }

  /// Export automations to JSON
  String exportAutomations() {
    return jsonEncode(_automations.map((a) => a.toJson()).toList());
  }

  /// Create a template automation
  static Automation createTemplate(String templateName) {
    switch (templateName) {
      case 'low_battery_alert':
        return Automation(
          name: 'Low Battery Alert',
          description: 'Notify when a node battery drops below 20%',
          trigger: const AutomationTrigger(
            type: TriggerType.batteryLow,
            config: {'batteryThreshold': 20},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.pushNotification,
              config: {
                'notificationTitle': 'Low Battery: {{node.name}}',
                'notificationBody': 'Battery at {{battery}}',
              },
            ),
          ],
        );

      case 'node_offline_alert':
        return Automation(
          name: 'Node Offline Alert',
          description: 'Notify when a node goes offline',
          trigger: const AutomationTrigger(type: TriggerType.nodeOffline),
          actions: const [
            AutomationAction(
              type: ActionType.pushNotification,
              config: {
                'notificationTitle': 'Node Offline',
                'notificationBody': '{{node.name}} is no longer reachable',
              },
            ),
          ],
        );

      case 'geofence_exit':
        return Automation(
          name: 'Geofence Exit Alert',
          description: 'Alert when a node leaves a designated area',
          trigger: const AutomationTrigger(
            type: TriggerType.geofenceExit,
            config: {'geofenceRadius': 500},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.pushNotification,
              config: {
                'notificationTitle': 'Left Area',
                'notificationBody': '{{node.name}} has left the monitored area',
              },
            ),
          ],
        );

      case 'sos_response':
        return Automation(
          name: 'SOS Auto-Response',
          description: 'Auto-reply when receiving SOS message',
          trigger: const AutomationTrigger(
            type: TriggerType.messageContains,
            config: {'keyword': 'SOS'},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.pushNotification,
              config: {
                'notificationTitle': 'Emergency Alert',
                'notificationBody': '{{node.name}}: {{message}}',
              },
            ),
            AutomationAction(type: ActionType.vibrate),
          ],
        );

      case 'dead_mans_switch':
        return Automation(
          name: 'Dead Man\'s Switch',
          description: 'Alert if no activity from node for 30 minutes',
          trigger: const AutomationTrigger(
            type: TriggerType.nodeSilent,
            config: {'silentMinutes': 30},
          ),
          actions: const [
            AutomationAction(
              type: ActionType.pushNotification,
              config: {
                'notificationTitle': 'Node Silent',
                'notificationBody':
                    '{{node.name}} hasn\'t been heard from in 30 minutes',
              },
            ),
          ],
        );

      default:
        return Automation(
          name: 'New Automation',
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
        );
    }
  }

  /// Get available templates
  static List<({String id, String name, String description, IconData icon})>
  get templates {
    return const [
      (
        id: 'low_battery_alert',
        name: 'Low Battery Alert',
        description: 'Notify when battery drops below 20%',
        icon: Icons.battery_alert,
      ),
      (
        id: 'node_offline_alert',
        name: 'Node Offline Alert',
        description: 'Notify when a node goes offline',
        icon: Icons.wifi_off,
      ),
      (
        id: 'geofence_exit',
        name: 'Geofence Exit Alert',
        description: 'Alert when leaving a designated area',
        icon: Icons.location_off,
      ),
      (
        id: 'sos_response',
        name: 'SOS Response',
        description: 'Alert on emergency messages',
        icon: Icons.sos,
      ),
      (
        id: 'dead_mans_switch',
        name: 'Dead Man\'s Switch',
        description: 'Alert if node silent too long',
        icon: Icons.timer_off,
      ),
    ];
  }
}
