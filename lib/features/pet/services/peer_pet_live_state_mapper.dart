// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PeerPetLiveStateMapper — pure smoothing layer between a peer's
// presence/wire signal and the displayed live band.
//
// Design rules:
//   * No Flutter, no Riverpod, no timers — just pure functions over a
//     (current, incoming, pending, now) tuple. The owner of this class
//     (the Notifier in pet_providers.dart) is responsible for
//     scheduling a Timer when `decision.fireAt` is non-null.
//   * Asymmetric transition rules (see rules below) — the whole reason
//     this layer exists is to suppress mood thrash from noisy peer
//     observations and last-seen jitter.
//   * The `unknown` band is internal only. Mapping never emits a
//     "no-signal" label to the user — the widget layer renders nothing
//     for unknown.
//
// Transition rules (applied in order — first match wins):
//
//   Rule 0. `incoming == current` → no emit (same-band churn).
//
//   Rule 1. `incoming` is [PeerPetLiveBand.sleepy] or
//           [PeerPetLiveBand.dormant] → IMMEDIATE emit.
//           Wire-authoritative low-energy entry is never debounced.
//
//   Rule 2. `current` is sleepy/dormant AND `incoming` is not →
//           IMMEDIATE only when [PeerPresenceSignal.wireExplicitlyClearsLowEnergy]
//           is true (fresh observation, flags cleared). Otherwise
//           schedule the downgrade cooldown — exiting a wire-
//           authoritative low-energy band should not flap on stale or
//           missing wire data.
//
//   Rule 3. Upgrade to [PeerPetLiveBand.active] → IMMEDIATE. Presence
//           improvements are never debounced.
//
//   Rule 4. Other upgrades (incoming has strictly higher energy rank
//           than current, both non-sleepy/dormant) → IMMEDIATE.
//
//   Rule 5. Any other transition → COOLDOWN. Emit only after the
//           pending band has been stable for `downgradeCooldown`.
//
// Rank ladder (higher = more energetic):
//   dormant=0, sleepy=1, unknown=2, idle=3, calm=4, active=5
//
// `unknown` sits between sleepy and idle so that degrading from idle
// to unknown is treated as a downgrade (requires cooldown) and a peer
// that was sleepy doesn't "upgrade" to unknown on a brief wire gap
// (rule 5 applies, not rule 4 — rank tie would short-circuit but rank
// 1 → 2 is handled by rule 2 first).

import 'package:flutter/foundation.dart';

import '../models/peer_pet_live_state.dart';

/// Outcome of one smoothing pass. The caller is responsible for acting
/// on each field; the mapper itself is stateless.
@immutable
class PeerPetSmoothingDecision {
  /// The band to commit as the new emitted state, or null to keep the
  /// current band unchanged.
  final PeerPetLiveBand? emit;

  /// The band currently in the pending (cooldown-waiting) slot, or
  /// null to clear the pending slot.
  final PeerPetLiveBand? pendingBand;

  /// The wall-clock at which the owner should re-run smoothing to
  /// promote the pending band. Null when nothing is scheduled.
  final DateTime? fireAt;

  const PeerPetSmoothingDecision({
    required this.emit,
    required this.pendingBand,
    required this.fireAt,
  });

  /// Helper: no change, no pending, no timer.
  static const PeerPetSmoothingDecision noop = PeerPetSmoothingDecision(
    emit: null,
    pendingBand: null,
    fireAt: null,
  );

  @override
  String toString() =>
      'SmoothingDecision(emit=${emit?.name}, pending=${pendingBand?.name}, fireAt=$fireAt)';
}

class PeerPetLiveStateMapper {
  /// How long a downgrade candidate must hold its value before it is
  /// emitted. 15 seconds reads as "intentional" to a user without
  /// stranding a stale band visibly. Exposed for tests.
  final Duration downgradeCooldown;

  const PeerPetLiveStateMapper({
    this.downgradeCooldown = const Duration(seconds: 15),
  });

  // -------------------------------------------------------------------
  // Layer 1: raw band from a presence signal. Pure, no history.
  // -------------------------------------------------------------------

  /// Maps a [PeerPresenceSignal] to the instantaneous band BEFORE
  /// smoothing is applied. See `PeerPresenceSignal.wireFreshnessWindow`
  /// for why stale wire flags are ignored.
  PeerPetLiveBand resolveRaw(PeerPresenceSignal s) {
    // Stage-authoritative: once a peer's pet is dormant, it stays
    // dormant until they re-sigil. Never freshness-gated.
    if (s.isDormantOnWire) return PeerPetLiveBand.dormant;

    // Sleep is a transient flag — trust it only while the wire
    // observation is fresh. A stale "was asleep" must not pin our
    // display band for hours.
    if (s.wireFlagsAuthoritative && s.isAsleepOnWire) {
      return PeerPetLiveBand.sleepy;
    }

    // Presence freshness ladder. `unknown` catches the no-signal case
    // and the very-stale case.
    final since = s.sinceLastSeen;
    if (since == null) return PeerPetLiveBand.unknown;
    if (since < const Duration(seconds: 60)) return PeerPetLiveBand.active;
    if (since < const Duration(minutes: 5)) return PeerPetLiveBand.calm;
    if (since < const Duration(minutes: 30)) return PeerPetLiveBand.idle;
    return PeerPetLiveBand.unknown;
  }

