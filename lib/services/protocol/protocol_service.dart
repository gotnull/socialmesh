// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../models/mesh_models.dart';
import '../../models/device_error.dart';
import '../../models/telemetry_log.dart';
import '../../generated/meshtastic/admin.pb.dart' as admin;
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/config.pb.dart' as config_pb;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../generated/meshtastic/module_config.pb.dart' as module_pb;
import '../../generated/meshtastic/channel.pb.dart' as channel_pb;
import '../../generated/meshtastic/channel.pbenum.dart' as channel_pbenum;
import '../../generated/meshtastic/portnums.pbenum.dart' as pn;
import '../../generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'admin_ack_tracker.dart';
import 'admin_target.dart';
import 'mesh_packet_builder.dart';
import 'packet_framer.dart';
import 'text_message_payload_budget.dart';
import 'socialmesh/sm_capability_store.dart';
import 'socialmesh/sm_codec.dart';
import 'socialmesh/sm_constants.dart';
import 'socialmesh/sm_feature_flag.dart';
import 'socialmesh/sm_file_transfer.dart';
import 'socialmesh/sm_identity.dart';
import 'socialmesh/sm_metrics.dart';
import 'socialmesh/sm_packet_router.dart';
import 'socialmesh/sm_presence.dart';
import 'socialmesh/sm_signal.dart';
import 'sip/mrrp_codec.dart';
import 'sip/mrrp_engine.dart';
import 'sip/sip_codec.dart';
import 'sip/sip_constants.dart';
import 'sip/sip_counters.dart';
import 'sip/sip_discovery.dart';
import 'sip/sip_dm.dart';
import 'sip/sip_frame.dart';
import 'sip/sip_handshake.dart';
import 'sip/sip_identity.dart';
import 'sip/sip_rate_limiter.dart';
import 'sip/sip_types.dart';
import 'overlay/overlay_link_codec.dart';
import '../mesh_packet_dedupe_store.dart';
import '../mesh_health/mesh_health_models.dart';
import '../notifications/notification_service.dart';
import '../security/stl_envelope.dart';
import '../security/stl_middleware.dart';
import '../../utils/text_sanitizer.dart';
import '../../models/presence_confidence.dart';
import '../../features/nodes/node_display_name_resolver.dart';

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
    final content = sanitizeExternalText(
      json['c'] as String? ?? json['content'] as String? ?? '',
    );
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
    final text = sanitizeExternalText(utf8.decode(payload));
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

/// Event emitted by the file-transfer StreamController inside ProtocolService.
/// Carries the decoded packet (SmFileOffer / SmFileChunk / SmFileNack /
/// SmFileAck) together with its type discriminator and originating node.
class SmFileTransferEvent {
  final SmPacketType type;
  final Object packet;
  final int senderNodeNum;

  /// Protocol version from the wire header (bits 7-4). Defaults to 0.
  final int version;

  const SmFileTransferEvent({
    required this.type,
    required this.packet,
    required this.senderNodeNum,
    this.version = 0,
  });
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

// ─────────────────────────────────────────────────────────────────────
// Protobuf portnum helpers for SM portnums (260-262)
//
// The generated PortNum enum only covers values defined in the
// Meshtastic .proto files.  SM portnums 260-262 are NOT in the enum,
// so PortNum.valueOf(261) returns null.  On the sender side we need
// to write the raw int to the wire; on the receiver side protobuf
// 6.0.0 stores unknown enum values in unknownFields rather than in
// the field getter (data.portnum.value returns 0).
// ─────────────────────────────────────────────────────────────────────

/// Creates a [pb.Data] with the given portnum set as raw protobuf bytes.
///
/// Use this instead of `..portnum = PortNum.valueOf(x)` for portnums
/// outside the generated enum (SM portnums 260-262).
pb.Data _createDataWithPortnum(int portnum, Uint8List payload) {
  final data = pb.Data()..payload = payload;
  // Encode field 1 (portnum), wire type 0 (varint)
  final bytes = <int>[0x08]; // tag: (1 << 3) | 0
  var v = portnum;
  while (v > 0x7F) {
    bytes.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  bytes.add(v & 0x7F);
  data.mergeFromBuffer(bytes);
  return data;
}

/// Extracts the raw portnum int from a [pb.Data] message.
///
/// Protobuf 6.0.0 maps unknown enum values to the default (0).
/// The raw int is preserved in [UnknownFieldSet] under tag 1.
int _extractRawPortnum(pb.Data data) {
  final value = data.portnum.value;
  if (value != 0) return value;
  // Check unknownFields for the raw portnum value
  final field = data.unknownFields.getField(1);
  if (field != null && field.varints.isNotEmpty) {
    return field.varints.first.toInt();
  }
  return value;
}

/// Ephemeral PKC admin session obtained from a remote node's admin response.
///
/// The firmware returns a session passkey in [AdminMessage.sessionPasskey].
/// This passkey authenticates subsequent SET/ACTION admin operations on the
/// remote node. Sessions expire after 5 minutes (firmware default).
class _AdminSession {
  final List<int> passkey;
  final DateTime expiration;

  const _AdminSession({required this.passkey, required this.expiration});

  bool get isExpired => DateTime.now().isAfter(expiration);
}

/// Protocol service for handling Meshtastic protocol
class ProtocolService {
  final DeviceTransport _transport;
  late final PacketFramer _framer;

  final StreamController<Message> _messageController;
  final StreamController<MeshNode> _nodeController;
  final StreamController<ChannelConfig> _channelController;
  final StreamController<DeviceError> _errorController;
  final StreamController<MeshSignalPacket> _signalController;
  final StreamController<SmFileTransferEvent> _fileTransferController;
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
  final StreamController<String> _cannedMessageTextController;
  final StreamController<String> _ringtoneTextController;
  final StreamController<module_pb.ModuleConfig_TrafficManagementConfig>
  _trafficManagementConfigController;
  final StreamController<pb.ClientNotification> _clientNotificationController;
  final StreamController<pb.User> _userConfigController;
  final StreamController<DetectionSensorEvent> _detectionSensorEventController;
  final StreamController<TraceRouteLog> _traceRouteLogController;
  final StreamController<MeshTelemetry> _meshTelemetryController;
  final StreamController<pb.MqttClientProxyMessage>
  _mqttClientProxyMessageController;

  /// Emitted when a config or admin message is sent to the **local** node
  /// (not a remote target) that is expected to trigger a firmware reboot.
  /// Consumers (e.g. the reconnect flow) use this to enter reboot
  /// recovery mode and extend patience before pairing invalidation.
  final StreamController<void> _localConfigWriteController;

  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<DeviceConnectionState>? _transportStateSubscription;
  Completer<void>? _configCompleter;
  Timer? _rssiTimer;
  bool _pollingConfig = false;

  // --- Phased connect handshake ---
  //
  // The firmware replays packets that arrived while the phone app was
  // disconnected from its internal `phoneQueue` — but only in response to a
  // second wantConfigId following the initial one. Mirrors the two-phase
  // `sendWantConfig` / `sendWantDatabase` sequence the official Meshtastic
  // iOS app uses (NONCE_ONLY_CONFIG = 69420 then NONCE_ONLY_DB = 69421).
  //
  // See meshtastic-ios/Meshtastic/Accessory/Accessory Manager/
  //   AccessoryManager.swift (lines 117–118, 193–252, 707–737) and
  //   AccessoryManager+Connect.swift (Steps 3 and 5).
  static const int _nonceInitialConfig = 69420;
  static const int _nonceQueueDrain = 69421;
  _HandshakePhase _handshakePhase = _HandshakePhase.idle;

  /// Completes when the phase-2 `configCompleteId(69421)` arrives. The
  /// queue-drain retry loop in `_requestQueueDrain` awaits this to decide
  /// whether to re-send. Fresh per attempt, recreated by
  /// `_requestQueueDrain` on every retry.
  Completer<void>? _queueDrainCompleter;

  /// Timestamp of the last data received from the transport layer.
  ///
  /// Updated inside [_handleDataAsync] every time the transport delivers
  /// bytes. The RSSI polling timer checks this value to detect a stalled
  /// notification path — if connected and configured but no data has arrived
  /// for [_dataStaleThreshold], the protocol service asks the transport to
  /// refresh its BLE notification subscriptions. If data flow still doesn't
  /// resume after an additional [_dataStaleDisconnectGrace], it triggers a
  /// disconnect so the auto-reconnect path can establish a fresh session.
  DateTime? _lastDataReceivedAt;

  /// Whether a notification refresh has already been requested in the
  /// current stale-data episode to avoid redundant refresh calls.
  bool _notificationRefreshRequested = false;

  /// Duration after which the absence of transport data is considered stale.
  /// Meshtastic radios emit telemetry/position every 15–900 s depending on
  /// config. 3 minutes covers the common default cadences with margin.
  static const Duration _dataStaleThreshold = Duration(minutes: 3);

  /// Additional grace period after a notification refresh before the service
  /// decides the receive path is truly broken and forces a disconnect.
  static const Duration _dataStaleDisconnectGrace = Duration(seconds: 30);

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
  module_pb.ModuleConfig_TrafficManagementConfig?
  _currentTrafficManagementConfig;
  pb.User? _currentUserConfig;
  final Map<int, MeshNode> _nodes = {};
  final List<ChannelConfig> _channels = [];
  final Random _random = Random();
  bool _configurationComplete = false;
  final MeshPacketDedupeStore _dedupeStore;

  /// STL middleware for verified inbound unwrapping.
  final StlMiddleware _stlMiddleware = StlMiddleware();

  // --- Position rate limiter ---
  // Prevents any caller from spamming POSITION_APP packets regardless of
  // how they reach sendPosition() / sendPositionToNode(). This is the
  // authoritative last-mile enforcement point for position airtime.
  DateTime? _lastPositionBroadcastAt;
  DateTime? _lastPositionDirectAt;
  static const Duration _positionBroadcastMinInterval = Duration(seconds: 20);
  static const Duration _positionDirectMinInterval = Duration(seconds: 10);

  void Function({
    required int nodeNum,
    String? longName,
    String? shortName,
    int? lastSeenAtMs,
  })?
  onIdentityUpdate;

  static const Duration _messagePacketTtl = Duration(minutes: 120);

  /// Minimum plausible Unix timestamp for message timestamps.
  /// 2020-01-01 00:00:00 UTC — any rxTime before this is treated as invalid.
  static const int _minPlausibleEpoch = 1577836800;

  /// Maximum clock drift tolerance: 1 day into the future.
  static const int _maxFutureSlack = 86400;

  // Track pending messages by packet ID for delivery status updates
  final Map<int, String> _pendingMessages = {}; // packetId -> messageId

  /// Tracks remote admin packets awaiting ACK from the mesh.
  final AdminAckTracker _adminAckTracker = AdminAckTracker();

  // BLE device name for hardware model inference
  String? _deviceName;

  // --- Socialmesh binary protocol components ---
  final SmCapabilityStore _smCapabilityStore;
  final SmFeatureFlag _smFeatureFlag;
  final SmMetrics _smMetrics;
  final SmRateLimiter _smRateLimiter;
  final SmIdentityRateLimiter _smIdentityRateLimiter;

  // --- SIP protocol components ---
  SipDiscovery? _sipDiscovery;
  SipHandshakeManager? _sipHandshake;
  SipIdentityHandler? _sipIdentity;
  SipDmManager? _sipDm;
  SipCounters? _sipCounters;

  /// Shared SIP rate limiter. When attached, HS_HELLO retransmits (and
  /// any future handshake/identity sends routed through this service)
  /// will consult + record against the byte budget rather than bypassing
  /// it entirely.
  SipRateLimiter? _sipRateLimiter;

  // --- MRRP protocol component ---
  MrrpEngine? _mrrpEngine;

  // --- Startup buffers ---
  //
  // SIP frames and MRRP frames that arrive before the respective runtime
  // components are attached are held here and replayed once attachment
  // occurs. Without this buffer, every packet that arrives during the
  // startup window (between BLE connection and the first UI screen that
  // watches sipDiscoveryProvider / mrrpEngineProvider) is permanently
  // lost — including SERVICE_ADVERT frames that populate Mesh Explorer.
  //
  // Both buffers are bounded to prevent unbounded memory growth if
  // attachment never happens (e.g. SIP is later disabled).
  static const int _kSipStartupBufferMax = 16;
  final List<({pb.MeshPacket packet, Uint8List payload})> _sipStartupBuffer =
      [];

  static const int _kMrrpStartupBufferMax = 16;
  final List<({int senderNodeId, SipFrame frame})> _mrrpStartupBuffer = [];

  // Overlay v0.2 ingress hook. `null` when the overlay attachment
  // provider has not attached yet, or when OVERLAY_LINK_ENABLED is off
  // (the provider simply does not call [attachOverlayInbound]). Frames
  // that sniff as v0.2 link frames are buffered here while the hook
  // is unset so they survive the provider-init window, mirroring the
  // MRRP startup-buffer pattern.
  static const int _kOverlayStartupBufferMax = 16;
  final List<({int senderNodeId, Uint8List mrrpPayload})>
  _overlayStartupBuffer = [];
  Future<void> Function(int senderNodeId, Uint8List mrrpPayload)?
  _overlayInbound;

  /// Cumulative count of overlay v0.2 frames discarded because the
  /// startup buffer was full at the time of arrival. Observability
  /// hook for "overlay traffic vanished mysteriously" diagnostics
  /// (P2 caveat). Logged at rate-limited intervals — never per-frame.
  int _overlayStartupBufferDrops = 0;

  /// Next drop count at which an aggregate log line will fire.
  /// Doubles each time to keep logs bounded even under sustained loss.
  int _overlayStartupBufferNextLogAt = 1;

  /// Diagnostic: total overlay v0.2 frames discarded due to a full
  /// startup buffer since the [ProtocolService] was created.
  int get overlayStartupBufferDrops => _overlayStartupBufferDrops;

  /// Attach a SipDiscovery instance so inbound SIP packets can be routed.
  ///
  /// Called from the provider layer once the discovery engine is created.
  /// Any frames buffered during the pre-attachment startup window are
  /// drained in a microtask after this method returns. The drain is
  /// deferred because it may trigger MRRP callbacks that mutate other
  /// Riverpod providers — Riverpod forbids cross-provider state changes
  /// during a provider's synchronous initialization.
  void attachSipDiscovery(SipDiscovery? discovery) {
    _sipDiscovery = discovery;
    if (discovery != null) {
      AppLogging.sip('ProtocolService: SipDiscovery attached');
      Future.microtask(_drainSipStartupBuffer);
    }
  }

  /// Clear both startup buffers, discarding any undelivered frames.
  ///
  /// Called by [start] to ensure stale frames from a prior BLE session cannot
  /// be replayed to a new session's [SipDiscovery] or [MrrpEngine].
  void _clearStartupBuffers() {
    if (_sipStartupBuffer.isNotEmpty || _mrrpStartupBuffer.isNotEmpty) {
      AppLogging.sip(
        'SIP_STARTUP: discarding ${_sipStartupBuffer.length} SIP + '
        '${_mrrpStartupBuffer.length} MRRP buffered frames (new session)',
      );
    }
    _sipStartupBuffer.clear();
    _mrrpStartupBuffer.clear();
    _overlayStartupBuffer.clear();
    _overlayStartupBufferDrops = 0;
    _overlayStartupBufferNextLogAt = 1;
  }

  /// Drain frames buffered before [SipDiscovery] was attached.
  void _drainSipStartupBuffer() {
    if (_sipStartupBuffer.isEmpty) return;
    final buffered = List.of(_sipStartupBuffer);
    _sipStartupBuffer.clear();
    AppLogging.sip(
      'SIP_STARTUP: draining ${buffered.length} buffered early frame(s)',
    );
    for (final item in buffered) {
      _handleSipPacket(item.packet, item.payload);
    }
    AppLogging.sip('SIP_STARTUP: drain complete');
  }

  /// Attach a SipHandshakeManager for inbound handshake frames.
  void attachSipHandshake(SipHandshakeManager? handshake) {
    _sipHandshake = handshake;
    if (handshake != null) {
      handshake.onHelloRetransmit = (peerNodeId, frame) {
        final encoded = SipCodec.encode(frame);
        if (encoded == null) return;
        // Route through the gated path so retransmits respect the SIP
        // byte budget instead of bypassing it.
        sendSipGated(encoded, SipMessageType.hsHello);
      };
      AppLogging.sip('ProtocolService: SipHandshakeManager attached');
    }
  }

  /// Attach the shared SIP rate limiter. Gates HS_HELLO retransmits
  /// (and future handshake send paths) against the byte budget.
  /// Pass `null` to detach.
  void attachSipRateLimiter(SipRateLimiter? limiter) {
    _sipRateLimiter = limiter;
    if (limiter != null) {
      AppLogging.sip('ProtocolService: SipRateLimiter attached');
    }
  }

  /// Callback fired exactly once per successful handshake completion,
  /// **after** the DM session is created (or deduped).
  ///
  /// The provider layer wires this to auto-open an overlay v0.2 link in
  /// the background when both peers advertise overlay capability. Kept
  /// as a narrow void callback — protocol_service must not depend on
  /// the overlay engine directly.
  ///
  /// Invoked fire-and-forget. Exceptions thrown by the callback are
  /// logged and swallowed — they MUST NOT break the SIP/DM ready path.
  void Function(int peerNodeId)? onSipHandshakeComplete;

  /// Attach a SipIdentityHandler for inbound identity frames.
  void attachSipIdentity(SipIdentityHandler? identity) {
    _sipIdentity = identity;
    if (identity != null) {
      AppLogging.sip('ProtocolService: SipIdentityHandler attached');
    }
  }

  /// Attach a SipDmManager for inbound DM frames.
  void attachSipDm(SipDmManager? dm) {
    _sipDm = dm;
    if (dm != null) {
      AppLogging.sip('ProtocolService: SipDmManager attached');
    }
  }

  /// Attach SipCounters for instrumentation.
  void attachSipCounters(SipCounters? counters) {
    _sipCounters = counters;
    if (counters != null) {
      AppLogging.sip('ProtocolService: SipCounters attached');
    }
  }

  /// Attach an MrrpEngine for inbound MRRP frames.
  ///
  /// [_mrrpEngine] is assigned synchronously so any frames arriving after
  /// this call are handled directly. Buffered frames from the pre-attachment
  /// window are drained in a microtask — same pattern as [attachSipDiscovery]
  /// — because the drain triggers counter / advert-cache updates that mutate
  /// other Riverpod providers. Riverpod forbids cross-provider state changes
  /// during a provider's synchronous initialization.
  ///
  /// The critical start/attach ordering contract is preserved: [engine.start()]
  /// must still be called before this method. The engine reference is set
  /// synchronously, so the microtask-deferred drain processes frames on an
  /// already-running engine. Any new frames arriving between assignment and
  /// drain execute through [_handleMrrpPacket] directly (no buffer).
  void attachMrrpEngine(MrrpEngine? engine) {
    _mrrpEngine = engine;
    if (engine != null) {
      AppLogging.mrrp('ProtocolService: MrrpEngine attached');
      Future.microtask(_drainMrrpStartupBuffer);
    }
  }

  /// Drain MRRP frames buffered before [MrrpEngine] was attached.
  void _drainMrrpStartupBuffer() {
    if (_mrrpStartupBuffer.isEmpty) return;
    final buffered = List.of(_mrrpStartupBuffer);
    _mrrpStartupBuffer.clear();
    AppLogging.mrrp(
      'MRRP_STARTUP: draining ${buffered.length} buffered mrrpData frame(s)',
    );
    for (final item in buffered) {
      _handleMrrpPacket(item.senderNodeId, item.frame);
    }
    AppLogging.mrrp('MRRP_STARTUP: drain complete');
  }

  /// Attach a handler for inbound MRRP v0.2 overlay link frames.
  ///
  /// The handler is the single authoritative ingress path for the
  /// overlay. Only one handler may be attached at a time; passing
  /// `null` detaches. The provider layer (`overlayAttachmentProvider`)
  /// calls `attachOverlayInbound(null)` from `ref.onDispose` to null
  /// the reference on every teardown — avoiding the class of bugs
  /// described in the "no duplicate subscribers" P1 locked rule.
  ///
  /// When [handler] is attached and the startup buffer contains
  /// frames that arrived before attach, they are drained in a
  /// microtask to avoid cross-provider mutation during synchronous
  /// provider init — same contract as [attachMrrpEngine].
  void attachOverlayInbound(
    Future<void> Function(int senderNodeId, Uint8List mrrpPayload)? handler,
  ) {
    _overlayInbound = handler;
    if (handler != null) {
      AppLogging.overlay('ProtocolService: overlay ingress attached');
      Future.microtask(_drainOverlayStartupBuffer);
    } else {
      AppLogging.overlay('ProtocolService: overlay ingress detached');
    }
  }

  /// Drain overlay frames buffered before [attachOverlayInbound].
  Future<void> _drainOverlayStartupBuffer() async {
    if (_overlayStartupBuffer.isEmpty) return;
    final handler = _overlayInbound;
    if (handler == null) return;
    final buffered = List.of(_overlayStartupBuffer);
    _overlayStartupBuffer.clear();
    AppLogging.overlay(
      'OVERLAY_STARTUP: draining ${buffered.length} buffered frame(s)',
    );
    for (final item in buffered) {
      await handler(item.senderNodeId, item.mrrpPayload);
    }
    AppLogging.overlay('OVERLAY_STARTUP: drain complete');
  }

  /// Diagnostic: buffered overlay frames awaiting attachment.
  int get overlayStartupBufferLength => _overlayStartupBuffer.length;

  /// Callback invoked when an identity claim is verified, for NodeDex bridging.
  ///
  /// Set by the provider layer to bridge verified identities into NodeDex.
  void Function({
    required int nodeId,
    required Uint8List pubkey,
    required Uint8List personaId,
    required SipIdentityState identityState,
    String? displayName,
  })?
  onSipIdentityVerified;

  /// Per-node session passkeys for PKC remote admin authentication.
  ///
  /// The firmware returns a session passkey in admin responses (especially
  /// getDeviceMetadataResponse). This passkey must be included in subsequent
  /// SET/ACTION admin messages for the session to be accepted. Sessions
  /// expire after [_sessionPasskeyTtl] (matching the firmware's 300s default).
  final Map<int, _AdminSession> _adminSessions = {};
  static const Duration _sessionPasskeyTtl = Duration(minutes: 5);

  /// Public accessors for SM binary protocol components.
  SmCapabilityStore get smCapabilityStore => _smCapabilityStore;
  SmFeatureFlag get smFeatureFlag => _smFeatureFlag;
  SmMetrics get smMetrics => _smMetrics;

  ProtocolService(
    this._transport, {
    MeshPacketDedupeStore? dedupeStore,
    SmCapabilityStore? smCapabilityStore,
    SmFeatureFlag? smFeatureFlag,
  }) : _messageController = StreamController<Message>.broadcast(),
       _nodeController = StreamController<MeshNode>.broadcast(),
       _channelController = StreamController<ChannelConfig>.broadcast(),
       _errorController = StreamController<DeviceError>.broadcast(),
       _signalController = StreamController<MeshSignalPacket>.broadcast(),
       _fileTransferController =
           StreamController<SmFileTransferEvent>.broadcast(),
       _myNodeNumController = StreamController<int>.broadcast(),
       _rssiController = StreamController<int>.broadcast(),
       _snrController = StreamController<double>.broadcast(),
       _channelUtilController = StreamController<double>.broadcast(),
       _deliveryController =
           StreamController<MessageDeliveryUpdate>.broadcast(),
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
           StreamController<
             module_pb.ModuleConfig_PaxcounterConfig
           >.broadcast(),
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
       _cannedMessageTextController = StreamController<String>.broadcast(),
       _ringtoneTextController = StreamController<String>.broadcast(),
       _trafficManagementConfigController =
           StreamController<
             module_pb.ModuleConfig_TrafficManagementConfig
           >.broadcast(),
       _clientNotificationController =
           StreamController<pb.ClientNotification>.broadcast(),
       _userConfigController = StreamController<pb.User>.broadcast(),
       _detectionSensorEventController =
           StreamController<DetectionSensorEvent>.broadcast(),
       _traceRouteLogController = StreamController<TraceRouteLog>.broadcast(),
       _meshTelemetryController = StreamController<MeshTelemetry>.broadcast(),
       _mqttClientProxyMessageController =
           StreamController<pb.MqttClientProxyMessage>.broadcast(),
       _localConfigWriteController = StreamController<void>.broadcast(),
       _dedupeStore = dedupeStore ?? MeshPacketDedupeStore(),
       _smCapabilityStore = smCapabilityStore ?? SmCapabilityStore(),
       _smFeatureFlag = smFeatureFlag ?? SmFeatureFlag(),
       _smMetrics = SmMetrics(),
       _smRateLimiter = SmRateLimiter(),
       _smIdentityRateLimiter = SmIdentityRateLimiter() {
    _framer = PacketFramer(
      onAbuseDetected: () {
        AppLogging.protocol(
          'SECURITY: Framer abuse detected - disconnecting transport',
        );
        _transport.disconnect();
      },
    );
  }

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

  /// Stream of parsed traceroute responses
  Stream<TraceRouteLog> get traceRouteLogStream =>
      _traceRouteLogController.stream;

  /// Stream of per-packet telemetry for mesh health analysis.
  ///
  /// Emits a [MeshTelemetry] for every incoming decoded mesh packet,
  /// capturing packet-level metadata (RSSI, SNR, hop count, payload
  /// size, etc.) needed by [MeshHealthAnalyzer].
  Stream<MeshTelemetry> get meshTelemetryStream =>
      _meshTelemetryController.stream;

  /// Emitted when a config write to the local node completes. The
  /// reconnect flow listens to this to enter reboot recovery mode.
  Stream<void> get localConfigWriteStream => _localConfigWriteController.stream;

  /// Stream of received messages
  Stream<Message> get messageStream => _messageController.stream;

  /// Stream of node updates
  Stream<MeshNode> get nodeStream => _nodeController.stream;

  /// Stream of channel updates
  Stream<ChannelConfig> get channelStream => _channelController.stream;

  /// Stream of received mesh signal packets (PRIVATE_APP portnum)
  Stream<MeshSignalPacket> get signalStream => _signalController.stream;

  /// Stream of incoming SM file transfer packets (FILE_OFFER, FILE_CHUNK,
  /// FILE_NACK, FILE_ACK). Consumers subscribe instead of setting a callback.
  Stream<SmFileTransferEvent> get fileTransferStream =>
      _fileTransferController.stream;

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

  /// Stream of MQTT client proxy messages from the device.
  ///
  /// When the device has `proxyToClientEnabled = true`, it sends
  /// outbound MQTT messages via this stream for the phone to publish
  /// to the broker.
  Stream<pb.MqttClientProxyMessage> get mqttClientProxyMessageStream =>
      _mqttClientProxyMessageController.stream;

  /// Sends an MQTT client proxy message to the device.
  ///
  /// This delivers an inbound MQTT message from the broker to the
  /// device via `ToRadio.mqttClientProxyMessage`.
  Future<void> sendMqttClientProxyMessage(
    pb.MqttClientProxyMessage proxyMsg,
  ) async {
    if (_myNodeNum == null || !_transport.isConnected) return;
    final toRadio = pb.ToRadio()..mqttClientProxyMessage = proxyMsg;
    try {
      await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
      AppLogging.mqttProxy(
        'Sent proxy message to device (topic: ${proxyMsg.topic})',
      );
    } catch (e) {
      AppLogging.mqttProxy(
        'Failed to send proxy message (device may have disconnected): $e',
      );
    }
  }

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

  /// Stream of range test config updates
  Stream<module_pb.ModuleConfig_RangeTestConfig> get rangeTestConfigStream =>
      _rangeTestConfigController.stream;

  /// Current range test config
  module_pb.ModuleConfig_RangeTestConfig? get currentRangeTestConfig =>
      _currentRangeTestConfig;

  /// Stream of external notification config updates
  Stream<module_pb.ModuleConfig_ExternalNotificationConfig>
  get externalNotificationConfigStream =>
      _externalNotificationConfigController.stream;

  /// Current external notification config
  module_pb.ModuleConfig_ExternalNotificationConfig?
  get currentExternalNotificationConfig => _currentExternalNotificationConfig;

  /// Stream of canned message config updates
  Stream<module_pb.ModuleConfig_CannedMessageConfig>
  get cannedMessageConfigStream => _cannedMessageConfigController.stream;

  /// Current canned message config
  module_pb.ModuleConfig_CannedMessageConfig? get currentCannedMessageConfig =>
      _currentCannedMessageConfig;

  /// Stream of canned message text updates (pipe-separated)
  Stream<String> get cannedMessageTextStream =>
      _cannedMessageTextController.stream;

  /// Stream of ringtone text updates (RTTTL format)
  Stream<String> get ringtoneTextStream => _ringtoneTextController.stream;

  /// Stream of traffic management config updates
  Stream<module_pb.ModuleConfig_TrafficManagementConfig>
  get trafficManagementConfigStream =>
      _trafficManagementConfigController.stream;

  /// Current traffic management config
  module_pb.ModuleConfig_TrafficManagementConfig?
  get currentTrafficManagementConfig => _currentTrafficManagementConfig;

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

  /// ACK tracker for confirmed-mode remote admin operations.
  ///
  /// Local admin callers MUST NOT use this — local packets are processed
  /// synchronously by the firmware and never produce routing ACKs.
  AdminAckTracker get adminAckTracker => _adminAckTracker;

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
    _handshakePhase = _HandshakePhase.idle;
    if (_queueDrainCompleter != null && !_queueDrainCompleter!.isCompleted) {
      _queueDrainCompleter!.completeError('Connection reset');
    }
    _queueDrainCompleter = null;
    // Discard any SIP/MRRP frames buffered from a prior BLE session.
    // Without this, frames from Device A remain in the buffer and are
    // replayed to Device B's SipDiscovery / MrrpEngine after reconnect.
    _clearStartupBuffers();

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

      // Send heartbeat to wake the device before requesting config.
      // Follows the standard Meshtastic connection sequence (heartbeat first,
      // then wantConfigId). Devices in low-power sleep (e.g. Heltec
      // MeshPocket) may not process the first wantConfigId without this.
      await _sendHeartbeat();

      // NOW request configuration - device will respond via notifications
      await _requestConfiguration();

      // Start polling for configuration response
      // Notifications should work, but poll as backup
      _pollForConfigurationAsync();

      // Now we're waiting for config - enable the listener to complete on error
      waitingForConfig = true;

      // Wait for config to complete with timeout.
      //
      // Transport-aware early recovery: TCP sessions have a different
      // failure profile than BLE. NOTIFY-style flakiness does not exist
      // on a raw TCP socket — if bytes do not arrive it is almost always
      // because the firmware missed the first `wantConfigId` (common
      // after a remote reboot). Rather than consume the full 30s wait,
      // fire a single early retry so the user is not staring at a blank
      // configuring screen for half a minute. BLE/USB keep their
      // original single-shot behavior; the existing data-flow watchdog
      // handles stalled NOTIFY paths separately.
      AppLogging.protocol('Protocol: Waiting for configCompleteId...');
      const totalTimeout = Duration(seconds: 30);
      const earlyRetryWindow = Duration(seconds: 8);
      Timer? earlyRetryTimer;
      if (_transport.reconnectMode == TransportReconnectMode.directEndpoint) {
        earlyRetryTimer = Timer(earlyRetryWindow, () async {
          // Idempotence: (1) completer nulled/completed means either
          // success or stop()/error has already settled the wait — skip.
          // (2) transport not connected means the socket already died
          // and there is nothing to retry on.
          final completer = _configCompleter;
          if (completer == null || completer.isCompleted) return;
          if (!_transport.isConnected) return;
          AppLogging.protocol(
            'HANDSHAKE: phase-1 not observed within '
            '${earlyRetryWindow.inSeconds}s on '
            '${_transport.type.name} — resending wantConfigId once '
            '(bounded retry, not a handshake restart)',
          );
          try {
            await _requestConfiguration();
          } catch (e) {
            AppLogging.protocol(
              'HANDSHAKE: early phase-1 retry send failed — $e',
            );
          }
        });
      }
      try {
        await _configCompleter!.future.timeout(
          totalTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Configuration timed out waiting for device response',
            );
          },
        );
      } finally {
        earlyRetryTimer?.cancel();
      }
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

