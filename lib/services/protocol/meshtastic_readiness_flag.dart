// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feature-flag holder for the Meshtastic readiness watchdog.
///
/// The watchdog is the auto-rebuild side of the readiness pipeline:
/// when a restore reaches `linkConnected` but never advances to
/// `ready` (the phase-2-stalled wedge after iOS Core Bluetooth state
/// restoration), it forces a clean transport-disconnect + fresh
/// scan/connect cycle.
///
/// **Default policy is intentionally conservative**: OFF in release
/// builds until field validation confirms it does not misfire on slow
/// BLE / congested meshes / delayed config drains. ON in debug + profile
/// builds so internal builds exercise the rebuild path during dogfood.
/// Env override (`MESHTASTIC_READINESS_WATCHDOG_ENABLED=true|false`)
/// wins over the build-mode default in either direction so the rollout
/// can be flipped per-install.
///
/// **Diverges from `OverlayFeatureFlags`**: this file's
/// `_readBoolOrNull` returns `null` for missing/unparseable values so
/// the build-mode default applies. `OverlayFeatureFlags._readBool`
/// returns `false` on missing because overlay is an opt-in feature;
/// this watchdog is part of the readiness pipeline and is expected to
/// be on in non-release builds without any `.env` configuration.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@immutable
class MeshtasticReadinessFlags {
  /// Gate for the readiness watchdog auto-rebuild. The readiness state
  /// machine itself is NOT gated by this flag — it always runs, always
  /// logs, and always drives UI; only the auto session-rebuild
  /// side-effect is flagged.
  final bool watchdogEnabled;

  /// Gate for the degraded-readiness recovery listener: when the protocol
  /// surfaces `degraded` while the transport link is still up (phase-2
  /// handshake exhausted its retries), the connection notifier drives one
  /// bounded teardown through the existing config-timeout recovery path.
  /// Unlike [watchdogEnabled] this defaults ON in every build mode - it
  /// reacts only to a terminal protocol-declared failure, not to a timer
  /// racing a legitimately slow handshake.
  /// Kill switch: `MESHTASTIC_DEGRADED_RECOVERY_ENABLED=false`.
  final bool degradedRecoveryEnabled;

  const MeshtasticReadinessFlags({
    required this.watchdogEnabled,
    this.degradedRecoveryEnabled = true,
  });

  /// Fully disabled. Used as a static fallback in tests where dotenv
  /// is not initialised.
  static const MeshtasticReadinessFlags disabled = MeshtasticReadinessFlags(
    watchdogEnabled: false,
    degradedRecoveryEnabled: false,
  );

  /// Read the flag snapshot from the current `.env` environment.
  ///
  /// Resolution order (watchdog):
  /// 1. Env var present and parseable -> use that value.
  /// 2. Env var missing/unparseable + debug or profile build -> ON.
  /// 3. Env var missing/unparseable + release build -> OFF.
  ///
  /// Degraded recovery defaults ON in all build modes; only its env kill
  /// switch can turn it off.
  factory MeshtasticReadinessFlags.fromEnv() {
    final envOverride = _readBoolOrNull(
      'MESHTASTIC_READINESS_WATCHDOG_ENABLED',
    );
    final defaultOn = kDebugMode || kProfileMode;
    final degradedOverride = _readBoolOrNull(
      'MESHTASTIC_DEGRADED_RECOVERY_ENABLED',
    );
    return MeshtasticReadinessFlags(
      watchdogEnabled: envOverride ?? defaultOn,
      degradedRecoveryEnabled: degradedOverride ?? true,
    );
  }

  static bool? _readBoolOrNull(String key) {
    try {
      final raw = dotenv.env[key];
      if (raw == null) return null;
      final lowered = raw.trim().toLowerCase();
      if (lowered == 'true') return true;
      if (lowered == 'false') return false;
      return null;
    } catch (_) {
      return null;
    }
  }
}
