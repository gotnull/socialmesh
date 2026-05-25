// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org_membership.dart';

void main() {
  group('LicenseOrgMemberRole.fromWire', () {
    test('parses known roles', () {
      expect(
        LicenseOrgMemberRole.fromWire('owner'),
        LicenseOrgMemberRole.owner,
      );
      expect(
        LicenseOrgMemberRole.fromWire('admin'),
        LicenseOrgMemberRole.admin,
      );
      expect(
        LicenseOrgMemberRole.fromWire('member'),
        LicenseOrgMemberRole.member,
      );
    });

    test('defaults to unknown for null / unrecognised values', () {
      expect(LicenseOrgMemberRole.fromWire(null), LicenseOrgMemberRole.unknown);
      expect(LicenseOrgMemberRole.fromWire(''), LicenseOrgMemberRole.unknown);
      expect(
        LicenseOrgMemberRole.fromWire('super'),
        LicenseOrgMemberRole.unknown,
      );
    });
  });

  group('LicenseOrgMemberStatus.fromWire', () {
    test('parses known statuses', () {
      expect(
        LicenseOrgMemberStatus.fromWire('active'),
        LicenseOrgMemberStatus.active,
      );
      expect(
        LicenseOrgMemberStatus.fromWire('revoked'),
        LicenseOrgMemberStatus.revoked,
      );
      expect(
        LicenseOrgMemberStatus.fromWire('invited'),
        LicenseOrgMemberStatus.invited,
      );
    });

    test('defaults to unknown for null / unrecognised values', () {
      expect(
        LicenseOrgMemberStatus.fromWire(null),
        LicenseOrgMemberStatus.unknown,
      );
      expect(
        LicenseOrgMemberStatus.fromWire(''),
        LicenseOrgMemberStatus.unknown,
      );
      expect(
        LicenseOrgMemberStatus.fromWire('expired'),
        LicenseOrgMemberStatus.unknown,
      );
    });
  });

  group('LicenseOrgMembership.fromMap', () {
    test('parses a complete row', () {
      final m = LicenseOrgMembership.fromMap({
        'uid': 'user-1',
        'orgId': 'acme-eng-team',
        'role': 'member',
        'joinedAt': Timestamp.fromDate(DateTime.utc(2026, 5, 5)),
        'invitedBy': 'admin-1',
        'status': 'active',
      });
      expect(m, isNotNull);
      expect(m!.uid, 'user-1');
      expect(m.orgId, 'acme-eng-team');
      expect(m.role, LicenseOrgMemberRole.member);
      expect(m.joinedAt, DateTime.utc(2026, 5, 5));
      expect(m.invitedBy, 'admin-1');
      expect(m.status, LicenseOrgMemberStatus.active);
      expect(m.isAccessActive, isTrue);
    });

    test('returns null for missing data', () {
      expect(LicenseOrgMembership.fromMap(null), isNull);
    });

    test('returns null when uid is missing or wrong type', () {
      expect(
        LicenseOrgMembership.fromMap({'orgId': 'acme', 'status': 'active'}),
        isNull,
      );
      expect(
        LicenseOrgMembership.fromMap({
          'uid': 42,
          'orgId': 'acme',
          'status': 'active',
        }),
        isNull,
      );
      expect(
        LicenseOrgMembership.fromMap({
          'uid': '',
          'orgId': 'acme',
          'status': 'active',
        }),
        isNull,
      );
    });

    test('returns null when orgId is missing or empty', () {
      expect(
        LicenseOrgMembership.fromMap({'uid': 'user-1', 'status': 'active'}),
        isNull,
      );
      expect(
        LicenseOrgMembership.fromMap({
          'uid': 'user-1',
          'orgId': '',
          'status': 'active',
        }),
        isNull,
      );
    });

    test('tolerates missing optional fields', () {
      final m = LicenseOrgMembership.fromMap({
        'uid': 'user-1',
        'orgId': 'acme-eng-team',
        'status': 'active',
      });
      expect(m, isNotNull);
      expect(m!.role, LicenseOrgMemberRole.unknown);
      expect(m.joinedAt, isNull);
      expect(m.invitedBy, isNull);
    });

    test('drops empty invitedBy', () {
      final m = LicenseOrgMembership.fromMap({
        'uid': 'user-1',
        'orgId': 'acme-eng-team',
        'status': 'active',
        'invitedBy': '',
      });
      expect(m!.invitedBy, isNull);
    });

    test('isAccessActive is false for revoked / invited / unknown', () {
      LicenseOrgMembership? build(String status) =>
          LicenseOrgMembership.fromMap({
            'uid': 'user-1',
            'orgId': 'acme-eng-team',
            'status': status,
          });
      expect(build('revoked')!.isAccessActive, isFalse);
      expect(build('invited')!.isAccessActive, isFalse);
      expect(build('expired')!.isAccessActive, isFalse);
    });
  });

  group('equality and copyWith', () {
    LicenseOrgMembership sample() => LicenseOrgMembership(
      uid: 'user-1',
      orgId: 'acme-eng-team',
      role: LicenseOrgMemberRole.member,
      joinedAt: DateTime.utc(2026, 5, 5),
      invitedBy: 'admin-1',
      status: LicenseOrgMemberStatus.active,
    );

    test('equal when all fields match', () {
      expect(sample(), equals(sample()));
      expect(sample().hashCode, sample().hashCode);
    });

    test('differs when status changes', () {
      expect(
        sample(),
        isNot(
          equals(sample().copyWith(status: LicenseOrgMemberStatus.revoked)),
        ),
      );
    });

    test('copyWith preserves untouched fields', () {
      final updated = sample().copyWith(role: LicenseOrgMemberRole.admin);
      expect(updated.role, LicenseOrgMemberRole.admin);
      expect(updated.uid, 'user-1');
      expect(updated.orgId, 'acme-eng-team');
    });
  });
}
