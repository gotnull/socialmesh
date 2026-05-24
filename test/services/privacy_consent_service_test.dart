// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/privacy_consent_service.dart';

void main() {
  group('PrivacyConsentService', () {
    late SharedPreferences prefs;
    late PrivacyConsentService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = PrivacyConsentService(prefs);
    });

    group('defaults', () {
      test('analytics defaults to false', () {
        expect(service.isAnalyticsEnabled, isFalse);
      });

      test('crashlytics defaults to false', () {
        expect(service.isCrashlyticsEnabled, isFalse);
      });

      test('hasAcceptedTerms defaults to false', () {
        expect(service.hasAcceptedTerms, isFalse);
      });

      test('hasMadeChoice defaults to false', () {
        expect(service.hasMadeChoice, isFalse);
      });
    });

    group('analytics consent', () {
      test('persists true', () async {
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        expect(service.isAnalyticsEnabled, isTrue);
      });

      test('persists false', () async {
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, false);
        expect(service.isAnalyticsEnabled, isFalse);
      });
    });

    group('crashlytics consent', () {
      test('persists true', () async {
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);
        expect(service.isCrashlyticsEnabled, isTrue);
      });

      test('persists false', () async {
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, false);
        expect(service.isCrashlyticsEnabled, isFalse);
      });
    });

    group('hasAcceptedTerms', () {
      test('returns true when accepted_terms_version is set', () async {
        await prefs.setString('accepted_terms_version', '2026-02-20');
        expect(service.hasAcceptedTerms, isTrue);
      });

      test('returns false when accepted_terms_version is not set', () {
        expect(service.hasAcceptedTerms, isFalse);
      });
    });

    group('hasMadeChoice', () {
      test('returns true when consent_decision_made is set', () async {
        await prefs.setBool(PrivacyConsentService.consentDecisionMadeKey, true);
        expect(service.hasMadeChoice, isTrue);
      });

      test(
        'returns false when consent_decision_made is explicitly false',
        () async {
          await prefs.setBool(
            PrivacyConsentService.consentDecisionMadeKey,
            false,
          );
          expect(service.hasMadeChoice, isFalse);
        },
      );
    });

    group('fresh install scenario', () {
      test('no consent, no terms, no prior choice', () {
        expect(service.isAnalyticsEnabled, isFalse);
        expect(service.isCrashlyticsEnabled, isFalse);
        expect(service.hasAcceptedTerms, isFalse);
        expect(service.hasMadeChoice, isFalse);
      });
    });

    group('returning user scenario (post-v2 migration)', () {
      test('explicit opt-in is honored across service instances', () async {
        await prefs.setString('accepted_terms_version', '2026-02-20');
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.consentDecisionMadeKey, true);
        await prefs.setBool(PrivacyConsentService.consentV2MigratedKey, true);

        final newService = PrivacyConsentService(prefs);
        expect(newService.hasAcceptedTerms, isTrue);
        expect(newService.isAnalyticsEnabled, isTrue);
        expect(newService.isCrashlyticsEnabled, isTrue);
        expect(newService.hasMadeChoice, isTrue);
      });

      test('explicit opt-out is honored across service instances', () async {
        await prefs.setString('accepted_terms_version', '2026-02-20');
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, false);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, false);
        await prefs.setBool(PrivacyConsentService.consentDecisionMadeKey, true);
        await prefs.setBool(PrivacyConsentService.consentV2MigratedKey, true);

        final newService = PrivacyConsentService(prefs);
        expect(newService.isAnalyticsEnabled, isFalse);
        expect(newService.isCrashlyticsEnabled, isFalse);
        expect(newService.hasMadeChoice, isTrue);
      });
    });

    group('v2 migration', () {
      test('resets prior implicit consent on first run', () async {
        // Simulate a pre-v2 install where terms-acceptance implicitly
        // enabled both telemetry channels.
        await prefs.setString('accepted_terms_version', '2026-02-20');
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);
        // consent_decision_made and consent_v2_migrated are absent.

        await service.applyPersistedConsent();

        expect(service.isAnalyticsEnabled, isFalse);
        expect(service.isCrashlyticsEnabled, isFalse);
        expect(service.hasMadeChoice, isFalse);
        expect(
          prefs.getBool(PrivacyConsentService.consentV2MigratedKey),
          isTrue,
        );
      });

      test('does not re-run once consent_v2_migrated is set', () async {
        // First run: implicit consent gets reset.
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);
        await service.applyPersistedConsent();
        expect(service.isAnalyticsEnabled, isFalse);

        // User makes an explicit choice afterwards.
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.consentDecisionMadeKey, true);

        // Second run must NOT reset that explicit choice.
        await service.applyPersistedConsent();
        expect(service.isAnalyticsEnabled, isTrue);
        expect(service.hasMadeChoice, isTrue);
      });

      test('skips reset on a truly fresh install', () async {
        // No prior keys at all; migration still marks itself done but
        // the consent flags stay false (their default).
        await service.applyPersistedConsent();

        expect(service.isAnalyticsEnabled, isFalse);
        expect(service.isCrashlyticsEnabled, isFalse);
        expect(service.hasMadeChoice, isFalse);
        expect(
          prefs.getBool(PrivacyConsentService.consentV2MigratedKey),
          isTrue,
        );
      });
    });

    group('recordChoice', () {
      // recordChoice() calls FirebaseAnalytics.instance, which throws
      // in unit tests because no native plugin is wired. The service
      // catches that internally; the persisted prefs are what matters.

      test(
        'three-option mapping: off persists analytics=false crash=false',
        () async {
          await service.recordChoice(analytics: false, crashlytics: false);

          expect(
            prefs.getBool(PrivacyConsentService.analyticsConsentKey),
            isFalse,
          );
          expect(
            prefs.getBool(PrivacyConsentService.crashlyticsConsentKey),
            isFalse,
          );
          expect(
            prefs.getBool(PrivacyConsentService.consentDecisionMadeKey),
            isTrue,
          );
        },
      );

      test(
        'three-option mapping: crash-only persists analytics=false crash=true',
        () async {
          await service.recordChoice(analytics: false, crashlytics: true);

          expect(
            prefs.getBool(PrivacyConsentService.analyticsConsentKey),
            isFalse,
          );
          expect(
            prefs.getBool(PrivacyConsentService.crashlyticsConsentKey),
            isTrue,
          );
          expect(
            prefs.getBool(PrivacyConsentService.consentDecisionMadeKey),
            isTrue,
          );
        },
      );

      test('three-option mapping: full opt-in persists both true', () async {
        await service.recordChoice(analytics: true, crashlytics: true);

        expect(
          prefs.getBool(PrivacyConsentService.analyticsConsentKey),
          isTrue,
        );
        expect(
          prefs.getBool(PrivacyConsentService.crashlyticsConsentKey),
          isTrue,
        );
        expect(
          prefs.getBool(PrivacyConsentService.consentDecisionMadeKey),
          isTrue,
        );
      });
    });

    group('toggle setters mark hasMadeChoice', () {
      test('setAnalyticsConsent flips the decision-made flag', () async {
        expect(service.hasMadeChoice, isFalse);
        await service.setAnalyticsConsent(true);
        expect(service.hasMadeChoice, isTrue);
      });

      test('setCrashlyticsConsent flips the decision-made flag', () async {
        expect(service.hasMadeChoice, isFalse);
        await service.setCrashlyticsConsent(false);
        // Even a "no" toggle counts as an explicit decision.
        expect(service.hasMadeChoice, isTrue);
      });
    });

    group('SharedPreferences keys', () {
      test('uses correct key names', () {
        expect(
          PrivacyConsentService.analyticsConsentKey,
          equals('analytics_consent'),
        );
        expect(
          PrivacyConsentService.crashlyticsConsentKey,
          equals('crashlytics_consent'),
        );
        expect(
          PrivacyConsentService.consentDecisionMadeKey,
          equals('consent_decision_made'),
        );
        expect(
          PrivacyConsentService.consentV2MigratedKey,
          equals('consent_v2_migrated'),
        );
      });
    });
  });
}
