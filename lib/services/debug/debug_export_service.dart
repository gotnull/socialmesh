// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/debug/app_log_screen.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../models/presence_confidence.dart';
import '../../providers/presence_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../../utils/share_utils.dart';

/// Service to export comprehensive debug information as JSON
class DebugExportService {
  final Ref _ref;

  DebugExportService(this._ref);

  /// Generate full debug export JSON
  Future<Map<String, dynamic>> generateDebugExport() async {
    final export = <String, dynamic>{};

    // Metadata
    export['exportDate'] = DateTime.now().toIso8601String();
    export['exportType'] = 'debug';
    export['version'] = '1.0';

    // Platform info
    export['platform'] = {
      'isIOS': Platform.isIOS,
      'isAndroid': Platform.isAndroid,
      'isMacOS': Platform.isMacOS,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
    };

    // Connection state
    try {
      final connectionState = _ref.read(connectionStateProvider);
      final connectedDevice = _ref.read(connectedDeviceProvider);
      final autoReconnectState = _ref.read(autoReconnectStateProvider);

      export['connection'] = {
        'state': connectionState.value?.name ?? 'unknown',
        'autoReconnectState': autoReconnectState.name,
        'connectedDevice': connectedDevice != null
            ? {
                'id': connectedDevice.id,
                'name': connectedDevice.name,
                'type': connectedDevice.type.name,
                'rssi': connectedDevice.rssi,
              }
            : null,
      };
    } catch (e) {
      export['connection'] = {'error': e.toString()};
    }

    // Protocol state
    try {
      final protocol = _ref.read(protocolServiceProvider);
      final myNodeNum = _ref.read(myNodeNumProvider);
      final region = _ref.read(deviceRegionProvider).value;

      export['protocol'] = {
        'myNodeNum': myNodeNum,
        'myNodeNumHex': myNodeNum != null
            ? '0x${myNodeNum.toRadixString(16).toUpperCase()}'
            : null,
        'configurationComplete': protocol.configurationComplete,
        'region': region?.name,
      };
    } catch (e) {
      export['protocol'] = {'error': e.toString()};
    }

    // Settings
    try {
      final settings = await _ref.read(settingsServiceProvider.future);
      export['settings'] = {
        'autoReconnect': settings.autoReconnect,
        'lastDeviceId': settings.lastDeviceId,
        'lastDeviceName': settings.lastDeviceName,
        'notificationsEnabled': settings.notificationsEnabled,
        'channelMessageNotificationsEnabled':
            settings.channelMessageNotificationsEnabled,
        'directMessageNotificationsEnabled':
            settings.directMessageNotificationsEnabled,
        'newNodeNotificationsEnabled': settings.newNodeNotificationsEnabled,
        'accentColor': settings.accentColor,
      };
    } catch (e) {
      export['settings'] = {'error': e.toString()};
    }

    // Nodes
    try {
      final nodes = _ref.read(nodesProvider);
      final presenceMap = _ref.read(presenceMapProvider);
      export['nodes'] = {
        'count': nodes.length,
        'activeCount': nodes.values
            .where((n) => presenceConfidenceFor(presenceMap, n).isActive)
            .length,
        'list': nodes.values
            .map((n) => _nodeToDebugMap(n, presenceMap))
            .toList(),
      };
    } catch (e) {
      export['nodes'] = {'error': e.toString()};
    }

    // Channels
    try {
      final channels = _ref.read(channelsProvider);
      export['channels'] = channels
          .map(
            (c) => {
              'index': c.index,
              'name': c.name,
              'role': c.role,
              'hasPsk': c.psk.isNotEmpty,
            },
          )
          .toList();
    } catch (e) {
      export['channels'] = {'error': e.toString()};
    }

    // Messages summary
    try {
      final messages = _ref.read(messagesProvider);
      export['messages'] = {
        'totalCount': messages.length,
        'sentCount': messages.where((m) => m.sent).length,
        'receivedCount': messages.where((m) => m.received).length,
        'failedCount': messages
            .where((m) => m.status == MessageStatus.failed)
            .length,
        'last10': messages.reversed
            .take(10)
            .map((m) => _messageToDebugMap(m))
            .toList(),
      };
    } catch (e) {
      export['messages'] = {'error': e.toString()};
    }

    // Routes
    try {
      final routes = _ref.read(routesProvider);
      final activeRoute = _ref.read(activeRouteProvider);
      export['routes'] = {
        'savedCount': routes.length,
        'isRecording': activeRoute != null,
        'activeRoute': activeRoute != null
            ? {
                'name': activeRoute.name,
                'pointCount': activeRoute.locations.length,
                'distanceMeters': activeRoute.totalDistance,
              }
            : null,
        'saved': routes
            .map(
              (r) => {
                'name': r.name,
                'pointCount': r.locations.length,
                'distanceMeters': r.totalDistance,
                'createdAt': r.createdAt.toIso8601String(),
              },
            )
            .toList(),
      };
    } catch (e) {
      export['routes'] = {'error': e.toString()};
    }

    // Telemetry summary
    try {
      final deviceMetrics = await _ref.read(deviceMetricsLogsProvider.future);
      final envMetrics = await _ref.read(environmentMetricsLogsProvider.future);
      final positions = await _ref.read(positionLogsProvider.future);

      export['telemetry'] = {
        'deviceMetricsCount': deviceMetrics.length,
        'environmentMetricsCount': envMetrics.length,
        'positionLogsCount': positions.length,
        'lastDeviceMetrics': deviceMetrics.isNotEmpty
            ? deviceMetrics.last.toJson()
            : null,
        'lastEnvironmentMetrics': envMetrics.isNotEmpty
            ? envMetrics.last.toJson()
            : null,
        'last10Positions': positions.reversed
            .take(10)
            .map((p) => p.toJson())
            .toList(),
      };
    } catch (e) {
      export['telemetry'] = {'error': e.toString()};
    }

    // App logs
    try {
      final logger = _ref.read(appLoggerProvider);
      final logs = logger.logs;
      export['appLogs'] = {
        'totalCount': logs.length,
        'errorCount': logs.where((l) => l.level == LogLevel.error).length,
        'warningCount': logs.where((l) => l.level == LogLevel.warning).length,
        'last100': logs.reversed
            .take(100)
            .map(
              (l) => {
                'timestamp': l.timestamp.toIso8601String(),
                'level': l.level.label,
                'source': l.source,
                'message': l.message,
              },
            )
            .toList(),
      };
    } catch (e) {
      export['appLogs'] = {'error': e.toString()};
    }

    // Pending messages queue
    try {
      final queue = _ref.read(offlineQueueProvider);
      export['offlineQueue'] = {'pendingCount': queue.pendingCount};
    } catch (e) {
      export['offlineQueue'] = {'error': e.toString()};
    }

    return export;
  }

