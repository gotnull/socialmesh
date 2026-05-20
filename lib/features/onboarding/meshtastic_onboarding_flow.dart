// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Single owner of the post-Scanner-tap Meshtastic onboarding flow.
///
/// Replaces the legacy multi-owner choreography
/// (Scanner pushes RegionSelectionScreen, RegionSelection pops itself,
/// RegionConfigNotifier waits for reboot/reconnect/readiness via two
/// competing listeners, Scanner calls `setInitialized` from one of
/// five callsites) with a single declarative state machine.
///
/// Phases (see [MeshtasticOnboardingState]):
///   idle -> connecting -> checkingConfig
///        -> regionRequired -> writingRegion -> awaitingReboot
///        -> awaitingReconnect -> awaitingReadiness -> ready
///
/// Off-paths:
///   - failed(reason)        (typed)
///   - pairingInvalidated    (apple-code 14 routed via existing helper)
///   - cancelled             (user backed out of region picker)
///
/// The coordinator does NOT do BLE work itself: that stays in
/// `Scanner._connectToDevice` and the existing
/// `RestoreSessionCoordinator`. The coordinator listens to the same
/// `deviceConnectionProvider` and `meshtasticReadinessProvider` that
/// the rest of the app already publishes, so onboarding state derives
/// from the canonical wire signals rather than from Scanner-side
/// widget callbacks.
///
/// `appInitProvider.setInitialized()` is called from this file in
/// exactly one place (the ready transition) when the feature flag
/// is on, replacing the five legacy callsites in the onboarding
/// path.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/transport.dart' show DeviceInfo;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../providers/app_providers.dart'
    show AppInitState, appInitProvider, protocolServiceProvider;
import '../../providers/connection_providers.dart'
    show DeviceConnectionState2, DevicePairingState, deviceConnectionProvider;
import '../../services/protocol/protocol_service.dart'
    show OperationalReadiness;
import 'meshtastic_onboarding_state.dart';

/// Per-phase timeout windows. Picked to be generous enough to cover
/// slow firmware (Heltec MeshPocket has been observed taking ~30s
/// for phase-2 on first boot after a region change) but short enough
/// that a wedge surfaces a typed failure within a single user
/// session rather than stranding the UI forever.
@visibleForTesting
class OnboardingFlowTimeouts {
  final Duration regionWrite;
  final Duration awaitReboot;
  final Duration awaitReconnect;
  final Duration awaitReadiness;

  const OnboardingFlowTimeouts({
    this.regionWrite = const Duration(seconds: 30),
    this.awaitReboot = const Duration(seconds: 30),
    this.awaitReconnect = const Duration(seconds: 60),
    this.awaitReadiness = const Duration(seconds: 60),
  });

  static const OnboardingFlowTimeouts defaults = OnboardingFlowTimeouts();
}

/// Coordinator notifier. Riverpod 3.x.
class MeshtasticOnboardingFlow extends Notifier<MeshtasticOnboardingState> {
  /// Generation counter for in-flight phase timeouts. Bumped on every
  /// state transition so a stale timer can no-op when it fires after
  /// the flow has moved past the phase that armed it.
  int _generation = 0;

  /// Active timeout timer for the current phase. Replaced on every
  /// transition that arms one.
  Timer? _phaseTimer;

  /// Direct subscriptions on the protocol's broadcast streams.
  /// The Riverpod-derived `meshtasticReadinessProvider` and
  /// `deviceRegionProvider` are async-derived StreamProviders whose
  /// emission timing relative to a freshly-attached `ref.listen`
  /// callback is unreliable in tests; subscribing directly avoids
  /// the round-trip and keeps the state machine's signal-handling
  /// synchronous with the protocol layer.
  StreamSubscription<OperationalReadiness>? _readinessSub;
  StreamSubscription<config_pbenum.Config_LoRaConfig_RegionCode>? _regionSub;

