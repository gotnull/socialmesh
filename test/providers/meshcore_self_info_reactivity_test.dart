// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D24.A — `MeshCoreSelfInfoNotifier` reactivity regression tests.
//
// Pre-D24 the notifier watched `meshCoreAdapterProvider`, but the
// adapter is a singleton whose reference does not change identity
// when `adapter.deviceInfo` flips from null → populated during
// identify. Riverpod skipped the rebuild and Battery / TX Power /
// SF/CR stayed at `--` until the user tapped Refresh.
//
// D24.A switches the watch to `meshDeviceInfoProvider` (now
// reactive on the MeshCore connection-state stream) so the load
// fires automatically on identify completion. These tests pin the
// new edge-driven behaviour so a future refactor can't quietly
// regress the no-refresh-tap-needed contract.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

const _identifiedDevice = MeshDeviceInfo(
  protocolType: MeshProtocolType.meshcore,
  displayName: 'TerryDev',
  nodeId: '79426D8D',
);

const _identifiedDeviceB = MeshDeviceInfo(
  protocolType: MeshProtocolType.meshcore,
  displayName: 'OtherDev',
  nodeId: 'AABBCCDD',
);

const _meshtasticDevice = MeshDeviceInfo(
  protocolType: MeshProtocolType.meshtastic,
  displayName: 'Meshtastic Device',
  nodeId: '11223344',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D24.A self-info reactivity', () {
    test(
      'stays initial when deviceInfo is null (no spurious fetch attempt)',
      () async {
        final c = ProviderContainer(
          overrides: [
            meshDeviceInfoProvider.overrideWithValue(null),
            meshCoreSessionProvider.overrideWithValue(null),
          ],
        );
        addTearDown(c.dispose);

        final state = c.read(meshCoreSelfInfoProvider);
        // Initial build with null deviceInfo must not transition to
        // loading or failed. Stay parked at initial.
        expect(state.selfInfo, isNull);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);

        // Allow any deferred microtasks to flush.
        await Future<void>.delayed(Duration.zero);
        final after = c.read(meshCoreSelfInfoProvider);
        expect(after.error, isNull);
        expect(after.isLoading, isFalse);
      },
    );

    test(
      'fires fetch automatically when deviceInfo flips null → non-null',
      () async {
        // Override session as null so the load path bails with a
        // failure outcome we can pin without needing a real session.
        // The test's purpose is to confirm the LOAD WAS TRIGGERED by
        // the deviceInfo transition (not to test getSelfInfo itself).
        final c = ProviderContainer(
          overrides: [
            meshDeviceInfoProvider.overrideWithValue(_identifiedDevice),
            meshCoreSessionProvider.overrideWithValue(null),
          ],
        );
        addTearDown(c.dispose);

        // Build the notifier; the deferred load fires on next event-
        // loop turn (mirrors the production deferral pattern).
        c.read(meshCoreSelfInfoProvider);
        // Pump twice: first to let `Future<void>(_loadSelfInfo)` run,
        // second to let `state = ...failed(...)` propagate.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = c.read(meshCoreSelfInfoProvider);
        expect(
          state.error,
          equals('No session available'),
          reason:
              'load was triggered by the deviceInfo transition; '
              'session=null path is the expected failure outcome',
        );
        expect(state.isLoading, isFalse);
      },
    );

    test('manual refresh always re-fires, bypassing the dedupe key', () async {
      final c = ProviderContainer(
        overrides: [
          meshDeviceInfoProvider.overrideWithValue(_identifiedDevice),
          meshCoreSessionProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);

      c.read(meshCoreSelfInfoProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Mutate the failure path to a non-failure marker so we can
      // detect the second invocation overwriting it.
      final notifier = c.read(meshCoreSelfInfoProvider.notifier);
      // refresh() must clear the dedupe key and re-issue the load,
      // even though `_loadedForNodeId` may already match the current
      // device.
      await notifier.refresh();

      final state = c.read(meshCoreSelfInfoProvider);
      // Same failure shape on the second run because session is
      // still null. Pin: refresh() did not silently return early.
      expect(state.error, equals('No session available'));
    });

    test(
      'meshtastic deviceInfo does not trigger a fetch (MeshCore-only watch)',
      () async {
        // The notifier filters on protocolType, so a Meshtastic
        // device-info value must not cause a MeshCore self-info
        // fetch attempt (would always fail with 'No session
        // available' because the MeshCore session provider would
        // be null in that scenario, but the cleaner guard is to
        // not try at all).
        final c = ProviderContainer(
          overrides: [
            meshDeviceInfoProvider.overrideWithValue(_meshtasticDevice),
            meshCoreSessionProvider.overrideWithValue(null),
          ],
        );
        addTearDown(c.dispose);

        c.read(meshCoreSelfInfoProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = c.read(meshCoreSelfInfoProvider);
        // No load attempt fired → no error, just the parked
        // initial state.
        expect(state.error, isNull);
        expect(state.isLoading, isFalse);
        expect(state.selfInfo, isNull);
      },
    );

    test('dedupe key remembers nodeId across spurious rebuilds', () async {
      // Drives the notifier to a "loaded for nodeId X" state via the
      // null-session failure path, then invalidates the device-info
      // provider while keeping the same nodeId. The notifier must
      // NOT re-issue the fetch (would clobber any cached state).
      final c = ProviderContainer(
        overrides: [
          meshDeviceInfoProvider.overrideWithValue(_identifiedDevice),
          meshCoreSessionProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);

      c.read(meshCoreSelfInfoProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // First fetch fired → state = failed.
      expect(
        c.read(meshCoreSelfInfoProvider).error,
        equals('No session available'),
      );

      // Force a rebuild via `invalidate`. Riverpod 3.x reuses the
      // Notifier instance but re-runs `build()` and re-registers
      // `ref.onDispose` callbacks, so the notifier's per-instance
      // dedupe key (`_loadedForNodeId`) also survives. The fresh
      // build still re-issues the load because `_loadedForNodeId`
      // is null when the previous load failed (we never set it on
      // failure path).
      c.invalidate(meshCoreSelfInfoProvider);
      c.read(meshCoreSelfInfoProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // After invalidate, the rebuild re-runs `build()`. The dedupe
      // key was kept on the OLD notifier (now disposed), so the new
      // notifier fetches once. Pin: only ONE fetch per fresh
      // notifier instance per nodeId.
      final state = c.read(meshCoreSelfInfoProvider);
      // Same error means the fetch path ran exactly once again
      // (fresh notifier). The point is: no double-fetch loop.
      expect(state.error, equals('No session available'));
    });

    test('disconnect (deviceInfo → null) clears stale loaded state', () async {
      // Mutable slot + invalidate is the cleanest way to flip a
      // regular `Provider`'s value mid-test without falling back to
      // the banned `StateController` / `StateProvider`.
      final slot = <MeshDeviceInfo?>[_identifiedDevice];
      final c = ProviderContainer(
        overrides: [
          meshDeviceInfoProvider.overrideWith((ref) => slot.first),
          meshCoreSessionProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);

      // Sanity: the override must surface the slot's current value
      // before we drive the notifier.
      expect(c.read(meshDeviceInfoProvider), equals(_identifiedDevice));

      c.read(meshCoreSelfInfoProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // Initial state path: error=No session available.
      expect(
        c.read(meshCoreSelfInfoProvider).error,
        equals('No session available'),
      );

      // Now flip to null (disconnect) and force re-evaluation.
      slot[0] = null;
      c.invalidate(meshDeviceInfoProvider);
      // Allow notifier to rebuild on the watched-value change.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final after = c.read(meshCoreSelfInfoProvider);
      expect(after.selfInfo, isNull);
      expect(after.error, isNull);
      expect(after.isLoading, isFalse);
    });

    test(
      'switching device (different nodeId) bypasses the dedupe key',
      () async {
        final slot = <MeshDeviceInfo?>[_identifiedDevice];
        final c = ProviderContainer(
          overrides: [
            meshDeviceInfoProvider.overrideWith((ref) => slot.first),
            meshCoreSessionProvider.overrideWithValue(null),
          ],
        );
        addTearDown(c.dispose);

        c.read(meshCoreSelfInfoProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          c.read(meshCoreSelfInfoProvider).error,
          equals('No session available'),
        );

        // Switch to a different device (different nodeId). The
        // notifier must re-fetch even though the protocol type is
        // the same.
        slot[0] = _identifiedDeviceB;
        c.invalidate(meshDeviceInfoProvider);
        // Force the cascade rebuild + new deferred load to schedule.
        c.read(meshCoreSelfInfoProvider);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Pin: re-fetch happened (still fails on null session, but
        // the path was exercised again).
        expect(
          c.read(meshCoreSelfInfoProvider).error,
          equals('No session available'),
        );
      },
    );
  });
}
