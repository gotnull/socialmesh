// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetCareEngine — pure state-transition functions for the pet care loop.
//
// Key invariants:
// - Every public method returns a fresh PetState; the input is never mutated.
// - No IO, no timers, no DateTime.now() — every time-dependent call takes
//   [now] explicitly. This is what makes the engine trivially testable and
//   deterministic.
// - Clamping is applied here so state-layer code can trust the bounds.
// - Catch-up has two modes: exact (gap ≤ exactCatchUpMaxGap) and bounded
//   neglect projection (gap > exactCatchUpMaxGap). The invariant is that
//   no single catch-up can make the pet unrecoverable.

import 'dart:math' as math;

import '../models/attention_call.dart';
import '../models/care_accumulators.dart';
import '../models/care_event.dart';
import '../models/pet_action_result.dart';
import '../models/pet_config.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import 'pet_evolution_engine.dart';

class PetCareEngine {
  final PetConfig config;
  final PetEvolutionEngine evolution;

  PetCareEngine({required this.config})
    : evolution = PetEvolutionEngine(config: config);

  // ---- Time helpers -----------------------------------------------------

  /// True iff [at] is inside the sleep window configured on [config].
  bool isInSleepWindow(DateTime at) {
    final h = at.hour;
    final start = config.sleepWindowStartHour;
    final end = config.sleepWindowEndHour;
    if (start == end) return false;
    if (start < end) {
      return h >= start && h < end;
    }
    // Wraps midnight (22 → 7).
    return h >= start || h < end;
  }

  /// Mood class derived from current state. Drives the public state's
  /// `mood` field and the renderer's animation posture.
  PetMood deriveMood(PetState s) {
    if (s.stage == PetStage.dormant) return PetMood.content;
    if (s.isAsleep) return PetMood.sleeping;
    if (s.activeCall != null) return PetMood.calling;
    if (s.isSick) return PetMood.sick;
    if (s.energy <= config.callTriggerStatThreshold) return PetMood.hungry;
    if (s.mood <= config.callTriggerStatThreshold) return PetMood.sad;
    return PetMood.content;
  }

  // ---- Top-level advancement -------------------------------------------

  /// Advance [state] forward to [now]. Applies decay, hygiene spawns, sleep
  /// transitions, sickness, call lifecycle, and stage transitions.
  ///
  /// Chooses exact or bounded mode based on gap. Idempotent when gap ≤ 0.
  PetState advanceTo(PetState state, DateTime now) {
    final gap = now.difference(state.lastTickAt);
    if (gap <= Duration.zero) return state;

    if (gap <= config.exactCatchUpMaxGap) {
      return _advanceExact(state, now);
    }
    // Exact for the first window, bounded for the rest.
    final cutOver = state.lastTickAt.add(config.exactCatchUpMaxGap);
    var s = _advanceExact(state, cutOver);
    s = _advanceBounded(s, now);
    return s;
  }

  // ---- Exact-simulation mode -------------------------------------------
  //
  // Stage transitions are time-exact: each stage has a configured duration
  // and fires at `stageStartedAt + duration`, independent of the 30-minute
  // care-tick cadence. Care ticks only drive decay, hygiene spawns,
  // sickness, and call lifecycle — the care-loop rhythm. To honour both
  // rhythms at once we interleave the two event streams in chronological
  // order, firing whichever boundary comes first each iteration.

  PetState _advanceExact(PetState state, DateTime now) {
    var s = state;
    while (true) {
      final nextCareTick = s.lastTickAt.add(config.careTickDuration);
      final nextStageAt = _nextStageBoundaryAt(s);
      final tickDue = !nextCareTick.isAfter(now);
      final stageDue = nextStageAt != null && !nextStageAt.isAfter(now);

      if (!tickDue && !stageDue) break;

      // Pick the earlier event. If tied, fire the stage transition first
      // so the new stage governs anything the care tick might do.
      final fireStage =
          stageDue && (!tickDue || !nextStageAt.isAfter(nextCareTick));

      if (fireStage) {
        // Flush time-only effects up to the transition instant, then
        // advance the stage. lastTickAt jumps to the transition moment.
        s = _applyTimeOnlyTransitions(s, nextStageAt);
        s = s.copyWith(lastTickAt: nextStageAt);
        s = _applyStageTransition(s, nextStageAt);
      } else {
        s = _applyCareTick(s, nextCareTick);
      }
    }

    // Partial sub-tick between the last event and now — lets sleep/wake
    // edge transitions and call expiry fire even when no full care tick
    // or stage boundary was crossed.
    if (now.isAfter(s.lastTickAt)) {
      s = _applyTimeOnlyTransitions(s, now);
      s = s.copyWith(lastTickAt: now);
    }
    return s;
  }

