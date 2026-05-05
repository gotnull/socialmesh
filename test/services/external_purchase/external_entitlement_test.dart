// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';

void main() {
  group('ExternalEntitlement.fromJson', () {
    test('round-trips a typical webhook-confirmed entitlement', () {
      final source = {
        'productId': 'theme_pack',
        'status': 'active',
        'provider': 'buymeacoffee',
        'grantedAt': '2026-05-05T10:00:00.000Z',
        'lastVerifiedAt': '2026-05-05T10:00:00.000Z',
        'sessionId': 'abc-123',
      };
      final e = ExternalEntitlement.fromJson(source);
      expect(e.productId, 'theme_pack');
      expect(e.status, ExternalEntitlementStatus.active);
      expect(e.provider, ExternalProvider.buymeacoffee);
      expect(e.sessionId, 'abc-123');
      expect(e.isActive, isTrue);
      expect(e.toJson(), source);
    });

    test('isActive is false for revoked / expired / unknown', () {
      DateTime t() => DateTime.parse('2026-05-05T10:00:00.000Z');
      const productId = 'theme_pack';
      for (final status in ExternalEntitlementStatus.values) {
        final e = ExternalEntitlement(
          productId: productId,
          status: status,
          provider: ExternalProvider.buymeacoffee,
          grantedAt: t(),
          lastVerifiedAt: t(),
        );
        expect(
          e.isActive,
          status == ExternalEntitlementStatus.active,
          reason: 'isActive must be true ONLY for status=active (got $status)',
        );
      }
    });

    test('unknown provider strings degrade gracefully', () {
      // Future provider rollouts might land in the cache before the
      // app build catches up. Don't crash — surface as `unknown`.
      final e = ExternalEntitlement.fromJson({
        'productId': 'theme_pack',
        'status': 'active',
        'provider': 'paypal',
        'grantedAt': '2026-05-05T10:00:00.000Z',
        'lastVerifiedAt': '2026-05-05T10:00:00.000Z',
        'sessionId': null,
      });
      expect(e.provider, ExternalProvider.unknown);
      expect(e.isActive, isTrue);
    });

    test('sessionId is optional', () {
      // Manual unlock-code redemptions have no sessionId.
      final e = ExternalEntitlement.fromJson({
        'productId': 'theme_pack',
        'status': 'active',
        'provider': 'manual',
        'grantedAt': '2026-05-05T10:00:00.000Z',
        'lastVerifiedAt': '2026-05-05T10:00:00.000Z',
        'sessionId': null,
      });
      expect(e.sessionId, isNull);
      expect(e.provider, ExternalProvider.manual);
    });
  });

  group('CheckoutSessionDescriptor.fromJson', () {
    test('parses everything the createExternalCheckout callable returns', () {
      final d = CheckoutSessionDescriptor.fromJson({
        'sessionId': 'abc',
        'checkoutUrl': 'https://buymeacoffee.com/gotnull',
        'returnDeepLink': 'socialmesh://purchase-return?sessionId=abc',
        'referenceCode': 'SM-AB23-CD45',
        'expectedAmount': 4.99,
        'currency': 'USD',
        'expiresAt': '2026-05-05T11:00:00.000Z',
      });
      expect(d.sessionId, 'abc');
      expect(d.referenceCode, 'SM-AB23-CD45');
      expect(d.expectedAmount, 4.99);
      expect(d.currency, 'USD');
    });
  });

  group('CheckoutStatus', () {
    test('isTerminal: paid, failed, expired terminate; pending does not', () {
      expect(CheckoutStatus.paid.isTerminal, isTrue);
      expect(CheckoutStatus.failed.isTerminal, isTrue);
      expect(CheckoutStatus.expired.isTerminal, isTrue);
      expect(CheckoutStatus.pending.isTerminal, isFalse);
      expect(CheckoutStatus.unknown.isTerminal, isFalse);
    });

    test('fromWire defaults to unknown for unrecognised strings', () {
      expect(CheckoutStatus.fromWire('foo'), CheckoutStatus.unknown);
      expect(CheckoutStatus.fromWire(null), CheckoutStatus.unknown);
    });
  });
}
