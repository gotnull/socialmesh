// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/trigger_protocol.dart';
import 'condition_node.dart';

export '../../../models/trigger_protocol.dart' show TriggerProtocol;

/// Core automation model
class Automation {
  final String id;
  final String name;
  final String? description;
  final bool enabled;
  final AutomationTrigger trigger;
  final List<AutomationAction> actions;
  final List<AutomationCondition>? conditions;
  final ConditionNode? conditionTree;

  /// Branch-aware action lists (Phase 3).
  /// When set, these override the legacy [actions] list for runtime execution.
  final List<AutomationAction>? thenActions;
  final List<AutomationAction>? elseActions;

  final DateTime createdAt;
  final DateTime? lastTriggered;
  final int triggerCount;

  Automation({
    String? id,
    required this.name,
    this.description,
    this.enabled = true,
    required this.trigger,
    required this.actions,
    this.conditions,
    this.conditionTree,
    this.thenActions,
    this.elseActions,
    DateTime? createdAt,
    this.lastTriggered,
    this.triggerCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Returns the effective condition tree for runtime evaluation.
  ///
  /// If [conditionTree] is explicitly set, returns it. Otherwise lifts
  /// the legacy [conditions] list into an ALL group. Returns `null` when
  /// there are no conditions at all.
  ConditionNode? get effectiveConditionTree =>
      conditionTree ?? ConditionNode.fromLegacyConditions(conditions);

  /// Returns the effective THEN action list for runtime execution.
  ///
  /// If [thenActions] is explicitly set, returns it. Otherwise falls back
  /// to the legacy [actions] list. This ensures backward compatibility:
  /// existing automations with only [actions] behave as THEN-only automations.
  List<AutomationAction> get effectiveThenActions => thenActions ?? actions;

  /// Returns the effective ELSE action list for runtime execution.
  ///
  /// Returns [elseActions] when set and non-empty, otherwise `null`.
  /// A `null` result means no ELSE branch exists — the automation is
  /// THEN-only (or legacy linear).
  List<AutomationAction>? get effectiveElseActions =>
      (elseActions != null && elseActions!.isNotEmpty) ? elseActions : null;

  /// Whether this automation has branch structure (THEN/ELSE).
  bool get hasBranchStructure =>
      thenActions != null || effectiveElseActions != null;

  Automation copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    AutomationTrigger? trigger,
    List<AutomationAction>? actions,
    List<AutomationCondition>? conditions,
    ConditionNode? conditionTree,
    List<AutomationAction>? thenActions,
    List<AutomationAction>? elseActions,
    DateTime? createdAt,
    DateTime? lastTriggered,
    int? triggerCount,
  }) {
    return Automation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      trigger: trigger ?? this.trigger,
      actions: actions ?? this.actions,
      conditions: conditions ?? this.conditions,
      conditionTree: conditionTree ?? this.conditionTree,
      thenActions: thenActions ?? this.thenActions,
      elseActions: elseActions ?? this.elseActions,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      triggerCount: triggerCount ?? this.triggerCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'trigger': trigger.toJson(),
    'actions': actions.map((a) => a.toJson()).toList(),
    // Legacy flat conditions — always written for backward compatibility.
    'conditions': conditions?.map((c) => c.toJson()).toList(),
    // Typed condition tree — written when explicitly set.
    if (conditionTree != null) 'conditionTree': conditionTree!.toJson(),
    // Branch-aware action lists — written when explicitly set.
    if (thenActions != null)
      'thenActions': thenActions!.map((a) => a.toJson()).toList(),
    if (elseActions != null)
      'elseActions': elseActions!.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastTriggered': lastTriggered?.toIso8601String(),
    'triggerCount': triggerCount,
  };

