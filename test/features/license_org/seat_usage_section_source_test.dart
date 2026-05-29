// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Source-text regressions for the Phase 2 Seat Usage section + the
// shared-widget extraction. Live widget tests would need a fake
// Cloud Functions invoker, a stubbed presence-derived
// `licenseOrgSeatUtilizationProvider`, and a hand-built
// ProviderScope override matrix — fragile for the small surface
// area. Pinning the load-bearing invariants by text is the right
// trade-off: layout placement, role gating, provider invalidation
// on revoke success, idle-highlight threshold, error-state fallback.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String cardSrc;
  late String serviceSrc;
  late String providerSrc;
  late String labelHelperSrc;
  late String revokeSheetSrc;
  late String membersSheetSrc;

  setUpAll(() {
    cardSrc = File(
      'lib/features/license_org/license_org_overview_card.dart',
    ).readAsStringSync();
    serviceSrc = File(
      'lib/services/license_org/license_org_seat_service.dart',
    ).readAsStringSync();
    providerSrc = File(
      'lib/providers/license_org_seat_utilization_providers.dart',
    ).readAsStringSync();
    labelHelperSrc = File(
      'lib/features/license_org/utils/member_label.dart',
    ).readAsStringSync();
    revokeSheetSrc = File(
      'lib/features/license_org/widgets/revoke_seat_confirm_sheet.dart',
    ).readAsStringSync();
    membersSheetSrc = File(
      'lib/features/license_org/license_org_members_sheet.dart',
    ).readAsStringSync();
  });

  group('Shared-widget extraction', () {
    test('licenseOrgMemberLabel exported from utils/member_label.dart', () {
      expect(
        labelHelperSrc,
        contains('String licenseOrgMemberLabel(String uid)'),
      );
      expect(
        labelHelperSrc,
        contains('String licenseOrgUidFromAllocationId(String allocationId)'),
      );
    });

    test('RevokeSeatConfirmSheet exported from widgets/', () {
      expect(
        revokeSheetSrc,
        contains('class RevokeSeatConfirmSheet extends StatelessWidget'),
      );
      // Pops bool — the action-then-confirm pattern callers depend on.
      expect(revokeSheetSrc, contains('Navigator.of(context).pop(true)'));
      expect(revokeSheetSrc, contains('Navigator.of(context).pop(false)'));
    });

    test('Members sheet uses the extracted helpers (no in-file dupes)', () {
      // Local _RevokeConfirmSheet + _labelForUid would defeat the
      // extraction. Pin that the members sheet imports the shared
      // versions and contains no private duplicates.
      expect(membersSheetSrc, contains("import 'utils/member_label.dart'"));
      expect(
        membersSheetSrc,
        contains("import 'widgets/revoke_seat_confirm_sheet.dart'"),
      );
      expect(membersSheetSrc, isNot(contains('class _RevokeConfirmSheet')));
      expect(membersSheetSrc, isNot(contains('String _labelForUid(')));
      expect(membersSheetSrc, isNot(contains('String _uidFromAllocationId(')));
    });
  });

  group('LicenseOrgSeatService.getSeatUtilization', () {
    test('callable name matches the Phase 1 backend export', () {
      expect(
        serviceSrc,
        contains("_invoker.call('getLicenseOrgSeatUtilization'"),
      );
    });

    test('SeatUtilizationMember.fromMap parses every wire field', () {
      // Defensive: a refactor that drops a field would silently
      // surface as `null` in the UI without this pin.
      expect(serviceSrc, contains("allocationId: m['allocationId'] as String"));
      expect(serviceSrc, contains("uid: m['uid'] as String"));
      expect(serviceSrc, contains("role: m['role'] as String? ?? 'unknown'"));
      expect(serviceSrc, contains("productId: m['productId'] as String"));
      expect(
        serviceSrc,
        contains("DateTime.parse(m['seatAllocatedAt'] as String)"),
      );
      expect(serviceSrc, contains("(m['daysIdle'] as num?)?.toInt()"));
    });

    test('GetSeatUtilizationFailure carries the backend message verbatim', () {
      expect(
        serviceSrc,
        contains('GetSeatUtilizationFailure(message: e.message ?? e.code)'),
      );
    });
  });

  group('licenseOrgSeatUtilizationProvider', () {
    test('AsyncNotifier.family keyed by orgId', () {
      expect(
        providerSrc,
        contains(
          'class LicenseOrgSeatUtilizationNotifier\n'
          '    extends AsyncNotifier<LicenseOrgSeatUtilizationState>',
        ),
      );
      expect(
        providerSrc,
        contains(
          'AsyncNotifierProvider.family<\n'
          '      LicenseOrgSeatUtilizationNotifier,\n'
          '      LicenseOrgSeatUtilizationState,\n'
          '      String\n'
          '    >(LicenseOrgSeatUtilizationNotifier.new)',
        ),
      );
    });

    test('feature-flag gated + empty-orgId early return', () {
      expect(
        providerSrc,
        contains('if (!AppFeatureFlags.isGroupLicensingEnabled)'),
      );
      expect(providerSrc, contains('if (orgId.isEmpty)'));
    });

    test(
      'failure state collapses to LicenseOrgSeatUtilizationState.failure',
      () {
        // The notifier never throws on a Cloud Functions failure; it
        // returns the sentinel state and the UI renders the inline
        // error banner. A regression that lets the failure throw
        // would surface a Riverpod error boundary instead of the
        // designed-for empty/error chrome.
        expect(providerSrc, contains('GetSeatUtilizationFailure f =>'));
        expect(providerSrc, contains('LicenseOrgSeatUtilizationState.failure'));
      },
    );
  });

  group('_SeatUsageSection layout + behavior', () {
    test('rendered between InfoTable and _RecentActivitySection', () {
      // Layout placement is load-bearing — admins expect the
      // utilization data above the audit trail. Pin the order of
      // the three widgets in the build() body.
      final infoTableIdx = cardSrc.indexOf('InfoTable(');
      final seatUsageIdx = cardSrc.indexOf('_SeatUsageSection(orgId: orgId)');
      final recentActivityIdx = cardSrc.indexOf(
        '_RecentActivitySection(orgId: orgId)',
      );
      expect(infoTableIdx, greaterThan(-1));
      expect(seatUsageIdx, greaterThan(infoTableIdx));
      expect(recentActivityIdx, greaterThan(seatUsageIdx));
    });

    test('owner / admin only — gated by role at the call site', () {
      // Member role doesn't see the section AT ALL (the callable
      // would reject the read anyway). Pin the gate so a later
      // refactor doesn't accidentally surface a useless loading
      // spinner to members.
      final seatUsageIdx = cardSrc.indexOf('_SeatUsageSection(orgId: orgId)');
      final body = cardSrc.substring(
        cardSrc.lastIndexOf('if (status == LicenseOrgStatus.active)'),
        seatUsageIdx,
      );
      expect(body, contains('role == LicenseOrgMemberRole.owner'));
      expect(body, contains('role == LicenseOrgMemberRole.admin'));
    });

    test('30-day idle threshold drives the highlight color', () {
      expect(cardSrc, contains('_idleHighlightDays = 30'));
      expect(cardSrc, contains('AppTheme.errorRed'));
    });

    test('three last-active states render distinct copy', () {
      // Pin the three ARB keys so a refactor that collapses them
      // (e.g. into a single nullable plural) surfaces here.
      expect(cardSrc, contains('licenseOrgSeatUsageNeverSignedIn'));
      expect(cardSrc, contains('licenseOrgSeatUsageActiveToday'));
      expect(cardSrc, contains('licenseOrgSeatUsageIdleDays'));
    });

    test('revoke success invalidates the seat-utilization provider', () {
      // Without invalidate the section keeps showing the revoked
      // member until the screen is re-entered. Pin the call so a
      // refactor (e.g. switching to a manual `ref.refresh`) keeps
      // the contract.
      final revokeIdx = cardSrc.indexOf('case RevokeSeatSuccess');
      expect(revokeIdx, greaterThan(-1));
      final body = cardSrc.substring(revokeIdx, revokeIdx + 600);
      expect(
        body,
        contains(
          'ref.invalidate(licenseOrgSeatUtilizationProvider(widget.orgId))',
        ),
      );
    });

    test(
      'error state renders StatusBanner.error, NOT a hand-rolled container',
      () {
        // The "no hand-rolled error containers" rule from the
        // visual-audit playbook applies — pin the canonical primitive.
        final errorBuildIdx = cardSrc.indexOf('Widget _buildError(');
        expect(errorBuildIdx, greaterThan(-1));
        final body = cardSrc.substring(errorBuildIdx, errorBuildIdx + 600);
        expect(body, contains('StatusBanner.error'));
        expect(body, contains('licenseOrgSeatUsageLoadError'));
      },
    );
  });
}
