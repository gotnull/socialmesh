import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/mesh_models.dart' show MeshNode;
import '../../services/ifttt/ifttt_service.dart';
import 'models/automation.dart';
import 'automation_repository.dart';

/// Message model for automation processing (local to avoid import conflict)
class AutomationMessage {
  final int from;
  final String text;
  final int? channel;

  AutomationMessage({required this.from, required this.text, this.channel});
}

/// Engine that evaluates triggers and executes automation actions
class AutomationEngine {
  final AutomationRepository _repository;
  final IftttService _iftttService;
  final FlutterLocalNotificationsPlugin? _notifications;

  /// Callback to send a message via the mesh
  final Future<bool> Function(int nodeNum, String message)? onSendMessage;

  /// Callback to send a message to a channel
  final Future<bool> Function(int channelIndex, String message)?
  onSendToChannel;

  // Track node states for change detection
  final Map<int, bool> _nodeOnlineStatus = {};
  final Map<int, int> _nodeBatteryLevels = {};
  final Map<int, DateTime> _nodeLastHeard = {};
  final Map<int, (double, double)> _nodePositions = {};

  // Throttling for repeated triggers
  final Map<String, DateTime> _lastTriggerTimes = {};
  static const _minTriggerInterval = Duration(minutes: 1);

  // Silent node monitoring
  Timer? _silentNodeTimer;

  AutomationEngine({
    required AutomationRepository repository,
    required IftttService iftttService,
    FlutterLocalNotificationsPlugin? notifications,
    this.onSendMessage,
    this.onSendToChannel,
  }) : _repository = repository,
       _iftttService = iftttService,
       _notifications = notifications;

  /// Start the automation engine
  void start() {
    _startSilentNodeMonitor();
    debugPrint('AutomationEngine: Started');
  }

  /// Stop the automation engine
  void stop() {
    _silentNodeTimer?.cancel();
    _silentNodeTimer = null;
    debugPrint('AutomationEngine: Stopped');
  }

  /// Process a node update event
  Future<void> processNodeUpdate(
    MeshNode node, {
    MeshNode? previousNode,
  }) async {
    final automations = _repository.automations
        .where((a) => a.enabled)
        .toList();
    if (automations.isEmpty) return;

    // Check online/offline transitions
    final wasOnline = _nodeOnlineStatus[node.nodeNum];
    final isOnline = node.isOnline;
    _nodeOnlineStatus[node.nodeNum] = isOnline;

    if (wasOnline == false && isOnline) {
      await _processEvent(
        AutomationEvent(
          type: TriggerType.nodeOnline,
          nodeNum: node.nodeNum,
          nodeName: node.displayName,
          batteryLevel: node.batteryLevel,
          latitude: node.latitude,
          longitude: node.longitude,
        ),
      );
    } else if (wasOnline == true && !isOnline) {
      await _processEvent(
        AutomationEvent(
          type: TriggerType.nodeOffline,
          nodeNum: node.nodeNum,
          nodeName: node.displayName,
        ),
      );
    }

    // Check battery changes
    final previousBattery = _nodeBatteryLevels[node.nodeNum];
    if (node.batteryLevel != null) {
      _nodeBatteryLevels[node.nodeNum] = node.batteryLevel!;

      // Battery low check
      if (previousBattery != null &&
          previousBattery > 20 &&
          node.batteryLevel! <= 20) {
        await _processEvent(
          AutomationEvent(
            type: TriggerType.batteryLow,
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
            batteryLevel: node.batteryLevel,
          ),
        );
      }

      // Battery full check
      if (previousBattery != null &&
          previousBattery < 100 &&
          node.batteryLevel == 100) {
        await _processEvent(
          AutomationEvent(
            type: TriggerType.batteryFull,
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
            batteryLevel: node.batteryLevel,
          ),
        );
      }
    }

    // Check position changes / geofencing
    if (node.hasPosition) {
      final previousPos = _nodePositions[node.nodeNum];
      final currentPos = (node.latitude!, node.longitude!);
      _nodePositions[node.nodeNum] = currentPos;

      if (previousPos != null) {
        // Position changed event
        await _processEvent(
          AutomationEvent(
            type: TriggerType.positionChanged,
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
            latitude: node.latitude,
            longitude: node.longitude,
          ),
        );

        // Check geofence events for all automations with geofence triggers
        await _checkGeofenceEvents(node, previousPos, currentPos);
      }
    }

    // Check signal strength
    if (node.snr != null) {
      await _processEvent(
        AutomationEvent(
          type: TriggerType.signalWeak,
          nodeNum: node.nodeNum,
          nodeName: node.displayName,
          snr: node.snr,
        ),
      );
    }

    // Update last heard for silent node detection
    if (node.lastHeard != null) {
      _nodeLastHeard[node.nodeNum] = node.lastHeard!;
    }
  }

