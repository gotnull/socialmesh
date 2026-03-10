// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/legal/age_eligibility_state.dart';
import 'package:socialmesh/core/legal/age_group.dart';
import 'package:socialmesh/core/legal/legal_constants.dart';

void main() {
  group('AgeEligibilityState', () {
    test('empty state needs confirmation', () {
      const state = AgeEligibilityState.empty;
      expect(state.needsConfirmation, isTrue);
      expect(state.hasConfirmed, isFalse);
      expect(state.confirmedAt, isNull);
      expect(state.policyVersion, 0);
      expect(state.ageGroup, AgeGroup.unknown);
      expect(state.source, AgeSource.unknown);
    });

    test(
      'confirmed with current policy version does not need confirmation',
      () {
        final state = AgeEligibilityState(
          hasConfirmed: true,
          confirmedAt: DateTime.now().toUtc(),
          policyVersion: LegalConstants.ageEligibilityPolicyVersion,
          ageGroup: AgeGroup.adult,
          source: AgeSource.selfAttestation,
        );
        expect(state.needsConfirmation, isFalse);
      },
    );

    test('confirmed with old policy version needs confirmation', () {
      final state = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: DateTime.now().toUtc(),
        policyVersion: LegalConstants.ageEligibilityPolicyVersion - 1,
        ageGroup: AgeGroup.adult,
      );
      expect(state.needsConfirmation, isTrue);
    });

    test('not confirmed with current policy version needs confirmation', () {
      const state = AgeEligibilityState(hasConfirmed: false, policyVersion: 1);
      expect(state.needsConfirmation, isTrue);
    });

    test('safetyPolicy returns AgeSafetyPolicy matching ageGroup', () {
      const adultState = AgeEligibilityState(
        hasConfirmed: true,
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(adultState.safetyPolicy.isMinor, isFalse);
      expect(adultState.safetyPolicy.ageGroup, AgeGroup.adult);

      const teenState = AgeEligibilityState(
        hasConfirmed: true,
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      expect(teenState.safetyPolicy.isMinor, isTrue);
      expect(teenState.safetyPolicy.shouldHidePreciseLocation, isTrue);
    });

    test('equality works correctly', () {
      final now = DateTime.now().toUtc();
      final a = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      final b = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on different ageGroup', () {
      final now = DateTime.now().toUtc();
      final a = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
        ageGroup: AgeGroup.adult,
      );
      final b = AgeEligibilityState(
        hasConfirmed: true,
        confirmedAt: now,
        policyVersion: 1,
        ageGroup: AgeGroup.teen,
      );
      expect(a, isNot(equals(b)));
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
      expect(str, contains('ageGroup=AgeGroup.unknown'));
    });
  });

  group('SharedPreferences persistence round-trip', () {
    test(
      'persists and reads back age eligibility with ageGroup and source',
      () async {
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
        await prefs.setString(
          LegalConstants.ageEligibilityAgeGroupKey,
          AgeGroup.adult.name,
        );
        await prefs.setString(
          LegalConstants.ageEligibilityAgeSourceKey,
          AgeSource.selfAttestation.name,
        );

        // Read back
        final confirmed =
            prefs.getBool(LegalConstants.ageEligibilityConfirmedKey) ?? false;
        final at = prefs.getString(LegalConstants.ageEligibilityConfirmedAtKey);
        final version =
            prefs.getInt(LegalConstants.ageEligibilityPolicyVersionKey) ?? 0;
        final groupName = prefs.getString(
          LegalConstants.ageEligibilityAgeGroupKey,
        );
        final sourceName = prefs.getString(
          LegalConstants.ageEligibilityAgeSourceKey,
        );

        expect(confirmed, isTrue);
        expect(at, equals(timestamp));
        expect(version, equals(LegalConstants.ageEligibilityPolicyVersion));
        expect(groupName, equals('adult'));
        expect(sourceName, equals('selfAttestation'));

        // Construct state from persisted values
        final state = AgeEligibilityState(
          hasConfirmed: confirmed,
          confirmedAt: at != null ? DateTime.tryParse(at) : null,
          policyVersion: version,
          ageGroup: AgeGroup.values.firstWhere(
            (g) => g.name == groupName,
            orElse: () => AgeGroup.unknown,
          ),
          source: AgeSource.values.firstWhere(
            (s) => s.name == sourceName,
            orElse: () => AgeSource.unknown,
          ),
        );
        expect(state.needsConfirmation, isFalse);
        expect(state.ageGroup, AgeGroup.adult);
        expect(state.source, AgeSource.selfAttestation);
      },
    );

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
        expect(state.ageGroup, AgeGroup.unknown);
      },
    );

    test('unknown ageGroup in prefs falls back gracefully', () async {
      SharedPreferences.setMockInitialValues({
        LegalConstants.ageEligibilityConfirmedKey: true,
        LegalConstants.ageEligibilityConfirmedAtKey: DateTime.now()
            .toUtc()
            .toIso8601String(),
        LegalConstants.ageEligibilityPolicyVersionKey:
            LegalConstants.ageEligibilityPolicyVersion,
        LegalConstants.ageEligibilityAgeGroupKey: 'invalid_value',
      });
      final prefs = await SharedPreferences.getInstance();

      final groupName = prefs.getString(
        LegalConstants.ageEligibilityAgeGroupKey,
      );
      final ageGroup = AgeGroup.values.firstWhere(
        (g) => g.name == groupName,
        orElse: () => AgeGroup.unknown,
      );
      expect(ageGroup, AgeGroup.unknown);
    });

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
      expect(LegalConstants.ageEligibilityAgeGroupKey, isNotEmpty);
      expect(LegalConstants.ageEligibilityAgeSourceKey, isNotEmpty);
    });
  });
}
