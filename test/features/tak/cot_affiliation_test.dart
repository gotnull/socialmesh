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

  group('cotTypeIcon', () {
    test('b- prefix returns data_object icon', () {
      expect(cotTypeIcon('b-f-some-thing'), Icons.data_object);
    });

    test('b- prefix with minimal string returns data_object', () {
      expect(cotTypeIcon('b-'), Icons.data_object);
    });

    test('t- prefix returns assignment icon', () {
      expect(cotTypeIcon('t-u-something'), Icons.assignment);
    });

    test('t- prefix with minimal string returns assignment', () {
      expect(cotTypeIcon('t-'), Icons.assignment);
    });

    test('ground unit returns groups icon', () {
      expect(cotTypeIcon('a-f-G-U-C'), Icons.groups);
    });

    test('ground equipment returns local_shipping icon', () {
      expect(cotTypeIcon('a-f-G-E'), Icons.local_shipping);
    });

    test('ground installation returns business icon', () {
      expect(cotTypeIcon('a-n-G-I'), Icons.business);
    });

    test('ground civilian returns person icon', () {
      expect(cotTypeIcon('a-f-G-C'), Icons.person);
    });

    test('ground generic returns terrain icon', () {
      expect(cotTypeIcon('a-f-G'), Icons.terrain);
    });

    test('air dimension returns flight icon', () {
      expect(cotTypeIcon('a-h-A'), Icons.flight);
    });

    test('air UAV returns flight_takeoff icon', () {
      expect(cotTypeIcon('a-h-A-U'), Icons.flight_takeoff);
    });

    test('sea surface returns sailing icon', () {
      expect(cotTypeIcon('a-n-S'), Icons.sailing);
    });

    test('subsurface returns scuba_diving icon', () {
      expect(cotTypeIcon('a-n-U'), Icons.scuba_diving);
    });

    test('space returns satellite_alt icon', () {
      expect(cotTypeIcon('a-f-P'), Icons.satellite_alt);
    });

    test('SOF returns shield icon', () {
      expect(cotTypeIcon('a-f-F'), Icons.shield);
    });

    test('electronic warfare returns cell_tower icon', () {
      expect(cotTypeIcon('a-f-E'), Icons.cell_tower);
    });

    test('malformed type returns gps_fixed icon', () {
      expect(cotTypeIcon('a-f'), Icons.gps_fixed);
    });

    test('empty string returns gps_fixed icon', () {
      expect(cotTypeIcon(''), Icons.gps_fixed);
    });

    test('unknown dimension returns gps_fixed icon', () {
      expect(cotTypeIcon('a-f-Z'), Icons.gps_fixed);
    });
  });
}
