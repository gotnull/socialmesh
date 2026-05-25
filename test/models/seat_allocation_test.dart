// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/seat_allocation.dart';

void main() {
  group('SeatAllocationStatus.fromWire', () {
    test('parses known statuses', () {
      expect(
        SeatAllocationStatus.fromWire('active'),
        SeatAllocationStatus.active,
      );
      expect(
        SeatAllocationStatus.fromWire('revoked'),
        SeatAllocationStatus.revoked,
      );
    });

    test('defaults to unknown for null / unrecognised values', () {
      expect(SeatAllocationStatus.fromWire(null), SeatAllocationStatus.unknown);
      expect(SeatAllocationStatus.fromWire(''), SeatAllocationStatus.unknown);
      expect(
        SeatAllocationStatus.fromWire('expired'),
        SeatAllocationStatus.unknown,
      );
    });
  });

  group('SeatAllocationRef', () {
    test('equality is field-based', () {
      const a = SeatAllocationRef(orgId: 'acme', productId: 'widget_pack');
      const b = SeatAllocationRef(orgId: 'acme', productId: 'widget_pack');
      const c = SeatAllocationRef(orgId: 'acme', productId: 'theme_pack');
      const d = SeatAllocationRef(orgId: 'beta', productId: 'widget_pack');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
    });

    test('Set<SeatAllocationRef> de-dupes by value', () {
      final first = SeatAllocationRef(orgId: 'acme', productId: 'widget_pack');
      final secondSameValue = SeatAllocationRef(
        orgId: 'acme',
        productId: 'widget_pack',
      );
      final third = SeatAllocationRef(orgId: 'acme', productId: 'theme_pack');
      final s = <SeatAllocationRef>{first, secondSameValue, third};
      expect(s, hasLength(2));
    });
  });

  group('SeatAllocation.fromMap', () {
    test('parses a complete row', () {
      final s = SeatAllocation.fromMap({
        'orgId': 'acme-eng-team',
        'uid': 'user-1',
        'productId': 'widget_pack',
        'allocatedAt': Timestamp.fromDate(DateTime.utc(2026, 5, 5, 10)),
        'allocatedBy': 'admin-1',
        'revokedAt': null,
        'status': 'active',
      });
      expect(s, isNotNull);
      expect(s!.orgId, 'acme-eng-team');
      expect(s.uid, 'user-1');
      expect(s.productId, 'widget_pack');
      expect(s.allocatedAt, DateTime.utc(2026, 5, 5, 10));
      expect(s.allocatedBy, 'admin-1');
      expect(s.revokedAt, isNull);
      expect(s.status, SeatAllocationStatus.active);
      expect(s.isAccessActive, isTrue);
    });

    test('returns null for missing data', () {
      expect(SeatAllocation.fromMap(null), isNull);
    });

    test('returns null when orgId is missing or empty', () {
      expect(
        SeatAllocation.fromMap({
          'uid': 'user-1',
          'productId': 'widget_pack',
          'status': 'active',
        }),
        isNull,
      );
      expect(
        SeatAllocation.fromMap({
          'orgId': '',
          'uid': 'user-1',
          'productId': 'widget_pack',
          'status': 'active',
        }),
        isNull,
      );
    });

    test('returns null when uid is missing or wrong type', () {
      expect(
        SeatAllocation.fromMap({
          'orgId': 'acme',
          'productId': 'widget_pack',
          'status': 'active',
        }),
        isNull,
      );
      expect(
        SeatAllocation.fromMap({
          'orgId': 'acme',
          'uid': 42,
          'productId': 'widget_pack',
          'status': 'active',
        }),
        isNull,
      );
    });

    test('returns null when productId is missing or empty', () {
      expect(
        SeatAllocation.fromMap({
          'orgId': 'acme',
          'uid': 'user-1',
          'status': 'active',
        }),
        isNull,
      );
      expect(
        SeatAllocation.fromMap({
          'orgId': 'acme',
          'uid': 'user-1',
          'productId': '',
          'status': 'active',
        }),
        isNull,
      );
    });

    test('tolerates missing optional timestamps + allocatedBy', () {
      final s = SeatAllocation.fromMap({
        'orgId': 'acme',
        'uid': 'user-1',
        'productId': 'widget_pack',
        'status': 'active',
      });
      expect(s, isNotNull);
      expect(s!.allocatedAt, isNull);
      expect(s.allocatedBy, isNull);
      expect(s.revokedAt, isNull);
    });

    test('accepts ISO-8601 string timestamps', () {
      final s = SeatAllocation.fromMap({
        'orgId': 'acme',
        'uid': 'user-1',
        'productId': 'widget_pack',
        'status': 'revoked',
        'allocatedAt': '2026-05-01T10:00:00.000Z',
        'revokedAt': '2026-05-05T10:00:00.000Z',
      });
      expect(s!.allocatedAt, DateTime.utc(2026, 5, 1, 10));
      expect(s.revokedAt, DateTime.utc(2026, 5, 5, 10));
    });

    test('isAccessActive is false for revoked / unknown', () {
      SeatAllocation? build(String status) => SeatAllocation.fromMap({
        'orgId': 'acme',
        'uid': 'user-1',
        'productId': 'widget_pack',
        'status': status,
      });
      expect(build('active')!.isAccessActive, isTrue);
      expect(build('revoked')!.isAccessActive, isFalse);
      expect(build('expired')!.isAccessActive, isFalse);
    });

    test('toRef projects to (orgId, productId)', () {
      final s = SeatAllocation.fromMap({
        'orgId': 'acme',
        'uid': 'user-1',
        'productId': 'widget_pack',
        'status': 'active',
      })!;
      expect(
        s.toRef(),
        const SeatAllocationRef(orgId: 'acme', productId: 'widget_pack'),
      );
    });
  });

  group('equality and copyWith', () {
    SeatAllocation sample() => const SeatAllocation(
      orgId: 'acme',
      uid: 'user-1',
      productId: 'widget_pack',
      allocatedAt: null,
      allocatedBy: 'admin-1',
      revokedAt: null,
      status: SeatAllocationStatus.active,
    );

    test('equal when all fields match', () {
      expect(sample(), equals(sample()));
      expect(sample().hashCode, sample().hashCode);
    });

    test('differs when status changes', () {
      expect(
        sample(),
        isNot(equals(sample().copyWith(status: SeatAllocationStatus.revoked))),
      );
    });

    test('copyWith preserves untouched fields', () {
      final updated = sample().copyWith(uid: 'user-2');
      expect(updated.uid, 'user-2');
      expect(updated.orgId, 'acme');
      expect(updated.productId, 'widget_pack');
      expect(updated.status, SeatAllocationStatus.active);
    });
  });
}
