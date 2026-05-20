// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Derived navigation provider that maps the union of `appInitProvider`
/// and `meshtasticOnboardingFlowProvider` into a single canonical
/// "what shell should the router render?" enum.
///
/// `_AppRouter` is a pure renderer of the derived shell. The onboarding
/// flow is the single source of truth for everything between
/// "user tapped a device" and "MainShell is on screen"; outside that
/// window the provider falls through to `appInitProvider` for the legal
/// gates (terms, age, scanner-on-first-launch).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging.dart';
import '../../core/legal/legal_constants.dart';
import '../../providers/app_providers.dart'
    show AppInitState, appInitProvider, settingsServiceProvider;
import '../../providers/remote_legal_versions_provider.dart';
import '../../services/storage/storage_service.dart' show SettingsService;
import 'meshtastic_onboarding_flow.dart';
import 'meshtastic_onboarding_state.dart';

/// Canonical app shells. Every `_AppRouter` rendering decision must
/// pick exactly one of these; nothing else.
enum AppShell {
  /// Pre-init splash (`AppInitState.uninitialized` / `initializing`).
  splash,

  /// Hard error from boot — surfaces an error screen with retry.
  error,

  /// Age-gating: user has not confirmed 16+ for the current policy.
  ageEligibility,

  /// First-run onboarding (terms, walkthrough, etc.).
  onboarding,

  /// Terms re-acceptance gate (terms version bump after a returning
  /// user is otherwise ready).
  termsAcceptance,

  /// Scanner UI (no device paired yet, or coordinator is connecting
  /// / checking config / surfacing failure or pairing-invalidation).
  scanner,

  /// Fully ready: MainShell or MeshCoreShell via AppRootShell.
  mainShell,
}

/// Picks the active shell. Pure derivation: no side effects.
@immutable
class AppShellResolution {
  final AppShell shell;
  final String reason;
  const AppShellResolution(this.shell, this.reason);
}

