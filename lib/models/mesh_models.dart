import 'package:uuid/uuid.dart';

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
    );
  }

  bool get isBroadcast => to == 0xFFFFFFFF;
  bool get isDirect => !isBroadcast;

  @override
  String toString() => 'Message(from: $from, to: $to, text: $text)';
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
  final int? batteryLevel;
  final String? firmwareVersion;
  final String? hardwareModel;

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
    this.batteryLevel,
    this.firmwareVersion,
    this.hardwareModel,
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
    int? batteryLevel,
    String? firmwareVersion,
    String? hardwareModel,
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
      batteryLevel: batteryLevel ?? this.batteryLevel,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareModel: hardwareModel ?? this.hardwareModel,
    );
  }

  String get displayName => longName ?? shortName ?? 'Node $nodeNum';

  bool get hasPosition => latitude != null && longitude != null;

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

  ChannelConfig({
    required this.index,
    required this.name,
    required this.psk,
    this.uplink = false,
    this.downlink = true,
    this.role = 'SECONDARY',
  });

  ChannelConfig copyWith({
    int? index,
    String? name,
    List<int>? psk,
    bool? uplink,
    bool? downlink,
    String? role,
  }) {
    return ChannelConfig(
      index: index ?? this.index,
      name: name ?? this.name,
      psk: psk ?? this.psk,
      uplink: uplink ?? this.uplink,
      downlink: downlink ?? this.downlink,
      role: role ?? this.role,
    );
  }

  @override
  String toString() => 'ChannelConfig($name, index: $index)';
}
