// SPDX-License-Identifier: GPL-3.0-or-later
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

    group('fresh install scenario', () {
      test('no consent and no terms accepted', () {
        expect(service.isAnalyticsEnabled, isFalse);
        expect(service.isCrashlyticsEnabled, isFalse);
        expect(service.hasAcceptedTerms, isFalse);
      });
    });

    group('returning user scenario', () {
      test('consent remembered across service instances', () async {
        // Simulate previous acceptance
        await prefs.setString('accepted_terms_version', '2026-02-20');
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);

        // New service instance (simulates cold launch)
        final newService = PrivacyConsentService(prefs);
        expect(newService.hasAcceptedTerms, isTrue);
        expect(newService.isAnalyticsEnabled, isTrue);
        expect(newService.isCrashlyticsEnabled, isTrue);
      });
    });

    group('opt-out scenario', () {
      test('user can revoke analytics consent', () async {
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        expect(service.isAnalyticsEnabled, isTrue);

        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, false);
        expect(service.isAnalyticsEnabled, isFalse);
      });

      test('user can revoke crashlytics consent independently', () async {
        await prefs.setBool(PrivacyConsentService.analyticsConsentKey, true);
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, true);

        // Revoke only crashlytics
        await prefs.setBool(PrivacyConsentService.crashlyticsConsentKey, false);
        expect(service.isAnalyticsEnabled, isTrue);
        expect(service.isCrashlyticsEnabled, isFalse);
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
      });
    });
  });
}
