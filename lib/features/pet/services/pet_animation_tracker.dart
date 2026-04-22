// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetAnimationTracker — durable "last acknowledged transition" bookkeeping
// per ownerNodeNum. Keeps one-shot hatch / evolution effects from
// replaying on widget rebuild, app resume, or unrelated provider
// invalidation.
//
// The model is deliberately minimal: a single millisecond-epoch watermark
// per owner. Any stage transition with a timestamp strictly greater than
// the watermark is "unacknowledged" and should trigger its one-shot
// effect. The screen then advances the watermark to the transition
// instant so it never fires again.

import 'package:shared_preferences/shared_preferences.dart';

import '../models/care_event.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';

class PetAnimationTracker {
  final SharedPreferences _prefs;

  PetAnimationTracker(this._prefs);

  static String _key(int ownerNodeNum) =>
      'pet.ackedTransitionAt.$ownerNodeNum'; // lint-allow: hardcoded-string

  /// The watermark: the most recent stage transition (by instant) the UI
  /// has already animated. Returns [DateTime.fromMillisecondsSinceEpoch(0)]
  /// when nothing has been acknowledged yet.
  DateTime ackedAt(int ownerNodeNum) {
    final ms = _prefs.getInt(_key(ownerNodeNum));
    if (ms == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  Future<void> acknowledge(int ownerNodeNum, DateTime at) async {
    await _prefs.setInt(_key(ownerNodeNum), at.toUtc().millisecondsSinceEpoch);
  }

  /// The most recent unacknowledged stage transition in [state], or null
  /// if every transition is acknowledged. We return the latest (not the
  /// earliest) because [PetState.stage] always reflects the most-recent
  /// transition — playing the effect for that transition matches what
  /// the user currently sees on screen.
  ///
  /// "Stage transition" here means either [CareEventKind.stageAdvanced]
  /// (every transition except egg→juvenile) OR [CareEventKind.hatched]
  /// (the egg→juvenile case, which emits ONLY `hatched` — see
  /// PetCareEngine._applyStageTransition).
  /// [CareEventKind.branchResolved] and [CareEventKind.dormantEntered]
  /// are sibling events fired at the same instant and are identified by
  /// inspecting [PetState.stage] / [PetState.branch] at that point.
  CareEvent? latestUnacknowledged(PetState state) {
    final watermark = ackedAt(state.ownerNodeNum);
    CareEvent? best;
    for (final event in state.recentEvents) {
      if (!_isStageTransitionKind(event.kind)) continue;
      if (!event.at.isAfter(watermark)) continue;
      if (best == null || event.at.isAfter(best.at)) {
        best = event;
      }
    }
    return best;
  }

  /// Convenience: mark every stage transition currently in [state] as
  /// acknowledged. Used on the very first mount of the home screen for a
  /// pet whose earlier history predates this tracker's introduction.
  Future<void> acknowledgeAll(PetState state) async {
    DateTime? latest;
    for (final event in state.recentEvents) {
      if (!_isStageTransitionKind(event.kind)) continue;
      if (latest == null || event.at.isAfter(latest)) latest = event.at;
    }
    if (latest != null) {
      await acknowledge(state.ownerNodeNum, latest);
    }
  }

  static bool _isStageTransitionKind(CareEventKind kind) =>
      kind == CareEventKind.stageAdvanced || kind == CareEventKind.hatched;
}

/// Classify a stage transition by the resulting stage of the pet at the
/// moment the event was fired. The [PetState] passed in should be the
/// state AS OF OR AFTER the transition (i.e. the current owned state),
/// since the state's `stage` will be the post-transition stage at the
/// time the event was appended.
enum PetTransitionKind {
  hatch, // egg → juvenile
  adolescence, // juvenile → adolescent
  branchResolution, // adolescent → adult
  maturation, // adult → elder
  dormancy, // elder → dormant
  unknown,
}

PetTransitionKind classifyTransitionByResultingStage(PetStage resulting) {
  switch (resulting) {
    case PetStage.juvenile:
      return PetTransitionKind.hatch;
    case PetStage.adolescent:
      return PetTransitionKind.adolescence;
    case PetStage.adult:
      return PetTransitionKind.branchResolution;
    case PetStage.elder:
      return PetTransitionKind.maturation;
    case PetStage.dormant:
      return PetTransitionKind.dormancy;
    case PetStage.egg:
      return PetTransitionKind.unknown;
  }
}