  /// The instant at which [s] will next cross a stage boundary, or null
  /// if [s] is in a terminal stage (dormant).
  DateTime? _nextStageBoundaryAt(PetState s) {
    final duration = evolution.durationFor(s.stage);
    if (duration == null) return null;
    return s.stageStartedAt.add(duration);
  }

  PetState _applyCareTick(PetState s, DateTime tickTime) {
    var next = s;
    next = _applyTimeOnlyTransitions(next, tickTime);

    // Stat decay — pet still decays during sleep but slower; when asleep,
    // only energy drifts. This matches Gen1 "pet rests but still gets
    // hungry eventually".
    if (!next.isAsleep) {
      next = next.copyWith(
        energy: _clampStat(next.energy - config.energyDecayPerTick),
        mood: _clampStat(next.mood - config.moodDecayPerTick),
        stability: _clampStat(next.stability - config.stabilityDecayPerTick),
      );
    } else {
      // Halved decay on energy during sleep.
      final halfEnergyDecay = math.max(0, config.energyDecayPerTick ~/ 2);
      next = next.copyWith(energy: _clampStat(next.energy - halfEnergyDecay));
    }

    // Probabilistic hygiene spawn during wake. Deterministic PRNG seeded on
    // (dnaSeed, tickTime) keeps the engine pure.
    if (!next.isAsleep &&
        next.hygieneArtefacts.length < config.hygieneMaxOnField) {
      final tickMinutes = config.careTickDuration.inMinutes;
      final spawnMinutes = config.hygieneSpawnInterval.inMinutes;
      // Probability that a hygiene event spawns *this* tick.
      final p = spawnMinutes > 0 ? tickMinutes / spawnMinutes : 0.0;
      final rng = _deterministicUnit(next.dnaSeed, tickTime);
      if (rng < p) {
        next = next.copyWith(
          hygieneArtefacts: [...next.hygieneArtefacts, tickTime],
          recentEvents: _appendEvent(
            next.recentEvents,
            CareEvent(
              at: tickTime,
              kind: CareEventKind.hygieneArtefactAppeared,
            ),
          ),
        );
      }
    }

    // Sickness trigger check (hygiene stale and numerous).
    if (!next.isSick) {
      final staleCount = next.hygieneArtefacts
          .where((a) => tickTime.difference(a) >= config.hygieneStaleAfter)
          .length;
      final highInstability =
          next.instability >= config.sicknessInstabilityThreshold;
      if (staleCount >= config.hygieneSicknessThreshold || highInstability) {
        next = next.copyWith(
          isSick: true,
          recentEvents: _appendEvent(
            next.recentEvents,
            CareEvent(at: tickTime, kind: CareEventKind.sicknessOnset),
          ),
        );
      }
    }

    // Instability drifts down over time (self-healing when surges stop).
    if (next.instability > 0 && !next.isSick) {
      next = next.copyWith(instability: math.max(0, next.instability - 1));
    }

    // Call lifecycle — start / expire.
    next = _evaluateAttentionCall(next, tickTime);

    // Advance lastTickAt to this tick's instant.
    next = next.copyWith(lastTickAt: tickTime);

    // Stage transitions are handled by the outer _advanceExact loop
    // at their exact configured boundaries, not here — see
    // _advanceExact / _applyStageTransition.

    return next;
  }

  PetState _applyTimeOnlyTransitions(PetState s, DateTime now) {
    var next = s;

    // Sleep/wake edge transitions based on sleep window.
    final shouldSleep = isInSleepWindow(now);
    if (shouldSleep && !next.isAsleep) {
      next = next.copyWith(
        isAsleep: true,
        recentEvents: _appendEvent(
          next.recentEvents,
          CareEvent(at: now, kind: CareEventKind.sleepEntered),
        ),
      );
      // If the player didn't Dim within grace, that will be recorded later
      // by the Dim action or by the next tick's absence-check. Grace logic
      // is evaluated by the bedtime-call pathway in _evaluateAttentionCall.
    } else if (!shouldSleep && next.isAsleep) {
      next = next.copyWith(
        isAsleep: false,
        recentEvents: _appendEvent(
          next.recentEvents,
          CareEvent(at: now, kind: CareEventKind.sleepExited),
        ),
      );
    }

    // Call expiry → missed mistake.
    final call = next.activeCall;
    if (call != null && call.hasExpired(now)) {
      final acc = next.stageAccumulators;
      next = next.copyWith(
        activeCall: null,
        stageAccumulators: acc.copyWith(
          mistakes: acc.mistakes + 1,
          totalCalls: acc.totalCalls + 1,
        ),
        recentEvents: _appendEvents(next.recentEvents, [
          CareEvent(at: now, kind: CareEventKind.callMissed),
          CareEvent(
            at: now,
            kind: CareEventKind.mistakeRecorded,
            detail: 'missed_call',
          ),
        ]),
      );
    }

    return next;
  }

