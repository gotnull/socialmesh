// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// Connection State Management
//
// This file implements the deferred connection architecture where:
// - App startup is independent of device connection
// - Device connection happens asynchronously in the background
// - Features are gated based on connection requirements
//
// Key concepts:
// - `DevicePairingState`: Device connection lifecycle (independent of app state)
// - `DeviceConnectionNotifier`: Manages async device connection
// - `FeatureRequirement`: Declares what features need to function
// - `FeatureAvailabilityNotifier`: Computed feature availability

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/safety/error_handler.dart';
import '../core/transport.dart';
import '../services/protocol/meshtastic_readiness_flag.dart';
import '../services/protocol/protocol_service.dart'
    show OperationalReadiness, ProtocolService;
import '../services/transport/ble_transport.dart' show BleTransport;
import '../services/meshcore/connection_coordinator.dart'
    show ConnectionResult, MeshCoreTcpDeviceId;
import '../services/transport/background_ble_service.dart';
import 'app_lifecycle_provider.dart';
import 'app_providers.dart';
import 'scanner_lifecycle_providers.dart';
import 'connectivity_providers.dart';
import 'meshcore_providers.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

// =============================================================================
// DEVICE PAIRING STATE
// =============================================================================

/// Device pairing/connection lifecycle state.
/// This is independent of app initialization state.
enum DevicePairingState {
  /// No device has ever been paired (first launch)
  neverPaired,

  /// Was paired before but not currently connected
  disconnected,

  /// Actively scanning for known device
  scanning,

  /// BLE connection in progress
  connecting,

  /// BLE connected, waiting for protocol configuration
  configuring,

  /// Fully connected and protocol configured
  connected,

  /// Connection error (BT disabled, device unavailable, auth failed)
  error,

  /// Saved device pairing is permanently invalid (device reset/forget)
  pairedDeviceInvalidated,
}

/// Reasons the saved pairing was invalidated.
enum PairingInvalidationReason {
  /// Device reset or pairing info removed on the hardware.
  peerReset('peer_removed_pairing'),

  /// Device could not be found after repeated scans.
  missingDevice('device_not_found'),

  /// Local databases wiped during account deletion. The BLE bond is stale
  /// and the user must forget the device in Bluetooth settings.
  accountDeleted('account_deleted'),

  /// Android-only: after the final reconnect scan-fail, the saved
  /// `lastDeviceId` is no longer present in
  /// `FlutterBluePlus.bondedDevices`. The user likely removed the
  /// device from Android Bluetooth settings. UI surfaces a re-pair
  /// CTA instead of the generic "Device not found" copy. iOS cannot
  /// detect this pre-connection (no bond-state API on CBPeripheral),
  /// so this reason is never produced on iOS.
  bondForgotten('bond_forgotten_after_scan_fail');

  final String logValue;
  const PairingInvalidationReason(this.logValue);
}

/// Detect whether the given exception signals the device removed pairing state.
/// This happens when:
/// - iOS: Error code 14 or "Peer removed pairing information" message
/// - Android: GATT status 5 (GATT_INSUFFICIENT_AUTHENTICATION) during connect/MTU,
///   or "device is disconnected" during requestMtu which indicates bond mismatch
bool isPairingInvalidationError(Object error) {
  if (error is FlutterBluePlusException) {
    // iOS: Error code 14 means peer removed pairing
    final isApplePeerReset =
        error.platform == ErrorPlatform.apple && error.code == 14;
    final hasPeerResetMessage = (error.description ?? '').contains(
      'Peer removed pairing information', // lint-allow: hardcoded-string
    );
    if (isApplePeerReset || hasPeerResetMessage) {
      return true;
    }

    // Android: Error code 5 is GATT_INSUFFICIENT_AUTHENTICATION (bond mismatch)
    // This happens when device expects bonded connection but phone doesn't have bond
    final isAndroidAuthError =
        error.platform == ErrorPlatform.android && error.code == 5;
    if (isAndroidAuthError) {
      return true;
    }
  }

  final message = error.toString();

  // iOS specific message
  if (message.contains('Peer removed pairing information')) {
    return true;
  }

  // Android: "device is disconnected" during requestMtu usually means bond mismatch
  // The device was connected but immediately disconnected during MTU negotiation
  if (message.contains('requestMtu') &&
      message.contains('device is disconnected')) {
    return true;
  }

  // Our custom message when device disconnects during connection setup
  // This typically happens on Android when there's a bond mismatch
  if (message.contains('Device disconnected during connection setup')) {
    return true;
  }

  return false;
}

/// Extract the apple-specific error code when available.
int? pairingInvalidationAppleCode(Object error) {
  if (error is FlutterBluePlusException &&
      error.platform == ErrorPlatform.apple) {
    return error.code;
  }
  return null;
}

/// Reason for disconnection or error
enum DisconnectReason {
  /// No error - normal state
  none,

  /// Device not found during scan
  deviceNotFound,

  /// Bluetooth is disabled
  bluetoothDisabled,

  /// BLE connection failed
  connectionFailed,

  /// Protocol configuration timeout
  configTimeout,

  /// PIN/authentication cancelled or failed
  authFailed,

  /// User manually disconnected
  userDisconnected,

  /// Device disconnected unexpectedly
  unexpectedDisconnect,
}

/// Complete device connection state with metadata
class DeviceConnectionState2 {
  final DevicePairingState state;
  final DisconnectReason reason;
  final String? errorMessage;
  final DeviceInfo? device;
  final DateTime? lastConnectedAt;
  final int reconnectAttempts;
  final int? myNodeNum;
  final int connectionSessionId;

  const DeviceConnectionState2({
    required this.state,
    this.reason = DisconnectReason.none,
    this.errorMessage,
    this.device,
    this.lastConnectedAt,
    this.reconnectAttempts = 0,
    this.myNodeNum,
    this.connectionSessionId = 0,
  });

  bool get isConnected => state == DevicePairingState.connected;
  bool get isConnecting =>
      state == DevicePairingState.connecting ||
      state == DevicePairingState.configuring;
  bool get isScanning => state == DevicePairingState.scanning;
  bool get hasError => state == DevicePairingState.error;
  bool get isTerminalInvalidated =>
      state == DevicePairingState.pairedDeviceInvalidated;
  bool get wasPreviouslyPaired => state != DevicePairingState.neverPaired;

  DeviceConnectionState2 copyWith({
    DevicePairingState? state,
    DisconnectReason? reason,
    String? errorMessage,
    DeviceInfo? device,
    DateTime? lastConnectedAt,
    int? reconnectAttempts,
    int? myNodeNum,
    int? connectionSessionId,
  }) {
    return DeviceConnectionState2(
      state: state ?? this.state,
      reason: reason ?? this.reason,
      errorMessage: errorMessage ?? this.errorMessage,
      device: device ?? this.device,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      myNodeNum: myNodeNum ?? this.myNodeNum,
      connectionSessionId: connectionSessionId ?? this.connectionSessionId,
    );
  }

  @override
  String toString() =>
      'DeviceConnectionState2(state: $state, reason: $reason, device: ${device?.name}, session: $connectionSessionId)';
}

// =============================================================================
// DEVICE CONNECTION NOTIFIER
// =============================================================================

/// Single canonical entry point for re-binding the Meshtastic protocol to
/// a (newly or already) connected transport. Every reconnect path —
/// auto-reconnect after a transport blip, background scan/connect, manual
/// retry, lifecycle resume — funnels through [restoreSession] so the
/// stale-state hazards listed below are handled uniformly:
///
/// - **Single-flight via [_inFlight]**: overlapping triggers (iOS may
///   emit repeated `AppLifecycleState.resumed` events; auto-reconnect
///   races against manual reconnect) collapse onto one execution; later
///   callers `await` the existing future instead of starting a parallel
///   restore.
/// - **Session generation via [_sessionGeneration]**: every restore is
///   tagged with a monotonic generation. After every async boundary the
///   `_doRestore` body re-checks the generation; if it has advanced (e.g.
///   the user disconnected, switched devices, or the transport was
///   disposed) the restore aborts before doing anything else, never
///   resurrecting a stale device.
/// - **Intentional-disconnect respect via [isUserDisconnected]**: a
///   restore triggered by lifecycle resume or transport reconnect is
///   silently skipped when the user has explicitly disconnected. This
///   read is provided as a callback so the coordinator does not depend
///   on the [DeviceConnectionNotifier]'s private state directly.
/// - **BLE-restoration safety net**: when the transport is a
///   [BleTransport], `refreshNotifications()` runs first to repair the
///   stale `_fromNumSubscription` left by iOS Core Bluetooth state
///   restoration before `protocol.stop()` then `protocol.start()` rebuild
///   a fresh handshake.
///
/// The coordinator deliberately does NOT touch UI providers (no banner
/// text, no snackbars) and does NOT auto-trigger session rebuilds — that
/// is the watchdog's job (Step 4, gated, default OFF in release).
/// MeshCore is unaffected; it has its own `ConnectionCoordinator`.
///
/// **Visibility**: the class is public (no underscore) only so a focused
/// unit test in `test/providers/restore_session_coordinator_test.dart`
/// can construct and exercise it directly with `ProviderContainer`
/// overrides for `transportProvider` / `protocolServiceProvider`.
/// Production code MUST go through
/// [DeviceConnectionNotifier.restoreSessionForLifecycleResume] (or
/// remain inside the connection notifier itself) — never construct an
/// extra instance.
@visibleForTesting
class RestoreSessionCoordinator {
  RestoreSessionCoordinator({
    required this.readTransport,
    required this.readProtocol,
    required this.isUserDisconnected,
    bool Function()? isAppBackgrounded,
  }) : isAppBackgrounded = isAppBackgrounded ?? _alwaysForeground;

  /// Re-reads the current transport on every restore so a transport
  /// swap (BLE -> TCP, or transport-provider re-creation) takes effect
  /// immediately without rewiring the coordinator.
  final DeviceTransport Function() readTransport;

  /// Re-reads the current [ProtocolService]. Same rationale as
  /// [readTransport].
  final ProtocolService Function() readProtocol;

  final bool Function() isUserDisconnected;

  /// Returns `true` while the app is in the background (paused / inactive
  /// / detached). Used to enforce a one-attempt budget per background
  /// session — see [_kBackgroundAttemptBudget]. Defaulted to "always
  /// foreground" so unit tests that don't care about lifecycle keep
  /// working unchanged.
  final bool Function() isAppBackgrounded;

  static bool _alwaysForeground() => false;

  /// Maximum number of restore attempts permitted while the app is
  /// backgrounded before we suppress further attempts until foreground.
  /// Battery / thermal safety is the design constraint here — repeated
  /// failed restores while backgrounded create a hot-phone-overnight
  /// regression. 2 covers the legitimate "iOS woke us with state
  /// restoration" case plus one retry for a drop that lands mid-session
  /// while backgrounded (testers report multi-hour background sessions
  /// ending disconnected), and still refuses to spin.
  static const int _kBackgroundAttemptBudget = 2;

  int _sessionGeneration = 0;
  Future<void>? _inFlight;
  int _backgroundAttemptCount = 0;
  bool _budgetExhaustedLogged = false;

  /// Current generation. Bumped at the start of every accepted
  /// [restoreSession] and explicitly via [invalidate].
  int get sessionGeneration => _sessionGeneration;

  /// True while a restore is in flight. Callers may use this to gate
  /// downstream behavior (e.g. a watchdog arming itself only after the
  /// restore completed).
  bool get inFlight => _inFlight != null;

  /// True when the per-background-session attempt budget has been
  /// consumed (i.e. a further restore call would be denied with
  /// `cause=background_budget_exhausted`). Used by the readiness
  /// watchdog to suppress its rebuild when a user is actively keeping
  /// the app backgrounded — battery-safety beats staying connected.
  bool get backgroundBudgetExhausted =>
      _backgroundAttemptCount >= _kBackgroundAttemptBudget;

  /// Bump the generation without running a restore. Call this on user
  /// disconnect, device switch, transport disposal, or any other
  /// authoritative "the previous session is dead" event so any
  /// in-flight restore aborts at its next stale check.
  void invalidate(String reason) {
    final old = _sessionGeneration;
    _sessionGeneration++;
    AppLogging.connection(
      'RESTORE: invalidate gen=$old -> $_sessionGeneration reason=$reason',
    );
  }

