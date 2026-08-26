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

  group('LicenseOrgFleetAccess.fromWire', () {
    test('absent means none, not unknown', () {
      // An org predating the capability genuinely has no access.
      // Reporting "unknown" about it would be less accurate than
      // reporting "not granted".
      expect(LicenseOrgFleetAccess.fromWire(null), LicenseOrgFleetAccess.none);
      expect(LicenseOrgFleetAccess.fromWire(''), LicenseOrgFleetAccess.none);
    });

    test('explicit none means none', () {
      expect(
        LicenseOrgFleetAccess.fromWire('none'),
        LicenseOrgFleetAccess.none,
      );
    });

    test('recognised grants map through', () {
      expect(
        LicenseOrgFleetAccess.fromWire('pilot'),
        LicenseOrgFleetAccess.pilot,
      );
      expect(
        LicenseOrgFleetAccess.fromWire('commercial'),
        LicenseOrgFleetAccess.commercial,
      );
    });

    test('an unrecognised value is unknown, NOT none', () {
      // A newer server grant kind is a genuine third display state: we
      // must not claim access is granted, nor confidently claim it is
      // denied. Collapsing it to `none` would assert a denial we cannot
      // support.
      expect(
        LicenseOrgFleetAccess.fromWire('enterprise-2029'),
        LicenseOrgFleetAccess.unknown,
      );
      expect(
        LicenseOrgFleetAccess.fromWire('PILOT'),
        LicenseOrgFleetAccess.unknown,
      );
    });

    test('round trips through toWire', () {
      for (final access in LicenseOrgFleetAccess.values) {
        if (access == LicenseOrgFleetAccess.unknown) continue;
        expect(LicenseOrgFleetAccess.fromWire(access.toWire()), access);
      }
    });

    test('isGrantedForDisplay covers only recognised grants', () {
      expect(LicenseOrgFleetAccess.pilot.isGrantedForDisplay, isTrue);
      expect(LicenseOrgFleetAccess.commercial.isGrantedForDisplay, isTrue);
      expect(LicenseOrgFleetAccess.none.isGrantedForDisplay, isFalse);
      // Unknown is deliberately not a grant for display purposes - we
      // render an indeterminate state rather than implying access.
      expect(LicenseOrgFleetAccess.unknown.isGrantedForDisplay, isFalse);
    });
  });

  group('LicenseOrg fleetAccess parsing', () {
    Map<String, dynamic> wire({Object? fleetAccess}) => <String, dynamic>{
      'ownerUid': 'owner-uid',
      'status': 'active',
      'name': 'Acme',
      if (fleetAccess != null) 'fleetAccess': fleetAccess,
    };

    test('defaults to none when the field is absent', () {
      final org = LicenseOrg.fromMap('acme-team', wire());
      expect(org, isNotNull);
      expect(org!.fleetAccess, LicenseOrgFleetAccess.none);
    });

    test('parses a pilot grant', () {
      final org = LicenseOrg.fromMap('acme-team', wire(fleetAccess: 'pilot'));
      expect(org!.fleetAccess, LicenseOrgFleetAccess.pilot);
    });

    test('parses a commercial grant', () {
      final org = LicenseOrg.fromMap(
        'acme-team',
        wire(fleetAccess: 'commercial'),
      );
      expect(org!.fleetAccess, LicenseOrgFleetAccess.commercial);
    });

    test('a non-string value degrades to none rather than throwing', () {
      final org = LicenseOrg.fromMap('acme-team', wire(fleetAccess: 42));
      expect(org, isNotNull);
      expect(org!.fleetAccess, LicenseOrgFleetAccess.none);
    });

    test('fleetAccess participates in equality', () {
      final base = LicenseOrg.fromMap('acme-team', wire(fleetAccess: 'pilot'))!;
      expect(
        base,
        isNot(base.copyWith(fleetAccess: LicenseOrgFleetAccess.commercial)),
      );
    });

    test('toString does not imply authority', () {
      final org = LicenseOrg.fromMap('acme-team', wire(fleetAccess: 'pilot'))!;
      expect(org.toString(), contains('fleetAccess: pilot'));
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