  factory Automation.fromJson(Map<String, dynamic> json) {
    final treeJson = json['conditionTree'] as Map<String, dynamic>?;
    return Automation(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      trigger: AutomationTrigger.fromJson(
        json['trigger'] as Map<String, dynamic>,
      ),
      actions: (json['actions'] as List)
          .map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      conditions: (json['conditions'] as List?)
          ?.map((c) => AutomationCondition.fromJson(c as Map<String, dynamic>))
          .toList(),
      conditionTree: treeJson != null ? ConditionNode.fromJson(treeJson) : null,
      thenActions: (json['thenActions'] as List?)
          ?.map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      elseActions: (json['elseActions'] as List?)
          ?.map((a) => AutomationAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastTriggered: json['lastTriggered'] != null
          ? DateTime.parse(json['lastTriggered'] as String)
          : null,
      triggerCount: json['triggerCount'] as int? ?? 0,
    );
  }
}

/// Trigger types
enum TriggerType {
  nodeOnline,
  nodeOffline,
  batteryLow,
  batteryFull,
  messageReceived,
  messageContains,
  positionChanged,
  geofenceEnter,
  geofenceExit,
  nodeSilent,
  scheduled,
  signalWeak,
  channelActivity,
  detectionSensor, // Detection sensor triggered (motion, door, etc.)
  manual, // Triggered manually via Siri Shortcuts or UI
}

extension TriggerTypeExtension on TriggerType {
  /// Non-localized display name for internal use (e.g. default text matching).
  String get displayName {
    switch (this) {
      case TriggerType.nodeOnline:
        return 'Node becomes active'; // lint-allow: hardcoded-string
      case TriggerType.nodeOffline:
        return 'Node becomes inactive'; // lint-allow: hardcoded-string
      case TriggerType.batteryLow:
        return 'Battery drops below threshold'; // lint-allow: hardcoded-string
      case TriggerType.batteryFull:
        return 'Battery fully charged'; // lint-allow: hardcoded-string
      case TriggerType.messageReceived:
        return 'Message received'; // lint-allow: hardcoded-string
      case TriggerType.messageContains:
        return 'Message contains keyword'; // lint-allow: hardcoded-string
      case TriggerType.positionChanged:
        return 'Position updated'; // lint-allow: hardcoded-string
      case TriggerType.geofenceEnter:
        return 'Enters geofence area'; // lint-allow: hardcoded-string
      case TriggerType.geofenceExit:
        return 'Exits geofence area'; // lint-allow: hardcoded-string
      case TriggerType.nodeSilent:
        return 'Node silent for duration'; // lint-allow: hardcoded-string
      case TriggerType.scheduled:
        return 'Scheduled time'; // lint-allow: hardcoded-string
      case TriggerType.signalWeak:
        return 'Signal strength drops'; // lint-allow: hardcoded-string
      case TriggerType.channelActivity:
        return 'Activity on channel'; // lint-allow: hardcoded-string
      case TriggerType.detectionSensor:
        return 'Detection sensor triggered'; // lint-allow: hardcoded-string
      case TriggerType.manual:
        return 'Manual trigger'; // lint-allow: hardcoded-string
    }
  }

