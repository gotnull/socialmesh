// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/logging.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/automation.dart';
import 'models/schedule_spec.dart';
import 'services/automation_sqlite_store.dart';

/// Repository for storing and retrieving automations.
///
/// Uses [AutomationSqliteStore] as the backing store for automations
/// (with Cloud Sync outbox support). SharedPreferences is still used
/// for logs and schedules which are device-local and do not sync.
class AutomationRepository extends ChangeNotifier {
  static const String _automationsKey = 'automations';
  static const String _logKey = 'automation_log';
  static const String _schedulesKey = 'automation_schedules';
  static const String _migratedKey = 'automations_migrated_to_sqlite';
  static const int _maxLogEntries = 100;

  SharedPreferences? _prefs;
  AutomationSqliteStore? _store;
  List<AutomationLogEntry> _log = [];
  List<ScheduleSpec> _schedules = [];

  List<Automation> get automations => List.unmodifiable(_store?.getAll() ?? []);
  List<AutomationLogEntry> get log => List.unmodifiable(_log);
  List<ScheduleSpec> get schedules => List.unmodifiable(_schedules);

  /// Set the SQLite store. Must be called before [init].
  void setStore(AutomationSqliteStore store) {
    _store = store;
  }

  /// Initialize the repository.
  ///
  /// If a [AutomationSqliteStore] has been set via [setStore], automations
  /// are read from SQLite. Otherwise, falls back to SharedPreferences
  /// (legacy path for tests or pre-migration state).
  ///
  /// On first run with a store, migrates any existing automations from
  /// SharedPreferences into SQLite and enqueues them for sync.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    if (_store != null) {
      await _migrateFromSharedPreferencesIfNeeded();
    } else {
      // Legacy fallback: load from SharedPreferences directly
      await _loadAutomationsFromPrefs();
    }

    await _loadLog();
    await _loadSchedules();
  }

  // ============== Migration ==============

  /// One-time migration from SharedPreferences to SQLite.
  ///
  /// Checks if automations have already been migrated. If not:
  /// 1. Reads automations from SharedPreferences
  /// 2. Bulk-imports them into the SQLite store
  /// 3. Enqueues them all for sync so they reach Firestore
  /// 4. Clears the SharedPreferences key
  /// 5. Sets the migration flag
  ///
  /// Also handles the profile-blob migration: if automationsJson
  /// exists in the profile preferences, those are imported too.
  Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    final alreadyMigrated = _prefs?.getBool(_migratedKey) ?? false;
    if (alreadyMigrated) return;

    final jsonString = _prefs?.getString(_automationsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = jsonDecode(jsonString) as List;
        final automations = list
            .map((item) => Automation.fromJson(item as Map<String, dynamic>))
            .toList();

        if (automations.isNotEmpty) {
          AppLogging.automations(
            'AutomationRepository: Migrating ${automations.length} '
            'automations from SharedPreferences to SQLite',
          );
          await _store!.bulkImport(automations);
          await _store!.enqueueAllForSync();
        }
      } catch (e) {
        AppLogging.automations(
          'AutomationRepository: Error migrating from SharedPreferences: $e',
        );
      }
    }

    // Clear the old SharedPreferences key
    await _prefs?.remove(_automationsKey);
    // Set migration flag
    await _prefs?.setBool(_migratedKey, true);

    AppLogging.automations(
      'AutomationRepository: Migration to SQLite complete '
      '(${_store!.count} automations)',
    );
  }

  /// Import automations from a cloud profile preferences JSON string.
  ///
  /// This is the one-time safety net for users who synced automations
  /// via the old profile-blob approach. Called when the profile loads
  /// and automationsJson is non-empty, but only if the SQLite store
  /// is empty (to avoid overwriting newer per-document synced data).
  Future<void> importFromCloudPrefsIfEmpty(String automationsJson) async {
    if (_store == null) return;
    if (_store!.count > 0) {
      // SQLite already has automations — per-document sync is authoritative
      return;
    }

    try {
      final list = jsonDecode(automationsJson) as List;
      final automations = list
          .map((item) => Automation.fromJson(item as Map<String, dynamic>))
          .toList();

      if (automations.isNotEmpty) {
        AppLogging.automations(
          'AutomationRepository: Importing ${automations.length} '
          'automations from cloud profile preferences (one-time)',
        );
        await _store!.bulkImport(automations);
        await _store!.enqueueAllForSync();
        notifyListeners();
      }
    } catch (e) {
      AppLogging.automations(
        'AutomationRepository: Error importing from cloud prefs: $e',
      );
    }
  }

  // ============== Legacy SharedPreferences loader ==============

  /// Legacy: used only when no SQLite store is available.
  List<Automation> _legacyAutomations = [];

  Future<void> _loadAutomationsFromPrefs() async {
    final jsonString = _prefs?.getString(_automationsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = jsonDecode(jsonString) as List;
        _legacyAutomations = list
            .map((item) => Automation.fromJson(item as Map<String, dynamic>))
            .toList();
        AppLogging.automations(
          'AutomationRepository: Loaded ${_legacyAutomations.length} '
          'automations (legacy SharedPreferences)',
        );
      } catch (e) {
        AppLogging.automations(
          'AutomationRepository: Error loading automations: $e',
        );
        _legacyAutomations = [];
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
        AppLogging.automations('AutomationRepository: Error loading log: $e');
        _log = [];
      }
    }
  }

  Future<void> _loadSchedules() async {
    final jsonString = _prefs?.getString(_schedulesKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = jsonDecode(jsonString) as List;
        _schedules = list
            .map((item) => ScheduleSpec.fromJson(item as Map<String, dynamic>))
            .toList();
        AppLogging.automations(
          'AutomationRepository: Loaded ${_schedules.length} schedules',
        );
      } catch (e) {
        AppLogging.automations(
          'AutomationRepository: Error loading schedules: $e',
        );
        _schedules = [];
      }
    }
  }

  Future<void> _saveLog() async {
    final jsonString = jsonEncode(_log.map((l) => l.toJson()).toList());
    await _prefs?.setString(_logKey, jsonString);
  }

  Future<void> _saveSchedules() async {
    final jsonString = jsonEncode(_schedules.map((s) => s.toJson()).toList());
    await _prefs?.setString(_schedulesKey, jsonString);
  }

  // ============== Schedule Management ==============

  /// Add a new schedule
  Future<void> addSchedule(ScheduleSpec schedule) async {
    _schedules.add(schedule);
    await _saveSchedules();
    notifyListeners();
    AppLogging.automations(
      'AutomationRepository: Added schedule "${schedule.id}" (${schedule.kind})',
    );
  }

  /// Update an existing schedule
  Future<void> updateSchedule(ScheduleSpec schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      await _saveSchedules();
      notifyListeners();
    }
  }

  /// Delete a schedule
  Future<void> deleteSchedule(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    await _saveSchedules();
    notifyListeners();
    AppLogging.automations('AutomationRepository: Deleted schedule $id');
  }

  /// Get a schedule by ID
  ScheduleSpec? getSchedule(String id) {
    try {
      return _schedules.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get schedules by automation ID (if linked)
  List<ScheduleSpec> getSchedulesForAutomation(String automationId) {
    return _schedules.where((s) => s.id.startsWith(automationId)).toList();
  }

  /// Get all active schedules
  List<ScheduleSpec> get activeSchedules {
    final now = DateTime.now();
    return _schedules.where((s) => s.isActive(now)).toList();
  }

  /// Persist all schedules (called by scheduler after updates)
  Future<void> persistSchedules(List<ScheduleSpec> schedules) async {
    _schedules = List.from(schedules);
    await _saveSchedules();
  }

  /// Load schedules for scheduler resync
  Future<List<ScheduleSpec>> loadSchedules() async {
    await _loadSchedules();
    return List.from(_schedules);
  }

  /// Export automations as JSON string for cloud sync
  String toJsonString() {
    if (_store != null) {
      return _store!.toJsonString();
    }
    return jsonEncode(_legacyAutomations.map((a) => a.toJson()).toList());
  }

  /// Load automations from JSON string (for cloud sync restore).
  ///
  /// With the new per-document sync, this is only used as a fallback
  /// for the profile-blob import path. Prefer [importFromCloudPrefsIfEmpty].
  Future<void> loadFromJson(String jsonString) async {
    if (_store != null) {
      await importFromCloudPrefsIfEmpty(jsonString);
      return;
    }

    // Legacy path: direct SharedPreferences write
    try {
      final list = jsonDecode(jsonString) as List;
      _legacyAutomations = list
          .map((item) => Automation.fromJson(item as Map<String, dynamic>))
          .toList();
      await _prefs?.setString(_automationsKey, jsonString);
      notifyListeners();
      AppLogging.automations(
        'AutomationRepository: Loaded ${_legacyAutomations.length} '
        'automations from cloud (legacy)',
      );
    } catch (e) {
      AppLogging.automations(
        'AutomationRepository: Error loading from JSON: $e',
      );
    }
  }

  /// Add a new automation
  Future<void> addAutomation(Automation automation) async {
    if (_store != null) {
      await _store!.save(automation);
    } else {
      _legacyAutomations.add(automation);
      await _saveLegacyAutomations();
    }
    notifyListeners();
    AppLogging.automations(
      'AutomationRepository: Added automation "${automation.name}"',
    );
  }

  /// Update an existing automation
  Future<void> updateAutomation(Automation automation) async {
    if (_store != null) {
      await _store!.save(automation);
    } else {
      final index = _legacyAutomations.indexWhere((a) => a.id == automation.id);
      if (index != -1) {
        _legacyAutomations[index] = automation;
        await _saveLegacyAutomations();
      }
    }
    notifyListeners();
    AppLogging.automations(
      'AutomationRepository: Updated automation "${automation.name}"',
    );
  }

  /// Delete an automation
  Future<void> deleteAutomation(String id) async {
    if (_store != null) {
      await _store!.delete(id);
    } else {
      _legacyAutomations.removeWhere((a) => a.id == id);
      await _saveLegacyAutomations();
    }
    notifyListeners();
    AppLogging.automations('AutomationRepository: Deleted automation $id');
  }

  /// Get an automation by ID
  Automation? getAutomation(String id) {
    if (_store != null) {
      return _store!.getById(id);
    }
    try {
      return _legacyAutomations.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Toggle automation enabled state
  Future<void> toggleAutomation(String id, bool enabled) async {
    if (_store != null) {
      final automation = _store!.getById(id);
      if (automation != null) {
        await _store!.save(automation.copyWith(enabled: enabled));
      }
    } else {
      final index = _legacyAutomations.indexWhere((a) => a.id == id);
      if (index != -1) {
        _legacyAutomations[index] = _legacyAutomations[index].copyWith(
          enabled: enabled,
        );
        await _saveLegacyAutomations();
      }
    }
    notifyListeners();
  }

  /// Record that an automation was triggered
  Future<void> recordTrigger(String id) async {
    if (_store != null) {
      final automation = _store!.getById(id);
      if (automation != null) {
        await _store!.save(
          automation.copyWith(
            lastTriggered: DateTime.now(),
            triggerCount: automation.triggerCount + 1,
          ),
        );
      }
    } else {
      final index = _legacyAutomations.indexWhere((a) => a.id == id);
      if (index != -1) {
        final automation = _legacyAutomations[index];
        _legacyAutomations[index] = automation.copyWith(
          lastTriggered: DateTime.now(),
          triggerCount: automation.triggerCount + 1,
        );
        await _saveLegacyAutomations();
      }
    }
    notifyListeners();
  }

  /// Add a log entry
  Future<void> addLogEntry(AutomationLogEntry entry) async {
    _log.insert(0, entry);
    // Keep only last N entries
    if (_log.length > _maxLogEntries) {
      _log = _log.sublist(0, _maxLogEntries);
    }
    await _saveLog();
    notifyListeners();
  }

  /// Clear the log
  Future<void> clearLog() async {
    _log.clear();
    await _saveLog();
  }

  /// Get automations by trigger type
  List<Automation> getAutomationsByTrigger(TriggerType type) {
    return automations.where((a) => a.trigger.type == type).toList();
  }

  /// Get enabled automations
  List<Automation> get enabledAutomations {
    return automations.where((a) => a.enabled).toList();
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
        await addAutomation(newAutomation);
      }

      return imported.length;
    } catch (e) {
      AppLogging.automations('AutomationRepository: Error importing: $e');
      return 0;
    }
  }

  /// Export automations to JSON
  String exportAutomations() {
    return toJsonString();
  }

  /// Save automations to SharedPreferences (legacy path only).
  Future<void> _saveLegacyAutomations() async {
    final jsonString = jsonEncode(
      _legacyAutomations.map((a) => a.toJson()).toList(),
    );
    await _prefs?.setString(_automationsKey, jsonString);
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
                    '{{node.name}} hasn\'t been heard from in {{silent.duration}}.',
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
