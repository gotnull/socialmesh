// SPDX-License-Identifier: GPL-3.0-or-later
// Action node builders for the Socialmesh visual automation flow builder.
//
// Each ActionType maps to a VSOutputNode-style builder that:
// - Accepts an EventSignalInputData (the upstream trigger/condition chain)
// - Presents a user-configurable widget for the action parameters
// - Acts as a terminal node (no outputs) — the end of an automation path
// - Serializes/deserializes its configuration
//
// Action nodes are terminal nodes — they sit on the right edge of the
// automation graph canvas. Each action node represents one concrete thing
// that happens when the automation fires: send a message, push a
// notification, trigger a webhook, etc.
//
// At compile time, the compiler walks backwards from each action node
// through the graph, collecting the trigger and conditions along the path,
// and builds a complete Automation object with this action in its actions
// list.

import 'package:flutter/material.dart';

import '../interfaces/action_signal_interface.dart';
import '../interfaces/event_signal_interface.dart';
import '../vs_node_view/common.dart';
import '../vs_node_view/data/vs_interface.dart';
import '../vs_node_view/data/vs_node_data.dart';
import '../vs_node_view/data/vs_subgroup.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Node width for action nodes — wider than the default to accommodate
/// configuration widgets with proper padding.
const double _kActionNodeWidth = 220.0;

/// All action type identifiers. Must match ActionType.name values in
/// lib/features/automations/models/automation.dart.
class ActionTypes {
  ActionTypes._();

  static const sendMessage = 'sendMessage';
  static const playSound = 'playSound';
  static const vibrate = 'vibrate';
  static const pushNotification = 'pushNotification';
  static const triggerWebhook = 'triggerWebhook';
  static const logEvent = 'logEvent';
  static const updateWidget = 'updateWidget';
  static const sendToChannel = 'sendToChannel';
  static const triggerShortcut = 'triggerShortcut';
  static const glyphPattern = 'glyphPattern';

  /// Display names for each action type.
  static const Map<String, String> displayNames = {
    sendMessage: 'Send Message',
    playSound: 'Play Sound',
    vibrate: 'Vibrate',
    pushNotification: 'Push Notification',
    triggerWebhook: 'Trigger Webhook',
    logEvent: 'Log Event',
    updateWidget: 'Update Widget',
    sendToChannel: 'Send to Channel',
    triggerShortcut: 'Trigger Shortcut',
    glyphPattern: 'Glyph Pattern',
  };

  /// Icons for each action type.
  static const Map<String, IconData> icons = {
    sendMessage: Icons.send,
    playSound: Icons.volume_up,
    vibrate: Icons.vibration,
    pushNotification: Icons.notifications_active,
    triggerWebhook: Icons.webhook,
    logEvent: Icons.receipt_long,
    updateWidget: Icons.widgets,
    sendToChannel: Icons.forum,
    triggerShortcut: Icons.shortcut,
    glyphPattern: Icons.auto_awesome,
  };
}

// ---------------------------------------------------------------------------
// Action config state holders
// ---------------------------------------------------------------------------

/// Configuration for send-message actions.
class _SendMessageConfig {
  String messageText = '';
  int? targetNodeNum;

  dynamic toJson() => {
    'messageText': messageText,
    'targetNodeNum': targetNodeNum,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      messageText = json['messageText'] as String? ?? '';
      targetNodeNum = json['targetNodeNum'] as int?;
    }
  }
}

/// Configuration for play-sound actions.
class _PlaySoundConfig {
  String? soundType;
  String? soundRtttl;
  String? soundName;

  dynamic toJson() => {
    'soundType': soundType,
    'soundRtttl': soundRtttl,
    'soundName': soundName,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      soundType = json['soundType'] as String?;
      soundRtttl = json['soundRtttl'] as String?;
      soundName = json['soundName'] as String?;
    }
  }
}

/// Configuration for push-notification actions.
class _PushNotificationConfig {
  String notificationTitle = '';
  String notificationBody = '';
  String? notificationSoundRtttl;
  String? notificationSoundName;

  dynamic toJson() => {
    'notificationTitle': notificationTitle,
    'notificationBody': notificationBody,
    'notificationSoundRtttl': notificationSoundRtttl,
    'notificationSoundName': notificationSoundName,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      notificationTitle = json['notificationTitle'] as String? ?? '';
      notificationBody = json['notificationBody'] as String? ?? '';
      notificationSoundRtttl = json['notificationSoundRtttl'] as String?;
      notificationSoundName = json['notificationSoundName'] as String?;
    }
  }
}

/// Configuration for trigger-webhook actions.
class _WebhookConfig {
  String webhookUrl = '';
  String webhookEventName = '';

