// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feature-flag holder for [MeshtasticOnboardingFlow], the single
/// coordinator that owns the post-Scanner-tap onboarding path:
/// connect -> config check -> region required -> region write ->
/// reboot -> reconnect -> readiness -> ready/failure.
///
/// **Why a flag**: the legacy path is a multi-owner choreography
/// across Scanner, RegionSelectionScreen, RegionConfigNotifier,
/// _AppRouter and a handful of competing setInitialized callers.
/// Replacing that with a declarative state machine + appShell-driven
/// routing is invasive enough that we want to land it cold-dark in
/// release until iPhone field validation says "done".
///
/// Default policy:
/// 1. Env var present and parseable -> use that value.
/// 2. Env var missing/unparseable + debug or profile build -> ON.
/// 3. Env var missing/unparseable + release build -> OFF.
///
/// When OFF, every wired callsite falls back to the legacy
/// Scanner -> Navigator.push(RegionSelectionScreen) -> pop ->
/// setInitialized choreography. When ON, Scanner does not push
/// the region screen, RegionSelection does not self-pop, and only
/// MeshtasticOnboardingFlow promotes to MainShell.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@immutable
class MeshtasticOnboardingFlowFlags {
  /// Gate for the new coordinator. False -> legacy path remains
  /// the only owner. True -> coordinator owns the onboarding flow.
  final bool enabled;

  const MeshtasticOnboardingFlowFlags({required this.enabled});

  /// Fully disabled. Used as a static fallback in tests where
  /// dotenv is not initialised.
  static const MeshtasticOnboardingFlowFlags disabled =
      MeshtasticOnboardingFlowFlags(enabled: false);

  /// Force-on for tests that exercise the coordinator directly
  /// without depending on dotenv.
  static const MeshtasticOnboardingFlowFlags enabledForTests =
      MeshtasticOnboardingFlowFlags(enabled: true);

  factory MeshtasticOnboardingFlowFlags.fromEnv() {
    final envOverride = _readBoolOrNull('MESHTASTIC_ONBOARDING_FLOW_ENABLED');
    final defaultOn = kDebugMode || kProfileMode;
    return MeshtasticOnboardingFlowFlags(enabled: envOverride ?? defaultOn);
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
