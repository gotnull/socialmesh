// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'presence_confidence.dart';
import '../core/health/node_health.dart';
import '../features/nodes/node_display_name_resolver.dart';
import '../utils/text_sanitizer.dart';

/// Message status enum
enum MessageStatus {
  pending, // Message being sent
  sent, // Message sent to radio — awaiting confirmation
  delivered, // Message confirmed (ACK received)
  failed, // Terminal send failure (routing error, PKI, etc.)
  unconfirmed, // Sent but no ACK within the timeout window
  retrying, // Auto-retry in progress
}

/// Routing error codes from Meshtastic protocol
enum RoutingError {
  none(0, 'Delivered'),
  noRoute(1, 'No route to destination'),
  gotNak(2, 'Received NAK from relay'),
  timeout(3, 'Delivery timed out'),
  noInterface(4, 'No suitable interface'),
  maxRetransmit(5, 'Max retransmissions reached'),
  noChannel(6, 'Channel not available'),
  tooLarge(7, 'Message too large'),
  noResponse(8, 'No response from destination'),
  dutyCycleLimit(9, 'Duty cycle limit exceeded'),
  badRequest(32, 'Invalid request'),
  notAuthorized(33, 'Not authorized'),
  pkiFailed(34, 'PKI encryption failed'),
  pkiUnknownPubkey(35, 'Unknown public key'),
  adminBadSessionKey(36, 'Invalid admin session key'),
  adminPublicKeyUnauthorized(37, 'Admin key not authorized'),
  rateLimitExceeded(38, 'Rate limit exceeded');

  final int code;
  final String message;

  const RoutingError(this.code, this.message);

  static RoutingError fromCode(int code) {
    return RoutingError.values.firstWhere(
      (e) => e.code == code,
      orElse: () => RoutingError.none,
    );
  }

  bool get isSuccess => this == RoutingError.none;
  bool get isRetryable =>
      this == RoutingError.timeout ||
      this == RoutingError.maxRetransmit ||
      this == RoutingError.noRoute ||
      this == RoutingError.dutyCycleLimit;

  /// Returns true if this error is related to PKI/encryption key issues
  /// These errors can often be fixed by requesting fresh user info
  bool get isPkiRelated =>
      this == RoutingError.pkiFailed ||
      this == RoutingError.pkiUnknownPubkey ||
      this == RoutingError.noChannel;

  /// Returns a helpful suggestion for fixing this error
  String? get fixSuggestion {
    switch (this) {
      case RoutingError.pkiFailed:
      case RoutingError.pkiUnknownPubkey:
      case RoutingError.noChannel:
        return 'Try "Request User Info" to refresh encryption keys'; // lint-allow: hardcoded-string
      case RoutingError.noRoute:
        return 'Node may be out of range or offline'; // lint-allow: hardcoded-string
      case RoutingError.timeout:
      case RoutingError.maxRetransmit:
        return 'Network congestion, try again later'; // lint-allow: hardcoded-string
      case RoutingError.dutyCycleLimit:
        return 'Radio duty cycle limit reached, wait a moment'; // lint-allow: hardcoded-string
      default:
        return null;
    }
  }
}

/// Source of where a message originated
enum MessageSource {
  /// Manually typed by user in the messaging screen
  manual,

  /// Sent via automation rule
  automation,

  /// Sent via Siri Shortcuts / App Intents
  siri,

  /// Sent as a notification reaction (emoji response)
  reaction,

  /// Sent as a tapback/emoji reaction
  tapback,

  /// Unknown/legacy source
  unknown,
}

/// A telemetry metric type that can be requested on demand from a node.
///
/// Each variant maps to a Meshtastic telemetry sub-message. A request sets
/// the matching empty sub-message with `wantResponse = true`; the node's
/// corresponding telemetry module replies with its current values.
enum TelemetryRequestType {
  /// Battery, voltage, channel utilization, air-util TX, uptime.
  device,

  /// Temperature, humidity, pressure, IAQ, lux, wind, rainfall, soil.
  environment,

  /// PM particulates and CO2.
  airQuality,
}

/// Message model
class Message {
  final String id;
  final int from;
  final int to;
  final String text;
  final DateTime timestamp;
  final int? channel;
  final bool sent;
  final bool received;
  final bool acked;

