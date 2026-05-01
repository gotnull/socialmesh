// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Constellation — domain model.
//
// Read-only relationship graph centred on a single NodeDex entry. The
// graph explains why a node exists in NodeDex by surrounding the
// identity card with the encounters, route evidence, channel context,
// telemetry, and quick actions we have for it.
//
// This file is intentionally independent of fl_nodes. The adapter
// layer at node_constellation_fl_nodes_adapter.dart converts these
// models into the package's data structures.

import 'package:flutter/foundation.dart';

/// Kinds of nodes that can appear in a NodeDex Constellation.
enum NodeDexGraphNodeType {
  identity,
  encounter,
  routeEvidence,
  channel,
  telemetry,
  message,
  action,
  group,
}

/// Kinds of edges between graph nodes.
enum NodeDexGraphEdgeType {
  observed,
  inferred,
  route,
  channel,
  telemetry,
  message,
  action,
}

/// Confidence in the relationship represented by a node or edge.
enum NodeDexGraphConfidence { high, medium, low }

/// Quick actions exposed on action nodes. The adapter layer maps each
/// of these to a concrete navigation in [NodeConstellationScreen].
enum NodeDexGraphAction { message, toggleFavourite, viewOnMap, inspectDetails }

/// Time-window selector for the Constellation filter.
enum NodeDexConstellationTimeWindow {
  /// Active now (≤ 5 minutes since last seen).
  now,

  /// Last 24 hours.
  last24h,

  /// Last 7 days.
  last7d,

  /// All time.
  all,
}

/// One label/value detail row that node cards may render via
/// [InfoTable]. Confined to a small struct so test vectors can stay
/// readable.
@immutable
class NodeDexGraphDetailRow {
  final String label;
  final String value;

  const NodeDexGraphDetailRow({required this.label, required this.value});

  @override
  bool operator ==(Object other) =>
      other is NodeDexGraphDetailRow &&
      other.label == label &&
      other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}

/// One node in the Constellation. The id is a deterministic, stable
/// string so rebuilds do not reshuffle the layout.
@immutable
class NodeDexGraphNode {
  /// Stable, deterministic identifier (e.g. `id:1234`, `enc:1234`,
  /// `ch:1234:0`, `act:1234:message`). Used as the primary key.
  final String id;

  final NodeDexGraphNodeType type;

  /// Primary user-facing line.
  final String label;

  /// Optional secondary line.
  final String? subtitle;

  final NodeDexGraphConfidence confidence;

  /// Most recent activity timestamp for deterministic ordering.
  /// `null` when no timestamp applies (e.g. action nodes).
  final DateTime? timestamp;

  /// Compact details rendered inside the card body. Capped at a few
  /// rows on purpose; this is a graph card, not a detail screen.
  final List<NodeDexGraphDetailRow> details;

  /// Set when [type] is [NodeDexGraphNodeType.action]; otherwise null.
  final NodeDexGraphAction? action;

  /// Override target for action navigation; falls back to the centre
  /// node id when null.
  final int? targetNodeNum;

  /// Whether this node represents MQTT-sourced evidence. Drives the
  /// rfOnly filter and the visual treatment of the card.
  final bool viaMqtt;

  /// Whether this is the centre of the constellation. Exactly one
  /// node in a [NodeDexConstellation] has this set to `true`.
  final bool centered;

  const NodeDexGraphNode({
    required this.id,
    required this.type,
    required this.label,
    this.subtitle,
    this.confidence = NodeDexGraphConfidence.medium,
    this.timestamp,
    this.details = const [],
    this.action,
    this.targetNodeNum,
    this.viaMqtt = false,
    this.centered = false,
  });

  @override
  bool operator ==(Object other) =>
      other is NodeDexGraphNode &&
      other.id == id &&
      other.type == type &&
      other.label == label &&
      other.subtitle == subtitle &&
      other.confidence == confidence &&
      other.timestamp == timestamp &&
      listEquals(other.details, details) &&
      other.action == action &&
      other.targetNodeNum == targetNodeNum &&
      other.viaMqtt == viaMqtt &&
      other.centered == centered;

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    label,
    subtitle,
    confidence,
    timestamp,
    Object.hashAll(details),
    action,
    targetNodeNum,
    viaMqtt,
    centered,
  ]);
}

/// One edge between two graph nodes. The id is stable across rebuilds
/// so the adapter does not have to reshuffle.
@immutable
class NodeDexGraphEdge {
  /// Deterministic id, e.g. `e:observed:id:1234:enc:1234`.
  final String id;
  final NodeDexGraphEdgeType type;
  final String fromNodeId;
  final String toNodeId;
  final NodeDexGraphConfidence confidence;
  final bool viaMqtt;

  const NodeDexGraphEdge({
    required this.id,
    required this.type,
    required this.fromNodeId,
    required this.toNodeId,
    this.confidence = NodeDexGraphConfidence.medium,
    this.viaMqtt = false,
  });

  bool get isInferred => type == NodeDexGraphEdgeType.inferred;

  @override
  bool operator ==(Object other) =>
      other is NodeDexGraphEdge &&
      other.id == id &&
      other.type == type &&
      other.fromNodeId == fromNodeId &&
      other.toNodeId == toNodeId &&
      other.confidence == confidence &&
      other.viaMqtt == viaMqtt;

  @override
  int get hashCode =>
      Object.hash(id, type, fromNodeId, toNodeId, confidence, viaMqtt);
}

