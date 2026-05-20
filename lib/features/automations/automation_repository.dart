// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

import 'models/automation.dart';
import 'models/schedule_spec.dart';
import 'services/automation_sqlite_store.dart';

/// Sync state key used to mark that automations were imported from the
/// stale profile blob (`automationsJson`). The sync service checks this
/// flag to reset the pull watermark and prevent resurrecting deleted
/// automations. **Transient** — cleared by the sync service after the
/// reconciliation pull completes.
const String blobImportedSyncKey = 'automations_blob_imported';

/// Permanent local flag: once set, the profile's `automationsJson` blob
/// has been processed for this user on this device and must never be
/// imported again. Distinct from [blobImportedSyncKey] because that flag
/// is transient (the sync service clears it after the reconciliation
/// pull). Without a permanent flag, a user who imported the blob, synced,
/// then deleted everything would resurrect their deleted automations on
/// the next cold start — `_store.count` returns 0 for tombstones, and the
/// transient flag has already been cleared, so the count-based gate would
/// happily re-import the stale blob.
const String blobConsumedSyncKey = 'automations_blob_consumed';

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

  List<Automation> get automations =>
      List.unmodifiable(_store?.getAll() ?? _legacyAutomations);
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
  /// One-time safety net for users who synced automations via the old
  /// profile-blob approach. Gated by the [blobImportedSyncKey] flag rather
  /// than by `_store.count`, because tombstoned (deleted) rows return 0
  /// from `count` — if we only checked count, a user who imported the
  /// blob, then deleted everything, would resurrect the deleted entries
  /// on the next cold start. Per-document sync is authoritative the moment
  /// the blob has been imported once, deletions included.
  Future<void> importFromCloudPrefsIfEmpty(String automationsJson) async {
    if (_store == null) {
      AppLogging.automations('importFromCloudPrefsIfEmpty SKIP: store is null');
      return;
    }

    // Permanent gate — once consumed, never re-import. This is the load-
    // bearing check: without it, a user who imports the blob, syncs, then
    // deletes their automations would resurrect the deletions on every
    // cold start (tombstones return 0 from `count`, and the transient
    // [blobImportedSyncKey] has already been cleared by the sync service).
    final consumed = await _store!.getSyncState(blobConsumedSyncKey) == 'true';
    if (consumed) {
      AppLogging.automations(
        'importFromCloudPrefsIfEmpty SKIP: blob already consumed',
      );
      return;
    }

    // Mark consumed BEFORE doing anything else, so that a crash or parse
    // failure can't leave the gate open for the next cold start.
    await _store!.setSyncState(blobConsumedSyncKey, 'true');
    AppLogging.automations('importFromCloudPrefsIfEmpty marked blob consumed');

    // If the user has ever stored an automation on this device (live OR
    // tombstoned), do NOT import. Per-document sync is authoritative.
    // The previous gate checked only `_store.count`, which excludes
    // tombstones — that's exactly how the deletion-resurrection blip
    // slipped through.
    if (await _store!.hasAnyRows()) {
      AppLogging.automations(
        'importFromCloudPrefsIfEmpty SKIP: '
        'hasAnyRows=true (tombstones or live rows present), '
        'live count=${_store!.count}',
      );
      return;
    }
    AppLogging.automations(
      'importFromCloudPrefsIfEmpty proceeding with import '
      '(SQLite is completely empty for this user)',
    );

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
        // Transient flag for the sync service: tells it to reset the pull
        // watermark and do a full re-pull before pushing, so Firestore
        // deletion markers are applied first. The sync service clears
        // this flag itself after the reconciliation completes.
        await _store!.setSyncState(blobImportedSyncKey, 'true');
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
    AppLogging.automations(
      'addAutomation entry id=${automation.id} name="${automation.name}"',
    );
    if (_store != null) {
      await _store!.save(automation);
    } else {
      _legacyAutomations.add(automation);
      await _saveLegacyAutomations();
    }
    AppLogging.automations('addAutomation persisted, about to notifyListeners');
    notifyListeners();
    AppLogging.automations(
      'AutomationRepository: Added automation "${automation.name}"',
    );
  }

  /// Update an existing automation
  Future<void> updateAutomation(Automation automation) async {
    AppLogging.automations(
      'updateAutomation entry id=${automation.id} name="${automation.name}"',
    );
    if (_store != null) {
      await _store!.save(automation);
    } else {
      final index = _legacyAutomations.indexWhere((a) => a.id == automation.id);
      if (index != -1) {
        _legacyAutomations[index] = automation;
        await _saveLegacyAutomations();
      }
    }
    AppLogging.automations(
      'updateAutomation persisted, about to notifyListeners',
    );
    notifyListeners();
    AppLogging.automations(
      'AutomationRepository: Updated automation "${automation.name}"',
    );
  }

  /// Delete an automation
  Future<void> deleteAutomation(String id) async {
    AppLogging.automations('deleteAutomation entry id=$id');
    if (_store != null) {
      await _store!.delete(id);
    } else {
      _legacyAutomations.removeWhere((a) => a.id == id);
      await _saveLegacyAutomations();
    }
    AppLogging.automations(
      'deleteAutomation persisted, about to notifyListeners',
    );
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
    notifyListeners();
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
          name: 'Low Battery Alert', // lint-allow: hardcoded-string
          description:
              'Notify when a node battery drops below 20%', // lint-allow: hardcoded-string
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
          name: 'Node Offline Alert', // lint-allow: hardcoded-string
          description:
              'Notify when a node goes offline', // lint-allow: hardcoded-string
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
          name: 'Geofence Exit Alert', // lint-allow: hardcoded-string
          description:
              'Alert when a node leaves a designated area', // lint-allow: hardcoded-string
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
          name: 'SOS Auto-Response', // lint-allow: hardcoded-string
          description:
              'Auto-reply when receiving SOS message', // lint-allow: hardcoded-string
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
          name: 'Dead Man\'s Switch', // lint-allow: hardcoded-string
          description:
              'Alert if no activity from node for 30 minutes', // lint-allow: hardcoded-string
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
          name: 'New Automation', // lint-allow: hardcoded-string
          trigger: const AutomationTrigger(type: TriggerType.messageReceived),
          actions: const [AutomationAction(type: ActionType.pushNotification)],
        );
    }
  }

  /// Returns the primary `TriggerType` used by [templateId], or `null`
  /// if no template matches. Used by the Automations screen to drive
  /// protocol-aware filtering: templates whose trigger is `unsupported`
  /// on the active protocol are hidden from the Quick Start list so a
  /// MeshCore user never sees `low_battery_alert` as a suggestion.
  static TriggerType? templateTriggerType(String templateId) {
    switch (templateId) {
      case 'low_battery_alert':
        return TriggerType.batteryLow;
      case 'node_offline_alert':
        return TriggerType.nodeOffline;
      case 'geofence_exit':
        return TriggerType.geofenceExit;
      case 'sos_response':
        return TriggerType.messageContains;
      case 'dead_mans_switch':
        return TriggerType.nodeSilent;
      case 'weather_report':
        return TriggerType.scheduled;
      case 'channel_monitor':
        return TriggerType.channelActivity;
      case 'emergency_beacon':
        return TriggerType.messageContains;
      default:
        return null;
    }
  }

  /// Get available templates
  static List<({String id, String name, String description, IconData icon})>
  get templates {
    return const [
      (
        id: 'low_battery_alert',
        name: 'Low Battery Alert', // lint-allow: hardcoded-string
        description:
            'Notify when battery drops below 20%', // lint-allow: hardcoded-string
        icon: Icons.battery_alert,
      ),
      (
        id: 'node_offline_alert',
        name: 'Node Offline Alert', // lint-allow: hardcoded-string
        description:
            'Notify when a node goes offline', // lint-allow: hardcoded-string
        icon: Icons.wifi_off,
      ),
      (
        id: 'geofence_exit',
        name: 'Geofence Exit Alert', // lint-allow: hardcoded-string
        description:
            'Alert when leaving a designated area', // lint-allow: hardcoded-string
        icon: Icons.location_off,
      ),
      (
        id: 'sos_response',
        name: 'SOS Response', // lint-allow: hardcoded-string
        description:
            'Alert on emergency messages', // lint-allow: hardcoded-string
        icon: Icons.sos,
      ),
      (
        id: 'dead_mans_switch',
        name: 'Dead Man\'s Switch', // lint-allow: hardcoded-string
        description:
            'Alert if node silent too long', // lint-allow: hardcoded-string
        icon: Icons.timer_off,
      ),
    ];
  }

  /// Resolve the localized title for a template by its ID.
  ///
  /// Falls back to the hardcoded English string when no ARB key matches.
  static String localizedTemplateTitle(String id, AppLocalizations l10n) {
    return switch (id) {
      'low_battery_alert' => l10n.automationTemplateLowBatteryTitle,
      'node_offline_alert' => l10n.automationTemplateNodeOfflineTitle,
      'geofence_exit' => l10n.automationTemplateGeofenceExitTitle,
      'sos_response' => l10n.automationTemplateSosTitle,
      'dead_mans_switch' => l10n.automationTemplateDeadManTitle,
      'weather_report' => l10n.automationTemplateWeatherReportTitle,
      'channel_monitor' => l10n.automationTemplateChannelMonitorTitle,
      'emergency_beacon' => l10n.automationTemplateEmergencyBeaconTitle,
      _ => id,
    };
  }

  /// Resolve the localized description for a template by its ID.
  ///
  /// Falls back to the template ID when no ARB key matches.
  static String localizedTemplateDescription(String id, AppLocalizations l10n) {
    return switch (id) {
      'low_battery_alert' => l10n.automationTemplateLowBatteryDesc,
      'node_offline_alert' => l10n.automationTemplateNodeOfflineDesc,
      'geofence_exit' => l10n.automationTemplateGeofenceExitDesc,
      'sos_response' => l10n.automationTemplateSosDesc,
      'dead_mans_switch' => l10n.automationTemplateDeadManDesc,
      'weather_report' => l10n.automationTemplateWeatherReportDescription,
      'channel_monitor' => l10n.automationTemplateChannelMonitorDescription,
      'emergency_beacon' => l10n.automationTemplateEmergencyBeaconDescription,
      _ => id,
    };
  }
}
