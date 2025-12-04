import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/mesh_models.dart';

/// IFTTT trigger types
enum IftttTriggerType {
  messageReceived,
  nodeOnline,
  nodeOffline,
  positionUpdate,
  batteryLow,
  temperatureAlert,
  sosEmergency,
}

/// IFTTT configuration model
class IftttConfig {
  final bool enabled;
  final String webhookKey;
  final bool messageReceived;
  final bool nodeOnline;
  final bool nodeOffline;
  final bool positionUpdate;
  final bool batteryLow;
  final bool temperatureAlert;
  final bool sosEmergency;
  final int batteryThreshold;
  final double temperatureThreshold;
  final double geofenceRadius; // in meters
  final double? geofenceLat;
  final double? geofenceLon;
  final int? geofenceNodeNum; // Node to monitor for geofencing
  final String? geofenceNodeName; // Display name of monitored node
  final int geofenceThrottleMinutes; // Minimum minutes between geofence alerts

  const IftttConfig({
    this.enabled = false,
    this.webhookKey = '',
    this.messageReceived = true,
    this.nodeOnline = true,
    this.nodeOffline = true,
    this.positionUpdate = false,
    this.batteryLow = true,
    this.temperatureAlert = false,
    this.sosEmergency = true,
    this.batteryThreshold = 20,
    this.temperatureThreshold = 40.0,
    this.geofenceRadius = 1000.0,
    this.geofenceLat,
    this.geofenceLon,
    this.geofenceNodeNum,
    this.geofenceNodeName,
    this.geofenceThrottleMinutes = 30,
  });

  IftttConfig copyWith({
    bool? enabled,
    String? webhookKey,
    bool? messageReceived,
    bool? nodeOnline,
    bool? nodeOffline,
    bool? positionUpdate,
    bool? batteryLow,
    bool? temperatureAlert,
    bool? sosEmergency,
    int? batteryThreshold,
    double? temperatureThreshold,
    double? geofenceRadius,
    double? geofenceLat,
    double? geofenceLon,
    int? geofenceNodeNum,
    String? geofenceNodeName,
    int? geofenceThrottleMinutes,
  }) {
    return IftttConfig(
      enabled: enabled ?? this.enabled,
      webhookKey: webhookKey ?? this.webhookKey,
      messageReceived: messageReceived ?? this.messageReceived,
      nodeOnline: nodeOnline ?? this.nodeOnline,
      nodeOffline: nodeOffline ?? this.nodeOffline,
      positionUpdate: positionUpdate ?? this.positionUpdate,
      batteryLow: batteryLow ?? this.batteryLow,
      temperatureAlert: temperatureAlert ?? this.temperatureAlert,
      sosEmergency: sosEmergency ?? this.sosEmergency,
      batteryThreshold: batteryThreshold ?? this.batteryThreshold,
      temperatureThreshold: temperatureThreshold ?? this.temperatureThreshold,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      geofenceLat: geofenceLat ?? this.geofenceLat,
      geofenceLon: geofenceLon ?? this.geofenceLon,
      geofenceNodeNum: geofenceNodeNum ?? this.geofenceNodeNum,
      geofenceNodeName: geofenceNodeName ?? this.geofenceNodeName,
      geofenceThrottleMinutes:
          geofenceThrottleMinutes ?? this.geofenceThrottleMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'webhookKey': webhookKey,
    'messageReceived': messageReceived,
    'nodeOnline': nodeOnline,
    'nodeOffline': nodeOffline,
    'positionUpdate': positionUpdate,
    'batteryLow': batteryLow,
    'temperatureAlert': temperatureAlert,
    'sosEmergency': sosEmergency,
    'batteryThreshold': batteryThreshold,
    'temperatureThreshold': temperatureThreshold,
    'geofenceRadius': geofenceRadius,
    'geofenceLat': geofenceLat,
    'geofenceLon': geofenceLon,
    'geofenceNodeNum': geofenceNodeNum,
    'geofenceNodeName': geofenceNodeName,
    'geofenceThrottleMinutes': geofenceThrottleMinutes,
  };

  factory IftttConfig.fromJson(Map<String, dynamic> json) {
    return IftttConfig(
      enabled: json['enabled'] as bool? ?? false,
      webhookKey: json['webhookKey'] as String? ?? '',
      messageReceived: json['messageReceived'] as bool? ?? true,
      nodeOnline: json['nodeOnline'] as bool? ?? true,
      nodeOffline: json['nodeOffline'] as bool? ?? true,
      positionUpdate: json['positionUpdate'] as bool? ?? false,
      batteryLow: json['batteryLow'] as bool? ?? true,
      temperatureAlert: json['temperatureAlert'] as bool? ?? false,
      sosEmergency: json['sosEmergency'] as bool? ?? true,
      batteryThreshold: json['batteryThreshold'] as int? ?? 20,
      temperatureThreshold:
          (json['temperatureThreshold'] as num?)?.toDouble() ?? 40.0,
      geofenceRadius: (json['geofenceRadius'] as num?)?.toDouble() ?? 1000.0,
      geofenceLat: (json['geofenceLat'] as num?)?.toDouble(),
      geofenceLon: (json['geofenceLon'] as num?)?.toDouble(),
      geofenceNodeNum: json['geofenceNodeNum'] as int?,
      geofenceNodeName: json['geofenceNodeName'] as String?,
      geofenceThrottleMinutes: json['geofenceThrottleMinutes'] as int? ?? 30,
    );
  }
}

/// IFTTT Webhooks integration service
class IftttService {
  static const String _configKey = 'ifttt_config';
  static const String _webhookBaseUrl = 'https://maker.ifttt.com/trigger';

