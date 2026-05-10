// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Operations domain models.
//
// SocialMesh Operations are time-bound or evergreen passive participation
// objectives. They derive progress from observed app state only — they
// never send packets, touch transports, or generate RF traffic.
//
// This file owns the data contracts. The catalog lives in
// `domain/operation_catalog.dart`. Persisted progress lives in
// `data/operations_repository.dart`. Event ingestion lives in
// `models/operation_event.dart`.

import 'dart:convert';

/// Coarse classification used by the UI to group operations.
enum OperationCategory {
  /// Discovery — encounter and discover nodes on the mesh.
  discovery,

  /// Connectivity — traceroutes, multi-hop paths, link health.
  connectivity,

  /// Coverage — geographic and signal reach (deferred in v1).
  coverage,

  /// Endurance — long-running active participation (deferred in v1).
  endurance,

  /// Community — event and seasonal operations (future).
  community,
}

/// What kind of observed event satisfies an objective.
///
/// Each kind maps to a normalized `OperationsEvent` subtype the engine
/// already knows how to count. New kinds require a corresponding event
/// type and engine handler.
enum OperationObjectiveKind {
  /// Count unique non-self node encounters.
  uniqueNodeEncounter,

  /// Count successful traceroute completions.
  tracerouteSuccess,

  /// Count traceroutes whose route length is greater than a target hop count.
  multiHopObserved,
}

/// Reward kinds. v1 only includes cosmetic / metadata rewards. No paid
/// currency or server redemption.
enum OperationRewardKind { badge, patch, sigilTrait, themeToken, title }

/// Lifecycle state for an operation derived from its persisted progress.
enum OperationCompletionState {
  /// No persisted progress yet — counters at zero.
  notStarted,

  /// At least one objective has progress > 0 but the operation is not
  /// fully complete.
  inProgress,

  /// All objectives reached their targets.
  completed,
}

/// A single objective belonging to an `OperationDefinition`.
///
/// An operation is complete only when every objective reaches its target.
class OperationObjective {
  /// Stable identifier within the parent operation. Used as the key into
  /// `OperationProgress.objectiveProgress`.
  final String id;

  /// ARB key for the human-readable objective title.
  final String titleKey;

  /// What kind of observed event counts toward this objective.
  final OperationObjectiveKind kind;

  /// Target count required for completion.
  final int target;

  /// Optional kind-specific parameters. Examples:
  ///   - `{'minHopCount': 2}` for `multiHopObserved`.
  /// Kept as a plain `Map<String, Object?>` so additional kinds can add
  /// parameters without changing this class.
  final Map<String, Object?> params;

  const OperationObjective({
    required this.id,
    required this.titleKey,
    required this.kind,
    required this.target,
    this.params = const {},
  });

  /// Convenience for kind-specific integer parameters (returns the default
  /// when the param is missing or the wrong type).
  int paramInt(String key, int defaultValue) {
    final raw = params[key];
    if (raw is int) return raw;
    return defaultValue;
  }
}

/// Cosmetic / metadata reward awarded on operation completion.
class OperationReward {
  final OperationRewardKind kind;

  /// Identifier resolved by the receiving subsystem (badge id, sigil
  /// trait id, theme token name, etc.). Opaque to Operations itself.
  final String value;

  /// ARB key for the reward's display label.
  final String labelKey;

  const OperationReward({
    required this.kind,
    required this.value,
    required this.labelKey,
  });
}

/// Static definition of an operation. Catalog entries are defined in code
/// today; future phases may load campaigns from config or remote.
class OperationDefinition {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final OperationCategory category;
  final List<OperationObjective> objectives;
  final List<OperationReward> rewards;

  /// Optional start / end timestamps for time-bound operations. When both
  /// are null the operation is evergreen.
  final DateTime? startAt;
  final DateTime? endAt;

  /// Whether the operation can be re-completed once its rewards are
  /// claimed. v1 catalog entries are non-repeatable.
  final bool repeatable;

