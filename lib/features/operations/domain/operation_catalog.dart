// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Static catalog of SocialMesh operations.
//
// Each entry must be derivable from observed app state today. Operations
// that depend on signals not yet reliably exposed by the rest of the app
// stay in `_deferred` with `enabled: false` so the UI omits them and the
// engine refuses to advance them. They're documented in code instead of
// pretending to work.

import '../models/operation_models.dart';

/// Catalog identifiers. Public so tests, logs, and reward consumers can
/// reference them without string-typing.
abstract final class OperationIds {
  static const firstContact = 'first_contact';
  static const signalHunter = 'signal_hunter';
  static const pathfinder = 'pathfinder';

  // Deferred — present in catalog, disabled.
  static const longRangeObserver = 'long_range_observer';
  static const nightWatch = 'night_watch';
  static const multiHopObserver = 'multi_hop_observer';
  static const mapCoverage = 'map_coverage';
}

/// Returns the full catalog, including disabled / deferred entries. The
/// UI filters by `enabled` and `isActiveAt(now)`; the engine refuses to
/// advance progress for any operation whose definition is disabled.
List<OperationDefinition> buildOperationCatalog() {
  return List<OperationDefinition>.unmodifiable([..._enabled, ..._deferred]);
}

const List<OperationDefinition> _enabled = [
  OperationDefinition(
    id: OperationIds.firstContact,
    titleKey: 'operationFirstContactTitle',
    descriptionKey: 'operationFirstContactDescription',
    category: OperationCategory.discovery,
    objectives: [
      OperationObjective(
        id: 'encounter_one',
        titleKey: 'operationFirstContactObjective',
        kind: OperationObjectiveKind.uniqueNodeEncounter,
        target: 1,
      ),
    ],
    rewards: [
      OperationReward(
        kind: OperationRewardKind.badge,
        value: 'first_contact_badge',
        labelKey: 'operationFirstContactRewardLabel',
      ),
    ],
  ),
  OperationDefinition(
    id: OperationIds.signalHunter,
    titleKey: 'operationSignalHunterTitle',
    descriptionKey: 'operationSignalHunterDescription',
    category: OperationCategory.discovery,
    objectives: [
      OperationObjective(
        id: 'encounter_ten',
        titleKey: 'operationSignalHunterObjective',
        kind: OperationObjectiveKind.uniqueNodeEncounter,
        target: 10,
      ),
    ],
    rewards: [
      OperationReward(
        kind: OperationRewardKind.patch,
        value: 'signal_hunter_patch',
        labelKey: 'operationSignalHunterRewardLabel',
      ),
    ],
  ),
  OperationDefinition(
    id: OperationIds.pathfinder,
    titleKey: 'operationPathfinderTitle',
    descriptionKey: 'operationPathfinderDescription',
    category: OperationCategory.connectivity,
    objectives: [
      OperationObjective(
        id: 'traceroute_one',
        titleKey: 'operationPathfinderObjective',
        kind: OperationObjectiveKind.tracerouteSuccess,
        target: 1,
      ),
    ],
    rewards: [
      OperationReward(
        kind: OperationRewardKind.title,
        value: 'pathfinder_title',
        labelKey: 'operationPathfinderRewardLabel',
      ),
    ],
  ),
];

// Deferred catalog. These are intentionally `enabled: false` because the
// observed signals are not reliable in the app today. They are listed here
// (rather than dropped) so future phases can flip the flag without
// touching consumers, and so the engine has an authoritative "do not
// progress" decision rather than silently treating an unknown id.
//
// Future phases that want to enable these MUST first wire a reliable
// event source upstream and add the matching `OperationsEvent` subtype +
// engine handler. Flipping `enabled: true` without the wiring would
// silently leave the operation impossible to complete.
const List<OperationDefinition> _deferred = [
  OperationDefinition(
    id: OperationIds.longRangeObserver,
    titleKey: 'operationLongRangeObserverTitle',
    descriptionKey: 'operationLongRangeObserverDescription',
    category: OperationCategory.coverage,
    objectives: [
      OperationObjective(
        id: 'long_range_one',
        titleKey: 'operationLongRangeObserverObjective',
        kind: OperationObjectiveKind.uniqueNodeEncounter,
        target: 1,
      ),
    ],
    rewards: [],
    enabled: false,
  ),
  OperationDefinition(
    id: OperationIds.nightWatch,
    titleKey: 'operationNightWatchTitle',
    descriptionKey: 'operationNightWatchDescription',
    category: OperationCategory.endurance,
    objectives: [
      OperationObjective(
        id: 'connection_window',
        titleKey: 'operationNightWatchObjective',
        kind: OperationObjectiveKind.uniqueNodeEncounter,
        target: 1,
      ),
    ],
    rewards: [],
    enabled: false,
  ),
  OperationDefinition(
    id: OperationIds.multiHopObserver,
    titleKey: 'operationMultiHopObserverTitle',
    descriptionKey: 'operationMultiHopObserverDescription',
    category: OperationCategory.connectivity,
    objectives: [
      OperationObjective(
        id: 'multi_hop_one',
        titleKey: 'operationMultiHopObserverObjective',
        kind: OperationObjectiveKind.multiHopObserved,
        target: 1,
        params: {'minHopCount': 2},
      ),
    ],
    rewards: [],
    enabled: false,
  ),
  OperationDefinition(
    id: OperationIds.mapCoverage,
    titleKey: 'operationMapCoverageTitle',
    descriptionKey: 'operationMapCoverageDescription',
    category: OperationCategory.coverage,
    objectives: [
      OperationObjective(
        id: 'map_cells',
        titleKey: 'operationMapCoverageObjective',
        kind: OperationObjectiveKind.uniqueNodeEncounter,
        target: 1,
      ),
    ],
    rewards: [],
    enabled: false,
  ),
];
