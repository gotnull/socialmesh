// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/legal/age_group.dart';
import 'package:socialmesh/core/legal/age_safety_policy.dart';

void main() {
  group('AgeSafetyPolicy.isMinor', () {
    test('unknown is treated as minor (conservative default)', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.unknown,
        source: AgeSource.unknown,
      );
      expect(policy.isMinor, isTrue);
    });

    test('under13 is minor', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.under13,
        source: AgeSource.selfAttestation,
      );
      expect(policy.isMinor, isTrue);
    });

    test('teen is minor', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      expect(policy.isMinor, isTrue);
    });

    test('adult is not minor', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(policy.isMinor, isFalse);
    });
  });

  group('AgeSafetyPolicy.shouldHidePreciseLocation', () {
    test('true when unknown', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.unknown,
        source: AgeSource.unknown,
      );
      expect(policy.shouldHidePreciseLocation, isTrue);
    });

    test('true for under13', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.under13,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldHidePreciseLocation, isTrue);
    });

    test('true for teen', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldHidePreciseLocation, isTrue);
    });

    test('false for adult', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldHidePreciseLocation, isFalse);
    });
  });

  group('AgeSafetyPolicy.shouldRestrictUnsolicitedContact', () {
    // Unlike isMinor, restriction is only applied for confirmed minor groups,
    // not for unknown (conservative for location, but not for contact UI).
    test('false when unknown (restriction requires confirmed minor group)', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.unknown,
        source: AgeSource.unknown,
      );
      expect(policy.shouldRestrictUnsolicitedContact, isFalse);
    });

    test('true for under13', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.under13,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldRestrictUnsolicitedContact, isTrue);
    });

    test('true for teen', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldRestrictUnsolicitedContact, isTrue);
    });

    test('false for adult', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldRestrictUnsolicitedContact, isFalse);
    });
  });

  group('AgeSafetyPolicy.shouldRequireSafeDefaults', () {
    test('true when unknown', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.unknown,
        source: AgeSource.unknown,
      );
      expect(policy.shouldRequireSafeDefaults, isTrue);
    });

    test('true for under13', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.under13,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldRequireSafeDefaults, isTrue);
    });

    test('true for teen', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldRequireSafeDefaults, isTrue);
    });

    test('false for adult', () {
      const policy = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(policy.shouldRequireSafeDefaults, isFalse);
    });
  });

  group('AgeSafetyPolicy.safe', () {
    test('is conservative default (unknown = minor for most capabilities)', () {
      expect(AgeSafetyPolicy.safe.isMinor, isTrue);
      expect(AgeSafetyPolicy.safe.shouldHidePreciseLocation, isTrue);
      // Contact restriction is not applied speculatively for unknown users.
      expect(AgeSafetyPolicy.safe.shouldRestrictUnsolicitedContact, isFalse);
      expect(AgeSafetyPolicy.safe.shouldRequireSafeDefaults, isTrue);
    });

    test('uses unknown ageGroup and unknown source', () {
      expect(AgeSafetyPolicy.safe.ageGroup, AgeGroup.unknown);
      expect(AgeSafetyPolicy.safe.source, AgeSource.unknown);
    });
  });

  group('AgeSafetyPolicy equality and hashCode', () {
    test('equal when same ageGroup and source', () {
      const a = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      const b = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when ageGroup differs', () {
      const a = AgeSafetyPolicy(
        ageGroup: AgeGroup.teen,
        source: AgeSource.selfAttestation,
      );
      const b = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equal when source differs', () {
      const a = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.selfAttestation,
      );
      const b = AgeSafetyPolicy(
        ageGroup: AgeGroup.adult,
        source: AgeSource.playAgeSignals,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
