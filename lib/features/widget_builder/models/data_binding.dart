import '../../../models/mesh_models.dart';
import '../../../models/presence_confidence.dart';
import '../models/widget_schema.dart';

/// Available data binding categories
enum BindingCategory {
  node, // Node-specific data
  device, // Connected device data
  network, // Network-wide statistics
  environment, // Environment sensors
  power, // Power/battery metrics
  airQuality, // Air quality sensors
  gps, // GPS/position data
  messaging, // Message statistics
}

/// Definition of a bindable data field
class BindingDefinition {
  final String path;
  final String label;
  final String description;
  final BindingCategory category;
  final Type valueType;
  final String? unit;
  final double? minValue;
  final double? maxValue;
  final String? defaultFormat;

  const BindingDefinition({
    required this.path,
    required this.label,
    required this.description,
    required this.category,
    required this.valueType,
    this.unit,
    this.minValue,
    this.maxValue,
    this.defaultFormat,
  });
}

/// Registry of all available data bindings
class BindingRegistry {
  static const List<BindingDefinition> bindings = [
    // Node Info
    BindingDefinition(
      path: 'node.longName',
      label: 'Node Name',
      description: 'Full name of the node',
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.shortName',
      label: 'Short Name',
      description: 'Short 4-character node identifier',
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.nodeNum',
      label: 'Node Number',
      description: 'Unique node number',
      category: BindingCategory.node,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.presenceConfidence',
      label: 'Presence Confidence',
      description: 'Inferred presence: active, fading, stale, unknown',
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.lastHeard',
      label: 'Last Heard',
      description: 'When the node was last heard from',
      category: BindingCategory.node,
      valueType: DateTime,
    ),
    BindingDefinition(
      path: 'node.role',
      label: 'Node Role',
      description: 'Role in the mesh (CLIENT, ROUTER, etc.)',
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.hardwareModel',
      label: 'Hardware Model',
      description: 'Device hardware model',
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.firmwareVersion',
      label: 'Firmware Version',
      description: 'Current firmware version',
      category: BindingCategory.node,
      valueType: String,
    ),

    // Signal & Connectivity
    BindingDefinition(
      path: 'node.snr',
      label: 'SNR',
      description: 'Signal-to-noise ratio',
      category: BindingCategory.node,
      valueType: int,
      unit: 'dB',
      minValue: -20,
      maxValue: 15,
      defaultFormat: '{value} dB',
    ),
    // Alias for node.snr (used by some marketplace widgets)
    BindingDefinition(
      path: 'device.snr',
      label: 'SNR',
      description: 'Signal-to-noise ratio',
      category: BindingCategory.device,
      valueType: int,
      unit: 'dB',
      minValue: -20,
      maxValue: 15,
      defaultFormat: '{value} dB',
    ),
    BindingDefinition(
      path: 'node.rssi',
      label: 'RSSI',
      description: 'Received signal strength indicator',
      category: BindingCategory.node,
      valueType: int,
      unit: 'dBm',
      minValue: -120,
      maxValue: 0,
      defaultFormat: '{value} dBm',
    ),
    // Alias for node.rssi (used by some marketplace widgets)
    BindingDefinition(
      path: 'device.rssi',
      label: 'RSSI',
      description: 'Received signal strength indicator',
      category: BindingCategory.device,
      valueType: int,
      unit: 'dBm',
      minValue: -120,
      maxValue: 0,
      defaultFormat: '{value} dBm',
    ),
    BindingDefinition(
      path: 'node.distance',
      label: 'Distance',
      description: 'Distance to node in meters',
      category: BindingCategory.node,
      valueType: double,
      unit: 'm',
      defaultFormat: '{value} m',
    ),

    // Power & Battery
    BindingDefinition(
      path: 'node.batteryLevel',
      label: 'Battery Level',
      description: 'Battery percentage (0-100)',
      category: BindingCategory.power,
      valueType: int,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.voltage',
      label: 'Battery Voltage',
      description: 'Battery voltage',
      category: BindingCategory.power,
      valueType: double,
      unit: 'V',
      defaultFormat: '{value}V',
    ),
    BindingDefinition(
      path: 'node.channelUtilization',
      label: 'Channel Utilization',
      description: 'Current channel utilization percentage',
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    // Aliases for node.channelUtilization
    BindingDefinition(
      path: 'device.channelUtilization',
      label: 'Channel Utilization',
      description: 'Current channel utilization percentage',
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'device.channelUtil',
      label: 'Channel Util',
      description: 'Current channel utilization percentage',
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.airUtilTx',
      label: 'Airtime TX',
      description: 'Transmission airtime utilization',
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.uptimeSeconds',
      label: 'Uptime',
      description: 'Device uptime in seconds',
      category: BindingCategory.device,
      valueType: int,
      unit: 's',
    ),

    // Environment
    BindingDefinition(
      path: 'node.temperature',
      label: 'Temperature',
      description: 'Ambient temperature',
      category: BindingCategory.environment,
      valueType: double,
      unit: '°C',
      defaultFormat: '{value}°C',
    ),
    BindingDefinition(
      path: 'node.humidity',
      label: 'Humidity',
      description: 'Relative humidity percentage',
      category: BindingCategory.environment,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.barometricPressure',
      label: 'Pressure',
      description: 'Barometric pressure',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'hPa',
      defaultFormat: '{value} hPa',
    ),
    // Alias for node.barometricPressure (used by some marketplace widgets)
    BindingDefinition(
      path: 'node.pressure',
      label: 'Pressure',
      description: 'Barometric pressure',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'hPa',
      defaultFormat: '{value} hPa',
    ),
    BindingDefinition(
      path: 'node.lux',
      label: 'Light Level',
      description: 'Ambient light level',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'lux',
      defaultFormat: '{value} lux',
    ),
    BindingDefinition(
      path: 'node.iaq',
      label: 'IAQ Index',
      description: 'Indoor air quality index',
      category: BindingCategory.environment,
      valueType: int,
      minValue: 0,
      maxValue: 500,
    ),

    // Wind
    BindingDefinition(
      path: 'node.windSpeed',
      label: 'Wind Speed',
      description: 'Current wind speed',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'm/s',
      defaultFormat: '{value} m/s',
    ),
    BindingDefinition(
      path: 'node.windDirection',
      label: 'Wind Direction',
      description: 'Wind direction in degrees',
      category: BindingCategory.environment,
      valueType: int,
      unit: '°',
      minValue: 0,
      maxValue: 360,
      defaultFormat: '{value}°',
    ),
    BindingDefinition(
      path: 'node.windGust',
      label: 'Wind Gust',
      description: 'Wind gust speed',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'm/s',
      defaultFormat: '{value} m/s',
    ),

    // Rain
    BindingDefinition(
      path: 'node.rainfall1h',
      label: 'Rainfall (1h)',
      description: 'Rainfall in last hour',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'mm',
      defaultFormat: '{value} mm',
    ),
    BindingDefinition(
      path: 'node.rainfall24h',
      label: 'Rainfall (24h)',
      description: 'Rainfall in last 24 hours',
      category: BindingCategory.environment,
      valueType: double,
      unit: 'mm',
      defaultFormat: '{value} mm',
    ),

    // Soil
    BindingDefinition(
      path: 'node.soilMoisture',
      label: 'Soil Moisture',
      description: 'Soil moisture percentage',
      category: BindingCategory.environment,
      valueType: int,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.soilTemperature',
      label: 'Soil Temperature',
      description: 'Soil temperature',
      category: BindingCategory.environment,
      valueType: double,
      unit: '°C',
      defaultFormat: '{value}°C',
    ),

    // Air Quality
    BindingDefinition(
      path: 'node.pm25Standard',
      label: 'PM2.5',
      description: 'PM2.5 particulate matter',
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'µg/m³',
      defaultFormat: '{value} µg/m³',
    ),
    BindingDefinition(
      path: 'node.pm10Standard',
      label: 'PM1.0',
      description: 'PM1.0 particulate matter',
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'µg/m³',
      defaultFormat: '{value} µg/m³',
    ),
    BindingDefinition(
      path: 'node.pm100Standard',
      label: 'PM10',
      description: 'PM10 particulate matter',
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'µg/m³',
      defaultFormat: '{value} µg/m³',
    ),
    BindingDefinition(
      path: 'node.co2',
      label: 'CO2',
      description: 'CO2 concentration',
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'ppm',
      defaultFormat: '{value} ppm',
    ),

    // GPS / Position
    BindingDefinition(
      path: 'node.latitude',
      label: 'Latitude',
      description: 'GPS latitude coordinate',
      category: BindingCategory.gps,
      valueType: double,
      defaultFormat: '{value}°',
    ),
    BindingDefinition(
      path: 'node.longitude',
      label: 'Longitude',
      description: 'GPS longitude coordinate',
      category: BindingCategory.gps,
      valueType: double,
      defaultFormat: '{value}°',
    ),
    BindingDefinition(
      path: 'node.altitude',
      label: 'Altitude',
      description: 'Altitude above sea level',
      category: BindingCategory.gps,
      valueType: int,
      unit: 'm',
      defaultFormat: '{value} m',
    ),
    BindingDefinition(
      path: 'node.satsInView',
      label: 'Satellites',
      description: 'Number of GPS satellites in view',
      category: BindingCategory.gps,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.groundSpeed',
      label: 'Ground Speed',
      description: 'Ground speed',
      category: BindingCategory.gps,
      valueType: double,
      unit: 'm/s',
      defaultFormat: '{value} m/s',
    ),
    BindingDefinition(
      path: 'node.groundTrack',
      label: 'Heading',
      description: 'Ground track/heading in degrees',
      category: BindingCategory.gps,
      valueType: double,
      unit: '°',
      minValue: 0,
      maxValue: 360,
      defaultFormat: '{value}°',
    ),

    // Power Channels
    BindingDefinition(
      path: 'node.ch1Voltage',
      label: 'Channel 1 Voltage',
      description: 'Power channel 1 voltage',
      category: BindingCategory.power,
      valueType: double,
      unit: 'V',
      defaultFormat: '{value}V',
    ),
    BindingDefinition(
      path: 'node.ch1Current',
      label: 'Channel 1 Current',
      description: 'Power channel 1 current',
      category: BindingCategory.power,
      valueType: double,
      unit: 'A',
      defaultFormat: '{value}A',
    ),

    // Network Stats
    BindingDefinition(
      path: 'node.numPacketsTx',
      label: 'Packets TX',
      description: 'Total packets transmitted',
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.numPacketsRx',
      label: 'Packets RX',
      description: 'Total packets received',
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.numTxDropped',
      label: 'Packets TX Dropped',
      description: 'Packets dropped due to full TX queue',
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.noiseFloor',
      label: 'Noise Floor',
      description: 'Measured noise floor in dBm',
      category: BindingCategory.network,
      valueType: int,
      unit: 'dBm',
      defaultFormat: '{value} dBm',
    ),
    BindingDefinition(
      path: 'node.nodeStatus',
      label: 'Node Status',
      description: 'Custom status message from the node',
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.numOnlineNodes',
      label: 'Nodes Heard (2h)',
      description: 'Meshtastic metric: nodes heard in the last 2 hours',
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.numTotalNodes',
      label: 'Total Nodes',
      description: 'Total number of known nodes',
      category: BindingCategory.network,
      valueType: int,
    ),

    // Network-wide bindings (not node-specific)
    BindingDefinition(
      path: 'network.totalNodes',
      label: 'Total Mesh Nodes',
      description: 'Total nodes in the mesh network',
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'network.activeCount',
      label: 'Active Mesh Nodes',
      description: 'Nodes heard recently',
      category: BindingCategory.network,
      valueType: int,
    ),
    // Back-compat alias for older widgets
    BindingDefinition(
      path: 'network.onlineNodes',
      label: 'Active Mesh Nodes (legacy)',
      description: 'Alias for active node count (back-compat)',
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'network.unreadMessages',
      label: 'Unread Messages',
      description: 'Number of unread messages',
      category: BindingCategory.messaging,
      valueType: int,
    ),
    BindingDefinition(
      path: 'messaging.recentCount',
      label: 'Recent Messages',
      description: 'Number of recent messages',
      category: BindingCategory.messaging,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.displayName',
      label: 'Display Name',
      description: 'Node display name (long name or short name)',
      category: BindingCategory.node,
      valueType: String,
    ),
  ];

  /// Get bindings filtered by category
  static List<BindingDefinition> getByCategory(BindingCategory category) {
    return bindings.where((b) => b.category == category).toList();
  }

  /// Get binding definition by path
  static BindingDefinition? getByPath(String path) {
    try {
      return bindings.firstWhere((b) => b.path == path);
    } catch (_) {
      return null;
    }
  }

  /// Get all unique categories
  static List<BindingCategory> get categories => BindingCategory.values;

  /// Get human-readable category name
  static String getCategoryName(BindingCategory category) {
    switch (category) {
      case BindingCategory.node:
        return 'Node Info';
      case BindingCategory.device:
        return 'Device Metrics';
      case BindingCategory.network:
        return 'Network';
      case BindingCategory.environment:
        return 'Environment';
      case BindingCategory.power:
        return 'Power & Battery';
      case BindingCategory.airQuality:
        return 'Air Quality';
      case BindingCategory.gps:
        return 'GPS & Position';
      case BindingCategory.messaging:
        return 'Messaging';
    }
  }
}

/// Data binding engine - resolves binding expressions to live data
class DataBindingEngine {
  /// Current context data
  MeshNode? _currentNode;
  Map<int, MeshNode>? _allNodes;
  List<Message>? _messages;

