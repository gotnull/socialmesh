// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the AppInitNotifier device-connection retry contract:
// - a device-connection init that throws stays retryable on the next
//   initialize() call (a transient failure must not kill auto-reconnect
//   for the whole session),
// - the retry never re-runs the one-time background services pass,
// - an in-flight init is never duplicated by a concurrent initialize(),
// - after a successful init, further initialize() calls do not touch the
//   device-connection notifier again,
// - retries fire only on external initialize() triggers, never a timer.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/legal/age_eligibility_state.dart';
import 'package:socialmesh/core/legal/age_group.dart';
import 'package:socialmesh/core/legal/legal_constants.dart';
import 'package:socialmesh/core/platform/platform_capabilities.dart';
import 'package:socialmesh/core/platform/platform_capabilities_provider.dart';
import 'package:socialmesh/features/automations/automation_providers.dart';
import 'package:socialmesh/features/widget_builder/widget_sync_providers.dart';
import 'package:socialmesh/providers/age_eligibility_provider.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/file_transfer_providers.dart';

class _FakeAgeEligibilityNotifier extends AgeEligibilityNotifier {
  @override
  Future<AgeEligibilityState> build() async => AgeEligibilityState(
    hasConfirmed: true,
    confirmedAt: DateTime.utc(2026, 1, 1),
    policyVersion: LegalConstants.ageEligibilityPolicyVersion,
    ageGroup: AgeGroup.adult,
    source: AgeSource.selfAttestation,
  );
}

class _FakeDeviceConnectionNotifier extends DeviceConnectionNotifier {
  int initializeCalls = 0;
  int startBackgroundCalls = 0;

  /// Number of upcoming initialize() calls that should throw.
  int failuresRemaining = 0;

  /// When set, initialize() parks on this until completed (in-flight test).
  Completer<void>? hang;

  @override
  DeviceConnectionState2 build() =>
      const DeviceConnectionState2(state: DevicePairingState.disconnected);

  @override
  Future<void> initialize() async {
    initializeCalls++;
    final h = hang;
    if (h != null) await h.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('simulated device init failure');
    }
  }

  @override
  Future<void> startBackgroundConnection() async {
    startBackgroundCalls++;
  }
}

Future<void> _pumpUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testCapabilities = PlatformCapabilities(
    platformFamily: PlatformFamily.mobile,
    supportsBle: false,
    supportsTcp: false,
    supportsMqtt: false,
    supportsSerial: false,
    supportsNotifications: false,
    supportsBackgroundLocation: false,
    supportsFileExport: false,
    supportsSecureStorage: false,
    supportsLocalDatabase: false,
    supportsWebBridge: false,
  );

  late _FakeDeviceConnectionNotifier fake;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'last_device_id': 'AA:BB:CC:DD:EE:FF',
      'last_device_type': 'ble',
      'auto_reconnect': true,
    });
    fake = _FakeDeviceConnectionNotifier();
    container = ProviderContainer(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(testCapabilities),
        ageEligibilityProvider.overrideWith(_FakeAgeEligibilityNotifier.new),
        deviceConnectionProvider.overrideWith(() => fake),
        // One-time background services: every init is individually
        // try-caught in production, so throwing overrides make the pass
        // complete immediately instead of hanging on real platform
        // channels that do not exist in the test environment.
        fileTransferEngineProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        messageStorageProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        nodeStorageProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        iftttServiceProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        automationEngineInitProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        automationStoreProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        widgetSqliteStoreProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
        widgetStorageServiceProvider.overrideWith(
          (ref) => throw StateError('test: skipped'),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('failed device-connection init retries on next initialize() without '
      're-running one-time services; success stops further retries', () async {
    final notifier = container.read(appInitProvider.notifier);
    fake.failuresRemaining = 1;

    await notifier.initialize();
    await _pumpUntil(() => fake.initializeCalls == 1);
    // The throw happened before startBackgroundConnection.
    expect(fake.startBackgroundCalls, 0);

    // Second external trigger (e.g. terms acceptance) retries ONLY the
    // device-connection block.
    await notifier.initialize();
    await _pumpUntil(() => fake.initializeCalls == 2);
    await _pumpUntil(() => fake.startBackgroundCalls == 1);

    // Third trigger: init is done, nothing more must reach the notifier.
    await notifier.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      fake.initializeCalls,
      2,
      reason:
          'After a successful device-connection init, initialize() must '
          'not touch the device-connection notifier again. A bump here '
          'also means the one-time background pass re-ran.',
    );
    expect(fake.startBackgroundCalls, 1);
  });

  test('a concurrent initialize() never duplicates an in-flight device '
      'init', () async {
    final notifier = container.read(appInitProvider.notifier);
    fake.failuresRemaining = 1;

    // First pass fails so the retry path is armed.
    await notifier.initialize();
    await _pumpUntil(() => fake.initializeCalls == 1);

    // Park the retry mid-flight, then fire two more external triggers.
    fake.hang = Completer<void>();
    await notifier.initialize();
    await _pumpUntil(() => fake.initializeCalls == 2);
    await notifier.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      fake.initializeCalls,
      2,
      reason: 'The in-flight guard must make an overlapping retry a no-op.',
    );

    // Release the hang; the parked attempt completes successfully.
    fake.hang!.complete();
    fake.hang = null;
    await _pumpUntil(() => fake.startBackgroundCalls == 1);

    // No timer-driven retries: with everything settled, the call count
    // must stay flat without further external triggers.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(fake.initializeCalls, 2);
  });
}
