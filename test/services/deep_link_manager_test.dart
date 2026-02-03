// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/deep_link_manager.dart';
import 'package:socialmesh/services/deep_link/deep_link.dart';

void main() {
  group('DeepLinkManager', () {
    test('readiness state changes correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(deepLinkManagerProvider);

      // App starts not ready
      expect(container.read(deepLinkReadyProvider), false);

      // Mark app ready
      container.read(deepLinkReadyProvider.notifier).setReady();
      expect(container.read(deepLinkReadyProvider), true);

      // Mark app not ready
      container.read(deepLinkReadyProvider.notifier).setNotReady();
      expect(container.read(deepLinkReadyProvider), false);
    });

    test('deep link types are correctly defined', () {
      // Test DeepLinkType enum values
      expect(DeepLinkType.values, contains(DeepLinkType.node));
      expect(DeepLinkType.values, contains(DeepLinkType.channel));
      expect(DeepLinkType.values, contains(DeepLinkType.profile));
      expect(DeepLinkType.values, contains(DeepLinkType.widget));
      expect(DeepLinkType.values, contains(DeepLinkType.post));
      expect(DeepLinkType.values, contains(DeepLinkType.location));
      expect(DeepLinkType.values, contains(DeepLinkType.invalid));
    });

    test('ParsedDeepLink isValid returns correct value', () {
      // Valid node link
      const validNode = ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: 'socialmesh://node/test',
        nodeNum: 12345,
      );
      expect(validNode.isValid, true);

      // Invalid link type
      const invalid = ParsedDeepLink(
        type: DeepLinkType.invalid,
        originalUri: 'invalid://link',
        validationErrors: ['Unknown scheme'],
      );
      expect(invalid.isValid, false);

      // Valid type but with validation errors
      const withErrors = ParsedDeepLink(
        type: DeepLinkType.location,
        originalUri: 'socialmesh://location',
        validationErrors: ['Missing latitude'],
      );
      expect(withErrors.isValid, false);
    });

    test('ParsedDeepLink needsFirestoreFetch is correct', () {
      // Node with Firestore ID but no nodeNum
      const needsFetch = ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: 'socialmesh://node/docId',
        nodeFirestoreId: 'docId123',
      );
      expect(needsFetch.needsFirestoreFetch, true);
      expect(needsFetch.hasCompleteNodeData, false);

      // Node with nodeNum
      const hasData = ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: 'socialmesh://node/data',
        nodeNum: 12345,
      );
      expect(hasData.needsFirestoreFetch, false);
      expect(hasData.hasCompleteNodeData, true);
    });

    test('DeepLinkRouter routes correctly', () {
      // Test routing a node link
      const nodeLink = ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: 'socialmesh://node/test',
        nodeNum: 12345,
        nodeLongName: 'Test Node',
      );
      final nodeResult = deepLinkRouter.route(nodeLink);
      expect(nodeResult.routeName, '/nodes');

      // Test routing a channel link
      const channelLink = ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: 'socialmesh://channel/data',
        channelBase64Data: 'test123',
      );
      final channelResult = deepLinkRouter.route(channelLink);
      expect(channelResult.routeName, '/qr-scanner');
      expect(channelResult.requiresDevice, true);

      // Test routing a profile link
      const profileLink = ParsedDeepLink(
        type: DeepLinkType.profile,
        originalUri: 'socialmesh://profile/user1',
        profileDisplayName: 'user1',
      );
      final profileResult = deepLinkRouter.route(profileLink);
      expect(profileResult.routeName, '/profile');
    });
  });
}
