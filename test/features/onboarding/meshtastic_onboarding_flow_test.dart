// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/onboarding/meshtastic_onboarding_flow.dart';
import 'package:socialmesh/features/onboarding/meshtastic_onboarding_state.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

import '_onboarding_test_harness.dart';

/// Drives the [MeshtasticOnboardingFlow] state machine via the
/// canonical signal feeds (deviceConnectionProvider +
/// meshtasticReadinessProvider + deviceRegionProvider) and asserts
/// every documented transition. These tests are the single
/// authoritative pinning of the coordinator's behaviour; if any
/// future patch breaks one of them, the regression is in scope of
/// the recon-report contract approved at design time.
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
    'transport connected transitions connecting -> checkingConfig',
    () async {
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
        isA<OnboardingCheckingConfig>(),
      );
    },
  );

  test('UNSET region during checkingConfig -> regionRequired', () async {
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
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await pumpMicrotasks();

    expect(
      container.read(meshtasticOnboardingFlowProvider),
      isA<OnboardingRegionRequired>(),
    );
  });

  test('non-UNSET region during checkingConfig -> ready (no reboot)', () async {
    final protocol = FakeOnboardingProtocolService(
      initialRegion: config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
    );
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
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);
    await pumpMicrotasks();

    expect(
      container.read(meshtasticOnboardingFlowProvider),
      isA<OnboardingReady>(),
    );
  });

  test(
    'selectRegion transitions regionRequired -> writingRegion -> awaitingReboot',
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
      protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
      await pumpMicrotasks();

      final selectFuture = notifier.selectRegion(
        config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
      );
      // After dispatch but before await completes, state is
      // writingRegion. setRegion is awaited internally, so let
      // microtasks drain.
      await selectFuture;
      expect(protocol.setRegionCallCount, 1);

      // After setRegion resolves, coordinator has moved on to
      // awaitingReboot.
      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingAwaitingReboot>(),
      );
    },
  );

  test(
    'expected reboot disconnect transitions awaitingReboot -> awaitingReconnect',
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
      protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
      await pumpMicrotasks();
      await notifier.selectRegion(
        config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
      );

      // Simulate the device reboot: disconnect.
      setConnectionState(
        container,
        state: DevicePairingState.disconnected,
        device: device,
      );
      await pumpMicrotasks();

      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingAwaitingReconnect>(),
      );
    },
  );

  test(
    'reconnect to same device transitions awaitingReconnect -> awaitingReadiness',
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
      protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
      await pumpMicrotasks();
      await notifier.selectRegion(
        config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
      );

      // Reboot disconnect.
      setConnectionState(
        container,
        state: DevicePairingState.disconnected,
        device: device,
      );
      await pumpMicrotasks();

      // Reconnect with same id. Bump session id so the listener
      // sees a fresh transition into connected.
      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: device,
        sessionId: 2,
      );
      await pumpMicrotasks();

      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingAwaitingReadiness>(),
      );
    },
  );

  test(
    'connected_then_phase2 (transport up but readiness still phase2) does NOT promote',
    () async {
      // Regression pin for the stuck-MainShell bug: connection arm
      // sees `connected` but readiness is still climbing. The
      // coordinator must NOT call setInitialized at this point.
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
      protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
      await pumpMicrotasks();
      await notifier.selectRegion(
        config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
      );
      setConnectionState(
        container,
        state: DevicePairingState.disconnected,
        device: device,
      );
      await pumpMicrotasks();
      setConnectionState(
        container,
        state: DevicePairingState.connected,
        device: device,
        sessionId: 2,
      );
      await pumpMicrotasks();

      // Coordinator is awaitingReadiness. Readiness is still phase2;
      // emit phase2 explicitly via the protocol's internal control —
      // the state machine should not promote.
      protocol.debugForceReadinessForTesting(
        OperationalReadiness.handshakePhase2,
      );
      await pumpMicrotasks();

      expect(
        container.read(meshtasticOnboardingFlowProvider),
        isA<OnboardingAwaitingReadiness>(),
      );
    },
  );

  test('readiness ready transitions awaitingReadiness -> ready', () async {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice();
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
    );
    await pumpMicrotasks();
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await pumpMicrotasks();
    await notifier.selectRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);
    setConnectionState(
      container,
      state: DevicePairingState.disconnected,
      device: device,
    );
    await pumpMicrotasks();
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
      sessionId: 2,
    );
    await pumpMicrotasks();

    protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await pumpMicrotasks();

    expect(
      container.read(meshtasticOnboardingFlowProvider),
      isA<OnboardingReady>(),
    );
  });

  test('wrong-device reconnect surfaces wrongDeviceReconnected', () async {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice(id: 'device-alpha');
    final other = testDevice(id: 'device-beta');
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
    );
    await pumpMicrotasks();
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await pumpMicrotasks();
    await notifier.selectRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);

    setConnectionState(
      container,
      state: DevicePairingState.disconnected,
      device: device,
    );
    await pumpMicrotasks();

    // Reconnect with a DIFFERENT device. Should fail typed.
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: other,
      sessionId: 2,
    );
    await pumpMicrotasks();

    final state = container.read(meshtasticOnboardingFlowProvider);
    expect(state, isA<OnboardingFailed>());
    expect(
      (state as OnboardingFailed).reason,
      OnboardingFailureReason.wrongDeviceReconnected,
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

  test('readiness timeout surfaces failed(readinessTimeout)', () async {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(
      protocol: protocol,
      timeouts: const OnboardingFlowTimeouts(
        regionWrite: Duration(seconds: 30),
        awaitReboot: Duration(seconds: 30),
        awaitReconnect: Duration(seconds: 60),
        awaitReadiness: Duration(milliseconds: 50),
      ),
    );
    addTearDown(container.dispose);

    final device = testDevice();
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
    );
    await pumpMicrotasks();
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await pumpMicrotasks();
    await notifier.selectRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);
    setConnectionState(
      container,
      state: DevicePairingState.disconnected,
      device: device,
    );
    await pumpMicrotasks();
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
      sessionId: 2,
    );
    await pumpMicrotasks();

    // Readiness never reaches ready. Wait past the test-injected
    // 50 ms timeout.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = container.read(meshtasticOnboardingFlowProvider);
    expect(state, isA<OnboardingFailed>());
    expect(
      (state as OnboardingFailed).reason,
      OnboardingFailureReason.readinessTimeout,
    );
  });

  test('regionWrite throws -> failed(regionWriteFailed)', () async {
    final protocol = FakeOnboardingProtocolService()
      ..setRegionShouldThrow = true;
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice();
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
    );
    await pumpMicrotasks();
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
    await pumpMicrotasks();
    await notifier.selectRegion(config_pbenum.Config_LoRaConfig_RegionCode.ANZ);

    final state = container.read(meshtasticOnboardingFlowProvider);
    expect(state, isA<OnboardingFailed>());
    expect(
      (state as OnboardingFailed).reason,
      OnboardingFailureReason.regionWriteFailed,
    );
  });

  test('cancel() while regionRequired transitions to cancelled', () async {
    final protocol = FakeOnboardingProtocolService();
    final container = buildOnboardingTestContainer(protocol: protocol);
    addTearDown(container.dispose);

    final device = testDevice();
    final notifier = container.read(meshtasticOnboardingFlowProvider.notifier);
    notifier.connect(device);
    setConnectionState(
      container,
      state: DevicePairingState.connected,
      device: device,
    );
    await pumpMicrotasks();
    protocol.emitRegion(config_pbenum.Config_LoRaConfig_RegionCode.UNSET);
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

  test(
    'every reboot-window state reports expectingTransportDisconnect=true',
    () {
      expect(
        OnboardingWritingRegion(
          testDevice(),
          config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
        ).expectingTransportDisconnect,
        isTrue,
      );
      expect(
        OnboardingAwaitingReboot(
          testDevice(),
          config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
        ).expectingTransportDisconnect,
        isTrue,
      );
      expect(
        OnboardingAwaitingReconnect(
          testDevice(),
          config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
        ).expectingTransportDisconnect,
        isTrue,
      );
      expect(
        OnboardingAwaitingReadiness(
          testDevice(),
          config_pbenum.Config_LoRaConfig_RegionCode.ANZ,
        ).expectingTransportDisconnect,
        isTrue,
      );
      expect(const OnboardingIdle().expectingTransportDisconnect, isFalse);
      expect(
        OnboardingConnecting(testDevice()).expectingTransportDisconnect,
        isFalse,
      );
    },
  );
}
