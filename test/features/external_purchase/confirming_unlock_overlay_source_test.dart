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

    test('navigates via rootNavigator so the overlay can dismiss cleanly', () {
      // The overlay sits inside MaterialApp.builder; pushing onto
      // the nested Navigator would mount the License Org Overview
      // BELOW the overlay scrim. Use rootNavigator to push at the
      // top-most level.
      // Formatter sometimes breaks the call across lines; assert
      // the kw without baking in the surrounding whitespace.
      expect(src, contains('rootNavigator: true'));
      expect(src, contains('LicenseOrgOverviewScreen.route()'));
    });

    test('CTA fires onDismiss BEFORE navigating', () {
      // Without onDismiss, the service would still think there is a
      // pending confirmation to surface — a second deep link in the
      // same session would not re-trigger the overlay. Call dismiss
      // first, then push.
      final ctaIdx = src.indexOf('unlockSuccessOrgPackCta');
      final onPressedIdx = src.lastIndexOf('onPressed: () {', ctaIdx);
      expect(onPressedIdx, greaterThan(-1));
      final body = src.substring(onPressedIdx, ctaIdx + 200);
      final dismissIdx = body.indexOf('onDismiss();');
      final navIdx = body.indexOf('Navigator.of(');
      expect(dismissIdx, greaterThan(-1));
      expect(navIdx, greaterThan(dismissIdx));
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
