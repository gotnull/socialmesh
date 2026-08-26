// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Fleet identity + parsing tests.
//
// The identity cases are driven from
// test/fixtures/fleet_identity_vectors.json, which the TypeScript
// callable test reads as well. If Dart and TypeScript ever derive
// different document ids, an admin enrolling a radio from one path
// would create a duplicate instead of addressing the existing record.
// Sharing one fixture makes that a test failure rather than a
// production surprise.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org_fleet_device.dart';

// Loaded at main() scope, so this runs outside a test body where
// `expect` is unavailable - a plain throw is the correct failure mode.
Map<String, dynamic> _loadVectors() {
  final file = File('test/fixtures/fleet_identity_vectors.json');
  if (!file.existsSync()) {
    throw StateError(
      'shared identity fixture missing at ${file.path} - it is the '
      'cross-language contract with the TypeScript callable tests',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<int> _hexToBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return out;
}

/// Minimal valid wire map. Individual tests override single keys to
/// exercise one malformed field at a time.
Map<String, dynamic> _validWire({
  String licenseOrgId = 'acme-team',
  String transportIdentity = 'mt-81c42d94',
  String transport = 'meshtastic',
  String assignment = 'unassigned',
  Object? assignedUid,
  Object? createdAt = '2026-08-15T02:30:00.000Z',
  Object? updatedAt = '2026-08-15T02:30:00.000Z',
  Object? createdBy = 'admin-uid-1',
  Object? tags,
}) {
  return <String, dynamic>{
    'licenseOrgId': licenseOrgId,
    'transportIdentity': transportIdentity,
    'transport': transport,
    'label': 'North Gate',
    'assignedUid': assignedUid,
    'assignment': assignment,
    'purpose': 'Gate Operations',
    'tags': tags ?? <String>['gate', 'fixed'],
    'notes': 'Roof mount, 5 dBi dipole.',
    'lastKnownHardware': 'TRACKER_T1000_E',
    'lastKnownFirmware': '2.7.19',
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'status': 'active',
  };
}

String _idFor(Map<String, dynamic> wire) =>
    '${wire['licenseOrgId']}__${wire['transportIdentity']}';

void main() {
  final vectors = _loadVectors();

  group('fleet identity - shared cross-language vectors', () {
    test('meshtastic identity matches every vector', () {
      final cases = (vectors['meshtasticIdentity'] as List).cast<Map>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        expect(
          fleetMeshtasticIdentity(c['nodeNum'] as int),
          c['expected'],
          reason: c['why'] as String,
        );
      }
    });

    test('node numbers are unsigned - negatives mask, never wrap', () {
      // Dart int is 64-bit signed. Without the explicit mask a negative
      // node number would produce a '-' in the document id.
      expect(fleetMeshtasticIdentity(-1), 'mt-ffffffff');
      expect(fleetMeshtasticIdentity(-1).contains('-0'), isFalse);
      expect(
        fleetMeshtasticIdentity(0xFFFFFFFF),
        fleetMeshtasticIdentity(-1),
        reason: 'unsigned max and -1 are the same 32-bit value',
      );
    });

    test('meshcore identity matches every vector and is never truncated', () {
      final cases = (vectors['meshCoreIdentity'] as List).cast<Map>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final hex = c['publicKeyHex'] as String;
        final identity = fleetMeshCoreIdentity(_hexToBytes(hex));
        expect(identity, c['expected'], reason: c['why'] as String);
        expect(
          identity!.length,
          3 + 64,
          reason: 'full 256-bit key retained, not shortened to 64 bits',
        );
        expect(identity.substring(3), hex);
      }
    });

    test('meshcore identity fails closed on a wrong-length key', () {
      final cases = (vectors['meshCoreIdentityInvalid'] as List).cast<Map>();
      for (final c in cases) {
        final bytes = List<int>.filled(c['byteLength'] as int, 0);
        expect(
          fleetMeshCoreIdentity(bytes),
          isNull,
          reason: c['why'] as String,
        );
      }
    });

    test('meshcore identity rejects a non-byte value', () {
      final bad = List<int>.filled(kFleetMeshCorePublicKeyBytes, 0);
      bad[7] = 256;
      expect(fleetMeshCoreIdentity(bad), isNull);
    });

    test('composed document id matches every vector', () {
      final cases = (vectors['fleetDeviceId'] as List).cast<Map>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        expect(
          fleetDeviceIdFor(
            licenseOrgId: c['licenseOrgId'] as String,
            transportIdentity: c['transportIdentity'] as String,
          ),
          c['expected'],
          reason: c['why'] as String,
        );
      }
    });

    test('same radio in different orgs yields different ids', () {
      const identity = 'mt-81c42d94';
      final a = fleetDeviceIdFor(
        licenseOrgId: 'acme-team',
        transportIdentity: identity,
      );
      final b = fleetDeviceIdFor(
        licenseOrgId: 'alpine-expedition',
        transportIdentity: identity,
      );
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(
        a,
        isNot(b),
        reason:
            'license_orgs allows many orgs per user and no invariant makes a '
            'radio globally exclusive - a shared id would collide',
      );
    });

    test('same radio in the same org is deterministic', () {
      final first = fleetDeviceIdFor(
        licenseOrgId: 'acme-team',
        transportIdentity: 'mt-81c42d94',
      );
      final second = fleetDeviceIdFor(
        licenseOrgId: 'acme-team',
        transportIdentity: 'mt-81c42d94',
      );
      expect(first, second);
      expect(first, isNotNull);
    });

    test('invalid inputs fail closed', () {
      final cases = (vectors['fleetDeviceIdInvalid'] as List).cast<Map>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        expect(
          fleetDeviceIdFor(
            licenseOrgId: c['licenseOrgId'] as String,
            transportIdentity: c['transportIdentity'] as String,
          ),
          isNull,
          reason: c['why'] as String,
        );
      }
    });

    test('every composed id is a safe Firestore document id', () {
      final safety = vectors['documentIdSafety'] as Map<String, dynamic>;
      final reserved = RegExp(safety['reservedPatternMustNotMatch'] as String);
      final maxBytes = safety['maxBytes'] as int;
      final cases = (vectors['fleetDeviceId'] as List).cast<Map>();

      for (final c in cases) {
        final id = c['expected'] as String;
        expect(id.contains('/'), isFalse, reason: 'ids cannot contain a slash');
        expect(id, isNot('.'));
        expect(id, isNot('..'));
        expect(
          reserved.hasMatch(id),
          isFalse,
          reason:
              'Firestore reserves __.*__; an org slug prefix makes it '
              'unreachable',
        );
        expect(utf8.encode(id).length, lessThanOrEqualTo(maxBytes));
      }
    });
  });

  group('audit device reference', () {
    test('matches every vector', () {
      final cases = (vectors['auditDeviceRef'] as List).cast<Map>();
      expect(cases, isNotEmpty);
      for (final c in cases) {
        expect(
          fleetAuditDeviceRef(c['transportIdentity'] as String),
          c['expected'],
          reason: c['why'] as String,
        );
      }
    });

    test('always fits the audit helper targetId cap', () {
      // appendLicenseOrgAuditEvent throws above this length. A full
      // MeshCore fleet id is 133 chars, so the short ref is what makes
      // fleet auditing possible without weakening the audit contract.
      final cap = vectors['auditTargetIdMaxLength'] as int;
      final longest = fleetAuditDeviceRef('mc-${'f' * 64}');
      expect(longest, isNotNull);
      expect(longest!.length, lessThanOrEqualTo(cap));

      for (final c in (vectors['fleetDeviceId'] as List).cast<Map>()) {
        final ref = fleetAuditDeviceRef(c['transportIdentity'] as String);
        expect(ref, isNotNull);
        expect(ref!.length, lessThanOrEqualTo(cap));
      }
    });

    test('returns null for an unrecognised identity shape', () {
      expect(fleetAuditDeviceRef('xx-81c42d94'), isNull);
      expect(fleetAuditDeviceRef(''), isNull);
    });
  });

  group('LicenseOrgFleetDevice.fromMap', () {
    test('parses a well-formed document', () {
      final wire = _validWire();
      final device = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire);

      expect(device, isNotNull);
      expect(device!.licenseOrgId, 'acme-team');
      expect(device.transport, FleetTransport.meshtastic);
      expect(device.transportIdentity, 'mt-81c42d94');
      expect(device.label, 'North Gate');
      expect(device.assignment, FleetAssignmentKind.unassigned);
      expect(device.assignedUid, isNull);
      expect(device.tags, ['gate', 'fixed']);
      expect(device.status, FleetDeviceStatus.active);
      expect(device.createdBy, 'admin-uid-1');
      expect(device.createdAt.isUtc, isTrue);
      expect(device.updatedAt.isUtc, isTrue);
    });

    test('accepts a Firestore Timestamp as well as an ISO string', () {
      final moment = DateTime.utc(2026, 8, 15, 2, 30);
      final wire = _validWire(
        createdAt: Timestamp.fromDate(moment),
        updatedAt: Timestamp.fromDate(moment),
      );
      final device = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire);

      expect(device, isNotNull);
      expect(device!.createdAt, moment);
      expect(device.updatedAt, moment);
    });

    test('returns null for null data', () {
      expect(
        LicenseOrgFleetDevice.fromMap('acme-team__mt-81c42d94', null),
        isNull,
      );
    });

    test('requires createdAt - no legacy fleet data to tolerate', () {
      final wire = _validWire(createdAt: null);
      expect(LicenseOrgFleetDevice.fromMap(_idFor(wire), wire), isNull);
    });

    test('requires updatedAt', () {
      final wire = _validWire(updatedAt: null);
      expect(LicenseOrgFleetDevice.fromMap(_idFor(wire), wire), isNull);
    });

    test('rejects an unparseable timestamp', () {
      final wire = _validWire(createdAt: 'not-a-date');
      expect(LicenseOrgFleetDevice.fromMap(_idFor(wire), wire), isNull);
    });

    test('requires createdBy', () {
      for (final bad in <Object?>[null, '', 42]) {
        final wire = _validWire(createdBy: bad);
        expect(
          LicenseOrgFleetDevice.fromMap(_idFor(wire), wire),
          isNull,
          reason: 'createdBy=$bad must fail closed',
        );
      }
    });

    test('rejects an unknown transport', () {
      final wire = _validWire(transport: 'carrier-pigeon');
      expect(LicenseOrgFleetDevice.fromMap(_idFor(wire), wire), isNull);
    });

    test('rejects a malformed org slug', () {
      final wire = _validWire(licenseOrgId: 'Acme_Team');
      expect(LicenseOrgFleetDevice.fromMap(_idFor(wire), wire), isNull);
    });

    test('rejects a malformed transport identity', () {
      final wire = _validWire(transportIdentity: 'mt-zzzz');
      expect(LicenseOrgFleetDevice.fromMap(_idFor(wire), wire), isNull);
    });

    test('rejects a document whose id disagrees with its own fields', () {
      // A row claiming to belong to acme-team but stored under another
      // org's id is corrupt and must not be trusted, because the
      // security rules authorise on resource.data.licenseOrgId.
      final wire = _validWire(licenseOrgId: 'acme-team');
      expect(
        LicenseOrgFleetDevice.fromMap('other-org__mt-81c42d94', wire),
        isNull,
      );
    });

    test('drops malformed tag entries but keeps the rest', () {
      final wire = _validWire(tags: <Object?>['keep', '', null, 7, 'also']);
      final device = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire);
      expect(device, isNotNull);
      expect(device!.tags, ['keep', 'also']);
    });

    test('tolerates a missing tags field', () {
      final wire = _validWire()..remove('tags');
      final device = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire);
      expect(device, isNotNull);
      expect(device!.tags, isEmpty);
    });

    test('normalises empty optional strings to null', () {
      final wire = _validWire()
        ..['purpose'] = ''
        ..['notes'] = ''
        ..['lastKnownFirmware'] = '';
      final device = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire);
      expect(device, isNotNull);
      expect(device!.purpose, isNull);
      expect(device.notes, isNull);
      expect(device.lastKnownFirmware, isNull);
    });
  });

  group('assignment invariant', () {
    LicenseOrgFleetDevice? build(String assignment, Object? uid) {
      final wire = _validWire(assignment: assignment, assignedUid: uid);
      return LicenseOrgFleetDevice.fromMap(_idFor(wire), wire);
    }

    test('member with a uid is consistent', () {
      expect(build('member', 'member-uid-1')!.isConsistent, isTrue);
    });

    test('member without a uid is inconsistent', () {
      expect(build('member', null)!.isConsistent, isFalse);
    });

    test('orgPool without a uid is consistent', () {
      expect(build('org_pool', null)!.isConsistent, isTrue);
    });

    test('orgPool with a uid is inconsistent', () {
      expect(build('org_pool', 'member-uid-1')!.isConsistent, isFalse);
    });

    test('unassigned without a uid is consistent', () {
      expect(build('unassigned', null)!.isConsistent, isTrue);
    });

    test('unassigned with a uid is inconsistent', () {
      expect(build('unassigned', 'member-uid-1')!.isConsistent, isFalse);
    });

    test('an unknown assignment kind is never consistent', () {
      expect(build('something-new', null)!.isConsistent, isFalse);
    });
  });

  group('wire enums', () {
    test('round trip through fromWire/toWire', () {
      for (final t in FleetTransport.values) {
        expect(FleetTransport.fromWire(t.toWire()), t);
      }
      for (final a in FleetAssignmentKind.values) {
        expect(FleetAssignmentKind.fromWire(a.toWire()), a);
      }
      for (final s in FleetDeviceStatus.values) {
        expect(FleetDeviceStatus.fromWire(s.toWire()), s);
      }
    });

    test('unrecognised wire values collapse to unknown, never throw', () {
      expect(FleetTransport.fromWire('reticulum'), FleetTransport.unknown);
      expect(FleetTransport.fromWire(null), FleetTransport.unknown);
      expect(
        FleetAssignmentKind.fromWire('contractor'),
        FleetAssignmentKind.unknown,
      );
      expect(FleetDeviceStatus.fromWire('lost'), FleetDeviceStatus.unknown);
    });

    test('wire values are snake_case where multi-word', () {
      expect(FleetAssignmentKind.orgPool.toWire(), 'org_pool');
      expect(FleetTransport.meshCore.toWire(), 'meshcore');
    });
  });

  group('value semantics', () {
    test('equality covers every field', () {
      final wire = _validWire();
      final a = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire)!;
      final b = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire)!;

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(label: 'South Gate')));
      expect(a, isNot(a.copyWith(tags: const ['different'])));
      expect(a, isNot(a.copyWith(status: FleetDeviceStatus.retired)));
    });

    test('toString carries no free-form user content', () {
      final wire = _validWire();
      final device = LicenseOrgFleetDevice.fromMap(_idFor(wire), wire)!;
      final text = device.toString();

      expect(text, contains(device.id));
      expect(
        text,
        isNot(contains('Roof mount')),
        reason: 'notes must not leak into logs',
      );
      expect(
        text,
        isNot(contains('Gate Operations')),
        reason: 'purpose must not leak into logs',
      );
    });
  });
}
