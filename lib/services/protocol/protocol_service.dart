// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../models/mesh_models.dart';
import '../../models/device_error.dart';
import '../../generated/meshtastic/admin.pb.dart' as admin;
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;
import '../../generated/meshtastic/portnums.pbenum.dart' as pn;
import '../../generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'packet_framer.dart';
import '../mesh_packet_dedupe_store.dart';
import '../../utils/text_sanitizer.dart';

/// Mesh signal packet received from PRIVATE_APP portnum.
///
/// This is the over-the-air format for Signals (ephemeral posts).
/// Format: JSON with fields:
/// - id: Signal ID (UUID) - required for cloud sync
/// - c: Signal text content (compressed key)
/// - t: Time-to-live in minutes (compressed key)
/// - la/ln: Optional location coordinates (compressed keys)
///
/// The id field enables deterministic matching:
/// - Firestore document: posts/{id}
/// - Storage path: signals/{userId}/{id}.jpg
/// - Comments: posts/{id}/comments/{commentId}
///
class MeshSignalPacket {
  final int senderNodeId;
  final int packetId;
  final String? signalId;
  final String content;
  final int ttlMinutes;
  final double? latitude;
  final double? longitude;
  final int? hopCount; // null = unknown, 0 = local, 1+ = hops away
  final DateTime receivedAt;
  final bool hasImage;
  final Map<String, dynamic>?
  presenceInfo; // Extended presence: {"i": int, "s": string}

  const MeshSignalPacket({
    required this.senderNodeId,
    required this.packetId,
    this.signalId,
    required this.content,
    required this.ttlMinutes,
    this.latitude,
    this.longitude,
    this.hopCount,
    required this.receivedAt,
    this.hasImage = false,
    this.presenceInfo,
  });

  /// Parse from mesh packet payload (JSON).
  /// Compressed keys: id, c (content), t (ttl), la (lat), ln (lng), p (presence)
  factory MeshSignalPacket.fromPayload(
    int senderNodeId,
    List<int> payload, {
    int? hopCount,
    int? packetId,
  }) {
    final jsonStr = utf8.decode(payload);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    // Support both compressed and full keys
    final content = json['c'] as String? ?? json['content'] as String? ?? '';
    final ttl = json['t'] as int? ?? json['ttl'] as int? ?? 60;
    final lat =
        (json['la'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble();
    final lng =
        (json['ln'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble();

    // Parse extended presence info if present
    Map<String, dynamic>? presenceInfo;
    final presenceRaw = json['p'];
    if (presenceRaw is Map<String, dynamic>) {
      presenceInfo = presenceRaw;
    }

    return MeshSignalPacket(
      senderNodeId: senderNodeId,
      packetId: packetId ?? 0,
      signalId: json['id'] as String?,
      content: content,
      ttlMinutes: ttl,
      latitude: lat,
      longitude: lng,
      hopCount: hopCount,
      receivedAt: DateTime.now(),
      hasImage:
          _extractBool(json['i']) ||
          _extractBool(json['hasImage']) ||
          _extractBool(json['has_image']),
      presenceInfo: presenceInfo,
    );
  }

  static bool _extractBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  /// Serialize to mesh packet payload (JSON).
  /// Uses compressed keys to minimize payload size:
  /// - id: signal ID (required for cloud sync)
  /// - c: content
  /// - t: ttl
  /// - la/ln: latitude/longitude
  /// - p: presence info (optional)
  List<int> toPayload() {
    if (signalId == null || signalId!.isEmpty) {
      throw StateError('MeshSignalPacket requires signalId for send');
    }
    final json = <String, dynamic>{'c': content, 't': ttlMinutes};
    json['id'] = signalId;
    if (latitude != null && longitude != null) {
      json['la'] = latitude;
      json['ln'] = longitude;
    }
    if (hasImage) {
      json['i'] = true;
    }
    if (presenceInfo != null && presenceInfo!.isNotEmpty) {
      json['p'] = presenceInfo;
    }
    return utf8.encode(jsonEncode(json));
  }
}

/// Detection sensor event received from DETECTION_SENSOR_APP portnum.
/// Represents a motion/door/window sensor state change from the mesh.
class DetectionSensorEvent {
  final int senderNodeId;
  final String sensorName;
  final bool detected;
  final DateTime receivedAt;

  const DetectionSensorEvent({
    required this.senderNodeId,
    required this.sensorName,
    required this.detected,
    required this.receivedAt,
  });

  /// Parse from mesh packet payload (text format: "sensorName: state")
  factory DetectionSensorEvent.fromPayload(
    int senderNodeId,
    List<int> payload,
  ) {
    final text = utf8.decode(payload);
    // Detection sensor format is typically "SensorName: Detected" or "SensorName: Clear"
    final parts = text.split(':');
    final sensorName = parts.isNotEmpty ? parts[0].trim() : 'Unknown Sensor';
    final stateText = parts.length > 1 ? parts[1].trim().toLowerCase() : '';
    final detected =
        stateText.contains('detect') ||
        stateText.contains('trigger') ||
        stateText.contains('motion') ||
        stateText.contains('open') ||
        stateText == '1' ||
        stateText == 'true' ||
        stateText == 'high';

    return DetectionSensorEvent(
      senderNodeId: senderNodeId,
      sensorName: sensorName,
      detected: detected,
      receivedAt: DateTime.now(),
    );
  }
}

/// Debug flags to control verbose logging
class ProtocolDebugFlags {
  /// Log RSSI polling updates
  static bool logRssi = false;

  /// Log position-related messages (POSITION_APP, NodeInfo positions)
  static bool logPosition = true;

  /// Log telemetry messages (battery, voltage, etc.)
  static bool logTelemetry = false;

  /// Log packet processing details
  static bool logPackets = false;

  /// Log node info updates
  static bool logNodeInfo = true;

  /// Log channel configuration
  static bool logChannels = false;
}

/// Protocol service for handling Meshtastic protocol
class ProtocolService {
  final DeviceTransport _transport;
  final PacketFramer _framer;

  final StreamController<Message> _messageController;
  final StreamController<MeshNode> _nodeController;
  final StreamController<ChannelConfig> _channelController;
  final StreamController<DeviceError> _errorController;
  final StreamController<MeshSignalPacket> _signalController;
  final StreamController<int> _myNodeNumController;
  final StreamController<int> _rssiController;
  final StreamController<double> _snrController;
  final StreamController<double> _channelUtilController;
  final StreamController<MessageDeliveryUpdate> _deliveryController;
  final StreamController<config_pbenum.Config_LoRaConfig_RegionCode>
  _regionController;
  final StreamController<config_pb.Config_PositionConfig>
  _positionConfigController;
  final StreamController<config_pb.Config_DeviceConfig> _deviceConfigController;
  final StreamController<config_pb.Config_DisplayConfig>
  _displayConfigController;
  final StreamController<config_pb.Config_PowerConfig> _powerConfigController;
  final StreamController<config_pb.Config_NetworkConfig>
  _networkConfigController;
  final StreamController<config_pb.Config_BluetoothConfig>
  _bluetoothConfigController;
  final StreamController<config_pb.Config_SecurityConfig>
  _securityConfigController;
  final StreamController<config_pb.Config_LoRaConfig> _loraConfigController;
  final StreamController<module_pb.ModuleConfig_MQTTConfig>
  _mqttConfigController;
  final StreamController<module_pb.ModuleConfig_TelemetryConfig>
  _telemetryConfigController;
  final StreamController<module_pb.ModuleConfig_PaxcounterConfig>
  _paxCounterConfigController;
  final StreamController<module_pb.ModuleConfig_AmbientLightingConfig>
  _ambientLightingConfigController;
  final StreamController<module_pb.ModuleConfig_SerialConfig>
  _serialConfigController;
  final StreamController<module_pb.ModuleConfig_StoreForwardConfig>
  _storeForwardConfigController;
  final StreamController<module_pb.ModuleConfig_DetectionSensorConfig>
  _detectionSensorConfigController;
  final StreamController<module_pb.ModuleConfig_RangeTestConfig>
  _rangeTestConfigController;
  final StreamController<module_pb.ModuleConfig_ExternalNotificationConfig>
  _externalNotificationConfigController;
  final StreamController<module_pb.ModuleConfig_CannedMessageConfig>
  _cannedMessageConfigController;
  final StreamController<pb.ClientNotification> _clientNotificationController;
  final StreamController<pb.User> _userConfigController;
  final StreamController<DetectionSensorEvent> _detectionSensorEventController;

  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<DeviceConnectionState>? _transportStateSubscription;
  Completer<void>? _configCompleter;
  Timer? _rssiTimer;
  bool _pollingConfig = false;

  int? _myNodeNum;
  int _lastRssi = -90;
  double _lastSnr = 0.0;
  double _lastChannelUtil = 0.0;
  config_pbenum.Config_LoRaConfig_RegionCode? _currentRegion;
  config_pb.Config_PositionConfig? _currentPositionConfig;
  config_pb.Config_DeviceConfig? _currentDeviceConfig;
  config_pb.Config_DisplayConfig? _currentDisplayConfig;
  config_pb.Config_PowerConfig? _currentPowerConfig;
  config_pb.Config_NetworkConfig? _currentNetworkConfig;
  config_pb.Config_BluetoothConfig? _currentBluetoothConfig;
  config_pb.Config_SecurityConfig? _currentSecurityConfig;
  config_pb.Config_LoRaConfig? _currentLoraConfig;
  module_pb.ModuleConfig_MQTTConfig? _currentMqttConfig;
  module_pb.ModuleConfig_TelemetryConfig? _currentTelemetryConfig;
  module_pb.ModuleConfig_PaxcounterConfig? _currentPaxCounterConfig;
  module_pb.ModuleConfig_AmbientLightingConfig? _currentAmbientLightingConfig;
  module_pb.ModuleConfig_SerialConfig? _currentSerialConfig;
  module_pb.ModuleConfig_StoreForwardConfig? _currentStoreForwardConfig;
  module_pb.ModuleConfig_DetectionSensorConfig? _currentDetectionSensorConfig;
  module_pb.ModuleConfig_RangeTestConfig? _currentRangeTestConfig;
  module_pb.ModuleConfig_ExternalNotificationConfig?
  _currentExternalNotificationConfig;
  module_pb.ModuleConfig_CannedMessageConfig? _currentCannedMessageConfig;
  pb.User? _currentUserConfig;
  final Map<int, MeshNode> _nodes = {};
  final List<ChannelConfig> _channels = [];
  final Random _random = Random();
  bool _configurationComplete = false;
  final MeshPacketDedupeStore _dedupeStore;

  void Function({
    required int nodeNum,
    String? longName,
    String? shortName,
    int? lastSeenAtMs,
  })?
  onIdentityUpdate;

  static const Duration _messagePacketTtl = Duration(minutes: 120);

  // Track pending messages by packet ID for delivery status updates
  final Map<int, String> _pendingMessages = {}; // packetId -> messageId

  // BLE device name for hardware model inference
  String? _deviceName;

  ProtocolService(this._transport, {MeshPacketDedupeStore? dedupeStore})
    : _framer = PacketFramer(),
      _messageController = StreamController<Message>.broadcast(),
      _nodeController = StreamController<MeshNode>.broadcast(),
      _channelController = StreamController<ChannelConfig>.broadcast(),
      _errorController = StreamController<DeviceError>.broadcast(),
      _signalController = StreamController<MeshSignalPacket>.broadcast(),
      _myNodeNumController = StreamController<int>.broadcast(),
      _rssiController = StreamController<int>.broadcast(),
      _snrController = StreamController<double>.broadcast(),
      _channelUtilController = StreamController<double>.broadcast(),
      _deliveryController = StreamController<MessageDeliveryUpdate>.broadcast(),
      _regionController =
          StreamController<
            config_pbenum.Config_LoRaConfig_RegionCode
          >.broadcast(),
      _positionConfigController =
          StreamController<config_pb.Config_PositionConfig>.broadcast(),
      _deviceConfigController =
          StreamController<config_pb.Config_DeviceConfig>.broadcast(),
      _displayConfigController =
          StreamController<config_pb.Config_DisplayConfig>.broadcast(),
      _powerConfigController =
          StreamController<config_pb.Config_PowerConfig>.broadcast(),
      _networkConfigController =
          StreamController<config_pb.Config_NetworkConfig>.broadcast(),
      _bluetoothConfigController =
          StreamController<config_pb.Config_BluetoothConfig>.broadcast(),
      _securityConfigController =
          StreamController<config_pb.Config_SecurityConfig>.broadcast(),
      _loraConfigController =
          StreamController<config_pb.Config_LoRaConfig>.broadcast(),
      _mqttConfigController =
          StreamController<module_pb.ModuleConfig_MQTTConfig>.broadcast(),
      _telemetryConfigController =
          StreamController<module_pb.ModuleConfig_TelemetryConfig>.broadcast(),
      _paxCounterConfigController =
          StreamController<module_pb.ModuleConfig_PaxcounterConfig>.broadcast(),
      _ambientLightingConfigController =
          StreamController<
            module_pb.ModuleConfig_AmbientLightingConfig
          >.broadcast(),
      _serialConfigController =
          StreamController<module_pb.ModuleConfig_SerialConfig>.broadcast(),
      _storeForwardConfigController =
          StreamController<
            module_pb.ModuleConfig_StoreForwardConfig
          >.broadcast(),
      _detectionSensorConfigController =
          StreamController<
            module_pb.ModuleConfig_DetectionSensorConfig
          >.broadcast(),
      _rangeTestConfigController =
          StreamController<module_pb.ModuleConfig_RangeTestConfig>.broadcast(),
      _externalNotificationConfigController =
          StreamController<
            module_pb.ModuleConfig_ExternalNotificationConfig
          >.broadcast(),
      _cannedMessageConfigController =
          StreamController<
            module_pb.ModuleConfig_CannedMessageConfig
          >.broadcast(),
      _clientNotificationController =
          StreamController<pb.ClientNotification>.broadcast(),
      _userConfigController = StreamController<pb.User>.broadcast(),
      _detectionSensorEventController =
          StreamController<DetectionSensorEvent>.broadcast(),
      _dedupeStore = dedupeStore ?? MeshPacketDedupeStore();

  /// Set the BLE device name for hardware model inference
  void setDeviceName(String? name) {
    _deviceName = name;
    AppLogging.protocol('Device name set to: $name');
  }

  /// Set the BLE model number (from Device Information Service 0x180A)
  void setBleModelNumber(String? modelNumber) {
    _bleModelNumber = modelNumber;
    if (modelNumber != null) {
      AppLogging.protocol('BLE model number set to: $modelNumber');
    }
  }

  /// Set the BLE manufacturer name (from Device Information Service 0x180A)
  void setBleManufacturerName(String? manufacturerName) {
    _bleManufacturerName = manufacturerName;
    if (manufacturerName != null) {
      AppLogging.protocol('BLE manufacturer name set to: $manufacturerName');
    }
  }

  String? _bleModelNumber;
  String? _bleManufacturerName;

  /// Stream of received messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of node updates
  Stream<MeshNode> get nodeStream => _nodeController.stream;

  /// Stream of channel updates
  Stream<ChannelConfig> get channelStream => _channelController.stream;

  /// Stream of received mesh signal packets (PRIVATE_APP portnum)
  Stream<MeshSignalPacket> get signalStream => _signalController.stream;

  /// Stream of detection sensor events (DETECTION_SENSOR_APP portnum)
  Stream<DetectionSensorEvent> get detectionSensorEventStream =>
      _detectionSensorEventController.stream;

  /// Stream of client notifications (firmware errors, warnings, config validation)
  Stream<pb.ClientNotification> get clientNotificationStream =>
      _clientNotificationController.stream;

  /// Stream of region updates
  Stream<config_pbenum.Config_LoRaConfig_RegionCode> get regionStream =>
      _regionController.stream;

  /// Current region
  config_pbenum.Config_LoRaConfig_RegionCode? get currentRegion =>
      _currentRegion;

  /// Stream of position config updates
  Stream<config_pb.Config_PositionConfig> get positionConfigStream =>
      _positionConfigController.stream;

  /// Current position config
  config_pb.Config_PositionConfig? get currentPositionConfig =>
      _currentPositionConfig;

  /// Stream of device config updates
  Stream<config_pb.Config_DeviceConfig> get deviceConfigStream =>
      _deviceConfigController.stream;

  /// Current device config
  config_pb.Config_DeviceConfig? get currentDeviceConfig =>
      _currentDeviceConfig;

  /// Stream of display config updates
  Stream<config_pb.Config_DisplayConfig> get displayConfigStream =>
      _displayConfigController.stream;

  /// Current display config
  config_pb.Config_DisplayConfig? get currentDisplayConfig =>
      _currentDisplayConfig;

  /// Stream of power config updates
  Stream<config_pb.Config_PowerConfig> get powerConfigStream =>
      _powerConfigController.stream;

  /// Current power config
  config_pb.Config_PowerConfig? get currentPowerConfig => _currentPowerConfig;

  /// Stream of network config updates
  Stream<config_pb.Config_NetworkConfig> get networkConfigStream =>
      _networkConfigController.stream;

  /// Current network config
  config_pb.Config_NetworkConfig? get currentNetworkConfig =>
      _currentNetworkConfig;

  /// Stream of bluetooth config updates
  Stream<config_pb.Config_BluetoothConfig> get bluetoothConfigStream =>
      _bluetoothConfigController.stream;

  /// Current bluetooth config
  config_pb.Config_BluetoothConfig? get currentBluetoothConfig =>
      _currentBluetoothConfig;

  /// Stream of security config updates
  Stream<config_pb.Config_SecurityConfig> get securityConfigStream =>
      _securityConfigController.stream;

  /// Current security config
  config_pb.Config_SecurityConfig? get currentSecurityConfig =>
      _currentSecurityConfig;

  /// Stream of LoRa config updates
  Stream<config_pb.Config_LoRaConfig> get loraConfigStream =>
      _loraConfigController.stream;

  /// Current LoRa config
  config_pb.Config_LoRaConfig? get currentLoraConfig => _currentLoraConfig;

  /// Stream of MQTT config updates
  Stream<module_pb.ModuleConfig_MQTTConfig> get mqttConfigStream =>
      _mqttConfigController.stream;

  /// Current MQTT config
  module_pb.ModuleConfig_MQTTConfig? get currentMqttConfig =>
      _currentMqttConfig;

  /// Stream of telemetry config updates
  Stream<module_pb.ModuleConfig_TelemetryConfig> get telemetryConfigStream =>
      _telemetryConfigController.stream;

  /// Current telemetry config
  module_pb.ModuleConfig_TelemetryConfig? get currentTelemetryConfig =>
      _currentTelemetryConfig;

  /// Stream of PAX counter config updates
  Stream<module_pb.ModuleConfig_PaxcounterConfig> get paxCounterConfigStream =>
      _paxCounterConfigController.stream;

  /// Current PAX counter config
  module_pb.ModuleConfig_PaxcounterConfig? get currentPaxCounterConfig =>
      _currentPaxCounterConfig;

  /// Stream of ambient lighting config updates
  Stream<module_pb.ModuleConfig_AmbientLightingConfig>
  get ambientLightingConfigStream => _ambientLightingConfigController.stream;

  /// Current ambient lighting config
  module_pb.ModuleConfig_AmbientLightingConfig?
  get currentAmbientLightingConfig => _currentAmbientLightingConfig;

  /// Stream of serial config updates
  Stream<module_pb.ModuleConfig_SerialConfig> get serialConfigStream =>
      _serialConfigController.stream;

  /// Current serial config
  module_pb.ModuleConfig_SerialConfig? get currentSerialConfig =>
      _currentSerialConfig;

  /// Stream of store forward config updates
  Stream<module_pb.ModuleConfig_StoreForwardConfig>
  get storeForwardConfigStream => _storeForwardConfigController.stream;

  /// Current store forward config
  module_pb.ModuleConfig_StoreForwardConfig? get currentStoreForwardConfig =>
      _currentStoreForwardConfig;

  /// Stream of detection sensor config updates
  Stream<module_pb.ModuleConfig_DetectionSensorConfig>
  get detectionSensorConfigStream => _detectionSensorConfigController.stream;

  /// Current detection sensor config
  module_pb.ModuleConfig_DetectionSensorConfig?
  get currentDetectionSensorConfig => _currentDetectionSensorConfig;

  /// Stream of canned message config updates
  Stream<module_pb.ModuleConfig_CannedMessageConfig>
  get cannedMessageConfigStream => _cannedMessageConfigController.stream;

  /// Current canned message config
  module_pb.ModuleConfig_CannedMessageConfig? get currentCannedMessageConfig =>
      _currentCannedMessageConfig;

  /// Stream of user (owner) config updates
  Stream<pb.User> get userConfigStream => _userConfigController.stream;

  /// Current user (owner) config for connected device
  pb.User? get currentUserConfig => _currentUserConfig;

  /// Stream of RSSI updates
  Stream<int> get rssiStream => _rssiController.stream;

  /// Stream of SNR (Signal-to-Noise Ratio) updates
  Stream<double> get snrStream => _snrController.stream;

  /// Stream of channel utilization updates (0-100%)
  Stream<double> get channelUtilStream => _channelUtilController.stream;

  /// Get last known SNR
  double get lastSnr => _lastSnr;

  /// Get last known channel utilization
  double get lastChannelUtil => _lastChannelUtil;

  /// Stream of message delivery updates
  Stream<MessageDeliveryUpdate> get deliveryStream =>
      _deliveryController.stream;

  /// Get last known RSSI
  int get lastRssi => _lastRssi;

  /// Stream of device errors
  Stream<DeviceError> get errorStream => _errorController.stream;

  /// Stream of my node number updates
  Stream<int> get myNodeNumStream => _myNodeNumController.stream;

  /// My node number
  int? get myNodeNum => _myNodeNum;

  /// Configuration complete
  bool get configurationComplete => _configurationComplete;

  /// Check if the transport is connected
  bool get isConnected => _transport.isConnected;

  /// All known nodes
  Map<int, MeshNode> get nodes => Map.unmodifiable(_nodes);

  /// All channels
  List<ChannelConfig> get channels => List.unmodifiable(_channels);

  /// Start listening to transport and wait for configuration
  Future<void> start() async {
    AppLogging.debug('🔵 Protocol.start() called - instance: $hashCode');
    AppLogging.protocol('Starting protocol service');

    // Cancel any existing subscriptions to prevent duplicates
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    _transportStateSubscription?.cancel();
    _transportStateSubscription = null;

    // Clear previous connection state
    _channels.clear();
    _nodes.clear();
    _myNodeNum = null;
    _configurationComplete = false;

    _configCompleter = Completer<void>();
    var waitingForConfig = false; // Track if we're past initial setup

    _dataSubscription = _transport.dataStream.listen(
      _handleData,
      onError: (error) {
        AppLogging.protocol('Transport error: $error');
      },
    );
    AppLogging.protocol('DATA_SUBSCRIBED to transport');

    // Listen for transport disconnection to fail fast
    _transportStateSubscription = _transport.stateStream.listen((state) {
      if (state == DeviceConnectionState.disconnected ||
          state == DeviceConnectionState.error) {
        AppLogging.protocol('Transport disconnected/error during config wait');
        // Only complete with error if we're actually waiting for config
        // This prevents double-errors when enableNotifications throws directly
        if (waitingForConfig &&
            _configCompleter != null &&
            !_configCompleter!.isCompleted) {
          _configCompleter!.completeError(
            Exception('Transport disconnected during configuration'),
          );
        }
      }
    });

    try {
      // Enable notifications FIRST - device needs this to respond to config request
      await _transport.enableNotifications();

      // Short delay to let notifications settle
      await Future.delayed(const Duration(milliseconds: 200));

      // NOW request configuration - device will respond via notifications
      await _requestConfiguration();

      // Start polling for configuration response
      // Notifications should work, but poll as backup
      _pollForConfigurationAsync();

      // Now we're waiting for config - enable the listener to complete on error
      waitingForConfig = true;

      // Wait for config to complete with timeout
      AppLogging.protocol('Protocol: Waiting for configCompleteId...');
      await _configCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Configuration timed out waiting for device response',
          );
        },
      );
      AppLogging.debug('✅ Protocol: Configuration was received');
    } catch (e, st) {
      AppLogging.debug('❌ Protocol: Configuration failed: $e');
      AppLogging.debug('❌ Protocol: Stacktrace: $st');
      // Convert FlutterBluePlus auth errors to user-friendly message
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('authentication') ||
          errorStr.contains('encryption') ||
          errorStr.contains('insufficient')) {
        throw Exception(
          'Connection failed - please try again and enter the PIN when prompted',
        );
      }

      // Wrap all other errors into an Exception to avoid bubbling Error types
      // (e.g., FlutterError) which are surfaced as non-fatal FlutterErrors in Crashlytics.
      throw Exception('Protocol configuration failed: $e');
    }

    // Start RSSI polling timer (every 2 seconds)
    _startRssiPolling();

    AppLogging.protocol('Protocol service started');
  }

