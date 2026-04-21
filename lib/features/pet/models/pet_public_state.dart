// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetPublicState — the ≤8-byte mesh-visible summary of another node's pet.
// Published via MRRP service pet.v1. Cached locally in pet.db's
// remote_pet_cache table.
//
// Wire format v1 (schema tag 0x01) is frozen. Any field rearrangement,
// growth, or semantic change requires a new schema tag.

import 'package:flutter/foundation.dart';

import 'pet_enums.dart';

@immutable
class PetPublicState {
  /// Full 32-bit deterministic seed. Enough entropy for the remote renderer
  /// to differentiate morphology within the same branch — no extra variant
  /// bits needed.
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;

  /// Saturating day count; caps at PetConfig.publicAgeDaysMax (255).
  final int ageInDays;

  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final bool isEvolving;

  const PetPublicState({
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.ageInDays,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.isEvolving,
  });

  PetPublicState copyWith({
    int? dnaSeed,
    PetStage? stage,
    PetBranch? branch,
    PetMood? mood,
    int? ageInDays,
    bool? isAsleep,
    bool? isSick,
    bool? isCalling,
    bool? isEvolving,
  }) {
    return PetPublicState(
      dnaSeed: dnaSeed ?? this.dnaSeed,
      stage: stage ?? this.stage,
      branch: branch ?? this.branch,
      mood: mood ?? this.mood,
      ageInDays: ageInDays ?? this.ageInDays,
      isAsleep: isAsleep ?? this.isAsleep,
      isSick: isSick ?? this.isSick,
      isCalling: isCalling ?? this.isCalling,
      isEvolving: isEvolving ?? this.isEvolving,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetPublicState &&
          dnaSeed == other.dnaSeed &&
          stage == other.stage &&
          branch == other.branch &&
          mood == other.mood &&
          ageInDays == other.ageInDays &&
          isAsleep == other.isAsleep &&
          isSick == other.isSick &&
          isCalling == other.isCalling &&
          isEvolving == other.isEvolving;

  @override
  int get hashCode => Object.hash(
    dnaSeed,
    stage,
    branch,
    mood,
    ageInDays,
    isAsleep,
    isSick,
    isCalling,
    isEvolving,
  );
}
