// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pure progress engine.
//
// Takes a single normalized event + the current persisted progress for
// one operation and returns either:
//   - the same progress (event ignored — wrong kind, wrong window, or
//     already counted), or
//   - new progress (event counted, dedupe key recorded, completedAt set
//     if every objective is now full).
//
// No I/O, no providers, no DateTime.now() — `now` is a parameter so the
// engine is fully deterministic and trivially testable.

import '../models/operation_event.dart';
import '../models/operation_models.dart';

/// Result of attempting to apply an event.
class OperationsEngineResult {
  /// Updated progress (same instance returned when nothing changed).
  final OperationProgress progress;

  /// True when this call advanced any objective counter.
  final bool didAdvance;

  /// True when the operation transitioned to completed on this call.
  /// (False if it was already completed or is not yet completed.)
  final bool didCompleteNow;

  /// Per-objective deltas applied on this call. Empty when no advance.
  final Map<String, int> deltas;

  /// Reason the event was ignored when `didAdvance` is false. Used for
  /// observability logging only.
  final OperationsEngineSkipReason? skipReason;

  const OperationsEngineResult({
    required this.progress,
    required this.didAdvance,
    required this.didCompleteNow,
    required this.deltas,
    this.skipReason,
  });
}

enum OperationsEngineSkipReason {
  /// The operation is already complete and not repeatable.
  alreadyComplete,

  /// The operation's catalog version no longer matches persisted progress
  /// — caller should re-seed from the catalog before applying events.
  versionMismatch,

  /// The event's dedupe key is already counted for this operation.
  dedupeKeyKnown,

  /// No objective in the operation matches the event kind.
  noMatchingObjective,

  /// The event is outside the operation's active window.
  outOfWindow,

  /// The operation definition is disabled.
  disabled,
}

abstract final class OperationsProgressEngine {
  /// Apply [event] against [definition] + [current] progress and return
  /// the result.
  ///
  /// `now` is used for `completedAt` and the active-window check;
  /// callers in production pass `clock.now()` (or `DateTime.now()`),
  /// tests pass a fixed instant.
  static OperationsEngineResult apply({
    required OperationDefinition definition,
    required OperationProgress current,
    required OperationsEvent event,
    required DateTime now,
  }) {
    if (!definition.enabled) {
      return _skip(current, OperationsEngineSkipReason.disabled);
    }

    if (current.version != definition.version) {
      return _skip(current, OperationsEngineSkipReason.versionMismatch);
    }

    if (current.completedAt != null && !definition.repeatable) {
      return _skip(current, OperationsEngineSkipReason.alreadyComplete);
    }

    if (!definition.isActiveAt(event.occurredAt)) {
      return _skip(current, OperationsEngineSkipReason.outOfWindow);
    }

    if (current.dedupedKeys.contains(event.dedupeKey)) {
      return _skip(current, OperationsEngineSkipReason.dedupeKeyKnown);
    }

    final deltas = <String, int>{};
    final updated = Map<String, int>.from(current.objectiveProgress);

    for (final objective in definition.objectives) {
      if (!_eventMatchesObjective(event, objective)) continue;
      final currentCount = updated[objective.id] ?? 0;
      if (currentCount >= objective.target) continue;
      updated[objective.id] = currentCount + 1;
      deltas[objective.id] = 1;
    }

    if (deltas.isEmpty) {
      return _skip(current, OperationsEngineSkipReason.noMatchingObjective);
    }

    final newDeduped = Set<String>.from(current.dedupedKeys)
      ..add(event.dedupeKey);

    final allComplete = definition.objectives.every((o) {
      return (updated[o.id] ?? 0) >= o.target;
    });
    final didCompleteNow = allComplete && current.completedAt == null;

    return OperationsEngineResult(
      progress: current.copyWith(
        objectiveProgress: updated,
        dedupedKeys: newDeduped,
        completedAt: allComplete
            ? (current.completedAt ?? now)
            : current.completedAt,
        updatedAt: now,
      ),
      didAdvance: true,
      didCompleteNow: didCompleteNow,
      deltas: deltas,
    );
  }

  static OperationsEngineResult _skip(
    OperationProgress current,
    OperationsEngineSkipReason reason,
  ) {
    return OperationsEngineResult(
      progress: current,
      didAdvance: false,
      didCompleteNow: false,
      deltas: const {},
      skipReason: reason,
    );
  }

  static bool _eventMatchesObjective(
    OperationsEvent event,
    OperationObjective objective,
  ) {
    switch (objective.kind) {
      case OperationObjectiveKind.uniqueNodeEncounter:
        return event is OperationNodeEncountered;
      case OperationObjectiveKind.tracerouteSuccess:
        return event is OperationTracerouteCompleted;
      case OperationObjectiveKind.multiHopObserved:
        if (event is! OperationTracerouteCompleted) return false;
        final minHops = objective.paramInt('minHopCount', 2);
        return event.hopCount >= minHops;
    }
  }
}
