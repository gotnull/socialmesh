// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../l10n/app_localizations.dart';
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

  /// The expected/typical max value for visual display.
  /// Use this for metrics where the actual value is typically much lower
  /// than maxValue (e.g., channel utilization is 0-100% but typically <20%).
  /// Gauges use this for better visual representation.
  final double? displayMax;
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
    this.displayMax,
    this.defaultFormat,
  });
}

/// Registry of all available data bindings
class BindingRegistry {
  static const List<BindingDefinition> bindings = [
    // Node Info
    BindingDefinition(
      path: 'node.longName',
      label: 'Node Name', // lint-allow: hardcoded-string
      description: 'Full name of the node', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.shortName',
      label: 'Short Name', // lint-allow: hardcoded-string
      description:
          'Short 4-character node identifier', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.nodeNum',
      label: 'Node Number', // lint-allow: hardcoded-string
      description: 'Unique node number', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.presenceConfidence',
      label: 'Presence Confidence', // lint-allow: hardcoded-string
      description:
          'Inferred presence: active, fading, stale, unknown', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.lastHeard',
      label: 'Last Heard', // lint-allow: hardcoded-string
      description:
          'When the node was last heard from', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: DateTime,
    ),
    BindingDefinition(
      path: 'node.role',
      label: 'Node Role', // lint-allow: hardcoded-string
      description:
          'Role in the mesh (CLIENT, ROUTER, etc.)', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.hardwareModel',
      label: 'Hardware Model', // lint-allow: hardcoded-string
      description: 'Device hardware model', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.firmwareVersion',
      label: 'Firmware Version', // lint-allow: hardcoded-string
      description: 'Current firmware version', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),

    // Signal & Connectivity
    BindingDefinition(
      path: 'node.snr',
      label: 'SNR',
      description: 'Signal-to-noise ratio', // lint-allow: hardcoded-string
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
      description: 'Signal-to-noise ratio', // lint-allow: hardcoded-string
      category: BindingCategory.device,
      valueType: int,
      unit: 'dB',
      minValue: -20,
      maxValue: 15,
      defaultFormat: '{value} dB',
    ),
    BindingDefinition(
      path: 'node.rssi',
      label: 'RSSI', // lint-allow: hardcoded-string
      description:
          'Received signal strength indicator', // lint-allow: hardcoded-string
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
      label: 'RSSI', // lint-allow: hardcoded-string
      description:
          'Received signal strength indicator', // lint-allow: hardcoded-string
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
      description: 'Distance to node in meters', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: double,
      unit: 'm',
      defaultFormat: '{value} m',
    ),

    // Power & Battery
    BindingDefinition(
      path: 'node.batteryLevel',
      label: 'Battery Level', // lint-allow: hardcoded-string
      description: 'Battery percentage (0-100)', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: int,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.voltage',
      label: 'Battery Voltage', // lint-allow: hardcoded-string
      description: 'Battery voltage', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'V',
      defaultFormat: '{value}V',
    ),
    BindingDefinition(
      path: 'node.channelUtilization',
      label: 'Channel Utilization', // lint-allow: hardcoded-string
      description:
          'Current channel utilization percentage', // lint-allow: hardcoded-string
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      displayMax: 25, // Typical range 0-25% for healthy networks
      defaultFormat: '{value}%',
    ),
    // Aliases for node.channelUtilization
    BindingDefinition(
      path: 'device.channelUtilization',
      label: 'Channel Utilization', // lint-allow: hardcoded-string
      description:
          'Current channel utilization percentage', // lint-allow: hardcoded-string
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      displayMax: 25, // Typical range 0-25% for healthy networks
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'device.channelUtil',
      label: 'Channel Util', // lint-allow: hardcoded-string
      description:
          'Current channel utilization percentage', // lint-allow: hardcoded-string
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      displayMax: 25, // Typical range 0-25% for healthy networks
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.airUtilTx',
      label: 'Airtime TX', // lint-allow: hardcoded-string
      description:
          'Transmission airtime utilization', // lint-allow: hardcoded-string
      category: BindingCategory.device,
      valueType: double,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      displayMax: 25, // Typical range 0-25% for healthy networks
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.uptimeSeconds',
      label: 'Uptime',
      description: 'Device uptime in seconds', // lint-allow: hardcoded-string
      category: BindingCategory.device,
      valueType: int,
      unit: 's',
    ),

    // Environment
    BindingDefinition(
      path: 'node.temperature',
      label: 'Temperature',
      description: 'Ambient temperature', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: '°C', // lint-allow: hardcoded-string
      defaultFormat: '{value}°C',
    ),
    BindingDefinition(
      path: 'node.humidity',
      label: 'Humidity', // lint-allow: hardcoded-string
      description:
          'Relative humidity percentage', // lint-allow: hardcoded-string
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
      description: 'Barometric pressure', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'hPa',
      defaultFormat: '{value} hPa',
    ),
    // Alias for node.barometricPressure (used by some marketplace widgets)
    BindingDefinition(
      path: 'node.pressure',
      label: 'Pressure',
      description: 'Barometric pressure', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'hPa',
      defaultFormat: '{value} hPa',
    ),
    BindingDefinition(
      path: 'node.lux',
      label: 'Light Level', // lint-allow: hardcoded-string
      description: 'Ambient light level', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'lux',
      defaultFormat: '{value} lux',
    ),
    BindingDefinition(
      path: 'node.iaq',
      label: 'IAQ Index', // lint-allow: hardcoded-string
      description: 'Indoor air quality index', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: int,
      minValue: 0,
      maxValue: 500,
    ),

    // Wind
    BindingDefinition(
      path: 'node.windSpeed',
      label: 'Wind Speed', // lint-allow: hardcoded-string
      description: 'Current wind speed', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'm/s',
      defaultFormat: '{value} m/s',
    ),
    BindingDefinition(
      path: 'node.windDirection',
      label: 'Wind Direction', // lint-allow: hardcoded-string
      description: 'Wind direction in degrees', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: int,
      unit: '°',
      minValue: 0,
      maxValue: 360,
      defaultFormat: '{value}°',
    ),
    BindingDefinition(
      path: 'node.windGust',
      label: 'Wind Gust', // lint-allow: hardcoded-string
      description: 'Wind gust speed', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'm/s',
      defaultFormat: '{value} m/s',
    ),

    // Rain
    BindingDefinition(
      path: 'node.rainfall1h',
      label: 'Rainfall (1h)', // lint-allow: hardcoded-string
      description: 'Rainfall in last hour', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'mm',
      defaultFormat: '{value} mm',
    ),
    BindingDefinition(
      path: 'node.rainfall24h',
      label: 'Rainfall (24h)', // lint-allow: hardcoded-string
      description: 'Rainfall in last 24 hours', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: 'mm',
      defaultFormat: '{value} mm',
    ),

    // Soil
    BindingDefinition(
      path: 'node.soilMoisture',
      label: 'Soil Moisture', // lint-allow: hardcoded-string
      description: 'Soil moisture percentage', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: int,
      unit: '%',
      minValue: 0,
      maxValue: 100,
      defaultFormat: '{value}%',
    ),
    BindingDefinition(
      path: 'node.soilTemperature',
      label: 'Soil Temperature', // lint-allow: hardcoded-string
      description: 'Soil temperature', // lint-allow: hardcoded-string
      category: BindingCategory.environment,
      valueType: double,
      unit: '°C', // lint-allow: hardcoded-string
      defaultFormat: '{value}°C',
    ),

    // Air Quality
    BindingDefinition(
      path: 'node.pm25Standard',
      label: 'PM2.5', // lint-allow: hardcoded-string
      description: 'PM2.5 particulate matter', // lint-allow: hardcoded-string
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'µg/m³', // lint-allow: hardcoded-string
      defaultFormat: '{value} µg/m³',
    ),
    BindingDefinition(
      path: 'node.pm10Standard',
      label: 'PM1.0', // lint-allow: hardcoded-string
      description: 'PM1.0 particulate matter', // lint-allow: hardcoded-string
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'µg/m³', // lint-allow: hardcoded-string
      defaultFormat: '{value} µg/m³',
    ),
    BindingDefinition(
      path: 'node.pm100Standard',
      label: 'PM10',
      description: 'PM10 particulate matter', // lint-allow: hardcoded-string
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'µg/m³', // lint-allow: hardcoded-string
      defaultFormat: '{value} µg/m³',
    ),
    BindingDefinition(
      path: 'node.co2',
      label: 'CO2',
      description: 'CO2 concentration', // lint-allow: hardcoded-string
      category: BindingCategory.airQuality,
      valueType: int,
      unit: 'ppm',
      defaultFormat: '{value} ppm',
    ),

    // GPS / Position
    BindingDefinition(
      path: 'node.latitude',
      label: 'Latitude',
      description: 'GPS latitude coordinate', // lint-allow: hardcoded-string
      category: BindingCategory.gps,
      valueType: double,
      defaultFormat: '{value}°',
    ),
    BindingDefinition(
      path: 'node.longitude',
      label: 'Longitude',
      description: 'GPS longitude coordinate', // lint-allow: hardcoded-string
      category: BindingCategory.gps,
      valueType: double,
      defaultFormat: '{value}°',
    ),
    BindingDefinition(
      path: 'node.altitude',
      label: 'Altitude',
      description: 'Altitude above sea level', // lint-allow: hardcoded-string
      category: BindingCategory.gps,
      valueType: int,
      unit: 'm',
      defaultFormat: '{value} m',
    ),
    BindingDefinition(
      path: 'node.satsInView',
      label: 'Satellites', // lint-allow: hardcoded-string
      description:
          'Number of GPS satellites in view', // lint-allow: hardcoded-string
      category: BindingCategory.gps,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.groundSpeed',
      label: 'Ground Speed', // lint-allow: hardcoded-string
      description: 'Ground speed', // lint-allow: hardcoded-string
      category: BindingCategory.gps,
      valueType: double,
      unit: 'm/s',
      defaultFormat: '{value} m/s',
    ),
    BindingDefinition(
      path: 'node.groundTrack',
      label: 'Heading', // lint-allow: hardcoded-string
      description:
          'Ground track/heading in degrees', // lint-allow: hardcoded-string
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
      label: 'Channel 1 Voltage', // lint-allow: hardcoded-string
      description: 'Power channel 1 voltage', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'V',
      defaultFormat: '{value}V',
    ),
    BindingDefinition(
      path: 'node.ch1Current',
      label: 'Channel 1 Current', // lint-allow: hardcoded-string
      description: 'Power channel 1 current', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'A',
      defaultFormat: '{value}A',
    ),

    // Network Stats
    BindingDefinition(
      path: 'node.numPacketsTx',
      label: 'Packets TX', // lint-allow: hardcoded-string
      description: 'Total packets transmitted', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.numPacketsRx',
      label: 'Packets RX', // lint-allow: hardcoded-string
      description: 'Total packets received', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.numTxDropped',
      label: 'Packets TX Dropped', // lint-allow: hardcoded-string
      description:
          'Packets dropped due to full TX queue', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.noiseFloor',
      label: 'Noise Floor', // lint-allow: hardcoded-string
      description:
          'Measured noise floor in dBm', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
      unit: 'dBm',
      defaultFormat: '{value} dBm',
    ),
    BindingDefinition(
      path: 'node.nodeStatus',
      label: 'Node Status', // lint-allow: hardcoded-string
      description:
          'Custom status message from the node', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),
    BindingDefinition(
      path: 'node.numOnlineNodes',
      label: 'Nodes Heard (2h)', // lint-allow: hardcoded-string
      description:
          'Meshtastic metric: nodes heard in the last 2 hours', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.numTotalNodes',
      label: 'Total Nodes', // lint-allow: hardcoded-string
      description:
          'Total number of known nodes', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),

    // Network-wide bindings (not node-specific)
    BindingDefinition(
      path: 'network.totalNodes',
      label: 'Total Mesh Nodes', // lint-allow: hardcoded-string
      description:
          'Total nodes in the mesh network', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'network.activeCount',
      label: 'Online Mesh Nodes', // lint-allow: hardcoded-string
      description: 'Nodes heard within 2 hours', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    // Back-compat alias for older widgets
    BindingDefinition(
      path: 'network.onlineNodes',
      label: 'Online Mesh Nodes (legacy)', // lint-allow: hardcoded-string
      description:
          'Alias for online node count (back-compat)', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),
    BindingDefinition(
      path: 'network.unreadMessages',
      label: 'Unread Messages', // lint-allow: hardcoded-string
      description: 'Number of unread messages', // lint-allow: hardcoded-string
      category: BindingCategory.messaging,
      valueType: int,
    ),
    BindingDefinition(
      path: 'messaging.recentCount',
      label: 'Recent Messages', // lint-allow: hardcoded-string
      description: 'Number of recent messages', // lint-allow: hardcoded-string
      category: BindingCategory.messaging,
      valueType: int,
    ),
    BindingDefinition(
      path: 'node.displayName',
      label: 'Display Name', // lint-allow: hardcoded-string
      description:
          'Node display name (long name or short name)', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: String,
    ),

    // RF Metadata
    BindingDefinition(
      path: 'node.hopCount',
      label: 'Hop Count', // lint-allow: hardcoded-string
      description:
          'Number of hops from this node (0 = direct neighbor)', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: int,
      minValue: 0,
      maxValue: 7,
    ),
    BindingDefinition(
      path: 'node.viaMqtt',
      label: 'Via MQTT', // lint-allow: hardcoded-string
      description:
          'Whether this node was last heard via MQTT transport', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: bool,
    ),
    BindingDefinition(
      path: 'node.firstHeard',
      label: 'First Heard', // lint-allow: hardcoded-string
      description:
          'When the node was first discovered', // lint-allow: hardcoded-string
      category: BindingCategory.node,
      valueType: DateTime,
    ),

    // Additional Network Stats
    BindingDefinition(
      path: 'node.numPacketsRxBad',
      label: 'Bad Packets RX', // lint-allow: hardcoded-string
      description: 'Bad packets received', // lint-allow: hardcoded-string
      category: BindingCategory.network,
      valueType: int,
    ),

    // Additional Power Channels
    BindingDefinition(
      path: 'node.ch2Voltage',
      label: 'Channel 2 Voltage', // lint-allow: hardcoded-string
      description: 'Power channel 2 voltage', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'V',
      defaultFormat: '{value}V',
    ),
    BindingDefinition(
      path: 'node.ch2Current',
      label: 'Channel 2 Current', // lint-allow: hardcoded-string
      description: 'Power channel 2 current', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'A',
      defaultFormat: '{value}A',
    ),
    BindingDefinition(
      path: 'node.ch3Voltage',
      label: 'Channel 3 Voltage', // lint-allow: hardcoded-string
      description: 'Power channel 3 voltage', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'V',
      defaultFormat: '{value}V',
    ),
    BindingDefinition(
      path: 'node.ch3Current',
      label: 'Channel 3 Current', // lint-allow: hardcoded-string
      description: 'Power channel 3 current', // lint-allow: hardcoded-string
      category: BindingCategory.power,
      valueType: double,
      unit: 'A',
      defaultFormat: '{value}A',
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
        return 'Node Info'; // lint-allow: hardcoded-string
      case BindingCategory.device:
        return 'Device Metrics'; // lint-allow: hardcoded-string
      case BindingCategory.network:
        return 'Network';
      case BindingCategory.environment:
        return 'Environment';
      case BindingCategory.power:
        return 'Power & Battery'; // lint-allow: hardcoded-string
      case BindingCategory.airQuality:
        return 'Air Quality'; // lint-allow: hardcoded-string
      case BindingCategory.gps:
        return 'GPS & Position'; // lint-allow: hardcoded-string
      case BindingCategory.messaging:
        return 'Messaging';
    }
  }

  /// Get localized label for a binding path.
  static String localizedLabel(String path, AppLocalizations l10n) {
    return switch (path) {
      'node.longName' => l10n.widgetBuilderBindingNodeName,
      'node.shortName' => l10n.widgetBuilderBindingShortName,
      'node.nodeNum' => l10n.widgetBuilderBindingNodeNumber,
      'node.presenceConfidence' => l10n.widgetBuilderBindingPresenceConfidence,
      'node.lastHeard' => l10n.widgetBuilderBindingLastHeard,
      'node.role' => l10n.widgetBuilderBindingNodeRole,
      'node.hardwareModel' => l10n.widgetBuilderBindingHardwareModel,
      'node.firmwareVersion' => l10n.widgetBuilderBindingFirmwareVersion,
      'node.snr' => l10n.widgetBuilderBindingSnr,
      'device.snr' => l10n.widgetBuilderBindingSnr,
      'node.rssi' => l10n.widgetBuilderBindingRssi,
      'device.rssi' => l10n.widgetBuilderBindingRssi,
      'node.distance' => l10n.widgetBuilderBindingDistance,
      'node.batteryLevel' => l10n.widgetBuilderBindingBatteryLevel,
      'node.voltage' => l10n.widgetBuilderBindingBatteryVoltage,
      'node.channelUtilization' => l10n.widgetBuilderBindingChannelUtil,
      'device.channelUtilization' => l10n.widgetBuilderBindingChannelUtil,
      'device.channelUtil' => l10n.widgetBuilderBindingChannelUtil,
      'node.airUtilTx' => l10n.widgetBuilderBindingAirtimeTx,
      'node.uptimeSeconds' => l10n.widgetBuilderBindingUptime,
      'node.temperature' => l10n.widgetBuilderBindingTemperature,
      'node.humidity' => l10n.widgetBuilderBindingHumidity,
      'node.barometricPressure' => l10n.widgetBuilderBindingPressure,
      'node.pressure' => l10n.widgetBuilderBindingPressure,
      'node.lux' => l10n.widgetBuilderBindingLightLevel,
      'node.iaq' => l10n.widgetBuilderBindingIaqIndex,
      'node.windSpeed' => l10n.widgetBuilderBindingWindSpeed,
      'node.windDirection' => l10n.widgetBuilderBindingWindDirection,
      'node.windGust' => l10n.widgetBuilderBindingWindGust,
      'node.rainfall1h' => l10n.widgetBuilderBindingRainfall1h,
      'node.rainfall24h' => l10n.widgetBuilderBindingRainfall24h,
      'node.soilMoisture' => l10n.widgetBuilderBindingSoilMoisture,
      'node.soilTemperature' => l10n.widgetBuilderBindingSoilTemperature,
      'node.pm25Standard' => l10n.widgetBuilderBindingPm25,
      'node.pm10Standard' => l10n.widgetBuilderBindingPm10Small,
      'node.pm100Standard' => l10n.widgetBuilderBindingPm10Large,
      'node.co2' => l10n.widgetBuilderBindingCo2,
      'node.latitude' => l10n.widgetBuilderBindingLatitude,
      'node.longitude' => l10n.widgetBuilderBindingLongitude,
      'node.altitude' => l10n.widgetBuilderBindingAltitude,
      'node.satsInView' => l10n.widgetBuilderBindingSatellites,
      'node.groundSpeed' => l10n.widgetBuilderBindingGroundSpeed,
      'node.groundTrack' => l10n.widgetBuilderBindingHeading,
      'node.ch1Voltage' => l10n.widgetBuilderBindingCh1Voltage,
      'node.ch1Current' => l10n.widgetBuilderBindingCh1Current,
      'node.numPacketsTx' => l10n.widgetBuilderBindingPacketsTx,
      'node.numPacketsRx' => l10n.widgetBuilderBindingPacketsRx,
      'node.numTxDropped' => l10n.widgetBuilderBindingPacketsTxDropped,
      'node.noiseFloor' => l10n.widgetBuilderBindingNoiseFloor,
      'node.nodeStatus' => l10n.widgetBuilderBindingNodeStatus,
      'node.numOnlineNodes' => l10n.widgetBuilderBindingNodesHeard2h,
      'node.numTotalNodes' => l10n.widgetBuilderBindingTotalNodes,
      'network.totalNodes' => l10n.widgetBuilderBindingTotalMeshNodes,
      'network.activeCount' => l10n.widgetBuilderBindingActiveMeshNodes,
      'network.onlineNodes' => l10n.widgetBuilderBindingActiveMeshNodesLegacy,
      'network.unreadMessages' => l10n.widgetBuilderBindingUnreadMessages,
      'messaging.recentCount' => l10n.widgetBuilderBindingRecentMessages,
      'node.displayName' => l10n.widgetBuilderBindingDisplayName,
      'node.hopCount' => l10n.widgetBuilderBindingHopCount,
      'node.viaMqtt' => l10n.widgetBuilderBindingViaMqtt,
      'node.firstHeard' => l10n.widgetBuilderBindingFirstHeard,
      'node.numPacketsRxBad' => l10n.widgetBuilderBindingBadPacketsRx,
      'node.ch2Voltage' => l10n.widgetBuilderBindingCh2Voltage,
      'node.ch2Current' => l10n.widgetBuilderBindingCh2Current,
      'node.ch3Voltage' => l10n.widgetBuilderBindingCh3Voltage,
      'node.ch3Current' => l10n.widgetBuilderBindingCh3Current,
      _ => getByPath(path)?.label ?? path,
    };
  }

  /// Get localized description for a binding path.
  static String localizedDescription(String path, AppLocalizations l10n) {
    return switch (path) {
      'node.longName' => l10n.widgetBuilderBindingNodeNameDesc,
      'node.shortName' => l10n.widgetBuilderBindingShortNameDesc,
      'node.nodeNum' => l10n.widgetBuilderBindingNodeNumberDesc,
      'node.presenceConfidence' =>
        l10n.widgetBuilderBindingPresenceConfidenceDesc,
      'node.lastHeard' => l10n.widgetBuilderBindingLastHeardDesc,
      'node.role' => l10n.widgetBuilderBindingNodeRoleDesc,
      'node.hardwareModel' => l10n.widgetBuilderBindingHardwareModelDesc,
      'node.firmwareVersion' => l10n.widgetBuilderBindingFirmwareVersionDesc,
      'node.snr' => l10n.widgetBuilderBindingSnrDesc,
      'device.snr' => l10n.widgetBuilderBindingSnrDesc,
      'node.rssi' => l10n.widgetBuilderBindingRssiDesc,
      'device.rssi' => l10n.widgetBuilderBindingRssiDesc,
      'node.distance' => l10n.widgetBuilderBindingDistanceDesc,
      'node.batteryLevel' => l10n.widgetBuilderBindingBatteryLevelDesc,
      'node.voltage' => l10n.widgetBuilderBindingBatteryVoltageDesc,
      'node.channelUtilization' => l10n.widgetBuilderBindingChannelUtilDesc,
      'device.channelUtilization' => l10n.widgetBuilderBindingChannelUtilDesc,
      'device.channelUtil' => l10n.widgetBuilderBindingChannelUtilDesc,
      'node.airUtilTx' => l10n.widgetBuilderBindingAirtimeTxDesc,
      'node.uptimeSeconds' => l10n.widgetBuilderBindingUptimeDesc,
      'node.temperature' => l10n.widgetBuilderBindingTemperatureDesc,
      'node.humidity' => l10n.widgetBuilderBindingHumidityDesc,
      'node.barometricPressure' => l10n.widgetBuilderBindingPressureDesc,
      'node.pressure' => l10n.widgetBuilderBindingPressureDesc,
      'node.lux' => l10n.widgetBuilderBindingLightLevelDesc,
      'node.iaq' => l10n.widgetBuilderBindingIaqIndexDesc,
      'node.windSpeed' => l10n.widgetBuilderBindingWindSpeedDesc,
      'node.windDirection' => l10n.widgetBuilderBindingWindDirectionDesc,
      'node.windGust' => l10n.widgetBuilderBindingWindGustDesc,
      'node.rainfall1h' => l10n.widgetBuilderBindingRainfall1hDesc,
      'node.rainfall24h' => l10n.widgetBuilderBindingRainfall24hDesc,
      'node.soilMoisture' => l10n.widgetBuilderBindingSoilMoistureDesc,
      'node.soilTemperature' => l10n.widgetBuilderBindingSoilTemperatureDesc,
      'node.pm25Standard' => l10n.widgetBuilderBindingPm25Desc,
      'node.pm10Standard' => l10n.widgetBuilderBindingPm10SmallDesc,
      'node.pm100Standard' => l10n.widgetBuilderBindingPm10LargeDesc,
      'node.co2' => l10n.widgetBuilderBindingCo2Desc,
      'node.latitude' => l10n.widgetBuilderBindingLatitudeDesc,
      'node.longitude' => l10n.widgetBuilderBindingLongitudeDesc,
      'node.altitude' => l10n.widgetBuilderBindingAltitudeDesc,
      'node.satsInView' => l10n.widgetBuilderBindingSatellitesDesc,
      'node.groundSpeed' => l10n.widgetBuilderBindingGroundSpeedDesc,
      'node.groundTrack' => l10n.widgetBuilderBindingHeadingDesc,
      'node.ch1Voltage' => l10n.widgetBuilderBindingCh1VoltageDesc,
      'node.ch1Current' => l10n.widgetBuilderBindingCh1CurrentDesc,
      'node.numPacketsTx' => l10n.widgetBuilderBindingPacketsTxDesc,
      'node.numPacketsRx' => l10n.widgetBuilderBindingPacketsRxDesc,
      'node.numTxDropped' => l10n.widgetBuilderBindingPacketsTxDroppedDesc,
      'node.noiseFloor' => l10n.widgetBuilderBindingNoiseFloorDesc,
      'node.nodeStatus' => l10n.widgetBuilderBindingNodeStatusDesc,
      'node.numOnlineNodes' => l10n.widgetBuilderBindingNodesHeard2hDesc,
      'node.numTotalNodes' => l10n.widgetBuilderBindingTotalNodesDesc,
      'network.totalNodes' => l10n.widgetBuilderBindingTotalMeshNodesDesc,
      'network.activeCount' => l10n.widgetBuilderBindingActiveMeshNodesDesc,
      'network.onlineNodes' =>
        l10n.widgetBuilderBindingActiveMeshNodesLegacyDesc,
      'network.unreadMessages' => l10n.widgetBuilderBindingUnreadMessagesDesc,
      'messaging.recentCount' => l10n.widgetBuilderBindingRecentMessagesDesc,
      'node.displayName' => l10n.widgetBuilderBindingDisplayNameDesc,
      'node.hopCount' => l10n.widgetBuilderBindingHopCountDesc,
      'node.viaMqtt' => l10n.widgetBuilderBindingViaMqttDesc,
      'node.firstHeard' => l10n.widgetBuilderBindingFirstHeardDesc,
      'node.numPacketsRxBad' => l10n.widgetBuilderBindingBadPacketsRxDesc,
      'node.ch2Voltage' => l10n.widgetBuilderBindingCh2VoltageDesc,
      'node.ch2Current' => l10n.widgetBuilderBindingCh2CurrentDesc,
      'node.ch3Voltage' => l10n.widgetBuilderBindingCh3VoltageDesc,
      'node.ch3Current' => l10n.widgetBuilderBindingCh3CurrentDesc,
      _ => getByPath(path)?.description ?? path,
    };
  }

  /// Get localized category name.
  static String localizedCategoryName(
    BindingCategory category,
    AppLocalizations l10n,
  ) {
    return switch (category) {
      BindingCategory.node => l10n.widgetBuilderBindingCategoryNodeInfo,
      BindingCategory.device => l10n.widgetBuilderBindingCategoryDevice,
      BindingCategory.network => l10n.widgetBuilderBindingCategoryNetwork,
      BindingCategory.environment =>
        l10n.widgetBuilderBindingCategoryEnvironment,
      BindingCategory.power => l10n.widgetBuilderBindingCategoryPower,
      BindingCategory.airQuality => l10n.widgetBuilderBindingCategoryAirQuality,
      BindingCategory.gps => l10n.widgetBuilderBindingCategoryGps,
      BindingCategory.messaging => l10n.widgetBuilderBindingCategoryMessages,
    };
  }
}

/// Data binding engine - resolves binding expressions to live data
class DataBindingEngine {
  /// Optional localizations for formatting
  AppLocalizations? _l10n;

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

