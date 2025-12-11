import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/grid_widget_schema.dart';

/// Service for persisting grid-based custom widgets locally
class GridWidgetStorageService {
  static const _storageKey = 'grid_widgets';
  static const _seedVersionKey = 'grid_widgets_seed_version';
  static const _currentSeedVersion = 1;

  final Logger _logger;
  SharedPreferences? _prefs;

  GridWidgetStorageService({Logger? logger}) : _logger = logger ?? Logger();

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _seedDefaultWidgets();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('GridWidgetStorageService not initialized');
    }
    return _prefs!;
  }

  /// Seed default widgets on first launch
  Future<void> _seedDefaultWidgets() async {
    final lastVersion = _preferences.getInt(_seedVersionKey) ?? 0;
    if (lastVersion >= _currentSeedVersion) return;

    _logger.i(
      'Seeding grid widgets: version $lastVersion -> $_currentSeedVersion',
    );

    final existingWidgets = await getWidgets();
    final existingNames = existingWidgets.map((w) => w.name).toSet();

    for (final template in GridWidgetTemplates.all()) {
      if (!existingNames.contains(template.name)) {
        await saveWidget(template);
        _logger.d('Seeded grid widget: ${template.name}');
      }
    }

    await _preferences.setInt(_seedVersionKey, _currentSeedVersion);
    _logger.i('Grid widgets seeded successfully (v$_currentSeedVersion)');
  }

  /// Save a widget
  Future<void> saveWidget(GridWidgetSchema widget) async {
    try {
      final widgets = await getWidgets();
      final index = widgets.indexWhere((w) => w.id == widget.id);

      if (index >= 0) {
        widgets[index] = widget;
      } else {
        widgets.add(widget);
      }

      await _saveWidgetsList(widgets);
      _logger.d('Saved grid widget: ${widget.name}');
    } catch (e) {
      _logger.e('Error saving grid widget: $e');
      rethrow;
    }
  }

  /// Get all widgets
  Future<List<GridWidgetSchema>> getWidgets() async {
    try {
      final json = _preferences.getString(_storageKey);
      if (json == null || json.isEmpty) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map(
            (item) => GridWidgetSchema.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      _logger.e('Error loading grid widgets: $e');
      return [];
    }
  }

  /// Get a specific widget by ID
  Future<GridWidgetSchema?> getWidget(String id) async {
    final widgets = await getWidgets();
    try {
      return widgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Delete a widget
  Future<void> deleteWidget(String id) async {
    try {
      final widgets = await getWidgets();
      widgets.removeWhere((w) => w.id == id);
      await _saveWidgetsList(widgets);
      _logger.d('Deleted grid widget: $id');
    } catch (e) {
      _logger.e('Error deleting grid widget: $e');
      rethrow;
    }
  }

  /// Duplicate a widget
  Future<GridWidgetSchema> duplicateWidget(String id) async {
    final original = await getWidget(id);
    if (original == null) {
      throw Exception('Grid widget not found: $id');
    }

    final copy = GridWidgetSchema(
      name: '${original.name} (Copy)',
      size: original.size,
      elements: original.elements,
    );

    await saveWidget(copy);
    return copy;
  }

  /// Export widget to JSON string
  Future<String> exportWidget(String id) async {
    final widget = await getWidget(id);
    if (widget == null) {
      throw Exception('Grid widget not found: $id');
    }
    return jsonEncode(widget.toJson());
  }

  /// Import widget from JSON string
  Future<GridWidgetSchema> importWidget(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final widget = GridWidgetSchema.fromJson(json);

      // Create new widget with fresh ID to avoid conflicts
      final imported = GridWidgetSchema(
        name: widget.name,
        size: widget.size,
        elements: widget.elements,
        customWidth: widget.customWidth,
        customHeight: widget.customHeight,
      );

      await saveWidget(imported);
      return imported;
    } catch (e) {
      _logger.e('Error importing grid widget: $e');
      rethrow;
    }
  }

  Future<void> _saveWidgetsList(List<GridWidgetSchema> widgets) async {
    final json = jsonEncode(widgets.map((w) => w.toJson()).toList());
    await _preferences.setString(_storageKey, json);
  }

  /// Clear all widgets (for testing)
  Future<void> clearAll() async {
    await _preferences.remove(_storageKey);
    await _preferences.remove(_seedVersionKey);
    _logger.d('Cleared all grid widgets');
  }
}

/// Default template widgets for grid-based system
class GridWidgetTemplates {
  static List<GridWidgetSchema> all() {
    return [
      _batteryWidget(),
      _signalWidget(),
      _environmentWidget(),
      _nodeInfoWidget(),
      _gpsWidget(),
      _networkOverviewWidget(),
      _quickActionsWidget(),
    ];
  }

  /// Battery status widget - shows battery icon, name and gauge
  static GridWidgetSchema _batteryWidget() {
    return GridWidgetSchema(
      name: 'Battery Status',
      description: 'Display battery level with gauge',
      size: GridWidgetSize.small, // 2x2
      elements: [
        // Row 0: Icon and label
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 0,
          iconName: 'battery_full',
          iconSize: 20,
          iconColor: const Color(0xFF4ADE80),
        ),
        GridElement(
          type: GridElementType.text,
          row: 0,
          column: 1,
          binding: const GridBinding(path: 'node.displayName'),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        // Row 1: Gauge spanning both columns
        GridElement(
          type: GridElementType.gauge,
          row: 1,
          column: 0,
          columnSpan: 2,
          gaugeStyle: GaugeStyle.battery,
          binding: const GridBinding(path: 'node.batteryLevel'),
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: const Color(0xFF4ADE80),
        ),
      ],
    );
  }

  /// Signal strength widget - shows SNR/RSSI with signal gauge
  static GridWidgetSchema _signalWidget() {
    return GridWidgetSchema(
      name: 'Signal Strength',
      description: 'Display SNR and RSSI signal quality',
      size: GridWidgetSize.small, // 2x2
      elements: [
        // Signal gauge spanning full widget
        GridElement(
          type: GridElementType.gauge,
          row: 0,
          column: 0,
          rowSpan: 2,
          columnSpan: 2,
          gaugeStyle: GaugeStyle.signal,
          binding: const GridBinding(path: 'device.snr'),
          gaugeMin: -20,
          gaugeMax: 20,
          gaugeColor: const Color(0xFF4F6AF6),
        ),
      ],
    );
  }

  /// Environment widget - temp, humidity, pressure
  static GridWidgetSchema _environmentWidget() {
    return GridWidgetSchema(
      name: 'Environment',
      description: 'Temperature, humidity, and pressure',
      size: GridWidgetSize.medium, // 3x2
      elements: [
        // Row 0: Icons
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 0,
          iconName: 'thermostat',
          iconSize: 24,
          iconColor: const Color(0xFFEF4444),
        ),
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 1,
          iconName: 'water_drop',
          iconSize: 24,
          iconColor: const Color(0xFF06B6D4),
        ),
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 2,
          iconName: 'speed',
          iconSize: 24,
          iconColor: const Color(0xFF8B5CF6),
        ),
        // Row 1: Values
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 0,
          binding: const GridBinding(
            path: 'node.temperature',
            format: '{value}°',
          ),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 1,
          binding: const GridBinding(path: 'node.humidity', format: '{value}%'),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 2,
          binding: const GridBinding(path: 'node.pressure', format: '{value}'),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }

  /// Node info widget with name and last heard
  static GridWidgetSchema _nodeInfoWidget() {
    return GridWidgetSchema(
      name: 'Node Info',
      description: 'Basic node information card',
      size: GridWidgetSize.medium, // 3x2
      elements: [
        // Row 0: Icon and name
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 0,
          iconName: 'router',
          iconSize: 24,
          iconColor: const Color(0xFFE91E8C),
        ),
        GridElement(
          type: GridElementType.text,
          row: 0,
          column: 1,
          columnSpan: 2,
          binding: const GridBinding(path: 'node.displayName'),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        // Row 1: Role and last heard
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 0,
          columnSpan: 2,
          binding: const GridBinding(path: 'node.role'),
          fontSize: 12,
          textColor: const Color(0xFF888888),
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 2,
          binding: const GridBinding(path: 'node.lastHeard'),
          fontSize: 11,
          textColor: const Color(0xFF666666),
        ),
      ],
    );
  }

  /// GPS position widget
  static GridWidgetSchema _gpsWidget() {
    return GridWidgetSchema(
      name: 'GPS Position',
      description: 'Show GPS coordinates and satellites',
      size: GridWidgetSize.medium, // 3x2
      elements: [
        // Row 0: GPS icon and sats
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 0,
          iconName: 'gps_fixed',
          iconSize: 24,
          iconColor: const Color(0xFF22C55E),
        ),
        GridElement(
          type: GridElementType.text,
          row: 0,
          column: 1,
          text: 'GPS',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        GridElement(
          type: GridElementType.text,
          row: 0,
          column: 2,
          binding: const GridBinding(
            path: 'node.satsInView',
            format: '{value} sats',
          ),
          fontSize: 12,
          textColor: const Color(0xFF888888),
        ),
        // Row 1: Lat/Lon/Alt
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 0,
          binding: const GridBinding(path: 'node.latitude', format: '{value}°'),
          fontSize: 12,
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 1,
          binding: const GridBinding(
            path: 'node.longitude',
            format: '{value}°',
          ),
          fontSize: 12,
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 2,
          binding: const GridBinding(path: 'node.altitude', format: '{value}m'),
          fontSize: 12,
          textColor: const Color(0xFF888888),
        ),
      ],
    );
  }

  /// Network overview - nodes count and message count
  static GridWidgetSchema _networkOverviewWidget() {
    return GridWidgetSchema(
      name: 'Network Overview',
      description: 'Mesh network status at a glance',
      size: GridWidgetSize.medium, // 3x2
      elements: [
        // Row 0: Icons
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 0,
          iconName: 'check_circle',
          iconSize: 24,
          iconColor: const Color(0xFF4ADE80),
        ),
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 1,
          iconName: 'people_outline',
          iconSize: 24,
          iconColor: const Color(0xFF4F6AF6),
        ),
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 2,
          iconName: 'chat_bubble_outline',
          iconSize: 24,
          iconColor: const Color(0xFF4F6AF6),
        ),
        // Row 1: Values
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 0,
          text: 'Online',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 1,
          binding: const GridBinding(path: 'network.totalNodes'),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        GridElement(
          type: GridElementType.text,
          row: 1,
          column: 2,
          binding: const GridBinding(path: 'messaging.recentCount'),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }

  /// Quick actions widget with tappable action icons
  static GridWidgetSchema _quickActionsWidget() {
    return GridWidgetSchema(
      name: 'Quick Actions',
      description: 'Common mesh actions at a glance',
      size: GridWidgetSize.large, // 3x3
      elements: [
        // Row 0: Header
        GridElement(
          type: GridElementType.icon,
          row: 0,
          column: 0,
          iconName: 'flash_on',
          iconSize: 20,
          iconColor: const Color(0xFFFBBF24),
        ),
        GridElement(
          type: GridElementType.text,
          row: 0,
          column: 1,
          columnSpan: 2,
          text: 'Quick Actions',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        // Row 1: Action icons
        GridElement(
          type: GridElementType.icon,
          row: 1,
          column: 0,
          iconName: 'send',
          iconSize: 28,
          iconColor: const Color(0xFF4F6AF6),
          action: const GridAction(type: GridActionType.sendMessage),
        ),
        GridElement(
          type: GridElementType.icon,
          row: 1,
          column: 1,
          iconName: 'location_on',
          iconSize: 28,
          iconColor: const Color(0xFF22C55E),
          action: const GridAction(type: GridActionType.shareLocation),
        ),
        GridElement(
          type: GridElementType.icon,
          row: 1,
          column: 2,
          iconName: 'radar',
          iconSize: 28,
          iconColor: const Color(0xFF8B5CF6),
          action: const GridAction(type: GridActionType.traceroute),
        ),
        // Row 2: Labels
        GridElement(
          type: GridElementType.text,
          row: 2,
          column: 0,
          text: 'Message',
          fontSize: 10,
          textColor: const Color(0xFF888888),
        ),
        GridElement(
          type: GridElementType.text,
          row: 2,
          column: 1,
          text: 'Location',
          fontSize: 10,
          textColor: const Color(0xFF888888),
        ),
        GridElement(
          type: GridElementType.text,
          row: 2,
          column: 2,
          text: 'Traceroute',
          fontSize: 10,
          textColor: const Color(0xFF888888),
        ),
      ],
    );
  }
}
