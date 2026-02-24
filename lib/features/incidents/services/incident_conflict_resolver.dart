// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/incident.dart';
import '../models/incident_transition.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Two transitions on the same incident are considered conflicting if their
/// timestamps differ by ≤ this value (in milliseconds).
///
/// Outside this window, the earlier timestamp wins outright.
/// Inside this window, the full 5-field tie-break chain is applied.
///
/// Spec: INCIDENT_LIFECYCLE.md — Conflict Resolution, item 2.
const int conflictWindowMs = 5000;

// ---------------------------------------------------------------------------
// Resolution result
// ---------------------------------------------------------------------------

/// Result of conflict resolution for a single incident's transitions.
class ConflictResolution {
  /// Non-superseded transitions in temporal order, suitable for projection
  /// rebuild.
  final List<IncidentTransition> winningTransitions;

  /// IDs of transitions that lost conflict resolution and should be marked
  /// superseded.
  final Set<String> supersededIds;

  /// Human-readable description of which tie-break level decided each
  /// conflict. Used in logs.
  final String debugResolutionPath;

  const ConflictResolution({
    required this.winningTransitions,
    required this.supersededIds,
    required this.debugResolutionPath,
  });
}

// ---------------------------------------------------------------------------
// Resolver
// ---------------------------------------------------------------------------

/// Deterministic conflict resolution for concurrent incident transitions.
///
/// When two devices transition the same incident offline, this resolver
/// applies a 5-field tie-break chain to determine a unique winner:
///
/// 1. **priorityRank** — transition type ordered highest-first:
///    escalate (5) > cancel (4) > assign (3) > resolve (2) > submit (1).
/// 2. **timestamp** — earlier epoch-ms wins.
/// 3. **actorRoleRank** — Admin (4) > Supervisor (3) > Operator (2) >
///    Observer (1).
/// 4. **actorId** — lexicographic string comparison.
/// 5. **transitionId** — UUID lexicographic comparison (final tie-breaker).
///
/// Transitions outside the 5-second conflict window are resolved purely by
/// timestamp (earlier wins).
///
/// Spec: INCIDENT_LIFECYCLE.md — Conflict Resolution section.
class IncidentConflictResolver {
  const IncidentConflictResolver();

  // -----------------------------------------------------------------------
  // Rank mappings
  // -----------------------------------------------------------------------

  /// Ranks transition types by operational priority.
  ///
  /// Higher rank wins in conflict resolution.
  ///
  /// Spec: INCIDENT_LIFECYCLE.md — escalate (5) > cancel (4) > assign (3) >
  /// resolve (2) > submit (1).
  static int transitionTypeRank(IncidentState toState) {
    return switch (toState) {
      IncidentState.escalated => 5,
      IncidentState.cancelled => 4,
      IncidentState.assigned => 3,
      IncidentState.resolved => 2,
      IncidentState.open => 1, // submit
      IncidentState.closed => 0,
      IncidentState.draft => -1,
    };
  }

  /// Ranks actor roles by authority.
  ///
  /// Higher rank wins in conflict resolution.
  static int actorRoleRank(String? roleName) {
    return switch (roleName) {
      'admin' => 4,
      'supervisor' => 3,
      'operator' => 2,
      'observer' => 1,
      _ => 0,
    };
  }

  // -----------------------------------------------------------------------
  // Comparators
  // -----------------------------------------------------------------------

  /// Pairwise comparator with window check.
  ///
  /// **Warning:** this comparator is intransitive across 3+ elements when
  /// timestamps straddle the 5-second window boundary. Safe for pairwise
  /// use only. [resolveConflicts] uses group-level window determination
  /// with [compareFullChain] / [compareByTimestamp] instead.
  ///
  /// Returns negative if [a] wins, positive if [b] wins.
  static int compare(IncidentTransition a, IncidentTransition b) {
    final tsA = a.timestamp.millisecondsSinceEpoch;
    final tsB = b.timestamp.millisecondsSinceEpoch;
    final tsDiff = (tsA - tsB).abs();

    // Outside 5-second window: earlier timestamp wins outright.
    if (tsDiff > conflictWindowMs) {
      return tsA.compareTo(tsB);
    }

    // Within 5-second window: full chain.

    // 1. priorityRank — higher wins (descending).
    final prA = transitionTypeRank(a.toState);
    final prB = transitionTypeRank(b.toState);
    if (prA != prB) return prB - prA;

    // 2. timestamp — earlier wins (ascending).
    if (tsA != tsB) return tsA.compareTo(tsB);

    // 3. actorRoleRank — higher wins (descending).
    final arA = actorRoleRank(a.actorRole);
    final arB = actorRoleRank(b.actorRole);
    if (arA != arB) return arB - arA;

    // 4. actorId — lexicographic (ascending).
    final aidCmp = a.actorId.compareTo(b.actorId);
    if (aidCmp != 0) return aidCmp;

    // 5. transitionId — lexicographic (ascending, final tie-breaker).
    return a.id.compareTo(b.id);
  }