  Map<String, dynamic> _nodeToDebugMap(
    MeshNode node,
    Map<int, NodePresence> presenceMap,
  ) {
    final presence = presenceConfidenceFor(presenceMap, node);
    final lastHeardAge = lastHeardAgeFor(presenceMap, node);
    return {
      'nodeNum': node.nodeNum,
      'nodeNumHex': '0x${node.nodeNum.toRadixString(16).toUpperCase()}',
      'userId': node.userId,
      'longName': node.longName,
      'shortName': node.shortName,
      'hardwareModel': node.hardwareModel,
      'role': node.role,
      'presenceConfidence': presence.name,
      'hasPosition': node.hasPosition,
      'latitude': node.latitude != null
          ? double.parse(node.latitude!.toStringAsFixed(2))
          : null,
      'longitude': node.longitude != null
          ? double.parse(node.longitude!.toStringAsFixed(2))
          : null,
      'altitude': node.altitude,
      'satsInView': node.satsInView,
      'gpsAccuracy': node.gpsAccuracy,
      'groundSpeed': node.groundSpeed,
      'groundTrack': node.groundTrack,
      'precisionBits': node.precisionBits,
      'batteryLevel': node.batteryLevel,
      'voltage': node.voltage,
      'snr': node.snr,
      'rssi': node.rssi,
      'channelUtilization': node.channelUtilization,
      'airUtilTx': node.airUtilTx,
      'uptimeSeconds': node.uptimeSeconds,
      'numTxDropped': node.numTxDropped,
      'noiseFloor': node.noiseFloor,
      'nodeStatus': node.nodeStatus,
      'temperature': node.temperature,
      'humidity': node.humidity,
      'lastHeard': node.lastHeard?.toIso8601String(),
      'lastHeardAgo': lastHeardAge?.inSeconds,
      'isMuted': node.isMuted,
    };
  }

  Map<String, dynamic> _messageToDebugMap(Message msg) {
    return {
      'id': msg.id,
      'from': msg.from,
      'fromHex': '0x${msg.from.toRadixString(16).toUpperCase()}',
      'to': msg.to,
      'toHex': '0x${msg.to.toRadixString(16).toUpperCase()}',
      'channel': msg.channel,
      'text': '[redacted]',
      'timestamp': msg.timestamp.toIso8601String(),
      'status': msg.status.name,
      'sent': msg.sent,
      'received': msg.received,
      'isDirect': msg.isDirect,
      'packetId': msg.packetId,
      'errorMessage': msg.errorMessage,
      'routingError': msg.routingError?.name,
    };
  }

  /// Export as JSON string
  Future<String> exportAsJson() async {
    final data = await generateDebugExport();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Export and share as file
  Future<void> exportAndShare(Rect sharePositionOrigin) async {
    final json = await exportAsJson();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')[0];

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/socialmesh_debug_$timestamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Socialmesh Debug Export $timestamp',
      sharePositionOrigin: getSafeSharePosition(null, sharePositionOrigin),
    );
  }
}

/// Provider for debug export service
final debugExportServiceProvider = Provider<DebugExportService>((ref) {
  return DebugExportService(ref);
});
