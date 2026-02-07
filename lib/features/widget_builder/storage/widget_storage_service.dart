// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/logging.dart';
import '../models/widget_schema.dart';

/// Service for persisting custom widgets locally
import '../services/widget_sqlite_store.dart';

class WidgetStorageService {
  static const _storageKey = 'custom_widgets';
  static const _installedKey = 'installed_widgets';
  // Maps schema ID (UUID) -> marketplace ID (Firebase doc ID)
  static const _schemaToMarketplaceKey = 'schema_to_marketplace_map';
  static const _migratedKey = 'widgets_migrated_to_sqlite';

  SharedPreferences? _prefs;

  // Import for sync logging

  /// Shared SQLite store for Cloud Sync support.
  ///
  /// When set (via [setSharedStore]), all CRUD operations delegate to
  /// the SQLite store instead of SharedPreferences. This allows any
  /// instance of WidgetStorageService (including ad-hoc ones created
  /// in screens) to participate in Cloud Sync automatically.
  static WidgetSqliteStore? _sharedStore;

  /// Set the shared SQLite store for all WidgetStorageService instances.
  ///
  /// Call this once during app initialization (from the widget store
  /// provider) before any screen creates a WidgetStorageService.
  static void setSharedStore(WidgetSqliteStore store) {
    AppLogging.sync(
      '[WidgetStorage] setSharedStore() called — '
      'store hashCode=${identityHashCode(store)}, '
      'syncEnabled=${store.syncEnabled}',
    );
    _sharedStore = store;
  }

  /// Whether the SQLite store is available for delegation.
  static bool get hasStore => _sharedStore != null;

  WidgetStorageService();

  /// Initialize the service.
  ///
  /// If a shared SQLite store has been set via [setSharedStore],
  /// performs a one-time migration from SharedPreferences to SQLite
  /// on first run.
  Future<void> init() async {
    AppLogging.widgets('[WidgetStorage] Initializing...');
    AppLogging.sync(
      '[WidgetStorage] init() ENTER — hasStore=$hasStore, '
      'sharedStore hashCode=${_sharedStore != null ? identityHashCode(_sharedStore) : "null"}, '
      'syncEnabled=${_sharedStore?.syncEnabled}',
    );
    _prefs = await SharedPreferences.getInstance();

    if (_sharedStore != null) {
      await _migrateToSqliteIfNeeded();
    }

    AppLogging.widgets('[WidgetStorage] Initialized successfully');
    AppLogging.sync(
      '[WidgetStorage] init() EXIT — hasStore=$hasStore, '
      'syncEnabled=${_sharedStore?.syncEnabled}',
    );
  }

  /// One-time migration from SharedPreferences to SQLite.
  Future<void> _migrateToSqliteIfNeeded() async {
    final alreadyMigrated = _prefs?.getBool(_migratedKey) ?? false;
    AppLogging.sync(
      '[WidgetStorage] _migrateToSqliteIfNeeded() — '
      'alreadyMigrated=$alreadyMigrated',
    );
    if (alreadyMigrated) return;

    final json = _prefs?.getString(_storageKey);
    AppLogging.sync(
      '[WidgetStorage] Migration: SharedPreferences data '
      '${json != null ? "found (${json.length} chars)" : "NOT found"}',
    );
    if (json != null && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        final widgets = list
            .map((item) => WidgetSchema.fromJson(item as Map<String, dynamic>))
            .toList();

        if (widgets.isNotEmpty) {
          AppLogging.widgets(
            '[WidgetStorage] Migrating ${widgets.length} widgets '
            'from SharedPreferences to SQLite',
          );
          AppLogging.sync(
            '[WidgetStorage] Migration: importing ${widgets.length} widgets '
            'to SQLite + enqueuing for sync',
          );
          await _sharedStore!.bulkImport(widgets);
          await _sharedStore!.enqueueAllForSync();
          AppLogging.sync(
            '[WidgetStorage] Migration: bulkImport + enqueueAllForSync complete',
          );
        }
      } catch (e) {
        AppLogging.widgets(
          '[WidgetStorage] Error migrating from SharedPreferences: $e',
        );
        AppLogging.sync('[WidgetStorage] Migration ERROR: $e');
      }
    }