  /// Strength of the acknowledgement for DM outgoing messages, mirroring the
  /// official Meshtastic companion app's `realACK` distinction.
  ///
  /// - `null`: unknown / legacy — row was written before the column existed,
  ///   or the message has not yet received any ack.
  /// - `false`: an implicit mesh ack was received (proof that *some* node on
  ///   the mesh observed the packet, but not that the intended recipient
  ///   processed it). Presented as a weaker "acknowledged by another node"
  ///   state in the UI.
  /// - `true`: an explicit ack was received from the intended DM recipient
  ///   (the authoritative delivery confirmation).
  ///
  /// Forward-only — the provider layer never downgrades `true → false`.
  final bool? realAck;
  final MessageStatus status;
  final String? errorMessage;
  final RoutingError? routingError;
  final int? packetId; // Meshtastic packet ID for tracking delivery
  final MessageSource source; // Where the message originated from

  // --- Retry / confirmation tracking ---

  /// When this message was first dispatched to the radio (epoch ms).
  /// Set when status transitions to [MessageStatus.sent].  Null for
  /// channel/broadcast messages (they never get ACKs) and for legacy
  /// persisted messages created before this feature was added.
  final DateTime? sentAt;

  /// Timestamp of the most recent resend attempt.
  final DateTime? lastAttemptAt;

  /// Number of resend attempts made (manual + auto-retry).
  final int retryCount;

  /// Whether bounded auto-retry is enabled for this message.
  final bool autoRetryEnabled;

  /// Meshtastic replyId — the packet ID of the message this is replying to.
  /// Used for tapback reactions and threaded replies.
  final int? replyId;

  /// Whether this message is an emoji tapback (data.emoji != 0 in protobuf).
  final bool isEmoji;

  /// Whether the user has read this message (opened the conversation).
  /// Only meaningful for incoming messages (received == true).
  final bool read;

  /// Hop count at reception: hopStart - hopLimit.
  /// 0 = direct (no relay), null = unknown (sent messages or legacy data).
  final int? hopCount;

  /// Received SNR (Signal-to-Noise Ratio) in dB at the gateway node.
  /// Higher is better. Typical range: -20 to +15. null if unavailable.
  final double? rxSnr;

  /// Received RSSI (Received Signal Strength Indicator) in dBm.
  /// Typical range: -120 (weak) to -40 (strong). null if unavailable.
  final int? rxRssi;

  /// Whether this packet passed through an MQTT gateway. true = MQTT,
  /// false = RF-only, null = unknown (legacy data or sent messages).
  final bool? viaMqtt;

  // Cached sender info - populated when message is received/created
  // This ensures sender info is always available even if node hasn't loaded yet
  final String? senderLongName;
  final String? senderShortName;
  final int? senderAvatarColor;