final appShellProvider = Provider<AppShellResolution>((ref) {
  final initState = ref.watch(appInitProvider);
  AppLogging.connection('APP_SHELL_PROVIDER: compute appInit=$initState');

  // Splash + error gates fire before anything else; onboarding flow
  // cannot override these.
  switch (initState) {
    case AppInitState.uninitialized:
    case AppInitState.initializing:
      return const AppShellResolution(AppShell.splash, 'appInit:initializing');
    case AppInitState.error:
      return const AppShellResolution(AppShell.error, 'appInit:error');
    case AppInitState.needsAgeEligibility:
      return const AppShellResolution(
        AppShell.ageEligibility,
        'appInit:needsAgeEligibility',
      );
    case AppInitState.needsOnboarding:
      return const AppShellResolution(
        AppShell.onboarding,
        'appInit:needsOnboarding',
      );
    case AppInitState.needsTermsAcceptance:
      return const AppShellResolution(
        AppShell.termsAcceptance,
        'appInit:needsTermsAcceptance',
      );
    case AppInitState.needsScanner:
    case AppInitState.ready:
      // Onboarding flow only overrides routing for the connect ->
      // region -> reboot -> ready window. Outside that window, fall
      // through to the legacy decision below.
      break;
  }

  final flow = ref.watch(meshtasticOnboardingFlowProvider);

  // `needsScanner` is a hard-reset signal (factory reset, manual
  // disconnect, scanner re-entry from banner). Stale completed-flow
  // states from a PRIOR session must not override it; those would
  // route the user to MainShell while the app's source of truth
  // says they should be on Scanner. Only ACTIVELY in-flight flow
  // states (connecting / checkingConfig / regionRequired and the
  // four reboot-window phases) get to override needsScanner — those
  // are part of the current onboarding cycle and need their own
  // shell render.
  final bool flowIsTerminalOrIdle =
      flow is OnboardingIdle ||
      flow is OnboardingReady ||
      flow is OnboardingFailed ||
      flow is OnboardingPairingInvalidated ||
      flow is OnboardingCancelled;
  if (initState == AppInitState.needsScanner && flowIsTerminalOrIdle) {
    return const AppShellResolution(
      AppShell.scanner,
      'appInit:needsScanner+flow_inert',
    );
  }

  switch (flow) {
    case OnboardingConnecting():
    case OnboardingCheckingConfig():
      return const AppShellResolution(
        AppShell.scanner,
        'flow:connecting_or_checking',
      );
    case OnboardingRegionRequired():
    case OnboardingWritingRegion():
    case OnboardingAwaitingReboot():
    case OnboardingAwaitingReconnect():
    case OnboardingAwaitingReadiness():
      // Region-flow phases NO LONGER swap the shell. The picker is
      // pushed as a fullscreen MaterialPageRoute by the coordinator
      // listener in `_AppRouterState.initState` whenever the flow
      // enters one of these phases, and popped on
      // OnboardingReady/Failed. The shell underneath stays on
      // mainShell so MainShell doesn't get disposed mid-flow (which
      // was the source of every dual-mount race we fought) and so
      // the user lands on mainShell cleanly when the picker pops.
      return _legacyReadyShell(ref, reason: 'flow:region_in_flight');
    case OnboardingReady():
      // Terms gate is checked from `_AppRouter` once we say mainShell.
      // The provider just signals readiness.
      return _legacyReadyShell(ref, reason: 'flow:ready');
    case OnboardingPairingInvalidated():
      return const AppShellResolution(
        AppShell.scanner,
        'flow:terminal_recover',
      );
    case OnboardingFailed():
      // If appInit reached `ready` while the flow was failing (e.g. the
      // device wrote its region and rebooted, then reconnected JUST
      // after `awaitingReconnect` timed out), the user is actually in
      // a healthy connected state - we should land them on mainShell
      // rather than forcing them back to the scanner. The scanner-as-
      // recovery route is only useful when the device hasn't actually
      // come back online. `flow:ready` would be cleaner but the flow
      // notifier doesn't auto-transition out of `failed` on a late
      // reconnect, so this fall-through is the recovery path.
      if (initState == AppInitState.ready) {
        return _legacyReadyShell(ref, reason: 'flow:failed+appInit:ready');
      }
      return const AppShellResolution(
        AppShell.scanner,
        'flow:terminal_recover',
      );
    case OnboardingCancelled():
      return const AppShellResolution(AppShell.scanner, 'flow:cancelled');
    case OnboardingIdle():
      // No active onboarding -> use legacy appInit-driven decision.
      break;
  }

  // Legacy fallback. needsScanner and ready map directly.
  switch (initState) {
    case AppInitState.needsScanner:
      return const AppShellResolution(AppShell.scanner, 'appInit:needsScanner');
    case AppInitState.ready:
      return _legacyReadyShell(ref, reason: 'appInit:ready');
    default:
      return const AppShellResolution(AppShell.splash, 'appInit:fallback');
  }
});

/// Resolves the "ready" shell with the legacy terms-acceptance gate
/// applied. Mirrors the gate `_AppRouter` historically applied inline
/// for `AppInitState.ready` so the user is still prompted on a terms
/// version bump.
AppShellResolution _legacyReadyShell(Ref ref, {required String reason}) {
  final effectiveAsync = ref.watch(effectiveLegalVersionsProvider);
  final settingsAsync = ref.watch(settingsServiceProvider);
  final needsTerms =
      settingsAsync.whenOrNull(
        data: (SettingsService settings) {
          final acceptedTerms = settings.acceptedTermsVersion;
          final acceptedPrivacy = settings.acceptedPrivacyVersion;
          final effective = effectiveAsync.asData?.value;
          final reqTerms =
              effective?.termsVersion ?? LegalConstants.termsVersion;
          final reqPrivacy =
              effective?.privacyVersion ?? LegalConstants.privacyVersion;
          if (acceptedTerms == null || acceptedPrivacy == null) {
            return true;
          }
          return acceptedTerms.compareTo(reqTerms) < 0 ||
              acceptedPrivacy.compareTo(reqPrivacy) < 0;
        },
      ) ??
      false;
  if (needsTerms) {
    return AppShellResolution(
      AppShell.termsAcceptance,
      '$reason+termsRequired',
    );
  }
  return AppShellResolution(AppShell.mainShell, reason);
}
