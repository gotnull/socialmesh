// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Source-text regression tests for [InviteAcceptScreen].
//
// The redeem flow needs to kick the external-entitlement cache so the
// seat-based org packs flip from price labels to OWNED without an app
// restart. The membership + seat Firestore snapshots already
// invalidate the org / seat providers, but the entitlement docs only
// land in the local cache via the `getExternalEntitlements` callable
// — so a manual refresh is required immediately after a successful
// redeem. Without it the user sees confirmation but no premium
// unlock, which is exactly the "did it work?" anxiety we hit during
// the Community Pack e2e on 2026-05-28.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    src = File(
      'lib/features/license_org/invite_accept_screen.dart',
    ).readAsStringSync();
  });

  group('InviteAcceptScreen — refresh-on-redeem', () {
    test('imports refreshExternalEntitlements from the provider graph', () {
      expect(
        src,
        contains("import '../../providers/external_purchase_providers.dart';"),
      );
    });

    test('calls refreshExternalEntitlements(ref) on AcceptInviteSuccess', () {
      // Find the success branch and assert the refresh call lives
      // INSIDE it. We bound the search to the success-case body so a
      // refresh call that drifted into the failure branch (or top of
      // _onAccept before the await) would not satisfy this contract.
      final successIdx = src.indexOf('case AcceptInviteSuccess(');
      expect(successIdx, greaterThan(-1), reason: 'success branch missing');
      final failureIdx = src.indexOf('case AcceptInviteFailure(', successIdx);
      expect(failureIdx, greaterThan(successIdx));
      final successBody = src.substring(successIdx, failureIdx);
      expect(
        successBody,
        contains('refreshExternalEntitlements(ref)'),
        reason:
            'refreshExternalEntitlements must fire inside the success branch',
      );
    });

    test('wraps the refresh in unawaited() so the UI does not block', () {
      // The snackbar + 1.8s hold + pop runs sequentially; the
      // refresh fires off in the background and the StreamProvider
      // re-derives when the callable lands.
      expect(src, contains('unawaited(refreshExternalEntitlements(ref))'));
      expect(src, contains("import 'dart:async';"));
    });
  });

  group('InviteAcceptScreen — alreadyAllocated UX branch', () {
    test('uses the alreadyMember copy when the backend reports replay', () {
      // The backend returns `alreadyAllocated: true` when the caller
      // already has an active seat (idempotent replay — a double-tap
      // or a stranger's invite-link to an existing member). A fresh
      // green "Joined" snackbar in that case is misleading; the user
      // could think they joined a new group. Branch on the flag.
      expect(
        src,
        contains('licenseOrgInviteAcceptAlreadyMember(licenseOrgId)'),
      );
      expect(src, contains('licenseOrgInviteAcceptSuccess(licenseOrgId)'));
    });

    test('downgrades haptic + snackbar tone for the replay branch', () {
      // A "nothing happened" replay should not feel like a state
      // change. Light haptic + info-coloured snackbar makes the
      // distinction tangible without inventing a new error state.
      expect(src, contains('HapticType.light'));
      expect(src, contains('HapticType.success'));
      expect(src, contains('SnackBarType.info'));
      expect(src, contains('SnackBarType.success'));
      // Ensure the branch keys on alreadyAllocated and not some
      // other flag (e.g. a stale "isReplay").
      expect(
        src,
        contains('alreadyAllocated ? HapticType.light : HapticType.success'),
      );
      expect(
        src,
        contains('alreadyAllocated ? SnackBarType.info : SnackBarType.success'),
      );
    });
  });
}