    // Clear the old SharedPreferences key for widgets data
    // (keep _installedKey and _schemaToMarketplaceKey — those are
    // marketplace tracking, not widget schema storage)
    await _prefs?.remove(_storageKey);
    await _prefs?.setBool(_migratedKey, true);

    AppLogging.widgets(
      '[WidgetStorage] Migration to SQLite complete '
      '(${_sharedStore!.count} widgets)',
    );
    AppLogging.sync(
      '[WidgetStorage] Migration complete — '
      '${_sharedStore!.count} widgets in SQLite, '
      'syncEnabled=${_sharedStore!.syncEnabled}',
    );
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      AppLogging.widgets('[WidgetStorage] ERROR: Service not initialized!');
      throw Exception('WidgetStorageService not initialized');
    }
    return _prefs!;
  }

  /// Save a custom widget
  Future<void> saveWidget(WidgetSchema widget) async {
    AppLogging.widgets(
      '[WidgetStorage] saveWidget called for id=${widget.id}, name=${widget.name}',
    );
    AppLogging.sync(
      '[WidgetStorage] saveWidget() ENTER — '
      'id=${widget.id}, name=${widget.name}, '
      'hasStore=$hasStore, '
      'store hashCode=${_sharedStore != null ? identityHashCode(_sharedStore) : "null"}, '
      'store.syncEnabled=${_sharedStore?.syncEnabled}',
    );
    try {
      // Ensure initialized
      if (_prefs == null) {
        AppLogging.widgets(
          '[WidgetStorage] Not initialized, initializing now...',
        );
        AppLogging.sync(
          '[WidgetStorage] saveWidget: NOT initialized, calling init()',
        );
        await init();
      }

      // Delegate to SQLite store if available
      if (_sharedStore != null) {
        AppLogging.sync(
          '[WidgetStorage] saveWidget: DELEGATING to SQLite store '
          '(syncEnabled=${_sharedStore!.syncEnabled}) — '
          'if syncEnabled=false, this widget will NOT be enqueued for sync!',
        );
        await _sharedStore!.save(widget);
        AppLogging.widgets(
          '[WidgetStorage] Widget saved to SQLite: ${widget.name}',
        );
        AppLogging.sync(
          '[WidgetStorage] saveWidget() EXIT — saved to SQLite OK, '
          'widget ${widget.id} (${widget.name})',
        );
        return;
      }

      // Legacy SharedPreferences path
      AppLogging.sync(
        '[WidgetStorage] saveWidget: NO SQLite store — using legacy '
        'SharedPreferences path (widget will NOT sync!)',
      );
      final widgets = await getWidgets();
      AppLogging.widgets(
        '[WidgetStorage] Current widgets count: ${widgets.length}',
      );

      final index = widgets.indexWhere((w) => w.id == widget.id);
      AppLogging.widgets('[WidgetStorage] Existing widget index: $index');

      if (index >= 0) {
        AppLogging.widgets(
          '[WidgetStorage] Updating existing widget at index $index',
        );
        widgets[index] = widget;
      } else {
        AppLogging.widgets('[WidgetStorage] Adding new widget');
        widgets.add(widget);
      }

      await _saveWidgetsList(widgets);
      AppLogging.widgets(
        '[WidgetStorage] Widget saved successfully, new count: ${widgets.length}',
      );
      AppLogging.widgets('Saved widget: ${widget.name}');
      AppLogging.sync(
        '[WidgetStorage] saveWidget() EXIT — saved to SharedPreferences '
        '(NO sync), widget ${widget.id}',
      );
    } catch (e, stack) {
      AppLogging.widgets('[WidgetStorage] ERROR saving widget: $e');
      AppLogging.widgets('[WidgetStorage] Stack: $stack');
      AppLogging.widgets('Error saving widget: $e');
      AppLogging.sync('[WidgetStorage] saveWidget() ERROR: $e');
      rethrow;
    }
  }

  /// Get all custom widgets
  Future<List<WidgetSchema>> getWidgets() async {
    // Delegate to SQLite store if available
    if (_sharedStore != null) {
      return _sharedStore!.getAll();
    }

    // Legacy SharedPreferences path
    try {
      // Ensure initialized
      if (_prefs == null) {
        AppLogging.widgets(
          '[WidgetStorage] Not initialized in getWidgets, initializing...',
        );
        await init();
      }

      final json = _preferences.getString(_storageKey);
      AppLogging.widgets(
        '[WidgetStorage] getWidgets - raw json length: ${json?.length ?? 0}',
      );
      if (json == null || json.isEmpty) {
        AppLogging.widgets('[WidgetStorage] No widgets stored');
        return [];
      }

      final list = jsonDecode(json) as List<dynamic>;
      AppLogging.widgets(
        '[WidgetStorage] Parsed ${list.length} widgets from storage',
      );
      return list
          .map((item) => WidgetSchema.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogging.widgets('[WidgetStorage] ERROR loading widgets: $e');
      AppLogging.widgets('[WidgetStorage] Stack: $stack');
      AppLogging.widgets('⚠️ Error loading widgets: $e');
      return [];
    }
  }

  /// Get a specific widget by ID
  Future<WidgetSchema?> getWidget(String id) async {
    // Delegate to SQLite store if available
    if (_sharedStore != null) {
      return _sharedStore!.getById(id);
    }

    // Legacy SharedPreferences path
    final widgets = await getWidgets();
    try {
      return widgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Delete a widget
  /// Returns the marketplace ID if this was a marketplace widget (for profile cleanup)
  Future<String?> deleteWidget(String id) async {
    AppLogging.sync(
      '[WidgetStorage] deleteWidget() ENTER — '
      'id=$id, hasStore=$hasStore, '
      'store.syncEnabled=${_sharedStore?.syncEnabled}',
    );
    try {
      // Delete from SQLite store if available, otherwise from SharedPreferences
      if (_sharedStore != null) {
        await _sharedStore!.delete(id);
      } else {
        final widgets = await getWidgets();
        widgets.removeWhere((w) => w.id == id);
        await _saveWidgetsList(widgets);
      }

      // Look up marketplace ID from schema ID mapping
      final marketplaceId = await getMarketplaceIdForSchema(id);
      AppLogging.widgets(
        '[WidgetStorage] deleteWidget: schemaId=$id, marketplaceId=$marketplaceId',
      );

      // Remove from marketplace installed list using marketplace ID
      final installed = _preferences.getStringList(_installedKey) ?? [];
      final idToRemove = marketplaceId ?? id;
      if (installed.contains(idToRemove)) {
        installed.remove(idToRemove);
        await _preferences.setStringList(_installedKey, installed);
        AppLogging.widgets(
          '[WidgetStorage] Removed from marketplace installed list: $idToRemove',
        );
        AppLogging.widgets(
          'Removed from marketplace installed list: $idToRemove',
        );
      }

      // Also remove schema ID if it was stored directly (user-created widgets)
      if (installed.contains(id) && id != idToRemove) {
        installed.remove(id);
        await _preferences.setStringList(_installedKey, installed);
      }

      // Remove from schema->marketplace mapping
      if (marketplaceId != null) {
        await _removeSchemaToMarketplaceMapping(id);
      }

      AppLogging.widgets('Deleted widget: $id');
      AppLogging.sync(
        '[WidgetStorage] deleteWidget() EXIT — '
        'id=$id deleted, marketplaceId=$marketplaceId',
      );
      return marketplaceId; // Return for profile cleanup
    } catch (e) {
      AppLogging.widgets('Error deleting widget: $e');
      AppLogging.sync('[WidgetStorage] deleteWidget() ERROR: $e');
      rethrow;
    }
  }

  /// Duplicate a widget
  Future<WidgetSchema> duplicateWidget(String id) async {
    final original = await getWidget(id);
    if (original == null) {
      throw Exception('Widget not found: $id');
    }

    final copy = WidgetSchema(
      name: '${original.name} (Copy)',
      description: original.description,
      author: original.author,
      version: original.version,
      size: original.size,
      root: original.root,
      tags: original.tags,
      isPublic: false,
    );

    await saveWidget(copy);
    return copy;
  }

  /// Export widget to JSON string
  Future<String> exportWidget(String id) async {
    final widget = await getWidget(id);
    if (widget == null) {
      throw Exception('Widget not found: $id');
    }
    return widget.toJsonString();
  }

  /// Import widget from JSON string
  Future<WidgetSchema> importWidget(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final widget = WidgetSchema.fromJson(json);

      // Create a new widget with a new ID to avoid conflicts
      final importedWidget = WidgetSchema(
        name: widget.name,
        description: widget.description,
        author: widget.author,
        version: widget.version,
        size: widget.size,
        root: widget.root,
        tags: widget.tags,
        isPublic: false,
      );

      await saveWidget(importedWidget);
      return importedWidget;
    } catch (e) {
      AppLogging.widgets('⚠️ Error importing widget: $e');
      rethrow;
    }
  }

  /// Save widgets installed from marketplace
  /// [marketplaceId] is the Firebase document ID from the marketplace (optional, defaults to widget.id)
  Future<void> installMarketplaceWidget(
    WidgetSchema widget, {
    String? marketplaceId,
  }) async {
    try {
      // Save to regular storage
      await saveWidget(widget);

      // Track marketplace ID (Firebase doc ID) as installed
      // This is the ID stored in user profile's installedWidgetIds
      final idToTrack = marketplaceId ?? widget.id;
      final installed = _preferences.getStringList(_installedKey) ?? [];
      if (!installed.contains(idToTrack)) {
        installed.add(idToTrack);
        await _preferences.setStringList(_installedKey, installed);
        AppLogging.widgets(
          '[WidgetStorage] Tracking marketplace ID: $idToTrack for widget: ${widget.name}',
        );
      }

      // Store schema ID -> marketplace ID mapping for deletion lookup
      if (marketplaceId != null && marketplaceId != widget.id) {
        await _saveSchemaToMarketplaceMapping(widget.id, marketplaceId);
        AppLogging.widgets(
          '[WidgetStorage] Saved mapping: ${widget.id} -> $marketplaceId',
        );
      }

      AppLogging.widgets(
        'Installed marketplace widget: ${widget.name} (marketplace ID: $idToTrack)',
      );
    } catch (e) {
      AppLogging.widgets('⚠️ Error installing marketplace widget: $e');
      rethrow;
    }
  }

  /// Check if a widget is from the marketplace
  Future<bool> isMarketplaceWidget(String id) async {
    final installed = _preferences.getStringList(_installedKey) ?? [];
    return installed.contains(id);
  }

  /// Get IDs of widgets installed from marketplace
  Future<List<String>> getInstalledMarketplaceIds() async {
    return _preferences.getStringList(_installedKey) ?? [];
  }

  /// Get marketplace ID for a schema ID (used during deletion)
  Future<String?> getMarketplaceIdForSchema(String schemaId) async {
    final mapJson = _preferences.getString(_schemaToMarketplaceKey);
    if (mapJson == null || mapJson.isEmpty) return null;
    try {
      final map = jsonDecode(mapJson) as Map<String, dynamic>;
      return map[schemaId] as String?;
    } catch (e) {
      AppLogging.widgets(
        '[WidgetStorage] Error reading schema->marketplace map: $e',
      );
      return null;
    }
  }

  /// Save schema ID -> marketplace ID mapping
  Future<void> _saveSchemaToMarketplaceMapping(
    String schemaId,
    String marketplaceId,
  ) async {
    final mapJson = _preferences.getString(_schemaToMarketplaceKey);
    Map<String, dynamic> map = {};
    if (mapJson != null && mapJson.isNotEmpty) {
      try {
        map = jsonDecode(mapJson) as Map<String, dynamic>;
      } catch (_) {}
    }
    map[schemaId] = marketplaceId;
    await _preferences.setString(_schemaToMarketplaceKey, jsonEncode(map));
  }

  /// Remove schema ID from mapping
  Future<void> _removeSchemaToMarketplaceMapping(String schemaId) async {
    final mapJson = _preferences.getString(_schemaToMarketplaceKey);
    if (mapJson == null || mapJson.isEmpty) return;
    try {
      final map = jsonDecode(mapJson) as Map<String, dynamic>;
      map.remove(schemaId);
      await _preferences.setString(_schemaToMarketplaceKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _saveWidgetsList(List<WidgetSchema> widgets) async {
    final json = jsonEncode(widgets.map((w) => w.toJson()).toList());
    await _preferences.setString(_storageKey, json);
  }

  /// Clear all widgets (for testing/debug)
  Future<void> clearAll() async {
    if (_sharedStore != null) {
      await _sharedStore!.clearAll();
    }
    await _preferences.remove(_storageKey);
    await _preferences.remove(_installedKey);
    await _preferences.remove(_schemaToMarketplaceKey);
    AppLogging.widgets('Cleared all custom widgets');
  }
}

/// Provider for widget templates
class WidgetTemplates {
  /// Battery status widget template
  static WidgetSchema batteryWidget() {
    return WidgetSchema(
      name: 'Battery Status',
      description: 'Display battery level with gauge',
      tags: ['status', 'battery', 'power'],
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: [
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(
              mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
            ),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'battery_full',
                iconSize: 20,
                style: const StyleSchema(textColor: '#4ADE80'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.displayName',
                  defaultValue: 'My Device',
                ),
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.text,
            binding: const BindingSchema(
              path: 'node.batteryLevel',
              format: '{value}%',
              defaultValue: '--',
            ),
            style: const StyleSchema(
              textColor: '#FFFFFF',
              fontSize: 32,
              fontWeight: 'bold',
            ),
          ),
          ElementSchema(
            type: ElementType.gauge,
            gaugeType: GaugeType.linear,
            gaugeMin: 0,
            gaugeMax: 100,
            gaugeColor: '#4ADE80',
            binding: const BindingSchema(path: 'node.batteryLevel'),
            style: const StyleSchema(height: 6),
          ),
        ],
      ),
    );
  }

  /// Signal strength widget template
  static WidgetSchema signalWidget() {
    return WidgetSchema(
      name: 'Signal Strength',
      description: 'Display SNR and RSSI',
      tags: ['info', 'signal', 'snr', 'rssi', 'connectivity'],
      size: CustomWidgetSize.medium,
      root: ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          padding: 16,
          mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
        ),
        children: [
          // SNR
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'signal_cellular_alt',
                iconSize: 24,
                style: const StyleSchema(textColor: '#4F6AF6'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'device.snr',
                  format: '{value} dB',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'SNR',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // RSSI
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'network_check',
                iconSize: 24,
                style: const StyleSchema(textColor: '#22C55E'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'device.rssi',
                  format: '{value} dBm',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'RSSI',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Environment sensor widget template
  static WidgetSchema environmentWidget() {
    return WidgetSchema(
      name: 'Environment',
      description: 'Temperature, humidity, and pressure display',
      tags: ['environment', 'temperature', 'humidity', 'pressure', 'sensors'],
      size: CustomWidgetSize.medium,
      root: ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          padding: 16,
          mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
        ),
        children: [
          // Temperature
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'thermostat',
                iconSize: 24,
                style: const StyleSchema(textColor: '#EF4444'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.temperature',
                  format: '{value}°',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Temp',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // Humidity
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'water_drop',
                iconSize: 24,
                style: const StyleSchema(textColor: '#06B6D4'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.humidity',
                  format: '{value}%',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Humidity',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // Barometric Pressure
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'speed',
                iconSize: 24,
                style: const StyleSchema(textColor: '#8B5CF6'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.pressure',
                  format: '{value}',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'hPa',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Node info widget template
  static WidgetSchema nodeInfoWidget() {
    return WidgetSchema(
      name: 'Node Info',
      description: 'Basic node information card',
      tags: ['info', 'node'],
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 10),
        children: [
          // Header with icon and node name
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'hub',
                iconSize: 20,
                style: const StyleSchema(textColor: '#E91E8C'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(width: 8),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.displayName',
                  defaultValue: 'Unknown Node',
                ),
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 16,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
          // Role label with value
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.text,
                text: 'Role: ',
                style: const StyleSchema(textColor: '#666666', fontSize: 12),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.role',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#AAAAAA', fontSize: 12),
              ),
            ],
          ),
          // Hardware model
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.text,
                text: 'Device: ',
                style: const StyleSchema(textColor: '#666666', fontSize: 12),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.hardwareModel',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#AAAAAA', fontSize: 12),
              ),
            ],
          ),
          // Last heard with label
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'schedule',
                iconSize: 12,
                style: const StyleSchema(textColor: '#555555'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(width: 4),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.lastHeard',
                  defaultValue: 'Never',
                ),
                style: const StyleSchema(textColor: '#555555', fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// GPS position widget template
  static WidgetSchema gpsWidget() {
    return WidgetSchema(
      name: 'GPS Position',
      description: 'Show GPS coordinates and satellites',
      tags: ['location', 'gps', 'position', 'coordinates'],
      size: CustomWidgetSize.medium,
      root: ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          padding: 16,
          mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
        ),
        children: [
          // Latitude
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'gps_fixed',
                iconSize: 24,
                style: const StyleSchema(textColor: '#22C55E'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.latitude',
                  format: '{value}°',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Lat',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // Longitude
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'explore',
                iconSize: 24,
                style: const StyleSchema(textColor: '#4F6AF6'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.longitude',
                  format: '{value}°',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Lon',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // Satellites
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'satellite_alt',
                iconSize: 24,
                style: const StyleSchema(textColor: '#F59E0B'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.satsInView',
                  defaultValue: '--',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Sats',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get all built-in templates
  static List<WidgetSchema> all() {
    return [
      batteryWidget(),
      signalWidget(),
      environmentWidget(),
      nodeInfoWidget(),
      gpsWidget(),
      networkOverviewWidget(),
      quickActionsWidget(),
    ];
  }

  /// Network overview widget template
  static WidgetSchema networkOverviewWidget() {
    return WidgetSchema(
      name: 'Network Overview',
      description: 'Mesh network status at a glance',
      tags: ['status', 'network', 'mesh', 'nodes'],
      size: CustomWidgetSize.medium,
      root: ElementSchema(
        type: ElementType.row,
        style: const StyleSchema(
          padding: 16,
          mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
        ),
        children: [
          // Status
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'check_circle',
                iconSize: 24,
                style: const StyleSchema(textColor: '#4ADE80'),
                condition: ConditionalSchema(
                  bindingPath: 'node.presenceConfidence',
                  operator: ConditionalOperator.equals,
                  value: true,
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Online',
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Status',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // Nodes
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'people_outline',
                iconSize: 24,
                style: const StyleSchema(textColor: '#4F6AF6'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'network.totalNodes',
                  defaultValue: '0',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Nodes',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
          // Divider
          ElementSchema(
            type: ElementType.shape,
            shapeType: ShapeType.dividerVertical,
            style: const StyleSchema(height: 50, width: 1),
          ),
          // Messages
          ElementSchema(
            type: ElementType.column,
            style: const StyleSchema(alignment: AlignmentOption.center),
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'chat_bubble_outline',
                iconSize: 24,
                style: const StyleSchema(textColor: '#4F6AF6'),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'messaging.recentCount',
                  defaultValue: '0',
                ),
                style: const StyleSchema(
                  fontSize: 16,
                  fontWeight: 'w600',
                  textColor: '#FFFFFF',
                ),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Messages',
                style: const StyleSchema(fontSize: 11, textColor: '#888888'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Quick actions widget template - displays quick action buttons
  static WidgetSchema quickActionsWidget() {
    return WidgetSchema(
      name: 'Quick Actions',
      description: 'Common mesh actions at a glance',
      tags: ['actions', 'quick', 'compose', 'send'],
      size: CustomWidgetSize.medium,
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 12),
        children: [
          // Header row
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'flash_on',
                iconSize: 20,
                style: const StyleSchema(textColor: '#FBBF24'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(width: 8),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Quick Actions',
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
          // Action buttons row - matching native Quick Compose style
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(spacing: 8),
            children: [
              // Message action - rectangular button
              ElementSchema(
                type: ElementType.container,
                style: const StyleSchema(
                  expanded: true,
                  height: 48,
                  backgroundColor: '#0D1F3C',
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: '#1A3A66',
                  alignment: AlignmentOption.center,
                ),
                action: const ActionSchema(
                  type: ActionType.sendMessage,
                  requiresNodeSelection: true,
                  requiresChannelSelection: true,
                  label: 'Quick Message',
                ),
                children: [
                  ElementSchema(
                    type: ElementType.column,
                    style: const StyleSchema(
                      alignment: AlignmentOption.center,
                      mainAxisAlignment: MainAxisAlignmentOption.center,
                    ),
                    children: [
                      ElementSchema(
                        type: ElementType.icon,
                        iconName: 'send',
                        iconSize: 18,
                        style: const StyleSchema(textColor: '#4F6AF6'),
                      ),
                      ElementSchema(
                        type: ElementType.spacer,
                        style: const StyleSchema(height: 2),
                      ),
                      ElementSchema(
                        type: ElementType.text,
                        text: 'Message',
                        style: const StyleSchema(
                          textColor: '#4F6AF6',
                          fontSize: 8,
                          fontWeight: 'w600',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Location action - rectangular button
              ElementSchema(
                type: ElementType.container,
                style: const StyleSchema(
                  expanded: true,
                  height: 48,
                  backgroundColor: '#0D2818',
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: '#1A4D30',
                  alignment: AlignmentOption.center,
                ),
                action: const ActionSchema(
                  type: ActionType.shareLocation,
                  label: 'Share Location',
                ),
                children: [
                  ElementSchema(
                    type: ElementType.column,
                    style: const StyleSchema(
                      alignment: AlignmentOption.center,
                      mainAxisAlignment: MainAxisAlignmentOption.center,
                    ),
                    children: [
                      ElementSchema(
                        type: ElementType.icon,
                        iconName: 'location_on',
                        iconSize: 18,
                        style: const StyleSchema(textColor: '#22C55E'),
                      ),
                      ElementSchema(
                        type: ElementType.spacer,
                        style: const StyleSchema(height: 2),
                      ),
                      ElementSchema(
                        type: ElementType.text,
                        text: 'Location',
                        style: const StyleSchema(
                          textColor: '#22C55E',
                          fontSize: 8,
                          fontWeight: 'w600',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Traceroute action - rectangular button
              ElementSchema(
                type: ElementType.container,
                style: const StyleSchema(
                  expanded: true,
                  height: 48,
                  backgroundColor: '#2D1A0D',
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: '#5C3D1F',
                  alignment: AlignmentOption.center,
                ),
                action: const ActionSchema(
                  type: ActionType.traceroute,
                  requiresNodeSelection: true,
                  label: 'Traceroute',
                ),
                children: [
                  ElementSchema(
                    type: ElementType.column,
                    style: const StyleSchema(
                      alignment: AlignmentOption.center,
                      mainAxisAlignment: MainAxisAlignmentOption.center,
                    ),
                    children: [
                      ElementSchema(
                        type: ElementType.icon,
                        iconName: 'route',
                        iconSize: 18,
                        style: const StyleSchema(textColor: '#F97316'),
                      ),
                      ElementSchema(
                        type: ElementType.spacer,
                        style: const StyleSchema(height: 2),
                      ),
                      ElementSchema(
                        type: ElementType.text,
                        text: 'Trace',
                        style: const StyleSchema(
                          textColor: '#F97316',
                          fontSize: 8,
                          fontWeight: 'w600',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Request positions action - rectangular button
              ElementSchema(
                type: ElementType.container,
                style: const StyleSchema(
                  expanded: true,
                  height: 48,
                  backgroundColor: '#0D2226',
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: '#1A444D',
                  alignment: AlignmentOption.center,
                ),
                action: const ActionSchema(
                  type: ActionType.requestPositions,
                  label: 'Request Positions',
                ),
                children: [
                  ElementSchema(
                    type: ElementType.column,
                    style: const StyleSchema(
                      alignment: AlignmentOption.center,
                      mainAxisAlignment: MainAxisAlignmentOption.center,
                    ),
                    children: [
                      ElementSchema(
                        type: ElementType.icon,
                        iconName: 'refresh',
                        iconSize: 18,
                        style: const StyleSchema(textColor: '#06B6D4'),
                      ),
                      ElementSchema(
                        type: ElementType.spacer,
                        style: const StyleSchema(height: 2),
                      ),
                      ElementSchema(
                        type: ElementType.text,
                        text: 'Refresh',
                        style: const StyleSchema(
                          textColor: '#06B6D4',
                          fontSize: 8,
                          fontWeight: 'w600',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
