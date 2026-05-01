// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// NodeDex Constellation provider.
//
// Builds a [NodeDexConstellation] from existing app state for a single
// centre node id. The provider is keyed by `centerNodeNum` so callers
// scoped to one entry never rebuild when an unrelated entry changes.
//
// Provider dependency graph (read top-down):
//
//   nodeDexNodeConstellationProvider(centerNodeNum)
//     ├─ nodeDexConstellationFilterProvider(centerNodeNum)
//     ├─ nodeDexEntryProvider(centerNodeNum)        — NodeDexEntry
//     ├─ nodesProvider                              — Map<int, MeshNode>
//     └─ channelsProvider                           — List<ChannelConfig>
//
// All upstream providers are watched lazily; if the entry is missing
// the provider returns a constellation with `emptyReason: missingEntry`
// rather than throwing.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import 'node_constellation_models.dart';

/// Per-centre filter state. Default: all-time, MQTT included, inferred
/// edges shown.
class NodeDexConstellationFilterNotifier
    extends Notifier<NodeDexConstellationFilter> {
  NodeDexConstellationFilterNotifier(this.centerNodeNum);

  final int centerNodeNum;

  @override
  NodeDexConstellationFilter build() => const NodeDexConstellationFilter();

  void setTimeWindow(NodeDexConstellationTimeWindow window) {
    if (state.timeWindow == window) return;
    state = state.copyWith(timeWindow: window);
  }

  void setRfOnly(bool rfOnly) {
    if (state.rfOnly == rfOnly) return;
    state = state.copyWith(rfOnly: rfOnly);
  }

  void setShowInferred(bool show) {
    if (state.showInferred == show) return;
    state = state.copyWith(showInferred: show);
  }
}

/// Filter for the constellation centred on `centerNodeNum`.
final nodeDexConstellationFilterProvider =
    NotifierProvider.family<
      NodeDexConstellationFilterNotifier,
      NodeDexConstellationFilter,
      int
    >(NodeDexConstellationFilterNotifier.new);

/// Materialised constellation for a single centre node. Keyed on the
/// node number so unrelated entries do not invalidate this provider.
final nodeDexNodeConstellationProvider =
    Provider.family<NodeDexConstellation, int>((ref, centerNodeNum) {
      final filter = ref.watch(
        nodeDexConstellationFilterProvider(centerNodeNum),
      );
      final entry = ref.watch(nodeDexEntryProvider(centerNodeNum));
      final nodes = ref.watch(nodesProvider);
      final channels = ref.watch(channelsProvider);
      final node = nodes[centerNodeNum];
      final now = clock.now();

      if (entry == null && node == null) {
        return NodeDexConstellation(
          centerNodeNum: centerNodeNum,
          nodes: const [],
          edges: const [],
          filter: filter,
          emptyReason: NodeDexConstellationEmptyReason.missingEntry,
        );
      }

      return buildNodeDexConstellation(
        centerNodeNum: centerNodeNum,
        entry: entry,
        node: node,
        channels: channels,
        filter: filter,
        now: now,
      );
    });

/// Pure-function entry point exposed for tests. Builds a
/// [NodeDexConstellation] from raw upstream values without going
/// through Riverpod, so the deterministic ordering and filter
/// behaviour can be asserted in unit tests.
NodeDexConstellation buildNodeDexConstellation({
  required int centerNodeNum,
  required NodeDexEntry? entry,
  required MeshNode? node,
  required List<ChannelConfig> channels,
  required NodeDexConstellationFilter filter,
  required DateTime now,
}) {
  if (entry == null && node == null) {
    return NodeDexConstellation(
      centerNodeNum: centerNodeNum,
      nodes: const [],
      edges: const [],
      filter: filter,
      emptyReason: NodeDexConstellationEmptyReason.missingEntry,
    );
  }

  final builder = _ConstellationBuilder(
    centerNodeNum: centerNodeNum,
    entry: entry,
    node: node,
    channels: channels,
    filter: filter,
    now: now,
  );

  builder.addIdentity();
  builder.addEncounter();
  builder.addRouteEvidence();
  builder.addChannel();
  builder.addTelemetry();
  builder.addMessage();
  builder.addActions();

  return builder.build();
}

