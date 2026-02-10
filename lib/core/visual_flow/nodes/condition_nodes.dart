// SPDX-License-Identifier: GPL-3.0-or-later
// Condition node builders for the Socialmesh visual automation flow builder.
//
// Each ConditionType maps to a VSNodeData builder that:
// - Accepts an EventSignalInputData (the upstream trigger event)
// - Presents a user-configurable widget for the condition parameters
// - Emits an EventSignalOutputData that passes through the event signal
//   only when the condition is met (acts as a filter/gate on the signal)
// - Serializes/deserializes its configuration
//
// Condition nodes are pass-through filters — they sit between trigger nodes
// and action nodes, forwarding the event signal downstream only when the
// condition criteria are satisfied. At compile time, the compiler extracts
// the condition configuration from each condition node in the path and adds
// it to the compiled Automation's conditions list (AND-gated).
//
// Visually, condition nodes have one input (event signal from upstream) and
// one output (filtered event signal to downstream). The amber event signal
// wire flows through them left-to-right.

import 'package:flutter/material.dart';

import '../../../../features/automations/models/automation.dart';
import '../interfaces/event_signal_interface.dart';
import '../vs_node_view/common.dart';
import '../vs_node_view/data/vs_interface.dart';
import '../vs_node_view/data/vs_node_data.dart';
import '../vs_node_view/data/vs_subgroup.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Node width for condition nodes — wider than the default to accommodate
/// configuration widgets with proper padding.
const double _kConditionNodeWidth = 220.0;

/// All condition type identifiers.
///
/// Most identifiers match ConditionType.name values from
/// lib/features/automations/models/automation.dart. However, nodeOnline and
/// nodeOffline use a `cond_` prefix to avoid colliding with the identically
/// named trigger types in TriggerTypes. Use [fromEnum] and [toEnum] to
/// convert between ConditionType enum values and these node type strings.
class ConditionTypes {
  ConditionTypes._();

  static const timeRange = 'timeRange';
  static const dayOfWeek = 'dayOfWeek';
  static const batteryAbove = 'batteryAbove';
  static const batteryBelow = 'batteryBelow';
  // Prefixed to avoid collision with TriggerTypes.nodeOnline / nodeOffline.
  static const nodeOnline = 'cond_nodeOnline';
  static const nodeOffline = 'cond_nodeOffline';
  static const withinGeofence = 'withinGeofence';
  static const outsideGeofence = 'outsideGeofence';

  /// Maps a [ConditionType] enum value to the condition node type string
  /// used by the visual flow builder and serialization manager.
  static const Map<ConditionType, String> fromEnum = {
    ConditionType.timeRange: timeRange,
    ConditionType.dayOfWeek: dayOfWeek,
    ConditionType.batteryAbove: batteryAbove,
    ConditionType.batteryBelow: batteryBelow,
    ConditionType.nodeOnline: nodeOnline,
    ConditionType.nodeOffline: nodeOffline,
    ConditionType.withinGeofence: withinGeofence,
    ConditionType.outsideGeofence: outsideGeofence,
  };

  /// Maps a condition node type string back to a [ConditionType] enum value.
  static const Map<String, ConditionType> toEnum = {
    timeRange: ConditionType.timeRange,
    dayOfWeek: ConditionType.dayOfWeek,
    batteryAbove: ConditionType.batteryAbove,
    batteryBelow: ConditionType.batteryBelow,
    nodeOnline: ConditionType.nodeOnline,
    nodeOffline: ConditionType.nodeOffline,
    withinGeofence: ConditionType.withinGeofence,
    outsideGeofence: ConditionType.outsideGeofence,
  };

  /// Display names for each condition type.
  static const Map<String, String> displayNames = {
    timeRange: 'Time Range',
    dayOfWeek: 'Day of Week',
    batteryAbove: 'Battery Above',
    batteryBelow: 'Battery Below',
    nodeOnline: 'Node Is Online',
    nodeOffline: 'Node Is Offline',
    withinGeofence: 'Within Geofence',
    outsideGeofence: 'Outside Geofence',
  };

  /// Icons for each condition type.
  static const Map<String, IconData> icons = {
    timeRange: Icons.access_time,
    dayOfWeek: Icons.calendar_today,
    batteryAbove: Icons.battery_charging_full,
    batteryBelow: Icons.battery_alert,
    nodeOnline: Icons.wifi,
    nodeOffline: Icons.wifi_off,
    withinGeofence: Icons.location_on,
    outsideGeofence: Icons.location_off,
  };
}

// ---------------------------------------------------------------------------
// Condition config state holders
// ---------------------------------------------------------------------------

/// Configuration for time range conditions.
class _TimeRangeConfig {
  String timeStart = '08:00';
  String timeEnd = '22:00';

