// SPDX-License-Identifier: GPL-3.0-or-later
// NodeDex query node builders for the Socialmesh visual automation flow builder.
//
// These nodes allow users to build dynamic node list pipelines on the visual
// canvas. A pipeline typically starts with an "All Nodes" source node and
// flows through filter, sort, and limit nodes to produce a refined list of
// mesh node identifiers.
//
// The output of a query pipeline (NodeListPayload) can feed into:
// - Trigger nodes: "When ANY node in this list goes offline..."
// - Action nodes: "Send message to ALL nodes in this list"
// - Other query nodes: chaining filters
//
// At compile time, the compiler extracts the filter chain from the
// NodeListPayload and stores it as metadata on the compiled Automation.
// At runtime, the automation engine re-evaluates the query against live
// NodeDex data on each trigger event.
//
// Wire color: Purple (kNodeListColor) — visually distinct from amber
// trigger, cyan condition, and green action wires.

import 'package:flutter/material.dart';

import '../interfaces/node_list_interface.dart';
import '../vs_node_view/common.dart';
import '../vs_node_view/data/vs_interface.dart';
import '../vs_node_view/data/vs_node_data.dart';
import '../vs_node_view/data/vs_subgroup.dart';
import '../vs_node_view/special_nodes/vs_widget_node.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Node width for query nodes — slightly wider to accommodate filter config.
const double _kQueryNodeWidth = 220.0;

/// Purple accent for NodeDex query node headers.
const Color _kQueryAccent = kNodeListColor;

/// All NodeDex query node type identifiers.
class NodeDexQueryTypes {
  NodeDexQueryTypes._();

  static const allNodes = 'nodedex_all_nodes';
  static const traitFilter = 'nodedex_trait_filter';
  static const distanceFilter = 'nodedex_distance_filter';
  static const encounterFilter = 'nodedex_encounter_filter';
  static const onlineFilter = 'nodedex_online_filter';
  static const batteryFilter = 'nodedex_battery_filter';
  static const nameFilter = 'nodedex_name_filter';
  static const sortNodes = 'nodedex_sort';
  static const limitNodes = 'nodedex_limit';

  /// Display names for each query node type.
  static const Map<String, String> displayNames = {
    allNodes: 'All Nodes',
    traitFilter: 'Trait Filter',
    distanceFilter: 'Distance Filter',
    encounterFilter: 'Encounter Filter',
    onlineFilter: 'Online Filter',
    batteryFilter: 'Battery Filter',
    nameFilter: 'Name Filter',
    sortNodes: 'Sort',
    limitNodes: 'Limit',
  };

  /// Icons for each query node type.
  static const Map<String, IconData> icons = {
    allNodes: Icons.dns_outlined,
    traitFilter: Icons.category_outlined,
    distanceFilter: Icons.social_distance_outlined,
    encounterFilter: Icons.visibility_outlined,
    onlineFilter: Icons.wifi_outlined,
    batteryFilter: Icons.battery_std_outlined,
    nameFilter: Icons.text_fields_outlined,
    sortNodes: Icons.sort_outlined,
    limitNodes: Icons.filter_list_outlined,
  };
}

// ---------------------------------------------------------------------------
// Config classes
// ---------------------------------------------------------------------------

class _TraitFilterConfig {
  String selectedTrait = 'beacon';

  static const List<String> allTraits = [
    'wanderer',
    'beacon',
    'ghost',
    'sentinel',
    'relay',
    'courier',
    'anchor',
    'drifter',
    'unknown',
  ];

  dynamic toJson() => {'selectedTrait': selectedTrait};

  void fromJson(dynamic json) {
    if (json is Map) {
      selectedTrait = json['selectedTrait'] as String? ?? 'beacon';
    }
  }
}

class _DistanceFilterConfig {
  String operator = 'lt';
  double distanceMeters = 10000.0;

  dynamic toJson() => {'operator': operator, 'distanceMeters': distanceMeters};

