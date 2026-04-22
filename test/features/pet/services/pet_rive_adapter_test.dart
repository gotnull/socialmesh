// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the Dart↔Rive presentation adapter.
//
// Invariants pinned:
//   - Contract fields match expected primitive ranges (int/bool/double).
//   - Enum indices passed through verbatim from PetState.
//   - Raw stats normalised to [0, 1]; vitality is the mean.
//   - Analog modifiers (buoyancy, auraIntensity) land in [0, 1] after
//     inverse-lerp from the painter helper bands.
//   - Seed-derived trait buckets (symmetryClass, strandConfig,
//     hasAnomaly, signatureRotationDeg) stay in their declared ranges.
//   - Equality works — so the widget can short-circuit `setState` when
//     inputs haven't changed.
//   - `healthyAdultSteady` baseline is a concrete sensible default.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/care_accumulators.dart';
import 'package:socialmesh/features/pet/models/pet_config.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_rive_adapter.dart';

PetState _buildState({
  int dnaSeed = 0xABCDEF01,
  PetStage stage = PetStage.adult,
  PetBranch branch = PetBranch.steady,
  int energy = 10,
  int mood = 10,
  int stability = 10,
  bool isAsleep = false,
  bool isSick = false,
  List<DateTime> hygieneArtefacts = const [],
}) {
  final now = DateTime.utc(2026, 4, 22);
  return PetState(
    ownerNodeNum: 0x5AAD5ED6,
    dnaSeed: dnaSeed,
    stage: stage,
    branch: branch,
    hatchedAt: now,
    stageStartedAt: now,
    lastTickAt: now,
    energy: energy,
    mood: mood,
    stability: stability,
    instability: 0,
    isSick: isSick,
    isAsleep: isAsleep,
    hygieneArtefacts: hygieneArtefacts,
    activeCall: null,
    stageAccumulators: const CareAccumulators.empty(),
    recentEvents: const [],
  );
}

