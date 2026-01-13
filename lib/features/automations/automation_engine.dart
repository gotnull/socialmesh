import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging.dart';
import '../../models/mesh_models.dart' show MeshNode;
import '../../services/ifttt/ifttt_service.dart';
import '../../services/audio/rtttl_player.dart';
import '../../services/audio/notification_sound_service.dart';
import '../../services/glyph_service.dart';
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
  final GlyphService? _glyphService;

  /// Callback to send a message via the mesh
  final Future<bool> Function(int nodeNum, String message)? onSendMessage;

  /// Callback to send a message to a channel
  final Future<bool> Function(int channelIndex, String message)?
  onSendToChannel;

  // Track node states for change detection
  final Map<int, bool> _nodeOnlineStatus = {};
  final Map<int, int> _nodeBatteryLevels = {};
  final Map<int, DateTime> _nodeLastHeard = {};
  final Map<int, String> _nodeNames = {};
  final Map<int, (double, double)> _nodePositions = {};

  // Hysteresis: track which battery low alerts have fired per node+automation
  // Key: "nodeNum_automationId", Value: true if fired (reset when battery goes above threshold)
  final Map<String, bool> _firedBatteryLowAlerts = {};

  // Throttling for repeated triggers
  final Map<String, DateTime> _lastTriggerTimes = {};
  static const _minTriggerInterval = Duration(minutes: 1);

  // Silent node monitoring
  Timer? _silentNodeTimer;

  AutomationEngine({
    required AutomationRepository repository,
    required IftttService iftttService,
    FlutterLocalNotificationsPlugin? notifications,
    GlyphService? glyphService,
    this.onSendMessage,
    this.onSendToChannel,
  }) : _repository = repository,
       _iftttService = iftttService,
       _notifications = notifications,
       _glyphService = glyphService;

  /// Start the automation engine
  void start() {
    _startSilentNodeMonitor();
    AppLogging.automations('AutomationEngine: Started');
  }

  /// Stop the automation engine
  void stop() {
    _silentNodeTimer?.cancel();
    _silentNodeTimer = null;
    AppLogging.automations('AutomationEngine: Stopped');
  }

  /// Execute an automation manually (e.g., from Siri Shortcuts)
  Future<void> executeAutomationManually(
    Automation automation,
    AutomationEvent event,
  ) async {
    AppLogging.automations(
      'AutomationEngine: Manual execution of "${automation.name}"',
    );
    await _executeAutomation(automation, event);
  }

  /// Process a node update event
  Future<void> processNodeUpdate(
    MeshNode node, {
    MeshNode? previousNode,
  }) async {
    // Track node name for silent node lookups
    _nodeNames[node.nodeNum] = node.displayName;

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

      // Battery low check with hysteresis - only fire on threshold CROSSING
      final batteryLowAutomations = automations
          .where((a) => a.trigger.type == TriggerType.batteryLow)
          .toList();

      for (final automation in batteryLowAutomations) {
        final threshold = automation.trigger.batteryThreshold;
        final hysteresisKey = '${node.nodeNum}_${automation.id}';

        // If this is the FIRST time we see this node's battery, initialize hysteresis state
        // Don't fire on first sight - we don't know if it "crossed" or was already below
        if (previousBattery == null) {
          _firedBatteryLowAlerts[hysteresisKey] =
              node.batteryLevel! <= threshold;
          continue;
        }

        // Reset fired state when battery goes above threshold (with small buffer)
        if (node.batteryLevel! > threshold + 5) {
          if (_firedBatteryLowAlerts[hysteresisKey] == true) {
            AppLogging.automations(
              '🔋 Battery recovered above $threshold+5: resetting hysteresis for ${automation.name}',
            );
            _firedBatteryLowAlerts[hysteresisKey] = false;
          }
        }

        // Fire only on CROSSING: previous was above threshold, now at or below
        if (previousBattery > threshold &&
            node.batteryLevel! <= threshold &&
            _firedBatteryLowAlerts[hysteresisKey] != true) {
          AppLogging.automations(
            '🔋 Battery crossed threshold $threshold: $previousBattery -> ${node.batteryLevel} (firing ${automation.name})',
          );
          _firedBatteryLowAlerts[hysteresisKey] = true;
          await _processEvent(
            AutomationEvent(
              type: TriggerType.batteryLow,
              nodeNum: node.nodeNum,
              nodeName: node.displayName,
              batteryLevel: node.batteryLevel,
            ),
          );
        }
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

    AppLogging.automations(
      'AutomationEngine: Processing ${event.type.name} event',
    );
    AppLogging.automations(
      '🤖 AutomationEngine: Found ${automations.length} matching automations',
    );

    for (final automation in automations) {
      AppLogging.automations('AutomationEngine: Checking "${automation.name}"');
      if (_shouldTrigger(automation, event)) {
        AppLogging.automations(
          'AutomationEngine: TRIGGERING "${automation.name}"',
        );
        await _executeAutomation(automation, event);
      } else {
        AppLogging.automations(
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
      AppLogging.automations('_shouldTrigger: Throttled');
      return false;
    }

    // Check node filter
    if (trigger.nodeNum != null && trigger.nodeNum != event.nodeNum) {
      AppLogging.automations(
        '🤖 _shouldTrigger: Node filter mismatch (trigger=${trigger.nodeNum}, event=${event.nodeNum})',
      );
      return false;
    }

    // Check trigger-specific conditions
    switch (trigger.type) {
      case TriggerType.batteryLow:
        if (event.batteryLevel == null ||
            event.batteryLevel! > trigger.batteryThreshold) {
          AppLogging.automations(
            '_shouldTrigger: Battery level not below threshold',
          );
          return false;
        }
        break;

      case TriggerType.messageContains:
        if (trigger.keyword == null || event.messageText == null) {
          AppLogging.automations(
            '🤖 _shouldTrigger: messageContains - keyword=${trigger.keyword}, message=${event.messageText}',
          );
          return false;
        }
        final keywordLower = trigger.keyword!.toLowerCase();
        final messageLower = event.messageText!.toLowerCase();
        if (!messageLower.contains(keywordLower)) {
          AppLogging.automations(
            '🤖 _shouldTrigger: messageContains - "$messageLower" does not contain "$keywordLower"',
          );
          return false;
        }
        AppLogging.automations(
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
    AppLogging.automations('AutomationEngine: Executing "${automation.name}"');

    // Update throttle
    final throttleKey = '${automation.id}_${event.type.name}';
    _lastTriggerTimes[throttleKey] = DateTime.now();

    final actionsExecuted = <String>[];
    final actionResults = <ActionResult>[];
    String? errorMessage;

    try {
      for (final action in automation.actions) {
        final result = await _executeAction(action, event, automation);
        actionsExecuted.add(action.type.displayName);
        actionResults.add(result);
        AppLogging.automations(
          'AutomationEngine: Action "${action.type.displayName}" - ${result.success ? "SUCCESS" : "FAILED: ${result.errorMessage}"}',
        );
      }

      // Update automation stats
      await _repository.recordTrigger(automation.id);
    } catch (e) {
      errorMessage = e.toString();
      AppLogging.automations(
        'AutomationEngine: Error executing automation: $e',
      );
    }

    // Determine overall success (all actions succeeded and no error)
    final allActionsSucceeded = actionResults.every((r) => r.success);
    final overallSuccess = errorMessage == null && allActionsSucceeded;

    // Build error message from failed actions if none set
    if (errorMessage == null && !allActionsSucceeded) {
      final failedActions = actionResults
          .where((r) => !r.success)
          .map((r) => '${r.actionName}: ${r.errorMessage}')
          .toList();
      errorMessage = 'Failed actions: ${failedActions.join("; ")}';
    }

    // Log execution
    await _repository.addLogEntry(
      AutomationLogEntry(
        automationId: automation.id,
        automationName: automation.name,
        timestamp: DateTime.now(),
        success: overallSuccess,
        triggerDetails: _buildTriggerDetails(event),
        actionsExecuted: actionsExecuted,
        actionResults: actionResults,
        errorMessage: errorMessage,
      ),
    );
  }

  /// Execute a single action and return detailed result
  Future<ActionResult> _executeAction(
    AutomationAction action,
    AutomationEvent event,
    Automation automation,
  ) async {
    final actionName = action.type.displayName;

    try {
      switch (action.type) {
        case ActionType.sendMessage:
          if (onSendMessage == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Send message callback not configured',
            );
          }
          if (action.targetNodeNum == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'No target node specified',
            );
          }
          final message = _interpolateVariables(
            action.messageText ?? '',
            event,
            trigger: automation.trigger,
          );
          final sent = await onSendMessage!(action.targetNodeNum!, message);
          return ActionResult(
            actionName: actionName,
            success: sent,
            errorMessage: sent ? null : 'Failed to send message',
          );

        case ActionType.sendToChannel:
          if (onSendToChannel == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Send to channel callback not configured',
            );
          }
          if (action.targetChannelIndex == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'No target channel specified',
            );
          }
          final message = _interpolateVariables(
            action.messageText ?? '',
            event,
            trigger: automation.trigger,
          );
          final sent = await onSendToChannel!(
            action.targetChannelIndex!,
            message,
          );
          return ActionResult(
            actionName: actionName,
            success: sent,
            errorMessage: sent ? null : 'Failed to send to channel',
          );

        case ActionType.playSound:
          final rtttl = action.soundRtttl;
          if (rtttl == null || rtttl.isEmpty) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'No sound configured',
            );
          }
          final player = RtttlPlayer();
          try {
            await player.play(rtttl);
            return ActionResult(actionName: actionName, success: true);
          } catch (e) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Failed to play sound: $e',
            );
          } finally {
            await player.dispose();
          }

        case ActionType.vibrate:
          // Trigger haptic feedback for vibration
          await HapticFeedback.heavyImpact();
          // Add a small delay and vibrate again for emphasis
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          return ActionResult(actionName: actionName, success: true);

        case ActionType.pushNotification:
          if (_notifications == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Notifications not initialized',
            );
          }
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

          // Prepare custom notification sound if configured
          String? soundFileName;
          final customSoundRtttl = action.notificationSoundRtttl;
          if (customSoundRtttl != null && customSoundRtttl.isNotEmpty) {
            try {
              soundFileName = await NotificationSoundService.instance
                  .prepareSoundFromRtttl(customSoundRtttl);
            } catch (e) {
              AppLogging.automations(
                'Failed to prepare notification sound: $e',
              );
            }
          }

          // Show notification with custom or default sound
          await _notifications.show(
            automation.id.hashCode,
            title,
            body,
            NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                sound: soundFileName,
              ),
            ),
          );

          // Also play the sound through the audio player for immediate feedback
          // (notification sound may be delayed or silenced by system)
          if (customSoundRtttl != null && customSoundRtttl.isNotEmpty) {
            final player = RtttlPlayer();
            try {
              await player.play(customSoundRtttl);
            } catch (e) {
              AppLogging.automations('Failed to play notification sound: $e');
            } finally {
              await player.dispose();
            }
          }
          return ActionResult(actionName: actionName, success: true);

        case ActionType.triggerWebhook:
          if (action.webhookEventName == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'No webhook event name specified',
            );
          }

          // Check if IFTTT is configured before attempting
          if (!_iftttService.isActive) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage:
                  'IFTTT not configured - enable IFTTT and set webhook key in settings',
            );
          }

          // Build value1, value2, value3 from event data
          String? value1;
          String? value2;
          String? value3;

          // value1: Node name or message sender
          if (event.nodeName != null) {
            value1 = event.nodeName;
          }

          // value2: Location or message text
          if (event.latitude != null && event.longitude != null) {
            value2 = '${event.latitude},${event.longitude}';
          } else if (event.messageText != null) {
            value2 = event.messageText;
          }

          // value3: Additional context (battery, SNR, timestamp)
          final contextParts = <String>[];
          if (event.batteryLevel != null) {
            contextParts.add('Battery: ${event.batteryLevel}%');
          }
          if (event.snr != null) {
            contextParts.add('SNR: ${event.snr}');
          }
          contextParts.add('Time: ${event.timestamp.toIso8601String()}');
          value3 = contextParts.join(', ');

          final webhookSuccess = await _iftttService.triggerCustomEvent(
            eventName: action.webhookEventName!,
            value1: value1,
            value2: value2,
            value3: value3,
          );
          return ActionResult(
            actionName: actionName,
            success: webhookSuccess,
            errorMessage: webhookSuccess
                ? null
                : 'Webhook request failed - check network connection',
          );

        case ActionType.logEvent:
          // Already logging executions
          return ActionResult(actionName: actionName, success: true);

        case ActionType.updateWidget:
          // Widget updates handled via WidgetKit
          return ActionResult(actionName: actionName, success: true);

        case ActionType.triggerShortcut:
          // iOS Shortcuts via URL scheme
          if (!Platform.isIOS) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Shortcuts only available on iOS',
            );
          }

          final shortcutName = action.shortcutName;
          if (shortcutName == null || shortcutName.isEmpty) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'No shortcut name specified',
            );
          }

          // Build input text from event variables (JSON format)
          final inputText = _buildShortcutInput(event);

          // URL encode the shortcut name and input
          final encodedName = Uri.encodeComponent(shortcutName);
          final encodedInput = Uri.encodeComponent(inputText);

          // Use x-callback-url to return to app after shortcut completes
          // The shortcut can access the input via "Shortcut Input" action
          // and parse it as JSON using "Get Dictionary from Input"
          final shortcutUrl = Uri.parse(
            'shortcuts://x-callback-url/run-shortcut?name=$encodedName&input=text&text=$encodedInput',
          );

          try {
            final launched = await launchUrl(
              shortcutUrl,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              return ActionResult(
                actionName: actionName,
                success: false,
                errorMessage: 'Could not launch shortcut "$shortcutName"',
              );
            }
            return ActionResult(actionName: actionName, success: true);
          } catch (e) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Failed to run shortcut: $e',
            );
          }

        case ActionType.glyphPattern:
          // Nothing Phone glyph patterns
          if (_glyphService == null || !_glyphService.isSupported) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Glyph interface not available',
            );
          }

          final pattern = action.config['pattern'] as String? ?? 'pulse';

          try {
            switch (pattern) {
              case 'connected':
                await _glyphService.showConnected();
              case 'disconnected':
                await _glyphService.showDisconnected();
              case 'message':
                await _glyphService.showMessageReceived();
              case 'dm':
                await _glyphService.showMessageReceived(isDM: true);
              case 'sent':
                await _glyphService.showMessageSent();
              case 'node_online':
                await _glyphService.showNodeOnline();
              case 'node_offline':
                await _glyphService.showNodeOffline();
              case 'signal_nearby':
                await _glyphService.showSignalNearby();
              case 'low_battery':
                await _glyphService.showLowBattery();
              case 'error':
                await _glyphService.showError();
              case 'success':
                await _glyphService.showSuccess();
              case 'syncing':
                await _glyphService.showSyncing();
              case 'pulse':
              default:
                await _glyphService.showAutomationTriggered();
            }

            return ActionResult(actionName: actionName, success: true);
          } catch (e) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: 'Failed to show glyph pattern: $e',
            );
          }
      }
    } catch (e) {
      return ActionResult(
        actionName: actionName,
        success: false,
        errorMessage: e.toString(),
      );
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
            AutomationEvent(
              type: TriggerType.nodeSilent,
              nodeNum: nodeNum,
              nodeName: _nodeNames[nodeNum],
            ),
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

  /// Build input text for iOS Shortcut from event data
  /// The shortcut can parse this JSON using "Get Dictionary from Input" action
  String _buildShortcutInput(AutomationEvent event) {
    final data = <String, dynamic>{
      'trigger': event.type.name,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (event.nodeNum != null) {
      data['node_num'] = '!${event.nodeNum!.toRadixString(16)}';
    }
    if (event.nodeName != null) {
      data['node_name'] = event.nodeName;
    }
    if (event.batteryLevel != null) {
      data['battery'] = event.batteryLevel;
    }
    if (event.latitude != null && event.longitude != null) {
      data['latitude'] = event.latitude;
      data['longitude'] = event.longitude;
    }
    if (event.messageText != null) {
      data['message'] = event.messageText;
    }
    if (event.channelIndex != null) {
      data['channel'] = event.channelIndex;
    }
    if (event.snr != null) {
      data['snr'] = event.snr;
    }

    // Return as JSON string - shortcut uses "Get Dictionary from Input" to parse
    return jsonEncode(data);
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