  /// Process an incoming message
  Future<void> processMessage(
    AutomationMessage message, {
    required String senderName,
    String? channelName,
  }) async {
    // Message received trigger
    await _processEvent(
      AutomationEvent(
        type: TriggerType.messageReceived,
        nodeNum: message.from,
        nodeName: senderName,
        messageText: message.text,
        channelIndex: message.channel,
      ),
    );

    // Message contains trigger (will check keyword in evaluation)
    await _processEvent(
      AutomationEvent(
        type: TriggerType.messageContains,
        nodeNum: message.from,
        nodeName: senderName,
        messageText: message.text,
        channelIndex: message.channel,
      ),
    );

    // Channel activity trigger
    if (message.channel != null) {
      await _processEvent(
        AutomationEvent(
          type: TriggerType.channelActivity,
          nodeNum: message.from,
          nodeName: senderName,
          messageText: message.text,
          channelIndex: message.channel,
        ),
      );
    }
  }

  /// Process an automation event
  Future<void> _processEvent(AutomationEvent event) async {
    final automations = _repository.automations
        .where((a) => a.enabled && a.trigger.type == event.type)
        .toList();

    debugPrint('🤖 AutomationEngine: Processing ${event.type.name} event');
    debugPrint(
      '🤖 AutomationEngine: Found ${automations.length} matching automations',
    );

    for (final automation in automations) {
      debugPrint('🤖 AutomationEngine: Checking "${automation.name}"');
      if (_shouldTrigger(automation, event)) {
        debugPrint('🤖 AutomationEngine: TRIGGERING "${automation.name}"');
        await _executeAutomation(automation, event);
      } else {
        debugPrint(
          '🤖 AutomationEngine: Skipped "${automation.name}" (conditions not met)',
        );
      }
    }
  }

