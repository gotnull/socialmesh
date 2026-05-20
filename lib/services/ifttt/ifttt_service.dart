// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../models/trigger_protocol.dart';

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

/// Webhook mode: IFTTT key-based or custom URL
enum WebhookMode {
  /// Classic IFTTT Webhooks: event name + key -> maker.ifttt.com
  ifttt,

  /// Custom URL: POST JSON to any HTTP/HTTPS endpoint (e.g. Home Assistant)
  customUrl,
}

/// IFTTT / Webhook configuration model
class IftttConfig {
  final bool enabled;
  final String webhookKey;
  final WebhookMode webhookMode;
  final String customWebhookUrl;
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
  // Per-protocol scope. Mirrors `TriggerProtocolFilter` from
  // Automations Phase 0. `any` (the legacy default) fires for both
  // protocols so existing IFTTT setups stay back-compat. Pinning to
  // `meshtastic` or `meshcore` short-circuits the trigger methods
  // when the firing event's protocol doesn't match.
  final TriggerProtocolFilter protocolFilter;

  const IftttConfig({
    this.enabled = false,
    this.webhookKey = '',
    this.webhookMode = WebhookMode.ifttt,
    this.customWebhookUrl = '',
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
    this.protocolFilter = TriggerProtocolFilter.any,
  });

  /// Whether the webhook key is configured (IFTTT mode)
  bool get hasIftttKey => webhookKey.isNotEmpty;

  /// Whether a custom webhook URL is configured
  bool get hasCustomUrl => customWebhookUrl.isNotEmpty;

  /// Whether the active mode has its required credentials configured
  bool get hasActiveCredentials =>
      webhookMode == WebhookMode.ifttt ? hasIftttKey : hasCustomUrl;