  /// Localized display name for UI.
  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case TriggerType.nodeOnline:
        return l10n.automationTriggerNodeOnline;
      case TriggerType.nodeOffline:
        return l10n.automationTriggerNodeOffline;
      case TriggerType.batteryLow:
        return l10n.automationTriggerBatteryLow;
      case TriggerType.batteryFull:
        return l10n.automationTriggerBatteryFull;
      case TriggerType.messageReceived:
        return l10n.automationTriggerMessageReceived;
      case TriggerType.messageContains:
        return l10n.automationTriggerMessageContains;
      case TriggerType.positionChanged:
        return l10n.automationTriggerPositionChanged;
      case TriggerType.geofenceEnter:
        return l10n.automationTriggerGeofenceEnter;
      case TriggerType.geofenceExit:
        return l10n.automationTriggerGeofenceExit;
      case TriggerType.nodeSilent:
        return l10n.automationTriggerNodeSilent;
      case TriggerType.scheduled:
        return l10n.automationTriggerScheduled;
      case TriggerType.signalWeak:
        return l10n.automationTriggerSignalWeak;
      case TriggerType.channelActivity:
        return l10n.automationTriggerChannelActivity;
      case TriggerType.detectionSensor:
        return l10n.automationTriggerDetectionSensor;
      case TriggerType.manual:
        return l10n.automationTriggerManual;
    }
  }

  IconData get icon {
    switch (this) {
      case TriggerType.nodeOnline:
        return Icons.wifi;
      case TriggerType.nodeOffline:
        return Icons.wifi_off;
      case TriggerType.batteryLow:
        return Icons.battery_alert;
      case TriggerType.batteryFull:
        return Icons.battery_full;
      case TriggerType.messageReceived:
        return Icons.message;
      case TriggerType.messageContains:
        return Icons.text_fields;
      case TriggerType.positionChanged:
        return Icons.location_on;
      case TriggerType.geofenceEnter:
        return Icons.location_searching;
      case TriggerType.geofenceExit:
        return Icons.location_disabled;
      case TriggerType.nodeSilent:
        return Icons.timer_off;
      case TriggerType.scheduled:
        return Icons.schedule;
      case TriggerType.signalWeak:
        return Icons.signal_cellular_alt;
      case TriggerType.channelActivity:
        return Icons.forum;
      case TriggerType.detectionSensor:
        return Icons.sensors;
      case TriggerType.manual:
        return Icons.play_arrow;
    }
  }

  String get category {
    switch (this) {
      case TriggerType.nodeOnline:
      case TriggerType.nodeOffline:
      case TriggerType.nodeSilent:
        return 'Node Status'; // lint-allow: hardcoded-string
      case TriggerType.batteryLow:
      case TriggerType.batteryFull:
        return 'Battery';
      case TriggerType.messageReceived:
      case TriggerType.messageContains:
      case TriggerType.channelActivity:
        return 'Messages';
      case TriggerType.detectionSensor:
        return 'Sensors';
      case TriggerType.positionChanged:
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        return 'Location';
      case TriggerType.scheduled:
        return 'Time';
      case TriggerType.signalWeak:
        return 'Signal';
      case TriggerType.manual:
        return 'Manual';
    }
  }

  /// Localized category name for UI.
  String localizedCategory(AppLocalizations l10n) {
    switch (this) {
      case TriggerType.nodeOnline:
      case TriggerType.nodeOffline:
      case TriggerType.nodeSilent:
        return l10n.automationCategoryNodeStatus;
      case TriggerType.batteryLow:
      case TriggerType.batteryFull:
        return l10n.automationCategoryBattery;
      case TriggerType.messageReceived:
      case TriggerType.messageContains:
      case TriggerType.channelActivity:
        return l10n.automationCategoryMessages;
      case TriggerType.detectionSensor:
        return l10n.automationCategorySensors;
      case TriggerType.positionChanged:
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        return l10n.automationCategoryLocation;
      case TriggerType.scheduled:
        return l10n.automationCategoryTime;
      case TriggerType.signalWeak:
        return l10n.automationCategorySignal;
      case TriggerType.manual:
        return l10n.automationCategoryManual;
    }
  }

  /// Default description for automation
  String get defaultDescription {
    switch (this) {
      case TriggerType.nodeOnline:
        return 'Triggered when a node is heard recently'; // lint-allow: hardcoded-string
      case TriggerType.nodeOffline:
        return 'Triggered when a node is not heard for a while'; // lint-allow: hardcoded-string
      case TriggerType.batteryLow:
        return 'Triggered when battery drops below threshold'; // lint-allow: hardcoded-string
      case TriggerType.batteryFull:
        return 'Triggered when battery is fully charged'; // lint-allow: hardcoded-string
      case TriggerType.messageReceived:
        return 'Triggered when any message is received'; // lint-allow: hardcoded-string
      case TriggerType.messageContains:
        return 'Triggered when message contains keyword'; // lint-allow: hardcoded-string
      case TriggerType.positionChanged:
        return 'Triggered when node position changes'; // lint-allow: hardcoded-string
      case TriggerType.geofenceEnter:
        return 'Triggered when node enters geofence area'; // lint-allow: hardcoded-string
      case TriggerType.geofenceExit:
        return 'Triggered when node exits geofence area'; // lint-allow: hardcoded-string
      case TriggerType.nodeSilent:
        return 'Triggered when node is silent for duration'; // lint-allow: hardcoded-string
      case TriggerType.scheduled:
        return 'Triggered at scheduled time'; // lint-allow: hardcoded-string
      case TriggerType.signalWeak:
        return 'Triggered when signal strength drops'; // lint-allow: hardcoded-string
      case TriggerType.channelActivity:
        return 'Triggered when activity on channel'; // lint-allow: hardcoded-string
      case TriggerType.detectionSensor:
        return 'Triggered when detection sensor activates'; // lint-allow: hardcoded-string
      case TriggerType.manual:
        return 'Triggered manually via Shortcuts or UI'; // lint-allow: hardcoded-string
    }
  }

  /// Localized default description for UI.
  String localizedDescription(AppLocalizations l10n) {
    switch (this) {
      case TriggerType.nodeOnline:
        return l10n.automationTriggerDescNodeOnline;
      case TriggerType.nodeOffline:
        return l10n.automationTriggerDescNodeOffline;
      case TriggerType.batteryLow:
        return l10n.automationTriggerDescBatteryLow;
      case TriggerType.batteryFull:
        return l10n.automationTriggerDescBatteryFull;
      case TriggerType.messageReceived:
        return l10n.automationTriggerDescMessageReceived;
      case TriggerType.messageContains:
        return l10n.automationTriggerDescMessageContains;
      case TriggerType.positionChanged:
        return l10n.automationTriggerDescPositionChanged;
      case TriggerType.geofenceEnter:
        return l10n.automationTriggerDescGeofenceEnter;
      case TriggerType.geofenceExit:
        return l10n.automationTriggerDescGeofenceExit;
      case TriggerType.nodeSilent:
        return l10n.automationTriggerDescNodeSilent;
      case TriggerType.scheduled:
        return l10n.automationTriggerDescScheduled;
      case TriggerType.signalWeak:
        return l10n.automationTriggerDescSignalWeak;
      case TriggerType.channelActivity:
        return l10n.automationTriggerDescChannelActivity;
      case TriggerType.detectionSensor:
        return l10n.automationTriggerDescDetectionSensor;
      case TriggerType.manual:
        return l10n.automationTriggerDescManual;
    }
  }

  /// Default message text for sendMessage/sendToChannel actions
  String get defaultMessageText {
    switch (this) {
      case TriggerType.nodeOnline:
        return '{{node.name}} is now active';
      case TriggerType.nodeOffline:
        return '{{node.name}} became inactive';
      case TriggerType.batteryLow:
        return '{{node.name}} battery low: {{battery}}';
      case TriggerType.batteryFull:
        return '{{node.name}} battery fully charged';
      case TriggerType.messageReceived:
        return 'Message from {{node.name}}: {{message}}'; // lint-allow: hardcoded-string
      case TriggerType.messageContains:
        return 'Keyword detected from {{node.name}}: {{message}}'; // lint-allow: hardcoded-string
      case TriggerType.positionChanged:
        return '{{node.name}} moved to {{location}}';
      case TriggerType.geofenceEnter:
        return '{{node.name}} entered the zone';
      case TriggerType.geofenceExit:
        return '{{node.name}} left the zone';
      case TriggerType.nodeSilent:
        return "{{node.name}} hasn't been heard from in {{silent.duration}}.";
      case TriggerType.scheduled:
        return 'Scheduled alert at {{time}}'; // lint-allow: hardcoded-string
      case TriggerType.signalWeak:
        return '{{node.name}} signal weak';
      case TriggerType.channelActivity:
        return 'Activity on {{channel.name}}: {{message}}'; // lint-allow: hardcoded-string
      case TriggerType.detectionSensor:
        return '{{sensor.name}}: {{sensor.state}}';
      case TriggerType.manual:
        return 'Automation triggered manually'; // lint-allow: hardcoded-string
    }
  }
}

