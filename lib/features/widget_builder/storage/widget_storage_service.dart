import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/widget_schema.dart';

/// Service for persisting custom widgets locally
class WidgetStorageService {
  static const _storageKey = 'custom_widgets';
  static const _installedKey = 'installed_widgets';
  static const _seededKey = 'seeded_widgets';

  final Logger _logger;
  SharedPreferences? _prefs;

  WidgetStorageService({Logger? logger}) : _logger = logger ?? Logger();

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _seedDefaultWidgets();
  }

  /// Seed default widgets on first launch so users have examples
  Future<void> _seedDefaultWidgets() async {
    final alreadySeeded = _preferences.getBool(_seededKey) ?? false;
    if (alreadySeeded) return;

    _logger.i('Seeding default widgets for first launch');

    // Save all template widgets as user widgets
    for (final template in WidgetTemplates.all()) {
      await saveWidget(template);
    }

    await _preferences.setBool(_seededKey, true);
    _logger.i('Default widgets seeded successfully');
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('WidgetStorageService not initialized');
    }
    return _prefs!;
  }

  /// Save a custom widget
  Future<void> saveWidget(WidgetSchema widget) async {
    try {
      final widgets = await getWidgets();
      final index = widgets.indexWhere((w) => w.id == widget.id);

      if (index >= 0) {
        widgets[index] = widget;
      } else {
        widgets.add(widget);
      }

      await _saveWidgetsList(widgets);
      _logger.d('Saved widget: ${widget.name}');
    } catch (e) {
      _logger.e('Error saving widget: $e');
      rethrow;
    }
  }

  /// Get all custom widgets
  Future<List<WidgetSchema>> getWidgets() async {
    try {
      final json = _preferences.getString(_storageKey);
      if (json == null || json.isEmpty) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((item) => WidgetSchema.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
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
  Future<void> deleteWidget(String id) async {
    try {
      final widgets = await getWidgets();
      widgets.removeWhere((w) => w.id == id);
      await _saveWidgetsList(widgets);
      _logger.d('Deleted widget: $id');
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
  Future<void> installMarketplaceWidget(WidgetSchema widget) async {
    try {
      // Save to regular storage
      await saveWidget(widget);

      // Track as installed from marketplace
      final installed = _preferences.getStringList(_installedKey) ?? [];
      if (!installed.contains(widget.id)) {
        installed.add(widget.id);
        await _preferences.setStringList(_installedKey, installed);
      }

      _logger.d('Installed marketplace widget: ${widget.name}');
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

  Future<void> _saveWidgetsList(List<WidgetSchema> widgets) async {
    final json = jsonEncode(widgets.map((w) => w.toJson()).toList());
    await _preferences.setString(_storageKey, json);
  }

  /// Clear all widgets (for testing/debug)
  Future<void> clearAll() async {
    await _preferences.remove(_storageKey);
    await _preferences.remove(_installedKey);
    await _preferences.remove(_seededKey);
    _logger.i('Cleared all custom widgets');
  }

  /// Re-seed default widgets (for testing or resetting to defaults)
  Future<void> reseedDefaults() async {
    await _preferences.setBool(_seededKey, false);
    await _seedDefaultWidgets();
  }
}

/// Provider for widget templates
class WidgetTemplates {
  /// Battery status widget template
  static WidgetSchema batteryWidget() {
    return WidgetSchema(
      name: 'Battery Status',
      description: 'Display battery level with gauge',
      tags: ['battery', 'power', 'status'],
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
      tags: ['signal', 'snr', 'rssi', 'connectivity'],
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: [
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'signal_cellular_alt',
                iconSize: 20,
                style: const StyleSchema(textColor: '#4F6AF6'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(width: 8),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Signal',
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(
              mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
            ),
            children: [
              ElementSchema(
                type: ElementType.column,
                children: [
                  ElementSchema(
                    type: ElementType.text,
                    text: 'SNR',
                    style: const StyleSchema(
                      textColor: '#888888',
                      fontSize: 11,
                    ),
                  ),
                  ElementSchema(
                    type: ElementType.text,
                    binding: const BindingSchema(
                      path: 'node.snr',
                      format: '{value} dB',
                      defaultValue: '--',
                    ),
                    style: const StyleSchema(
                      textColor: '#FFFFFF',
                      fontSize: 18,
                      fontWeight: 'w600',
                    ),
                  ),
                ],
              ),
              ElementSchema(
                type: ElementType.column,
                children: [
                  ElementSchema(
                    type: ElementType.text,
                    text: 'RSSI',
                    style: const StyleSchema(
                      textColor: '#888888',
                      fontSize: 11,
                    ),
                  ),
                  ElementSchema(
                    type: ElementType.text,
                    binding: const BindingSchema(
                      path: 'node.rssi',
                      format: '{value} dBm',
                      defaultValue: '--',
                    ),
                    style: const StyleSchema(
                      textColor: '#FFFFFF',
                      fontSize: 18,
                      fontWeight: 'w600',
                    ),
                  ),
                ],
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
      description: 'Temperature and humidity display',
      tags: ['environment', 'temperature', 'humidity', 'sensors'],
      size: CustomWidgetSize.medium,
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 12),
        children: [
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'thermostat',
                iconSize: 20,
                style: const StyleSchema(textColor: '#F97316'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(width: 8),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'Environment',
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(
              mainAxisAlignment: MainAxisAlignmentOption.spaceAround,
            ),
            children: [
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
                      format: '{value}°C',
                      defaultValue: '--',
                    ),
                    style: const StyleSchema(
                      textColor: '#FFFFFF',
                      fontSize: 20,
                      fontWeight: 'w600',
                    ),
                  ),
                ],
              ),
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
                      textColor: '#FFFFFF',
                      fontSize: 20,
                      fontWeight: 'w600',
                    ),
                  ),
                ],
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
      tags: ['node', 'info', 'status'],
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: [
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
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(spacing: 16),
            children: [
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.role',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#888888', fontSize: 12),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.hardwareModel',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#888888', fontSize: 12),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.text,
            binding: const BindingSchema(
              path: 'node.lastHeard',
              defaultValue: 'Never',
            ),
            style: const StyleSchema(textColor: '#666666', fontSize: 11),
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
      tags: ['gps', 'position', 'location', 'coordinates'],
      root: ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 12, spacing: 8),
        children: [
          ElementSchema(
            type: ElementType.row,
            children: [
              ElementSchema(
                type: ElementType.icon,
                iconName: 'gps_fixed',
                iconSize: 20,
                style: const StyleSchema(textColor: '#22C55E'),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(width: 8),
              ),
              ElementSchema(
                type: ElementType.text,
                text: 'GPS',
                style: const StyleSchema(
                  textColor: '#FFFFFF',
                  fontSize: 14,
                  fontWeight: 'w600',
                ),
              ),
              ElementSchema(
                type: ElementType.spacer,
                style: const StyleSchema(expanded: true),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.satsInView',
                  format: '{value} sats',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#888888', fontSize: 12),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.row,
            style: const StyleSchema(spacing: 16),
            children: [
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.latitude',
                  format: 'Lat: {value}°',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#FFFFFF', fontSize: 13),
              ),
              ElementSchema(
                type: ElementType.text,
                binding: const BindingSchema(
                  path: 'node.longitude',
                  format: 'Lon: {value}°',
                  defaultValue: '--',
                ),
                style: const StyleSchema(textColor: '#FFFFFF', fontSize: 13),
              ),
            ],
          ),
          ElementSchema(
            type: ElementType.text,
            binding: const BindingSchema(
              path: 'node.altitude',
              format: 'Alt: {value}m',
              defaultValue: '--',
            ),
            style: const StyleSchema(textColor: '#888888', fontSize: 12),
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
    ];
  }

  /// Network overview widget template
  static WidgetSchema networkOverviewWidget() {
    return WidgetSchema(
      name: 'Network Overview',
      description: 'Mesh network status at a glance',
      tags: ['network', 'mesh', 'nodes', 'status'],
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
            style: const StyleSchema(
              height: 50,
              width: 1,
              backgroundColor: '#333333',
            ),
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
            style: const StyleSchema(
              height: 50,
              width: 1,
              backgroundColor: '#333333',
            ),
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
}
