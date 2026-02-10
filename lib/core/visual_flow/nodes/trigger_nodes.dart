// SPDX-License-Identifier: GPL-3.0-or-later
// Trigger node builders for the Socialmesh visual automation flow builder.
//
// Each TriggerType maps to a VSWidgetNode builder that:
// - Presents a user-configurable widget (threshold sliders, node pickers, etc.)
// - Emits an EventSignalOutputData carrying the trigger config downstream
// - Serializes/deserializes its configuration via VSWidgetNode's getValue/setValue
//
// Trigger nodes are source nodes — they have no inputs and exactly one output.
// They sit on the left edge of the automation graph canvas.

import 'package:flutter/material.dart';

import '../interfaces/event_signal_interface.dart';
import '../vs_node_view/common.dart';
import '../vs_node_view/data/vs_subgroup.dart';
import '../vs_node_view/special_nodes/vs_widget_node.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Node width for trigger nodes — wider than the default to accommodate
/// configuration widgets with proper padding.
const double _kTriggerNodeWidth = 220.0;

/// All trigger type identifiers. Must match TriggerType.name values in
/// lib/features/automations/models/automation.dart.
class TriggerTypes {
  TriggerTypes._();

  static const nodeOnline = 'nodeOnline';
  static const nodeOffline = 'nodeOffline';
  static const batteryLow = 'batteryLow';
  static const batteryFull = 'batteryFull';
  static const messageReceived = 'messageReceived';
  static const messageContains = 'messageContains';
  static const positionChanged = 'positionChanged';
  static const geofenceEnter = 'geofenceEnter';
  static const geofenceExit = 'geofenceExit';
  static const nodeSilent = 'nodeSilent';
  static const scheduled = 'scheduled';
  static const signalWeak = 'signalWeak';
  static const channelActivity = 'channelActivity';
  static const detectionSensor = 'detectionSensor';
  static const manual = 'manual';

  /// Display names for each trigger type.
  static const Map<String, String> displayNames = {
    nodeOnline: 'Node Online',
    nodeOffline: 'Node Offline',
    batteryLow: 'Battery Low',
    batteryFull: 'Battery Full',
    messageReceived: 'Message Received',
    messageContains: 'Message Contains',
    positionChanged: 'Position Changed',
    geofenceEnter: 'Geofence Enter',
    geofenceExit: 'Geofence Exit',
    nodeSilent: 'Node Silent',
    scheduled: 'Scheduled',
    signalWeak: 'Signal Weak',
    channelActivity: 'Channel Activity',
    detectionSensor: 'Detection Sensor',
    manual: 'Manual',
  };

  /// Icons for each trigger type.
  static const Map<String, IconData> icons = {
    nodeOnline: Icons.wifi,
    nodeOffline: Icons.wifi_off,
    batteryLow: Icons.battery_alert,
    batteryFull: Icons.battery_full,
    messageReceived: Icons.message,
    messageContains: Icons.text_fields,
    positionChanged: Icons.location_on,
    geofenceEnter: Icons.fence,
    geofenceExit: Icons.fence_outlined,
    nodeSilent: Icons.volume_off,
    scheduled: Icons.schedule,
    signalWeak: Icons.signal_cellular_alt,
    channelActivity: Icons.forum,
    detectionSensor: Icons.sensors,
    manual: Icons.touch_app,
  };
}

// ---------------------------------------------------------------------------
// Trigger config state holders
//
// Each mutable config class holds the user's configuration for a specific
// trigger type. It is used by VSWidgetNode's getValue/setValue for
// serialization, and by the embedded widget for user interaction.
// ---------------------------------------------------------------------------

/// Configuration for triggers that optionally filter by node number.
class _NodeFilterConfig {
  int? nodeNum;

  dynamic toJson() => {'nodeNum': nodeNum};

  void fromJson(dynamic json) {
    if (json is Map) {
      nodeNum = json['nodeNum'] as int?;
    }
  }
}

/// Configuration for battery threshold triggers.
class _BatteryConfig {
  int? nodeNum;
  int threshold;

  _BatteryConfig({this.threshold = 20});

  dynamic toJson() => {'nodeNum': nodeNum, 'batteryThreshold': threshold};

  void fromJson(dynamic json) {
    if (json is Map) {
      nodeNum = json['nodeNum'] as int?;
      threshold = json['batteryThreshold'] as int? ?? 20;
    }
  }
}

/// Configuration for message-contains triggers.
class _MessageContainsConfig {
  String keyword = '';