// Which protocol's event stream an automation listens to.
//
// `any` is the legacy default: existing automations created before
// MeshCore support fire on any inbound event regardless of source.
// `meshtastic` / `meshcore` restrict firing to events tagged with that
// protocol. Tagging happens at the event-source seam in
// `app_providers.dart` (Meshtastic) and the MeshCore message provider
// (MeshCore); see `AutomationEvent.protocol`.
enum TriggerProtocolFilter { any, meshtastic, meshcore }

/// Automation trigger
class AutomationTrigger {
  final TriggerType type;
  final Map<String, dynamic> config;

  const AutomationTrigger({required this.type, this.config = const {}});

  // Protocol scope. Defaults to `any` for back-compat with automations
  // persisted before MeshCore support landed. Stored under
  // `config['protocolFilter']` as the enum's `name` string so existing
  // `AutomationSqliteStore` schema needs no migration.
  TriggerProtocolFilter get protocolFilter {
    final raw = config['protocolFilter'];
    if (raw is String) {
      for (final v in TriggerProtocolFilter.values) {
        if (v.name == raw) return v;
      }
    }
    return TriggerProtocolFilter.any;
  }

  // True when this trigger should fire for an event carrying `incoming`.
  bool matchesProtocol(TriggerProtocol incoming) {
    switch (protocolFilter) {
      case TriggerProtocolFilter.any:
        return true;
      case TriggerProtocolFilter.meshtastic:
        return incoming == TriggerProtocol.meshtastic;
      case TriggerProtocolFilter.meshcore:
        return incoming == TriggerProtocol.meshcore;
    }
  }

  /// Node filter - which node(s) this trigger applies to
  /// null = all nodes, otherwise specific node number
  int? get nodeNum => config['nodeNum'] as int?;

  /// Battery threshold for battery triggers
  int get batteryThreshold => config['batteryThreshold'] as int? ?? 20;

  /// Keyword for messageContains trigger
  String? get keyword => config['keyword'] as String?;

  /// Channel for channel-specific triggers
  int? get channelIndex => config['channelIndex'] as int?;

