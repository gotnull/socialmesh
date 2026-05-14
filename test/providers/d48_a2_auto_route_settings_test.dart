// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A2: extends `meshCoreAutoRouteSettingsProvider` with
// `maxRetries` + `retryTimeoutSeconds`. Pinned:
//   - defaults match the value-type constants.
//   - setters persist + reactivate.
//   - clamp ranges: [1, 8] for maxRetries; [3, 30] for
//     retryTimeoutSeconds.
//   - setter is a no-op when the new value equals the current value.
//   - a second container reads back the persisted values on build.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/meshcore_auto_route_settings.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meshCoreAutoRouteSettingsProvider defaults - D48-A2', () {
    test('build() returns documented maxRetries + retryTimeoutSeconds', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final s = c.read(meshCoreAutoRouteSettingsProvider);
      expect(s.maxRetries, MeshCoreAutoRouteSettings.defaultMaxRetries);
      expect(
        s.retryTimeoutSeconds,
        MeshCoreAutoRouteSettings.defaultRetryTimeoutSeconds,
      );
    });
  });

  group('meshCoreAutoRouteSettingsProvider setters - D48-A2', () {
    test('setMaxRetries writes through to SharedPreferences', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(meshCoreAutoRouteSettingsProvider.notifier).setMaxRetries(5);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRetries, 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kMeshCoreAutoRouteMaxRetriesPrefKey), 5);
    });

    test(
      'setRetryTimeoutSeconds writes through to SharedPreferences',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await c
            .read(meshCoreAutoRouteSettingsProvider.notifier)
            .setRetryTimeoutSeconds(15);
        expect(
          c.read(meshCoreAutoRouteSettingsProvider).retryTimeoutSeconds,
          15,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(kMeshCoreAutoRouteRetryTimeoutSecondsPrefKey), 15);
      },
    );

    test('maxRetries clamps to [1, 8]', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      await n.setMaxRetries(99);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRetries, 8);

      await n.setMaxRetries(-5);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRetries, 1);

      await n.setMaxRetries(0);
      expect(c.read(meshCoreAutoRouteSettingsProvider).maxRetries, 1);
    });

    test('retryTimeoutSeconds clamps to [3, 30]', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      await n.setRetryTimeoutSeconds(120);
      expect(c.read(meshCoreAutoRouteSettingsProvider).retryTimeoutSeconds, 30);

      await n.setRetryTimeoutSeconds(0);
      expect(c.read(meshCoreAutoRouteSettingsProvider).retryTimeoutSeconds, 3);
    });

    test('setter is a no-op when the new value equals the current', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(meshCoreAutoRouteSettingsProvider.notifier);

      // Identity write should not touch SharedPreferences.
      await n.setMaxRetries(MeshCoreAutoRouteSettings.defaultMaxRetries);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kMeshCoreAutoRouteMaxRetriesPrefKey), isFalse);
    });
  });

  group('meshCoreAutoRouteSettingsProvider hydration - D48-A2', () {
    test(
      'a second container reads back persisted maxRetries + timeout',
      () async {
        final c1 = ProviderContainer();
        final n1 = c1.read(meshCoreAutoRouteSettingsProvider.notifier);
        await n1.setMaxRetries(6);
        await n1.setRetryTimeoutSeconds(20);
        c1.dispose();

        final c2 = ProviderContainer();
        addTearDown(c2.dispose);
        c2.read(meshCoreAutoRouteSettingsProvider);
        await _settle();
        final s = c2.read(meshCoreAutoRouteSettingsProvider);
        expect(s.maxRetries, 6);
        expect(s.retryTimeoutSeconds, 20);
      },
    );

    test('out-of-range persisted values are clamped on hydration', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kMeshCoreAutoRouteMaxRetriesPrefKey: 999,
        kMeshCoreAutoRouteRetryTimeoutSecondsPrefKey: 999,
      });

      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(meshCoreAutoRouteSettingsProvider);
      await _settle();
      final s = c.read(meshCoreAutoRouteSettingsProvider);
      expect(s.maxRetries, 8);
      expect(s.retryTimeoutSeconds, 30);
    });
  });
}
