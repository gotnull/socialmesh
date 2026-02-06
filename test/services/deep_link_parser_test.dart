// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/deep_link/deep_link.dart';

void main() {
  group('DeepLinkParser', () {
    group('socialmesh:// scheme', () {
      test('parses node link with base64 data', () {
        // Base64 encoded: {"nodeNum":12345,"longName":"Test Node"}
        const base64 =
            'eyJub2RlTnVtIjoxMjM0NSwibG9uZ05hbWUiOiJUZXN0IE5vZGUifQ==';
        final result = deepLinkParser.parse('socialmesh://node/$base64');

        expect(result.type, DeepLinkType.node);
        expect(result.isValid, true);
        expect(result.nodeNum, 12345);
        expect(result.nodeLongName, 'Test Node');
        expect(result.needsFirestoreFetch, false);
        expect(result.hasCompleteNodeData, true);
      });

      test('parses node link with firestore doc ID', () {
        final result = deepLinkParser.parse('socialmesh://node/abc123xyz');

        expect(result.type, DeepLinkType.node);
        expect(result.isValid, true);
        expect(result.nodeFirestoreId, 'abc123xyz');
        expect(result.nodeNum, isNull);
        expect(result.needsFirestoreFetch, true);
        expect(result.hasCompleteNodeData, false);
      });

      test('parses channel link with base64 data', () {
        const base64 = 'Q2hhbm5lbERhdGE=';
        final result = deepLinkParser.parse('socialmesh://channel/$base64');

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        expect(result.channelBase64Data, base64);
        expect(result.channelFirestoreId, isNull);
        expect(result.hasChannelBase64Data, true);
        expect(result.hasChannelFirestoreId, false);
      });

      test('parses channel link with Firestore ID prefix', () {
        final result = deepLinkParser.parse(
          'socialmesh://channel/id:abc123xyz789',
        );

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        expect(result.channelFirestoreId, 'abc123xyz789');
        expect(result.channelBase64Data, isNull);
        expect(result.hasChannelFirestoreId, true);
        expect(result.hasChannelBase64Data, false);
      });

      test('parses channel link with empty Firestore ID as invalid', () {
        final result = deepLinkParser.parse('socialmesh://channel/id:');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });

      test('parses profile link', () {
        final result = deepLinkParser.parse('socialmesh://profile/user123');

        expect(result.type, DeepLinkType.profile);
        expect(result.isValid, true);
        expect(result.profileDisplayName, 'user123');
      });

      test('parses widget link', () {
        final result = deepLinkParser.parse('socialmesh://widget/widget456');

        expect(result.type, DeepLinkType.widget);
        expect(result.isValid, true);
        expect(result.widgetId, 'widget456');
      });

      test('parses widget link with base64 schema data', () {
        // Base64 encoded: {"name":"Test Widget","root":{"type":"container"}}
        // which is long enough to trigger base64 detection
        const base64Schema =
            'eyJuYW1lIjoiVGVzdCBXaWRnZXQiLCJyb290Ijp7InR5cGUiOiJjb250YWluZXIiLCJpZCI6InRlc3QiLCJjaGlsZHJlbiI6W119LCJzaXplIjoibWVkaXVtIn0';
        final result = deepLinkParser.parse(
          'socialmesh://widget/$base64Schema',
        );

        expect(result.type, DeepLinkType.widget);
        expect(result.isValid, true);
        expect(result.widgetBase64Data, base64Schema);
        expect(result.widgetId, isNull);
        expect(result.hasWidgetBase64Data, true);
      });

      test('parses widget link with Firestore ID prefix', () {
        final result = deepLinkParser.parse(
          'socialmesh://widget/id:abc123xyz789',
        );

        expect(result.type, DeepLinkType.widget);
        expect(result.isValid, true);
        expect(result.widgetFirestoreId, 'abc123xyz789');
        expect(result.widgetId, isNull);
        expect(result.widgetBase64Data, isNull);
        expect(result.hasWidgetFirestoreId, true);
      });

      test('parses post link', () {
        final result = deepLinkParser.parse('socialmesh://post/post789');

        expect(result.type, DeepLinkType.post);
        expect(result.isValid, true);
        expect(result.postId, 'post789');
      });

      test('parses location link with lat/lng', () {
        final result = deepLinkParser.parse(
          'socialmesh://location?lat=37.7749&lng=-122.4194',
        );

        expect(result.type, DeepLinkType.location);
        expect(result.isValid, true);
        expect(result.locationLatitude, 37.7749);
        expect(result.locationLongitude, -122.4194);
      });

      test('parses location link with label', () {
        final result = deepLinkParser.parse(
          'socialmesh://location?lat=40.7128&lng=-74.0060&label=NYC',
        );

        expect(result.type, DeepLinkType.location);
        expect(result.isValid, true);
        expect(result.locationLatitude, 40.7128);
        expect(result.locationLongitude, -74.0060);
        expect(result.locationLabel, 'NYC');
      });

      test('returns invalid for unknown path', () {
        final result = deepLinkParser.parse('socialmesh://unknown/foo');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
        expect(result.validationErrors, isNotEmpty);
      });

      test('returns invalid for empty path', () {
        final result = deepLinkParser.parse('socialmesh://');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });
    });

    group('https://socialmesh.app scheme', () {
      test('parses node share link', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/node/docId123',
        );

        expect(result.type, DeepLinkType.node);
        expect(result.isValid, true);
        expect(result.nodeFirestoreId, 'docId123');
        expect(result.needsFirestoreFetch, true);
      });

      test('parses profile share link', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/profile/userId456',
        );

        expect(result.type, DeepLinkType.profile);
        expect(result.isValid, true);
        expect(result.profileDisplayName, 'userId456');
      });

      test('parses channel share link', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/channel/channelDoc456',
        );

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        expect(result.channelFirestoreId, 'channelDoc456');
        expect(result.channelBase64Data, isNull);
        expect(result.hasChannelFirestoreId, true);
      });

      test('parses channel share link with missing ID as invalid', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/channel/',
        );

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });

      test('parses widget share link', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/widget/widgetABC',
        );

        expect(result.type, DeepLinkType.widget);
        expect(result.isValid, true);
        expect(result.widgetId, 'widgetABC');
      });

      test('parses post share link', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/post/postXYZ',
        );

        expect(result.type, DeepLinkType.post);
        expect(result.isValid, true);
        expect(result.postId, 'postXYZ');
      });

      test('parses location share link', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/location?lat=51.5074&lng=-0.1278&label=London',
        );

        expect(result.type, DeepLinkType.location);
        expect(result.isValid, true);
        expect(result.locationLatitude, 51.5074);
        expect(result.locationLongitude, -0.1278);
        expect(result.locationLabel, 'London');
      });

      test('returns invalid for non-share path', () {
        final result = deepLinkParser.parse('https://socialmesh.app/about');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });
    });

    group('meshtastic:// scheme (legacy)', () {
      test('parses legacy node link', () {
        final result = deepLinkParser.parse('meshtastic://node/docId789');

        expect(result.type, DeepLinkType.node);
        expect(result.isValid, true);
        expect(result.nodeFirestoreId, 'docId789');
      });

      test('parses legacy channel link', () {
        final result = deepLinkParser.parse('meshtastic://channel/base64Data');

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        expect(result.channelBase64Data, 'base64Data');
      });
    });

    group('https://meshtastic.org/e/# (legacy channel)', () {
      test('parses legacy meshtastic.org channel URL', () {
        final result = deepLinkParser.parse(
          'https://meshtastic.org/e/#CgMSAQESDAgBOAFAA0gBUAFoAQ',
        );

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        expect(result.channelBase64Data, 'CgMSAQESDAgBOAFAA0gBUAFoAQ');
      });

      test('handles URL-encoded fragment', () {
        final result = deepLinkParser.parse(
          'https://meshtastic.org/e/#CgMSAQESDAgBOAFAA0gBUAFoAQ%3D%3D',
        );

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        // URL-decoded fragment
        expect(result.channelBase64Data, 'CgMSAQESDAgBOAFAA0gBUAFoAQ==');
      });
    });

    group('error handling', () {
      test('handles empty string', () {
        final result = deepLinkParser.parse('');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });

      test('handles malformed URI', () {
        final result = deepLinkParser.parse('not a valid uri ://');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });

      test('handles unknown scheme', () {
        final result = deepLinkParser.parse('ftp://example.com/file');

        expect(result.type, DeepLinkType.invalid);
        expect(result.isValid, false);
      });

      test('location link with missing lat', () {
        final result = deepLinkParser.parse('socialmesh://location?lng=-122');

        expect(result.type, DeepLinkType.location);
        expect(result.isValid, false);
        expect(result.validationErrors, contains('Missing latitude'));
      });

      test('location link with missing lng', () {
        final result = deepLinkParser.parse('socialmesh://location?lat=37');

        expect(result.type, DeepLinkType.location);
        expect(result.isValid, false);
        expect(result.validationErrors, contains('Missing longitude'));
      });

      test('location link with invalid coordinates', () {
        final result = deepLinkParser.parse(
          'socialmesh://location?lat=abc&lng=xyz',
        );

        expect(result.type, DeepLinkType.location);
        expect(result.isValid, false);
        expect(result.validationErrors, contains('Invalid latitude'));
        expect(result.validationErrors, contains('Invalid longitude'));
      });

      test('node link with missing data', () {
        final result = deepLinkParser.parse('socialmesh://node/');

        expect(result.type, DeepLinkType.node);
        expect(result.isValid, false);
        expect(result.validationErrors, contains('Missing node data'));
      });

      test('channel link with missing data', () {
        final result = deepLinkParser.parse('socialmesh://channel/');

        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, false);
        expect(result.validationErrors, contains('Missing channel data'));
      });

      test('profile link with missing id', () {
        final result = deepLinkParser.parse('socialmesh://profile/');

        expect(result.type, DeepLinkType.profile);
        expect(result.isValid, false);
        expect(
          result.validationErrors,
          contains('Missing profile display name'),
        );
      });
    });

    group('preserves original URI', () {
      test('stores original URI in result', () {
        const uri = 'socialmesh://node/test123';
        final result = deepLinkParser.parse(uri);

        expect(result.originalUri, uri);
      });
    });
  });

  group('DeepLinkRouter', () {
    test('routes valid node link to /nodes', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.node,
        originalUri: 'socialmesh://node/test',
        nodeNum: 12345,
        nodeLongName: 'Test',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/nodes');
      expect(result.arguments?['highlightNodeNum'], 12345);
      expect(result.arguments?['scrollToNode'], true);
    });

    test('routes channel link with base64 data to /qr-scanner', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: 'socialmesh://channel/data',
        channelBase64Data: 'channelData123',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/qr-scanner');
      expect(result.arguments?['base64Data'], 'channelData123');
      expect(result.requiresDevice, true);
    });

    test('routes channel link with Firestore ID to /channel-import', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: 'socialmesh://channel/id:abc123',
        channelFirestoreId: 'abc123',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/channel-import');
      expect(result.arguments?['firestoreId'], 'abc123');
      expect(result.requiresDevice, true);
    });

    test('routes channel link without data to /channels fallback', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: 'socialmesh://channel/empty',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/channels');
      expect(result.fallbackMessage, 'Invalid channel data');
    });

    test('routes profile link to /profile', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.profile,
        originalUri: 'socialmesh://profile/user1',
        profileDisplayName: 'user1',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/profile');
      expect(result.arguments?['displayName'], 'user1');
    });

    test('routes widget link to /widget-detail', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.widget,
        originalUri: 'socialmesh://widget/w1',
        widgetId: 'w1',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/widget-detail');
      expect(result.arguments?['widgetId'], 'w1');
    });

    test('routes widget link with base64 data to /widget-import', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.widget,
        originalUri: 'socialmesh://widget/base64data',
        widgetBase64Data: 'base64data',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/widget-import');
      expect(result.arguments?['base64Data'], 'base64data');
      expect(result.requiresDevice, false);
    });

    test('routes widget link with Firestore ID to /widget-import', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.widget,
        originalUri: 'socialmesh://widget/id:abc123',
        widgetFirestoreId: 'abc123',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/widget-import');
      expect(result.arguments?['firestoreId'], 'abc123');
      expect(result.requiresDevice, false);
    });

    test('routes post link to /post-detail', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.post,
        originalUri: 'socialmesh://post/p1',
        postId: 'p1',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/post-detail');
      expect(result.arguments?['postId'], 'p1');
    });

    test('routes location link to /map with coordinates', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.location,
        originalUri: 'socialmesh://location?lat=1&lng=2',
        locationLatitude: 37.7749,
        locationLongitude: -122.4194,
        locationLabel: 'SF',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/map');
      expect(result.arguments?['latitude'], 37.7749);
      expect(result.arguments?['longitude'], -122.4194);
      expect(result.arguments?['label'], 'SF');
    });

    test('routes invalid link to /main with fallback message', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.invalid,
        originalUri: 'invalid://link',
        validationErrors: ['Unknown scheme'],
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/main');
      expect(result.fallbackMessage, contains('Invalid link'));
    });

    test('routes link with validation errors to /main', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.location,
        originalUri: 'socialmesh://location',
        validationErrors: ['Missing latitude'],
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/main');
      expect(result.fallbackMessage, contains('Invalid link'));
    });

    test('channel link with base64 requiresDevice is true', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: 'socialmesh://channel/test',
        channelBase64Data: 'test',
      );

      final result = deepLinkRouter.route(link);

      expect(result.requiresDevice, true);
    });

    test('channel link with Firestore ID requiresDevice is true', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channel,
        originalUri: 'https://socialmesh.app/share/channel/doc123',
        channelFirestoreId: 'doc123',
      );

      final result = deepLinkRouter.route(link);

      expect(result.requiresDevice, true);
    });

    test('profile link requiresDevice is false', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.profile,
        originalUri: 'socialmesh://profile/user',
        profileDisplayName: 'user',
      );

      final result = deepLinkRouter.route(link);

      expect(result.requiresDevice, isFalse);
    });

    test('automation link routes to /automation-import', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.automation,
        originalUri: 'socialmesh://automation/base64data',
        automationBase64Data: 'base64data',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/automation-import');
      expect(result.arguments?['base64Data'], 'base64data');
      expect(result.requiresDevice, false);
    });

    test('automation link with firestore ID routes correctly', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.automation,
        originalUri: 'https://socialmesh.app/share/automation/doc123',
        automationFirestoreId: 'doc123',
      );

      final result = deepLinkRouter.route(link);

      expect(result.routeName, '/automation-import');
      expect(result.arguments?['firestoreId'], 'doc123');
    });
  });

  group('Automation deep link parsing', () {
    test('parses automation link with base64 data', () {
      // Base64 encoded: {"name":"Test"}
      const base64 = 'eyJuYW1lIjoiVGVzdCJ9';
      final result = deepLinkParser.parse('socialmesh://automation/$base64');

      expect(result.type, DeepLinkType.automation);
      expect(result.isValid, true);
      expect(result.automationBase64Data, base64);
    });

    test('parses automation share link with firestore ID', () {
      final result = deepLinkParser.parse(
        'https://socialmesh.app/share/automation/battery-alert-123',
      );

      expect(result.type, DeepLinkType.automation);
      expect(result.isValid, true);
      expect(result.automationFirestoreId, 'battery-alert-123');
    });

    test('parses real Low Battery Alert automation', () {
      // URL-safe base64 from scripts/generate_automation_links.py
      const base64 =
          'eyJuYW1lIjoiTG93IEJhdHRlcnkgQWxlcnQiLCJkZXNjcmlwdGlvbiI6Ik5vdGlmeSB3aGVuIE1lc2h0YXN0aWMgYjBmNCBiYXR0ZXJ5IGRyb3BzIGJlbG93IDIwJSIsInRyaWdnZXIiOnsidHlwZSI6ImJhdHRlcnlMb3ciLCJub2RlTnVtIjoxMTMwMTM5ODkyLCJ0aHJlc2hvbGQiOjIwLCJoeXN0ZXJlc2lzIjo1fSwiYWN0aW9ucyI6W3sidHlwZSI6Im5vdGlmaWNhdGlvbiIsInRpdGxlIjoiQmF0dGVyeSBMb3ciLCJtZXNzYWdlIjoiTm9kZSBiMGY0IGJhdHRlcnkgYXQge2JhdHRlcnl9JSJ9LHsidHlwZSI6InNvdW5kIiwicnR0dGwiOiJCYXR0ZXJ5TG93OmQ9NCxvPTUsYj0xMDA6MTZlNiwxNmU2LDE2ZTYifV19';
      final result = deepLinkParser.parse('socialmesh://automation/$base64');

      expect(result.type, DeepLinkType.automation);
      expect(result.isValid, true);
      expect(result.automationBase64Data, base64);
    });

    test('parses real Node Offline Alert automation', () {
      const base64 =
          'eyJuYW1lIjoiTm9kZSBPZmZsaW5lIEFsZXJ0IiwiZGVzY3JpcHRpb24iOiJBbGVydCB3aGVuIGIwZjQgZ29lcyBvZmZsaW5lIGZvciAxMCBtaW51dGVzIiwidHJpZ2dlciI6eyJ0eXBlIjoibm9kZU9mZmxpbmUiLCJub2RlTnVtIjoxMTMwMTM5ODkyLCJkdXJhdGlvbiI6NjAwfSwiYWN0aW9ucyI6W3sidHlwZSI6Im5vdGlmaWNhdGlvbiIsInRpdGxlIjoiTm9kZSBPZmZsaW5lIiwibWVzc2FnZSI6Ik1lc2h0YXN0aWMgYjBmNCBoYXMgYmVlbiBvZmZsaW5lIGZvciAxMCBtaW51dGVzIn1dfQ';
      final result = deepLinkParser.parse('socialmesh://automation/$base64');

      expect(result.type, DeepLinkType.automation);
      expect(result.isValid, true);
      expect(result.automationBase64Data, base64);
    });

    test('parses real Emergency Keyword automation', () {
      const base64 =
          'eyJuYW1lIjoiRW1lcmdlbmN5IEtleXdvcmQiLCJkZXNjcmlwdGlvbiI6IkFsZXJ0IG9uIGVtZXJnZW5jeSBtZXNzYWdlcyBmcm9tIGFueSBub2RlIiwidHJpZ2dlciI6eyJ0eXBlIjoibWVzc2FnZUNvbnRhaW5zIiwia2V5d29yZHMiOlsiaGVscCIsImVtZXJnZW5jeSIsInNvcyJdfSwiYWN0aW9ucyI6W3sidHlwZSI6Im5vdGlmaWNhdGlvbiIsInRpdGxlIjoiRW1lcmdlbmN5IE1lc3NhZ2UiLCJtZXNzYWdlIjoiRW1lcmdlbmN5IGtleXdvcmQgZGV0ZWN0ZWQgZnJvbSB7bm9kZVNob3J0TmFtZX0iLCJwcmlvcml0eSI6ImhpZ2gifSx7InR5cGUiOiJzb3VuZCIsInJ0dHRsIjoiQWxlcnQ6ZD00LG89NSxiPTE4MDoxNmU2LDE2cCwxNmU2LDE2cCwxNmU2In0seyJ0eXBlIjoidmlicmF0ZSIsInBhdHRlcm4iOlswLDUwMCwyMDAsNTAwXX1dfQ';
      final result = deepLinkParser.parse('socialmesh://automation/$base64');

      expect(result.type, DeepLinkType.automation);
      expect(result.isValid, true);
      expect(result.automationBase64Data, base64);
    });
  });

  group('DeepLinkRouteResult', () {
    test('fallback returns /main route', () {
      const result = DeepLinkRouteResult.fallback;

      expect(result.routeName, '/main');
      expect(result.arguments, isNull);
    });

    test('constructor allows all fields', () {
      const result = DeepLinkRouteResult(
        routeName: '/test',
        arguments: {'key': 'value'},
        requiresDevice: true,
        requiresAuth: true,
        fallbackMessage: 'Test message',
      );

      expect(result.routeName, '/test');
      expect(result.arguments?['key'], 'value');
      expect(result.requiresDevice, true);
      expect(result.requiresAuth, true);
      expect(result.fallbackMessage, 'Test message');
    });
  });
}