  /// Whether the operation appears at all. False entries are kept in the
  /// catalog as deferred placeholders so future builds can flip the flag
  /// without code changes elsewhere.
  final bool enabled;

  /// Schema version for the definition itself. Bumped if objective shape
  /// or reward shape changes meaningfully so persisted progress can be
  /// migrated or invalidated safely.
  final int version;

  const OperationDefinition({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.category,
    required this.objectives,
    required this.rewards,
    this.startAt,
    this.endAt,
    this.repeatable = false,
    this.enabled = true,
    this.version = 1,
  });

  /// True when [now] is inside the operation's active window. Evergreen
  /// operations are always active.
  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }
}

/// Persisted progress for a single operation.
///
/// `dedupedKeys` carries every event dedupe marker the engine has already
/// counted for this operation. The engine uses it to make progress updates
/// idempotent across provider rebuilds, app restarts, and reconnect-replay
/// storms.
class OperationProgress {
  final String operationId;

  /// objectiveId -> count.
  final Map<String, int> objectiveProgress;

  /// Set of `OperationsEvent.dedupeKey` values that have already been
  /// counted toward this operation. Persisted as JSON.
  final Set<String> dedupedKeys;

  final DateTime? completedAt;
  final DateTime? claimedAt;
  final DateTime updatedAt;

  /// Mirrors the catalog `OperationDefinition.version` snapshotted when
  /// progress was last written. Lets us detect stale progress if a
  /// definition's objective shape changes.
  final int version;

  const OperationProgress({
    required this.operationId,
    required this.objectiveProgress,
    required this.dedupedKeys,
    required this.updatedAt,
    required this.version,
    this.completedAt,
    this.claimedAt,
  });

  /// Empty progress for a brand-new operation.
  factory OperationProgress.empty(
    OperationDefinition def, {
    required DateTime now,
  }) {
    return OperationProgress(
      operationId: def.id,
      objectiveProgress: {for (final o in def.objectives) o.id: 0},
      dedupedKeys: const {},
      updatedAt: now,
      version: def.version,
    );
  }

  OperationProgress copyWith({
    Map<String, int>? objectiveProgress,
    Set<String>? dedupedKeys,
    DateTime? completedAt,
    DateTime? claimedAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return OperationProgress(
      operationId: operationId,
      objectiveProgress: objectiveProgress ?? this.objectiveProgress,
      dedupedKeys: dedupedKeys ?? this.dedupedKeys,
      completedAt: completedAt ?? this.completedAt,
      claimedAt: claimedAt ?? this.claimedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  /// Compute the lifecycle state given the catalog definition's targets.
  OperationCompletionState stateFor(OperationDefinition def) {
    if (completedAt != null) return OperationCompletionState.completed;
    final hasAnyProgress = objectiveProgress.values.any((c) => c > 0);
    if (!hasAnyProgress) return OperationCompletionState.notStarted;
    return OperationCompletionState.inProgress;
  }

  /// Fraction of overall completion across all objectives, clamped to
  /// `[0.0, 1.0]`. When the definition has no targets this returns 0.
  double overallFractionFor(OperationDefinition def) {
    if (def.objectives.isEmpty) return 0.0;
    var sum = 0.0;
    for (final o in def.objectives) {
      if (o.target <= 0) continue;
      final got = objectiveProgress[o.id] ?? 0;
      sum += (got / o.target).clamp(0.0, 1.0);
    }
    return (sum / def.objectives.length).clamp(0.0, 1.0);
  }

  String dedupedKeysJson() => jsonEncode(dedupedKeys.toList());
  String objectiveProgressJson() => jsonEncode(objectiveProgress);

  static Map<String, int> decodeObjectiveProgress(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map<String, int>(
      (k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0),
    );
  }

  static Set<String> decodeDedupedKeys(String? raw) {
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.map((e) => e.toString()).toSet();
  }
}