  /// Set localizations for formatted output
  void setLocalizations(AppLocalizations l10n) {
    _l10n = l10n;
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
        return 'Node Name'; // lint-allow: hardcoded-string
      case 'node.shortName':
        return 'NODE';
      case 'node.displayName':
        return 'Node Name'; // lint-allow: hardcoded-string
      case 'node.nodeNum':
        return 12345678;
      case 'node.presenceConfidence':
        return 'active';
      case 'node.role':
        return 'CLIENT';
      case 'node.hardwareModel':
        return 'T-Beam'; // lint-allow: hardcoded-string
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

      // RF Metadata
      case 'node.hopCount':
        return 2;
      case 'node.viaMqtt':
        return false;
      case 'node.firstHeard':
        return DateTime.now().subtract(const Duration(days: 3));

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
      case 'node.numPacketsRxBad':
        return 3;

      default:
        return null;
    }
  }

  /// Resolve device-level fields (from protocol streams)
  ///
  /// These represent the BLE connection to the radio (RSSI, SNR) and
  /// radio-level telemetry (channel utilization). They are NOT the same
  /// as per-node LoRa signal metrics on [MeshNode] — do not fall back
  /// to node model fields here.
  dynamic _resolveDevicePath(String field) {
    switch (field) {
      case 'rssi':
        // BLE RSSI from protocol polling — phone↔radio signal strength.
        // Do NOT fall back to _currentNode?.rssi which is per-node LoRa
        // RSSI (a completely different measurement).
        return _deviceRssi;
      case 'snr':
        // SNR from last received mesh packet.
        // Do NOT fall back to _currentNode?.snr — the device-level SNR
        // stream is the authoritative source for the connected radio.
        return _deviceSnr;
      case 'channelUtil':
      case 'channelUtilization':
        // Channel utilization from device telemetry. Fall back to node
        // model value since both represent the same radio-reported metric.
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
        return PresenceCalculator.isOnline(node.lastHeard, now: DateTime.now());
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
        return node.snr;
      case 'rssi':
        return node.rssi;
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

      // RF Metadata
      case 'hopCount':
        return node.hopCount;
      case 'viaMqtt':
        return node.viaMqtt;
      case 'firstHeard':
        return node.firstHeard;

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
        final now = DateTime.now();
        return nodes.values
            .where((n) => PresenceCalculator.isOnline(n.lastHeard, now: now))
            .length;
      case 'onlineNodes': // Back-compat for older widgets
        final nodes = _allNodes;
        if (nodes == null) return 0;
        final nowLegacy = DateTime.now();
        return nodes.values
            .where(
              (n) => PresenceCalculator.isOnline(n.lastHeard, now: nowLegacy),
            )
            .length;
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
      if (_l10n != null) {
        return value ? _l10n!.widgetBuilderBoolYes : _l10n!.widgetBuilderBoolNo;
      }
      return value ? 'Yes' : 'No';
    }
    return value.toString();
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return _l10n?.widgetBuilderMarketplaceJustNow ??
          'Just now'; // lint-allow: hardcoded-string
    } else if (diff.inMinutes < 60) {
      return _l10n?.widgetBuilderMarketplaceMinutesAgo(diff.inMinutes) ??
          '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return _l10n?.widgetBuilderMarketplaceHoursAgo(diff.inHours) ??
          '${diff.inHours}h ago';
    } else {
      return _l10n?.widgetBuilderMarketplaceDaysAgo(diff.inDays) ??
          '${diff.inDays}d ago';
    }
  }
}