  /// Canonical reconnect routine. Idempotent under concurrent calls.
  ///
  /// Pre-checks (in order, each logs and short-circuits):
  /// 1. user-disconnected → skip;
  /// 2. in-flight → return the in-flight future;
  /// 3. transport not connected → skip (caller must connect first).
  ///
  /// On entry: bumps the generation, refreshes BLE notifications (BLE
  /// transports only), calls `protocol.stop()`, binds the new generation
  /// onto the protocol service, calls `protocol.start()`. Each `await`
  /// is followed by a stale check that aborts cleanly without touching
  /// shared state when a newer restore (or user disconnect) has taken
  /// over.
  Future<void> restoreSession({required String reason}) async {
    if (isUserDisconnected()) {
      AppLogging.connection(
        'RESTORE: skipped reason=$reason cause=user_disconnected',
      );
      return;
    }

    // Background safety budget — enforced BEFORE the single-flight + the
    // transport check so repeated background attempts don't even pay the
    // cost of those checks. Foreground is always-allowed; the budget
    // resets when we observe foreground (the natural moments — lifecycle
    // resume, manual reconnect, auto-reconnect) all happen in foreground
    // with the app's existing flow. See `_kBackgroundAttemptBudget`.
    final backgrounded = isAppBackgrounded();
    if (!backgrounded) {
      _backgroundAttemptCount = 0;
      _budgetExhaustedLogged = false;
    } else {
      if (_backgroundAttemptCount >= _kBackgroundAttemptBudget) {
        if (!_budgetExhaustedLogged) {
          AppLogging.connection(
            'BACKGROUND_RECONNECT: giving_up_until_foreground '
            'count=$_backgroundAttemptCount budget=$_kBackgroundAttemptBudget',
          );
          _budgetExhaustedLogged = true;
        }
        AppLogging.connection(
          'RESTORE: skipped reason=$reason cause=background_budget_exhausted '
          'count=$_backgroundAttemptCount',
        );
        return;
      }
      _backgroundAttemptCount++;
      AppLogging.connection(
        'BACKGROUND_RECONNECT: attempt count=$_backgroundAttemptCount '
        'budget=$_kBackgroundAttemptBudget reason=$reason',
      );
    }

    if (_inFlight != null) {
      AppLogging.connection(
        'RESTORE: skipped reason=$reason cause=in_flight gen=$_sessionGeneration',
      );
      return _inFlight;
    }
    final transport = readTransport();
    if (!transport.isConnected) {
      AppLogging.connection(
        'RESTORE: skipped reason=$reason cause=transport_disconnected',
      );
      return;
    }

    final myGen = ++_sessionGeneration;
    final stopwatch = Stopwatch()..start();
    AppLogging.connection(
      'RESTORE: begin gen=$myGen reason=$reason transport=${transport.runtimeType}',
    );

    final future = _doRestore(myGen, transport, stopwatch);
    _inFlight = future;
    try {
      await future;
    } finally {
      // Only clear the in-flight slot if it still points at our future —
      // a later restore that overwrote it (cannot happen today because
      // single-flight blocks it, but cheap defense) must not be cleared
      // by an earlier completion.
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<void> _doRestore(
    int gen,
    DeviceTransport transport,
    Stopwatch sw,
  ) async {
    bool stale() {
      if (_sessionGeneration != gen) {
        AppLogging.connection(
          'RESTORE: stale gen=$gen current=$_sessionGeneration -- abort',
        );
        return true;
      }
      if (isUserDisconnected()) {
        AppLogging.connection(
          'RESTORE: stale gen=$gen cause=user_disconnected -- abort',
        );
        return true;
      }
      return false;
    }

    final protocol = readProtocol();

    if (transport is BleTransport) {
      AppLogging.connection('BLE_NOTIF: refresh attempted gen=$gen');
      try {
        await transport.refreshNotifications();
        if (stale()) return;
        AppLogging.connection('BLE_NOTIF: refresh ok gen=$gen');
      } catch (e) {
        AppLogging.connection('BLE_NOTIF: refresh failed gen=$gen err=$e');
        if (stale()) return;
      }
    }

    // `stop()` is synchronous in this codebase — it cancels the data
    // subscription, errors any pending completers, and resets
    // `_isStarted = false` so the upcoming `start()` is allowed past the
    // `_isStarted && _transport.isConnected` short-circuit.
    protocol.stop();
    if (stale()) return;
    protocol.bindSessionGeneration(gen);
    if (stale()) return;
    await protocol.start();
    if (stale()) return;
    AppLogging.connection(
      'RESTORE: end gen=$gen elapsed=${sw.elapsedMilliseconds}ms '
      'readiness=${protocol.readiness}',
    );
  }
}

/// Auto-rebuild side of the readiness fix (Step 4). Watches
/// `protocol.readinessStream` and, if a restore reaches `linkConnected`
/// but never advances to `ready` within deadline, triggers ONE clean
/// transport-disconnect + fresh `startBackgroundConnection()` cycle via
/// the supplied [triggerRebuild] callback. The rebuild flows through
/// `RestoreSessionCoordinator` so session-generation, single-flight,
/// user-disconnect, and background-budget guards still apply — the
/// watchdog is NEVER a separate reconnect path.
///
/// Hard rules baked into this class:
/// - **OFF in release by default.** [MeshtasticReadinessFlags] resolves
///   to `watchdogEnabled=false` in release unless env override flips it.
/// - **No reconnect/rebuild loop.** At most one rebuild per
///   [_kRebuildBackoff] (60 s). After the backoff also fails, the next
///   timeout-trigger logs `WATCHDOG: suppressed_backoff` and waits.
/// - **Suppressed in background once the coordinator's budget is
///   exhausted.** Battery / thermal safety wins.
/// - **Phase-1 timeout is a warning only**, not a rebuild trigger. The
///   rebuild fires on total-timeout (20 s) only — phase-1 (18 s) just
///   surfaces the wedge in logs sooner for triage. The phase-1 warning
///   only logs if readiness is still in `linkConnected` /
///   `handshakePhase1` when the timer fires; firmware that completes
///   phase-1 before the deadline gets no false-positive warning.
/// - **Timer ownership is single-arm-per-generation**. `_arm()`
///   cancels any prior timers and creates a fresh pair before storing
///   them in [_phase1Timer] / [_totalTimer]. Every timer callback
///   captures its own [Timer] reference and self-suppresses if the
///   field no longer points at it (cancel + replace race), if the
///   coordinator's generation moved on, or if readiness is already
///   `ready`. Together these prevent the orphan-total-timer rebuild
///   that fired one unnecessary `transport.disconnect()` per healthy
///   restore cycle in field testing.
@visibleForTesting
class ReadinessWatchdog {
  ReadinessWatchdog({
    required this.flags,
    required this.coordinator,
    required this.readinessStream,
    required this.triggerRebuild,
    required this.isAppBackgrounded,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final MeshtasticReadinessFlags flags;
  final RestoreSessionCoordinator coordinator;
  final Stream<OperationalReadiness> readinessStream;
  final Future<void> Function() triggerRebuild;
  final bool Function() isAppBackgrounded;

  /// Wall-clock source for the rebuild-backoff window. Defaults to
  /// [DateTime.now]; tests inject a fake-clock-aware callback so
  /// `fakeAsync` can advance the backoff window deterministically.
  /// Production code uses `DateTime.now` (the timer itself is enough
  /// for the deadline; this clock only governs the 60 s rebuild cap).
  final DateTime Function() clock;

  /// Phase-1 deadline: log a "still in phase 1" warning. No rebuild.
  /// 18 s covers the slowest observed phase-1 on Heltec firmware (~14 s).
  /// Healthy devices nominally complete phase-1 in 1-3 s, so this
  /// remains a useful "something is wrong" signal even at 18 s.
  static const Duration _kPhase1Deadline = Duration(seconds: 18);

  /// Total deadline: rebuild trigger when readiness has not reached
  /// `ready`.
  static const Duration _kTotalDeadline = Duration(seconds: 20);

  /// Minimum interval between rebuilds. After a rebuild fires, no
  /// further rebuild will fire from the watchdog for this duration even
  /// if readiness still hasn't reached `ready`.
  static const Duration _kRebuildBackoff = Duration(seconds: 60);

  StreamSubscription<OperationalReadiness>? _subscription;
  Timer? _phase1Timer;
  Timer? _totalTimer;
  DateTime? _lastRebuildAt;
  bool _phase1LoggedThisArm = false;

  /// Generation the current pair of timers was armed for. `null` means
  /// "no armed timers right now" (just-constructed, just-cancelled, or
  /// post-`stop`). Stale timer callbacks compare against this and the
  /// coordinator's current generation to decide whether to act.
  int? _armedGeneration;

  /// Last readiness state observed on the stream. Updated synchronously
  /// in [_onReadiness] before the per-state branch runs, so timer
  /// callbacks reading this see the same value the cancellation /
  /// arming logic just used.
  OperationalReadiness _lastReadiness = OperationalReadiness.idle;

  /// Test-only window into the armed-for generation, mirroring the
  /// pattern used by [RestoreSessionCoordinator.sessionGeneration].
  @visibleForTesting
  int? get armedGenerationForTesting => _armedGeneration;

  @visibleForTesting
  OperationalReadiness get lastReadinessForTesting => _lastReadiness;

  /// Subscribe to readiness transitions. No-op if the watchdog flag is
  /// disabled — call sites can construct the watchdog unconditionally
  /// for symmetry without paying any cost in release.
  void start() {
    if (!flags.watchdogEnabled) return;
    _subscription = readinessStream.listen(_onReadiness);
  }

  /// Cancel the subscription and any armed timers. Idempotent.
  Future<void> stop() async {
    _cancelTimers(reason: 'stop');
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onReadiness(OperationalReadiness state) {
    _lastReadiness = state;
    switch (state) {
      case OperationalReadiness.linkConnected:
      case OperationalReadiness.handshakePhase1:
      case OperationalReadiness.handshakePhase2:
        _arm();
      case OperationalReadiness.ready:
        _cancelTimers(reason: 'ready');
      case OperationalReadiness.idle:
        _cancelTimers(reason: 'idle');
      case OperationalReadiness.degraded:
        _cancelTimers(reason: 'degraded');
    }
  }

  void _arm() {
    if (!flags.watchdogEnabled) return;
    final gen = coordinator.sessionGeneration;

    // Idempotent skip: same generation, both timers still alive.
    // Re-emitting `linkConnected -> handshakePhase1 -> handshakePhase2`
    // for the same restore should NOT recreate timers.
    if (_armedGeneration == gen &&
        (_phase1Timer?.isActive ?? false) &&
        (_totalTimer?.isActive ?? false)) {
      AppLogging.connection('WATCHDOG: arm_skipped already_armed gen=$gen');
      return;
    }

    // Replace path: cancel any prior timers cleanly before creating a
    // fresh pair. Without this, an `_arm()` call that races a
    // partially-fired previous arm (phase-1 fired, total still
    // pending) would drop the field reference but leave the OS-level
    // timer alive — the orphan total timer that fired spurious
    // rebuilds in field testing.
    if (_phase1Timer != null || _totalTimer != null) {
      AppLogging.connection(
        'WATCHDOG: rearm_cancelled_previous gen=$gen '
        'previousGen=$_armedGeneration',
      );
      _phase1Timer?.cancel();
      _phase1Timer = null;
      _totalTimer?.cancel();
      _totalTimer = null;
    }

    _armedGeneration = gen;
    _phase1LoggedThisArm = false;
    AppLogging.connection(
      'WATCHDOG: armed deadline=${_kTotalDeadline.inSeconds}s gen=$gen',
    );

    // Capture each timer in a `late final` local so the callback can
    // self-identify against the field. If `_arm()` runs again and
    // replaces the field, the old callback's `identical(..., self)`
    // check returns false and the callback exits without side effects.
    late final Timer phase1;
    phase1 = Timer(_kPhase1Deadline, () => _onPhase1Timeout(gen, phase1));
    _phase1Timer = phase1;

    late final Timer total;
    total = Timer(_kTotalDeadline, () => _onTotalTimeout(gen, total));
    _totalTimer = total;
  }

  void _cancelTimers({required String reason}) {
    if (_phase1Timer == null && _totalTimer == null) return;
    AppLogging.connection(
      'WATCHDOG: cancelled reason=$reason gen=$_armedGeneration',
    );
    _phase1Timer?.cancel();
    _phase1Timer = null;
    _totalTimer?.cancel();
    _totalTimer = null;
    _armedGeneration = null;
  }

  void _onPhase1Timeout(int gen, Timer self) {
    // Self-identity guard: the field no longer points at us, so a
    // newer arm has replaced this timer (or `_cancelTimers` ran).
    if (!identical(_phase1Timer, self)) {
      AppLogging.connection(
        'WATCHDOG: stale_timer_suppressed timerGen=$gen '
        'currentGen=${coordinator.sessionGeneration}',
      );
      return;
    }
    // Stale-generation guard: the coordinator advanced past this gen.
    if (_armedGeneration != gen || gen != coordinator.sessionGeneration) {
      AppLogging.connection(
        'WATCHDOG: stale_timer_suppressed timerGen=$gen '
        'currentGen=${coordinator.sessionGeneration}',
      );
      return;
    }
    // Only warn if we're actually still stuck in phase-1. If readiness
    // already advanced to `handshakePhase2` (or further) by the time
    // the timer fires, phase-1 actually completed within the deadline
    // and the warning would be a false positive.
    final stuckInPhase1 =
        _lastReadiness == OperationalReadiness.linkConnected ||
        _lastReadiness == OperationalReadiness.handshakePhase1;
    if (stuckInPhase1 && !_phase1LoggedThisArm) {
      AppLogging.connection('WATCHDOG: phase1 timeout gen=$gen');
      _phase1LoggedThisArm = true;
    }
  }

  Future<void> _onTotalTimeout(int gen, Timer self) async {
    // Self-identity guard: orphan from a replaced or cancelled arm.
    if (!identical(_totalTimer, self)) {
      AppLogging.connection(
        'WATCHDOG: stale_timer_suppressed timerGen=$gen '
        'currentGen=${coordinator.sessionGeneration}',
      );
      return;
    }
    // Stale-generation guard.
    if (_armedGeneration != gen || gen != coordinator.sessionGeneration) {
      AppLogging.connection(
        'WATCHDOG: stale_timer_suppressed timerGen=$gen '
        'currentGen=${coordinator.sessionGeneration}',
      );
      return;
    }
    // Already-ready guard. The cancel-on-ready path in `_onReadiness`
    // is the primary protection; this is defence in depth for the
    // race where the timer's callback was already enqueued before the
    // cancel ran.
    if (_lastReadiness == OperationalReadiness.ready) {
      AppLogging.connection(
        'WATCHDOG: stale_timer_suppressed timerGen=$gen '
        'currentGen=${coordinator.sessionGeneration}',
      );
      return;
    }

    AppLogging.connection('WATCHDOG: total timeout gen=$gen');

    if (isAppBackgrounded() || coordinator.backgroundBudgetExhausted) {
      AppLogging.connection('WATCHDOG: suppressed_in_background gen=$gen');
      return;
    }

    final now = clock();
    if (_lastRebuildAt != null &&
        now.difference(_lastRebuildAt!) < _kRebuildBackoff) {
      AppLogging.connection(
        'WATCHDOG: suppressed_backoff gen=$gen '
        'since=${now.difference(_lastRebuildAt!).inSeconds}s '
        'min=${_kRebuildBackoff.inSeconds}s',
      );
      return;
    }
    _lastRebuildAt = now;

    try {
      await triggerRebuild();
      AppLogging.connection('WATCHDOG: rebuild outcome=ok gen=$gen');
    } catch (e) {
      AppLogging.connection('WATCHDOG: rebuild outcome=error:$e gen=$gen');
    }
  }
}

/// Outcome of the shared pre-scan BLE cleanup.
enum _BleCleanupOutcome {
  /// Stack is settled; the caller may proceed to scan.
  ready,

  /// The target device is absent from the Android bonded list; the
  /// caller must route to pairing invalidation instead of scanning.
  bondMissing,
}

/// Manages device connection lifecycle independently from app initialization.
/// Starts connection asynchronously in background after app is ready.
class DeviceConnectionNotifier extends Notifier<DeviceConnectionState2> {
  StreamSubscription<DeviceConnectionState>? _connectionSubscription;
  Timer? _scanTimer;
  Timer? _retryTimer; // Timer for retry attempts
  bool _isInitialized = false;
  bool _userDisconnected = false; // Track if user manually disconnected

  // Consecutive config-timeout teardowns since the last successful
  // restore. Bounds the app-driven disconnect/reconnect recovery in
  // `_initializeProtocolAfterAutoReconnect` so a radio that never
  // completes configuration cannot keep the phone in a permanent
  // disconnect loop.
  int _configTimeoutTeardowns = 0;
  static const int _maxConfigTimeoutTeardowns = 3;

  /// Owns the canonical reconnect routine. Lazy-init in [build] so the
  /// closure captures the current `ref` and `_userDisconnected` reads.
  late final RestoreSessionCoordinator _restoreCoordinator;

  /// Auto-rebuild side of the readiness fix. Subscribes to
  /// `protocol.readinessStream` and triggers ONE clean rebuild per
  /// 60 s when readiness fails to reach `ready`. Always constructed
  /// (cheap), but its `start()` is a no-op when the watchdog flag is
  /// disabled (release-default OFF).
  late final ReadinessWatchdog _watchdog;
  bool _watchdogRebuildInFlight = false;
  bool _backgroundScanInProgress = false; // Guard against concurrent scans
  bool _authFailurePending =
      false; // Track PIN/auth failure through disconnect sequence
  int _missingDeviceAttempts = 0;
  DateTime? _firstMissingAttemptAt;
  static const int _maxInvalidationAttempts = 3;
  static const Duration _invalidationWindow = Duration(seconds: 120);
  int _connectionSessionId = 0;
  int _reconnectAttempt = 0; // Current retry attempt (0-based)
  int _maxReconnectAttempts = 3; // Max retries for normal reconnect
  static const int _maxReconnectAttemptsRegion =
      6; // Max retries during region apply (device reboot)

  int _nextConnectionSessionId() {
    _connectionSessionId += 1;
    return _connectionSessionId;
  }

  @override
  DeviceConnectionState2 build() {
    _restoreCoordinator = RestoreSessionCoordinator(
      readTransport: () => ref.read(transportProvider),
      readProtocol: () => ref.read(protocolServiceProvider),
      isUserDisconnected: () => _userDisconnected,
      isAppBackgrounded: () => !ref.read(appLifecycleProvider),
    );

    _watchdog = ReadinessWatchdog(
      flags: ref.read(meshtasticReadinessFlagsProvider),
      coordinator: _restoreCoordinator,
      readinessStream: ref.read(protocolServiceProvider).readinessStream,
      triggerRebuild: _triggerWatchdogRebuild,
      isAppBackgrounded: () => !ref.read(appLifecycleProvider),
    );
    _watchdog.start();

    // Clean up subscriptions when provider is disposed
    ref.onDispose(() {
      AppLogging.connection('🔌 DeviceConnectionNotifier: Disposing...');
      _restoreCoordinator.invalidate('notifier_dispose');
      _watchdog.stop();
      _connectionSubscription?.cancel();
      _scanTimer?.cancel();
      _retryTimer?.cancel();
    });

    return const DeviceConnectionState2(state: DevicePairingState.neverPaired);
  }

  /// Test-only: expose the restore-session generation so tests can assert
  /// stale-restore behavior without poking private fields.
  @visibleForTesting
  int get restoreSessionGenerationForTesting =>
      _restoreCoordinator.sessionGeneration;

  /// Run the canonical restore routine from the lifecycle-resume hook.
  ///
  /// Called by `main.dart`'s `_handleAppResumed` when the BLE link is up
  /// but the Meshtastic protocol is not operational. The coordinator's
  /// own pre-checks (user-disconnected, in-flight, transport-not-
  /// connected) make this safe to call unconditionally from the
  /// lifecycle hook; the caller still owns the "is this a situation
  /// worth restoring?" decision (don't disturb a healthy session).
  Future<void> restoreSessionForLifecycleResume() async {
    await _restoreCoordinator.restoreSession(reason: 'lifecycle_resume');
  }

  /// Watchdog rebuild trigger. Disconnects the transport (forcing iOS
  /// to drop any state-restored GATT) then re-enters the existing
  /// `startBackgroundConnection()` path, which itself goes through the
  /// coordinator's `restoreSession`. Generation, single-flight,
  /// user-disconnect, and background-budget guards all still apply.
  ///
  /// **Not a separate reconnect path** — every guard the coordinator
  /// enforces fires here too. A user-disconnect mid-rebuild causes the
  /// next `startBackgroundConnection` call to return early on its own
  /// `_userDisconnected` check.
  Future<void> _triggerWatchdogRebuild() async {
    if (_userDisconnected) return;
    if (_watchdogRebuildInFlight) return;
    _watchdogRebuildInFlight = true;
    try {
      final transport = ref.read(transportProvider);
      try {
        await transport.disconnect();
      } catch (e) {
        AppLogging.connection(
          'WATCHDOG: rebuild transport.disconnect failed: $e',
        );
      }
      await startBackgroundConnection();
    } finally {
      _watchdogRebuildInFlight = false;
    }
  }

  /// Test-only method to set state directly.
  /// Do not use in production code.
  @visibleForTesting
  void setTestState(DeviceConnectionState2 newState) {
    state = newState;
  }

  /// Test-only seam that drives `_handleDisconnect` directly so unit
  /// tests can pin the region-apply gate (must not call
  /// `setNeedsScanner` while `regionConfigProvider.applyStatus ==
  /// applying`). Production code reaches `_handleDisconnect` via the
  /// transport state stream — driving that here is unnecessary
  /// overhead.
  @visibleForTesting
  void debugHandleDisconnectForTest(DisconnectReason reason) {
    _handleDisconnect(reason);
  }

  /// Cancel any in-progress auto-reconnect cycle.
  ///
  /// Called by the reconnect watchdog timer in [TopStatusBanner] when
  /// 90 s of continuous reconnecting elapses without progress. Stops
  /// the retry timer, resets internal flags, attempts to stop any
  /// active BLE scan, and sets [AutoReconnectState] to
  /// [AutoReconnectState.failed] so the banner shows actionable
  /// options (Retry / Go to Scanner).
  ///
  /// **Not authoritative**: this does NOT set `userDisconnected=true`,
  /// so other entry points (connectivity-restored listener, app-resume
  /// recovery) may legitimately re-arm. For user-tapped Cancel use
  /// [userCancelAutoReconnect].
  void cancelAutoReconnect() {
    AppLogging.connection('🔌 cancelAutoReconnect: Cancelling reconnect cycle');
    _retryTimer?.cancel();
    _retryTimer = null;
    _backgroundScanInProgress = false;
    _reconnectAttempt = 0;

    // Best-effort stop of any active BLE scan.
    FlutterBluePlus.stopScan().catchError((_) {});

    // Transition to failed so the banner shows Device not found with
    // Retry / Connect actions. _performReconnect also checks for
    // failed as an abort condition.
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.failed);

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.deviceNotFound,
    );
  }

  /// User-initiated authoritative cancel (banner Cancel tap).
  ///
  /// Distinct from the watchdog [cancelAutoReconnect] in two ways:
  ///
  /// 1. Sets `userDisconnected=true` so connectivity-restored,
  ///    app-resume, and any other re-arm path is blocked until the
  ///    user explicitly initiates a new connect from Scanner.
  /// 2. Drives `autoReconnectState` straight to `idle` (not `failed`)
  ///    because the next surface the user sees is the Scanner — the
  ///    "Device not found" banner state is never displayed.
  ///
  /// Also issues a best-effort transport disconnect so any in-flight
  /// TCP socket / BLE GATT link is torn down before the Scanner mounts.
  ///
  /// Logs `RECONNECT_CANCEL_AUTHORED_STOP` for telemetry.
  Future<void> userCancelAutoReconnect() async {
    AppLogging.connection(
      'RECONNECT_BANNER_CANCEL_TAPPED — running authoritative cancel',
    );

    _retryTimer?.cancel();
    _retryTimer = null;
    _backgroundScanInProgress = false;
    _reconnectAttempt = 0;
    _configTimeoutTeardowns = 0;
    _userDisconnected = true;

    // Block re-arm via the global flag (read by the auto-reconnect
    // manager and the connectivity-restored listener).
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(true);

    // Idle (not failed): the user is being routed to Scanner; no need
    // to display the post-failure banner state.
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);

    // Best-effort stops.
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await ref.read(transportProvider).disconnect();
    } catch (_) {}

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.userDisconnected,
    );

    AppLogging.connection(
      'RECONNECT_CANCEL_AUTHORED_STOP userDisconnected=true '
      'autoReconnectState=idle reconnectAttempt=$_reconnectAttempt',
    );
  }

