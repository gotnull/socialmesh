// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetAdvisory — the single highest-priority "what should the user do
// right now?" signal, derived purely from [PetState] + [PetConfig].
//
// Why this exists
// ---------------
// The pet-home care loop was not discoverable: stats decayed silently,
// hygiene artefacts appeared as cryptic specks, the Stabilise button
// materialised without explanation, and nothing told a first-time user
// that "hungry" means "tap Charge." This model is the glue that lets
// the UI speak plain language: one advisory per frame, action name
// included, priority-sorted so the user always sees the one thing that
// matters most.
//
// Purity
// ------
// No Flutter, no Riverpod, no DateTime.now() — takes `now` explicitly.
// This keeps the derivation fully unit-testable and deterministic.

import 'package:flutter/foundation.dart';

import 'pet_config.dart';
import 'pet_enums.dart';
import 'pet_state.dart';

/// The urgency band an advisory falls into. The UI colours and
/// positions the status line based on this, independent of the
/// specific need.
enum PetAdvisoryLevel {
  /// Nothing to do. "Thriving" / "Resting".
  calm,

  /// Mild nudge. Small mess, slight passive mood dip.
  info,

  /// Should act soon. Low energy/mood without an active call.
  warn,

  /// Act now. Active call or sickness or imminent-sickness.
  urgent,

  /// Terminal or pre-hatch state. Not actionable in the normal sense.
  stage,
}

/// Which action the advisory suggests the user tap. The UI uses this
/// to (a) bold the action name in the status message, (b) pulse the
/// matching button, and (c) scroll/highlight the button into view if
/// needed. `null` = no suggested action (thriving, resting, egg).
enum PetAdvisoryAction { charge, resonate, stabilise, purge, dim, reSigil }

/// A single primary-need advisory. Equal-by-value so consumers can
/// `.select` on this without rebuilding every frame.
@immutable
class PetAdvisory {
  /// The canonical "kind" of this advisory — drives message + icon.
  /// Kept as an explicit enum rather than inferred from fields so the
  /// UI layer doesn't have to reason about priority.
  final PetAdvisoryKind kind;
  final PetAdvisoryLevel level;
  final PetAdvisoryAction? action;

  const PetAdvisory({required this.kind, required this.level, this.action});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetAdvisory &&
          kind == other.kind &&
          level == other.level &&
          action == other.action;

  @override
  int get hashCode => Object.hash(kind, level, action);

  @override
  String toString() =>
      'PetAdvisory(${kind.name}, ${level.name}, action=${action?.name})';
}

/// The canonical set of need-states. Wire this through l10n for
/// messages and through the icon table in the widget layer.
enum PetAdvisoryKind {
  dormant,
  egg,
  sick,
  callHungry,
  callLonely,
  callSick,
  callHygiene,
  callBedtime,
  callBoredom,
  hygieneImminent, // artefacts ≥ sickness threshold but not yet sick
  energyLow,
  moodLow,
  hygieneMild, // artefacts ≥ 1 but below sickness threshold
  resting, // asleep
  bedtime, // in sleep window, not yet asleep
  thriving,
}

