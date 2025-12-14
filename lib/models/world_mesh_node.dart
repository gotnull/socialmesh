/// Node status based on last seen time
enum NodeStatus {
  online, // < 1 hour
  idle, // 1-24 hours
  offline, // > 24 hours or never seen
}

/// Model for nodes from mesh-observer's nodes.json API
/// Represents Meshtastic nodes from the global MQTT network
class WorldMeshNode {
  final int nodeNum;
  final String longName;
  final String shortName;
  final String hwModel;
  final String role;

  // Position
  final int latitude; // In 1e-7 degrees (divide by 10000000 for decimal)
  final int longitude; // In 1e-7 degrees
  final int? altitude;
  final int? precision;

  // MapReport
  final String? fwVersion;
  final String? region;
  final String? modemPreset;
  final bool hasDefaultCh;
  final int? onlineLocalNodes;
  final int? lastMapReport;

  // DeviceMetrics
  final int? batteryLevel;
  final double? voltage;
  final double? chUtil;
  final double? airUtilTx;
  final int? uptime;
  final int? lastDeviceMetrics;

  // EnvironmentMetrics
  final double? temperature;
  final double? relativeHumidity;
  final double? barometricPressure;
  final double? lux;
  final int? windDirection;
  final double? windSpeed;
  final double? windGust;
  final double? radiation;
  final double? rainfall1;
  final double? rainfall24;
  final int? lastEnvironmentMetrics;

  // Neighbors
  final Map<String, NeighborInfo>? neighbors;

  // SeenBy - MQTT topics where this node was seen
  final Map<String, int> seenBy;

  WorldMeshNode({
    required this.nodeNum,
    required this.longName,
    required this.shortName,
    required this.hwModel,
    required this.role,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.precision,
    this.fwVersion,
    this.region,
    this.modemPreset,
    this.hasDefaultCh = false,
    this.onlineLocalNodes,
    this.lastMapReport,
    this.batteryLevel,
    this.voltage,
    this.chUtil,
    this.airUtilTx,
    this.uptime,
    this.lastDeviceMetrics,
    this.temperature,
    this.relativeHumidity,
    this.barometricPressure,
    this.lux,
    this.windDirection,
    this.windSpeed,
    this.windGust,
    this.radiation,
    this.rainfall1,
    this.rainfall24,
    this.lastEnvironmentMetrics,
    this.neighbors,
    required this.seenBy,
  });

  /// Parse from mesh-observer JSON format
  factory WorldMeshNode.fromJson(int nodeNum, Map<String, dynamic> json) {
    return WorldMeshNode(
      nodeNum: nodeNum,
      longName: json['longName'] as String? ?? 'Unknown',
      shortName: json['shortName'] as String? ?? '????',
      hwModel: json['hwModel'] as String? ?? 'UNKNOWN',
      role: json['role'] as String? ?? 'UNKNOWN',
      latitude: json['latitude'] as int? ?? 0,
      longitude: json['longitude'] as int? ?? 0,
      altitude: json['altitude'] as int?,
      precision: json['precision'] as int?,
      fwVersion: json['fwVersion'] as String?,
      region: json['region'] as String?,
      modemPreset: json['modemPreset'] as String?,
      hasDefaultCh: json['hasDefaultCh'] as bool? ?? false,
      onlineLocalNodes: json['onlineLocalNodes'] as int?,
      lastMapReport: json['lastMapReport'] as int?,
      batteryLevel: json['batteryLevel'] as int?,
      voltage: (json['voltage'] as num?)?.toDouble(),
      chUtil: (json['chUtil'] as num?)?.toDouble(),
      airUtilTx: (json['airUtilTx'] as num?)?.toDouble(),
      uptime: json['uptime'] as int?,
      lastDeviceMetrics: json['lastDeviceMetrics'] as int?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      relativeHumidity: (json['relativeHumidity'] as num?)?.toDouble(),
      barometricPressure: (json['barometricPressure'] as num?)?.toDouble(),
      lux: (json['lux'] as num?)?.toDouble(),
      windDirection: json['windDirection'] as int?,
      windSpeed: (json['windSpeed'] as num?)?.toDouble(),
      windGust: (json['windGust'] as num?)?.toDouble(),
      radiation: (json['radiation'] as num?)?.toDouble(),
      rainfall1: (json['rainfall1'] as num?)?.toDouble(),
      rainfall24: (json['rainfall24'] as num?)?.toDouble(),
      lastEnvironmentMetrics: json['lastEnvironmentMetrics'] as int?,
      neighbors: _parseNeighbors(json['neighbors']),
      seenBy: _parseSeenBy(json['seenBy']),
    );
  }

  static Map<String, NeighborInfo>? _parseNeighbors(dynamic neighbors) {
    if (neighbors == null) return null;
    final map = neighbors as Map<String, dynamic>;
    return map.map(
      (key, value) =>
          MapEntry(key, NeighborInfo.fromJson(value as Map<String, dynamic>)),
    );
  }