  /// Initialize the connection manager.
  /// Call this after app services are ready.
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Already initialized, skipping',
      );
      return;
    }
    _isInitialized = true;
    _userDisconnected = false;

    AppLogging.connection('🔌 DeviceConnectionNotifier: Initializing...');

    // Set up connectivity listener for auto-retry when internet comes back online
    // This helps reconnect after region change (device reboot) when connectivity is restored
    _setupConnectivityListener();

    // Check if we have a previously paired device
    final settings = await ref.read(settingsServiceProvider.future);
    final lastDeviceId = settings.lastDeviceId;

    if (lastDeviceId == null) {
      // Never paired before
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: No previous device, state=neverPaired',
      );
      state = DeviceConnectionState2(
        state: DevicePairingState.neverPaired,
        connectionSessionId: _connectionSessionId,
      );
      return;
    }

    // Had a device before - mark as disconnected and start background connection
    AppLogging.connection(
      '🔌 DeviceConnectionNotifier: Previous device found: $lastDeviceId',
    );
    state = DeviceConnectionState2(
      state: DevicePairingState.disconnected,
      connectionSessionId: _connectionSessionId,
    );

    // Listen to transport connection state changes
    // BUT only for Meshtastic protocol - MeshCore uses its own transport
    final lastProtocol = settings.lastDeviceProtocol;
    if (lastProtocol != 'meshcore') {
      _setupConnectionListener();
    } else {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: MeshCore device - skipping Meshtastic listener',
      );
    }

    // Start background connection attempt if auto-reconnect enabled
    if (settings.autoReconnect) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Auto-reconnect enabled, scheduling connection...',
      );
      // Small delay to let UI render first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!ref.mounted) return;
        if (!_userDisconnected) {
          // Route to appropriate protocol's connect method
          if (lastProtocol == 'meshcore') {
            _startMeshCoreBackgroundConnection(lastDeviceId, settings);
          } else {
            startBackgroundConnection();
          }
        } else {
          AppLogging.connection(
            '🔌 DeviceConnectionNotifier: Skipping auto-connect - user disconnected',
          );
        }
      });
    } else {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Auto-reconnect disabled',
      );
    }
  }

  /// Set up listener for connectivity changes to auto-retry device connection
  /// when internet comes back online after region change (device reboot).
  /// This ensures the "Device not found - Retry" banner automatically retries
  /// when connectivity is restored.
  void _setupConnectivityListener() {
    ref.listen<ConnectivityStatus>(connectivityStatusProvider, (
      previous,
      next,
    ) {
      // Only act when connectivity changes from offline to online
      final wasOffline = previous == null || !previous.online;
      final isNowOnline = next.online;

      if (!wasOffline || !isNowOnline) return;

      AppLogging.connection(
        '🔌 Connectivity restored: checking if reconnect needed...',
      );

      // Skip if user manually disconnected
      if (_userDisconnected) {
        AppLogging.connection(
          '🔌 Connectivity restored but user disconnected - skipping auto-reconnect',
        );
        return;
      }

      // Check if we need to reconnect
      // Note: We avoid reading regionConfigProvider here to prevent circular dependency.
      // The region apply reconnect is handled via autoReconnectState.
      final autoReconnectState = ref.read(autoReconnectStateProvider);
      final isFailed = autoReconnectState == AutoReconnectState.failed;
      final isScanning = autoReconnectState == AutoReconnectState.scanning;
      final isConnecting = autoReconnectState == AutoReconnectState.connecting;
      final isDisconnected = state.state == DevicePairingState.disconnected;

      // Trigger reconnect if:
      // 1. Previous reconnect failed (e.g., device not found after region reboot)
      // 2. Currently scanning/connecting/retrying (connectivity came back during retry)
      // 3. We're disconnected but not by user
      if (isFailed || isScanning || isConnecting || isDisconnected) {
        AppLogging.connection(
          '🔌 Connectivity restored: triggering reconnect '
          '(failed=$isFailed, scanning=$isScanning, connecting=$isConnecting, disconnected=$isDisconnected)',
        );
        // Reset retry counter to give fresh attempts after connectivity restored
        _reconnectAttempt = 0;
        _retryTimer?.cancel();
        // Small delay to ensure network stack is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (ref.mounted && !_userDisconnected) {
            startBackgroundConnection();
          }
        });
      }
    });
  }

  /// Set up listener for transport connection state changes
  void _setupConnectionListener() {
    final transport = ref.read(transportProvider);

    _connectionSubscription?.cancel();
    _connectionSubscription = transport.stateStream.listen((transportState) {
      AppLogging.connection(
        '🔌 DeviceConnectionNotifier: Transport state changed: $transportState (userDisconnected=$_userDisconnected)',
      );

      switch (transportState) {
        case DeviceConnectionState.connected:
          // BLE connected but may still need protocol config
          if (state.state != DevicePairingState.connected &&
              state.state != DevicePairingState.configuring) {
            AppLogging.connection(
              '🔌 DeviceConnectionNotifier: BLE connected, state=configuring',
            );
            state = state.copyWith(state: DevicePairingState.configuring);
            // Transport auto-reconnected (BLE / USB / network) — start protocol
            _initializeProtocolAfterAutoReconnect();
          }
          break;
        case DeviceConnectionState.disconnected:
          if (_userDisconnected) {
            AppLogging.connection(
              '🔌 DeviceConnectionNotifier: Disconnected (user-initiated), NOT triggering reconnect',
            );
          } else {
            AppLogging.connection(
              '🔌 DeviceConnectionNotifier: Disconnected (unexpected), handling...',
            );
          }
          _handleDisconnect(
            _userDisconnected
                ? DisconnectReason.userDisconnected
                : DisconnectReason.unexpectedDisconnect,
          );
          break;
        case DeviceConnectionState.connecting:
          AppLogging.connection(
            '🔌 DeviceConnectionNotifier: state=connecting',
          );
          state = state.copyWith(state: DevicePairingState.connecting);
          break;
        case DeviceConnectionState.disconnecting:
          AppLogging.connection(
            '🔌 DeviceConnectionNotifier: state=disconnecting (transitional)',
          );
          // Transitional state, ignore
          break;
        case DeviceConnectionState.error:
          AppLogging.connection('🔌 DeviceConnectionNotifier: state=error');
          state = state.copyWith(
            state: DevicePairingState.error,
            reason: DisconnectReason.connectionFailed,
          );
          break;
      }
    });
  }

  /// Initialize protocol after the transport auto-reconnected (any
  /// transport: BLE / USB / network). Bypasses `_connectToDevice` so
  /// it doesn't run a fresh scan/connect.
  Future<void> _initializeProtocolAfterAutoReconnect() async {
    // Check if we should handle this reconnection
    // We handle it in these cases:
    // 1. autoReconnectState == connecting (our background reconnect initiated it)
    final autoReconnectState = ref.read(autoReconnectStateProvider);

    // Note: We don't check regionConfigProvider here to avoid circular dependency
    // during initialization. If region apply is in progress, the auto-reconnect
    // state will be set to 'connecting' which we check above.
    final shouldHandleReconnect =
        autoReconnectState == AutoReconnectState.connecting;

    if (!shouldHandleReconnect) {
      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: SKIPPING - '
        'autoReconnect=$autoReconnectState, '
        'scanner is handling connection',
      );
      return;
    }

    final transport = ref.read(transportProvider);
    final transportLabel = transport.type.name.toUpperCase();
    AppLogging.connection(
      '🔌 _initializeProtocolAfterAutoReconnect: $transportLabel auto-reconnected, starting protocol... '
      '(autoReconnect=$autoReconnectState)',
    );
    AppLogging.connection(
      'RECONNECT_PATH transport=$transportLabel source=state_listener',
    );

    try {
      final protocol = ref.read(protocolServiceProvider);

      // Get device info from transport or use stored info
      final deviceName = state.device?.name ?? 'Unknown';
      protocol.setDeviceName(deviceName);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Starting protocol for $deviceName...',
      );
      // Route through the canonical restore routine. Replaces a prior
      // `if (configurationComplete && myNodeNum != null) skip` guard
      // that could leave stale state in place when phase-2 stalled —
      // myNodeNum was already set in phase-1 and the skip-guard fell
      // through to a `start()` that short-circuited on
      // `_isStarted && _transport.isConnected` and never re-attached
      // the packet stream. The coordinator's `_inFlight` provides the
      // dedup the old skip-guard was trying to provide, without
      // skipping legitimate restores.
      await _restoreCoordinator.restoreSession(reason: 'auto_reconnect');

      // Verify we got configuration
      if (protocol.myNodeNum == null) {
        AppLogging.connection(
          '🔌 _initializeProtocolAfterAutoReconnect: Protocol started but no myNodeNum',
        );
        return;
      }

      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Protocol ready! myNodeNum: ${protocol.myNodeNum}',
      );

      // Update state to connected
      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Marking DevicePairingState.connected',
      );
      state = state.copyWith(
        state: DevicePairingState.connected,
        lastConnectedAt: DateTime.now(),
        myNodeNum: protocol.myNodeNum,
        reason: DisconnectReason.none,
        reconnectAttempts: 0,
        connectionSessionId: _nextConnectionSessionId(),
      );
      _configTimeoutTeardowns = 0;

      // Update legacy providers
      if (state.device != null) {
        ref.read(connectedDeviceProvider.notifier).setState(state.device);
      }
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.success);
    } catch (e) {
      AppLogging.connection(
        '🔌 _initializeProtocolAfterAutoReconnect: Error: $e',
      );

      // Determine if this is a PIN/auth error that requires user interaction.
      // These errors cannot be resolved by retrying — the user must manually
      // re-pair via the Scanner (which shows the system PIN dialog). Without
      // this guard, the auto-reconnect manager keeps retrying indefinitely,
      // creating a loop of connect → PIN fail → disconnect → reconnect.
      //
      // CRITICAL: Only match ACTUAL BLE authentication/encryption errors,
      // NOT generic config timeouts. Config timeouts can happen for many
      // reasons (slow BLE after app restart, device still booting, etc.)
      // and should be retried normally — not routed to Scanner.
      final errorStr = e.toString().toLowerCase();
      final isAuthError =
          errorStr.contains('authentication') ||
          errorStr.contains('encryption') ||
          errorStr.contains('insufficient') ||
          errorStr.contains('pin was cancelled') ||
          errorStr.contains('enter the pin');

      if (isAuthError) {
        AppLogging.connection(
          '🔌 _initializeProtocolAfterAutoReconnect: PIN/auth error — '
          'disconnecting transport and routing to Scanner (requires user interaction)',
        );
        AppErrorHandler.addBreadcrumb(
          'AutoReconnect: PIN/auth error, routing to Scanner', // lint-allow: hardcoded-string
        );

        // Set flag BEFORE transport.disconnect() so _handleDisconnect
        // preserves the auth failure reason instead of overwriting it
        // with unexpectedDisconnect.
        _authFailurePending = true;

        // Mark as failed so the auto-reconnect manager stops retrying
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);

        // Disconnect the BLE transport so the device is released cleanly.
        // This will trigger _handleDisconnect via the transport state
        // stream, which checks _authFailurePending and routes to Scanner.
        try {
          final transport = ref.read(transportProvider);
          await transport.disconnect();
        } catch (_) {
          // Ignore cleanup errors — ensure we still route to Scanner
          // even if the disconnect itself fails.
          _authFailurePending = false;
          state = state.copyWith(
            state: DevicePairingState.disconnected,
            reason: DisconnectReason.authFailed,
            errorMessage: e.toString(),
          );
          ref.read(appInitProvider.notifier).setNeedsScanner();
          AppLogging.connection(
            '🔌 _initializeProtocolAfterAutoReconnect: disconnect failed, '
            'forcing Scanner navigation anyway',
          );
        }
      } else {
        // NOT an auth error — this is a generic config timeout or
        // transport error. Do NOT route to Scanner.
        AppLogging.connection(
          '🔌 _initializeProtocolAfterAutoReconnect: Non-auth error — '
          'NOT routing to Scanner (error: $e)',
        );
        await _handleNonAuthRestoreFailure();
      }
    }
  }

  /// Recovery for a restore attempt that failed without an auth error
  /// (typically a config-handshake timeout) while the link is still up.
  ///
  /// The auto-reconnect manager only reacts to a `disconnected`
  /// transport event. Left alone, the app sits in `configuring` until
  /// the OS eventually drops the link. Drive a bounded teardown instead
  /// so the drop flows through the canonical reconnect pipeline
  /// (_handleDisconnect -> autoReconnectManager -> _performReconnect).
  /// Bounded so a radio that never completes configuration falls back
  /// to the banner + manual Retry instead of looping forever.
  /// Do NOT call startBackgroundConnection here - dual-scan race
  /// (see _handleDisconnect's unexpectedDisconnect branch).
  Future<void> _handleNonAuthRestoreFailure() async {
    final transport = ref.read(transportProvider);
    final regionApplying = ref.read(regionApplyInFlightProvider);
    if (transport.isConnected &&
        !_userDisconnected &&
        !regionApplying &&
        _configTimeoutTeardowns < _maxConfigTimeoutTeardowns) {
      _configTimeoutTeardowns++;
      AppLogging.connection(
        '🔌 _handleNonAuthRestoreFailure: config did not complete but '
        'link is still up - forcing teardown '
        '$_configTimeoutTeardowns/$_maxConfigTimeoutTeardowns to '
        're-enter the reconnect pipeline',
      );
      if (transport is ReceiveDiagnosticsSupport) {
        (transport as ReceiveDiagnosticsSupport).noteDisconnectCause(
          'config_timeout_retry',
        );
      }
      try {
        await transport.disconnect();
      } catch (disconnectError) {
        AppLogging.connection(
          '🔌 _handleNonAuthRestoreFailure: teardown disconnect '
          'failed - $disconnectError',
        );
      }
    } else if (_configTimeoutTeardowns >= _maxConfigTimeoutTeardowns) {
      AppLogging.connection(
        '🔌 _handleNonAuthRestoreFailure: config-timeout teardown '
        'budget exhausted ($_configTimeoutTeardowns) - leaving link '
        'up; user can Retry from the banner',
      );
    }
  }

  /// Test-only seam driving [_handleNonAuthRestoreFailure] directly.
  /// Production code reaches it via the restore-failure catch in
  /// `_initializeProtocolAfterAutoReconnect`; driving the full restore
  /// pipeline in a unit test is unnecessary overhead.
  @visibleForTesting
  Future<void> debugHandleNonAuthRestoreFailureForTest() =>
      _handleNonAuthRestoreFailure();

  /// Test-only view of the consecutive config-timeout teardown count.
  @visibleForTesting
  int get configTimeoutTeardownsForTesting => _configTimeoutTeardowns;

  /// Shared pre-scan BLE cleanup for background reconnect paths.
  ///
  /// The radio may have just been released by another app, or the OS may
  /// hold a stale GATT handle to the target; scanning in that state finds
  /// nothing. Stops any active scan, disconnects stale system-device
  /// handles to [targetDeviceId], optionally verifies the Android bond
  /// still exists ([enforceBond]), and waits for the stack to settle.
  ///
  /// Returns [_BleCleanupOutcome.bondMissing] only when [enforceBond] is
  /// true and the target is absent from the Android bonded list; the
  /// caller owns the pairing-invalidation response.
  Future<_BleCleanupOutcome> _cleanupBleBeforeScan(
    String targetDeviceId, {
    required bool enforceBond,
    required String logContext,
  }) async {
    // 1. Stop any existing scan
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore
    }

    // 2. Check system devices for stale connections to our target
    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      for (final device in systemDevices) {
        if (device.remoteId.toString() == targetDeviceId) {
          AppLogging.connection(
            '🔌 $logContext: Found target in system devices, cleaning up...',
          );
          try {
            if (Platform.isAndroid) {
              await device.clearGattCache();
            }
            await device.disconnect();
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }
    } catch (e) {
      // Ignore
    }

    // 3. Android: Also check bonded devices
    if (enforceBond && Platform.isAndroid) {
      try {
        final bondedDevices = await FlutterBluePlus.bondedDevices;
        var foundInBonded = false;
        for (final device in bondedDevices) {
          if (device.remoteId.toString() == targetDeviceId) {
            foundInBonded = true;
            AppLogging.connection(
              '🔌 $logContext: Found target in bonded devices, cleaning up...',
            );
            try {
              await device.clearGattCache();
              if (device.isConnected) {
                await device.disconnect();
              }
            } catch (e) {
              // Ignore
            }
          }
        }

        if (!foundInBonded) {
          AppLogging.connection(
            '🔌 $logContext: Device NOT in bonded devices — '
            'bond was likely removed in Android Bluetooth settings.',
          );
          return _BleCleanupOutcome.bondMissing;
        }
      } catch (e) {
        // Ignore — proceed with connection attempt if bond check fails
        AppLogging.connection('🔌 $logContext: Bond check failed: $e');
      }
    }

    // 4. Wait for BLE to reset (longer on Android due to GATT cache)
    final resetDelay = Platform.isAndroid ? 1500 : 1000;
    AppLogging.connection(
      '🔌 $logContext: Waiting ${resetDelay}ms for BLE reset...',
    );
    await Future.delayed(Duration(milliseconds: resetDelay));
    return _BleCleanupOutcome.ready;
  }

  /// Start background connection attempt to known device
  Future<void> startBackgroundConnection() async {
    // Check if user manually disconnected - don't auto-reconnect
    if (_userDisconnected) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - user manually disconnected',
      );
      return;
    }

    // Manual scan is in flight (Scanner is actively driving the BLE
    // adapter). Skip background reconnect so the two don't race for the
    // adapter — the scanner publishes results into its own state and
    // resumes auto-reconnect on dispose / scan completion.
    if (ref.read(manualScanActiveProvider)) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - manual scan active '
        '(BLE_SCAN_AUTORECONNECT_SUPPRESSED)',
      );
      return;
    }

    // CRITICAL: Don't start a duplicate scan if the auto-reconnect manager
    // (_performReconnect) is already scanning or connecting. TopStatusBanner
    // can trigger startBackgroundConnection at the same time as the manager,
    // creating two concurrent BLE scans that race each other and cause
    // connection failures and BLE contention.
    final autoReconnectState = ref.read(autoReconnectStateProvider);
    if (autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - auto-reconnect manager '
        'already active ($autoReconnectState)',
      );
      return;
    }

    // If user is manually connecting from Scanner, don't race with their
    // chosen device connection.
    if (autoReconnectState == AutoReconnectState.manualConnecting) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - user is manually '
        'connecting from Scanner',
      );
      return;
    }

    // CRITICAL: Don't disrupt an already-connected device.
    // Without this guard, the aggressive BLE cleanup below disconnects
    // the active connection (finds it in system devices and calls
    // device.disconnect()), creating a cascade of disconnect→reconnect
    // cycles that can leave the app in a broken state.
    // This commonly happens when _initializeBackgroundServices() fires
    // multiple times (e.g. onboarding + terms acceptance both call
    // initialize()) while the scanner has already established a live
    // connection.
    if (state.isConnected) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - device already connected',
      );
      return;
    }

    // Also skip if we're in the middle of configuring (protocol handshake)
    if (state.state == DevicePairingState.configuring) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - connection configuring',
      );
      return;
    }

    // Guard against concurrent scans - only one background scan at a time
    if (_backgroundScanInProgress) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - scan already in progress',
      );
      return;
    }

    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: Saved device invalidated, skipping reconnect',
      );
      return;
    }

    final settings = await ref.read(settingsServiceProvider.future);

    // Check if auto-reconnect is enabled in settings
    if (!settings.autoReconnect) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: BLOCKED - auto-reconnect disabled in settings',
      );
      return;
    }

    final lastDeviceId = settings.lastDeviceId;
    final lastDeviceName = settings.lastDeviceName;
    final lastProtocol = settings.lastDeviceProtocol;

    if (lastDeviceId == null) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: No device to reconnect to',
      );
      return;
    }

    // MeshCore auto-reconnect uses _startMeshCoreBackgroundConnection instead
    if (lastProtocol == 'meshcore') {
      AppLogging.connection(
        '🔌 startBackgroundConnection: MeshCore device - use _startMeshCoreBackgroundConnection',
      );
      _backgroundScanInProgress = false;
      return;
    }

    // Network/TCP transport reconnect is endpoint-based, not scan-based.
    // The BLE scan loop below is meaningless for a TCP peer and would
    // also short-circuit on `Bluetooth is off` even when the user has
    // no intention of using BLE. Hand off to the central reconnect
    // dispatcher which routes `directEndpoint` to _performNetworkReconnect.
    //
    // Previously this branch deferred to autoReconnectManagerProvider's
    // transport-state listener, but at cold start the listener uses the
    // in-memory `_lastConnectedDeviceIdProvider` (null on fresh launch),
    // so no reconnect would ever be triggered — the user was left
    // staring at "Connecting…" forever.
    if (ref.read(transportProvider).reconnectMode ==
        TransportReconnectMode.directEndpoint) {
      AppLogging.connection(
        '🔌 startBackgroundConnection: transport reconnect mode is '
        'directEndpoint — dispatching network reconnect for $lastDeviceId',
      );
      _backgroundScanInProgress = false;
      state = state.copyWith(state: DevicePairingState.connecting);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);
      dispatchReconnectForDevice(ref, lastDeviceId);
      return;
    }

    // Check Bluetooth state first
    final btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      AppLogging.connection('🔌 startBackgroundConnection: Bluetooth is off');
      final l10n = safeL10n();
      state = state.copyWith(
        state: DevicePairingState.error,
        reason: DisconnectReason.bluetoothDisabled,
        errorMessage: l10n.connectionErrorBluetoothDisabled,
      );
      return;
    }

    // Mark scan as in progress
    _backgroundScanInProgress = true;

    AppLogging.connection(
      '🔌 startBackgroundConnection: Starting scan for: $lastDeviceId',
    );
    state = state.copyWith(state: DevicePairingState.scanning);

    // Also update legacy auto-reconnect state for compatibility
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.scanning);

    final transport = ref.read(transportProvider);
    DeviceInfo? foundDevice;

    try {
      // Aggressive BLE cleanup - device may have just been released by another app
      AppLogging.connection(
        '🔌 startBackgroundConnection: Aggressive BLE cleanup starting...',
      );
      final cleanup = await _cleanupBleBeforeScan(
        lastDeviceId,
        enforceBond: true,
        logContext: 'startBackgroundConnection',
      );
      if (cleanup == _BleCleanupOutcome.bondMissing) {
        // The saved device is NOT in the bonded list: the user likely
        // "forgot" it in Android Bluetooth settings. Attempting to connect
        // will fail with GATT 133 or auth errors, leaving the user stuck
        // on the Nodes Screen with a misleading "Device not found" banner.
        // Trigger pairing invalidation immediately so MainShell shows the
        // inline Scanner with clear guidance to re-pair.
        _backgroundScanInProgress = false;
        await handlePairingInvalidation(PairingInvalidationReason.peerReset);
        return;
      }

      // Scan for 5 seconds
      AppLogging.connection(
        '🔌 startBackgroundConnection: Starting 5s scan...',
      );
      await for (final device in transport.scan(
        timeout: const Duration(seconds: 5),
      )) {
        // Check again if user disconnected during scan
        if (_userDisconnected) {
          AppLogging.connection(
            '🔌 startBackgroundConnection: User disconnected during scan, aborting',
          );
          return;
        }
        AppLogging.connection(
          '🔌 startBackgroundConnection: Found device ${device.id} (looking for $lastDeviceId)',
        );
        if (device.id == lastDeviceId) {
          foundDevice = device;
          AppLogging.connection(
            '🔌 startBackgroundConnection: Target device found!',
          );
          break;
        }
      }

      if (foundDevice == null) {
        AppLogging.connection(
          '🔌 startBackgroundConnection: Device not found in scan (attempt ${_reconnectAttempt + 1})',
        );

        // Check if we're in region apply flow - use more aggressive retry.
        //
        // Read through `regionApplyInFlightProvider` (a leaf with no
        // upstream dependencies), NOT `regionConfigProvider`.
        // `regionConfigProvider`'s notifier listens to
        // `deviceConnectionProvider`, so reading it from inside
        // `DeviceConnectionNotifier` closes a Riverpod cycle and throws
        // `CircularDependencyError`. The leaf provider is set/cleared
        // by `RegionConfigNotifier` at apply-start and apply-finish
        // edges, so it stays in sync without participating in the
        // dependency graph.
        final isRegionApplying = ref.read(regionApplyInFlightProvider);

        // Set max attempts based on context
        _maxReconnectAttempts = isRegionApplying
            ? _maxReconnectAttemptsRegion // 6 attempts (60s) for region reboot
            : 3; // 3 attempts (30s) for normal reconnect

        // Check if we should retry
        if (_reconnectAttempt < _maxReconnectAttempts) {
          _reconnectAttempt++;
          final retryDelay = isRegionApplying
              ? 10000
              : 10000; // 10s between retries
          AppLogging.connection(
            '🔌 startBackgroundConnection: Will retry in ${retryDelay}ms '
            '(attempt $_reconnectAttempt/$_maxReconnectAttempts, regionApplying=$isRegionApplying)',
          );

          // Schedule retry
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(milliseconds: retryDelay), () {
            if (ref.mounted && !_userDisconnected) {
              AppLogging.connection(
                '🔌 startBackgroundConnection: Retry timer fired, attempt $_reconnectAttempt',
              );
              // Reset state so the scanning guard at the top of
              // startBackgroundConnection does not block this retry.
              ref
                  .read(autoReconnectStateProvider.notifier)
                  .setState(AutoReconnectState.idle);
              startBackgroundConnection();
            }
          });

          // Keep state as scanning during retry delay so the banner
          // stays visible. The timer callback resets to idle right
          // before re-entering startBackgroundConnection.
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.scanning);
          return;
        }

        // Max retries exceeded
        AppLogging.connection(
          '🔌 startBackgroundConnection: Max retries exceeded ($_maxReconnectAttempts attempts)',
        );
        _reconnectAttempt = 0; // Reset for next disconnect event

        // Platform-appropriate unreachable-vs-forgotten differentiation.
        //
        // Android: at the final scan-fail (about to enter unreachable
        // state), check the system bond list. If `lastDeviceId` is
        // missing, the user removed the device from Android Bluetooth
        // settings — surface a re-pair CTA instead of the generic
        // "Device not found" copy. The pre-scan cleanup branch above
        // already runs the same check, but it can be skipped if
        // `bondedDevices` threw, or the bond can be removed mid-scan.
        // This is the safety net.
        //
        // iOS: scan-fail alone is NEVER inferred as pairing
        // invalidation. There is no pre-connection bond-state API on
        // CBPeripheral, so the only reliable signal is a
        // connect/auth failure (handled separately in
        // `_connectToDevice`'s catch block). Falls through to the
        // existing unreachable behaviour.
        if (Platform.isAndroid) {
          try {
            final bondedDevices = await FlutterBluePlus.bondedDevices;
            final stillBonded = bondedDevices.any(
              (d) => d.remoteId.toString() == lastDeviceId,
            );
            if (!stillBonded) {
              AppLogging.connection(
                '🔌 startBackgroundConnection: Final scan-fail + bond '
                'missing for $lastDeviceId. Routing to pairing '
                'invalidation (bondForgotten).',
              );
              await handlePairingInvalidation(
                PairingInvalidationReason.bondForgotten,
              );
              return;
            }
            AppLogging.connection(
              '🔌 startBackgroundConnection: Final scan-fail with bond '
              'still present. Treating as unreachable (radio off / '
              'out of range).',
            );
          } catch (e) {
            // Bond query failed. Fall through to existing unreachable
            // path. Logging the failure so triage is not blind.
            AppLogging.connection(
              '🔌 startBackgroundConnection: Bond check at final scan-fail '
              'threw: $e. Falling through to unreachable.',
            );
          }
        } else {
          AppLogging.connection(
            '🔌 startBackgroundConnection: Final scan-fail on iOS. No '
            'pre-connect bond signal; treating as unreachable. Pairing '
            'invalidation only fires on connect/auth failure.',
          );
        }

        final invalidated = await reportMissingSavedDevice();
        if (!invalidated) {
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.failed);
        }
        return;
      }

      // Use stored name if scan didn't provide one
      if (foundDevice.name.isEmpty || foundDevice.name == 'Unknown') {
        foundDevice = DeviceInfo(
          id: foundDevice.id,
          name: lastDeviceName ?? foundDevice.name,
          type: foundDevice.type,
          rssi: foundDevice.rssi,
        );
      }

      // Final check before connecting
      if (_userDisconnected) {
        AppLogging.connection(
          '🔌 startBackgroundConnection: User disconnected before connect, aborting',
        );
        return;
      }

      // Reset retry counter on successful device find
      _reconnectAttempt = 0;
      _retryTimer?.cancel();

      await _connectToDevice(foundDevice);
    } catch (e) {
      if (state.state == DevicePairingState.pairedDeviceInvalidated) {
        return;
      }

      AppLogging.connection('🔌 startBackgroundConnection: Error: $e');
      state = state.copyWith(
        state: DevicePairingState.disconnected,
        reason: DisconnectReason.connectionFailed,
        errorMessage: e.toString(),
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);
    } finally {
      _backgroundScanInProgress = false;
    }
  }

  /// Public entry point for protocol-aware reconnect dispatch (D27).
  ///
  /// Used by `dispatchReconnectMeshCoreAware` and the MeshCore lifecycle
  /// listener so every mid-session reconnect for a saved MeshCore peer
  /// flows through the coordinator's protocol-aware path
  /// ([_startMeshCoreBackgroundConnection]) — TCP ids dispatch to
  /// `connectMeshCoreTcp`, BLE ids fall through to the BLE strategies,
  /// and the Meshtastic `transportProvider` is never consulted.
  ///
  /// Fire-and-forget: callers do not await the result. Internal state
  /// machine (`_backgroundScanInProgress`, autoReconnectStateProvider,
  /// devicePairingState) tracks progress for the UI.
  Future<void> startMeshCoreReconnect(String deviceId) async {
    final settings = await ref.read(settingsServiceProvider.future);
    await _startMeshCoreBackgroundConnection(deviceId, settings);
  }

  /// Start background connection for MeshCore device.
  ///
  /// Uses the same direct-connect-by-id strategy as resume reconnect.
  /// On iOS, scanning with service UUID filters can miss MeshCore devices,
  /// so we attempt direct connect first, then fall back to unfiltered scan.
  Future<void> _startMeshCoreBackgroundConnection(
    String deviceId,
    dynamic settings,
  ) async {
    AppLogging.connection(
      '🔌 MeshCore background connect: Starting for device: $deviceId',
    );

    // Guard against concurrent connection attempts
    if (_backgroundScanInProgress) {
      AppLogging.connection(
        '🔌 MeshCore background connect: BLOCKED - connection already in progress',
      );
      return;
    }

    // Check if already connected
    final coordinator = ref.read(connectionCoordinatorProvider);
    if (coordinator.isConnected) {
      AppLogging.connection(
        '🔌 MeshCore background connect: Already connected, skipping',
      );
      return;
    }

    if (coordinator.isConnecting) {
      AppLogging.connection(
        '🔌 MeshCore background connect: Connection already in progress, skipping',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // TCP fast-path: when `lastDeviceId` is the synthesised TCP form
    // `meshcore-tcp:<host>:<port>`, dispatch straight to the coordinator's
    // TCP entry point. The BLE strategies below cannot find a TCP peer in
    // any of their lookup mechanisms (FlutterBluePlus.systemDevices, scan
    // results), so without this branch a TCP peer never reconnects.
    //
    // The TCP path doesn't require Bluetooth, so we also skip the BT
    // adapter precondition for TCP devices.
    // -------------------------------------------------------------------------
    final tcpId = MeshCoreTcpDeviceId.tryParse(deviceId);
    if (tcpId != null) {
      AppLogging.connection(
        '🔌 MeshCore background connect: TCP fast-path host=${tcpId.host} '
        'port=${tcpId.port}',
      );
      state = state.copyWith(state: DevicePairingState.scanning);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);

      _backgroundScanInProgress = true;
      try {
        final result = await coordinator.connectMeshCoreTcp(
          host: tcpId.host,
          port: tcpId.port,
        );
        if (result.success) {
          state = state.copyWith(
            state: DevicePairingState.connected,
            connectionSessionId: _connectionSessionId,
          );
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.idle);
          AppLogging.connection(
            '🔌 MeshCore background connect: TCP fast-path succeeded',
          );
        } else {
          state = state.copyWith(
            state: DevicePairingState.error,
            errorMessage: result.errorMessage,
          );
          ref
              .read(autoReconnectStateProvider.notifier)
              .setState(AutoReconnectState.failed);
          AppLogging.connection(
            '🔌 MeshCore background connect: TCP fast-path failed: '
            '${result.errorMessage}',
          );
        }
      } finally {
        _backgroundScanInProgress = false;
      }
      return;
    } else if (deviceId.startsWith(MeshCoreTcpDeviceId.prefix)) {
      // Looks like a TCP id but didn't parse. Bail rather than fall
      // through to BLE (which would scan forever for a non-BLE peer).
      AppLogging.connection(
        '🔌 MeshCore background connect: TCP id malformed: $deviceId',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);
      return;
    }

    // Check Bluetooth state first
    final btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      AppLogging.connection('🔌 MeshCore background connect: Bluetooth is off');
      final l10n = safeL10n();
      state = state.copyWith(
        state: DevicePairingState.error,
        reason: DisconnectReason.bluetoothDisabled,
        errorMessage: l10n.connectionErrorBluetoothDisabled,
      );
      return;
    }

    _backgroundScanInProgress = true;

    try {
      // Update state to scanning/connecting
      state = state.copyWith(state: DevicePairingState.scanning);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);

      // Strategy 1: Direct connect by device identifier
      AppLogging.connection(
        '🔌 MeshCore background connect: Strategy 1 - direct connect by ID',
      );

      DeviceInfo foundDevice;

      // Check system devices first (iOS may know about the peripheral)
      try {
        final systemDevices = await FlutterBluePlus.systemDevices([]);
        AppLogging.connection(
          '🔌 MeshCore background connect: Found ${systemDevices.length} system devices',
        );

        DeviceInfo? fromSystem;
        for (final device in systemDevices) {
          if (device.remoteId.toString() == deviceId) {
            AppLogging.connection(
              '🔌 MeshCore background connect: Target found in system devices',
            );
            fromSystem = DeviceInfo(
              id: device.remoteId.toString(),
              name: device.platformName.isNotEmpty
                  ? device.platformName
                  : settings.lastDeviceName ??
                        'MeshCore Device', // lint-allow: hardcoded-string
              type: TransportType.ble,
              address: device.remoteId.toString(),
            );
            break;
          }
        }

        foundDevice =
            fromSystem ??
            DeviceInfo(
              id: deviceId,
              name:
                  settings.lastDeviceName ??
                  'MeshCore Device', // lint-allow: hardcoded-string
              type: TransportType.ble,
              address: deviceId,
            );
      } catch (e) {
        AppLogging.connection(
          '🔌 MeshCore background connect: System devices check failed: $e',
        );
        foundDevice = DeviceInfo(
          id: deviceId,
          name:
              settings.lastDeviceName ??
              'MeshCore Device', // lint-allow: hardcoded-string
          type: TransportType.ble,
          address: deviceId,
        );
      }

      // Try direct connection
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);
      state = state.copyWith(state: DevicePairingState.connecting);

      var result = await coordinator.connect(device: foundDevice);

      if (result.success) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Direct connect succeeded!',
        );
        await _finalizeMeshCoreConnect(foundDevice, result, settings);
        return;
      }

      // Strategy 2: Fall back to unfiltered scan
      AppLogging.connection(
        '🔌 MeshCore background connect: Direct connect failed (${result.errorMessage}), '
        'trying Strategy 2 - unfiltered scan',
      );

      // The failed direct connect may have left the OS holding a stale
      // handle to the target, which makes the unfiltered scan blind to
      // it. Same cleanup as the Meshtastic path, minus the bond check
      // (a missing bond is handled by the connect failure itself here).
      await _cleanupBleBeforeScan(
        deviceId,
        enforceBond: false,
        logContext: 'MeshCore background connect',
      );

      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);
      state = state.copyWith(state: DevicePairingState.scanning);

      final transport = ref.read(transportProvider);
      DeviceInfo? scannedDevice;

      await for (final device in transport.scan(
        timeout: const Duration(seconds: 10),
        scanAll: true, // Don't filter by service UUID
      )) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Scan found: ${device.id}',
        );
        if (device.id == deviceId) {
          scannedDevice = device;
          break;
        }
      }

      if (scannedDevice == null) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Device not found in scan',
        );
        state = state.copyWith(
          state: DevicePairingState.disconnected,
          reason: DisconnectReason.deviceNotFound,
          errorMessage: safeL10n().connectionErrorDeviceNotFound,
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);
        return;
      }

      // Try connect with scanned device
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.connecting);
      state = state.copyWith(state: DevicePairingState.connecting);

      result = await coordinator.connect(device: scannedDevice);

      if (!result.success) {
        AppLogging.connection(
          '🔌 MeshCore background connect: Scanned device connect failed: ${result.errorMessage}',
        );
        state = state.copyWith(
          state: DevicePairingState.disconnected,
          reason: DisconnectReason.connectionFailed,
          errorMessage:
              result.errorMessage ??
              'Connection failed', // lint-allow: hardcoded-string
        );
        ref
            .read(autoReconnectStateProvider.notifier)
            .setState(AutoReconnectState.failed);
        return;
      }

      AppLogging.connection(
        '🔌 MeshCore background connect: Scanned device connect succeeded!',
      );
      await _finalizeMeshCoreConnect(scannedDevice, result, settings);
    } catch (e) {
      AppLogging.connection('🔌 MeshCore background connect: Error: $e');
      state = state.copyWith(
        state: DevicePairingState.disconnected,
        reason: DisconnectReason.connectionFailed,
        errorMessage: e.toString(),
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);
    } finally {
      _backgroundScanInProgress = false;
    }
  }

  /// Finalize MeshCore connection by updating all state providers.
  Future<void> _finalizeMeshCoreConnect(
    DeviceInfo device,
    ConnectionResult result,
    dynamic settings,
  ) async {
    // Update connected device provider
    ref.read(connectedDeviceProvider.notifier).setState(device);

    // Parse node ID for pairing state
    final nodeIdHex = result.deviceInfo?.nodeId ?? '0';
    final nodeNumParsed = int.tryParse(nodeIdHex, radix: 16);

    // Update pairing state
    state = state.copyWith(
      state: DevicePairingState.connected,
      device: device,
      myNodeNum: nodeNumParsed,
      reason: DisconnectReason.none,
      connectionSessionId: _nextConnectionSessionId(),
    );

    // Mark as paired in the pairing helper (with MeshCore flag)
    markAsPaired(device, nodeNumParsed, isMeshCore: true);

    // Clear user disconnected flags
    _userDisconnected = false;
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);

    AppLogging.connection(
      '🔌 MeshCore background connect: Finalized, device=${result.deviceInfo?.displayName}',
    );

    // Set success state briefly then idle
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.success);

    await Future.delayed(const Duration(milliseconds: 500));
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);
  }

  Future<bool> reportMissingSavedDevice() async {
    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      return true;
    }

    final now = DateTime.now();
    if (_firstMissingAttemptAt == null ||
        now.difference(_firstMissingAttemptAt!) > _invalidationWindow) {
      _firstMissingAttemptAt = now;
      _missingDeviceAttempts = 0;
    }

    _missingDeviceAttempts++;

    if (_missingDeviceAttempts >= _maxInvalidationAttempts) {
      await handlePairingInvalidation(PairingInvalidationReason.missingDevice);
      return true;
    }

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.deviceNotFound,
      errorMessage: safeL10n().connectionErrorDeviceNotFound,
    );

    return false;
  }

  void _resetInvalidationTracking() {
    _missingDeviceAttempts = 0;
    _firstMissingAttemptAt = null;
  }

  /// Public helper so other providers can force an invalidation.
  Future<void> handlePairingInvalidation(
    PairingInvalidationReason reason, {
    int? appleCode,
  }) async {
    await _handlePairingInvalidated(reason: reason, appleCode: appleCode);
  }

  Future<void> _handlePairingInvalidated({
    required PairingInvalidationReason reason,
    int? appleCode,
  }) async {
    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      return;
    }

    final settings = await ref.read(settingsServiceProvider.future);
    final savedDeviceId =
        state.device?.id ?? settings.lastDeviceId ?? 'unknown';
    final appleCodeLabel = appleCode?.toString() ?? 'n/a';

    AppLogging.connection(
      'PAIRING_INVALIDATED deviceId=$savedDeviceId reason=${reason.logValue} appleCode=$appleCodeLabel',
    );
    AppErrorHandler.addBreadcrumb(
      'Pairing invalidated: reason=${reason.logValue}, ' // lint-allow: hardcoded-string
      'appleCode=$appleCodeLabel, device=$savedDeviceId', // lint-allow: hardcoded-string
    );

    _resetInvalidationTracking();
    _backgroundScanInProgress = false;
    _scanTimer?.cancel();
    _userDisconnected = false;

    final transport = ref.read(transportProvider);
    try {
      await transport.disconnect();
    } catch (_) {
      // Ignore disconnect errors during invalidation.
    }

    await clearDeviceDataBeforeConnectRef(ref, clearNodeData: true);
    await settings.clearLastDevice();
    clearSavedDeviceId(ref);
    ref.read(connectedDeviceProvider.notifier).setState(null);
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.failed);

    // UX copy is reason-specific. `bondForgotten` is the
    // Android-only "user removed the device from Bluetooth settings"
    // case and gets re-pair guidance; every other reason keeps the
    // existing "Device was reset or replaced" copy. Only fire the
    // re-pair text when there is an actual pairing/auth signal — a
    // plain scan-fail with the bond still present must NOT reach this
    // branch (the call site checks bond presence first).
    final errorMessage = reason == PairingInvalidationReason.bondForgotten
        ? safeL10n().connectionErrorBondForgotten
        : safeL10n().connectionErrorDeviceReset;

    state = DeviceConnectionState2(
      state: DevicePairingState.pairedDeviceInvalidated,
      reason: DisconnectReason.deviceNotFound,
      errorMessage: errorMessage,
      connectionSessionId: _connectionSessionId,
    );
  }

  /// Connect to a specific device
  Future<void> connectToDevice(DeviceInfo device) async {
    await _connectToDevice(device);
  }

  Future<void> _connectToDevice(DeviceInfo device) async {
    AppLogging.connection('Connecting to: ${device.name} (${device.id})');

    // Explicit user-initiated connect clears the disconnect latch.
    // The `RestoreSessionCoordinator.isUserDisconnected` guard exists
    // to block opportunistic restore paths (auto-reconnect, lifecycle
    // resume) from resurrecting a session after the user tapped
    // Disconnect. `_connectToDevice` is the opposite: an explicit tap
    // (Scanner, banner Reconnect) saying "yes, connect now". Without
    // this clear, the coordinator skipped `protocol.start()` after a
    // prior disconnect, transport came up but readiness stayed at
    // `idle`, and the missing `myNodeNum` was misdiagnosed as
    // Authentication failed.
    clearUserDisconnected();

    state = state.copyWith(
      state: DevicePairingState.connecting,
      device: device,
    );
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.connecting);

    // Central transition prep runs BEFORE the transport read so we bind
    // against the right transport family (the user may have manually
    // connected via TCP last session and transportTypeProvider would
    // otherwise still point at network when they tap a BLE device).
    // prepareForDeviceTransitionRef: classifies, persists new identity,
    // clears state in the correct order, then flips transport type.
    await prepareForDeviceTransitionRef(
      ref,
      device: device,
      deviceProtocol: 'meshtastic',
    );

    final transport = ref.read(transportProvider);

    try {
      await transport.connect(device);

      if (transport.state != DeviceConnectionState.connected) {
        throw Exception('BLE connection failed');
      }

      state = state.copyWith(state: DevicePairingState.configuring);

      // Start protocol service
      final protocol = ref.read(protocolServiceProvider);
      protocol.setDeviceName(device.name);
      protocol.setBleModelNumber(transport.bleModelNumber);
      protocol.setBleManufacturerName(transport.bleManufacturerName);

      AppLogging.connection('Starting protocol...');
      // Route through the canonical restore routine so the BLE-restoration
      // safety net (refreshNotifications + clean stop+start) runs on every
      // fresh connect too — a freshly-paired session can also inherit a
      // stale subscription from a prior `_RecordingTransport` lifecycle on
      // some flutter_blue_plus / iOS combinations.
      await _restoreCoordinator.restoreSession(reason: 'connect_to_device');

      // Verify we got configuration
      if (protocol.myNodeNum == null) {
        AppLogging.connection(
          'Protocol started but no myNodeNum - auth failed',
        );
        // Set flag BEFORE transport.disconnect() so _handleDisconnect
        // sees authFailed and calls setNeedsScanner() instead of treating
        // it as an unexpected disconnect (which just shows a "Device not
        // found" banner with a useless Retry button). This mirrors the
        // same pattern in _initializeProtocolAfterAutoReconnect().
        _authFailurePending = true;
        await transport.disconnect();
        throw Exception('Authentication failed');
      }

      AppLogging.connection('Connected! myNodeNum: ${protocol.myNodeNum}');

      // Update state immediately so consumers know we're connected
      AppLogging.connection(
        'Device fully connected – allowing Go Active to enable',
      );
      state = state.copyWith(
        state: DevicePairingState.connected,
        device: device,
        lastConnectedAt: DateTime.now(),
        myNodeNum: protocol.myNodeNum,
        reason: DisconnectReason.none,
        reconnectAttempts: 0,
        connectionSessionId: _nextConnectionSessionId(),
      );

      // Update legacy providers for compatibility
      ref.read(connectedDeviceProvider.notifier).setState(device);
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.success);
      _resetInvalidationTracking();

      // Start location updates after signalling connection
      final locationService = ref.read(locationServiceProvider);
      await locationService.startLocationUpdates();

      // Mark region as configured (reconnecting to known device)
      final settings = await ref.read(settingsServiceProvider.future);
      if (!settings.regionConfigured) {
        await settings.setRegionConfigured(true);
      }
    } catch (e) {
      if (isPairingInvalidationError(e)) {
        await handlePairingInvalidation(
          PairingInvalidationReason.peerReset,
          appleCode: pairingInvalidationAppleCode(e),
        );
        rethrow;
      }

      // On Android, GATT error 133 during auto-reconnect with a missing
      // bond means the user "forgot" the device in Bluetooth settings.
      // Verify the bond is actually gone before treating it as pairing
      // invalidation (133 can also mean cache corruption or range issues
      // when the bond is intact).
      if (Platform.isAndroid) {
        final errorStr = e.toString().toLowerCase();
        final isGatt133 =
            errorStr.contains('android-code: 133') ||
            (errorStr.contains('gatt_error') &&
                !errorStr.contains('android-code:'));
        if (isGatt133) {
          try {
            final bondedDevices = await FlutterBluePlus.bondedDevices;
            final isStillBonded = bondedDevices.any(
              (d) => d.remoteId.toString() == device.id,
            );
            if (!isStillBonded) {
              AppLogging.connection(
                '🔌 _connectToDevice: GATT 133 + bond missing — '
                'device was forgotten in Android Bluetooth settings. '
                'Triggering pairing invalidation.',
              );
              await handlePairingInvalidation(
                PairingInvalidationReason.peerReset,
              );
              rethrow;
            }
          } catch (bondCheckError) {
            // Bond check itself failed — fall through to normal error handling
            AppLogging.connection(
              '🔌 _connectToDevice: Bond check after GATT 133 failed: $bondCheckError',
            );
          }
        }
      }

      AppLogging.connection('Connection failed: $e');

      final reason = e.toString().contains('Authentication')
          ? DisconnectReason.authFailed
          : e.toString().contains('timeout')
          ? DisconnectReason.configTimeout
          : DisconnectReason.connectionFailed;

      state = state.copyWith(
        state: DevicePairingState.error,
        reason: reason,
        errorMessage: e.toString(),
        reconnectAttempts: state.reconnectAttempts + 1,
      );

      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.failed);

      rethrow;
    }
  }

  /// Handle disconnection
  void _handleDisconnect(DisconnectReason reason) {
    // If an auth/PIN failure triggered this disconnect, override the
    // reason so it propagates correctly to the UI (Scanner shows
    // guidance cards instead of MainShell showing a "Device not found"
    // banner that loops on retry).
    if (_authFailurePending) {
      _authFailurePending = false;
      reason = DisconnectReason.authFailed;
      AppLogging.connection(
        '🔌 _handleDisconnect: Overriding reason to authFailed '
        '(PIN/auth failure triggered this disconnect)',
      );
    }

    AppLogging.connection(
      '🔌 _handleDisconnect: reason=$reason, currentState=${state.state}',
    );

    // Debug: Log stack trace to identify who triggered this disconnect
    if (kDebugMode) {
      AppLogging.connection(
        '🔌 _handleDisconnect called from:\n${StackTrace.current}',
      );
    }

    if (state.state == DevicePairingState.pairedDeviceInvalidated) {
      AppLogging.connection(
        '🔌 _handleDisconnect: Saved device invalidated, ignoring',
      );
      return;
    }

    if (state.state == DevicePairingState.neverPaired) {
      AppLogging.connection('🔌 _handleDisconnect: Never paired, ignoring');
      return; // No device to reconnect to
    }

    // Pairing-invalidation routing.
    //
    // Apple Core Bluetooth surfaces a peer-removed-pairing event by
    // throwing FlutterBluePlusException(apple-code: 14, "Peer removed
    // pairing information") inside connect(). The exception is rethrown
    // to the caller (Scanner._connectToDevice), but the transport ALSO
    // emits a disconnected/error state, which lands here through the
    // listener. Without the routing below, this path silently downgrades
    // the failure to unexpectedDisconnect and the auto-reconnect manager
    // spins. Consult the transport's last captured connect error and
    // route to the existing pairing-invalidation flow when it matches.
    final transport = ref.read(transportProvider);
    if (transport is BleTransport) {
      final lastError = transport.lastDisconnectError;
      if (lastError != null && isPairingInvalidationError(lastError)) {
        final appleCode = pairingInvalidationAppleCode(lastError);
        AppLogging.connection(
          'PAIRING_INVALIDATED platform=ios '
          'reason=peer_removed_pairing_information '
          'appleCode=${appleCode ?? "n/a"}',
        );
        transport.clearLastDisconnectError();
        unawaited(
          handlePairingInvalidation(
            PairingInvalidationReason.peerReset,
            appleCode: appleCode,
          ),
        );
        return;
      }
    }

    // Structured teardown context recorded by the transport at the
    // origin that observed the drop (OS state change, notify stream
    // closing, watchdog force-disconnect). Stamped into errorMessage so
    // in-app bug reports carry it verbatim.
    final disconnectDetail = transport is ReceiveDiagnosticsSupport
        ? (transport as ReceiveDiagnosticsSupport).lastDisconnectDetail
        : null;

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: reason,
      errorMessage: disconnectDetail?.toCompactString(),
    );

    // Tell the protocol service the prior session's config is no
    // longer authoritative. Without this, `_isStarted`,
    // `_configurationComplete`, and `_myNodeNum` survive the
    // disconnect, and the next reconnect's
    // `_initializeProtocolAfterAutoReconnect` skips `protocol.start()`
    // (and `protocol.start()` itself skips on its internal
    // `_isStarted && _transport.isConnected` guard once the transport
    // flips back to connected). The result was Nodes (0) forever
    // after any reboot — region apply, nodeDbReset, factoryReset —
    // because no fresh `NodeInfo` packets ever arrived.
    //
    // We don't call the heavier `protocol.stop()` here: the transport
    // already cleaned up its side of the link, and a full stop would
    // also tear down RSSI/data subscriptions that the next
    // `protocol.start()` is about to re-establish anyway.
    try {
      ref.read(protocolServiceProvider).resetForReconnect();
    } catch (e) {
      AppLogging.connection(
        '🔌 _handleDisconnect: protocol.resetForReconnect failed (non-fatal): $e',
      );
    }

    // Preserve the user's chosen transport type across disconnect.
    // Previous behavior forced network → ble on disconnect to resume BLE
    // scanning, but that silently erased the user's intent and broke TCP
    // continuity: reconnect logic would then scan for BLE devices of a
    // node the user connected to over the network. Transport changes
    // must be explicit user actions (Scanner UI / Network section) —
    // never an implicit side effect of disconnect cleanup.
    ref.read(connectedDeviceProvider.notifier).setState(null);

    // If user disconnected, don't trigger any auto-reconnect behavior
    if (reason == DisconnectReason.userDisconnected) {
      AppLogging.connection(
        '🔌 _handleDisconnect: User-initiated disconnect, no auto-reconnect',
      );
      ref
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
    } else {
      if (reason == DisconnectReason.authFailed) {
        // Region apply triggers an EXPECTED transport disconnect (the
        // device reboots after writing the new region). If a region
        // apply is in flight, this is not a fault — skip the
        // setNeedsScanner() that would otherwise stomp the
        // RegionSelectionScreen's `setInitialized()` after it pops.
        // The auto-reconnect manager handles the reboot reconnect on
        // its own.
        //
        // We read `regionApplyInFlightProvider` (a leaf with no
        // upstream dependencies) instead of `regionConfigProvider`
        // because `RegionConfigNotifier.build()` listens to
        // `deviceConnectionProvider`. Reading it from this method
        // would close a cycle and Riverpod 3.x throws
        // `CircularDependencyError`. The leaf is set true at apply
        // start and false in the `finally` of `applyRegion`, so the
        // gate is exact.
        final regionApplying = ref.read(regionApplyInFlightProvider);
        if (regionApplying) {
          AppLogging.connection(
            'DISCONNECT_HANDLER_SKIPPED_REGION_APPLYING reason=$reason '
            'regionApplyInFlight=true',
          );
        } else {
          // PIN/auth failure: route to Scanner where the user gets
          // guidance cards (forget device in Bluetooth settings, etc.)
          // instead of staying on MainShell with a misleading
          // "Device not found" banner that just loops on retry.
          AppLogging.connection(
            '🔌 _handleDisconnect: Auth failure — '
            'setting needsScanner to route to Scanner screen',
          );
          ref.read(appInitProvider.notifier).setNeedsScanner();
        }
      } else {
        // Unexpected disconnect (e.g., device reboot after region change).
        // Do NOT call startBackgroundConnection() here — the
        // autoReconnectManagerProvider listener on connectionStateProvider
        // already detects this disconnect and calls _performReconnect(),
        // which has its own scan loop with retry logic. Calling
        // startBackgroundConnection() from here creates a dual-scan race:
        // both _performReconnect's FlutterBluePlus.startScan AND
        // startBackgroundConnection's transport.scan run concurrently,
        // causing BLE contention, interleaved scan results, and
        // connection failures.
        //
        // startBackgroundConnection() is still used for app-launch
        // reconnect (called from initialize()), which is the correct
        // single-path reconnect on startup.
        AppLogging.connection(
          '🔌 _handleDisconnect: Unexpected disconnect — '
          'autoReconnectManagerProvider will handle reconnect',
        );
        final foreground = ref.read(appLifecycleProvider);
        final protocol = ref.read(protocolServiceProvider);
        AppLogging.connection(
          'DISCONNECT_CONTEXT '
          '${disconnectDetail?.toLogPayload() ?? 'origin=unknown'} '
          'foreground=$foreground '
          'reconnectAttempts=${state.reconnectAttempts} '
          'readiness=${protocol.readiness.name} '
          'phase=${protocol.handshakePhaseName} '
          'configFrames=${protocol.configFramesSinceHandshake}',
        );

        // Defense: if the latch is still set but the Scanner is no
        // longer mounted, the manual connect's `try/catch/finally`
        // can no longer clear it — the future is orphaned. Clear here
        // as a safety net so recovery (auto-reconnect / APP RESUMED)
        // is not perma-blocked. Scanner-still-mounted cases are
        // handled by `_connectToDevice`'s catch + Scanner dispose's
        // session-aware clear.
        final autoState = ref.read(autoReconnectStateProvider);
        if (autoState == AutoReconnectState.manualConnecting) {
          final mountCount = ref.read(scannerMountCountProvider);
          if (mountCount == 0) {
            AppLogging.connection(
              'MANUAL_CONNECT_CLEARED session=disconnect_handler '
              'reason=unexpected_disconnect_no_scanner '
              'scannerMountCount=$mountCount',
            );
            ref
                .read(autoReconnectStateProvider.notifier)
                .setState(AutoReconnectState.idle);
          }
        }
      }
      // Reset retry counter so the next startBackgroundConnection
      // (if triggered by autoReconnectManager) starts fresh.
      _reconnectAttempt = 0;
    }
  }

  /// Manually disconnect - prevents auto-reconnect
  Future<void> disconnect() async {
    AppLogging.connection('🔌 disconnect(): Starting manual disconnect...');

    // Mark that user intentionally disconnected - prevents any auto-reconnect
    _userDisconnected = true;
    _backgroundScanInProgress = false; // Clear scan guard to allow future scans
    AppLogging.connection('🔌 disconnect(): Set _userDisconnected=true');
    // Bump the restore generation so any in-flight `restoreSession()`
    // (e.g. a lifecycle-resume restore that started a moment ago) aborts
    // at its next stale check before touching protocol/transport.
    _restoreCoordinator.invalidate('user_disconnect');

    // Also sync with the global userDisconnectedProvider
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(true);

    _scanTimer?.cancel();
    _retryTimer?.cancel();
    _reconnectAttempt = 0; // Reset retry counter

    // Stop any active scans before disconnecting
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore
    }

    final transport = ref.read(transportProvider);
    AppLogging.connection('🔌 disconnect(): Calling transport.disconnect()...');
    await transport.disconnect();
    AppLogging.connection('🔌 disconnect(): Transport disconnected');

    // Preserve the user's chosen transport type across manual disconnect.
    // See `_handleDisconnect` for the full rationale — transport changes
    // must be explicit user actions (Scanner UI), not disconnect side
    // effects.

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.userDisconnected,
    );

    ref.read(connectedDeviceProvider.notifier).setState(null);
    ref
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.idle);

    AppLogging.connection('🔌 disconnect(): Manual disconnect complete');
  }

  /// Clear the user disconnected flag - call when user explicitly wants to reconnect
  void clearUserDisconnected() {
    AppLogging.connection(
      '🔌 clearUserDisconnected(): Clearing flag to allow reconnect',
    );
    _userDisconnected = false;

    // Also sync with the global userDisconnectedProvider
    ref.read(userDisconnectedProvider.notifier).setUserDisconnected(false);
  }

  /// Retry connection after error
  Future<void> retryConnection() async {
    if (state.state == DevicePairingState.neverPaired) return;

    state = state.copyWith(
      state: DevicePairingState.disconnected,
      reason: DisconnectReason.none,
    );

    await startBackgroundConnection();
  }

  /// Mark as paired after first successful connection from scanner.
  ///
  /// [isMeshCore] - If true, this is a MeshCore connection. The Meshtastic
  /// transport listener will NOT be set up (MeshCore uses its own transport).
  /// This prevents the immediate disconnect that occurs when the Meshtastic
  /// transport's disconnected state triggers `_handleDisconnect`.
  bool _reconciledThisSession = false;

  void markAsPaired(
    DeviceInfo device,
    int? myNodeNum, {
    bool isMeshCore = false,
  }) {
    // CRITICAL: Only set up the Meshtastic connection listener for Meshtastic devices.
    // MeshCore uses ConnectionCoordinator which manages its own transport.
    // Setting up the Meshtastic listener for MeshCore would cause immediate
    // disconnect because the Meshtastic transport is in disconnected state.
    if (!isMeshCore) {
      _setupConnectionListener();
      AppLogging.connection(
        '🔌 markAsPaired: Meshtastic device, transport listener active',
      );
    } else {
      // For MeshCore, cancel any existing Meshtastic transport listener
      // to prevent spurious disconnect events
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      AppLogging.connection(
        '🔌 markAsPaired: MeshCore device, skipping Meshtastic transport listener',
      );
    }

    // Mark as initialized so future calls don't re-run build() initialization
    _isInitialized = true;
    _userDisconnected = false;

    state = DeviceConnectionState2(
      state: DevicePairingState.connected,
      device: device,
      lastConnectedAt: DateTime.now(),
      myNodeNum: myNodeNum,
      connectionSessionId: _nextConnectionSessionId(),
    );
    _resetInvalidationTracking();

    AppLogging.connection(
      '🔌 markAsPaired: device=${device.id}, myNodeNum=$myNodeNum, isMeshCore=$isMeshCore',
    );

    // Prompt for battery optimization exemption on first BLE connection
    // (Android only, Meshtastic only). Fire-and-forget — the prompt is
    // non-blocking and stores its own "shown" flag.
    if (!isMeshCore) {
      Future.microtask(() async {
        try {
          await BackgroundBleService.instance
              .promptBatteryOptimizationIfNeeded();
        } catch (e) {
          AppLogging.connection('🔌 Battery optimization prompt error: $e');
        }
      });
    }

    // Wire the background reconnect manager for Meshtastic devices.
    // This provides exponential-backoff BLE reconnection when the app is
    // backgrounded and the OS drops the BLE link. The callbacks close over
    // the provider-layer state so the manager remains Riverpod-free.
    if (!isMeshCore) {
      final transport = ref.read(transportProvider);
      BackgroundBleService.instance.reconnectManager.observe(
        transportStateStream: transport.stateStream,
        reconnect: () async {
          // Guard against double-connect if the provider-layer reconnect
          // is already handling it.
          if (transport.isConnected ||
              transport.state == DeviceConnectionState.connecting) {
            return true;
          }
          try {
            await transport.connect(device);
            return true;
          } catch (e) {
            AppLogging.connection('🔌 BackgroundReconnect callback error: $e');
            return false;
          }
        },
        isUserDisconnected: () => _userDisconnected,
        isRebootExpected: () => ref.read(rebootExpectedProvider),
        deviceName: device.name,
      );
    }

    // Run one-shot reconciliation for this node on connect (Meshtastic only)
    // MeshCore doesn't use the same message storage/reconciliation
    if (!isMeshCore && !_reconciledThisSession && myNodeNum != null) {
      _reconciledThisSession = true;
      AppLogging.connection('🔌 Running reconnect canary for node $myNodeNum');
      // Fire-and-forget reconcile
      Future.microtask(() async {
        try {
          await ref
              .read(messagesProvider.notifier)
              .reconcileFromStorageForNode(myNodeNum);
        } catch (e) {
          AppLogging.connection('🔌 Reconnect canary error: $e');
        }
      });
    }
  }
}