  PetState _evaluateAttentionCall(PetState s, DateTime now) {
    if (s.activeCall != null) return s;
    if (s.stage == PetStage.egg || s.stage == PetStage.dormant) return s;
    if (s.isAsleep) return s;

    CallReason? reason;
    if (s.isSick) {
      reason = CallReason.sick;
    } else if (s.energy <= config.callTriggerStatThreshold) {
      reason = CallReason.hungry;
    } else if (s.mood <= config.callTriggerStatThreshold) {
      reason = CallReason.lonely;
    } else if (s.hygieneArtefacts.length >= config.hygieneSicknessThreshold) {
      reason = CallReason.hygiene;
    }

    if (reason == null) return s;

    final call = AttentionCall(
      startedAt: now,
      deadline: now.add(config.callAnswerDeadline),
      reason: reason,
    );
    final acc = s.stageAccumulators;
    return s.copyWith(
      activeCall: call,
      stageAccumulators: acc.copyWith(totalCalls: acc.totalCalls + 1),
      recentEvents: _appendEvent(
        s.recentEvents,
        CareEvent(at: now, kind: CareEventKind.callStarted),
      ),
    );
  }

  /// Transition [s] to the next stage at [transitionAt]. Resolves the
  /// branch, resets stage accumulators, and appends the transition
  /// events. No time guard — the caller must have already verified that
  /// [transitionAt] is at or after the current stage's duration boundary
  /// (see [_advanceExact] and [_advanceBounded]).
  ///
  /// Returns [s] unchanged if the stage is terminal (dormant).
  PetState _applyStageTransition(PetState s, DateTime transitionAt) {
    final nextStage = evolution.nextStage(s.stage);
    if (nextStage == s.stage) return s;

    final nextBranch = evolution.resolveBranch(
      from: s.stage,
      to: nextStage,
      current: s.branch,
      acc: s.stageAccumulators,
    );
    // Egg → juvenile is the player-facing "Hatched" moment and emits
    // `hatched` INSTEAD OF `stageAdvanced`. Every downstream consumer
    // that filters on "stage transition" must accept either kind (see
    // PetNotificationDispatcher._isStageTransitionKind and
    // PetAnimationTracker). This keeps the recent-events feed from
    // showing both "Hatched" and "Evolved" at the same timestamp.
    final isHatching =
        s.stage == PetStage.egg && nextStage == PetStage.juvenile;
    final events = <CareEvent>[
      if (isHatching)
        CareEvent(at: transitionAt, kind: CareEventKind.hatched)
      else
        CareEvent(at: transitionAt, kind: CareEventKind.stageAdvanced),
      if (s.stage == PetStage.adolescent && nextStage == PetStage.adult)
        CareEvent(at: transitionAt, kind: CareEventKind.branchResolved),
      if (nextStage == PetStage.dormant)
        CareEvent(at: transitionAt, kind: CareEventKind.dormantEntered),
    ];
    return s.copyWith(
      stage: nextStage,
      branch: nextBranch,
      stageStartedAt: transitionAt,
      stageAccumulators: const CareAccumulators.empty(),
      recentEvents: _appendEvents(s.recentEvents, events),
    );
  }

  // ---- Bounded neglect projection --------------------------------------