  void fromJson(dynamic json) {
    if (json is Map) {
      operator = json['operator'] as String? ?? 'lt';
      distanceMeters = (json['distanceMeters'] as num?)?.toDouble() ?? 10000.0;
    }
  }
}

class _EncounterFilterConfig {
  String operator = 'gte';
  int threshold = 5;

  dynamic toJson() => {'operator': operator, 'threshold': threshold};

  void fromJson(dynamic json) {
    if (json is Map) {
      operator = json['operator'] as String? ?? 'gte';
      threshold = json['threshold'] as int? ?? 5;
    }
  }
}

class _OnlineFilterConfig {
  bool onlineOnly = true;

  dynamic toJson() => {'onlineOnly': onlineOnly};

  void fromJson(dynamic json) {
    if (json is Map) {
      onlineOnly = json['onlineOnly'] as bool? ?? true;
    }
  }
}

class _BatteryFilterConfig {
  String operator = 'lte';
  int threshold = 20;

  dynamic toJson() => {'operator': operator, 'threshold': threshold};

  void fromJson(dynamic json) {
    if (json is Map) {
      operator = json['operator'] as String? ?? 'lte';
      threshold = json['threshold'] as int? ?? 20;
    }
  }
}

class _NameFilterConfig {
  String substring = '';

  dynamic toJson() => {'substring': substring};

  void fromJson(dynamic json) {
    if (json is Map) {
      substring = json['substring'] as String? ?? '';
    }
  }
}

class _SortConfig {
  String sortField = 'lastSeen';
  bool ascending = false;

  static const List<String> sortFields = [
    'lastSeen',
    'firstSeen',
    'encounters',
    'distance',
    'name',
    'batteryLevel',
    'snr',
  ];

  static const Map<String, String> fieldLabels = {
    'lastSeen': 'Last Seen',
    'firstSeen': 'First Seen',
    'encounters': 'Encounters',
    'distance': 'Distance',
    'name': 'Name',
    'batteryLevel': 'Battery',
    'snr': 'Signal (SNR)',
  };

  dynamic toJson() => {'sortField': sortField, 'ascending': ascending};

  void fromJson(dynamic json) {
    if (json is Map) {
      sortField = json['sortField'] as String? ?? 'lastSeen';
      ascending = json['ascending'] as bool? ?? false;
    }
  }
}

class _LimitConfig {
  int limit = 10;

  dynamic toJson() => {'limit': limit};

  void fromJson(dynamic json) {
    if (json is Map) {
      limit = json['limit'] as int? ?? 10;
    }
  }
}

// ---------------------------------------------------------------------------
// Helper to build NodeListPayload with chained filters
// ---------------------------------------------------------------------------

/// Merges upstream payload filters with a new filter, building the pipeline.
NodeListPayload _chainFilter(
  NodeListPayload? upstream,
  NodeListFilter filter,
  String description,
) {
  final upstreamFilters = upstream != null
      ? List<NodeListFilter>.from(upstream.filters)
      : <NodeListFilter>[];
  upstreamFilters.add(filter);

  final upstreamDesc = upstream?.queryDescription ?? '';
  final fullDesc = upstreamDesc.isNotEmpty
      ? '$upstreamDesc, $description'
      : description;

  return NodeListPayload(
    nodeNums: upstream?.nodeNums ?? const [],
    queryDescription: fullDesc,
    filters: upstreamFilters,
    sortField: upstream?.sortField,
    sortAscending: upstream?.sortAscending ?? true,
    limit: upstream?.limit,
  );
}