final deviceConnectionProvider =
    NotifierProvider<DeviceConnectionNotifier, DeviceConnectionState2>(
      DeviceConnectionNotifier.new,
    );

// =============================================================================
// FEATURE REQUIREMENT SYSTEM
// =============================================================================

/// Feature requirements for gating
enum FeatureRequirement {
  /// No requirements - always available (settings, about, account)
  none,

  /// Requires network (Firebase) - social features
  network,

  /// Can work with cached data when disconnected
  cached,

  /// Requires active device connection
  deviceConnection,
}

/// Feature identifiers for the registry
enum FeatureId {
  // Tier 0 - No requirements (always available)
  settings,
  about,
  account,
  profileView,
  deviceShop,
  subscription,
  themeSettings,

  // Tier 1 - Network only (social/cloud features)
  socialFeed,
  stories,
  followers,
  cloudSync,
  socialPost,
  socialComment,
  socialLike,
  profileEdit,
  worldMap,

  // Tier 2 - Cached data (works offline with previous data)
  messageHistory,
  nodeList,
  channelList,
  mapView,
  timeline,
  presence,

  // Tier 3 - Device connection required (mesh operations)
  sendMessage,
  deviceConfig,
  traceroute,
  nodeActions,
  channelConfig,
  positionShare,
  requestPosition,
  sendBell,
  removeNode,
  rebootDevice,
  factoryReset,
  setOwner,
  regionSetup,
  rangeTest,
  storeForward,
}