void main() {
  const adapter = PetRiveAdapter();
  const config = PetConfig();

  group('PetRiveAdapter — enum index pass-through', () {
    test('stage/branch/mood indices match the enum indices', () {
      final inputs = adapter.buildInputs(
        state: _buildState(stage: PetStage.elder, branch: PetBranch.luminous),
        derivedMood: PetMood.calling,
        config: config,
      );
      expect(inputs.stageIndex, PetStage.elder.index);
      expect(inputs.branchIndex, PetBranch.luminous.index);
      expect(inputs.moodIndex, PetMood.calling.index);
    });
  });

  group('PetRiveAdapter — flag plumbing', () {
    test('isAsleep / isSick pass through from PetState', () {
      final inputs = adapter.buildInputs(
        state: _buildState(isAsleep: true, isSick: true),
        derivedMood: PetMood.sleeping,
        config: config,
      );
      expect(inputs.isAsleep, isTrue);
      expect(inputs.isSick, isTrue);
    });

    test(
      'isCalling is true iff activeCall != null (state has no call here)',
      () {
        final inputs = adapter.buildInputs(
          state: _buildState(),
          derivedMood: PetMood.content,
          config: config,
        );
        expect(inputs.isCalling, isFalse);
      },
    );
  });

  group('PetRiveAdapter — vitality normalisation', () {
    test('full-health stats → vitality 1.0 ± epsilon', () {
      final inputs = adapter.buildInputs(
        state: _buildState(energy: 10, mood: 10, stability: 10),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(inputs.vitality, closeTo(1.0, 1e-9));
    });

    test('zero stats → vitality 0.0', () {
      final inputs = adapter.buildInputs(
        state: _buildState(energy: 0, mood: 0, stability: 0),
        derivedMood: PetMood.sad,
        config: config,
      );
      expect(inputs.vitality, 0.0);
    });

    test('half stats → vitality ~0.5', () {
      final inputs = adapter.buildInputs(
        state: _buildState(energy: 5, mood: 5, stability: 5),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(inputs.vitality, closeTo(0.5, 1e-9));
    });

    test('mixed stats average to the mean', () {
      // energy=2 (0.2), mood=8 (0.8), stability=5 (0.5) → mean 0.5.
      final inputs = adapter.buildInputs(
        state: _buildState(energy: 2, mood: 8, stability: 5),
        derivedMood: PetMood.hungry,
        config: config,
      );
      expect(inputs.vitality, closeTo(0.5, 1e-9));
    });
  });

  group('PetRiveAdapter — analog modifiers land in [0, 1]', () {
    test('buoyancy bounded and monotonic in vitality', () {
      final low = adapter.buildInputs(
        state: _buildState(energy: 0, mood: 0, stability: 0),
        derivedMood: PetMood.sad,
        config: config,
      );
      final mid = adapter.buildInputs(
        state: _buildState(energy: 5, mood: 5, stability: 5),
        derivedMood: PetMood.content,
        config: config,
      );
      final high = adapter.buildInputs(
        state: _buildState(energy: 10, mood: 10, stability: 10),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(low.buoyancy, inInclusiveRange(0.0, 1.0));
      expect(mid.buoyancy, inInclusiveRange(0.0, 1.0));
      expect(high.buoyancy, inInclusiveRange(0.0, 1.0));
      expect(low.buoyancy, lessThan(mid.buoyancy));
      expect(mid.buoyancy, lessThan(high.buoyancy));
    });

    test('auraIntensity bounded and driven by stability alone', () {
      final low = adapter.buildInputs(
        state: _buildState(energy: 10, mood: 10, stability: 0),
        derivedMood: PetMood.content,
        config: config,
      );
      final high = adapter.buildInputs(
        state: _buildState(energy: 10, mood: 10, stability: 10),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(low.auraIntensity, inInclusiveRange(0.0, 1.0));
      expect(high.auraIntensity, inInclusiveRange(0.0, 1.0));
      expect(low.auraIntensity, lessThan(high.auraIntensity));
    });
  });

  group('PetRiveAdapter — seed-derived buckets', () {
    test('symmetryClass ∈ {0..3} across a seed sweep', () {
      for (var i = 0; i < 64; i++) {
        final seed = i * 0x9E3779B1;
        final inputs = adapter.buildInputs(
          state: _buildState(dnaSeed: seed),
          derivedMood: PetMood.content,
          config: config,
        );
        expect(inputs.symmetryClass, inInclusiveRange(0, 3));
      }
    });

    test('strandConfig ∈ {0..2}', () {
      for (var i = 0; i < 64; i++) {
        final seed = i * 0x85EBCA77;
        final inputs = adapter.buildInputs(
          state: _buildState(dnaSeed: seed),
          derivedMood: PetMood.content,
          config: config,
        );
        expect(inputs.strandConfig, inInclusiveRange(0, 2));
      }
    });

    test('signatureRotationDeg ∈ [0, 359]', () {
      for (var i = 0; i < 64; i++) {
        final seed = i * 0xC2B2AE35;
        final inputs = adapter.buildInputs(
          state: _buildState(dnaSeed: seed),
          derivedMood: PetMood.content,
          config: config,
        );
        expect(inputs.signatureRotationDeg, inInclusiveRange(0, 359));
      }
    });

    test('hygieneArtefactCount is clamped to [0, 3]', () {
      final now = DateTime.utc(2026, 4, 22);
      final many = List<DateTime>.generate(10, (i) => now);
      final inputs = adapter.buildInputs(
        state: _buildState(hygieneArtefacts: many),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(inputs.hygieneArtefactCount, 3);
    });
  });

  group('PetRiveAdapter — determinism + equality', () {
    test('same inputs produce equal PetRiveInputs values', () {
      final a = adapter.buildInputs(
        state: _buildState(),
        derivedMood: PetMood.content,
        config: config,
      );
      final b = adapter.buildInputs(
        state: _buildState(),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different seed → different inputs (typically)', () {
      final a = adapter.buildInputs(
        state: _buildState(dnaSeed: 0xAAAAAAAA),
        derivedMood: PetMood.content,
        config: config,
      );
      final b = adapter.buildInputs(
        state: _buildState(dnaSeed: 0x55555555),
        derivedMood: PetMood.content,
        config: config,
      );
      expect(a, isNot(b));
    });
  });

  group('PetRiveInputs — healthyAdultSteady baseline', () {
    test('is a sensible default for public-state fallbacks', () {
      const b = PetRiveInputs.healthyAdultSteady;
      expect(b.stageIndex, PetStage.adult.index);
      expect(b.branchIndex, PetBranch.steady.index);
      expect(b.moodIndex, PetMood.content.index);
      expect(b.vitality, 1.0);
      expect(b.buoyancy, 1.0);
      expect(b.auraIntensity, 1.0);
      expect(b.hygieneArtefactCount, 0);
      expect(b.isAsleep, isFalse);
      expect(b.isSick, isFalse);
      expect(b.isCalling, isFalse);
    });
  });

  group('PetRiveAdapter — public-defaults builder', () {
    test('builds a baseline inputs bundle from public-state fields', () {
      final inputs = adapter.buildInputsFromPublicDefaults(
        stage: PetStage.elder,
        branch: PetBranch.luminous,
        mood: PetMood.content,
        isAsleep: false,
        isSick: false,
        isCalling: true,
        symmetryClass: 2,
        strandConfig: 1,
        hasAnomaly: false,
      );
      expect(inputs.stageIndex, PetStage.elder.index);
      expect(inputs.branchIndex, PetBranch.luminous.index);
      expect(inputs.isCalling, isTrue);
      expect(inputs.vitality, 1.0);
      expect(inputs.symmetryClass, 2);
    });
  });
}