// ---------------------------------------------------------------------------
// All Nodes — source node (no input, outputs all nodes)
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildAllNodesBuilder() {
  return (Offset offset, VSOutputData? ref) {
    return VSWidgetNode(
      type: NodeDexQueryTypes.allNodes,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'All Nodes',
      outputData: NodeListOutputData(
        type: 'node_list_out',
        title: 'Nodes',
        outputFunction: (_) {
          return const NodeListPayload(queryDescription: 'All Nodes');
        },
      ),
      setValue: (_) {},
      getValue: () => null,
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.allNodes]!,
        label: 'Source: all discovered nodes',
        child: const SizedBox.shrink(),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Trait Filter
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildTraitFilterBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _TraitFilterConfig();

    return _QueryFilterNode(
      type: NodeDexQueryTypes.traitFilter,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Trait Filter',
      ref: ref,
      getConfig: () => config.toJson(),
      setConfig: (json) => config.fromJson(json),
      buildFilter: () => NodeListFilter(
        field: 'trait',
        operator: 'eq',
        value: config.selectedTrait,
      ),
      buildDescription: () =>
          'Trait = ${_traitDisplayName(config.selectedTrait)}',
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.traitFilter]!,
        label: 'Filter by trait',
        child: _TraitSelector(config: config),
      ),
    );
  };
}

String _traitDisplayName(String trait) {
  const labels = {
    'wanderer': 'Wanderer',
    'beacon': 'Beacon',
    'ghost': 'Ghost',
    'sentinel': 'Sentinel',
    'relay': 'Relay',
    'courier': 'Courier',
    'anchor': 'Anchor',
    'drifter': 'Drifter',
    'unknown': 'Newcomer',
  };
  return labels[trait] ?? trait;
}