class _ConstellationBuilder {
  // The total nodes a constellation may render (centre + 12 surrounding).
  static const int _maxNodes = 13;

  // Recency thresholds, in seconds, used by [_withinTimeWindow].
  static const int _windowNowSeconds = 5 * 60;
  static const int _window24hSeconds = 24 * 60 * 60;
  static const int _window7dSeconds = 7 * 24 * 60 * 60;

  final int centerNodeNum;
  final NodeDexEntry? entry;
  final MeshNode? node;
  final List<ChannelConfig> channels;
  final NodeDexConstellationFilter filter;
  final DateTime now;

  final List<NodeDexGraphNode> _nodes = [];
  final List<NodeDexGraphEdge> _edges = [];

  String get _identityId => 'id:$centerNodeNum';

  String _displayName() {
    final entry = this.entry;
    final node = this.node;
    final nick = entry?.localNickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final long = node?.longName?.trim();
    if (long != null && long.isNotEmpty) return long;
    final last = entry?.lastKnownName?.trim();
    if (last != null && last.isNotEmpty) return last;
    final short = node?.shortName?.trim();
    if (short != null && short.isNotEmpty) return short;
    return _hexId(centerNodeNum);
  }

  static String _hexId(int nodeNum) {
    final hex = nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '!$hex';
  }

  _ConstellationBuilder({
    required this.centerNodeNum,
    required this.entry,
    required this.node,
    required this.channels,
    required this.filter,
    required this.now,
  });

  bool _withinTimeWindow(DateTime? ts) {
    if (ts == null) return true;
    switch (filter.timeWindow) {
      case NodeDexConstellationTimeWindow.all:
        return true;
      case NodeDexConstellationTimeWindow.now:
        return now.difference(ts).inSeconds <= _windowNowSeconds;
      case NodeDexConstellationTimeWindow.last24h:
        return now.difference(ts).inSeconds <= _window24hSeconds;
      case NodeDexConstellationTimeWindow.last7d:
        return now.difference(ts).inSeconds <= _window7dSeconds;
    }
  }

  void addIdentity() {
    final entry = this.entry;
    final node = this.node;
    final lastSeen = node?.lastHeard ?? entry?.lastSeen;
    final details = <NodeDexGraphDetailRow>[
      NodeDexGraphDetailRow(label: 'ID', value: _hexId(centerNodeNum)),
      if (node?.shortName != null && node!.shortName!.trim().isNotEmpty)
        NodeDexGraphDetailRow(label: 'Short', value: node.shortName!.trim()),
      if (entry?.encounterCount != null)
        NodeDexGraphDetailRow(
          label: 'Encounters',
          value: entry!.encounterCount.toString(),
        ),
      if (lastSeen != null)
        NodeDexGraphDetailRow(
          label: 'Last seen',
          value: _formatRelative(lastSeen, now),
        ),
      if (entry?.socialTag != null)
        NodeDexGraphDetailRow(label: 'Tag', value: entry!.socialTag!.name),
    ];
    _nodes.add(
      NodeDexGraphNode(
        id: _identityId,
        type: NodeDexGraphNodeType.identity,
        label: _displayName(),
        subtitle: _hexId(centerNodeNum),
        confidence: NodeDexGraphConfidence.high,
        timestamp: lastSeen,
        details: details,
        viaMqtt: node?.viaMqtt ?? false,
        centered: true,
      ),
    );
  }