/// Filter applied when materialising a [NodeDexConstellation].
@immutable
class NodeDexConstellationFilter {
  final NodeDexConstellationTimeWindow timeWindow;

  /// When true, hide every node and edge that is sourced from MQTT.
  final bool rfOnly;

  /// When false, drop edges whose [NodeDexGraphEdge.type] is
  /// [NodeDexGraphEdgeType.inferred] and any node that becomes
  /// unreachable from the centre as a result.
  final bool showInferred;

  const NodeDexConstellationFilter({
    this.timeWindow = NodeDexConstellationTimeWindow.all,
    this.rfOnly = false,
    this.showInferred = true,
  });

  /// Convenience for UI: when true, include MQTT-sourced evidence.
  bool get includeMqtt => !rfOnly;

  NodeDexConstellationFilter copyWith({
    NodeDexConstellationTimeWindow? timeWindow,
    bool? rfOnly,
    bool? showInferred,
  }) {
    return NodeDexConstellationFilter(
      timeWindow: timeWindow ?? this.timeWindow,
      rfOnly: rfOnly ?? this.rfOnly,
      showInferred: showInferred ?? this.showInferred,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NodeDexConstellationFilter &&
      other.timeWindow == timeWindow &&
      other.rfOnly == rfOnly &&
      other.showInferred == showInferred;

  @override
  int get hashCode => Object.hash(timeWindow, rfOnly, showInferred);
}

/// Reasons the constellation may be empty. Surfaced in the empty
/// state so the user understands why they are looking at nothing.
enum NodeDexConstellationEmptyReason {
  /// No NodeDex entry exists for the requested node id.
  missingEntry,

  /// The entry exists but the active filter excluded every node.
  filteredOut,
}

/// Materialised constellation for a single centre node.
@immutable
class NodeDexConstellation {
  /// Node number of the centre identity. Stable across rebuilds.
  final int centerNodeNum;

  /// All graph nodes in deterministic order. The first item is the
  /// centre when the centre is present.
  final List<NodeDexGraphNode> nodes;

  /// All graph edges in deterministic order.
  final List<NodeDexGraphEdge> edges;

  /// The filter that produced this snapshot.
  final NodeDexConstellationFilter filter;

  /// When non-null, [nodes] is empty for an explainable reason.
  final NodeDexConstellationEmptyReason? emptyReason;

  /// When set, every action card defaults its [targetNodeNum] to this
  /// when its own override is null. Same value as [centerNodeNum] in
  /// MVP; kept separate so future versions can attach actions to
  /// non-centre identities without an API break.
  int get defaultActionTarget => centerNodeNum;

  const NodeDexConstellation({
    required this.centerNodeNum,
    required this.nodes,
    required this.edges,
    required this.filter,
    this.emptyReason,
  });

  /// True when there is nothing to render.
  bool get isEmpty => nodes.isEmpty;

  /// Centre identity node, or null when the entry is missing.
  NodeDexGraphNode? get centerNode {
    for (final n in nodes) {
      if (n.centered) return n;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NodeDexConstellation &&
      other.centerNodeNum == centerNodeNum &&
      listEquals(other.nodes, nodes) &&
      listEquals(other.edges, edges) &&
      other.filter == filter &&
      other.emptyReason == emptyReason;

  @override
  int get hashCode => Object.hash(
    centerNodeNum,
    Object.hashAll(nodes),
    Object.hashAll(edges),
    filter,
    emptyReason,
  );
}

/// Sort priorities used by the provider. Exposed so tests can assert
/// the deterministic ordering contract.
class NodeDexGraphSortPriority {
  const NodeDexGraphSortPriority._();

  static int typePriority(NodeDexGraphNodeType type) {
    switch (type) {
      case NodeDexGraphNodeType.identity:
        return 0;
      case NodeDexGraphNodeType.encounter:
        return 1;
      case NodeDexGraphNodeType.routeEvidence:
        return 2;
      case NodeDexGraphNodeType.channel:
        return 3;
      case NodeDexGraphNodeType.telemetry:
        return 4;
      case NodeDexGraphNodeType.message:
        return 5;
      case NodeDexGraphNodeType.action:
        return 6;
      case NodeDexGraphNodeType.group:
        return 7;
    }
  }

  static int confidencePriority(NodeDexGraphConfidence confidence) {
    switch (confidence) {
      case NodeDexGraphConfidence.high:
        return 0;
      case NodeDexGraphConfidence.medium:
        return 1;
      case NodeDexGraphConfidence.low:
        return 2;
    }
  }

  /// Comparator implementing the project's deterministic ordering
  /// contract: type → confidence → most-recent-first → stable id.
  static int compare(NodeDexGraphNode a, NodeDexGraphNode b) {
    final typeCmp = typePriority(a.type).compareTo(typePriority(b.type));
    if (typeCmp != 0) return typeCmp;
    final confCmp = confidencePriority(
      a.confidence,
    ).compareTo(confidencePriority(b.confidence));
    if (confCmp != 0) return confCmp;
    final aTs = a.timestamp;
    final bTs = b.timestamp;
    if (aTs != null && bTs != null) {
      final tsCmp = bTs.compareTo(aTs); // most recent first
      if (tsCmp != 0) return tsCmp;
    } else if (aTs != null) {
      return -1;
    } else if (bTs != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }
}
