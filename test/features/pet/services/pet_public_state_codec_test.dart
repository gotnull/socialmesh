// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_public_state.dart';
import 'package:socialmesh/features/pet/services/pet_public_state_codec.dart';

PetPublicState _sample({
  int seed = 0xDEADBEEF,
  PetStage stage = PetStage.adult,
  PetBranch branch = PetBranch.luminous,
  PetMood mood = PetMood.content,
  int age = 7,
  bool asleep = false,
  bool sick = false,
  bool calling = false,
  bool evolving = false,
}) {
  return PetPublicState(
    dnaSeed: seed,
    stage: stage,
    branch: branch,
    mood: mood,
    ageInDays: age,
    isAsleep: asleep,
    isSick: sick,
    isCalling: calling,
    isEvolving: evolving,
  );
}

void main() {
  group('PetPublicStateCodec wire format v1', () {
    test('encodes to exactly 8 bytes with schema tag 0x01', () {
      final bytes = PetPublicStateCodec.encode(_sample());
      expect(bytes.length, PetPublicStateCodec.wireLengthV1);
      expect(bytes.length, 8);
      expect(bytes[0], PetPublicStateCodec.schemaTagV1);
    });

    test('round-trips a representative sample', () {
      final state = _sample(
        seed: 0x12345678,
        stage: PetStage.elder,
        branch: PetBranch.volatile,
        mood: PetMood.sleeping,
        age: 42,
        asleep: true,
        sick: false,
        calling: true,
        evolving: false,
      );
      final bytes = PetPublicStateCodec.encode(state);
      final decoded = PetPublicStateCodec.decode(bytes);
      expect(decoded, state);
    });

    test('round-trips 1000 random states with byte length always ≤ 8', () {
      final rng = math.Random(0xC0FFEE);
      for (var i = 0; i < 1000; i++) {
        final state = PetPublicState(
          dnaSeed: rng.nextInt(0xFFFFFFFF),
          stage: PetStage.values[rng.nextInt(PetStage.values.length)],
          branch: PetBranch.values[rng.nextInt(PetBranch.values.length)],
          mood: PetMood.values[rng.nextInt(PetMood.values.length)],
          ageInDays: rng.nextInt(256),
          isAsleep: rng.nextBool(),
          isSick: rng.nextBool(),
          isCalling: rng.nextBool(),
          isEvolving: rng.nextBool(),
        );
        final bytes = PetPublicStateCodec.encode(state);
        expect(bytes.length, lessThanOrEqualTo(8));
        expect(PetPublicStateCodec.decode(bytes), state);
      }
    });

    test('ageInDays saturates at 255', () {
      final state = _sample(age: 9999);
      final bytes = PetPublicStateCodec.encode(state);
      expect(bytes[7], 255);
      final decoded = PetPublicStateCodec.decode(bytes);
      expect(decoded.ageInDays, 255);
    });

    test('flags encode/decode independently', () {
      final combos = [
        (true, false, false, false),
        (false, true, false, false),
        (false, false, true, false),
        (false, false, false, true),
        (true, true, true, true),
      ];
      for (final (asleep, sick, calling, evolving) in combos) {
        final state = _sample(
          asleep: asleep,
          sick: sick,
          calling: calling,
          evolving: evolving,
        );
        final decoded = PetPublicStateCodec.decode(
          PetPublicStateCodec.encode(state),
        );
        expect(decoded.isAsleep, asleep);
        expect(decoded.isSick, sick);
        expect(decoded.isCalling, calling);
        expect(decoded.isEvolving, evolving);
      }
    });

    test('tryDecode returns null on unknown schema tag (does not crash)', () {
      final bad = Uint8List.fromList([0xFF, 0, 0, 0, 0, 0, 0, 0]);
      expect(PetPublicStateCodec.tryDecode(bad), isNull);
    });

    test('tryDecode returns null on short blob', () {
      final bad = Uint8List.fromList([0x01, 0, 0, 0]);
      expect(PetPublicStateCodec.tryDecode(bad), isNull);
    });

    test('decode throws on unknown schema tag', () {
      final bad = Uint8List.fromList([0x02, 0, 0, 0, 0, 0, 0, 0]);
      expect(
        () => PetPublicStateCodec.decode(bad),
        throwsA(isA<PetPublicStateDecodeException>()),
      );
    });

    test('all stage values round-trip', () {
      for (final stage in PetStage.values) {
        final s = _sample(stage: stage);
        expect(
          PetPublicStateCodec.decode(PetPublicStateCodec.encode(s)).stage,
          stage,
        );
      }
    });

    test('all branch values round-trip', () {
      for (final branch in PetBranch.values) {
        final s = _sample(branch: branch);
        expect(
          PetPublicStateCodec.decode(PetPublicStateCodec.encode(s)).branch,
          branch,
        );
      }
    });

    test('all mood values round-trip', () {
      for (final mood in PetMood.values) {
        final s = _sample(mood: mood);
        expect(
          PetPublicStateCodec.decode(PetPublicStateCodec.encode(s)).mood,
          mood,
        );
      }
    });

    test('dnaSeed preserves full 32-bit range', () {
      final seeds = [
        0x00000000,
        0x7FFFFFFF,
        0x80000000,
        0xFFFFFFFF,
        0xABCDEF12,
      ];
      for (final seed in seeds) {
        final s = _sample(seed: seed);
        final decoded = PetPublicStateCodec.decode(
          PetPublicStateCodec.encode(s),
        );
        expect(decoded.dnaSeed, seed);
      }
    });
  });
}