  dynamic toJson() => {
    'webhookUrl': webhookUrl,
    'webhookEventName': webhookEventName,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      webhookUrl = json['webhookUrl'] as String? ?? '';
      webhookEventName = json['webhookEventName'] as String? ?? '';
    }
  }
}

/// Configuration for send-to-channel actions.
class _SendToChannelConfig {
  String messageText = '';
  int? targetChannelIndex;

  dynamic toJson() => {
    'messageText': messageText,
    'targetChannelIndex': targetChannelIndex,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      messageText = json['messageText'] as String? ?? '';
      targetChannelIndex = json['targetChannelIndex'] as int?;
    }
  }
}

/// Configuration for trigger-shortcut actions.
class _ShortcutConfig {
  String shortcutName = '';

  dynamic toJson() => {'shortcutName': shortcutName};

  void fromJson(dynamic json) {
    if (json is Map) {
      shortcutName = json['shortcutName'] as String? ?? '';
    }
  }
}

/// Configuration for glyph-pattern actions.
class _GlyphPatternConfig {
  String pattern = '';

  dynamic toJson() => {'pattern': pattern};

  void fromJson(dynamic json) {
    if (json is Map) {
      pattern = json['pattern'] as String? ?? '';
    }
  }
}

// ---------------------------------------------------------------------------
// Action node data class
//
// Action nodes are terminal — they have one EventSignal input and no outputs.
// They use a custom VSNodeData subclass that embeds the action configuration
// widget and holds the serializable config alongside the standard node data.
// ---------------------------------------------------------------------------

/// An action node representing the terminal execution step in an automation
/// graph.
///
/// Inputs:
/// - [EventSignalInputData] 'action_in' — the upstream event signal from
///   the trigger/condition chain. Only EventSignal wires can connect here,
///   enforcing that actions are always preceded by a proper trigger pipeline.
///
/// Outputs: none — action nodes are terminals.
///
/// The embedded [configWidget] is rendered inside the node card, allowing
/// users to configure the action parameters (message text, webhook URL,
/// notification title, etc.) directly on the canvas.
class ActionNode extends VSNodeData {
  ActionNode({
    super.id,
    required super.type,
    required super.widgetOffset,
    required this.actionType,
    required this.configWidget,
    required this.getConfig,
    required this.setConfig,
    super.nodeWidth,
    super.title,
    super.toolTip,
    VSOutputData? ref,
  }) : super(
         inputData: [
           EventSignalInputData(
             type: 'action_in',
             title: 'Execute',
             initialConnection: ref,
           ),
         ],
         outputData: const [],
       );

  /// The action type string matching ActionType.name.
  final String actionType;

  /// The widget displayed inside the node for user configuration.
  final Widget configWidget;

  /// Returns the current config as a JSON-serializable value.
  final dynamic Function() getConfig;

  /// Restores config from a JSON-deserialized value.
  final void Function(dynamic) setConfig;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return json
      ..['actionType'] = actionType
      ..['value'] = getConfig();
  }
}

// ---------------------------------------------------------------------------
// Action widget builders
// ---------------------------------------------------------------------------

/// Builds a config widget for send-message actions.
Widget _buildSendMessageWidget(_SendMessageConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.sendMessage]!,
    label: ActionTypes.displayNames[ActionTypes.sendMessage]!,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeNumField(
          label: 'To Node #',
          value: config.targetNodeNum,
          onChanged: (v) => config.targetNodeNum = v,
        ),
        const SizedBox(height: 8),
        _TextInputField(
          hint: 'Message text...',
          value: config.messageText,
          onChanged: (v) => config.messageText = v,
          maxLines: 2,
        ),
      ],
    ),
  );
}

/// Builds a config widget for play-sound actions.
Widget _buildPlaySoundWidget(_PlaySoundConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.playSound]!,
    label: ActionTypes.displayNames[ActionTypes.playSound]!,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TextInputField(
          hint: 'Sound name...',
          value: config.soundName ?? '',
          onChanged: (v) => config.soundName = v.isEmpty ? null : v,
        ),
        const SizedBox(height: 8),
        _TextInputField(
          hint: 'RTTTL string (optional)...',
          value: config.soundRtttl ?? '',
          onChanged: (v) => config.soundRtttl = v.isEmpty ? null : v,
        ),
      ],
    ),
  );
}

/// Builds a config widget for vibrate actions (no configuration needed).
Widget _buildVibrateWidget() {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.vibrate]!,
    label: ActionTypes.displayNames[ActionTypes.vibrate]!,
    child: Text(
      'Device vibration pattern',
      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      textAlign: TextAlign.center,
    ),
  );
}

