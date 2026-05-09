// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Sealed state machine for the post-Scanner-tap Meshtastic onboarding
/// flow. The ordered phases are:
///
///   idle
///     -> connecting          (user tapped a device)
///     -> checkingConfig      (BLE link up, protocol started)
///     -> regionRequired      (device reports region UNSET)
///     -> writingRegion       (user picked a region; setRegion sent)
///     -> awaitingReboot      (transport disconnect observed; expected)
///     -> awaitingReconnect   (transport coming back; auto-reconnect runs)
///     -> awaitingReadiness   (link back up; protocol re-handshaking)
///     -> ready               (OperationalReadiness.ready -- promote to MainShell)
///
/// Terminal off-paths:
///   - failed(reason)          (typed failure)
///   - pairingInvalidated      (apple-code 14 / bond removed)
///   - cancelled               (user backed out of region picker, etc.)
///
/// Each non-idle state carries the identity of the device the flow
/// was initiated against so a wrong-device reconnect after a reboot
/// can be detected and surfaced as `failed(wrongDeviceReconnected)`.
/// `writingRegion` and beyond also carry the selected region so that
/// post-reboot verification can match the device's reported region
/// against what the user picked.
library;

import 'package:flutter/foundation.dart';

import '../../core/transport.dart' show DeviceInfo;
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;

/// Discriminator enum used by tests and the appShell mapper. Mirrors
/// the sealed-class hierarchy 1:1 so consumers can pattern-match
/// without runtime type checks.
enum MeshtasticOnboardingPhase {
  idle,
  connecting,
  checkingConfig,
  regionRequired,
  writingRegion,
  awaitingReboot,
  awaitingReconnect,
  awaitingReadiness,
  ready,
  failed,
  pairingInvalidated,
  cancelled,
}

/// Typed failure modes for [OnboardingFailed]. Each maps to a
/// distinct user-facing recovery affordance.
enum OnboardingFailureReason {
  /// Initial transport.connect / protocol.start did not complete.
  connectFailed,

  /// `protocol.setRegion` failed at the wire level.
  regionWriteFailed,

  /// Device did not disconnect after region write within the
  /// expected reboot window. Likely the firmware ignored the write
  /// or the transport was in a wedged state.
  rebootTimeout,

  /// Transport never came back after the expected reboot.
  reconnectTimeout,

  /// Reconnect happened but readiness never reached `ready`.
  readinessTimeout,

  /// Reconnect picked a different device than the flow targets.
  wrongDeviceReconnected,
}

/// Base type for the onboarding state machine.
@immutable
sealed class MeshtasticOnboardingState {
  const MeshtasticOnboardingState();

  MeshtasticOnboardingPhase get phase;

  /// True when the state machine is in a phase where a transport
  /// disconnect is *expected* (because we just told the device to
  /// reboot for region apply). Consumers use this to suppress the
  /// "unexpected disconnect" UX during the reboot window.
  bool get expectingTransportDisconnect =>
      phase == MeshtasticOnboardingPhase.writingRegion ||
      phase == MeshtasticOnboardingPhase.awaitingReboot ||
      phase == MeshtasticOnboardingPhase.awaitingReconnect ||
      phase == MeshtasticOnboardingPhase.awaitingReadiness;

  /// True when the state machine is in a terminal state. Scanner uses
  /// this to ensure its `_connecting` overlay is cleared regardless
  /// of which terminal arm fired.
  bool get isTerminal =>
      phase == MeshtasticOnboardingPhase.ready ||
      phase == MeshtasticOnboardingPhase.failed ||
      phase == MeshtasticOnboardingPhase.pairingInvalidated ||
      phase == MeshtasticOnboardingPhase.cancelled;
}

class OnboardingIdle extends MeshtasticOnboardingState {
  const OnboardingIdle();
  @override
  MeshtasticOnboardingPhase get phase => MeshtasticOnboardingPhase.idle;
}

class OnboardingConnecting extends MeshtasticOnboardingState {
  final DeviceInfo target;
  const OnboardingConnecting(this.target);
  @override
  MeshtasticOnboardingPhase get phase => MeshtasticOnboardingPhase.connecting;
}

class OnboardingCheckingConfig extends MeshtasticOnboardingState {
  final DeviceInfo target;
  const OnboardingCheckingConfig(this.target);
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.checkingConfig;
}

class OnboardingRegionRequired extends MeshtasticOnboardingState {
  final DeviceInfo target;
  const OnboardingRegionRequired(this.target);
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.regionRequired;
}

class OnboardingWritingRegion extends MeshtasticOnboardingState {
  final DeviceInfo target;
  final config_pbenum.Config_LoRaConfig_RegionCode region;
  const OnboardingWritingRegion(this.target, this.region);
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.writingRegion;
}

class OnboardingAwaitingReboot extends MeshtasticOnboardingState {
  final DeviceInfo target;
  final config_pbenum.Config_LoRaConfig_RegionCode region;
  const OnboardingAwaitingReboot(this.target, this.region);
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.awaitingReboot;
}

class OnboardingAwaitingReconnect extends MeshtasticOnboardingState {
  final DeviceInfo target;
  final config_pbenum.Config_LoRaConfig_RegionCode region;
  const OnboardingAwaitingReconnect(this.target, this.region);
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.awaitingReconnect;
}

class OnboardingAwaitingReadiness extends MeshtasticOnboardingState {
  final DeviceInfo target;
  final config_pbenum.Config_LoRaConfig_RegionCode region;
  const OnboardingAwaitingReadiness(this.target, this.region);
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.awaitingReadiness;
}

class OnboardingReady extends MeshtasticOnboardingState {
  final DeviceInfo target;
  const OnboardingReady(this.target);
  @override
  MeshtasticOnboardingPhase get phase => MeshtasticOnboardingPhase.ready;
}

class OnboardingFailed extends MeshtasticOnboardingState {
  final OnboardingFailureReason reason;
  final String? detail;
  const OnboardingFailed(this.reason, {this.detail});
  @override
  MeshtasticOnboardingPhase get phase => MeshtasticOnboardingPhase.failed;
}

class OnboardingPairingInvalidated extends MeshtasticOnboardingState {
  final int? appleCode;
  const OnboardingPairingInvalidated({this.appleCode});
  @override
  MeshtasticOnboardingPhase get phase =>
      MeshtasticOnboardingPhase.pairingInvalidated;
}

class OnboardingCancelled extends MeshtasticOnboardingState {
  const OnboardingCancelled();
  @override
  MeshtasticOnboardingPhase get phase => MeshtasticOnboardingPhase.cancelled;
}
