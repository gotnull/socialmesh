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
}
