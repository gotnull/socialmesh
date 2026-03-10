// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/legal/age_eligibility_state.dart';
import '../core/legal/age_group.dart';
import '../core/legal/age_safety_policy.dart';
import '../core/legal/legal_constants.dart';
import '../core/logging.dart';
import '../services/age_signal_service.dart';
import 'app_providers.dart';

/// Manages the 18+ age eligibility confirmation state.
///
/// On [build], reads the persisted eligibility record from [SettingsService].
/// The gate is shown when [needsConfirmation] returns true. Calling [confirm]
/// persists the confirmation and updates state so the router advances.
class AgeEligibilityNotifier extends AsyncNotifier<AgeEligibilityState> {
  @override
  Future<AgeEligibilityState> build() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final confirmedAtStr = settings.ageEligibilityConfirmedAt;

    final ageGroup = AgeGroup.values.firstWhere(
      (g) => g.name == settings.ageEligibilityAgeGroupName,
      orElse: () => AgeGroup.unknown,
    );
    final source = AgeSource.values.firstWhere(
      (s) => s.name == settings.ageEligibilityAgeSourceName,
      orElse: () => AgeSource.unknown,
    );

    final state = AgeEligibilityState(
      hasConfirmed: settings.ageEligibilityConfirmed,
      confirmedAt: confirmedAtStr != null
          ? DateTime.tryParse(confirmedAtStr)
          : null,
      policyVersion: settings.ageEligibilityPolicyVersion,
      ageGroup: ageGroup,
      source: source,
    );

    AppLogging.app(
      'AgeEligibility: Loaded - '
      'confirmed=${state.hasConfirmed}, '
      'policyVersion=${state.policyVersion}, '
      'ageGroup=${state.ageGroup}, '
      'needsConfirmation=${state.needsConfirmation}',
    );

    // If the user needs to (re-)confirm, try platform age signals first.
    // A verified platform signal can auto-confirm, bypassing the UI gate.
    if (state.needsConfirmation) {
      final signal = await AgeSignalService.fetchPlatformAgeSignal();
      if (signal.ageGroup != AgeGroup.unknown) {
        AppLogging.app(
          'AgeEligibility: Platform signal received — '
          'ageGroup=${signal.ageGroup}, source=${signal.source}',
        );
        final now = DateTime.now().toUtc();
        await settings.setAgeEligibilityConfirmed(
          policyVersion: LegalConstants.ageEligibilityPolicyVersion,
          ageGroupName: signal.ageGroup.name,
          ageSource: signal.source.name,
        );
        return AgeEligibilityState(
          hasConfirmed: true,
          confirmedAt: now,
          policyVersion: LegalConstants.ageEligibilityPolicyVersion,
          ageGroup: signal.ageGroup,
          source: signal.source,
        );
      }
    }

    return state;
  }

  /// Whether the user needs to confirm (or re-confirm) age eligibility.
  ///
  /// Returns true while the provider is still loading (errs on gating).
  bool get needsConfirmation {
    final current = state.asData?.value;
    if (current == null) return true;
    return current.needsConfirmation;
  }

  /// Capability policy derived from the current eligibility state.
  ///
  /// Returns [AgeSafetyPolicy.safe] (conservative) while loading.
  AgeSafetyPolicy get safetyPolicy {
    return state.asData?.value.safetyPolicy ?? AgeSafetyPolicy.safe;
  }

  /// Record the user's age group and persist it locally.
  ///
  /// Called from the eligibility gate screen or the Settings age-group picker.
  /// Any [AgeGroup] value is accepted; capability restrictions are enforced
  /// downstream by [AgeSafetyPolicy].
  Future<void> confirm({
    required AgeGroup ageGroup,
    AgeSource source = AgeSource.selfAttestation,
  }) async {
    final policyVersion = LegalConstants.ageEligibilityPolicyVersion;

    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setAgeEligibilityConfirmed(
      policyVersion: policyVersion,
      ageGroupName: ageGroup.name,
      ageSource: source.name,
    );

    final now = DateTime.now().toUtc();

    state = AsyncData(
      AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: policyVersion,
        ageGroup: ageGroup,
        source: source,
      ),
    );

    AppLogging.app(
      'AgeEligibility: Confirmed - '
      'policyVersion=$policyVersion, '
      'ageGroup=$ageGroup, '
      'at=${now.toIso8601String()}',
    );
  }

  /// Reset the eligibility state so the user can re-select their age group.
  ///
  /// Called from Settings → Age Group → Update. Sets the persisted policy
  /// version to 0, which triggers [needsConfirmation] and re-shows the
  /// eligibility gate on next router evaluation.
  Future<void> resetForReview() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.clearAgeEligibility();

    state = const AsyncData(AgeEligibilityState());

    AppLogging.app('AgeEligibility: Reset for review — gate will re-appear');

    // Re-run app init so the router re-evaluates and shows the gate.
    ref.read(appInitProvider.notifier).initialize();
  }
}

/// Provider for age eligibility state.
///
/// Watch this provider to reactively gate on eligibility confirmation.
final ageEligibilityProvider =
    AsyncNotifierProvider<AgeEligibilityNotifier, AgeEligibilityState>(
      AgeEligibilityNotifier.new,
    );

/// Synchronous capability policy derived from the current eligibility state.
///
/// Watch this provider to apply safe-defaults gating in UI and services.
/// Returns [AgeSafetyPolicy.safe] (conservative) while the eligibility
/// state is loading.
final ageSafetyPolicyProvider = Provider<AgeSafetyPolicy>((ref) {
  final eligibility = ref.watch(ageEligibilityProvider);
  return eligibility.asData?.value.safetyPolicy ?? AgeSafetyPolicy.safe;
});