  /// Geofence center latitude
  double? get geofenceLat {
    final value = config['geofenceLat'];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  /// Geofence center longitude
  double? get geofenceLon {
    final value = config['geofenceLon'];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  /// Geofence radius in meters
  double get geofenceRadius {
    final value = config['geofenceRadius'];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return 500.0;
  }

  /// Silent duration in minutes for nodeSilent trigger
  int get silentMinutes => config['silentMinutes'] as int? ?? 30;

  /// Schedule cron expression or simple time
  String? get schedule => config['schedule'] as String?;

  /// Signal threshold (SNR) for signalWeak trigger
  int get signalThreshold => config['signalThreshold'] as int? ?? -10;

  /// Sensor name filter for detectionSensor trigger (null = any sensor)
  String? get sensorNameFilter => config['sensorNameFilter'] as String?;

  /// Detected state filter for detectionSensor trigger (null = any, true = detected, false = clear)
  bool? get detectedStateFilter => config['detectedStateFilter'] as bool?;

  /// Validate trigger configuration and return error message if invalid
  String? validate() {
    switch (type) {
      case TriggerType.messageContains:
        final kw = keyword;
        if (kw == null || kw.trim().isEmpty) {
          return 'Please enter a keyword to match'; // lint-allow: hardcoded-string
        }
        break;
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        if (geofenceLat == null || geofenceLon == null) {
          return 'Please select a geofence location'; // lint-allow: hardcoded-string
        }
        break;
      case TriggerType.scheduled:
        if (schedule == null || schedule!.trim().isEmpty) {
          return 'Please set a schedule time'; // lint-allow: hardcoded-string
        }
        break;
      default:
        // No validation required for other trigger types
        break;
    }
    return null;
  }

  /// Localized validation — returns localized error message if invalid.
  String? localizedValidate(AppLocalizations l10n) {
    switch (type) {
      case TriggerType.messageContains:
        final kw = keyword;
        if (kw == null || kw.trim().isEmpty) {
          return l10n.automationValidateKeyword;
        }
        break;
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        if (geofenceLat == null || geofenceLon == null) {
          return l10n.automationValidateGeofence;
        }
        break;
      case TriggerType.scheduled:
        if (schedule == null || schedule!.trim().isEmpty) {
          return l10n.automationValidateSchedule;
        }
        break;
      default:
        break;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'config': config};

  factory AutomationTrigger.fromJson(Map<String, dynamic> json) {
    return AutomationTrigger(
      type: TriggerType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TriggerType.messageReceived,
      ),
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }

  AutomationTrigger copyWith({
    TriggerType? type,
    Map<String, dynamic>? config,
  }) {
    return AutomationTrigger(
      type: type ?? this.type,
      config: config ?? this.config,
    );
  }
}

/// Action types
enum ActionType {
  sendMessage,
  playSound,
  vibrate,
  pushNotification,
  triggerWebhook,
  logEvent,
  updateWidget,
  sendToChannel,
  triggerShortcut,
  glyphPattern,
}

extension ActionTypeExtension on ActionType {
  String get displayName {
    switch (this) {
      case ActionType.sendMessage:
        return 'Send message to node'; // lint-allow: hardcoded-string
      case ActionType.playSound:
        return 'Play alert sound'; // lint-allow: hardcoded-string
      case ActionType.vibrate:
        return 'Vibrate device'; // lint-allow: hardcoded-string
      case ActionType.pushNotification:
        return 'Push notification'; // lint-allow: hardcoded-string
      case ActionType.triggerWebhook:
        return 'Trigger webhook'; // lint-allow: hardcoded-string
      case ActionType.logEvent:
        return 'Log to history'; // lint-allow: hardcoded-string
      case ActionType.updateWidget:
        return 'Update home widget'; // lint-allow: hardcoded-string
      case ActionType.sendToChannel:
        return 'Send to channel'; // lint-allow: hardcoded-string
      case ActionType.triggerShortcut:
        return 'Run iOS Shortcut'; // lint-allow: hardcoded-string
      case ActionType.glyphPattern:
        return 'Glyph pattern (Nothing Phone)'; // lint-allow: hardcoded-string
    }
  }

  /// Localized display name for UI.
  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case ActionType.sendMessage:
        return l10n.automationActionSendMessage;
      case ActionType.playSound:
        return l10n.automationActionPlaySound;
      case ActionType.vibrate:
        return l10n.automationActionVibrate;
      case ActionType.pushNotification:
        return l10n.automationActionPushNotification;
      case ActionType.triggerWebhook:
        return l10n.automationActionTriggerWebhook;
      case ActionType.logEvent:
        return l10n.automationActionLogEvent;
      case ActionType.updateWidget:
        return l10n.automationActionUpdateWidget;
      case ActionType.sendToChannel:
        return l10n.automationActionSendToChannel;
      case ActionType.triggerShortcut:
        return l10n.automationActionTriggerShortcut;
      case ActionType.glyphPattern:
        return l10n.automationActionGlyphPattern;
    }
  }

  IconData get icon {
    switch (this) {
      case ActionType.sendMessage:
        return Icons.send;
      case ActionType.playSound:
        return Icons.volume_up;
      case ActionType.vibrate:
        return Icons.vibration;
      case ActionType.pushNotification:
        return Icons.notifications;
      case ActionType.triggerWebhook:
        return Icons.webhook;
      case ActionType.logEvent:
        return Icons.history;
      case ActionType.updateWidget:
        return Icons.widgets;
      case ActionType.sendToChannel:
        return Icons.forum;
      case ActionType.triggerShortcut:
        return Icons.play_circle;
      case ActionType.glyphPattern:
        return Icons.lightbulb;
    }
  }
}

/// Automation action
class AutomationAction {
  final ActionType type;
  final Map<String, dynamic> config;