/// Feature registry - maps features to their requirements
const Map<FeatureId, FeatureRequirement> _featureRegistry = {
  // Tier 0 - Always available
  FeatureId.settings: FeatureRequirement.none,
  FeatureId.about: FeatureRequirement.none,
  FeatureId.account: FeatureRequirement.none,
  FeatureId.profileView: FeatureRequirement.none,
  FeatureId.deviceShop: FeatureRequirement.none,
  FeatureId.subscription: FeatureRequirement.none,
  FeatureId.themeSettings: FeatureRequirement.none,

  // Tier 1 - Network required
  FeatureId.socialFeed: FeatureRequirement.network,
  FeatureId.stories: FeatureRequirement.network,
  FeatureId.followers: FeatureRequirement.network,
  FeatureId.cloudSync: FeatureRequirement.network,
  FeatureId.socialPost: FeatureRequirement.network,
  FeatureId.socialComment: FeatureRequirement.network,
  FeatureId.socialLike: FeatureRequirement.network,
  FeatureId.profileEdit: FeatureRequirement.network,
  FeatureId.worldMap: FeatureRequirement.network,

  // Tier 2 - Cached data
  FeatureId.messageHistory: FeatureRequirement.cached,
  FeatureId.nodeList: FeatureRequirement.cached,
  FeatureId.channelList: FeatureRequirement.cached,
  FeatureId.mapView: FeatureRequirement.cached,
  FeatureId.timeline: FeatureRequirement.cached,
  FeatureId.presence: FeatureRequirement.cached,

  // Tier 3 - Device connection required
  FeatureId.sendMessage: FeatureRequirement.deviceConnection,
  FeatureId.deviceConfig: FeatureRequirement.deviceConnection,
  FeatureId.traceroute: FeatureRequirement.deviceConnection,
  FeatureId.nodeActions: FeatureRequirement.deviceConnection,
  FeatureId.channelConfig: FeatureRequirement.deviceConnection,
  FeatureId.positionShare: FeatureRequirement.deviceConnection,
  FeatureId.requestPosition: FeatureRequirement.deviceConnection,
  FeatureId.sendBell: FeatureRequirement.deviceConnection,
  FeatureId.removeNode: FeatureRequirement.deviceConnection,
  FeatureId.rebootDevice: FeatureRequirement.deviceConnection,
  FeatureId.factoryReset: FeatureRequirement.deviceConnection,
  FeatureId.setOwner: FeatureRequirement.deviceConnection,
  FeatureId.regionSetup: FeatureRequirement.deviceConnection,
  FeatureId.rangeTest: FeatureRequirement.deviceConnection,
  FeatureId.storeForward: FeatureRequirement.deviceConnection,
};

