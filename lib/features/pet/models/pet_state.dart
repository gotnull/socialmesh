// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetState — the full owner-side pet state. Lives in pet.db's single-row
// own_pet table, keyed by ownerNodeNum. All persistence round-trips through
// toJson/fromJson.
//
// Invariants:
// - dnaSeed is fixed at hatch; it is deterministic from (ownerNodeNum,
//   hatchedAtMs) and never changes until a re-sigil event starts a fresh pet.
// - Visible stats (energy, mood, stability) are clamped to [statMin, statMax]
//   by the care engine; constructors trust their inputs.
// - stageAccumulators are reset at every stage transition by the evolution
//   engine.
// - recentEvents is a ring buffer; the care engine trims to capacity.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'attention_call.dart';
import 'care_accumulators.dart';
import 'care_event.dart';
import 'pet_enums.dart';

@immutable
class PetState {
  final int ownerNodeNum;
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final DateTime hatchedAt;
  final DateTime stageStartedAt;
  final DateTime lastTickAt;
  final int energy;
  final int mood;
  final int stability;
  final int instability;
  final bool isSick;
  final bool isAsleep;
  final List<DateTime> hygieneArtefacts;
  final AttentionCall? activeCall;
  final CareAccumulators stageAccumulators;
  final List<CareEvent> recentEvents;

  const PetState({
    required this.ownerNodeNum,
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.hatchedAt,
    required this.stageStartedAt,
    required this.lastTickAt,
    required this.energy,
    required this.mood,
    required this.stability,
    required this.instability,
    required this.isSick,
    required this.isAsleep,
    required this.hygieneArtefacts,
    required this.activeCall,
    required this.stageAccumulators,
    required this.recentEvents,
  });

  /// Mint a fresh egg for [ownerNodeNum] at [hatchedAt]. [dnaSeed] is
  /// computed deterministically from the two inputs.
  factory PetState.egg({
    required int ownerNodeNum,
    required DateTime hatchedAt,
    int statMax = 10,
  }) {
    return PetState(
      ownerNodeNum: ownerNodeNum,
      dnaSeed: computeDnaSeed(ownerNodeNum, hatchedAt),
      stage: PetStage.egg,
      branch: PetBranch.unborn,
      hatchedAt: hatchedAt,
      stageStartedAt: hatchedAt,
      lastTickAt: hatchedAt,
      energy: statMax,
      mood: statMax,
      stability: statMax,
      instability: 0,
      isSick: false,
      isAsleep: false,
      hygieneArtefacts: const [],
      activeCall: null,
      stageAccumulators: const CareAccumulators.empty(),
      recentEvents: [CareEvent(at: hatchedAt, kind: CareEventKind.hatched)],
    );
  }

  /// Deterministic 32-bit seed from ownerNodeNum and hatch time.
  /// The renderer is required to use the full seed (not just branch) for
  /// in-branch morphology differentiation — see design doc §renderer.
  static int computeDnaSeed(int ownerNodeNum, DateTime hatchedAt) {
    // Mix two 32-bit fields with a stable non-crypto hash.
    final hatchMs = hatchedAt.toUtc().millisecondsSinceEpoch;
    int h = ownerNodeNum & 0xFFFFFFFF;
    h ^= (hatchMs ^ (hatchMs >> 32)) & 0xFFFFFFFF;
    // xorshift-ish mixing.
    h ^= (h << 13) & 0xFFFFFFFF;
    h ^= (h >> 17);
    h ^= (h << 5) & 0xFFFFFFFF;
    return h & 0xFFFFFFFF;
  }

  /// Whole-day age derived from hatchedAt. Saturates at publicAgeDaysMax
  /// when encoded for the wire.
  int ageInDaysAt(DateTime now) {
    final ms = now.difference(hatchedAt).inMilliseconds;
    if (ms < 0) return 0;
    return (ms ~/ const Duration(days: 1).inMilliseconds);
  }

