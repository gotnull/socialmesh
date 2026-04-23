// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Explicit outcome layer for owner pet actions. Every action resolves to
// one of the four outcome classes below; the UI consumes this to give
// immediate feedback even when stats don't change.

import 'package:flutter/foundation.dart';

import 'pet_enums.dart';
import 'pet_state.dart';

enum PetActionOutcome {
  /// The action changed state in a meaningful way. The state change
  /// itself is the feedback; no toast needed.
  applied,

  /// The action was valid but redundant because a stat is already at its
  /// ceiling (e.g. Charge when energy is already full).
  capped,

  /// The action is valid in principle but there's nothing to act on
  /// (e.g. Sync with no active call, Stabilise with no artefact).
  notNeeded,

  /// The action cannot be performed in the pet's current state (e.g.
  /// Charge while asleep, ReSigil while still alive). The corresponding
  /// button should generally be hidden or disabled so this outcome is
  /// rarely surfaced — but it exists so the engine can safely refuse
  /// any tap.
  invalidInState,
}

/// A machine-readable reason attached to non-[PetActionOutcome.applied]
/// outcomes. Maps to l10n keys in the UI layer.
enum PetActionReason {
  // Capped — a stat hit its ceiling.
  fullyCharged,
  moodAlreadyFull,
  stabilityAlreadyFull,

  // Not needed — no pending work for this action.
  nothingToClean,
  nothingToSync,
  alreadyAsleep,

  // Invalid — the pet's state forbids this action.
  asleep,
  egg,
  dormant,
  notSick,
  notBedtime,
  notDormant,
}

@immutable
class PetActionResult {
  final PetState state;
  final CareAction action;
  final PetActionOutcome outcome;
  final PetActionReason? reason;

  const PetActionResult({
    required this.state,
    required this.action,
    required this.outcome,
    this.reason,
  });

  factory PetActionResult.applied({
    required PetState state,
    required CareAction action,
  }) => PetActionResult(
    state: state,
    action: action,
    outcome: PetActionOutcome.applied,
  );

  factory PetActionResult.capped({
    required PetState state,
    required CareAction action,
    required PetActionReason reason,
  }) => PetActionResult(
    state: state,
    action: action,
    outcome: PetActionOutcome.capped,
    reason: reason,
  );

  factory PetActionResult.notNeeded({
    required PetState state,
    required CareAction action,
    required PetActionReason reason,
  }) => PetActionResult(
    state: state,
    action: action,
    outcome: PetActionOutcome.notNeeded,
    reason: reason,
  );

  factory PetActionResult.invalidInState({
    required PetState state,
    required CareAction action,
    required PetActionReason reason,
  }) => PetActionResult(
    state: state,
    action: action,
    outcome: PetActionOutcome.invalidInState,
    reason: reason,
  );

  bool get isApplied => outcome == PetActionOutcome.applied;
  bool get isNoOp => outcome != PetActionOutcome.applied;
}
