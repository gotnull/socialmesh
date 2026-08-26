// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// The Teams list state matrix.
//
// This is a pure function over the membership authority plus context,
// so the whole matrix is testable without a widget tree, a Firestore
// mock, or a clock. The invariant it exists to protect: only a RESOLVED
// membership answer may be rendered as "you belong to no organisations".

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/teams/application/teams_list_state.dart';
import 'package:socialmesh/services/org/license_org_membership_repository.dart';

LicenseOrgMembershipSetState _membership({
  required LicenseOrgMembershipResolution resolution,
  Set<String> orgIds = const <String>{},
}) => LicenseOrgMembershipSetState(orgIds: orgIds, resolution: resolution);

TeamsListState _derive({
  bool featureEnabled = true,
  bool hasDurableAccount = true,
  required LicenseOrgMembershipSetState membership,
  bool isOnline = true,
}) => deriveTeamsListState(
  featureEnabled: featureEnabled,
  hasDurableAccount: hasDurableAccount,
  membership: membership,
  isOnline: isOnline,
);

void main() {
  final pending = _membership(
    resolution: LicenseOrgMembershipResolution.pending,
  );
  final failed = _membership(resolution: LicenseOrgMembershipResolution.failed);
  final resolvedEmpty = _membership(
    resolution: LicenseOrgMembershipResolution.resolved,
  );
  final resolvedOne = _membership(
    resolution: LicenseOrgMembershipResolution.resolved,
    orgIds: const {'acme-team'},
  );
  final resolvedMany = _membership(
    resolution: LicenseOrgMembershipResolution.resolved,
    orgIds: const {'zulu-team', 'acme-team', 'mid-team'},
  );

  group('gates take precedence', () {
    test('feature disabled wins over everything', () {
      expect(
        _derive(featureEnabled: false, membership: resolvedMany),
        isA<TeamsDisabled>(),
      );
    });

    test('no durable account -> account treatment, never an org claim', () {
      // Covers signed out AND anonymous: both lack a uid that survives
      // a reinstall, which is what membership is keyed by.
      final state = _derive(
        hasDurableAccount: false,
        membership: resolvedEmpty,
      );
      expect(state, isA<TeamsAccountRequired>());
      expect(
        state,
        isNot(isA<TeamsEmpty>()),
        reason: 'a signed-out user must not be told they have no teams',
      );
    });

    test('account gate outranks a failed membership', () {
      expect(
        _derive(hasDurableAccount: false, membership: failed),
        isA<TeamsAccountRequired>(),
      );
    });
  });

  group('unresolved membership never claims emptiness', () {
    test('pending + online -> checking', () {
      expect(
        _derive(membership: pending, isOnline: true),
        isA<TeamsChecking>(),
      );
    });

    test('pending + offline -> explicit uncertainty', () {
      expect(
        _derive(membership: pending, isOnline: false),
        isA<TeamsOfflineUnknown>(),
      );
    });

    test('neither pending state is ever the empty state', () {
      for (final online in [true, false]) {
        final state = _derive(membership: pending, isOnline: online);
        expect(state, isNot(isA<TeamsEmpty>()));
        expect(state, isNot(isA<TeamsLoaded>()));
      }
    });
  });

  group('failed membership', () {
    test('failed -> unavailable, regardless of connectivity', () {
      for (final online in [true, false]) {
        expect(
          _derive(membership: failed, isOnline: online),
          isA<TeamsUnavailable>(),
          reason: 'a failure is terminal until retried, not a spinner',
        );
      }
    });

    test('a PARTIAL union is never rendered as a list', () {
      // The owner query succeeded and returned an org; the membership
      // query failed. The surviving half is a subset, so presenting it
      // as the list would assert a completeness we do not have.
      final partial = _membership(
        resolution: LicenseOrgMembershipResolution.failed,
        orgIds: const {'acme-team'},
      );
      final state = _derive(membership: partial);

      expect(state, isA<TeamsUnavailable>());
      expect(state, isNot(isA<TeamsLoaded>()));
      // The stronger guarantee is structural, not assertable here:
      // TeamsUnavailable declares no id field, so a widget has nothing
      // to render even by mistake. If someone ever adds ids to it, the
      // exhaustive switch in the screen is where that must be caught -
      // a toString() check would pass vacuously and prove nothing.
    });

    test('failed outranks emptiness reasoning', () {
      final failedEmpty = _membership(
        resolution: LicenseOrgMembershipResolution.failed,
      );
      expect(_derive(membership: failedEmpty), isA<TeamsUnavailable>());
    });
  });

  group('resolved membership', () {
    test('resolved + empty -> the confident empty state', () {
      expect(_derive(membership: resolvedEmpty), isA<TeamsEmpty>());
    });

    test('resolved + empty is empty even while offline', () {
      // Once we have an authoritative answer, connectivity is
      // irrelevant - we know.
      expect(
        _derive(membership: resolvedEmpty, isOnline: false),
        isA<TeamsEmpty>(),
      );
    });

    test('resolved + one org', () {
      final state = _derive(membership: resolvedOne);
      expect(state, isA<TeamsLoaded>());
      expect((state as TeamsLoaded).orgIds, ['acme-team']);
    });

    test('resolved + many orgs, in a stable order', () {
      final state = _derive(membership: resolvedMany) as TeamsLoaded;
      expect(state.orgIds, ['acme-team', 'mid-team', 'zulu-team']);
    });

    test('a resolved list renders offline too', () {
      final state = _derive(membership: resolvedMany, isOnline: false);
      expect(state, isA<TeamsLoaded>());
    });
  });

  group('connectivity is presentation context only', () {
    test('it never changes WHICH orgs are listed', () {
      final online = _derive(membership: resolvedMany, isOnline: true);
      final offline = _derive(membership: resolvedMany, isOnline: false);
      expect((online as TeamsLoaded).orgIds, (offline as TeamsLoaded).orgIds);
    });

    test('it only separates the two pending presentations', () {
      // Every non-pending resolution must be identical in type
      // regardless of connectivity.
      for (final membership in [failed, resolvedEmpty, resolvedMany]) {
        expect(
          _derive(membership: membership, isOnline: true).runtimeType,
          _derive(membership: membership, isOnline: false).runtimeType,
        );
      }
    });
  });
}