/// Get the requirement for a feature
FeatureRequirement getFeatureRequirement(FeatureId feature) {
  return _featureRegistry[feature] ?? FeatureRequirement.none;
}

/// Check if a feature requires device connection
bool featureRequiresDevice(FeatureId feature) {
  return getFeatureRequirement(feature) == FeatureRequirement.deviceConnection;
}

/// Feature availability state
class FeatureAvailability {
  final Map<FeatureId, bool> availability;
  final bool isDeviceConnected;
  final bool isNetworkAvailable;

  const FeatureAvailability({
    required this.availability,
    required this.isDeviceConnected,
    required this.isNetworkAvailable,
  });

  bool isAvailable(FeatureId feature) => availability[feature] ?? false;

  String? getUnavailabilityReason(FeatureId feature) {
    if (isAvailable(feature)) return null;

    final requirement = _featureRegistry[feature] ?? FeatureRequirement.none;
    switch (requirement) {
      case FeatureRequirement.none:
        return null;
      case FeatureRequirement.network:
        return 'Network connection required'; // lint-allow: hardcoded-string
      case FeatureRequirement.cached:
        return null; // Cached features always show something
      case FeatureRequirement.deviceConnection:
        return 'Connect device to use this feature'; // lint-allow: hardcoded-string
    }
  }
}

