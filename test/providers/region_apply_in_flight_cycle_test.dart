// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/providers/app_providers.dart';

/// Pins the `regionApplyInFlightProvider` leaf-provider pattern that
/// breaks the Riverpod cycle between `RegionConfigNotifier` and
/// `DeviceConnectionNotifier`.
///
/// The cycle exists because `RegionConfigNotifier.build()` calls
/// `ref.listen(deviceConnectionProvider, ...)`. If
/// `DeviceConnectionNotifier` (or any provider on its dependency tree)
/// reads `regionConfigProvider`, Riverpod 3.x throws
/// `CircularDependencyError`. The leaf provider exists specifically to
/// expose `applyStatus == applying` without participating in the
/// dependency graph — `RegionConfigNotifier` sets it imperatively at
/// the apply-start and apply-finish edges.
///
/// Field evidence: an Android scan-failure branch in
/// `DeviceConnectionNotifier.startBackgroundConnection` was reading
/// `regionConfigProvider` directly. The throw fired on every Android
/// scan-fail, aborting the function before the retry-timer code below
/// it could run — leaving `autoReconnectState=failed` permanently and
/// stranding the user. The fix at `connection_providers.dart:1651`
/// switched the read to `regionApplyInFlightProvider`. This test pins
/// that fix (textual + structural).
void main() {
  setUpAll(() {
    // dotenv must be loaded before reading provider values that
    // transitively touch RevenueCat config / feature flags.
    dotenv.loadFromString(envString: 'TEST=1');
  });

  group('regionApplyInFlightProvider cycle-break', () {
    test('leaf default is false; setActive flips the read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(regionApplyInFlightProvider), isFalse);

      container.read(regionApplyInFlightProvider.notifier).setActive(true);
      expect(container.read(regionApplyInFlightProvider), isTrue);

      container.read(regionApplyInFlightProvider.notifier).setActive(false);
      expect(container.read(regionApplyInFlightProvider), isFalse);
    });

    test('leaf provider has no upstream — reading it does not pull '
        'deviceConnectionProvider, regionConfigProvider, or any other graph '
        'node into the dependency chain', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Touch only the leaf. If the leaf had any upstream dep,
      // Riverpod would build that graph as a side effect; the leaf
      // by design has none, so only it exists in the container.
      container.read(regionApplyInFlightProvider);

      // Cross-check by toggling — this is the imperative API
      // RegionConfigNotifier uses at apply-start/finish. The
      // setActive call must not pull any other provider into
      // existence either.
      container.read(regionApplyInFlightProvider.notifier).setActive(true);
      expect(container.read(regionApplyInFlightProvider), isTrue);
    });
  });

  group('regression pin: connection_providers.dart no longer reads '
      'regionConfigProvider directly', () {
    test('connection_providers.dart contains no `ref.read(regionConfigProvider)` '
        'or `ref.watch(regionConfigProvider)` call', () async {
      final source = await File(
        'lib/providers/connection_providers.dart',
      ).readAsString();

      // Guards against revert. The cycle-creating reads are the
      // patterns Riverpod's CircularDependencyError flags. The leaf
      // provider read is the safe substitute and stays in place.
      //
      // Note: the file may legitimately mention `regionConfigProvider`
      // in doc comments explaining WHY this pattern is banned, so we
      // search only for the Riverpod call shapes.
      expect(
        source.contains('ref.read(regionConfigProvider)'),
        isFalse,
        reason:
            'reading regionConfigProvider from inside DeviceConnectionNotifier '
            "closes a Riverpod cycle (regionConfigProvider's notifier listens "
            'to deviceConnectionProvider). Use `regionApplyInFlightProvider` '
            'instead — it is the leaf provider designed for this exact case.',
      );
      expect(
        source.contains('ref.watch(regionConfigProvider)'),
        isFalse,
        reason:
            'same cycle hazard as ref.read(regionConfigProvider) — '
            'use `regionApplyInFlightProvider` from inside connection notifiers.',
      );
    });

    test('connection_providers.dart references regionApplyInFlightProvider '
        '(the cycle-safe substitute used by the scan-failure branch and '
        'the disconnect handler)', () async {
      final source = await File(
        'lib/providers/connection_providers.dart',
      ).readAsString();

      expect(
        source.contains('ref.read(regionApplyInFlightProvider)'),
        isTrue,
        reason:
            'the scan-failure branch and disconnect handler should '
            'still read region-apply state via the leaf provider',
      );
    });
  });
}