  /// Full 5-field chain comparator (no window check). **Transitive.**
  ///
  /// Used within [resolveConflicts] for groups whose time span is within the
  /// conflict window. Priority rank is the primary sort key.
  static int compareFullChain(IncidentTransition a, IncidentTransition b) {
    // 1. priorityRank — higher wins (descending).
    final prA = transitionTypeRank(a.toState);
    final prB = transitionTypeRank(b.toState);
    if (prA != prB) return prB - prA;

    // 2. timestamp — earlier wins (ascending).
    final tsA = a.timestamp.millisecondsSinceEpoch;
    final tsB = b.timestamp.millisecondsSinceEpoch;
    if (tsA != tsB) return tsA.compareTo(tsB);

    // 3. actorRoleRank — higher wins (descending).
    final arA = actorRoleRank(a.actorRole);
    final arB = actorRoleRank(b.actorRole);
    if (arA != arB) return arB - arA;

    // 4. actorId — lexicographic (ascending).
    final aidCmp = a.actorId.compareTo(b.actorId);
    if (aidCmp != 0) return aidCmp;

    // 5. transitionId — lexicographic (ascending).
    return a.id.compareTo(b.id);
  }

  /// Timestamp-first comparator (no window check). **Transitive.**
  ///
  /// Used within [resolveConflicts] for groups whose time span exceeds the
  /// conflict window. Timestamp is the primary sort key.
  static int compareByTimestamp(IncidentTransition a, IncidentTransition b) {
    // 1. timestamp — earlier wins (ascending).
    final tsA = a.timestamp.millisecondsSinceEpoch;
    final tsB = b.timestamp.millisecondsSinceEpoch;
    if (tsA != tsB) return tsA.compareTo(tsB);

    // 2. priorityRank — higher wins (descending).
    final prA = transitionTypeRank(a.toState);
    final prB = transitionTypeRank(b.toState);
    if (prA != prB) return prB - prA;

    // 3. actorRoleRank — higher wins (descending).
    final arA = actorRoleRank(a.actorRole);
    final arB = actorRoleRank(b.actorRole);
    if (arA != arB) return arB - arA;

    // 4. actorId — lexicographic (ascending).
    final aidCmp = a.actorId.compareTo(b.actorId);
    if (aidCmp != 0) return aidCmp;

    // 5. transitionId — lexicographic (ascending).
    return a.id.compareTo(b.id);
  }

  // -----------------------------------------------------------------------
  // Resolution
  // -----------------------------------------------------------------------

