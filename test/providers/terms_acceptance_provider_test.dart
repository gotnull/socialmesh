// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/legal/legal_constants.dart';
import 'package:socialmesh/core/legal/terms_acceptance_state.dart';

void main() {
  group('TermsAcceptanceState gating logic', () {
    test('needsAcceptance is true when no versions stored', () {
      const state = TermsAcceptanceState.empty;
      expect(state.needsAcceptance, isTrue);
    });

    test('needsAcceptance is true when terms version outdated', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2025-01-01',
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
      );
      expect(state.needsAcceptance, isTrue);
    });

    test('needsAcceptance is true when privacy version outdated', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
        acceptedPrivacyVersion: '2025-01-01',
      );
      expect(state.needsAcceptance, isTrue);
    });

    test('needsAcceptance is true when both versions outdated', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2024-06-01',
        acceptedPrivacyVersion: '2024-06-01',
      );
      expect(state.needsAcceptance, isTrue);
    });

    test('needsAcceptance is false when both versions are current', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
      );
      expect(state.needsAcceptance, isFalse);
    });

    test('needsAcceptance is true when only terms version is set', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
      );
      expect(state.needsAcceptance, isTrue);
    });

    test('needsAcceptance is true when only privacy version is set', () {
      const state = TermsAcceptanceState(
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
      );
      expect(state.needsAcceptance, isTrue);
    });
  });

  group('TermsAcceptanceState version change detection', () {
    test('termsVersionChanged is false when never accepted', () {
      const state = TermsAcceptanceState.empty;
      expect(state.termsVersionChanged, isFalse);
    });

    test('termsVersionChanged is false when version matches', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
      );
      expect(state.termsVersionChanged, isFalse);
    });

    test('termsVersionChanged is true when version differs', () {
      const state = TermsAcceptanceState(acceptedTermsVersion: '2025-01-01');
      expect(state.termsVersionChanged, isTrue);
    });

    test('privacyVersionChanged is false when never accepted', () {
      const state = TermsAcceptanceState.empty;
      expect(state.privacyVersionChanged, isFalse);
    });

    test('privacyVersionChanged is false when version matches', () {
      const state = TermsAcceptanceState(
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
      );
      expect(state.privacyVersionChanged, isFalse);
    });

    test('privacyVersionChanged is true when version differs', () {
      const state = TermsAcceptanceState(acceptedPrivacyVersion: '2024-06-01');
      expect(state.privacyVersionChanged, isTrue);
    });
  });

  group('TermsAcceptanceState isCurrentWith', () {
    test('returns true when both versions match required', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2026-02-01',
        acceptedPrivacyVersion: '2026-01-14',
      );
      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isTrue,
      );
    });

    test('returns false when terms version does not match', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2025-06-01',
        acceptedPrivacyVersion: '2026-01-14',
      );
      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isFalse,
      );
    });

    test('returns false when privacy version does not match', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2026-02-01',
        acceptedPrivacyVersion: '2025-06-01',
      );
      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isFalse,
      );
    });

    test('returns false when null versions compared to required', () {
      const state = TermsAcceptanceState.empty;
      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isFalse,
      );
    });
  });

  group('SharedPreferences persistence round-trip', () {
    test('persists and reads back terms acceptance', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate writing acceptance
      await prefs.setString(
        LegalConstants.acceptedTermsVersionKey,
        LegalConstants.termsVersion,
      );
      await prefs.setString(
        LegalConstants.acceptedPrivacyVersionKey,
        LegalConstants.privacyVersion,
      );
      final timestamp = DateTime.now().toIso8601String();
      await prefs.setString(LegalConstants.acceptedAtKey, timestamp);
      await prefs.setString(LegalConstants.acceptedPlatformKey, 'ios');
      await prefs.setString(LegalConstants.acceptedBuildKey, '42');

      // Read back
      final readTerms = prefs.getString(LegalConstants.acceptedTermsVersionKey);
      final readPrivacy = prefs.getString(
        LegalConstants.acceptedPrivacyVersionKey,
      );
      final readAt = prefs.getString(LegalConstants.acceptedAtKey);
      final readPlatform = prefs.getString(LegalConstants.acceptedPlatformKey);
      final readBuild = prefs.getString(LegalConstants.acceptedBuildKey);

      expect(readTerms, equals(LegalConstants.termsVersion));
      expect(readPrivacy, equals(LegalConstants.privacyVersion));
      expect(readAt, equals(timestamp));
      expect(readPlatform, equals('ios'));
      expect(readBuild, equals('42'));

      // Construct state from persisted values
      final state = TermsAcceptanceState(
        acceptedTermsVersion: readTerms,
        acceptedPrivacyVersion: readPrivacy,
        acceptedAt: readAt != null ? DateTime.tryParse(readAt) : null,
        acceptedBuild: readBuild,
        acceptedPlatform: readPlatform,
      );
      expect(state.needsAcceptance, isFalse);
      expect(state.hasAccepted, isTrue);
    });

    test(
      'empty SharedPreferences produces state that needs acceptance',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final readTerms = prefs.getString(
          LegalConstants.acceptedTermsVersionKey,
        );
        final readPrivacy = prefs.getString(
          LegalConstants.acceptedPrivacyVersionKey,
        );

        final state = TermsAcceptanceState(
          acceptedTermsVersion: readTerms,
          acceptedPrivacyVersion: readPrivacy,
        );
        expect(state.needsAcceptance, isTrue);
        expect(state.hasAccepted, isFalse);
      },
    );

    test(
      'outdated version in SharedPreferences triggers re-acceptance',
      () async {
        SharedPreferences.setMockInitialValues({
          LegalConstants.acceptedTermsVersionKey: '2025-01-01',
          LegalConstants.acceptedPrivacyVersionKey: '2025-01-01',
          LegalConstants.acceptedAtKey: '2025-01-01T00:00:00.000',
          LegalConstants.acceptedPlatformKey: 'android',
        });
        final prefs = await SharedPreferences.getInstance();

        final state = TermsAcceptanceState(
          acceptedTermsVersion: prefs.getString(
            LegalConstants.acceptedTermsVersionKey,
          ),
          acceptedPrivacyVersion: prefs.getString(
            LegalConstants.acceptedPrivacyVersionKey,
          ),
          acceptedAt: DateTime.tryParse(
            prefs.getString(LegalConstants.acceptedAtKey) ?? '',
          ),
          acceptedPlatform: prefs.getString(LegalConstants.acceptedPlatformKey),
        );

        expect(state.hasAccepted, isTrue);
        expect(state.needsAcceptance, isTrue);
        expect(state.termsVersionChanged, isTrue);
        expect(state.privacyVersionChanged, isTrue);
      },
    );

    test(
      'updating stored version resolves re-acceptance requirement',
      () async {
        // Start with outdated values
        SharedPreferences.setMockInitialValues({
          LegalConstants.acceptedTermsVersionKey: '2025-01-01',
          LegalConstants.acceptedPrivacyVersionKey: '2025-01-01',
        });
        final prefs = await SharedPreferences.getInstance();

        // Verify state needs acceptance
        var state = TermsAcceptanceState(
          acceptedTermsVersion: prefs.getString(
            LegalConstants.acceptedTermsVersionKey,
          ),
          acceptedPrivacyVersion: prefs.getString(
            LegalConstants.acceptedPrivacyVersionKey,
          ),
        );
        expect(state.needsAcceptance, isTrue);

        // Simulate user accepting updated terms
        await prefs.setString(
          LegalConstants.acceptedTermsVersionKey,
          LegalConstants.termsVersion,
        );
        await prefs.setString(
          LegalConstants.acceptedPrivacyVersionKey,
          LegalConstants.privacyVersion,
        );

        // Re-read and verify
        state = TermsAcceptanceState(
          acceptedTermsVersion: prefs.getString(
            LegalConstants.acceptedTermsVersionKey,
          ),
          acceptedPrivacyVersion: prefs.getString(
            LegalConstants.acceptedPrivacyVersionKey,
          ),
        );
        expect(state.needsAcceptance, isFalse);
        expect(state.hasAccepted, isTrue);
      },
    );
  });

  group('Version bump scenarios', () {
    test('terms-only bump: privacy stays, terms bumps', () {
      // Simulate: user accepted 2026-01-14 terms & 2026-01-14 privacy
      // Then terms bumped to 2026-02-01 but privacy stayed at 2026-01-14
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2026-01-14',
        acceptedPrivacyVersion: '2026-01-14',
      );

      // If current constants are terms=2026-02-01, privacy=2026-01-14
      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isFalse,
        reason: 'Terms version bumped, should require re-acceptance',
      );
    });

    test('privacy-only bump: terms stays, privacy bumps', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2026-02-01',
        acceptedPrivacyVersion: '2026-01-14',
      );

      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-03-01',
        ),
        isFalse,
        reason: 'Privacy version bumped, should require re-acceptance',
      );
    });

    test('both bumped: both change', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2025-06-01',
        acceptedPrivacyVersion: '2025-06-01',
      );

      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isFalse,
      );
    });

    test('no bump: both match', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: '2026-02-01',
        acceptedPrivacyVersion: '2026-01-14',
      );

      expect(
        state.isCurrentWith(
          requiredTermsVersion: '2026-02-01',
          requiredPrivacyVersion: '2026-01-14',
        ),
        isTrue,
      );
    });
  });

  group('TermsAcceptanceState metadata', () {
    test('acceptedAt timestamp is preserved through copyWith', () {
      final now = DateTime(2026, 2, 1, 14, 30, 0);
      final state = TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
        acceptedAt: now,
        acceptedPlatform: 'ios',
        acceptedBuild: '100',
      );

      final copy = state.copyWith(acceptedPlatform: 'android');
      expect(copy.acceptedAt, equals(now));
      expect(copy.acceptedPlatform, equals('android'));
      expect(copy.acceptedBuild, equals('100'));
      expect(copy.acceptedTermsVersion, equals(LegalConstants.termsVersion));
    });

    test('platform and build are optional metadata', () {
      const state = TermsAcceptanceState(
        acceptedTermsVersion: LegalConstants.termsVersion,
        acceptedPrivacyVersion: LegalConstants.privacyVersion,
      );

      // Should work fine without platform/build
      expect(state.needsAcceptance, isFalse);
      expect(state.acceptedPlatform, isNull);
      expect(state.acceptedBuild, isNull);
    });
  });
}
