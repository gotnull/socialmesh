// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/legal/age_group.dart';

void main() {
  group('AgeGroup enum', () {
    test('all values have unique names', () {
      final names = AgeGroup.values.map((g) => g.name).toSet();
      expect(names.length, equals(AgeGroup.values.length));
    });

    test('known value round-trips through name lookup', () {
      for (final group in AgeGroup.values) {
        final found = AgeGroup.values.firstWhere(
          (g) => g.name == group.name,
          orElse: () => AgeGroup.unknown,
        );
        expect(found, equals(group));
      }
    });

    test('invalid name falls back to unknown', () {
      const invalidName = 'notARealGroup';
      final found = AgeGroup.values.firstWhere(
        (g) => g.name == invalidName,
        orElse: () => AgeGroup.unknown,
      );
      expect(found, AgeGroup.unknown);
    });
  });

  group('AgeSource enum', () {
    test('all values have unique names', () {
      final names = AgeSource.values.map((s) => s.name).toSet();
      expect(names.length, equals(AgeSource.values.length));
    });

    test('selfAttestation round-trips through name lookup', () {
      final found = AgeSource.values.firstWhere(
        (s) => s.name == AgeSource.selfAttestation.name,
      );
      expect(found, AgeSource.selfAttestation);
    });

    test('invalid name falls back to unknown', () {
      const invalidName = 'notARealSource';
      final found = AgeSource.values.firstWhere(
        (s) => s.name == invalidName,
        orElse: () => AgeSource.unknown,
      );
      expect(found, AgeSource.unknown);
    });
  });
}