  dynamic toJson() => {'keyword': keyword};

  void fromJson(dynamic json) {
    if (json is Map) {
      keyword = json['keyword'] as String? ?? '';
    }
  }
}

/// Configuration for geofence triggers.
class _GeofenceConfig {
  int? nodeNum;
  double? lat;
  double? lon;
  double radius = 500.0;

  dynamic toJson() => {
    'nodeNum': nodeNum,
    'geofenceLat': lat,
    'geofenceLon': lon,
    'geofenceRadius': radius,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      nodeNum = json['nodeNum'] as int?;
      final latVal = json['geofenceLat'];
      lat = latVal is num ? latVal.toDouble() : null;
      final lonVal = json['geofenceLon'];
      lon = lonVal is num ? lonVal.toDouble() : null;
      final radVal = json['geofenceRadius'];
      radius = radVal is num ? radVal.toDouble() : 500.0;
    }
  }
}

/// Configuration for node-silent triggers.
class _SilentConfig {
  int? nodeNum;
  int silentMinutes = 30;

  dynamic toJson() => {'nodeNum': nodeNum, 'silentMinutes': silentMinutes};

  void fromJson(dynamic json) {
    if (json is Map) {
      nodeNum = json['nodeNum'] as int?;
      silentMinutes = json['silentMinutes'] as int? ?? 30;
    }
  }
}

/// Configuration for scheduled triggers.
class _ScheduleConfig {
  String schedule = '';

  dynamic toJson() => {'schedule': schedule};

  void fromJson(dynamic json) {
    if (json is Map) {
      schedule = json['schedule'] as String? ?? '';
    }
  }
}

/// Configuration for signal-weak triggers.
class _SignalWeakConfig {
  int? nodeNum;
  int signalThreshold = -10;

  dynamic toJson() => {'nodeNum': nodeNum, 'signalThreshold': signalThreshold};

  void fromJson(dynamic json) {
    if (json is Map) {
      nodeNum = json['nodeNum'] as int?;
      signalThreshold = json['signalThreshold'] as int? ?? -10;
    }
  }
}

/// Configuration for channel activity triggers.
class _ChannelConfig {
  int? channelIndex;

  dynamic toJson() => {'channelIndex': channelIndex};

  void fromJson(dynamic json) {
    if (json is Map) {
      channelIndex = json['channelIndex'] as int?;
    }
  }
}

/// Configuration for detection sensor triggers.
class _DetectionSensorConfig {
  String? sensorNameFilter;
  bool? detectedStateFilter;

  dynamic toJson() => {
    'sensorNameFilter': sensorNameFilter,
    'detectedStateFilter': detectedStateFilter,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      sensorNameFilter = json['sensorNameFilter'] as String?;
      detectedStateFilter = json['detectedStateFilter'] as bool?;
    }
  }
}

// ---------------------------------------------------------------------------
// Trigger widget builders
//
// Each function returns a StatefulWidget that lets the user configure
// the trigger parameters. The config object is shared with the enclosing
// VSWidgetNode via closure, so getValue/setValue can serialize it.
// ---------------------------------------------------------------------------

/// Builds a compact config widget for node-filter triggers (nodeOnline,
/// nodeOffline, positionChanged).
Widget _buildNodeFilterWidget(_NodeFilterConfig config, String triggerType) {
  return _TriggerConfigWidget(
    icon: TriggerTypes.icons[triggerType] ?? Icons.bolt,
    label: TriggerTypes.displayNames[triggerType] ?? triggerType,
    child: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: _NodeNumField(
        value: config.nodeNum,
        onChanged: (v) => config.nodeNum = v,
      ),
    ),
  );
}

/// Builds a config widget for battery triggers with a threshold slider.
Widget _buildBatteryWidget(_BatteryConfig config, String triggerType) {
  return _TriggerConfigWidget(
    icon: TriggerTypes.icons[triggerType] ?? Icons.battery_alert,
    label: TriggerTypes.displayNames[triggerType] ?? triggerType,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeNumField(
          value: config.nodeNum,
          onChanged: (v) => config.nodeNum = v,
        ),
        const SizedBox(height: 8),
        _ThresholdSlider(
          label: 'Threshold',
          suffix: '%',
          value: config.threshold.toDouble(),
          min: 5,
          max: 95,
          divisions: 18,
          onChanged: (v) => config.threshold = v.round(),
        ),
      ],
    ),
  );
}