/// Computes feature availability based on connection states
class FeatureAvailabilityNotifier extends Notifier<FeatureAvailability> {
  @override
  FeatureAvailability build() {
    final deviceState = ref.watch(deviceConnectionProvider);
    // For now, assume network is available (could add network connectivity provider)
    const isNetworkAvailable = true;

    final availability = <FeatureId, bool>{};

    for (final entry in _featureRegistry.entries) {
      final feature = entry.key;
      final requirement = entry.value;

      bool available;
      switch (requirement) {
        case FeatureRequirement.none:
          available = true;
          break;
        case FeatureRequirement.network:
          available = isNetworkAvailable;
          break;
        case FeatureRequirement.cached:
          available = true; // Always show cached, but may be stale
          break;
        case FeatureRequirement.deviceConnection:
          available = deviceState.isConnected;
          break;
      }
      availability[feature] = available;
    }

    return FeatureAvailability(
      availability: availability,
      isDeviceConnected: deviceState.isConnected,
      isNetworkAvailable: isNetworkAvailable,
    );
  }
}

final featureAvailabilityProvider =
    NotifierProvider<FeatureAvailabilityNotifier, FeatureAvailability>(
      FeatureAvailabilityNotifier.new,
    );

// =============================================================================
// CONVENIENCE PROVIDERS
// =============================================================================

