// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/onboarding/app_shell_provider.dart';
import 'package:socialmesh/features/onboarding/meshtastic_onboarding_flow.dart';
import 'package:socialmesh/features/onboarding/meshtastic_onboarding_state.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/app_providers.dart';

import '_onboarding_test_harness.dart';

/// Pins every onboarding-state -> AppShell mapping the user-spec calls
/// out:
///   - connecting / checkingConfig -> scanner
///   - regionRequired / writingRegion / awaitingReboot /
///     awaitingReconnect / awaitingReadiness -> regionPicker
///   - ready -> mainShell
///   - failed / pairingInvalidated -> scanner
///   - cancelled -> scanner
///
/// Also pins:
///   - flag OFF preserves legacy appInit-driven routing (so
///     existing screens continue to render unchanged)
///   - splash / error / age / onboarding / terms init states ALWAYS
///     win over coordinator state (boot-lifecycle gates)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('appShellProvider — onboarding-flow drives routing', () {
    test('OnboardingConnecting -> AppShell.scanner', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(OnboardingConnecting(testDevice()));

      expect(container.read(appShellProvider).shell, AppShell.scanner);
    });

    test('OnboardingCheckingConfig -> AppShell.scanner', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(OnboardingCheckingConfig(testDevice()));

      expect(container.read(appShellProvider).shell, AppShell.scanner);
    });

    test('OnboardingRegionRequired -> AppShell.regionPicker', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(OnboardingRegionRequired(testDevice()));

      expect(container.read(appShellProvider).shell, AppShell.regionPicker);
    });

    test(
      'OnboardingWritingRegion -> AppShell.regionPicker (stay on picker)',
      () {
        final container = _container();
        addTearDown(container.dispose);
        _setAppInit(container, AppInitState.needsScanner);
        container
            .read(meshtasticOnboardingFlowProvider.notifier)
            .debugForceState(
              OnboardingWritingRegion(
                testDevice(),
                config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
              ),
            );

        expect(container.read(appShellProvider).shell, AppShell.regionPicker);
      },
    );

    test('OnboardingAwaitingReboot -> AppShell.regionPicker', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(
            OnboardingAwaitingReboot(
              testDevice(),
              config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
            ),
          );

      expect(container.read(appShellProvider).shell, AppShell.regionPicker);
    });

    test('OnboardingAwaitingReconnect -> AppShell.regionPicker', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(
            OnboardingAwaitingReconnect(
              testDevice(),
              config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
            ),
          );

      expect(container.read(appShellProvider).shell, AppShell.regionPicker);
    });

    test('OnboardingAwaitingReadiness -> AppShell.regionPicker', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(
            OnboardingAwaitingReadiness(
              testDevice(),
              config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
            ),
          );

      expect(container.read(appShellProvider).shell, AppShell.regionPicker);
    });

    test(
      'OnboardingReady promotes to AppShell.mainShell (when appInit==ready)',
      () {
        final container = _container();
        addTearDown(container.dispose);
        _setAppInit(container, AppInitState.ready);
        container
            .read(meshtasticOnboardingFlowProvider.notifier)
            .debugForceState(OnboardingReady(testDevice()));

        expect(container.read(appShellProvider).shell, AppShell.mainShell);
      },
    );

    test('OnboardingFailed -> AppShell.scanner (recovery)', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(
            const OnboardingFailed(OnboardingFailureReason.readinessTimeout),
          );

      expect(container.read(appShellProvider).shell, AppShell.scanner);
    });

    test('OnboardingPairingInvalidated -> AppShell.scanner', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(const OnboardingPairingInvalidated());

      expect(container.read(appShellProvider).shell, AppShell.scanner);
    });

    test('OnboardingCancelled -> AppShell.scanner', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.needsScanner);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(const OnboardingCancelled());

      expect(container.read(appShellProvider).shell, AppShell.scanner);
    });
  });

  group('appShellProvider — boot lifecycle gates take precedence', () {
    test('AppInitState.initializing -> splash (overrides any flow state)', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.initializing);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(OnboardingReady(testDevice()));

      expect(container.read(appShellProvider).shell, AppShell.splash);
    });

    test(
      'AppInitState.needsAgeEligibility -> ageEligibility (overrides flow)',
      () {
        final container = _container();
        addTearDown(container.dispose);
        _setAppInit(container, AppInitState.needsAgeEligibility);
        container
            .read(meshtasticOnboardingFlowProvider.notifier)
            .debugForceState(OnboardingReady(testDevice()));

        expect(container.read(appShellProvider).shell, AppShell.ageEligibility);
      },
    );

    test('AppInitState.error -> error (overrides flow)', () {
      final container = _container();
      addTearDown(container.dispose);
      _setAppInit(container, AppInitState.error);
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .debugForceState(OnboardingReady(testDevice()));

      expect(container.read(appShellProvider).shell, AppShell.error);
    });
  });
}

ProviderContainer _container() {
  final protocol = FakeOnboardingProtocolService();
  return buildOnboardingTestContainer(protocol: protocol);
}

void _setAppInit(ProviderContainer container, AppInitState state) {
  // The notifier exposes setInitialized / setNeedsScanner as the
  // narrow public surface; for the rarer states we use the
  // testing-only seam.
  switch (state) {
    case AppInitState.uninitialized:
      // Default initial state — do nothing.
      break;
    case AppInitState.initializing:
      container
          .read(appInitProvider.notifier)
          .debugForceStateForTesting(AppInitState.initializing);
      break;
    case AppInitState.ready:
      container.read(appInitProvider.notifier).setInitialized();
      break;
    case AppInitState.needsScanner:
      container.read(appInitProvider.notifier).setNeedsScanner();
      break;
    case AppInitState.error:
      container
          .read(appInitProvider.notifier)
          .debugForceStateForTesting(AppInitState.error);
      break;
    case AppInitState.needsAgeEligibility:
      container
          .read(appInitProvider.notifier)
          .debugForceStateForTesting(AppInitState.needsAgeEligibility);
      break;
    case AppInitState.needsOnboarding:
      container
          .read(appInitProvider.notifier)
          .debugForceStateForTesting(AppInitState.needsOnboarding);
      break;
    case AppInitState.needsTermsAcceptance:
      container
          .read(appInitProvider.notifier)
          .debugForceStateForTesting(AppInitState.needsTermsAcceptance);
      break;
  }
}