  // -------------------------------------------------------------------
  // Layer 2: smoothing decision given current + incoming + pending.
  // -------------------------------------------------------------------

  /// Compute a decision given the current emitted band, the freshly-
  /// resolved incoming band, and the in-flight pending downgrade (if
  /// any). Pure — all state is passed in.
  ///
  /// [signal] is required so rule 2 can inspect
  /// [PeerPresenceSignal.wireExplicitlyClearsLowEnergy] for the
  /// sleepy/dormant exit escape hatch.
  PeerPetSmoothingDecision smooth({
    required PeerPetLiveBand current,
    required PeerPetLiveBand incoming,
    required PeerPetLiveBand? pendingBand,
    required DateTime? pendingSince,
    required PeerPresenceSignal signal,
    required DateTime now,
  }) {
    // Rule 0: same-band churn. Clear any pending so we don't fire a
    // stale timer later.
    if (incoming == current) {
      return const PeerPetSmoothingDecision(
        emit: null,
        pendingBand: null,
        fireAt: null,
      );
    }

    // Rule 1: wire-authoritative low-energy entry is immediate.
    if (incoming == PeerPetLiveBand.sleepy ||
        incoming == PeerPetLiveBand.dormant) {
      return PeerPetSmoothingDecision(
        emit: incoming,
        pendingBand: null,
        fireAt: null,
      );
    }

    // Rule 2: exiting sleepy/dormant requires stable evidence, UNLESS
    // the wire state freshly and explicitly clears the low-energy flags.
    final exitingLowEnergy =
        current == PeerPetLiveBand.sleepy || current == PeerPetLiveBand.dormant;
    if (exitingLowEnergy) {
      if (signal.wireExplicitlyClearsLowEnergy) {
        return PeerPetSmoothingDecision(
          emit: incoming,
          pendingBand: null,
          fireAt: null,
        );
      }
      return _scheduleOrHold(
        incoming: incoming,
        pendingBand: pendingBand,
        pendingSince: pendingSince,
        now: now,
      );
    }

    // Rule 3: upgrading to active is always immediate.
    if (incoming == PeerPetLiveBand.active) {
      return PeerPetSmoothingDecision(
        emit: incoming,
        pendingBand: null,
        fireAt: null,
      );
    }

    // Rule 4: other upgrades (strictly higher rank).
    if (_rank(incoming) > _rank(current)) {
      return PeerPetSmoothingDecision(
        emit: incoming,
        pendingBand: null,
        fireAt: null,
      );
    }

    // Rule 5: downgrades and lateral-to-unknown go through cooldown.
    return _scheduleOrHold(
      incoming: incoming,
      pendingBand: pendingBand,
      pendingSince: pendingSince,
      now: now,
    );
  }

  /// Shared cooldown logic: if we already have this pending band and
  /// it has held long enough, emit it; if it's a new pending band,
  /// start a fresh clock; if the pending band changed to something
  /// other than incoming, treat as "new pending" so timers never
  /// accumulate.
  PeerPetSmoothingDecision _scheduleOrHold({
    required PeerPetLiveBand incoming,
    required PeerPetLiveBand? pendingBand,
    required DateTime? pendingSince,
    required DateTime now,
  }) {
    if (pendingBand == incoming && pendingSince != null) {
      final heldFor = now.difference(pendingSince);
      if (heldFor >= downgradeCooldown) {
        return PeerPetSmoothingDecision(
          emit: incoming,
          pendingBand: null,
          fireAt: null,
        );
      }
      // Keep waiting — re-emit the existing pending schedule so the
      // caller doesn't start a second timer.
      return PeerPetSmoothingDecision(
        emit: null,
        pendingBand: incoming,
        fireAt: pendingSince.add(downgradeCooldown),
      );
    }
    // New pending candidate (either fresh or replacing a different one).
    // The caller MUST cancel any existing timer before scheduling a
    // new one — the mapper is stateless and cannot enforce that, so
    // see PeerPetLiveStateController in pet_providers.dart for the
    // timer-cancellation discipline.
    return PeerPetSmoothingDecision(
      emit: null,
      pendingBand: incoming,
      fireAt: now.add(downgradeCooldown),
    );
  }

  /// Energy rank. Only used for rule 4; rules 1-3 and 5 don't depend
  /// on it. `unknown` sits between sleepy and idle so "peer went
  /// silent" is a downgrade from idle (rule 5) but not an upgrade
  /// from sleepy (rule 2 handles that case first).
  static int _rank(PeerPetLiveBand b) {
    switch (b) {
      case PeerPetLiveBand.dormant:
        return 0;
      case PeerPetLiveBand.sleepy:
        return 1;
      case PeerPetLiveBand.unknown:
        return 2;
      case PeerPetLiveBand.idle:
        return 3;
      case PeerPetLiveBand.calm:
        return 4;
      case PeerPetLiveBand.active:
        return 5;
    }
  }
}