/// Simple boolean for checking if device is connected
final isDeviceConnectedProvider = Provider<bool>((ref) {
  final deviceState = ref.watch(deviceConnectionProvider);
  // Consider the device connected as soon as the state passes through connection
  // or configuration phases so UI can react immediately while background work
  // (location updates, feed refresh, etc.) continues.
  if (deviceState.isConnected) return true;
  if (deviceState.state == DevicePairingState.connecting ||
      deviceState.state == DevicePairingState.configuring) {
    return true;
  }
  // Also check the transport directly as a fallback - the transport may be
  // connected even if deviceConnectionProvider hasn't updated yet
  final transport = ref.watch(transportProvider);
  if (transport.isConnected) return true;
  return false;
});

/// Check if a specific feature is available
final featureAvailableProvider = Provider.family<bool, FeatureId>((
  ref,
  feature,
) {
  return ref.watch(featureAvailabilityProvider).isAvailable(feature);
});

/// Get unavailability reason for a feature
final featureUnavailabilityReasonProvider = Provider.family<String?, FeatureId>(
  (ref, feature) {
    return ref
        .watch(featureAvailabilityProvider)
        .getUnavailabilityReason(feature);
  },
);

// =============================================================================
// BACKGROUND SERVICE STATE
// =============================================================================

/// Whether the Android foreground service that keeps BLE alive in background
/// is currently running. UI can use this to show status indicators.
final isBackgroundServiceRunningProvider = Provider<bool>((ref) {
  // Re-evaluate when the device connection changes.
  final deviceState = ref.watch(deviceConnectionProvider);
  // The service is started automatically by BleTransport on connect and
  // stopped on disconnect. Reading the singleton's flag is sufficient.
  if (!deviceState.isConnected) return false;
  return BackgroundBleService.instance.isRunning;
});

/// Keeps the Android foreground-service notification's "Detailed" content
/// (node count + last message time) in sync with live mesh state.
///
/// [BackgroundBleService] owns the notification text but is Riverpod-free by
/// design, so it cannot read the node set or message history itself. This
/// notifier watches those providers and pushes the stats to the service,
/// debounced to coalesce the NodeInfo burst the radio dumps on connect.
///
/// No-op on iOS (the foreground service is Android-only) — kept alive at app
/// level via a `ref.watch` in the root widget.
class BackgroundNotificationUpdaterNotifier extends Notifier<bool> {
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 750);

  @override
  bool build() {
    if (!Platform.isAndroid) return false;

    ref.onDispose(() => _debounce?.cancel());

    // Re-render when the node set changes or a new message arrives. Both are
    // debounced so the connect-time NodeInfo storm coalesces into one update.
    ref.listen(nodesProvider, (_, _) => _scheduleRefresh());
    ref.listen(messagesProvider, (_, _) => _scheduleRefresh());

    // Push immediately when the service starts so Detailed isn't left on the
    // minimal fallback until the next mesh event.
    ref.listen(isBackgroundServiceRunningProvider, (previous, running) {
      if (running && previous != true) refreshNow();
    });

    return false;
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, refreshNow);
  }

  /// Compute the current mesh stats and push them to the foreground service.
  /// Safe to call when the service is stopped — it no-ops internally.
  void refreshNow() {
    if (!Platform.isAndroid) return;
    if (!BackgroundBleService.instance.isRunning) return;

    final nodes = ref.read(nodesProvider);
    final messages = ref.read(messagesProvider);

    DateTime? lastMessageAt;
    for (final message in messages) {
      if (lastMessageAt == null || message.timestamp.isAfter(lastMessageAt)) {
        lastMessageAt = message.timestamp;
      }
    }

    BackgroundBleService.instance.updateMeshStats(
      nodeCount: nodes.length,
      lastMessageAt: lastMessageAt,
    );
  }
}

final backgroundNotificationUpdaterProvider =
    NotifierProvider<BackgroundNotificationUpdaterNotifier, bool>(
      BackgroundNotificationUpdaterNotifier.new,
    );
