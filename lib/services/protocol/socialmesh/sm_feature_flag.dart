// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feature flags for SocialMesh protocol surfaces.
///
/// Currently gates the SIP/MRRP interop stack and the BLE receive-stall
/// detector. Override via `.env`:
/// ```
/// SIP_ENABLED=true
/// MRRP_ENABLED=true
/// ```
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Safe wrapper — returns null if dotenv is not initialized (e.g. in tests).
String? _safeGetEnv(String key) {
  try {
    return dotenv.env[key];
  } catch (_) {
    return null;
  }
}

/// Parse an env var as bool. Returns `null` if not set.
/// Accepts `'true'` / `'1'` as true, everything else as false.
bool? _parseBoolEnv(String key) {
  final raw = _safeGetEnv(key)?.toLowerCase().trim();
  if (raw == null) return null;
  return raw == 'true' || raw == '1';
}

/// Feature flags for SM protocol-layer behavior.
///
/// Constructor parameters override `.env` values; when neither is set
/// each flag falls back to its documented default.
class SmFeatureFlag {
  bool _sipEnabled;
  bool _mrrpEnabled;
  bool _mrrpHarnessEnabled;
  bool _bleReceiveStallDetectionEnabled;
  bool _bleReceiveStallRecoveryResubscribe;
  bool _bleReceiveStallRecoveryReconnect;

  /// Creates feature flags.
  ///
  /// Resolution order for each flag:
  /// 1. Explicit constructor argument (if provided).
  /// 2. `.env` value (e.g. `SIP_ENABLED`, `BLE_RX_STALL_DETECTION`).
  /// 3. Hardcoded default.
  SmFeatureFlag({
    bool? sipEnabled,
    bool? mrrpEnabled,
    bool? mrrpHarnessEnabled,
    bool? bleReceiveStallDetectionEnabled,
    bool? bleReceiveStallRecoveryResubscribe,
    bool? bleReceiveStallRecoveryReconnect,
  }) : _sipEnabled = sipEnabled ?? _parseBoolEnv('SIP_ENABLED') ?? false,
       _mrrpEnabled = mrrpEnabled ?? _parseBoolEnv('MRRP_ENABLED') ?? false,
       _mrrpHarnessEnabled =
           mrrpHarnessEnabled ?? _parseBoolEnv('MRRP_HARNESS_ENABLED') ?? false,
       _bleReceiveStallDetectionEnabled =
           bleReceiveStallDetectionEnabled ??
           _parseBoolEnv('BLE_RX_STALL_DETECTION') ??
           true,
       _bleReceiveStallRecoveryResubscribe =
           bleReceiveStallRecoveryResubscribe ??
           _parseBoolEnv('BLE_RX_STALL_RECOVERY_RESUBSCRIBE') ??
           true,
       _bleReceiveStallRecoveryReconnect =
           bleReceiveStallRecoveryReconnect ??
           _parseBoolEnv('BLE_RX_STALL_RECOVERY_RECONNECT') ??
           false;

  /// Whether the SocialMesh Interop Profile (SIP) is enabled.
  ///
  /// When true, the app participates in SIP discovery, handshake,
  /// identity exchange, ephemeral DM, and micro-exchange.
  /// Default: false (disabled until explicitly opted in).
  bool get sipEnabled => _sipEnabled;

  /// Set SIP enabled state.
  void setSipEnabled(bool value) => _sipEnabled = value;

  /// Whether the Mesh Request/Response Protocol (MRRP) is enabled.
  ///
  /// Requires [sipEnabled] to be true. When enabled, the app registers
  /// MRRP services, broadcasts service advertisements, and handles
  /// request/response frames over SIP sessions.
  /// Default: false.
  bool get mrrpEnabled => _mrrpEnabled && _sipEnabled;

  /// Set MRRP enabled state.
  void setMrrpEnabled(bool value) => _mrrpEnabled = value;

  /// Whether the MRRP protocol harness UI is enabled.
  ///
  /// Requires [mrrpEnabled] to be true. When enabled, the harness
  /// screens are accessible for live testing, simulation, and QA.
  /// Default: false.
  bool get mrrpHarnessEnabled => _mrrpHarnessEnabled && mrrpEnabled;

  /// Set MRRP harness enabled state.
  void setMrrpHarnessEnabled(bool value) => _mrrpHarnessEnabled = value;

  /// Whether the BLE receive-pipeline stall detector is enabled.
  ///
  /// When true, ProtocolService runs an out-of-band 30-second timer that
  /// inspects cached transport timestamps and emits a single severity-2
  /// `BLE_RX_STALL_SUSPECTED` warning per stall episode. Pure logging —
  /// no recovery side-effect on its own.
  /// Default: true.
  bool get bleReceiveStallDetectionEnabled => _bleReceiveStallDetectionEnabled;

  /// Set BLE receive-stall detection enabled state.
  void setBleReceiveStallDetectionEnabled(bool value) =>
      _bleReceiveStallDetectionEnabled = value;

  /// Whether the resubscribe recovery path runs when a stall is suspected.
  ///
  /// When true, the stall detector triggers
  /// `BleTransport.refreshNotifications()` once per stall episode. The
  /// same code path is already exercised by the legacy 3-min health
  /// check; this flag just allows triggering it earlier (and from a
  /// path that survives `pauseRssiPolling`).
  /// Default: true.
  bool get bleReceiveStallRecoveryResubscribe =>
      _bleReceiveStallRecoveryResubscribe;

  /// Set BLE receive-stall resubscribe-recovery enabled state.
  void setBleReceiveStallRecoveryResubscribe(bool value) =>
      _bleReceiveStallRecoveryResubscribe = value;

  /// Whether the hard-reconnect recovery path runs when a stall persists.
  ///
  /// When true, if staleness exceeds the hard threshold the detector
  /// forces a transport disconnect, allowing the auto-reconnect path to
  /// establish a fresh session. Default: false (off until field
  /// telemetry from the resubscribe path validates the safer recovery).
  bool get bleReceiveStallRecoveryReconnect =>
      _bleReceiveStallRecoveryReconnect;

  /// Set BLE receive-stall hard-reconnect-recovery enabled state.
  void setBleReceiveStallRecoveryReconnect(bool value) =>
      _bleReceiveStallRecoveryReconnect = value;

  @override
  String toString() =>
      'SmFeatureFlag(sip=$_sipEnabled, mrrp=$_mrrpEnabled, mrrpHarness=$_mrrpHarnessEnabled, bleRxStallDetect=$_bleReceiveStallDetectionEnabled, bleRxStallResub=$_bleReceiveStallRecoveryResubscribe, bleRxStallReconnect=$_bleReceiveStallRecoveryReconnect)';
}
