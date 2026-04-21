// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetConfig — tunable cadences and thresholds. Immutable; swap instances for
// production vs. testing profiles. Remote-Config may override these at runtime
// in a later phase; v1 ships with the production profile only.

import 'package:flutter/foundation.dart';

@immutable
class PetConfig {
  // ---- Stat bounds ------------------------------------------------------
  final int statMax;
  final int statMin;

  // ---- Tick cadence -----------------------------------------------------
  /// Real-time duration of one care tick. Decay is expressed in pips per tick.
  final Duration careTickDuration;

  /// Foreground animation cadence — drives visual breathing/pulse, not stats.
  final Duration foregroundAnimationTick;

  // ---- Decay rates (pips per care tick) ---------------------------------
  final int energyDecayPerTick;
  final int moodDecayPerTick;
  final int stabilityDecayPerTick;

  // ---- Sleep window -----------------------------------------------------
  /// Hour of day (0-23) at which the sleep window opens.
  final int sleepWindowStartHour;

  /// Hour of day (0-23) at which the sleep window closes.
  final int sleepWindowEndHour;

  /// Grace period after sleep window opens before missing Dim counts as a
  /// care mistake.
  final Duration sleepDimGracePeriod;

  // ---- Attention calls --------------------------------------------------
  /// Stat threshold (inclusive) at or below which a call may trigger.
  final int callTriggerStatThreshold;

  /// Window to answer a call before it counts as a missed-call mistake.
  final Duration callAnswerDeadline;

  // ---- Sickness ---------------------------------------------------------
  /// Instability level (inclusive) at or above which sickness may onset.
  final int sicknessInstabilityThreshold;

  /// Each Surge bumps instability by this much.
  final int instabilityPerSurge;

  /// Hygiene artefacts this old (or older) are considered "stale" and
  /// contribute to sickness risk.
  final Duration hygieneStaleAfter;

  /// Minimum stale artefacts on field for the sickness check to fire.
  final int hygieneSicknessThreshold;

  /// Maximum hygiene artefacts visible on the field at once.
  final int hygieneMaxOnField;

  // ---- Hygiene spawn cadence -------------------------------------------
  /// Average real-time interval between hygiene artefact spawns during
  /// wake time.
  final Duration hygieneSpawnInterval;

  // ---- Catch-up model ---------------------------------------------------
  /// Above this gap length, catch-up switches from exact simulation to the
  /// bounded neglect projection.
  final Duration exactCatchUpMaxGap;

  /// During bounded projection, minimum floor that any stat can reach.
  /// Ensures the pet can always be recovered with active care.
  final int neglectFloorStat;

  /// Max care-mistakes that a single neglect projection can add, regardless
  /// of gap length. Prevents a 3-month absence from skipping past recovery.
  final int neglectMistakeCap;

  // ---- Stage durations --------------------------------------------------
  final Duration eggDuration;
  final Duration juvenileDuration;
  final Duration adolescentDuration;
  final Duration adultDuration;
  final Duration elderDuration;
  // Dormant is indefinite; no duration.

  // ---- Evolution thresholds (evaluated at adolescent → adult) -----------
  final int luminousMaxMistakes;
  final double luminousMinAttentionScore;
  final int steadyMaxMistakes;
  final int volatileMinSurges;

  // ---- Mesh publication -------------------------------------------------
  /// Minimum interval between heartbeat publishes. Events override.
  final Duration meshHeartbeatInterval;

  /// Minimum interval between mood-class pushes.
  final Duration moodPushMinInterval;

  /// How long a new mood class must be stable before it can be pushed.
  final Duration moodPushDebounce;

  /// Age (0..255) cap for the public state's ageInDays byte.
  final int publicAgeDaysMax;

  // ---- Recent events ring buffer ---------------------------------------
  final int recentEventsCapacity;

  const PetConfig({
    this.statMax = 10,
    this.statMin = 0,
    this.careTickDuration = const Duration(minutes: 30),
    this.foregroundAnimationTick = const Duration(seconds: 10),
    this.energyDecayPerTick = 1,
    this.moodDecayPerTick = 1,
    this.stabilityDecayPerTick = 1,
    this.sleepWindowStartHour = 22,
    this.sleepWindowEndHour = 7,
    this.sleepDimGracePeriod = const Duration(minutes: 15),
    this.callTriggerStatThreshold = 3,
    this.callAnswerDeadline = const Duration(hours: 2),
    this.sicknessInstabilityThreshold = 7,
    this.instabilityPerSurge = 2,
    this.hygieneStaleAfter = const Duration(hours: 2),
    this.hygieneSicknessThreshold = 2,
    this.hygieneMaxOnField = 3,
    this.hygieneSpawnInterval = const Duration(hours: 5),
    this.exactCatchUpMaxGap = const Duration(hours: 24),
    this.neglectFloorStat = 1,
    this.neglectMistakeCap = 6,
    this.eggDuration = const Duration(minutes: 10),
    this.juvenileDuration = const Duration(days: 2),
    this.adolescentDuration = const Duration(days: 4),
    this.adultDuration = const Duration(days: 12),
    this.elderDuration = const Duration(days: 7),
    this.luminousMaxMistakes = 2,
    this.luminousMinAttentionScore = 0.7,
    this.steadyMaxMistakes = 5,
    this.volatileMinSurges = 8,
    this.meshHeartbeatInterval = const Duration(hours: 8),
    this.moodPushMinInterval = const Duration(hours: 1),
    this.moodPushDebounce = const Duration(minutes: 15),
    this.publicAgeDaysMax = 255,
    this.recentEventsCapacity = 24,
  });

  /// Short-cycle configuration for tests and internal dogfooding. ~11 days.
  const PetConfig.testing()
    : this(
        careTickDuration: const Duration(minutes: 30),
        eggDuration: const Duration(seconds: 30),
        juvenileDuration: const Duration(days: 1),
        adolescentDuration: const Duration(days: 2),
        adultDuration: const Duration(days: 5),
        elderDuration: const Duration(days: 3),
      );

  /// Total duration from hatch to the start of dormant.
  Duration get productiveLifespan =>
      eggDuration +
      juvenileDuration +
      adolescentDuration +
      adultDuration +
      elderDuration;
}