  SharedPreferences? _prefs;
  IftttConfig _config = const IftttConfig();

  // Track last battery alerts per node to avoid spamming
  final Map<int, DateTime> _lastBatteryAlert = {};
  // Track last temperature alerts per node
  final Map<int, DateTime> _lastTemperatureAlert = {};
  // Track last geofence alerts per node to avoid spamming
  final Map<int, DateTime> _lastGeofenceAlert = {};
  // Track if node was previously inside geofence (only alert on transition)
  final Map<int, bool> _wasInsideGeofence = {};
  // Track node online status for online/offline transitions
  final Map<int, bool> _previousOnlineStatus = {};

  IftttConfig get config => _config;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
  }

  Future<void> _loadConfig() async {
    final jsonString = _prefs?.getString(_configKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _config = IftttConfig.fromJson(json);
      } catch (e) {
        debugPrint('IFTTT: Error loading config: $e');
      }
    }
  }

  /// Save configuration
  Future<void> saveConfig(IftttConfig config) async {
    _config = config;
    final jsonString = jsonEncode(config.toJson());
    await _prefs?.setString(_configKey, jsonString);
    debugPrint('IFTTT: Config saved');
  }

  /// Check if IFTTT is properly configured and enabled
  bool get isActive => _config.enabled && _config.webhookKey.isNotEmpty;

  /// Trigger a webhook event
  Future<bool> _triggerWebhook({
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
  }) async {
    if (!isActive) return false;

    try {
      final url = '$_webhookBaseUrl/$eventName/with/key/${_config.webhookKey}';

      final body = <String, String>{};
      if (value1 != null) body['value1'] = value1;
      if (value2 != null) body['value2'] = value2;
      if (value3 != null) body['value3'] = value3;

      debugPrint('IFTTT: Triggering $eventName');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('IFTTT: Webhook triggered successfully');
        return true;
      } else {
        debugPrint('IFTTT: Webhook failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('IFTTT: Error triggering webhook: $e');
      return false;
    }
  }

  /// Trigger message received event
  Future<bool> triggerMessageReceived({
    required String senderName,
    required String message,
    String? channelName,
  }) async {
    debugPrint(
      'IFTTT: triggerMessageReceived called - messageReceived=${_config.messageReceived}',
    );
    if (!_config.messageReceived) {
      debugPrint('IFTTT: Message trigger disabled in config');
      return false;
    }

    debugPrint(
      'IFTTT: Sending message webhook - sender=$senderName, msg=$message',
    );
    return _triggerWebhook(
      eventName: 'meshtastic_message',
      value1: senderName,
      value2: message,
      value3: channelName ?? 'Direct Message',
    );
  }

  /// Trigger node online event
  Future<bool> triggerNodeOnline({
    required int nodeNum,
    required String nodeName,
  }) async {
    if (!_config.nodeOnline) return false;

    // Check for status transition
    final wasOnline = _previousOnlineStatus[nodeNum];
    _previousOnlineStatus[nodeNum] = true;

    // Only trigger if node was previously offline or unknown
    if (wasOnline == true) return false;

    return _triggerWebhook(
      eventName: 'meshtastic_node_online',
      value1: nodeName,
      value2: '!${nodeNum.toRadixString(16)}',
      value3: DateTime.now().toIso8601String(),
    );
  }

  /// Trigger node offline event
  Future<bool> triggerNodeOffline({
    required int nodeNum,
    required String nodeName,
  }) async {
    if (!_config.nodeOffline) return false;

    // Check for status transition
    final wasOnline = _previousOnlineStatus[nodeNum];
    _previousOnlineStatus[nodeNum] = false;

    // Only trigger if node was previously online
    if (wasOnline != true) return false;

    return _triggerWebhook(
      eventName: 'meshtastic_node_offline',
      value1: nodeName,
      value2: '!${nodeNum.toRadixString(16)}',
      value3: DateTime.now().toIso8601String(),
    );
  }

  /// Trigger position update event (geofencing)
  Future<bool> triggerPositionUpdate({
    required int nodeNum,
    required String nodeName,
    required double latitude,
    required double longitude,
  }) async {
    if (!_config.positionUpdate) return false;
    if (_config.geofenceLat == null || _config.geofenceLon == null) {
      return false;
    }

    // Only trigger for the monitored node if one is specified
    if (_config.geofenceNodeNum != null && _config.geofenceNodeNum != nodeNum) {
      return false;
    }

    // Calculate distance from geofence center
    final distance = _calculateDistance(
      latitude,
      longitude,
      _config.geofenceLat!,
      _config.geofenceLon!,
    );

    final isInsideGeofence = distance <= _config.geofenceRadius;
    final wasInside =
        _wasInsideGeofence[nodeNum] ?? true; // Assume inside initially

    // Update tracking
    _wasInsideGeofence[nodeNum] = isInsideGeofence;

    // Only trigger when transitioning from inside to outside
    if (isInsideGeofence || !wasInside) {
      return false;
    }

    // Throttle: only alert once per configured interval per node
    final lastAlert = _lastGeofenceAlert[nodeNum];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inMinutes <
            _config.geofenceThrottleMinutes) {
      return false;
    }
    _lastGeofenceAlert[nodeNum] = DateTime.now();

    return _triggerWebhook(
      eventName: 'meshtastic_position',
      value1: nodeName,
      value2: '$latitude,$longitude',
      value3: '${distance.toStringAsFixed(0)}m from center',
    );
  }

  /// Trigger battery low event
  Future<bool> triggerBatteryLow({
    required int nodeNum,
    required String nodeName,
    required int batteryLevel,
  }) async {
    if (!_config.batteryLow) return false;
    if (batteryLevel > _config.batteryThreshold) return false;

    // Throttle: only alert once per hour per node
    final lastAlert = _lastBatteryAlert[nodeNum];
    if (lastAlert != null && DateTime.now().difference(lastAlert).inHours < 1) {
      return false;
    }
    _lastBatteryAlert[nodeNum] = DateTime.now();

    return _triggerWebhook(
      eventName: 'meshtastic_battery_low',
      value1: nodeName,
      value2: '$batteryLevel%',
      value3: 'Threshold: ${_config.batteryThreshold}%',
    );
  }

  /// Trigger temperature alert event
  Future<bool> triggerTemperatureAlert({
    required int nodeNum,
    required String nodeName,
    required double temperature,
  }) async {
    if (!_config.temperatureAlert) return false;
    if (temperature < _config.temperatureThreshold) return false;

    // Throttle: only alert once per 30 minutes per node
    final lastAlert = _lastTemperatureAlert[nodeNum];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inMinutes < 30) {
      return false;
    }
    _lastTemperatureAlert[nodeNum] = DateTime.now();

    return _triggerWebhook(
      eventName: 'meshtastic_temperature',
      value1: nodeName,
      value2: '${temperature.toStringAsFixed(1)}°C',
      value3: 'Threshold: ${_config.temperatureThreshold.toStringAsFixed(1)}°C',
    );
  }

  /// Trigger SOS/emergency event
  Future<bool> triggerSosEmergency({
    required int nodeNum,
    required String nodeName,
    double? latitude,
    double? longitude,
  }) async {
    if (!_config.sosEmergency) return false;

    final location = (latitude != null && longitude != null)
        ? '$latitude,$longitude'
        : 'Unknown location';

    return _triggerWebhook(
      eventName: 'meshtastic_sos',
      value1: nodeName,
      value2: '!${nodeNum.toRadixString(16)}',
      value3: location,
    );
  }

  /// Test webhook configuration
  /// Sends a sample geofence alert so you can test your notification format
  Future<bool> testWebhook() async {
    if (_config.webhookKey.isEmpty) return false;

    // Use configured geofence center or default Sydney coordinates
    final testLat = _config.geofenceLat ?? -33.8688;
    final testLon = _config.geofenceLon ?? 151.2093;
    final testNodeName = _config.geofenceNodeName ?? 'Test Node';

    return _triggerWebhook(
      eventName: 'meshtastic_position',
      value1: testNodeName,
      value2: '$testLat,$testLon',
      value3: '1250m from center',
    );
  }

  /// Process a node update for IFTTT triggers
  Future<void> processNodeUpdate(
    MeshNode node, {
    MeshNode? previousNode,
  }) async {
    if (!isActive) return;

    final nodeName = node.displayName;

    // Check online/offline status change
    if (node.isOnline) {
      await triggerNodeOnline(nodeNum: node.nodeNum, nodeName: nodeName);
    } else {
      await triggerNodeOffline(nodeNum: node.nodeNum, nodeName: nodeName);
    }

    // Check battery level
    if (node.batteryLevel != null) {
      await triggerBatteryLow(
        nodeNum: node.nodeNum,
        nodeName: nodeName,
        batteryLevel: node.batteryLevel!,
      );
    }

    // Check position for geofencing
    if (node.hasPosition) {
      await triggerPositionUpdate(
        nodeNum: node.nodeNum,
        nodeName: nodeName,
        latitude: node.latitude!,
        longitude: node.longitude!,
      );
    }
  }

  /// Process a message for IFTTT triggers
  Future<void> processMessage(
    Message message, {
    required String senderName,
    String? channelName,
  }) async {
    if (!isActive) return;

    // Check for SOS keywords in message
    final lowerText = message.text.toLowerCase();
    if (lowerText.contains('sos') ||
        lowerText.contains('emergency') ||
        lowerText.contains('help') ||
        lowerText.contains('mayday')) {
      // Get sender position if available from the message context
      await triggerSosEmergency(nodeNum: message.from, nodeName: senderName);
    }

    // Trigger message received
    await triggerMessageReceived(
      senderName: senderName,
      message: message.text,
      channelName: channelName,
    );
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  double _sin(double x) => _taylor(x, true);
  double _cos(double x) => _taylor(x, false);
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  double _atan(double x) {
    double result = 0;
    double term = x;
    for (int i = 0; i < 50; i++) {
      result += term / (2 * i + 1) * (i % 2 == 0 ? 1 : -1);
      term *= x * x;
    }
    return result;
  }

  double _taylor(double x, bool isSin) {
    // Normalize x to [-pi, pi]
    const pi = 3.141592653589793;
    while (x > pi) {
      x -= 2 * pi;
    }
    while (x < -pi) {
      x += 2 * pi;
    }

    double result = isSin ? x : 1;
    double term = isSin ? x : 1;
    for (int i = 1; i < 20; i++) {
      term *= -x * x / ((2 * i) * (2 * i - (isSin ? 1 : -1)));
      result += term;
    }
    return result;
  }
}
