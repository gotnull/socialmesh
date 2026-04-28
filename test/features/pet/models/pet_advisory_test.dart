// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/attention_call.dart';
import 'package:socialmesh/features/pet/models/care_accumulators.dart';
import 'package:socialmesh/features/pet/models/pet_advisory.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';

/// Minimal juvenile-stage fixture so tests can focus on one priority
/// rung at a time without re-declaring every field.
PetState _fixture({
  int energy = 10,
  int mood = 10,
  int stability = 10,
  int instability = 0,
  bool isSick = false,
  bool isAsleep = false,
  List<DateTime>? hygieneArtefacts,
  AttentionCall? activeCall,
  PetStage stage = PetStage.juvenile,
}) {
  final now = DateTime.utc(2026, 5, 1, 12);
  return PetState(
    ownerNodeNum: 1,
    dnaSeed: 0xDEADBEEF,
    stage: stage,
    branch: PetBranch.steady,
    hatchedAt: now,
    stageStartedAt: now,
    lastTickAt: now,
    energy: energy,
    mood: mood,
    stability: stability,
    instability: instability,
    isSick: isSick,
    isAsleep: isAsleep,
    hygieneArtefacts: hygieneArtefacts ?? const [],
    activeCall: activeCall,
    stageAccumulators: const CareAccumulators.empty(),
    recentEvents: const [],
  );
}

const _config = PetConfig();

void main() {
  group('computePrimaryAdvisory — priority ladder', () {
    test('dormant stage overrides everything, including sickness', () {
      // Even a sick, call-firing pet in dormant should surface the
      // dormant / re-sigil advisory — dormancy is terminal.
      final s = _fixture(
        stage: PetStage.dormant,
        isSick: true,
        activeCall: AttentionCall(
          startedAt: DateTime.utc(2026, 5, 1, 12),
          deadline: DateTime.utc(2026, 5, 1, 14),
          reason: CallReason.sick,
        ),
      );
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.dormant);
      expect(a.level, PetAdvisoryLevel.stage);
      expect(a.action, PetAdvisoryAction.reSigil);
    });

    test('egg stage surfaces no action', () {
      final s = _fixture(stage: PetStage.egg);
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.egg);
      expect(a.action, isNull);
    });

    test('sickness (no call) → urgent Purge', () {
      final s = _fixture(isSick: true);
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.sick);
      expect(a.level, PetAdvisoryLevel.urgent);
      expect(a.action, PetAdvisoryAction.purge);
    });

    test('active hungry call → Charge (not Sync)', () {
      // Sync is deliberately never the primary hint — the underlying
      // need has its own dedicated action.
      final s = _fixture(
        activeCall: AttentionCall(
          startedAt: DateTime.utc(2026, 5, 1, 12),
          deadline: DateTime.utc(2026, 5, 1, 14),
          reason: CallReason.hungry,
        ),
      );
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.callHungry);
      expect(a.action, PetAdvisoryAction.charge);
    });

    test('active hygiene call → Stabilise', () {
      final s = _fixture(
        activeCall: AttentionCall(
          startedAt: DateTime.utc(2026, 5, 1, 12),
          deadline: DateTime.utc(2026, 5, 1, 14),
          reason: CallReason.hygiene,
        ),
      );
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.callHygiene);
      expect(a.action, PetAdvisoryAction.stabilise);
    });

    test('hygiene at sickness threshold → imminent warning', () {
      // Default hygieneSicknessThreshold = 2.
      final s = _fixture(
        hygieneArtefacts: [
          DateTime.utc(2026, 5, 1, 10),
          DateTime.utc(2026, 5, 1, 11),
        ],
      );
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.hygieneImminent);
      expect(a.level, PetAdvisoryLevel.urgent);
      expect(a.action, PetAdvisoryAction.stabilise);
    });

    test('energy ≤ call threshold (no call yet) → warn Charge', () {
      final s = _fixture(energy: 3); // default callTriggerStatThreshold=3
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.energyLow);
      expect(a.level, PetAdvisoryLevel.warn);
      expect(a.action, PetAdvisoryAction.charge);
    });

    test('mood ≤ call threshold (no call yet) → warn Resonate', () {
      final s = _fixture(mood: 2);
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.moodLow);
      expect(a.action, PetAdvisoryAction.resonate);
    });

    test('single mild artefact → info Stabilise', () {
      final s = _fixture(hygieneArtefacts: [DateTime.utc(2026, 5, 1, 11, 30)]);
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.hygieneMild);
      expect(a.level, PetAdvisoryLevel.info);
      expect(a.action, PetAdvisoryAction.stabilise);
    });

    test('asleep → calm resting, no action', () {
      final s = _fixture(isAsleep: true);
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: true,
      );
      expect(a.kind, PetAdvisoryKind.resting);
      expect(a.level, PetAdvisoryLevel.calm);
      expect(a.action, isNull);
    });

    test('bedtime (awake, in sleep window, all stats full) → info Dim', () {
      final s = _fixture();
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: true,
      );
      expect(a.kind, PetAdvisoryKind.bedtime);
      expect(a.action, PetAdvisoryAction.dim);
    });

    test('all stats full, not bedtime → thriving', () {
      final s = _fixture();
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.thriving);
      expect(a.level, PetAdvisoryLevel.calm);
      expect(a.action, isNull);
    });
  });

  group('priority — sickness call outranks passive low stats', () {
    // Passive stats can be low AND a call can be firing at the same
    // time. The active call wins because its deadline is running.
    test('sick call beats low-energy passive nudge', () {
      final s = _fixture(
        energy: 1,
        activeCall: AttentionCall(
          startedAt: DateTime.utc(2026, 5, 1, 12),
          deadline: DateTime.utc(2026, 5, 1, 14),
          reason: CallReason.sick,
        ),
        isSick: true,
      );
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      // Sickness is checked before active-call routing, so the direct
      // "sick" advisory is surfaced (same action regardless).
      expect(a.action, PetAdvisoryAction.purge);
    });

    test('hygieneImminent beats energyLow', () {
      final s = _fixture(
        energy: 2,
        hygieneArtefacts: [
          DateTime.utc(2026, 5, 1, 10),
          DateTime.utc(2026, 5, 1, 11),
        ],
      );
      final a = computePrimaryAdvisory(
        state: s,
        config: _config,
        inSleepWindow: false,
      );
      expect(a.kind, PetAdvisoryKind.hygieneImminent);
    });
  });
}