  /// For gaps longer than [config.exactCatchUpMaxGap], this applies a
  /// compressed degradation: daily neglect ticks that cap at
  /// [config.neglectMistakeCap] mistakes and never push stats below
  /// [config.neglectFloorStat]. This preserves the "can recover with
  /// active care" invariant for arbitrarily long absences.
  PetState _advanceBounded(PetState state, DateTime now) {
    final days = now.difference(state.lastTickAt).inDays;
    if (days <= 0) return state.copyWith(lastTickAt: now);

    final acc = state.stageAccumulators;
    final addedMistakes = math.min(days, config.neglectMistakeCap);
    final floor = config.neglectFloorStat;

    final hygieneCount = math.min(
      config.hygieneMaxOnField,
      state.hygieneArtefacts.length + days,
    );
    final hygieneArtefacts = List<DateTime>.generate(
      hygieneCount,
      (i) => i < state.hygieneArtefacts.length
          ? state.hygieneArtefacts[i]
          : state.lastTickAt.add(Duration(days: i + 1)),
    );

    final events = <CareEvent>[
      for (var i = 0; i < addedMistakes; i++)
        CareEvent(
          at: state.lastTickAt.add(Duration(days: i + 1)),
          kind: CareEventKind.mistakeRecorded,
          detail: 'neglect_projection',
        ),
    ];

    var projected = state.copyWith(
      energy: math
          .max(floor, state.energy - days * 2)
          .clamp(floor, config.statMax),
      mood: math.max(floor, state.mood - days * 2).clamp(floor, config.statMax),
      stability: math
          .max(floor, state.stability - days)
          .clamp(floor, config.statMax),
      hygieneArtefacts: hygieneArtefacts,
      stageAccumulators: acc.copyWith(mistakes: acc.mistakes + addedMistakes),
      recentEvents: _appendEvents(state.recentEvents, events),
    );

    // Walk the stage chain based on actual elapsed time, stepping
    // through every boundary crossed during the gap.
    while (true) {
      final duration = evolution.durationFor(projected.stage);
      if (duration == null) break;
      final transitionAt = projected.stageStartedAt.add(duration);
      if (transitionAt.isAfter(now)) break;
      final advanced = _applyStageTransition(
        projected.copyWith(lastTickAt: transitionAt),
        transitionAt,
      );
      if (advanced.stage == projected.stage) break;
      projected = advanced;
    }

    projected = projected.copyWith(lastTickAt: now);
    return projected;
  }

  // ---- Player actions --------------------------------------------------

  /// Apply [action] to [state] and return a structured result describing
  /// what the engine did. The result's [PetActionResult.state] is the
  /// (possibly-unchanged) post-action state; its [PetActionOutcome] tells
  /// the UI whether to show a toast, a no-op reaction, or nothing at all.
  ///
  /// Action semantics:
  ///   - **charge/surge**: invalid while asleep / egg / dormant; capped
  ///     when energy is at max AND there's no hungry call to answer.
  ///   - **resonate**: invalid while asleep / egg / dormant; notNeeded
  ///     when mood is at max AND there's no lonely call to answer.
  ///   - **stabilise**: notNeeded when no hygiene artefact exists.
  ///   - **sync**: notNeeded when no active call AND stability is at max.
  ///   - **purge**: invalid (notSick) unless the pet is sick.
  ///   - **dim**: invalid outside the sleep window; notNeeded when
  ///     already asleep.
  ///   - **inspect**: always applied (opens the detail sheet).
  ///   - **reSigil**: invalid unless dormant — the controller layer
  ///     handles the actual replacement because it needs to mint a new
  ///     PetState from scratch.
  PetActionResult applyAction(PetState state, CareAction action, DateTime now) {
    // Always advance first so the action applies to the "current" state.
    final base = advanceTo(state, now);

    switch (action) {
      case CareAction.charge:
        return _applyCharge(base, now);
      case CareAction.surge:
        return _applySurge(base, now);
      case CareAction.resonate:
        return _applyResonate(base, now);
      case CareAction.stabilise:
        return _applyStabilise(base, now);
      case CareAction.sync:
        return _applySync(base, now);
      case CareAction.purge:
        return _applyPurge(base, now);
      case CareAction.dim:
        return _applyDim(base, now);
      case CareAction.inspect:
        return _applyInspect(base, now);
      case CareAction.reSigil:
        return _applyReSigil(base, action);
    }
  }

  // ---- Per-action handlers ---------------------------------------------

  /// Returns a refusal result when [s]'s life-cycle stage (egg or
  /// dormant) forbids the interactive action, or null when the stage is
  /// permissive and the caller should continue checking other guards.
  PetActionResult? _refuseForLifeStage(PetState s, CareAction action) {
    if (s.stage == PetStage.egg) {
      return PetActionResult.invalidInState(
        state: s,
        action: action,
        reason: PetActionReason.egg,
      );
    }
    if (s.stage == PetStage.dormant) {
      return PetActionResult.invalidInState(
        state: s,
        action: action,
        reason: PetActionReason.dormant,
      );
    }
    return null;
  }

