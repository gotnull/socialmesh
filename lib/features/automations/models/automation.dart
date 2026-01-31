// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Core automation model
class Automation {
  final String id;
  final String name;
  final String? description;
  final bool enabled;
  final AutomationTrigger trigger;
  final List<AutomationAction> actions;
  final List<AutomationCondition>? conditions;
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
    DateTime? createdAt,
    this.lastTriggered,
    this.triggerCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Automation copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    AutomationTrigger? trigger,
    List<AutomationAction>? actions,
    List<AutomationCondition>? conditions,
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
    'conditions': conditions?.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastTriggered': lastTriggered?.toIso8601String(),
    'triggerCount': triggerCount,
  };

  factory Automation.fromJson(Map<String, dynamic> json) {
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
  String get displayName {
    switch (this) {
      case TriggerType.nodeOnline:
        return 'Node becomes active';
      case TriggerType.nodeOffline:
        return 'Node becomes inactive';
      case TriggerType.batteryLow:
        return 'Battery drops below threshold';
      case TriggerType.batteryFull:
        return 'Battery fully charged';
      case TriggerType.messageReceived:
        return 'Message received';
      case TriggerType.messageContains:
        return 'Message contains keyword';
      case TriggerType.positionChanged:
        return 'Position updated';
      case TriggerType.geofenceEnter:
        return 'Enters geofence area';
      case TriggerType.geofenceExit:
        return 'Exits geofence area';
      case TriggerType.nodeSilent:
        return 'Node silent for duration';
      case TriggerType.scheduled:
        return 'Scheduled time';
      case TriggerType.signalWeak:
        return 'Signal strength drops';
      case TriggerType.channelActivity:
        return 'Activity on channel';
      case TriggerType.detectionSensor:
        return 'Detection sensor triggered';
      case TriggerType.manual:
        return 'Manual trigger';
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
        return 'Node Status';
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

  /// Default description for automation
  String get defaultDescription {
    switch (this) {
      case TriggerType.nodeOnline:
        return 'Triggered when a node is heard recently';
      case TriggerType.nodeOffline:
        return 'Triggered when a node is not heard for a while';
      case TriggerType.batteryLow:
        return 'Triggered when battery drops below threshold';
      case TriggerType.batteryFull:
        return 'Triggered when battery is fully charged';
      case TriggerType.messageReceived:
        return 'Triggered when any message is received';
      case TriggerType.messageContains:
        return 'Triggered when message contains keyword';
      case TriggerType.positionChanged:
        return 'Triggered when node position changes';
      case TriggerType.geofenceEnter:
        return 'Triggered when node enters geofence area';
      case TriggerType.geofenceExit:
        return 'Triggered when node exits geofence area';
      case TriggerType.nodeSilent:
        return 'Triggered when node is silent for duration';
      case TriggerType.scheduled:
        return 'Triggered at scheduled time';
      case TriggerType.signalWeak:
        return 'Triggered when signal strength drops';
      case TriggerType.channelActivity:
        return 'Triggered when activity on channel';
      case TriggerType.detectionSensor:
        return 'Triggered when detection sensor activates';
      case TriggerType.manual:
        return 'Triggered manually via Shortcuts or UI';
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
        return 'Message from {{node.name}}: {{message}}';
      case TriggerType.messageContains:
        return 'Keyword detected from {{node.name}}: {{message}}';
      case TriggerType.positionChanged:
        return '{{node.name}} moved to {{location}}';
      case TriggerType.geofenceEnter:
        return '{{node.name}} entered the zone';
      case TriggerType.geofenceExit:
        return '{{node.name}} left the zone';
      case TriggerType.nodeSilent:
        return "{{node.name}} hasn't been heard from in {{silent.duration}}.";
      case TriggerType.scheduled:
        return 'Scheduled alert at {{time}}';
      case TriggerType.signalWeak:
        return '{{node.name}} signal weak';
      case TriggerType.channelActivity:
        return 'Activity on {{channel.name}}: {{message}}';
      case TriggerType.detectionSensor:
        return '{{sensor.name}}: {{sensor.state}}';
      case TriggerType.manual:
        return 'Automation triggered manually';
    }
  }
}

/// Automation trigger
class AutomationTrigger {
  final TriggerType type;
  final Map<String, dynamic> config;

  const AutomationTrigger({required this.type, this.config = const {}});

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
          return 'Please enter a keyword to match';
        }
        break;
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        if (geofenceLat == null || geofenceLon == null) {
          return 'Please select a geofence location';
        }
        break;
      case TriggerType.scheduled:
        if (schedule == null || schedule!.trim().isEmpty) {
          return 'Please set a schedule time';
        }
        break;
      default:
        // No validation required for other trigger types
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
        return 'Send message to node';
      case ActionType.playSound:
        return 'Play alert sound';
      case ActionType.vibrate:
        return 'Vibrate device';
      case ActionType.pushNotification:
        return 'Push notification';
      case ActionType.triggerWebhook:
        return 'Trigger webhook (IFTTT)';
      case ActionType.logEvent:
        return 'Log to history';
      case ActionType.updateWidget:
        return 'Update home widget';
      case ActionType.sendToChannel:
        return 'Send to channel';
      case ActionType.triggerShortcut:
        return 'Run iOS Shortcut';
      case ActionType.glyphPattern:
        return 'Glyph pattern (Nothing Phone)';
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
          return 'Please enter a message to send';
        }
        if (targetNodeNum == null) {
          return 'Please select a target node';
        }
        break;
      case ActionType.sendToChannel:
        final msg = messageText;
        if (msg == null || msg.trim().isEmpty) {
          return 'Please enter a message to send';
        }
        break;
      case ActionType.triggerWebhook:
        final eventName = webhookEventName;
        if (eventName == null || eventName.trim().isEmpty) {
          return 'Please enter a webhook event name';
        }
        break;
      case ActionType.triggerShortcut:
        final name = shortcutName;
        if (name == null || name.trim().isEmpty) {
          return 'Please enter a Shortcut name';
        }
        break;
      default:
        // playSound, vibrate, pushNotification, logEvent, updateWidget
        // These don't require specific configuration
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
        return 'During time range';
      case ConditionType.dayOfWeek:
        return 'On specific days';
      case ConditionType.batteryAbove:
        return 'Battery above threshold';
      case ConditionType.batteryBelow:
        return 'Battery below threshold';
      case ConditionType.nodeOnline:
        return 'Node is active';
      case ConditionType.nodeOffline:
        return 'Node is inactive';
      case ConditionType.withinGeofence:
        return 'Within geofence';
      case ConditionType.outsideGeofence:
        return 'Outside geofence';
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
  final List<String> actionsExecuted;
  final List<ActionResult>? actionResults;
  final String? errorMessage;

  AutomationLogEntry({
    required this.automationId,
    required this.automationName,
    required this.timestamp,
    required this.success,
    this.triggerDetails,
    required this.actionsExecuted,
    this.actionResults,
    this.errorMessage,
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
    'actionsExecuted': actionsExecuted,
    'actionResults': actionResults?.map((r) => r.toJson()).toList(),
    'errorMessage': errorMessage,
  };

  factory AutomationLogEntry.fromJson(Map<String, dynamic> json) {
    return AutomationLogEntry(
      automationId: json['automationId'] as String,
      automationName: json['automationName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool,
      triggerDetails: json['triggerDetails'] as String?,
      actionsExecuted: (json['actionsExecuted'] as List).cast<String>(),
      actionResults: (json['actionResults'] as List?)
          ?.map((r) => ActionResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