  /// Device-level data (from protocol streams, not node data)
  int? _deviceRssi;
  double? _deviceSnr;
  double? _deviceChannelUtil;

  /// Whether to use placeholder data instead of live data
  bool _usePlaceholderData = false;

  /// Enable placeholder data mode for previews
  void setUsePlaceholderData(bool value) {
    _usePlaceholderData = value;
  }

  /// Update context with current node data
  void setCurrentNode(MeshNode? node) {
    _currentNode = node;
  }

  /// Update context with all nodes
  void setAllNodes(Map<int, MeshNode>? nodes) {
    _allNodes = nodes;
  }

  /// Update context with messages
  void setMessages(List<Message>? messages) {
    _messages = messages;
  }

  /// Update context with device-level signal data (from protocol streams)
  void setDeviceSignal({int? rssi, double? snr, double? channelUtil}) {
    _deviceRssi = rssi;
    _deviceSnr = snr;
    _deviceChannelUtil = channelUtil;
  }

  /// Resolve a binding to its current value
  dynamic resolveBinding(BindingSchema binding) {
    final rawValue = _resolvePath(binding.path);
    final transformedValue = _applyTransform(rawValue, binding.transform);
    return transformedValue;
  }

  /// Format a resolved value using the binding's format string
  String formatValue(BindingSchema binding, dynamic value) {
    if (value == null) {
      return binding.defaultValue ?? '--';
    }

    final format = binding.format ?? '{value}';
    String result = format.replaceAll('{value}', _valueToString(value));

    return result;
  }

