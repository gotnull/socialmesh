// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Parser + router tests for socialmesh://purchase-return?sessionId=…
// links. The actual side-effect (firing into ExternalPurchaseService)
// is exercised in external_purchase_service_test.dart; here we just
// validate that the parser identifies the link, extracts the sessionId,
// and the router produces a no-op route that carries the sessionId in
// arguments for the manager to dispatch on.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/deep_link/deep_link_parser.dart';
import 'package:socialmesh/services/deep_link/deep_link_router.dart';
import 'package:socialmesh/services/deep_link/deep_link_types.dart';

void main() {
  const parser = DeepLinkParser();
  const router = DeepLinkRouter();

  group('parser', () {
    test('socialmesh://purchase-return?sessionId=XYZ parses correctly', () {
      final link = parser.parse(
        'socialmesh://purchase-return?sessionId=abc-123',
      );
      expect(link.type, DeepLinkType.purchaseReturn);
      expect(link.isValid, isTrue);
      expect(link.purchaseSessionId, 'abc-123');
      expect(link.hasPurchaseSessionId, isTrue);
    });

    test('missing sessionId fails validation', () {
      final link = parser.parse('socialmesh://purchase-return');
      expect(link.isValid, isFalse);
      expect(link.validationErrors, isNotEmpty);
    });

    test('empty sessionId fails validation', () {
      final link = parser.parse('socialmesh://purchase-return?sessionId=');
      expect(link.isValid, isFalse);
    });

    test('extra unrelated query params do not interfere', () {
      // The redirect URL may pick up tracking params from BMC.
      final link = parser.parse(
        'socialmesh://purchase-return?utm_source=bmc&sessionId=abc-123&utm_medium=email',
      );
      expect(link.type, DeepLinkType.purchaseReturn);
      expect(link.purchaseSessionId, 'abc-123');
    });
  });

  group('router', () {
    test('valid purchase-return routes to /main with sessionId in args', () {
      final link = parser.parse(
        'socialmesh://purchase-return?sessionId=abc-123',
      );
      final result = router.route(link);
      expect(result.routeName, '/main');
      expect(result.arguments?['purchaseSessionId'], 'abc-123');
      expect(result.requiresDevice, isFalse);
      expect(result.requiresAuth, isFalse);
    });

    test('invalid purchase-return falls back to /main with no args', () {
      final link = parser.parse('socialmesh://purchase-return');
      final result = router.route(link);
      expect(result.routeName, '/main');
      // Either no args or no purchaseSessionId — either way the
      // manager must NOT dispatch into ExternalPurchaseService.
      expect(
        result.arguments == null ||
            result.arguments!['purchaseSessionId'] == null,
        isTrue,
      );
    });
  });
}
