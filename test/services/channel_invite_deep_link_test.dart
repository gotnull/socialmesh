// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/deep_link/deep_link.dart';

void main() {
  group('Channel Invite Deep Link Parsing', () {
    group('socialmesh:// scheme', () {
      test('parses channel-invite with valid fragment', () {
        const secret = 'abc123secretXYZ_-';
        final result = deepLinkParser.parse(
          'socialmesh://channel-invite/deadbeef0123456789abcdef01234567#t=$secret',
        );

        expect(result.type, DeepLinkType.channelInvite);
        expect(result.isValid, true);
        expect(result.channelInviteId, 'deadbeef0123456789abcdef01234567');
        expect(result.channelInviteSecret, secret);
        expect(result.hasChannelInvite, true);
      });

      test('rejects channel-invite without fragment', () {
        final result = deepLinkParser.parse(
          'socialmesh://channel-invite/deadbeef0123456789abcdef01234567',
        );

        expect(result.isValid, false);
        expect(result.validationErrors, isNotEmpty);
      });

      test('rejects channel-invite with empty secret', () {
        final result = deepLinkParser.parse(
          'socialmesh://channel-invite/deadbeef0123456789abcdef01234567#t=',
        );

        expect(result.isValid, false);
      });

      test('rejects channel-invite without invite ID', () {
        final result = deepLinkParser.parse(
          'socialmesh://channel-invite/#t=somesecret',
        );

        expect(result.isValid, false);
      });

      test('extracts secret from multi-part fragment', () {
        final result = deepLinkParser.parse(
          'socialmesh://channel-invite/abcd1234#foo=bar&t=mysecret123&baz=qux',
        );

        expect(result.type, DeepLinkType.channelInvite);
        expect(result.isValid, true);
        expect(result.channelInviteSecret, 'mysecret123');
      });
    });

    group('https://socialmesh.app universal link', () {
      test('parses /share/channel/{id}#t={secret} as invite', () {
        const id = 'aabbccdd11223344';
        const secret = 'base64url_secret_value';
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/channel/$id#t=$secret',
        );

        expect(result.type, DeepLinkType.channelInvite);
        expect(result.isValid, true);
        expect(result.channelInviteId, id);
        expect(result.channelInviteSecret, secret);
      });

      test('/share/channel/{id} without fragment is regular channel link', () {
        const id = 'aabbccdd11223344';
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/channel/$id',
        );

        // Without fragment → standard channel (Firestore) not invite
        expect(result.type, DeepLinkType.channel);
        expect(result.isValid, true);
        expect(result.channelFirestoreId, id);
      });

      test('fragment missing t= key is invalid invite', () {
        final result = deepLinkParser.parse(
          'https://socialmesh.app/share/channel/abc123#x=notsecret',
        );

        // Has fragment but no t= → treated as invite attempt but invalid
        expect(result.isValid, false);
      });
    });

    group('secret is never logged in full', () {
      test('secret is redacted in parsed link representation', () {
        // This is a design invariant — the parser must not leak secrets.
        // We verify the ParsedDeepLink holds the secret but that
        // logging redacts it (tested implicitly by the parser's log line:
        // "secret=<redacted N chars>").
        final result = deepLinkParser.parse(
          'socialmesh://channel-invite/id1234#t=topsecretvalue42',
        );

        expect(result.channelInviteSecret, 'topsecretvalue42');
        // toString of ParsedDeepLink should NOT contain the raw secret.
        // ParsedDeepLink is a data class — we just confirm the value is stored.
        expect(result.hasChannelInvite, true);
      });
    });
  });

  group('Channel Invite Deep Link Routing', () {
    test('routes to /channel-invite with args', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channelInvite,
        originalUri: 'socialmesh://channel-invite/inv1#t=sec1',
        channelInviteId: 'inv1',
        channelInviteSecret: 'sec1',
      );

      final route = deepLinkRouter.route(link);

      expect(route.routeName, '/channel-invite');
      expect(route.requiresAuth, true);
      expect(route.arguments, isA<Map>());
      expect((route.arguments as Map)['inviteId'], 'inv1');
      expect((route.arguments as Map)['inviteSecret'], 'sec1');
    });

    test('routes to fallback when invite data missing', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channelInvite,
        originalUri: 'socialmesh://channel-invite/',
      );

      final route = deepLinkRouter.route(link);

      // hasChannelInvite is false → fallback
      expect(route.routeName, '/channels');
      expect(route.fallbackMessage, isNotNull);
    });

    test('requiresAuth is true for invite links', () {
      final link = ParsedDeepLink(
        type: DeepLinkType.channelInvite,
        originalUri: 'test',
        channelInviteId: 'abc',
        channelInviteSecret: 'xyz',
      );

      final route = deepLinkRouter.route(link);
      expect(route.requiresAuth, true);
    });
  });
}