  PetState copyWith({
    int? ownerNodeNum,
    int? dnaSeed,
    PetStage? stage,
    PetBranch? branch,
    DateTime? hatchedAt,
    DateTime? stageStartedAt,
    DateTime? lastTickAt,
    int? energy,
    int? mood,
    int? stability,
    int? instability,
    bool? isSick,
    bool? isAsleep,
    List<DateTime>? hygieneArtefacts,
    Object? activeCall = _sentinel,
    CareAccumulators? stageAccumulators,
    List<CareEvent>? recentEvents,
  }) {
    return PetState(
      ownerNodeNum: ownerNodeNum ?? this.ownerNodeNum,
      dnaSeed: dnaSeed ?? this.dnaSeed,
      stage: stage ?? this.stage,
      branch: branch ?? this.branch,
      hatchedAt: hatchedAt ?? this.hatchedAt,
      stageStartedAt: stageStartedAt ?? this.stageStartedAt,
      lastTickAt: lastTickAt ?? this.lastTickAt,
      energy: energy ?? this.energy,
      mood: mood ?? this.mood,
      stability: stability ?? this.stability,
      instability: instability ?? this.instability,
      isSick: isSick ?? this.isSick,
      isAsleep: isAsleep ?? this.isAsleep,
      hygieneArtefacts: hygieneArtefacts ?? this.hygieneArtefacts,
      activeCall: identical(activeCall, _sentinel)
          ? this.activeCall
          : activeCall as AttentionCall?,
      stageAccumulators: stageAccumulators ?? this.stageAccumulators,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }

  // ---- Serialization ---------------------------------------------------

  static const _schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'schemaVersion': _schemaVersion,
    'ownerNodeNum': ownerNodeNum,
    'dnaSeed': dnaSeed,
    'stage': stage.index,
    'branch': branch.index,
    'hatchedAt': hatchedAt.toUtc().millisecondsSinceEpoch,
    'stageStartedAt': stageStartedAt.toUtc().millisecondsSinceEpoch,
    'lastTickAt': lastTickAt.toUtc().millisecondsSinceEpoch,
    'energy': energy,
    'mood': mood,
    'stability': stability,
    'instability': instability,
    'isSick': isSick,
    'isAsleep': isAsleep,
    'hygieneArtefacts': hygieneArtefacts
        .map((d) => d.toUtc().millisecondsSinceEpoch)
        .toList(),
    'activeCall': activeCall?.toJson(),
    'stageAccumulators': stageAccumulators.toJson(),
    'recentEvents': recentEvents.map((e) => e.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory PetState.fromJson(Map<String, dynamic> json) {
    final stageIndex = (json['stage'] as num?)?.toInt() ?? 0;
    final branchIndex = (json['branch'] as num?)?.toInt() ?? 0;
    return PetState(
      ownerNodeNum: (json['ownerNodeNum'] as num).toInt(),
      dnaSeed: (json['dnaSeed'] as num).toInt(),
      stage: PetStage.values[stageIndex.clamp(0, PetStage.values.length - 1)],
      branch:
          PetBranch.values[branchIndex.clamp(0, PetBranch.values.length - 1)],
      hatchedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['hatchedAt'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      stageStartedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['stageStartedAt'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      lastTickAt: DateTime.fromMillisecondsSinceEpoch(
        (json['lastTickAt'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      energy: (json['energy'] as num).toInt(),
      mood: (json['mood'] as num).toInt(),
      stability: (json['stability'] as num).toInt(),
      instability: (json['instability'] as num).toInt(),
      isSick: json['isSick'] as bool? ?? false,
      isAsleep: json['isAsleep'] as bool? ?? false,
      hygieneArtefacts: ((json['hygieneArtefacts'] as List?) ?? const [])
          .map(
            (e) => DateTime.fromMillisecondsSinceEpoch(
              (e as num).toInt(),
              isUtc: true,
            ).toLocal(),
          )
          .toList(),
      activeCall: json['activeCall'] == null
          ? null
          : AttentionCall.fromJson(
              Map<String, dynamic>.from(json['activeCall'] as Map),
            ),
      stageAccumulators: json['stageAccumulators'] == null
          ? const CareAccumulators.empty()
          : CareAccumulators.fromJson(
              Map<String, dynamic>.from(json['stageAccumulators'] as Map),
            ),
      recentEvents: ((json['recentEvents'] as List?) ?? const [])
          .map((e) => CareEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  factory PetState.fromJsonString(String s) =>
      PetState.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

const Object _sentinel = Object();
