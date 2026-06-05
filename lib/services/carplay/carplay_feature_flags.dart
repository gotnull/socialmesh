// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feature-flag holder for the CarPlay communication surface.
///
/// Mirrors the [WatchCompanionFeatureFlags] pattern: a small immutable
/// snapshot read from the current dotenv environment. There is no central
/// `FeatureFlagKey` enum in this codebase; per-service flag classes are the
/// convention (see `WatchCompanionFeatureFlags`, `OverlayFeatureFlags`).
///
/// Unlike the Watch surface, the CarPlay writer defaults to **off** (opt-in).
/// The feature is dark until the SiriKit Intents extension ships, so the main
/// app must not mirror messages into the shared App Group container by default.
/// Set `CARPLAY_COMMUNICATION_ENABLED=true` to activate the writer.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Snapshot of the CarPlay communication flags for a single provider build.
/// Instances are immutable; new dotenv state means a new snapshot via [fromEnv].
@immutable
class CarPlayFeatureFlags {
  /// Master switch for the CarPlay communication writer. When false the main
  /// app does not mirror `messages.db` into the App Group container, does not
  /// write `peers.json`, and registers no reactive listeners.
  final bool enabled;

  const CarPlayFeatureFlags({this.enabled = false});

  /// Fully disabled snapshot. Used when dotenv is unavailable or when a caller
  /// wants to assert "CarPlay surface is off" without consulting the env.
  static const CarPlayFeatureFlags disabled = CarPlayFeatureFlags(
    enabled: false,
  );

  /// Read the flag snapshot from the current `.env` environment.
  ///
  /// `CARPLAY_COMMUNICATION_ENABLED=true` activates the writer. Missing or
  /// unparseable values default to `false` (opt-in).
  factory CarPlayFeatureFlags.fromEnv() {
    return CarPlayFeatureFlags(
      enabled: _readBoolDefaultFalse('CARPLAY_COMMUNICATION_ENABLED'),
    );
  }

  /// Parse a dotenv bool with default `false`. Only the literal string `true`
  /// (case-insensitive, trimmed) enables; anything else, including a missing
  /// key or a dotenv-not-initialised exception, returns false.
  static bool _readBoolDefaultFalse(String key) {
    try {
      final raw = dotenv.env[key];
      if (raw == null) return false;
      return raw.trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }
}