  void addEncounter() {
    final entry = this.entry;
    if (entry == null) return;
    if (entry.encounterCount <= 0 && entry.encounters.isEmpty) return;
    if (!_withinTimeWindow(entry.lastSeen)) return;

    final details = <NodeDexGraphDetailRow>[
      NodeDexGraphDetailRow(
        label: 'Total',
        value: entry.encounterCount.toString(),
      ),
      NodeDexGraphDetailRow(
        label: 'First seen',
        value: _formatRelative(entry.firstSeen, now),
      ),
      NodeDexGraphDetailRow(
        label: 'Last seen',
        value: _formatRelative(entry.lastSeen, now),
      ),
      if (entry.bestSnr != null)
        NodeDexGraphDetailRow(label: 'Best SNR', value: '${entry.bestSnr} dB'),
    ];

    final encounterId = 'enc:$centerNodeNum';
    final hasFreshEncounter =
        entry.encounters.isNotEmpty && _withinTimeWindow(entry.lastSeen);
    final confidence = hasFreshEncounter
        ? NodeDexGraphConfidence.high
        : NodeDexGraphConfidence.medium;

    _nodes.add(
      NodeDexGraphNode(
        id: encounterId,
        type: NodeDexGraphNodeType.encounter,
        label: 'Encounters',
        subtitle: '${entry.encounterCount} total',
        confidence: confidence,
        timestamp: entry.lastSeen,
        details: details,
        viaMqtt: false,
      ),
    );

    _edges.add(
      NodeDexGraphEdge(
        id: 'e:observed:$_identityId:$encounterId',
        type: NodeDexGraphEdgeType.observed,
        fromNodeId: _identityId,
        toNodeId: encounterId,
        confidence: confidence,
      ),
    );
  }

  void addRouteEvidence() {
    final node = this.node;
    if (node == null) return;
    final viaMqtt = node.viaMqtt;
    if (filter.rfOnly && viaMqtt) return;

    final hopCount = node.hopCount;
    final transport = viaMqtt ? 'MQTT' : 'RF';
    final hopText = hopCount == null
        ? 'unknown'
        : (hopCount == 0 ? 'direct' : '$hopCount hops');

    final details = <NodeDexGraphDetailRow>[
      NodeDexGraphDetailRow(label: 'Transport', value: transport),
      NodeDexGraphDetailRow(label: 'Hops', value: hopText),
      if (node.snr != null)
        NodeDexGraphDetailRow(label: 'SNR', value: '${node.snr} dB'),
      if (node.rssi != null)
        NodeDexGraphDetailRow(label: 'RSSI', value: '${node.rssi} dBm'),
    ];

    final routeId = 'rt:$centerNodeNum';
    final confidence = (hopCount != null && hopCount <= 1)
        ? NodeDexGraphConfidence.high
        : NodeDexGraphConfidence.medium;

    _nodes.add(
      NodeDexGraphNode(
        id: routeId,
        type: NodeDexGraphNodeType.routeEvidence,
        label: viaMqtt ? 'MQTT path' : 'RF path',
        subtitle: hopText,
        confidence: confidence,
        timestamp: node.lastHeard,
        details: details,
        viaMqtt: viaMqtt,
      ),
    );

    _edges.add(
      NodeDexGraphEdge(
        id: 'e:route:$_identityId:$routeId',
        type: NodeDexGraphEdgeType.route,
        fromNodeId: _identityId,
        toNodeId: routeId,
        confidence: confidence,
        viaMqtt: viaMqtt,
      ),
    );

    // Inferred edge: this RF/MQTT path explains the encounter we
    // recorded. Only added when the encounter node is actually
    // present (i.e. entry != null and within the time window).
    if (filter.showInferred && _hasNode('enc:$centerNodeNum')) {
      _edges.add(
        NodeDexGraphEdge(
          id: 'e:inferred:$routeId:enc:$centerNodeNum',
          type: NodeDexGraphEdgeType.inferred,
          fromNodeId: routeId,
          toNodeId: 'enc:$centerNodeNum',
          confidence: NodeDexGraphConfidence.low,
          viaMqtt: viaMqtt,
        ),
      );
    }
  }

