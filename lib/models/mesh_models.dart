import 'package:uuid/uuid.dart';

/// Message status enum
enum MessageStatus {
  pending, // Message being sent
  sent, // Message sent to device
  delivered, // Message delivered (acked)
  failed, // Failed to send
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
  final MessageStatus status;
  final String? errorMessage;
  final RoutingError? routingError;
  final int? packetId; // Meshtastic packet ID for tracking delivery

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
    this.status = MessageStatus.sent,
    this.errorMessage,
    this.routingError,
    this.packetId,
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
    MessageStatus? status,
    String? errorMessage,
    RoutingError? routingError,
    int? packetId,
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
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      routingError: routingError ?? this.routingError,
      packetId: packetId ?? this.packetId,
    );
  }

  bool get isBroadcast => to == 0xFFFFFFFF;
  bool get isDirect => !isBroadcast;
  bool get isFailed => status == MessageStatus.failed;
  bool get isPending => status == MessageStatus.pending;
  bool get isRetryable => routingError?.isRetryable ?? false;

  @override
  String toString() => 'Message(from: $from, to: $to, text: $text)';
}

/// Message delivery status update from the mesh
class MessageDeliveryUpdate {
  final int packetId;
  final bool delivered;
  final RoutingError? error;

  MessageDeliveryUpdate({
    required this.packetId,
    required this.delivered,
    this.error,
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
  final int? snr;
  final int? rssi;
  final int? batteryLevel;
  final double? temperature; // Temperature in Celsius from environment metrics
  final double? humidity; // Relative humidity percentage
  final String? firmwareVersion;
  final String? hardwareModel;
  final String? role; // 'CLIENT', 'ROUTER', etc.
  final double? distance; // distance in meters
  final bool isOnline;
  final bool isFavorite;
  final int? avatarColor; // Color value for avatar
  final bool hasPublicKey; // Whether node has encryption key set

  MeshNode({
    required this.nodeNum,
    this.longName,
    this.shortName,
    this.userId,
    this.latitude,
    this.longitude,
    this.altitude,
    this.lastHeard,
    this.snr,
    this.rssi,
    this.batteryLevel,
    this.temperature,
    this.humidity,
    this.firmwareVersion,
    this.hardwareModel,
    this.role,
    this.distance,
    this.isOnline = false,
    this.isFavorite = false,
    this.avatarColor,
    this.hasPublicKey = false,
  });

  MeshNode copyWith({
    int? nodeNum,
    String? longName,
    String? shortName,
    String? userId,
    double? latitude,
    double? longitude,
    int? altitude,
    DateTime? lastHeard,
    int? snr,
    int? rssi,
    int? batteryLevel,
    double? temperature,
    double? humidity,
    String? firmwareVersion,
    String? hardwareModel,
    String? role,
    double? distance,
    bool? isOnline,
    bool? isFavorite,
    int? avatarColor,
    bool? hasPublicKey,
  }) {
    return MeshNode(
      nodeNum: nodeNum ?? this.nodeNum,
      longName: longName ?? this.longName,
      shortName: shortName ?? this.shortName,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      lastHeard: lastHeard ?? this.lastHeard,
      snr: snr ?? this.snr,
      rssi: rssi ?? this.rssi,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareModel: hardwareModel ?? this.hardwareModel,
      role: role ?? this.role,
      distance: distance ?? this.distance,
      isOnline: isOnline ?? this.isOnline,
      isFavorite: isFavorite ?? this.isFavorite,
      avatarColor: avatarColor ?? this.avatarColor,
      hasPublicKey: hasPublicKey ?? this.hasPublicKey,
    );
  }

  String get displayName => longName ?? shortName ?? 'Node $nodeNum';

  /// Check if node has valid position data
  /// Position must be non-null and not exactly 0,0 (invalid/unset marker)
  bool get hasPosition =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0.0 && longitude == 0.0);

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
