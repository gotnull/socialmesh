// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:socialmesh/features/nodes/node_display_name_resolver.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:intl/intl.dart';

import '../../utils/time_format.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging.dart';
import '../../models/presence_confidence.dart';
import '../../models/mesh_models.dart' show MeshNode;
import '../../services/ifttt/ifttt_service.dart';
import '../../services/audio/rtttl_player.dart';
import '../../services/audio/notification_sound_service.dart';
import '../../services/glyph_service.dart';
import 'models/automation.dart';
import 'models/condition_node.dart';
import 'models/condition_node_result.dart';
import 'models/schedule_spec.dart';
import 'automation_debug_service.dart';
import 'automation_repository.dart';
import 'scheduler_service.dart';
import 'services/notification_renderer/notification_renderer_module.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

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
  final AutomationDebugService? _debugService;
  Scheduler? _scheduler;
  StreamSubscription<ScheduledFireEvent>? _schedulerSubscription;

  // Callback to send a message via the mesh. The `protocol` carries
  // the firing event's source (`event.protocol`) so the wiring layer
  // can route via Meshtastic's `protocolServiceProvider` or
  // MeshCore's `meshCoreSessionProvider`. Tests that only care about
  // node-num + text can ignore the third argument.
  final Future<bool> Function(
    int nodeNum,
    String message,
    TriggerProtocol protocol,
  )?
  onSendMessage;

  // Same shape for channel sends.
  final Future<bool> Function(
    int channelIndex,
    String message,
    TriggerProtocol protocol,
  )?
  onSendToChannel;

  /// Callback to resolve the local device's node number.
  /// Used to enrich scheduled events with the connected radio's telemetry.
  final int? Function()? onGetMyNodeNum;

  /// Callback to get the phone's current GPS position (lat, lon).
  /// Used to enrich scheduled events with the phone's location.
  final Future<(double, double)?> Function()? onGetPhonePosition;

  // Track node states for change detection
  final Map<int, PresenceConfidence> _nodePresence = {};
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
    AutomationDebugService? debugService,
    Scheduler? scheduler,
    this.onSendMessage,
    this.onSendToChannel,
    this.onGetMyNodeNum,
    this.onGetPhonePosition,
  }) : _repository = repository,
       _iftttService = iftttService,
       _notifications = notifications,
       _glyphService = glyphService,
       _debugService = debugService,
       _scheduler = scheduler;

  /// Set the scheduler (can be done after construction for dependency injection)
  void setScheduler(Scheduler scheduler) {
    _scheduler = scheduler;
  }

  /// Get the current scheduler
  Scheduler? get scheduler => _scheduler;

  /// Start the automation engine
  void start() {
    _startSilentNodeMonitor();
    _startScheduler();
    AppLogging.automations('AutomationEngine: Started');
  }

  /// Stop the automation engine
  void stop() {
    _silentNodeTimer?.cancel();
    _silentNodeTimer = null;
    _stopScheduler();
    AppLogging.automations('AutomationEngine: Stopped');
  }

  /// Start the scheduler and subscribe to events
  void _startScheduler() {
    if (_scheduler == null) return;

    _schedulerSubscription?.cancel();
    _schedulerSubscription = _scheduler!.fireEvents.listen((event) {
      processScheduledEvent(event);
    });

    _scheduler!.start();
    AppLogging.automations('AutomationEngine: Scheduler started');
  }

  /// Stop the scheduler
  void _stopScheduler() {
    _schedulerSubscription?.cancel();
    _schedulerSubscription = null;
    _scheduler?.stop();
  }

  /// Process a scheduled fire event from the scheduler.
  ///
  /// Enriches the event with the connected radio's last-known battery level
  /// and the phone's current GPS position so that {{battery}} and
  /// {{location}} template variables resolve to real values.
  Future<void> processScheduledEvent(ScheduledFireEvent event) async {
    AppLogging.automations(
      'AutomationEngine: Processing scheduled event ${event.slotKey}'
      '${event.isCatchUp ? " (catch-up)" : ""}',
    );

    // Resolve the local radio's battery from cached telemetry
    int? batteryLevel;
    final myNodeNum = onGetMyNodeNum?.call();
    if (myNodeNum != null) {
      batteryLevel = _nodeBatteryLevels[myNodeNum];
    }

    // Resolve the phone's current GPS position
    double? latitude;
    double? longitude;
    try {
      final pos = await onGetPhonePosition?.call();
      if (pos != null) {
        latitude = pos.$1;
        longitude = pos.$2;
      }
    } catch (e) {
      AppLogging.automations(
        'AutomationEngine: Failed to get phone position: $e',
      );
    }

    // Fall back to the local radio's last-known position
    if (latitude == null && myNodeNum != null) {
      final nodePos = _nodePositions[myNodeNum];
      if (nodePos != null) {
        latitude = nodePos.$1;
        longitude = nodePos.$2;
      }
    }

    AppLogging.automations(
      'AutomationEngine: Scheduled event enrichment — '
      'battery=$batteryLevel, lat=$latitude, lon=$longitude',
    );

    await _processEvent(
      AutomationEvent(
        type: TriggerType.scheduled,
        scheduleId: event.scheduleId,
        slotKey: event.slotKey,
        scheduledFor: event.scheduledFor,
        isCatchUp: event.isCatchUp,
        batteryLevel: batteryLevel,
        latitude: latitude,
        longitude: longitude,
        nodeNum: myNodeNum,
        nodeName: myNodeNum != null ? _nodeNames[myNodeNum] : null,
      ),
    );
  }

  /// Execute an automation manually (e.g., from Siri Shortcuts)
  ///
  /// Enriches the event with the connected radio's last-known battery level,
  /// node name, and the phone's current GPS position so that {{battery}},
  /// {{node.name}}, and {{location}} template variables resolve to real values.
  Future<void> executeAutomationManually(
    Automation automation,
    AutomationEvent event,
  ) async {
    AppLogging.automations(
      'AutomationEngine: Manual execution of "${automation.name}"',
    );

    // Enrich event with current device context if not already provided
    int? batteryLevel = event.batteryLevel;
    int? nodeNum = event.nodeNum;
    String? nodeName = event.nodeName;
    double? latitude = event.latitude;
    double? longitude = event.longitude;

    // Resolve local radio's battery and name from cached telemetry
    final myNodeNum = onGetMyNodeNum?.call();
    if (myNodeNum != null) {
      nodeNum ??= myNodeNum;
      nodeName ??= _nodeNames[myNodeNum];
      batteryLevel ??= _nodeBatteryLevels[myNodeNum];
    }

    // Resolve the phone's current GPS position
    if (latitude == null) {
      try {
        final pos = await onGetPhonePosition?.call();
        if (pos != null) {
          latitude = pos.$1;
          longitude = pos.$2;
        }
      } catch (e) {
        AppLogging.automations(
          'AutomationEngine: Failed to get phone position for manual exec: $e',
        );
      }

      // Fall back to the local radio's last-known position
      if (latitude == null && myNodeNum != null) {
        final nodePos = _nodePositions[myNodeNum];
        if (nodePos != null) {
          latitude = nodePos.$1;
          longitude = nodePos.$2;
        }
      }
    }

    AppLogging.automations(
      'AutomationEngine: Manual event enrichment — '
      'battery=$batteryLevel, node=$nodeName, lat=$latitude, lon=$longitude',
    );

    final enrichedEvent = AutomationEvent(
      type: event.type,
      nodeNum: nodeNum,
      nodeName: nodeName,
      batteryLevel: batteryLevel,
      latitude: latitude,
      longitude: longitude,
      messageText: event.messageText,
      channelIndex: event.channelIndex,
      snr: event.snr,
      sensorName: event.sensorName,
      sensorDetected: event.sensorDetected,
      timestamp: event.timestamp,
      scheduleId: event.scheduleId,
      slotKey: event.slotKey,
      scheduledFor: event.scheduledFor,
      isCatchUp: event.isCatchUp,
    );

    await _executeAutomation(
      automation,
      enrichedEvent,
      branchActions: automation.effectiveThenActions,
      branchResult: const BranchSelectionResult(
        selection: BranchSelection.thenBranch,
        reason: 'Manual execution — condition evaluation bypassed, THEN path',
        manualBypass: true,
      ),
    );
  }

  /// Process a node update event
  Future<void> processNodeUpdate(
    MeshNode node, {
    MeshNode? previousNode,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    // Track node name for silent node lookups
    _nodeNames[node.nodeNum] = node.displayName;

    final automations = _repository.automations
        .where((a) => a.enabled)
        .toList();
    if (automations.isEmpty) return;

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
          final pos = _nodePositions[node.nodeNum];
          await _processEvent(
            AutomationEvent(
              type: TriggerType.batteryLow,
              nodeNum: node.nodeNum,
              nodeName: node.displayName,
              batteryLevel: node.batteryLevel,
              latitude: pos?.$1,
              longitude: pos?.$2,
              protocol: protocol,
            ),
          );
        }
      }

      // Battery full check
      if (previousBattery != null &&
          previousBattery < 100 &&
          node.batteryLevel == 100) {
        final fullPos = _nodePositions[node.nodeNum];
        await _processEvent(
          AutomationEvent(
            type: TriggerType.batteryFull,
            nodeNum: node.nodeNum,
            nodeName: node.displayName,
            batteryLevel: node.batteryLevel,
            latitude: fullPos?.$1,
            longitude: fullPos?.$2,
            protocol: protocol,
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
            batteryLevel: _nodeBatteryLevels[node.nodeNum],
            latitude: node.latitude,
            longitude: node.longitude,
            protocol: protocol,
          ),
        );

        // Check geofence events for all automations with geofence triggers
        await _checkGeofenceEvents(
          node,
          previousPos,
          currentPos,
          protocol: protocol,
        );
      }
    }

    // Check signal strength
    if (node.snr != null) {
      final snrPos = _nodePositions[node.nodeNum];
      await _processEvent(
        AutomationEvent(
          type: TriggerType.signalWeak,
          nodeNum: node.nodeNum,
          nodeName: node.displayName,
          batteryLevel: _nodeBatteryLevels[node.nodeNum],
          snr: node.snr,
          latitude: snrPos?.$1,
          longitude: snrPos?.$2,
          protocol: protocol,
        ),
      );
    }

    // Capture previous lastHeard for presence calculation
    final prevLastHeard = _nodeLastHeard[node.nodeNum];

    // Update last heard for silent node detection
    if (node.lastHeard != null) {
      _nodeLastHeard[node.nodeNum] = node.lastHeard!;
    }

    // Presence detection: determine if the node transitioned between active/inactive
    try {
      final now = DateTime.now();
      // Prefer previously computed presence if available, else derive from previous lastHeard
      final previousPresence =
          _nodePresence[node.nodeNum] ??
          PresenceCalculator.fromLastHeard(prevLastHeard, now: now);
      final currentPresence = PresenceCalculator.fromLastHeard(
        node.lastHeard,
        now: now,
      );

      if (previousPresence != currentPresence) {
        await processPresenceUpdate(
          node,
          previous: previousPresence,
          current: currentPresence,
          protocol: protocol,
        );
      }
    } catch (e) {
      AppLogging.automations('AutomationEngine: Presence detection error: $e');
    }
  }

  /// Process presence transition events (active/inactive)
  Future<void> processPresenceUpdate(
    MeshNode node, {
    required PresenceConfidence previous,
    required PresenceConfidence current,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    final automations = _repository.automations
        .where((a) => a.enabled)
        .toList();
    if (automations.isEmpty) return;

    _nodePresence[node.nodeNum] = current;

    if (current.isActive && !previous.isActive) {
      await _processEvent(
        AutomationEvent(
          type: TriggerType.nodeOnline,
          nodeNum: node.nodeNum,
          nodeName: node.displayName,
          batteryLevel: node.batteryLevel,
          latitude: node.latitude,
          longitude: node.longitude,
          protocol: protocol,
        ),
      );
      return;
    }

    if (current.isInactive && !previous.isInactive) {
      await _processEvent(
        AutomationEvent(
          type: TriggerType.nodeOffline,
          nodeNum: node.nodeNum,
          nodeName: node.displayName,
          batteryLevel: _nodeBatteryLevels[node.nodeNum],
          latitude: node.latitude,
          longitude: node.longitude,
          protocol: protocol,
        ),
      );
    }
  }

  /// Process an incoming message
  Future<void> processMessage(
    AutomationMessage message, {
    required String senderName,
    String? channelName,
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
    // Enrich message events with cached node data. Cached battery /
    // position only exists on the Meshtastic side; MeshCore events
    // arrive with null which is harmless.
    final msgBattery = _nodeBatteryLevels[message.from];
    final msgPos = _nodePositions[message.from];

    // Message received trigger
    await _processEvent(
      AutomationEvent(
        type: TriggerType.messageReceived,
        nodeNum: message.from,
        nodeName: senderName,
        messageText: message.text,
        channelIndex: message.channel,
        batteryLevel: msgBattery,
        latitude: msgPos?.$1,
        longitude: msgPos?.$2,
        protocol: protocol,
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
        batteryLevel: msgBattery,
        latitude: msgPos?.$1,
        longitude: msgPos?.$2,
        protocol: protocol,
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
          batteryLevel: msgBattery,
          latitude: msgPos?.$1,
          longitude: msgPos?.$2,
          protocol: protocol,
        ),
      );
    }
  }

  /// Process a detection sensor event from the mesh
  Future<void> processDetectionSensorEvent({
    required int nodeNum,
    required String sensorName,
    required bool detected,
  }) async {
    AppLogging.automations(
      'AutomationEngine: Detection sensor event from $nodeNum: $sensorName = $detected',
    );

    final sensorPos = _nodePositions[nodeNum];
    await _processEvent(
      AutomationEvent(
        type: TriggerType.detectionSensor,
        nodeNum: nodeNum,
        nodeName:
            _nodeNames[nodeNum] ?? NodeDisplayNameResolver.defaultName(nodeNum),
        sensorName: sensorName,
        sensorDetected: detected,
        batteryLevel: _nodeBatteryLevels[nodeNum],
        latitude: sensorPos?.$1,
        longitude: sensorPos?.$2,
      ),
    );
  }

  // Derive the routing protocol for an automation+event pair. A
  // pinned trigger filter wins outright; otherwise the firing event's
  // own protocol carries through. Scheduled events use this same
  // helper so a meshcore-pinned scheduled trigger dispatches its
  // actions via MeshCore even though the scheduled event itself has
  // no source protocol (default `meshtastic` exists only as a
  // placeholder for the gate).
  TriggerProtocol _routingProtocol(
    Automation automation,
    AutomationEvent event,
  ) {
    switch (automation.trigger.protocolFilter) {
      case TriggerProtocolFilter.meshtastic:
        return TriggerProtocol.meshtastic;
      case TriggerProtocolFilter.meshcore:
        return TriggerProtocol.meshcore;
      case TriggerProtocolFilter.any:
        return event.protocol;
    }
  }

  /// Process an automation event
  Future<void> _processEvent(AutomationEvent event) async {
    final automations = _repository.automations
        .where(
          (a) =>
              a.enabled &&
              a.trigger.type == event.type &&
              // Scheduled events have no source protocol — the user's
              // filter intent is honoured at action dispatch via
              // `_routingProtocol`, so the gate skips the protocol
              // check here. Every other event type carries a real
              // source protocol (Meshtastic vs MeshCore) and is gated
              // normally.
              (event.type == TriggerType.scheduled ||
                  a.trigger.matchesProtocol(event.protocol)),
        )
        .toList();

    AppLogging.automations(
      'AutomationEngine: Processing ${event.type.name} event',
    );
    AppLogging.automations(
      '🤖 AutomationEngine: Found ${automations.length} matching automations',
    );

    for (final automation in automations) {
      AppLogging.automations('AutomationEngine: Checking "${automation.name}"');
      final skipReason = _evaluateTrigger(automation, event);
      if (skipReason == null) {
        AppLogging.automations(
          'AutomationEngine: TRIGGERING "${automation.name}"',
        );

        // Phase 3: Determine branch selection based on condition result.
        final branchResult = _selectBranch(automation, event);
        if (branchResult.selection == BranchSelection.none) {
          // Condition failed and no ELSE branch — skip execution.
          AppLogging.automations(
            '🤖 AutomationEngine: No branch to execute for "${automation.name}" '
            '(${branchResult.reason})',
          );
          _debugService?.recordEvaluation(
            AutomationEvaluation(
              automationId: automation.id,
              automationName: automation.name,
              enabled: automation.enabled,
              triggerType: automation.trigger.type,
              eventType: event.type,
              timestamp: DateTime.now(),
              triggered: false,
              skipReason: SkipReason.conditionFailed,
              skipDetails: branchResult.reason,
              eventData: _buildEventData(event),
              triggerConfig: automation.trigger.config,
              conditionTreeResult: branchResult.conditionTreeResult,
              branchSelection: BranchSelection.none,
              branchReason: branchResult.reason,
            ),
          );
        } else {
          // Execute the selected branch's actions.
          final branchActions =
              branchResult.selection == BranchSelection.thenBranch
              ? automation.effectiveThenActions
              : automation.effectiveElseActions!;
          await _executeAutomation(
            automation,
            event,
            branchActions: branchActions,
            branchResult: branchResult,
          );
        }
      } else {
        AppLogging.automations(
          '🤖 AutomationEngine: Skipped "${automation.name}" (${skipReason.displayName})',
        );
        // Build condition tree result for debug when skipped due to conditions
        ConditionNodeResult? treeResult;
        if (skipReason == SkipReason.conditionFailed) {
          final tree = automation.effectiveConditionTree;
          if (tree != null) {
            treeResult = evaluateConditionTree(tree, event);
          }
        }
        _debugService?.recordEvaluation(
          AutomationEvaluation(
            automationId: automation.id,
            automationName: automation.name,
            enabled: automation.enabled,
            triggerType: automation.trigger.type,
            eventType: event.type,
            timestamp: DateTime.now(),
            triggered: false,
            skipReason: skipReason,
            skipDetails: skipReason.displayName,
            eventData: _buildEventData(event),
            triggerConfig: automation.trigger.config,
            conditionTreeResult: treeResult,
          ),
        );
      }
    }
  }

  /// Select which branch to execute based on condition evaluation.
  ///
  /// Evaluates the condition tree exactly once and returns a structured
  /// [BranchSelectionResult] indicating which branch should execute.
  BranchSelectionResult _selectBranch(
    Automation automation,
    AutomationEvent event,
  ) {
    final tree = automation.effectiveConditionTree;

    // No conditions → always THEN.
    if (tree == null) {
      return const BranchSelectionResult(
        selection: BranchSelection.thenBranch,
        reason: 'No conditions — default THEN path',
      );
    }

    final treeResult = evaluateConditionTree(tree, event);

    if (treeResult.passed) {
      return BranchSelectionResult(
        selection: BranchSelection.thenBranch,
        reason: 'Condition tree passed — THEN path',
        conditionTreeResult: treeResult,
      );
    }

    // Condition failed — check for ELSE branch.
    if (automation.effectiveElseActions != null) {
      return BranchSelectionResult(
        selection: BranchSelection.elseBranch,
        reason: 'Condition tree failed — ELSE path',
        conditionTreeResult: treeResult,
      );
    }

    // Condition failed, no ELSE — skip.
    return BranchSelectionResult(
      selection: BranchSelection.none,
      reason: 'Condition tree failed — no ELSE branch, skipping',
      conditionTreeResult: treeResult,
    );
  }

  /// Derive a domain-aware dedupe key for throttling.
  ///
  /// The key always starts with `automationId_triggerType` and appends
  /// the most specific discriminator available for the event type:
  ///
  /// - Node-based triggers (nodeOnline/Offline, battery*, positionChanged,
  ///   signalWeak, detectionSensor): append `_node{nodeNum}`.
  /// - Message/channel triggers (messageReceived, messageContains,
  ///   channelActivity): append `_node{nodeNum}` when available, plus
  ///   `_ch{channelIndex}` for channel activity.
  /// - Scheduled triggers: append `_slot{slotKey}` when available, or
  ///   `_at{scheduledFor.millisecondsSinceEpoch}` for catch-up precision.
  /// - Geofence triggers: append `_node{nodeNum}` when available.
  /// - Manual / other: no extra discriminator (falls back to per-automation).
  static String buildDedupeKey(Automation automation, AutomationEvent event) {
    final buf = StringBuffer('${automation.id}_${event.type.name}');

    switch (event.type) {
      // Node-scoped triggers — dedupe per originating node
      case TriggerType.nodeOnline:
      case TriggerType.nodeOffline:
      case TriggerType.batteryLow:
      case TriggerType.batteryFull:
      case TriggerType.positionChanged:
      case TriggerType.signalWeak:
      case TriggerType.nodeSilent:
      case TriggerType.detectionSensor:
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        if (event.nodeNum != null) buf.write('_node${event.nodeNum}');
        break;

      // Message-scoped triggers — dedupe per sender (and channel when relevant)
      case TriggerType.messageReceived:
      case TriggerType.messageContains:
        if (event.nodeNum != null) buf.write('_node${event.nodeNum}');
        break;
      case TriggerType.channelActivity:
        if (event.channelIndex != null) {
          buf.write('_ch${event.channelIndex}');
        }
        if (event.nodeNum != null) buf.write('_node${event.nodeNum}');
        break;

      // Schedule-scoped triggers — dedupe per slot
      case TriggerType.scheduled:
        if (event.slotKey != null) {
          buf.write('_slot${event.slotKey}');
        } else if (event.scheduledFor != null) {
          buf.write('_at${event.scheduledFor!.millisecondsSinceEpoch}');
        }
        break;

      // Manual — no extra discriminator
      case TriggerType.manual:
        break;
    }

    return buf.toString();
  }

  /// Check if automation should trigger for this event.
  ///
  /// Returns `null` if the automation should fire, or a [SkipReason]
  /// explaining why it was skipped.
  SkipReason? _evaluateTrigger(Automation automation, AutomationEvent event) {
    final trigger = automation.trigger;

    // Check throttling using domain-aware dedupe key
    final throttleKey = buildDedupeKey(automation, event);
    final lastTrigger = _lastTriggerTimes[throttleKey];
    if (lastTrigger != null &&
        DateTime.now().difference(lastTrigger) < _minTriggerInterval) {
      AppLogging.automations('_evaluateTrigger: Throttled');
      return SkipReason.throttled;
    }

    // Check node filter
    if (trigger.nodeNum != null && trigger.nodeNum != event.nodeNum) {
      AppLogging.automations(
        '🤖 _evaluateTrigger: Node filter mismatch (trigger=${trigger.nodeNum}, event=${event.nodeNum})',
      );
      return SkipReason.nodeFilterMismatch;
    }

    // Check trigger-specific conditions
    switch (trigger.type) {
      case TriggerType.batteryLow:
        if (event.batteryLevel == null ||
            event.batteryLevel! > trigger.batteryThreshold) {
          AppLogging.automations(
            '_evaluateTrigger: Battery level not below threshold',
          );
          return SkipReason.batteryThresholdNotMet;
        }
        break;

      case TriggerType.messageContains:
        if (trigger.keyword == null || event.messageText == null) {
          AppLogging.automations(
            '🤖 _evaluateTrigger: messageContains - keyword=${trigger.keyword}, message=${event.messageText}',
          );
          return SkipReason.keywordNotMatched;
        }
        final keywordLower = trigger.keyword!.toLowerCase();
        final messageLower = event.messageText!.toLowerCase();
        if (!messageLower.contains(keywordLower)) {
          AppLogging.automations(
            '🤖 _evaluateTrigger: messageContains - "$messageLower" does not contain "$keywordLower"',
          );
          return SkipReason.keywordNotMatched;
        }
        AppLogging.automations(
          '🤖 _evaluateTrigger: messageContains - MATCH! "$messageLower" contains "$keywordLower"',
        );
        break;

      case TriggerType.signalWeak:
        if (event.snr == null || event.snr! > trigger.signalThreshold) {
          return SkipReason.signalThresholdNotMet;
        }
        break;

      case TriggerType.channelActivity:
        if (trigger.channelIndex != null &&
            trigger.channelIndex != event.channelIndex) {
          return SkipReason.channelFilterMismatch;
        }
        break;

      case TriggerType.detectionSensor:
        // Check sensor name filter
        final sensorFilter = trigger.sensorNameFilter;
        if (sensorFilter != null && sensorFilter.isNotEmpty) {
          if (event.sensorName == null ||
              !event.sensorName!.toLowerCase().contains(
                sensorFilter.toLowerCase(),
              )) {
            AppLogging.automations(
              '🤖 _evaluateTrigger: detectionSensor - sensor name mismatch (filter=$sensorFilter, event=${event.sensorName})',
            );
            return SkipReason.nodeFilterMismatch;
          }
        }
        // Check detected state filter
        final stateFilter = trigger.detectedStateFilter;
        if (stateFilter != null && event.sensorDetected != stateFilter) {
          AppLogging.automations(
            '🤖 _evaluateTrigger: detectionSensor - state mismatch (filter=$stateFilter, event=${event.sensorDetected})',
          );
          return SkipReason.nodeFilterMismatch;
        }
        break;

      case TriggerType.scheduled:
        // Verify the schedule ID matches the automation ID so each
        // scheduled event only triggers its own automation.
        if (event.scheduleId != null && event.scheduleId != automation.id) {
          return SkipReason.triggerTypeMismatch;
        }
        break;

      default:
        break;
    }

    // Conditions are no longer evaluated here — they are evaluated in
    // _selectBranch() which determines THEN/ELSE/NONE branch selection.
    // This allows condition failures to route to ELSE actions instead of
    // unconditionally skipping execution.

    return null;
  }

  /// Evaluate a [ConditionNode] tree recursively, producing a structured
  /// [ConditionNodeResult] that mirrors the tree shape.
  ConditionNodeResult evaluateConditionTree(
    ConditionNode node,
    AutomationEvent event,
  ) {
    return switch (node) {
      PredicateNode(condition: final c) => _evaluatePredicateNode(c, event),
      AllGroup(children: final children) => _evaluateAllGroup(children, event),
      AnyGroup(children: final children) => _evaluateAnyGroup(children, event),
      NotGroup(child: final child) => _evaluateNotGroup(child, event),
    };
  }

  PredicateResult _evaluatePredicateNode(
    AutomationCondition condition,
    AutomationEvent event,
  ) {
    final passed = _evaluateCondition(condition, event);
    return PredicateResult(
      passed: passed,
      conditionType: condition.type,
      detail: '${condition.type.name}: ${passed ? "passed" : "failed"}',
    );
  }

  AllGroupResult _evaluateAllGroup(
    List<ConditionNode> children,
    AutomationEvent event,
  ) {
    final childResults = <ConditionNodeResult>[];
    var allPassed = true;
    for (final child in children) {
      final result = evaluateConditionTree(child, event);
      childResults.add(result);
      if (!result.passed) allPassed = false;
    }
    return AllGroupResult(passed: allPassed, childResults: childResults);
  }

  AnyGroupResult _evaluateAnyGroup(
    List<ConditionNode> children,
    AutomationEvent event,
  ) {
    final childResults = <ConditionNodeResult>[];
    var anyPassed = false;
    for (final child in children) {
      final result = evaluateConditionTree(child, event);
      childResults.add(result);
      if (result.passed) anyPassed = true;
    }
    return AnyGroupResult(passed: anyPassed, childResults: childResults);
  }

  NotGroupResult _evaluateNotGroup(ConditionNode child, AutomationEvent event) {
    final childResult = evaluateConditionTree(child, event);
    return NotGroupResult(
      passed: !childResult.passed,
      childResult: childResult,
    );
  }

  /// Evaluate a condition
  ///
  /// For time-based conditions (timeRange, dayOfWeek), uses event.evaluationTime
  /// which is scheduledFor for scheduled triggers, ensuring correct evaluation
  /// even when processing catch-up events.
  bool _evaluateCondition(
    AutomationCondition condition,
    AutomationEvent event,
  ) {
    // Use evaluationTime for time-based conditions (supports scheduled triggers)
    final evalTime = event.evaluationTime;

    switch (condition.type) {
      case ConditionType.timeRange:
        final timeOfDay = TimeOfDay(
          hour: evalTime.hour,
          minute: evalTime.minute,
        );
        final start = _parseTimeOfDay(condition.timeStart);
        final end = _parseTimeOfDay(condition.timeEnd);
        if (start == null || end == null) return true;
        return _isTimeInRange(timeOfDay, start, end);

      case ConditionType.dayOfWeek:
        final days = condition.daysOfWeek;
        if (days == null || days.isEmpty) return true;
        // Use evaluationTime's day of week (0=Sunday format)
        return days.contains(evalTime.weekday % 7);

      case ConditionType.batteryAbove:
        if (event.batteryLevel == null) return true;
        return event.batteryLevel! > condition.batteryThreshold;

      case ConditionType.batteryBelow:
        if (event.batteryLevel == null) return true;
        return event.batteryLevel! < condition.batteryThreshold;

      case ConditionType.nodeOnline:
        if (condition.nodeNum == null) return true;
        // Geofence and node state use latest known state, not historic replay
        return _nodePresence[condition.nodeNum]?.isActive == true;

      case ConditionType.nodeOffline:
        if (condition.nodeNum == null) return true;
        // Geofence and node state use latest known state, not historic replay
        return _nodePresence[condition.nodeNum]?.isInactive != false;

      case ConditionType.withinGeofence:
      case ConditionType.outsideGeofence:
        // Geofence conditions use latest location snapshot, not historic replay
        return true;
    }
  }

  /// Build a lightweight event data map for debug recording.
  Map<String, dynamic> _buildEventData(AutomationEvent event) => {
    'type': event.type.name,
    if (event.nodeNum != null) 'nodeNum': event.nodeNum,
    if (event.nodeName != null) 'nodeName': event.nodeName,
    if (event.batteryLevel != null) 'batteryLevel': event.batteryLevel,
    if (event.channelIndex != null) 'channelIndex': event.channelIndex,
    if (event.messageText != null) 'messageText': event.messageText,
    if (event.scheduleId != null) 'scheduleId': event.scheduleId,
    if (event.slotKey != null) 'slotKey': event.slotKey,
    if (event.sensorName != null) 'sensorName': event.sensorName,
    'timestamp': event.timestamp.toIso8601String(),
  };

  /// Build a concise condition summary from a tree result for log persistence.
  String _buildConditionSummary(ConditionNodeResult result) {
    return switch (result) {
      PredicateResult(:final passed, :final conditionType) =>
        '${conditionType.displayName}: ${passed ? "passed" : "failed"}',
      AllGroupResult(:final passed, :final childResults) =>
        passed
            ? 'All ${childResults.length} conditions passed'
            : '${childResults.where((c) => !c.passed).length} of ${childResults.length} conditions failed',
      AnyGroupResult(:final passed, :final childResults) =>
        passed
            ? '${childResults.where((c) => c.passed).length} of ${childResults.length} conditions matched'
            : 'No conditions matched',
      NotGroupResult(:final passed) =>
        passed ? 'NOT condition passed' : 'NOT condition failed',
    };
  }

  /// Execute an automation's actions for the selected branch.
  ///
  /// When [branchActions] is provided, executes those actions instead of
  /// the automation's default [actions] list. When [branchResult] is provided,
  /// records branch selection in the debug trace.
  Future<void> _executeAutomation(
    Automation automation,
    AutomationEvent event, {
    List<AutomationAction>? branchActions,
    BranchSelectionResult? branchResult,
  }) async {
    AppLogging.automations('AutomationEngine: Executing "${automation.name}"');

    // Update throttle using domain-aware dedupe key
    final throttleKey = buildDedupeKey(automation, event);
    _lastTriggerTimes[throttleKey] = DateTime.now();

    // Use branch-specific actions if provided, else fall back to legacy actions.
    final actionsToRun = branchActions ?? automation.actions;

    final actionsExecuted = <String>[];
    final actionResults = <ActionResult>[];
    String? errorMessage;

    try {
      for (final action in actionsToRun) {
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
        triggerEventType: event.type.name,
        triggerNodeName: event.nodeName,
        triggerBatteryLevel: event.batteryLevel,
        triggerMessageText: event.messageText,
        actionsExecuted: actionsExecuted,
        actionResults: actionResults,
        errorMessage: errorMessage,
        branchSelection: branchResult?.selection.jsonValue,
        manualBypass: branchResult?.manualBypass ?? false,
        conditionSummary: branchResult?.conditionTreeResult != null
            ? _buildConditionSummary(branchResult!.conditionTreeResult!)
            : null,
      ),
    );

    // Record debug evaluation for execution
    _debugService?.recordEvaluation(
      AutomationEvaluation(
        automationId: automation.id,
        automationName: automation.name,
        enabled: automation.enabled,
        triggerType: automation.trigger.type,
        eventType: event.type,
        timestamp: DateTime.now(),
        triggered: true,
        eventData: _buildEventData(event),
        triggerConfig: automation.trigger.config,
        conditionResults: automation.conditions?.map((c) {
          final passed = _evaluateCondition(c, event);
          return ConditionEvaluation(
            type: c.type,
            passed: passed,
            details: '${c.type.name}: ${passed ? "passed" : "failed"}',
          );
        }).toList(),
        conditionTreeResult: branchResult?.conditionTreeResult,
        manualBypass: branchResult?.manualBypass ?? false,
        branchSelection: branchResult?.selection,
        branchReason: branchResult?.reason,
        branchActionsExecuted: actionsExecuted,
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
    final l10n = safeL10n();

    try {
      switch (action.type) {
        case ActionType.sendMessage:
          if (onSendMessage == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorSendMsgNotConfigured,
            );
          }
          if (action.targetNodeNum == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorNoTargetNode,
            );
          }
          final message = _interpolateVariables(
            action.messageText ?? '',
            event,
            trigger: automation.trigger,
          );
          final sent = await onSendMessage!(
            action.targetNodeNum!,
            message,
            _routingProtocol(automation, event),
          );
          return ActionResult(
            actionName: actionName,
            success: sent,
            errorMessage: sent ? null : l10n.automationErrorSendMsgFailed,
          );

        case ActionType.sendToChannel:
          if (onSendToChannel == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorSendChannelNotConfigured,
            );
          }
          if (action.targetChannelIndex == null) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorNoTargetChannel,
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
            _routingProtocol(automation, event),
          );
          return ActionResult(
            actionName: actionName,
            success: sent,
            errorMessage: sent ? null : l10n.automationErrorSendChannelFailed,
          );

        case ActionType.playSound:
          final rtttl = action.soundRtttl;
          if (rtttl == null || rtttl.isEmpty) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorNoSoundConfigured,
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
              errorMessage: l10n.automationErrorPlaySoundFailed(e.toString()),
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
              errorMessage: l10n.automationErrorNotificationsNotInit,
            );
          }

          // Build notification via the policy-driven renderer.
          // This resolves variables, enforces per-field grapheme limits,
          // and falls through template tiers if content exceeds the
          // platform display budget.
          final notifSpec = NotificationSpec.fromUserTemplate(
            titleTemplate: action.notificationTitle ?? automation.name,
            bodyTemplate: action.notificationBody ?? '',
            fallbackTitle: automation.name,
            fallbackBody:
                'Automation triggered.', // lint-allow: hardcoded-string
          );
          final renderResult = NotificationRenderer.render(
            spec: notifSpec,
            variables: _buildVariableMap(event, trigger: automation.trigger),
            policy: NotificationPolicy.strictest,
          );
          final title = renderResult.parts.title;
          final body = renderResult.parts.body;

          if (renderResult.reductionApplied) {
            AppLogging.automations(
              'Notification reduced: tier=${renderResult.tierUsed}, '
              'fallback=${renderResult.usedFallback}',
            );
          }

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
            id: automation.id.hashCode,
            title: title,
            body: body,
            notificationDetails: NotificationDetails(
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
          final hasCustomUrl =
              action.webhookUrl != null && action.webhookUrl!.isNotEmpty;
          final hasEventName =
              action.webhookEventName != null &&
              action.webhookEventName!.isNotEmpty;

          // Require at least an event name (used as the event key in both
          // IFTTT and custom URL payloads).
          if (!hasEventName) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorNoWebhookEvent,
            );
          }

          // When no custom URL is provided, fall back to the global IFTTT
          // config which requires an active webhook key.
          if (!hasCustomUrl && !_iftttService.isActive) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorIftttNotConfigured,
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
            contextParts.add(
              'Battery: ${event.batteryLevel}%',
            ); // lint-allow: hardcoded-string
          }
          if (event.snr != null) {
            contextParts.add(
              'SNR: ${event.snr}',
            ); // lint-allow: hardcoded-string
          }
          contextParts.add(
            'Time: ${event.timestamp.toIso8601String()}',
          ); // lint-allow: hardcoded-string
          value3 = contextParts.join(', ');

          // Use custom URL when provided, otherwise fall back to IFTTT
          final bool webhookSuccess;
          if (hasCustomUrl) {
            webhookSuccess = await _iftttService.triggerCustomUrl(
              url: action.webhookUrl!,
              eventName: action.webhookEventName!,
              value1: value1,
              value2: value2,
              value3: value3,
            );
          } else {
            webhookSuccess = await _iftttService.triggerCustomEvent(
              eventName: action.webhookEventName!,
              value1: value1,
              value2: value2,
              value3: value3,
            );
          }
          return ActionResult(
            actionName: actionName,
            success: webhookSuccess,
            errorMessage: webhookSuccess
                ? null
                : l10n.automationErrorWebhookFailed,
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
              errorMessage: l10n.automationErrorShortcutsIosOnly,
            );
          }

          final shortcutName = action.shortcutName;
          if (shortcutName == null || shortcutName.isEmpty) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorNoShortcutName,
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
            'shortcuts://x-callback-url/run-shortcut?name=$encodedName&input=text&text=$encodedInput', // lint-allow: hardcoded-string
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
                errorMessage: l10n.automationErrorShortcutLaunchFailed(
                  shortcutName,
                ),
              );
            }
            return ActionResult(actionName: actionName, success: true);
          } catch (e) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorShortcutRunFailed(e.toString()),
            );
          }

        case ActionType.glyphPattern:
          // Nothing Phone glyph patterns
          if (_glyphService == null || !_glyphService.isSupported) {
            return ActionResult(
              actionName: actionName,
              success: false,
              errorMessage: l10n.automationErrorGlyphNotAvailable,
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
              errorMessage: l10n.automationErrorGlyphPatternFailed(
                e.toString(),
              ),
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
    (double, double) currentPos, {
    TriggerProtocol protocol = TriggerProtocol.meshtastic,
  }) async {
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
            batteryLevel: _nodeBatteryLevels[node.nodeNum],
            latitude: currentPos.$1,
            longitude: currentPos.$2,
            protocol: protocol,
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
            batteryLevel: _nodeBatteryLevels[node.nodeNum],
            latitude: currentPos.$1,
            longitude: currentPos.$2,
            protocol: protocol,
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
          final silentPos = _nodePositions[nodeNum];
          await _processEvent(
            AutomationEvent(
              type: TriggerType.nodeSilent,
              nodeNum: nodeNum,
              nodeName: _nodeNames[nodeNum],
              batteryLevel: _nodeBatteryLevels[nodeNum],
              latitude: silentPos?.$1,
              longitude: silentPos?.$2,
            ),
          );
        }
      }
    }
  }

  /// Format a human-readable timestamp for notification display
  static DateFormat get _notificationTimeFormat =>
      AppTimeFormat.is24HourFromPreferences()
      ? DateFormat('MMM d, HH:mm')
      : DateFormat('MMM d, h:mm a');

  /// Build the runtime variable map from an [AutomationEvent].
  ///
  /// This is the single source of truth for variable resolution, shared
  /// by both the legacy [_interpolateVariables] (for messages) and the
  /// new [NotificationRenderer] pipeline.
  Map<String, String> _buildVariableMap(
    AutomationEvent event, {
    AutomationTrigger? trigger,
  }) {
    final locationStr = event.latitude != null && event.longitude != null
        ? '${event.latitude!.toStringAsFixed(6)}, '
              '${event.longitude!.toStringAsFixed(6)}'
        : 'Unknown';

    final vars = <String, String>{
      'node.name': event.nodeName ?? '',
      'node.num': event.nodeNum?.toRadixString(16) ?? '',
      'battery': '${event.batteryLevel ?? '?'}%',
      'location': locationStr,
      'message': event.messageText?.isNotEmpty == true
          ? event.messageText!
          : '',
      'time': _notificationTimeFormat.format(DateTime.now()),
      'sensor.name': event.sensorName ?? '',
      'sensor.state': event.sensorDetected == true ? 'detected' : 'clear',
    };

    if (trigger != null) {
      vars['threshold'] = '${trigger.batteryThreshold}%';
      vars['keyword'] = trigger.keyword ?? '';
      vars['zone.radius'] = '${trigger.geofenceRadius.round()}m';
      vars['silent.duration'] = '${trigger.silentMinutes} min';
      vars['signal.threshold'] = '${trigger.signalThreshold} dB';
      vars['channel.name'] = 'Channel ${trigger.channelIndex ?? 0}';
    }

    return vars;
  }

  String _interpolateVariables(
    String text,
    AutomationEvent event, {
    AutomationTrigger? trigger,
  }) {
    // Format location with reasonable precision (6 decimal places ≈ 0.1m)
    final locationStr = event.latitude != null && event.longitude != null
        ? '${event.latitude!.toStringAsFixed(6)}, '
              '${event.longitude!.toStringAsFixed(6)}'
        : 'Unknown';

    var result = text
        .replaceAll('{{node.name}}', event.nodeName ?? 'Unknown')
        .replaceAll('{{node.num}}', event.nodeNum?.toRadixString(16) ?? '')
        .replaceAll('{{battery}}', '${event.batteryLevel ?? '?'}%')
        .replaceAll('{{location}}', locationStr)
        .replaceAll(
          '{{message}}',
          event.messageText?.isNotEmpty == true ? event.messageText! : '',
        )
        .replaceAll('{{time}}', _notificationTimeFormat.format(DateTime.now()))
        .replaceAll('{{sensor.name}}', event.sensorName ?? 'Unknown')
        .replaceAll(
          '{{sensor.state}}',
          event.sensorDetected == true ? 'detected' : 'clear',
        );

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
            'Channel ${trigger.channelIndex ?? 0}', // lint-allow: hardcoded-string
          );
    }

    return result;
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
