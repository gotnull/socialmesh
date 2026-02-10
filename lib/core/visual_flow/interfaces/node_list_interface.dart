// SPDX-License-Identifier: GPL-3.0-or-later
// Custom interface type for the Socialmesh visual automation flow builder.
//
// NodeList interfaces carry filtered lists of mesh nodes through the
// automation graph. They represent the output of NodeDex query nodes —
// filters, sorts, and set operations that narrow down the full mesh node
// population to a specific subset matching user-defined criteria.
//
// Color: Purple — visually distinct from the amber event signal, cyan bool
// gate, and green action signal wires, making NodeDex query pipelines
// immediately recognisable on the canvas.
//
// NodeList outputs can feed into:
// - Other NodeList inputs (for chaining filters: "Beacons" → "Distance > 10km")
// - Trigger node inputs (for dynamic targeting: "When ANY node in this list
//   goes offline...")
// - Action node inputs (for broadcast: "Send message to ALL nodes in this
//   list")
//
// This interface type is the foundation for Phase 3+ NodeDex query pipeline
// integration, where users build visual filter chains and feed the results
// into automations.

import 'package:flutter/material.dart';

import '../vs_node_view/data/vs_interface.dart';

/// Purple color for NodeDex query / node list wires.
///
/// Chosen to match the AppTheme.primaryPurple accent and to be visually
/// distinct from all three automation signal types (amber trigger, cyan
/// condition, green action).
const Color kNodeListColor = Color(0xFF8B5CF6);

/// Input interface that accepts a filtered node list.
///
/// Used on downstream query nodes (for chaining filters), trigger nodes
/// (for dynamic node targeting), and action nodes (for broadcast to a
/// filtered set of nodes).
///
/// Accepts connections from:
/// - [NodeListOutputData] — the primary node list output type from query
///   nodes.
class NodeListInputData extends VSInputData {
  NodeListInputData({
    required super.type,
    super.title,
    super.toolTip,
    super.initialConnection,
    super.interfaceIconBuilder,
  });

  @override
  List<Type> get acceptedTypes => [NodeListOutputData];

  @override
  Color get interfaceColor => kNodeListColor;
}

/// Output interface that emits a filtered node list.
///
/// Used on NodeDex query nodes — filter nodes, sort nodes, set operation
/// nodes (union, intersection, difference), and the root "All Nodes" source
/// node.
///
/// The [outputFunction] receives a map of the node's evaluated input values
/// and returns a [NodeListPayload] containing the filtered/sorted list of
/// mesh node identifiers and the query metadata that produced them.
class NodeListOutputData extends VSOutputData<NodeListPayload> {
  NodeListOutputData({
    required super.type,
    super.title,
    super.toolTip,
    super.outputFunction,
    super.interfaceIconBuilder,
  });

  @override
  Color get interfaceColor => kNodeListColor;
}

/// The payload carried by a node list wire.
///
/// This data structure flows through the graph at compile time (when the
/// user saves the flow) and at design-time preview. It captures both the
/// resulting list of node identifiers and the query metadata that produced
/// them, allowing the compiler to reconstruct the query pipeline for
/// runtime evaluation.
///
/// At runtime, the actual node list is evaluated dynamically by the
/// automation engine using live NodeDex data — this payload is used for
/// graph compilation and visual preview, not as a static snapshot of
/// which nodes matched at design time.
class NodeListPayload {
  const NodeListPayload({
    this.nodeNums = const [],
    this.queryDescription = '',
    this.filters = const [],
    this.sortField,
    this.sortAscending = true,
    this.limit,
  });

  /// The list of mesh node numbers that currently match the query.
  ///
  /// At design time this is populated from the current NodeDex state for
  /// visual preview (e.g. showing a count badge on the node). At compile
  /// time the compiler extracts the [filters] and [sortField] to build a
  /// dynamic query that is re-evaluated on each automation trigger.
  ///
  /// Empty list means either no nodes match or the query has not been
  /// previewed yet.
  final List<int> nodeNums;

  /// A human-readable description of the query this payload represents.
  ///
  /// Used for display in the node's subtitle and in the compiled
  /// automation's description. Built by concatenating the display names
  /// of all upstream filter nodes.
  ///
  /// Examples:
  /// - "All Nodes"
  /// - "Trait = Beacon, Distance > 10km"
  /// - "Encounters > 5, sorted by Last Seen"
  final String queryDescription;

  /// The chain of filters applied to produce this node list.
  ///
  /// Each entry is a [NodeListFilter] describing one filter step in the
  /// pipeline. The compiler uses this to build the runtime query.
  ///
  /// Filters are applied in order — the output of each filter is the input
  /// to the next.
  final List<NodeListFilter> filters;

  /// The field to sort results by, if any.
  ///
  /// Stored as a string matching the NodeDex sort field identifiers:
  /// 'lastSeen', 'encounters', 'distance', 'name', 'firstSeen',
  /// 'batteryLevel', 'snr'.
  ///
  /// Null means no sort is applied (results are in default NodeDex order).
  final String? sortField;