/// Builds a config widget for message-contains trigger with a keyword field.
Widget _buildMessageContainsWidget(_MessageContainsConfig config) {
  return _TriggerConfigWidget(
    icon: Icons.text_fields,
    label: 'Message Contains',
    child: _TextInputField(
      hint: 'Keyword...',
      value: config.keyword,
      onChanged: (v) => config.keyword = v,
    ),
  );
}

/// Builds a config widget for geofence triggers.
Widget _buildGeofenceWidget(_GeofenceConfig config, String triggerType) {
  return _TriggerConfigWidget(
    icon: TriggerTypes.icons[triggerType] ?? Icons.fence,
    label: TriggerTypes.displayNames[triggerType] ?? triggerType,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeNumField(
          value: config.nodeNum,
          onChanged: (v) => config.nodeNum = v,
        ),
        const SizedBox(height: 8),
        _CoordinateDisplay(lat: config.lat, lon: config.lon),
        const SizedBox(height: 8),
        _ThresholdSlider(
          label: 'Radius',
          suffix: 'm',
          value: config.radius,
          min: 50,
          max: 5000,
          divisions: 99,
          onChanged: (v) => config.radius = v,
        ),
      ],
    ),
  );
}

/// Builds a config widget for node-silent trigger.
Widget _buildSilentWidget(_SilentConfig config) {
  return _TriggerConfigWidget(
    icon: Icons.volume_off,
    label: 'Node Silent',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeNumField(
          value: config.nodeNum,
          onChanged: (v) => config.nodeNum = v,
        ),
        const SizedBox(height: 8),
        _ThresholdSlider(
          label: 'Silent for',
          suffix: 'min',
          value: config.silentMinutes.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          onChanged: (v) => config.silentMinutes = v.round(),
        ),
      ],
    ),
  );
}

/// Builds a config widget for scheduled trigger.
Widget _buildScheduleWidget(_ScheduleConfig config) {
  return _TriggerConfigWidget(
    icon: Icons.schedule,
    label: 'Scheduled',
    child: _TextInputField(
      hint: 'Schedule (HH:mm)...',
      value: config.schedule,
      onChanged: (v) => config.schedule = v,
    ),
  );
}

/// Builds a config widget for signal-weak trigger.
Widget _buildSignalWeakWidget(_SignalWeakConfig config) {
  return _TriggerConfigWidget(
    icon: Icons.signal_cellular_alt,
    label: 'Signal Weak',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NodeNumField(
          value: config.nodeNum,
          onChanged: (v) => config.nodeNum = v,
        ),
        const SizedBox(height: 8),
        _ThresholdSlider(
          label: 'SNR below',
          suffix: 'dB',
          value: config.signalThreshold.toDouble(),
          min: -20,
          max: 0,
          divisions: 20,
          onChanged: (v) => config.signalThreshold = v.round(),
        ),
      ],
    ),
  );
}

/// Builds a config widget for channel activity trigger.
Widget _buildChannelWidget(_ChannelConfig config) {
  return _TriggerConfigWidget(
    icon: Icons.forum,
    label: 'Channel Activity',
    child: _NodeNumField(
      label: 'Channel',
      value: config.channelIndex,
      onChanged: (v) => config.channelIndex = v,
    ),
  );
}

/// Builds a config widget for detection sensor trigger.
Widget _buildDetectionSensorWidget(_DetectionSensorConfig config) {
  return _TriggerConfigWidget(
    icon: Icons.sensors,
    label: 'Detection Sensor',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TextInputField(
          hint: 'Sensor name filter...',
          value: config.sensorNameFilter ?? '',
          onChanged: (v) => config.sensorNameFilter = v.isEmpty ? null : v,
        ),
      ],
    ),
  );
}

/// Builds a config widget for manual trigger (no configuration needed).
Widget _buildManualWidget() {
  return _TriggerConfigWidget(
    icon: Icons.touch_app,
    label: 'Manual',
    child: Text(
      'Triggered via Siri Shortcuts or UI',
      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      textAlign: TextAlign.center,
    ),
  );
}

/// Builds a config widget for simple event triggers (messageReceived,
/// positionChanged, batteryFull) that only need an optional node filter.
Widget _buildSimpleEventWidget(String triggerType) {
  return _TriggerConfigWidget(
    icon: TriggerTypes.icons[triggerType] ?? Icons.bolt,
    label: TriggerTypes.displayNames[triggerType] ?? triggerType,
    child: Text(
      'Any matching event',
      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      textAlign: TextAlign.center,
    ),
  );
}