  void addChannel() {
    final node = this.node;
    if (node == null) return;
    final idx = node.lastHeardChannel;
    if (idx == null) return;
    if (filter.rfOnly && (node.viaMqtt)) return;

    final ChannelConfig? channel = _findChannel(idx);
    final label = channel?.name.isNotEmpty == true
        ? channel!.name
        : 'Channel $idx';
    final channelId = 'ch:$centerNodeNum:$idx';

    final details = <NodeDexGraphDetailRow>[
      NodeDexGraphDetailRow(label: 'Index', value: idx.toString()),
      if (channel != null)
        NodeDexGraphDetailRow(label: 'Role', value: channel.role),
    ];

    _nodes.add(
      NodeDexGraphNode(
        id: channelId,
        type: NodeDexGraphNodeType.channel,
        label: label,
        subtitle: 'Last heard',
        confidence: NodeDexGraphConfidence.medium,
        timestamp: node.lastHeard,
        details: details,
        viaMqtt: node.viaMqtt,
      ),
    );

    _edges.add(
      NodeDexGraphEdge(
        id: 'e:channel:$_identityId:$channelId',
        type: NodeDexGraphEdgeType.channel,
        fromNodeId: _identityId,
        toNodeId: channelId,
        confidence: NodeDexGraphConfidence.medium,
        viaMqtt: node.viaMqtt,
      ),
    );
  }

  void addTelemetry() {
    final node = this.node;
    if (node == null) return;
    final hasAny = [
      node.batteryLevel,
      node.voltage,
      node.channelUtilization,
      node.airUtilTx,
      node.uptimeSeconds,
      node.temperature,
      node.humidity,
      node.barometricPressure,
    ].any((v) => v != null);
    if (!hasAny) return;

    final details = <NodeDexGraphDetailRow>[
      if (node.batteryLevel != null)
        NodeDexGraphDetailRow(label: 'Battery', value: '${node.batteryLevel}%'),
      if (node.voltage != null)
        NodeDexGraphDetailRow(
          label: 'Voltage',
          value: '${node.voltage!.toStringAsFixed(2)} V',
        ),
      if (node.channelUtilization != null)
        NodeDexGraphDetailRow(
          label: 'Ch util',
          value: '${node.channelUtilization!.toStringAsFixed(1)}%',
        ),
      if (node.airUtilTx != null)
        NodeDexGraphDetailRow(
          label: 'Tx air',
          value: '${node.airUtilTx!.toStringAsFixed(1)}%',
        ),
      if (node.temperature != null)
        NodeDexGraphDetailRow(
          label: 'Temp',
          value: '${node.temperature!.toStringAsFixed(1)}°C',
        ),
      if (node.humidity != null)
        NodeDexGraphDetailRow(
          label: 'Humidity',
          value: '${node.humidity!.toStringAsFixed(0)}%',
        ),
    ];

    final telemetryId = 'tel:$centerNodeNum';
    _nodes.add(
      NodeDexGraphNode(
        id: telemetryId,
        type: NodeDexGraphNodeType.telemetry,
        label: 'Telemetry',
        subtitle: details.isNotEmpty ? details.first.value : null,
        confidence: NodeDexGraphConfidence.medium,
        timestamp: node.lastHeard,
        details: details,
        viaMqtt: node.viaMqtt,
      ),
    );

    _edges.add(
      NodeDexGraphEdge(
        id: 'e:telemetry:$_identityId:$telemetryId',
        type: NodeDexGraphEdgeType.telemetry,
        fromNodeId: _identityId,
        toNodeId: telemetryId,
        confidence: NodeDexGraphConfidence.medium,
        viaMqtt: node.viaMqtt,
      ),
    );
  }

  void addMessage() {
    // Message-content access is intentionally NOT performed here. The
    // graph card renders a count and a "View thread" affordance via
    // an action node — bodies are never put into labels or subtitles.
    final entry = this.entry;
    final messageCount = entry?.messageCount ?? 0;
    if (messageCount <= 0) return;

    final messageId = 'msg:$centerNodeNum';
    _nodes.add(
      NodeDexGraphNode(
        id: messageId,
        type: NodeDexGraphNodeType.message,
        label: 'Messages',
        subtitle: '$messageCount exchanged',
        confidence: NodeDexGraphConfidence.medium,
        timestamp: entry?.lastSeen,
        details: const [],
        viaMqtt: false,
      ),
    );

    _edges.add(
      NodeDexGraphEdge(
        id: 'e:message:$_identityId:$messageId',
        type: NodeDexGraphEdgeType.message,
        fromNodeId: _identityId,
        toNodeId: messageId,
        confidence: NodeDexGraphConfidence.medium,
      ),
    );
  }

