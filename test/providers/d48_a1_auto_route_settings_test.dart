// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A1: `meshCoreAutoRouteSettingsProvider` persistence pins.
//
// Pinned invariants:
//   - build() returns the documented factory defaults.
//   - setEnabled / setMaxRouteWeight / setInitialRouteWeight /
//     setRouteWeightSuccessIncrement / setRouteWeightFailureDecrement
//     each persist to SharedPreferences AND update reactive state.
//   - Range clamping: weights clamp to [0, 10]; increments clamp to
//     [0, 2]. Below-range values clamp to min; above-range to max.
//   - A second container reads back the persisted values on build.
//   - Setter is a no-op when the new value equals the current value
//     (no spurious write).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

Future<void> _settle() async {
  // Allow the microtask in `build()` to land.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meshCoreAutoRouteSettingsProvider defaults - D48-A1', () {
    test('build() returns the factory defaults', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(meshCoreAutoRouteSettingsProvider);
      expect(s.enabled, isFalse);
      expect(s.maxRouteWeight, 5.0);
      expect(s.initialRouteWeight, 3.0);
      expect(s.routeWeightSuccessIncrement, 0.5);
      expect(s.routeWeightFailureDecrement, 0.2);
    });
  });

  group('meshCoreAutoRouteSettingsProvider setters - D48-A1', () {
    test('setEnabled writes through to SharedPreferences', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(meshCoreAutoRouteSettingsProvider.notifier).setEnabled(true);
      expect(c.read(meshCoreAutoRouteSettingsProvider).enabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kMeshCoreAutoRouteEnabledPrefKey), isTrue);
    });

    test('weight setters clamp to [0, 10]', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      await n.setMaxRouteWeight(99.0);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRouteWeight, 10.0);

      await n.setMaxRouteWeight(-3.0);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRouteWeight, 0.0);

      await n.setInitialRouteWeight(8.5);
      expect(c.read(meshCoreAutoRouteSettingsProvider).initialRouteWeight, 8.5);
    });

    test('increment setters clamp to [0, 2]', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      await n.setRouteWeightSuccessIncrement(5.0);
      expect(
        c.read(meshCoreAutoRouteSettingsProvider).routeWeightSuccessIncrement,
        2.0,
      );

      await n.setRouteWeightFailureDecrement(-1.0);
      expect(
        c.read(meshCoreAutoRouteSettingsProvider).routeWeightFailureDecrement,
        0.0,
      );
    });

    test('setter is a no-op when the new value equals the current', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      // Identity setEnabled.
      await n.setEnabled(false);
      final prefs = await SharedPreferences.getInstance();
      // The key was never written by the no-op call.
      expect(prefs.containsKey(kMeshCoreAutoRouteEnabledPrefKey), isFalse);
    });

    test('NaN inputs clamp to min instead of corrupting state', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      await n.setMaxRouteWeight(double.nan);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRouteWeight, 0.0);
      await n.setRouteWeightSuccessIncrement(double.nan);
      expect(
        c.read(meshCoreAutoRouteSettingsProvider).routeWeightSuccessIncrement,
        0.0,
      );
    });
  });

  group('meshCoreAutoRouteSettingsProvider hydration - D48-A1', () {
    test('a second container reads back the persisted values', () async {
      // First container: write values.
      final c1 = ProviderContainer();
      final n1 = c1.read(meshCoreAutoRouteSettingsProvider.notifier);
      await n1.setEnabled(true);
      await n1.setMaxRouteWeight(7.5);
      await n1.setInitialRouteWeight(1.0);
      await n1.setRouteWeightSuccessIncrement(0.75);
      await n1.setRouteWeightFailureDecrement(0.5);
      c1.dispose();

      // Second container: read back via the microtask in build().
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      // Touch the provider to trigger build()'s microtask.
      c2.read(meshCoreAutoRouteSettingsProvider);
      await _settle();
      final s = c2.read(meshCoreAutoRouteSettingsProvider);
      expect(s.enabled, isTrue);
      expect(s.maxRouteWeight, 7.5);
      expect(s.initialRouteWeight, 1.0);
      expect(s.routeWeightSuccessIncrement, 0.75);
      expect(s.routeWeightFailureDecrement, 0.5);
    });

    test('out-of-range persisted values are clamped on hydration', () async {
      // Write a corrupted value directly to SharedPreferences (could
      // happen if a future version stored a wider range and we read
      // it on downgrade).
      SharedPreferences.setMockInitialValues(<String, Object>{
        kMeshCoreAutoRouteMaxWeightPrefKey: 99.0,
        kMeshCoreAutoRouteSuccessIncrementPrefKey: 10.0,
      });

      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(meshCoreAutoRouteSettingsProvider);
      await _settle();
      final s = c.read(meshCoreAutoRouteSettingsProvider);
      expect(s.maxRouteWeight, 10.0);
      expect(s.routeWeightSuccessIncrement, 2.0);
    });
  });
}