  /// Resolve binding and return formatted string
  String resolveAndFormat(BindingSchema binding) {
    final value = resolveBinding(binding);
    return formatValue(binding, value);
  }

  /// Evaluate a conditional expression
  bool evaluateCondition(ConditionalSchema condition) {
    final value = _resolvePath(condition.bindingPath);

    switch (condition.operator) {
      case ConditionalOperator.equals:
        return value == condition.value;
      case ConditionalOperator.notEquals:
        return value != condition.value;
      case ConditionalOperator.greaterThan:
        return value is num &&
            condition.value is num &&
            value > condition.value;
      case ConditionalOperator.lessThan:
        return value is num &&
            condition.value is num &&
            value < condition.value;
      case ConditionalOperator.greaterOrEqual:
        return value is num &&
            condition.value is num &&
            value >= condition.value;
      case ConditionalOperator.lessOrEqual:
        return value is num &&
            condition.value is num &&
            value <= condition.value;
      case ConditionalOperator.isNull:
        return value == null;
      case ConditionalOperator.isNotNull:
        return value != null;
      case ConditionalOperator.contains:
        if (value is String && condition.value is String) {
          return value.contains(condition.value);
        }
        return false;
      case ConditionalOperator.isEmpty:
        if (value == null) return true;
        if (value is String) return value.isEmpty;
        if (value is List) return value.isEmpty;
        return false;
      case ConditionalOperator.isNotEmpty:
        if (value == null) return false;
        if (value is String) return value.isNotEmpty;
        if (value is List) return value.isNotEmpty;
        return true;
    }
  }