  void addActions() {
    final node = this.node;
    final hasCoords = node?.latitude != null && node?.longitude != null;
    final actions = <NodeDexGraphAction>[
      NodeDexGraphAction.message,
      NodeDexGraphAction.toggleFavourite,
      if (hasCoords) NodeDexGraphAction.viewOnMap,
      NodeDexGraphAction.inspectDetails,
    ];
    for (final action in actions) {
      _nodes.add(
        NodeDexGraphNode(
          id: 'act:$centerNodeNum:${action.name}',
          type: NodeDexGraphNodeType.action,
          label: _actionLabel(action),
          confidence: NodeDexGraphConfidence.high,
          action: action,
          targetNodeNum: centerNodeNum,
        ),
      );
      _edges.add(
        NodeDexGraphEdge(
          id: 'e:action:$_identityId:act:$centerNodeNum:${action.name}',
          type: NodeDexGraphEdgeType.action,
          fromNodeId: _identityId,
          toNodeId: 'act:$centerNodeNum:${action.name}',
          confidence: NodeDexGraphConfidence.high,
        ),
      );
    }
  }

  static String _actionLabel(NodeDexGraphAction action) {
    switch (action) {
      case NodeDexGraphAction.message:
        return 'Message';
      case NodeDexGraphAction.toggleFavourite:
        return 'Favourite';
      case NodeDexGraphAction.viewOnMap:
        return 'View on map';
      case NodeDexGraphAction.inspectDetails:
        return 'Inspect details';
    }
  }

  ChannelConfig? _findChannel(int index) {
    for (final c in channels) {
      if (c.index == index) return c;
    }
    return null;
  }

  bool _hasNode(String id) {
    for (final n in _nodes) {
      if (n.id == id) return true;
    }
    return false;
  }

  NodeDexConstellation build() {
    // Apply the rfOnly filter to MQTT-tagged surrounding nodes
    // (centre is exempt — hiding it would defeat the screen).
    final retained = <NodeDexGraphNode>[];
    for (final n in _nodes) {
      if (filter.rfOnly && n.viaMqtt && !n.centered) continue;
      retained.add(n);
    }

    // Drop edges whose endpoints disappeared, and inferred edges when
    // the filter says so.
    final retainedIds = retained.map((n) => n.id).toSet();
    final retainedEdges = <NodeDexGraphEdge>[];
    for (final e in _edges) {
      if (!filter.showInferred && e.isInferred) continue;
      if (filter.rfOnly && e.viaMqtt) continue;
      if (!retainedIds.contains(e.fromNodeId)) continue;
      if (!retainedIds.contains(e.toNodeId)) continue;
      retainedEdges.add(e);
    }

    // Deterministic sort then cap.
    retained.sort(NodeDexGraphSortPriority.compare);
    final capped = retained.length > _maxNodes
        ? retained.sublist(0, _maxNodes)
        : retained;
    final cappedIds = capped.map((n) => n.id).toSet();
    final cappedEdges =
        retainedEdges
            .where(
              (e) =>
                  cappedIds.contains(e.fromNodeId) &&
                  cappedIds.contains(e.toNodeId),
            )
            .toList(growable: false)
          ..sort((a, b) => a.id.compareTo(b.id));

    final emptyReason = capped.isEmpty
        ? (entry == null && node == null
              ? NodeDexConstellationEmptyReason.missingEntry
              : NodeDexConstellationEmptyReason.filteredOut)
        : null;

    return NodeDexConstellation(
      centerNodeNum: centerNodeNum,
      nodes: List.unmodifiable(capped),
      edges: List.unmodifiable(cappedEdges),
      filter: filter,
      emptyReason: emptyReason,
    );
  }
}

String _formatRelative(DateTime ts, DateTime now) {
  final diff = now.difference(ts);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
