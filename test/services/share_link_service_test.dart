// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/share_link_service.dart';
import 'package:socialmesh/models/mesh_models.dart';

void main() {
  group('ShareLinkService - Authentication Requirements', () {
    group('shareNode', () {
      test('throws StateError when user is not authenticated', () async {
        // Create service without any auth - will use FirebaseAuth.instance which
        // returns null for currentUser in test environment
        final service = ShareLinkService();

        final node = MeshNode(
          nodeNum: 1130139892,
          longName: 'Test Node',
          shortName: 'TEST',
        );

        expect(
          () => service.shareNode(node: node),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('signed in'),
            ),
          ),
        );
      });

      test('error message is user-friendly', () async {
        final service = ShareLinkService();

        final node = MeshNode(
          nodeNum: 1130139892,
          longName: 'Test Node',
          shortName: 'TEST',
        );

        try {
          await service.shareNode(node: node);
          fail('Expected StateError');
        } on StateError catch (e) {
          expect(e.message, 'Must be signed in to share nodes');
        }
      });
    });

    group('shareNodeBasic', () {
      test('throws StateError when user is not authenticated', () async {
        final service = ShareLinkService();

        expect(
          () => service.shareNodeBasic(
            nodeId: '!435bb0f4',
            nodeName: 'Test Node',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('signed in'),
            ),
          ),
        );
      });

      test('error message is user-friendly', () async {
        final service = ShareLinkService();

        try {
          await service.shareNodeBasic(
            nodeId: '!435bb0f4',
            nodeName: 'Test Node',
          );
          fail('Expected StateError');
        } on StateError catch (e) {
          expect(e.message, 'Must be signed in to share nodes');
        }
      });
    });
  });

  group('ShareLinkService - Non-auth methods', () {
    test('shareProfile does not require auth', () {
      // shareProfile just creates a share URL, no Firestore write
      // This test validates the method signature hasn't changed
      final service = ShareLinkService();

      // Method exists and takes expected parameters
      expect(
        () =>
            service.shareProfile(userId: 'test-user', displayName: 'Test User'),
        // Will throw from Share.share in test environment, but not StateError
        throwsA(isNot(isA<StateError>())),
      );
    });

    test('shareWidget does not require auth', () {
      final service = ShareLinkService();

      expect(
        () => service.shareWidget(
          widgetId: 'test-widget',
          widgetName: 'Test Widget',
        ),
        throwsA(isNot(isA<StateError>())),
      );
    });

    test('shareLocation does not require auth', () {
      final service = ShareLinkService();

      expect(
        () => service.shareLocation(latitude: 37.7749, longitude: -122.4194),
        throwsA(isNot(isA<StateError>())),
      );
    });

    test('sharePost does not require auth', () {
      final service = ShareLinkService();

      expect(
        () => service.sharePost(postId: 'test-post'),
        throwsA(isNot(isA<StateError>())),
      );
    });

    test('shareText does not require auth', () {
      final service = ShareLinkService();

      expect(
        () => service.shareText(text: 'Test text'),
        throwsA(isNot(isA<StateError>())),
      );
    });
  });
}
