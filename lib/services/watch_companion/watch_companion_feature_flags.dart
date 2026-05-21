// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feature-flag holder for the SocialMesh Apple Watch companion surface.
///
/// Mirrors the [OverlayFeatureFlags] pattern: a small immutable snapshot
/// read from the current dotenv environment. When [enabled] is false the
/// iOS bridge (Slice 4) does not activate `WCSession`, no snapshots are
/// pushed, and any intent that does arrive returns
/// `accepted=false, diagnosticReason="feature_disabled"`. Lets the
/// developer kill the surface remotely (via dotenv overlay) if the
/// bridge misbehaves in the field, without shipping a new build.
///
/// There is no central `FeatureFlagKey` enum in this codebase, so this
/// class lives alongside the watch-companion service rather than in a
/// shared registry. That matches the existing per-service flag-class
/// convention (see `OverlayFeatureFlags`, `SmFeatureFlag`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Snapshot of the Apple Watch companion flags for a single provider
/// build. Instances are immutable; new dotenv state means a new snapshot
/// from [fromEnv].
@immutable
class WatchCompanionFeatureFlags {
  /// Master kill-switch. False suppresses every Watch surface: bridge
  /// activation, snapshot pushes, intent dispatch. Default is true so
  /// the bridge is active wherever a watchOS target is paired.
  final bool enabled;

  const WatchCompanionFeatureFlags({this.enabled = true});

  /// Fully disabled. Used when dotenv is unavailable, or when callers
  /// explicitly want to assert "Watch surface is off" without consulting
  /// the environment.
  static const WatchCompanionFeatureFlags disabled = WatchCompanionFeatureFlags(
    enabled: false,
  );

  /// Read the flag snapshot from the current `.env` environment.
  ///
  /// `WATCH_COMPANION_ENABLED=false` disables the surface entirely.
  /// Missing or unparseable values default to `true` (the surface is
  /// opt-out, not opt-in, so a fresh paired Watch works without any
  /// configuration).
  factory WatchCompanionFeatureFlags.fromEnv() {
    return WatchCompanionFeatureFlags(
      enabled: _readBoolDefaultTrue('WATCH_COMPANION_ENABLED'),
    );
  }

  /// Parse a dotenv bool with default `true`. Only the literal string
  /// `false` (case-insensitive, trimmed) disables; anything else,
  /// including a missing key or a dotenv-not-initialised exception,
  /// returns true.
  static bool _readBoolDefaultTrue(String key) {
    try {
      final raw = dotenv.env[key];
      if (raw == null) return true;
      return raw.trim().toLowerCase() != 'false';
    } catch (_) {
      return true;
    }
  }
}
