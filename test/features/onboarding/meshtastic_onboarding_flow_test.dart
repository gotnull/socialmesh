// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/onboarding/meshtastic_onboarding_flow.dart';
import 'package:socialmesh/features/onboarding/meshtastic_onboarding_state.dart';
import 'package:socialmesh/providers/connection_providers.dart';

import '_onboarding_test_harness.dart';

/// Drives the [MeshtasticOnboardingFlow] state machine via the
/// canonical signal feeds (deviceConnectionProvider) and asserts the
/// remaining transitions.
///
/// History: this file used to assert a deeper state machine that
/// included regionRequired / writingRegion / awaitingReboot /
/// awaitingReconnect / awaitingReadiness phases. Those phases were
/// retired when region selection moved entirely to MainShell's inline
/// picker (driven by `needsRegionSetupProvider` +
/// `RegionConfigNotifier.applyRegion`). The flow now collapses to
/// `idle -> connecting -> checkingConfig -> ready` plus the failure /
/// invalidation / cancellation terminals - so the test surface is
/// correspondingly smaller.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('connect -> connecting carries the target device identity', () async {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice();
    container.read(meshtasticOnboardingFlowProvider.notifier).connect(device);

    final state = container.read(meshtasticOnboardingFlowProvider);
    expect(state, isA<OnboardingConnecting>());
    expect((state as OnboardingConnecting).target.id, device.id);
  });

  test(
    'transport connected advances connecting -> checkingConfig -> ready',
    () async {
      // The flow now skips the regionRequired path entirely. Whether
      // the device's region is UNSET or set, checkingConfig promotes
      // straight to OnboardingReady. The inline picker on MainShell
      // (driven by `needsRegionSetupProvider`) handles UNSET devices.
      final protocol = FakeOnboardingProtocolService();
      final container = buildOnboardingTestContainer(protocol: protocol);
      addTearDown(container.dispose);

      final device = testDevice();
      container.read(meshtasticOnboardingFlowProvider.notifier).connect(device);
      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: device,
      );
      await pumpMicrotasks();

      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingReady>(),
        reason:
            'transport connected + checkingConfig must promote directly '
            'to ready regardless of device region, since the inline '
            'picker on MainShell now owns region selection.',
      );
    },
  );

  test(
    'device switch: prev=connected (other device) -> next=connected (target) '
    'advances the flow via connectionSessionId edge',
    () async {
      // Regression: a user disconnecting from device A while device B was
      // also still recorded as `connected` would leave the
      // OnboardingConnecting listener wedged. The state-edge guard
      // `previous.state != connected` blocks because both prev and next
      // are `connected`, so the session-id advance is the only signal
      // that the target just landed. Without that branch the user gets
      // stuck on Scanner indefinitely.
      final protocol = FakeOnboardingProtocolService();
      final container = buildOnboardingTestContainer(protocol: protocol);
      addTearDown(container.dispose);

      // Seed the deviceConnectionProvider as already-connected to a
      // prior device (simulates a stale auto-reconnect that landed
      // before the user tapped a different target).
      final priorDevice = testDevice(id: 'prior-device');
      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: priorDevice,
        sessionId: 1,
      );
      await pumpMicrotasks();

      // User taps the new target.
      final newTarget = testDevice(id: 'new-target');
      container
          .read(meshtasticOnboardingFlowProvider.notifier)
          .connect(newTarget);

      // markAsPaired for the new target bumps sessionId but raw state
      // stays `connected`.
      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: newTarget,
        sessionId: 2,
      );
      await pumpMicrotasks();

      // Flow now promotes to ready directly (no region detour).
      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingReady>(),
        reason:
            'Device switch with prev=connected (other device) and next='
            "connected (target) must advance via the connectionSessionId "
            "edge so the flow does not wedge on Scanner.",
      );
    },
  );

  test('session edge guard requires next.device.id matches target', () async {
    // Negative case: even if connectionSessionId advances, the flow
    // must NOT advance when next.device.id is a different device. A
    // background reconnect to an unrelated device cannot accidentally
    // pull a manual-connect flow forward.
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final target = testDevice(id: 'tapped-target');
    container.read(meshtasticOnboardingFlowProvider.notifier).connect(target);

    // sessionId advances but device.id does not match target.
    final otherDevice = testDevice(id: 'unrelated');
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: otherDevice,
      sessionId: 7,
    );
    await pumpMicrotasks();

    expect(
      container.read(meshtasticOnboardingFlowProvider),
      isA<OnboardingConnecting>(),
      reason:
          'A connected event for an unrelated device must not advance '
          'the manual-connect flow even when the session id changes.',
    );
  });

  test(
    'pairing-invalidated mid-flow transitions to OnboardingPairingInvalidated',
    () async {
      final protocol = FakeOnboardingProtocolService();
      final container = buildOnboardingTestContainer(protocol: protocol);
      addTearDown(container.dispose);

      final device = testDevice();
      final notifier = container.read(
        meshtasticOnboardingFlowProvider.notifier,
      );
      notifier.connect(device);
      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: device,
      );
      await pumpMicrotasks();

      // Apple-code-14-style invalidation surfaces via the pairing
      // state. The connection notifier flips into terminal state.
      setConnectionState(
        container,
        state: DevicePairingState.disconnected,
        device: device,
        isInvalidated: true,
      );
      await pumpMicrotasks();

      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingPairingInvalidated>(),
      );
    },
  );

  test(
    'connect to a second device while still connecting to the first '
    'retargets the flow, and the second device promotes it to ready',
    () async {
      // A failed attempt leaves the flow in connecting for its device. A
      // later tap on another radio must take over the target, or that
      // radio connects behind the overlay and the flow never leaves
      // connecting.
      final protocol = FakeOnboardingProtocolService();
      final container = buildOnboardingTestContainer(protocol: protocol);
      addTearDown(container.dispose);

      final notifier = container.read(
        meshtasticOnboardingFlowProvider.notifier,
      );
      notifier.connect(testDevice(id: 'first-radio'));
      final second = testDevice(id: 'second-radio');
      notifier.connect(second);

      final retargeted = container.read(meshtasticOnboardingFlowProvider);
      expect(retargeted, isA<OnboardingConnecting>());
      expect((retargeted as OnboardingConnecting).target.id, second.id);

      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: second,
      );
      await pumpMicrotasks();

      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingReady>(),
      );
    },
  );

  test('connectFailed for the target ends the attempt as connectFailed', () {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice();
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    notifier.connectFailed(device, detail: 'TimeoutException');

    final state = container.read(meshtasticOnboardingFlowProvider);
    expect(state, isA<OnboardingFailed>());
    expect(
      (state as OnboardingFailed).reason,
      OnboardingFailureReason.connectFailed,
    );
    expect(state.detail, 'TimeoutException');
  });

  test('connectFailed for an older radio leaves a retargeted flow alone', () {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    final older = testDevice(id: 'older-radio');
    final newer = testDevice(id: 'newer-radio');
    notifier.connect(older);
    notifier.connect(newer);
    notifier.connectFailed(older);

    final state = container.read(meshtasticOnboardingFlowProvider);
    expect(state, isA<OnboardingConnecting>());
    expect((state as OnboardingConnecting).target.id, newer.id);
  });

  test('connectFailed outside connecting does nothing', () {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    container
        .read(meshtasticOnboardingFlowProvider.notifier)
        .connectFailed(testDevice());

    expect(
      container.read(meshtasticOnboardingFlowProvider),
      isA<OnboardingIdle>(),
    );
  });

  test('cancel() while connecting transitions to cancelled', () async {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice();
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    await pumpMicrotasks();

    notifier.cancel();
    expect(
      container.read(meshtasticOnboardingFlowProvider),
      isA<OnboardingCancelled>(),
    );
  });

  test('every terminal state reports isTerminal=true', () {
    expect(const OnboardingIdle().isTerminal, isFalse);
    expect(OnboardingConnecting(testDevice()).isTerminal, isFalse);
    expect(OnboardingReady(testDevice()).isTerminal, isTrue);
    expect(
      const OnboardingFailed(OnboardingFailureReason.connectFailed).isTerminal,
      isTrue,
    );
    expect(const OnboardingPairingInvalidated().isTerminal, isTrue);
    expect(const OnboardingCancelled().isTerminal, isTrue);
  });
}