// ---------------------------------------------------------------------------
// Distance Filter
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildDistanceFilterBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _DistanceFilterConfig();

    return _QueryFilterNode(
      type: NodeDexQueryTypes.distanceFilter,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Distance Filter',
      ref: ref,
      getConfig: () => config.toJson(),
      setConfig: (json) => config.fromJson(json),
      buildFilter: () => NodeListFilter(
        field: 'distance',
        operator: config.operator,
        value: config.distanceMeters,
      ),
      buildDescription: () {
        final opSymbol = config.operator == 'lt' ? '<' : '>';
        final km = (config.distanceMeters / 1000).toStringAsFixed(1);
        return 'Distance $opSymbol ${km}km';
      },
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.distanceFilter]!,
        label: 'Filter by distance',
        child: _DistanceConfig(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Encounter Filter
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildEncounterFilterBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _EncounterFilterConfig();

    return _QueryFilterNode(
      type: NodeDexQueryTypes.encounterFilter,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Encounter Filter',
      ref: ref,
      getConfig: () => config.toJson(),
      setConfig: (json) => config.fromJson(json),
      buildFilter: () => NodeListFilter(
        field: 'encounters',
        operator: config.operator,
        value: config.threshold,
      ),
      buildDescription: () {
        final opSymbol = config.operator == 'gte' ? '>=' : '<=';
        return 'Encounters $opSymbol ${config.threshold}';
      },
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.encounterFilter]!,
        label: 'Filter by encounter count',
        child: _EncounterConfig(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Online Filter
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildOnlineFilterBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _OnlineFilterConfig();

    return _QueryFilterNode(
      type: NodeDexQueryTypes.onlineFilter,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Online Filter',
      ref: ref,
      getConfig: () => config.toJson(),
      setConfig: (json) => config.fromJson(json),
      buildFilter: () => NodeListFilter(
        field: 'online',
        operator: 'eq',
        value: config.onlineOnly,
      ),
      buildDescription: () =>
          config.onlineOnly ? 'Online only' : 'Offline only',
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.onlineFilter]!,
        label: 'Filter by online status',
        child: _OnlineConfig(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Battery Filter
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildBatteryFilterBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _BatteryFilterConfig();

    return _QueryFilterNode(
      type: NodeDexQueryTypes.batteryFilter,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Battery Filter',
      ref: ref,
      getConfig: () => config.toJson(),
      setConfig: (json) => config.fromJson(json),
      buildFilter: () => NodeListFilter(
        field: 'batteryLevel',
        operator: config.operator,
        value: config.threshold,
      ),
      buildDescription: () {
        final opSymbol = config.operator == 'lte' ? '<=' : '>=';
        return 'Battery $opSymbol ${config.threshold}%';
      },
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.batteryFilter]!,
        label: 'Filter by battery level',
        child: _BatteryConfig(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Name Filter
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildNameFilterBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _NameFilterConfig();

    return _QueryFilterNode(
      type: NodeDexQueryTypes.nameFilter,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Name Filter',
      ref: ref,
      getConfig: () => config.toJson(),
      setConfig: (json) => config.fromJson(json),
      buildFilter: () => NodeListFilter(
        field: 'name',
        operator: 'contains',
        value: config.substring,
      ),
      buildDescription: () => 'Name contains "${config.substring}"',
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.nameFilter]!,
        label: 'Filter by name',
        child: _NameConfig(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Sort Node
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildSortBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _SortConfig();

    return _QuerySortNode(
      type: NodeDexQueryTypes.sortNodes,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Sort',
      ref: ref,
      config: config,
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.sortNodes]!,
        label: 'Sort results',
        child: _SortConfigWidget(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Limit Node
// ---------------------------------------------------------------------------

VSNodeDataBuilder _buildLimitBuilder() {
  return (Offset offset, VSOutputData? ref) {
    final config = _LimitConfig();

    return _QueryLimitNode(
      type: NodeDexQueryTypes.limitNodes,
      widgetOffset: offset,
      nodeWidth: _kQueryNodeWidth,
      title: 'Limit',
      ref: ref,
      config: config,
      child: _QueryConfigWidget(
        icon: NodeDexQueryTypes.icons[NodeDexQueryTypes.limitNodes]!,
        label: 'Limit results',
        child: _LimitConfigWidget(config: config),
      ),
    );
  };
}

// ---------------------------------------------------------------------------
// Custom node data classes
// ---------------------------------------------------------------------------

/// Filter node — has one NodeList input, one NodeList output, and a
/// configurable filter that is appended to the upstream filter chain.
class _QueryFilterNode extends VSNodeData {
  _QueryFilterNode({
    required super.type,
    required super.widgetOffset,
    required this.getConfig,
    required this.setConfig,
    required this.buildFilter,
    required this.buildDescription,
    required this.child,
    super.nodeWidth,
    super.title,
    VSOutputData? ref,
  }) : super(
         inputData: [
           NodeListInputData(
             type: 'node_list_in',
             title: 'Input',
             initialConnection: ref,
           ),
         ],
         outputData: [
           NodeListOutputData(
             type: 'node_list_out',
             title: 'Filtered',
             outputFunction: (inputs) {
               final upstream = inputs['node_list_in'] as NodeListPayload?;
               final filter = buildFilter();
               final desc = buildDescription();
               return _chainFilter(upstream, filter, desc);
             },
           ),
         ],
       );

  final dynamic Function() getConfig;
  final void Function(dynamic json) setConfig;
  final NodeListFilter Function() buildFilter;
  final String Function() buildDescription;
  final Widget child;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return json..['value'] = getConfig();
  }
}

/// Sort node — has one NodeList input, one NodeList output, applies sort
/// metadata to the upstream payload.
class _QuerySortNode extends VSNodeData {
  _QuerySortNode({
    required super.type,
    required super.widgetOffset,
    required this.config,
    required this.child,
    super.nodeWidth,
    super.title,
    VSOutputData? ref,
  }) : super(
         inputData: [
           NodeListInputData(
             type: 'node_list_in',
             title: 'Input',
             initialConnection: ref,
           ),
         ],
         outputData: [
           NodeListOutputData(
             type: 'node_list_out',
             title: 'Sorted',
             outputFunction: (inputs) {
               final upstream = inputs['node_list_in'] as NodeListPayload?;
               if (upstream == null) {
                 return NodeListPayload(
                   sortField: config.sortField,
                   sortAscending: config.ascending,
                   queryDescription:
                       'Sorted by ${_SortConfig.fieldLabels[config.sortField] ?? config.sortField}',
                 );
               }
               final direction = config.ascending ? 'asc' : 'desc';
               final fieldLabel =
                   _SortConfig.fieldLabels[config.sortField] ??
                   config.sortField;
               final desc = upstream.queryDescription.isNotEmpty
                   ? '${upstream.queryDescription}, sorted by $fieldLabel ($direction)'
                   : 'Sorted by $fieldLabel ($direction)';
               return upstream.copyWith(
                 sortField: config.sortField,
                 sortAscending: config.ascending,
                 queryDescription: desc,
               );
             },
           ),
         ],
       );

  final _SortConfig config;
  final Widget child;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return json..['value'] = config.toJson();
  }
}

/// Limit node — has one NodeList input, one NodeList output, applies a
/// result count limit to the upstream payload.
class _QueryLimitNode extends VSNodeData {
  _QueryLimitNode({
    required super.type,
    required super.widgetOffset,
    required this.config,
    required this.child,
    super.nodeWidth,
    super.title,
    VSOutputData? ref,
  }) : super(
         inputData: [
           NodeListInputData(
             type: 'node_list_in',
             title: 'Input',
             initialConnection: ref,
           ),
         ],
         outputData: [
           NodeListOutputData(
             type: 'node_list_out',
             title: 'Limited',
             outputFunction: (inputs) {
               final upstream = inputs['node_list_in'] as NodeListPayload?;
               if (upstream == null) {
                 return NodeListPayload(
                   limit: config.limit,
                   queryDescription: 'Top ${config.limit}',
                 );
               }
               final desc = upstream.queryDescription.isNotEmpty
                   ? '${upstream.queryDescription}, top ${config.limit}'
                   : 'Top ${config.limit}';
               return upstream.copyWith(
                 limit: config.limit,
                 queryDescription: desc,
               );
             },
           ),
         ],
       );

  final _LimitConfig config;
  final Widget child;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    return json..['value'] = config.toJson();
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns a [VSSubgroup] containing builders for all NodeDex query node types.
///
/// Register this subgroup in the [VSNodeManager] nodeBuilders list alongside
/// trigger, condition, logic gate, and action subgroups.
VSSubgroup nodeDexQueryNodeSubgroup() {
  return VSSubgroup(
    name: 'NodeDex',
    subgroup: [
      _buildAllNodesBuilder(),
      _buildTraitFilterBuilder(),
      _buildDistanceFilterBuilder(),
      _buildEncounterFilterBuilder(),
      _buildOnlineFilterBuilder(),
      _buildBatteryFilterBuilder(),
      _buildNameFilterBuilder(),
      _buildSortBuilder(),
      _buildLimitBuilder(),
    ],
  );
}

/// Returns a flat list of all NodeDex query node builders (without subgroup
/// wrapping). Useful for registering as additional nodes for deserialization.
List<VSNodeDataBuilder> allNodeDexQueryNodeBuilders() {
  return [
    _buildAllNodesBuilder(),
    _buildTraitFilterBuilder(),
    _buildDistanceFilterBuilder(),
    _buildEncounterFilterBuilder(),
    _buildOnlineFilterBuilder(),
    _buildBatteryFilterBuilder(),
    _buildNameFilterBuilder(),
    _buildSortBuilder(),
    _buildLimitBuilder(),
  ];
}

/// Returns true if the given node data represents a NodeDex query node.
bool isNodeDexQueryNode(VSNodeData data) {
  return data.type == NodeDexQueryTypes.allNodes ||
      data.type == NodeDexQueryTypes.traitFilter ||
      data.type == NodeDexQueryTypes.distanceFilter ||
      data.type == NodeDexQueryTypes.encounterFilter ||
      data.type == NodeDexQueryTypes.onlineFilter ||
      data.type == NodeDexQueryTypes.batteryFilter ||
      data.type == NodeDexQueryTypes.nameFilter ||
      data.type == NodeDexQueryTypes.sortNodes ||
      data.type == NodeDexQueryTypes.limitNodes;
}

/// Returns the query config from a NodeDex query node, or null if the node
/// is not a query node with extractable config.
Map<String, dynamic>? getNodeDexQueryConfig(VSNodeData data) {
  if (data is _QueryFilterNode) {
    return data.getConfig() as Map<String, dynamic>?;
  }
  if (data is _QuerySortNode) {
    return data.config.toJson() as Map<String, dynamic>;
  }
  if (data is _QueryLimitNode) {
    return data.config.toJson() as Map<String, dynamic>;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Config widget wrappers
// ---------------------------------------------------------------------------

/// Wrapper widget for query node configuration — provides consistent styling
/// with the NodeDex purple accent.
class _QueryConfigWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _QueryConfigWidget({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _kQueryAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _kQueryAccent.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (child is! SizedBox) ...[const SizedBox(height: 6), child],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trait selector widget
// ---------------------------------------------------------------------------

class _TraitSelector extends StatefulWidget {
  final _TraitFilterConfig config;

  const _TraitSelector({required this.config});

  @override
  State<_TraitSelector> createState() => _TraitSelectorState();
}

class _TraitSelectorState extends State<_TraitSelector> {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: _TraitFilterConfig.allTraits.map((trait) {
        final isSelected = widget.config.selectedTrait == trait;
        return GestureDetector(
          onTap: () {
            setState(() {
              widget.config.selectedTrait = trait;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kQueryAccent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? _kQueryAccent
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _traitDisplayName(trait),
              style: TextStyle(
                color: isSelected ? _kQueryAccent : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Distance config widget
// ---------------------------------------------------------------------------

class _DistanceConfig extends StatefulWidget {
  final _DistanceFilterConfig config;

  const _DistanceConfig({required this.config});

  @override
  State<_DistanceConfig> createState() => _DistanceConfigState();
}

class _DistanceConfigState extends State<_DistanceConfig> {
  @override
  Widget build(BuildContext context) {
    final km = (widget.config.distanceMeters / 1000).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _CompactToggle(
              options: const ['<', '>'],
              values: const ['lt', 'gt'],
              selected: widget.config.operator,
              onChanged: (val) {
                setState(() => widget.config.operator = val);
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${km}km',
              style: const TextStyle(
                color: _kQueryAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _kQueryAccent,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
              thumbColor: _kQueryAccent,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: widget.config.distanceMeters,
              min: 100,
              max: 100000,
              onChanged: (val) {
                setState(() => widget.config.distanceMeters = val);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Encounter config widget
// ---------------------------------------------------------------------------

class _EncounterConfig extends StatefulWidget {
  final _EncounterFilterConfig config;

  const _EncounterConfig({required this.config});

  @override
  State<_EncounterConfig> createState() => _EncounterConfigState();
}

class _EncounterConfigState extends State<_EncounterConfig> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CompactToggle(
          options: const ['>=', '<='],
          values: const ['gte', 'lte'],
          selected: widget.config.operator,
          onChanged: (val) {
            setState(() => widget.config.operator = val);
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: 24,
          child: TextField(
            controller: TextEditingController(
              text: widget.config.threshold.toString(),
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: _kQueryAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _kQueryAccent),
              ),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null) {
                widget.config.threshold = parsed;
              }
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Online config widget
// ---------------------------------------------------------------------------

class _OnlineConfig extends StatefulWidget {
  final _OnlineFilterConfig config;

  const _OnlineConfig({required this.config});

  @override
  State<_OnlineConfig> createState() => _OnlineConfigState();
}

class _OnlineConfigState extends State<_OnlineConfig> {
  @override
  Widget build(BuildContext context) {
    return _CompactToggle(
      options: const ['Online', 'Offline'],
      values: const ['true', 'false'],
      selected: widget.config.onlineOnly ? 'true' : 'false',
      onChanged: (val) {
        setState(() => widget.config.onlineOnly = val == 'true');
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Battery config widget
// ---------------------------------------------------------------------------

class _BatteryConfig extends StatefulWidget {
  final _BatteryFilterConfig config;

  const _BatteryConfig({required this.config});

  @override
  State<_BatteryConfig> createState() => _BatteryConfigState();
}

class _BatteryConfigState extends State<_BatteryConfig> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _CompactToggle(
              options: const ['<=', '>='],
              values: const ['lte', 'gte'],
              selected: widget.config.operator,
              onChanged: (val) {
                setState(() => widget.config.operator = val);
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.config.threshold}%',
              style: const TextStyle(
                color: _kQueryAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _kQueryAccent,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
              thumbColor: _kQueryAccent,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: widget.config.threshold.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (val) {
                setState(() => widget.config.threshold = val.round());
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Name config widget
// ---------------------------------------------------------------------------

class _NameConfig extends StatefulWidget {
  final _NameFilterConfig config;

  const _NameConfig({required this.config});

  @override
  State<_NameConfig> createState() => _NameConfigState();
}

class _NameConfigState extends State<_NameConfig> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.config.substring);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: _controller,
        style: const TextStyle(color: _kQueryAccent, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Node name...',
          hintStyle: TextStyle(
            color: Colors.grey.withValues(alpha: 0.5),
            fontSize: 12,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _kQueryAccent),
          ),
        ),
        onChanged: (val) {
          widget.config.substring = val;
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sort config widget
// ---------------------------------------------------------------------------

class _SortConfigWidget extends StatefulWidget {
  final _SortConfig config;

  const _SortConfigWidget({required this.config});

  @override
  State<_SortConfigWidget> createState() => _SortConfigWidgetState();
}

class _SortConfigWidgetState extends State<_SortConfigWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sort field selector.
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _SortConfig.sortFields.map((field) {
            final isSelected = widget.config.sortField == field;
            final label = _SortConfig.fieldLabels[field] ?? field;
            return GestureDetector(
              onTap: () {
                setState(() => widget.config.sortField = field);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kQueryAccent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? _kQueryAccent
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? _kQueryAccent : Colors.grey,
                    fontSize: 10,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        // Direction toggle.
        _CompactToggle(
          options: const ['Ascending', 'Descending'],
          values: const ['true', 'false'],
          selected: widget.config.ascending ? 'true' : 'false',
          onChanged: (val) {
            setState(() => widget.config.ascending = val == 'true');
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Limit config widget
// ---------------------------------------------------------------------------

class _LimitConfigWidget extends StatefulWidget {
  final _LimitConfig config;

  const _LimitConfigWidget({required this.config});

  @override
  State<_LimitConfigWidget> createState() => _LimitConfigWidgetState();
}

class _LimitConfigWidgetState extends State<_LimitConfigWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Top ${widget.config.limit} nodes',
          style: const TextStyle(
            color: _kQueryAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _kQueryAccent,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
              thumbColor: _kQueryAccent,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: widget.config.limit.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (val) {
                setState(() => widget.config.limit = val.round());
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact toggle widget — reused across config widgets
// ---------------------------------------------------------------------------

class _CompactToggle extends StatelessWidget {
  final List<String> options;
  final List<String> values;
  final String selected;
  final void Function(String value) onChanged;

  const _CompactToggle({
    required this.options,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(options.length, (i) {
        final isSelected = values[i] == selected;
        return GestureDetector(
          onTap: () => onChanged(values[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kQueryAccent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.horizontal(
                left: i == 0 ? const Radius.circular(6) : Radius.zero,
                right: i == options.length - 1
                    ? const Radius.circular(6)
                    : Radius.zero,
              ),
              border: Border.all(
                color: isSelected
                    ? _kQueryAccent
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              options[i],
              style: TextStyle(
                color: isSelected ? _kQueryAccent : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }
}