  dynamic toJson() => {'timeStart': timeStart, 'timeEnd': timeEnd};

  void fromJson(dynamic json) {
    if (json is Map) {
      timeStart = json['timeStart'] as String? ?? '08:00';
      timeEnd = json['timeEnd'] as String? ?? '22:00';
    }
  }
}

/// Configuration for day-of-week conditions.
class _DayOfWeekConfig {
  /// Days of week: 0 = Sunday, 6 = Saturday.
  List<int> daysOfWeek = [1, 2, 3, 4, 5]; // Default: weekdays

  dynamic toJson() => {'daysOfWeek': daysOfWeek};

  void fromJson(dynamic json) {
    if (json is Map) {
      final days = json['daysOfWeek'];
      if (days is List) {
        daysOfWeek = days.cast<int>();
      }
    }
  }
}

/// Configuration for battery threshold conditions.
class _BatteryThresholdConfig {
  int batteryThreshold;

  _BatteryThresholdConfig({this.batteryThreshold = 50});

  dynamic toJson() => {'batteryThreshold': batteryThreshold};

  void fromJson(dynamic json) {
    if (json is Map) {
      batteryThreshold = json['batteryThreshold'] as int? ?? 50;
    }
  }
}

/// Configuration for node presence conditions.
class _NodePresenceConfig {
  int? nodeNum;

  dynamic toJson() => {'nodeNum': nodeNum};

  void fromJson(dynamic json) {
    if (json is Map) {
      nodeNum = json['nodeNum'] as int?;
    }
  }
}

/// Configuration for geofence conditions.
class _GeofenceConditionConfig {
  double? lat;
  double? lon;
  double radius = 500.0;

  dynamic toJson() => {
    'geofenceLat': lat,
    'geofenceLon': lon,
    'geofenceRadius': radius,
  };

  void fromJson(dynamic json) {
    if (json is Map) {
      final latVal = json['geofenceLat'];
      lat = latVal is num ? latVal.toDouble() : null;
      final lonVal = json['geofenceLon'];
      lon = lonVal is num ? lonVal.toDouble() : null;
      final radVal = json['geofenceRadius'];
      radius = radVal is num ? radVal.toDouble() : 500.0;
    }
  }
}

// ---------------------------------------------------------------------------
// Condition node data class
//
// Unlike trigger nodes (which are VSWidgetNodes with no inputs), condition
// nodes are plain VSNodeData subclasses with one EventSignal input and one
// EventSignal output, plus an embedded config widget rendered alongside the
// interfaces.
// ---------------------------------------------------------------------------

/// A condition node that filters the event signal based on user-configured
/// criteria.
///
/// Inputs:
/// - [EventSignalInputData] 'event_in' — the upstream event signal.
///
/// Outputs:
/// - [EventSignalOutputData] 'event_out' — the filtered event signal,
///   forwarded only when the condition is met.
///
/// The embedded [configWidget] is rendered between the input and output
/// interfaces inside the node card.
class ConditionNode extends VSNodeData {
  ConditionNode({
    super.id,
    required super.type,
    required super.widgetOffset,
    required this.conditionType,
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
             type: 'event_in',
             title: 'Event',
             initialConnection: ref,
           ),
         ],
         outputData: [
           EventSignalOutputData(
             type: 'event_out',
             title: 'Event',
             outputFunction: (inputs) {
               // Pass through the upstream event signal with an added
               // condition marker. The compiler reads this to reconstruct
               // the condition chain.
               final upstream = inputs['event_in'] as EventSignalPayload?;
               if (upstream == null) {
                 return EventSignalPayload(triggerType: '', passed: false);
               }
               return upstream.copyWith(passed: upstream.passed);
             },
           ),
         ],
       );

  /// The condition type string matching ConditionType.name.
  final String conditionType;

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
      ..['conditionType'] = conditionType
      ..['value'] = getConfig();
  }
}

// ---------------------------------------------------------------------------
// Condition widget builders
// ---------------------------------------------------------------------------

