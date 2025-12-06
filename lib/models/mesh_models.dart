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
