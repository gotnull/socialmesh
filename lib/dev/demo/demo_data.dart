// SPDX-License-Identifier: GPL-3.0-or-later
import '../../models/mesh_models.dart';

/// Sample data for demo mode.
///
/// Provides deterministic sample data for key screens when running
/// without backend configuration. All data is static and predictable
/// for testing and demonstration purposes.
class DemoData {
  DemoData._();

  /// Sample node numbers (deterministic hex values).
  static const int nodeAlpha = 0xABCD1234;
  static const int nodeBeta = 0xBEEF5678;
  static const int nodeGamma = 0xCAFE9ABC;

  /// Demo user's own node number.
  static const int myNodeNum = 0xDEAD0001;

  /// Sample nodes representing a small mesh network.
  static List<MeshNode> get sampleNodes => [
    MeshNode(
      nodeNum: nodeAlpha,
      longName: 'Alpha Station',
      shortName: 'ALPH',
      userId: '!abcd1234',
      latitude: 37.7749,
      longitude: -122.4194,
      altitude: 15,
      lastHeard: DateTime.now().subtract(const Duration(minutes: 2)),
      firstHeard: DateTime.now().subtract(const Duration(hours: 24)),
      snr: 8,
      rssi: -75,
      batteryLevel: 85,
      temperature: 22.5,
      firmwareVersion: '2.5.6',
      hardwareModel: 'TBEAM',
      role: 'ROUTER',
      distance: 1250.0,
      hasPublicKey: true,
      channelUtilization: 12.5,
      airUtilTx: 3.2,
      uptimeSeconds: 86400,
    ),
    MeshNode(
      nodeNum: nodeBeta,
      longName: 'Beta Mobile',
      shortName: 'BETA',
      userId: '!beef5678',
      latitude: 37.7849,
      longitude: -122.4094,
      altitude: 22,
      lastHeard: DateTime.now().subtract(const Duration(minutes: 8)),
      firstHeard: DateTime.now().subtract(const Duration(hours: 12)),
      snr: 5,
      rssi: -82,
      batteryLevel: 62,
      temperature: 24.1,
      firmwareVersion: '2.5.6',
      hardwareModel: 'HELTEC_V3',
      role: 'CLIENT',
      distance: 2100.0,
      hasPublicKey: true,
      channelUtilization: 8.3,
      airUtilTx: 1.8,
      uptimeSeconds: 43200,
    ),
    MeshNode(
      nodeNum: nodeGamma,
      longName: 'Gamma Relay',
      shortName: 'GAMM',
      userId: '!cafe9abc',
      latitude: 37.7649,
      longitude: -122.4294,
      altitude: 45,
      lastHeard: DateTime.now().subtract(const Duration(minutes: 15)),
      firstHeard: DateTime.now().subtract(const Duration(days: 3)),
      snr: 12,
      rssi: -68,
      batteryLevel: 100,
      firmwareVersion: '2.5.5',
      hardwareModel: 'RAK4631',
      role: 'ROUTER',
      distance: 3400.0,
      hasPublicKey: true,
      channelUtilization: 18.7,
      airUtilTx: 5.1,
      uptimeSeconds: 259200,
      voltage: 4.2,
    ),
  ];

  /// Sample messages for demo conversation.
  static List<Message> get sampleMessages => [
    Message(
      id: 'demo-msg-1',
      from: nodeAlpha,
      to: 0xFFFFFFFF, // Broadcast
      text: 'Good morning mesh! Anyone out there?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      channel: 0,
      status: MessageStatus.delivered,
      senderLongName: 'Alpha Station',
      senderShortName: 'ALPH',
    ),
    Message(
      id: 'demo-msg-2',
      from: nodeBeta,
      to: 0xFFFFFFFF,
      text: 'Hey Alpha! Just got online. Signal looks good today.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 28)),
      channel: 0,
      status: MessageStatus.delivered,
      senderLongName: 'Beta Mobile',
      senderShortName: 'BETA',
    ),
    Message(
      id: 'demo-msg-3',
      from: nodeGamma,
      to: 0xFFFFFFFF,
      text: 'Gamma relay here. Relaying traffic from the hilltop.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      channel: 0,
      status: MessageStatus.delivered,
      senderLongName: 'Gamma Relay',
      senderShortName: 'GAMM',
    ),
    Message(
      id: 'demo-msg-4',
      from: nodeAlpha,
      to: myNodeNum, // Direct message
      text: 'Welcome to the demo! This is a direct message.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      channel: null,
      status: MessageStatus.delivered,
      senderLongName: 'Alpha Station',
      senderShortName: 'ALPH',
    ),
    Message(
      id: 'demo-msg-5',
      from: myNodeNum,
      to: nodeAlpha,
      text: 'Thanks! Testing direct messaging.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      channel: null,
      sent: true,
      status: MessageStatus.delivered,
    ),
  ];

  /// Sample telemetry data points.
  static List<TelemetrySample> get sampleTelemetry => [
    TelemetrySample(
      nodeNum: nodeAlpha,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      batteryLevel: 87,
      voltage: 4.1,
      temperature: 21.8,
      channelUtilization: 10.2,
    ),
    TelemetrySample(
      nodeNum: nodeAlpha,
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      batteryLevel: 85,
      voltage: 4.0,
      temperature: 22.5,
      channelUtilization: 12.5,
    ),
  ];
}

/// Telemetry sample for demo data.
class TelemetrySample {
  final int nodeNum;
  final DateTime timestamp;
  final int? batteryLevel;
  final double? voltage;
  final double? temperature;
  final double? channelUtilization;

  const TelemetrySample({
    required this.nodeNum,
    required this.timestamp,
    this.batteryLevel,
    this.voltage,
    this.temperature,
    this.channelUtilization,
  });
}
