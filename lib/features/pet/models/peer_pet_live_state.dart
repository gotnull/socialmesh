// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Peer pet live-state layering.
//
// Three explicit layers separate concerns so the display band is
// deterministic, testable, and resistant to noisy wire updates:
//
//   1. [PeerPetRawObservation] — thin wrapper over the decoded wire
//      public state and its observedAt timestamp. Never touched by UI
//      directly; exists so the freshness signal can be extracted
//      without coupling to the cache row shape.
//
//   2. [PeerPresenceSignal] — the inputs to the mapping function.
//      Purely durations + booleans; no Flutter, no Riverpod. This is
//      what the smoothing layer reasons about.
//
//   3. [PeerPetLiveState] — the smoothed, display-ready band. Equal-
//      by-value so `.select`-style consumers short-circuit on no-op
//      emissions. Never persisted; recomputed from the two inputs
//      above whenever either changes.
//
// See peer_pet_live_state_mapper.dart for the rules that map layer 2
// onto layer 3.

import 'package:flutter/foundation.dart';

import 'pet_public_state.dart';

/// Thin wrapper over a decoded peer pet observation. Kept separate so
/// the mapper doesn't have to import the cache row type.
@immutable
class PeerPetRawObservation {
  final PetPublicState state;
  final DateTime observedAt;

  const PeerPetRawObservation({required this.state, required this.observedAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerPetRawObservation &&
          state == other.state &&
          observedAt == other.observedAt;

  @override
  int get hashCode => Object.hash(state, observedAt);
}

/// Inputs to the live-state mapper. Purely numeric / boolean — no Flutter,
/// no Riverpod. Derived once per mapping pass from the raw observation
/// and the peer's last-seen timestamp.
@immutable
class PeerPresenceSignal {
  /// How long since the peer's mesh presence was last observed. Null
  /// when the peer has never been seen (e.g. cache-only observation
  /// without a node table entry).
  final Duration? sinceLastSeen;

  /// How long since the pet wire observation was decoded. Null when no
  /// observation exists at all.
  final Duration? sinceObserved;

  final bool isAsleepOnWire;
  final bool isDormantOnWire;

  const PeerPresenceSignal({
    required this.sinceLastSeen,
    required this.sinceObserved,
    required this.isAsleepOnWire,
    required this.isDormantOnWire,
  });

  /// Empty signal — no observation, no last-seen. Resolves to [PeerPetLiveBand.unknown].
  static const PeerPresenceSignal absent = PeerPresenceSignal(
    sinceLastSeen: null,
    sinceObserved: null,
    isAsleepOnWire: false,
    isDormantOnWire: false,
  );

  /// True when the pet wire observation is fresh enough that its
  /// boolean flags carry authority. Stale observations' flags are
  /// ignored (the peer may have changed state since). 30 minutes
  /// matches the idle→unknown freshness boundary so a peer whose last
  /// pet update was long ago is never pinned to `sleepy` by a stale
  /// flag.
  static const Duration wireFreshnessWindow = Duration(minutes: 30);

  /// The "wire explicitly clears it" escape hatch from the exit rule
  /// for sleepy/dormant (see mapper rule 2). True only when we have a
  /// VERY fresh observation where both low-energy flags are clear —
  /// i.e. the peer has recently, explicitly said "awake and lively."
  static const Duration wireExplicitClearanceWindow = Duration(seconds: 10);

  bool get wireFlagsAuthoritative =>
      sinceObserved != null && sinceObserved! <= wireFreshnessWindow;

  bool get wireExplicitlyClearsLowEnergy =>
      sinceObserved != null &&
      sinceObserved! <= wireExplicitClearanceWindow &&
      !isAsleepOnWire &&
      !isDormantOnWire;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerPresenceSignal &&
          sinceLastSeen == other.sinceLastSeen &&
          sinceObserved == other.sinceObserved &&
          isAsleepOnWire == other.isAsleepOnWire &&
          isDormantOnWire == other.isDormantOnWire;

  @override
  int get hashCode => Object.hash(
    sinceLastSeen,
    sinceObserved,
    isAsleepOnWire,
    isDormantOnWire,
  );
}

/// The smoothed, display-ready band for a peer.
///
/// Priority ladder (high → low energy):
///   active > calm > idle > sleepy > dormant
///
/// [unknown] sits outside the ladder — it means "no signal." The UI
/// renders no band line for [unknown]; do NOT surface it as a
/// user-facing label. The internal representation is preserved so
/// mapper logic can treat "band we chose to show nothing" distinctly
/// from "a definite idle band."
enum PeerPetLiveBand { active, calm, idle, sleepy, dormant, unknown }

/// Smoothed band + when it was emitted. Kept tiny and equal-by-value
/// so consumers with `.select` avoid rebuilds on identical emissions.
@immutable
class PeerPetLiveState {
  final PeerPetLiveBand band;
  final DateTime emittedAt;

  const PeerPetLiveState({required this.band, required this.emittedAt});

  /// Initial state for a freshly-mounted peer — unknown, no emission yet.
  factory PeerPetLiveState.initial(DateTime now) =>
      PeerPetLiveState(band: PeerPetLiveBand.unknown, emittedAt: now);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerPetLiveState &&
          band == other.band &&
          emittedAt == other.emittedAt;

  @override
  int get hashCode => Object.hash(band, emittedAt);

  @override
  String toString() => 'PeerPetLiveState(${band.name} @ $emittedAt)';
}
