// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/whats_new/whats_new_registry.dart';
import 'package:socialmesh/providers/whats_new_providers.dart';

void main() {
  // ===========================================================================
  // WhatsNewItem
  // ===========================================================================

  group('WhatsNewItem', () {
    test('stores all required fields', () {
      const item = WhatsNewItem(
        id: 'test_feature',
        title: 'Test Feature',
        description: 'A brand new feature.',
        icon: Icons.star,
      );

      expect(item.id, 'test_feature');
      expect(item.title, 'Test Feature');
      expect(item.description, 'A brand new feature.');
      expect(item.icon, Icons.star);
    });

    test('optional fields default to null', () {
      const item = WhatsNewItem(
        id: 'minimal',
        title: 'Minimal',
        description: 'Desc',
        icon: Icons.info,
      );

      expect(item.iconColor, isNull);
      expect(item.deepLinkRoute, isNull);
      expect(item.helpTopicId, isNull);
      expect(item.badgeKey, isNull);
      expect(item.ctaLabel, isNull);
    });

    test('stores optional fields when provided', () {
      const item = WhatsNewItem(
        id: 'full',
        title: 'Full Item',
        description: 'Desc',
        icon: Icons.star,
        iconColor: Color(0xFFFF0000),
        deepLinkRoute: '/feature',
        helpTopicId: 'feature_help',
        badgeKey: 'feature',
        ctaLabel: 'Open Feature',
      );

      expect(item.iconColor, const Color(0xFFFF0000));
      expect(item.deepLinkRoute, '/feature');
      expect(item.helpTopicId, 'feature_help');
      expect(item.badgeKey, 'feature');
      expect(item.ctaLabel, 'Open Feature');
    });
  });

  // ===========================================================================
  // WhatsNewPayload
  // ===========================================================================

  group('WhatsNewPayload', () {
    test('stores version and headline', () {
      const payload = WhatsNewPayload(
        version: '1.0.0',
        headline: 'Welcome',
        items: [],
      );

      expect(payload.version, '1.0.0');
      expect(payload.headline, 'Welcome');
      expect(payload.subtitle, isNull);
      expect(payload.items, isEmpty);
    });

    test('badgeKeys returns set of all item badge keys', () {
      const payload = WhatsNewPayload(
        version: '2.0.0',
        headline: 'New',
        items: [
          WhatsNewItem(
            id: 'a',
            title: 'A',
            description: 'Desc',
            icon: Icons.star,
            badgeKey: 'feature_a',
          ),
          WhatsNewItem(
            id: 'b',
            title: 'B',
            description: 'Desc',
            icon: Icons.star,
            badgeKey: 'feature_b',
          ),
          WhatsNewItem(
            id: 'c',
            title: 'C',
            description: 'Desc',
            icon: Icons.star,
            // No badge key
          ),
        ],
      );

      final keys = payload.badgeKeys;
      expect(keys, {'feature_a', 'feature_b'});
      expect(keys, isNot(contains(null)));
    });

    test('badgeKeys returns empty set when no items have badge keys', () {
      const payload = WhatsNewPayload(
        version: '1.0.0',
        headline: 'Test',
        items: [
          WhatsNewItem(
            id: 'a',
            title: 'A',
            description: 'Desc',
            icon: Icons.star,
          ),
        ],
      );

      expect(payload.badgeKeys, isEmpty);
    });
  });

  // ===========================================================================
  // WhatsNewRegistry — allPayloads
  // ===========================================================================

  group('WhatsNewRegistry.allPayloads', () {
    test('returns at least one payload', () {
      expect(WhatsNewRegistry.allPayloads, isNotEmpty);
    });

    test('contains a payload for NodeDex at 1.13.0', () {
      final payload = WhatsNewRegistry.getPayload('1.13.0');
      expect(payload, isNotNull);
      expect(payload!.items.any((i) => i.id == 'nodedex_intro'), isTrue);
    });

    test('NodeDex item has correct configuration', () {
      final payload = WhatsNewRegistry.getPayload('1.13.0')!;
      final item = payload.items.firstWhere((i) => i.id == 'nodedex_intro');

      expect(item.title, 'NodeDex');
      expect(item.description, isNotEmpty);
      expect(item.deepLinkRoute, '/nodedex');
      expect(item.helpTopicId, 'nodedex_overview');
      expect(item.badgeKey, 'nodedex');
      expect(item.ctaLabel, 'Open NodeDex');
    });
  });

  // ===========================================================================
  // WhatsNewRegistry.getPayload
  // ===========================================================================

  group('WhatsNewRegistry.getPayload', () {
    test('returns payload for known version', () {
      final payload = WhatsNewRegistry.getPayload('1.13.0');
      expect(payload, isNotNull);
      expect(payload!.version, '1.13.0');
    });

    test('returns null for unknown version', () {
      expect(WhatsNewRegistry.getPayload('0.0.1'), isNull);
      expect(WhatsNewRegistry.getPayload('99.99.99'), isNull);
    });
  });

  // ===========================================================================
  // WhatsNewRegistry.getPendingPayload
  // ===========================================================================

  group('WhatsNewRegistry.getPendingPayload', () {
    test('returns payload when lastSeen is null (fresh install)', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: '1.13.0',
        lastSeenVersion: null,
      );

      expect(payload, isNotNull);
      expect(payload!.version, '1.13.0');
    });

    test('returns payload when lastSeen is older than payload', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: '1.13.0',
        lastSeenVersion: '1.1.0',
      );

      expect(payload, isNotNull);
      expect(payload!.version, '1.13.0');
    });

    test('returns null when lastSeen equals payload version', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: '1.13.0',
        lastSeenVersion: '1.13.0',
      );

      expect(payload, isNull);
    });

    test('returns null when lastSeen is newer than payload', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: '1.13.0',
        lastSeenVersion: '1.14.0',
      );

      expect(payload, isNull);
    });

    test('returns null when current version is older than all payloads', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: '0.8.0',
        lastSeenVersion: null,
      );

      // 0.8.0 < 0.9.0 (the earliest payload version), so payload should not be shown
      expect(payload, isNull);
    });

    test(
      'returns payload when current version is newer than payload (update catchup)',
      () {
        final payload = WhatsNewRegistry.getPendingPayload(
          currentVersion: '1.13.0',
          lastSeenVersion: '1.0.0',
        );

        // User updated from 1.0.0 to 1.13.0, should see the 1.13.0 payload
        expect(payload, isNotNull);
        expect(payload!.version, '1.13.0');
      },
    );

    test('returns null for invalid current version string', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: 'bad',
        lastSeenVersion: null,
      );

      expect(payload, isNull);
    });

    test('handles build metadata in version strings', () {
      final payload = WhatsNewRegistry.getPendingPayload(
        currentVersion: '1.13.0+103',
        lastSeenVersion: '1.1.0+50',
      );

      expect(payload, isNotNull);
      expect(payload!.version, '1.13.0');
    });
  });

  // ===========================================================================
  // WhatsNewRegistry.getUnseenBadgeKeys
  // ===========================================================================

  group('WhatsNewRegistry.getUnseenBadgeKeys', () {
    test('returns badge keys when lastSeen is null', () {
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '1.13.0',
        lastSeenVersion: null,
      );

      expect(keys, contains('nodedex'));
    });

    test('returns badge keys when lastSeen is older', () {
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '1.13.0',
        lastSeenVersion: '1.1.0',
      );

      expect(keys, contains('nodedex'));
    });

    test('returns empty set when lastSeen equals current', () {
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '1.13.0',
        lastSeenVersion: '1.13.0',
      );

      expect(keys, isEmpty);
    });

    test('returns empty set when lastSeen is newer', () {
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '1.13.0',
        lastSeenVersion: '2.0.0',
      );

      expect(keys, isEmpty);
    });

    test('returns empty set when current is older than all payloads', () {
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '0.8.0',
        lastSeenVersion: null,
      );

      expect(keys, isEmpty);
    });

    test('accumulates badge keys from multiple unseen payloads', () {
      // If the registry only has 1.13.0, this test verifies the accumulation
      // pattern works even with a single entry
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '2.0.0',
        lastSeenVersion: '1.0.0',
      );

      expect(keys, isNotEmpty);
      expect(keys, contains('nodedex'));
    });

    test('handles build metadata in version strings', () {
      final keys = WhatsNewRegistry.getUnseenBadgeKeys(
        currentVersion: '1.13.0+200',
        lastSeenVersion: '1.1.0+100',
      );

      expect(keys, contains('nodedex'));
    });
  });

  // ===========================================================================
  // WhatsNewState
  // ===========================================================================

  group('WhatsNewState', () {
    test('initial state has correct defaults', () {
      const state = WhatsNewState.initial;

      expect(state.pendingPayload, isNull);
      expect(state.unseenBadgeKeys, isEmpty);
      expect(state.shownThisSession, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.hasPending, isFalse);
    });

    test('hasPending returns true when payload is present', () {
      const payload = WhatsNewPayload(
        version: '1.0.0',
        headline: 'Test',
        items: [],
      );

      const state = WhatsNewState(pendingPayload: payload);
      expect(state.hasPending, isTrue);
    });

    test('isBadgeKeyUnseen returns true for keys in set', () {
      const state = WhatsNewState(
        unseenBadgeKeys: {'nodedex', 'other_feature'},
      );

      expect(state.isBadgeKeyUnseen('nodedex'), isTrue);
      expect(state.isBadgeKeyUnseen('other_feature'), isTrue);
      expect(state.isBadgeKeyUnseen('nonexistent'), isFalse);
    });

    test('hasUnseenBadgeKeys returns true when set is non-empty', () {
      const stateWithKeys = WhatsNewState(unseenBadgeKeys: {'nodedex'});
      expect(stateWithKeys.hasUnseenBadgeKeys, isTrue);

      const stateEmpty = WhatsNewState(unseenBadgeKeys: {});
      expect(stateEmpty.hasUnseenBadgeKeys, isFalse);

      const stateInitial = WhatsNewState.initial;
      expect(stateInitial.hasUnseenBadgeKeys, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      const payload = WhatsNewPayload(
        version: '1.0.0',
        headline: 'Test',
        items: [],
      );

      const original = WhatsNewState(
        pendingPayload: payload,
        unseenBadgeKeys: {'nodedex'},
        shownThisSession: false,
        isLoaded: true,
      );

      final modified = original.copyWith(shownThisSession: true);

      expect(modified.pendingPayload, payload);
      expect(modified.unseenBadgeKeys, {'nodedex'});
      expect(modified.shownThisSession, isTrue);
      expect(modified.isLoaded, isTrue);
    });

    test('copyWith clearPendingPayload removes payload', () {
      const payload = WhatsNewPayload(
        version: '1.0.0',
        headline: 'Test',
        items: [],
      );

      const state = WhatsNewState(pendingPayload: payload);
      final cleared = state.copyWith(clearPendingPayload: true);

      expect(cleared.pendingPayload, isNull);
      expect(cleared.hasPending, isFalse);
    });

    test('copyWith can replace unseenBadgeKeys with empty set', () {
      const state = WhatsNewState(unseenBadgeKeys: {'nodedex', 'feature_b'});

      final cleared = state.copyWith(unseenBadgeKeys: const {});
      expect(cleared.unseenBadgeKeys, isEmpty);
    });
  });

  // ===========================================================================
  // Preference transitions (not seen -> seen)
  // ===========================================================================

  group('WhatsNewState transitions', () {
    test('fresh install -> show -> dismiss flow', () {
      // Step 1: Fresh install — nothing seen yet
      const step1 = WhatsNewState.initial;
      expect(step1.isLoaded, isFalse);
      expect(step1.hasPending, isFalse);
      expect(step1.shownThisSession, isFalse);

      // Step 2: Load completes — pending payload found
      const payload = WhatsNewPayload(
        version: '1.13.0',
        headline: "What's New",
        items: [
          WhatsNewItem(
            id: 'nodedex_intro',
            title: 'NodeDex',
            description: 'A living field journal',
            icon: Icons.auto_stories_outlined,
            badgeKey: 'nodedex',
          ),
        ],
      );

      final step2 = step1.copyWith(
        pendingPayload: payload,
        unseenBadgeKeys: {'nodedex'},
        isLoaded: true,
      );
      expect(step2.isLoaded, isTrue);
      expect(step2.hasPending, isTrue);
      expect(step2.isBadgeKeyUnseen('nodedex'), isTrue);
      expect(step2.shownThisSession, isFalse);

      // Step 3: Sheet is shown — mark shown this session
      final step3 = step2.copyWith(shownThisSession: true);
      expect(step3.shownThisSession, isTrue);
      expect(step3.hasPending, isTrue); // Still pending until dismissed

      // Step 4: User dismisses popup — payload cleared but badge keys persist
      final step4 = step3.copyWith(
        clearPendingPayload: true,
        // Badge keys are NOT cleared on popup dismiss (decoupled)
      );
      expect(step4.hasPending, isFalse);
      expect(
        step4.unseenBadgeKeys,
        isNotEmpty,
        reason: 'Badge keys persist after popup dismiss',
      );
      expect(step4.isBadgeKeyUnseen('nodedex'), isTrue);
      expect(step4.hasUnseenBadgeKeys, isTrue);
      expect(step4.shownThisSession, isTrue);

      // Step 5: User navigates to NodeDex — badge key dismissed individually
      final step5 = step4.copyWith(
        unseenBadgeKeys: Set<String>.from(step4.unseenBadgeKeys)
          ..remove('nodedex'),
      );
      expect(step5.unseenBadgeKeys, isEmpty);
      expect(step5.isBadgeKeyUnseen('nodedex'), isFalse);
      expect(step5.hasUnseenBadgeKeys, isFalse);
    });

    test('upgrade with nothing new — no popup, no badges', () {
      // User upgraded but lastSeen matches current, no pending
      const state = WhatsNewState(
        isLoaded: true,
        // No pending payload
      );

      expect(state.hasPending, isFalse);
      expect(state.unseenBadgeKeys, isEmpty);
    });

    test('individual badge key dismissal with multiple keys', () {
      // Simulates a future scenario with multiple badge keys
      const state = WhatsNewState(
        unseenBadgeKeys: {'feature_a', 'feature_b', 'feature_c'},
        isLoaded: true,
      );

      expect(state.isBadgeKeyUnseen('feature_a'), isTrue);
      expect(state.isBadgeKeyUnseen('feature_b'), isTrue);
      expect(state.isBadgeKeyUnseen('feature_c'), isTrue);
      expect(state.hasUnseenBadgeKeys, isTrue);

      // Dismiss feature_a — others remain
      final afterA = state.copyWith(
        unseenBadgeKeys: Set<String>.from(state.unseenBadgeKeys)
          ..remove('feature_a'),
      );
      expect(afterA.isBadgeKeyUnseen('feature_a'), isFalse);
      expect(afterA.isBadgeKeyUnseen('feature_b'), isTrue);
      expect(afterA.isBadgeKeyUnseen('feature_c'), isTrue);
      expect(afterA.hasUnseenBadgeKeys, isTrue);

      // Dismiss feature_b — one remains
      final afterB = afterA.copyWith(
        unseenBadgeKeys: Set<String>.from(afterA.unseenBadgeKeys)
          ..remove('feature_b'),
      );
      expect(afterB.isBadgeKeyUnseen('feature_b'), isFalse);
      expect(afterB.isBadgeKeyUnseen('feature_c'), isTrue);
      expect(afterB.hasUnseenBadgeKeys, isTrue);

      // Dismiss feature_c — all gone
      final afterC = afterB.copyWith(
        unseenBadgeKeys: Set<String>.from(afterB.unseenBadgeKeys)
          ..remove('feature_c'),
      );
      expect(afterC.unseenBadgeKeys, isEmpty);
      expect(afterC.hasUnseenBadgeKeys, isFalse);
    });

    test('popup dismiss preserves badge keys for hamburger dot', () {
      // Verifies the hamburger menu dot stays visible after popup dismiss
      const payload = WhatsNewPayload(
        version: '1.13.0',
        headline: "What's New",
        items: [
          WhatsNewItem(
            id: 'nodedex_intro',
            title: 'NodeDex',
            description: 'A living field journal',
            icon: Icons.auto_stories_outlined,
            badgeKey: 'nodedex',
          ),
        ],
      );

      // Before dismiss: popup pending, badge keys active
      const before = WhatsNewState(
        pendingPayload: payload,
        unseenBadgeKeys: {'nodedex'},
        shownThisSession: true,
        isLoaded: true,
      );
      expect(before.hasPending, isTrue);
      expect(before.hasUnseenBadgeKeys, isTrue);

      // After dismiss: popup cleared, badge keys still active
      final after = before.copyWith(clearPendingPayload: true);
      expect(after.hasPending, isFalse);
      expect(
        after.hasUnseenBadgeKeys,
        isTrue,
        reason: 'Badge keys must survive popup dismiss for drawer/hamburger',
      );
      expect(after.isBadgeKeyUnseen('nodedex'), isTrue);
    });
  });

  // ===========================================================================
  // Registry integrity
  // ===========================================================================

  group('WhatsNewRegistry integrity', () {
    test('all payloads have valid version strings', () {
      for (final payload in WhatsNewRegistry.allPayloads) {
        final parts = payload.version.split('.');
        expect(
          parts.length,
          3,
          reason: 'Version ${payload.version} should have 3 parts',
        );
        for (final part in parts) {
          expect(
            int.tryParse(part),
            isNotNull,
            reason:
                'Version part "$part" in ${payload.version} should be numeric',
          );
        }
      }
    });

    test('all payloads have non-empty items', () {
      for (final payload in WhatsNewRegistry.allPayloads) {
        expect(
          payload.items,
          isNotEmpty,
          reason: 'Payload ${payload.version} should have at least one item',
        );
      }
    });

    test('all items have non-empty id, title, and description', () {
      for (final payload in WhatsNewRegistry.allPayloads) {
        for (final item in payload.items) {
          expect(
            item.id,
            isNotEmpty,
            reason: 'Item should have a non-empty id',
          );
          expect(
            item.title,
            isNotEmpty,
            reason: 'Item ${item.id} should have a title',
          );
          expect(
            item.description,
            isNotEmpty,
            reason: 'Item ${item.id} should have a description',
          );
        }
      }
    });

    test('no duplicate item ids within a payload', () {
      for (final payload in WhatsNewRegistry.allPayloads) {
        final ids = payload.items.map((i) => i.id).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'Payload ${payload.version} has duplicate item ids',
        );
      }
    });

    test('no duplicate payload versions', () {
      final versions = WhatsNewRegistry.allPayloads
          .map((p) => p.version)
          .toList();
      expect(
        versions.toSet().length,
        versions.length,
        reason: 'Registry has duplicate payload versions',
      );
    });

    test('payloads are in ascending version order', () {
      final payloads = WhatsNewRegistry.allPayloads;
      for (var i = 1; i < payloads.length; i++) {
        final prev = payloads[i - 1].version.split('.').map(int.parse).toList();
        final curr = payloads[i].version.split('.').map(int.parse).toList();

        final isAscending =
            curr[0] > prev[0] ||
            (curr[0] == prev[0] && curr[1] > prev[1]) ||
            (curr[0] == prev[0] && curr[1] == prev[1] && curr[2] > prev[2]);

        expect(
          isAscending,
          isTrue,
          reason:
              'Payload ${payloads[i].version} should be after ${payloads[i - 1].version}',
        );
      }
    });
  });
}
