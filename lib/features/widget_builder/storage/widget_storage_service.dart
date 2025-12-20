import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/widget_schema.dart';

/// Service for persisting custom widgets locally
class WidgetStorageService {
  static const _storageKey = 'custom_widgets';
  static const _installedKey = 'installed_widgets';
  // Maps schema ID (UUID) -> marketplace ID (Firebase doc ID)
  static const _schemaToMarketplaceKey = 'schema_to_marketplace_map';

  final Logger _logger;
  SharedPreferences? _prefs;

  WidgetStorageService({Logger? logger}) : _logger = logger ?? Logger();

  /// Initialize the service
  Future<void> init() async {
    debugPrint('[WidgetStorage] Initializing...');
    _prefs = await SharedPreferences.getInstance();
    debugPrint('[WidgetStorage] Initialized successfully');
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      debugPrint('[WidgetStorage] ERROR: Service not initialized!');
      throw Exception('WidgetStorageService not initialized');
    }
    return _prefs!;
  }

  /// Save a custom widget
  Future<void> saveWidget(WidgetSchema widget) async {
    debugPrint(
      '[WidgetStorage] saveWidget called for id=${widget.id}, name=${widget.name}',
    );
    try {
      // Ensure initialized
      if (_prefs == null) {
        debugPrint('[WidgetStorage] Not initialized, initializing now...');
        await init();
      }

      final widgets = await getWidgets();
      debugPrint('[WidgetStorage] Current widgets count: ${widgets.length}');

      final index = widgets.indexWhere((w) => w.id == widget.id);
      debugPrint('[WidgetStorage] Existing widget index: $index');

      if (index >= 0) {
        debugPrint('[WidgetStorage] Updating existing widget at index $index');
        widgets[index] = widget;
      } else {
        debugPrint('[WidgetStorage] Adding new widget');
        widgets.add(widget);
      }

      await _saveWidgetsList(widgets);
      debugPrint(
        '[WidgetStorage] Widget saved successfully, new count: ${widgets.length}',
      );
      _logger.d('Saved widget: ${widget.name}');
    } catch (e, stack) {
      debugPrint('[WidgetStorage] ERROR saving widget: $e');
      debugPrint('[WidgetStorage] Stack: $stack');
      _logger.e('Error saving widget: $e');
      rethrow;
    }
  }

  /// Get all custom widgets
  Future<List<WidgetSchema>> getWidgets() async {
    try {
      // Ensure initialized
      if (_prefs == null) {
        debugPrint(
          '[WidgetStorage] Not initialized in getWidgets, initializing...',
        );
        await init();
      }

      final json = _preferences.getString(_storageKey);
      debugPrint(
        '[WidgetStorage] getWidgets - raw json length: ${json?.length ?? 0}',
      );
      if (json == null || json.isEmpty) {
        debugPrint('[WidgetStorage] No widgets stored');
        return [];
      }

      final list = jsonDecode(json) as List<dynamic>;
      debugPrint('[WidgetStorage] Parsed ${list.length} widgets from storage');
      return list
          .map((item) => WidgetSchema.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('[WidgetStorage] ERROR loading widgets: $e');
      debugPrint('[WidgetStorage] Stack: $stack');
      _logger.e('Error loading widgets: $e');
      return [];
    }
  }

  /// Get a specific widget by ID
  Future<WidgetSchema?> getWidget(String id) async {
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
    try {
      final widgets = await getWidgets();
      widgets.removeWhere((w) => w.id == id);
      await _saveWidgetsList(widgets);

      // Look up marketplace ID from schema ID mapping
      final marketplaceId = await getMarketplaceIdForSchema(id);
      debugPrint(
        '[WidgetStorage] deleteWidget: schemaId=$id, marketplaceId=$marketplaceId',
      );

      // Remove from marketplace installed list using marketplace ID
      final installed = _preferences.getStringList(_installedKey) ?? [];
      final idToRemove = marketplaceId ?? id;
      if (installed.contains(idToRemove)) {
        installed.remove(idToRemove);
        await _preferences.setStringList(_installedKey, installed);
        debugPrint(
          '[WidgetStorage] Removed from marketplace installed list: $idToRemove',
        );
        _logger.d('Removed from marketplace installed list: $idToRemove');
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

      _logger.d('Deleted widget: $id');
      return marketplaceId; // Return for profile cleanup
    } catch (e) {
      _logger.e('Error deleting widget: $e');
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
      _logger.e('Error importing widget: $e');
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
        debugPrint(
          '[WidgetStorage] Tracking marketplace ID: $idToTrack for widget: ${widget.name}',
        );
      }

      // Store schema ID -> marketplace ID mapping for deletion lookup
      if (marketplaceId != null && marketplaceId != widget.id) {
        await _saveSchemaToMarketplaceMapping(widget.id, marketplaceId);
        debugPrint(
          '[WidgetStorage] Saved mapping: ${widget.id} -> $marketplaceId',
        );
      }

      _logger.d(
        'Installed marketplace widget: ${widget.name} (marketplace ID: $idToTrack)',
      );
    } catch (e) {
      _logger.e('Error installing marketplace widget: $e');
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
      debugPrint('[WidgetStorage] Error reading schema->marketplace map: $e');
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
    await _preferences.remove(_storageKey);
    await _preferences.remove(_installedKey);
    await _preferences.remove(_schemaToMarketplaceKey);
    _logger.i('Cleared all custom widgets');
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
                  bindingPath: 'node.isOnline',
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
