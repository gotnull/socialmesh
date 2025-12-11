import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../models/mesh_models.dart';
import '../../models/device_error.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/mesh.pbenum.dart' as pbenum;
import '../../generated/meshtastic/portnums.pb.dart' as pn;
import '../../generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'packet_framer.dart';

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
  final Logger _logger;
  final PacketFramer _framer;

  final StreamController<Message> _messageController;
  final StreamController<MeshNode> _nodeController;
  final StreamController<ChannelConfig> _channelController;
  final StreamController<DeviceError> _errorController;
  final StreamController<int> _myNodeNumController;
  final StreamController<int> _rssiController;
  final StreamController<double> _snrController;
  final StreamController<double> _channelUtilController;
  final StreamController<MessageDeliveryUpdate> _deliveryController;
  final StreamController<pbenum.RegionCode> _regionController;
  final StreamController<pb.Config_PositionConfig> _positionConfigController;
  final StreamController<pb.Config_DeviceConfig> _deviceConfigController;
  final StreamController<pb.Config_DisplayConfig> _displayConfigController;
  final StreamController<pb.Config_PowerConfig> _powerConfigController;
  final StreamController<pb.Config_NetworkConfig> _networkConfigController;
  final StreamController<pb.Config_BluetoothConfig> _bluetoothConfigController;
  final StreamController<pb.Config_SecurityConfig> _securityConfigController;
  final StreamController<pb.Config_LoRaConfig> _loraConfigController;
  final StreamController<pb.ModuleConfig_MQTTConfig> _mqttConfigController;
  final StreamController<pb.ModuleConfig_TelemetryConfig>
  _telemetryConfigController;
  final StreamController<pb.ModuleConfig_PaxcounterConfig>
  _paxCounterConfigController;
  final StreamController<pb.ModuleConfig_AmbientLightingConfig>
  _ambientLightingConfigController;
  final StreamController<pb.ModuleConfig_SerialConfig> _serialConfigController;
  final StreamController<pb.ModuleConfig_StoreForwardConfig>
  _storeForwardConfigController;
  final StreamController<pb.ModuleConfig_DetectionSensorConfig>
  _detectionSensorConfigController;
  final StreamController<pb.ModuleConfig_RangeTestConfig>
  _rangeTestConfigController;
  final StreamController<pb.ModuleConfig_ExternalNotificationConfig>
  _externalNotificationConfigController;

  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<DeviceConnectionState>? _transportStateSubscription;
  Completer<void>? _configCompleter;
  Timer? _rssiTimer;

  int? _myNodeNum;
  int _lastRssi = -90;
  double _lastSnr = 0.0;
  double _lastChannelUtil = 0.0;
  pbenum.RegionCode? _currentRegion;
  pb.Config_PositionConfig? _currentPositionConfig;
  pb.Config_DeviceConfig? _currentDeviceConfig;
  pb.Config_DisplayConfig? _currentDisplayConfig;
  pb.Config_PowerConfig? _currentPowerConfig;
  pb.Config_NetworkConfig? _currentNetworkConfig;
  pb.Config_BluetoothConfig? _currentBluetoothConfig;
  pb.Config_SecurityConfig? _currentSecurityConfig;
  pb.Config_LoRaConfig? _currentLoraConfig;
  pb.ModuleConfig_MQTTConfig? _currentMqttConfig;
  pb.ModuleConfig_TelemetryConfig? _currentTelemetryConfig;
  pb.ModuleConfig_PaxcounterConfig? _currentPaxCounterConfig;
  pb.ModuleConfig_AmbientLightingConfig? _currentAmbientLightingConfig;
  pb.ModuleConfig_SerialConfig? _currentSerialConfig;
  pb.ModuleConfig_StoreForwardConfig? _currentStoreForwardConfig;
  pb.ModuleConfig_DetectionSensorConfig? _currentDetectionSensorConfig;
  pb.ModuleConfig_RangeTestConfig? _currentRangeTestConfig;
  pb.ModuleConfig_ExternalNotificationConfig?
  _currentExternalNotificationConfig;
  final Map<int, MeshNode> _nodes = {};
  final List<ChannelConfig> _channels = [];
  final Random _random = Random();
  bool _configurationComplete = false;

  // Track pending messages by packet ID for delivery status updates
  final Map<int, String> _pendingMessages = {}; // packetId -> messageId

  // BLE device name for hardware model inference
  String? _deviceName;

  ProtocolService(this._transport, {Logger? logger})
    : _logger = logger ?? Logger(),
      _framer = PacketFramer(logger: logger),
      _messageController = StreamController<Message>.broadcast(),
      _nodeController = StreamController<MeshNode>.broadcast(),
      _channelController = StreamController<ChannelConfig>.broadcast(),
      _errorController = StreamController<DeviceError>.broadcast(),
      _myNodeNumController = StreamController<int>.broadcast(),
      _rssiController = StreamController<int>.broadcast(),
      _snrController = StreamController<double>.broadcast(),
      _channelUtilController = StreamController<double>.broadcast(),
      _deliveryController = StreamController<MessageDeliveryUpdate>.broadcast(),
      _regionController = StreamController<pbenum.RegionCode>.broadcast(),
      _positionConfigController =
          StreamController<pb.Config_PositionConfig>.broadcast(),
      _deviceConfigController =
          StreamController<pb.Config_DeviceConfig>.broadcast(),
      _displayConfigController =
          StreamController<pb.Config_DisplayConfig>.broadcast(),
      _powerConfigController =
          StreamController<pb.Config_PowerConfig>.broadcast(),
      _networkConfigController =
          StreamController<pb.Config_NetworkConfig>.broadcast(),
      _bluetoothConfigController =
          StreamController<pb.Config_BluetoothConfig>.broadcast(),
      _securityConfigController =
          StreamController<pb.Config_SecurityConfig>.broadcast(),
      _loraConfigController =
          StreamController<pb.Config_LoRaConfig>.broadcast(),
      _mqttConfigController =
          StreamController<pb.ModuleConfig_MQTTConfig>.broadcast(),
      _telemetryConfigController =
          StreamController<pb.ModuleConfig_TelemetryConfig>.broadcast(),
      _paxCounterConfigController =
          StreamController<pb.ModuleConfig_PaxcounterConfig>.broadcast(),
      _ambientLightingConfigController =
          StreamController<pb.ModuleConfig_AmbientLightingConfig>.broadcast(),
      _serialConfigController =
          StreamController<pb.ModuleConfig_SerialConfig>.broadcast(),
      _storeForwardConfigController =
          StreamController<pb.ModuleConfig_StoreForwardConfig>.broadcast(),
      _detectionSensorConfigController =
          StreamController<pb.ModuleConfig_DetectionSensorConfig>.broadcast(),
      _rangeTestConfigController =
          StreamController<pb.ModuleConfig_RangeTestConfig>.broadcast(),
      _externalNotificationConfigController =
          StreamController<
            pb.ModuleConfig_ExternalNotificationConfig
          >.broadcast();

  /// Set the BLE device name for hardware model inference
  void setDeviceName(String? name) {
    _deviceName = name;
    _logger.i('Device name set to: $name');
  }

  /// Set the BLE model number (from Device Information Service 0x180A)
  void setBleModelNumber(String? modelNumber) {
    _bleModelNumber = modelNumber;
    if (modelNumber != null) {
      _logger.i('BLE model number set to: $modelNumber');
    }
  }

  /// Set the BLE manufacturer name (from Device Information Service 0x180A)
  void setBleManufacturerName(String? manufacturerName) {
    _bleManufacturerName = manufacturerName;
    if (manufacturerName != null) {
      _logger.i('BLE manufacturer name set to: $manufacturerName');
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

  /// Stream of region updates
  Stream<pbenum.RegionCode> get regionStream => _regionController.stream;

  /// Current region
  pbenum.RegionCode? get currentRegion => _currentRegion;

  /// Stream of position config updates
  Stream<pb.Config_PositionConfig> get positionConfigStream =>
      _positionConfigController.stream;

  /// Current position config
  pb.Config_PositionConfig? get currentPositionConfig => _currentPositionConfig;

  /// Stream of device config updates
  Stream<pb.Config_DeviceConfig> get deviceConfigStream =>
      _deviceConfigController.stream;

  /// Current device config
  pb.Config_DeviceConfig? get currentDeviceConfig => _currentDeviceConfig;

  /// Stream of display config updates
  Stream<pb.Config_DisplayConfig> get displayConfigStream =>
      _displayConfigController.stream;

  /// Current display config
  pb.Config_DisplayConfig? get currentDisplayConfig => _currentDisplayConfig;

  /// Stream of power config updates
  Stream<pb.Config_PowerConfig> get powerConfigStream =>
      _powerConfigController.stream;

  /// Current power config
  pb.Config_PowerConfig? get currentPowerConfig => _currentPowerConfig;

  /// Stream of network config updates
  Stream<pb.Config_NetworkConfig> get networkConfigStream =>
      _networkConfigController.stream;

  /// Current network config
  pb.Config_NetworkConfig? get currentNetworkConfig => _currentNetworkConfig;

  /// Stream of bluetooth config updates
  Stream<pb.Config_BluetoothConfig> get bluetoothConfigStream =>
      _bluetoothConfigController.stream;

  /// Current bluetooth config
  pb.Config_BluetoothConfig? get currentBluetoothConfig =>
      _currentBluetoothConfig;

  /// Stream of security config updates
  Stream<pb.Config_SecurityConfig> get securityConfigStream =>
      _securityConfigController.stream;

  /// Current security config
  pb.Config_SecurityConfig? get currentSecurityConfig => _currentSecurityConfig;

  /// Stream of LoRa config updates
  Stream<pb.Config_LoRaConfig> get loraConfigStream =>
      _loraConfigController.stream;

  /// Current LoRa config
  pb.Config_LoRaConfig? get currentLoraConfig => _currentLoraConfig;

  /// Stream of MQTT config updates
  Stream<pb.ModuleConfig_MQTTConfig> get mqttConfigStream =>
      _mqttConfigController.stream;

  /// Current MQTT config
  pb.ModuleConfig_MQTTConfig? get currentMqttConfig => _currentMqttConfig;

  /// Stream of telemetry config updates
  Stream<pb.ModuleConfig_TelemetryConfig> get telemetryConfigStream =>
      _telemetryConfigController.stream;

  /// Current telemetry config
  pb.ModuleConfig_TelemetryConfig? get currentTelemetryConfig =>
      _currentTelemetryConfig;

  /// Stream of PAX counter config updates
  Stream<pb.ModuleConfig_PaxcounterConfig> get paxCounterConfigStream =>
      _paxCounterConfigController.stream;

  /// Current PAX counter config
  pb.ModuleConfig_PaxcounterConfig? get currentPaxCounterConfig =>
      _currentPaxCounterConfig;

  /// Stream of ambient lighting config updates
  Stream<pb.ModuleConfig_AmbientLightingConfig>
  get ambientLightingConfigStream => _ambientLightingConfigController.stream;

  /// Current ambient lighting config
  pb.ModuleConfig_AmbientLightingConfig? get currentAmbientLightingConfig =>
      _currentAmbientLightingConfig;

  /// Stream of serial config updates
  Stream<pb.ModuleConfig_SerialConfig> get serialConfigStream =>
      _serialConfigController.stream;

  /// Current serial config
  pb.ModuleConfig_SerialConfig? get currentSerialConfig => _currentSerialConfig;

  /// Stream of store forward config updates
  Stream<pb.ModuleConfig_StoreForwardConfig> get storeForwardConfigStream =>
      _storeForwardConfigController.stream;

  /// Current store forward config
  pb.ModuleConfig_StoreForwardConfig? get currentStoreForwardConfig =>
      _currentStoreForwardConfig;

  /// Stream of detection sensor config updates
  Stream<pb.ModuleConfig_DetectionSensorConfig>
  get detectionSensorConfigStream => _detectionSensorConfigController.stream;

  /// Current detection sensor config
  pb.ModuleConfig_DetectionSensorConfig? get currentDetectionSensorConfig =>
      _currentDetectionSensorConfig;

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
    _logger.i('Starting protocol service');

    _configCompleter = Completer<void>();
    var waitingForConfig = false; // Track if we're past initial setup

    _dataSubscription = _transport.dataStream.listen(
      _handleData,
      onError: (error) {
        _logger.e('Transport error: $error');
      },
    );

    // Listen for transport disconnection to fail fast
    _transportStateSubscription = _transport.stateStream.listen((state) {
      if (state == DeviceConnectionState.disconnected ||
          state == DeviceConnectionState.error) {
        _logger.w('Transport disconnected/error during config wait');
        // Only complete with error if we're actually waiting for config
        // This prevents double-errors when enableNotifications throws directly
        if (waitingForConfig &&
            _configCompleter != null &&
            !_configCompleter!.isCompleted) {
          _configCompleter!.completeError(
            Exception(
              'Connection failed - please try again and enter the PIN when prompted',
            ),
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
            'Configuration timed out - device may require pairing or PIN was cancelled',
          );
        },
      );
      AppLogging.debug('✅ Protocol: Configuration was received');
    } catch (e) {
      AppLogging.debug('❌ Protocol: Configuration failed: $e');
      // Convert FlutterBluePlus auth errors to user-friendly message
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('authentication') ||
          errorStr.contains('encryption') ||
          errorStr.contains('insufficient')) {
        throw Exception(
          'Connection failed - please try again and enter the PIN when prompted',
        );
      }
      rethrow;
    }

    // Start RSSI polling timer (every 2 seconds)
    _startRssiPolling();

    _logger.i('Protocol service started');
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
    int pollCount = 0;
    const maxPolls = 100;

    Future.doWhile(() async {
      if (_configurationComplete || pollCount >= maxPolls) {
        return false; // Stop polling
      }

      try {
        await _transport.pollOnce();
        pollCount++;
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        _logger.w('Poll error: $e');
      }
      return true; // Continue polling
    });
  }

  /// Stop listening
  void stop() {
    _logger.i('Stopping protocol service');
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _transportStateSubscription?.cancel();
    _transportStateSubscription = null;
    if (_configCompleter != null && !_configCompleter!.isCompleted) {
      _configCompleter!.completeError('Service stopped');
    }
    _configCompleter = null;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _framer.clear();
    _configurationComplete = false;
  }

  /// Handle incoming data from transport
  void _handleData(List<int> data) {
    _logger.d('Received ${data.length} bytes');

    if (_transport.requiresFraming) {
      // Serial/USB: Extract packets using framer
      final packets = _framer.addData(data);

      for (final packet in packets) {
        _processPacket(packet);
      }
    } else {
      // BLE: Data is already a complete raw protobuf
      if (data.isNotEmpty) {
        _processPacket(data);
      }
    }
  }

  /// Process a complete packet
  void _processPacket(List<int> packet) {
    try {
      _logger.d('Processing packet: ${packet.length} bytes');

      final fromRadio = pn.FromRadio.fromBuffer(packet);

      // Debug: log which payload variant we got
      final variant = fromRadio.whichPayloadVariant();
      AppLogging.protocol('FromRadio payload variant: $variant');

      if (fromRadio.hasPacket()) {
        _handleMeshPacket(fromRadio.packet);
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
      } else if (fromRadio.hasConfigCompleteId()) {
        AppLogging.protocol(
          'Configuration complete! ID: ${fromRadio.configCompleteId}',
        );
        _logger.i('Configuration complete: ${fromRadio.configCompleteId}');
        _configurationComplete = true;
        if (_configCompleter != null && !_configCompleter!.isCompleted) {
          _configCompleter!.complete();
        }

        // Log summary of all nodes and their position status
        _logger.i('=== NODE SUMMARY AFTER CONFIG COMPLETE ===');
        _logger.i('Total nodes: ${_nodes.length}');
        for (final node in _nodes.values) {
          _logger.i(
            '  Node ${node.nodeNum}: "${node.longName}" hasPosition=${node.hasPosition}, '
            'lat=${node.latitude}, lng=${node.longitude}',
          );
        }
        _logger.i('==========================================');

        // Request LoRa config to get current region, and Position config
        Future.delayed(const Duration(milliseconds: 100), () {
          getLoRaConfig();
          // Also request Position config to see GPS settings
          Future.delayed(const Duration(milliseconds: 200), () {
            getPositionConfig();
          });
          // Request device metadata to get firmware version
          Future.delayed(const Duration(milliseconds: 300), () {
            getDeviceMetadata();
          });
          // Request positions from all nodes including ourselves
          Future.delayed(const Duration(milliseconds: 500), () {
            requestAllPositions();
          });
        });
      }
    } catch (e, stack) {
      _logger.e('Error processing packet: $e', error: e, stackTrace: stack);
    }
  }

  /// Handle incoming mesh packet
  void _handleMeshPacket(pb.MeshPacket packet) {
    _logger.d('Handling mesh packet from ${packet.from} to ${packet.to}');

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

      switch (data.portnum) {
        case pb.PortNum.TEXT_MESSAGE_APP:
          _handleTextMessage(packet, data);
          break;
        case pb.PortNum.POSITION_APP:
          _handlePositionUpdate(packet, data);
          break;
        case pb.PortNum.NODEINFO_APP:
          _handleNodeInfoUpdate(packet, data);
          break;
        case pb.PortNum.ROUTING_APP:
          _handleRoutingMessage(packet, data);
          break;
        case pb.PortNum.TELEMETRY_APP:
          _handleTelemetry(packet, data);
          break;
        case pb.PortNum.ADMIN_APP:
          _handleAdminMessage(packet, data);
          break;
        default:
          _logger.d(
            'Received message with portnum: ${data.portnum} (${data.portnum.value})',
          );
      }
    }
  }

  /// Handle admin message responses
  void _handleAdminMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      final adminMsg = pb.AdminMessage.fromBuffer(data.payload);
      _logger.d('Admin message variant: ${adminMsg.whichPayloadVariant()}');

      if (adminMsg.hasGetConfigResponse()) {
        final config = adminMsg.getConfigResponse;

        // Handle LoRa config
        if (config.hasLora()) {
          final loraConfig = config.lora;
          _logger.i('Received LoRa config - region: ${loraConfig.region.name}');
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
          _logger.i('Received Device config - role: ${deviceConfig.role.name}');
          _currentDeviceConfig = deviceConfig;
          _deviceConfigController.add(deviceConfig);
        }

        // Handle Display config
        if (config.hasDisplay()) {
          final displayConfig = config.display;
          _logger.i(
            'Received Display config - screenOnSecs: ${displayConfig.screenOnSecs}',
          );
          _currentDisplayConfig = displayConfig;
          _displayConfigController.add(displayConfig);
        }

        // Handle Power config
        if (config.hasPower()) {
          final powerConfig = config.power;
          _logger.i(
            'Received Power config - isPowerSaving: ${powerConfig.isPowerSaving}',
          );
          _currentPowerConfig = powerConfig;
          _powerConfigController.add(powerConfig);
        }

        // Handle Network config
        if (config.hasNetwork()) {
          final networkConfig = config.network;
          _logger.i(
            'Received Network config - wifiEnabled: ${networkConfig.wifiEnabled}',
          );
          _currentNetworkConfig = networkConfig;
          _networkConfigController.add(networkConfig);
        }

        // Handle Bluetooth config
        if (config.hasBluetooth()) {
          final btConfig = config.bluetooth;
          _logger.i('Received Bluetooth config - enabled: ${btConfig.enabled}');
          _currentBluetoothConfig = btConfig;
          _bluetoothConfigController.add(btConfig);
        }

        // Handle Security config
        if (config.hasSecurity()) {
          final secConfig = config.security;
          _logger.i(
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
          _logger.i('Received MQTT config - enabled: ${mqttConfig.enabled}');
          _currentMqttConfig = mqttConfig;
          _mqttConfigController.add(mqttConfig);
        }

        // Handle Telemetry config
        if (moduleConfig.hasTelemetry()) {
          final telemetryConfig = moduleConfig.telemetry;
          _logger.i(
            'Received Telemetry config - deviceInterval: ${telemetryConfig.deviceUpdateInterval}',
          );
          _currentTelemetryConfig = telemetryConfig;
          _telemetryConfigController.add(telemetryConfig);
        }

        // Handle PAX counter config
        if (moduleConfig.hasPaxcounter()) {
          final paxConfig = moduleConfig.paxcounter;
          _logger.i(
            'Received PAX counter config - enabled: ${paxConfig.enabled}',
          );
          _currentPaxCounterConfig = paxConfig;
          _paxCounterConfigController.add(paxConfig);
        }

        // Handle Ambient Lighting config
        if (moduleConfig.hasAmbientLighting()) {
          final ambientConfig = moduleConfig.ambientLighting;
          _logger.i(
            'Received Ambient Lighting config - ledState: ${ambientConfig.ledState}',
          );
          _currentAmbientLightingConfig = ambientConfig;
          _ambientLightingConfigController.add(ambientConfig);
        }

        // Handle Serial config
        if (moduleConfig.hasSerial()) {
          final serialConfig = moduleConfig.serial;
          _logger.i(
            'Received Serial config - enabled: ${serialConfig.enabled}',
          );
          _currentSerialConfig = serialConfig;
          _serialConfigController.add(serialConfig);
        }

        // Handle Store Forward config
        if (moduleConfig.hasStoreForward()) {
          final sfConfig = moduleConfig.storeForward;
          _logger.i(
            'Received Store Forward config - enabled: ${sfConfig.enabled}',
          );
          _currentStoreForwardConfig = sfConfig;
          _storeForwardConfigController.add(sfConfig);
        }

        // Handle Detection Sensor config
        if (moduleConfig.hasDetectionSensor()) {
          final dsConfig = moduleConfig.detectionSensor;
          _logger.i(
            'Received Detection Sensor config - enabled: ${dsConfig.enabled}',
          );
          _currentDetectionSensorConfig = dsConfig;
          _detectionSensorConfigController.add(dsConfig);
        }

        // Handle Range Test config
        if (moduleConfig.hasRangeTest()) {
          final rtConfig = moduleConfig.rangeTest;
          _logger.i(
            'Received Range Test config - enabled: ${rtConfig.enabled}',
          );
          _currentRangeTestConfig = rtConfig;
          _rangeTestConfigController.add(rtConfig);
        }

        // Handle External Notification config
        if (moduleConfig.hasExternalNotification()) {
          final extNotifConfig = moduleConfig.externalNotification;
          _logger.i(
            'Received External Notification config - enabled: ${extNotifConfig.enabled}',
          );
          _currentExternalNotificationConfig = extNotifConfig;
          _externalNotificationConfigController.add(extNotifConfig);
        }
      } else if (adminMsg.hasGetChannelResponse()) {
        // Handle channel response - update local channel list
        final channel = adminMsg.getChannelResponse;
        _logger.i(
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
        _logger.i(
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
            _logger.i('Hardware model from metadata: $hwModelName');
          } else {
            // Try to infer from BLE model number or device name
            _logger.i(
              'Hardware model UNSET in metadata, attempting to infer (bleModel="$_bleModelNumber", deviceName="$_deviceName")',
            );
            hwModelName = _inferHardwareModel();
            if (hwModelName == null) {
              _logger.w(
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
          _logger.i('Updated node $_myNodeNum with device metadata');
        }
      }
    } catch (e) {
      _logger.e('Error handling admin message: $e');
    }
  }

  /// Handle Config from FromRadio (sent during initial config boot sequence)
  /// This includes LoRa config with the region!
  void _handleFromRadioConfig(pb.Config config) {
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

  /// Handle DeviceMetadata from FromRadio (sent during initial config)
  void _handleFromRadioMetadata(pb.DeviceMetadata metadata) {
    AppLogging.debug(
      '📋 FromRadio metadata: firmware="${metadata.firmwareVersion}", '
      'hwModel=${metadata.hwModel.name}',
    );
    _logger.i(
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
        _logger.i('Hardware model from FromRadio metadata: $hwModelName');
      } else {
        // Try to infer from BLE model number or device name
        _logger.i(
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
      final text = utf8.decode(data.payload);
      _logger.i('Text message from ${packet.from}: $text');

      final message = Message(
        from: packet.from,
        to: packet.to,
        text: text,
        channel: packet.channel,
        received: true,
      );

      _messageController.add(message);
    } catch (e) {
      _logger.e('Error decoding text message: $e');
    }
  }

  /// Handle routing message (ACK/NAK/errors)
  void _handleRoutingMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      // If requestId is set, it references the original packet that this is a response to
      final requestId = data.requestId;

      _logger.d(
        'Routing message received: requestId=$requestId, from=${packet.from}, '
        'to=${packet.to}, packetId=${packet.id}',
      );

      if (requestId == 0) {
        _logger.d('Routing message with no requestId, ignoring');
        return;
      }

      // Parse the Routing protobuf message
      final routing = pb.Routing.fromBuffer(data.payload);
      final variant = routing.whichVariant();

      _logger.d('Routing variant: $variant');

      RoutingError routingError;
      bool delivered;

      switch (variant) {
        case pb.Routing_Variant.errorReason:
          // Error response - check the error code
          final errorCode = routing.errorReason.value;
          routingError = RoutingError.fromCode(errorCode);
          delivered = routingError.isSuccess;
          _logger.i(
            'Routing error for packet $requestId: ${routingError.message} (code=$errorCode, name=${routing.errorReason.name})',
          );
          break;

        case pb.Routing_Variant.routeRequest:
          _logger.d('Route request received for packet $requestId');
          // Route requests don't indicate delivery status
          return;

        case pb.Routing_Variant.routeReply:
          _logger.d('Route reply received for packet $requestId');
          // Route replies don't indicate delivery status
          return;

        case pb.Routing_Variant.notSet:
          // Empty routing message typically means success (ACK)
          routingError = RoutingError.fromCode(0);
          delivered = true;
          _logger.d('Empty routing message (ACK) for packet $requestId');
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
      _logger.e('Error handling routing message: $e');
    }
  }

  /// Handle telemetry message (battery, voltage, etc.)
  void _handleTelemetry(pb.MeshPacket packet, pb.Data data) {
    try {
      // TELEMETRY_APP payload is a Telemetry message wrapper with oneof variant
      final telem = telemetry.Telemetry.fromBuffer(data.payload);

      // Check which variant we received
      final variant = telem.whichVariant();
      _logger.d('Telemetry variant: $variant from ${packet.from}');

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
            _logger.i(
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
              isOnline: true,
            );
            _nodes[packet.from] = updatedDeviceNode;
            _nodeController.add(updatedDeviceNode);
          }
          break;

        case telemetry.Telemetry_Variant.environmentMetrics:
          final envMetrics = telem.environmentMetrics;
          if (ProtocolDebugFlags.logTelemetry) {
            _logger.i(
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
              isOnline: true,
            );
            _nodes[packet.from] = updatedEnvNode;
            _nodeController.add(updatedEnvNode);
          }
          return;

        case telemetry.Telemetry_Variant.airQualityMetrics:
          final aqMetrics = telem.airQualityMetrics;
          if (ProtocolDebugFlags.logTelemetry) {
            _logger.i(
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
              isOnline: true,
            );
            _nodes[packet.from] = updatedAqNode;
            _nodeController.add(updatedAqNode);
          }
          return;

        case telemetry.Telemetry_Variant.powerMetrics:
          final pwrMetrics = telem.powerMetrics;
          if (ProtocolDebugFlags.logTelemetry) {
            _logger.i(
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
              isOnline: true,
            );
            _nodes[packet.from] = updatedPwrNode;
            _nodeController.add(updatedPwrNode);
          }
          return;

        case telemetry.Telemetry_Variant.localStats:
          final stats = telem.localStats;
          if (ProtocolDebugFlags.logTelemetry) {
            _logger.i(
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
              lastHeard: DateTime.now(),
              isOnline: true,
            );
            _nodes[packet.from] = updatedStatsNode;
            _nodeController.add(updatedStatsNode);
          }
          return;

        case telemetry.Telemetry_Variant.healthMetrics:
          if (ProtocolDebugFlags.logTelemetry) {
            _logger.i('HealthMetrics from ${packet.from}');
          }
          return;

        case telemetry.Telemetry_Variant.notSet:
          if (ProtocolDebugFlags.logTelemetry) {
            _logger.d('Telemetry with no variant set from ${packet.from}');
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
        _logger.d('Creating new node entry for ${packet.from} from telemetry');
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
          isOnline: true,
          avatarColor: avatarColor,
          isFavorite: false,
        );
        _nodes[packet.from] = newNode;
        _nodeController.add(newNode);
      }
    } catch (e) {
      _logger.e('Error decoding telemetry: $e');
      // Log the raw payload for debugging
      _logger.d('Raw telemetry payload: ${data.payload}');
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
        _logger.i(
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
        _logger.i(
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
        _logger.i(
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
          isOnline: true,
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
      _logger.e('Error decoding position: $e');
    }
  }

  /// Handle node info update
  void _handleNodeInfoUpdate(pb.MeshPacket packet, pb.Data data) {
    try {
      final user = pb.User.fromBuffer(data.payload);
      _logger.i('Node info from ${packet.from}: ${user.longName}');

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
          _logger.i('Hardware model UNSET in User packet, inferred: $hwModel');
        }
      }

      // Extract role from user
      final role = user.hasRole() ? user.role.name : 'CLIENT';

      final existingNode = _nodes[packet.from];
      final updatedNode =
          existingNode?.copyWith(
            longName: user.longName,
            shortName: user.shortName,
            userId: user.hasId() ? user.id : existingNode.userId,
            hardwareModel: hwModel ?? existingNode.hardwareModel,
            role: role,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : existingNode.snr,
            lastHeard: DateTime.now(),
            isOnline: true,
          ) ??
          MeshNode(
            nodeNum: packet.from,
            longName: user.longName,
            shortName: user.shortName,
            userId: user.hasId() ? user.id : null,
            hardwareModel: hwModel,
            role: role,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
            lastHeard: DateTime.now(),
            isOnline: true,
            avatarColor: avatarColor,
            isFavorite: false,
          );

      _nodes[packet.from] = updatedNode;
      _nodeController.add(updatedNode);
    } catch (e) {
      _logger.e('Error decoding node info: $e');
    }
  }

  /// Update lastHeard timestamp for a node (marks it as online)
  /// This is called for any packet received from a node
  void _updateNodeLastHeard(int nodeNum) {
    final node = _nodes[nodeNum];
    if (node != null) {
      final updatedNode = node.copyWith(
        lastHeard: DateTime.now(),
        isOnline: true,
      );
      _nodes[nodeNum] = updatedNode;
      _nodeController.add(updatedNode);
    }
  }

  /// Handle my node info
  void _handleMyNodeInfo(pb.MyNodeInfo myInfo) {
    _myNodeNum = myInfo.myNodeNum;
    AppLogging.protocol('Protocol: My node number set to: $_myNodeNum');
    _logger.i('My node number: $_myNodeNum');
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
      _logger.i('Node info received: ${nodeInfo.num}');
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
      _logger.i(
        'NodeInfo deviceMetrics: battery=${metrics.batteryLevel}%, '
        'voltage=${metrics.voltage}V, uptime=${metrics.uptimeSeconds}s',
      );
    } else {
      _logger.d('NodeInfo has no deviceMetrics');
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
      _logger.d(
        'NodeInfo user: longName=${user.longName}, hwModel=${user.hwModel}, hasHwModel=${user.hasHwModel()}',
      );
      if (user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET) {
        hwModel = _formatHardwareModel(user.hwModel);
        _logger.d('Formatted hardware model: $hwModel');
      }
      if (user.hasRole()) {
        role = user.role.name;
      }
      if (user.hasId()) {
        userId = user.id;
      }
      // Check if user has a public key set (for PKI encryption)
      hasPublicKey = user.hasPublicKey() && user.publicKey.isNotEmpty;
    } else {
      _logger.d('NodeInfo has no user data');
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
      _logger.i(
        '📍 NodeInfo ${nodeInfo.num} position check: latI=${nodeInfo.position.latitudeI}, '
        'lngI=${nodeInfo.position.longitudeI}, lat=${nodeInfo.position.latitudeI / 1e7}, '
        'lng=${nodeInfo.position.longitudeI / 1e7}, valid=$hasValidPosition',
      );
    }

    if (existingNode != null) {
      updatedNode = existingNode.copyWith(
        longName: nodeInfo.hasUser()
            ? nodeInfo.user.longName
            : existingNode.longName,
        shortName: nodeInfo.hasUser()
            ? nodeInfo.user.shortName
            : existingNode.shortName,
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
        isOnline: true,
        role: role,
        avatarColor: existingNode.avatarColor,
        hasPublicKey: hasPublicKey,
      );
    } else {
      updatedNode = MeshNode(
        nodeNum: nodeInfo.num,
        longName: nodeInfo.hasUser() ? nodeInfo.user.longName : '',
        shortName: nodeInfo.hasUser() ? nodeInfo.user.shortName : '',
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
        isOnline: true,
        role: role,
        avatarColor: avatarColor,
        isFavorite: false,
        hasPublicKey: hasPublicKey,
      );
    }

    _nodes[nodeInfo.num] = updatedNode;
    _nodeController.add(updatedNode);
  }

  /// Handle channel configuration
  void _handleChannel(pb.Channel channel) {
    AppLogging.debug(
      '📡 Channel ${channel.index} received from device: '
      'role=${channel.role.name}, name="${channel.hasSettings() ? channel.settings.name : ""}", '
      'psk=${channel.hasSettings() ? channel.settings.psk.length : 0} bytes',
    );

    // Map protobuf role to string
    String roleStr;
    switch (channel.role) {
      case pb.Channel_Role.PRIMARY:
        roleStr = 'PRIMARY';
        break;
      case pb.Channel_Role.SECONDARY:
        roleStr = 'SECONDARY';
        break;
      case pb.Channel_Role.DISABLED:
      default:
        roleStr = 'DISABLED';
        break;
    }

    // Extract position precision from moduleSettings if present
    int positionPrecision = 0;
    if (channel.hasSettings() &&
        channel.settings.hasModuleSettings() &&
        channel.settings.moduleSettings.hasPositionPrecision()) {
      positionPrecision = channel.settings.moduleSettings.positionPrecision;
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
    if (channel.index == 0 || channel.role != pb.Channel_Role.DISABLED) {
      _channelController.add(channelConfig);
    }
  }

  /// Request configuration from device
  Future<void> _requestConfiguration() async {
    try {
      if (!_transport.isConnected) {
        _logger.w('Cannot request configuration: not connected');
        return;
      }

      _logger.i('Requesting device configuration');

      // Wake device by sending START2 bytes (only for serial/USB)
      if (_transport.requiresFraming) {
        final wakeBytes = List<int>.filled(32, 0xC3); // 32 START2 bytes
        await _transport.send(Uint8List.fromList(wakeBytes));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Generate a config ID to track this request
      // The firmware will send back all config + NodeDB with positions
      final configId = _random.nextInt(0x7FFFFFFF);

      _logger.i('Requesting config with ID: $configId');
      final toRadio = pn.ToRadio()..wantConfigId = configId;
      final bytes = toRadio.writeToBuffer();

      // BLE uses raw protobufs, Serial/USB requires framing
      final sendBytes = _transport.requiresFraming
          ? PacketFramer.frame(bytes)
          : bytes;

      await _transport.send(sendBytes);
      _logger.i('Configuration request sent');
    } catch (e) {
      _logger.e('Error requesting configuration: $e');
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
      _logger.i('Sending message to $to: $text');

      final packetId = _generatePacketId();

      final data = pb.Data()
        ..portnum = pb.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text)
        ..wantResponse = wantAck;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = to
        ..channel = channel
        ..decoded = data
        ..id = packetId
        ..wantAck = wantAck;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Track the message for delivery status
      if (messageId != null && wantAck) {
        _pendingMessages[packetId] = messageId;
      }

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
      );

      _messageController.add(message);

      return packetId;
    } catch (e) {
      _logger.e('Error sending message: $e');
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
      _logger.i('Sending message to $to: $text');

      final packetId = _generatePacketId();

      // Call the pre-tracking callback BEFORE sending
      // This ensures tracking is set up before any ACK can arrive
      if (wantAck) {
        onPacketIdGenerated(packetId);
      }

      final data = pb.Data()
        ..portnum = pb.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text)
        ..wantResponse = wantAck;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = to
        ..channel = channel
        ..decoded = data
        ..id = packetId
        ..wantAck = wantAck;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Track the message for delivery status (internal tracking)
      if (messageId != null && wantAck) {
        _pendingMessages[packetId] = messageId;
      }

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
      );

      _messageController.add(message);

      return packetId;
    } catch (e) {
      _logger.e('Error sending message: $e');
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
      _logger.i('Sending position: $latitude, $longitude');

      final position = pb.Position()
        ..latitudeI = (latitude * 1e7).toInt()
        ..longitudeI = (longitude * 1e7).toInt()
        ..time = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (altitude != null) {
        position.altitude = altitude;
      }

      final data = pb.Data()
        ..portnum = pb.PortNum.POSITION_APP
        ..payload = position.writeToBuffer();

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to =
            0xFFFFFFFF // Broadcast
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
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
      _logger.e('Error sending position: $e');
      rethrow;
    }
  }

  /// Request node info
  Future<void> requestNodeInfo(int nodeNum) async {
    try {
      _logger.i('Requesting node info for $nodeNum');

      final data = pb.Data()
        ..portnum = pb.PortNum.NODEINFO_APP
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = nodeNum
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = true;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error requesting node info: $e');
    }
  }

  /// Request position from a specific node
  Future<void> requestPosition(int nodeNum) async {
    try {
      _logger.i('Requesting position for node $nodeNum');

      // Create an empty position to request the node's position
      final position = pb.Position();

      final data = pb.Data()
        ..portnum = pb.PortNum.POSITION_APP
        ..payload = position.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = nodeNum
        ..decoded = data
        ..id = _generatePacketId()
        ..wantAck = true;

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error requesting position: $e');
    }
  }

  /// Request positions from all known nodes
  Future<void> requestAllPositions() async {
    _logger.i('Requesting positions from all ${_nodes.length} known nodes');
    for (final nodeNum in _nodes.keys) {
      await requestPosition(nodeNum);
      // Small delay between requests to avoid flooding
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Send a traceroute request to a specific node
  /// Returns immediately - results come via mesh packet responses
  Future<void> sendTraceroute(int nodeNum) async {
    _logger.i('Sending traceroute to node $nodeNum');

    // Create an empty RouteDiscovery for the request
    final routeDiscovery = pb.RouteDiscovery();

    final data = pb.Data()
      ..portnum = pb.PortNum.TRACEROUTE_APP
      ..payload = routeDiscovery.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum ?? 0
      ..to = nodeNum
      ..decoded = data
      ..id = _generatePacketId()
      ..wantAck = true;

    final toRadio = pn.ToRadio()..packet = packet;
    final bytes = toRadio.writeToBuffer();

    await _transport.send(_prepareForSend(bytes));
  }

  /// Begin edit settings transaction
  Future<void> _beginEditSettings() async {
    _logger.d('Beginning edit settings transaction');

    final adminMsg = pb.AdminMessage()..beginEditSettings = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    final bytes = toRadio.writeToBuffer();

    await _transport.send(_prepareForSend(bytes));
    // Small delay to let device process
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Commit edit settings transaction
  Future<void> _commitEditSettings() async {
    _logger.d('Committing edit settings transaction');

    final adminMsg = pb.AdminMessage()..commitEditSettings = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    final bytes = toRadio.writeToBuffer();

    await _transport.send(_prepareForSend(bytes));
  }

  /// Set channel with proper transaction handling
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

      // Begin edit transaction
      await _beginEditSettings();

      final channelSettings = pb.ChannelSettings()
        ..name = config.name
        ..psk = config.psk
        ..uplinkEnabled = config.uplink
        ..downlinkEnabled = config.downlink;

      // Set position precision via moduleSettings
      if (config.positionPrecision > 0) {
        channelSettings.moduleSettings = pb.ModuleSettings()
          ..positionPrecision = config.positionPrecision;
      }

      // Determine channel role from config
      pb.Channel_Role role;
      switch (config.role.toUpperCase()) {
        case 'PRIMARY':
          role = pb.Channel_Role.PRIMARY;
          break;
        case 'SECONDARY':
          role = pb.Channel_Role.SECONDARY;
          break;
        case 'DISABLED':
        default:
          role = pb.Channel_Role.DISABLED;
          break;
      }

      final channel = pb.Channel()
        ..index = config.index
        ..settings = channelSettings
        ..role = role;

      AppLogging.debug(
        '📡 Channel protobuf: index=${channel.index}, role=${channel.role.name}, '
        'name="${channel.settings.name}", psk=${channel.settings.psk.length} bytes',
      );

      final adminMsg = pb.AdminMessage()..setChannel = channel;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      AppLogging.channels('Channel ${config.index} sent to device');

      // Small delay before commit
      await Future.delayed(const Duration(milliseconds: 200));

      // Commit the transaction - this triggers the save to flash
      await _commitEditSettings();
      AppLogging.channels('Channel settings committed to flash');

      // Wait a bit then request the channel back to verify
      await Future.delayed(const Duration(milliseconds: 500));
      AppLogging.channels('Verifying channel ${config.index}...');
      await getChannel(config.index);
    } catch (e) {
      _logger.e('Error setting channel: $e');
      rethrow;
    }
  }

  /// Get channel
  Future<void> getChannel(int index) async {
    try {
      _logger.i('Getting channel $index');

      final adminMsg = pb.AdminMessage()..getChannelRequest = index + 1;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = _myNodeNum ?? 0
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error getting channel: $e');
    }
  }

  /// Set device role
  Future<void> setDeviceRole(pb.Config_DeviceConfig_Role role) async {
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
      _logger.i('Setting device role: ${role.name}');

      // Get current owner info and update role
      final user = pb.User()..role = role;

      final adminMsg = pb.AdminMessage()..setOwner = user;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      // Immediately update local node cache so UI reflects the change
      final existingNode = _nodes[_myNodeNum!];
      if (existingNode != null) {
        final updatedNode = existingNode.copyWith(role: role.name);
        _nodes[_myNodeNum!] = updatedNode;
        _nodeController.add(updatedNode);
        _logger.i('Updated local node cache with new role');
      }
    } catch (e) {
      _logger.e('Error setting device role: $e');
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

      _logger.i(
        'Setting user name: long="$trimmedLong", short="$trimmedShort"',
      );

      final user = pb.User()
        ..longName = trimmedLong
        ..shortName = trimmedShort;

      final adminMsg = pb.AdminMessage()..setOwner = user;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
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
        _logger.i('Updated local node cache with new name');
      }
    } catch (e) {
      _logger.e('Error setting user name: $e');
      rethrow;
    }
  }

  /// Set the region/frequency for the device
  Future<void> setRegion(pbenum.RegionCode region) async {
    // Validate we're ready to send
    if (_myNodeNum == null) {
      throw StateError('Cannot set region: device not ready (no node number)');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set region: not connected to device');
    }

    try {
      _logger.i('Setting region: ${region.name}');

      final loraConfig = pb.Config_LoRaConfig()..region = region;

      final config = pb.Config()..lora = loraConfig;

      final adminMsg = pb.AdminMessage()..setConfig = config;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum!
        ..to = _myNodeNum!
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error setting region: $e');
      rethrow;
    }
  }

  /// Request the current LoRa configuration (for region)
  Future<void> getLoRaConfig() async {
    try {
      _logger.i('Requesting LoRa config');

      // Use ConfigType enum for LoRa config
      final adminMsg = pb.AdminMessage()
        ..getConfigRequest = pb.AdminMessage_ConfigType.LORA_CONFIG;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = _myNodeNum ?? 0
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error getting LoRa config: $e');
    }
  }

  /// Request the current Position configuration (GPS settings)
  Future<void> getPositionConfig() async {
    try {
      _logger.i('Requesting Position config');

      final adminMsg = pb.AdminMessage()
        ..getConfigRequest = pb.AdminMessage_ConfigType.POSITION_CONFIG;

      final data = pb.Data()
        ..portnum = pb.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = pb.MeshPacket()
        ..from = _myNodeNum ?? 0
        ..to = _myNodeNum ?? 0
        ..decoded = data
        ..id = _generatePacketId();

      final toRadio = pn.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      _logger.e('Error getting Position config: $e');
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

    _logger.i('Rebooting device in $delaySeconds seconds');

    final adminMsg = pb.AdminMessage()..rebootSeconds = delaySeconds;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Shutting down device in $delaySeconds seconds');

    final adminMsg = pb.AdminMessage()..shutdownSeconds = delaySeconds;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Factory reset the device configuration (keeps node DB)
  Future<void> factoryResetConfig() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot factory reset config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot factory reset config: not connected');
    }

    _logger.i('Factory resetting configuration');

    final adminMsg = pb.AdminMessage()..factoryResetConfig = 1;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Factory reset the entire device (config + node DB)
  Future<void> factoryResetDevice() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot factory reset device: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot factory reset device: not connected');
    }

    _logger.i('Factory resetting entire device');

    final adminMsg = pb.AdminMessage()..factoryResetDevice = 1;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Reset the node database (removes all learned nodes)
  Future<void> nodeDbReset() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot reset node DB: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot reset node DB: not connected');
    }

    _logger.i('Resetting node database');

    final adminMsg = pb.AdminMessage()..nodedbReset = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Enter DFU (Device Firmware Update) mode
  Future<void> enterDfuMode() async {
    if (_myNodeNum == null) {
      throw StateError('Cannot enter DFU mode: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot enter DFU mode: not connected');
    }

    _logger.i('Entering DFU mode');

    final adminMsg = pb.AdminMessage()..enterDfuModeRequest = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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
    _logger.i('Requesting device metadata');

    final adminMsg = pb.AdminMessage()..getDeviceMetadataRequest = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Removing node $nodeNum');

    final adminMsg = pb.AdminMessage()..removeByNodenum = nodeNum;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set a node as favorite
  Future<void> setFavoriteNode(int nodeNum) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set favorite: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set favorite: not connected');
    }

    _logger.i('Setting node $nodeNum as favorite');

    final adminMsg = pb.AdminMessage()..setFavoriteNode = nodeNum;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Removing node $nodeNum from favorites');

    final adminMsg = pb.AdminMessage()..removeFavoriteNode = nodeNum;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Setting fixed position: $latitude, $longitude, alt=$altitude');

    final position = pb.Position()
      ..latitudeI = (latitude * 1e7).toInt()
      ..longitudeI = (longitude * 1e7).toInt()
      ..altitude = altitude;

    final adminMsg = pb.AdminMessage()..setFixedPosition = position;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Removing fixed position');

    final adminMsg = pb.AdminMessage()..removeFixedPosition = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Setting device time to $unixTimestamp');

    final adminMsg = pb.AdminMessage()..setTimeOnly = unixTimestamp;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Setting HAM mode: callSign=$callSign');

    final hamParams = pb.HamParameters()
      ..callSign = callSign
      ..txPower = txPower
      ..frequency = frequency;

    final adminMsg = pb.AdminMessage()..setHamMode = hamParams;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  // ============================================================================
  // CONFIGURATION METHODS
  // ============================================================================

  /// Get device configuration by type
  Future<void> getConfig(pb.AdminMessage_ConfigType configType) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get config: not connected');
    }

    _logger.i('Requesting config: ${configType.name}');

    final adminMsg = pb.AdminMessage()..getConfigRequest = configType;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set device configuration (wraps with begin/commit transaction)
  Future<void> setConfig(pb.Config config) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set config: not connected');
    }

    _logger.i('Setting config');

    await _beginEditSettings();

    final adminMsg = pb.AdminMessage()..setConfig = config;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    await Future.delayed(const Duration(milliseconds: 200));
    await _commitEditSettings();
  }

  /// Set LoRa configuration (region, modem preset, TX power, etc.)
  Future<void> setLoRaConfig({
    required pbenum.RegionCode region,
    required pb.ModemPreset modemPreset,
    required int hopLimit,
    required bool txEnabled,
    required int txPower,
    bool overrideDutyCycle = false,
  }) async {
    _logger.i('Setting LoRa config');

    final loraConfig = pb.Config_LoRaConfig()
      ..region = region
      ..modemPreset = modemPreset
      ..hopLimit = hopLimit
      ..txEnabled = txEnabled
      ..txPower = txPower
      ..overrideDutyCycle = overrideDutyCycle;

    final config = pb.Config()..lora = loraConfig;
    await setConfig(config);
  }

  /// Set device configuration (role, serial, etc.)
  Future<void> setDeviceConfig({
    required pb.Config_DeviceConfig_Role_ role,
    required pb.Config_DeviceConfig_RebroadcastMode rebroadcastMode,
    required bool serialEnabled,
    required int nodeInfoBroadcastSecs,
    required bool ledHeartbeatDisabled,
    bool doubleTapAsButtonPress = false,
  }) async {
    _logger.i('Setting device config');

    final deviceConfig = pb.Config_DeviceConfig()
      ..role = role
      ..rebroadcastMode = rebroadcastMode
      ..serialEnabled = serialEnabled
      ..nodeInfoBroadcastSecs = nodeInfoBroadcastSecs
      ..doubleTapAsButtonPress = doubleTapAsButtonPress
      ..ledHeartbeatDisabled = ledHeartbeatDisabled;

    final config = pb.Config()..device = deviceConfig;
    await setConfig(config);
  }

  /// Set position configuration
  Future<void> setPositionConfig({
    required int positionBroadcastSecs,
    required bool positionBroadcastSmartEnabled,
    required bool fixedPosition,
    required pb.Config_PositionConfig_GpsMode gpsMode,
    required int gpsUpdateInterval,
    int gpsAttemptTime = 30,
    int broadcastSmartMinimumDistance = 100,
    int broadcastSmartMinimumIntervalSecs = 30,
    int positionFlags = 811,
  }) async {
    _logger.i('Setting position config: gpsMode=$gpsMode');

    final posConfig = pb.Config_PositionConfig()
      ..positionBroadcastSecs = positionBroadcastSecs
      ..positionBroadcastSmartEnabled = positionBroadcastSmartEnabled
      ..fixedPosition = fixedPosition
      ..gpsMode = gpsMode
      ..gpsEnabled = gpsMode == pb.Config_PositionConfig_GpsMode.ENABLED
      ..gpsUpdateInterval = gpsUpdateInterval
      ..gpsAttemptTime = gpsAttemptTime
      ..broadcastSmartMinimumDistance = broadcastSmartMinimumDistance
      ..broadcastSmartMinimumIntervalSecs = broadcastSmartMinimumIntervalSecs
      ..positionFlags = positionFlags;

    final config = pb.Config()..position = posConfig;
    await setConfig(config);
  }

  /// Set power configuration
  Future<void> setPowerConfig({
    required bool isPowerSaving,
    required int waitBluetoothSecs,
    required int sdsSecs,
    required int lsSecs,
    required int minWakeSecs,
    int onBatteryShutdownAfterSecs = 0,
  }) async {
    _logger.i('Setting power config');

    final powerConfig = pb.Config_PowerConfig()
      ..isPowerSaving = isPowerSaving
      ..onBatteryShutdownAfterSecs = onBatteryShutdownAfterSecs
      ..waitBluetoothSecs = waitBluetoothSecs
      ..sdsSecs = sdsSecs
      ..lsSecs = lsSecs
      ..minWakeSecs = minWakeSecs;

    final config = pb.Config()..power = powerConfig;
    await setConfig(config);
  }

  /// Set display configuration
  Future<void> setDisplayConfig({
    required int screenOnSecs,
    required int autoScreenCarouselSecs,
    required bool flipScreen,
    required pb.Config_DisplayConfig_DisplayUnits units,
    required pb.Config_DisplayConfig_DisplayMode displayMode,
    required bool headingBold,
    required bool wakeOnTapOrMotion,
    int gpsFormat = 0,
  }) async {
    _logger.i('Setting display config');

    final displayConfig = pb.Config_DisplayConfig()
      ..screenOnSecs = screenOnSecs
      ..gpsFormat = gpsFormat
      ..autoScreenCarouselSecs = autoScreenCarouselSecs
      ..flipScreen = flipScreen
      ..units = units
      ..displaymode = displayMode
      ..headingBold = headingBold
      ..wakeOnTapOrMotion = wakeOnTapOrMotion;

    final config = pb.Config()..display = displayConfig;
    await setConfig(config);
  }

  /// Set Bluetooth configuration
  Future<void> setBluetoothConfig({
    required bool enabled,
    required pb.Config_BluetoothConfig_PairingMode mode,
    required int fixedPin,
  }) async {
    _logger.i('Setting Bluetooth config');

    final btConfig = pb.Config_BluetoothConfig()
      ..enabled = enabled
      ..mode = mode
      ..fixedPin = fixedPin;

    final config = pb.Config()..bluetooth = btConfig;
    await setConfig(config);
  }

  /// Set network configuration
  Future<void> setNetworkConfig({
    required bool wifiEnabled,
    required String wifiSsid,
    required String wifiPsk,
    required bool ethEnabled,
    required String ntpServer,
  }) async {
    _logger.i('Setting network config');

    final networkConfig = pb.Config_NetworkConfig()
      ..wifiEnabled = wifiEnabled
      ..wifiSsid = wifiSsid
      ..wifiPsk = wifiPsk
      ..ethEnabled = ethEnabled
      ..ntpServer = ntpServer;

    final config = pb.Config()..network = networkConfig;
    await setConfig(config);
  }

  /// Set security configuration
  Future<void> setSecurityConfig({
    required bool isManaged,
    required bool serialEnabled,
    required bool debugLogEnabled,
    required bool adminChannelEnabled,
  }) async {
    _logger.i('Setting security config');

    final secConfig = pb.Config_SecurityConfig()
      ..isManaged = isManaged
      ..serialEnabled = serialEnabled
      ..debugLogApiEnabled = debugLogEnabled
      ..adminChannelEnabled = adminChannelEnabled;

    final config = pb.Config()..security = secConfig;
    await setConfig(config);
  }

  // ============================================================================
  // MODULE CONFIGURATION METHODS
  // ============================================================================

  /// Get module configuration by type
  Future<void> getModuleConfig(
    pb.AdminMessage_ModuleConfigType moduleType,
  ) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get module config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get module config: not connected');
    }

    _logger.i('Requesting module config: ${moduleType.name}');

    final adminMsg = pb.AdminMessage()..getModuleConfigRequest = moduleType;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set module configuration (wraps with begin/commit transaction)
  Future<void> setModuleConfig(pb.ModuleConfig moduleConfig) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set module config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set module config: not connected');
    }

    _logger.i('Setting module config');

    await _beginEditSettings();

    final adminMsg = pb.AdminMessage()..setModuleConfig = moduleConfig;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    await Future.delayed(const Duration(milliseconds: 200));
    await _commitEditSettings();
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
  }) async {
    _logger.i('Setting MQTT config');

    final mqttConfig = pb.ModuleConfig_MQTTConfig()
      ..enabled = enabled
      ..address = address
      ..username = username
      ..password = password
      ..encryptionEnabled = encryptionEnabled
      ..jsonEnabled = jsonEnabled
      ..tlsEnabled = tlsEnabled
      ..root = root
      ..proxyToClientEnabled = proxyToClientEnabled
      ..mapReportingEnabled = mapReportingEnabled;

    final moduleConfig = pb.ModuleConfig()..mqtt = mqttConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Get Telemetry module configuration
  /// Returns the current telemetry config, requesting from device if needed
  Future<pb.ModuleConfig_TelemetryConfig?> getTelemetryModuleConfig() async {
    // If we already have the config, return it
    if (_currentTelemetryConfig != null) {
      return _currentTelemetryConfig;
    }

    // Request config from device
    await getModuleConfig(pb.AdminMessage_ModuleConfigType.TELEMETRY_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _telemetryConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Telemetry config request timed out'),
      );
      return config;
    } catch (e) {
      _logger.e('Failed to get telemetry config: $e');
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
  }) async {
    _logger.i('Setting telemetry config');

    final telemetryConfig = pb.ModuleConfig_TelemetryConfig();
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

    final moduleConfig = pb.ModuleConfig()..telemetry = telemetryConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Get External Notification module configuration
  Future<pb.ModuleConfig_ExternalNotificationConfig?>
  getExternalNotificationModuleConfig() async {
    // If we already have the config, return it
    if (_currentExternalNotificationConfig != null) {
      return _currentExternalNotificationConfig;
    }

    // Request config from device
    await getModuleConfig(pb.AdminMessage_ModuleConfigType.EXTNOTIF_CONFIG);

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
      _logger.e('Failed to get external notification config: $e');
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
  }) async {
    _logger.i('Setting external notification config');

    final extNotifConfig = pb.ModuleConfig_ExternalNotificationConfig();
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

    final moduleConfig = pb.ModuleConfig()
      ..externalNotification = extNotifConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Set Store & Forward module configuration
  Future<void> setStoreForwardConfig({
    bool? enabled,
    bool? heartbeat,
    int? records,
    int? historyReturnMax,
    int? historyReturnWindow,
  }) async {
    _logger.i('Setting store & forward config');

    final sfConfig = pb.ModuleConfig_StoreForwardConfig();
    if (enabled != null) sfConfig.enabled = enabled;
    if (heartbeat != null) sfConfig.heartbeat = heartbeat;
    if (records != null) sfConfig.records = records;
    if (historyReturnMax != null) sfConfig.historyReturnMax = historyReturnMax;
    if (historyReturnWindow != null) {
      sfConfig.historyReturnWindow = historyReturnWindow;
    }

    final moduleConfig = pb.ModuleConfig()..storeForward = sfConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Get Store & Forward module configuration
  Future<pb.ModuleConfig_StoreForwardConfig?>
  getStoreForwardModuleConfig() async {
    // If we already have the config, return it
    if (_currentStoreForwardConfig != null) {
      return _currentStoreForwardConfig;
    }

    // Request config from device
    await getModuleConfig(pb.AdminMessage_ModuleConfigType.STOREFORWARD_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _storeForwardConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Store forward config request timed out'),
      );
      return config;
    } catch (e) {
      _logger.e('Failed to get store forward config: $e');
      return null;
    }
  }

  /// Get Detection Sensor module configuration
  Future<pb.ModuleConfig_DetectionSensorConfig?>
  getDetectionSensorModuleConfig() async {
    // If we already have the config, return it
    if (_currentDetectionSensorConfig != null) {
      return _currentDetectionSensorConfig;
    }

    // Request config from device
    await getModuleConfig(
      pb.AdminMessage_ModuleConfigType.DETECTIONSENSOR_CONFIG,
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
      _logger.e('Failed to get detection sensor config: $e');
      return null;
    }
  }

  /// Get Range Test module configuration
  Future<pb.ModuleConfig_RangeTestConfig?> getRangeTestModuleConfig() async {
    // If we already have the config, return it
    if (_currentRangeTestConfig != null) {
      return _currentRangeTestConfig;
    }

    // Request config from device
    await getModuleConfig(pb.AdminMessage_ModuleConfigType.RANGETEST_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _rangeTestConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Range test config request timed out'),
      );
      return config;
    } catch (e) {
      _logger.e('Failed to get range test config: $e');
      return null;
    }
  }

  /// Set Range Test module configuration
  Future<void> setRangeTestConfig({
    bool? enabled,
    int? sender,
    bool? save,
  }) async {
    _logger.i('Setting range test config');

    final rtConfig = pb.ModuleConfig_RangeTestConfig();
    if (enabled != null) rtConfig.enabled = enabled;
    if (sender != null) rtConfig.sender = sender;
    if (save != null) rtConfig.save = save;

    final moduleConfig = pb.ModuleConfig()..rangeTest = rtConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Get Ambient Lighting module configuration
  Future<pb.ModuleConfig_AmbientLightingConfig?>
  getAmbientLightingModuleConfig() async {
    // If we already have the config, return it
    if (_currentAmbientLightingConfig != null) {
      return _currentAmbientLightingConfig;
    }

    // Request config from device
    await getModuleConfig(
      pb.AdminMessage_ModuleConfigType.AMBIENTLIGHTING_CONFIG,
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
      _logger.e('Failed to get ambient lighting config: $e');
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
  }) async {
    _logger.i('Setting ambient lighting config');

    final alConfig = pb.ModuleConfig_AmbientLightingConfig();
    alConfig.ledState = ledState;
    alConfig.red = red;
    alConfig.green = green;
    alConfig.blue = blue;
    if (current != null) alConfig.current = current;

    final moduleConfig = pb.ModuleConfig()..ambientLighting = alConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Get PAX Counter module configuration
  Future<pb.ModuleConfig_PaxcounterConfig?> getPaxCounterModuleConfig() async {
    // If we already have the config, return it
    if (_currentPaxCounterConfig != null) {
      return _currentPaxCounterConfig;
    }

    // Request config from device
    await getModuleConfig(pb.AdminMessage_ModuleConfigType.PAXCOUNTER_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _paxCounterConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('PAX counter config request timed out'),
      );
      return config;
    } catch (e) {
      _logger.e('Failed to get PAX counter config: $e');
      return null;
    }
  }

  /// Set PAX Counter module configuration
  Future<void> setPaxCounterConfig({
    bool? enabled,
    int? updateInterval,
    bool? wifiEnabled,
    bool? bleEnabled,
  }) async {
    _logger.i('Setting PAX counter config');

    final paxConfig = pb.ModuleConfig_PaxcounterConfig();
    if (enabled != null) paxConfig.enabled = enabled;
    if (updateInterval != null) {
      paxConfig.paxcounterUpdateInterval = updateInterval;
    }

    final moduleConfig = pb.ModuleConfig()..paxcounter = paxConfig;
    await setModuleConfig(moduleConfig);
  }

  /// Get Serial module configuration
  Future<pb.ModuleConfig_SerialConfig?> getSerialModuleConfig() async {
    // If we already have the config, return it
    if (_currentSerialConfig != null) {
      return _currentSerialConfig;
    }

    // Request config from device
    await getModuleConfig(pb.AdminMessage_ModuleConfigType.SERIAL_CONFIG);

    // Wait for response with timeout
    try {
      final config = await _serialConfigController.stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Serial config request timed out'),
      );
      return config;
    } catch (e) {
      _logger.e('Failed to get serial config: $e');
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
  }) async {
    _logger.i('Setting serial config');

    final serialConfig = pb.ModuleConfig_SerialConfig();
    if (enabled != null) serialConfig.enabled = enabled;
    if (echo != null) serialConfig.echo = echo;
    if (rxd != null) serialConfig.rxd = rxd;
    if (txd != null) serialConfig.txd = txd;
    if (baud != null) {
      serialConfig.baud =
          pb.ModuleConfig_SerialConfig_Serial_Baud.valueOf(baud) ??
          pb.ModuleConfig_SerialConfig_Serial_Baud.BAUD_DEFAULT;
    }
    if (timeout != null) serialConfig.timeout = timeout;
    if (mode != null) {
      serialConfig.mode =
          pb.ModuleConfig_SerialConfig_Serial_Mode.valueOf(mode) ??
          pb.ModuleConfig_SerialConfig_Serial_Mode.DEFAULT;
    }
    if (overrideConsoleSerialPort != null) {
      serialConfig.overrideConsoleSerialPort = overrideConsoleSerialPort;
    }

    final moduleConfig = pb.ModuleConfig()..serial = serialConfig;
    await setModuleConfig(moduleConfig);
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

    _logger.i('Requesting canned messages');

    final adminMsg = pb.AdminMessage()
      ..getCannedMessageModuleMessagesRequest = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Setting canned messages');

    final adminMsg = pb.AdminMessage()
      ..setCannedMessageModuleMessages = messages;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Requesting ringtone');

    final adminMsg = pb.AdminMessage()..getRingtoneRequest = true;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Setting ringtone');

    final adminMsg = pb.AdminMessage()..setRingtoneMessage = rtttl;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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

    _logger.i('Deleting file: $filename');

    final adminMsg = pb.AdminMessage()..deleteFileRequest = filename;

    final data = pb.Data()
      ..portnum = pb.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = pb.MeshPacket()
      ..from = _myNodeNum!
      ..to = _myNodeNum!
      ..decoded = data
      ..id = _generatePacketId();

    final toRadio = pn.ToRadio()..packet = packet;
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
        _logger.i(
          'Inferred hardware from BLE model number "$_bleModelNumber": $inferred',
        );
        return inferred;
      }
    }

    // Try manufacturer name - SenseCAP/Seeed devices
    if (_bleManufacturerName != null && _bleManufacturerName!.isNotEmpty) {
      final mfgLower = _bleManufacturerName!.toLowerCase();
      if (mfgLower.contains('sensecap') || mfgLower.contains('seeed')) {
        _logger.i(
          'Inferred hardware from manufacturer "$_bleManufacturerName": Tracker T1000-E',
        );
        return 'Tracker T1000-E';
      }
    }

    // Fall back to device name
    if (_deviceName != null && _deviceName!.isNotEmpty) {
      final inferred = _inferHardwareModelFromDeviceName(_deviceName);
      if (inferred != null) {
        _logger.i(
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
    await _deliveryController.close();
    await _regionController.close();
  }
}
