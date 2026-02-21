// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../providers/app_providers.dart';

/// Manages user consent state for Firebase Analytics and Crashlytics.
///
/// Consent defaults to `false` (disabled) until the user explicitly accepts
/// terms and privacy. On every cold launch, persisted consent state is read
/// from SharedPreferences and applied to the Firebase SDKs before any
/// telemetry can fire.
///
/// Usage:
/// - In [_initializeFirebaseServices] (top-level, no Riverpod):
///   ```dart
///   final consent = PrivacyConsentService(prefs);
///   await consent.applyPersistedConsent();
///   ```
/// - From widgets (via Riverpod):
///   ```dart
///   final consent = await ref.read(privacyConsentServiceProvider.future);
///   await consent.grantConsentOnAcceptance();
///   ```
class PrivacyConsentService {
  /// SharedPreferences key for analytics consent.
  static const String analyticsConsentKey = 'analytics_consent';

  /// SharedPreferences key for Crashlytics consent.
  static const String crashlyticsConsentKey = 'crashlytics_consent';

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

  // ---------------------------------------------------------------------------
  // Setters (persist + apply immediately)
  // ---------------------------------------------------------------------------

  /// Persist and apply analytics consent.
  Future<void> setAnalyticsConsent(bool enabled) async {
    await _prefs.setBool(analyticsConsentKey, enabled);
    await _applyAnalytics(enabled);
  }

  /// Persist and apply Crashlytics consent.
  Future<void> setCrashlyticsConsent(bool enabled) async {
    await _prefs.setBool(crashlyticsConsentKey, enabled);
    await _applyCrashlytics(enabled);
  }

  // ---------------------------------------------------------------------------
  // Compound operations
  // ---------------------------------------------------------------------------

  /// Called when the user accepts terms for the first time or after a version
  /// bump. Enables both analytics and Crashlytics and persists consent.
  Future<void> grantConsentOnAcceptance() async {
    AppLogging.privacy('terms accepted, enabling analytics and crashlytics');
    await setAnalyticsConsent(true);
    await setCrashlyticsConsent(true);
  }

  /// Read persisted consent flags and apply them to the Firebase SDKs.
  /// Called on every cold launch from [_initializeFirebaseServices] to
  /// ensure the SDK state matches the user's last-known consent.
  Future<void> applyPersistedConsent() async {
    final analytics = isAnalyticsEnabled;
    final crashlytics = isCrashlyticsEnabled;
    final terms = hasAcceptedTerms;

    AppLogging.privacy(
      terms
          ? 'terms accepted, analytics=$analytics, crashlytics=$crashlytics'
          : 'terms not accepted, analytics=false, crashlytics=false',
    );

    await _applyAnalytics(terms && analytics);
    await _applyCrashlytics(terms && crashlytics);
  }

  // ---------------------------------------------------------------------------
  // Firebase SDK calls
  // ---------------------------------------------------------------------------

  Future<void> _applyAnalytics(bool enabled) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      AppLogging.privacy('setAnalyticsCollectionEnabled($enabled)');
    } catch (e) {
      AppLogging.privacy('Analytics consent apply failed: $e');
    }
  }

  Future<void> _applyCrashlytics(bool enabled) async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      AppLogging.privacy('setCrashlyticsCollectionEnabled($enabled)');
    } catch (e) {
      AppLogging.privacy('Crashlytics consent apply failed: $e');
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