  /// Test seam: lets a test inject custom timeouts. Defaults to
  /// [OnboardingFlowTimeouts.defaults] in production.
  OnboardingFlowTimeouts _timeouts = OnboardingFlowTimeouts.defaults;

  @visibleForTesting
  void debugSetTimeoutsForTesting(OnboardingFlowTimeouts timeouts) {
    _timeouts = timeouts;
  }

  @override
  MeshtasticOnboardingState build() {
    ref.onDispose(() {
      _phaseTimer?.cancel();
      _phaseTimer = null;
      _readinessSub?.cancel();
      _readinessSub = null;
      _regionSub?.cancel();
      _regionSub = null;
    });

    _attachListeners();

    return const OnboardingIdle();
  }

  /// Wires the canonical signal feeds (transport state + readiness +
  /// device-region stream) into the state machine. Each listener is
  /// pure-observation: it advances state but never calls back into
  /// Scanner / RegionSelection / app routing directly.
  ///
  /// Connection state is taken from the Riverpod notifier (synchronous,
  /// reliable). Readiness and region are subscribed directly to the
  /// protocol's broadcast streams to avoid Riverpod StreamProvider
  /// async-derivation timing edge cases.
  void _attachListeners() {
    ref.listen<DeviceConnectionState2>(deviceConnectionProvider, (
      previous,
      next,
    ) {
      _onDeviceConnectionChanged(previous, next);
    });

    // appInit -> needsScanner is a hard reset signal. It happens on
    // manual disconnect, factory-reset cascade, scanner re-entry
    // from the banner. Whatever flow state we were in is now stale;
    // reset to idle so a re-tap from scanner cleanly transitions
    // OnboardingIdle -> OnboardingConnecting again. Without this
    // reset, `appShellProvider` could see a leftover `OnboardingReady`
    // from the prior session and route the user to MainShell while
    // appInit says "scanner".
    ref.listen<AppInitState>(appInitProvider, (previous, next) {
      AppLogging.connection(
        'ONBOARDING_FLOW: appInit_listener fired '
        'previous=$previous next=$next currentFlow=${state.phase.name}',
      );
      if (next == AppInitState.needsScanner &&
          previous != AppInitState.needsScanner) {
        if (state is OnboardingIdle) return;
        AppLogging.connection(
          'ONBOARDING_FLOW: reset_for_needs_scanner old=${state.phase.name}',
        );
        _transitionTo(const OnboardingIdle(), reason: 'appInit_needsScanner');
      }
    });

    final protocol = ref.read(protocolServiceProvider);
    _readinessSub = protocol.readinessStream.listen((readiness) {
      _onReadinessChanged(readiness);
    });
    _regionSub = protocol.regionStream.listen((region) {
      _onDeviceRegionChanged(region);
    });
  }

  // ---------------------------------------------------------------
  // Public dispatch surface
  // ---------------------------------------------------------------

  /// Scanner tap entry. Records the target identity, transitions to
  /// [OnboardingConnecting], and lets the BLE work happen via the
  /// existing Scanner / DeviceConnectionNotifier pipeline. State
  /// progress is then driven by the listeners above.
  void connect(DeviceInfo device) {
    if (state is OnboardingConnecting &&
        (state as OnboardingConnecting).target.id == device.id) {
      // Already running for this device. Don't bump generation.
      return;
    }
    _transitionTo(OnboardingConnecting(device), reason: 'connect');
  }

  /// Deprecated: this entry point is no longer reachable from
  /// production code. The region picker on MainShell now writes the
  /// region directly via `regionConfigProvider.applyRegion()`, which
  /// owns its own write/reboot/reconnect state machine independently
  /// of this flow. Kept for binary back-compat with any cached
  /// imports; transitions the flow to Failed if anyone still calls
  /// it.
  @Deprecated(
    'Region selection is owned by RegionConfigNotifier.applyRegion, '
    'not by the onboarding flow. This method is dead-end.',
  )
  Future<void> selectRegion(
    config_pbenum.Config_LoRaConfig_RegionCode region,
  ) async {
    AppLogging.connection(
      'ONBOARDING_FLOW: select_region called on deprecated path '
      'region=${region.name} - no-op',
    );
  }

