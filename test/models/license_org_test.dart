// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org.dart';

void main() {
  group('LicenseOrgStatus.fromWire', () {
    test('parses known wire values', () {
      expect(LicenseOrgStatus.fromWire('active'), LicenseOrgStatus.active);
      expect(
        LicenseOrgStatus.fromWire('suspended'),
        LicenseOrgStatus.suspended,
      );
    });

    test('defaults to unknown for null / empty / unrecognised values', () {
      expect(LicenseOrgStatus.fromWire(null), LicenseOrgStatus.unknown);
      expect(LicenseOrgStatus.fromWire(''), LicenseOrgStatus.unknown);
      expect(LicenseOrgStatus.fromWire('deleted'), LicenseOrgStatus.unknown);
      expect(LicenseOrgStatus.fromWire('ACTIVE'), LicenseOrgStatus.unknown);
    });
  });

  group('LicenseOrg.fromMap', () {
    test('parses a complete document', () {
      final org = LicenseOrg.fromMap('acme-eng-team', {
        'name': 'Acme Engineering Team',
        'ownerUid': 'admin-uid-1',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 5, 10, 0, 0)),
        'status': 'active',
      });
      expect(org, isNotNull);
      expect(org!.id, 'acme-eng-team');
      expect(org.name, 'Acme Engineering Team');
      expect(org.ownerUid, 'admin-uid-1');
      expect(org.createdAt, DateTime.utc(2026, 5, 5, 10, 0, 0));
      expect(org.status, LicenseOrgStatus.active);
      expect(org.isAccessActive, isTrue);
    });

    test('returns null for missing data map', () {
      expect(LicenseOrg.fromMap('x', null), isNull);
    });

    test('returns null when ownerUid is missing or wrong type', () {
      expect(LicenseOrg.fromMap('x', {'status': 'active'}), isNull);
      expect(
        LicenseOrg.fromMap('x', {'ownerUid': 123, 'status': 'active'}),
        isNull,
        reason: 'wrong type must fail closed, not crash',
      );
      expect(
        LicenseOrg.fromMap('x', {'ownerUid': '', 'status': 'active'}),
        isNull,
      );
    });

    test('tolerates missing optional fields (name, createdAt)', () {
      final org = LicenseOrg.fromMap('x', {
        'ownerUid': 'admin-uid-1',
        'status': 'active',
      });
      expect(org, isNotNull);
      expect(org!.name, '');
      expect(org.createdAt, isNull);
    });

    test('accepts ISO-8601 string createdAt', () {
      final org = LicenseOrg.fromMap('x', {
        'ownerUid': 'admin-uid-1',
        'status': 'active',
        'createdAt': '2026-05-05T10:00:00.000Z',
      });
      expect(org!.createdAt, DateTime.utc(2026, 5, 5, 10, 0, 0));
    });

    test('drops malformed createdAt without failing the parse', () {
      final org = LicenseOrg.fromMap('x', {
        'ownerUid': 'admin-uid-1',
        'status': 'active',
        'createdAt': 'not-a-date',
      });
      expect(org, isNotNull);
      expect(org!.createdAt, isNull);
    });

    test('isAccessActive is false for suspended / unknown orgs', () {
      final suspended = LicenseOrg.fromMap('x', {
        'ownerUid': 'admin-uid-1',
        'status': 'suspended',
      });
      final unknown = LicenseOrg.fromMap('x', {
        'ownerUid': 'admin-uid-1',
        'status': 'deleted',
      });
      expect(suspended!.isAccessActive, isFalse);
      expect(unknown!.isAccessActive, isFalse);
    });
  });

  group('equality and copyWith', () {
    LicenseOrg sample() => LicenseOrg(
      id: 'acme-eng-team',
      name: 'Acme',
      ownerUid: 'admin-1',
      createdAt: DateTime.utc(2026, 5, 5),
      status: LicenseOrgStatus.active,
    );

    test('equal when all fields match', () {
      expect(sample(), equals(sample()));
      expect(sample().hashCode, sample().hashCode);
    });

    test('differs when status changes', () {
      expect(
        sample(),
        isNot(equals(sample().copyWith(status: LicenseOrgStatus.suspended))),
      );
    });

    test('copyWith preserves untouched fields', () {
      final updated = sample().copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.ownerUid, 'admin-1');
      expect(updated.status, LicenseOrgStatus.active);
    });
  });
}
