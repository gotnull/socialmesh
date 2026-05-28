// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Source-text regressions for [ConfirmingUnlockOverlay] — specifically
// the post-purchase "View your group" CTA that ties the Stripe
// confirmation success state to the License Org Overview screen's
// card-level auto-prompt.
//
// Why source-text: a live widget test would need a fake CallableInvoker
// PLUS a fake authStateProvider PLUS a fake currentUserLicenseOrgIdsProvider
// PLUS a fake licenseOrgProvider, then drive a fake ConfirmationState
// through stages. That is fragile and the surface area is small —
// pin the gating invariants here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    src = File(
      'lib/features/external_purchase/confirming_unlock_overlay.dart',
    ).readAsStringSync();
  });

  group('_Success — post-purchase rename CTA', () {
    test('is a ConsumerWidget (needs ref.watch on org providers)', () {
      // The CTA depends on currentUserLicenseOrgIdsProvider +
      // licenseOrgProvider — both Riverpod providers. _Success must
      // be a ConsumerWidget for `ref.watch` to be in scope.
      expect(src, contains('class _Success extends ConsumerWidget'));
    });

    test('gates on caller being a signed-in non-anonymous user with a uid', () {
      // A guest or signed-out buyer cannot own an org, so the CTA
      // would never apply. The gate also avoids surfacing a CTA on
      // the redeem-unlock-code path where the buyer is anon.
      expect(src, contains('user == null'));
      expect(src, contains('user.isAnonymous'));
      expect(src, contains('user.uid.isEmpty'));
    });

    test('only fires when user OWNS at least one unnamed org', () {
      // The CTA must check ownerUid == user.uid (not just membership)
      // and skip orgs that already have a name (so revisiting after
      // a previous rename does not nag).
      expect(src, contains('org.ownerUid != user.uid'));
      expect(src, contains('org.name.isNotEmpty'));
    });

    test(
      'navigates via the global navigatorKey, not Navigator.of(context)',
      () {
        // The overlay sits inside MaterialApp.builder as a Stack
        // sibling of the Navigator subtree — `Navigator.of(context)`
        // and `Navigator.of(context, rootNavigator: true)` both fail
        // because there is no Navigator ancestor above the overlay.
        // The CTA must use the global `navigatorKey.currentState`
        // bound on the MaterialApp in main.dart.
        expect(src, contains("import '../../core/navigation.dart'"));
        expect(src, contains('navigatorKey.currentState'));
        expect(src, contains('LicenseOrgOverviewScreen.route()'));
      },
    );

    test('CTA captures navigatorKey BEFORE onDismiss + pushes AFTER', () {
      // Regression for Crashlytics 0fac5378d7a21235e2599d2fed6cc415,
      // FATAL on iOS 26.5.0 (1.43.0 #182), 2026-05-28: dismissing
      // first unmounts the overlay and tears down the build context;
      // a navigator captured AFTER dismiss is then disposed and the
      // push silently no-ops. Capture nav FIRST, then dismiss, then
      // push on the captured reference.
      final ctaIdx = src.indexOf('unlockSuccessOrgPackCta');
      final onPressedIdx = src.lastIndexOf('onPressed: () {', ctaIdx);
      expect(onPressedIdx, greaterThan(-1));
      final body = src.substring(onPressedIdx, ctaIdx + 400);
      final captureIdx = body.indexOf('navigatorKey.currentState');
      final dismissIdx = body.indexOf('onDismiss();');
      final pushIdx = body.indexOf('nav?.push');
      expect(captureIdx, greaterThan(-1));
      expect(dismissIdx, greaterThan(captureIdx));
      expect(pushIdx, greaterThan(dismissIdx));
    });

    test('falls back to plain Dismiss when no unnamed org exists', () {
      // Personal-pack buyers, members redeeming via invite, or
      // owners who already named everything — none should see the
      // CTA. The fallback branch renders just the Dismiss button.
      // The if/spread + else collection-if compiles to `] else`
      // (NOT `} else`) because the truthy branch is a list spread.
      expect(src, contains('if (unnamedOrgId != null)'));
      expect(src, contains('] else'));
    });
  });
}