  /// User backed out of the region picker (back gesture / cancel).
  /// Transitions to [OnboardingCancelled] which the appShell mapper
  /// routes back to the scanner.
  void cancel({String reason = 'user'}) {
    if (state is OnboardingIdle || state is OnboardingCancelled) return;
    _transitionTo(const OnboardingCancelled(), reason: 'cancel:$reason');
  }

  /// Test / recovery hook: drop the flow back to idle. Production
  /// callers should prefer [cancel] which logs distinctly.
  @visibleForTesting
  void resetForTesting() {
    _transitionTo(const OnboardingIdle(), reason: 'resetForTesting');
  }

  /// Force-set state for tests that need to drive specific phases
  /// without simulating the full provider graph.
  @visibleForTesting
  void debugForceState(
    MeshtasticOnboardingState forced, {
    String reason = 'debugForce',
  }) {
    _transitionTo(forced, reason: reason);
  }

  // ---------------------------------------------------------------
  // Listener handlers
  // ---------------------------------------------------------------

  void _onDeviceConnectionChanged(
    DeviceConnectionState2? previous,
    DeviceConnectionState2 next,
  ) {
    final current = state;

    // Pairing invalidation overrides every phase. It's terminal and
    // routes to scanner via the existing handler in connection_providers.
    if (next.isTerminalInvalidated) {
      if (current is OnboardingPairingInvalidated ||
          current is OnboardingIdle) {
        return;
      }
      AppLogging.connection(
        'ONBOARDING_FLOW: pairing_invalidated appleCode=n/a',
      );
      _transitionTo(
        const OnboardingPairingInvalidated(),
        reason: 'terminalInvalidated',
      );
      return;
    }

    switch (current) {
      case OnboardingIdle():
      case OnboardingReady():
      case OnboardingFailed():
      case OnboardingPairingInvalidated():
      case OnboardingCancelled():
        return;

      case OnboardingConnecting(:final target):
        // Scanner is doing transport.connect + protocol.start. Once
        // pairing-state hits `connected`, BLE link + protocol bootstrap
        // are done; move into config-check. Two edges count as "the
        // target just landed":
        //   (a) Classic `connecting -> connected`: previous state was
        //       anything other than `connected`.
        //   (b) Device switch: previous state was still `connected`
        //       (to a *different* device) when the user tapped this
        //       target, so `markAsPaired` bumps `connectionSessionId`
        //       but the raw state stays `connected`. Without this
        //       branch the listener wedges - the `prev != connected`
        //       guard never fires and the shell stays on scanner.
        // Both edges require `next.device.id == target.id` so a stale
        // reconnect to an unrelated device cannot accidentally advance
        // the flow.
        final reachedTarget =
            next.state == DevicePairingState.connected &&
            next.device?.id == target.id;
        final stateEdge = previous?.state != DevicePairingState.connected;
        final sessionAdvanced =
            previous?.connectionSessionId != next.connectionSessionId;
        if (reachedTarget && (stateEdge || sessionAdvanced)) {
          _transitionTo(
            OnboardingCheckingConfig(target),
            reason: 'transport_connected',
          );
          // Sync-check the region the moment we land in
          // checkingConfig. The region-stream listener may have
          // already emitted (and Riverpod de-duped) the cached value
          // before we reached this state, so a passive wait on the
          // listener can stall forever in that case.
          _checkRegionForReady(target);
        }
        return;

      case OnboardingCheckingConfig():
      case OnboardingRegionRequired():
        // No connection-arm action: device-region listener owns the
        // regionRequired/ready decision in checkingConfig, and we sit
        // in regionRequired until the user picks. A disconnect here
        // is unexpected and surfaces as a failure.
        if (!next.isConnected && previous?.isConnected == true) {
          AppLogging.connection(
            'ONBOARDING_FLOW: unexpected_disconnect phase=${current.phase.name}',
          );
          _transitionTo(
            const OnboardingFailed(OnboardingFailureReason.connectFailed),
            reason: 'unexpected_disconnect',
          );
        }
        return;

      case OnboardingWritingRegion(:final target, :final region):
      case OnboardingAwaitingReboot(:final target, :final region):
        // Disconnect is *expected* here. Don't surface as failure.
        if (!next.isConnected && previous?.isConnected == true) {
          AppLogging.connection(
            'ONBOARDING_FLOW: expected_reboot_disconnect target=${target.id}',
          );
          _transitionTo(
            OnboardingAwaitingReconnect(target, region),
            reason: 'expected_reboot',
          );
          _armPhaseTimer(_timeouts.awaitReconnect, () {
            if (state is! OnboardingAwaitingReconnect) return;
            AppLogging.connection(
              'ONBOARDING_FLOW: timeout phase=awaitingReconnect',
            );
            _transitionTo(
              const OnboardingFailed(OnboardingFailureReason.reconnectTimeout),
              reason: 'awaitingReconnect_timeout',
            );
          });
        }
        return;

      case OnboardingAwaitingReconnect(:final target, :final region):
        // Wait for transport to come back up AND for the device.id to
        // match the original target. Wrong-device reconnect surfaces
        // as a typed failure.
        if (next.isConnected &&
            next.state == DevicePairingState.connected &&
            previous?.isConnected != true) {
          final reconnectedDeviceId = next.device?.id;
          if (reconnectedDeviceId != null && reconnectedDeviceId != target.id) {
            AppLogging.connection(
              'ONBOARDING_FLOW: wrong_device_connected '
              'expected=${target.id} actual=$reconnectedDeviceId',
            );
            _transitionTo(
              const OnboardingFailed(
                OnboardingFailureReason.wrongDeviceReconnected,
              ),
              reason: 'wrong_device',
            );
            return;
          }
          AppLogging.connection(
            'ONBOARDING_FLOW: reconnect_seen target=${target.id}',
          );
          _transitionTo(
            OnboardingAwaitingReadiness(target, region),
            reason: 'transport_reconnected',
          );
          _armPhaseTimer(_timeouts.awaitReadiness, () {
            if (state is! OnboardingAwaitingReadiness) return;
            AppLogging.connection(
              'ONBOARDING_FLOW: timeout phase=awaitingReadiness',
            );
            _transitionTo(
              const OnboardingFailed(OnboardingFailureReason.readinessTimeout),
              reason: 'awaitingReadiness_timeout',
            );
          });
        }
        return;

      case OnboardingAwaitingReadiness():
        // Readiness arm owns completion. A disconnect here means the
        // post-reboot reconnect failed mid-handshake; let the reconnect
        // mechanics retry. We stay in awaitingReadiness; the readiness
        // timer will catch a hard wedge.
        return;
    }
  }