  /// Internal: resolve a binding path to a value
  dynamic _resolvePath(String path) {
    // If placeholder mode is enabled, return sample data
    if (_usePlaceholderData) {
      return _getPlaceholderValue(path);
    }

    final parts = path.split('.');
    if (parts.isEmpty) return null;

    final root = parts[0];
    final fieldPath = parts.length > 1 ? parts.sublist(1).join('.') : '';

    switch (root) {
      case 'node':
        return _resolveNodePath(_currentNode, fieldPath);
      case 'network':
        return _resolveNetworkPath(fieldPath);
      case 'messages':
        return _resolveMessagesPath(fieldPath);
      case 'device':
        return _resolveDevicePath(fieldPath);
      default:
        return null;
    }
  }

  /// Get placeholder values for preview mode
  dynamic _getPlaceholderValue(String path) {
    switch (path) {
      // Node info
      case 'node.longName':
        return 'Node Name';
      case 'node.shortName':
        return 'NODE';
      case 'node.displayName':
        return 'Node Name';
      case 'node.nodeNum':
        return 12345678;
      case 'node.presenceConfidence':
        return 'active';
      case 'node.role':
        return 'CLIENT';
      case 'node.hardwareModel':
        return 'T-Beam';
      case 'node.firmwareVersion':
        return '2.3.0';

      // Power
      case 'node.batteryLevel':
        return 75;
      case 'node.voltage':
        return 3.85;
      case 'node.isCharging':
        return false;
      case 'node.ch1Voltage':
        return 12.6;
      case 'node.ch1Current':
        return 0.85;
      case 'node.ch2Voltage':
        return 5.1;
      case 'node.ch2Current':
        return 0.42;
      case 'node.ch3Voltage':
        return 3.3;
      case 'node.ch3Current':
        return 0.15;

      // Signal
      case 'node.snr':
      case 'device.snr':
        return 8.5;
      case 'node.rssi':
      case 'device.rssi':
        return -85;
      case 'device.channelUtil':
      case 'device.channelUtilization':
        return 15.0;

      // Environment
      case 'node.temperature':
        return 22.5;
      case 'node.humidity':
        return 45.0;
      case 'node.pressure':
      case 'node.barometricPressure':
        return 1013.25;
      case 'node.lightLevel':
      case 'node.lux':
        return 500;
      case 'node.iaq':
      case 'node.iaqIndex':
        return 75;
      case 'node.windSpeed':
        return 12.5;
      case 'node.windDirection':
        return 225;
      case 'node.windGust':
        return 18.0;
      case 'node.rainfall1h':
        return 2.5;
      case 'node.rainfall24h':
        return 15.0;
      case 'node.soilMoisture':
        return 35;
      case 'node.soilTemperature':
        return 18.5;
      case 'node.pm25':
      case 'node.pm2_5':
        return 12.0;
      case 'node.pm10':
        return 25.0;
      case 'node.pm1_0':
        return 8.0;
      case 'node.co2':
        return 420;

      // GPS
      case 'node.latitude':
        return -33.8688;
      case 'node.longitude':
        return 151.2093;
      case 'node.altitude':
        return 58.0;
      case 'node.speed':
        return 0.0;
      case 'node.heading':
        return 180;
      case 'node.distance':
        return 1250.0;

      // Network
      case 'network.nodeCount':
      case 'network.totalNodes':
        return 5;
      case 'network.activeCount':
        return 3;

      // Messages
      case 'messages.count':
      case 'messages.totalCount':
        return 42;
      case 'messages.sentCount':
        return 18;
      case 'messages.receivedCount':
        return 24;
      case 'messaging.recentCount':
        return 0;

      default:
        return null;
    }
  }

