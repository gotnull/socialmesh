// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../providers/app_providers.dart';

/// Manages user consent state for Firebase Analytics and Crashlytics.
///
/// Consent defaults to `false` (disabled) until the user explicitly makes
/// a choice via [PrivacyChoiceSheet]. On every cold launch, persisted
/// consent state is read from SharedPreferences and applied to the
/// Firebase SDKs before any telemetry can fire.
///
/// The service tracks three independent flags:
/// - [isAnalyticsEnabled]: usage analytics (Firebase Analytics)
/// - [isCrashlyticsEnabled]: crash diagnostics (Firebase Crashlytics)
/// - [hasMadeChoice]: whether the user has explicitly seen and answered
///   the privacy choice prompt. Used to ensure the prompt is shown
///   exactly once per install.
class PrivacyConsentService {
  /// SharedPreferences key for analytics consent.
  static const String analyticsConsentKey = 'analytics_consent';

  /// SharedPreferences key for Crashlytics consent.
  static const String crashlyticsConsentKey = 'crashlytics_consent';

  /// SharedPreferences key recording that the user has explicitly answered
  /// the privacy choice prompt (regardless of which option they picked).
  static const String consentDecisionMadeKey = 'consent_decision_made';

  /// SharedPreferences key recording that the one-shot v2 migration has
  /// run. The v2 migration resets any prior implicitly-granted consent so
  /// the explicit choice prompt is shown to every existing user exactly
  /// once. See [_runV2MigrationIfNeeded].
  static const String consentV2MigratedKey = 'consent_v2_migrated';

  final SharedPreferences _prefs;

  PrivacyConsentService(this._prefs);

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Whether the user has consented to Firebase Analytics collection.
  /// Defaults to `false` (disabled) until explicitly granted.
  bool get isAnalyticsEnabled => _prefs.getBool(analyticsConsentKey) ?? false;

  /// Whether the user has consented to Firebase Crashlytics collection.
  /// Defaults to `false` (disabled) until explicitly granted.
  bool get isCrashlyticsEnabled =>
      _prefs.getBool(crashlyticsConsentKey) ?? false;

  /// Whether the user has ever accepted terms (checks the existing
  /// [SettingsService] key written by [TermsAcceptanceNotifier.accept]).
  bool get hasAcceptedTerms =>
      _prefs.getString('accepted_terms_version') != null;

  /// Whether the user has explicitly answered the privacy choice prompt.
  /// Returns `false` until they tap one of the three options in
  /// [PrivacyChoiceSheet] (or flip any toggle in the privacy settings
  /// screen). Used by the post-onboarding hook to ensure the prompt is
  /// shown exactly once per install.
  bool get hasMadeChoice => _prefs.getBool(consentDecisionMadeKey) ?? false;

  // ---------------------------------------------------------------------------
  // Setters (persist + apply immediately)
  // ---------------------------------------------------------------------------

  /// Persist and apply analytics consent. Also marks the user as having
  /// made an explicit choice so the consent prompt does not re-appear.
  Future<void> setAnalyticsConsent(bool enabled) async {
    AppLogging.privacy('user changed analytics consent to $enabled');
    await _prefs.setBool(analyticsConsentKey, enabled);
    await _prefs.setBool(consentDecisionMadeKey, true);
    await _applyAnalytics(enabled);
  }

  /// Persist and apply Crashlytics consent. Also marks the user as having
  /// made an explicit choice so the consent prompt does not re-appear.
  Future<void> setCrashlyticsConsent(bool enabled) async {
    AppLogging.privacy('user changed crashlytics consent to $enabled');
    await _prefs.setBool(crashlyticsConsentKey, enabled);
    await _prefs.setBool(consentDecisionMadeKey, true);
    await _applyCrashlytics(enabled);
  }

