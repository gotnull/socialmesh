// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement_cache.dart';

void main() {
  late SharedPreferences prefs;
  late ExternalEntitlementCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cache = ExternalEntitlementCache(prefs);
  });

  ExternalEntitlement entitlement(
    String productId, {
    ExternalEntitlementStatus status = ExternalEntitlementStatus.active,
    ExternalProvider provider = ExternalProvider.buymeacoffee,
    String? sessionId = 'sess-123',
  }) {
    final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
    return ExternalEntitlement(
      productId: productId,
      status: status,
      provider: provider,
      grantedAt: ts,
      lastVerifiedAt: ts,
      sessionId: sessionId,
    );
  }

  group('read/write', () {
    test('empty cache returns empty list', () {
      expect(cache.read(), isEmpty);
      expect(cache.activeProductIds(), isEmpty);
    });

    test('write then read round-trips multiple entitlements', () async {
      final list = [entitlement('theme_pack'), entitlement('widget_pack')];
      await cache.write(list);
      final readBack = cache.read();
      expect(readBack, hasLength(2));
      expect(readBack.map((e) => e.productId).toSet(), {
        'theme_pack',
        'widget_pack',
      });
    });

    test('activeProductIds excludes revoked / expired entries', () async {
      await cache.write([
        entitlement('theme_pack'),
        entitlement('widget_pack', status: ExternalEntitlementStatus.revoked),
        entitlement('ringtone_pack', status: ExternalEntitlementStatus.expired),
      ]);
      expect(cache.activeProductIds(), {'theme_pack'});
    });

    test('write replaces — not appends', () async {
      // Webhook truth wins. If the backend says one entitlement is gone,
      // a stale row from a prior fetch must not linger.
      await cache.write([entitlement('theme_pack')]);
      await cache.write([entitlement('widget_pack')]);
      expect(cache.activeProductIds(), {'widget_pack'});
    });
  });

  group('lastRefreshedAt', () {
    test('null before any write', () {
      expect(cache.lastRefreshedAt(), isNull);
    });

    test('updates on each write', () async {
      await cache.write([entitlement('theme_pack')]);
      final first = cache.lastRefreshedAt();
      expect(first, isNotNull);

      await Future.delayed(const Duration(milliseconds: 10));
      await cache.write([entitlement('widget_pack')]);
      final second = cache.lastRefreshedAt();
      expect(
        second!.isAfter(first!),
        isTrue,
        reason: 'second write must record a later timestamp',
      );
    });
  });

  group('clear', () {
    test('clears entitlements and refresh timestamp', () async {
      await cache.write([entitlement('theme_pack')]);
      expect(cache.read(), isNotEmpty);
      expect(cache.lastRefreshedAt(), isNotNull);

      await cache.clear();
      expect(cache.read(), isEmpty);
      expect(cache.lastRefreshedAt(), isNull);
    });
  });

  group('corruption recovery', () {
    test('corrupted JSON blob is dropped silently', () async {
      // A SharedPreferences entry can survive an app update that
      // changes the model shape. Decode failure should clear the
      // bad blob, not poison every subsequent read.
      await prefs.setString(
        'external_purchase.entitlements_cache',
        '{not valid json',
      );
      expect(cache.read(), isEmpty);
      // Verify the bad blob was scrubbed.
      expect(prefs.getString('external_purchase.entitlements_cache'), isNull);
    });

    test('non-list JSON body is treated as empty', () async {
      await prefs.setString(
        'external_purchase.entitlements_cache',
        '{"oops": true}',
      );
      expect(cache.read(), isEmpty);
    });
  });
}
