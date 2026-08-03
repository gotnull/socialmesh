// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/haptic_service.dart';

void main() {
  group('HapticService.pulsesFor', () {
    test('every type/intensity pair has a non-empty plan', () {
      for (final type in HapticType.values) {
        for (final intensity in HapticIntensity.values) {
          expect(
            HapticService.pulsesFor(type, intensity),
            isNotEmpty,
            reason: '$type at $intensity has no pulses',
          );
        }
      }
    });

    test('Light setting never exceeds lightImpact', () {
      for (final type in HapticType.values) {
        final pulses = HapticService.pulsesFor(type, HapticIntensity.light);
        for (final pulse in pulses) {
          expect(
            pulse.index,
            lessThanOrEqualTo(HapticPrimitive.lightImpact.index),
            reason: '$type at light plays $pulse',
          );
        }
      }
    });

    test('Heavy setting plays heavyImpact for every impact-class event', () {
      for (final type in const [
        HapticType.light,
        HapticType.medium,
        HapticType.heavy,
        HapticType.success,
        HapticType.warning,
        HapticType.error,
      ]) {
        final pulses = HapticService.pulsesFor(type, HapticIntensity.heavy);
        expect(
          pulses,
          contains(HapticPrimitive.heavyImpact),
          reason: '$type at heavy plays $pulses',
        );
      }
    });

    test('Heavy is strictly stronger than Light for every type '
        '(strongest primitive or pulse count increases)', () {
      for (final type in HapticType.values) {
        final light = HapticService.pulsesFor(type, HapticIntensity.light);
        final heavy = HapticService.pulsesFor(type, HapticIntensity.heavy);
        final lightMax = light
            .map((p) => p.index)
            .reduce((a, b) => a > b ? a : b);
        final heavyMax = heavy
            .map((p) => p.index)
            .reduce((a, b) => a > b ? a : b);
        expect(
          heavyMax > lightMax ||
              (heavyMax == lightMax && heavy.length > light.length),
          isTrue,
          reason: '$type: heavy=$heavy is not stronger than light=$light',
        );
      }
    });

    test('mapping table is pinned', () {
      List<HapticPrimitive> plan(HapticType t, HapticIntensity i) =>
          HapticService.pulsesFor(t, i);

      const sc = HapticPrimitive.selectionClick;
      const li = HapticPrimitive.lightImpact;
      const mi = HapticPrimitive.mediumImpact;
      const hi = HapticPrimitive.heavyImpact;

      expect(plan(HapticType.selection, HapticIntensity.light), [sc]);
      expect(plan(HapticType.selection, HapticIntensity.medium), [sc]);
      expect(plan(HapticType.selection, HapticIntensity.heavy), [mi]);

      expect(plan(HapticType.light, HapticIntensity.light), [sc]);
      expect(plan(HapticType.light, HapticIntensity.medium), [li]);
      expect(plan(HapticType.light, HapticIntensity.heavy), [hi]);

      expect(plan(HapticType.medium, HapticIntensity.light), [sc]);
      expect(plan(HapticType.medium, HapticIntensity.medium), [mi]);
      expect(plan(HapticType.medium, HapticIntensity.heavy), [hi]);

      expect(plan(HapticType.heavy, HapticIntensity.light), [li]);
      expect(plan(HapticType.heavy, HapticIntensity.medium), [hi]);
      expect(plan(HapticType.heavy, HapticIntensity.heavy), [hi, hi]);

      expect(plan(HapticType.success, HapticIntensity.light), [li]);
      expect(plan(HapticType.success, HapticIntensity.medium), [mi, li]);
      expect(plan(HapticType.success, HapticIntensity.heavy), [hi, hi]);

      expect(plan(HapticType.warning, HapticIntensity.light), [li, li]);
      expect(plan(HapticType.warning, HapticIntensity.medium), [mi, mi]);
      expect(plan(HapticType.warning, HapticIntensity.heavy), [hi, hi]);

      expect(plan(HapticType.error, HapticIntensity.light), [li, li, li]);
      expect(plan(HapticType.error, HapticIntensity.medium), [mi, mi, mi]);
      expect(plan(HapticType.error, HapticIntensity.heavy), [hi, hi, hi]);
    });

    test('pulse gaps are pinned', () {
      expect(
        HapticService.pulseGapFor(HapticType.warning),
        const Duration(milliseconds: 150),
      );
      for (final type in HapticType.values) {
        if (type == HapticType.warning) continue;
        expect(
          HapticService.pulseGapFor(type),
          const Duration(milliseconds: 100),
        );
      }
    });
  });

  group('HapticIntensity.fromValue', () {
    test('resolves stored values and defaults to medium', () {
      expect(HapticIntensity.fromValue(0), HapticIntensity.light);
      expect(HapticIntensity.fromValue(1), HapticIntensity.medium);
      expect(HapticIntensity.fromValue(2), HapticIntensity.heavy);
      expect(HapticIntensity.fromValue(99), HapticIntensity.medium);
    });
  });
}