  const AutomationAction({required this.type, this.config = const {}});

  /// Message text for sendMessage/sendToChannel actions
  /// Supports variables: {{node.name}}, {{battery}}, {{location}}, {{message}}
  String? get messageText => config['messageText'] as String?;

  /// Target node for sendMessage
  int? get targetNodeNum => config['targetNodeNum'] as int?;

  /// Target channel for sendToChannel
  int? get targetChannelIndex => config['targetChannelIndex'] as int?;

  /// Sound type for playSound (legacy)
  String? get soundType => config['soundType'] as String?;

  /// RTTTL string for playSound
  String? get soundRtttl => config['soundRtttl'] as String?;

  /// Display name for the selected sound
  String? get soundName => config['soundName'] as String?;

  /// Webhook URL for triggerWebhook
  String? get webhookUrl => config['webhookUrl'] as String?;

  /// Webhook event name (for IFTTT)
  String? get webhookEventName => config['webhookEventName'] as String?;

  /// Notification title
  String? get notificationTitle => config['notificationTitle'] as String?;

  /// Notification body
  String? get notificationBody => config['notificationBody'] as String?;

  /// Notification sound RTTTL (optional custom sound)
  String? get notificationSoundRtttl =>
      config['notificationSoundRtttl'] as String?;

  /// Notification sound name (for display)
  String? get notificationSoundName =>
      config['notificationSoundName'] as String?;

  /// iOS Shortcut name
  String? get shortcutName => config['shortcutName'] as String?;

  /// Validate action configuration and return error message if invalid
  String? validate() {
    switch (type) {
      case ActionType.sendMessage:
        final msg = messageText;
        if (msg == null || msg.trim().isEmpty) {
          return 'Please enter a message to send'; // lint-allow: hardcoded-string
        }
        if (targetNodeNum == null) {
          return 'Please select a target node'; // lint-allow: hardcoded-string
        }
        break;
      case ActionType.sendToChannel:
        final msg = messageText;
        if (msg == null || msg.trim().isEmpty) {
          return 'Please enter a message to send'; // lint-allow: hardcoded-string
        }
        break;
      case ActionType.triggerWebhook:
        final eventName = webhookEventName;
        if (eventName == null || eventName.trim().isEmpty) {
          return 'Please enter a webhook event name'; // lint-allow: hardcoded-string
        }
        break;
      case ActionType.triggerShortcut:
        final name = shortcutName;
        if (name == null || name.trim().isEmpty) {
          return 'Please enter a Shortcut name'; // lint-allow: hardcoded-string
        }
        break;
      default:
        // playSound, vibrate, pushNotification, logEvent, updateWidget
        // These don't require specific configuration
        break;
    }
    return null;
  }