/// Builds a config widget for time range conditions.
Widget _buildTimeRangeWidget(_TimeRangeConfig config) {
  return _ConditionConfigWidget(
    icon: ConditionTypes.icons[ConditionTypes.timeRange]!,
    label: ConditionTypes.displayNames[ConditionTypes.timeRange]!,
    accentColor: _kConditionAccent,
    child: Row(
      children: [
        Expanded(
          child: _TimeField(
            label: 'From',
            value: config.timeStart,
            onChanged: (v) => config.timeStart = v,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              color: _kConditionAccent.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: _TimeField(
            label: 'To',
            value: config.timeEnd,
            onChanged: (v) => config.timeEnd = v,
          ),
        ),
      ],
    ),
  );
}

/// Builds a config widget for day-of-week conditions.
Widget _buildDayOfWeekWidget(_DayOfWeekConfig config) {
  return _ConditionConfigWidget(
    icon: ConditionTypes.icons[ConditionTypes.dayOfWeek]!,
    label: ConditionTypes.displayNames[ConditionTypes.dayOfWeek]!,
    accentColor: _kConditionAccent,
    child: _DayOfWeekSelector(
      selectedDays: config.daysOfWeek,
      onChanged: (days) => config.daysOfWeek = days,
    ),
  );
}

/// Builds a config widget for battery threshold conditions.
Widget _buildBatteryThresholdWidget(
  _BatteryThresholdConfig config,
  String conditionType,
) {
  final isAbove = conditionType == ConditionTypes.batteryAbove;
  return _ConditionConfigWidget(
    icon: ConditionTypes.icons[conditionType]!,
    label: ConditionTypes.displayNames[conditionType]!,
    accentColor: _kConditionAccent,
    child: _ThresholdSlider(
      label: isAbove ? 'Above' : 'Below',
      suffix: '%',
      value: config.batteryThreshold.toDouble(),
      min: 5,
      max: 95,
      divisions: 18,
      onChanged: (v) => config.batteryThreshold = v.round(),
    ),
  );
}

/// Builds a config widget for node presence conditions.
Widget _buildNodePresenceWidget(
  _NodePresenceConfig config,
  String conditionType,
) {
  return _ConditionConfigWidget(
    icon: ConditionTypes.icons[conditionType]!,
    label: ConditionTypes.displayNames[conditionType]!,
    accentColor: _kConditionAccent,
    child: _NodeNumField(
      value: config.nodeNum,
      onChanged: (v) => config.nodeNum = v,
    ),
  );
}

/// Builds a config widget for geofence conditions.
Widget _buildGeofenceConditionWidget(
  _GeofenceConditionConfig config,
  String conditionType,
) {
  return _ConditionConfigWidget(
    icon: ConditionTypes.icons[conditionType]!,
    label: ConditionTypes.displayNames[conditionType]!,
    accentColor: _kConditionAccent,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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

// ---------------------------------------------------------------------------
// Accent color for condition nodes
// ---------------------------------------------------------------------------

/// Cyan accent for condition node headers and interface highlights.
/// Matches the BoolGate interface color for visual consistency.
const Color _kConditionAccent = Color(0xFF22D3EE);

// ---------------------------------------------------------------------------
// Public API: condition node builder list and subgroup
// ---------------------------------------------------------------------------

/// Builds a single condition node builder function for the given type.
VSNodeDataBuilder _buildConditionNodeBuilder(String conditionType) {
  switch (conditionType) {
    case ConditionTypes.timeRange:
      return (Offset offset, VSOutputData? ref) {
        final config = _TimeRangeConfig();
        return ConditionNode(
          type: conditionType,
          conditionType: conditionType,
          widgetOffset: offset,
          nodeWidth: _kConditionNodeWidth,
          title: ConditionTypes.displayNames[conditionType]!,
          ref: ref,
          configWidget: _buildTimeRangeWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ConditionTypes.dayOfWeek:
      return (Offset offset, VSOutputData? ref) {
        final config = _DayOfWeekConfig();
        return ConditionNode(
          type: conditionType,
          conditionType: conditionType,
          widgetOffset: offset,
          nodeWidth: _kConditionNodeWidth,
          title: ConditionTypes.displayNames[conditionType]!,
          ref: ref,
          configWidget: _buildDayOfWeekWidget(config),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ConditionTypes.batteryAbove:
    case ConditionTypes.batteryBelow:
      return (Offset offset, VSOutputData? ref) {
        final config = _BatteryThresholdConfig(
          batteryThreshold: conditionType == ConditionTypes.batteryAbove
              ? 50
              : 20,
        );
        return ConditionNode(
          type: conditionType,
          conditionType: conditionType,
          widgetOffset: offset,
          nodeWidth: _kConditionNodeWidth,
          title: ConditionTypes.displayNames[conditionType]!,
          ref: ref,
          configWidget: _buildBatteryThresholdWidget(config, conditionType),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ConditionTypes.nodeOnline:
    case ConditionTypes.nodeOffline:
      return (Offset offset, VSOutputData? ref) {
        final config = _NodePresenceConfig();
        return ConditionNode(
          type: conditionType,
          conditionType: conditionType,
          widgetOffset: offset,
          nodeWidth: _kConditionNodeWidth,
          title: ConditionTypes.displayNames[conditionType]!,
          ref: ref,
          configWidget: _buildNodePresenceWidget(config, conditionType),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    case ConditionTypes.withinGeofence:
    case ConditionTypes.outsideGeofence:
      return (Offset offset, VSOutputData? ref) {
        final config = _GeofenceConditionConfig();
        return ConditionNode(
          type: conditionType,
          conditionType: conditionType,
          widgetOffset: offset,
          nodeWidth: _kConditionNodeWidth,
          title: ConditionTypes.displayNames[conditionType]!,
          ref: ref,
          configWidget: _buildGeofenceConditionWidget(config, conditionType),
          getConfig: () => config.toJson(),
          setConfig: (v) => config.fromJson(v),
        );
      };

    default:
      return (Offset offset, VSOutputData? ref) {
        return ConditionNode(
          type: conditionType,
          conditionType: conditionType,
          widgetOffset: offset,
          nodeWidth: _kConditionNodeWidth,
          title: conditionType,
          ref: ref,
          configWidget: _ConditionConfigWidget(
            icon: Icons.filter_alt_outlined,
            label: conditionType,
            accentColor: _kConditionAccent,
            child: Text(
              'Unknown condition',
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

/// Returns a [VSSubgroup] containing builders for all condition node types.
///
/// This is the entry point for registering condition nodes with the
/// [VSNodeManager]. Pass this subgroup into the nodeBuilders list.
VSSubgroup conditionNodeSubgroup() {
  return VSSubgroup(
    name: 'Conditions',
    subgroup: [
      // Time
      _buildConditionNodeBuilder(ConditionTypes.timeRange),
      _buildConditionNodeBuilder(ConditionTypes.dayOfWeek),

      // Battery
      _buildConditionNodeBuilder(ConditionTypes.batteryAbove),
      _buildConditionNodeBuilder(ConditionTypes.batteryBelow),

      // Node presence
      _buildConditionNodeBuilder(ConditionTypes.nodeOnline),
      _buildConditionNodeBuilder(ConditionTypes.nodeOffline),

      // Geofence
      _buildConditionNodeBuilder(ConditionTypes.withinGeofence),
      _buildConditionNodeBuilder(ConditionTypes.outsideGeofence),
    ],
  );
}

/// Returns a flat list of all condition node builders (without subgroup
/// wrapping). Useful for registering as additional nodes for deserialization.
List<VSNodeDataBuilder> allConditionNodeBuilders() {
  return [
    ConditionTypes.timeRange,
    ConditionTypes.dayOfWeek,
    ConditionTypes.batteryAbove,
    ConditionTypes.batteryBelow,
    ConditionTypes.nodeOnline,
    ConditionTypes.nodeOffline,
    ConditionTypes.withinGeofence,
    ConditionTypes.outsideGeofence,
  ].map(_buildConditionNodeBuilder).toList();
}

// ---------------------------------------------------------------------------
// Shared widget components for condition configuration UIs
// ---------------------------------------------------------------------------

/// Root container for condition configuration widgets inside a node card.
///
/// Displays a header row with icon and label, followed by the configuration
/// [child] widget. The [accentColor] tints the header to visually
/// distinguish condition nodes from trigger and action nodes.
class _ConditionConfigWidget extends StatelessWidget {
  const _ConditionConfigWidget({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
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
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: accentColor.withValues(alpha: 0.8),
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

/// A compact time input field (HH:mm format).
class _TimeField extends StatefulWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              hintText: 'HH:mm',
              hintStyle: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
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
                  color: _kConditionAccent.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact day-of-week toggle selector.
///
/// Displays abbreviated day names (S, M, T, W, T, F, S) as toggle buttons.
/// Selected days are highlighted with the condition accent color.
class _DayOfWeekSelector extends StatefulWidget {
  const _DayOfWeekSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  @override
  State<_DayOfWeekSelector> createState() => _DayOfWeekSelectorState();
}

class _DayOfWeekSelectorState extends State<_DayOfWeekSelector> {
  late List<int> _selected;

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const double _chipSize = 26;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedDays);
  }

  void _toggle(int day) {
    setState(() {
      if (_selected.contains(day)) {
        _selected.remove(day);
      } else {
        _selected.add(day);
      }
    });
    widget.onChanged(List.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final isSelected = _selected.contains(index);
        return GestureDetector(
          onTap: () => _toggle(index),
          child: Container(
            width: _chipSize,
            height: _chipSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? _kConditionAccent.withValues(alpha: 0.3)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? _kConditionAccent
                    : colorScheme.onSurface.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _dayLabels[index],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? _kConditionAccent
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A compact node number input field.
class _NodeNumField extends StatefulWidget {
  const _NodeNumField({this.value, required this.onChanged});

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
          'Node #',
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
                hintText: 'Any',
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
                    color: _kConditionAccent.withValues(alpha: 0.6),
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
                  color: _kConditionAccent.withValues(alpha: 0.8),
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
              activeTrackColor: _kConditionAccent.withValues(alpha: 0.6),
              inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
              thumbColor: _kConditionAccent,
              overlayColor: _kConditionAccent.withValues(alpha: 0.15),
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