  /// Start periodic RSSI polling from BLE connection
  void _startRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final rssi = await _transport.readRssi();
      if (rssi != null && rssi != _lastRssi) {
        _lastRssi = rssi;
        _rssiController.add(rssi);
      }
    });
  }

  /// Poll for configuration data in background (non-blocking)
  void _pollForConfigurationAsync() {
    if (_pollingConfig) {
      AppLogging.protocol('Config poll already running, skipping');
      return;
    }
    _pollingConfig = true;
    int pollCount = 0;
    const maxPolls = 100;

    Future.doWhile(() async {
      if (_configurationComplete || pollCount >= maxPolls) {
        _pollingConfig = false;
        return false; // Stop polling
      }
      if (!_transport.isConnected) {
        _pollingConfig = false;
        return false;
      }

      try {
        await _transport.pollOnce();
        pollCount++;
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (e) {
        AppLogging.protocol('Poll error: $e');
      }
      return true; // Continue polling
    });
  }

  /// Stop listening
  void stop() {
    AppLogging.protocol('Stopping protocol service');
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _transportStateSubscription?.cancel();
    _transportStateSubscription = null;
    if (_configCompleter != null && !_configCompleter!.isCompleted) {
      _configCompleter!.completeError('Service stopped');
    }
    _configCompleter = null;
    if (_dataSubscription != null) {
      _dataSubscription?.cancel();
      AppLogging.protocol('DATA_SUBSCRIPTION_CANCELLED');
      _dataSubscription = null;
    }
    _framer.clear();
    _configurationComplete = false;
  }

  /// Handle incoming data from transport
  void _handleData(List<int> data) {
    unawaited(_handleDataAsync(data));
  }

  Future<void> _handleDataAsync(List<int> data) async {
    try {
      AppLogging.protocol('Received ${data.length} bytes');

      if (_transport.requiresFraming) {
        // Serial/USB: Extract packets using framer
        final packets = _framer.addData(data);

        for (final packet in packets) {
          AppLogging.protocol('MESH_FRAME_OK len=${packet.length}');
          await _processPacket(packet);
        }
      } else {
        // BLE: Data is already a complete raw protobuf
        if (data.isNotEmpty) {
          AppLogging.protocol('MESH_FRAME_OK len=${data.length}');
          await _processPacket(data);
        }
      }
    } catch (e, stack) {
      AppLogging.protocol('Transport packet error: $e\n$stack');
    }
  }

  @visibleForTesting
  Future<void> handleIncomingPacket(List<int> packet) =>
      _handleDataAsync(packet);

  /// Process a complete packet
  Future<void> _processPacket(List<int> packet) async {
    try {
      AppLogging.protocol('Processing packet: ${packet.length} bytes');

      final fromRadio = pb.FromRadio.fromBuffer(packet);

      // Debug: log which payload variant we got
      final variant = fromRadio.whichPayloadVariant();
      AppLogging.protocol('FromRadio payload variant: $variant');

      if (fromRadio.hasPacket()) {
        await _handleMeshPacket(fromRadio.packet);
      } else if (fromRadio.hasMyInfo()) {
        _handleMyNodeInfo(fromRadio.myInfo);
      } else if (fromRadio.hasNodeInfo()) {
        _handleNodeInfo(fromRadio.nodeInfo);
      } else if (fromRadio.hasChannel()) {
        _handleChannel(fromRadio.channel);
      } else if (fromRadio.hasConfig()) {
        // Handle config sent during initial boot - this includes LoRa config with region!
        _handleFromRadioConfig(fromRadio.config);
      } else if (fromRadio.hasMetadata()) {
        _handleFromRadioMetadata(fromRadio.metadata);
      } else if (fromRadio.hasClientNotification()) {
        _handleClientNotification(fromRadio.clientNotification);
      } else if (fromRadio.hasConfigCompleteId()) {
        AppLogging.protocol(
          'Configuration complete! ID: ${fromRadio.configCompleteId}',
        );
        AppLogging.protocol(
          'Configuration complete: ${fromRadio.configCompleteId}',
        );
        _configurationComplete = true;
        if (_configCompleter != null && !_configCompleter!.isCompleted) {
          _configCompleter!.complete();
        }

        // Log summary of all nodes and their position status
        AppLogging.protocol('=== NODE SUMMARY AFTER CONFIG COMPLETE ===');
        AppLogging.protocol('Total nodes: ${_nodes.length}');
        for (final node in _nodes.values) {
          AppLogging.protocol(
            '  Node ${node.nodeNum}: "${node.longName}" hasPosition=${node.hasPosition}, '
            'lat=${node.latitude}, lng=${node.longitude}',
          );
        }
        AppLogging.protocol('==========================================');

        // Request additional config after initial sync
        // Using unawaited calls with error handling to prevent crashes on disconnect
        _requestPostConfigData();
      }
    } catch (e, stack) {
      AppLogging.protocol('Error processing packet: $e\n$stack');
    }
  }

  /// Request additional configuration data after initial config sync completes.
  /// Uses staggered delays and error handling to prevent crashes if the device
  /// disconnects during the process.
  void _requestPostConfigData() {
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!_transport.isConnected) return;
      try {
        await getLoRaConfig();
      } catch (e) {
        AppLogging.protocol('Failed to get LoRa config: $e');
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!_transport.isConnected) return;
      try {
        await getPositionConfig();
      } catch (e) {
        AppLogging.protocol('Failed to get Position config: $e');
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!_transport.isConnected) return;
      try {
        await getDeviceMetadata();
      } catch (e) {
        AppLogging.protocol('Failed to get device metadata: $e');
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!_transport.isConnected) return;
      try {
        await _requestAllChannelDetails();
      } catch (e) {
        AppLogging.protocol('Failed to request channel details: $e');
      }
    });

    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!_transport.isConnected) return;
      try {
        await requestAllPositions();
      } catch (e) {
        AppLogging.protocol('Failed to request positions: $e');
      }
    });
  }

  /// Handle incoming mesh packet
  Future<void> _handleMeshPacket(pb.MeshPacket packet) async {
    AppLogging.protocol(
      'Handling mesh packet from ${packet.from} to ${packet.to}',
    );

    // Update lastHeard for the sender node (keeps node online status accurate)
    // This ensures any packet from a node updates its online status
    _updateNodeLastHeard(packet.from);

    // Extract and emit SNR from received packets
    if (packet.hasRxSnr()) {
      final snr = packet.rxSnr.toDouble();
      if (snr != _lastSnr) {
        _lastSnr = snr;
        _snrController.add(snr);
      }
    }

    if (packet.hasDecoded()) {
      final data = packet.decoded;

      if (data.portnum == pn.PortNum.TEXT_MESSAGE_APP) {
        final key = MeshPacketKey(
          packetType: 'channel_message',
          senderNodeId: packet.from,
          packetId: packet.id,
          channelIndex: packet.channel,
        );

        final seen = await _dedupeStore.hasSeen(key, ttl: _messagePacketTtl);
        if (seen) {
          AppLogging.messages(
            '📨 Duplicate message packet ignored: packetId=${packet.id}, '
            'from=${packet.from.toRadixString(16)}, channel=${packet.channel}',
          );
          return;
        }

        await _dedupeStore.markSeen(key, ttl: _messagePacketTtl);
      }

      switch (data.portnum) {
        case pn.PortNum.TEXT_MESSAGE_APP:
          _handleTextMessage(packet, data);
          break;
        case pn.PortNum.POSITION_APP:
          _handlePositionUpdate(packet, data);
          break;
        case pn.PortNum.NODEINFO_APP:
          _handleNodeInfoUpdate(packet, data);
          break;
        case pn.PortNum.ROUTING_APP:
          _handleRoutingMessage(packet, data);
          break;
        case pn.PortNum.TELEMETRY_APP:
          _handleTelemetry(packet, data);
          break;
        case pn.PortNum.ADMIN_APP:
          _handleAdminMessage(packet, data);
          break;
        case pn.PortNum.PRIVATE_APP:
          _handleSignalMessage(packet, data);
          break;
        case pn.PortNum.DETECTION_SENSOR_APP:
          _handleDetectionSensorMessage(packet, data);
          break;
        case pn.PortNum.NODE_STATUS_APP:
          _handleNodeStatusMessage(packet, data);
          break;
        default:
          AppLogging.protocol(
            'Received message with portnum: ${data.portnum} (${data.portnum.value})',
          );
      }
    }
  }

  /// Handle incoming signal packets (PRIVATE_APP portnum)
  void _handleSignalMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      AppLogging.signals(
        'RX_SIGNAL_RAW packetId=${packet.id} from=${packet.from.toRadixString(16)} '
        'to=${packet.to.toRadixString(16)} bytes=${data.payload.length}',
      );

      // Ignore our own signals echoed back
      if (packet.from == _myNodeNum) {
        AppLogging.signals('Ignoring own signal echo');
        return;
      }

      // Calculate hop count from mesh packet metadata
      // hopStart field is not available in current generated protobuf
      // Set to null until protobuf is updated to include hopStart
      final int? hopCount = null;
      AppLogging.signals(
        '📡 Signals: hopCount unavailable (hopStart not in generated proto) -> storing null',
      );

      final signalPacket = MeshSignalPacket.fromPayload(
        packet.from,
        data.payload,
        hopCount: hopCount,
        packetId: packet.id,
      );

      AppLogging.signals(
        'SIGNAL_PARSE_OK packetId=${signalPacket.packetId} '
        'signalId=${signalPacket.signalId ?? "none"} '
        'sender=${packet.from.toRadixString(16)} ttl=${signalPacket.ttlMinutes}',
      );

      AppLogging.signals(
        'Received mesh signal from !${packet.from.toRadixString(16)}: '
        '"${signalPacket.content.length > 30 ? '${signalPacket.content.substring(0, 30)}...' : signalPacket.content}" '
        '(ttl=${signalPacket.ttlMinutes}m)',
      );

      _signalController.add(signalPacket);
    } catch (e) {
      AppLogging.signals('Failed to parse signal packet: $e');
    }
  }

  /// Handle detection sensor events (DETECTION_SENSOR_APP portnum)
  void _handleDetectionSensorMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      AppLogging.protocol(
        'RX_DETECTION_SENSOR from=${packet.from.toRadixString(16)} '
        'bytes=${data.payload.length}',
      );

      final event = DetectionSensorEvent.fromPayload(packet.from, data.payload);

      AppLogging.protocol(
        'Detection sensor event: ${event.sensorName} = '
        '${event.detected ? "DETECTED" : "CLEAR"} from !${packet.from.toRadixString(16)}',
      );

      _detectionSensorEventController.add(event);
    } catch (e) {
      AppLogging.protocol('Failed to parse detection sensor message: $e');
    }
  }

  /// Handle node status messages (NODE_STATUS_APP portnum - v2.7.18)
  void _handleNodeStatusMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      final statusMsg = pb.StatusMessage.fromBuffer(data.payload);
      final status = statusMsg.hasStatus() ? statusMsg.status : null;

      AppLogging.protocol(
        'RX_NODE_STATUS from=${packet.from.toRadixString(16)} '
        'status="${status ?? "empty"}"',
      );

      if (status != null && status.isNotEmpty) {
        // Update node with status message
        final existingNode = _nodes[packet.from];
        if (existingNode != null) {
          final updatedNode = existingNode.copyWith(
            nodeStatus: status,
            lastHeard: DateTime.now(),
          );
          _nodes[packet.from] = updatedNode;
          _nodeController.add(updatedNode);
        } else {
          // Create a minimal node entry if we don't have one
          final newNode = MeshNode(
            nodeNum: packet.from,
            nodeStatus: status,
            lastHeard: DateTime.now(),
          );
          _nodes[packet.from] = newNode;
          _nodeController.add(newNode);
        }
      }
    } catch (e) {
      AppLogging.protocol('Failed to parse node status message: $e');
    }
  }

  /// Handle admin message responses
  void _handleAdminMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      final adminMsg = admin.AdminMessage.fromBuffer(data.payload);
      AppLogging.protocol(
        'Admin message variant: ${adminMsg.whichPayloadVariant()}',
      );

      if (adminMsg.hasGetConfigResponse()) {
        final config = adminMsg.getConfigResponse;

        // Handle LoRa config
        if (config.hasLora()) {
          final loraConfig = config.lora;
          AppLogging.protocol(
            'Received LoRa config - region: ${loraConfig.region.name}',
          );
          _currentRegion = loraConfig.region;
          _currentLoraConfig = loraConfig;
          _regionController.add(loraConfig.region);
          _loraConfigController.add(loraConfig);
        }

        // Handle Position config
        if (config.hasPosition()) {
          final posConfig = config.position;
          AppLogging.debug(
            '📍 Received Position config: '
            'gpsEnabled=${posConfig.gpsEnabled}, '
            'gpsMode=${posConfig.gpsMode}, '
            'fixedPosition=${posConfig.fixedPosition}, '
            'positionBroadcastSecs=${posConfig.positionBroadcastSecs}, '
            'gpsUpdateInterval=${posConfig.gpsUpdateInterval}',
          );
          _currentPositionConfig = posConfig;
          _positionConfigController.add(posConfig);
        }

        // Handle Device config
        if (config.hasDevice()) {
          final deviceConfig = config.device;
          AppLogging.protocol(
            'Received Device config - role: ${deviceConfig.role.name}',
          );
          _currentDeviceConfig = deviceConfig;
          _deviceConfigController.add(deviceConfig);
        }

        // Handle Display config
        if (config.hasDisplay()) {
          final displayConfig = config.display;
          AppLogging.protocol(
            'Received Display config - screenOnSecs: ${displayConfig.screenOnSecs}',
          );
          _currentDisplayConfig = displayConfig;
          _displayConfigController.add(displayConfig);
        }

        // Handle Power config
        if (config.hasPower()) {
          final powerConfig = config.power;
          AppLogging.protocol(
            'Received Power config - isPowerSaving: ${powerConfig.isPowerSaving}',
          );
          _currentPowerConfig = powerConfig;
          _powerConfigController.add(powerConfig);
        }

        // Handle Network config
        if (config.hasNetwork()) {
          final networkConfig = config.network;
          AppLogging.protocol(
            'Received Network config - wifiEnabled: ${networkConfig.wifiEnabled}',
          );
          _currentNetworkConfig = networkConfig;
          _networkConfigController.add(networkConfig);
        }

        // Handle Bluetooth config
        if (config.hasBluetooth()) {
          final btConfig = config.bluetooth;
          AppLogging.protocol(
            'Received Bluetooth config - enabled: ${btConfig.enabled}',
          );
          _currentBluetoothConfig = btConfig;
          _bluetoothConfigController.add(btConfig);
        }

        // Handle Security config
        if (config.hasSecurity()) {
          final secConfig = config.security;
          AppLogging.protocol(
            'Received Security config - isManaged: ${secConfig.isManaged}',
          );
          _currentSecurityConfig = secConfig;
          _securityConfigController.add(secConfig);
        }
      } else if (adminMsg.hasGetModuleConfigResponse()) {
        final moduleConfig = adminMsg.getModuleConfigResponse;

        // Handle MQTT config
        if (moduleConfig.hasMqtt()) {
          final mqttConfig = moduleConfig.mqtt;
          AppLogging.protocol(
            'Received MQTT config - enabled: ${mqttConfig.enabled}',
          );
          _currentMqttConfig = mqttConfig;
          _mqttConfigController.add(mqttConfig);
        }

        // Handle Telemetry config
        if (moduleConfig.hasTelemetry()) {
          final telemetryConfig = moduleConfig.telemetry;
          AppLogging.protocol(
            'Received Telemetry config - deviceInterval: ${telemetryConfig.deviceUpdateInterval}',
          );
          _currentTelemetryConfig = telemetryConfig;
          _telemetryConfigController.add(telemetryConfig);
        }

        // Handle PAX counter config
        if (moduleConfig.hasPaxcounter()) {
          final paxConfig = moduleConfig.paxcounter;
          AppLogging.protocol(
            'Received PAX counter config - enabled: ${paxConfig.enabled}',
          );
          _currentPaxCounterConfig = paxConfig;
          _paxCounterConfigController.add(paxConfig);
        }

        // Handle Ambient Lighting config
        if (moduleConfig.hasAmbientLighting()) {
          final ambientConfig = moduleConfig.ambientLighting;
          AppLogging.protocol(
            'Received Ambient Lighting config - ledState: ${ambientConfig.ledState}',
          );
          _currentAmbientLightingConfig = ambientConfig;
          _ambientLightingConfigController.add(ambientConfig);
        }

        // Handle Serial config
        if (moduleConfig.hasSerial()) {
          final serialConfig = moduleConfig.serial;
          AppLogging.protocol(
            'Received Serial config - enabled: ${serialConfig.enabled}',
          );
          _currentSerialConfig = serialConfig;
          _serialConfigController.add(serialConfig);
        }

        // Handle Store Forward config
        if (moduleConfig.hasStoreForward()) {
          final sfConfig = moduleConfig.storeForward;
          AppLogging.protocol(
            'Received Store Forward config - enabled: ${sfConfig.enabled}',
          );
          _currentStoreForwardConfig = sfConfig;
          _storeForwardConfigController.add(sfConfig);
        }

        // Handle Detection Sensor config
        if (moduleConfig.hasDetectionSensor()) {
          final dsConfig = moduleConfig.detectionSensor;
          AppLogging.protocol(
            'Received Detection Sensor config - enabled: ${dsConfig.enabled}',
          );
          _currentDetectionSensorConfig = dsConfig;
          _detectionSensorConfigController.add(dsConfig);
        }

        // Handle Range Test config
        if (moduleConfig.hasRangeTest()) {
          final rtConfig = moduleConfig.rangeTest;
          AppLogging.protocol(
            'Received Range Test config - enabled: ${rtConfig.enabled}',
          );
          _currentRangeTestConfig = rtConfig;
          _rangeTestConfigController.add(rtConfig);
        }

        // Handle External Notification config
        if (moduleConfig.hasExternalNotification()) {
          final extNotifConfig = moduleConfig.externalNotification;
          AppLogging.protocol(
            'Received External Notification config - enabled: ${extNotifConfig.enabled}',
          );
          _currentExternalNotificationConfig = extNotifConfig;
          _externalNotificationConfigController.add(extNotifConfig);
        }

        // Handle Canned Message config
        if (moduleConfig.hasCannedMessage()) {
          final cannedConfig = moduleConfig.cannedMessage;
          AppLogging.protocol(
            'Received Canned Message config - enabled: ${cannedConfig.enabled}',
          );
          _currentCannedMessageConfig = cannedConfig;
          _cannedMessageConfigController.add(cannedConfig);
        }
      } else if (adminMsg.hasGetChannelResponse()) {
        // Handle channel response - update local channel list
        final channel = adminMsg.getChannelResponse;
        AppLogging.protocol(
          'Received channel response: index=${channel.index}, role=${channel.role.name}',
        );
        _handleChannel(channel);
      } else if (adminMsg.hasGetDeviceMetadataResponse()) {
        // Handle device metadata response - update node with firmware version
        final metadata = adminMsg.getDeviceMetadataResponse;
        AppLogging.debug(
          '📋 Received device metadata: firmware="${metadata.firmwareVersion}", '
          'hwModel=${metadata.hwModel.name}',
        );
        AppLogging.protocol(
          'Received device metadata: firmwareVersion=${metadata.firmwareVersion}, '
          'hwModel=${metadata.hwModel.name}, hasWifi=${metadata.hasWifi}',
        );

        // Update our node with the firmware version and other metadata
        if (_myNodeNum != null && _nodes.containsKey(_myNodeNum)) {
          final existingNode = _nodes[_myNodeNum]!;

          // Determine hardware model - use metadata if valid, otherwise infer
          String? hwModelName;
          if (metadata.hwModel != pb.HardwareModel.UNSET) {
            hwModelName = _formatHardwareModel(metadata.hwModel);
            AppLogging.protocol('Hardware model from metadata: $hwModelName');
          } else {
            // Try to infer from BLE model number or device name
            AppLogging.protocol(
              'Hardware model UNSET in metadata, attempting to infer (bleModel="$_bleModelNumber", deviceName="$_deviceName")',
            );
            hwModelName = _inferHardwareModel();
            if (hwModelName == null) {
              AppLogging.protocol(
                'Could not infer hardware model - device firmware may need update',
              );
            }
          }

          final updatedNode = existingNode.copyWith(
            firmwareVersion: metadata.firmwareVersion.isNotEmpty
                ? metadata.firmwareVersion
                : null,
            hasWifi: metadata.hasWifi,
            hasBluetooth: metadata.hasBluetooth,
            hardwareModel: hwModelName ?? existingNode.hardwareModel,
          );
          _nodes[_myNodeNum!] = updatedNode;
          _nodeController.add(updatedNode);
          AppLogging.protocol('Updated node $_myNodeNum with device metadata');
        }
      } else if (adminMsg.hasGetOwnerResponse()) {
        // Handle response to getOwnerRequest - contains remote node's User info
        final user = adminMsg.getOwnerResponse;
        AppLogging.protocol(
          '🔑 📥 Received getOwnerResponse from ${packet.from.toRadixString(16)}: ${user.longName} (${user.shortName})',
        );
        AppLogging.protocol(
          '🔑 📥 Public key present: ${user.publicKey.isNotEmpty} (${user.publicKey.length} bytes)',
        );
        AppLogging.protocol(
          'Received owner info from ${packet.from}: ${user.longName}',
        );

        // Update the node with the received user info
        final existingNode = _nodes[packet.from];
        if (existingNode != null) {
          String? hwModel;
          if (user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET) {
            hwModel = _formatHardwareModel(user.hwModel);
          }

          final updatedNode = existingNode.copyWith(
            longName: user.longName.isNotEmpty
                ? user.longName
                : existingNode.longName,
            shortName: user.shortName.isNotEmpty
                ? user.shortName
                : existingNode.shortName,
            userId: user.hasId() ? user.id : existingNode.userId,
            hardwareModel: hwModel ?? existingNode.hardwareModel,
            role: user.hasRole() ? user.role.name : existingNode.role,
            hasPublicKey: user.publicKey.isNotEmpty,
            lastHeard: DateTime.now(),
          );
          _nodes[packet.from] = updatedNode;
          _nodeController.add(updatedNode);
          AppLogging.protocol(
            '🔑 ✅ Updated node ${packet.from.toRadixString(16)} with fresh user info',
          );
        } else {
          // Create new node entry
          final colors = [
            0xFF1976D2,
            0xFFD32F2F,
            0xFF388E3C,
            0xFFF57C00,
            0xFF7B1FA2,
            0xFF00796B,
            0xFFC2185B,
          ];
          final avatarColor = colors[packet.from % colors.length];

          String? hwModel;
          if (user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET) {
            hwModel = _formatHardwareModel(user.hwModel);
          }

          final newNode = MeshNode(
            nodeNum: packet.from,
            longName: user.longName.isNotEmpty
                ? sanitizeUtf16(user.longName)
                : null,
            shortName: user.shortName.isNotEmpty
                ? sanitizeUtf16(user.shortName)
                : null,
            userId: user.hasId() ? user.id : null,
            hardwareModel: hwModel,
            role: user.hasRole() ? user.role.name : 'CLIENT',
            hasPublicKey: user.publicKey.isNotEmpty,
            lastHeard: DateTime.now(),
            avatarColor: avatarColor,
            isFavorite: false,
          );
          _nodes[packet.from] = newNode;
          _nodeController.add(newNode);
          AppLogging.protocol(
            '🔑 ✅ Created new node ${packet.from.toRadixString(16)} from owner response',
          );
        }
      }
    } catch (e) {
      AppLogging.protocol('Error handling admin message: $e');
    }
  }

  /// Handle Config from FromRadio (sent during initial config boot sequence)
  /// This includes LoRa config with the region!
  void _handleFromRadioConfig(config_pb.Config config) {
    // Handle LoRa config - this is where we get the region during initial boot
    if (config.hasLora()) {
      final loraConfig = config.lora;
      AppLogging.debug(
        '📡 FromRadio LoRa config: region=${loraConfig.region.name}, '
        'modemPreset=${loraConfig.modemPreset.name}',
      );
      _currentRegion = loraConfig.region;
      _currentLoraConfig = loraConfig;
      _regionController.add(loraConfig.region);
      _loraConfigController.add(loraConfig);
    }

    // Handle Position config
    if (config.hasPosition()) {
      final posConfig = config.position;
      AppLogging.debug(
        '📍 FromRadio Position config: gpsEnabled=${posConfig.gpsEnabled}, '
        'gpsMode=${posConfig.gpsMode}',
      );
      _currentPositionConfig = posConfig;
      _positionConfigController.add(posConfig);
    }

    // Handle Device config
    if (config.hasDevice()) {
      final deviceConfig = config.device;
      AppLogging.liveActivity(
        'FromRadio Device config: role=${deviceConfig.role.name}',
      );
      _currentDeviceConfig = deviceConfig;
      _deviceConfigController.add(deviceConfig);
    }

    // Handle Power config
    if (config.hasPower()) {
      final powerConfig = config.power;
      _currentPowerConfig = powerConfig;
      _powerConfigController.add(powerConfig);
    }

    // Handle Network config
    if (config.hasNetwork()) {
      final networkConfig = config.network;
      _currentNetworkConfig = networkConfig;
      _networkConfigController.add(networkConfig);
    }

    // Handle Bluetooth config
    if (config.hasBluetooth()) {
      final btConfig = config.bluetooth;
      _currentBluetoothConfig = btConfig;
      _bluetoothConfigController.add(btConfig);
    }

    // Handle Display config
    if (config.hasDisplay()) {
      final displayConfig = config.display;
      _currentDisplayConfig = displayConfig;
      _displayConfigController.add(displayConfig);
    }

    // Handle Security config
    if (config.hasSecurity()) {
      final secConfig = config.security;
      _currentSecurityConfig = secConfig;
      _securityConfigController.add(secConfig);
    }
  }

  /// Handle ClientNotification from firmware (config errors, warnings, etc.)
  /// These are important messages that should be displayed to the user.
  void _handleClientNotification(pb.ClientNotification notification) {
    final levelName = notification.level.name;
    final message = notification.message;

    // Log with appropriate level
    if (notification.level == pb.LogRecord_Level.ERROR ||
        notification.level == pb.LogRecord_Level.CRITICAL) {
      AppLogging.protocol('⚠️ Client Notification [ERROR]: $message');
    } else if (notification.level == pb.LogRecord_Level.WARNING) {
      AppLogging.protocol('⚠️ Client Notification [WARNING]: $message');
    } else {
      AppLogging.protocol('ℹ️ Client Notification [$levelName]: $message');
    }

    // Emit to stream so UI can display to user
    _clientNotificationController.add(notification);
  }

  /// Handle DeviceMetadata from FromRadio (sent during initial config)
  void _handleFromRadioMetadata(pb.DeviceMetadata metadata) {
    AppLogging.debug(
      '📋 FromRadio metadata: firmware="${metadata.firmwareVersion}", '
      'hwModel=${metadata.hwModel.name}',
    );
    AppLogging.protocol(
      'FromRadio metadata: firmwareVersion=${metadata.firmwareVersion}, '
      'hwModel=${metadata.hwModel.name}, hasWifi=${metadata.hasWifi}',
    );

    // Update our node with the firmware version and other metadata
    if (_myNodeNum != null && _nodes.containsKey(_myNodeNum)) {
      final existingNode = _nodes[_myNodeNum]!;

      // Determine hardware model - use metadata if valid, otherwise infer
      String? hwModelName;
      if (metadata.hwModel != pb.HardwareModel.UNSET) {
        hwModelName = _formatHardwareModel(metadata.hwModel);
        AppLogging.protocol(
          'Hardware model from FromRadio metadata: $hwModelName',
        );
      } else {
        // Try to infer from BLE model number or device name
        AppLogging.protocol(
          'Hardware model UNSET in FromRadio metadata, attempting to infer',
        );
        hwModelName = _inferHardwareModel();
      }

      final updatedNode = existingNode.copyWith(
        firmwareVersion: metadata.firmwareVersion.isNotEmpty
            ? metadata.firmwareVersion
            : null,
        hasWifi: metadata.hasWifi,
        hasBluetooth: metadata.hasBluetooth,
        hardwareModel: hwModelName ?? existingNode.hardwareModel,
      );
      _nodes[_myNodeNum!] = updatedNode;
      _nodeController.add(updatedNode);
      AppLogging.debug(
        '📋 Updated node $_myNodeNum with FromRadio metadata: '
        'firmware="${updatedNode.firmwareVersion}", hw="${updatedNode.hardwareModel}"',
      );
    } else {
      // myNodeNum not set yet - store metadata for later
      AppLogging.debug(
        '📋 FromRadio metadata received before myNodeNum set - caching',
      );
      _pendingMetadata = metadata;
    }
  }

  /// Cached metadata received before myNodeNum was set
  pb.DeviceMetadata? _pendingMetadata;

  /// Handle text message
  void _handleTextMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      final text = sanitizeUtf16(
        utf8.decode(data.payload, allowMalformed: true),
      );
      AppLogging.protocol('Text message from ${packet.from}: $text');

      // Look up sender node info to cache in message
      final senderNode = _nodes[packet.from];
      String? senderLongName;
      String? senderShortName;
      int? senderAvatarColor;

      if (senderNode != null) {
        senderLongName = senderNode.longName;
        senderShortName = senderNode.shortName;
        senderAvatarColor = senderNode.avatarColor;
      }

      // If sender is unknown, create a placeholder node
      if (senderNode == null) {
        AppLogging.protocol(
          'Creating placeholder node for unknown sender ${packet.from}',
        );
        final placeholderNode = MeshNode(
          nodeNum: packet.from,
          lastHeard: DateTime.now(),
          firstHeard: DateTime.now(),
        );
        _nodes[packet.from] = placeholderNode;
        _nodeController.add(placeholderNode);
      }

      final message = Message(
        from: packet.from,
        to: packet.to,
        text: text,
        channel: packet.channel,
        received: true,
        senderLongName: senderLongName,
        senderShortName: senderShortName,
        senderAvatarColor: senderAvatarColor,
      );

      _messageController.add(message);
    } catch (e) {
      AppLogging.protocol('Error decoding text message: $e');
    }
  }

  /// Handle routing message (ACK/NAK/errors)
  void _handleRoutingMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      // If requestId is set, it references the original packet that this is a response to
      final requestId = data.requestId;

      AppLogging.protocol(
        'Routing message received: requestId=$requestId, from=${packet.from}, '
        'to=${packet.to}, packetId=${packet.id}',
      );

      if (requestId == 0) {
        AppLogging.protocol('Routing message with no requestId, ignoring');
        return;
      }

      // Parse the Routing protobuf message
      final routing = pb.Routing.fromBuffer(data.payload);
      final variant = routing.whichVariant();

      AppLogging.protocol('Routing variant: $variant');

      RoutingError routingError;
      bool delivered;

      switch (variant) {
        case pb.Routing_Variant.errorReason:
          // Error response - check the error code
          final errorCode = routing.errorReason.value;
          routingError = RoutingError.fromCode(errorCode);
          delivered = routingError.isSuccess;
          AppLogging.protocol(
            'Routing error for packet $requestId: ${routingError.message} (code=$errorCode, name=${routing.errorReason.name})',
          );
          break;

        case pb.Routing_Variant.routeRequest:
          AppLogging.protocol('Route request received for packet $requestId');
          // Route requests don't indicate delivery status
          return;

        case pb.Routing_Variant.routeReply:
          AppLogging.protocol('Route reply received for packet $requestId');
          // Route replies don't indicate delivery status
          return;

        case pb.Routing_Variant.notSet:
          // Empty routing message typically means success (ACK)
          routingError = RoutingError.fromCode(0);
          delivered = true;
          AppLogging.protocol(
            'Empty routing message (ACK) for packet $requestId',
          );
          break;
      }

      // Check if we're tracking this packet
      final messageId = _pendingMessages[requestId];
      if (messageId != null) {
        _pendingMessages.remove(requestId);
      }

      // Emit delivery update
      final update = MessageDeliveryUpdate(
        packetId: requestId,
        delivered: delivered,
        error: delivered ? null : routingError,
      );
      _deliveryController.add(update);
    } catch (e) {
      AppLogging.protocol('Error handling routing message: $e');
    }
  }

  /// Handle telemetry message (battery, voltage, etc.)
  void _handleTelemetry(pb.MeshPacket packet, pb.Data data) {
    try {
      // TELEMETRY_APP payload is a Telemetry message wrapper with oneof variant
      final telem = telemetry.Telemetry.fromBuffer(data.payload);

      // Check which variant we received
      final variant = telem.whichVariant();
      AppLogging.protocol('Telemetry variant: $variant from ${packet.from}');

      int? batteryLevel;
      double? voltage;
      double? channelUtil;
      double? airUtilTx;
      int? uptimeSeconds;

      switch (variant) {
        case telemetry.Telemetry_Variant.deviceMetrics:
          final deviceMetrics = telem.deviceMetrics;
          batteryLevel = deviceMetrics.hasBatteryLevel()
              ? deviceMetrics.batteryLevel
              : null;
          voltage = deviceMetrics.hasVoltage()
              ? deviceMetrics.voltage.toDouble()
              : null;
          channelUtil = deviceMetrics.hasChannelUtilization()
              ? deviceMetrics.channelUtilization.toDouble()
              : null;
          airUtilTx = deviceMetrics.hasAirUtilTx()
              ? deviceMetrics.airUtilTx.toDouble()
              : null;
          uptimeSeconds = deviceMetrics.hasUptimeSeconds()
              ? deviceMetrics.uptimeSeconds
              : null;

          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'DeviceMetrics from ${packet.from}: battery=$batteryLevel%, voltage=${voltage}V, '
              'channelUtil=$channelUtil%, airUtilTx=$airUtilTx%, uptime=${uptimeSeconds}s',
            );
          }

          // Update node with device metrics
          final existingDeviceNode = _nodes[packet.from];
          if (existingDeviceNode != null) {
            final updatedDeviceNode = existingDeviceNode.copyWith(
              batteryLevel: batteryLevel,
              voltage: voltage,
              channelUtilization: channelUtil,
              airUtilTx: airUtilTx,
              uptimeSeconds: uptimeSeconds,
              lastHeard: DateTime.now(),
            );
            _nodes[packet.from] = updatedDeviceNode;
            _nodeController.add(updatedDeviceNode);
          }
          break;

        case telemetry.Telemetry_Variant.environmentMetrics:
          final envMetrics = telem.environmentMetrics;
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'EnvironmentMetrics from ${packet.from}: '
              'temp=${envMetrics.hasTemperature() ? envMetrics.temperature : "N/A"}°C, '
              'humidity=${envMetrics.hasRelativeHumidity() ? envMetrics.relativeHumidity : "N/A"}%, '
              'pressure=${envMetrics.hasBarometricPressure() ? envMetrics.barometricPressure : "N/A"}hPa',
            );
          }
          // Update node with all environment metrics
          final existingEnvNode = _nodes[packet.from];
          if (existingEnvNode != null) {
            final updatedEnvNode = existingEnvNode.copyWith(
              temperature: envMetrics.hasTemperature()
                  ? envMetrics.temperature.toDouble()
                  : null,
              humidity: envMetrics.hasRelativeHumidity()
                  ? envMetrics.relativeHumidity.toDouble()
                  : null,
              barometricPressure: envMetrics.hasBarometricPressure()
                  ? envMetrics.barometricPressure.toDouble()
                  : null,
              gasResistance: envMetrics.hasGasResistance()
                  ? envMetrics.gasResistance.toDouble()
                  : null,
              iaq: envMetrics.hasIaq() ? envMetrics.iaq : null,
              lux: envMetrics.hasLux() ? envMetrics.lux.toDouble() : null,
              whiteLux: envMetrics.hasWhiteLux()
                  ? envMetrics.whiteLux.toDouble()
                  : null,
              irLux: envMetrics.hasIrLux() ? envMetrics.irLux.toDouble() : null,
              uvLux: envMetrics.hasUvLux() ? envMetrics.uvLux.toDouble() : null,
              windDirection: envMetrics.hasWindDirection()
                  ? envMetrics.windDirection
                  : null,
              windSpeed: envMetrics.hasWindSpeed()
                  ? envMetrics.windSpeed.toDouble()
                  : null,
              windGust: envMetrics.hasWindGust()
                  ? envMetrics.windGust.toDouble()
                  : null,
              windLull: envMetrics.hasWindLull()
                  ? envMetrics.windLull.toDouble()
                  : null,
              weight: envMetrics.hasWeight()
                  ? envMetrics.weight.toDouble()
                  : null,
              radiation: envMetrics.hasRadiation()
                  ? envMetrics.radiation.toDouble()
                  : null,
              rainfall1h: envMetrics.hasRainfall1h()
                  ? envMetrics.rainfall1h.toDouble()
                  : null,
              rainfall24h: envMetrics.hasRainfall24h()
                  ? envMetrics.rainfall24h.toDouble()
                  : null,
              soilMoisture: envMetrics.hasSoilMoisture()
                  ? envMetrics.soilMoisture
                  : null,
              soilTemperature: envMetrics.hasSoilTemperature()
                  ? envMetrics.soilTemperature.toDouble()
                  : null,
              envDistance: envMetrics.hasDistance()
                  ? envMetrics.distance.toDouble()
                  : null,
              envCurrent: envMetrics.hasCurrent()
                  ? envMetrics.current.toDouble()
                  : null,
              envVoltage: envMetrics.hasVoltage()
                  ? envMetrics.voltage.toDouble()
                  : null,
              lastHeard: DateTime.now(),
            );
            _nodes[packet.from] = updatedEnvNode;
            _nodeController.add(updatedEnvNode);
          }
          return;

        case telemetry.Telemetry_Variant.airQualityMetrics:
          final aqMetrics = telem.airQualityMetrics;
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'AirQualityMetrics from ${packet.from}: '
              'PM2.5=${aqMetrics.hasPm25Standard() ? aqMetrics.pm25Standard : "N/A"}ug/m3, '
              'CO2=${aqMetrics.hasCo2() ? aqMetrics.co2 : "N/A"}ppm',
            );
          }
          // Update node with air quality metrics
          final existingAqNode = _nodes[packet.from];
          if (existingAqNode != null) {
            final updatedAqNode = existingAqNode.copyWith(
              pm10Standard: aqMetrics.hasPm10Standard()
                  ? aqMetrics.pm10Standard
                  : null,
              pm25Standard: aqMetrics.hasPm25Standard()
                  ? aqMetrics.pm25Standard
                  : null,
              pm100Standard: aqMetrics.hasPm100Standard()
                  ? aqMetrics.pm100Standard
                  : null,
              pm10Environmental: aqMetrics.hasPm10Environmental()
                  ? aqMetrics.pm10Environmental
                  : null,
              pm25Environmental: aqMetrics.hasPm25Environmental()
                  ? aqMetrics.pm25Environmental
                  : null,
              pm100Environmental: aqMetrics.hasPm100Environmental()
                  ? aqMetrics.pm100Environmental
                  : null,
              particles03um: aqMetrics.hasParticles03um()
                  ? aqMetrics.particles03um
                  : null,
              particles05um: aqMetrics.hasParticles05um()
                  ? aqMetrics.particles05um
                  : null,
              particles10um: aqMetrics.hasParticles10um()
                  ? aqMetrics.particles10um
                  : null,
              particles25um: aqMetrics.hasParticles25um()
                  ? aqMetrics.particles25um
                  : null,
              particles50um: aqMetrics.hasParticles50um()
                  ? aqMetrics.particles50um
                  : null,
              particles100um: aqMetrics.hasParticles100um()
                  ? aqMetrics.particles100um
                  : null,
              co2: aqMetrics.hasCo2() ? aqMetrics.co2 : null,
              lastHeard: DateTime.now(),
            );
            _nodes[packet.from] = updatedAqNode;
            _nodeController.add(updatedAqNode);
          }
          return;

        case telemetry.Telemetry_Variant.powerMetrics:
          final pwrMetrics = telem.powerMetrics;
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'PowerMetrics from ${packet.from}: '
              'ch1=${pwrMetrics.hasCh1Voltage() ? pwrMetrics.ch1Voltage : "N/A"}V, '
              'ch2=${pwrMetrics.hasCh2Voltage() ? pwrMetrics.ch2Voltage : "N/A"}V, '
              'ch3=${pwrMetrics.hasCh3Voltage() ? pwrMetrics.ch3Voltage : "N/A"}V',
            );
          }
          // Update node with power metrics
          final existingPwrNode = _nodes[packet.from];
          if (existingPwrNode != null) {
            final updatedPwrNode = existingPwrNode.copyWith(
              ch1Voltage: pwrMetrics.hasCh1Voltage()
                  ? pwrMetrics.ch1Voltage.toDouble()
                  : null,
              ch1Current: pwrMetrics.hasCh1Current()
                  ? pwrMetrics.ch1Current.toDouble()
                  : null,
              ch2Voltage: pwrMetrics.hasCh2Voltage()
                  ? pwrMetrics.ch2Voltage.toDouble()
                  : null,
              ch2Current: pwrMetrics.hasCh2Current()
                  ? pwrMetrics.ch2Current.toDouble()
                  : null,
              ch3Voltage: pwrMetrics.hasCh3Voltage()
                  ? pwrMetrics.ch3Voltage.toDouble()
                  : null,
              ch3Current: pwrMetrics.hasCh3Current()
                  ? pwrMetrics.ch3Current.toDouble()
                  : null,
              lastHeard: DateTime.now(),
            );
            _nodes[packet.from] = updatedPwrNode;
            _nodeController.add(updatedPwrNode);
          }
          return;

        case telemetry.Telemetry_Variant.localStats:
          final stats = telem.localStats;
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'LocalStats from ${packet.from}: '
              'channelUtil=${stats.channelUtilization}%, airUtilTx=${stats.airUtilTx}%, '
              'numOnlineNodes=${stats.numOnlineNodes}, numTotalNodes=${stats.numTotalNodes}',
            );
          }
          // Local stats can provide channel utilization
          if (packet.from == _myNodeNum) {
            _lastChannelUtil = stats.channelUtilization.toDouble();
            _channelUtilController.add(_lastChannelUtil);
          }
          // Update node with local stats
          final existingStatsNode = _nodes[packet.from];
          if (existingStatsNode != null) {
            final updatedStatsNode = existingStatsNode.copyWith(
              channelUtilization: stats.hasChannelUtilization()
                  ? stats.channelUtilization.toDouble()
                  : null,
              airUtilTx: stats.hasAirUtilTx()
                  ? stats.airUtilTx.toDouble()
                  : null,
              uptimeSeconds: stats.hasUptimeSeconds()
                  ? stats.uptimeSeconds
                  : null,
              numPacketsTx: stats.hasNumPacketsTx() ? stats.numPacketsTx : null,
              numPacketsRx: stats.hasNumPacketsRx() ? stats.numPacketsRx : null,
              numPacketsRxBad: stats.hasNumPacketsRxBad()
                  ? stats.numPacketsRxBad
                  : null,
              numOnlineNodes: stats.hasNumOnlineNodes()
                  ? stats.numOnlineNodes
                  : null,
              numTotalNodes: stats.hasNumTotalNodes()
                  ? stats.numTotalNodes
                  : null,
              numTxDropped: stats.hasNumTxDropped() ? stats.numTxDropped : null,
              noiseFloor: stats.hasNoiseFloor() ? stats.noiseFloor : null,
              lastHeard: DateTime.now(),
            );
            _nodes[packet.from] = updatedStatsNode;
            _nodeController.add(updatedStatsNode);
          }
          return;

        case telemetry.Telemetry_Variant.healthMetrics:
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol('HealthMetrics from ${packet.from}');
          }
          return;

        case telemetry.Telemetry_Variant.hostMetrics:
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol('HostMetrics from ${packet.from}');
          }
          return;

        case telemetry.Telemetry_Variant.notSet:
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'Telemetry with no variant set from ${packet.from}',
            );
          }
          return;
      }

      // Emit channel utilization if available (from our own device)
      if (channelUtil != null && packet.from == _myNodeNum) {
        _lastChannelUtil = channelUtil;
        _channelUtilController.add(channelUtil);
      }

      // Device metrics are now handled in the switch case above
      // This block is only for creating new nodes if they don't exist
      if (_nodes[packet.from] == null &&
          batteryLevel != null &&
          batteryLevel > 0) {
        AppLogging.protocol(
          'Creating new node entry for ${packet.from} from telemetry',
        );
        final colors = [
          0xFF1976D2,
          0xFFD32F2F,
          0xFF388E3C,
          0xFFF57C00,
          0xFF7B1FA2,
          0xFF00796B,
          0xFFC2185B,
        ];
        final avatarColor = colors[packet.from % colors.length];

        final newNode = MeshNode(
          nodeNum: packet.from,
          batteryLevel: batteryLevel,
          voltage: voltage,
          channelUtilization: channelUtil,
          airUtilTx: airUtilTx,
          uptimeSeconds: uptimeSeconds,
          lastHeard: DateTime.now(),
          avatarColor: avatarColor,
          isFavorite: false,
        );
        _nodes[packet.from] = newNode;
        _nodeController.add(newNode);
      }
    } catch (e) {
      AppLogging.protocol('Error decoding telemetry: $e');
      // Log the raw payload for debugging
      AppLogging.protocol('Raw telemetry payload: ${data.payload}');
    }
  }

  /// Handle position update
  void _handlePositionUpdate(pb.MeshPacket packet, pb.Data data) {
    try {
      final position = pb.Position.fromBuffer(data.payload);

      // Check if position has valid coordinates (matching iOS implementation)
      // Require BOTH lat AND lng to be non-zero
      // Filter Apple Park coordinates (default invalid position)
      final isApplePark =
          position.latitudeI == 373346000 && position.longitudeI == -1220090000;
      final hasValidPosition =
          (position.latitudeI != 0 && position.longitudeI != 0) && !isApplePark;

      if (ProtocolDebugFlags.logPosition) {
        AppLogging.debug(
          '📍 POSITION_APP from !${packet.from.toRadixString(16)}: '
          'latI=${position.latitudeI}, lngI=${position.longitudeI}, '
          'lat=${position.latitudeI / 1e7}, lng=${position.longitudeI / 1e7}, '
          'isApplePark=$isApplePark, valid=$hasValidPosition',
        );
      }

      final node = _nodes[packet.from];
      if (node != null && hasValidPosition) {
        AppLogging.protocol(
          '✅ UPDATING NODE ${node.displayName} (!${packet.from.toRadixString(16)}) WITH VALID POSITION: '
          '${position.latitudeI / 1e7}, ${position.longitudeI / 1e7}',
        );
        final updatedNode = node.copyWith(
          latitude: position.latitudeI / 1e7,
          longitude: position.longitudeI / 1e7,
          altitude: position.hasAltitude() ? position.altitude : node.altitude,
          lastHeard: DateTime.now(),
          positionTimestamp: DateTime.now(),
          // GPS extended fields
          satsInView: position.hasSatsInView()
              ? position.satsInView
              : node.satsInView,
          gpsAccuracy: position.hasGpsAccuracy()
              ? position.gpsAccuracy / 1000.0
              : node.gpsAccuracy, // mm to meters
          groundSpeed: position.hasGroundSpeed()
              ? position.groundSpeed.toDouble()
              : node.groundSpeed, // m/s
          groundTrack: position.hasGroundTrack()
              ? position.groundTrack / 100.0
              : node.groundTrack, // 1/100 degrees to degrees
          precisionBits: position.hasPrecisionBits()
              ? position.precisionBits
              : node.precisionBits,
        );
        _nodes[packet.from] = updatedNode;
        _nodeController.add(updatedNode);
        AppLogging.protocol(
          '✅ Node ${updatedNode.displayName} now hasPosition=${updatedNode.hasPosition}',
        );
      } else if (node != null) {
        // Update lastHeard even if position is invalid
        final updatedNode = node.copyWith(lastHeard: DateTime.now());
        _nodes[packet.from] = updatedNode;
        _nodeController.add(updatedNode);
      } else if (hasValidPosition) {
        // Node doesn't exist yet but we have valid position - create placeholder
        // This handles cases where position arrives before NodeInfo
        AppLogging.protocol(
          'Creating placeholder node ${packet.from} from position update',
        );
        final colors = [
          0xFF1976D2,
          0xFFD32F2F,
          0xFF388E3C,
          0xFFF57C00,
          0xFF7B1FA2,
          0xFF00796B,
          0xFFC2185B,
        ];
        final avatarColor = colors[packet.from % colors.length];

        final newNode = MeshNode(
          nodeNum: packet.from,
          longName: '!${packet.from.toRadixString(16)}',
          shortName: packet.from
              .toRadixString(16)
              .substring(
                packet.from.toRadixString(16).length > 4
                    ? packet.from.toRadixString(16).length - 4
                    : 0,
              )
              .toUpperCase(),
          latitude: position.latitudeI / 1e7,
          longitude: position.longitudeI / 1e7,
          altitude: position.hasAltitude() ? position.altitude : null,
          snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
          lastHeard: DateTime.now(),
          avatarColor: avatarColor,
          isFavorite: false,
          positionTimestamp: DateTime.now(),
          // GPS extended fields
          satsInView: position.hasSatsInView() ? position.satsInView : null,
          gpsAccuracy: position.hasGpsAccuracy()
              ? position.gpsAccuracy / 1000.0
              : null,
          groundSpeed: position.hasGroundSpeed()
              ? position.groundSpeed.toDouble()
              : null,
          groundTrack: position.hasGroundTrack()
              ? position.groundTrack / 100.0
              : null,
          precisionBits: position.hasPrecisionBits()
              ? position.precisionBits
              : null,
        );
        _nodes[packet.from] = newNode;
        _nodeController.add(newNode);
      }
    } catch (e) {
      AppLogging.protocol('Error decoding position: $e');
    }
  }

  /// Handle node info update
  void _handleNodeInfoUpdate(pb.MeshPacket packet, pb.Data data) {
    try {
      final user = pb.User.fromBuffer(data.payload);

      // Sanitize node names to prevent UTF-16 crashes when rendering text
      final longName = sanitizeUtf16(user.longName);
      final shortName = sanitizeUtf16(user.shortName);

      AppLogging.protocol(
        '🔑 📥 Received node info from ${packet.from.toRadixString(16)}: $longName ($shortName)',
      );
      AppLogging.protocol(
        '🔑 📥 Public key present: ${user.publicKey.isNotEmpty} (${user.publicKey.length} bytes)',
      );
      AppLogging.protocol('Node info from ${packet.from}: $longName');

      final colors = [
        0xFF1976D2,
        0xFFD32F2F,
        0xFF388E3C,
        0xFFF57C00,
        0xFF7B1FA2,
        0xFF00796B,
        0xFFC2185B,
      ];
      final avatarColor = colors[packet.from % colors.length];

      // Extract hardware model from user
      String? hwModel;
      if (user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET) {
        hwModel = _formatHardwareModel(user.hwModel);
      } else if (packet.from == _myNodeNum) {
        // For our own node, try to infer from BLE model number or device name
        hwModel = _inferHardwareModel();
        if (hwModel != null) {
          AppLogging.protocol(
            'Hardware model UNSET in User packet, inferred: $hwModel',
          );
        }
      }

      // Extract role from user
      final role = user.hasRole() ? user.role.name : 'CLIENT';

      final existingNode = _nodes[packet.from];
      final updatedNode =
          existingNode?.copyWith(
            longName: longName,
            shortName: shortName,
            userId: user.hasId() ? user.id : existingNode.userId,
            hardwareModel: hwModel ?? existingNode.hardwareModel,
            role: role,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : existingNode.snr,
            lastHeard: DateTime.now(),
          ) ??
          MeshNode(
            nodeNum: packet.from,
            longName: longName,
            shortName: shortName,
            userId: user.hasId() ? user.id : null,
            hardwareModel: hwModel,
            role: role,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
            lastHeard: DateTime.now(),
            avatarColor: avatarColor,
            isFavorite: false,
          );

      _nodes[packet.from] = updatedNode;
      _nodeController.add(updatedNode);
      onIdentityUpdate?.call(
        nodeNum: packet.from,
        longName: longName.isNotEmpty ? longName : null,
        shortName: shortName.isNotEmpty ? shortName : null,
        lastSeenAtMs: updatedNode.lastHeard?.millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogging.protocol('Error decoding node info: $e');
    }
  }

  /// Update lastHeard timestamp for a node (marks it as online)
  /// This is called for any packet received from a node
  void _updateNodeLastHeard(int nodeNum) {
    final node = _nodes[nodeNum];
    if (node != null) {
      final updatedNode = node.copyWith(lastHeard: DateTime.now());
      _nodes[nodeNum] = updatedNode;
      _nodeController.add(updatedNode);
    }
  }

  /// Handle my node info
  void _handleMyNodeInfo(pb.MyNodeInfo myInfo) {
    _myNodeNum = myInfo.myNodeNum;
    AppLogging.protocol('Protocol: My node number set to: $_myNodeNum');
    AppLogging.protocol('My node number: $_myNodeNum');
    _myNodeNumController.add(_myNodeNum!);

    // Apply any pending metadata that was received before myNodeNum was set
    if (_pendingMetadata != null) {
      AppLogging.protocol('Applying pending FromRadio metadata...');
      _handleFromRadioMetadata(_pendingMetadata!);
      _pendingMetadata = null;
    }

    // Request our own position after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_myNodeNum != null) {
        requestPosition(_myNodeNum!);
      }
    });
  }

  /// Handle node info
  void _handleNodeInfo(pb.NodeInfo nodeInfo) {
    if (ProtocolDebugFlags.logNodeInfo) {
      AppLogging.protocol('Node info received: ${nodeInfo.num}');
    }

    // DEBUG: Log position status with debugPrint so it shows in console
    if (ProtocolDebugFlags.logPosition) {
      AppLogging.debug(
        '📍 NodeInfo ${nodeInfo.num.toRadixString(16)}: hasPosition=${nodeInfo.hasPosition()}',
      );
      if (nodeInfo.hasPosition()) {
        final pos = nodeInfo.position;
        AppLogging.debug(
          '📍 NodeInfo ${nodeInfo.num.toRadixString(16)} POSITION: '
          'latI=${pos.latitudeI}, lngI=${pos.longitudeI}, '
          'lat=${pos.latitudeI / 1e7}, lng=${pos.longitudeI / 1e7}',
        );
      } else {
        AppLogging.debug(
          '📍 NodeInfo ${nodeInfo.num.toRadixString(16)} has NO position data',
        );
      }
    }

    // Log device metrics if present
    if (nodeInfo.hasDeviceMetrics()) {
      final metrics = nodeInfo.deviceMetrics;
      AppLogging.protocol(
        'NodeInfo deviceMetrics: battery=${metrics.batteryLevel}%, '
        'voltage=${metrics.voltage}V, uptime=${metrics.uptimeSeconds}s',
      );
    } else {
      AppLogging.protocol('NodeInfo has no deviceMetrics');
    }

    final existingNode = _nodes[nodeInfo.num];

    // Generate consistent color from node number
    final colors = [
      0xFF1976D2,
      0xFFD32F2F,
      0xFF388E3C,
      0xFFF57C00,
      0xFF7B1FA2,
      0xFF00796B,
      0xFFC2185B,
    ];
    final avatarColor = colors[nodeInfo.num % colors.length];

    // Extract hardware model and role from user if present
    String? hwModel;
    String role = 'CLIENT';
    String? userId;
    bool hasPublicKey = false;
    if (nodeInfo.hasUser()) {
      final user = nodeInfo.user;
      AppLogging.protocol(
        'NodeInfo user: longName=${user.longName}, hwModel=${user.hwModel}, hasHwModel=${user.hasHwModel()}',
      );
      if (user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET) {
        hwModel = _formatHardwareModel(user.hwModel);
        AppLogging.protocol('Formatted hardware model: $hwModel');
      }
      if (user.hasRole()) {
        role = user.role.name;
      }
      if (user.hasId()) {
        userId = user.id;
      }
      // Check if user has a public key set (for PKI encryption)
      hasPublicKey = user.hasPublicKey() && user.publicKey.isNotEmpty;

      // Emit user config if this is our own node
      if (_myNodeNum != null && nodeInfo.num == _myNodeNum) {
        _currentUserConfig = user;
        _userConfigController.add(user);
        AppLogging.protocol(
          'Emitted user config for myNode: isUnmessagable=${user.isUnmessagable}, isLicensed=${user.isLicensed}',
        );
      }
    } else {
      AppLogging.protocol('NodeInfo has no user data');
    }

    MeshNode updatedNode;

    // Check if NodeInfo has valid position data (matching iOS implementation)
    // Require BOTH lat AND lng to be non-zero
    // Filter Apple Park coordinates (default invalid position)
    final hasValidPosition =
        nodeInfo.hasPosition() &&
        (nodeInfo.position.latitudeI != 0 &&
            nodeInfo.position.longitudeI != 0) &&
        !(nodeInfo.position.latitudeI == 373346000 &&
            nodeInfo.position.longitudeI == -1220090000);

    if (nodeInfo.hasPosition()) {
      AppLogging.protocol(
        '📍 NodeInfo ${nodeInfo.num} position check: latI=${nodeInfo.position.latitudeI}, '
        'lngI=${nodeInfo.position.longitudeI}, lat=${nodeInfo.position.latitudeI / 1e7}, '
        'lng=${nodeInfo.position.longitudeI / 1e7}, valid=$hasValidPosition',
      );
    }

    if (existingNode != null) {
      // Preserve existing names if new ones are empty, sanitize to prevent UTF-16 crashes
      final newLongName =
          nodeInfo.hasUser() && nodeInfo.user.longName.isNotEmpty
          ? sanitizeUtf16(nodeInfo.user.longName)
          : existingNode.longName;
      final newShortName =
          nodeInfo.hasUser() && nodeInfo.user.shortName.isNotEmpty
          ? sanitizeUtf16(nodeInfo.user.shortName)
          : existingNode.shortName;

      updatedNode = existingNode.copyWith(
        longName: newLongName,
        shortName: newShortName,
        userId: userId ?? existingNode.userId,
        hardwareModel: hwModel ?? existingNode.hardwareModel,
        latitude: hasValidPosition
            ? nodeInfo.position.latitudeI / 1e7
            : existingNode.latitude,
        longitude: hasValidPosition
            ? nodeInfo.position.longitudeI / 1e7
            : existingNode.longitude,
        altitude: hasValidPosition && nodeInfo.position.hasAltitude()
            ? nodeInfo.position.altitude
            : existingNode.altitude,
        snr: nodeInfo.hasSnr() ? nodeInfo.snr.toInt() : existingNode.snr,
        batteryLevel: nodeInfo.hasDeviceMetrics()
            ? nodeInfo.deviceMetrics.batteryLevel
            : existingNode.batteryLevel,
        lastHeard: DateTime.now(),
        role: role,
        avatarColor: existingNode.avatarColor,
        hasPublicKey: hasPublicKey,
        isMuted: nodeInfo.hasIsMuted()
            ? nodeInfo.isMuted
            : existingNode.isMuted,
      );
    } else {
      // Use null for empty strings to trigger fallback display logic, sanitize to prevent UTF-16 crashes
      final userLongName =
          nodeInfo.hasUser() && nodeInfo.user.longName.isNotEmpty
          ? sanitizeUtf16(nodeInfo.user.longName)
          : null;
      final userShortName =
          nodeInfo.hasUser() && nodeInfo.user.shortName.isNotEmpty
          ? sanitizeUtf16(nodeInfo.user.shortName)
          : null;

      updatedNode = MeshNode(
        nodeNum: nodeInfo.num,
        longName: userLongName,
        shortName: userShortName,
        userId: userId,
        hardwareModel: hwModel,
        latitude: hasValidPosition ? nodeInfo.position.latitudeI / 1e7 : null,
        longitude: hasValidPosition ? nodeInfo.position.longitudeI / 1e7 : null,
        altitude: hasValidPosition && nodeInfo.position.hasAltitude()
            ? nodeInfo.position.altitude
            : null,
        snr: nodeInfo.hasSnr() ? nodeInfo.snr.toInt() : null,
        batteryLevel: nodeInfo.hasDeviceMetrics()
            ? nodeInfo.deviceMetrics.batteryLevel
            : null,
        lastHeard: DateTime.now(),
        role: role,
        avatarColor: avatarColor,
        isFavorite: false,
        hasPublicKey: hasPublicKey,
        isMuted: nodeInfo.hasIsMuted() ? nodeInfo.isMuted : false,
      );
    }

    _nodes[nodeInfo.num] = updatedNode;
    _nodeController.add(updatedNode);
    if (nodeInfo.hasUser()) {
      final user = nodeInfo.user;
      // Sanitize names for the callback as well
      final sanitizedLongName = user.longName.isNotEmpty
          ? sanitizeUtf16(user.longName)
          : null;
      final sanitizedShortName = user.shortName.isNotEmpty
          ? sanitizeUtf16(user.shortName)
          : null;
      onIdentityUpdate?.call(
        nodeNum: nodeInfo.num,
        longName: sanitizedLongName,
        shortName: sanitizedShortName,
        lastSeenAtMs: updatedNode.lastHeard?.millisecondsSinceEpoch,
      );
    }
  }

  /// Handle channel configuration
  void _handleChannel(channel_pb.Channel channel) {
    AppLogging.debug(
      '📡 Channel ${channel.index} RAW received: '
      'hasSettings=${channel.hasSettings()}, role=${channel.role.name}',
    );
    if (channel.hasSettings()) {
      final settings = channel.settings;
      AppLogging.debug(
        '📡 Channel ${channel.index} settings: '
        'name="${settings.name}", psk=${settings.psk.length} bytes, '
        'uplink=${settings.uplinkEnabled}, downlink=${settings.downlinkEnabled}, '
        'hasModuleSettings=${settings.hasModuleSettings()}',
      );

      // Always try to read moduleSettings even if hasModuleSettings returns false
      // because proto3 returns false for sub-messages with all default values
      final mod = settings.moduleSettings;
      AppLogging.debug(
        '📡 Channel ${channel.index} moduleSettings (always read): '
        'positionPrecision=${mod.positionPrecision}, '
        'isMuted=${mod.isMuted}',
      );

      if (settings.hasModuleSettings()) {
        AppLogging.debug(
          '📡 Channel ${channel.index} has moduleSettings marker set',
        );
      } else {
        AppLogging.debug(
          '📡 Channel ${channel.index} has NO moduleSettings marker',
        );
      }
    }

    // Map protobuf role to string
    String roleStr;
    switch (channel.role) {
      case channel_pbenum.Channel_Role.PRIMARY:
        roleStr = 'PRIMARY';
        break;
      case channel_pbenum.Channel_Role.SECONDARY:
        roleStr = 'SECONDARY';
        break;
      case channel_pbenum.Channel_Role.DISABLED:
      default:
        roleStr = 'DISABLED';
        break;
    }

    // Extract position precision from moduleSettings
    // Note: In proto3, hasModuleSettings() returns false when all fields are default (0)
    // So we ALWAYS read the value directly, regardless of hasModuleSettings()
    // This matches what iOS does
    int positionPrecision = 0;
    if (channel.hasSettings()) {
      // Always read moduleSettings.positionPrecision directly
      positionPrecision = channel.settings.moduleSettings.positionPrecision;
      AppLogging.debug(
        '📡 Channel ${channel.index} positionPrecision=$positionPrecision '
        '(hasModuleSettings=${channel.settings.hasModuleSettings()})',
      );
    }

    final channelConfig = ChannelConfig(
      index: channel.index,
      name: channel.hasSettings() ? channel.settings.name : '',
      psk: channel.hasSettings() ? channel.settings.psk : [],
      uplink: channel.hasSettings() ? channel.settings.uplinkEnabled : false,
      downlink: channel.hasSettings()
          ? channel.settings.downlinkEnabled
          : false,
      role: roleStr,
      positionPrecision: positionPrecision,
    );

    // Extend list if needed, but don't add dummy entries to stream
    while (_channels.length <= channel.index) {
      _channels.add(ChannelConfig(index: _channels.length, name: '', psk: []));
    }
    _channels[channel.index] = channelConfig;

    // Emit channel 0 (Primary), emit others only if they're not disabled
    if (channel.index == 0 ||
        channel.role != channel_pbenum.Channel_Role.DISABLED) {
      _channelController.add(channelConfig);
    }
  }

  /// Request configuration from device
  Future<void> _requestConfiguration() async {
    try {
      if (!_transport.isConnected) {
        AppLogging.protocol('Cannot request configuration: not connected');
        return;
      }

      AppLogging.protocol('Requesting device configuration');

      // Wake device by sending START2 bytes (only for serial/USB)
      if (_transport.requiresFraming) {
        final wakeBytes = List<int>.filled(32, 0xC3); // 32 START2 bytes
        await _transport.send(Uint8List.fromList(wakeBytes));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Generate a config ID to track this request
      // The firmware will send back all config + NodeDB with positions
      final configId = _random.nextInt(0x7FFFFFFF);

      AppLogging.protocol('Requesting config with ID: $configId');
      final toRadio = pb.ToRadio()..wantConfigId = configId;
      final bytes = toRadio.writeToBuffer();

      // BLE uses raw protobufs, Serial/USB requires framing
      final sendBytes = _transport.requiresFraming
          ? PacketFramer.frame(bytes)
          : bytes;

      await _transport.send(sendBytes);
      AppLogging.protocol('Configuration request sent');
    } catch (e) {
      AppLogging.protocol('Error requesting configuration: $e');
    }
  }

  /// Send a text message
  /// Returns the packet ID for tracking delivery status
  Future<int> sendMessage({
    required String text,
    required int to,
    int channel = 0,
    bool wantAck = true,
    String? messageId,
    MessageSource source = MessageSource.unknown,
    int? replyId,
    bool isEmoji = false,
  }) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError(
        'Cannot send message: device not ready (no node number)',
      );
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot send message: not connected to device');
    }

    try {
      AppLogging.protocol('Sending message to $to: $text');

      final packetId = _generatePacketId();

      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text)
        ..wantResponse = wantAck
        ..emoji = isEmoji ? 1 : 0;

      if (replyId != null) {
        data.replyId = replyId;
      }

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = to
        ..channel = channel
        ..decoded = data
        ..id = packetId
        ..wantAck = wantAck;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Track the message for delivery status
      if (messageId != null && wantAck) {
        _pendingMessages[packetId] = messageId;
      }

      // Get our node info to cache in message
      final myNode = _nodes[_myNodeNum!];

      final message = Message(
        id: messageId,
        from: _myNodeNum!,
        to: to,
        text: text,
        channel: channel,
        sent: true,
        packetId: packetId,
        status: wantAck ? MessageStatus.pending : MessageStatus.sent,
        source: source,
        senderLongName: myNode?.longName,
        senderShortName: myNode?.shortName,
        senderAvatarColor: myNode?.avatarColor,
      );

      _messageController.add(message);

      return packetId;
    } catch (e) {
      AppLogging.protocol('Error sending message: $e');
      rethrow;
    }
  }

  /// Broadcast a signal packet to all nodes in the mesh.
  ///
  /// Uses PRIVATE_APP portnum (256) with JSON payload.
  /// Returns the packet ID for tracking.
  ///
  /// Throws [ArgumentError] if payload exceeds max mesh packet size.
  /// Note: 180 chars ≠ 180 bytes. Emojis and special chars inflate UTF-8 size.
  static const int _maxSignalPayloadBytes = 200;

  Future<int> sendSignal({
    required String signalId,
    required String content,
    required int ttlMinutes,
    double? latitude,
    double? longitude,
    bool hasImage = false,
    Map<String, dynamic>? presenceInfo,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot send signal: device not ready (no node number)');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot send signal: not connected to device');
    }

    try {
      final signalPacket = MeshSignalPacket(
        senderNodeId: _myNodeNum!,
        packetId: 0,
        signalId: signalId,
        content: content,
        ttlMinutes: ttlMinutes,
        latitude: latitude,
        longitude: longitude,
        receivedAt: DateTime.now(),
        hasImage: hasImage,
        presenceInfo: presenceInfo,
      );

      final payload = signalPacket.toPayload();

      // Guard: Prevent oversized payloads that cause fragmentation or drops
      if (payload.length > _maxSignalPayloadBytes) {
        AppLogging.signals(
          'Signal payload too large: ${payload.length} bytes '
          '(max $_maxSignalPayloadBytes). Content: ${content.length} chars',
        );
        throw ArgumentError(
          'Signal payload exceeds max size: ${payload.length} bytes '
          '(limit: $_maxSignalPayloadBytes bytes). '
          'Try shorter content or remove location.',
        );
      }

      final packetId = _generatePacketId();

      final data = pb.Data()
        ..portnum = pn.PortNum.PRIVATE_APP
        ..payload = payload;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to =
            0xFFFFFFFF // Broadcast
        ..decoded = data
        ..id = packetId;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      AppLogging.signals(
        'Broadcast signal: "${content.length > 30 ? '${content.substring(0, 30)}...' : content}" '
        '(ttl=${ttlMinutes}m, packetId=$packetId)',
      );

      return packetId;
    } catch (e) {
      AppLogging.signals('Error broadcasting signal: $e');
      rethrow;
    }
  }

  /// Send a text message with pre-tracking callback
  /// This allows tracking to be set up BEFORE the message is sent,
  /// avoiding race conditions where ACK arrives before tracking is ready
  Future<int> sendMessageWithPreTracking({
    required String text,
    required int to,
    int channel = 0,
    bool wantAck = true,
    String? messageId,
    required void Function(int packetId) onPacketIdGenerated,
    MessageSource source = MessageSource.unknown,
    int? replyId,
    bool isEmoji = false,
  }) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError(
        'Cannot send message: device not ready (no node number)',
      );
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot send message: not connected to device');
    }

    try {
      AppLogging.protocol('Sending message to $to: $text');

      final packetId = _generatePacketId();

      // Call the pre-tracking callback BEFORE sending
      // This ensures tracking is set up before any ACK can arrive
      if (wantAck) {
        onPacketIdGenerated(packetId);
      }

      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text)
        ..wantResponse = wantAck
        ..emoji = isEmoji ? 1 : 0;

      if (replyId != null) {
        data.replyId = replyId;
      }

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = to
        ..channel = channel
        ..decoded = data
        ..id = packetId
        ..wantAck = wantAck;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Track the message for delivery status (internal tracking)
      if (messageId != null && wantAck) {
        _pendingMessages[packetId] = messageId;
      }

      // Get our node info to cache in message
      final myNode = _nodes[_myNodeNum!];

      final message = Message(
        id: messageId,
        from: _myNodeNum!,
        to: to,
        text: text,
        channel: channel,
        sent: true,
        packetId: packetId,
        status: wantAck ? MessageStatus.pending : MessageStatus.sent,
        source: source,
        senderLongName: myNode?.longName,
        senderShortName: myNode?.shortName,
        senderAvatarColor: myNode?.avatarColor,
      );

      _messageController.add(message);

      return packetId;
    } catch (e) {
      AppLogging.protocol('Error sending message: $e');
      rethrow;
    }
  }

  /// Generate a random packet ID
  int _generatePacketId() {
    return _random.nextInt(0x7FFFFFFF);
  }

  /// Prepare bytes for sending (frame if transport requires it)
  List<int> _prepareForSend(List<int> bytes) {
    return _transport.requiresFraming ? PacketFramer.frame(bytes) : bytes;
  }

  /// Send position
  Future<void> sendPosition({
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    try {
      AppLogging.protocol('Sending position: $latitude, $longitude');

      final position = pb.Position()
        ..latitudeI = (latitude * 1e7).toInt()
        ..longitudeI = (longitude * 1e7).toInt()
        ..time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (altitude != null) {
        position.altitude = altitude;
      }

      final data = pb.Data()
        ..portnum = pn.PortNum.POSITION_APP
        ..payload = position.writeToBuffer();

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            0xFFFFFFFF // Broadcast
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Also update our own node's position locally immediately
      // This ensures the map shows our position right away without waiting for echo
      if (_myNodeNum != null) {
        final myNode = _nodes[_myNodeNum];
        if (myNode != null) {
          final updatedNode = myNode.copyWith(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            lastHeard: DateTime.now(),
          );
          _nodes[_myNodeNum!] = updatedNode;
          _nodeController.add(updatedNode);
          AppLogging.debug(
            '📍 Updated MY node position locally: $latitude, $longitude',
          );
        }
      }
    } catch (e) {
      AppLogging.protocol('Error sending position: $e');
      rethrow;
    }
  }

  /// Send position to a specific node (direct message, not broadcast)
  Future<void> sendPositionToNode({
    required int nodeNum,
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    try {
      AppLogging.protocol(
        'Sending position to node $nodeNum: $latitude, $longitude',
      );

      final position = pb.Position()
        ..latitudeI = (latitude * 1e7).toInt()
        ..longitudeI = (longitude * 1e7).toInt()
        ..time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (altitude != null) {
        position.altitude = altitude;
      }

      final data = pb.Data()
        ..portnum = pn.PortNum.POSITION_APP
        ..payload = position.writeToBuffer();

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            nodeNum // Send to specific node
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = true;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error sending position to node: $e');
      rethrow;
    }
  }

  /// Request node info/PKI key exchange by broadcasting our own User info
  ///
  /// This triggers the Meshtastic key exchange mechanism:
  /// 1. We broadcast our User info (including our public key)
  /// 2. Other nodes receive it and update their NodeDB with our info
  /// 3. This prompts them to broadcast their User info in response
  /// 4. We receive their info and update our NodeDB
  ///
  /// Note: Admin messages (getOwnerRequest) require authorization and won't
  /// work for arbitrary remote nodes. Broadcasting NODEINFO is the standard
  /// way to trigger key exchange.
  Future<void> requestNodeInfo(int nodeNum) async {
    try {
      AppLogging.protocol(
        '🔑 Broadcasting our User info to trigger key exchange with ${nodeNum.toRadixString(16)}',
      );
      AppLogging.protocol('Broadcasting User info to trigger key exchange');

      // Build our User info to broadcast
      final myNode = _nodes[_myNodeNum];
      final user = pb.User()
        ..id = myNode?.userId ?? '!${(_myNodeNum ?? 0).toRadixString(16)}'
        ..longName = myNode?.longName ?? 'Unknown'
        ..shortName = myNode?.shortName ?? '????';

      AppLogging.protocol(
        '🔑 Broadcasting: ${user.longName} (${user.shortName})',
      );

      final data = pb.Data()
        ..portnum = pn.PortNum.NODEINFO_APP
        ..payload = user.writeToBuffer()
        ..wantResponse = true; // Request a response with their info

      // Send directly to the target node (not broadcast) with wantResponse
      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            nodeNum // Direct to target node
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = true;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      AppLogging.protocol(
        '🔑 ✅ Sent NODEINFO with wantResponse to ${nodeNum.toRadixString(16)}',
      );
      AppLogging.protocol('Sent NODEINFO request to $nodeNum');
    } catch (e) {
      AppLogging.protocol('🔑 ❌ Error requesting node info: $e');
      AppLogging.protocol('Error requesting node info: $e');
      rethrow;
    }
  }

  /// Broadcast our User info to all nodes (triggers mesh-wide key exchange)
  Future<void> broadcastUserInfo() async {
    try {
      AppLogging.protocol('🔑 Broadcasting our User info to mesh');

      final myNode = _nodes[_myNodeNum];
      final user = pb.User()
        ..id = myNode?.userId ?? '!${(_myNodeNum ?? 0).toRadixString(16)}'
        ..longName = myNode?.longName ?? 'Unknown'
        ..shortName = myNode?.shortName ?? '????';

      final data = pb.Data()
        ..portnum = pn.PortNum.NODEINFO_APP
        ..payload = user.writeToBuffer();

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            0xFFFFFFFF // Broadcast
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      AppLogging.protocol('🔑 ✅ Broadcast User info to mesh');
    } catch (e) {
      AppLogging.protocol('🔑 ❌ Error broadcasting user info: $e');
      AppLogging.protocol('Error broadcasting user info: $e');
    }
  }

  /// Request position from a specific node
  Future<void> requestPosition(int nodeNum) async {
    try {
      AppLogging.protocol('Requesting position for node $nodeNum');

      // Create an empty position to request the node's position
      final position = pb.Position();

      final data = pb.Data()
        ..portnum = pn.PortNum.POSITION_APP
        ..payload = position.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = nodeNum
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = true;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error requesting position: $e');
    }
  }

  /// Request positions from all known nodes
  Future<void> requestAllPositions() async {
    // Take a snapshot of node keys to avoid ConcurrentModificationError
    // if _nodes is modified while iterating (e.g., by incoming packets)
    final nodeNums = _nodes.keys.toList();
    AppLogging.protocol(
      'Requesting positions from all ${nodeNums.length} known nodes',
    );
    for (final nodeNum in nodeNums) {
      await requestPosition(nodeNum);
      // Small delay between requests to avoid flooding
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Send a traceroute request to a specific node
  /// Returns immediately - results come via mesh packet responses
  Future<void> sendTraceroute(int nodeNum) async {
    AppLogging.protocol('Sending traceroute to node $nodeNum');

    // Create an empty RouteDiscovery for the request
    final routeDiscovery = pb.RouteDiscovery();

    final data = pb.Data()
      ..portnum = pn.PortNum.TRACEROUTE_APP
      ..payload = routeDiscovery.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum ?? 0
      ..to = nodeNum
      ..decoded = data
      ..id = _generatePacketId()
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    final bytes = toRadio.writeToBuffer();

    await _transport.send(_prepareForSend(bytes));
  }

  /// Set channel configuration
  Future<void> setChannel(ChannelConfig config) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError('Cannot set channel: device not ready (no node number)');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set channel: not connected to device');
    }

    try {
      AppLogging.debug(
        '📡 Setting channel ${config.index}: "${config.name}" (role: ${config.role})',
      );

      final channelSettings = channel_pb.ChannelSettings()
        ..name = config.name
        ..psk = config.psk
        ..uplinkEnabled = config.uplink
        ..downlinkEnabled = config.downlink;

      // Always set position precision via moduleSettings (even when 0 to disable)
      // This matches iOS behavior - the device needs moduleSettings to be explicitly set
      channelSettings.moduleSettings = channel_pb.ModuleSettings()
        ..positionPrecision = config.positionPrecision;

      // Determine channel role from config
      channel_pbenum.Channel_Role role;
      switch (config.role.toUpperCase()) {
        case 'PRIMARY':
          role = channel_pbenum.Channel_Role.PRIMARY;
          break;
        case 'SECONDARY':
          role = channel_pbenum.Channel_Role.SECONDARY;
          break;
        case 'DISABLED':
        default:
          role = channel_pbenum.Channel_Role.DISABLED;
          break;
      }

      final channel = channel_pb.Channel()
        ..index = config.index
        ..settings = channelSettings
        ..role = role;

      AppLogging.debug(
        '📡 Channel protobuf: index=${channel.index}, role=${channel.role.name}, '
        'name="${channel.settings.name}", psk=${channel.settings.psk.length} bytes',
      );

      final adminMsg = admin.AdminMessage()..setChannel = channel;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId()
        ..priority = pbenum.MeshPacket_Priority.RELIABLE
        ..wantAck = true;

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      AppLogging.channels('Channel ${config.index} sent to device');

      // Wait a bit then request the channel back to verify
      await Future.delayed(const Duration(milliseconds: 500));
      AppLogging.channels('Verifying channel ${config.index}...');
      await getChannel(config.index);
    } catch (e) {
      AppLogging.protocol('Error setting channel: $e');
      rethrow;
    }
  }

  /// Get channel
  Future<void> getChannel(int index) async {
    try {
      AppLogging.protocol('Getting channel $index');

      final adminMsg = admin.AdminMessage()..getChannelRequest = index + 1;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = _myNodeNum ?? 0
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error getting channel: $e');
    }
  }

  /// Set device role
  Future<void> setDeviceRole(config_pb.Config_DeviceConfig_Role role) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError(
        'Cannot set device role: device not ready (no node number)',
      );
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set device role: not connected to device');
    }

    try {
      AppLogging.protocol('Setting device role: ${role.name}');

      // Get current owner info and update role
      final user = pb.User()..role = role;

      final adminMsg = admin.AdminMessage()..setOwner = user;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Immediately update local node cache so UI reflects the change
      final existingNode = _nodes[_myNodeNum!];
      if (existingNode != null) {
        final updatedNode = existingNode.copyWith(role: role.name);
        _nodes[_myNodeNum!] = updatedNode;
        _nodeController.add(updatedNode);
        AppLogging.protocol('Updated local node cache with new role');
      }
    } catch (e) {
      AppLogging.protocol('Error setting device role: $e');
      rethrow;
    }
  }

  /// Set owner config (name and/or role) in a single admin message.
  /// This is preferred over calling setUserName and setDeviceRole separately
  /// because the device will reboot after each setOwner call.
  ///
  /// After calling this, the device will save the config and reboot.
  /// The caller should expect a disconnection.
  Future<void> setOwnerConfig({
    String? longName,
    String? shortName,
    config_pb.Config_DeviceConfig_Role? role,
    bool? isUnmessagable,
    bool? isLicensed,
  }) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError(
        'Cannot set owner config: device not ready (no node number)',
      );
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set owner config: not connected to device');
    }

    // Must have at least one field to update
    if (longName == null &&
        shortName == null &&
        role == null &&
        isUnmessagable == null &&
        isLicensed == null) {
      AppLogging.protocol('setOwnerConfig called with no changes');
      return;
    }

    try {
      // Validate and trim lengths
      final trimmedLong = longName != null
          ? (longName.length > 36 ? longName.substring(0, 36) : longName)
          : null;
      final trimmedShort = shortName != null
          ? (shortName.length > 4 ? shortName.substring(0, 4) : shortName)
          : null;

      AppLogging.protocol(
        'Setting owner config: '
        'longName=${trimmedLong ?? "(unchanged)"}, '
        'shortName=${trimmedShort ?? "(unchanged)"}, '
        'role=${role?.name ?? "(unchanged)"}, '
        'isUnmessagable=${isUnmessagable ?? "(unchanged)"}, '
        'isLicensed=${isLicensed ?? "(unchanged)"}',
      );

      // Build User object with all provided fields
      final user = pb.User();
      if (trimmedLong != null) user.longName = trimmedLong;
      if (trimmedShort != null) user.shortName = trimmedShort;
      if (role != null) user.role = role;
      if (isUnmessagable != null) user.isUnmessagable = isUnmessagable;
      if (isLicensed != null) user.isLicensed = isLicensed;

      final adminMsg = admin.AdminMessage()..setOwner = user;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      AppLogging.protocol('Owner config sent successfully, device will reboot');

      // Immediately update local node cache so UI reflects the change
      final existingNode = _nodes[_myNodeNum!];
      if (existingNode != null) {
        final updatedNode = existingNode.copyWith(
          longName: trimmedLong ?? existingNode.longName,
          shortName: trimmedShort ?? existingNode.shortName,
          role: role?.name ?? existingNode.role,
        );
        _nodes[_myNodeNum!] = updatedNode;
        _nodeController.add(updatedNode);
        AppLogging.protocol('Updated local node cache with new owner config');

        // Also update identity store so name persists across reconnects
        // This is critical - without this, _mergeIdentity will restore old name
        if (trimmedLong != null || trimmedShort != null) {
          onIdentityUpdate?.call(
            nodeNum: _myNodeNum!,
            longName: trimmedLong,
            shortName: trimmedShort,
            lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
          );
          AppLogging.protocol('Updated identity store with new name');
        }
      }
    } catch (e) {
      AppLogging.protocol('Error setting owner config: $e');
      rethrow;
    }
  }

  /// Set the user name (long name and short name)
  /// Long name is up to 36 bytes, short name is up to 4 characters
  Future<void> setUserName({
    required String longName,
    required String shortName,
  }) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError(
        'Cannot set user name: device not ready (no node number)',
      );
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set user name: not connected to device');
    }

    try {
      // Validate lengths
      final trimmedLong = longName.length > 36
          ? longName.substring(0, 36)
          : longName;
      final trimmedShort = shortName.length > 4
          ? shortName.substring(0, 4)
          : shortName;

      AppLogging.protocol(
        'Setting user name: long="$trimmedLong", short="$trimmedShort"',
      );

      final user = pb.User()
        ..longName = trimmedLong
        ..shortName = trimmedShort;

      final adminMsg = admin.AdminMessage()..setOwner = user;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Immediately update local node cache so UI reflects the change
      final existingNode = _nodes[_myNodeNum!];
      if (existingNode != null) {
        final updatedNode = existingNode.copyWith(
          longName: trimmedLong,
          shortName: trimmedShort,
        );
        _nodes[_myNodeNum!] = updatedNode;
        _nodeController.add(updatedNode);
        AppLogging.protocol('Updated local node cache with new name');

        // Also update identity store so name persists across reconnects
        onIdentityUpdate?.call(
          nodeNum: _myNodeNum!,
          longName: trimmedLong,
          shortName: trimmedShort,
          lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      AppLogging.protocol('Error setting user name: $e');
      rethrow;
    }
  }

  /// Set the region/frequency for the device
  /// Also sets usePreset=true and hopLimit=3 to match Meshtastic defaults
  Future<void> setRegion(
    config_pbenum.Config_LoRaConfig_RegionCode region,
  ) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError('Cannot set region: device not ready (no node number)');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set region: not connected to device');
    }

    try {
      AppLogging.protocol('Setting region: ${region.name}');

      // Set Meshtastic defaults: usePreset=true, LONG_FAST preset, hopLimit=3
      final loraConfig = config_pb.Config_LoRaConfig()
        ..usePreset = true
        ..region = region
        ..modemPreset = config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST
        ..hopLimit = 3;

      final config = config_pb.Config()..lora = loraConfig;

      final adminMsg = admin.AdminMessage()..setConfig = config;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error setting region: $e');
      rethrow;
    }
  }

  /// Request full channel details from device
  /// The initial config dump doesn't include moduleSettings (which has positionPrecision)
  /// So we need to explicitly request each channel to get full details
  Future<void> _requestAllChannelDetails() async {
    if (_myNodeNum == null || !_transport.isConnected) return;

    AppLogging.debug('📡 Requesting full channel details for all channels...');

    // Request channels 0-7 (Meshtastic supports up to 8 channels)
    for (var i = 0; i < 8; i++) {
      try {
        await _requestChannelDetails(i);
        // Small delay between requests to avoid overwhelming the device
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        AppLogging.debug('📡 Error requesting channel $i: $e');
      }
    }
  }

  /// Request details for a specific channel
  /// Note: getChannelRequest uses 1-based indexing (channel index + 1)
  /// to avoid sending zero which protobufs treats as not present
  Future<void> _requestChannelDetails(int channelIndex) async {
    try {
      AppLogging.debug('📡 Requesting channel $channelIndex details');

      // Protocol uses 1-based indexing: send channelIndex + 1
      final adminMsg = admin.AdminMessage()
        ..getChannelRequest = channelIndex + 1;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error requesting channel $channelIndex: $e');
    }
  }

  /// Request the current LoRa configuration (for region)
  Future<void> getLoRaConfig({int? targetNodeNum}) async {
    try {
      final target = targetNodeNum ?? _myNodeNum ?? 0;
      AppLogging.protocol(
        'Requesting LoRa config${targetNodeNum != null ? ' from node $targetNodeNum' : ''}',
      );

      // Use ConfigType enum for LoRa config
      final adminMsg = admin.AdminMessage()
        ..getConfigRequest = admin.AdminMessage_ConfigType.LORA_CONFIG;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = target
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error getting LoRa config: $e');
    }
  }

  /// Request the current Position configuration (GPS settings)
  Future<void> getPositionConfig({int? targetNodeNum}) async {
    try {
      final target = targetNodeNum ?? _myNodeNum ?? 0;
      AppLogging.protocol(
        'Requesting Position config${targetNodeNum != null ? ' from node $targetNodeNum' : ''}',
      );

      final adminMsg = admin.AdminMessage()
        ..getConfigRequest = admin.AdminMessage_ConfigType.POSITION_CONFIG;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = target
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error getting Position config: $e');
    }
  }

  // ============================================================================
  // DEVICE MANAGEMENT METHODS
  // ============================================================================

  /// Reboot the device after specified seconds (0 = immediate)
  Future<void> reboot({int delaySeconds = 2}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot reboot: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot reboot: not connected');
    }

    AppLogging.protocol('Rebooting device in $delaySeconds seconds');

    final adminMsg = admin.AdminMessage()..rebootSeconds = delaySeconds;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Shutdown the device after specified seconds (0 = immediate)
  Future<void> shutdown({int delaySeconds = 2}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot shutdown: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot shutdown: not connected');
    }

    AppLogging.protocol('Shutting down device in $delaySeconds seconds');

    final adminMsg = admin.AdminMessage()..shutdownSeconds = delaySeconds;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Factory reset the device configuration (keeps node DB)
  /// The delay parameter specifies seconds to wait before reset (default 5, like official app)
  Future<void> factoryResetConfig({int delaySeconds = 5}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot factory reset config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot factory reset config: not connected');
    }

    AppLogging.protocol(
      'Factory resetting configuration (delay: ${delaySeconds}s)',
    );

    final adminMsg = admin.AdminMessage()..factoryResetConfig = delaySeconds;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Factory reset the entire device (config + node DB)
  /// The delay parameter specifies seconds to wait before reset (default 5, like official app)
  Future<void> factoryResetDevice({int delaySeconds = 5}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot factory reset device: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot factory reset device: not connected');
    }

    AppLogging.protocol(
      'Factory resetting entire device (delay: ${delaySeconds}s)',
    );

    final adminMsg = admin.AdminMessage()..factoryResetDevice = delaySeconds;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Reset the node database (removes all learned nodes)
  /// This sends the reset command to the device and clears the local node cache.
  Future<void> nodeDbReset() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot reset node DB: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot reset node DB: not connected');
    }

    AppLogging.protocol('Resetting node database');

    final adminMsg = admin.AdminMessage()..nodedbReset = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    // Wait for device to process the reset command
    await Future.delayed(const Duration(milliseconds: 500));

    // Clear local nodes cache (keep only our own node)
    clearNodes();
  }

  /// Clear all nodes from the local cache (keeps only own node if known)
  void clearNodes() {
    final myNum = _myNodeNum;
    final myNode = myNum != null ? _nodes[myNum] : null;
    _nodes.clear();
    // Re-add our own node so the app remains functional
    if (myNode != null) {
      _nodes[myNum!] = myNode;
    }
    AppLogging.protocol('Cleared local nodes cache');
  }

  /// Enter DFU (Device Firmware Update) mode
  Future<void> enterDfuMode() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot enter DFU mode: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot enter DFU mode: not connected');
    }

    AppLogging.protocol('Entering DFU mode');

    final adminMsg = admin.AdminMessage()..enterDfuModeRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..channel = 0
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Request device metadata
  Future<void> getDeviceMetadata() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get metadata: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get metadata: not connected');
    }

    AppLogging.protocol('Requesting device metadata...');
    AppLogging.protocol('Requesting device metadata');

    final adminMsg = admin.AdminMessage()..getDeviceMetadataRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  // ============================================================================
  // NODE MANAGEMENT METHODS
  // ============================================================================

  /// Remove a node from the device's node database
  Future<void> removeNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot remove node: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot remove node: not connected');
    }

    AppLogging.protocol('Removing node $nodeNum from device database');

    final adminMsg = admin.AdminMessage()..removeByNodenum = nodeNum;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    AppLogging.protocol('Node $nodeNum removal command sent to device');
  }

  /// Set a node as favorite
  Future<void> setFavoriteNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set favorite: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set favorite: not connected');
    }

    AppLogging.protocol('Setting node $nodeNum as favorite');

    final adminMsg = admin.AdminMessage()..setFavoriteNode = nodeNum;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Remove a node from favorites
  Future<void> removeFavoriteNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot remove favorite: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot remove favorite: not connected');
    }

    AppLogging.protocol('Removing node $nodeNum from favorites');

    final adminMsg = admin.AdminMessage()..removeFavoriteNode = nodeNum;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set a fixed position for the device
  Future<void> setFixedPosition({
    required double latitude,
    required double longitude,
    int altitude = 0,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set fixed position: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set fixed position: not connected');
    }

    AppLogging.protocol(
      'Setting fixed position: $latitude, $longitude, alt=$altitude',
    );

    final position = pb.Position()
      ..latitudeI = (latitude * 1e7).toInt()
      ..longitudeI = (longitude * 1e7).toInt()
      ..altitude = altitude;

    final adminMsg = admin.AdminMessage()..setFixedPosition = position;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Remove fixed position (use GPS)
  Future<void> removeFixedPosition() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot remove fixed position: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot remove fixed position: not connected');
    }

    AppLogging.protocol('Removing fixed position');

    final adminMsg = admin.AdminMessage()..removeFixedPosition = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set a node as ignored (mute messages from this node)
  Future<void> setIgnoredNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set ignored: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set ignored: not connected');
    }

    AppLogging.protocol('Setting node $nodeNum as ignored');

    final adminMsg = admin.AdminMessage()..setIgnoredNode = nodeNum;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Remove a node from ignored list (un-mute)
  Future<void> removeIgnoredNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot remove ignored: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot remove ignored: not connected');
    }

    AppLogging.protocol('Removing node $nodeNum from ignored list');

    final adminMsg = admin.AdminMessage()..removeIgnoredNode = nodeNum;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Toggle muted status for a node on the device (v2.7.18)
  ///
  /// This is different from setIgnoredNode - toggleMutedNode sets the
  /// device-side mute flag (isMuted in NodeInfo), while setIgnoredNode
  /// sets the local app ignore flag.
  Future<void> toggleMutedNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot toggle muted: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot toggle muted: not connected');
    }

    AppLogging.protocol('Toggling muted status for node $nodeNum');

    final adminMsg = admin.AdminMessage()..toggleMutedNode = nodeNum;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set the device time to a specific Unix timestamp
  Future<void> setTimeOnly(int unixTimestamp) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set time: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set time: not connected');
    }

    AppLogging.protocol('Setting device time to $unixTimestamp');

    final adminMsg = admin.AdminMessage()..setTimeOnly = unixTimestamp;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId()
      ..channel =
          0 // Primary channel
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set device time to current time
  Future<void> syncTime() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await setTimeOnly(timestamp);
  }

  // ============================================================================
  // HAM RADIO MODE
  // ============================================================================

  /// Set HAM radio mode with call sign
  Future<void> setHamMode({
    required String callSign,
    int txPower = 0,
    double frequency = 0.0,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set HAM mode: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set HAM mode: not connected');
    }

    AppLogging.protocol('Setting HAM mode: callSign=$callSign');

    final hamParams = admin.HamParameters()
      ..callSign = callSign
      ..txPower = txPower
      ..frequency = frequency;

    final adminMsg = admin.AdminMessage()..setHamMode = hamParams;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  // ============================================================================
  // CONFIGURATION METHODS
  // ============================================================================

  /// Get device configuration by type
  /// If [targetNodeNum] is provided, requests config from that remote node
  /// (requires remote admin authorization on the target node)
  Future<void> getConfig(
    admin.AdminMessage_ConfigType configType, {
    int? targetNodeNum,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get config: not connected');
    }

    final target = targetNodeNum ?? _myNodeNum!;
    final isRemote = target != _myNodeNum;

    AppLogging.protocol(
      'Requesting config: ${configType.name}${isRemote ? ' from remote node $target' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Requesting ${configType.name} from ${target.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..getConfigRequest = configType;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = target
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set device configuration
  /// If [targetNodeNum] is provided, sends config to that remote node
  /// (requires remote admin authorization on the target node)
  Future<void> setConfig(config_pb.Config config, {int? targetNodeNum}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set config: not connected');
    }

    final target = targetNodeNum ?? _myNodeNum!;
    final isRemote = target != _myNodeNum;

    AppLogging.protocol(
      'Setting config${isRemote ? ' on remote node $target' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Setting config on ${target.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..setConfig = config;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = target
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set LoRa configuration (region, modem preset, TX power, etc.)
  Future<void> setLoRaConfig({
    required config_pbenum.Config_LoRaConfig_RegionCode region,
    required config_pbenum.Config_LoRaConfig_ModemPreset modemPreset,
    required int hopLimit,
    required bool txEnabled,
    required int txPower,
    bool usePreset = true,
    bool overrideDutyCycle = false,
    int channelNum = 0,
    int bandwidth = 0,
    int spreadFactor = 0,
    int codingRate = 0,
    bool sx126xRxBoostedGain = false,
    double overrideFrequency = 0.0,
    bool ignoreMqtt = false,
    bool configOkToMqtt = false,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting LoRa config');

    final loraConfig = config_pb.Config_LoRaConfig()
      ..usePreset = usePreset
      ..region = region
      ..modemPreset = modemPreset
      ..hopLimit = hopLimit
      ..txEnabled = txEnabled
      ..txPower = txPower
      ..overrideDutyCycle = overrideDutyCycle
      ..channelNum = channelNum
      ..bandwidth = bandwidth
      ..spreadFactor = spreadFactor
      ..codingRate = codingRate
      ..sx126xRxBoostedGain = sx126xRxBoostedGain
      ..overrideFrequency = overrideFrequency
      ..ignoreMqtt = ignoreMqtt
      ..configOkToMqtt = configOkToMqtt;

    final config = config_pb.Config()..lora = loraConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set device configuration (role, serial, etc.)
  Future<void> setDeviceConfig({
    required config_pbenum.Config_DeviceConfig_Role role,
    required config_pbenum.Config_DeviceConfig_RebroadcastMode rebroadcastMode,
    required bool serialEnabled,
    required int nodeInfoBroadcastSecs,
    required bool ledHeartbeatDisabled,
    bool doubleTapAsButtonPress = false,
    int buttonGpio = 0,
    int buzzerGpio = 0,
    bool disableTripleClick = false,
    String tzdef = '',
    config_pbenum.Config_DeviceConfig_BuzzerMode buzzerMode =
        config_pbenum.Config_DeviceConfig_BuzzerMode.ALL_ENABLED,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting device config');

    final deviceConfig = config_pb.Config_DeviceConfig()
      ..role = role
      ..rebroadcastMode = rebroadcastMode
      ..serialEnabled = serialEnabled
      ..nodeInfoBroadcastSecs = nodeInfoBroadcastSecs
      ..doubleTapAsButtonPress = doubleTapAsButtonPress
      ..ledHeartbeatDisabled = ledHeartbeatDisabled
      ..buttonGpio = buttonGpio
      ..buzzerGpio = buzzerGpio
      ..disableTripleClick = disableTripleClick
      ..tzdef = tzdef
      ..buzzerMode = buzzerMode;

    final config = config_pb.Config()..device = deviceConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set position configuration
  Future<void> setPositionConfig({
    required int positionBroadcastSecs,
    required bool positionBroadcastSmartEnabled,
    required bool fixedPosition,
    required config_pb.Config_PositionConfig_GpsMode gpsMode,
    required int gpsUpdateInterval,
    int gpsAttemptTime = 30,
    int broadcastSmartMinimumDistance = 100,
    int broadcastSmartMinimumIntervalSecs = 30,
    int positionFlags = 811,
    int rxGpio = 0,
    int txGpio = 0,
    int gpsEnGpio = 0,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting position config: gpsMode=$gpsMode');

    final posConfig = config_pb.Config_PositionConfig()
      ..positionBroadcastSecs = positionBroadcastSecs
      ..positionBroadcastSmartEnabled = positionBroadcastSmartEnabled
      ..fixedPosition = fixedPosition
      ..gpsMode = gpsMode
      ..gpsEnabled = gpsMode == config_pb.Config_PositionConfig_GpsMode.ENABLED
      ..gpsUpdateInterval = gpsUpdateInterval
      ..gpsAttemptTime = gpsAttemptTime
      ..broadcastSmartMinimumDistance = broadcastSmartMinimumDistance
      ..broadcastSmartMinimumIntervalSecs = broadcastSmartMinimumIntervalSecs
      ..positionFlags = positionFlags
      ..rxGpio = rxGpio
      ..txGpio = txGpio
      ..gpsEnGpio = gpsEnGpio;

    final config = config_pb.Config()..position = posConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set power configuration
  Future<void> setPowerConfig({
    required bool isPowerSaving,
    required int waitBluetoothSecs,
    required int sdsSecs,
    required int lsSecs,
    required int minWakeSecs,
    int onBatteryShutdownAfterSecs = 0,
    double adcMultiplierOverride = 0.0,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting power config');

    final powerConfig = config_pb.Config_PowerConfig()
      ..isPowerSaving = isPowerSaving
      ..onBatteryShutdownAfterSecs = onBatteryShutdownAfterSecs
      ..adcMultiplierOverride = adcMultiplierOverride
      ..waitBluetoothSecs = waitBluetoothSecs
      ..sdsSecs = sdsSecs
      ..lsSecs = lsSecs
      ..minWakeSecs = minWakeSecs;

    final config = config_pb.Config()..power = powerConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set display configuration
  Future<void> setDisplayConfig({
    required int screenOnSecs,
    required int autoScreenCarouselSecs,
    required bool flipScreen,
    required config_pb.Config_DisplayConfig_DisplayUnits units,
    required config_pb.Config_DisplayConfig_DisplayMode displayMode,
    required bool headingBold,
    required bool wakeOnTapOrMotion,
    bool use12hClock = false,
    config_pb.Config_DisplayConfig_OledType oledType =
        config_pb.Config_DisplayConfig_OledType.OLED_AUTO,
    config_pb.Config_DisplayConfig_CompassOrientation compassOrientation =
        config_pb.Config_DisplayConfig_CompassOrientation.DEGREES_0,
    bool compassNorthTop = false,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting display config');

    final displayConfig = config_pb.Config_DisplayConfig()
      ..screenOnSecs = screenOnSecs
      ..autoScreenCarouselSecs = autoScreenCarouselSecs
      ..flipScreen = flipScreen
      ..units = units
      ..displaymode = displayMode
      ..headingBold = headingBold
      ..wakeOnTapOrMotion = wakeOnTapOrMotion
      ..use12hClock = use12hClock
      ..oled = oledType
      ..compassOrientation = compassOrientation
      ..compassNorthTop = compassNorthTop;

    final config = config_pb.Config()..display = displayConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set Bluetooth configuration
  Future<void> setBluetoothConfig({
    required bool enabled,
    required config_pb.Config_BluetoothConfig_PairingMode mode,
    required int fixedPin,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting Bluetooth config');

    final btConfig = config_pb.Config_BluetoothConfig()
      ..enabled = enabled
      ..mode = mode
      ..fixedPin = fixedPin;

    final config = config_pb.Config()..bluetooth = btConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set network configuration
  Future<void> setNetworkConfig({
    required bool wifiEnabled,
    required String wifiSsid,
    required String wifiPsk,
    required bool ethEnabled,
    required String ntpServer,
    config_pb.Config_NetworkConfig_AddressMode addressMode =
        config_pb.Config_NetworkConfig_AddressMode.DHCP,
    String rsyslogServer = '',
    int enabledProtocols = 0,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting network config');

    final networkConfig = config_pb.Config_NetworkConfig()
      ..wifiEnabled = wifiEnabled
      ..wifiSsid = wifiSsid
      ..wifiPsk = wifiPsk
      ..ethEnabled = ethEnabled
      ..ntpServer = ntpServer
      ..addressMode = addressMode
      ..rsyslogServer = rsyslogServer
      ..enabledProtocols = enabledProtocols;

    final config = config_pb.Config()..network = networkConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  /// Set security configuration
  Future<void> setSecurityConfig({
    required bool isManaged,
    required bool serialEnabled,
    required bool debugLogEnabled,
    required bool adminChannelEnabled,
    List<int> privateKey = const [],
    List<List<int>> adminKeys = const [],
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting security config');

    final secConfig = config_pb.Config_SecurityConfig()
      ..isManaged = isManaged
      ..serialEnabled = serialEnabled
      ..debugLogApiEnabled = debugLogEnabled
      ..adminChannelEnabled = adminChannelEnabled;

    // Set private key if provided
    if (privateKey.isNotEmpty) {
      secConfig.privateKey = privateKey;
    }

    // Set admin keys if provided
    if (adminKeys.isNotEmpty) {
      secConfig.adminKey.addAll(adminKeys);
    }

    final config = config_pb.Config()..security = secConfig;
    await setConfig(config, targetNodeNum: targetNodeNum);
  }

  // ============================================================================
  // MODULE CONFIGURATION METHODS
  // ============================================================================

  /// Get module configuration by type
  /// If [targetNodeNum] is provided, requests config from that remote node
  Future<void> getModuleConfig(
    admin.AdminMessage_ModuleConfigType moduleType, {
    int? targetNodeNum,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get module config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get module config: not connected');
    }

    final target = targetNodeNum ?? _myNodeNum!;
    final isRemote = target != _myNodeNum;

    AppLogging.protocol(
      'Requesting module config: ${moduleType.name}${isRemote ? ' from remote node $target' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Requesting ${moduleType.name} from ${target.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..getModuleConfigRequest = moduleType;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = target
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set module configuration
  /// If [targetNodeNum] is provided, sends config to that remote node
  Future<void> setModuleConfig(
    module_pb.ModuleConfig moduleConfig, {
    int? targetNodeNum,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set module config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set module config: not connected');
    }

    final target = targetNodeNum ?? _myNodeNum!;
    final isRemote = target != _myNodeNum;

    AppLogging.protocol(
      'Setting module config${isRemote ? ' on remote node $target' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Setting module config on ${target.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..setModuleConfig = moduleConfig;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = target
      ..decoded = data
      ..id = _generatePacketId()
      ..priority = pbenum.MeshPacket_Priority.RELIABLE
      ..wantAck = true;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set MQTT module configuration
  Future<void> setMQTTConfig({
    required bool enabled,
    required String address,
    required String username,
    required String password,
    required bool encryptionEnabled,
    required bool jsonEnabled,
    required bool tlsEnabled,
    required String root,
    required bool proxyToClientEnabled,
    required bool mapReportingEnabled,
    int mapPublishIntervalSecs = 3600,
    int mapPositionPrecision = 14,
    int? targetNodeNum,
  }) async {
    final isRemote = targetNodeNum != null && targetNodeNum != _myNodeNum;
    AppLogging.protocol(
      'Setting MQTT config${isRemote ? ' on remote node $targetNodeNum' : ''}',
    );

    final mapReportSettings = module_pb.ModuleConfig_MapReportSettings()
      ..publishIntervalSecs = mapPublishIntervalSecs
      ..positionPrecision = mapPositionPrecision;

    final mqttConfig = module_pb.ModuleConfig_MQTTConfig()
      ..enabled = enabled
      ..address = address
      ..username = username
      ..password = password
      ..encryptionEnabled = encryptionEnabled
      ..jsonEnabled = jsonEnabled
      ..tlsEnabled = tlsEnabled
      ..root = root
      ..proxyToClientEnabled = proxyToClientEnabled
      ..mapReportingEnabled = mapReportingEnabled
      ..mapReportSettings = mapReportSettings;

    final moduleConfig = module_pb.ModuleConfig()..mqtt = mqttConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Set canned message module configuration
  Future<void> setCannedMessageConfig({
    required bool enabled,
    required bool sendBell,
    required bool rotary1Enabled,
    required bool updown1Enabled,
    required String allowInputSource,
    required int inputbrokerPinA,
    required int inputbrokerPinB,
    required int inputbrokerPinPress,
    required module_pb.ModuleConfig_CannedMessageConfig_InputEventChar
    inputbrokerEventCw,
    required module_pb.ModuleConfig_CannedMessageConfig_InputEventChar
    inputbrokerEventCcw,
    required module_pb.ModuleConfig_CannedMessageConfig_InputEventChar
    inputbrokerEventPress,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting canned message config');

    final cannedConfig = module_pb.ModuleConfig_CannedMessageConfig()
      ..enabled = enabled
      ..sendBell = sendBell
      ..rotary1Enabled = rotary1Enabled
      ..updown1Enabled = updown1Enabled
      ..allowInputSource = allowInputSource
      ..inputbrokerPinA = inputbrokerPinA
      ..inputbrokerPinB = inputbrokerPinB
      ..inputbrokerPinPress = inputbrokerPinPress
      ..inputbrokerEventCw = inputbrokerEventCw
      ..inputbrokerEventCcw = inputbrokerEventCcw
      ..inputbrokerEventPress = inputbrokerEventPress;

    final moduleConfig = module_pb.ModuleConfig()..cannedMessage = cannedConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Get Telemetry module configuration
  /// Returns the current telemetry config, requesting from device if needed
  Future<module_pb.ModuleConfig_TelemetryConfig?>
  getTelemetryModuleConfig() async {
    // If we already have the config, return it
    if (_currentTelemetryConfig != null) {
      return _currentTelemetryConfig;
    }

    // Request config from device
    await getModuleConfig(admin.AdminMessage_ModuleConfigType.TELEMETRY_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _telemetryConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Telemetry config request timed out'),
      );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get telemetry config: $e');
      return null;
    }
  }

  /// Set Telemetry module configuration
  Future<void> setTelemetryModuleConfig({
    int? deviceUpdateInterval,
    bool? deviceTelemetryEnabled,
    int? environmentUpdateInterval,
    bool? environmentMeasurementEnabled,
    bool? environmentScreenEnabled,
    bool? environmentDisplayFahrenheit,
    bool? airQualityEnabled,
    int? airQualityInterval,
    bool? powerMeasurementEnabled,
    int? powerUpdateInterval,
    bool? powerScreenEnabled,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting telemetry config');

    final telemetryConfig = module_pb.ModuleConfig_TelemetryConfig();
    if (deviceUpdateInterval != null) {
      telemetryConfig.deviceUpdateInterval = deviceUpdateInterval;
    }
    if (deviceTelemetryEnabled != null) {
      telemetryConfig.deviceTelemetryEnabled = deviceTelemetryEnabled;
    }
    if (environmentUpdateInterval != null) {
      telemetryConfig.environmentUpdateInterval = environmentUpdateInterval;
    }
    if (environmentMeasurementEnabled != null) {
      telemetryConfig.environmentMeasurementEnabled =
          environmentMeasurementEnabled;
    }
    if (environmentScreenEnabled != null) {
      telemetryConfig.environmentScreenEnabled = environmentScreenEnabled;
    }
    if (environmentDisplayFahrenheit != null) {
      telemetryConfig.environmentDisplayFahrenheit =
          environmentDisplayFahrenheit;
    }
    if (airQualityEnabled != null) {
      telemetryConfig.airQualityEnabled = airQualityEnabled;
    }
    if (airQualityInterval != null) {
      telemetryConfig.airQualityInterval = airQualityInterval;
    }
    if (powerMeasurementEnabled != null) {
      telemetryConfig.powerMeasurementEnabled = powerMeasurementEnabled;
    }
    if (powerUpdateInterval != null) {
      telemetryConfig.powerUpdateInterval = powerUpdateInterval;
    }
    if (powerScreenEnabled != null) {
      telemetryConfig.powerScreenEnabled = powerScreenEnabled;
    }

    final moduleConfig = module_pb.ModuleConfig()..telemetry = telemetryConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Get External Notification module configuration
  Future<module_pb.ModuleConfig_ExternalNotificationConfig?>
  getExternalNotificationModuleConfig() async {
    // If we already have the config, return it
    if (_currentExternalNotificationConfig != null) {
      return _currentExternalNotificationConfig;
    }

    // Request config from device
    await getModuleConfig(admin.AdminMessage_ModuleConfigType.EXTNOTIF_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _externalNotificationConfigController.stream.first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'External notification config request timed out',
            ),
          );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get external notification config: $e');
      return null;
    }
  }

  /// Set External Notification module configuration
  Future<void> setExternalNotificationConfig({
    bool? enabled,
    int? output,
    int? outputMs,
    bool? active,
    bool? alertMessage,
    bool? alertBell,
    bool? alertMessageVibra,
    bool? alertMessageBuzzer,
    bool? alertBellVibra,
    bool? alertBellBuzzer,
    int? outputVibra,
    int? outputBuzzer,
    bool? usePwm,
    bool? useI2sAsBuzzer,
    int? nagTimeout,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting external notification config');

    final extNotifConfig = module_pb.ModuleConfig_ExternalNotificationConfig();
    if (enabled != null) extNotifConfig.enabled = enabled;
    if (output != null) extNotifConfig.output = output;
    if (outputMs != null) extNotifConfig.outputMs = outputMs;
    if (active != null) extNotifConfig.active = active;
    if (alertMessage != null) extNotifConfig.alertMessage = alertMessage;
    if (alertBell != null) extNotifConfig.alertBell = alertBell;
    if (alertMessageVibra != null) {
      extNotifConfig.alertMessageVibra = alertMessageVibra;
    }
    if (alertMessageBuzzer != null) {
      extNotifConfig.alertMessageBuzzer = alertMessageBuzzer;
    }
    if (alertBellVibra != null) {
      extNotifConfig.alertBellVibra = alertBellVibra;
    }
    if (alertBellBuzzer != null) {
      extNotifConfig.alertBellBuzzer = alertBellBuzzer;
    }
    if (outputVibra != null) extNotifConfig.outputVibra = outputVibra;
    if (outputBuzzer != null) extNotifConfig.outputBuzzer = outputBuzzer;
    if (usePwm != null) extNotifConfig.usePwm = usePwm;
    if (useI2sAsBuzzer != null) {
      extNotifConfig.useI2sAsBuzzer = useI2sAsBuzzer;
    }
    if (nagTimeout != null) extNotifConfig.nagTimeout = nagTimeout;

    final moduleConfig = module_pb.ModuleConfig()
      ..externalNotification = extNotifConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Set Store & Forward module configuration
  Future<void> setStoreForwardConfig({
    bool? enabled,
    bool? heartbeat,
    int? records,
    int? historyReturnMax,
    int? historyReturnWindow,
    bool? isServer,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting store & forward config');

    final sfConfig = module_pb.ModuleConfig_StoreForwardConfig();
    if (enabled != null) sfConfig.enabled = enabled;
    if (heartbeat != null) sfConfig.heartbeat = heartbeat;
    if (records != null) sfConfig.records = records;
    if (historyReturnMax != null) sfConfig.historyReturnMax = historyReturnMax;
    if (historyReturnWindow != null) {
      sfConfig.historyReturnWindow = historyReturnWindow;
    }
    if (isServer != null) sfConfig.isServer = isServer;

    final moduleConfig = module_pb.ModuleConfig()..storeForward = sfConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Get Store & Forward module configuration
  Future<module_pb.ModuleConfig_StoreForwardConfig?>
  getStoreForwardModuleConfig() async {
    // If we already have the config, return it
    if (_currentStoreForwardConfig != null) {
      return _currentStoreForwardConfig;
    }

    // Request config from device
    await getModuleConfig(
      admin.AdminMessage_ModuleConfigType.STOREFORWARD_CONFIG,
    );

    // Wait for response with timeout
    try {
      final config = await _storeForwardConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Store forward config request timed out'),
      );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get store forward config: $e');
      return null;
    }
  }

  /// Get Detection Sensor module configuration
  Future<module_pb.ModuleConfig_DetectionSensorConfig?>
  getDetectionSensorModuleConfig() async {
    // If we already have the config, return it
    if (_currentDetectionSensorConfig != null) {
      return _currentDetectionSensorConfig;
    }

    // Request config from device
    await getModuleConfig(
      admin.AdminMessage_ModuleConfigType.DETECTIONSENSOR_CONFIG,
    );

    // Wait for response with timeout
    try {
      final config = await _detectionSensorConfigController.stream.first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'Detection sensor config request timed out',
            ),
          );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get detection sensor config: $e');
      return null;
    }
  }

  /// Get Range Test module configuration
  Future<module_pb.ModuleConfig_RangeTestConfig?>
  getRangeTestModuleConfig() async {
    // If we already have the config, return it
    if (_currentRangeTestConfig != null) {
      return _currentRangeTestConfig;
    }

    // Request config from device
    await getModuleConfig(admin.AdminMessage_ModuleConfigType.RANGETEST_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _rangeTestConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Range test config request timed out'),
      );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get range test config: $e');
      return null;
    }
  }

  /// Set Range Test module configuration
  Future<void> setRangeTestConfig({
    bool? enabled,
    int? sender,
    bool? save,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting range test config');

    final rtConfig = module_pb.ModuleConfig_RangeTestConfig();
    if (enabled != null) rtConfig.enabled = enabled;
    if (sender != null) rtConfig.sender = sender;
    if (save != null) rtConfig.save = save;

    final moduleConfig = module_pb.ModuleConfig()..rangeTest = rtConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Get Ambient Lighting module configuration
  Future<module_pb.ModuleConfig_AmbientLightingConfig?>
  getAmbientLightingModuleConfig() async {
    // If we already have the config, return it
    if (_currentAmbientLightingConfig != null) {
      return _currentAmbientLightingConfig;
    }

    // Request config from device
    await getModuleConfig(
      admin.AdminMessage_ModuleConfigType.AMBIENTLIGHTING_CONFIG,
    );

    // Wait for response with timeout
    try {
      final config = await _ambientLightingConfigController.stream.first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'Ambient lighting config request timed out',
            ),
          );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get ambient lighting config: $e');
      return null;
    }
  }

  /// Set Ambient Lighting module configuration
  Future<void> setAmbientLightingConfig({
    required bool ledState,
    required int red,
    required int green,
    required int blue,
    int? current,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting ambient lighting config');

    final alConfig = module_pb.ModuleConfig_AmbientLightingConfig();
    alConfig.ledState = ledState;
    alConfig.red = red;
    alConfig.green = green;
    alConfig.blue = blue;
    if (current != null) alConfig.current = current;

    final moduleConfig = module_pb.ModuleConfig()..ambientLighting = alConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Get PAX Counter module configuration
  Future<module_pb.ModuleConfig_PaxcounterConfig?>
  getPaxCounterModuleConfig() async {
    // If we already have the config, return it
    if (_currentPaxCounterConfig != null) {
      return _currentPaxCounterConfig;
    }

    // Request config from device
    await getModuleConfig(
      admin.AdminMessage_ModuleConfigType.PAXCOUNTER_CONFIG,
    );

    // Wait for response with timeout
    try {
      final config = await _paxCounterConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('PAX counter config request timed out'),
      );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get PAX counter config: $e');
      return null;
    }
  }

  /// Set PAX Counter module configuration
  Future<void> setPaxCounterConfig({
    bool? enabled,
    int? updateInterval,
    bool? wifiEnabled,
    bool? bleEnabled,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting PAX counter config');

    final paxConfig = module_pb.ModuleConfig_PaxcounterConfig();
    if (enabled != null) paxConfig.enabled = enabled;
    if (updateInterval != null) {
      paxConfig.paxcounterUpdateInterval = updateInterval;
    }

    final moduleConfig = module_pb.ModuleConfig()..paxcounter = paxConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  /// Get Serial module configuration
  Future<module_pb.ModuleConfig_SerialConfig?> getSerialModuleConfig() async {
    // If we already have the config, return it
    if (_currentSerialConfig != null) {
      return _currentSerialConfig;
    }

    // Request config from device
    await getModuleConfig(admin.AdminMessage_ModuleConfigType.SERIAL_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _serialConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Serial config request timed out'),
      );
      return config;
    } catch (e) {
      AppLogging.protocol('Failed to get serial config: $e');
      return null;
    }
  }

  /// Set Serial module configuration
  Future<void> setSerialConfig({
    bool? enabled,
    bool? echo,
    int? rxd,
    int? txd,
    int? baud,
    int? timeout,
    int? mode,
    bool? overrideConsoleSerialPort,
    int? targetNodeNum,
  }) async {
    AppLogging.protocol('Setting serial config');

    final serialConfig = module_pb.ModuleConfig_SerialConfig();
    if (enabled != null) serialConfig.enabled = enabled;
    if (echo != null) serialConfig.echo = echo;
    if (rxd != null) serialConfig.rxd = rxd;
    if (txd != null) serialConfig.txd = txd;
    if (baud != null) {
      serialConfig.baud =
          module_pb.ModuleConfig_SerialConfig_Serial_Baud.valueOf(baud) ??
          module_pb.ModuleConfig_SerialConfig_Serial_Baud.BAUD_DEFAULT;
    }
    if (timeout != null) serialConfig.timeout = timeout;
    if (mode != null) {
      serialConfig.mode =
          module_pb.ModuleConfig_SerialConfig_Serial_Mode.valueOf(mode) ??
          module_pb.ModuleConfig_SerialConfig_Serial_Mode.DEFAULT;
    }
    if (overrideConsoleSerialPort != null) {
      serialConfig.overrideConsoleSerialPort = overrideConsoleSerialPort;
    }

    final moduleConfig = module_pb.ModuleConfig()..serial = serialConfig;
    await setModuleConfig(moduleConfig, targetNodeNum: targetNodeNum);
  }

  // ============================================================================
  // CANNED MESSAGES & RINGTONE
  // ============================================================================

  /// Get canned messages
  Future<void> getCannedMessages() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get canned messages: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get canned messages: not connected');
    }

    AppLogging.protocol('Requesting canned messages');

    final adminMsg = admin.AdminMessage()
      ..getCannedMessageModuleMessagesRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set canned messages (pipe-separated list)
  Future<void> setCannedMessages(String messages) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set canned messages: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set canned messages: not connected');
    }

    AppLogging.protocol('Setting canned messages');

    final adminMsg = admin.AdminMessage()
      ..setCannedMessageModuleMessages = messages;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Get device ringtone
  Future<void> getRingtone() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get ringtone: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get ringtone: not connected');
    }

    AppLogging.protocol('Requesting ringtone');

    final adminMsg = admin.AdminMessage()..getRingtoneRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set device ringtone (RTTTL format)
  Future<void> setRingtone(String rtttl) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set ringtone: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set ringtone: not connected');
    }

    AppLogging.protocol('Setting ringtone');

    final adminMsg = admin.AdminMessage()..setRingtoneMessage = rtttl;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Delete a file from the device
  Future<void> deleteFile(String filename) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot delete file: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot delete file: not connected');
    }

    AppLogging.protocol('Deleting file: $filename');

    final adminMsg = admin.AdminMessage()..deleteFileRequest = filename;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Infer hardware model from BLE device name
  /// Returns null if unable to determine
  String? _inferHardwareModelFromDeviceName(String? deviceName) {
    if (deviceName == null || deviceName.isEmpty) return null;

    final nameLower = deviceName.toLowerCase();

    // Map of device name patterns to hardware model display names
    // Patterns are checked in order, more specific patterns first
    final patterns = <String, String>{
      't1000-e': 'Tracker T1000-E',
      't1000e': 'Tracker T1000-E',
      'sensecap indicator': 'SenseCAP Indicator',
      'sensecap': 'SenseCAP Indicator', // Generic SenseCAP fallback
      't-beam supreme': 'T-Beam Supreme',
      'tbeam supreme': 'T-Beam Supreme',
      't-beam s3': 'LilyGo T-Beam S3 Core',
      'tbeam s3': 'LilyGo T-Beam S3 Core',
      't-beam': 'T-Beam',
      'tbeam': 'T-Beam',
      't-echo': 'T-Echo',
      'techo': 'T-Echo',
      't-deck': 'T-Deck',
      'tdeck': 'T-Deck',
      't-watch': 'T-Watch S3',
      'twatch': 'T-Watch S3',
      't-lora': 'T-LoRa V2',
      'tlora': 'T-LoRa V2',
      'heltec v3': 'Heltec V3',
      'heltec wireless tracker': 'Heltec Wireless Tracker',
      'heltec wireless paper': 'Heltec Wireless Paper',
      'heltec mesh node': 'Heltec Mesh Node T114',
      'heltec capsule': 'Heltec Capsule Sensor V3',
      'heltec vision master': 'Heltec Vision Master T190',
      'heltec': 'Heltec V3', // Generic Heltec fallback
      'rak4631': 'RAK4631',
      'rak meshtastic': 'RAK4631',
      'rak': 'RAK4631', // Generic RAK fallback
      'wio wm1110': 'Wio WM1110',
      'wio tracker': 'Wio WM1110',
      'nano g2': 'Nano G2 Ultra',
      'nano g1': 'Nano G1',
      'station g2': 'Station G2',
      'station g1': 'Station G1',
      'rp2040': 'RP2040 LoRa',
      'pico': 'Raspberry Pi Pico',
      'chatter': 'Chatter 2',
      'picomputer': 'Pi Computer S3',
    };

    for (final entry in patterns.entries) {
      if (nameLower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Infer hardware model from any available source
  /// Checks BLE model number first (most reliable), then manufacturer name, then device name
  String? _inferHardwareModel() {
    // First try BLE model number from Device Information Service
    if (_bleModelNumber != null && _bleModelNumber!.isNotEmpty) {
      final inferred = _inferHardwareModelFromDeviceName(_bleModelNumber);
      if (inferred != null) {
        AppLogging.protocol(
          'Inferred hardware from BLE model number "$_bleModelNumber": $inferred',
        );
        return inferred;
      }
    }

    // Try manufacturer name - SenseCAP/Seeed devices
    if (_bleManufacturerName != null && _bleManufacturerName!.isNotEmpty) {
      final mfgLower = _bleManufacturerName!.toLowerCase();
      if (mfgLower.contains('sensecap') || mfgLower.contains('seeed')) {
        AppLogging.protocol(
          'Inferred hardware from manufacturer "$_bleManufacturerName": Tracker T1000-E',
        );
        return 'Tracker T1000-E';
      }
    }

    // Fall back to device name
    if (_deviceName != null && _deviceName!.isNotEmpty) {
      final inferred = _inferHardwareModelFromDeviceName(_deviceName);
      if (inferred != null) {
        AppLogging.protocol(
          'Inferred hardware from device name "$_deviceName": $inferred',
        );
        return inferred;
      }
    }

    return null;
  }

  /// Format hardware model enum to readable string
  String _formatHardwareModel(pb.HardwareModel model) {
    // Convert enum name to readable format
    // e.g., HELTEC_V3 -> Heltec V3, TLORA_V2_1_1p6 -> T-LoRa V2.1 1.6
    final name = model.name;

    // Handle special cases
    final specialNames = {
      'UNSET': 'Unknown',
      'TLORA_V2': 'T-LoRa V2',
      'TLORA_V1': 'T-LoRa V1',
      'TLORA_V2_1_1p6': 'T-LoRa V2.1 1.6',
      'TLORA_V2_1_1p8': 'T-LoRa V2.1 1.8',
      'TLORA_V1_1p3': 'T-LoRa V1 1.3',
      'TLORA_T3_S3': 'T-LoRa T3-S3',
      'TBEAM': 'T-Beam',
      'TBEAM0p7': 'T-Beam 0.7',
      'T_ECHO': 'T-Echo',
      'T_DECK': 'T-Deck',
      'T_WATCH_S3': 'T-Watch S3',
      'HELTEC_V1': 'Heltec V1',
      'HELTEC_V2_0': 'Heltec V2.0',
      'HELTEC_V2_1': 'Heltec V2.1',
      'HELTEC_V3': 'Heltec V3',
      'HELTEC_WSL_V3': 'Heltec WSL V3',
      'HELTEC_WIRELESS_PAPER': 'Heltec Wireless Paper',
      'HELTEC_WIRELESS_PAPER_V1_0': 'Heltec Wireless Paper V1.0',
      'HELTEC_WIRELESS_PAPER_V1_1': 'Heltec Wireless Paper V1.1',
      'HELTEC_WIRELESS_TRACKER': 'Heltec Wireless Tracker',
      'HELTEC_HT62': 'Heltec HT62',
      'HELTEC_CAPSULE_SENSOR_V3': 'Heltec Capsule Sensor V3',
      'HELTEC_CAPSULE_SENSOR_V3_COMPACT': 'Heltec Capsule Sensor V3 Compact',
      'HELTEC_VISION_MASTER_T190': 'Heltec Vision Master T190',
      'HELTEC_VISION_MASTER_E213': 'Heltec Vision Master E213',
      'HELTEC_VISION_MASTER_E290': 'Heltec Vision Master E290',
      'HELTEC_MESH_NODE_T114': 'Heltec Mesh Node T114',
      'HELTEC_HRU_3601': 'Heltec HRU-3601',
      'RAK4631': 'RAK4631',
      'RAK11200': 'RAK11200',
      'RAK11310': 'RAK11310',
      'RAK2560': 'RAK2560',
      'RAK3172': 'RAK3172',
      'LILYGO_TBEAM_S3_CORE': 'LilyGo T-Beam S3 Core',
      'NANO_G1': 'Nano G1',
      'NANO_G1_EXPLORER': 'Nano G1 Explorer',
      'NANO_G2_ULTRA': 'Nano G2 Ultra',
      'STATION_G1': 'Station G1',
      'STATION_G2': 'Station G2',
      'WIO_WM1110': 'Wio WM1110',
      'WIO_E5': 'Wio E5',
      'SENSECAP_INDICATOR': 'Seeed SenseCAP Indicator',
      'TRACKER_T1000_E': 'Seeed Card Tracker T1000-E',
      'M5STACK': 'M5Stack',
      'PICOMPUTER_S3': 'Pi Computer S3',
      'RP2040_LORA': 'RP2040 LoRa',
      'RPI_PICO': 'Raspberry Pi Pico',
      'ESP32_S3_PICO': 'ESP32-S3 Pico',
      'EBYTE_ESP32_S3': 'EByte ESP32-S3',
      'CHATTER_2': 'Chatter 2',
      'NRF52840DK': 'nRF52840 DK',
      'NRF52_UNKNOWN': 'nRF52 Unknown',
      'NRF52840_PCA10059': 'nRF52840 PCA10059',
      'PORTDUINO': 'Portduino',
      'ANDROID_SIM': 'Android Simulator',
      'DIY_V1': 'DIY V1',
      'DR_DEV': 'DR Dev',
      'PRIVATE_HW': 'Private Hardware',
    };

    if (specialNames.containsKey(name)) {
      return specialNames[name]!;
    }

    // Default: replace underscores with spaces and title case
    return name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await _messageController.close();
    await _nodeController.close();
    await _channelController.close();
    await _errorController.close();
    await _signalController.close();
    await _deliveryController.close();
    await _regionController.close();
    await _clientNotificationController.close();
    await _userConfigController.close();
  }
}
