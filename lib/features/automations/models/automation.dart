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
}

extension TriggerTypeExtension on TriggerType {
  String get displayName {
    switch (this) {
      case TriggerType.nodeOnline:
        return 'Node comes online';
      case TriggerType.nodeOffline:
        return 'Node goes offline';
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
      case TriggerType.positionChanged:
      case TriggerType.geofenceEnter:
      case TriggerType.geofenceExit:
        return 'Location';
      case TriggerType.scheduled:
        return 'Time';
      case TriggerType.signalWeak:
        return 'Signal';
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

  /// Sound type for playSound
  String? get soundType => config['soundType'] as String?;

  /// Webhook URL for triggerWebhook
  String? get webhookUrl => config['webhookUrl'] as String?;

  /// Webhook event name (for IFTTT)
  String? get webhookEventName => config['webhookEventName'] as String?;

  /// Notification title
  String? get notificationTitle => config['notificationTitle'] as String?;

  /// Notification body
  String? get notificationBody => config['notificationBody'] as String?;

  /// iOS Shortcut name
  String? get shortcutName => config['shortcutName'] as String?;

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
        return 'Node is online';
      case ConditionType.nodeOffline:
        return 'Node is offline';
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
  final DateTime timestamp;

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
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Automation execution log entry
class AutomationLogEntry {
  final String automationId;
  final String automationName;
  final DateTime timestamp;
  final bool success;
  final String? triggerDetails;
  final List<String> actionsExecuted;
  final String? errorMessage;

  AutomationLogEntry({
    required this.automationId,
    required this.automationName,
    required this.timestamp,
    required this.success,
    this.triggerDetails,
    required this.actionsExecuted,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'automationId': automationId,
    'automationName': automationName,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'triggerDetails': triggerDetails,
    'actionsExecuted': actionsExecuted,
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
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