/// Compute the single most-urgent advisory for the given state. Pure.
///
/// Priority (top wins):
///   1. dormant          → stage advisory (reSigil)
///   2. egg              → stage advisory (no action)
///   3. sick             → urgent, Purge
///   4. active call      → urgent, action by reason
///   5. hygieneImminent  → urgent, Stabilise
///   6. energyLow        → warn, Charge
///   7. moodLow          → warn, Resonate
///   8. hygieneMild      → info, Stabilise
///   9. asleep           → calm (no action)
///  10. bedtime          → info, Dim
///  11. thriving         → calm (no action)
PetAdvisory computePrimaryAdvisory({
  required PetState state,
  required PetConfig config,
  required bool inSleepWindow,
}) {
  // Stage-driven terminals first — these override even sickness because
  // you can't purge a dormant pet or feed an egg.
  if (state.stage == PetStage.dormant) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.dormant,
      level: PetAdvisoryLevel.stage,
      action: PetAdvisoryAction.reSigil,
    );
  }
  if (state.stage == PetStage.egg) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.egg,
      level: PetAdvisoryLevel.stage,
    );
  }

  // Sickness is the most-urgent live state — the pet is actively harmed.
  if (state.isSick) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.sick,
      level: PetAdvisoryLevel.urgent,
      action: PetAdvisoryAction.purge,
    );
  }

  // Active attention call — the pet is actively beeping. Surface the
  // reason-specific action so "tap Sync" is never the primary hint
  // (Sync just silences the beep; the underlying need has its own
  // action). This mirrors the care-engine philosophy that each need
  // has a dedicated action.
  final call = state.activeCall;
  if (call != null) {
    switch (call.reason) {
      case CallReason.hungry:
        return const PetAdvisory(
          kind: PetAdvisoryKind.callHungry,
          level: PetAdvisoryLevel.urgent,
          action: PetAdvisoryAction.charge,
        );
      case CallReason.lonely:
        return const PetAdvisory(
          kind: PetAdvisoryKind.callLonely,
          level: PetAdvisoryLevel.urgent,
          action: PetAdvisoryAction.resonate,
        );
      case CallReason.sick:
        return const PetAdvisory(
          kind: PetAdvisoryKind.callSick,
          level: PetAdvisoryLevel.urgent,
          action: PetAdvisoryAction.purge,
        );
      case CallReason.hygiene:
        return const PetAdvisory(
          kind: PetAdvisoryKind.callHygiene,
          level: PetAdvisoryLevel.urgent,
          action: PetAdvisoryAction.stabilise,
        );
      case CallReason.bedtime:
        return const PetAdvisory(
          kind: PetAdvisoryKind.callBedtime,
          level: PetAdvisoryLevel.urgent,
          action: PetAdvisoryAction.dim,
        );
      case CallReason.boredom:
        return const PetAdvisory(
          kind: PetAdvisoryKind.callBoredom,
          level: PetAdvisoryLevel.urgent,
          action: PetAdvisoryAction.resonate,
        );
    }
  }

  // Hygiene imminent sickness — artefacts at the sickness threshold.
  // Surfaces BEFORE passive low-stat nudges because the consequence
  // (sickness) is a bigger state change than a mood dip.
  if (state.hygieneArtefacts.length >= config.hygieneSicknessThreshold) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.hygieneImminent,
      level: PetAdvisoryLevel.urgent,
      action: PetAdvisoryAction.stabilise,
    );
  }

  // Passive low-stat warnings — nudge before a call fires.
  if (state.energy <= config.callTriggerStatThreshold) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.energyLow,
      level: PetAdvisoryLevel.warn,
      action: PetAdvisoryAction.charge,
    );
  }
  if (state.mood <= config.callTriggerStatThreshold) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.moodLow,
      level: PetAdvisoryLevel.warn,
      action: PetAdvisoryAction.resonate,
    );
  }

  // Mild mess — single artefact, no urgency.
  if (state.hygieneArtefacts.isNotEmpty) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.hygieneMild,
      level: PetAdvisoryLevel.info,
      action: PetAdvisoryAction.stabilise,
    );
  }

  // Asleep: the engine handles rest; nothing to do.
  if (state.isAsleep) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.resting,
      level: PetAdvisoryLevel.calm,
    );
  }

  // Bedtime hint — pet is awake but inside the sleep window.
  if (inSleepWindow) {
    return const PetAdvisory(
      kind: PetAdvisoryKind.bedtime,
      level: PetAdvisoryLevel.info,
      action: PetAdvisoryAction.dim,
    );
  }

  // Nothing needed.
  return const PetAdvisory(
    kind: PetAdvisoryKind.thriving,
    level: PetAdvisoryLevel.calm,
  );
}
