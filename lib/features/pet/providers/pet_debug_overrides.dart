// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Dev-only pet visual state overrides. Drives PetCreature + need
// indicator from a debug sheet so every combination of
// stage/branch/mood/flags can be previewed against the real hero
// widget without touching actual pet state. kDebugMode-gated on the
// UI side — this file compiles in release, but nothing writes to the
// overrides outside debug builds.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pet_enums.dart';

class PetDebugOverrides {
  final PetStage? stage;
  final PetBranch? branch;
  final PetMood? mood;
  final bool? isAsleep;
  final bool? isSick;
  final CallReason? callReason;
  final bool? preferFrontFace;

  const PetDebugOverrides({
    this.stage,
    this.branch,
    this.mood,
    this.isAsleep,
    this.isSick,
    this.callReason,
    this.preferFrontFace,
  });

  bool get isAnyOverrideActive =>
      stage != null ||
      branch != null ||
      mood != null ||
      isAsleep != null ||
      isSick != null ||
      callReason != null ||
      preferFrontFace != null;

  PetDebugOverrides copyWith({
    PetStage? stage,
    bool clearStage = false,
    PetBranch? branch,
    bool clearBranch = false,
    PetMood? mood,
    bool clearMood = false,
    bool? isAsleep,
    bool clearIsAsleep = false,
    bool? isSick,
    bool clearIsSick = false,
    CallReason? callReason,
    bool clearCallReason = false,
    bool? preferFrontFace,
    bool clearPreferFrontFace = false,
  }) {
    return PetDebugOverrides(
      stage: clearStage ? null : (stage ?? this.stage),
      branch: clearBranch ? null : (branch ?? this.branch),
      mood: clearMood ? null : (mood ?? this.mood),
      isAsleep: clearIsAsleep ? null : (isAsleep ?? this.isAsleep),
      isSick: clearIsSick ? null : (isSick ?? this.isSick),
      callReason: clearCallReason ? null : (callReason ?? this.callReason),
      preferFrontFace: clearPreferFrontFace
          ? null
          : (preferFrontFace ?? this.preferFrontFace),
    );
  }
}

class PetDebugOverridesNotifier extends Notifier<PetDebugOverrides> {
  @override
  PetDebugOverrides build() => const PetDebugOverrides();

  void setStage(PetStage? v) =>
      state = state.copyWith(stage: v, clearStage: v == null);
  void setBranch(PetBranch? v) =>
      state = state.copyWith(branch: v, clearBranch: v == null);
  void setMood(PetMood? v) =>
      state = state.copyWith(mood: v, clearMood: v == null);
  void setIsAsleep(bool? v) =>
      state = state.copyWith(isAsleep: v, clearIsAsleep: v == null);
  void setIsSick(bool? v) =>
      state = state.copyWith(isSick: v, clearIsSick: v == null);
  void setCallReason(CallReason? v) =>
      state = state.copyWith(callReason: v, clearCallReason: v == null);
  void setPreferFrontFace(bool? v) => state = state.copyWith(
    preferFrontFace: v,
    clearPreferFrontFace: v == null,
  );

  void reset() => state = const PetDebugOverrides();
}

final petDebugOverridesProvider =
    NotifierProvider<PetDebugOverridesNotifier, PetDebugOverrides>(
      PetDebugOverridesNotifier.new,
    );
