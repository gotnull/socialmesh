// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/legal/legal_constants.dart';
import 'package:socialmesh/core/legal/terms_acceptance_state.dart';

void main() {
  group('LegalConstants', () {
    group('version format', () {
      test('termsVersion matches YYYY-MM-DD format', () {
        expect(
          LegalConstants.isValidVersion(LegalConstants.termsVersion),
          isTrue,
          reason:
              'termsVersion "${LegalConstants.termsVersion}" should match YYYY-MM-DD',
        );
      });

      test('privacyVersion matches YYYY-MM-DD format', () {
        expect(
          LegalConstants.isValidVersion(LegalConstants.privacyVersion),
          isTrue,
          reason:
              'privacyVersion "${LegalConstants.privacyVersion}" should match YYYY-MM-DD',
        );
      });

      test('isValidVersion accepts valid dates', () {
        expect(LegalConstants.isValidVersion('2026-01-14'), isTrue);
        expect(LegalConstants.isValidVersion('2026-02-01'), isTrue);
        expect(LegalConstants.isValidVersion('2025-12-31'), isTrue);
        expect(LegalConstants.isValidVersion('2029-06-15'), isTrue);
      });

      test('isValidVersion rejects invalid formats', () {
        expect(LegalConstants.isValidVersion(''), isFalse);
        expect(LegalConstants.isValidVersion('2026'), isFalse);
        expect(LegalConstants.isValidVersion('2026-01'), isFalse);
        expect(LegalConstants.isValidVersion('2026-1-14'), isFalse);
        expect(LegalConstants.isValidVersion('2026-01-1'), isFalse);
        expect(LegalConstants.isValidVersion('26-01-14'), isFalse);
        expect(LegalConstants.isValidVersion('2019-01-14'), isFalse);
        expect(LegalConstants.isValidVersion('2026-13-01'), isFalse);
        expect(LegalConstants.isValidVersion('2026-00-01'), isFalse);
        expect(LegalConstants.isValidVersion('2026-01-00'), isFalse);
        expect(LegalConstants.isValidVersion('2026-01-32'), isFalse);
        expect(LegalConstants.isValidVersion('not-a-date'), isFalse);
        expect(LegalConstants.isValidVersion('2026/01/14'), isFalse);
      });

      test('termsVersion and privacyVersion are non-empty', () {
        expect(LegalConstants.termsVersion, isNotEmpty);
        expect(LegalConstants.privacyVersion, isNotEmpty);
      });
    });

    group('anchor constants', () {
      test('all anchors are non-empty strings', () {
        for (final anchor in LegalConstants.allAnchors) {
          expect(anchor, isNotEmpty, reason: 'Anchor should not be empty');
        }
      });

      test('all anchors are valid HTML id values', () {
        for (final anchor in LegalConstants.allAnchors) {
          expect(
            LegalConstants.isValidAnchor(anchor),
            isTrue,
            reason:
                'Anchor "$anchor" should be a valid HTML id (lowercase, starts with letter, only letters/digits/hyphens)',
          );
        }
      });

      test('all anchors are unique', () {
        final unique = LegalConstants.allAnchors.toSet();
        expect(
          unique.length,
          equals(LegalConstants.allAnchors.length),
          reason: 'All anchor constants should be unique',
        );
      });

      test('isValidAnchor accepts valid HTML ids', () {
        expect(LegalConstants.isValidAnchor('agreement'), isTrue);
        expect(LegalConstants.isValidAnchor('license-grant'), isTrue);
        expect(LegalConstants.isValidAnchor('section2'), isTrue);
        expect(LegalConstants.isValidAnchor('a'), isTrue);
      });

      test('isValidAnchor rejects invalid HTML ids', () {
        expect(LegalConstants.isValidAnchor(''), isFalse);
        expect(LegalConstants.isValidAnchor('2section'), isFalse);
        expect(LegalConstants.isValidAnchor('-starts-hyphen'), isFalse);
        expect(LegalConstants.isValidAnchor('has spaces'), isFalse);
        expect(LegalConstants.isValidAnchor('HAS_CAPS'), isFalse);
        expect(LegalConstants.isValidAnchor('under_score'), isFalse);
      });

      test('allAnchors contains expected key anchors', () {
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorLicenseGrant),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorTermination),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorIndemnification),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorGoverningLaw),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorRadioCompliance),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorPayments),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorAcceptableUse),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorThirdPartyServices),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorChanges),
        );
        expect(
          LegalConstants.allAnchors,
          contains(LegalConstants.anchorContact),
        );
      });

      test('allAnchors has expected count of 16 sections', () {
        expect(LegalConstants.allAnchors.length, equals(16));
      });
    });

    group('SharedPreferences keys', () {
      test('all preference keys are non-empty', () {
        expect(LegalConstants.acceptedTermsVersionKey, isNotEmpty);
        expect(LegalConstants.acceptedPrivacyVersionKey, isNotEmpty);
        expect(LegalConstants.acceptedAtKey, isNotEmpty);
        expect(LegalConstants.acceptedBuildKey, isNotEmpty);
        expect(LegalConstants.acceptedPlatformKey, isNotEmpty);
      });

      test('all preference keys are unique', () {
        final keys = {
          LegalConstants.acceptedTermsVersionKey,
          LegalConstants.acceptedPrivacyVersionKey,
          LegalConstants.acceptedAtKey,
          LegalConstants.acceptedBuildKey,
          LegalConstants.acceptedPlatformKey,
        };
        expect(keys.length, equals(5));
      });
    });
  });

  group('TermsAcceptanceState', () {
    group('empty state', () {
      test('empty state has null fields', () {
        const state = TermsAcceptanceState.empty;
        expect(state.acceptedTermsVersion, isNull);
        expect(state.acceptedPrivacyVersion, isNull);
        expect(state.acceptedAt, isNull);
        expect(state.acceptedBuild, isNull);
        expect(state.acceptedPlatform, isNull);
      });

      test('empty state hasAccepted is false', () {
        expect(TermsAcceptanceState.empty.hasAccepted, isFalse);
      });

      test('empty state needsAcceptance is true', () {
        expect(TermsAcceptanceState.empty.needsAcceptance, isTrue);
      });
    });

    group('hasAccepted', () {
      test('returns false when only terms accepted', () {
        const state = TermsAcceptanceState(acceptedTermsVersion: '2026-02-01');
        expect(state.hasAccepted, isFalse);
      });

      test('returns false when only privacy accepted', () {
        const state = TermsAcceptanceState(
          acceptedPrivacyVersion: '2026-01-14',
        );
        expect(state.hasAccepted, isFalse);
      });

      test('returns true when both are accepted', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: '2026-02-01',
          acceptedPrivacyVersion: '2026-01-14',
        );
        expect(state.hasAccepted, isTrue);
      });
    });

    group('isCurrentWith', () {
      test('returns true when versions match', () {
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

      test('returns false when terms version differs', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: '2025-12-01',
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

      test('returns false when privacy version differs', () {
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

      test('returns false when both versions differ', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: '2025-01-01',
          acceptedPrivacyVersion: '2025-01-01',
        );
        expect(
          state.isCurrentWith(
            requiredTermsVersion: '2026-02-01',
            requiredPrivacyVersion: '2026-01-14',
          ),
          isFalse,
        );
      });

      test('returns false when accepted versions are null', () {
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

    group('needsAcceptance', () {
      test('returns true for empty state', () {
        expect(TermsAcceptanceState.empty.needsAcceptance, isTrue);
      });

      test('returns true when terms version outdated', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: '2025-01-01',
          acceptedPrivacyVersion: LegalConstants.privacyVersion,
        );
        expect(state.needsAcceptance, isTrue);
      });

      test('returns true when privacy version outdated', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: LegalConstants.termsVersion,
          acceptedPrivacyVersion: '2025-01-01',
        );
        expect(state.needsAcceptance, isTrue);
      });

      test('returns false when both versions are current', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: LegalConstants.termsVersion,
          acceptedPrivacyVersion: LegalConstants.privacyVersion,
        );
        expect(state.needsAcceptance, isFalse);
      });
    });

    group('termsVersionChanged', () {
      test('returns false when terms never accepted', () {
        expect(TermsAcceptanceState.empty.termsVersionChanged, isFalse);
      });

      test('returns false when terms version matches current', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: LegalConstants.termsVersion,
        );
        expect(state.termsVersionChanged, isFalse);
      });

      test('returns true when terms version differs from current', () {
        const state = TermsAcceptanceState(acceptedTermsVersion: '2025-01-01');
        expect(state.termsVersionChanged, isTrue);
      });
    });

    group('privacyVersionChanged', () {
      test('returns false when privacy never accepted', () {
        expect(TermsAcceptanceState.empty.privacyVersionChanged, isFalse);
      });

      test('returns false when privacy version matches current', () {
        const state = TermsAcceptanceState(
          acceptedPrivacyVersion: LegalConstants.privacyVersion,
        );
        expect(state.privacyVersionChanged, isFalse);
      });

      test('returns true when privacy version differs from current', () {
        const state = TermsAcceptanceState(
          acceptedPrivacyVersion: '2024-06-01',
        );
        expect(state.privacyVersionChanged, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with updated terms version', () {
        const original = TermsAcceptanceState(
          acceptedTermsVersion: '2025-01-01',
          acceptedPrivacyVersion: '2025-01-01',
        );
        final copy = original.copyWith(acceptedTermsVersion: '2026-02-01');
        expect(copy.acceptedTermsVersion, equals('2026-02-01'));
        expect(copy.acceptedPrivacyVersion, equals('2025-01-01'));
      });

      test('preserves existing values when not overridden', () {
        final now = DateTime(2026, 2, 1, 12, 0, 0);
        final original = TermsAcceptanceState(
          acceptedTermsVersion: '2026-02-01',
          acceptedPrivacyVersion: '2026-01-14',
          acceptedAt: now,
          acceptedBuild: '42',
          acceptedPlatform: 'ios',
        );
        final copy = original.copyWith();
        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('equal states are equal', () {
        final now = DateTime(2026, 2, 1, 12, 0, 0);
        final a = TermsAcceptanceState(
          acceptedTermsVersion: '2026-02-01',
          acceptedPrivacyVersion: '2026-01-14',
          acceptedAt: now,
          acceptedBuild: '100',
          acceptedPlatform: 'android',
        );
        final b = TermsAcceptanceState(
          acceptedTermsVersion: '2026-02-01',
          acceptedPrivacyVersion: '2026-01-14',
          acceptedAt: now,
          acceptedBuild: '100',
          acceptedPlatform: 'android',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different states are not equal', () {
        const a = TermsAcceptanceState(
          acceptedTermsVersion: '2026-02-01',
          acceptedPrivacyVersion: '2026-01-14',
        );
        const b = TermsAcceptanceState(
          acceptedTermsVersion: '2025-01-01',
          acceptedPrivacyVersion: '2026-01-14',
        );
        expect(a, isNot(equals(b)));
      });

      test('empty states are equal', () {
        const a = TermsAcceptanceState.empty;
        const b = TermsAcceptanceState();
        expect(a, equals(b));
      });
    });

    group('toString', () {
      test('produces readable representation', () {
        const state = TermsAcceptanceState(
          acceptedTermsVersion: '2026-02-01',
          acceptedPrivacyVersion: '2026-01-14',
          acceptedPlatform: 'ios',
        );
        final str = state.toString();
        expect(str, contains('2026-02-01'));
        expect(str, contains('2026-01-14'));
        expect(str, contains('ios'));
      });
    });
  });
}