/// Builds a config widget for push-notification actions.
Widget _buildPushNotificationWidget(_PushNotificationConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.pushNotification]!,
    label: ActionTypes.displayNames[ActionTypes.pushNotification]!,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TextInputField(
          hint: 'Notification title...',
          value: config.notificationTitle,
          onChanged: (v) => config.notificationTitle = v,
        ),
        const SizedBox(height: 8),
        _TextInputField(
          hint: 'Notification body...',
          value: config.notificationBody,
          onChanged: (v) => config.notificationBody = v,
          maxLines: 2,
        ),
      ],
    ),
  );
}

/// Builds a config widget for trigger-webhook actions.
Widget _buildTriggerWebhookWidget(_WebhookConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.triggerWebhook]!,
    label: ActionTypes.displayNames[ActionTypes.triggerWebhook]!,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TextInputField(
          hint: 'Event name (IFTTT)...',
          value: config.webhookEventName,
          onChanged: (v) => config.webhookEventName = v,
        ),
        const SizedBox(height: 8),
        _TextInputField(
          hint: 'Webhook URL...',
          value: config.webhookUrl,
          onChanged: (v) => config.webhookUrl = v,
        ),
      ],
    ),
  );
}

/// Builds a config widget for log-event actions (no configuration needed).
Widget _buildLogEventWidget() {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.logEvent]!,
    label: ActionTypes.displayNames[ActionTypes.logEvent]!,
    child: Text(
      'Records event to automation log',
      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      textAlign: TextAlign.center,
    ),
  );
}

/// Builds a config widget for update-widget actions (minimal config).
Widget _buildUpdateWidgetWidget() {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.updateWidget]!,
    label: ActionTypes.displayNames[ActionTypes.updateWidget]!,
    child: Text(
      'Refreshes home dashboard widget',
      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      textAlign: TextAlign.center,
    ),
  );
}

/// Builds a config widget for send-to-channel actions.
Widget _buildSendToChannelWidget(_SendToChannelConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.sendToChannel]!,
    label: ActionTypes.displayNames[ActionTypes.sendToChannel]!,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeNumField(
          label: 'Channel #',
          value: config.targetChannelIndex,
          onChanged: (v) => config.targetChannelIndex = v,
        ),
        const SizedBox(height: 8),
        _TextInputField(
          hint: 'Message text...',
          value: config.messageText,
          onChanged: (v) => config.messageText = v,
          maxLines: 2,
        ),
      ],
    ),
  );
}

/// Builds a config widget for trigger-shortcut actions.
Widget _buildTriggerShortcutWidget(_ShortcutConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.triggerShortcut]!,
    label: ActionTypes.displayNames[ActionTypes.triggerShortcut]!,
    child: _TextInputField(
      hint: 'Shortcut name...',
      value: config.shortcutName,
      onChanged: (v) => config.shortcutName = v,
    ),
  );
}

/// Builds a config widget for glyph-pattern actions.
Widget _buildGlyphPatternWidget(_GlyphPatternConfig config) {
  return _ActionConfigWidget(
    icon: ActionTypes.icons[ActionTypes.glyphPattern]!,
    label: ActionTypes.displayNames[ActionTypes.glyphPattern]!,
    child: _TextInputField(
      hint: 'Glyph pattern...',
      value: config.pattern,
      onChanged: (v) => config.pattern = v,
    ),
  );
}

// ---------------------------------------------------------------------------
// Public API: action node builder list and subgroup
// ---------------------------------------------------------------------------