  /// Check if automation should trigger for this event
  bool _shouldTrigger(Automation automation, AutomationEvent event) {
    final trigger = automation.trigger;

    // Check throttling
    final throttleKey = '${automation.id}_${event.type.name}';
    final lastTrigger = _lastTriggerTimes[throttleKey];
    if (lastTrigger != null &&
        DateTime.now().difference(lastTrigger) < _minTriggerInterval) {
      debugPrint('🤖 _shouldTrigger: Throttled');
      return false;
    }

    // Check node filter
    if (trigger.nodeNum != null && trigger.nodeNum != event.nodeNum) {
      debugPrint(
        '🤖 _shouldTrigger: Node filter mismatch (trigger=${trigger.nodeNum}, event=${event.nodeNum})',
      );
      return false;
    }

    // Check trigger-specific conditions
    switch (trigger.type) {
      case TriggerType.batteryLow:
        if (event.batteryLevel == null ||
            event.batteryLevel! > trigger.batteryThreshold) {
          debugPrint('🤖 _shouldTrigger: Battery level not below threshold');
          return false;
        }
        break;

      case TriggerType.messageContains:
        if (trigger.keyword == null || event.messageText == null) {
          debugPrint(
            '🤖 _shouldTrigger: messageContains - keyword=${trigger.keyword}, message=${event.messageText}',
          );
          return false;
        }
        final keywordLower = trigger.keyword!.toLowerCase();
        final messageLower = event.messageText!.toLowerCase();
        if (!messageLower.contains(keywordLower)) {
          debugPrint(
            '🤖 _shouldTrigger: messageContains - "$messageLower" does not contain "$keywordLower"',
          );
          return false;
        }
        debugPrint(
          '🤖 _shouldTrigger: messageContains - MATCH! "$messageLower" contains "$keywordLower"',
        );
        break;

      case TriggerType.signalWeak:
        if (event.snr == null || event.snr! > trigger.signalThreshold) {
          return false;
        }
        break;

      case TriggerType.channelActivity:
        if (trigger.channelIndex != null &&
            trigger.channelIndex != event.channelIndex) {
          return false;
        }
        break;

      default:
        break;
    }

    // Check additional conditions
    if (automation.conditions != null) {
      for (final condition in automation.conditions!) {
        if (!_evaluateCondition(condition, event)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Evaluate a condition
  bool _evaluateCondition(
    AutomationCondition condition,
    AutomationEvent event,
  ) {
    switch (condition.type) {
      case ConditionType.timeRange:
        final now = TimeOfDay.now();
        final start = _parseTimeOfDay(condition.timeStart);
        final end = _parseTimeOfDay(condition.timeEnd);
        if (start == null || end == null) return true;
        return _isTimeInRange(now, start, end);

      case ConditionType.dayOfWeek:
        final days = condition.daysOfWeek;
        if (days == null || days.isEmpty) return true;
        return days.contains(DateTime.now().weekday % 7);

      case ConditionType.batteryAbove:
        if (event.batteryLevel == null) return true;
        return event.batteryLevel! > condition.batteryThreshold;

      case ConditionType.batteryBelow:
        if (event.batteryLevel == null) return true;
        return event.batteryLevel! < condition.batteryThreshold;

      case ConditionType.nodeOnline:
        if (condition.nodeNum == null) return true;
        return _nodeOnlineStatus[condition.nodeNum] == true;

      case ConditionType.nodeOffline:
        if (condition.nodeNum == null) return true;
        return _nodeOnlineStatus[condition.nodeNum] != true;

      case ConditionType.withinGeofence:
      case ConditionType.outsideGeofence:
        // Geofence conditions would need additional config
        return true;
    }
  }

  /// Execute an automation's actions
  Future<void> _executeAutomation(
    Automation automation,
    AutomationEvent event,
  ) async {
    debugPrint('AutomationEngine: Executing "${automation.name}"');

    // Update throttle
    final throttleKey = '${automation.id}_${event.type.name}';
    _lastTriggerTimes[throttleKey] = DateTime.now();

    final actionsExecuted = <String>[];
    String? errorMessage;

    try {
      for (final action in automation.actions) {
        final success = await _executeAction(action, event, automation);
        if (success) {
          actionsExecuted.add(action.type.displayName);
        }
      }

      // Update automation stats
      await _repository.recordTrigger(automation.id);
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('AutomationEngine: Error executing automation: $e');
    }

    // Log execution
    await _repository.addLogEntry(
      AutomationLogEntry(
        automationId: automation.id,
        automationName: automation.name,
        timestamp: DateTime.now(),
        success: errorMessage == null,
        triggerDetails: _buildTriggerDetails(event),
        actionsExecuted: actionsExecuted,
        errorMessage: errorMessage,
      ),
    );
  }

  /// Execute a single action
  Future<bool> _executeAction(
    AutomationAction action,
    AutomationEvent event,
    Automation automation,
  ) async {
    switch (action.type) {
      case ActionType.sendMessage:
        if (onSendMessage == null || action.targetNodeNum == null) return false;
        final message = _interpolateVariables(
          action.messageText ?? '',
          event,
          trigger: automation.trigger,
        );
        return await onSendMessage!(action.targetNodeNum!, message);

      case ActionType.sendToChannel:
        if (onSendToChannel == null || action.targetChannelIndex == null) {
          return false;
        }
        final message = _interpolateVariables(
          action.messageText ?? '',
          event,
          trigger: automation.trigger,
        );
        return await onSendToChannel!(action.targetChannelIndex!, message);

      case ActionType.playSound:
        // Sound playback handled elsewhere
        return true;

      case ActionType.vibrate:
        // Vibration would be handled via HapticFeedback or platform channel
        // For now just return true as a stub
        return true;

      case ActionType.pushNotification:
        if (_notifications == null) return false;
        final title = _interpolateVariables(
          action.notificationTitle ?? automation.name,
          event,
          trigger: automation.trigger,
        );
        final body = _interpolateVariables(
          action.notificationBody ?? '',
          event,
          trigger: automation.trigger,
        );
        await _notifications.show(
          automation.id.hashCode,
          title,
          body,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
        return true;

      case ActionType.triggerWebhook:
        if (action.webhookEventName == null) return false;
        return await _iftttService
            .testWebhook(); // TODO: use actual webhook method

      case ActionType.logEvent:
        // Already logging executions
        return true;

      case ActionType.updateWidget:
        // Widget updates handled via WidgetKit
        return true;

      case ActionType.triggerShortcut:
        // iOS Shortcuts via URL scheme
        // Would need: url_launcher to open shortcuts://run-shortcut?name=X
        return true;
    }
  }

  /// Check geofence enter/exit events
  Future<void> _checkGeofenceEvents(
    MeshNode node,
    (double, double) previousPos,
    (double, double) currentPos,
  ) async {
    final automations = _repository.automations
        .where(
          (a) =>
              a.enabled &&
              (a.trigger.type == TriggerType.geofenceEnter ||
                  a.trigger.type == TriggerType.geofenceExit),
        )
        .toList();

    for (final automation in automations) {
      final trigger = automation.trigger;
      if (trigger.nodeNum != null && trigger.nodeNum != node.nodeNum) continue;
      if (trigger.geofenceLat == null || trigger.geofenceLon == null) continue;

      final center = (trigger.geofenceLat!, trigger.geofenceLon!);
      final wasInside =
          _calculateDistance(
            previousPos.$1,
            previousPos.$2,
            center.$1,
            center.$2,
          ) <=
          trigger.geofenceRadius;
      final isInside =
          _calculateDistance(
            currentPos.$1,
            currentPos.$2,
            center.$1,
            center.$2,
          ) <=
          trigger.geofenceRadius;

      if (!wasInside && isInside && trigger.type == TriggerType.geofenceEnter) {
        await _processEvent(
          AutomationEvent(
            type: TriggerType.geofenceEnter,
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
            latitude: currentPos.$1,
            longitude: currentPos.$2,
          ),
        );
      } else if (wasInside &&
          !isInside &&
          trigger.type == TriggerType.geofenceExit) {
        await _processEvent(
          AutomationEvent(
            type: TriggerType.geofenceExit,
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
            latitude: currentPos.$1,
            longitude: currentPos.$2,
          ),
        );
      }
    }
  }

  /// Start monitoring for silent nodes
  void _startSilentNodeMonitor() {
    _silentNodeTimer?.cancel();
    _silentNodeTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkSilentNodes();
    });
  }

  /// Check for nodes that have been silent too long
  Future<void> _checkSilentNodes() async {
    final automations = _repository.automations
        .where((a) => a.enabled && a.trigger.type == TriggerType.nodeSilent)
        .toList();

    for (final automation in automations) {
      final trigger = automation.trigger;
      final silentDuration = Duration(minutes: trigger.silentMinutes);

      for (final entry in _nodeLastHeard.entries) {
        final nodeNum = entry.key;
        final lastHeard = entry.value;

        // Skip if not monitoring this specific node
        if (trigger.nodeNum != null && trigger.nodeNum != nodeNum) continue;

        if (DateTime.now().difference(lastHeard) > silentDuration) {
          await _processEvent(
            AutomationEvent(type: TriggerType.nodeSilent, nodeNum: nodeNum),
          );
        }
      }
    }
  }

  /// Interpolate variables in message text
  String _interpolateVariables(
    String text,
    AutomationEvent event, {
    AutomationTrigger? trigger,
  }) {
    var result = text
        .replaceAll('{{node.name}}', event.nodeName ?? 'Unknown')
        .replaceAll('{{node.num}}', event.nodeNum?.toRadixString(16) ?? '')
        .replaceAll('{{battery}}', '${event.batteryLevel ?? '?'}%')
        .replaceAll(
          '{{location}}',
          event.latitude != null && event.longitude != null
              ? '${event.latitude}, ${event.longitude}'
              : 'Unknown',
        )
        .replaceAll('{{message}}', event.messageText ?? '')
        .replaceAll('{{time}}', DateTime.now().toIso8601String());

    // Trigger-specific context variables
    if (trigger != null) {
      result = result
          .replaceAll('{{threshold}}', '${trigger.batteryThreshold}%')
          .replaceAll('{{keyword}}', trigger.keyword ?? '')
          .replaceAll('{{zone.radius}}', '${trigger.geofenceRadius.round()}m')
          .replaceAll('{{silent.duration}}', '${trigger.silentMinutes} min')
          .replaceAll('{{signal.threshold}}', '${trigger.signalThreshold} dB')
          .replaceAll(
            '{{channel.name}}',
            'Channel ${trigger.channelIndex ?? 0}',
          );
    }

    return result;
  }

  /// Build trigger details string for logging
  String _buildTriggerDetails(AutomationEvent event) {
    final parts = <String>[];
    parts.add('Trigger: ${event.type.displayName}');
    if (event.nodeName != null) {
      parts.add('Node: ${event.nodeName}');
    }
    if (event.batteryLevel != null) {
      parts.add('Battery: ${event.batteryLevel}%');
    }
    if (event.messageText != null) {
      parts.add('Message: ${event.messageText}');
    }
    return parts.join(', ');
  }

  /// Parse time of day from string
  TimeOfDay? _parseTimeOfDay(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// Check if time is within range
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final now = time.hour * 60 + time.minute;
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;

    if (s <= e) {
      return now >= s && now <= e;
    } else {
      // Range crosses midnight
      return now >= s || now <= e;
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
