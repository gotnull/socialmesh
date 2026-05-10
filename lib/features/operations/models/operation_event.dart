// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Operations event types.
//
// Operations consume normalized events instead of reaching into protocol,
// transport, or persistence layers directly. Producers (the event router)
// translate observed app state into one of these subtypes; the progress
// engine pattern-matches on the subtype to update objective counters.
//
// Each event carries a `dedupeKey` that uniquely identifies the
// observation. The engine refuses to count the same key twice for the
// same operation, which keeps progress idempotent across provider
// rebuilds, app restarts, and reconnect-driven NodeDB replays.

/// Base type for normalized observations that can advance an objective.
sealed class OperationsEvent {
  /// When the underlying observation occurred (best effort).
  DateTime get occurredAt;

  /// Stable dedupe key. Same observation = same key, regardless of when
  /// or how often the engine sees it. Format is `<kind>:<id>`.
  String get dedupeKey;
}

/// A unique non-self node was encountered (live RF / MQTT / indirect
/// sighting only — sync replays from a reconnected device's NodeDB do
/// NOT produce this event because the upstream NodeDex pipeline filters
/// them out via `NodeIngestSource.livePacket`).
class OperationNodeEncountered extends OperationsEvent {
  final int nodeNum;
  @override
  final DateTime occurredAt;

  OperationNodeEncountered({required this.nodeNum, required this.occurredAt});

  @override
  String get dedupeKey => 'node_encounter:$nodeNum';
}

/// A traceroute completed successfully. `runId` is the SQLite row UUID
/// from `TraceRouteLog.id` and is the natural unique key.
class OperationTracerouteCompleted extends OperationsEvent {
  final String runId;
  final int targetNodeId;

  /// Number of hops in the route (forward direction). Multi-hop
  /// objectives compare this against `params['minHopCount']`.
  final int hopCount;

  @override
  final DateTime occurredAt;

  OperationTracerouteCompleted({
    required this.runId,
    required this.targetNodeId,
    required this.hopCount,
    required this.occurredAt,
  });

  @override
  String get dedupeKey => 'traceroute:$runId';
}
