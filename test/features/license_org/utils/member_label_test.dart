// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/license_org/utils/member_label.dart';

void main() {
  group('licenseOrgMemberLabel', () {
    test('empty uid renders the all-dashes fallback', () {
      expect(licenseOrgMemberLabel(''), '#------');
    });

    test('short uid pads with underscores to reach 6 chars', () {
      expect(licenseOrgMemberLabel('abc'), '#ABC___');
    });

    test('long uid takes the first 6 chars uppercased', () {
      expect(licenseOrgMemberLabel('9ltxJGViWHW5aj5HhLGmiVwkrLU2'), '#9LTXJG');
    });
  });

  group('licenseOrgUidFromAllocationId', () {
    test('extracts the uid from a canonical orgId__uid__productId triple', () {
      // Regression for the 2026-05-28 first-revoke bug — `targetId`
      // on a `seat_revoked_manual` audit row is the full allocation
      // doc id, not the uid alone. Splitting + returning the middle
      // segment is the load-bearing transformation.
      expect(
        licenseOrgUidFromAllocationId('acme__uid-roundtrip__complete_pack'),
        'uid-roundtrip',
      );
    });

    test('empty input degrades to empty', () {
      expect(licenseOrgUidFromAllocationId(''), '');
    });

    test('non-canonical shape falls back to the raw input', () {
      // Defensive: an unknown allocation-id format should NOT
      // surface as an empty label; the caller still gets something
      // (even if it's the raw doc id) so the row doesn't blank.
      expect(licenseOrgUidFromAllocationId('something-else'), 'something-else');
      expect(licenseOrgUidFromAllocationId('only__two'), 'only__two');
    });
  });
}