  /// Localized validation — returns localized error message if invalid.
  String? localizedValidate(AppLocalizations l10n) {
    switch (type) {
      case ActionType.sendMessage:
        final msg = messageText;
        if (msg == null || msg.trim().isEmpty) {
          return l10n.automationValidateMessage;
        }
        if (targetNodeNum == null) {
          return l10n.automationValidateTargetNode;
        }
        break;
      case ActionType.sendToChannel:
        final msg = messageText;
        if (msg == null || msg.trim().isEmpty) {
          return l10n.automationValidateMessage;
        }
        break;
      case ActionType.triggerWebhook:
        final eventName = webhookEventName;
        if (eventName == null || eventName.trim().isEmpty) {
          return l10n.automationValidateWebhookEvent;
        }
        break;
      case ActionType.triggerShortcut:
        final name = shortcutName;
        if (name == null || name.trim().isEmpty) {
          return l10n.automationValidateShortcutName;
        }
        break;
      default:
        break;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'config': config};

  factory AutomationAction.fromJson(Map<String, dynamic> json) {
    return AutomationAction(
      type: ActionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ActionType.pushNotification,
      ),
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }

  AutomationAction copyWith({ActionType? type, Map<String, dynamic>? config}) {
    return AutomationAction(
      type: type ?? this.type,
      config: config ?? this.config,
    );
  }
}

/// Condition types for AND logic
enum ConditionType {
  timeRange,
  dayOfWeek,
  batteryAbove,
  batteryBelow,
  nodeOnline,
  nodeOffline,
  withinGeofence,
  outsideGeofence,
}

extension ConditionTypeExtension on ConditionType {
  String get displayName {
    switch (this) {
      case ConditionType.timeRange:
        return 'During time range'; // lint-allow: hardcoded-string
      case ConditionType.dayOfWeek:
        return 'On specific days'; // lint-allow: hardcoded-string
      case ConditionType.batteryAbove:
        return 'Battery above threshold'; // lint-allow: hardcoded-string
      case ConditionType.batteryBelow:
        return 'Battery below threshold'; // lint-allow: hardcoded-string
      case ConditionType.nodeOnline:
        return 'Node is active'; // lint-allow: hardcoded-string
      case ConditionType.nodeOffline:
        return 'Node is inactive'; // lint-allow: hardcoded-string
      case ConditionType.withinGeofence:
        return 'Within geofence'; // lint-allow: hardcoded-string
      case ConditionType.outsideGeofence:
        return 'Outside geofence'; // lint-allow: hardcoded-string
    }
  }

  /// Localized display name for UI.
  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case ConditionType.timeRange:
        return l10n.automationConditionTimeRange;
      case ConditionType.dayOfWeek:
        return l10n.automationConditionDayOfWeek;
      case ConditionType.batteryAbove:
        return l10n.automationConditionBatteryAbove;
      case ConditionType.batteryBelow:
        return l10n.automationConditionBatteryBelow;
      case ConditionType.nodeOnline:
        return l10n.automationConditionNodeOnline;
      case ConditionType.nodeOffline:
        return l10n.automationConditionNodeOffline;
      case ConditionType.withinGeofence:
        return l10n.automationConditionWithinGeofence;
      case ConditionType.outsideGeofence:
        return l10n.automationConditionOutsideGeofence;
    }
  }

  IconData get icon {
    switch (this) {
      case ConditionType.timeRange:
        return Icons.access_time;
      case ConditionType.dayOfWeek:
        return Icons.calendar_today;
      case ConditionType.batteryAbove:
      case ConditionType.batteryBelow:
        return Icons.battery_std;
      case ConditionType.nodeOnline:
        return Icons.wifi;
      case ConditionType.nodeOffline:
        return Icons.wifi_off;
      case ConditionType.withinGeofence:
      case ConditionType.outsideGeofence:
        return Icons.my_location;
    }
  }
}

/// Automation condition (optional AND filters)
class AutomationCondition {
  final ConditionType type;
  final Map<String, dynamic> config;

  const AutomationCondition({required this.type, this.config = const {}});

  /// Time range start (HH:mm format)
  String? get timeStart => config['timeStart'] as String?;

  /// Time range end (HH:mm format)
  String? get timeEnd => config['timeEnd'] as String?;

  /// Days of week (0=Sunday, 6=Saturday)
  List<int>? get daysOfWeek => (config['daysOfWeek'] as List?)?.cast<int>();

  /// Battery threshold
  int get batteryThreshold => config['batteryThreshold'] as int? ?? 50;

  /// Node to check
  int? get nodeNum => config['nodeNum'] as int?;

  Map<String, dynamic> toJson() => {'type': type.name, 'config': config};

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      type: ConditionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ConditionType.nodeOnline,
      ),
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }
}

/// Event that can trigger automations
class AutomationEvent {
  final TriggerType type;
  final int? nodeNum;
  final String? nodeName;
  final int? batteryLevel;
  final double? latitude;
  final double? longitude;
  final String? messageText;
  final int? channelIndex;
  final int? snr;
  final String? sensorName;
  final bool? sensorDetected;
  final DateTime timestamp;

  // Scheduled trigger fields
  /// Schedule ID that fired this event (for TriggerType.scheduled)
  final String? scheduleId;

  /// Stable slot key for deduplication (e.g., "daily:2026-01-30T09:00+11:00")
  final String? slotKey;

  /// The intended fire time (not necessarily "now") for scheduled triggers
  /// Conditions like timeRange and dayOfWeek should evaluate against this
  final DateTime? scheduledFor;

  /// Whether this is a catch-up execution (missed schedule)
  final bool isCatchUp;

  // Source protocol of this event. Defaults to `meshtastic` so existing
  // call sites that didn't carry a protocol field keep firing the same
  // automations they always did. MeshCore-sourced events are tagged via
  // `processMeshCore*` engine methods.
  final TriggerProtocol protocol;

