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

  PetState _advanceExact(PetState state, DateTime now) {
    var s = state;
    // Advance one care tick at a time so decisions that depend on
    // sleep-window boundaries (e.g. bedtime call) fire at the right moment.
    while (true) {
      final nextTick = s.lastTickAt.add(config.careTickDuration);
      if (nextTick.isAfter(now)) break;
      s = _applyCareTick(s, nextTick);
    }
    // Handle the partial tick's worth of time-only effects (sleep/wake and
    // call expiry transitions need to fire even when no full tick elapsed).
    if (now.isAfter(s.lastTickAt)) {
      s = _applyTimeOnlyTransitions(s, now);
      s = s.copyWith(lastTickAt: now);
    }
    return s;
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

    // Stage transitions happen on tick boundaries.
    next = _maybeAdvanceStage(next, tickTime);

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

  PetState _maybeAdvanceStage(PetState s, DateTime now) {
    if (!evolution.shouldAdvance(
      stage: s.stage,
      stageStartedAt: s.stageStartedAt,
      now: now,
    )) {
      return s;
    }
    final nextStage = evolution.nextStage(s.stage);
    if (nextStage == s.stage) return s;

    final nextBranch = evolution.resolveBranch(
      from: s.stage,
      to: nextStage,
      current: s.branch,
      acc: s.stageAccumulators,
    );
    final events = <CareEvent>[
      CareEvent(at: now, kind: CareEventKind.stageAdvanced),
      if (s.stage == PetStage.adolescent && nextStage == PetStage.adult)
        CareEvent(at: now, kind: CareEventKind.branchResolved),
      if (nextStage == PetStage.dormant)
        CareEvent(at: now, kind: CareEventKind.dormantEntered),
    ];
    return s.copyWith(
      stage: nextStage,
      branch: nextBranch,
      stageStartedAt: now,
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

    // Walk the stage chain based on actual elapsed time, not per-transition
    // `now`. This lets a multi-stage absence step through every boundary.
    while (true) {
      final duration = evolution.durationFor(projected.stage);
      if (duration == null) break;
      final transitionAt = projected.stageStartedAt.add(duration);
      if (transitionAt.isAfter(now)) break;
      final advanced = _maybeAdvanceStage(
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

  PetState applyAction(PetState state, CareAction action, DateTime now) {
    // Always advance first so the action applies to the "current" state.
    var s = advanceTo(state, now);

    switch (action) {
      case CareAction.charge:
        if (s.isAsleep) return s;
        s = _answerCallIfMatching(s, now, CallReason.hungry);
        s = s.copyWith(
          energy: _clampStat(s.energy + 3),
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.charged),
          ),
        );
        break;

      case CareAction.surge:
        if (s.isAsleep) return s;
        s = _answerCallIfMatching(s, now, CallReason.hungry);
        final acc = s.stageAccumulators;
        s = s.copyWith(
          energy: _clampStat(s.energy + 5),
          instability: _clampStat(s.instability + config.instabilityPerSurge),
          stageAccumulators: acc.copyWith(surges: acc.surges + 1),
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.surged),
          ),
        );
        break;

      case CareAction.resonate:
        if (s.isAsleep) return s;
        s = _answerCallIfMatching(s, now, CallReason.lonely);
        s = s.copyWith(
          mood: _clampStat(s.mood + 3),
          stability: _clampStat(s.stability + 1),
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.resonated),
          ),
        );
        break;

      case CareAction.stabilise:
        if (s.hygieneArtefacts.isEmpty) return s;
        s = _answerCallIfMatching(s, now, CallReason.hygiene);
        s = s.copyWith(
          hygieneArtefacts: const [],
          stability: _clampStat(s.stability + 2),
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.stabilised),
          ),
        );
        break;

      case CareAction.sync:
        final acc = s.stageAccumulators;
        s = s.copyWith(
          stability: _clampStat(s.stability + 2),
          stageAccumulators: acc.copyWith(
            disciplineCorrections: acc.disciplineCorrections + 1,
          ),
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.synced),
          ),
        );
        break;

      case CareAction.purge:
        if (!s.isSick) return s;
        s = _answerCallIfMatching(s, now, CallReason.sick);
        s = s.copyWith(
          isSick: false,
          instability: math.max(0, s.instability - 3),
          recentEvents: _appendEvents(s.recentEvents, [
            CareEvent(at: now, kind: CareEventKind.purged),
            CareEvent(at: now, kind: CareEventKind.sicknessRecovered),
          ]),
        );
        break;

      case CareAction.dim:
        // Dim only meaningful inside or near sleep window.
        s = _answerCallIfMatching(s, now, CallReason.bedtime);
        s = s.copyWith(
          isAsleep: true,
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.dimmed),
          ),
        );
        break;

      case CareAction.inspect:
        s = s.copyWith(
          recentEvents: _appendEvent(
            s.recentEvents,
            CareEvent(at: now, kind: CareEventKind.inspected),
          ),
        );
        break;

      case CareAction.reSigil:
        // Handled one level up (replaces state with a fresh egg).
        break;
    }

    return s;
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