  /// Resolve device-level fields (from protocol streams)
  dynamic _resolveDevicePath(String field) {
    switch (field) {
      case 'rssi':
        // Prefer real-time device data, fall back to node data
        return _deviceRssi ?? _currentNode?.rssi;
      case 'snr':
        // Prefer real-time device data, fall back to node data
        return _deviceSnr ?? _currentNode?.snr;
      case 'channelUtil':
      case 'channelUtilization':
        // Prefer real-time device data, fall back to node data
        return _deviceChannelUtil ?? _currentNode?.channelUtilization;
      default:
        return null;
    }
  }

  /// Resolve messages-related fields
  dynamic _resolveMessagesPath(String field) {
    final messages = _messages;
    if (messages == null) return null;

    switch (field) {
      case 'count':
      case 'totalCount':
        return messages.length;
      case 'sentCount':
        return messages.where((m) => m.sent).length;
      case 'receivedCount':
        return messages.where((m) => m.received).length;
      case 'pendingCount':
        return messages.where((m) => m.isPending).length;
      default:
        return null;
    }
  }

  /// Resolve node-specific fields
  dynamic _resolveNodePath(MeshNode? node, String field) {
    if (node == null) return null;

    switch (field) {
      // Basic info
      case 'longName':
        return node.longName;
      case 'shortName':
        return node.shortName;
      case 'nodeNum':
        return node.nodeNum;
      case 'userId':
        return node.userId;
      case 'presenceConfidence':
        return node.presenceConfidence.name;
      case 'isOnline': // Back-compat for older widgets
        return node.presenceConfidence.isActive;
      case 'isFavorite':
        return node.isFavorite;
      case 'lastHeard':
        return node.lastHeard;
      case 'role':
        return node.role;
      case 'hardwareModel':
        return node.hardwareModel;
      case 'firmwareVersion':
        return node.firmwareVersion;
      case 'displayName':
        return node.displayName;

      // Signal - prefer real-time device data when available
      case 'snr':
        return _deviceSnr ?? node.snr;
      case 'rssi':
        return _deviceRssi ?? node.rssi;
      case 'distance':
        return node.distance;

      // Power
      case 'batteryLevel':
        return node.batteryLevel;
      case 'voltage':
        return node.voltage;
      case 'channelUtilization':
      case 'channelUtil': // Alias
        // Prefer real-time device data when available
        return _deviceChannelUtil ?? node.channelUtilization;
      case 'airUtilTx':
        return node.airUtilTx;
      case 'uptimeSeconds':
        return node.uptimeSeconds;

      // Environment
      case 'temperature':
        return node.temperature;
      case 'humidity':
        return node.humidity;
      case 'barometricPressure':
      case 'pressure': // Alias
        return node.barometricPressure;
      case 'lux':
        return node.lux;
      case 'iaq':
        return node.iaq;
      case 'windSpeed':
        return node.windSpeed;
      case 'windDirection':
        return node.windDirection;
      case 'windGust':
        return node.windGust;
      case 'windLull':
        return node.windLull;
      case 'rainfall1h':
        return node.rainfall1h;
      case 'rainfall24h':
        return node.rainfall24h;
      case 'soilMoisture':
        return node.soilMoisture;
      case 'soilTemperature':
        return node.soilTemperature;

      // Air Quality
      case 'pm10Standard':
        return node.pm10Standard;
      case 'pm25Standard':
        return node.pm25Standard;
      case 'pm100Standard':
        return node.pm100Standard;
      case 'co2':
        return node.co2;

      // GPS
      case 'latitude':
        return node.latitude;
      case 'longitude':
        return node.longitude;
      case 'altitude':
        return node.altitude;
      case 'satsInView':
        return node.satsInView;
      case 'groundSpeed':
        return node.groundSpeed;
      case 'groundTrack':
        return node.groundTrack;
      case 'hasPosition':
        return node.hasPosition;

      // Power channels
      case 'ch1Voltage':
        return node.ch1Voltage;
      case 'ch1Current':
        return node.ch1Current;
      case 'ch2Voltage':
        return node.ch2Voltage;
      case 'ch2Current':
        return node.ch2Current;
      case 'ch3Voltage':
        return node.ch3Voltage;
      case 'ch3Current':
        return node.ch3Current;

      // Stats
      case 'numPacketsTx':
        return node.numPacketsTx;
      case 'numPacketsRx':
        return node.numPacketsRx;
      case 'numPacketsRxBad':
        return node.numPacketsRxBad;
      case 'numOnlineNodes':
        return node.numOnlineNodes;
      case 'numTotalNodes':
        return node.numTotalNodes;
      case 'numTxDropped':
        return node.numTxDropped;
      case 'noiseFloor':
        return node.noiseFloor;
      case 'nodeStatus':
        return node.nodeStatus;

      default:
        return null;
    }
  }