  PetActionResult _applyCharge(PetState s, DateTime now) {
    final refusal = _refuseForLifeStage(s, CareAction.charge);
    if (refusal != null) return refusal;
    if (s.isAsleep) {
      return PetActionResult.invalidInState(
        state: s,
        action: CareAction.charge,
        reason: PetActionReason.asleep,
      );
    }
    final hasHungryCall = s.activeCall?.reason == CallReason.hungry;
    if (s.energy >= config.statMax && !hasHungryCall) {
      return PetActionResult.capped(
        state: s,
        action: CareAction.charge,
        reason: PetActionReason.fullyCharged,
      );
    }
    var next = _answerCallIfMatching(s, now, CallReason.hungry);
    next = next.copyWith(
      energy: _clampStat(next.energy + 3),
      recentEvents: _appendEvent(
        next.recentEvents,
        CareEvent(at: now, kind: CareEventKind.charged),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.charge);
  }

  PetActionResult _applySurge(PetState s, DateTime now) {
    final refusal = _refuseForLifeStage(s, CareAction.surge);
    if (refusal != null) return refusal;
    if (s.isAsleep) {
      return PetActionResult.invalidInState(
        state: s,
        action: CareAction.surge,
        reason: PetActionReason.asleep,
      );
    }
    final hasHungryCall = s.activeCall?.reason == CallReason.hungry;
    if (s.energy >= config.statMax && !hasHungryCall) {
      return PetActionResult.capped(
        state: s,
        action: CareAction.surge,
        reason: PetActionReason.fullyCharged,
      );
    }
    var next = _answerCallIfMatching(s, now, CallReason.hungry);
    final acc = next.stageAccumulators;
    next = next.copyWith(
      energy: _clampStat(next.energy + 5),
      instability: _clampStat(next.instability + config.instabilityPerSurge),
      stageAccumulators: acc.copyWith(surges: acc.surges + 1),
      recentEvents: _appendEvent(
        next.recentEvents,
        CareEvent(at: now, kind: CareEventKind.surged),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.surge);
  }

  PetActionResult _applyResonate(PetState s, DateTime now) {
    final refusal = _refuseForLifeStage(s, CareAction.resonate);
    if (refusal != null) return refusal;
    if (s.isAsleep) {
      return PetActionResult.invalidInState(
        state: s,
        action: CareAction.resonate,
        reason: PetActionReason.asleep,
      );
    }
    final hasLonelyCall = s.activeCall?.reason == CallReason.lonely;
    if (s.mood >= config.statMax && !hasLonelyCall) {
      return PetActionResult.notNeeded(
        state: s,
        action: CareAction.resonate,
        reason: PetActionReason.moodAlreadyFull,
      );
    }
    var next = _answerCallIfMatching(s, now, CallReason.lonely);
    next = next.copyWith(
      mood: _clampStat(next.mood + 3),
      recentEvents: _appendEvent(
        next.recentEvents,
        CareEvent(at: now, kind: CareEventKind.resonated),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.resonate);
  }

  PetActionResult _applyStabilise(PetState s, DateTime now) {
    if (s.hygieneArtefacts.isEmpty) {
      return PetActionResult.notNeeded(
        state: s,
        action: CareAction.stabilise,
        reason: PetActionReason.nothingToClean,
      );
    }
    var next = _answerCallIfMatching(s, now, CallReason.hygiene);
    next = next.copyWith(
      hygieneArtefacts: const [],
      stability: _clampStat(next.stability + 2),
      recentEvents: _appendEvent(
        next.recentEvents,
        CareEvent(at: now, kind: CareEventKind.stabilised),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.stabilise);
  }

  PetActionResult _applySync(PetState s, DateTime now) {
    // Sync is purely the "answer the call" tap — it exists only to
    // acknowledge an active attention call. It does NOT change stats.
    // Stat management lives with the dedicated care actions:
    // Stabilise raises stability, Resonate raises mood, Charge/Surge
    // raise energy, Purge clears sickness. Tamagotchi-style one-action
    // -per-stat: the beep is cleared by acknowledging, but whatever
    // underlying need the call surfaces must be addressed by its own
    // action. This keeps the mental model honest.
    final hasCall = s.activeCall != null;
    if (!hasCall) {
      return PetActionResult.notNeeded(
        state: s,
        action: CareAction.sync,
        reason: PetActionReason.nothingToSync,
      );
    }
    var next = _answerCallIfMatching(s, now, s.activeCall!.reason);
    final acc = next.stageAccumulators;
    next = next.copyWith(
      stageAccumulators: acc.copyWith(
        disciplineCorrections: acc.disciplineCorrections + 1,
      ),
      recentEvents: _appendEvent(
        next.recentEvents,
        CareEvent(at: now, kind: CareEventKind.synced),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.sync);
  }

  PetActionResult _applyPurge(PetState s, DateTime now) {
    if (!s.isSick) {
      return PetActionResult.invalidInState(
        state: s,
        action: CareAction.purge,
        reason: PetActionReason.notSick,
      );
    }
    var next = _answerCallIfMatching(s, now, CallReason.sick);
    next = next.copyWith(
      isSick: false,
      instability: math.max(0, next.instability - 3),
      recentEvents: _appendEvents(next.recentEvents, [
        CareEvent(at: now, kind: CareEventKind.purged),
        CareEvent(at: now, kind: CareEventKind.sicknessRecovered),
      ]),
    );
    return PetActionResult.applied(state: next, action: CareAction.purge);
  }

  PetActionResult _applyDim(PetState s, DateTime now) {
    if (s.isAsleep) {
      return PetActionResult.notNeeded(
        state: s,
        action: CareAction.dim,
        reason: PetActionReason.alreadyAsleep,
      );
    }
    if (!isInSleepWindow(now)) {
      return PetActionResult.invalidInState(
        state: s,
        action: CareAction.dim,
        reason: PetActionReason.notBedtime,
      );
    }
    var next = _answerCallIfMatching(s, now, CallReason.bedtime);
    next = next.copyWith(
      isAsleep: true,
      recentEvents: _appendEvent(
        next.recentEvents,
        CareEvent(at: now, kind: CareEventKind.dimmed),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.dim);
  }

  PetActionResult _applyInspect(PetState s, DateTime now) {
    final next = s.copyWith(
      recentEvents: _appendEvent(
        s.recentEvents,
        CareEvent(at: now, kind: CareEventKind.inspected),
      ),
    );
    return PetActionResult.applied(state: next, action: CareAction.inspect);
  }

  PetActionResult _applyReSigil(PetState s, CareAction action) {
    if (s.stage != PetStage.dormant) {
      return PetActionResult.invalidInState(
        state: s,
        action: action,
        reason: PetActionReason.notDormant,
      );
    }
    // Controller layer performs the actual replacement (minting a new
    // PetState). Engine reports "applied" so the UI can fire feedback;
    // the state it returns is unchanged.
    return PetActionResult.applied(state: s, action: action);
  }

  PetState _answerCallIfMatching(PetState s, DateTime now, CallReason reason) {
    final call = s.activeCall;
    if (call == null || call.reason != reason) return s;
    final acc = s.stageAccumulators;
    return s.copyWith(
      activeCall: null,
      stageAccumulators: acc.copyWith(answeredCalls: acc.answeredCalls + 1),
      recentEvents: _appendEvent(
        s.recentEvents,
        CareEvent(at: now, kind: CareEventKind.callAnswered),
      ),
    );
  }

  // ---- Utilities --------------------------------------------------------

  int _clampStat(int v) => v.clamp(config.statMin, config.statMax);

  List<CareEvent> _appendEvent(List<CareEvent> existing, CareEvent event) {
    return _appendEvents(existing, [event]);
  }

  List<CareEvent> _appendEvents(
    List<CareEvent> existing,
    List<CareEvent> added,
  ) {
    final combined = [...existing, ...added];
    if (combined.length <= config.recentEventsCapacity) return combined;
    return combined.sublist(combined.length - config.recentEventsCapacity);
  }

  /// Deterministic [0, 1) PRNG seeded on (dnaSeed, timestamp). Keeps the
  /// engine pure — no Random instances, no system entropy.
  double _deterministicUnit(int seed, DateTime at) {
    final ms = at.toUtc().millisecondsSinceEpoch;
    int h = (seed ^ ms) & 0xFFFFFFFF;
    h ^= (h << 13) & 0xFFFFFFFF;
    h ^= (h >> 17);
    h ^= (h << 5) & 0xFFFFFFFF;
    return (h & 0xFFFFFFFF) / 0x100000000;
  }
}
