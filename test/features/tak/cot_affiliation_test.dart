// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/tak/utils/cot_affiliation.dart';

void main() {
  group('parseAffiliation', () {
    test('parses friendly atom "f"', () {
      expect(parseAffiliation('a-f-G-U-C'), CotAffiliation.friendly);
    });

    test('parses hostile atom "h"', () {
      expect(parseAffiliation('a-h-G-U-C'), CotAffiliation.hostile);
    });

    test('parses neutral atom "n"', () {
      expect(parseAffiliation('a-n-G-U'), CotAffiliation.neutral);
    });

    test('parses unknown atom "u"', () {
      expect(parseAffiliation('a-u-G'), CotAffiliation.unknown);
    });

    test('parses assumed friend atom "a"', () {
      expect(parseAffiliation('a-a-G-U-C'), CotAffiliation.assumedFriend);
    });

    test('parses suspect atom "s"', () {
      expect(parseAffiliation('a-s-G-U-C'), CotAffiliation.suspect);
    });

    test('returns pending for unrecognized atom', () {
      expect(parseAffiliation('a-x-G-U-C'), CotAffiliation.pending);
    });

    test('returns pending for malformed type with one atom', () {
      expect(parseAffiliation('a'), CotAffiliation.pending);
    });

    test('returns pending for empty string', () {
      expect(parseAffiliation(''), CotAffiliation.pending);
    });

    test('handles uppercase atom (case-insensitive)', () {
      expect(parseAffiliation('a-F-G-U-C'), CotAffiliation.friendly);
    });

    test('handles minimal two-atom type', () {
      expect(parseAffiliation('a-h'), CotAffiliation.hostile);
    });

    test('handles non-atom type prefix', () {
      expect(parseAffiliation('b-f-some-thing'), CotAffiliation.friendly);
    });

    test('handles tasking type prefix', () {
      expect(parseAffiliation('t-u-something'), CotAffiliation.unknown);
    });
  });

  group('CotAffiliationX.color', () {
    test('friendly returns blue', () {
      expect(CotAffiliation.friendly.color, CotAffiliationColors.friendly);
    });

    test('hostile returns red', () {
      expect(CotAffiliation.hostile.color, CotAffiliationColors.hostile);
    });

    test('neutral returns green', () {
      expect(CotAffiliation.neutral.color, CotAffiliationColors.neutral);
    });

    test('unknown returns yellow', () {
      expect(CotAffiliation.unknown.color, CotAffiliationColors.unknown);
    });

    test('assumed friend returns lighter blue', () {
      expect(
        CotAffiliation.assumedFriend.color,
        CotAffiliationColors.assumedFriend,
      );
    });

    test('suspect returns lighter red', () {
      expect(CotAffiliation.suspect.color, CotAffiliationColors.suspect);
    });

    test('pending returns yellow', () {
      expect(CotAffiliation.pending.color, CotAffiliationColors.pending);
    });
  });

  group('CotAffiliationX.label', () {
    test('all affiliations have non-empty labels', () {
      for (final aff in CotAffiliation.values) {
        expect(aff.label.isNotEmpty, isTrue, reason: '$aff has empty label');
      }
    });
  });

  group('CotAffiliationColors', () {
    test('all colors are fully opaque', () {
      final colors = [
        CotAffiliationColors.friendly,
        CotAffiliationColors.hostile,
        CotAffiliationColors.neutral,
        CotAffiliationColors.unknown,
        CotAffiliationColors.assumedFriend,
        CotAffiliationColors.suspect,
        CotAffiliationColors.pending,
      ];
      for (final color in colors) {
        expect(color.a, 1.0, reason: '$color is not fully opaque');
      }
    });

    test('friendly and assumed friend are different', () {
      expect(
        CotAffiliationColors.friendly,
        isNot(CotAffiliationColors.assumedFriend),
      );
    });

    test('hostile and suspect are different', () {
      expect(CotAffiliationColors.hostile, isNot(CotAffiliationColors.suspect));
    });
  });
}