// ---------------------------------------------------------------------------
// Public API: trigger node builder list and subgroup
// ---------------------------------------------------------------------------

/// Creates the EventSignalOutputData that all trigger nodes share.
///
/// The [triggerType] and [configGetter] are captured by closure so the
/// output function can read the current config at evaluation time.
EventSignalOutputData _makeTriggerOutput(
  String triggerType,
  Map<String, dynamic> Function() configGetter,
) {
  return EventSignalOutputData(
    type: 'event_out',
    title: 'Event',
    outputFunction: (inputs) {
      return EventSignalPayload(
        triggerType: triggerType,
        nodeNum: configGetter()['nodeNum'] as int?,
        config: configGetter(),
        passed: true,
      );
    },
  );
}

/// Builds a single trigger node builder function for the given type.
VSNodeDataBuilder _buildTriggerNodeBuilder(String triggerType) {
  switch (triggerType) {
    case TriggerTypes.nodeOnline:
    case TriggerTypes.nodeOffline:
      return (Offset offset, _) {
        final config = _NodeFilterConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: TriggerTypes.displayNames[triggerType]!,
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildNodeFilterWidget(config, triggerType),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.batteryLow:
      return (Offset offset, _) {
        final config = _BatteryConfig(threshold: 20);
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: TriggerTypes.displayNames[triggerType]!,
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildBatteryWidget(config, triggerType),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.batteryFull:
      return (Offset offset, _) {
        final config = _NodeFilterConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: TriggerTypes.displayNames[triggerType]!,
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildNodeFilterWidget(config, triggerType),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.messageReceived:
      return (Offset offset, _) {
        final config = _NodeFilterConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: TriggerTypes.displayNames[triggerType]!,
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildNodeFilterWidget(config, triggerType),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.messageContains:
      return (Offset offset, _) {
        final config = _MessageContainsConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Message Contains',
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildMessageContainsWidget(config),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.positionChanged:
      return (Offset offset, _) {
        final config = _NodeFilterConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: TriggerTypes.displayNames[triggerType]!,
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildNodeFilterWidget(config, triggerType),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.geofenceEnter:
    case TriggerTypes.geofenceExit:
      return (Offset offset, _) {
        final config = _GeofenceConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: TriggerTypes.displayNames[triggerType]!,
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildGeofenceWidget(config, triggerType),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.nodeSilent:
      return (Offset offset, _) {
        final config = _SilentConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Node Silent',
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildSilentWidget(config),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.scheduled:
      return (Offset offset, _) {
        final config = _ScheduleConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Scheduled',
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildScheduleWidget(config),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.signalWeak:
      return (Offset offset, _) {
        final config = _SignalWeakConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Signal Weak',
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildSignalWeakWidget(config),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.channelActivity:
      return (Offset offset, _) {
        final config = _ChannelConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Channel Activity',
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildChannelWidget(config),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.detectionSensor:
      return (Offset offset, _) {
        final config = _DetectionSensorConfig();
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Detection Sensor',
          outputData: _makeTriggerOutput(triggerType, () => config.toJson()),
          child: _buildDetectionSensorWidget(config),
          getValue: () => config.toJson(),
          setValue: (v) => config.fromJson(v),
        );
      };

    case TriggerTypes.manual:
      return (Offset offset, _) {
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: 'Manual',
          outputData: _makeTriggerOutput(
            triggerType,
            () => <String, dynamic>{},
          ),
          child: _buildManualWidget(),
          getValue: () => <String, dynamic>{},
          setValue: (_) {},
        );
      };

    default:
      // Fallback for unknown trigger types — produces a simple event node.
      return (Offset offset, _) {
        return VSWidgetNode(
          type: triggerType,
          widgetOffset: offset,
          nodeWidth: _kTriggerNodeWidth,
          title: triggerType,
          outputData: _makeTriggerOutput(
            triggerType,
            () => <String, dynamic>{},
          ),
          child: _buildSimpleEventWidget(triggerType),
          getValue: () => <String, dynamic>{},
          setValue: (_) {},
        );
      };
  }
}

/// Returns a [VSSubgroup] containing builders for all trigger node types.
///
/// This is the entry point for registering trigger nodes with the
/// [VSNodeManager]. Pass this subgroup into the nodeBuilders list.
VSSubgroup triggerNodeSubgroup() {
  return VSSubgroup(
    name: 'Triggers',
    subgroup: [
      // Presence
      _buildTriggerNodeBuilder(TriggerTypes.nodeOnline),
      _buildTriggerNodeBuilder(TriggerTypes.nodeOffline),
      _buildTriggerNodeBuilder(TriggerTypes.nodeSilent),

      // Battery
      _buildTriggerNodeBuilder(TriggerTypes.batteryLow),
      _buildTriggerNodeBuilder(TriggerTypes.batteryFull),

      // Messages
      _buildTriggerNodeBuilder(TriggerTypes.messageReceived),
      _buildTriggerNodeBuilder(TriggerTypes.messageContains),

      // Location
      _buildTriggerNodeBuilder(TriggerTypes.positionChanged),
      _buildTriggerNodeBuilder(TriggerTypes.geofenceEnter),
      _buildTriggerNodeBuilder(TriggerTypes.geofenceExit),

      // Signal / Channel
      _buildTriggerNodeBuilder(TriggerTypes.signalWeak),
      _buildTriggerNodeBuilder(TriggerTypes.channelActivity),

      // Sensor / Schedule / Manual
      _buildTriggerNodeBuilder(TriggerTypes.detectionSensor),
      _buildTriggerNodeBuilder(TriggerTypes.scheduled),
      _buildTriggerNodeBuilder(TriggerTypes.manual),
    ],
  );
}

/// Returns a flat list of all trigger node builders (without subgroup
/// wrapping). Useful for registering as additional nodes for deserialization
/// when the subgroup structure is not needed.
List<VSNodeDataBuilder> allTriggerNodeBuilders() {
  return [
    TriggerTypes.nodeOnline,
    TriggerTypes.nodeOffline,
    TriggerTypes.batteryLow,
    TriggerTypes.batteryFull,
    TriggerTypes.messageReceived,
    TriggerTypes.messageContains,
    TriggerTypes.positionChanged,
    TriggerTypes.geofenceEnter,
    TriggerTypes.geofenceExit,
    TriggerTypes.nodeSilent,
    TriggerTypes.scheduled,
    TriggerTypes.signalWeak,
    TriggerTypes.channelActivity,
    TriggerTypes.detectionSensor,
    TriggerTypes.manual,
  ].map(_buildTriggerNodeBuilder).toList();
}

// ---------------------------------------------------------------------------
// Shared widget components for trigger configuration UIs
// ---------------------------------------------------------------------------

/// Root container for trigger configuration widgets inside a node card.
///
/// Displays a header row with icon and label, followed by the configuration
/// [child] widget.
class _TriggerConfigWidget extends StatelessWidget {
  const _TriggerConfigWidget({
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
            Icon(icon, size: 14, color: kEventSignalColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kEventSignalColor.withValues(alpha: 0.8),
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

/// A compact text input field for trigger configuration.
class _TextInputField extends StatefulWidget {
  const _TextInputField({
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

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

    return SizedBox(
      height: 36,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
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
            borderSide: BorderSide(color: kEventSignalColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// A compact node number input field.
///
/// Displays a simple integer text field for entering a mesh node number.
/// When empty, the trigger applies to all nodes.
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
                    color: kEventSignalColor.withValues(alpha: 0.6),
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

/// A compact slider for threshold values.
class _ThresholdSlider extends StatefulWidget {
  const _ThresholdSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  State<_ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<_ThresholdSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${_currentValue.round()} ${widget.suffix}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kEventSignalColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 28,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: kEventSignalColor.withValues(alpha: 0.6),
              inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
              thumbColor: kEventSignalColor,
              overlayColor: kEventSignalColor.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _currentValue,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (v) {
                setState(() => _currentValue = v);
                widget.onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays geofence coordinates in a compact read-only format.
///
/// In Phase 2+ this will open a map picker sheet when tapped.
class _CoordinateDisplay extends StatelessWidget {
  const _CoordinateDisplay({this.lat, this.lon});

  final double? lat;
  final double? lon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCoords = lat != null && lon != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Text(
        hasCoords
            ? '${lat!.toStringAsFixed(4)}, ${lon!.toStringAsFixed(4)}'
            : 'Tap to set location',
        style: TextStyle(
          fontSize: 11,
          color: hasCoords
              ? colorScheme.onSurface.withValues(alpha: 0.7)
              : colorScheme.onSurface.withValues(alpha: 0.35),
          fontStyle: hasCoords ? FontStyle.normal : FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
