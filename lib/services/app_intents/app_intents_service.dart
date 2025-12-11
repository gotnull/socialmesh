import '../../core/logging.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/automations/automation_providers.dart';
import '../../features/automations/models/automation.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Service to handle iOS App Intents (Siri Shortcuts integration)
class AppIntentsService {
  static const _channel = MethodChannel('com.socialmesh/app_intents');

  final Ref _ref;
  bool _isSetup = false;

  AppIntentsService(this._ref);

  /// Initialize the App Intents handler
  void setup() {
    if (_isSetup) return;
    if (!Platform.isIOS) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _isSetup = true;
    AppLogging.debug('AppIntentsService: Setup complete');
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    AppLogging.debug('AppIntentsService: Received ${call.method}');

    switch (call.method) {
      case 'handleIntent':
        return _handleIntent(call.arguments as Map<Object?, Object?>);
      default:
        throw PlatformException(
          code: 'UNSUPPORTED',
          message: 'Method ${call.method} not supported',
        );
    }
  }

  Future<void> _handleIntent(Map<Object?, Object?> args) async {
    final intentName = args['intentName'] as String?;
    final callbackId = args['callbackId'] as String?;

    if (intentName == null || callbackId == null) {
      return;
    }

    try {
      final result = await _processIntent(intentName, args);
      await _sendResult(callbackId, success: true, data: result);
    } catch (e) {
      await _sendResult(callbackId, success: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> _processIntent(
    String intentName,
    Map<Object?, Object?> args,
  ) async {
    switch (intentName) {
      case 'sendMessage':
        return _handleSendMessage(args);
      case 'sendChannelMessage':
        return _handleSendChannelMessage(args);
      case 'getNodeStatus':
        return _handleGetNodeStatus(args);
      case 'getOnlineNodes':
        return _handleGetOnlineNodes();
      case 'openNode':
        return _handleOpenNode(args);
      case 'openMap':
        return _handleOpenMap();
      case 'openMessages':
        return _handleOpenMessages();
      case 'runAutomation':
        return _handleRunAutomation(args);
      case 'listAutomations':
        return _handleListAutomations();
      default:
        throw Exception('Unknown intent: $intentName');
    }
  }

  Future<Map<String, dynamic>?> _handleSendMessage(
    Map<Object?, Object?> args,
  ) async {
    final message = args['message'] as String?;
    final nodeNum = args['nodeNum'] as int?;

    if (message == null || nodeNum == null) {
      throw Exception('Missing message or nodeNum');
    }

    final transport = _ref.read(transportProvider);
    if (!transport.isConnected) {
      throw Exception('Not connected to a node');
    }

    final protocol = _ref.read(protocolServiceProvider);
    await protocol.sendMessage(
      text: message,
      to: nodeNum,
      channel: 0,
      source: MessageSource.siri,
    );

    return {'sent': true};
  }

  Future<Map<String, dynamic>?> _handleSendChannelMessage(
    Map<Object?, Object?> args,
  ) async {
    final message = args['message'] as String?;
    final channelIndex = args['channelIndex'] as int? ?? 0;

    if (message == null) {
      throw Exception('Missing message');
    }

    final transport = _ref.read(transportProvider);
    if (!transport.isConnected) {
      throw Exception('Not connected to a node');
    }

    final protocol = _ref.read(protocolServiceProvider);

    // Send to broadcast address (0xFFFFFFFF) on the specified channel
    await protocol.sendMessage(
      text: message,
      to: 0xFFFFFFFF,
      channel: channelIndex,
      source: MessageSource.siri,
    );

    return {'sent': true};
  }

  Future<Map<String, dynamic>?> _handleGetNodeStatus(
    Map<Object?, Object?> args,
  ) async {
    final nodeNum = args['nodeNum'] as int?;

    if (nodeNum == null) {
      throw Exception('Missing nodeNum');
    }

    final nodes = _ref.read(nodesProvider);
    final node = nodes[nodeNum];

    if (node == null) {
      throw Exception('Node not found');
    }

    final lastSeen = node.lastHeard != null
        ? _formatLastSeen(node.lastHeard!)
        : 'Never';

    return {
      'name': node.longName ?? 'Node $nodeNum',
      'nodeNum': nodeNum,
      'isOnline': node.isOnline,
      'battery': node.batteryLevel,
      'lastSeen': lastSeen,
    };
  }

  Future<Map<String, dynamic>?> _handleGetOnlineNodes() async {
    final nodes = _ref.read(nodesProvider);
    int onlineCount = 0;

    for (final node in nodes.values) {
      if (node.isOnline) {
        onlineCount++;
      }
    }

    return {'count': onlineCount, 'total': nodes.length};
  }

  Future<Map<String, dynamic>?> _handleOpenNode(
    Map<Object?, Object?> args,
  ) async {
    final nodeNum = args['nodeNum'] as int?;
    if (nodeNum == null) {
      throw Exception('Missing nodeNum');
    }
    // Navigation will be handled by the app when it opens
    return {'nodeNum': nodeNum};
  }

  Future<Map<String, dynamic>?> _handleOpenMap() async {
    // Navigation will be handled by the app when it opens
    return {'screen': 'map'};
  }

  Future<Map<String, dynamic>?> _handleOpenMessages() async {
    // Navigation will be handled by the app when it opens
    return {'screen': 'messages'};
  }

  Future<Map<String, dynamic>?> _handleRunAutomation(
    Map<Object?, Object?> args,
  ) async {
    final name = args['name'] as String?;

    if (name == null || name.isEmpty) {
      return {'executed': false, 'error': 'Automation name is required'};
    }

    final repository = _ref.read(automationRepositoryProvider);
    final automations = repository.automations;

    // Find automation by name (case-insensitive)
    final automation = automations.cast<Automation?>().firstWhere(
      (a) => a?.name.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );

    if (automation == null) {
      return {'executed': false, 'error': "Automation '$name' not found"};
    }

    if (!automation.enabled) {
      return {'executed': false, 'error': "Automation '$name' is disabled"};
    }

    // Execute the automation
    final engine = _ref.read(automationEngineProvider);

    // Create a manual trigger event
    final event = AutomationEvent(
      type: TriggerType.manual,
      timestamp: DateTime.now(),
    );

    // Execute the automation
    await engine.executeAutomationManually(automation, event);

    return {'executed': true, 'name': automation.name};
  }

  Future<Map<String, dynamic>?> _handleListAutomations() async {
    final repository = _ref.read(automationRepositoryProvider);
    final automations = repository.automations;

    final automationList = automations
        .map(
          (a) => {
            'id': a.id,
            'name': a.name,
            'enabled': a.enabled,
            'description': a.description,
          },
        )
        .toList();

    return {'automations': automationList};
  }

  Future<void> _sendResult(
    String callbackId, {
    required bool success,
    Map<String, dynamic>? data,
    String? error,
  }) async {
    try {
      await _channel.invokeMethod('intentResult', {
        'callbackId': callbackId,
        'success': success,
        'data': data,
        'error': error,
      });
    } catch (e) {
      AppLogging.debug('AppIntentsService: Failed to send result: $e');
    }
  }

  String _formatLastSeen(DateTime lastHeard) {
    final now = DateTime.now();
    final diff = now.difference(lastHeard);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Provider for App Intents service
final appIntentsServiceProvider = Provider<AppIntentsService>((ref) {
  return AppIntentsService(ref);
});
