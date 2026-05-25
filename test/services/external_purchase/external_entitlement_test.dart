// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';

void main() {
  group('ExternalEntitlement.fromJson', () {
    test('parses a legacy backend webhook payload (no ownership fields)', () {
      // Legacy backend deploys serialize the entitlement without
      // `subjectKind` or `orgId`. Those rows must continue to grant as
      // user-owned so existing customers don't lose access on the
      // build that adds the ownership axis.
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
      expect(
        e.ownerKind,
        OwnerKind.user,
        reason: 'legacy rows with no subjectKind default to user-owned',
      );
      expect(e.orgId, isNull);
    });

    test('Dart toJson round-trip preserves all fields (cache contract)', () {
      // toJson is the canonical Dart wire format used by the
      // SharedPreferences cache. It MUST emit every field defensively
      // so a cache read after a process restart reproduces the same
      // model object byte-for-byte.
      final e = ExternalEntitlement(
        productId: 'theme_pack',
        status: ExternalEntitlementStatus.active,
        provider: ExternalProvider.buymeacoffee,
        grantedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        lastVerifiedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        sessionId: 'abc-123',
      );
      final round = ExternalEntitlement.fromJson(e.toJson());
      expect(round, equals(e));
      expect(round.ownerKind, OwnerKind.user);
      expect(round.orgId, isNull);
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
      // app build catches up. Don't crash - surface as `unknown`.
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

  group('OwnerKind / ownership', () {
    Map<String, dynamic> baseJson() => {
      'productId': 'theme_pack',
      'status': 'active',
      'provider': 'stripe',
      'grantedAt': '2026-05-05T10:00:00.000Z',
      'lastVerifiedAt': '2026-05-05T10:00:00.000Z',
      'sessionId': 'sess-1',
    };

    test('explicit subjectKind=user parses as OwnerKind.user', () {
      final e = ExternalEntitlement.fromJson({
        ...baseJson(),
        'subjectKind': 'user',
        'orgId': null,
      });
      expect(e.ownerKind, OwnerKind.user);
      expect(e.orgId, isNull);
    });

    test('subjectKind=org with orgId parses as OwnerKind.org', () {
      final e = ExternalEntitlement.fromJson({
        ...baseJson(),
        'subjectKind': 'org',
        'orgId': 'acme-eng-team',
      });
      expect(e.ownerKind, OwnerKind.org);
      expect(e.orgId, 'acme-eng-team');
      expect(e.isActive, isTrue);
    });

    test('subjectKind=org without orgId still deserialises safely', () {
      // A malformed / partially-populated row from a future backend
      // bug must not crash the parse - the cache loader has to keep
      // making forward progress so user-owned rows are still readable.
      final e = ExternalEntitlement.fromJson({
        ...baseJson(),
        'subjectKind': 'org',
        'orgId': null,
      });
      expect(e.ownerKind, OwnerKind.org);
      expect(e.orgId, isNull);
    });

    test('unknown subjectKind defaults to OwnerKind.user (safe)', () {
      // Forward compatibility: if a future backend adds a third value
      // (e.g. 'team', 'household') the legacy build must not start
      // granting it as org-owned, which it would silently ignore.
      // Defaulting to user means "preserve current behaviour" until
      // the app build understands the new value.
      final e = ExternalEntitlement.fromJson({
        ...baseJson(),
        'subjectKind': 'something-new',
      });
      expect(e.ownerKind, OwnerKind.user);
    });

    test('toJson emits subjectKind + orgId on every row', () {
      final user = ExternalEntitlement(
        productId: 'theme_pack',
        status: ExternalEntitlementStatus.active,
        provider: ExternalProvider.stripe,
        grantedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        lastVerifiedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        sessionId: 'sess-1',
      );
      expect(user.toJson()['subjectKind'], 'user');
      expect(user.toJson()['orgId'], isNull);

      final org = user.copyWith(
        ownerKind: OwnerKind.org,
        orgId: 'acme-eng-team',
      );
      expect(org.toJson()['subjectKind'], 'org');
      expect(org.toJson()['orgId'], 'acme-eng-team');
    });

    test('equality and hashCode include ownerKind + orgId', () {
      final a = ExternalEntitlement(
        productId: 'theme_pack',
        status: ExternalEntitlementStatus.active,
        provider: ExternalProvider.stripe,
        grantedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        lastVerifiedAt: DateTime.parse('2026-05-05T10:00:00.000Z'),
        sessionId: 'sess-1',
      );
      final b = a.copyWith(ownerKind: OwnerKind.org, orgId: 'acme-eng-team');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);

      final c = a.copyWith();
      expect(a, equals(c));
      expect(a.hashCode, c.hashCode);
    });

    test('OwnerKind.fromWire is null-safe and rejects nothing fatally', () {
      expect(OwnerKind.fromWire(null), OwnerKind.user);
      expect(OwnerKind.fromWire(''), OwnerKind.user);
      expect(OwnerKind.fromWire('user'), OwnerKind.user);
      expect(OwnerKind.fromWire('org'), OwnerKind.org);
      expect(OwnerKind.fromWire('USER'), OwnerKind.user); // case-strict
      expect(OwnerKind.fromWire('uid'), OwnerKind.user); // backend storage-key
      expect(
        OwnerKind.fromWire('install'),
        OwnerKind.user,
      ); // backend storage-key
    });
  });

  group('CheckoutSessionDescriptor.fromJson', () {
    test('parses a BMC payload (checkoutUrl + provider=buymeacoffee)', () {
      final d = CheckoutSessionDescriptor.fromJson({
        'sessionId': 'abc',
        'checkoutUrl': 'https://buymeacoffee.com/gotnull',
        'clientSecret': '',
        'paymentIntentId': '',
        'publishableKey': '',
        'returnDeepLink': 'socialmesh://purchase-return?sessionId=abc',
        'referenceCode': 'SM-AB23-CD45',
        'expectedAmount': 4.99,
        'currency': 'AUD',
        'expiresAt': '2026-05-05T11:00:00.000Z',
        'provider': 'buymeacoffee',
      });
      expect(d.sessionId, 'abc');
      expect(d.referenceCode, 'SM-AB23-CD45');
      expect(d.expectedAmount, 4.99);
      expect(d.currency, 'AUD');
      expect(d.provider, CheckoutProvider.buymeacoffee);
      expect(d.checkoutUrl, 'https://buymeacoffee.com/gotnull');
      expect(d.clientSecret, isEmpty);
    });

    test('parses a Stripe PaymentIntent payload', () {
      final d = CheckoutSessionDescriptor.fromJson({
        'sessionId': 'abc',
        'checkoutUrl': '',
        'clientSecret': 'pi_123_secret_xyz',
        'paymentIntentId': 'pi_123',
        'publishableKey': 'pk_test_abc',
        'returnDeepLink': 'socialmesh://purchase-return',
        'referenceCode': 'SM-AB23-CD45',
        'expectedAmount': 5.99,
        'currency': 'AUD',
        'expiresAt': '2026-05-15T11:00:00.000Z',
        'provider': 'stripe',
      });
      expect(d.provider, CheckoutProvider.stripe);
      expect(d.clientSecret, 'pi_123_secret_xyz');
      expect(d.paymentIntentId, 'pi_123');
      expect(d.publishableKey, 'pk_test_abc');
      expect(d.checkoutUrl, isEmpty);
    });

    test('missing provider field defaults to buymeacoffee', () {
      // Forward-compatibility with older backend deploys before Chunk C.
      final d = CheckoutSessionDescriptor.fromJson({
        'sessionId': 'abc',
        'checkoutUrl': 'https://buymeacoffee.com/gotnull',
        'returnDeepLink': 'socialmesh://purchase-return',
        'referenceCode': 'SM-AB23-CD45',
        'expectedAmount': 4.99,
        'currency': 'AUD',
        'expiresAt': '2026-05-05T11:00:00.000Z',
      });
      expect(d.provider, CheckoutProvider.buymeacoffee);
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