  /// Resolve network-wide fields
  dynamic _resolveNetworkPath(String field) {
    switch (field) {
      case 'totalNodes':
        return _allNodes?.length ?? 0;
      case 'activeCount':
        final nodes = _allNodes;
        if (nodes == null) return 0;
        return nodes.values.where((n) => n.presenceConfidence.isActive).length;
      case 'onlineNodes': // Back-compat for older widgets
        final nodes = _allNodes;
        if (nodes == null) return 0;
        return nodes.values.where((n) => n.presenceConfidence.isActive).length;
      case 'unreadMessages':
        // This would need to be tracked elsewhere
        return 0;
      default:
        return null;
    }
  }

  /// Apply transformation to a value
  dynamic _applyTransform(dynamic value, String? transform) {
    if (value == null || transform == null) return value;

    switch (transform) {
      case 'round':
        if (value is double) return value.round();
        return value;
      case 'floor':
        if (value is double) return value.floor();
        return value;
      case 'ceil':
        if (value is double) return value.ceil();
        return value;
      case 'uppercase':
        if (value is String) return value.toUpperCase();
        return value;
      case 'lowercase':
        if (value is String) return value.toLowerCase();
        return value;
      case 'abs':
        if (value is num) return value.abs();
        return value;
      default:
        return value;
    }
  }

  /// Convert value to display string
  String _valueToString(dynamic value) {
    if (value == null) return '--';
    if (value is DateTime) {
      return _formatDateTime(value);
    }
    if (value is double) {
      // Format doubles to reasonable precision
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(1);
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    return value.toString();
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
