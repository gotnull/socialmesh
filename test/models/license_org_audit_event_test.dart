// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pure model parser tests for [LicenseOrgAuditEvent.fromMap].
//
// Covers:
//   - happy-path parse (all fields present)
//   - missing required fields (null map / no licenseOrgId / no action) -> null
//   - unknown action wire string -> action == unknown
//   - unknown actorRole / targetKind / outcome -> unknown enum members
//   - Timestamp + ISO string parsing for tsServer
//   - empty reasonCode / targetId collapse to null
//   - actorDisplayLabel formatting (member, system, empty uid, short uid)
//   - metadata is unmodifiable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/license_org_audit_event.dart';

void main() {
  group('LicenseOrgAuditEvent.fromMap', () {
    test('parses a fully-populated row', () {
      final ts = Timestamp.fromDate(DateTime.utc(2026, 5, 26, 12));
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'targetKind': 'license_org_membership',
        'targetId': 'user-abc',
        'actorUid': 'admin-uid-1',
        'actorRole': 'admin',
        'outcome': 'success',
        'tsServer': ts,
        'metadata': const {'reissue': true, 'count': 3},
      });
      expect(event, isNotNull);
      expect(event!.id, 'evt-1');
      expect(event.licenseOrgId, 'acme');
      expect(event.action, LicenseOrgAuditAction.memberJoined);
      expect(event.targetKind, LicenseOrgAuditTargetKind.licenseOrgMembership);
      expect(event.targetId, 'user-abc');
      expect(event.actorUid, 'admin-uid-1');
      expect(event.actorRole, LicenseOrgAuditActorRole.admin);
      expect(event.outcome, LicenseOrgAuditOutcome.success);
      expect(event.reasonCode, isNull);
      expect(event.tsServer, ts.toDate().toUtc());
      expect(event.metadata, {'reissue': true, 'count': 3});
    });

    test('returns null on null map', () {
      expect(LicenseOrgAuditEvent.fromMap('evt-1', null), isNull);
    });

    test('returns null when licenseOrgId is missing', () {
      expect(
        LicenseOrgAuditEvent.fromMap('evt-1', {
          'action': 'member_joined',
          'actorUid': 'admin',
        }),
        isNull,
      );
    });

    test('returns null when licenseOrgId is empty', () {
      expect(
        LicenseOrgAuditEvent.fromMap('evt-1', {
          'licenseOrgId': '',
          'action': 'member_joined',
        }),
        isNull,
      );
    });

    test('returns null when action is missing', () {
      expect(
        LicenseOrgAuditEvent.fromMap('evt-1', {'licenseOrgId': 'acme'}),
        isNull,
      );
    });

    test('unknown action wire string collapses to action == unknown', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'a_future_action_v2',
        'outcome': 'success',
      });
      expect(event, isNotNull);
      expect(event!.action, LicenseOrgAuditAction.unknown);
    });

    test('unknown actorRole / targetKind / outcome collapse to unknown', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'targetKind': 'a_future_target_kind',
        'actorRole': 'a_future_role',
        'outcome': 'a_future_outcome',
      });
      expect(event, isNotNull);
      expect(event!.targetKind, LicenseOrgAuditTargetKind.unknown);
      expect(event.actorRole, LicenseOrgAuditActorRole.unknown);
      expect(event.outcome, LicenseOrgAuditOutcome.unknown);
    });

    test('parses tsServer from ISO 8601 string', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'tsServer': '2026-05-26T12:34:56.000Z',
      });
      expect(event, isNotNull);
      expect(event!.tsServer, DateTime.utc(2026, 5, 26, 12, 34, 56));
    });

    test('leaves tsServer null when the field is the wrong type', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'tsServer': 1234,
      });
      expect(event, isNotNull);
      expect(event!.tsServer, isNull);
    });

    test('empty reasonCode collapses to null', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'outcome': 'rejected',
        'reasonCode': '',
      });
      expect(event!.reasonCode, isNull);
    });

    test('non-string reasonCode collapses to null', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'reasonCode': 42,
      });
      expect(event!.reasonCode, isNull);
    });

    test('empty targetId collapses to null', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'targetId': '',
      });
      expect(event!.targetId, isNull);
    });

    test('metadata is unmodifiable', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'metadata': const {'a': 1, 'b': true},
      });
      expect(event!.metadata, {'a': 1, 'b': true});
      expect(() => event.metadata['c'] = 3, throwsA(isA<UnsupportedError>()));
    });

    test('missing metadata yields an empty unmodifiable map', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
      });
      expect(event!.metadata, isEmpty);
      expect(() => event.metadata['x'] = 1, throwsA(isA<UnsupportedError>()));
    });

    test('non-string metadata keys are filtered out', () {
      final event = LicenseOrgAuditEvent.fromMap('evt-1', {
        'licenseOrgId': 'acme',
        'action': 'member_joined',
        'metadata': const {'a': 1, 42: 'numeric-key-dropped'},
      });
      expect(event!.metadata, {'a': 1});
    });
  });

  group('actorDisplayLabel', () {
    LicenseOrgAuditEvent build({
      required String actorUid,
      LicenseOrgAuditActorRole role = LicenseOrgAuditActorRole.admin,
    }) => LicenseOrgAuditEvent(
      id: 'e',
      licenseOrgId: 'acme',
      action: LicenseOrgAuditAction.memberJoined,
      targetKind: LicenseOrgAuditTargetKind.licenseOrgMembership,
      targetId: null,
      actorUid: actorUid,
      actorRole: role,
      outcome: LicenseOrgAuditOutcome.success,
      reasonCode: null,
      tsServer: null,
      metadata: const {},
    );

    test('renders the first 6 chars of the uid uppercased', () {
      final e = build(actorUid: 'abcdef123456');
      expect(e.actorDisplayLabel, '#ABCDEF');
    });

    test('returns "system" verbatim for the system actor role', () {
      final e = build(
        actorUid: 'cloud-function',
        role: LicenseOrgAuditActorRole.system,
      );
      expect(e.actorDisplayLabel, 'system');
    });

    test('falls back to #?????? when actorUid is empty', () {
      final e = build(actorUid: '');
      expect(e.actorDisplayLabel, '#??????');
    });

    test('handles a short uid without padding', () {
      final e = build(actorUid: 'ab');
      expect(e.actorDisplayLabel, '#AB');
    });
  });
}