  AutomationEvent({
    required this.type,
    this.nodeNum,
    this.nodeName,
    this.batteryLevel,
    this.latitude,
    this.longitude,
    this.messageText,
    this.channelIndex,
    this.snr,
    this.sensorName,
    this.sensorDetected,
    DateTime? timestamp,
    this.scheduleId,
    this.slotKey,
    this.scheduledFor,
    this.isCatchUp = false,
    this.protocol = TriggerProtocol.meshtastic,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory for creating a scheduled fire event
  factory AutomationEvent.scheduledFire({
    required String scheduleId,
    required String slotKey,
    required DateTime scheduledFor,
    bool isCatchUp = false,
  }) {
    return AutomationEvent(
      type: TriggerType.scheduled,
      scheduleId: scheduleId,
      slotKey: slotKey,
      scheduledFor: scheduledFor,
      timestamp: DateTime.now(),
      isCatchUp: isCatchUp,
    );
  }

  /// Get the time to use for condition evaluation
  /// For scheduled triggers, use scheduledFor; otherwise use timestamp
  DateTime get evaluationTime => scheduledFor ?? timestamp;
}

/// Automation execution log entry
/// Result of a single action execution
class ActionResult {
  final String actionName;
  final bool success;
  final String? errorMessage;

  ActionResult({
    required this.actionName,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'actionName': actionName,
    'success': success,
    'errorMessage': errorMessage,
  };

  factory ActionResult.fromJson(Map<String, dynamic> json) {
    return ActionResult(
      actionName: json['actionName'] as String,
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class AutomationLogEntry {
  final String automationId;
  final String automationName;
  final DateTime timestamp;
  final bool success;
  final String? triggerDetails;
  final String? triggerEventType;
  final String? triggerNodeName;
  final int? triggerBatteryLevel;
  final String? triggerMessageText;
  final List<String> actionsExecuted;
  final List<ActionResult>? actionResults;
  final String? errorMessage;

  /// Phase 5: Which branch was selected (null for legacy entries).
  final String? branchSelection;

  /// Phase 5: Whether this was a manual execution that bypassed conditions.
  final bool manualBypass;

  /// Phase 5: Pre-computed human-readable condition summary.
  final String? conditionSummary;

  AutomationLogEntry({
    required this.automationId,
    required this.automationName,
    required this.timestamp,
    required this.success,
    this.triggerDetails,
    this.triggerEventType,
    this.triggerNodeName,
    this.triggerBatteryLevel,
    this.triggerMessageText,
    required this.actionsExecuted,
    this.actionResults,
    this.errorMessage,
    this.branchSelection,
    this.manualBypass = false,
    this.conditionSummary,
  });

  /// Returns count of successful actions
  int get successfulActionCount =>
      actionResults?.where((r) => r.success).length ?? actionsExecuted.length;

  /// Returns count of failed actions
  int get failedActionCount =>
      actionResults?.where((r) => !r.success).length ?? 0;

  /// Returns whether any actions failed
  bool get hasFailedActions => failedActionCount > 0;

  Map<String, dynamic> toJson() => {
    'automationId': automationId,
    'automationName': automationName,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'triggerDetails': triggerDetails,
    'triggerEventType': triggerEventType,
    'triggerNodeName': triggerNodeName,
    'triggerBatteryLevel': triggerBatteryLevel,
    'triggerMessageText': triggerMessageText,
    'actionsExecuted': actionsExecuted,
    'actionResults': actionResults?.map((r) => r.toJson()).toList(),
    'errorMessage': errorMessage,
    if (branchSelection != null) 'branchSelection': branchSelection,
    if (manualBypass) 'manualBypass': manualBypass,
    if (conditionSummary != null) 'conditionSummary': conditionSummary,
  };

  factory AutomationLogEntry.fromJson(Map<String, dynamic> json) {
    return AutomationLogEntry(
      automationId: json['automationId'] as String,
      automationName: json['automationName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool,
      triggerDetails: json['triggerDetails'] as String?,
      triggerEventType: json['triggerEventType'] as String?,
      triggerNodeName: json['triggerNodeName'] as String?,
      triggerBatteryLevel: json['triggerBatteryLevel'] as int?,
      triggerMessageText: json['triggerMessageText'] as String?,
      actionsExecuted: (json['actionsExecuted'] as List).cast<String>(),
      actionResults: (json['actionResults'] as List?)
          ?.map((r) => ActionResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      branchSelection: json['branchSelection'] as String?,
      manualBypass: json['manualBypass'] as bool? ?? false,
      conditionSummary: json['conditionSummary'] as String?,
    );
  }
}