  /// Resolves conflicts among a set of transitions for a single incident.
  ///
  /// Phase 1: groups transitions by `fromState`. Within each group, if
  /// multiple transitions exist, they are sorted by the deterministic chain
  /// and the winner is kept. Losers are added to [supersededIds].
  ///
  /// Phase 2: builds the reachable transition chain from `draft`. Transitions
  /// whose `fromState` is not reachable (orphaned by an upstream loss) are
  /// also superseded.
  ///
  /// Returns a [ConflictResolution] with the winning sequence (ordered by
  /// timestamp ASC, id ASC) and the set of superseded IDs.
  ConflictResolution resolveConflicts({
    required String incidentId,
    required List<IncidentTransition> transitions,
  }) {
    if (transitions.isEmpty) {
      return const ConflictResolution(
        winningTransitions: [],
        supersededIds: {},
        debugResolutionPath: '',
      );
    }

    final supersededIds = <String>{};
    final debugParts = <String>[];

    // --- Phase 1: resolve per-group conflicts ---

    final groups = <IncidentState, List<IncidentTransition>>{};
    for (final t in transitions) {
      groups.putIfAbsent(t.fromState, () => []).add(t);
    }

    for (final entry in groups.entries) {
      final group = entry.value;
      if (group.length <= 1) continue;

      // Group-level window determination: avoids intransitivity that arises
      // when the pairwise window check produces cycles across 3+ elements
      // straddling the 5-second boundary.
      //
      // If all transitions in the group fall within `conflictWindowMs` of
      // each other, use the full 5-field chain (priorityRank first).
      // Otherwise, use timestamp-first ordering.
      var minTs = group.first.timestamp.millisecondsSinceEpoch;
      var maxTs = minTs;
      for (final t in group) {
        final ts = t.timestamp.millisecondsSinceEpoch;
        if (ts < minTs) minTs = ts;
        if (ts > maxTs) maxTs = ts;
      }

      if ((maxTs - minTs) <= conflictWindowMs) {
        group.sort(compareFullChain);
      } else {
        group.sort(compareByTimestamp);
      }

      final winner = group.first;
      for (var i = 1; i < group.length; i++) {
        final loser = group[i];
        supersededIds.add(loser.id);
        debugParts.add(debugWinReason(winner, loser));
      }
    }

    // --- Phase 2: supersede orphans via chain walk ---
    //
    // Build the reachable chain from `draft` by following from→to links.
    // Any transition whose `fromState` is never reached is an orphan.
    // Uses indexed lookup (O(n)) instead of sorted iteration to avoid
    // timestamp-ordering fragility when timestamps collide.

    final remaining = transitions
        .where((t) => !supersededIds.contains(t.id))
        .toList();

    // Index by fromState. Each fromState has at most one winner after Phase 1.
    final byFromState = <IncidentState, IncidentTransition>{};
    for (final t in remaining) {
      byFromState[t.fromState] = t;
    }

    final reachableStates = {IncidentState.draft};
    final winningTransitions = <IncidentTransition>[];
    var current = IncidentState.draft;
    var steps = 0;

    while (byFromState.containsKey(current) && steps <= remaining.length) {
      final t = byFromState[current]!;
      winningTransitions.add(t);
      reachableStates.add(t.toState);
      current = t.toState;
      steps++;
    }

    // Any remaining transition not in the chain is an orphan.
    for (final t in remaining) {
      if (!reachableStates.contains(t.fromState)) {
        supersededIds.add(t.id);
        debugParts.add(
          'orphan: ${t.fromState.name}->${t.toState.name} '
          '(${t.fromState.name} unreachable)',
        );
      }
    }

    return ConflictResolution(
      winningTransitions: winningTransitions,
      supersededIds: supersededIds,
      debugResolutionPath: debugParts.join('; '),
    );
  }

  // -----------------------------------------------------------------------
  // Debug helpers
  // -----------------------------------------------------------------------

  /// Returns a human-readable string identifying which chain level decided
  /// the winner between two transitions.
  static String debugWinReason(
    IncidentTransition winner,
    IncidentTransition loser,
  ) {
    final tsW = winner.timestamp.millisecondsSinceEpoch;
    final tsL = loser.timestamp.millisecondsSinceEpoch;
    final tsDiff = (tsW - tsL).abs();

    // Outside window: pure timestamp.
    if (tsDiff > conflictWindowMs) {
      return 'timestamp(${winner.toState.name} earlier by ${tsDiff}ms) '
          '-> ${winner.toState.name} wins';
    }

    // Within window: walk the chain.
    final prW = transitionTypeRank(winner.toState);
    final prL = transitionTypeRank(loser.toState);
    if (prW != prL) {
      return 'priorityRank(${winner.toState.name}=$prW>'
          '${loser.toState.name}=$prL) '
          '-> ${winner.toState.name} wins';
    }

    final tiePrefix = 'priorityRank(tie)';

    if (tsW != tsL) {
      return '$tiePrefix -> timestamp(${winner.toState.name} earlier) '
          '-> ${winner.toState.name} wins';
    }

    final arW = actorRoleRank(winner.actorRole);
    final arL = actorRoleRank(loser.actorRole);
    if (arW != arL) {
      return '$tiePrefix -> timestamp(tie) -> '
          'actorRoleRank(${winner.actorRole}>${loser.actorRole}) '
          '-> ${winner.toState.name} wins';
    }

    if (winner.actorId != loser.actorId) {
      return '$tiePrefix -> timestamp(tie) -> actorRoleRank(tie) -> '
          'actorId(${winner.actorId}<${loser.actorId}) '
          '-> ${winner.toState.name} wins';
    }

    return '$tiePrefix -> timestamp(tie) -> actorRoleRank(tie) -> '
        'actorId(tie) -> '
        'transitionId(${winner.id}<${loser.id}) '
        '-> ${winner.toState.name} wins';
  }
}