  /// Atomically record both consent flags from the consent choice sheet.
  /// Marks the user as having made an explicit choice and applies both
  /// flags to the Firebase SDKs.
  ///
  /// This is the canonical entry point from [PrivacyChoiceSheet] - the
  /// three options map to:
  /// - Keep diagnostics off:       analytics=false, crashlytics=false
  /// - Crash reports only:         analytics=false, crashlytics=true
  /// - Help improve SocialMesh:    analytics=true,  crashlytics=true
  Future<void> recordChoice({
    required bool analytics,
    required bool crashlytics,
  }) async {
    AppLogging.privacy(
      'user recorded consent choice analytics=$analytics '
      'crashlytics=$crashlytics',
    );
    await _prefs.setBool(analyticsConsentKey, analytics);
    await _prefs.setBool(crashlyticsConsentKey, crashlytics);
    await _prefs.setBool(consentDecisionMadeKey, true);
    await _applyAnalytics(analytics);
    await _applyCrashlytics(crashlytics);
  }

  /// Read persisted consent flags and apply them to the Firebase SDKs.
  /// Called on every cold launch from `_initializeFirebaseServices` to
  /// ensure the SDK state matches the user's last-known consent.
  ///
  /// Also runs the v2 consent migration if it has not yet been applied -
  /// any implicitly-granted consent from prior versions is reset so the
  /// explicit choice prompt is shown to every existing user once.
  Future<void> applyPersistedConsent() async {
    await _runV2MigrationIfNeeded();

    final analytics = isAnalyticsEnabled;
    final crashlytics = isCrashlyticsEnabled;
    final choice = hasMadeChoice;

    AppLogging.privacy(
      'consent loaded analytics=$analytics crashlytics=$crashlytics '
      'hasMadeChoice=$choice',
    );

    await _applyAnalytics(analytics);
    await _applyCrashlytics(crashlytics);
  }

  // ---------------------------------------------------------------------------
  // v2 migration
  // ---------------------------------------------------------------------------

  /// One-shot migration that resets any prior implicitly-granted consent.
  ///
  /// Earlier app versions enabled both Analytics and Crashlytics as a
  /// side-effect of accepting terms, with no explicit user choice. The
  /// App Store privacy posture requires telemetry to be opt-in, so on
  /// the first launch of a v2-aware build we clear any prior consent
  /// and require the user to make an explicit choice via the prompt.
  ///
  /// Runs at most once per install. Cached SDK toggles are applied by
  /// the caller after this returns.
  Future<void> _runV2MigrationIfNeeded() async {
    if (_prefs.getBool(consentV2MigratedKey) == true) return;

    final hadAnalytics = _prefs.getBool(analyticsConsentKey) ?? false;
    final hadCrashlytics = _prefs.getBool(crashlyticsConsentKey) ?? false;

    AppLogging.privacy(
      'running v2 consent migration; prior analytics=$hadAnalytics '
      'crashlytics=$hadCrashlytics will be reset to opt-in',
    );

    await _prefs.setBool(analyticsConsentKey, false);
    await _prefs.setBool(crashlyticsConsentKey, false);
    await _prefs.setBool(consentDecisionMadeKey, false);
    await _prefs.setBool(consentV2MigratedKey, true);
  }

  // ---------------------------------------------------------------------------
  // Firebase SDK calls
  // ---------------------------------------------------------------------------

  Future<void> _applyAnalytics(bool enabled) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      AppLogging.privacy('setAnalyticsCollectionEnabled($enabled)');
    } catch (e) {
      AppLogging.privacy('analytics consent apply failed: $e');
    }
  }

  Future<void> _applyCrashlytics(bool enabled) async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      AppLogging.privacy('setCrashlyticsCollectionEnabled($enabled)');
    } catch (e) {
      AppLogging.privacy('crashlytics consent apply failed: $e');
    }
  }
}

/// Riverpod provider for [PrivacyConsentService].
///
/// Depends on [settingsServiceProvider] to reuse the same
/// [SharedPreferences] instance that the rest of the app uses.
final privacyConsentServiceProvider = FutureProvider<PrivacyConsentService>((
  ref,
) async {
  final settings = await ref.read(settingsServiceProvider.future);
  return PrivacyConsentService(settings.prefs);
});