  void _onReadinessChanged(OperationalReadiness readiness) {
    final current = state;
    if (readiness != OperationalReadiness.ready) return;

    switch (current) {
      case OnboardingCheckingConfig(:final target):
        // Device is fully connected and protocol is ready. If region
        // is non-UNSET, finish. Region-stream listener will close
        // the loop in regionRequired.
        final region = ref.read(protocolServiceProvider).currentRegion;
        if (region == null ||
            region == config_pbenum.Config_LoRaConfig_RegionCode.UNSET) {
          // Region is UNSET; wait for region-stream to confirm and
          // transition to regionRequired there. Don't promote.
          return;
        }
        AppLogging.connection(
          'ONBOARDING_FLOW: ready target=${target.id} '
          'reason=ready_no_region_change',
        );
        _completeReady(target);
        return;
      case OnboardingAwaitingReadiness(:final target):
        AppLogging.connection(
          'ONBOARDING_FLOW: ready target=${target.id} reason=ready_after_reboot',
        );
        _completeReady(target);
        return;
      case OnboardingIdle():
      case OnboardingConnecting():
      case OnboardingRegionRequired():
      case OnboardingWritingRegion():
      case OnboardingAwaitingReboot():
      case OnboardingAwaitingReconnect():
      case OnboardingReady():
      case OnboardingFailed():
      case OnboardingPairingInvalidated():
      case OnboardingCancelled():
        // Diagnostic for "connected but readiness still climbing"
        // is in connectedReadiness handler below; here we only
        // promote when the active state is ready-eligible.
        return;
    }
  }

