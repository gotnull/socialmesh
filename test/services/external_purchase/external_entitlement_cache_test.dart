// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/seat_allocation.dart';
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
    OwnerKind ownerKind = OwnerKind.user,
    String? orgId,
  }) {
    final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
    return ExternalEntitlement(
      productId: productId,
      status: status,
      provider: provider,
      grantedAt: ts,
      lastVerifiedAt: ts,
      sessionId: sessionId,
      ownerKind: ownerKind,
      orgId: orgId,
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

    test('write replaces - not appends', () async {
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

  group('ownership filtering', () {
    test('org-owned active rows are excluded from activeProductIds', () async {
      // Group/community licensing groundwork: org-owned rows must NOT
      // unlock features for the current user until a membership / seat
      // model exists. The cache is the boundary that enforces this -
      // the downstream provider merge is intentionally ownership-blind.
      await cache.write([
        entitlement('theme_pack'), // user-owned, active
        entitlement(
          'widget_pack',
          ownerKind: OwnerKind.org,
          orgId: 'acme-eng-team',
        ),
      ]);
      expect(
        cache.activeProductIds(),
        {'theme_pack'},
        reason: 'org-owned rows must not appear in the gate-feeding set',
      );
    });

    test('org-owned rows still round-trip through read/write', () async {
      // Filtering only happens at the gate-feeding step. The raw cache
      // contents must survive a write/read cycle so a future
      // membership layer can admit them without needing a backend
      // re-fetch.
      final orgRow = entitlement(
        'widget_pack',
        ownerKind: OwnerKind.org,
        orgId: 'acme-eng-team',
      );
      await cache.write([entitlement('theme_pack'), orgRow]);
      final readBack = cache.read();
      expect(readBack, hasLength(2));
      final orgInCache = readBack.firstWhere(
        (e) => e.productId == 'widget_pack',
      );
      expect(orgInCache.ownerKind, OwnerKind.org);
      expect(orgInCache.orgId, 'acme-eng-team');
    });

    test('org-owned cache entries do not crash on read', () async {
      // Belt and braces: an offline cache populated by a future
      // backend deploy that happens to land on a build that pre-dates
      // org awareness would crash here if the parser were strict.
      // Verify a raw JSON write with the org shape decodes cleanly.
      await prefs.setString(
        'external_purchase.entitlements_cache',
        '[{"productId":"widget_pack","status":"active","provider":"stripe",'
            '"grantedAt":"2026-05-05T10:00:00.000Z",'
            '"lastVerifiedAt":"2026-05-05T10:00:00.000Z",'
            '"sessionId":null,"subjectKind":"org","orgId":"acme-eng-team"}]',
      );
      final readBack = cache.read();
      expect(readBack, hasLength(1));
      expect(readBack.single.ownerKind, OwnerKind.org);
      expect(readBack.single.orgId, 'acme-eng-team');
      expect(cache.activeProductIds(), isEmpty);
    });

    test('legacy cache entries (no subjectKind) default to user-owned', () async {
      // Belt and braces: a cache populated by an older app version
      // had no `subjectKind` or `orgId` keys. After the upgrade, those
      // entries must still grant access exactly as before.
      await prefs.setString(
        'external_purchase.entitlements_cache',
        '[{"productId":"theme_pack","status":"active","provider":"buymeacoffee",'
            '"grantedAt":"2026-05-05T10:00:00.000Z",'
            '"lastVerifiedAt":"2026-05-05T10:00:00.000Z",'
            '"sessionId":"sess-1"}]',
      );
      final readBack = cache.read();
      expect(readBack, hasLength(1));
      expect(readBack.single.ownerKind, OwnerKind.user);
      expect(readBack.single.orgId, isNull);
      expect(cache.activeProductIds(), {'theme_pack'});
    });

    test(
      'mixed user + org + revoked: activeProductIds returns only active user',
      () async {
        await cache.write([
          entitlement('theme_pack'),
          entitlement(
            'ringtone_pack',
            status: ExternalEntitlementStatus.revoked,
          ),
          entitlement(
            'widget_pack',
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
          entitlement(
            'automations_pack',
            status: ExternalEntitlementStatus.revoked,
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
        ]);
        expect(cache.activeProductIds(), {'theme_pack'});
      },
    );
  });

  group('ownership filtering with org + seat context', () {
    // These tests pin the slice-3 contract on
    // `cache.activeProductIds(ownedOrgIds:, ownedSeats:)`:
    //
    //   - user-owned rows admit regardless of org/seat context
    //   - org-owned rows admit ONLY when membership AND seat both match
    //   - missing either side keeps the org row excluded
    //   - revoked org rows never admit
    //   - org rows with null/empty orgId never admit, even with a
    //     matching seat
    const orgId = 'acme-eng-team';
    const widgetSeat = SeatAllocationRef(
      orgId: orgId,
      productId: 'widget_pack',
    );

    test('membership + matching seat unlocks the org-owned row', () async {
      await cache.write([
        entitlement('widget_pack', ownerKind: OwnerKind.org, orgId: orgId),
      ]);
      expect(
        cache.activeProductIds(ownedOrgIds: {orgId}, ownedSeats: {widgetSeat}),
        {'widget_pack'},
      );
    });

    test('membership without seat keeps the org row excluded', () async {
      await cache.write([
        entitlement('widget_pack', ownerKind: OwnerKind.org, orgId: orgId),
      ]);
      expect(
        cache.activeProductIds(ownedOrgIds: {orgId}),
        isEmpty,
        reason: 'membership alone must not unlock org-owned entitlements',
      );
    });

    test('seat without membership keeps the org row excluded', () async {
      // Stale seat for an org the user has been removed from: a future
      // admin surface should revoke the seat too, but defence in depth
      // is the rule here. Removing membership is sufficient to lock
      // the entitlement.
      await cache.write([
        entitlement('widget_pack', ownerKind: OwnerKind.org, orgId: orgId),
      ]);
      expect(cache.activeProductIds(ownedSeats: {widgetSeat}), isEmpty);
    });

    test('seat for a different product does not unlock', () async {
      const themeSeat = SeatAllocationRef(
        orgId: orgId,
        productId: 'theme_pack',
      );
      await cache.write([
        entitlement('widget_pack', ownerKind: OwnerKind.org, orgId: orgId),
      ]);
      expect(
        cache.activeProductIds(ownedOrgIds: {orgId}, ownedSeats: {themeSeat}),
        isEmpty,
      );
    });

    test('seat for a different org does not unlock', () async {
      const otherOrgSeat = SeatAllocationRef(
        orgId: 'beta-club',
        productId: 'widget_pack',
      );
      await cache.write([
        entitlement('widget_pack', ownerKind: OwnerKind.org, orgId: orgId),
      ]);
      expect(
        cache.activeProductIds(
          ownedOrgIds: {orgId, 'beta-club'},
          ownedSeats: {otherOrgSeat},
        ),
        isEmpty,
      );
    });

    test(
      'revoked org row does not unlock even with membership + seat',
      () async {
        await cache.write([
          entitlement(
            'widget_pack',
            status: ExternalEntitlementStatus.revoked,
            ownerKind: OwnerKind.org,
            orgId: orgId,
          ),
        ]);
        expect(
          cache.activeProductIds(
            ownedOrgIds: {orgId},
            ownedSeats: {widgetSeat},
          ),
          isEmpty,
        );
      },
    );

    test(
      'slice 5b post-cascade: revoked entitlement + empty seat set locks',
      () async {
        // After the slice-5b backend cascade fires, the entitlement is
        // revoked AND the seat allocation is revoked. The provider
        // layer's currentUserSeatAllocationsProvider filters to
        // active-only seats, so the cache filter sees an empty
        // ownedSeats set. This pins that the cache still locks even
        // when the cascade has fully drained both layers.
        await cache.write([
          entitlement(
            'widget_pack',
            status: ExternalEntitlementStatus.revoked,
            ownerKind: OwnerKind.org,
            orgId: orgId,
          ),
        ]);
        // Active membership remains (membership doc is not cascaded by
        // slice 5b - org owner / admin tooling manages that
        // separately). Seats arrive as empty because the cascade
        // flipped them and the provider filters to active.
        expect(
          cache.activeProductIds(
            ownedOrgIds: {orgId},
            ownedSeats: const <SeatAllocationRef>{},
          ),
          isEmpty,
        );
      },
    );

    test('user-owned rows admit regardless of org/seat context', () async {
      await cache.write([
        entitlement('theme_pack'), // user-owned
      ]);
      // No context at all
      expect(cache.activeProductIds(), {'theme_pack'});
      // Wrong org context
      expect(cache.activeProductIds(ownedOrgIds: {'beta-club'}), {
        'theme_pack',
      });
    });

    test('mixed user + org rows: only matching org rows admit', () async {
      await cache.write([
        entitlement('theme_pack'),
        entitlement('widget_pack', ownerKind: OwnerKind.org, orgId: orgId),
        entitlement(
          'ringtone_pack',
          ownerKind: OwnerKind.org,
          orgId: 'beta-club',
        ),
      ]);
      expect(
        cache.activeProductIds(ownedOrgIds: {orgId}, ownedSeats: {widgetSeat}),
        {'theme_pack', 'widget_pack'},
        reason: 'beta-club row stays excluded - no membership or seat',
      );
    });

    test('org row with null orgId never admits', () async {
      // Defensive: a malformed cache entry where subjectKind=org but
      // orgId was lost must not match any seat by accident.
      await prefs.setString(
        'external_purchase.entitlements_cache',
        '[{"productId":"widget_pack","status":"active","provider":"stripe",'
            '"grantedAt":"2026-05-05T10:00:00.000Z",'
            '"lastVerifiedAt":"2026-05-05T10:00:00.000Z",'
            '"sessionId":null,"subjectKind":"org","orgId":null}]',
      );
      expect(
        cache.activeProductIds(ownedOrgIds: {orgId}, ownedSeats: {widgetSeat}),
        isEmpty,
      );
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