  /// Start periodic RSSI polling from BLE connection.
  ///
  /// Polls every 5 seconds. BLE signal strength between phone and radio
  /// changes slowly; 5-second granularity is imperceptible on the lock
  /// screen Live Activity while cutting BLE wake-ups by 60% vs 2 seconds.
  void _startRssiPolling() {
    _rssiTimer?.cancel();
    _rssiPaused = false;
    _lastDataReceivedAt = DateTime.now();
    _notificationRefreshRequested = false;
    _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final rssi = await _transport.readRssi();
      if (rssi != null && rssi != _lastRssi) {
        _lastRssi = rssi;
        _rssiController.add(rssi);
      }

      // --- Data-flow health check ---
      // Detect a stalled BLE notification path: the transport reports
      // connected but no data has arrived for longer than expected.
      _checkDataFlowHealth();
    });
  }

  /// Evaluate whether the receive path is still alive.
  ///
  /// Called from the RSSI polling timer every 5 seconds.  When data has
  /// not been received for [_dataStaleThreshold] the transport is asked
  /// to refresh its BLE notification subscription (iOS/Android can drop
  /// these silently).  If data still does not arrive within an
  /// additional [_dataStaleDisconnectGrace], a disconnect is forced so
  /// the auto-reconnect path can establish a fresh session.
  void _checkDataFlowHealth() {
    if (!_configurationComplete || !_transport.isConnected) return;
    if (_rssiPaused) return; // Don't fire while app is backgrounded

    final lastData = _lastDataReceivedAt;
    if (lastData == null) return;

    final staleness = DateTime.now().difference(lastData);

    if (staleness > _dataStaleThreshold) {
      if (!_notificationRefreshRequested) {
        // First escalation: refresh BLE notification subscription.
        _notificationRefreshRequested = true;
        AppLogging.protocol(
          '⚠️ DATA_HEALTH: No data received for '
          '${staleness.inSeconds}s — refreshing BLE notifications',
        );
        unawaited(
          _transport.refreshNotifications().catchError((Object e) {
            AppLogging.protocol(
              '⚠️ DATA_HEALTH: refreshNotifications failed: $e',
            );
          }),
        );

        // Also send a heartbeat to provoke a device response.
        unawaited(
          _sendHeartbeat().catchError((Object e) {
            AppLogging.protocol('⚠️ DATA_HEALTH: sendHeartbeat failed: $e');
          }),
        );
      } else if (staleness > _dataStaleThreshold + _dataStaleDisconnectGrace) {
        // Second escalation: refresh did not help — disconnect.
        AppLogging.protocol(
          '🔌 DATA_HEALTH: Still no data after notification refresh '
          '(${staleness.inSeconds}s) — forcing disconnect',
        );
        _notificationRefreshRequested = false;
        unawaited(
          _transport.disconnect().catchError((Object e) {
            AppLogging.protocol('⚠️ DATA_HEALTH: disconnect failed: $e');
          }),
        );
      }
    }
  }

  /// Whether RSSI polling is currently paused (app backgrounded).
  bool _rssiPaused = false;

  /// Pause RSSI polling to conserve battery while the app is backgrounded.
  ///
  /// BLE `readRssi()` every 2 seconds wakes the Bluetooth stack and triggers
  /// Live Activity UserDefaults writes. Over an 8-hour night that is ~14,400
  /// unnecessary BLE round-trips. Pausing eliminates this entirely; the Live
  /// Activity keeps the last-known value on the lock screen.
  void pauseRssiPolling() {
    if (_rssiPaused) return;
    _rssiPaused = true;
    _rssiTimer?.cancel();
    _rssiTimer = null;
    AppLogging.protocol('🔋 RSSI polling paused (app backgrounded)');
  }

  /// Resume RSSI polling when the app returns to the foreground.
  void resumeRssiPolling() {
    if (!_rssiPaused) return;
    _rssiPaused = false;
    // Only resume if the service is actively connected.
    if (_transport.isConnected && _configurationComplete) {
      _startRssiPolling();
      AppLogging.protocol('🔋 RSSI polling resumed (app foregrounded)');
    }
  }

  /// Drain the FROMRADIO characteristic during the two-phase connect
  /// handshake.
  ///
  /// Mirrors the official iOS app's `startDrainPendingPackets()` pattern
  /// (meshtastic-ios/Meshtastic/Accessory/Accessory Manager/AccessoryManager.swift
  /// lines 210 and 240, and Transports/Bluetooth Low Energy/BLEConnection.swift
  /// lines 130–169). The iOS app explicitly reads FROMRADIO after every
  /// `wantConfigID` write because BLE NOTIFY alone is not reliable on iOS
  /// during the quiet window between phase 1 and phase 2 — the firmware's
  /// phase-2 response can sit in the FROMRADIO characteristic unread until
  /// something forces a read.
  ///
  /// Prior behavior here terminated the poll loop the moment
  /// `_configurationComplete` flipped (i.e. end of phase 1), which left
  /// phase 2 relying on NOTIFY alone and produced a reliable ~180s stall
  /// until the data-health watchdog refreshed the subscription on
  /// T1000-E / Heltec firmware on iOS. The poll loop now continues until
  /// the full handshake reports `complete` (or we hit the poll budget,
  /// whichever first), matching the iOS reference behavior.
  void _pollForConfigurationAsync() {
    if (_pollingConfig) {
      AppLogging.protocol('Config poll already running, skipping');
      return;
    }
    _pollingConfig = true;
    int pollCount = 0;
    // 250 ms × 200 ≈ 50 s total poll budget — covers both handshake phases
    // on busy meshes. The loop also exits early when the handshake reaches
    // `complete` or the transport disconnects.
    const maxPolls = 200;

    Future.doWhile(() async {
      final handshakeDone = _handshakePhase == _HandshakePhase.complete;
      if (handshakeDone || pollCount >= maxPolls) {
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
    _lastDataReceivedAt = null;
    _notificationRefreshRequested = false;
    _transportStateSubscription?.cancel();
    _transportStateSubscription = null;
    if (_configCompleter != null && !_configCompleter!.isCompleted) {
      _configCompleter!.completeError('Service stopped');
    }
    _configCompleter = null;
    if (_queueDrainCompleter != null && !_queueDrainCompleter!.isCompleted) {
      _queueDrainCompleter!.completeError('Service stopped');
    }
    _queueDrainCompleter = null;
    if (_dataSubscription != null) {
      _dataSubscription?.cancel();
      AppLogging.protocol('DATA_SUBSCRIPTION_CANCELLED');
      _dataSubscription = null;
    }
    _framer.clear();
    _configurationComplete = false;
    _handshakePhase = _HandshakePhase.idle;
  }

  /// Handle incoming data from transport
  void _handleData(List<int> data) {
    unawaited(_handleDataAsync(data));
  }

  /// Track consecutive protobuf parse failures for abuse detection.
  int _consecutiveParseFailures = 0;

  /// Total malformed packets received in this session.
  int _totalMalformedPackets = 0;

  /// Max consecutive parse failures before disconnecting.
  static const int _maxConsecutiveParseFailures = 10;

  Future<void> _handleDataAsync(List<int> data) async {
    try {
      _lastDataReceivedAt = DateTime.now();
      _notificationRefreshRequested = false;
      AppLogging.protocol('Received ${data.length} bytes');

      // --- SECURITY AUDIT LOGGING ---
      if (data.length > 512) {
        AppLogging.protocol(
          '⚠️ PROTO SECURITY: Oversized transport data: ${data.length} bytes '
          '(max expected=512)',
        );
      }
      // --- END SECURITY AUDIT LOGGING ---

      if (_transport.requiresFraming) {
        // Serial/USB/TCP: Extract packets using framer
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

  /// Test-only seam: send the initial `wantConfigId` and enter the
  /// `awaitingInitialConfig` phase without running the full `start()`
  /// coroutine (which waits on BLE notifications and a 30-second timeout).
  @visibleForTesting
  Future<void> sendInitialConfigRequestForTest() => _requestConfiguration();

  /// Process a complete packet
  Future<void> _processPacket(List<int> packet) async {
    try {
      AppLogging.protocol('Processing packet: ${packet.length} bytes');

      // --- SECURITY AUDIT LOGGING ---
      AppLogging.protocol(
        'PROTO SECURITY: _processPacket(${packet.length} bytes) '
        'consecutiveFailures=$_consecutiveParseFailures '
        'totalMalformed=$_totalMalformedPackets '
        'first16=${packet.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      // --- END SECURITY AUDIT LOGGING ---

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
      } else if (fromRadio.hasMqttClientProxyMessage()) {
        AppLogging.mqttProxy(
          'Received proxy message from device '
          '(topic: ${fromRadio.mqttClientProxyMessage.topic})',
        );
        _mqttClientProxyMessageController.add(fromRadio.mqttClientProxyMessage);
      } else if (fromRadio.hasClientNotification()) {
        _handleClientNotification(fromRadio.clientNotification);
      } else if (fromRadio.hasConfigCompleteId()) {
        _handleConfigCompleteId(fromRadio.configCompleteId);
      }
    } catch (e, stack) {
      _consecutiveParseFailures++;
      _totalMalformedPackets++;
      AppLogging.protocol(
        '⚠️ PROTO SECURITY: Parse failure #$_totalMalformedPackets '
        '(consecutive=$_consecutiveParseFailures) '
        'packetLen=${packet.length} '
        'error=$e',
      );
      AppLogging.protocol('Error processing packet: $e\n$stack');

      // Disconnect after sustained parse failures (abuse / garbage stream)
      if (_consecutiveParseFailures >= _maxConsecutiveParseFailures) {
        AppLogging.protocol(
          'SECURITY: $_consecutiveParseFailures consecutive parse failures '
          '- disconnecting (possible attack)',
        );
        _consecutiveParseFailures = 0;
        _transport.disconnect();
      }
    }
  }

  /// Dispatch a configCompleteId against the two-phase handshake state
  /// machine.
  ///
  /// Phase-1 (`_nonceInitialConfig`) marks the configuration complete, fires
  /// the completer (so `start()` and the UI unblock), and kicks off the
  /// queue-drain request that triggers the firmware to deliver the rest of
  /// the NodeDB plus any buffered packets.
  ///
  /// Phase-2 (`_nonceQueueDrain`) marks the handshake complete and only
  /// THEN runs `_requestPostConfigData()`. This deferral matters: the burst
  /// of admin/position requests in `_requestPostConfigData` competes with
  /// the firmware's phase-2 NodeDB stream for BLE bandwidth and reliably
  /// stalls the iOS BLE NOTIFY path on T1000-E / Heltec firmware (~180s
  /// silence until the data-health watchdog refreshes notifications). With
  /// the deferral, phase 2 streams cleanly and post-config setup runs
  /// against the full NodeDB rather than just the local node.
  ///
  /// Defensive nonce handling: if the first phase sends back a nonce the
  /// firmware did not echo (older builds, custom forks), we still accept it
  /// while we're in the matching phase — log the discrepancy but proceed.
  /// Same applies to phase 2. Without this we hard-fail on any firmware
  /// that doesn't preserve `wantConfigId` in `configCompleteId`.
  void _handleConfigCompleteId(int nonce) {
    AppLogging.protocol(
      'Handshake: configCompleteId received (nonce: $nonce, '
      'phase: ${_handshakePhase.name})',
    );

    if (_handshakePhase == _HandshakePhase.awaitingInitialConfig) {
      if (nonce != _nonceInitialConfig) {
        AppLogging.protocol(
          'Handshake: phase-1 nonce mismatch (got $nonce, expected '
          '$_nonceInitialConfig) — proceeding defensively (firmware may not '
          'echo wantConfigId)',
        );
      }

      _configurationComplete = true;
      if (_configCompleter != null && !_configCompleter!.isCompleted) {
        _configCompleter!.complete();
      }

      AppLogging.protocol('=== NODE SUMMARY AFTER CONFIG COMPLETE ===');
      AppLogging.protocol('Total nodes: ${_nodes.length}');
      for (final node in _nodes.values) {
        AppLogging.protocol(
          '  Node ${node.nodeNum}: "${node.longName}" hasPosition=${node.hasPosition}, '
          'lat=${node.latitude}, lng=${node.longitude}',
        );
      }
      AppLogging.protocol('==========================================');

      // Phase-1 done — kick off phase 2 and DO NOT run post-config setup
      // yet. Post-config admin chatter is deferred to the phase-2 branch
      // below so it does not contend with the NodeDB stream.
      unawaited(_requestQueueDrain());
      return;
    }

    if (_handshakePhase == _HandshakePhase.awaitingQueueDrain) {
      if (nonce != _nonceQueueDrain) {
        AppLogging.protocol(
          'Handshake: phase-2 nonce mismatch (got $nonce, expected '
          '$_nonceQueueDrain) — proceeding defensively',
        );
      }
      _handshakePhase = _HandshakePhase.complete;
      AppLogging.protocol(
        'Handshake: queue drain complete — phoneQueue replay done',
      );

      // Release the retry loop in _requestQueueDrain.
      if (_queueDrainCompleter != null && !_queueDrainCompleter!.isCompleted) {
        _queueDrainCompleter!.complete();
      }
      _queueDrainCompleter = null;

      // Now safe to run the post-config admin requests. The full NodeDB
      // is in `_nodes` so position/metadata fan-outs operate on the real
      // set rather than just the local node.
      _requestPostConfigData();
      return;
    }

    AppLogging.protocol(
      'Handshake: ignoring unexpected configCompleteId '
      '(nonce: $nonce, phase: ${_handshakePhase.name})',
    );
  }

  /// Request additional configuration data after initial config sync completes.
  /// Uses staggered delays and error handling to prevent crashes if the device
  /// disconnects during the process.
  void _requestPostConfigData() {
    // Sync phone time to device immediately after config complete.
    // This ensures correct rxTime on subsequently received packets,
    // which affects message timestamps, ordering, and dedup windows.
    // The official Meshtastic Android app performs this sync on connect.
    Future.delayed(const Duration(milliseconds: 50), () async {
      if (!_transport.isConnected) return;
      try {
        await syncTime();
        AppLogging.protocol('Time synced to device on connect');
      } catch (e) {
        AppLogging.protocol('Failed to sync time on connect: $e');
      }
    });

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

  /// Emit a [MeshTelemetry] event for mesh health analysis.
  ///
  /// Called for every incoming decoded packet so [MeshHealthAnalyzer] can
  /// compute per-node statistics, channel utilization, and issue detection.
  /// Skips own-node packets — they arrive via BLE (no RF metrics) and would
  /// create false spam/signal-degradation detections.
  void _emitPacketTelemetry(pb.MeshPacket packet) {
    if (!_meshTelemetryController.hasListener) return;

    // Skip packets from our own device — they are BLE-delivered local data,
    // not mesh RF traffic. They lack RSSI/SNR and arrive in rapid bursts
    // (device metrics, local stats, position, nodeinfo) which the analyzer
    // would misclassify as interval spam.
    if (_myNodeNum != null && packet.from == _myNodeNum) return;

    final nodeId = packet.from.toRadixString(16).padLeft(8, '0');
    final isKnown = _nodes.containsKey(packet.from);
    final payloadBytes = packet.hasDecoded()
        ? packet.decoded.payload.length
        : 0;
    final rssi = packet.hasRxRssi() ? packet.rxRssi : -120;
    final snr = packet.hasRxSnr() ? packet.rxSnr.toDouble() : 0.0;

    // Compute hop count from hopStart - hopLimit (both available in proto)
    int hopCount = 0;
    int maxHopCount = 3;
    if (packet.hasHopStart() && packet.hopStart > 0) {
      maxHopCount = packet.hopStart;
      hopCount = packet.hopStart - packet.hopLimit;
      if (hopCount < 0) hopCount = 0;
    } else if (packet.hasHopLimit()) {
      maxHopCount = packet.hopLimit;
    }

    // Reliability from node's cumulative packet stats (if available)
    double reliability = 1.0;
    final node = _nodes[packet.from];
    if (node != null && node.numPacketsRx != null && node.numPacketsRx! > 0) {
      final bad = node.numPacketsRxBad ?? 0;
      reliability = 1.0 - (bad / node.numPacketsRx!);
    }

    // Estimate airtime from payload size (LoRa SF11/125kHz approximation)
    // ~2ms per byte + ~50ms preamble/header overhead
    final airtimeMs = (payloadBytes * 2) + 50;

    _meshTelemetryController.add(
      MeshTelemetry(
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        nodeId: nodeId,
        isKnownNode: isKnown,
        hopCount: hopCount,
        maxHopCount: maxHopCount,
        payloadBytes: payloadBytes,
        rssi: rssi,
        snr: snr,
        txIntervalSec: 900,
        reliability: reliability,
        airtimeMs: airtimeMs,
      ),
    );
  }

  /// Handle incoming mesh packet
  Future<void> _handleMeshPacket(pb.MeshPacket packet) async {
    AppLogging.protocol(
      'Handling mesh packet from ${packet.from} to ${packet.to}',
    );

    // Diagnostic: trace unicast packets through the receive pipeline.
    // This fires for any packet where `to` is not broadcast.  Tagged
    // protocol (not fileTransfer) because it covers ALL portnums —
    // routing, admin, text, etc. — not just file-transfer traffic.
    final isBroadcast = packet.to == 0xFFFFFFFF || packet.to == 0;
    if (!isBroadcast) {
      AppLogging.protocol(
        'RX_PIPELINE: unicast from=${packet.from.toRadixString(16)} '
        'to=${packet.to.toRadixString(16)} id=${packet.id} '
        'hasDecoded=${packet.hasDecoded()} '
        'portnum=${packet.hasDecoded() ? packet.decoded.portnum.name : 'N/A'} '
        'payloadLen=${packet.hasDecoded() ? packet.decoded.payload.length : 0}',
      );
    }

    // Emit per-packet telemetry for mesh health analysis
    _emitPacketTelemetry(packet);

    // Update lastHeard (and RF metadata) for the sender node.
    // rxRssi/rxSnr are per-packet RF metrics that tell us how strong
    // the sender's signal was when our radio received it. Propagating
    // them to MeshNode keeps the per-node signal data fresh for the UI
    // (node cards, node detail, nearby nodes, AR, 3D mesh, NodeDex).
    // hopCount and viaMqtt are also refreshed so the "hops away" and
    // MQTT badge stay current as mesh topology changes.
    _updateNodeLastHeard(
      packet.from,
      rxRssi: packet.hasRxRssi() ? packet.rxRssi : null,
      rxSnr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
      hopCount: _computeHopCount(packet),
      viaMqtt: packet.hasViaMqtt() ? packet.viaMqtt : null,
    );

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
        AppLogging.messages(
          '📨 TEXT_MESSAGE_APP received: packetId=${packet.id}, '
          'from=${packet.from.toRadixString(16)}, '
          'to=${packet.to.toRadixString(16)}, '
          'channel=${packet.channel}, '
          'payloadLen=${data.payload.length}',
        );

        final key = MeshPacketKey(
          packetType: 'channel_message',
          senderNodeId: packet.from,
          packetId: packet.id,
          channelIndex: packet.channel,
        );

        final seen = await _dedupeStore.hasSeen(key, ttl: _messagePacketTtl);
        if (seen) {
          AppLogging.messages(
            '📨 Packet-level dedup BLOCKED: packetId=${packet.id}, '
            'from=${packet.from.toRadixString(16)}, channel=${packet.channel}',
          );
          return;
        }

        AppLogging.messages(
          '📨 Packet-level dedup PASSED: packetId=${packet.id}, '
          'from=${packet.from.toRadixString(16)}',
        );
        await _dedupeStore.markSeen(key, ttl: _messagePacketTtl);
      }

      // Extract the raw portnum int.  Protobuf 6.0.0 maps unknown
      // enum values (SM portnums 260-262) to UNKNOWN_APP (0) in the
      // getter, but preserves the raw int in unknownFields.
      final rawPortnum = _extractRawPortnum(data);

      // Fast path: SM binary portnums bypass the enum-based switch.
      if (SmCodec.isSocialmeshPortnum(rawPortnum)) {
        // Diagnostic: log every SM packet with fileTransfer tag so it
        // appears when filtering by FILE_TRANSFER_ENABLED logging.
        if (rawPortnum == SmPortnum.fileTransfer) {
          AppLogging.fileTransfer(
            'RX SM portnum=$rawPortnum from='
            '${packet.from.toRadixString(16)} '
            'to=${packet.to.toRadixString(16)} '
            'payload=${data.payload.length} bytes',
          );
        }
        _handleSmPacket(packet, data);
      } else {
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
            // Diagnostic: log all incoming PRIVATE_APP packets so we
            // can verify file-transfer packets are reaching this device.
            AppLogging.fileTransfer(
              'RX PRIVATE_APP from=${packet.from.toRadixString(16)} '
              'to=${packet.to.toRadixString(16)} '
              '${data.payload.length} bytes, '
              'firstByte=${data.payload.isNotEmpty ? '0x${data.payload[0].toRadixString(16).padLeft(2, '0')}' : 'empty'}',
            );
            // Multiplex PRIVATE_APP (256) by inspecting payload magic bytes.
            // Order: SIP (2-byte magic), STL-wrapped file-transfer,
            // file-transfer (kind nibble), fallback to signals (legacy JSON).
            final privatePayload = Uint8List.fromList(data.payload);
            if (SipCodec.isSipPayload(privatePayload)) {
              _logIncomingMrrpCandidatePacket(packet, privatePayload);
              _handleSipPacket(packet, privatePayload);
            } else if (StlEnvelope.isStlWrapped(privatePayload)) {
              unawaited(
                _handleFileTransferOnPrivateApp(packet, privatePayload),
              );
            } else if (SmCodec.isFileTransferPayload(privatePayload)) {
              unawaited(
                _handleFileTransferOnPrivateApp(packet, privatePayload),
              );
            } else {
              _handleSignalMessage(packet, data);
            }
            break;
          case pn.PortNum.DETECTION_SENSOR_APP:
            _handleDetectionSensorMessage(packet, data);
            break;
          case pn.PortNum.NODE_STATUS_APP:
            _handleNodeStatusMessage(packet, data);
            break;
          case pn.PortNum.TRACEROUTE_APP:
            _handleTracerouteMessage(packet, data);
            break;
          default:
            AppLogging.protocol(
              'Received message with portnum: ${data.portnum} '
              '(${data.portnum.value}, raw=$rawPortnum)',
            );
        }
      }
    }
  }

  /// Handle inbound traceroute response (TRACEROUTE_APP portnum).
  ///
  /// The response arrives from the target node with a RouteDiscovery payload
  /// containing forward/back route lists and per-hop SNR values (scaled x4).
  void _handleTracerouteMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      if (data.payload.isEmpty) {
        AppLogging.protocol(
          'Traceroute response from ${packet.from.toRadixString(16)} has empty payload, ignoring',
        );
        return;
      }

      final routeDiscovery = pb.RouteDiscovery.fromBuffer(data.payload);

      final targetNode = packet.from;

      // Build forward-path hops (route towards destination)
      // Snapshot each hop's GPS position from the current node table so the
      // route can be rendered on the map even if nodes move later.
      final forwardRoute = routeDiscovery.route.toList();
      final forwardSnr = routeDiscovery.snrTowards.toList();
      final forwardHops = <TraceRouteHop>[];
      for (var i = 0; i < forwardRoute.length; i++) {
        final snrRaw = i < forwardSnr.length ? forwardSnr[i] : null;
        final node = _nodes[forwardRoute[i]];
        forwardHops.add(
          TraceRouteHop(
            nodeNum: forwardRoute[i],
            snr: snrRaw != null ? snrRaw / 4.0 : null,
            latitude: node != null && node.hasPosition ? node.latitude : null,
            longitude: node != null && node.hasPosition ? node.longitude : null,
          ),
        );
      }

      // Build back-path hops (route back from destination)
      final backRoute = routeDiscovery.routeBack.toList();
      final backSnr = routeDiscovery.snrBack.toList();
      final backHops = <TraceRouteHop>[];
      for (var i = 0; i < backRoute.length; i++) {
        final snrRaw = i < backSnr.length ? backSnr[i] : null;
        final node = _nodes[backRoute[i]];
        backHops.add(
          TraceRouteHop(
            nodeNum: backRoute[i],
            snr: snrRaw != null ? snrRaw / 4.0 : null,
            back: true,
            latitude: node != null && node.hasPosition ? node.latitude : null,
            longitude: node != null && node.hasPosition ? node.longitude : null,
          ),
        );
      }

      // Aggregate SNR from the received packet (already in dB)
      final rxSnr = packet.hasRxSnr() ? packet.rxSnr.toDouble() : null;

      // Transport flag: true if this packet arrived via MQTT gateway
      final mqtt = packet.hasViaMqtt() ? packet.viaMqtt : null;

      // Snapshot origin (local device) position
      double? originLat, originLon;
      if (_myNodeNum != null) {
        final myNode = _nodes[_myNodeNum];
        if (myNode != null && myNode.hasPosition) {
          originLat = myNode.latitude;
          originLon = myNode.longitude;
        }
      }

      // Snapshot target node position
      double? targetLat, targetLon;
      final targetNodeObj = _nodes[targetNode];
      if (targetNodeObj != null && targetNodeObj.hasPosition) {
        targetLat = targetNodeObj.latitude;
        targetLon = targetNodeObj.longitude;
      }

      final log = TraceRouteLog(
        nodeNum: targetNode,
        targetNode: targetNode,
        sent: true,
        response: true,
        hopsTowards: forwardRoute.length,
        hopsBack: backRoute.length,
        hops: [...forwardHops, ...backHops],
        snr: rxSnr,
        viaMqtt: mqtt,
        originLatitude: originLat,
        originLongitude: originLon,
        targetLatitude: targetLat,
        targetLongitude: targetLon,
      );

      AppLogging.protocol(
        'Traceroute response from ${targetNode.toRadixString(16)}: '
        '${forwardRoute.length} hops towards, ${backRoute.length} hops back',
      );

      _traceRouteLogController.add(log);
    } catch (e) {
      AppLogging.protocol('Failed to parse traceroute response: $e');
    }
  }

  /// Handle incoming signal packets (PRIVATE_APP portnum)
  void _handleSignalMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      AppLogging.social(
        'RX_SIGNAL_RAW packetId=${packet.id} from=${packet.from.toRadixString(16)} '
        'to=${packet.to.toRadixString(16)} bytes=${data.payload.length}',
      );

      // Ignore our own signals echoed back
      if (packet.from == _myNodeNum) {
        AppLogging.social('Ignoring own signal echo');
        return;
      }

      // Calculate hop count from mesh packet metadata
      final int? hopCount = _computeHopCount(packet);

      final signalPacket = MeshSignalPacket.fromPayload(
        packet.from,
        data.payload,
        hopCount: hopCount,
        packetId: packet.id,
      );

      AppLogging.social(
        'SIGNAL_PARSE_OK packetId=${signalPacket.packetId} '
        'signalId=${signalPacket.signalId ?? "none"} '
        'sender=${packet.from.toRadixString(16)} ttl=${signalPacket.ttlMinutes}',
      );

      AppLogging.social(
        'Received mesh signal from !${packet.from.toRadixString(16)}: '
        '"${signalPacket.content.length > 30 ? '${signalPacket.content.substring(0, 30)}...' : signalPacket.content}" '
        '(ttl=${signalPacket.ttlMinutes}m)',
      );

      _smMetrics.recordLegacyPacketReceived();
      _signalController.add(signalPacket);
    } catch (e) {
      AppLogging.social('Failed to parse signal packet: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // File transfers received on PRIVATE_APP (256)
  // ─────────────────────────────────────────────────────────────────

  /// Handle a binary file-transfer payload that arrived on PRIVATE_APP (256).
  ///
  /// File transfers are sent on PRIVATE_APP because custom SM portnums
  /// (260-263) are not reliably relayed by all firmware versions when
  /// [SmFeatureFlag.shouldSendBinary] is off. The payload is decoded the
  /// same way as portnum 263 — only the transport portnum differs.
  Future<void> _handleFileTransferOnPrivateApp(
    pb.MeshPacket packet,
    Uint8List payload,
  ) async {
    // Ignore our own packets echoed back
    if (packet.from == _myNodeNum) return;

    // CRITICAL: This method is called via unawaited() from _handleMeshPacket,
    // so any uncaught exception here escapes ALL try-catch blocks in the
    // packet processing pipeline and surfaces as a PlatformDispatcher error.
    // The top-level try-catch prevents that.
    try {
      AppLogging.fileTransfer(
        'RX file-transfer on PRIVATE_APP from='
        '${packet.from.toRadixString(16)} '
        'to=${packet.to.toRadixString(16)} '
        '${payload.length} bytes',
      );

      // STL: verify signature via fail-closed API, then strip envelope.
      // Invalid or malformed STL packets are dropped — no fallback.
      var innerPayload = payload;
      if (StlEnvelope.isStlWrapped(payload)) {
        final verified = await _stlMiddleware.verifyAndUnwrap(payload);
        if (verified == null) {
          AppLogging.stl(
            'STL verification failed, dropping packet from '
            '${packet.from.toRadixString(16)}',
          );
          return;
        }
        innerPayload = verified.payload;
      }

      final decoded = SmCodec.decodeFileTransfer(innerPayload);
      if (decoded == null) {
        AppLogging.fileTransfer(
          'Failed to decode file-transfer payload from '
          '${packet.from.toRadixString(16)}',
        );
        return;
      }

      switch (decoded.type) {
        case SmPacketType.fileOffer:
          _handleSmFileOffer(
            decoded.fileOffer,
            packet.from,
            version: decoded.version,
          );
        case SmPacketType.fileChunk:
          _handleSmFileChunk(decoded.fileChunk, packet.from);
        case SmPacketType.fileNack:
          _handleSmFileNack(decoded.fileNack, packet.from);
        case SmPacketType.fileAck:
          _handleSmFileAck(decoded.fileAck, packet.from);
        case SmPacketType.sppAccept:
          _handleSppAccept(decoded.sppAccept, packet.from);
        case SmPacketType.sppDecline:
          _handleSppDecline(decoded.sppDecline, packet.from);
        case SmPacketType.sppAbort:
          _handleSppAbort(decoded.sppAbort, packet.from);
        case SmPacketType.presence:
        case SmPacketType.signal:
        case SmPacketType.identity:
        case SmPacketType.feedPost:
          break;
      }
    } catch (e, stack) {
      AppLogging.fileTransfer(
        '⚠️ Error handling file-transfer packet from '
        '${packet.from.toRadixString(16)}: $e\n$stack',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Socialmesh binary protocol handlers (portnums 260/261/262)
  // ─────────────────────────────────────────────────────────────────

  /// Handle inbound Socialmesh binary packet.
  ///
  /// Decodes via [SmCodec], marks sender as binary-capable, and routes
  /// the decoded payload into the existing domain pipelines.
  void _handleSmPacket(pb.MeshPacket packet, pb.Data data) {
    // Ignore our own packets echoed back
    if (packet.from == _myNodeNum) return;

    // Top-level try-catch: _handleSmPacket is called synchronously from
    // _handleMeshPacket (inside _processPacket's try-catch), but if any
    // handler below throws, the error could escape as an uncaught platform
    // error depending on async scheduling. Belt-and-suspenders protection.
    try {
      _smMetrics.recordBinaryPacketReceived();

      final portnum = _extractRawPortnum(data);
      final payload = Uint8List.fromList(data.payload);
      final decoded = SmCodec.decode(portnum, payload);

      if (decoded == null) {
        _smMetrics.recordDecodeNull(portnum);
        AppLogging.protocol(
          'SM: decode returned null for portnum=$portnum, '
          '${payload.length} bytes from ${packet.from.toRadixString(16)}',
        );
        return;
      }

      // Mark sender as binary-capable
      _smCapabilityStore.markNodeSupported(packet.from);

      switch (decoded.type) {
        case SmPacketType.presence:
          _handleSmPresence(decoded.presence, packet.from);
        case SmPacketType.signal:
          _handleSmSignal(decoded.signal, packet.from, packet.id);
        case SmPacketType.identity:
          _handleSmIdentity(decoded.identity, packet.from);
        case SmPacketType.fileOffer:
          _handleSmFileOffer(
            decoded.fileOffer,
            packet.from,
            version: decoded.version,
          );
        case SmPacketType.fileChunk:
          _handleSmFileChunk(decoded.fileChunk, packet.from);
        case SmPacketType.fileNack:
          _handleSmFileNack(decoded.fileNack, packet.from);
        case SmPacketType.fileAck:
          _handleSmFileAck(decoded.fileAck, packet.from);
        case SmPacketType.sppAccept:
          _handleSppAccept(decoded.sppAccept, packet.from);
        case SmPacketType.sppDecline:
          _handleSppDecline(decoded.sppDecline, packet.from);
        case SmPacketType.sppAbort:
          _handleSppAbort(decoded.sppAbort, packet.from);
        case SmPacketType.feedPost:
          _handleSmFeedPost(decoded.feedPostPayload, packet.from, packet);
      }
    } catch (e, stack) {
      AppLogging.protocol(
        '⚠️ Error handling SM packet from '
        '${packet.from.toRadixString(16)}: $e\n$stack',
      );
    }
  }

  /// Handle decoded SM_PRESENCE: update extended presence info.
  void _handleSmPresence(SmPresence presence, int senderNodeNum) {
    AppLogging.protocol(
      'SM_PRESENCE from ${senderNodeNum.toRadixString(16)}: $presence',
    );

    // Map SmPresenceIntent -> PresenceIntent (1:1 by index value)
    final intent = PresenceIntent.fromValue(presence.intent.index);

    final extendedInfo = ExtendedPresenceInfo(
      intent: intent,
      shortStatus: presence.status,
    );

    // Notify via the onSmPresenceUpdate callback if set.
    // This allows providers to feed it into ExtendedPresenceService.
    onSmPresenceUpdate?.call(
      nodeNum: senderNodeNum,
      info: extendedInfo,
      battery: presence.battery,
      latitudeI: presence.latitudeI,
      longitudeI: presence.longitudeI,
    );
  }

  /// Handle decoded SM_SIGNAL: convert to MeshSignalPacket and emit
  /// on the existing signal stream.
  void _handleSmSignal(SmSignal signal, int senderNodeNum, int packetId) {
    final signalIdStr = SmPacketRouter.signalIdToString(signal.signalId);
    final ttlMinutes = SmPacketRouter.ttlToMinutes(signal.ttl);

    final meshPacket = MeshSignalPacket(
      senderNodeId: senderNodeNum,
      packetId: packetId,
      signalId: signalIdStr,
      content: signal.content,
      ttlMinutes: ttlMinutes,
      latitude: signal.latitude,
      longitude: signal.longitude,
      receivedAt: DateTime.now(),
      hasImage: signal.hasImage,
      // No presenceInfo in binary signals — presence is a separate packet.
    );

    AppLogging.social(
      'SM_SIGNAL mapped: signalId=$signalIdStr '
      'from=${senderNodeNum.toRadixString(16)} '
      'ttl=${ttlMinutes}m content=${signal.content.length} chars',
    );

    _signalController.add(meshPacket);
  }

  /// Handle decoded SM_IDENTITY: request/response routing.
  void _handleSmIdentity(SmIdentity identity, int senderNodeNum) {
    if (identity.isRequest) {
      AppLogging.protocol(
        'SM_IDENTITY request from ${senderNodeNum.toRadixString(16)}',
      );
      // Auto-respond if rate limit allows
      if (_smIdentityRateLimiter.canRequest(senderNodeNum)) {
        _smIdentityRateLimiter.recordRequest(senderNodeNum);
        _sendSmIdentityResponse(senderNodeNum);
      } else {
        AppLogging.protocol(
          'SM_IDENTITY request rate-limited for '
          '${senderNodeNum.toRadixString(16)}',
        );
      }
    } else {
      // Response or unsolicited broadcast
      AppLogging.protocol(
        'SM_IDENTITY ${identity.isResponse ? "response" : "broadcast"} '
        'from ${senderNodeNum.toRadixString(16)}: $identity',
      );

      // Verify sigil hash against sender's node number
      final hashValid = SmIdentity.verifySigilHash(
        identity.sigilHash,
        senderNodeNum,
      );

      onSmIdentityUpdate?.call(
        nodeNum: senderNodeNum,
        identity: identity,
        hashValid: hashValid,
      );
    }
  }

  /// Callback for SM_PRESENCE updates. Set by providers to feed into
  /// ExtendedPresenceService without importing it here.
  void Function({
    required int nodeNum,
    required ExtendedPresenceInfo info,
    int? battery,
    int? latitudeI,
    int? longitudeI,
  })?
  onSmPresenceUpdate;

  /// Callback for SM_IDENTITY updates (response / unsolicited).
  void Function({
    required int nodeNum,
    required SmIdentity identity,
    required bool hashValid,
  })?
  onSmIdentityUpdate;

  /// Callback for SM_FEED_POST receive. Set by providers to ingest
  /// feed posts into MeshFeedRepository without importing it here.
  void Function({
    required int authorNodeNum,
    required Uint8List payload,
    int? hopCount,
  })?
  onFeedPostReceived;

  /// Handle incoming SM_FEED_POST.
  void _handleSmFeedPost(
    Uint8List payload,
    int senderNodeNum,
    pb.MeshPacket packet,
  ) {
    AppLogging.meshFeed(
      'SM_FEED_POST from ${senderNodeNum.toRadixString(16)}: '
      '${payload.length} bytes',
    );

    final hopCount = packet.hopStart > 0 && packet.hopLimit >= 0
        ? packet.hopStart - packet.hopLimit
        : null;

    onFeedPostReceived?.call(
      authorNodeNum: senderNodeNum,
      payload: payload,
      hopCount: hopCount,
    );
  }

  /// Handle incoming FILE_OFFER.
  void _handleSmFileOffer(
    SmFileOffer offer,
    int senderNodeNum, {
    int version = 0,
  }) {
    AppLogging.protocol(
      'SM_FILE_OFFER from ${senderNodeNum.toRadixString(16)}: '
      'file=${offer.filename}, ${offer.totalBytes} bytes, '
      '${offer.chunkCount} chunks, v=$version',
    );
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.fileOffer,
        packet: offer,
        senderNodeNum: senderNodeNum,
        version: version,
      ),
    );
  }

  /// Handle incoming FILE_CHUNK.
  void _handleSmFileChunk(SmFileChunk chunk, int senderNodeNum) {
    AppLogging.protocol(
      'SM_FILE_CHUNK from ${senderNodeNum.toRadixString(16)}: '
      'idx=${chunk.chunkIndex}/${chunk.chunkCount}, '
      '${chunk.payload.length} bytes',
    );
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.fileChunk,
        packet: chunk,
        senderNodeNum: senderNodeNum,
      ),
    );
  }

  /// Handle incoming FILE_NACK.
  void _handleSmFileNack(SmFileNack nack, int senderNodeNum) {
    AppLogging.protocol(
      'SM_FILE_NACK from ${senderNodeNum.toRadixString(16)}: '
      '${nack.missingIndexes.length} missing chunks',
    );
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.fileNack,
        packet: nack,
        senderNodeNum: senderNodeNum,
      ),
    );
  }

  /// Handle incoming FILE_ACK.
  void _handleSmFileAck(SmFileAck ack, int senderNodeNum) {
    AppLogging.protocol(
      'SM_FILE_ACK from ${senderNodeNum.toRadixString(16)}: '
      'status=${ack.status.name}',
    );
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.fileAck,
        packet: ack,
        senderNodeNum: senderNodeNum,
      ),
    );
  }

  /// Handle incoming SPP_ACCEPT.
  void _handleSppAccept(Object accept, int senderNodeNum) {
    AppLogging.spp('SPP_ACCEPT from ${senderNodeNum.toRadixString(16)}');
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.sppAccept,
        packet: accept,
        senderNodeNum: senderNodeNum,
      ),
    );
  }

  /// Handle incoming SPP_DECLINE.
  void _handleSppDecline(Object decline, int senderNodeNum) {
    AppLogging.spp('SPP_DECLINE from ${senderNodeNum.toRadixString(16)}');
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.sppDecline,
        packet: decline,
        senderNodeNum: senderNodeNum,
      ),
    );
  }

  /// Handle incoming SPP_ABORT.
  void _handleSppAbort(Object abort, int senderNodeNum) {
    AppLogging.spp('SPP_ABORT from ${senderNodeNum.toRadixString(16)}');
    _fileTransferController.add(
      SmFileTransferEvent(
        type: SmPacketType.sppAbort,
        packet: abort,
        senderNodeNum: senderNodeNum,
      ),
    );
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
      final status = statusMsg.hasStatus()
          ? sanitizeExternalText(statusMsg.status)
          : null;

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

      // Only cache config responses from the local node. Remote admin
      // responses are emitted to streams for the requesting screen but must
      // not overwrite the local device's cached config.
      final isLocalResponse = _myNodeNum != null && packet.from == _myNodeNum;

      // Extract and store session passkey from remote admin responses.
      // The firmware includes a session passkey in admin responses when PKC
      // is enabled. Store it for subsequent SET/ACTION operations.
      if (!isLocalResponse && adminMsg.hasSessionPasskey()) {
        _storeSessionPasskey(packet.from, adminMsg.sessionPasskey);
      }

      if (adminMsg.hasGetConfigResponse()) {
        final config = adminMsg.getConfigResponse;

        // Handle LoRa config
        if (config.hasLora()) {
          final loraConfig = config.lora;
          AppLogging.protocol(
            'Received LoRa config - region: ${loraConfig.region.name}',
          );
          if (isLocalResponse) {
            _currentRegion = loraConfig.region;
            _currentLoraConfig = loraConfig;
          }
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
          if (isLocalResponse) {
            _currentPositionConfig = posConfig;
          }
          _positionConfigController.add(posConfig);
        }

        // Handle Device config
        if (config.hasDevice()) {
          final deviceConfig = config.device;
          AppLogging.protocol(
            'Received Device config - role: ${deviceConfig.role.name}',
          );
          if (isLocalResponse) {
            _currentDeviceConfig = deviceConfig;
          }
          _deviceConfigController.add(deviceConfig);
        }

        // Handle Display config
        if (config.hasDisplay()) {
          final displayConfig = config.display;
          AppLogging.protocol(
            'Received Display config - screenOnSecs: ${displayConfig.screenOnSecs}',
          );
          if (isLocalResponse) {
            _currentDisplayConfig = displayConfig;
          }
          _displayConfigController.add(displayConfig);
        }

        // Handle Power config
        if (config.hasPower()) {
          final powerConfig = config.power;
          AppLogging.protocol(
            'Received Power config - isPowerSaving: ${powerConfig.isPowerSaving}',
          );
          if (isLocalResponse) {
            _currentPowerConfig = powerConfig;
          }
          _powerConfigController.add(powerConfig);
        }

        // Handle Network config
        if (config.hasNetwork()) {
          final networkConfig = config.network;
          AppLogging.protocol(
            'Received Network config - wifiEnabled: ${networkConfig.wifiEnabled}',
          );
          if (isLocalResponse) {
            _currentNetworkConfig = networkConfig;
          }
          _networkConfigController.add(networkConfig);
        }

        // Handle Bluetooth config
        if (config.hasBluetooth()) {
          final btConfig = config.bluetooth;
          AppLogging.protocol(
            'Received Bluetooth config - enabled: ${btConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentBluetoothConfig = btConfig;
          }
          _bluetoothConfigController.add(btConfig);
        }

        // Handle Security config
        if (config.hasSecurity()) {
          final secConfig = config.security;
          AppLogging.protocol(
            'Received Security config - isManaged: ${secConfig.isManaged}',
          );
          if (isLocalResponse) {
            _currentSecurityConfig = secConfig;
          }
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
          if (isLocalResponse) {
            _currentMqttConfig = mqttConfig;
          }
          _mqttConfigController.add(mqttConfig);
        }

        // Handle Telemetry config
        if (moduleConfig.hasTelemetry()) {
          final telemetryConfig = moduleConfig.telemetry;
          AppLogging.protocol(
            'Received Telemetry config - deviceInterval: ${telemetryConfig.deviceUpdateInterval}',
          );
          if (isLocalResponse) {
            _currentTelemetryConfig = telemetryConfig;
          }
          _telemetryConfigController.add(telemetryConfig);
        }

        // Handle PAX counter config
        if (moduleConfig.hasPaxcounter()) {
          final paxConfig = moduleConfig.paxcounter;
          AppLogging.protocol(
            'Received PAX counter config - enabled: ${paxConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentPaxCounterConfig = paxConfig;
          }
          _paxCounterConfigController.add(paxConfig);
        }

        // Handle Ambient Lighting config
        if (moduleConfig.hasAmbientLighting()) {
          final ambientConfig = moduleConfig.ambientLighting;
          AppLogging.protocol(
            'Received Ambient Lighting config - ledState: ${ambientConfig.ledState}',
          );
          if (isLocalResponse) {
            _currentAmbientLightingConfig = ambientConfig;
          }
          _ambientLightingConfigController.add(ambientConfig);
        }

        // Handle Serial config
        if (moduleConfig.hasSerial()) {
          final serialConfig = moduleConfig.serial;
          AppLogging.protocol(
            'Received Serial config - enabled: ${serialConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentSerialConfig = serialConfig;
          }
          _serialConfigController.add(serialConfig);
        }

        // Handle Store Forward config
        if (moduleConfig.hasStoreForward()) {
          final sfConfig = moduleConfig.storeForward;
          AppLogging.protocol(
            'Received Store Forward config - enabled: ${sfConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentStoreForwardConfig = sfConfig;
          }
          _storeForwardConfigController.add(sfConfig);
        }

        // Handle Detection Sensor config
        if (moduleConfig.hasDetectionSensor()) {
          final dsConfig = moduleConfig.detectionSensor;
          AppLogging.protocol(
            'Received Detection Sensor config - enabled: ${dsConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentDetectionSensorConfig = dsConfig;
          }
          _detectionSensorConfigController.add(dsConfig);
        }

        // Handle Range Test config
        if (moduleConfig.hasRangeTest()) {
          final rtConfig = moduleConfig.rangeTest;
          AppLogging.protocol(
            'Received Range Test config - enabled: ${rtConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentRangeTestConfig = rtConfig;
          }
          _rangeTestConfigController.add(rtConfig);
        }

        // Handle External Notification config
        if (moduleConfig.hasExternalNotification()) {
          final extNotifConfig = moduleConfig.externalNotification;
          AppLogging.protocol(
            'Received External Notification config - enabled: ${extNotifConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentExternalNotificationConfig = extNotifConfig;
          }
          _externalNotificationConfigController.add(extNotifConfig);
        }

        // Handle Canned Message config
        if (moduleConfig.hasCannedMessage()) {
          final cannedConfig = moduleConfig.cannedMessage;
          AppLogging.protocol(
            'Received Canned Message config - enabled: ${cannedConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentCannedMessageConfig = cannedConfig;
          }
          _cannedMessageConfigController.add(cannedConfig);
        }

        // Handle Traffic Management config (v2.7.19)
        if (moduleConfig.hasTrafficManagement()) {
          final tmConfig = moduleConfig.trafficManagement;
          AppLogging.protocol(
            'Received Traffic Management config - enabled: ${tmConfig.enabled}',
          );
          if (isLocalResponse) {
            _currentTrafficManagementConfig = tmConfig;
          }
          _trafficManagementConfigController.add(tmConfig);
        }
      } else if (adminMsg.hasGetChannelResponse()) {
        // Handle channel response - update local channel list
        final channel = adminMsg.getChannelResponse;
        AppLogging.protocol(
          'Received channel response: index=${channel.index}, role=${channel.role.name}',
        );
        _handleChannel(channel);
      } else if (adminMsg.hasGetCannedMessageModuleMessagesResponse()) {
        // Handle canned messages text response (pipe-separated string)
        final messages = adminMsg.getCannedMessageModuleMessagesResponse;
        AppLogging.protocol(
          'Received canned messages text (${messages.length} chars)',
        );
        _cannedMessageTextController.add(sanitizeExternalText(messages));
      } else if (adminMsg.hasGetRingtoneResponse()) {
        // Handle ringtone text response (RTTTL format)
        final ringtone = adminMsg.getRingtoneResponse;
        AppLogging.protocol(
          'Received ringtone text (${ringtone.length} chars)',
        );
        _ringtoneTextController.add(sanitizeExternalText(ringtone));
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

        // Only update local node — remote metadata responses must not
        // overwrite the local device's cached firmware version or hardware
        // model.
        if (isLocalResponse &&
            _myNodeNum != null &&
            _nodes.containsKey(_myNodeNum)) {
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
                ? sanitizeExternalText(metadata.firmwareVersion)
                : null,
            hasWifi: metadata.hasWifi,
            hasBluetooth: metadata.hasBluetooth,
            hardwareModel: hwModelName ?? existingNode.hardwareModel,
            hwModelId: metadata.hwModel != pb.HardwareModel.UNSET
                ? metadata.hwModel.value
                : existingNode.hwModelId,
          );
          _nodes[_myNodeNum!] = updatedNode;
          _nodeController.add(updatedNode);
          AppLogging.protocol('Updated node $_myNodeNum with device metadata');
        } else if (!isLocalResponse && _nodes.containsKey(packet.from)) {
          // Remote metadata response — update the remote node's metadata
          // without polluting the local device's cache. This mirrors the
          // iOS app's pattern of storing metadata per-node.
          final remoteNode = _nodes[packet.from]!;

          String? hwModelName;
          if (metadata.hwModel != pb.HardwareModel.UNSET) {
            hwModelName = _formatHardwareModel(metadata.hwModel);
          }

          final updatedRemote = remoteNode.copyWith(
            firmwareVersion: metadata.firmwareVersion.isNotEmpty
                ? sanitizeExternalText(metadata.firmwareVersion)
                : null,
            hasWifi: metadata.hasWifi,
            hasBluetooth: metadata.hasBluetooth,
            hardwareModel: hwModelName ?? remoteNode.hardwareModel,
            hwModelId: metadata.hwModel != pb.HardwareModel.UNSET
                ? metadata.hwModel.value
                : remoteNode.hwModelId,
          );
          _nodes[packet.from] = updatedRemote;
          _nodeController.add(updatedRemote);
          AppLogging.protocol(
            'Updated remote node ${packet.from.toRadixString(16)} with device metadata',
          );
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
                ? sanitizeExternalText(user.longName)
                : existingNode.longName,
            shortName: user.shortName.isNotEmpty
                ? sanitizeExternalText(user.shortName)
                : existingNode.shortName,
            userId: user.hasId() ? user.id : existingNode.userId,
            hardwareModel: hwModel ?? existingNode.hardwareModel,
            hwModelId:
                user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET
                ? user.hwModel.value
                : existingNode.hwModelId,
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
                ? sanitizeExternalText(user.longName)
                : null,
            shortName: user.shortName.isNotEmpty
                ? sanitizeExternalText(user.shortName)
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
      AppLogging.protocol(
        'FromRadio Device config: role=${deviceConfig.role.name} (value=${deviceConfig.role.value})',
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
    final message = sanitizeExternalText(notification.message);

    // Log with appropriate level
    if (notification.level == pb.LogRecord_Level.ERROR ||
        notification.level == pb.LogRecord_Level.CRITICAL) {
      AppLogging.protocol('⚠️ Client Notification [ERROR]: $message');
    } else if (notification.level == pb.LogRecord_Level.WARNING) {
      AppLogging.protocol('⚠️ Client Notification [WARNING]: $message');
    } else {
      AppLogging.protocol('ℹ️ Client Notification [$levelName]: $message');
    }

    // Sanitize the protobuf message before emitting so the UI never
    // receives malformed UTF-16 that could crash text rendering.
    if (notification.message != message) {
      notification.message = message;
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
            ? sanitizeExternalText(metadata.firmwareVersion)
            : null,
        hasWifi: metadata.hasWifi,
        hasBluetooth: metadata.hasBluetooth,
        hardwareModel: hwModelName ?? existingNode.hardwareModel,
        hwModelId: metadata.hwModel != pb.HardwareModel.UNSET
            ? metadata.hwModel.value
            : existingNode.hwModelId,
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

  /// Compute hop count from hopStart and hopLimit fields in a MeshPacket.
  /// Returns null if hop info is unavailable.
  int? _computeHopCount(pb.MeshPacket packet) {
    if (packet.hasHopStart() && packet.hopStart > 0) {
      final hops = packet.hopStart - packet.hopLimit;
      return hops < 0 ? 0 : hops;
    }
    return null;
  }

  /// Handle text message
  void _handleTextMessage(pb.MeshPacket packet, pb.Data data) {
    try {
      final text = sanitizeExternalText(
        utf8.decode(data.payload, allowMalformed: true),
      );
      AppLogging.protocol('Text message from ${packet.from}: $text');

      // Look up sender node info to cache in message
      final senderNode = _nodes[packet.from];
      String? senderLongName;
      String? senderShortName;
      int? senderAvatarColor;

      if (senderNode != null) {
        senderLongName = senderNode.longName != null
            ? sanitizeExternalText(senderNode.longName!)
            : null;
        senderShortName = senderNode.shortName != null
            ? sanitizeExternalText(senderNode.shortName!)
            : null;
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
          rssi: packet.hasRxRssi() ? packet.rxRssi : null,
          snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
          hopCount: _computeHopCount(packet),
          viaMqtt: packet.hasViaMqtt() ? packet.viaMqtt : false,
        );
        _nodes[packet.from] = placeholderNode;
        _nodeController.add(placeholderNode);
      }

      // rxTime is set by the firmware on the receiving radio before delivery
      // to the phone over BLE. It is never sent over-the-air. Use it as the
      // message timestamp so the chat shows when the radio actually received
      // the packet, not when the app processed it.
      //
      // Validate that rxTime is plausible: devices without a time source
      // (no GPS, no phone sync) may report rxTime as 0 or a small uptime
      // value. Historical messages replayed on connect inherit whatever
      // rxTime the device stored at original receipt — if the device had
      // no clock then, rxTime will be invalid.
      final timestamp = _plausibleTimestamp(packet);

      final message = Message(
        id: Message.deterministicId(packetId: packet.id, fromNode: packet.from),
        from: packet.from,
        to: packet.to,
        text: text,
        timestamp: timestamp,
        channel: packet.channel,
        received: true,
        packetId: packet.id,
        hopCount: _computeHopCount(packet),
        rxSnr: packet.hasRxSnr() ? packet.rxSnr.toDouble() : null,
        rxRssi: packet.hasRxRssi() ? packet.rxRssi : null,
        viaMqtt: packet.hasViaMqtt() ? packet.viaMqtt : null,
        senderLongName: senderLongName,
        senderShortName: senderShortName,
        senderAvatarColor: senderAvatarColor,
        replyId: data.replyId != 0 ? data.replyId : null,
        isEmoji: data.emoji != 0,
        source: data.emoji != 0 ? MessageSource.tapback : MessageSource.unknown,
      );

      if (message.isEmoji) {
        AppLogging.protocol(
          '🏷️ Incoming tapback: emoji="${message.text}", '
          'replyId=${message.replyId}, from=${message.from}, '
          'packetId=${message.packetId}, '
          'data.emoji=${data.emoji}, data.replyId=${data.replyId}',
        );
      }

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

      // Forward to admin ACK tracker for confirmed-mode remote admin
      _adminAckTracker.onDeliveryUpdate(update);
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

        case telemetry.Telemetry_Variant.trafficManagementStats:
          final stats = telem.trafficManagementStats;
          if (ProtocolDebugFlags.logTelemetry) {
            AppLogging.protocol(
              'TrafficManagementStats from ${packet.from}: '
              'inspected=${stats.packetsInspected} '
              'posDedup=${stats.positionDedupDrops} '
              'cacheHits=${stats.nodeinfoCacheHits} '
              'rateDrops=${stats.rateLimitDrops} '
              'unknownDrops=${stats.unknownPacketDrops} '
              'hopExhausted=${stats.hopExhaustedPackets} '
              'hopsPreserved=${stats.routerHopsPreserved}',
            );
          }
          final tmNode = _nodes[packet.from];
          if (tmNode != null) {
            final updatedTmNode = tmNode.copyWith(
              tmPacketsInspected: stats.hasPacketsInspected()
                  ? stats.packetsInspected
                  : null,
              tmPositionDedupDrops: stats.hasPositionDedupDrops()
                  ? stats.positionDedupDrops
                  : null,
              tmNodeinfoCacheHits: stats.hasNodeinfoCacheHits()
                  ? stats.nodeinfoCacheHits
                  : null,
              tmRateLimitDrops: stats.hasRateLimitDrops()
                  ? stats.rateLimitDrops
                  : null,
              tmUnknownPacketDrops: stats.hasUnknownPacketDrops()
                  ? stats.unknownPacketDrops
                  : null,
              tmHopExhaustedPackets: stats.hasHopExhaustedPackets()
                  ? stats.hopExhaustedPackets
                  : null,
              tmRouterHopsPreserved: stats.hasRouterHopsPreserved()
                  ? stats.routerHopsPreserved
                  : null,
              lastHeard: DateTime.now(),
            );
            _nodes[packet.from] = updatedTmNode;
            _nodeController.add(updatedTmNode);
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
          firstHeard: DateTime.now(),
          rssi: packet.hasRxRssi() ? packet.rxRssi : null,
          snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
          hopCount: _computeHopCount(packet),
          viaMqtt: packet.hasViaMqtt() ? packet.viaMqtt : false,
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

  /// Extract the best available timestamp from a [pb.Position] protobuf.
  ///
  /// Follows the standard Meshtastic timestamp fallback order:
  ///   1. `position.timestamp` — actual GPS solution time (epoch seconds)
  ///   2. `position.time` — phone-provided time (epoch seconds)
  ///   3. [DateTime.now] — local processing time as final fallback
  ///
  /// All candidate values are validated against [_minPlausibleEpoch] and
  /// [_maxFutureSlack] before acceptance.
  static DateTime _positionSourceTimestamp(pb.Position position) {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Prefer GPS solution timestamp (field 7)
    if (position.hasTimestamp() && position.timestamp > 0) {
      final ts = position.timestamp;
      if (ts >= _minPlausibleEpoch && ts <= nowEpoch + _maxFutureSlack) {
        return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }
    }

    // Fallback to phone-provided time (field 4)
    if (position.hasTime() && position.time > 0) {
      final t = position.time;
      if (t >= _minPlausibleEpoch && t <= nowEpoch + _maxFutureSlack) {
        return DateTime.fromMillisecondsSinceEpoch(t * 1000);
      }
    }

    // Final fallback
    return DateTime.now();
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

      // Select canonical source timestamp per the standard fallback order
      final posTime = _positionSourceTimestamp(position);
      final String tsSource;
      if (position.hasTimestamp() &&
          position.timestamp > 0 &&
          posTime.millisecondsSinceEpoch == position.timestamp * 1000) {
        tsSource = 'gps_timestamp';
      } else if (position.hasTime() &&
          position.time > 0 &&
          posTime.millisecondsSinceEpoch == position.time * 1000) {
        tsSource = 'position_time';
      } else {
        tsSource = 'fallback_now';
      }

      if (ProtocolDebugFlags.logPosition) {
        AppLogging.debug(
          '📍 POSITION_APP from !${packet.from.toRadixString(16)}: '
          'latI=${position.latitudeI}, lngI=${position.longitudeI}, '
          'lat=${position.latitudeI / 1e7}, lng=${position.longitudeI / 1e7}, '
          'isApplePark=$isApplePark, valid=$hasValidPosition, '
          'tsSource=$tsSource, ts=$posTime',
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
          positionTimestamp: posTime,
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
          // Leave longName/shortName null for placeholder nodes.
          // Real names arrive via NodeInfo — baking hex IDs here
          // pollutes the data model and prevents displayName from
          // showing the correct fallback or the real name later.
          longName: null,
          shortName: null,
          latitude: position.latitudeI / 1e7,
          longitude: position.longitudeI / 1e7,
          altitude: position.hasAltitude() ? position.altitude : null,
          rssi: packet.hasRxRssi() ? packet.rxRssi : null,
          snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
          lastHeard: DateTime.now(),
          firstHeard: DateTime.now(),
          hopCount: _computeHopCount(packet),
          viaMqtt: packet.hasViaMqtt() ? packet.viaMqtt : false,
          avatarColor: avatarColor,
          isFavorite: false,
          positionTimestamp: posTime,
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
      final longName = sanitizeExternalText(user.longName);
      final shortName = sanitizeExternalText(user.shortName);

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

      // Only update names if the incoming values are non-empty.
      // Empty strings from NodeInfo packets should NOT overwrite
      // genuine names already stored on the node. Also clean out
      // hex placeholder names from older position-update code.
      final resolvedLongName = longName.isNotEmpty
          ? longName
          : existingNode != null
          ? NodeDisplayNameResolver.sanitizeName(existingNode.longName)
          : null;
      final resolvedShortName = shortName.isNotEmpty
          ? shortName
          : existingNode != null
          ? NodeDisplayNameResolver.sanitizeName(existingNode.shortName)
          : null;

      final updatedNode =
          existingNode?.copyWith(
            longName: resolvedLongName,
            clearLongName: resolvedLongName == null,
            shortName: resolvedShortName,
            clearShortName: resolvedShortName == null,
            userId: user.hasId() ? user.id : existingNode.userId,
            hardwareModel: hwModel ?? existingNode.hardwareModel,
            hwModelId:
                user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET
                ? user.hwModel.value
                : existingNode.hwModelId,
            role: role,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : existingNode.snr,
            lastHeard: DateTime.now(),
          ) ??
          MeshNode(
            nodeNum: packet.from,
            longName: longName.isNotEmpty ? longName : null,
            shortName: shortName.isNotEmpty ? shortName : null,
            userId: user.hasId() ? user.id : null,
            hardwareModel: hwModel,
            hwModelId:
                user.hasHwModel() && user.hwModel != pb.HardwareModel.UNSET
                ? user.hwModel.value
                : null,
            role: role,
            rssi: packet.hasRxRssi() ? packet.rxRssi : null,
            snr: packet.hasRxSnr() ? packet.rxSnr.toInt() : null,
            lastHeard: DateTime.now(),
            firstHeard: DateTime.now(),
            hopCount: _computeHopCount(packet),
            viaMqtt: packet.hasViaMqtt() ? packet.viaMqtt : false,
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

  /// Update lastHeard timestamp and RF signal metadata for a node.
  ///
  /// Called for every incoming mesh packet. [rxRssi] and [rxSnr] are
  /// the per-packet RF metrics from the radio — they tell us how strong
  /// the sender's LoRa signal was when our radio received it. Storing
  /// them on [MeshNode] makes per-node signal strength available to
  /// node cards, node detail, nearby nodes, AR, 3D mesh, and NodeDex.
  ///
  /// Packets from our own node (local BLE deliveries) lack RF metrics
  /// and will pass null for both, leaving existing values unchanged.
  ///
  /// [hopCount] is derived from hopStart - hopLimit on the packet.
  /// [viaMqtt] indicates whether the packet traversed MQTT transport.
  /// Both are null-safe: null means "no update", preserving existing values.
  void _updateNodeLastHeard(
    int nodeNum, {
    int? rxRssi,
    int? rxSnr,
    int? hopCount,
    bool? viaMqtt,
  }) {
    final node = _nodes[nodeNum];
    if (node != null) {
      final updatedNode = node.copyWith(
        lastHeard: DateTime.now(),
        rssi: rxRssi ?? node.rssi,
        snr: rxSnr ?? node.snr,
        hopCount: hopCount ?? node.hopCount,
        viaMqtt: viaMqtt ?? node.viaMqtt,
      );
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

    // Sync phone time to device as early as possible so that any messages
    // received by the device from this point onward carry a valid rxTime.
    // Historical messages already stored on the device retain whatever
    // timestamp the device had at original receipt, but this sync ensures
    // the device's clock is correct for the remainder of the session.
    // The post-config sync in _requestPostConfigData provides a second
    // reliable sync point after all config data has been exchanged.
    unawaited(
      Future.delayed(const Duration(milliseconds: 50), () async {
        if (!_transport.isConnected || _myNodeNum == null) return;
        try {
          await syncTime();
          AppLogging.protocol('Early time sync sent after myNodeInfo');
        } catch (e) {
          AppLogging.protocol('Early time sync failed (non-fatal): $e');
        }
      }),
    );

    // Request our own position after a short delay
    unawaited(
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (_myNodeNum != null) {
          try {
            await requestPosition(_myNodeNum!);
          } catch (e) {
            AppLogging.protocol('Position request after myNodeInfo failed: $e');
          }
        }
      }),
    );
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

    // Use the device's lastHeard timestamp when available.
    // NodeInfo.lastHeard is a uint32 Unix timestamp (seconds) recording
    // when the DEVICE last received a packet from this node.  Using
    // DateTime.now() here would reset every node's "Last Heard" to the
    // reconnection time, which is misleading.
    final DateTime deviceLastHeard;
    if (nodeInfo.hasLastHeard() && nodeInfo.lastHeard > 0) {
      final lastHeardEpoch = nodeInfo.lastHeard;
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (lastHeardEpoch >= _minPlausibleEpoch &&
          lastHeardEpoch <= nowEpoch + _maxFutureSlack) {
        deviceLastHeard = DateTime.fromMillisecondsSinceEpoch(
          lastHeardEpoch * 1000,
        );
        AppLogging.protocol(
          'NodeInfo ${nodeInfo.num}: using device lastHeard=$lastHeardEpoch '
          '(${deviceLastHeard.toIso8601String()})',
        );
      } else {
        deviceLastHeard = DateTime.now();
        final driftSeconds = lastHeardEpoch - nowEpoch;
        AppLogging.protocol(
          'NodeInfo ${nodeInfo.num}: implausible lastHeard=$lastHeardEpoch '
          '(drift=${driftSeconds}s vs phone) — using phone time',
        );
      }
    } else {
      deviceLastHeard = DateTime.now();
      AppLogging.protocol(
        'NodeInfo ${nodeInfo.num}: no device lastHeard, falling back to now',
      );
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
      AppLogging.protocol(
        'NodeInfo ${nodeInfo.num}: User.role=${user.role.name} (value=${user.role.value}), '
        'hasRole=${user.hasRole()}, resolved role=$role',
      );
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
      // Preserve existing names if new ones are empty, sanitize to prevent UTF-16 crashes.
      // BUT: don't preserve hex placeholder names (e.g. "!db2f10e0") that were
      // baked in by position-update placeholder creation — those are not real names
      // and should be replaced by null so displayName uses the proper fallback.
      final newLongName =
          nodeInfo.hasUser() && nodeInfo.user.longName.isNotEmpty
          ? sanitizeExternalText(nodeInfo.user.longName)
          : NodeDisplayNameResolver.sanitizeName(existingNode.longName) != null
          ? existingNode.longName
          : null;
      final newShortName =
          nodeInfo.hasUser() && nodeInfo.user.shortName.isNotEmpty
          ? sanitizeExternalText(nodeInfo.user.shortName)
          : NodeDisplayNameResolver.sanitizeName(existingNode.shortName) != null
          ? existingNode.shortName
          : null;

      updatedNode = existingNode.copyWith(
        longName: newLongName,
        shortName: newShortName,
        userId: userId ?? existingNode.userId,
        hardwareModel: hwModel ?? existingNode.hardwareModel,
        hwModelId:
            nodeInfo.hasUser() &&
                nodeInfo.user.hasHwModel() &&
                nodeInfo.user.hwModel != pb.HardwareModel.UNSET
            ? nodeInfo.user.hwModel.value
            : existingNode.hwModelId,
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
        lastHeard: deviceLastHeard,
        role: role,
        avatarColor: existingNode.avatarColor,
        hasPublicKey: hasPublicKey,
        isMuted: nodeInfo.hasIsMuted()
            ? nodeInfo.isMuted
            : existingNode.isMuted,
        isFavorite: nodeInfo.isFavorite,
        viaMqtt: nodeInfo.hasViaMqtt()
            ? nodeInfo.viaMqtt
            : existingNode.viaMqtt,
        hopCount: nodeInfo.hasHopsAway()
            ? nodeInfo.hopsAway
            : existingNode.hopCount,
      );
    } else {
      // Use null for empty strings to trigger fallback display logic, sanitize to prevent UTF-16 crashes
      final userLongName =
          nodeInfo.hasUser() && nodeInfo.user.longName.isNotEmpty
          ? sanitizeExternalText(nodeInfo.user.longName)
          : null;
      final userShortName =
          nodeInfo.hasUser() && nodeInfo.user.shortName.isNotEmpty
          ? sanitizeExternalText(nodeInfo.user.shortName)
          : null;

      updatedNode = MeshNode(
        nodeNum: nodeInfo.num,
        longName: userLongName,
        shortName: userShortName,
        userId: userId,
        hardwareModel: hwModel,
        hwModelId:
            nodeInfo.hasUser() &&
                nodeInfo.user.hasHwModel() &&
                nodeInfo.user.hwModel != pb.HardwareModel.UNSET
            ? nodeInfo.user.hwModel.value
            : null,
        latitude: hasValidPosition ? nodeInfo.position.latitudeI / 1e7 : null,
        longitude: hasValidPosition ? nodeInfo.position.longitudeI / 1e7 : null,
        altitude: hasValidPosition && nodeInfo.position.hasAltitude()
            ? nodeInfo.position.altitude
            : null,
        snr: nodeInfo.hasSnr() ? nodeInfo.snr.toInt() : null,
        batteryLevel: nodeInfo.hasDeviceMetrics()
            ? nodeInfo.deviceMetrics.batteryLevel
            : null,
        lastHeard: deviceLastHeard,
        firstHeard: DateTime.now(),
        role: role,
        avatarColor: avatarColor,
        isFavorite: nodeInfo.isFavorite,
        hasPublicKey: hasPublicKey,
        isMuted: nodeInfo.hasIsMuted() ? nodeInfo.isMuted : false,
        viaMqtt: nodeInfo.hasViaMqtt() ? nodeInfo.viaMqtt : false,
        hopCount: nodeInfo.hasHopsAway() ? nodeInfo.hopsAway : null,
      );
    }

    _nodes[nodeInfo.num] = updatedNode;
    _nodeController.add(updatedNode);
    if (nodeInfo.hasUser()) {
      final user = nodeInfo.user;
      // Sanitize names for the callback as well
      final sanitizedLongName = user.longName.isNotEmpty
          ? sanitizeExternalText(user.longName)
          : null;
      final sanitizedShortName = user.shortName.isNotEmpty
          ? sanitizeExternalText(user.shortName)
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
      name: channel.hasSettings()
          ? sanitizeExternalText(channel.settings.name)
          : '',
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

  /// Send a heartbeat to wake the device's connection handler.
  ///
  /// Per Meshtastic protocol, a heartbeat with a random nonce keeps the
  /// device's PhoneAPI connection alive and responsive. The official iOS
  /// app sends this before every wantConfigId request to ensure devices
  /// in low-power states are ready to respond.
  Future<void> _sendHeartbeat() async {
    try {
      if (!_transport.isConnected) return;

      // Nonce >= 2 to avoid any firmware special-casing of 0 or 1
      final heartbeat = pb.Heartbeat()..nonce = _random.nextInt(0x7FFFFFFE) + 2;
      final toRadio = pb.ToRadio()..heartbeat = heartbeat;
      final bytes = toRadio.writeToBuffer();
      final sendBytes = _transport.requiresFraming
          ? PacketFramer.frame(bytes)
          : bytes;

      await _transport.send(sendBytes);
      AppLogging.protocol('Heartbeat sent (nonce: ${heartbeat.nonce})');

      // Brief pause to let device process the heartbeat before config request
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      // Non-fatal — proceed with config request even if heartbeat fails
      AppLogging.protocol('Heartbeat send failed (non-fatal): $e');
    }
  }

  /// Request configuration from device
  Future<void> _requestConfiguration() async {
    try {
      if (!_transport.isConnected) {
        AppLogging.protocol('Cannot request configuration: not connected');
        return;
      }

      AppLogging.protocol(
        'Requesting device configuration '
        '(transport=${_transport.type.name}, '
        'wake=${_transport.requiresWakeSequence}, '
        'framed=${_transport.requiresFraming})',
      );

      // Wake device by sending START2 bytes. This is serial-UART-specific
      // (USB CP210x/CH34x): the UART buffer drops leading bytes until it
      // locks onto the frame preamble. TCP and BLE have no such buffer,
      // so we must not emit these bytes there — the firmware's PhoneAPI
      // treats them as a malformed framed packet.
      if (_transport.requiresWakeSequence) {
        final wakeBytes = List<int>.filled(32, 0xC3); // 32 START2 bytes
        await _transport.send(Uint8List.fromList(wakeBytes));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Phase 1 of the two-step handshake: request the main configuration
      // bundle (config + NodeDB). The second phase (queue drain) is kicked
      // off on receipt of configCompleteId; see `_requestQueueDrain`.
      _handshakePhase = _HandshakePhase.awaitingInitialConfig;
      AppLogging.protocol(
        'Handshake: sending initial wantConfigId (nonce: $_nonceInitialConfig)',
      );
      final toRadio = pb.ToRadio()..wantConfigId = _nonceInitialConfig;
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

  /// Second wantConfigId that triggers the firmware to replay packets it
  /// buffered in its `phoneQueue` while the app was disconnected and — on
  /// firmware versions like T1000-E 2.7.x — stream the rest of the NodeDB.
  ///
  /// Mirrors the iOS reference behavior (AccessoryManager+Connect.swift
  /// Steps 4–5): send a heartbeat first to nudge iOS Core Bluetooth's
  /// NOTIFY path, then the `wantConfigId(_nonceQueueDrain)`; wait up to
  /// `timeoutPerAttempt` for the matching `configCompleteId`. Without the
  /// heartbeat the NOTIFY subscription goes stale after the phase-1 burst
  /// and the firmware's phase-2 response sits in the iOS BLE buffer for
  /// ~180s until the data-health watchdog refreshes notifications.
  ///
  /// Retries up to `maxAttempts` times matching the iOS Step 5 policy
  /// (`retryStep(attempts: 3)` with a 3-second per-step timeout).
  Future<void> _requestQueueDrain({
    int maxAttempts = 3,
    Duration timeoutPerAttempt = const Duration(seconds: 3),
  }) async {
    _handshakePhase = _HandshakePhase.awaitingQueueDrain;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!_transport.isConnected) {
        AppLogging.protocol('Cannot request queue drain: not connected');
        return;
      }

      // Already advanced to `complete` by a stray early configCompleteId?
      // Nothing to do.
      if (_handshakePhase == _HandshakePhase.complete) return;

      // Fresh completer per attempt; _handleConfigCompleteId completes it
      // when phase-2 configCompleteId arrives. Capture the reference now
      // so a stray early phase-2 ack (received during the awaits below)
      // that nulls `_queueDrainCompleter` does not trip a null deref.
      final completer = Completer<void>();
      _queueDrainCompleter = completer;

      try {
        // Step 4 (iOS): heartbeat before wantConfigId. This pings the
        // firmware BLE path and refreshes the NOTIFY subscription state
        // so the phase-2 response is actually delivered.
        await _sendHeartbeat();

        if (!_transport.isConnected) {
          AppLogging.protocol(
            'Queue-drain aborted: transport dropped after heartbeat',
          );
          return;
        }

        // Phase-2 could already be satisfied if a stray configCompleteId
        // arrived during the heartbeat. Short-circuit to avoid sending
        // a pointless wantConfigId.
        if (completer.isCompleted ||
            _handshakePhase == _HandshakePhase.complete) {
          return;
        }

        AppLogging.protocol(
          'Handshake: sending queue-drain wantConfigId '
          '(nonce: $_nonceQueueDrain, attempt $attempt/$maxAttempts)',
        );
        final toRadio = pb.ToRadio()..wantConfigId = _nonceQueueDrain;
        final bytes = toRadio.writeToBuffer();
        final sendBytes = _transport.requiresFraming
            ? PacketFramer.frame(bytes)
            : bytes;
        await _transport.send(sendBytes);

        // Step 5a (iOS): wait for the matching configCompleteId.
        await completer.future.timeout(timeoutPerAttempt);
        // Completer fired — phase-2 complete. Loop exits via this return.
        return;
      } on TimeoutException {
        AppLogging.protocol(
          'Handshake: queue-drain attempt $attempt/$maxAttempts timed out '
          'after ${timeoutPerAttempt.inSeconds}s — retrying with fresh '
          'heartbeat',
        );
        // Clear the completer so _handleConfigCompleteId doesn't complete a
        // stale one if the firmware's laggy response finally arrives after
        // we've given up on this attempt.
        _queueDrainCompleter = null;
        // Fall through to next iteration.
      } catch (e) {
        AppLogging.protocol('Error requesting queue drain: $e');
        _queueDrainCompleter = null;
        return;
      }
    }

    AppLogging.protocol(
      'Handshake: queue-drain exhausted $maxAttempts attempts — giving up. '
      'Phase-2 may complete late; handshake state stays `awaitingQueueDrain` '
      'and a stray configCompleteId(69421) will still transition to complete.',
    );
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
      if (isEmoji) {
        AppLogging.protocol(
          '🏷️ Tapback send: emoji=$text, replyId=$replyId, to=$to, channel=$channel',
        );
      }

      final payloadBudget = TextMessagePayloadSizer.standard(
        replyId: replyId,
        isEmoji: isEmoji,
      ).measure(text);
      if (!payloadBudget.fitsInPacket) {
        throw TextMessagePayloadTooLargeException(payloadBudget);
      }

      final packetId = _generatePacketId();

      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);

      if (replyId != null) {
        data.replyId = replyId;
      }
      if (isEmoji) {
        data.emoji = 1;
      }

      AppLogging.protocol(
        '🏷️ Data fields: portnum=${data.portnum}, '
        'emoji=${data.hasEmoji() ? data.emoji : "unset"}, '
        'replyId=${data.hasReplyId() ? data.replyId : "unset"}, '
        'payloadLen=${data.payload.length}',
      );

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum!,
        to: to,
        data: data,
        packetId: packetId,
        channel: channel,
        wantAck: wantAck,
      );

      AppLogging.protocol(
        '📤 Outbound message: packetId=$packetId, '
        'to=0x${to.toRadixString(16)}, channel=$channel, '
        'wantAck=$wantAck, transport=radio '
        '(hopLimit/hopStart left to firmware)',
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      AppLogging.protocol(
        '📤 Sent ${bytes.length} bytes to node via '
        '${_transport.requiresFraming ? "USB" : "BLE"}',
      );

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
        replyId: replyId,
        isEmoji: isEmoji,
        senderLongName: myNode?.longName,
        senderShortName: myNode?.shortName,
        senderAvatarColor: myNode?.avatarColor,
      );

      if (isEmoji) {
        AppLogging.protocol(
          '🏷️ Tapback message object: id=${message.id}, packetId=$packetId, '
          'replyId=${message.replyId}, isEmoji=${message.isEmoji}',
        );
      }

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
  /// Maximum legacy JSON signal payload size in bytes.
  ///
  /// Aligned with [SmPayloadLimit.loraMtu] — the LoRa MTU ceiling for
  /// the Data.payload field. Previously 200, which was overly
  /// conservative and prevented legitimate signals from broadcasting.
  static const int _maxSignalPayloadBytes = SmPayloadLimit.loraMtu;

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
      var effectiveContent = content;
      var effectivePresence = presenceInfo;

      var signalPacket = MeshSignalPacket(
        senderNodeId: _myNodeNum!,
        packetId: 0,
        signalId: signalId,
        content: effectiveContent,
        ttlMinutes: ttlMinutes,
        latitude: latitude,
        longitude: longitude,
        receivedAt: DateTime.now(),
        hasImage: hasImage,
        presenceInfo: effectivePresence,
      );

      var payload = signalPacket.toPayload();

      // Graceful degradation: strip presence first, then truncate content.
      // The full content is preserved in the local DB and Firestore; this
      // truncation only affects the over-the-air mesh broadcast.
      if (payload.length > _maxSignalPayloadBytes &&
          effectivePresence != null) {
        effectivePresence = null;
        signalPacket = MeshSignalPacket(
          senderNodeId: _myNodeNum!,
          packetId: 0,
          signalId: signalId,
          content: effectiveContent,
          ttlMinutes: ttlMinutes,
          latitude: latitude,
          longitude: longitude,
          receivedAt: DateTime.now(),
          hasImage: hasImage,
        );
        payload = signalPacket.toPayload();
        AppLogging.social(
          'Stripped presence from legacy payload to fit mesh limit '
          '(now ${payload.length} bytes)',
        );
      }

      if (payload.length > _maxSignalPayloadBytes) {
        // Truncate content to fit. Cloud sync delivers full text.
        final excess = payload.length - _maxSignalPayloadBytes;
        final trimLen = effectiveContent.length - excess - 3;
        if (trimLen > 10) {
          effectiveContent = '${effectiveContent.substring(0, trimLen)}…';
          signalPacket = MeshSignalPacket(
            senderNodeId: _myNodeNum!,
            packetId: 0,
            signalId: signalId,
            content: effectiveContent,
            ttlMinutes: ttlMinutes,
            latitude: latitude,
            longitude: longitude,
            receivedAt: DateTime.now(),
            hasImage: hasImage,
          );
          payload = signalPacket.toPayload();
          AppLogging.social(
            'Truncated signal content for mesh: '
            '${content.length} -> ${effectiveContent.length} chars '
            '(${payload.length} bytes)',
          );
        }
      }

      // Final guard: if still too large after trimming, reject
      if (payload.length > _maxSignalPayloadBytes) {
        AppLogging.social(
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

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum!,
        to: 0xFFFFFFFF,
        data: data,
        packetId: packetId,
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      AppLogging.social(
        'Broadcast signal: "${content.length > 30 ? '${content.substring(0, 30)}...' : content}" '
        '(ttl=${ttlMinutes}m, packetId=$packetId)',
      );

      return packetId;
    } catch (e) {
      AppLogging.social('Error broadcasting signal: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Socialmesh binary protocol send methods
  // ─────────────────────────────────────────────────────────────────

  /// Broadcast a binary SM_SIGNAL (portnum 261).
  ///
  /// Returns the packet ID for tracking, or null if encoding failed.
  Future<int?> sendSmSignal(SmSignal signal) async {
    if (_myNodeNum == null || !_transport.isConnected) return null;

    final encoded = SmCodec.encodeSignal(signal);
    if (encoded == null) {
      AppLogging.social('SM_SIGNAL encode failed');
      return null;
    }

    if (!_smRateLimiter.canSend(SmPortnum.signal)) {
      AppLogging.social('SM_SIGNAL rate-limited');
      return null;
    }

    final packetId = _generatePacketId();

    final data = _createDataWithPortnum(SmPortnum.signal, encoded);

    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: 0xFFFFFFFF,
      data: data,
      packetId: packetId,
    );

    // Apply priority from signal spec
    final meshPriority = smSignalPriorityToMeshPriority(signal.priority);
    if (meshPriority > 64) {
      // Only set non-default priorities
      packet.priority = pn.PortNum.valueOf(meshPriority) != null
          ? pb.MeshPacket_Priority.valueOf(meshPriority) ??
                pb.MeshPacket_Priority.DEFAULT
          : pb.MeshPacket_Priority.DEFAULT;
    }

    // Apply hop limit from spec
    final hopLimit = signal.priority == SmSignalPriority.emergency
        ? SmTransport.emergencyHopLimit
        : SmTransport.signalHopLimit;
    packet.hopLimit = hopLimit;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    _smRateLimiter.recordSend(SmPortnum.signal);

    AppLogging.social(
      'SM_SIGNAL broadcast: signalId=${SmPacketRouter.signalIdToString(signal.signalId)} '
      'content=${signal.content.length} chars, packetId=$packetId',
    );

    return packetId;
  }

  /// Broadcast a SM_FEED_POST (portnum 264).
  ///
  /// [loraPayload] is the pre-encoded wire bytes from [MeshPost.encodeForLora].
  /// Returns the packet ID for tracking, or null if rate-limited or not connected.
  Future<int?> sendFeedPost(Uint8List loraPayload) async {
    if (_myNodeNum == null || !_transport.isConnected) return null;

    if (!_smRateLimiter.canSend(SmPortnum.feedPost)) {
      AppLogging.meshFeed('SM_FEED_POST rate-limited');
      return null;
    }

    final packetId = _generatePacketId();

    final data = _createDataWithPortnum(SmPortnum.feedPost, loraPayload);

    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: 0xFFFFFFFF,
      data: data,
      packetId: packetId,
    );

    packet.hopLimit = SmTransport.feedPostHopLimit;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    _smRateLimiter.recordSend(SmPortnum.feedPost);

    AppLogging.meshFeed(
      'SM_FEED_POST broadcast: ${loraPayload.length} bytes, '
      'packetId=$packetId',
    );

    return packetId;
  }

  /// Broadcast a binary SM_PRESENCE (portnum 260).
  ///
  /// Returns the packet ID for tracking, or null if encoding or rate
  /// limit prevented sending.
  Future<int?> sendSmPresence(SmPresence presence) async {
    if (_myNodeNum == null || !_transport.isConnected) return null;

    final encoded = SmCodec.encodePresence(presence);
    if (encoded == null) {
      AppLogging.protocol('SM_PRESENCE encode failed');
      return null;
    }

    if (!_smRateLimiter.canSend(SmPortnum.presence)) {
      AppLogging.protocol('SM_PRESENCE rate-limited');
      return null;
    }

    final packetId = _generatePacketId();

    final data = _createDataWithPortnum(SmPortnum.presence, encoded);

    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: 0xFFFFFFFF,
      data: data,
      packetId: packetId,
    );
    packet.hopLimit = SmTransport.presenceHopLimit;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    _smRateLimiter.recordSend(SmPortnum.presence);

    AppLogging.protocol('SM_PRESENCE broadcast: $presence, packetId=$packetId');
    return packetId;
  }

  // ---------------------------------------------------------------------------
  // SIP protocol: send and receive
  // ---------------------------------------------------------------------------

  /// Send a SIP packet as broadcast on PRIVATE_APP (portnum 256).
  ///
  /// The [payload] must be an already-encoded SIP frame (magic bytes included).
  /// Returns true if the packet was queued for send.
  Future<bool> sendSipPacket(Uint8List payload) async {
    if (_myNodeNum == null || !_transport.isConnected) {
      AppLogging.sip(
        'SIP_TX: not connected (myNodeNum=$_myNodeNum, '
        'connected=${_transport.isConnected})',
      );
      return false;
    }

    final packetId = _generatePacketId();

    final data = pb.Data()
      ..portnum = pn.PortNum.PRIVATE_APP
      ..payload = payload;

    // Broadcast so all mesh peers receive the SIP frame.
    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: 0xFFFFFFFF,
      data: data,
      packetId: packetId,
    );
    packet.hopLimit = 3;

    _logOutgoingMrrpPacket(packet, payload);

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    AppLogging.sip(
      'SIP_TX: sent ${payload.length}B, packetId=$packetId (broadcast)',
    );
    return true;
  }

  /// Handle an inbound PRIVATE_APP packet identified as SIP.
  void _handleSipPacket(pb.MeshPacket packet, Uint8List payload) {
    final senderNodeId = packet.from;

    AppLogging.sip(
      'SIP_RX: from=0x${senderNodeId.toRadixString(16)} '
      '${payload.length}B',
    );

    final discovery = _sipDiscovery;
    if (discovery == null) {
      // Buffer early frames so they are processed once SipDiscovery attaches.
      // Without this, every packet arriving before the first SIP-aware screen
      // opens (e.g. SIP Hub, Mesh Explorer) is permanently lost.
      if (_sipStartupBuffer.length < _kSipStartupBufferMax) {
        _sipStartupBuffer.add((packet: packet, payload: payload));
        AppLogging.sip(
          'SIP_STARTUP: buffering early frame '
          '(${_sipStartupBuffer.length}/$_kSipStartupBufferMax)',
        );
      } else {
        AppLogging.sip(
          'SIP_STARTUP: startup buffer full — discarding early frame',
        );
      }
      return;
    }

    // Ignore our own broadcasts looped back.
    if (discovery.isLocalNode(senderNodeId)) {
      AppLogging.sip('SIP_RX: ignoring loopback from self');
      return;
    }

    final frame = SipCodec.decode(payload);
    if (frame == null) {
      AppLogging.sip('SIP_RX: decode failed — dropping');
      return;
    }

    AppLogging.sip(
      'SIP_RX: msgType=${frame.msgType.name} from '
      '0x${senderNodeId.toRadixString(16)}',
    );

    // Record RX counter.
    _sipCounters?.recordRx(frame.msgType, payload.length);

    switch (frame.msgType) {
      // ----- SIP-0: Discovery -----
      case SipMessageType.capBeacon:
        discovery.handleBeacon(frame, senderNodeId);
      case SipMessageType.rollcallResp:
        discovery.handleRollcallResp(frame, senderNodeId);
      case SipMessageType.rollcallReq:
        final response = discovery.handleRollcallReq(
          senderNodeId,
          frame: frame,
        );
        if (response != null) {
          // Jittered delay before sending response (0-3s).
          Future.delayed(
            Duration(milliseconds: Random().nextInt(3000)),
            () =>
                _sendSipAndCount(response.encoded, SipMessageType.rollcallResp),
          );
        }

      // ----- SIP-1: Handshake -----
      case SipMessageType.hsHello:
        _handleSipHandshakeHello(senderNodeId, frame, payload);
      case SipMessageType.hsChallenge:
        _handleSipHandshakeChallenge(senderNodeId, frame);
      case SipMessageType.hsResponse:
        _handleSipHandshakeResponse(senderNodeId, frame);
      case SipMessageType.hsAccept:
        _handleSipHandshakeAccept(senderNodeId, frame);
      case SipMessageType.hsDecline:
        _handleSipHandshakeDecline(senderNodeId, frame);

      // ----- SIP-1: Identity -----
      case SipMessageType.idReq:
        _handleSipIdentityReq(senderNodeId, frame);
      case SipMessageType.idClaim:
      case SipMessageType.idResp:
        _handleSipIdentityClaim(senderNodeId, frame, payload);

      // ----- Ephemeral DM -----
      case SipMessageType.dmMsg:
        _handleSipDmMsg(frame);
      case SipMessageType.dmTyping:
        _handleSipDmTyping(frame);
      case SipMessageType.dmReaction:
        _handleSipDmReaction(frame);
      case SipMessageType.dmDelete:
        _handleSipDmDelete(frame);
      case SipMessageType.dmClose:
        _handleSipDmClose(frame);

      // ----- SIP-0: CAP_REQ / CAP_RESP (informational) -----
      case SipMessageType.capReq:
      case SipMessageType.capResp:
        discovery.handleBeacon(frame, senderNodeId);

      // ----- SIP-3: Transfer (deferred in v0.1) -----
      case SipMessageType.txStart:
      case SipMessageType.txChunk:
      case SipMessageType.txAck:
      case SipMessageType.txNack:
      case SipMessageType.txDone:
      case SipMessageType.txCancel:
        AppLogging.sip(
          'SIP_RX: SIP-3 transfer msgType=${frame.msgType.name} '
          '— deferred in v0.1, ignoring',
        );

      // ----- MRRP -----
      case SipMessageType.mrrpData:
        _handleMrrpPacket(senderNodeId, frame);

      case SipMessageType.error:
        AppLogging.sip(
          'SIP_RX: ERROR frame from '
          '0x${senderNodeId.toRadixString(16)}',
        );
    }
  }

  /// Handle an inbound MRRP frame embedded in a SIP mrrpData packet.
  void _handleMrrpPacket(int senderNodeId, SipFrame frame) {
    // Overlay v0.2 pre-filter. MRRP v0.2 link frames use
    // version_minor=2 and msg_type 0x20..0x27 — none of which the
    // MRRP v0.1 engine recognises, so a v0.1-only peer would drop
    // them. Give the overlay first look; fall through only when this
    // is not a v0.2 frame.
    if (OverlayLinkCodec.isLinkFrame(frame.payload)) {
      final handler = _overlayInbound;
      if (handler != null) {
        handler(senderNodeId, frame.payload);
        return;
      }
      // Buffer so overlay attachment during startup doesn't lose
      // frames. Bounded to avoid unbounded growth if the flag is off
      // or attachment never happens.
      if (_overlayStartupBuffer.length < _kOverlayStartupBufferMax) {
        _overlayStartupBuffer.add((
          senderNodeId: senderNodeId,
          mrrpPayload: frame.payload,
        ));
        AppLogging.overlay(
          'OVERLAY_STARTUP: buffering early v0.2 frame '
          '(${_overlayStartupBuffer.length}/$_kOverlayStartupBufferMax)',
        );
      } else {
        _overlayStartupBufferDrops++;
        // Rate-limited aggregate log: fire at 1, 2, 4, 8, 16, 32…
        // drops so operators see the signal without per-frame spam.
        if (_overlayStartupBufferDrops >= _overlayStartupBufferNextLogAt) {
          AppLogging.overlay(
            'OVERLAY_STARTUP: buffer full — '
            'total drops=$_overlayStartupBufferDrops '
            '(unattached or flag off)',
          );
          _overlayStartupBufferNextLogAt *= 2;
        }
      }
      return;
    }

    final engine = _mrrpEngine;
    if (engine == null) {
      // Buffer early MRRP frames so they survive the gap between BLE connect
      // and mrrpEngineProvider being built (when a Mesh Explorer or harness
      // screen is first opened).
      if (_mrrpStartupBuffer.length < _kMrrpStartupBufferMax) {
        _mrrpStartupBuffer.add((senderNodeId: senderNodeId, frame: frame));
        AppLogging.mrrp(
          'MRRP_STARTUP: buffering early mrrpData frame '
          '(${_mrrpStartupBuffer.length}/$_kMrrpStartupBufferMax)',
        );
      } else {
        AppLogging.mrrp(
          'MRRP_STARTUP: startup buffer full — discarding mrrpData frame',
        );
      }
      return;
    }
    engine.handleInboundFrame(senderNodeId, frame.payload);
  }

  void _logIncomingMrrpCandidatePacket(
    pb.MeshPacket packet,
    Uint8List payload,
  ) {
    final sipFrame = SipCodec.decode(payload);
    if (sipFrame == null || sipFrame.msgType != SipMessageType.mrrpData) {
      return;
    }

    final mrrpFrame = MrrpCodec.decode(sipFrame.payload);
    if (mrrpFrame == null) {
      AppLogging.mrrp(
        'MRRP_TRACE_RX_PACKET '
        'from=0x${packet.from.toRadixString(16)} '
        'to=0x${packet.to.toRadixString(16)} '
        'packetId=${packet.id} '
        'channel=${packet.channel} '
        'port=PRIVATE_APP '
        'decode=failed',
      );
      return;
    }

    AppLogging.mrrp(
      'MRRP_TRACE_RX_PACKET '
      'from=0x${packet.from.toRadixString(16)} '
      'to=0x${packet.to.toRadixString(16)} '
      'packetId=${packet.id} '
      'channel=${packet.channel} '
      'port=PRIVATE_APP '
      'msgType=${mrrpFrame.msgType.name} '
      'req_id=0x${mrrpFrame.requestId.toRadixString(16)} '
      'service=0x${mrrpFrame.serviceId.toRadixString(16).padLeft(8, '0')} '
      'action=0x${mrrpFrame.actionId.toRadixString(16).padLeft(4, '0')}',
    );
  }

  void _logOutgoingMrrpPacket(pb.MeshPacket packet, Uint8List payload) {
    final sipFrame = SipCodec.decode(payload);
    if (sipFrame == null || sipFrame.msgType != SipMessageType.mrrpData) {
      return;
    }

    final mrrpFrame = MrrpCodec.decode(sipFrame.payload);
    if (mrrpFrame == null) {
      AppLogging.mrrp(
        'MRRP_TRACE_TX_PACKET '
        'from=0x${packet.from.toRadixString(16)} '
        'to=0x${packet.to.toRadixString(16)} '
        'packetId=${packet.id} '
        'channel=${packet.channel} '
        'port=PRIVATE_APP '
        'wantAck=${packet.wantAck} '
        'hopLimit=${packet.hopLimit} '
        'transport=${_transport.type.name} '
        'decode=failed',
      );
      return;
    }

    AppLogging.mrrp(
      'MRRP_TRACE_TX_PACKET '
      'from=0x${packet.from.toRadixString(16)} '
      'to=0x${packet.to.toRadixString(16)} '
      'packetId=${packet.id} '
      'channel=${packet.channel} '
      'port=PRIVATE_APP '
      'wantAck=${packet.wantAck} '
      'hopLimit=${packet.hopLimit} '
      'transport=${_transport.type.name} '
      'msgType=${mrrpFrame.msgType.name} '
      'req_id=0x${mrrpFrame.requestId.toRadixString(16)} '
      'service=0x${mrrpFrame.serviceId.toRadixString(16).padLeft(8, '0')} '
      'action=0x${mrrpFrame.actionId.toRadixString(16).padLeft(4, '0')}',
    );
  }

  /// Inject a raw SIP PRIVATE_APP payload directly into the receive path.
  ///
  /// Intended for unit tests only. Bypasses BLE/USB framing and lets tests
  /// drive [_handleSipPacket] without constructing a full [pb.FromRadio].
  @visibleForTesting
  void injectSipPacketForTest(pb.MeshPacket packet, Uint8List payload) {
    _handleSipPacket(packet, payload);
  }

  /// Number of SIP frames currently held in the pre-attachment startup buffer.
  ///
  /// A non-zero value means [attachSipDiscovery] has not been called yet and
  /// SIP packets are being buffered for later delivery. Exposed for unit tests.
  @visibleForTesting
  int get sipStartupBufferLength => _sipStartupBuffer.length;

  /// Number of MRRP frames currently held in the pre-attachment startup buffer.
  ///
  /// Exposed for unit tests.
  @visibleForTesting
  int get mrrpStartupBufferLength => _mrrpStartupBuffer.length;

  /// Clear both startup buffers, discarding all buffered frames.
  ///
  /// Exposed for unit tests to simulate the BLE reconnect path without
  /// executing the full async [start] method.
  @visibleForTesting
  void clearStartupBuffersForTest() => _clearStartupBuffers();

  /// Send a SIP packet and record the TX counter.
  Future<bool> _sendSipAndCount(Uint8List payload, SipMessageType type) async {
    final ok = await sendSipPacket(payload);
    if (ok) {
      _sipCounters?.recordTx(type, payload.length);
    }
    return ok;
  }

  /// Send a SIP packet with rate-limiter enforcement **and** TX counter
  /// accounting.
  ///
  /// Use this for send paths that are **not** pre-accounted by their own
  /// builders (handshake, identity claims — HS_HELLO, HS_CHALLENGE,
  /// HS_RESPONSE, HS_ACCEPT, HS_DECLINE, ID_CLAIM, ID_RESP). Discovery
  /// and DM builders record their own bytes against the limiter before
  /// returning the encoded frame; those paths MUST continue to call
  /// [sendSipPacket] directly (via `_sendSipAndCount`) to avoid
  /// double-counting the budget.
  ///
  /// When no rate limiter has been attached (tests, early boot),
  /// behaviour degrades gracefully to [_sendSipAndCount]. When the
  /// limiter refuses the send, the bytes are dropped, the throttle
  /// counter is incremented, and `false` is returned — no exceptions.
  Future<bool> sendSipGated(Uint8List encoded, SipMessageType type) async {
    final limiter = _sipRateLimiter;
    if (limiter != null) {
      if (!limiter.canSend(encoded.length)) {
        AppLogging.sip(
          'SIP_TX: ${type.name} suppressed '
          '(budget insufficient for ${encoded.length}B, '
          'remaining=${limiter.remainingBytes})',
        );
        _sipCounters?.recordBudgetThrottle();
        return false;
      }
      limiter.recordSend(encoded.length);
    }
    return _sendSipAndCount(encoded, type);
  }

  /// Wrap a raw payload in a SIP frame envelope and send it on-air.
  ///
  /// Creates a [SipFrame] with the given [type], SIP-encodes it via
  /// [SipCodec.encode], then transmits the wire bytes. Used by MRRP
  /// providers to send MRRP data wrapped in the SIP framing that the
  /// receive side ([_handleSipPacket] → [SipCodec.decode]) expects.
  Future<bool> sendSipPayload(Uint8List payload, SipMessageType type) {
    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: type,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      payloadLen: payload.length,
      payload: payload,
    );
    final encoded = SipCodec.encode(frame);
    if (encoded == null) return Future.value(false);
    return _sendSipAndCount(encoded, type);
  }

  /// Accept an incoming SIP handshake request from [peerNodeId].
  ///
  /// Sends HS_CHALLENGE to the peer. No-ops if no pending request exists.
  ///
  /// **Defensive trace:** every invocation logs its originating call
  /// site via a captured stack trace. The mandatory consent rule says
  /// only an explicit user button tap may reach this method; if a
  /// field log ever shows a stack frame that is not the SIP hub's
  /// `_IncomingRequestTile` Accept button or the Mesh Explorer peer
  /// detail sheet's `_onAccept`, that points to a consent-bypass
  /// regression we must fix immediately.
  Future<void> acceptSipHandshake(int peerNodeId) async {
    final stack = StackTrace.current.toString().split('\n').take(6).join(' | ');
    AppLogging.sip(
      'SIP_HS: acceptSipHandshake call peer=0x${peerNodeId.toRadixString(16)} '
      'stack=$stack',
    );
    final hs = _sipHandshake;
    if (hs == null) return;
    final challengeFrame = hs.acceptHandshake(peerNodeId);
    if (challengeFrame == null) return;
    final encoded = SipCodec.encode(challengeFrame);
    if (encoded != null) {
      await sendSipGated(encoded, SipMessageType.hsChallenge);
    }
  }

  /// Decline an incoming SIP handshake request from [peerNodeId].
  ///
  /// Sends HS_DECLINE to the peer. No-ops if no pending request exists.
  Future<void> declineSipHandshake(int peerNodeId) async {
    final hs = _sipHandshake;
    if (hs == null) return;
    final declineFrame = hs.declineHandshake(peerNodeId);
    if (declineFrame == null) return;
    final encoded = SipCodec.encode(declineFrame);
    if (encoded != null) {
      await sendSipGated(encoded, SipMessageType.hsDecline);
    }
  }

  // ---------------------------------------------------------------------------
  // SIP-1 Handshake dispatch
  // ---------------------------------------------------------------------------

  void _handleSipHandshakeHello(
    int senderNodeId,
    SipFrame frame,
    Uint8List rawPayload,
  ) {
    final hs = _sipHandshake;
    if (hs == null) {
      AppLogging.sip('SIP_RX: no SipHandshakeManager — dropping HS_HELLO');
      return;
    }

    _sipCounters?.recordHandshakeInitiated();

    // Show a notification prompting the user to respond.
    // Gated on master + DM notification preferences + minor contact restriction.
    () async {
      final prefs = await SharedPreferences.getInstance();

      // Minor contact restriction: confirmed teen/under-13 users should not
      // receive unsolicited handshake requests. Auto-decline silently.
      final ageGroup = prefs.getString('age_eligibility_age_group') ?? '';
      if (ageGroup == 'under13' || ageGroup == 'teen') {
        AppLogging.sip(
          'SIP_HS: suppressing incoming HS_HELLO — minor contact restriction',
        );
        hs.declineHandshake(senderNodeId);
        return;
      }

      if (!(prefs.getBool('notifications_enabled') ?? true)) return;
      if (!(prefs.getBool('dm_notifications_enabled') ?? true)) return;
      final peerName =
          _nodes[senderNodeId]?.displayName ??
          NodeDisplayNameResolver.defaultName(senderNodeId);
      NotificationService().showSipHandshakeRequestNotification(
        peerName: peerName,
        peerNodeId: senderNodeId,
      );
    }();

    // Queue the request for user consent — no automatic challenge response.
    // Consent is a hard privacy boundary and is required even on the
    // simultaneous-open yield path.
    hs.handleHello(senderNodeId, frame);
  }

  void _handleSipHandshakeChallenge(int senderNodeId, SipFrame frame) {
    final hs = _sipHandshake;
    if (hs == null) return;

    hs.handleChallenge(senderNodeId, frame).then((responseFrame) {
      if (responseFrame != null) {
        final encoded = SipCodec.encode(responseFrame);
        if (encoded != null) {
          sendSipGated(encoded, SipMessageType.hsResponse);
        }
      }
    });
  }

  void _handleSipHandshakeResponse(int senderNodeId, SipFrame frame) {
    final hs = _sipHandshake;
    if (hs == null) return;

    hs.handleResponse(senderNodeId, frame).then((acceptFrame) {
      if (acceptFrame != null) {
        final encoded = SipCodec.encode(acceptFrame);
        if (encoded != null) {
          sendSipGated(encoded, SipMessageType.hsAccept);
          // Responder-side: handshake complete. Auto-create DM session.
          _completeSipHandshake(senderNodeId);
        }
      }
    });
  }

  void _handleSipHandshakeAccept(int senderNodeId, SipFrame frame) {
    final hs = _sipHandshake;
    if (hs == null) return;

    final result = hs.handleAccept(senderNodeId, frame);
    if (result != null) {
      // Initiator-side: handshake complete. Auto-create DM session.
      _completeSipHandshake(senderNodeId);
    } else {
      _sipCounters?.recordHandshakeFailed();
    }
  }

  void _handleSipHandshakeDecline(int senderNodeId, SipFrame frame) {
    final hs = _sipHandshake;
    if (hs == null) return;

    hs.handleDecline(senderNodeId, frame);

    () async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notifications_enabled') ?? true)) return;
      if (!(prefs.getBool('dm_notifications_enabled') ?? true)) return;
      final peerName =
          _nodes[senderNodeId]?.displayName ??
          NodeDisplayNameResolver.defaultName(senderNodeId);
      NotificationService().showSipHandshakeDeclinedNotification(
        peerName: peerName,
        peerNodeId: senderNodeId,
      );
    }();
  }

  /// Complete a handshake: consume result, create DM session, update counters.
  void _completeSipHandshake(int peerNodeId) {
    final hs = _sipHandshake;
    final dm = _sipDm;
    if (hs == null) return;

    final result = hs.consumeResult(peerNodeId);
    if (result == null) return;

    _sipCounters?.recordHandshakeCompleted();

    // Handle an existing DM session for this peer.
    //
    // Same tag → true duplicate (e.g. handshake state-machine re-entry
    // during a race). Skip without creating another entry.
    //
    // Different tag → the peer re-handshook and installed a new
    // session_tag on its side. Expire the prior local session(s) so
    // the new one takes over; otherwise the peer's DMs get dropped as
    // `unknown session` and our sends target a tag the peer discarded.
    final existing = dm?.activeSessions
        .where((s) => s.peerNodeId == peerNodeId)
        .toList();
    if (existing != null && existing.isNotEmpty) {
      final duplicateTag = existing.any(
        (s) => s.sessionTag == result.sessionTag,
      );
      if (duplicateTag) {
        AppLogging.sip(
          'SIP: DM session already exists for '
          'node=0x${peerNodeId.toRadixString(16)}, '
          'existing_tag=0x${result.sessionTag.toRadixString(16)}, '
          'skipping duplicate creation',
        );
        return;
      }
      dm?.supersedeSessionsForPeer(peerNodeId, exceptTag: result.sessionTag);
    }

    // Create ephemeral DM session from handshake result.
    dm?.createSession(
      sessionTag: result.sessionTag,
      peerNodeId: result.peerNodeId,
      ttlS: result.dmTtlS,
    );

    AppLogging.sip(
      'SIP: handshake->DM pipeline complete for '
      'node=0x${peerNodeId.toRadixString(16)}, '
      'session_tag=0x${result.sessionTag.toRadixString(16)}',
    );

    // Hand off to the provider-level overlay auto-opener. Fire-and-
    // forget: any exception is the provider's problem and must not
    // break DM readiness.
    final hsHook = onSipHandshakeComplete;
    if (hsHook != null) {
      try {
        hsHook(peerNodeId);
      } catch (e, st) {
        AppLogging.sip(
          'SIP: onSipHandshakeComplete hook threw (ignored): $e\n$st',
        );
      }
    }

    // Fire local notification for handshake completion.
    // Gated on master + DM notification preferences.
    () async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notifications_enabled') ?? true)) return;
      if (!(prefs.getBool('dm_notifications_enabled') ?? true)) return;
      final peerName =
          _nodes[peerNodeId]?.displayName ??
          NodeDisplayNameResolver.defaultName(peerNodeId);
      NotificationService().showSipHandshakeCompleteNotification(
        peerName: peerName,
        peerNodeId: peerNodeId,
      );
    }();
  }

  // ---------------------------------------------------------------------------
  // SIP-1 Identity dispatch
  // ---------------------------------------------------------------------------

  void _handleSipIdentityReq(int senderNodeId, SipFrame frame) {
    final identity = _sipIdentity;
    if (identity == null) {
      AppLogging.sip('SIP_RX: no SipIdentityHandler — dropping ID_REQ');
      return;
    }

    identity.handleInboundReq(frame: frame, senderNodeId: senderNodeId).then((
      resp,
    ) {
      if (resp != null) {
        _sendSipAndCount(resp.encoded, SipMessageType.idResp);
      }
    });
  }

  void _handleSipIdentityClaim(
    int senderNodeId,
    SipFrame frame,
    Uint8List rawPayload,
  ) {
    final identity = _sipIdentity;
    if (identity == null) {
      AppLogging.sip('SIP_RX: no SipIdentityHandler — dropping ID_CLAIM');
      return;
    }

    identity
        .handleInboundClaim(
          frame: frame,
          rawFrameBytes: rawPayload,
          senderNodeId: senderNodeId,
        )
        .then((result) {
          if (result == null) return;

          if (result.signatureValid) {
            _sipCounters?.recordSignatureSuccess();
            _sipCounters?.recordIdentityVerified();

            // Bridge verified identity into NodeDex.
            onSipIdentityVerified?.call(
              nodeId: senderNodeId,
              pubkey: result.claim.pubkey,
              personaId: result.claim.personaId,
              identityState: result.state,
              displayName: result.claim.displayName.isNotEmpty
                  ? result.claim.displayName
                  : null,
            );
          } else {
            _sipCounters?.recordSignatureFailure();
          }

          if (result.state == SipIdentityState.changedKey) {
            _sipCounters?.recordIdentityChangedKey();
          }
        });
  }

  // ---------------------------------------------------------------------------
  // SIP DM dispatch
  // ---------------------------------------------------------------------------

  void _handleSipDmMsg(SipFrame frame) {
    final dm = _sipDm;
    if (dm == null) {
      AppLogging.sip('SIP_RX: no SipDmManager — dropping DM_MSG');
      return;
    }

    final message = dm.handleInboundDm(frame);
    if (message != null) {
      // Fire local notification for inbound SIP DM.
      // Gated on master + DM notification preferences.
      final session = dm.getSession(frame.sessionId);
      if (session != null) {
        () async {
          final prefs = await SharedPreferences.getInstance();
          if (!(prefs.getBool('notifications_enabled') ?? true)) return;
          if (!(prefs.getBool('dm_notifications_enabled') ?? true)) return;
          final peerName =
              _nodes[session.peerNodeId]?.displayName ??
              NodeDisplayNameResolver.defaultName(session.peerNodeId);
          NotificationService().showSipDmNotification(
            peerName: peerName,
            message: message.text,
            sessionTag: frame.sessionId,
          );
        }();
      }
    }
  }

  void _handleSipDmTyping(SipFrame frame) {
    final dm = _sipDm;
    if (dm == null) {
      AppLogging.sip('SIP_RX: no SipDmManager — dropping DM_TYPING');
      return;
    }

    dm.handleInboundTyping(frame);
  }

  void _handleSipDmReaction(SipFrame frame) {
    final dm = _sipDm;
    if (dm == null) {
      AppLogging.sip('SIP_RX: no SipDmManager — dropping DM_REACTION');
      return;
    }

    dm.handleInboundReaction(frame);
  }

  void _handleSipDmDelete(SipFrame frame) {
    final dm = _sipDm;
    if (dm == null) {
      AppLogging.sip('SIP_RX: no SipDmManager — dropping DM_DELETE');
      return;
    }

    dm.handleInboundDelete(frame);
  }

  void _handleSipDmClose(SipFrame frame) {
    final dm = _sipDm;
    if (dm == null) {
      AppLogging.sip('SIP_RX: no SipDmManager — dropping DM_CLOSE');
      return;
    }

    dm.handleInboundClose(frame);
  }

  /// Send a file transfer packet as broadcast on PRIVATE_APP (portnum 256).
  ///
  /// File transfers are broadcast rather than unicast because Meshtastic
  /// firmware 2.5+ may apply PKC (Public Key Cryptography) to unicast
  /// packets, which fails when PKC keys are not properly exchanged between
  /// devices. Broadcast packets always use channel PSK encryption — the
  /// same proven path that legacy JSON signals use.
  ///
  /// The [destinationNode] parameter is retained for logging and future
  /// unicast support once PKC compatibility is resolved.
  ///
  /// The [payload] is the already-encoded binary packet (offer, chunk,
  /// nack, or ack). Returns true if the packet was queued for send.
  Future<bool> sendSmFileTransferPacket(
    Uint8List payload, {
    int? destinationNode,
    int hopLimit = 3,
  }) async {
    if (_myNodeNum == null || !_transport.isConnected) {
      AppLogging.fileTransfer(
        'sendSmFileTransferPacket BLOCKED: '
        'myNodeNum=${_myNodeNum != null ? "set" : "NULL"}, '
        'connected=${_transport.isConnected}',
      );
      return false;
    }

    if (!_smRateLimiter.canSend(SmPortnum.fileTransfer)) {
      AppLogging.fileTransfer(
        'sendSmFileTransferPacket RATE-LIMITED '
        '(${payload.length} bytes, '
        'intended=${destinationNode?.toRadixString(16) ?? "broadcast"})',
      );
      return false;
    }

    final packetId = _generatePacketId();

    // Use the normal protobuf portnum setter — NOT _createDataWithPortnum.
    // PRIVATE_APP (256) is a known proto enum value, so the standard setter
    // produces the exact wire encoding that firmware expects.
    final data = pb.Data()
      ..portnum = pn.PortNum.PRIVATE_APP
      ..payload = payload;

    // Always broadcast. Unicast PRIVATE_APP triggers PKC encryption in
    // firmware 2.5+ which fails between devices without properly
    // exchanged PKC keys (hasDecoded=false on receiver). Broadcast
    // uses channel PSK which always works. The engine's fileId matching
    // ensures only the intended recipient processes the payload.
    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: 0xFFFFFFFF,
      data: data,
      packetId: packetId,
    );
    packet.hopLimit = hopLimit;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    _smRateLimiter.recordSend(SmPortnum.fileTransfer);

    final intendedTo = destinationNode?.toRadixString(16) ?? 'broadcast';
    AppLogging.fileTransfer(
      'TX sent: ${payload.length} bytes, '
      'intended=$intendedTo, '
      'packetId=$packetId (broadcast)',
    );
    return true;
  }

  /// Send an SM_IDENTITY request to a specific node (unicast).
  ///
  /// Respects per-node rate limits. Returns the packet ID, or null if
  /// rate-limited or not connected.
  Future<int?> sendSmIdentityRequest(int targetNodeNum) async {
    if (_myNodeNum == null || !_transport.isConnected) return null;

    if (!_smIdentityRateLimiter.canRequest(targetNodeNum)) {
      AppLogging.protocol(
        'SM_IDENTITY request rate-limited for '
        '${targetNodeNum.toRadixString(16)}',
      );
      return null;
    }

    final identity = SmIdentity(
      sigilHash: SmIdentity.computeSigilHash(_myNodeNum!),
      isRequest: true,
    );

    final encoded = SmCodec.encodeIdentity(identity);
    if (encoded == null) return null;

    final packetId = _generatePacketId();

    final data = _createDataWithPortnum(SmPortnum.identity, encoded);

    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: targetNodeNum,
      data: data,
      packetId: packetId,
    );
    packet.hopLimit = SmTransport.identityRequestHopLimit;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    _smIdentityRateLimiter.recordRequest(targetNodeNum);

    AppLogging.protocol(
      'SM_IDENTITY request sent to ${targetNodeNum.toRadixString(16)}, '
      'packetId=$packetId',
    );
    return packetId;
  }

  /// Send an SM_IDENTITY response to a requesting node (unicast).
  void _sendSmIdentityResponse(int targetNodeNum) async {
    if (_myNodeNum == null || !_transport.isConnected) return;

    final identity = SmIdentity(
      sigilHash: SmIdentity.computeSigilHash(_myNodeNum!),
      isResponse: true,
      // trait and encounterCount left null until NodeDex integration
    );

    final encoded = SmCodec.encodeIdentity(identity);
    if (encoded == null) return;

    final packetId = _generatePacketId();

    final data = _createDataWithPortnum(SmPortnum.identity, encoded);

    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum!,
      to: targetNodeNum,
      data: data,
      packetId: packetId,
    );
    packet.hopLimit = SmTransport.identityRequestHopLimit;

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    AppLogging.protocol(
      'SM_IDENTITY response sent to ${targetNodeNum.toRadixString(16)}, '
      'packetId=$packetId',
    );
  }

  /// Broadcast a signal with dual-send support (binary + legacy).
  ///
  /// When [smBinaryEnabled] is true:
  ///   1. Always sends SM_SIGNAL (portnum 261) first.
  ///   2. If legacy compatibility is still needed, also sends legacy
  ///      JSON (portnum 256) with the same logical signal ID.
  ///
  /// When [smBinaryEnabled] is false:
  ///   Behaves exactly like [sendSignal] (legacy JSON only).
  ///
  /// Returns the packet ID of the primary send, or null on failure.
  Future<int?> sendSignalDualMode({
    required String signalId,
    required String content,
    required int ttlMinutes,
    double? latitude,
    double? longitude,
    bool hasImage = false,
    Map<String, dynamic>? presenceInfo,
  }) async {
    if (_myNodeNum == null || !_transport.isConnected) return null;

    if (!_smFeatureFlag.shouldSendBinary) {
      // Binary disabled — legacy only (existing behavior).
      // Uses the caller-provided signalId (UUID) unchanged.
      final packetId = await sendSignal(
        signalId: signalId,
        content: content,
        ttlMinutes: ttlMinutes,
        latitude: latitude,
        longitude: longitude,
        hasImage: hasImage,
        presenceInfo: presenceInfo,
      );
      return packetId;
    }

    // Binary enabled — build and send SM_SIGNAL first
    final binarySignalId = SmSignal.generateSignalId();

    final smSignal = SmSignal(
      signalId: binarySignalId,
      content: content,
      ttl: SmPacketRouter.ttlFromMinutes(ttlMinutes),
      hasImage: hasImage,
      latitudeI: latitude != null ? (latitude * 1e7).round() : null,
      longitudeI: longitude != null ? (longitude * 1e7).round() : null,
    );

    final binaryPacketId = await sendSmSignal(smSignal);
    int? resultPacketId = binaryPacketId;

    // Check if legacy send is needed
    final sendLegacy = _smFeatureFlag.shouldSendLegacyGivenMeshState(
      isMeshBinaryReady: _smCapabilityStore.isMeshBinaryReady,
    );

    if (sendLegacy) {
      try {
        // Use the ORIGINAL caller signalId (UUID) for the legacy packet.
        // This matches the Firestore document ID so receivers can look up
        // cloud data via posts/{signalId}. The binary packet uses its own
        // sm- prefixed ID; cross-format dedupe on the receive side handles
        // duplicates. If legacy send carried the sm- ID, receivers would
        // start a post listener for a Firestore doc that doesn't exist.
        final legacyPacketId = await sendSignal(
          signalId: signalId,
          content: content,
          ttlMinutes: ttlMinutes,
          latitude: latitude,
          longitude: longitude,
          hasImage: hasImage,
          presenceInfo: presenceInfo,
        );
        resultPacketId ??= legacyPacketId;
        _smMetrics.recordDualSend();
      } catch (e) {
        final binaryStatus = binaryPacketId != null
            ? 'succeeded'
            : 'also failed';
        AppLogging.social('Dual-send legacy failed (binary $binaryStatus): $e');
      }
    }

    return resultPacketId;
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

      final payloadBudget = TextMessagePayloadSizer.standard(
        replyId: replyId,
        isEmoji: isEmoji,
      ).measure(text);
      if (!payloadBudget.fitsInPacket) {
        throw TextMessagePayloadTooLargeException(payloadBudget);
      }

      final packetId = _generatePacketId();

      // Call the pre-tracking callback BEFORE sending
      // This ensures tracking is set up before any ACK can arrive
      if (wantAck) {
        onPacketIdGenerated(packetId);
      }

      final data = pb.Data()
        ..portnum = pn.PortNum.TEXT_MESSAGE_APP
        ..payload = utf8.encode(text);

      if (replyId != null) {
        data.replyId = replyId;
      }
      if (isEmoji) {
        data.emoji = 1;
      }

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum!,
        to: to,
        data: data,
        packetId: packetId,
        channel: channel,
        wantAck: wantAck,
      );

      AppLogging.protocol(
        '📤 Outbound message (pre-tracked): packetId=$packetId, '
        'to=0x${to.toRadixString(16)}, channel=$channel, '
        'wantAck=$wantAck, transport=radio '
        '(hopLimit/hopStart left to firmware)',
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));

      AppLogging.protocol(
        '📤 Sent ${bytes.length} bytes to node via '
        '${_transport.requiresFraming ? "USB" : "BLE"}',
      );

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
        replyId: replyId,
        isEmoji: isEmoji,
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
  /// Resolve an [AdminTarget] to a concrete destination node number.
  ///
  /// If [target] is null, defaults to the local device.
  int _resolveTarget(AdminTarget? target) {
    if (target == null) return _myNodeNum!;
    return target.resolve(_myNodeNum!);
  }

  /// Apply the stored session passkey to an admin message when targeting a
  /// remote node.
  ///
  /// Matches the iOS app's pattern: `if fromUser != toUser { adminPacket.sessionPasskey = ... }`.
  /// Only applied to SET/ACTION operations, not GET/request operations.
  void _applySessionPasskey(admin.AdminMessage adminMsg, int dest) {
    if (dest == _myNodeNum) return; // Local admin — no passkey needed.

    final session = _adminSessions[dest];
    if (session == null || session.isExpired) {
      AppLogging.protocol(
        'Remote admin to ${dest.toRadixString(16)}: '
        '${session == null ? "no session passkey" : "session expired"} '
        '— sending without passkey',
      );
      return;
    }

    adminMsg.sessionPasskey = session.passkey;
    AppLogging.protocol(
      'Remote admin to ${dest.toRadixString(16)}: '
      'attached session passkey (${session.passkey.length} bytes, '
      'expires ${session.expiration.toIso8601String()})',
    );
  }

  /// Store a session passkey received from a remote node's admin response.
  void _storeSessionPasskey(int nodeNum, List<int> passkey) {
    if (passkey.isEmpty) return;
    if (nodeNum == _myNodeNum) return; // Local node — ignore.

    _adminSessions[nodeNum] = _AdminSession(
      passkey: passkey,
      expiration: DateTime.now().add(_sessionPasskeyTtl),
    );
    AppLogging.protocol(
      'Stored session passkey for node ${nodeNum.toRadixString(16)} '
      '(${passkey.length} bytes, TTL ${_sessionPasskeyTtl.inSeconds}s)',
    );
  }

  int _generatePacketId() {
    return _random.nextInt(0x7FFFFFFF);
  }

  /// Prepare bytes for sending (frame if transport requires it)
  List<int> _prepareForSend(List<int> bytes) {
    return _transport.requiresFraming ? PacketFramer.frame(bytes) : bytes;
  }

  /// Send position (broadcast to all nodes).
  ///
  /// Rate-limited to one broadcast every [_positionBroadcastMinInterval]
  /// (20 s). Returns silently if the cooldown has not elapsed. This is the
  /// authoritative last-mile gate — no caller can bypass it.
  Future<void> sendPosition({
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    try {
      // Rate-limit: enforce minimum interval between broadcast positions.
      if (_lastPositionBroadcastAt != null) {
        final elapsed = DateTime.now().difference(_lastPositionBroadcastAt!);
        if (elapsed < _positionBroadcastMinInterval) {
          AppLogging.protocol(
            'POSITION_APP broadcast rate-limited '
            '(${elapsed.inSeconds}s < ${_positionBroadcastMinInterval.inSeconds}s)',
          );
          return;
        }
      }

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

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum ?? 0,
        to: 0xFFFFFFFF,
        data: data,
        packetId: _generatePacketId(),
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      _lastPositionBroadcastAt = DateTime.now();

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

  /// Send position to a specific node (direct message, not broadcast).
  ///
  /// Rate-limited to one directed send every [_positionDirectMinInterval]
  /// (10 s). Returns silently if the cooldown has not elapsed.
  Future<void> sendPositionToNode({
    required int nodeNum,
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    try {
      // Rate-limit: enforce minimum interval between directed position sends.
      if (_lastPositionDirectAt != null) {
        final elapsed = DateTime.now().difference(_lastPositionDirectAt!);
        if (elapsed < _positionDirectMinInterval) {
          AppLogging.protocol(
            'POSITION_APP direct rate-limited '
            '(${elapsed.inSeconds}s < ${_positionDirectMinInterval.inSeconds}s)',
          );
          return;
        }
      }

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

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum ?? 0,
        to: nodeNum,
        data: data,
        packetId: _generatePacketId(),
        wantAck: true,
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      _lastPositionDirectAt = DateTime.now();
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
      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum ?? 0,
        to: nodeNum,
        data: data,
        packetId: _generatePacketId(),
        wantAck: true,
      );

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

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum ?? 0,
        to: 0xFFFFFFFF,
        data: data,
        packetId: _generatePacketId(),
      );

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

      final packet = MeshPacketBuilder.userPayload(
        myNodeNum: _myNodeNum ?? 0,
        to: nodeNum,
        data: data,
        packetId: _generatePacketId(),
        wantAck: true,
      );

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
  /// Returns immediately - results come via mesh packet responses.
  /// Emits a placeholder [TraceRouteLog] with `response: false` so the UI
  /// can show a "No Response" entry while waiting.  When the inbound
  /// response arrives, the placeholder is replaced by the full log.
  Future<void> sendTraceroute(int nodeNum) async {
    AppLogging.protocol('Sending traceroute to node $nodeNum');

    // Create an empty RouteDiscovery for the request
    final routeDiscovery = pb.RouteDiscovery();

    final data = pb.Data()
      ..portnum = pn.PortNum.TRACEROUTE_APP
      ..payload = routeDiscovery.writeToBuffer()
      ..wantResponse = true;

    final packet = MeshPacketBuilder.userPayload(
      myNodeNum: _myNodeNum ?? 0,
      to: nodeNum,
      data: data,
      packetId: _generatePacketId(),
      wantAck: true,
    );

    final toRadio = pb.ToRadio()..packet = packet;
    final bytes = toRadio.writeToBuffer();

    await _transport.send(_prepareForSend(bytes));

    // Snapshot origin (local device) position for pending entry
    double? originLat, originLon;
    if (_myNodeNum != null) {
      final myNode = _nodes[_myNodeNum];
      if (myNode != null && myNode.hasPosition) {
        originLat = myNode.latitude;
        originLon = myNode.longitude;
      }
    }

    // Snapshot target node position for pending entry
    double? targetLat, targetLon;
    final targetNodeObj = _nodes[nodeNum];
    if (targetNodeObj != null && targetNodeObj.hasPosition) {
      targetLat = targetNodeObj.latitude;
      targetLon = targetNodeObj.longitude;
    }

    // Emit a placeholder log so the UI immediately shows a pending entry
    _traceRouteLogController.add(
      TraceRouteLog(
        nodeNum: nodeNum,
        targetNode: nodeNum,
        sent: true,
        response: false,
        hopsTowards: 0,
        hopsBack: 0,
        originLatitude: originLat,
        originLongitude: originLon,
        targetLatitude: targetLat,
        targetLongitude: targetLon,
      ),
    );
  }

  /// Local-only: channel slots are stored on the directly-connected device.
  ///
  /// Remote channel changes require a separate admin session with the target
  /// node. This method intentionally uses [MeshPacketBuilder.localAdmin].
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

      final packet = MeshPacketBuilder.admin(
        myNodeNum: _myNodeNum!,
        targetNodeNum: _myNodeNum!,
        data: data,
        packetId: _generatePacketId(),
      );

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

  /// Local-only: reads channel config from the directly-connected device.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
  Future<void> getChannel(int index) async {
    try {
      AppLogging.protocol('Getting channel $index');

      final adminMsg = admin.AdminMessage()..getChannelRequest = index + 1;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = MeshPacketBuilder.admin(
        myNodeNum: _myNodeNum ?? 0,
        targetNodeNum: _myNodeNum ?? 0,
        data: data,
        packetId: _generatePacketId(),
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error getting channel: $e');
    }
  }

  /// Set owner config (name and/or user flags) in a single admin message.
  ///
  /// After calling this, the local device will save the config and reboot.
  /// The caller should expect a disconnection (for local target only).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  ///
  /// Note: Device role is NOT sent here — it belongs in Config.DeviceConfig
  /// (via [setDeviceConfig]), which is the only place the firmware reads it.
  /// This matches the official Meshtastic iOS app's approach.
  Future<void> setOwnerConfig({
    String? longName,
    String? shortName,
    bool? isUnmessagable,
    bool? isLicensed,
    AdminTarget? target,
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
        'isUnmessagable=${isUnmessagable ?? "(unchanged)"}, '
        'isLicensed=${isLicensed ?? "(unchanged)"}',
      );

      // Build User object with all provided fields
      // Note: role is intentionally NOT set here — it belongs in
      // Config.DeviceConfig and is sent via setDeviceConfig().
      final user = pb.User();
      if (trimmedLong != null) user.longName = trimmedLong;
      if (trimmedShort != null) user.shortName = trimmedShort;
      if (isUnmessagable != null) user.isUnmessagable = isUnmessagable;
      if (isLicensed != null) user.isLicensed = isLicensed;

      final adminMsg = admin.AdminMessage()..setOwner = user;

      final dest = _resolveTarget(target);
      final isRemote = dest != _myNodeNum;

      if (isRemote) {
        AppLogging.protocol(
          'RemoteAdmin: sending setOwner to target=${dest.toRadixString(16)} (mode=remote)',
        );
      }

      _applySessionPasskey(adminMsg, dest);

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer();

      final packet = MeshPacketBuilder.admin(
        myNodeNum: _myNodeNum!,
        targetNodeNum: dest,
        data: data,
        packetId: _generatePacketId(),
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
      AppLogging.protocol(
        'Owner config sent successfully${isRemote ? " to remote node" : ", device will reboot"}',
      );

      // Only update local node cache and identity store for local target.
      // Remote admin targets should not pollute the local cache.
      if (!isRemote) {
        final existingNode = _nodes[_myNodeNum!];
        if (existingNode != null) {
          final updatedNode = existingNode.copyWith(
            longName: trimmedLong ?? existingNode.longName,
            shortName: trimmedShort ?? existingNode.shortName,
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

        // Owner config writes also trigger device reboot.
        AppLogging.protocol(
          'setOwnerConfig: Emitting localConfigWrite — device reboot expected',
        );
        _localConfigWriteController.add(null);
      }
    } catch (e) {
      AppLogging.protocol('Error setting owner config: $e');
      rethrow;
    }
  }

  /// Local-only: region/frequency is a radio hardware setting on the
  /// directly-connected device.
  ///
  /// Also sets usePreset=true and hopLimit=3 to match Meshtastic defaults.
  /// Called during onboarding only. This method intentionally uses
  /// [MeshPacketBuilder.localAdmin].
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

      final packet = MeshPacketBuilder.admin(
        myNodeNum: _myNodeNum!,
        targetNodeNum: _myNodeNum!,
        data: data,
        packetId: _generatePacketId(),
      );

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

      final packet = MeshPacketBuilder.localAdmin(
        myNodeNum: _myNodeNum!,
        data: data,
        packetId: _generatePacketId(),
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error requesting channel $channelIndex: $e');
    }
  }

  /// Request the current LoRa configuration (for region).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getLoRaConfig({AdminTarget? target}) async {
    try {
      final dest = _resolveTarget(target);
      final isRemote = dest != _myNodeNum;
      AppLogging.protocol(
        'Requesting LoRa config${isRemote ? ' from node $dest' : ''}',
      );

      // Use ConfigType enum for LoRa config
      final adminMsg = admin.AdminMessage()
        ..getConfigRequest = admin.AdminMessage_ConfigType.LORA_CONFIG;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = MeshPacketBuilder.admin(
        myNodeNum: _myNodeNum ?? 0,
        targetNodeNum: dest,
        data: data,
        packetId: _generatePacketId(),
      );

      final toRadio = pb.ToRadio()..packet = packet;
      final bytes = toRadio.writeToBuffer();

      await _transport.send(_prepareForSend(bytes));
    } catch (e) {
      AppLogging.protocol('Error getting LoRa config: $e');
    }
  }

  /// Request the current Position configuration (GPS settings).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getPositionConfig({AdminTarget? target}) async {
    try {
      final dest = _resolveTarget(target);
      final isRemote = dest != _myNodeNum;
      AppLogging.protocol(
        'Requesting Position config${isRemote ? ' from node $dest' : ''}',
      );

      final adminMsg = admin.AdminMessage()
        ..getConfigRequest = admin.AdminMessage_ConfigType.POSITION_CONFIG;

      final data = pb.Data()
        ..portnum = pn.PortNum.ADMIN_APP
        ..payload = adminMsg.writeToBuffer()
        ..wantResponse = true;

      final packet = MeshPacketBuilder.admin(
        myNodeNum: _myNodeNum ?? 0,
        targetNodeNum: dest,
        data: data,
        packetId: _generatePacketId(),
      );

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

  /// Reboot the device after specified seconds (0 = immediate).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> reboot({int delaySeconds = 2, AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot reboot: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot reboot: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Rebooting device in $delaySeconds seconds${isRemote ? ' (remote node $dest)' : ''}',
    );

    final adminMsg = admin.AdminMessage()..rebootSeconds = delaySeconds;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Shutdown the device after specified seconds (0 = immediate).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> shutdown({int delaySeconds = 2, AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot shutdown: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot shutdown: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Shutting down device in $delaySeconds seconds${isRemote ? ' (remote node $dest)' : ''}',
    );

    final adminMsg = admin.AdminMessage()..shutdownSeconds = delaySeconds;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Factory reset the device configuration (keeps node DB).
  /// The delay parameter specifies seconds to wait before reset (default 5, like official app).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> factoryResetConfig({
    int delaySeconds = 5,
    AdminTarget? target,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot factory reset config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot factory reset config: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Factory resetting configuration (delay: ${delaySeconds}s)${isRemote ? ' on remote node $dest' : ''}',
    );

    final adminMsg = admin.AdminMessage()..factoryResetConfig = delaySeconds;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Factory reset the entire device (config + node DB).
  /// The delay parameter specifies seconds to wait before reset (default 5, like official app).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> factoryResetDevice({
    int delaySeconds = 5,
    AdminTarget? target,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot factory reset device: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot factory reset device: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Factory resetting entire device (delay: ${delaySeconds}s)${isRemote ? ' on remote node $dest' : ''}',
    );

    final adminMsg = admin.AdminMessage()..factoryResetDevice = delaySeconds;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Reset the node database (removes all learned nodes).
  /// This sends the reset command to the device and clears the local node cache.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> nodeDbReset({AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot reset node DB: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot reset node DB: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Resetting node database${isRemote ? ' on remote node $dest' : ''}',
    );

    final adminMsg = admin.AdminMessage()..nodedbReset = true;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    // Only clear local cache when targeting the local device.
    if (!isRemote) {
      await Future.delayed(const Duration(milliseconds: 500));
      clearNodes();
    }
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

  /// Enter DFU (Device Firmware Update) mode.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> enterDfuMode({AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot enter DFU mode: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot enter DFU mode: not connected');
    }

    final dest = _resolveTarget(target);

    AppLogging.protocol('Entering DFU mode');

    final adminMsg = admin.AdminMessage()..enterDfuModeRequest = true;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Request device metadata.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getDeviceMetadata({AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get metadata: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get metadata: not connected');
    }

    final dest = _resolveTarget(target);

    AppLogging.protocol('Requesting device metadata...');
    AppLogging.protocol('Requesting device metadata');

    final adminMsg = admin.AdminMessage()..getDeviceMetadataRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  // ============================================================================
  // NODE MANAGEMENT METHODS
  // ============================================================================

  /// Local-only: removes a node from the directly-connected device's
  /// node database.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    AppLogging.protocol('Node $nodeNum removal command sent to device');
  }

  /// Local-only: favorites are stored in the directly-connected device's
  /// node database.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    // Immediately reflect the change in the protocol-layer node cache so that
    // any subsequent stream updates emitted for this node carry isFavorite=true.
    // Without this, telemetry or position packets arriving before the device
    // ACKs the admin command would re-emit the node with the stale false value,
    // causing the stream listener in NodesNotifier to override the user's choice.
    if (_nodes.containsKey(nodeNum)) {
      _nodes[nodeNum] = _nodes[nodeNum]!.copyWith(isFavorite: true);
    }
  }

  /// Local-only: favorites are stored in the directly-connected device's
  /// node database.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    // Immediately reflect the removal in the protocol-layer node cache so that
    // subsequent stream updates carry isFavorite=false right away and do not
    // re-add the node to favourites before the device ACKs the admin command.
    if (_nodes.containsKey(nodeNum)) {
      _nodes[nodeNum] = _nodes[nodeNum]!.copyWith(isFavorite: false);
    }
  }

  /// Local-only: sets a fixed GPS position on the directly-connected device.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Local-only: removes the fixed GPS override on the directly-connected
  /// device, reverting to live GPS.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Local-only: the ignore list is stored on the directly-connected device.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Local-only: the ignore list is stored on the directly-connected device.
  ///
  /// This method intentionally uses [MeshPacketBuilder.localAdmin].
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Extract a plausible [DateTime] from a mesh packet's rxTime.
  ///
  /// Returns the rxTime-derived timestamp when it passes validation:
  /// - non-zero
  /// - after [_minPlausibleEpoch] (2020-01-01)
  /// - not more than [_maxFutureSlack] seconds into the future
  ///
  /// Falls back to [DateTime.now] with a diagnostic log otherwise.
  static DateTime _plausibleTimestamp(pb.MeshPacket packet) {
    if (packet.hasRxTime() && packet.rxTime > 0) {
      final rxEpoch = packet.rxTime; // seconds since 1970
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (rxEpoch >= _minPlausibleEpoch &&
          rxEpoch <= nowEpoch + _maxFutureSlack) {
        return DateTime.fromMillisecondsSinceEpoch(rxEpoch * 1000);
      }
      AppLogging.protocol(
        'Implausible rxTime=$rxEpoch from=${packet.from} '
        'packetId=${packet.id} — falling back to local time',
      );
    } else {
      AppLogging.protocol(
        'Missing rxTime from=${packet.from} packetId=${packet.id} '
        '— using local time (device may lack a time source)',
      );
    }
    return DateTime.now();
  }

  /// Local-only: set the device time to a specific Unix timestamp.
  ///
  /// Time sync operates on the directly-connected device only. Remote nodes
  /// sync time via the mesh protocol's existing time propagation mechanism.
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

    final packet = MeshPacketBuilder.localAdmin(
      myNodeNum: _myNodeNum!,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Local-only: delegates to [setTimeOnly] with the phone's current time.
  ///
  /// See [setTimeOnly] for rationale on why time sync is local-only.
  Future<void> syncTime() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await setTimeOnly(timestamp);
  }

  // ============================================================================
  // HAM RADIO MODE
  // ============================================================================

  /// Set HAM radio mode with call sign.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> setHamMode({
    required String callSign,
    int txPower = 0,
    double frequency = 0.0,
    AdminTarget? target,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set HAM mode: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set HAM mode: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Setting HAM mode: callSign=$callSign${isRemote ? ' on remote node $dest' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        'RemoteAdmin: sending setHamMode to target=${dest.toRadixString(16)} (mode=remote)',
      );
    }

    final hamParams = admin.HamParameters()
      ..callSign = callSign
      ..txPower = txPower
      ..frequency = frequency;

    final adminMsg = admin.AdminMessage()..setHamMode = hamParams;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  // ============================================================================
  // CONFIGURATION METHODS
  // ============================================================================

  /// Get device configuration by type.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getConfig(
    admin.AdminMessage_ConfigType configType, {
    AdminTarget? target,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get config: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Requesting config: ${configType.name}${isRemote ? ' from remote node $dest' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Requesting ${configType.name} from ${dest.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..getConfigRequest = configType;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set device configuration.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> setConfig(config_pb.Config config, {AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set config: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'setConfig: Setting config${isRemote ? ' on remote node $dest' : ''} — '
      'hasDevice=${config.hasDevice()}, hasLora=${config.hasLora()}, '
      'hasPosition=${config.hasPosition()}, hasPower=${config.hasPower()}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Setting config on ${dest.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..setConfig = config;
    _applySessionPasskey(adminMsg, dest);
    final adminBytes = adminMsg.writeToBuffer();

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminBytes;

    final packetId = _generatePacketId();
    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: packetId,
    );

    final toRadio = pb.ToRadio()..packet = packet;
    final outBytes = _prepareForSend(toRadio.writeToBuffer());

    AppLogging.protocol(
      'setConfig: sending admin message — '
      'packetId=$packetId, adminPayload=${adminBytes.length} bytes, '
      'toRadio=${outBytes.length} bytes, from=${_myNodeNum!}, to=$dest',
    );

    await _transport.send(outBytes);

    AppLogging.protocol(
      'setConfig: transport.send completed — packet $packetId delivered to BLE stack',
    );

    // Optimistically update the local cache and emit to streams so config
    // screens show the saved values immediately when navigating back.
    // The device will reboot after config changes, dropping the BLE
    // connection before it can send back a config response. Without this
    // update the cache holds stale pre-save values.
    // Only update for local node config — remote admin targets should not
    // pollute the local cache.
    if (!isRemote) {
      _applySavedConfigToCache(config);

      // Notify listeners that a config write to the local node occurred.
      // The device will reboot to apply the change, so the reconnect flow
      // should enter recovery mode (increased patience + logical matching).
      AppLogging.protocol(
        'setConfig: Emitting localConfigWrite — device reboot expected',
      );
      _localConfigWriteController.add(null);
    }
  }

  /// Applies a just-saved config to the local cache and emits to streams.
  void _applySavedConfigToCache(config_pb.Config config) {
    AppLogging.protocol(
      '_applySavedConfigToCache: hasDevice=${config.hasDevice()}, '
      'hasLora=${config.hasLora()}, hasPosition=${config.hasPosition()}',
    );
    if (config.hasDevice()) {
      AppLogging.protocol(
        '_applySavedConfigToCache: caching device config — '
        'role=${config.device.role.name} (value=${config.device.role.value}), '
        'emitting to deviceConfigController',
      );
      _currentDeviceConfig = config.device;
      _deviceConfigController.add(config.device);
    }
    if (config.hasPosition()) {
      _currentPositionConfig = config.position;
      _positionConfigController.add(config.position);
    }
    if (config.hasLora()) {
      _currentRegion = config.lora.region;
      _currentLoraConfig = config.lora;
      _regionController.add(config.lora.region);
      _loraConfigController.add(config.lora);
    }
    if (config.hasDisplay()) {
      _currentDisplayConfig = config.display;
      _displayConfigController.add(config.display);
    }
    if (config.hasPower()) {
      _currentPowerConfig = config.power;
      _powerConfigController.add(config.power);
    }
    if (config.hasNetwork()) {
      _currentNetworkConfig = config.network;
      _networkConfigController.add(config.network);
    }
    if (config.hasBluetooth()) {
      _currentBluetoothConfig = config.bluetooth;
      _bluetoothConfigController.add(config.bluetooth);
    }
    if (config.hasSecurity()) {
      _currentSecurityConfig = config.security;
      _securityConfigController.add(config.security);
    }
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
    AdminTarget? target,
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
    await setConfig(config, target: target);
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
    AdminTarget? target,
  }) async {
    AppLogging.protocol(
      'setDeviceConfig called \u2014 role=${role.name} (value=${role.value}), '
      'rebroadcastMode=${rebroadcastMode.name}, '
      'serialEnabled=$serialEnabled, '
      'nodeInfoBroadcastSecs=$nodeInfoBroadcastSecs, '
      'ledHeartbeatDisabled=$ledHeartbeatDisabled, '
      'target=$target',
    );

    // Read-modify-write: clone the device's cached config so we preserve
    // any firmware fields we don't expose in the UI.  Building a brand-new
    // Config_DeviceConfig from scratch zeroes out unknown fields, which can
    // cause the firmware to silently reject or mishandle the config.
    //
    // IMPORTANT: only use the cached config for LOCAL targets.
    // _currentDeviceConfig always holds the LOCAL device's config (only
    // updated when isLocalResponse is true in _handleAdminMessage).
    // Cloning it for a remote target would contaminate the remote device
    // with the local device's internal field values.
    final isLocalTarget = target == null || target.isLocal;
    final config_pb.Config_DeviceConfig deviceConfig;
    if (isLocalTarget && _currentDeviceConfig != null) {
      // Clone by round-tripping through serialization — this preserves
      // every field the device sent us, including ones our generated
      // protobuf doesn't know about (unknown fields).
      deviceConfig = config_pb.Config_DeviceConfig.fromBuffer(
        _currentDeviceConfig!.writeToBuffer(),
      );
      AppLogging.protocol(
        'setDeviceConfig: cloned local config '
        '(${_currentDeviceConfig!.writeToBuffer().length} bytes), '
        'existing role=${deviceConfig.role.name}',
      );
    } else {
      deviceConfig = config_pb.Config_DeviceConfig();
      AppLogging.protocol(
        'setDeviceConfig: ${isLocalTarget ? 'no cached config' : 'remote target'} '
        '— building from scratch',
      );
    }

    // Now apply the user's changes on top of the cloned config
    deviceConfig
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

    // Verify the protobuf was built correctly before sending
    AppLogging.protocol(
      'setDeviceConfig proto verification — '
      'deviceConfig.role=${deviceConfig.role.name} (value=${deviceConfig.role.value}), '
      'deviceConfig bytes=${deviceConfig.writeToBuffer().length}',
    );

    final config = config_pb.Config()..device = deviceConfig;

    AppLogging.protocol(
      'setDeviceConfig Config wrapper — '
      'config.hasDevice()=${config.hasDevice()}, '
      'config.device.role=${config.device.role.name}, '
      'total config bytes=${config.writeToBuffer().length}',
    );

    await setConfig(config, target: target);

    AppLogging.protocol(
      'setDeviceConfig: setConfig completed \u2014 admin message sent to device',
    );

    // Update local node cache with the new role so the UI reflects it
    // immediately (the device will reboot before it can send a response).
    if (target == null || target.isLocal) {
      final nodeNum = _myNodeNum;
      if (nodeNum != null) {
        final existingNode = _nodes[nodeNum];
        if (existingNode != null) {
          final updatedNode = existingNode.copyWith(role: role.name);
          _nodes[nodeNum] = updatedNode;
          _nodeController.add(updatedNode);
          AppLogging.protocol(
            'Updated local node cache with new device role: ${role.name}',
          );
        }
      }
    }
  }

  /// Set position configuration
  Future<void> setPositionConfig({
    required int positionBroadcastSecs,
    required bool positionBroadcastSmartEnabled,
    required bool fixedPosition,
    required config_pb.Config_PositionConfig_GpsMode gpsMode,
    required int gpsUpdateInterval,
    int broadcastSmartMinimumDistance = 50,
    int broadcastSmartMinimumIntervalSecs = 30,
    int positionFlags = 811,
    int rxGpio = 0,
    int txGpio = 0,
    int gpsEnGpio = 0,
    AdminTarget? target,
  }) async {
    AppLogging.protocol(
      'Setting position config: gpsMode=$gpsMode, '
      'broadcastSecs=$positionBroadcastSecs, '
      'smartEnabled=$positionBroadcastSmartEnabled, '
      'gpsUpdateInterval=$gpsUpdateInterval, '
      'smartMinDistance=$broadcastSmartMinimumDistance, '
      'smartMinInterval=$broadcastSmartMinimumIntervalSecs',
    );

    final posConfig = config_pb.Config_PositionConfig()
      ..positionBroadcastSecs = positionBroadcastSecs
      ..positionBroadcastSmartEnabled = positionBroadcastSmartEnabled
      ..fixedPosition = fixedPosition
      ..gpsMode = gpsMode
      ..gpsEnabled = gpsMode == config_pb.Config_PositionConfig_GpsMode.ENABLED
      ..gpsUpdateInterval = gpsUpdateInterval
      ..broadcastSmartMinimumDistance = broadcastSmartMinimumDistance
      ..broadcastSmartMinimumIntervalSecs = broadcastSmartMinimumIntervalSecs
      ..positionFlags = positionFlags
      ..rxGpio = rxGpio
      ..txGpio = txGpio
      ..gpsEnGpio = gpsEnGpio;

    final config = config_pb.Config()..position = posConfig;
    await setConfig(config, target: target);
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
    AdminTarget? target,
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
    await setConfig(config, target: target);
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
    bool useLongNodeName = false,
    bool enableMessageBubbles = false,
    AdminTarget? target,
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
      ..compassNorthTop = compassNorthTop
      ..useLongNodeName = useLongNodeName
      ..enableMessageBubbles = enableMessageBubbles;

    final config = config_pb.Config()..display = displayConfig;
    await setConfig(config, target: target);
  }

  /// Set Bluetooth configuration
  Future<void> setBluetoothConfig({
    required bool enabled,
    required config_pb.Config_BluetoothConfig_PairingMode mode,
    required int fixedPin,
    AdminTarget? target,
  }) async {
    AppLogging.protocol('Setting Bluetooth config');

    final btConfig = config_pb.Config_BluetoothConfig()
      ..enabled = enabled
      ..mode = mode
      ..fixedPin = fixedPin;

    final config = config_pb.Config()..bluetooth = btConfig;
    await setConfig(config, target: target);
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
    AdminTarget? target,
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
    await setConfig(config, target: target);
  }

  /// Set security configuration
  Future<void> setSecurityConfig({
    required bool isManaged,
    required bool serialEnabled,
    required bool debugLogEnabled,
    required bool adminChannelEnabled,
    List<int> privateKey = const [],
    List<List<int>> adminKeys = const [],
    AdminTarget? target,
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
    await setConfig(config, target: target);
  }

  // ============================================================================
  // MODULE CONFIGURATION METHODS
  // ============================================================================

  /// Get module configuration by type.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getModuleConfig(
    admin.AdminMessage_ModuleConfigType moduleType, {
    AdminTarget? target,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get module config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get module config: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Requesting module config: ${moduleType.name}${isRemote ? ' from remote node $dest' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Requesting ${moduleType.name} from ${dest.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..getModuleConfigRequest = moduleType;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set module configuration.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> setModuleConfig(
    module_pb.ModuleConfig moduleConfig, {
    AdminTarget? target,
  }) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set module config: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set module config: not connected');
    }

    final dest = _resolveTarget(target);
    final isRemote = dest != _myNodeNum;

    AppLogging.protocol(
      'Setting module config${isRemote ? ' on remote node $dest' : ''}',
    );
    if (isRemote) {
      AppLogging.protocol(
        '🔧 Remote Admin: Setting module config on ${dest.toRadixString(16)}',
      );
    }

    final adminMsg = admin.AdminMessage()..setModuleConfig = moduleConfig;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));

    // Optimistically update the local cache (same rationale as setConfig --
    // the device reboots before it can send back a config response).
    if (!isRemote) {
      _applySavedModuleConfigToCache(moduleConfig);

      // Module config writes also trigger device reboot.
      AppLogging.protocol(
        'setModuleConfig: Emitting localConfigWrite — device reboot expected',
      );
      _localConfigWriteController.add(null);
    }
  }

  /// Applies a just-saved module config to the local cache and emits to streams.
  void _applySavedModuleConfigToCache(module_pb.ModuleConfig moduleConfig) {
    if (moduleConfig.hasMqtt()) {
      _currentMqttConfig = moduleConfig.mqtt;
      _mqttConfigController.add(moduleConfig.mqtt);
    }
    if (moduleConfig.hasTelemetry()) {
      _currentTelemetryConfig = moduleConfig.telemetry;
      _telemetryConfigController.add(moduleConfig.telemetry);
    }
    if (moduleConfig.hasPaxcounter()) {
      _currentPaxCounterConfig = moduleConfig.paxcounter;
      _paxCounterConfigController.add(moduleConfig.paxcounter);
    }
    if (moduleConfig.hasAmbientLighting()) {
      _currentAmbientLightingConfig = moduleConfig.ambientLighting;
      _ambientLightingConfigController.add(moduleConfig.ambientLighting);
    }
    if (moduleConfig.hasSerial()) {
      _currentSerialConfig = moduleConfig.serial;
      _serialConfigController.add(moduleConfig.serial);
    }
    if (moduleConfig.hasStoreForward()) {
      _currentStoreForwardConfig = moduleConfig.storeForward;
      _storeForwardConfigController.add(moduleConfig.storeForward);
    }
    if (moduleConfig.hasDetectionSensor()) {
      _currentDetectionSensorConfig = moduleConfig.detectionSensor;
      _detectionSensorConfigController.add(moduleConfig.detectionSensor);
    }
    if (moduleConfig.hasRangeTest()) {
      _currentRangeTestConfig = moduleConfig.rangeTest;
      _rangeTestConfigController.add(moduleConfig.rangeTest);
    }
    if (moduleConfig.hasExternalNotification()) {
      _currentExternalNotificationConfig = moduleConfig.externalNotification;
      _externalNotificationConfigController.add(
        moduleConfig.externalNotification,
      );
    }
    if (moduleConfig.hasCannedMessage()) {
      _currentCannedMessageConfig = moduleConfig.cannedMessage;
      _cannedMessageConfigController.add(moduleConfig.cannedMessage);
    }
    if (moduleConfig.hasTrafficManagement()) {
      _currentTrafficManagementConfig = moduleConfig.trafficManagement;
      _trafficManagementConfigController.add(moduleConfig.trafficManagement);
    }
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
    AdminTarget? target,
  }) async {
    final isRemote = target is RemoteAdminTarget;
    AppLogging.protocol(
      'Setting MQTT config${isRemote ? ' on remote node $target' : ''}',
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
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
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
    await setModuleConfig(moduleConfig, target: target);
  }

  /// Set traffic management module configuration (v2.7.19)
  Future<void> setTrafficManagementConfig({
    required bool enabled,
    required bool positionDedupEnabled,
    required int positionPrecisionBits,
    required int positionMinIntervalSecs,
    required bool nodeinfoDirectResponse,
    required int nodeinfoDirectResponseMaxHops,
    required bool rateLimitEnabled,
    required int rateLimitWindowSecs,
    required int rateLimitMaxPackets,
    required bool dropUnknownEnabled,
    required int unknownPacketThreshold,
    required bool exhaustHopTelemetry,
    required bool exhaustHopPosition,
    required bool routerPreserveHops,
    AdminTarget? target,
  }) async {
    AppLogging.protocol('Setting traffic management config');

    final tmConfig = module_pb.ModuleConfig_TrafficManagementConfig()
      ..enabled = enabled
      ..positionDedupEnabled = positionDedupEnabled
      ..positionPrecisionBits = positionPrecisionBits
      ..positionMinIntervalSecs = positionMinIntervalSecs
      ..nodeinfoDirectResponse = nodeinfoDirectResponse
      ..nodeinfoDirectResponseMaxHops = nodeinfoDirectResponseMaxHops
      ..rateLimitEnabled = rateLimitEnabled
      ..rateLimitWindowSecs = rateLimitWindowSecs
      ..rateLimitMaxPackets = rateLimitMaxPackets
      ..dropUnknownEnabled = dropUnknownEnabled
      ..unknownPacketThreshold = unknownPacketThreshold
      ..exhaustHopTelemetry = exhaustHopTelemetry
      ..exhaustHopPosition = exhaustHopPosition
      ..routerPreserveHops = routerPreserveHops;

    final moduleConfig = module_pb.ModuleConfig()..trafficManagement = tmConfig;
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
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
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
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
    await setModuleConfig(moduleConfig, target: target);
  }

  /// Set Store & Forward module configuration
  Future<void> setStoreForwardConfig({
    bool? enabled,
    bool? heartbeat,
    int? records,
    int? historyReturnMax,
    int? historyReturnWindow,
    bool? isServer,
    AdminTarget? target,
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
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
  }) async {
    AppLogging.protocol('Setting range test config');

    final rtConfig = module_pb.ModuleConfig_RangeTestConfig();
    if (enabled != null) rtConfig.enabled = enabled;
    if (sender != null) rtConfig.sender = sender;
    if (save != null) rtConfig.save = save;

    final moduleConfig = module_pb.ModuleConfig()..rangeTest = rtConfig;
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
  }) async {
    AppLogging.protocol('Setting ambient lighting config');

    final alConfig = module_pb.ModuleConfig_AmbientLightingConfig();
    alConfig.ledState = ledState;
    alConfig.red = red;
    alConfig.green = green;
    alConfig.blue = blue;
    if (current != null) alConfig.current = current;

    final moduleConfig = module_pb.ModuleConfig()..ambientLighting = alConfig;
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
  }) async {
    AppLogging.protocol('Setting PAX counter config');

    final paxConfig = module_pb.ModuleConfig_PaxcounterConfig();
    if (enabled != null) paxConfig.enabled = enabled;
    if (updateInterval != null) {
      paxConfig.paxcounterUpdateInterval = updateInterval;
    }

    final moduleConfig = module_pb.ModuleConfig()..paxcounter = paxConfig;
    await setModuleConfig(moduleConfig, target: target);
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
    AdminTarget? target,
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
    await setModuleConfig(moduleConfig, target: target);
  }

  // ============================================================================
  // CANNED MESSAGES & RINGTONE
  // ============================================================================

  /// Get canned messages.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getCannedMessages({AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get canned messages: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get canned messages: not connected');
    }

    final dest = _resolveTarget(target);

    AppLogging.protocol('Requesting canned messages');

    final adminMsg = admin.AdminMessage()
      ..getCannedMessageModuleMessagesRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set canned messages (pipe-separated list).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> setCannedMessages(String messages, {AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set canned messages: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set canned messages: not connected');
    }

    final dest = _resolveTarget(target);

    AppLogging.protocol('Setting canned messages');

    final adminMsg = admin.AdminMessage()
      ..setCannedMessageModuleMessages = messages;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Get device ringtone.
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> getRingtone({AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot get ringtone: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot get ringtone: not connected');
    }

    final dest = _resolveTarget(target);

    AppLogging.protocol('Requesting ringtone');

    final adminMsg = admin.AdminMessage()..getRingtoneRequest = true;

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer()
      ..wantResponse = true;

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

    final toRadio = pb.ToRadio()..packet = packet;
    await _transport.send(_prepareForSend(toRadio.writeToBuffer()));
  }

  /// Set device ringtone (RTTTL format).
  ///
  /// Pass [target] to specify local or remote device. Defaults to local.
  Future<void> setRingtone(String rtttl, {AdminTarget? target}) async {
    if (_myNodeNum == null) {
      throw StateError('Cannot set ringtone: device not ready');
    }
    if (!_transport.isConnected) {
      throw StateError('Cannot set ringtone: not connected');
    }

    final dest = _resolveTarget(target);

    AppLogging.protocol('Setting ringtone');

    final adminMsg = admin.AdminMessage()..setRingtoneMessage = rtttl;
    _applySessionPasskey(adminMsg, dest);

    final data = pb.Data()
      ..portnum = pn.PortNum.ADMIN_APP
      ..payload = adminMsg.writeToBuffer();

    final packet = MeshPacketBuilder.admin(
      myNodeNum: _myNodeNum!,
      targetNodeNum: dest,
      data: data,
      packetId: _generatePacketId(),
    );

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
      'heltec meshpocket': 'Heltec MeshPocket',
      'heltec mesh pocket': 'Heltec MeshPocket',
      'meshpocket': 'Heltec MeshPocket',
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
        return 'Tracker T1000-E'; // lint-allow: hardcoded-string
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
      'HELTEC_MESH_POCKET': 'Heltec MeshPocket',
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
    _adminAckTracker.cancelAll();
    _adminSessions.clear();
    await _dataSubscription?.cancel();
    await _messageController.close();
    await _nodeController.close();
    await _channelController.close();
    await _errorController.close();
    await _signalController.close();
    await _fileTransferController.close();
    await _deliveryController.close();
    await _regionController.close();
    await _clientNotificationController.close();
    await _userConfigController.close();
    await _traceRouteLogController.close();
    await _meshTelemetryController.close();
    await _mqttClientProxyMessageController.close();
    await _localConfigWriteController.close();
  }
}

/// Phases of the two-step connect handshake. See `_nonceInitialConfig` and
/// `_nonceQueueDrain` for the nonces exchanged in each phase.
enum _HandshakePhase {
  idle,
  awaitingInitialConfig,
  awaitingQueueDrain,
  complete,
}