  IftttConfig copyWith({
    bool? enabled,
    String? webhookKey,
    WebhookMode? webhookMode,
    String? customWebhookUrl,
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
    TriggerProtocolFilter? protocolFilter,
  }) {
    return IftttConfig(
      enabled: enabled ?? this.enabled,
      webhookKey: webhookKey ?? this.webhookKey,
      webhookMode: webhookMode ?? this.webhookMode,
      customWebhookUrl: customWebhookUrl ?? this.customWebhookUrl,
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
      protocolFilter: protocolFilter ?? this.protocolFilter,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'webhookKey': webhookKey,
    'webhookMode': webhookMode.name,
    'customWebhookUrl': customWebhookUrl,
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
    'protocolFilter': protocolFilter.name,
  };

  factory IftttConfig.fromJson(Map<String, dynamic> json) {
    return IftttConfig(
      enabled: json['enabled'] as bool? ?? false,
      webhookKey: json['webhookKey'] as String? ?? '',
      webhookMode: _parseWebhookMode(json['webhookMode'] as String?),
      customWebhookUrl: json['customWebhookUrl'] as String? ?? '',
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
      protocolFilter: _parseProtocolFilter(json['protocolFilter'] as String?),
    );
  }

  static TriggerProtocolFilter _parseProtocolFilter(String? value) {
    if (value == null) return TriggerProtocolFilter.any;
    for (final f in TriggerProtocolFilter.values) {
      if (f.name == value) return f;
    }
    return TriggerProtocolFilter.any;
  }

  static WebhookMode _parseWebhookMode(String? value) {
    if (value == WebhookMode.customUrl.name) return WebhookMode.customUrl;
    return WebhookMode.ifttt;
  }
}

/// Webhook integration service (IFTTT and custom URL)
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
  // Track node presence confidence for transitions
  final Map<int, PresenceConfidence> _previousPresence = {};

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
        AppLogging.ifttt('IFTTT: Error loading config: $e');
      }
    }
  }

  /// Save configuration
  Future<void> saveConfig(IftttConfig config) async {
    _config = config;
    final jsonString = jsonEncode(config.toJson());
    await _prefs?.setString(_configKey, jsonString);
    AppLogging.ifttt('IFTTT: Config saved');
  }

  /// Export config as JSON string for cloud sync
  String toJsonString() {
    return jsonEncode(_config.toJson());
  }

  /// Load config from JSON string (for cloud sync restore)
  Future<void> loadFromJson(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _config = IftttConfig.fromJson(json);
      await _prefs?.setString(_configKey, jsonString);
      AppLogging.ifttt('IFTTT: Loaded config from cloud');
    } catch (e) {
      AppLogging.ifttt('IFTTT: Error loading from JSON: $e');
    }
  }

  /// Check if the service is properly configured and enabled.
  ///
  /// In IFTTT mode, requires a webhook key.
  /// In custom URL mode, requires a non-empty URL.
  bool get isActive => _config.enabled && _config.hasActiveCredentials;

  /// Trigger a webhook event via the configured mode (IFTTT or custom URL).
  Future<bool> _triggerWebhook({
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
    TriggerProtocol? protocol,
  }) async {
    if (!isActive) return false;

    if (_config.webhookMode == WebhookMode.customUrl) {
      return _postToCustomUrl(
        url: _config.customWebhookUrl,
        eventName: eventName,
        value1: value1,
        value2: value2,
        value3: value3,
        protocol: protocol,
      );
    }

    return _postToIfttt(
      eventName: eventName,
      value1: value1,
      value2: value2,
      value3: value3,
    );
  }

  /// POST to the IFTTT Webhooks maker endpoint.
  Future<bool> _postToIfttt({
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
  }) async {
    try {
      final url = '$_webhookBaseUrl/$eventName/with/key/${_config.webhookKey}';

      final body = <String, String>{};
      if (value1 != null) body['value1'] = value1;
      if (value2 != null) body['value2'] = value2;
      if (value3 != null) body['value3'] = value3;

      AppLogging.ifttt('IFTTT: Triggering $eventName');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        AppLogging.ifttt('IFTTT: Webhook triggered successfully');
        return true;
      } else {
        AppLogging.ifttt(
          'IFTTT: Webhook failed with status ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      AppLogging.ifttt('IFTTT: Error triggering webhook: $e');
      return false;
    }
  }

  /// POST JSON to a custom webhook URL (e.g. Home Assistant, n8n, Node-RED).
  ///
  /// Sends a structured JSON body with event name, values, and timestamp.
  /// Private network addresses (10.x, 192.168.x, 172.16-31.x) are allowed.
  Future<bool> _postToCustomUrl({
    required String url,
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
    // Optional protocol tag. When provided, written into the JSON
    // body as `"protocol": "meshtastic"|"meshcore"` so applets can
    // branch on the source. Triggers that aren't yet protocol-aware
    // (battery / position / etc.) pass null and omit the field.
    TriggerProtocol? protocol,
  }) async {
    try {
      final body = buildIftttCustomUrlBody(
        eventName: eventName,
        value1: value1,
        value2: value2,
        value3: value3,
        protocol: protocol,
        timestamp: DateTime.now(),
      );

      AppLogging.ifttt('Webhook: POST $eventName -> $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (success) {
        AppLogging.ifttt('Webhook: Custom URL triggered successfully');
      } else {
        AppLogging.ifttt(
          'Webhook: Custom URL failed with status ${response.statusCode}',
        );
      }
      return success;
    } catch (e) {
      AppLogging.ifttt('Webhook: Error posting to custom URL: $e');
      return false;
    }
  }

  /// POST JSON to an arbitrary URL (for automation webhook actions).
  ///
  /// Unlike [_triggerWebhook], this does not require the global webhook config
  /// to be active — it fires directly to the provided [url].
  /// Private/LAN addresses (e.g. 192.168.x.x) are supported.
  Future<bool> triggerCustomUrl({
    required String url,
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
  }) async {
    return _postToCustomUrl(
      url: url,
      eventName: eventName,
      value1: value1,
      value2: value2,
      value3: value3,
    );
  }

  /// Trigger message received event
  Future<bool> triggerMessageReceived({
    required String senderName,
    required String message,
    String? channelName,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    AppLogging.debug(
      'IFTTT: triggerMessageReceived called - messageReceived=${_config.messageReceived}',
    );
    if (!_config.messageReceived) {
      AppLogging.ifttt('IFTTT: Message trigger disabled in config');
      return false;
    }

    AppLogging.debug(
      'IFTTT: Sending message webhook - sender=$senderName, msg=$message',
    );
    return _triggerWebhook(
      eventName: _messageReceivedEventName(protocol),
      value1: senderName,
      value2: message,
      value3: channelName ?? 'Direct Message', // lint-allow: hardcoded-string
      protocol: protocol,
    );
  }

  // Event-name discrimination by protocol. Existing IFTTT applets
  // out there subscribe to `meshtastic_message`; preserving that
  // name for Meshtastic-sourced events is the back-compat guarantee.
  // MeshCore-sourced events get a separate `meshcore_message` name
  // so new applets can subscribe to one protocol only.
  String _messageReceivedEventName(TriggerProtocol protocol) {
    switch (protocol) {
      case TriggerProtocol.meshtastic:
        return 'meshtastic_message';
      case TriggerProtocol.meshcore:
        return 'meshcore_message';
    }
  }

  String _sosEventName(TriggerProtocol protocol) {
    switch (protocol) {
      case TriggerProtocol.meshtastic:
        return 'meshtastic_sos';
      case TriggerProtocol.meshcore:
        return 'meshcore_sos';
    }
  }

  /// Trigger node online event
  Future<bool> triggerNodeOnline({
    required int nodeNum,
    required String nodeName,
  }) async {
    if (!_config.nodeOnline) return false;

    // Check for status transition
    final wasOnline = _previousPresence[nodeNum];
    _previousPresence[nodeNum] = PresenceConfidence.active;

    // Only trigger if node was previously offline or unknown
    if (wasOnline == PresenceConfidence.active) return false;

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
    final wasOnline = _previousPresence[nodeNum];
    _previousPresence[nodeNum] = PresenceConfidence.stale;

    // Only trigger if node was previously online
    if (wasOnline != PresenceConfidence.active &&
        wasOnline != PresenceConfidence.fading) {
      return false;
    }

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
    if (!_config.positionUpdate) {
      AppLogging.ifttt('IFTTT: Position update disabled in config');
      return false;
    }

    // If no geofence is configured, trigger on every position update
    if (_config.geofenceLat == null || _config.geofenceLon == null) {
      AppLogging.ifttt(
        'IFTTT: No geofence configured, triggering position update',
      );
      return _triggerWebhook(
        eventName: 'meshtastic_position',
        value1: nodeName,
        value2: '$latitude,$longitude',
        value3: DateTime.now().toIso8601String(),
      );
    }

    // Only trigger for the monitored node if one is specified
    if (_config.geofenceNodeNum != null && _config.geofenceNodeNum != nodeNum) {
      AppLogging.ifttt('IFTTT: Position update ignored - not monitored node');
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
      AppLogging.debug(
        'IFTTT: Position update ignored - no geofence transition (inside=$isInsideGeofence, wasInside=$wasInside)',
      );
      return false;
    }

    // Throttle: only alert once per configured interval per node
    final lastAlert = _lastGeofenceAlert[nodeNum];
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inMinutes <
            _config.geofenceThrottleMinutes) {
      AppLogging.ifttt('IFTTT: Position update throttled');
      return false;
    }
    _lastGeofenceAlert[nodeNum] = DateTime.now();

    AppLogging.ifttt(
      'IFTTT: Triggering geofence alert - $nodeName left geofence',
    );
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
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    if (!_config.sosEmergency) return false;

    final location = (latitude != null && longitude != null)
        ? '$latitude,$longitude'
        : 'Unknown location';

    return _triggerWebhook(
      eventName: _sosEventName(protocol),
      value1: nodeName,
      value2: '!${nodeNum.toRadixString(16)}',
      value3: location,
      protocol: protocol,
    );
  }

  /// Trigger a custom webhook event (for automations)
  Future<bool> triggerCustomEvent({
    required String eventName,
    String? value1,
    String? value2,
    String? value3,
  }) async {
    if (!isActive) return false;

    return _triggerWebhook(
      eventName: eventName,
      value1: value1,
      value2: value2,
      value3: value3,
    );
  }

  /// Test webhook configuration.
  ///
  /// Sends a sample event so the user can verify their configuration.
  /// Works for both IFTTT and custom URL modes.
  Future<bool> testWebhook() async {
    if (!_config.hasActiveCredentials) return false;

    // Use configured geofence center or default Sydney coordinates
    final testLat = _config.geofenceLat ?? -33.8688;
    final testLon = _config.geofenceLon ?? 151.2093;
    final testNodeName =
        _config.geofenceNodeName ?? 'Test Node'; // lint-allow: hardcoded-string

    // Temporarily activate the config so _triggerWebhook passes the isActive
    // check even if the user hasn't saved yet.
    final previousConfig = _config;
    _config = _config.copyWith(enabled: true);
    try {
      return await _triggerWebhook(
        eventName: 'meshtastic_position',
        value1: testNodeName,
        value2: '$testLat,$testLon',
        value3: '1250m from center',
      );
    } finally {
      _config = previousConfig;
    }
  }

  /// Process a node update for IFTTT triggers
  //
  // `protocol` lets callers tag where this event came from. Phase 0
  // accepts the parameter as a forward-looking API surface; Phase 4
  // will wire it into the webhook payload so subscribers can branch
  // on protocol (`meshtastic_node_update` vs `meshcore_node_update`).
  Future<void> processNodeUpdate(
    MeshNode node, {
    MeshNode? previousNode,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    if (!isActive) return;

    final nodeName = node.displayName;

    // Check battery level
    if (node.batteryLevel != null) {
      await triggerBatteryLow(
        nodeNum: node.nodeNum,
        nodeName: nodeName,
        batteryLevel: node.batteryLevel!,
      );
    }

    // Check temperature
    if (node.temperature != null) {
      await triggerTemperatureAlert(
        nodeNum: node.nodeNum,
        nodeName: nodeName,
        temperature: node.temperature!,
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

  /// Process a presence transition for IFTTT triggers
  Future<void> processPresenceUpdate(
    MeshNode node, {
    required PresenceConfidence previous,
    required PresenceConfidence current,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    if (!isActive) return;

    _previousPresence[node.nodeNum] = current;
    final nodeName = node.displayName;

    if (current.isActive && !previous.isActive) {
      await triggerNodeOnline(nodeNum: node.nodeNum, nodeName: nodeName);
      return;
    }

    if (current.isInactive && !previous.isInactive) {
      await triggerNodeOffline(nodeNum: node.nodeNum, nodeName: nodeName);
    }
  }

  // Process an inbound message for IFTTT triggers. Takes primitives
  // so both protocols can call into the same seam without coupling
  // the service to either `Message` (Meshtastic) or `MeshCoreMessage`.
  // The `protocol` tag drives event-name selection
  // (`meshtastic_message` vs `meshcore_message`) and is also written
  // into the custom-URL JSON payload so downstream applets can
  // branch. The user's per-config `protocolFilter` short-circuits
  // events from protocols they don't want surfaced.
  Future<void> processMessage({
    required int from,
    required String text,
    required String senderName,
    String? channelName,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    if (!isActive) return;
    if (!triggerProtocolFilterMatches(_config.protocolFilter, protocol)) {
      AppLogging.ifttt(
        'IFTTT: skipping message - protocol filter '
        '${_config.protocolFilter.name} excludes ${protocol.name}',
      );
      return;
    }

    // Check for SOS keywords in message
    final lowerText = text.toLowerCase();
    if (lowerText.contains('sos') ||
        lowerText.contains('emergency') ||
        lowerText.contains('help') ||
        lowerText.contains('mayday')) {
      await triggerSosEmergency(
        nodeNum: from,
        nodeName: senderName,
        protocol: protocol,
      );
    }

    // Trigger message received
    await triggerMessageReceived(
      senderName: senderName,
      message: text,
      channelName: channelName,
      protocol: protocol,
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

// Custom-URL JSON body assembly. Top-level so the wire shape is
// directly testable without spinning up an HTTP mock. The Meshtastic
// path passes `protocol = TriggerProtocol.meshtastic` and the MeshCore
// path passes `meshcore`; both surface as a `"protocol"` field so
// downstream applets (Home Assistant, n8n, Node-RED) can branch on
// the source without inspecting the event name. Triggers that aren't
// yet protocol-aware (battery / position) pass null and the field is
// omitted for back-compat with existing applet bodies.
Map<String, dynamic> buildIftttCustomUrlBody({
  required String eventName,
  String? value1,
  String? value2,
  String? value3,
  TriggerProtocol? protocol,
  required DateTime timestamp,
}) {
  return <String, dynamic>{
    'event': eventName,
    if (value1 != null) 'value1': value1,
    if (value2 != null) 'value2': value2,
    if (value3 != null) 'value3': value3,
    if (protocol != null) 'protocol': protocol.name,
    'timestamp': timestamp.toIso8601String(),
  };
}
