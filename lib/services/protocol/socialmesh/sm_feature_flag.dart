// SPDX-License-Identifier: GPL-3.0-or-later

/// Feature flags for the Socialmesh binary protocol migration.
///
/// These control whether the app sends binary-encoded packets
/// and whether it maintains legacy compatibility during the transition.
///
/// Default state: binary disabled, legacy compat enabled.
/// This is safe-by-default: no behavioral changes until explicitly opted in.
///
/// Override via `.env`:
/// ```
/// SM_BINARY_ENABLED=true
/// SM_LEGACY_COMPAT=false
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

/// Feature flags for SM binary send/receive behavior.
///
/// All flags default to safe values. The app behaves identically to
/// pre-binary behavior when constructed with defaults.
///
/// Constructor parameters override `.env` values. When neither is set,
/// `smBinaryEnabled` defaults to `false` and `legacyCompatibilityMode`
/// defaults to `true`.
class SmFeatureFlag {
  bool _smBinaryEnabled;
  bool _legacyCompatibilityMode;

  /// Creates feature flags.
  ///
  /// Resolution order for each flag:
  /// 1. Explicit constructor argument (if provided).
  /// 2. `.env` value (`SM_BINARY_ENABLED`, `SM_LEGACY_COMPAT`).
  /// 3. Hardcoded safe default.
  SmFeatureFlag({bool? smBinaryEnabled, bool? legacyCompatibilityMode})
    : _smBinaryEnabled =
          smBinaryEnabled ?? _parseBoolEnv('SM_BINARY_ENABLED') ?? false,
      _legacyCompatibilityMode =
          legacyCompatibilityMode ?? _parseBoolEnv('SM_LEGACY_COMPAT') ?? true;

  /// Whether to send binary-encoded SM packets.
  /// Default: false (safe-by-default).
  bool get smBinaryEnabled => _smBinaryEnabled;

  /// Whether to also send legacy JSON packets alongside binary.
  /// Only relevant when [smBinaryEnabled] is true.
  /// Default: true.
  bool get legacyCompatibilityMode => _legacyCompatibilityMode;

  /// Whether we should send legacy JSON when broadcasting a signal.
  ///
  /// True when:
  /// - Binary is disabled (default behavior, legacy only), OR
  /// - Binary is enabled but legacy compat mode is also on.
  bool get shouldSendLegacy => !_smBinaryEnabled || _legacyCompatibilityMode;

  /// Whether we should send binary SM_SIGNAL when broadcasting.
  bool get shouldSendBinary => _smBinaryEnabled;

  /// Combined decision: should we send legacy given mesh readiness?
  ///
  /// When binary is enabled and legacy compat is on, we stop sending
  /// legacy once the mesh has enough binary-capable peers.
  bool shouldSendLegacyGivenMeshState({required bool isMeshBinaryReady}) {
    if (!_smBinaryEnabled) return true;
    if (!_legacyCompatibilityMode) return false;
    return !isMeshBinaryReady;
  }

  /// Set binary mode.
  void setSmBinaryEnabled(bool value) => _smBinaryEnabled = value;

  /// Set legacy compatibility mode.
  void setLegacyCompatibilityMode(bool value) =>
      _legacyCompatibilityMode = value;

  @override
  String toString() =>
      'SmFeatureFlag(binary=$_smBinaryEnabled, legacyCompat=$_legacyCompatibilityMode)';
}