  Message({
    String? id,
    required this.from,
    required this.to,
    required this.text,
    DateTime? timestamp,
    this.channel,
    this.sent = false,
    this.received = false,
    this.acked = false,
    this.realAck,
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.routingError,
    this.packetId,
    this.source = MessageSource.unknown,
    this.replyId,
    this.isEmoji = false,
    this.read = false,
    this.hopCount,
    this.rxSnr,
    this.rxRssi,
    this.viaMqtt,
    this.senderLongName,
    this.senderShortName,
    this.senderAvatarColor,
    this.sentAt,
    this.lastAttemptAt,
    this.retryCount = 0,
    this.autoRetryEnabled = false,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Message copyWith({
    String? id,
    int? from,
    int? to,
    String? text,
    DateTime? timestamp,
    int? channel,
    bool? sent,
    bool? received,
    bool? acked,
    bool? realAck,
    bool clearRealAck = false,
    MessageStatus? status,
    String? errorMessage,
    RoutingError? routingError,
    int? packetId,
    MessageSource? source,
    int? replyId,
    bool? isEmoji,
    bool? read,
    int? hopCount,
    double? rxSnr,
    int? rxRssi,
    bool? viaMqtt,
    String? senderLongName,
    String? senderShortName,
    int? senderAvatarColor,
    DateTime? sentAt,
    bool clearSentAt = false,
    DateTime? lastAttemptAt,
    bool clearLastAttemptAt = false,
    int? retryCount,
    bool? autoRetryEnabled,
  }) {
    return Message(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      channel: channel ?? this.channel,
      sent: sent ?? this.sent,
      received: received ?? this.received,
      acked: acked ?? this.acked,
      realAck: clearRealAck ? null : realAck ?? this.realAck,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      routingError: routingError ?? this.routingError,
      packetId: packetId ?? this.packetId,
      source: source ?? this.source,
      replyId: replyId ?? this.replyId,
      isEmoji: isEmoji ?? this.isEmoji,
      read: read ?? this.read,
      hopCount: hopCount ?? this.hopCount,
      rxSnr: rxSnr ?? this.rxSnr,
      rxRssi: rxRssi ?? this.rxRssi,
      viaMqtt: viaMqtt ?? this.viaMqtt,
      senderLongName: senderLongName ?? this.senderLongName,
      senderShortName: senderShortName ?? this.senderShortName,
      senderAvatarColor: senderAvatarColor ?? this.senderAvatarColor,
      sentAt: clearSentAt ? null : sentAt ?? this.sentAt,
      lastAttemptAt: clearLastAttemptAt
          ? null
          : lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      autoRetryEnabled: autoRetryEnabled ?? this.autoRetryEnabled,
    );
  }

  /// Get the sender's display name from cached info or fallback to node number
  String get senderDisplayName {
    if (senderLongName != null && senderLongName!.isNotEmpty) {
      return sanitizeExternalText(senderLongName!);
    }
    if (senderShortName != null && senderShortName!.isNotEmpty) {
      return sanitizeExternalText(senderShortName!);
    }
    return NodeDisplayNameResolver.defaultName(from);
  }

  /// Get the sender's avatar name from cached info or fallback to hex ID
  String get senderAvatarName {
    if (senderShortName != null && senderShortName!.isNotEmpty) {
      return sanitizeExternalText(senderShortName!);
    }
    if (senderLongName != null && senderLongName!.isNotEmpty) {
      final sanitized = sanitizeExternalText(senderLongName!);
      return sanitized.substring(0, sanitized.length.clamp(0, 4));
    }
    return NodeDisplayNameResolver.shortHex(from);
  }

  bool get isBroadcast => to == 0xFFFFFFFF;
  bool get isDirect => !isBroadcast;
  bool get isCanonicalTapback => isEmoji && replyId != null;
  bool get isFailed => status == MessageStatus.failed;
  bool get isPending => status == MessageStatus.pending;
  bool get isUnconfirmed => status == MessageStatus.unconfirmed;
  bool get isRetrying => status == MessageStatus.retrying;
  bool get isRetryable => routingError?.isRetryable ?? false;

  /// Generate a deterministic message ID from mesh packet identity.
  ///
  /// Uses the firmware-assigned [packetId] and [fromNode] to produce a
  /// stable identifier that is identical regardless of which ingest path
  /// (foreground ProtocolService or BackgroundMessageProcessor) creates
  /// the [Message] object.  This eliminates the TOCTOU race where both
  /// paths generate different random UUIDs for the same physical packet.
  ///
  /// Format: `pkt-<fromHex>-<packetIdHex>` — human-readable, cannot
  /// collide with UUID v4 or SHA1 IDs from push notifications.
  static String deterministicId({
    required int packetId,
    required int fromNode,
  }) {
    final fromHex = fromNode.toRadixString(16);
    final pktHex = packetId.toRadixString(16);
    return 'pkt-$fromHex-$pktHex'; // lint-allow: hardcoded-string
  }

  /// Returns true when a manual Resend action should be offered: the message
  /// is a DM from us, is in an unconfirmed/failed state, and is not currently
  /// being retried automatically.
  bool get canResend => isDirect && (isUnconfirmed || isFailed) && !isRetrying;

  /// Returns true when the user can enable bounded auto-retry.
  bool get canEnableAutoRetry =>
      isDirect && (isUnconfirmed || isFailed) && !autoRetryEnabled;

  /// Returns true when the user can stop an active auto-retry.
  bool get canStopAutoRetry => autoRetryEnabled || isRetrying;

  @override
  String toString() => 'Message(from: $from, to: $to, text: $text)';
}

/// Message delivery status update from the mesh
class MessageDeliveryUpdate {
  final int packetId;
  final bool delivered;
  final RoutingError? error;

  /// Whether the ack was an explicit reply from the intended recipient
  /// (`true`) or an implicit mesh ack (`false`). Meaningful only when
  /// [delivered] is true; ignored on failure. Mirrors `realACK` in the
  /// official Meshtastic iOS companion app.
  final bool realAck;

  MessageDeliveryUpdate({
    required this.packetId,
    required this.delivered,
    this.error,
    this.realAck = false,
  });

  bool get isSuccess =>
      delivered && (error == null || error == RoutingError.none);
  bool get isFailed =>
      !delivered || (error != null && error != RoutingError.none);
}

/// Node in the mesh network
class MeshNode {
  final int nodeNum;
  final String? longName;
  final String? shortName;
  final String? userId;
  final double? latitude;
  final double? longitude;
  final int? altitude;
  final DateTime? lastHeard;
  final DateTime? firstHeard; // When node was first discovered
  final int? snr;
  final int? rssi;
  final int? batteryLevel;
  final double? temperature; // Temperature in Celsius from environment metrics
  final double? humidity; // Relative humidity percentage
  final String? firmwareVersion;
  final String? hardwareModel;
  final int? hwModelId; // Raw HardwareModel protobuf enum value
  final String? role; // 'CLIENT', 'ROUTER', etc.
  final double? distance; // distance in meters
  final bool isFavorite;
  final bool isIgnored; // Whether node is muted/ignored (local app setting)
  final bool
  isMuted; // Whether node is muted on the device (device-side setting)
  final int? avatarColor; // Color value for avatar
  final bool hasPublicKey; // Whether node has encryption key set

  /// Raw curve25519 public key bytes from the node's last NodeInfo.
  ///
  /// Mirrors `UserEntity.publicKey` in the official Meshtastic iOS app
  /// (`meshtastic-ios/Meshtastic/Persistence/UpdateCoreData.swift:381`).
  /// When non-empty, outbound DMs to this node attach `pkiEncrypted=true`
  /// + `publicKey=<bytes>` on the MeshPacket so the local firmware encrypts
  /// the payload with PKI rather than the channel PSK
  /// (`meshtastic-ios/Meshtastic/Accessory/Accessory Manager/AccessoryManager+ToRadio.swift:327-329`).
  /// `null` or empty when the node has not advertised a public key.
  final List<int>? publicKey;

  /// The local channel index on which this node was last heard.
  ///
  /// Field 6 in the firmware's `meshtastic.NodeInfo` proto — quote from
  /// the proto comment: "local channel index we heard that node on.
  /// Only populated if its not the default channel." `null` means the
  /// firmware did not include it (i.e. the node was last heard on the
  /// default Primary channel, or on a channel hash that didn't resolve
  /// to a local index).
  ///
  /// Diagnostic value: when an outbound DM gets a `NO_CHANNEL` NAK, the
  /// firmware uses this index (or the channel hash from NodeDB) to
  /// decide which of our channels to encrypt with. If the recipient's
  /// `lastHeardChannel` points to a slot we don't have configured —
  /// or we have configured with a different PSK — the firmware refuses
  /// to dispatch the DM.
  final int? lastHeardChannel;

  // Device Metrics
  final double? voltage; // Battery voltage
  final double? channelUtilization; // Current channel utilization %
  final double? airUtilTx; // Airtime TX utilization %
  final int? uptimeSeconds; // Device uptime in seconds

  // Environment Metrics
  final double? barometricPressure; // Pressure in hPa
  final double? gasResistance; // Gas resistance for IAQ
  final int? iaq; // Indoor Air Quality index
  final double? lux; // Ambient light
  final double? whiteLux; // White light lux
  final double? irLux; // Infrared lux
  final double? uvLux; // UV light lux
  final int? windDirection; // Wind direction (degrees)
  final double? windSpeed; // Wind speed (m/s)
  final double? windGust; // Wind gust speed
  final double? windLull; // Wind lull speed
  final double? weight; // Scale weight
  final double? radiation; // Radiation level
  final double? rainfall1h; // Rainfall last hour (mm)
  final double? rainfall24h; // Rainfall last 24h (mm)
  final int? soilMoisture; // Soil moisture %
  final double? soilTemperature; // Soil temperature °C
  final double? envDistance; // Distance sensor (mm)
  final double? envCurrent; // Environment sensor current
  final double? envVoltage; // Environment sensor voltage

  // Power Metrics
  final double? ch1Voltage;
  final double? ch1Current;
  final double? ch2Voltage;
  final double? ch2Current;
  final double? ch3Voltage;
  final double? ch3Current;

  // Air Quality Metrics
  final int? pm10Standard; // PM1.0 standard
  final int? pm25Standard; // PM2.5 standard
  final int? pm100Standard; // PM10.0 standard
  final int? pm10Environmental; // PM1.0 environmental
  final int? pm25Environmental; // PM2.5 environmental
  final int? pm100Environmental; // PM10.0 environmental
  final int? particles03um; // 0.3µm particle count
  final int? particles05um; // 0.5µm particle count
  final int? particles10um; // 1.0µm particle count
  final int? particles25um; // 2.5µm particle count
  final int? particles50um; // 5.0µm particle count
  final int? particles100um; // 10.0µm particle count
  final int? co2; // CO2 concentration (ppm)

  // Local Stats
  final int? numPacketsTx; // Total packets transmitted
  final int? numPacketsRx; // Total packets received
  final int? numPacketsRxBad; // Bad packets received
  final int? numOnlineNodes; // Online node count
  final int? numTotalNodes; // Total node count
  final int? numTxDropped; // Packets dropped due to full TX queue
  final int? noiseFloor; // Noise floor in dBm

  // Node Status (v2.7.18)
  final String? nodeStatus; // Status message from NODE_STATUS_APP

  // Traffic Management Stats (v2.7.19)
  final int? tmPacketsInspected;
  final int? tmPositionDedupDrops;
  final int? tmNodeinfoCacheHits;
  final int? tmRateLimitDrops;
  final int? tmUnknownPacketDrops;
  final int? tmHopExhaustedPackets;
  final int? tmRouterHopsPreserved;

  // GPS/Position Extended Fields
  final int? satsInView; // Number of satellites in view
  final double? gpsAccuracy; // GPS accuracy in meters
  final double? groundSpeed; // Ground speed m/s
  final double? groundTrack; // Ground track (heading) degrees
  final int? precisionBits; // Position precision bits
  final DateTime? positionTimestamp; // Last position update time

  // Connectivity
  final bool hasWifi; // Whether device has WiFi
  final bool hasBluetooth; // Whether device has Bluetooth

  // RF Metadata
  final int? hopCount; // Hops away from this node (0 = direct neighbor)
  final bool viaMqtt; // Whether node was discovered via MQTT transport

  MeshNode({
    required this.nodeNum,
    this.longName,
    this.shortName,
    this.userId,
    this.latitude,
    this.longitude,
    this.altitude,
    this.lastHeard,
    this.firstHeard,
    this.snr,
    this.rssi,
    this.batteryLevel,
    this.temperature,
    this.humidity,
    this.firmwareVersion,
    this.hardwareModel,
    this.hwModelId,
    this.role,
    this.distance,
    this.isFavorite = false,
    this.isIgnored = false,
    this.isMuted = false,
    this.avatarColor,
    this.hasPublicKey = false,
    this.publicKey,
    this.lastHeardChannel,
    // Device Metrics
    this.voltage,
    this.channelUtilization,
    this.airUtilTx,
    this.uptimeSeconds,
    // Environment Metrics
    this.barometricPressure,
    this.gasResistance,
    this.iaq,
    this.lux,
    this.whiteLux,
    this.irLux,
    this.uvLux,
    this.windDirection,
    this.windSpeed,
    this.windGust,
    this.windLull,
    this.weight,
    this.radiation,
    this.rainfall1h,
    this.rainfall24h,
    this.soilMoisture,
    this.soilTemperature,
    this.envDistance,
    this.envCurrent,
    this.envVoltage,
    // Power Metrics
    this.ch1Voltage,
    this.ch1Current,
    this.ch2Voltage,
    this.ch2Current,
    this.ch3Voltage,
    this.ch3Current,
    // Air Quality Metrics
    this.pm10Standard,
    this.pm25Standard,
    this.pm100Standard,
    this.pm10Environmental,
    this.pm25Environmental,
    this.pm100Environmental,
    this.particles03um,
    this.particles05um,
    this.particles10um,
    this.particles25um,
    this.particles50um,
    this.particles100um,
    this.co2,
    // Local Stats
    this.numPacketsTx,
    this.numPacketsRx,
    this.numPacketsRxBad,
    this.numOnlineNodes,
    this.numTotalNodes,
    this.numTxDropped,
    this.noiseFloor,
    // Node Status (v2.7.18)
    this.nodeStatus,
    // Traffic Management Stats (v2.7.19)
    this.tmPacketsInspected,
    this.tmPositionDedupDrops,
    this.tmNodeinfoCacheHits,
    this.tmRateLimitDrops,
    this.tmUnknownPacketDrops,
    this.tmHopExhaustedPackets,
    this.tmRouterHopsPreserved,
    // GPS/Position Extended Fields
    this.satsInView,
    this.gpsAccuracy,
    this.groundSpeed,
    this.groundTrack,
    this.precisionBits,
    this.positionTimestamp,
    // Connectivity
    this.hasWifi = false,
    this.hasBluetooth = false,
    // RF Metadata
    this.hopCount,
    this.viaMqtt = false,
  });

  MeshNode copyWith({
    int? nodeNum,
    String? longName,
    bool clearLongName = false,
    String? shortName,
    bool clearShortName = false,
    String? userId,
    double? latitude,
    double? longitude,
    int? altitude,
    DateTime? lastHeard,
    DateTime? firstHeard,
    int? snr,
    bool clearSnr = false,
    int? rssi,
    bool clearRssi = false,
    int? batteryLevel,
    double? temperature,
    double? humidity,
    String? firmwareVersion,
    String? hardwareModel,
    int? hwModelId,
    String? role,
    double? distance,
    bool? isFavorite,
    bool? isIgnored,
    bool? isMuted,
    int? avatarColor,
    bool? hasPublicKey,
    List<int>? publicKey,
    int? lastHeardChannel,
    // Device Metrics
    double? voltage,
    double? channelUtilization,
    double? airUtilTx,
    int? uptimeSeconds,
    // Environment Metrics
    double? barometricPressure,
    double? gasResistance,
    int? iaq,
    double? lux,
    double? whiteLux,
    double? irLux,
    double? uvLux,
    int? windDirection,
    double? windSpeed,
    double? windGust,
    double? windLull,
    double? weight,
    double? radiation,
    double? rainfall1h,
    double? rainfall24h,
    int? soilMoisture,
    double? soilTemperature,
    double? envDistance,
    double? envCurrent,
    double? envVoltage,
    // Power Metrics
    double? ch1Voltage,
    double? ch1Current,
    double? ch2Voltage,
    double? ch2Current,
    double? ch3Voltage,
    double? ch3Current,
    // Air Quality Metrics
    int? pm10Standard,
    int? pm25Standard,
    int? pm100Standard,
    int? pm10Environmental,
    int? pm25Environmental,
    int? pm100Environmental,
    int? particles03um,
    int? particles05um,
    int? particles10um,
    int? particles25um,
    int? particles50um,
    int? particles100um,
    int? co2,
    // Local Stats
    int? numPacketsTx,
    int? numPacketsRx,
    int? numPacketsRxBad,
    int? numOnlineNodes,
    int? numTotalNodes,
    int? numTxDropped,
    int? noiseFloor,
    // Node Status (v2.7.18)
    String? nodeStatus,
    // Traffic Management Stats (v2.7.19)
    int? tmPacketsInspected,
    int? tmPositionDedupDrops,
    int? tmNodeinfoCacheHits,
    int? tmRateLimitDrops,
    int? tmUnknownPacketDrops,
    int? tmHopExhaustedPackets,
    int? tmRouterHopsPreserved,
    // GPS/Position Extended Fields
    int? satsInView,
    double? gpsAccuracy,
    double? groundSpeed,
    double? groundTrack,
    int? precisionBits,
    DateTime? positionTimestamp,
    // Connectivity
    bool? hasWifi,
    bool? hasBluetooth,
    // RF Metadata
    int? hopCount,
    bool? viaMqtt,
  }) {
    return MeshNode(
      nodeNum: nodeNum ?? this.nodeNum,
      longName: clearLongName ? null : (longName ?? this.longName),
      shortName: clearShortName ? null : (shortName ?? this.shortName),
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      lastHeard: lastHeard ?? this.lastHeard,
      firstHeard: firstHeard ?? this.firstHeard,
      snr: clearSnr ? null : (snr ?? this.snr),
      rssi: clearRssi ? null : (rssi ?? this.rssi),
      batteryLevel: batteryLevel ?? this.batteryLevel,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareModel: hardwareModel ?? this.hardwareModel,
      hwModelId: hwModelId ?? this.hwModelId,
      role: role ?? this.role,
      distance: distance ?? this.distance,
      isFavorite: isFavorite ?? this.isFavorite,
      isIgnored: isIgnored ?? this.isIgnored,
      isMuted: isMuted ?? this.isMuted,
      avatarColor: avatarColor ?? this.avatarColor,
      hasPublicKey: hasPublicKey ?? this.hasPublicKey,
      publicKey: publicKey ?? this.publicKey,
      lastHeardChannel: lastHeardChannel ?? this.lastHeardChannel,
      // Device Metrics
      voltage: voltage ?? this.voltage,
      channelUtilization: channelUtilization ?? this.channelUtilization,
      airUtilTx: airUtilTx ?? this.airUtilTx,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      // Environment Metrics
      barometricPressure: barometricPressure ?? this.barometricPressure,
      gasResistance: gasResistance ?? this.gasResistance,
      iaq: iaq ?? this.iaq,
      lux: lux ?? this.lux,
      whiteLux: whiteLux ?? this.whiteLux,
      irLux: irLux ?? this.irLux,
      uvLux: uvLux ?? this.uvLux,
      windDirection: windDirection ?? this.windDirection,
      windSpeed: windSpeed ?? this.windSpeed,
      windGust: windGust ?? this.windGust,
      windLull: windLull ?? this.windLull,
      weight: weight ?? this.weight,
      radiation: radiation ?? this.radiation,
      rainfall1h: rainfall1h ?? this.rainfall1h,
      rainfall24h: rainfall24h ?? this.rainfall24h,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      soilTemperature: soilTemperature ?? this.soilTemperature,
      envDistance: envDistance ?? this.envDistance,
      envCurrent: envCurrent ?? this.envCurrent,
      envVoltage: envVoltage ?? this.envVoltage,
      // Power Metrics
      ch1Voltage: ch1Voltage ?? this.ch1Voltage,
      ch1Current: ch1Current ?? this.ch1Current,
      ch2Voltage: ch2Voltage ?? this.ch2Voltage,
      ch2Current: ch2Current ?? this.ch2Current,
      ch3Voltage: ch3Voltage ?? this.ch3Voltage,
      ch3Current: ch3Current ?? this.ch3Current,
      // Air Quality Metrics
      pm10Standard: pm10Standard ?? this.pm10Standard,
      pm25Standard: pm25Standard ?? this.pm25Standard,
      pm100Standard: pm100Standard ?? this.pm100Standard,
      pm10Environmental: pm10Environmental ?? this.pm10Environmental,
      pm25Environmental: pm25Environmental ?? this.pm25Environmental,
      pm100Environmental: pm100Environmental ?? this.pm100Environmental,
      particles03um: particles03um ?? this.particles03um,
      particles05um: particles05um ?? this.particles05um,
      particles10um: particles10um ?? this.particles10um,
      particles25um: particles25um ?? this.particles25um,
      particles50um: particles50um ?? this.particles50um,
      particles100um: particles100um ?? this.particles100um,
      co2: co2 ?? this.co2,
      // Local Stats
      numPacketsTx: numPacketsTx ?? this.numPacketsTx,
      numPacketsRx: numPacketsRx ?? this.numPacketsRx,
      numPacketsRxBad: numPacketsRxBad ?? this.numPacketsRxBad,
      numOnlineNodes: numOnlineNodes ?? this.numOnlineNodes,
      numTotalNodes: numTotalNodes ?? this.numTotalNodes,
      numTxDropped: numTxDropped ?? this.numTxDropped,
      noiseFloor: noiseFloor ?? this.noiseFloor,
      // Node Status (v2.7.18)
      nodeStatus: nodeStatus ?? this.nodeStatus,
      // Traffic Management Stats (v2.7.19)
      tmPacketsInspected: tmPacketsInspected ?? this.tmPacketsInspected,
      tmPositionDedupDrops: tmPositionDedupDrops ?? this.tmPositionDedupDrops,
      tmNodeinfoCacheHits: tmNodeinfoCacheHits ?? this.tmNodeinfoCacheHits,
      tmRateLimitDrops: tmRateLimitDrops ?? this.tmRateLimitDrops,
      tmUnknownPacketDrops: tmUnknownPacketDrops ?? this.tmUnknownPacketDrops,
      tmHopExhaustedPackets:
          tmHopExhaustedPackets ?? this.tmHopExhaustedPackets,
      tmRouterHopsPreserved:
          tmRouterHopsPreserved ?? this.tmRouterHopsPreserved,
      // GPS/Position Extended Fields
      satsInView: satsInView ?? this.satsInView,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      groundSpeed: groundSpeed ?? this.groundSpeed,
      groundTrack: groundTrack ?? this.groundTrack,
      precisionBits: precisionBits ?? this.precisionBits,
      positionTimestamp: positionTimestamp ?? this.positionTimestamp,
      // Connectivity
      hasWifi: hasWifi ?? this.hasWifi,
      hasBluetooth: hasBluetooth ?? this.hasBluetooth,
      // RF Metadata
      hopCount: hopCount ?? this.hopCount,
      viaMqtt: viaMqtt ?? this.viaMqtt,
    );
  }

  String get displayName {
    return NodeDisplayNameResolver.resolve(
      nodeNum: nodeNum,
      longName: longName,
      shortName: shortName,
    );
  }

  /// Get a short display name suitable for avatars (max 4 chars)
  /// Prefers shortName, falls back to longName prefix, then last 4 hex digits
  String get avatarName {
    if (shortName != null && shortName!.isNotEmpty) {
      return sanitizeExternalText(shortName!);
    }
    if (longName != null && longName!.isNotEmpty) {
      final sanitized = sanitizeExternalText(longName!);
      return sanitized.substring(0, sanitized.length.clamp(0, 4));
    }
    return NodeDisplayNameResolver.shortHex(nodeNum);
  }

  // Position must be non-null, finite, and not exactly 0,0 (invalid/unset
  // marker). The isFinite check is mandatory: flutter_map's Crs.checkLatLng
  // throws fatally when a non-finite LatLng reaches projectAtZoom, and every
  // map layer (tile, marker, circle, polyline) hits projectAtZoom during
  // build or paint.
  bool get hasPosition =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      !(latitude == 0.0 && longitude == 0.0);

  /// Check if node was recently discovered (first heard within last 24 hours)
  bool get isRecentlyDiscovered {
    final discovered = firstHeard;
    if (discovered == null) return false;
    return DateTime.now().difference(discovered).inHours < 24;
  }

  PresenceConfidence get presenceConfidence {
    return PresenceCalculator.fromLastHeard(lastHeard, now: DateTime.now());
  }

  /// Operational SiteOps health derived from [lastHeard]. Distinct from
  /// [presenceConfidence]; see [NodeHealthState].
  NodeHealthState get healthState {
    return classifyHealth(lastActivity: lastHeard, now: DateTime.now());
  }

  Duration? get lastHeardAge {
    final heard = lastHeard;
    if (heard == null) return null;
    return DateTime.now().difference(heard);
  }

  @override
  String toString() => 'MeshNode($displayName, num: $nodeNum)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshNode &&
          runtimeType == other.runtimeType &&
          nodeNum == other.nodeNum;

  @override
  int get hashCode => nodeNum.hashCode;
}

/// Channel configuration
class ChannelConfig {
  final int index;
  final String name;
  final List<int> psk;
  final bool uplink;
  final bool downlink;
  final String role;
  final int positionPrecision; // 0 = disabled, 32 = full precision

  ChannelConfig({
    required this.index,
    required this.name,
    required this.psk,
    this.uplink = false,
    this.downlink = false,
    this.role = 'SECONDARY',
    this.positionPrecision = 0,
  });

  /// Whether position sharing is enabled for this channel
  bool get positionEnabled => positionPrecision > 0;

  /// Whether the channel has a secure encryption key
  /// Returns false for empty keys or the default 1-byte key (AQ==)
  bool get hasSecureKey {
    if (psk.isEmpty) return false;
    // Default key is a single byte with value 1 (encoded as "AQ==")
    if (psk.length == 1 && psk[0] == 1) return false;
    return true;
  }

  /// Whether the channel uses the default simple key (AQ==)
  bool get isDefaultKey => psk.length == 1 && psk[0] == 1;

  /// Firmware-equivalent channel-hash byte used for routing.
  ///
  /// Mirrors `meshtastic/firmware`'s `Channels::generateHash()` —
  /// `xorHash(name_bytes) ^ xorHash(psk_bytes)` reduced to a single
  /// byte. Two radios that have a channel with the same byte-equal
  /// `name` and byte-equal `psk` produce the SAME hash; if either
  /// differs by even one byte, the hash byte differs and the firmware
  /// treats them as distinct channels.
  ///
  /// Used for diagnostic log lines (`CHANNEL_HASH_SUMMARY`) so a
  /// support trace can confirm two devices' "RnsHarness" entries are
  /// genuinely identical at the byte level. NEVER used for actual
  /// encryption / routing decisions — that's firmware-side. Just a
  /// sanity-check fingerprint.
  int get firmwareHash {
    int h = 0;
    for (final byte in utf8.encode(name)) {
      h ^= byte;
    }
    for (final byte in psk) {
      h ^= byte;
    }
    return h & 0xFF;
  }

  ChannelConfig copyWith({
    int? index,
    String? name,
    List<int>? psk,
    bool? uplink,
    bool? downlink,
    String? role,
    int? positionPrecision,
  }) {
    return ChannelConfig(
      index: index ?? this.index,
      name: name ?? this.name,
      psk: psk ?? this.psk,
      uplink: uplink ?? this.uplink,
      downlink: downlink ?? this.downlink,
      role: role ?? this.role,
      positionPrecision: positionPrecision ?? this.positionPrecision,
    );
  }

  @override
  String toString() => 'ChannelConfig($name, index: $index)';
}