/// Builds a single action node builder function for the given type.
VSNodeDataBuilder _buildActionNodeBuilder(String actionType) {
  switch (actionType) {
    case ActionTypes.sendMessage:
      return (Offset offset, VSOutputData? ref) {
        final config = _SendMessageConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildSendMessageWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ActionTypes.playSound:
      return (Offset offset, VSOutputData? ref) {
        final config = _PlaySoundConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildPlaySoundWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ActionTypes.vibrate:
      return (Offset offset, VSOutputData? ref) {
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildVibrateWidget(),
          getConfig: () => <String, dynamic>{},
          setConfig: (_) {},
        );
      };

    case ActionTypes.pushNotification:
      return (Offset offset, VSOutputData? ref) {
        final config = _PushNotificationConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildPushNotificationWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ActionTypes.triggerWebhook:
      return (Offset offset, VSOutputData? ref) {
        final config = _WebhookConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildTriggerWebhookWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ActionTypes.logEvent:
      return (Offset offset, VSOutputData? ref) {
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildLogEventWidget(),
          getConfig: () => <String, dynamic>{},
          setConfig: (_) {},
        );
      };

    case ActionTypes.updateWidget:
      return (Offset offset, VSOutputData? ref) {
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildUpdateWidgetWidget(),
          getConfig: () => <String, dynamic>{},
          setConfig: (_) {},
        );
      };

    case ActionTypes.sendToChannel:
      return (Offset offset, VSOutputData? ref) {
        final config = _SendToChannelConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildSendToChannelWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ActionTypes.triggerShortcut:
      return (Offset offset, VSOutputData? ref) {
        final config = _ShortcutConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildTriggerShortcutWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ActionTypes.glyphPattern:
      return (Offset offset, VSOutputData? ref) {
        final config = _GlyphPatternConfig();
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: ActionTypes.displayNames[actionType]!,
          ref: ref,
          configWidget: _buildGlyphPatternWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    default:
      // Fallback for unknown action types.
      return (Offset offset, VSOutputData? ref) {
        return ActionNode(
          type: actionType,
          actionType: actionType,
          widgetOffset: offset,
          nodeWidth: _kActionNodeWidth,
          title: actionType,
          ref: ref,
          configWidget: _ActionConfigWidget(
            icon: Icons.play_arrow,
            label: actionType,
            child: Text(
              'Unknown action',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
          getConfig: () => <String, dynamic>{},
          setConfig: (_) {},
        );
      };
  }
}

/// Returns a [VSSubgroup] containing builders for all action node types.
///
/// This is the entry point for registering action nodes with the
/// [VSNodeManager]. Pass this subgroup into the nodeBuilders list.
VSSubgroup actionNodeSubgroup() {
  return VSSubgroup(
    name: 'Actions',
    subgroup: [
      // Messaging
      _buildActionNodeBuilder(ActionTypes.sendMessage),
      _buildActionNodeBuilder(ActionTypes.sendToChannel),

      // Notifications
      _buildActionNodeBuilder(ActionTypes.pushNotification),

      // Feedback
      _buildActionNodeBuilder(ActionTypes.playSound),
      _buildActionNodeBuilder(ActionTypes.vibrate),
      _buildActionNodeBuilder(ActionTypes.glyphPattern),

      // Integration
      _buildActionNodeBuilder(ActionTypes.triggerWebhook),
      _buildActionNodeBuilder(ActionTypes.triggerShortcut),

      // System
      _buildActionNodeBuilder(ActionTypes.logEvent),
      _buildActionNodeBuilder(ActionTypes.updateWidget),
    ],
  );
}

/// Returns a flat list of all action node builders (without subgroup
/// wrapping). Useful for registering as additional nodes for deserialization.
List<VSNodeDataBuilder> allActionNodeBuilders() {
  return [
    ActionTypes.sendMessage,
    ActionTypes.playSound,
    ActionTypes.vibrate,
    ActionTypes.pushNotification,
    ActionTypes.triggerWebhook,
    ActionTypes.logEvent,
    ActionTypes.updateWidget,
    ActionTypes.sendToChannel,
    ActionTypes.triggerShortcut,
    ActionTypes.glyphPattern,
  ].map(_buildActionNodeBuilder).toList();
}

/// Returns true if the given node data represents an action node.
bool isActionNode(VSNodeData data) {
  return data is ActionNode;
}

/// Extracts the action type string from an action node.
///
/// Returns null if the node is not an ActionNode.
String? getActionType(VSNodeData data) {
  if (data is ActionNode) {
    return data.actionType;
  }
  return null;
}

/// Extracts the action configuration from an action node.
///
/// Returns null if the node is not an ActionNode.
Map<String, dynamic>? getActionConfig(VSNodeData data) {
  if (data is ActionNode) {
    final config = data.getConfig();
    if (config is Map<String, dynamic>) {
      return config;
    }
    if (config is Map) {
      return Map<String, dynamic>.from(config);
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Shared widget components for action configuration UIs
// ---------------------------------------------------------------------------

/// Root container for action configuration widgets inside a node card.
///
/// Displays a header row with icon and label in the action accent color
/// (green), followed by the configuration [child] widget.
class _ActionConfigWidget extends StatelessWidget {
  const _ActionConfigWidget({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kActionSignalColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kActionSignalColor.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// A compact text input field for action configuration.
class _TextInputField extends StatefulWidget {
  const _TextInputField({
    required this.hint,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<_TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<_TextInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: widget.maxLines > 1 ? 52 : 36,
        maxHeight: widget.maxLines > 1 ? 72 : 36,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: kActionSignalColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// A compact integer input field for node numbers and channel indices.
class _NodeNumField extends StatefulWidget {
  const _NodeNumField({
    this.label = 'Node #',
    this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_NodeNumField> createState() => _NodeNumFieldState();
}

class _NodeNumFieldState extends State<_NodeNumField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                widget.onChanged(v.isEmpty ? null : int.tryParse(v));
              },
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'All',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: kActionSignalColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
