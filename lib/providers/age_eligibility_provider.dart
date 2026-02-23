// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/legal/age_eligibility_state.dart';
import '../core/legal/legal_constants.dart';
import '../core/logging.dart';
import 'app_providers.dart';

/// Manages the 16+ age eligibility confirmation state.
///
/// On [build], reads the persisted eligibility record from [SettingsService].
/// The gate is shown when [needsConfirmation] returns true. Calling [confirm]
/// persists the confirmation and updates state so the router advances.
class AgeEligibilityNotifier extends AsyncNotifier<AgeEligibilityState> {
  @override
  Future<AgeEligibilityState> build() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final confirmedAtStr = settings.ageEligibilityConfirmedAt;

    final state = AgeEligibilityState(
      hasConfirmed: settings.ageEligibilityConfirmed,
      confirmedAt: confirmedAtStr != null
          ? DateTime.tryParse(confirmedAtStr)
          : null,
      policyVersion: settings.ageEligibilityPolicyVersion,
    );

    AppLogging.app(
      'AgeEligibility: Loaded - '
      'confirmed=${state.hasConfirmed}, '
      'policyVersion=${state.policyVersion}, '
      'needsConfirmation=${state.needsConfirmation}',
    );

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

  /// Record the user's 16+ confirmation and persist it locally.
  Future<void> confirm() async {
    final policyVersion = LegalConstants.ageEligibilityPolicyVersion;

    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setAgeEligibilityConfirmed(policyVersion: policyVersion);

    final now = DateTime.now().toUtc();

    state = AsyncData(
      AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: policyVersion,
      ),
    );

    AppLogging.app(
      'AgeEligibility: Confirmed 16+ - '
      'policyVersion=$policyVersion, '
      'at=${now.toIso8601String()}',
    );
  }
}

/// Provider for age eligibility state.
///
/// Watch this provider to reactively gate on eligibility confirmation.
final ageEligibilityProvider =
    AsyncNotifierProvider<AgeEligibilityNotifier, AgeEligibilityState>(
      AgeEligibilityNotifier.new,
    );