  void _onDeviceRegionChanged(
    config_pbenum.Config_LoRaConfig_RegionCode region,
  ) {
    final current = state;
    final isUnset = region == config_pbenum.Config_LoRaConfig_RegionCode.UNSET;
    switch (current) {
      case OnboardingCheckingConfig(:final target):
        if (isUnset) {
          AppLogging.connection(
            'ONBOARDING_FLOW: region_required target=${target.id}',
          );
          _transitionTo(
            OnboardingRegionRequired(target),
            reason: 'region_unset',
          );
        } else {
          AppLogging.connection(
            'ONBOARDING_FLOW: ready target=${target.id} '
            'reason=region_already_set',
          );
          _completeReady(target);
        }
        return;
      default:
        return;
    }
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  /// Sync-check the protocol's current region the moment we land in
  /// [OnboardingCheckingConfig]. Riverpod's StreamProvider de-dupes
  /// identical AsyncData emissions, so a region cached on the
  /// protocol service before our listener attached can otherwise
  /// stall the flow.
  void _checkRegionForReady(DeviceInfo target) {
    // The onboarding flow no longer gates ready on the device having a
    // region set. Region selection is handled exclusively by MainShell's
    // inline picker (driven by `needsRegionSetupProvider`), which works
    // identically whether the device was just connected via onboarding
    // or via auto-reconnect. Keeping the regionRequired -> writingRegion
    // -> awaitingReboot -> awaitingReconnect -> awaitingReadiness state
    // chain in the flow caused dual-mount races with MainShell, an
    // ever-growing series of fail-safes, and ultimately a stuck UI.
    // The inline picker covers MainShell's body when region is UNSET,
    // so the user can't bypass it.
    AppLogging.connection(
      'ONBOARDING_FLOW: ready target=${target.id} '
      'reason=ready_inline_picker_handles_region',
    );
    _completeReady(target);
  }

  void _completeReady(DeviceInfo target) {
    _transitionTo(OnboardingReady(target), reason: 'complete_ready');
    // Promote the app router. The single canonical setInitialized
    // call for the onboarding path lives here and only here.
    try {
      ref.read(appInitProvider.notifier).setInitialized();
    } catch (e) {
      AppLogging.connection('ONBOARDING_FLOW: setInitialized_failed err=$e');
    }
  }

  void _transitionTo(MeshtasticOnboardingState next, {required String reason}) {
    final old = state;
    if (identical(old, next)) return;
    if (old.runtimeType == next.runtimeType && old.phase == next.phase) {
      // Same phase, same data class. No-op to suppress duplicate logs
      // when listeners fire repeated events for the same transition.
      return;
    }
    _generation += 1;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    state = next;
    AppLogging.connection(
      'ONBOARDING_FLOW: state ${old.phase.name} -> ${next.phase.name} '
      'reason=$reason gen=$_generation',
    );
  }

  void _armPhaseTimer(Duration duration, void Function() onElapsed) {
    final myGen = _generation;
    _phaseTimer?.cancel();
    _phaseTimer = Timer(duration, () {
      if (myGen != _generation) return;
      onElapsed();
    });
  }
}

/// Riverpod provider for the coordinator. Kept alive for the lifetime
/// of the app — the state machine has terminal states but the user
/// can re-enter onboarding (factory-reset cycle, device replacement)
/// without disposing the underlying signal listeners.
final meshtasticOnboardingFlowProvider =
    NotifierProvider<MeshtasticOnboardingFlow, MeshtasticOnboardingState>(
      MeshtasticOnboardingFlow.new,
    );
