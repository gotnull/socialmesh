// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/legal/age_eligibility_state.dart';
import 'package:socialmesh/core/legal/legal_constants.dart';

void main() {
  group('AgeEligibilityState', () {
    test('empty state needs confirmation', () {
      const state = AgeEligibilityState.empty;
      expect(state.needsConfirmation, isTrue);
      expect(state.hasConfirmed, isFalse);
      expect(state.confirmedAt, isNull);
      expect(state.policyVersion, 0);
    });

    test(
      'confirmed with current policy version does not need confirmation',
      () {
        final state = AgeEligibilityState(
          hasConfirmed: true,
          confirmedAt: DateTime.now().toUtc(),
          policyVersion: LegalConstants.ageEligibilityPolicyVersion,
        );
        expect(state.needsConfirmation, isFalse);
      },
    );

    test('confirmed with old policy version needs confirmation', () {
      final state = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: DateTime.now().toUtc(),
        policyVersion: LegalConstants.ageEligibilityPolicyVersion - 1,
      );
      expect(state.needsConfirmation, isTrue);
    });

    test('not confirmed with current policy version needs confirmation', () {
      const state = AgeEligibilityState(hasConfirmed: false, policyVersion: 1);
      expect(state.needsConfirmation, isTrue);
    });

    test('equality works correctly', () {
      final now = DateTime.now().toUtc();
      final a = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
      );
      final b = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on different policyVersion', () {
      final now = DateTime.now().toUtc();
      final a = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
      );
      final b = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 2,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes all fields', () {
      const state = AgeEligibilityState.empty;
      final str = state.toString();
      expect(str, contains('confirmed=false'));
      expect(str, contains('policyVersion=0'));
    });
  });

  group('SharedPreferences persistence round-trip', () {
    test('persists and reads back age eligibility', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Simulate writing eligibility confirmation
      await prefs.setBool(LegalConstants.ageEligibilityConfirmedKey, true);
      final timestamp = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(
        LegalConstants.ageEligibilityConfirmedAtKey,
        timestamp,
      );
      await prefs.setInt(
        LegalConstants.ageEligibilityPolicyVersionKey,
        LegalConstants.ageEligibilityPolicyVersion,
      );

      // Read back
      final confirmed =
          prefs.getBool(LegalConstants.ageEligibilityConfirmedKey) ?? false;
      final at = prefs.getString(LegalConstants.ageEligibilityConfirmedAtKey);
      final version =
          prefs.getInt(LegalConstants.ageEligibilityPolicyVersionKey) ?? 0;

      expect(confirmed, isTrue);
      expect(at, equals(timestamp));
      expect(version, equals(LegalConstants.ageEligibilityPolicyVersion));

      // Construct state from persisted values
      final state = AgeEligibilityState(
        hasConfirmed: confirmed,
        confirmedAt: at != null ? DateTime.tryParse(at) : null,
        policyVersion: version,
      );
      expect(state.needsConfirmation, isFalse);
    });

    test(
      'empty SharedPreferences produces state that needs confirmation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final confirmed =
            prefs.getBool(LegalConstants.ageEligibilityConfirmedKey) ?? false;
        final at = prefs.getString(LegalConstants.ageEligibilityConfirmedAtKey);
        final version =
            prefs.getInt(LegalConstants.ageEligibilityPolicyVersionKey) ?? 0;

        final state = AgeEligibilityState(
          hasConfirmed: confirmed,
          confirmedAt: at != null ? DateTime.tryParse(at) : null,
          policyVersion: version,
        );
        expect(state.needsConfirmation, isTrue);
        expect(state.hasConfirmed, isFalse);
      },
    );

    test('old policy version in prefs triggers re-confirmation', () async {
      SharedPreferences.setMockInitialValues({
        LegalConstants.ageEligibilityConfirmedKey: true,
        LegalConstants.ageEligibilityConfirmedAtKey: DateTime.now()
            .toUtc()
            .toIso8601String(),
        LegalConstants.ageEligibilityPolicyVersionKey: 0,
      });
      final prefs = await SharedPreferences.getInstance();

      final state = AgeEligibilityState(
        hasConfirmed:
            prefs.getBool(LegalConstants.ageEligibilityConfirmedKey) ?? false,
        confirmedAt: DateTime.tryParse(
          prefs.getString(LegalConstants.ageEligibilityConfirmedAtKey) ?? '',
        ),
        policyVersion:
            prefs.getInt(LegalConstants.ageEligibilityPolicyVersionKey) ?? 0,
      );
      expect(state.hasConfirmed, isTrue);
      expect(
        state.needsConfirmation,
        isTrue,
        reason: 'Policy version 0 < current version should re-gate',
      );
    });
  });

  group('LegalConstants age eligibility keys', () {
    test('ageEligibilityPolicyVersion is positive', () {
      expect(LegalConstants.ageEligibilityPolicyVersion, greaterThan(0));
    });

    test('SharedPreferences key constants are non-empty', () {
      expect(LegalConstants.ageEligibilityConfirmedKey, isNotEmpty);
      expect(LegalConstants.ageEligibilityConfirmedAtKey, isNotEmpty);
      expect(LegalConstants.ageEligibilityPolicyVersionKey, isNotEmpty);
    });
  });
}
