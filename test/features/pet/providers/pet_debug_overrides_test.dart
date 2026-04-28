// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/providers/pet_debug_overrides.dart';

void main() {
  group('PetDebugOverridesNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts empty so every dimension falls back to real state', () {
      final state = container.read(petDebugOverridesProvider);
      expect(state.isAnyOverrideActive, isFalse);
      expect(state.stage, isNull);
      expect(state.branch, isNull);
      expect(state.mood, isNull);
      expect(state.isAsleep, isNull);
      expect(state.isSick, isNull);
      expect(state.callReason, isNull);
      expect(state.preferFrontFace, isNull);
    });

    test('setters update one dimension without touching others', () {
      final notifier = container.read(petDebugOverridesProvider.notifier);
      notifier.setStage(PetStage.adult);
      final state = container.read(petDebugOverridesProvider);
      expect(state.stage, PetStage.adult);
      expect(state.branch, isNull);
      expect(state.isAnyOverrideActive, isTrue);
    });

    test('passing null to a setter clears that dimension back to real', () {
      final notifier = container.read(petDebugOverridesProvider.notifier);
      notifier.setMood(PetMood.sad);
      notifier.setIsSick(true);
      expect(container.read(petDebugOverridesProvider).mood, PetMood.sad);
      notifier.setMood(null);
      final state = container.read(petDebugOverridesProvider);
      expect(state.mood, isNull);
      // Other override still set.
      expect(state.isSick, isTrue);
      expect(state.isAnyOverrideActive, isTrue);
    });

    test('reset wipes every override', () {
      final notifier = container.read(petDebugOverridesProvider.notifier);
      notifier.setStage(PetStage.elder);
      notifier.setBranch(PetBranch.luminous);
      notifier.setCallReason(CallReason.sick);
      notifier.setPreferFrontFace(false);
      expect(
        container.read(petDebugOverridesProvider).isAnyOverrideActive,
        isTrue,
      );
      notifier.reset();
      expect(
        container.read(petDebugOverridesProvider).isAnyOverrideActive,
        isFalse,
      );
    });
  });
}