  /// Whether the sort is ascending (true) or descending (false).
  ///
  /// Only meaningful when [sortField] is non-null.
  final bool sortAscending;

  /// Optional limit on the number of results.
  ///
  /// When non-null, only the first [limit] nodes (after filtering and
  /// sorting) are included in the output. Useful for "Top N" queries
  /// like "The 5 most recently seen Beacons".
  final int? limit;

  /// The number of nodes currently matching the query.
  int get count => nodeNums.length;

  /// Whether the query matched any nodes.
  bool get isEmpty => nodeNums.isEmpty;

  /// Whether the query matched at least one node.
  bool get isNotEmpty => nodeNums.isNotEmpty;

  /// Creates a copy with the given fields replaced.
  NodeListPayload copyWith({
    List<int>? nodeNums,
    String? queryDescription,
    List<NodeListFilter>? filters,
    String? sortField,
    bool? sortAscending,
    int? limit,
  }) {
    return NodeListPayload(
      nodeNums: nodeNums ?? this.nodeNums,
      queryDescription: queryDescription ?? this.queryDescription,
      filters: filters ?? this.filters,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      limit: limit ?? this.limit,
    );
  }

  @override
  String toString() {
    final desc = queryDescription.isNotEmpty ? queryDescription : 'unfiltered';
    return 'NodeListPayload($desc, ${nodeNums.length} nodes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NodeListPayload) return false;
    if (other.nodeNums.length != nodeNums.length) return false;
    for (int i = 0; i < nodeNums.length; i++) {
      if (other.nodeNums[i] != nodeNums[i]) return false;
    }
    return other.queryDescription == queryDescription &&
        other.sortField == sortField &&
        other.sortAscending == sortAscending &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(nodeNums),
    queryDescription,
    sortField,
    sortAscending,
    limit,
  );
}

/// A single filter step in a NodeDex query pipeline.
///
/// Each filter describes one predicate applied to the node list. Filters
/// are composable — the output of one filter is the input to the next,
/// forming a pipeline that progressively narrows the result set.
///
/// The [field], [operator], and [value] triple maps to the NodeDex filter
/// chip system, allowing bidirectional conversion between the visual query
/// pipeline and the existing filter UI.
class NodeListFilter {
  const NodeListFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  /// The node attribute to filter on.
  ///
  /// Matches NodeDex filter field identifiers:
  /// - 'trait' — the node's assigned trait (Beacon, Wanderer, etc.)
  /// - 'distance' — distance from the user's current position in meters
  /// - 'encounters' — number of times the node has been seen
  /// - 'lastSeen' — time since the node was last heard from
  /// - 'firstSeen' — time since the node was first discovered
  /// - 'batteryLevel' — last known battery percentage
  /// - 'snr' — last known signal-to-noise ratio
  /// - 'name' — the node's display name (substring match)
  /// - 'online' — whether the node is currently online (boolean)
  /// - 'coSeenWith' — nodes co-seen with a specific other node
  final String field;

  /// The comparison operator.
  ///
  /// Supported operators:
  /// - 'eq' — equals
  /// - 'neq' — not equals
  /// - 'gt' — greater than
  /// - 'gte' — greater than or equal
  /// - 'lt' — less than
  /// - 'lte' — less than or equal
  /// - 'contains' — substring match (for string fields)
  /// - 'in' — value is in a list (for enum fields like trait)
  final String operator;

  /// The comparison value.
  ///
  /// The type depends on the [field]:
  /// - String for 'trait', 'name', 'coSeenWith'
  /// - num for 'distance', 'encounters', 'batteryLevel', 'snr'
  /// - Duration (encoded as int seconds) for 'lastSeen', 'firstSeen'
  /// - bool for 'online'
  /// - `List<String>` for 'in' operator
  final dynamic value;

  /// Converts this filter to a JSON-serialisable map.
  Map<String, dynamic> toJson() {
    return {'field': field, 'operator': operator, 'value': value};
  }

  /// Creates a filter from a JSON map.
  factory NodeListFilter.fromJson(Map<String, dynamic> json) {
    return NodeListFilter(
      field: json['field'] as String,
      operator: json['operator'] as String,
      value: json['value'],
    );
  }

  /// Human-readable description of this filter step.
  ///
  /// Examples:
  /// - "Trait = Beacon"
  /// - "Distance > 10000"
  /// - "Encounters >= 5"
  /// - "Name contains 'relay'"
  String get displayDescription {
    final opSymbol = switch (operator) {
      'eq' => '=',
      'neq' => '!=',
      'gt' => '>',
      'gte' => '>=',
      'lt' => '<',
      'lte' => '<=',
      'contains' => 'contains',
      'in' => 'in',
      _ => operator,
    };
    return '$field $opSymbol $value';
  }

  @override
  String toString() => 'NodeListFilter($displayDescription)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeListFilter &&
        other.field == field &&
        other.operator == operator &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(field, operator, value);
}