  static Map<String, int> _parseSeenBy(dynamic seenBy) {
    if (seenBy == null) return {};
    final map = seenBy as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(key, value as int));
  }

  /// Get decimal latitude
  double get latitudeDecimal => latitude / 10000000.0;

  /// Get decimal longitude
  double get longitudeDecimal => longitude / 10000000.0;

  /// Get display name (long name preferred)
  String get displayName => longName.isNotEmpty ? longName : shortName;

  /// Get node ID in hex format
  String get nodeId => '!${nodeNum.toRadixString(16).padLeft(8, '0')}';

  /// Get last seen timestamp from seenBy map
  DateTime? get lastSeen {
    if (seenBy.isEmpty) return null;
    final maxTimestamp = seenBy.values.reduce((a, b) => a > b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(maxTimestamp * 1000);
  }

  /// Check if node was seen recently (within 24 hours)
  bool get isRecentlySeen {
    final seen = lastSeen;
    if (seen == null) return false;
    return DateTime.now().difference(seen).inHours < 24;
  }

  /// Check if node is online (seen within 1 hour)
  bool get isOnline {
    final seen = lastSeen;
    if (seen == null) return false;
    return DateTime.now().difference(seen).inMinutes < 60;
  }

  /// Check if node was seen recently but not online (1-24 hours)
  bool get isIdle {
    final seen = lastSeen;
    if (seen == null) return false;
    final diff = DateTime.now().difference(seen);
    return diff.inMinutes >= 60 && diff.inHours < 24;
  }

  /// Check if node is offline (>24 hours or never seen)
  bool get isOffline {
    final seen = lastSeen;
    if (seen == null) return true;
    return DateTime.now().difference(seen).inHours >= 24;
  }

  /// Get node status based on last seen time
  NodeStatus get status {
    if (isOnline) return NodeStatus.online;
    if (isIdle) return NodeStatus.idle;
    return NodeStatus.offline;
  }

  /// Get time since last seen as human readable string
  String get lastSeenString {
    final seen = lastSeen;
    if (seen == null) return 'Unknown';
    final diff = DateTime.now().difference(seen);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  /// Get battery status string
  String? get batteryString {
    if (batteryLevel == null) return null;
    if (batteryLevel! > 100) return 'Plugged in';
    return '$batteryLevel%';
  }

  /// Get formatted uptime string
  String? get uptimeString {
    if (uptime == null) return null;
    final d = uptime!;
    String s = '';
    if (d > 86400) {
      s += '${d ~/ 86400}d ';
    }
    final remaining = d % 86400;
    if (remaining > 3600) {
      s += '${remaining ~/ 3600}h ';
    }
    s += '${(remaining % 3600) ~/ 60}min';
    return s.trim();
  }

  /// Serialize to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'nodeNum': nodeNum,
      'longName': longName,
      'shortName': shortName,
      'hwModel': hwModel,
      'role': role,
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (precision != null) 'precision': precision,
      if (fwVersion != null) 'fwVersion': fwVersion,
      if (region != null) 'region': region,
      if (modemPreset != null) 'modemPreset': modemPreset,
      'hasDefaultCh': hasDefaultCh,
      if (onlineLocalNodes != null) 'onlineLocalNodes': onlineLocalNodes,
      if (lastMapReport != null) 'lastMapReport': lastMapReport,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (voltage != null) 'voltage': voltage,
      if (chUtil != null) 'chUtil': chUtil,
      if (airUtilTx != null) 'airUtilTx': airUtilTx,
      if (uptime != null) 'uptime': uptime,
      if (lastDeviceMetrics != null) 'lastDeviceMetrics': lastDeviceMetrics,
      if (temperature != null) 'temperature': temperature,
      if (relativeHumidity != null) 'relativeHumidity': relativeHumidity,
      if (barometricPressure != null) 'barometricPressure': barometricPressure,
      if (lux != null) 'lux': lux,
      if (windDirection != null) 'windDirection': windDirection,
      if (windSpeed != null) 'windSpeed': windSpeed,
      if (windGust != null) 'windGust': windGust,
      if (radiation != null) 'radiation': radiation,
      if (rainfall1 != null) 'rainfall1': rainfall1,
      if (rainfall24 != null) 'rainfall24': rainfall24,
      if (lastEnvironmentMetrics != null)
        'lastEnvironmentMetrics': lastEnvironmentMetrics,
      if (neighbors != null)
        'neighbors': neighbors!.map(
          (k, v) => MapEntry(k, {'snr': v.snr, 'updated': v.updated}),
        ),
      'seenBy': seenBy,
    };
  }

  /// Get position precision margin in meters (for privacy circle)
  int? get precisionMarginMeters {
    if (precision == null || precision! <= 0) return null;
    // Precision margins from Meshtastic protocol
    const margins = [
      11939464,
      5969732,
      2984866,
      1492433,
      746217,
      373108,
      186554,
      93277,
      46639,
      23319,
      11660,
      5830,
      2915,
      1457,
      729,
      364,
      182,
      91,
      46,
      23,
      11,
      6,
      3,
      1,
      1,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ];
    if (precision! > 0 && precision! <= margins.length) {
      final margin = margins[precision! - 1];
      return margin > 0 ? margin : null;
    }
    return null;
  }
}

/// Neighbor node info
class NeighborInfo {
  final double? snr;
  final int updated;

  NeighborInfo({this.snr, required this.updated});

  factory NeighborInfo.fromJson(Map<String, dynamic> json) {
    return NeighborInfo(
      snr: (json['snr'] as num?)?.toDouble(),
      updated: json['updated'] as int? ?? 0,
    );
  }
}
