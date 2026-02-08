// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/legal/legal_constants.dart';
import '../core/legal/terms_acceptance_state.dart';
import '../core/logging.dart';
import 'app_providers.dart';

/// Riverpod [AsyncNotifier] that manages terms and privacy acceptance state.
///
/// On [build], it reads the persisted acceptance record from [SettingsService].
/// It exposes [needsAcceptance] to determine whether the acceptance gate
/// should be shown, and [accept] to record the user's agreement and persist it.
///
/// Usage in UI:
/// ```dart
/// final termsAsync = ref.watch(termsAcceptanceProvider);
/// termsAsync.when(
///   data: (state) => state.needsAcceptance ? AcceptanceScreen() : MainApp(),
///   ...
/// );
/// ```
class TermsAcceptanceNotifier extends AsyncNotifier<TermsAcceptanceState> {
  @override
  Future<TermsAcceptanceState> build() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final acceptedAt = settings.termsAcceptedAt;

    final acceptance = TermsAcceptanceState(
      acceptedTermsVersion: settings.acceptedTermsVersion,
      acceptedPrivacyVersion: settings.acceptedPrivacyVersion,
      acceptedAt: acceptedAt != null ? DateTime.tryParse(acceptedAt) : null,
      acceptedBuild: settings.termsAcceptedBuild,
      acceptedPlatform: settings.termsAcceptedPlatform,
    );

    AppLogging.app(
      'TermsAcceptance: Loaded - '
      'termsVersion=${acceptance.acceptedTermsVersion}, '
      'privacyVersion=${acceptance.acceptedPrivacyVersion}, '
      'needsAcceptance=${acceptance.needsAcceptance}',
    );

    return acceptance;
  }

  /// Whether the user needs to accept (or re-accept) the current terms.
  ///
  /// Safe to call even while the provider is loading — returns true when
  /// the state is not yet available (erring on the side of gating).
  bool get needsAcceptance {
    final current = state.asData?.value;
    if (current == null) return true;
    return current.needsAcceptance;
  }

  /// Whether the terms version specifically changed (for showing "updated" messaging).
  bool get isTermsUpdate {
    final current = state.asData?.value;
    if (current == null) return false;
    return current.termsVersionChanged;
  }

  /// Whether the privacy version specifically changed (for showing "updated" messaging).
  bool get isPrivacyUpdate {
    final current = state.asData?.value;
    if (current == null) return false;
    return current.privacyVersionChanged;
  }

  /// Whether this is the user's first ever acceptance (never accepted before).
  bool get isFirstAcceptance {
    final current = state.asData?.value;
    if (current == null) return true;
    return !current.hasAccepted;
  }

  /// Record the user's acceptance and persist it to local storage.
  ///
  /// Updates [state] synchronously after persisting so that any UI watching
  /// this provider will immediately reflect the accepted state.
  Future<void> accept({String? buildNumber}) async {
    AppLogging.app(
      'TermsAcceptance: User accepted - '
      'termsVersion=${LegalConstants.termsVersion}, '
      'privacyVersion=${LegalConstants.privacyVersion}',
    );

    final settings = await ref.read(settingsServiceProvider.future);
    final platform = Platform.isIOS ? 'ios' : 'android';

    await settings.setTermsAccepted(
      termsVersion: LegalConstants.termsVersion,
      privacyVersion: LegalConstants.privacyVersion,
      platform: platform,
      buildNumber: buildNumber,
    );

    final now = DateTime.now();

    state = AsyncData(
      TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
        acceptedAt: now,
        acceptedBuild: buildNumber,
        acceptedPlatform: platform,
      ),
    );

    AppLogging.app(
      'TermsAcceptance: Persisted acceptance at ${now.toIso8601String()}',
    );
  }
}

/// Provider for terms acceptance state.
///
/// Watch this provider to reactively respond to acceptance changes.
/// The [AppInitNotifier] reads this during initialisation to decide
/// whether to show the acceptance gate.
final termsAcceptanceProvider =
    AsyncNotifierProvider<TermsAcceptanceNotifier, TermsAcceptanceState>(
      TermsAcceptanceNotifier.new,
    );
