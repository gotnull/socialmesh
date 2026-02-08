// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/deep_link/deep_link_parser.dart';
import 'package:socialmesh/services/deep_link/deep_link_router.dart';
import 'package:socialmesh/services/deep_link/deep_link_types.dart';

void main() {
  const parser = DeepLinkParser();
  const router = DeepLinkRouter();

  group('DeepLinkParser - legal universal links', () {
    test('https://socialmesh.app/terms parses as legal type', () {
      final result = parser.parse('https://socialmesh.app/terms');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('terms'));
      expect(result.legalSectionAnchor, isNull);
    });

    test('https://socialmesh.app/privacy parses as legal type', () {
      final result = parser.parse('https://socialmesh.app/privacy');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('privacy'));
      expect(result.legalSectionAnchor, isNull);
    });

    test('terms URL with anchor preserves section anchor', () {
      final result = parser.parse(
        'https://socialmesh.app/terms#radio-compliance',
      );

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('terms'));
      expect(result.legalSectionAnchor, equals('radio-compliance'));
    });

    test('terms URL with inapp param and anchor', () {
      final result = parser.parse(
        'https://socialmesh.app/terms?inapp=true#payments',
      );

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('terms'));
      expect(result.legalSectionAnchor, equals('payments'));
    });

    test('privacy URL with anchor preserves section anchor', () {
      final result = parser.parse(
        'https://socialmesh.app/privacy#third-party-services',
      );

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('privacy'));
      expect(result.legalSectionAnchor, equals('third-party-services'));
    });

    test('terms URL with multiple anchors', () {
      final result = parser.parse(
        'https://socialmesh.app/terms#indemnification',
      );

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.legalSectionAnchor, equals('indemnification'));
    });

    test('terms URL with license-grant anchor', () {
      final result = parser.parse('https://socialmesh.app/terms#license-grant');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.legalSectionAnchor, equals('license-grant'));
    });

    test('terms URL with governing-law anchor', () {
      final result = parser.parse('https://socialmesh.app/terms#governing-law');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.legalSectionAnchor, equals('governing-law'));
    });

    test('terms URL with acceptable-use anchor', () {
      final result = parser.parse(
        'https://socialmesh.app/terms#acceptable-use',
      );

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.legalSectionAnchor, equals('acceptable-use'));
    });
  });

  group('DeepLinkParser - legal custom scheme links', () {
    test('socialmesh://legal/terms parses as legal type', () {
      final result = parser.parse('socialmesh://legal/terms');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('terms'));
      expect(result.legalSectionAnchor, isNull);
    });

    test('socialmesh://legal/privacy parses as legal type', () {
      final result = parser.parse('socialmesh://legal/privacy');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('privacy'));
      expect(result.legalSectionAnchor, isNull);
    });

    test('socialmesh://legal/terms with anchor', () {
      final result = parser.parse('socialmesh://legal/terms#radio-compliance');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('terms'));
      expect(result.legalSectionAnchor, equals('radio-compliance'));
    });

    test('socialmesh://legal/privacy with anchor', () {
      final result = parser.parse('socialmesh://legal/privacy#data-security');

      expect(result.type, equals(DeepLinkType.legal));
      expect(result.isValid, isTrue);
      expect(result.legalDocument, equals('privacy'));
      expect(result.legalSectionAnchor, equals('data-security'));
    });

    test('socialmesh://legal without document type returns invalid', () {
      final result = parser.parse('socialmesh://legal');

      expect(result.type, equals(DeepLinkType.invalid));
      expect(result.isValid, isFalse);
    });

    test(
      'socialmesh://legal/unknown returns invalid for unknown document type',
      () {
        final result = parser.parse('socialmesh://legal/unknown');

        expect(result.type, equals(DeepLinkType.invalid));
        expect(result.isValid, isFalse);
      },
    );
  });

  group('DeepLinkParser - legal link helper getters', () {
    test('isLegalLink returns true for valid legal links', () {
      final result = parser.parse('https://socialmesh.app/terms');
      expect(result.isLegalLink, isTrue);
    });

    test('isLegalLink returns false for non-legal links', () {
      final result = parser.parse('https://socialmesh.app/share/node/abc123');
      expect(result.isLegalLink, isFalse);
    });

    test('isTermsLink returns true for terms document', () {
      final result = parser.parse('https://socialmesh.app/terms');
      expect(result.isTermsLink, isTrue);
      expect(result.isPrivacyLink, isFalse);
    });

    test('isPrivacyLink returns true for privacy document', () {
      final result = parser.parse('https://socialmesh.app/privacy');
      expect(result.isPrivacyLink, isTrue);
      expect(result.isTermsLink, isFalse);
    });
  });

  group('DeepLinkRouter - legal routes', () {
    test('routes terms link to /legal/terms', () {
      final parsed = parser.parse('https://socialmesh.app/terms');
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/terms'));
      expect(routeResult.requiresDevice, isFalse);
      expect(routeResult.requiresAuth, isFalse);
    });

    test('routes privacy link to /legal/privacy', () {
      final parsed = parser.parse('https://socialmesh.app/privacy');
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/privacy'));
      expect(routeResult.requiresDevice, isFalse);
      expect(routeResult.requiresAuth, isFalse);
    });

    test('routes terms link with anchor and passes sectionAnchor argument', () {
      final parsed = parser.parse(
        'https://socialmesh.app/terms#radio-compliance',
      );
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/terms'));
      expect(routeResult.arguments, isNotNull);
      expect(routeResult.arguments!['document'], equals('terms'));
      expect(
        routeResult.arguments!['sectionAnchor'],
        equals('radio-compliance'),
      );
    });

    test('routes privacy link without anchor and null sectionAnchor', () {
      final parsed = parser.parse('https://socialmesh.app/privacy');
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/privacy'));
      expect(routeResult.arguments, isNotNull);
      expect(routeResult.arguments!['document'], equals('privacy'));
      expect(routeResult.arguments!['sectionAnchor'], isNull);
    });

    test('routes custom scheme terms link correctly', () {
      final parsed = parser.parse('socialmesh://legal/terms');
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/terms'));
      expect(routeResult.arguments!['document'], equals('terms'));
    });

    test('routes custom scheme privacy link correctly', () {
      final parsed = parser.parse('socialmesh://legal/privacy');
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/privacy'));
      expect(routeResult.arguments!['document'], equals('privacy'));
    });

    test('routes custom scheme terms link with anchor', () {
      final parsed = parser.parse('socialmesh://legal/terms#acceptable-use');
      final routeResult = router.route(parsed);

      expect(routeResult.routeName, equals('/legal/terms'));
      expect(routeResult.arguments!['sectionAnchor'], equals('acceptable-use'));
    });
  });

  group('DeepLinkParser - legal links do not break existing links', () {
    test('/share/node still works', () {
      final result = parser.parse('https://socialmesh.app/share/node/abc123');
      expect(result.type, equals(DeepLinkType.node));
      expect(result.isValid, isTrue);
    });

    test('/share/profile still works', () {
      final result = parser.parse(
        'https://socialmesh.app/share/profile/testuser',
      );
      expect(result.type, equals(DeepLinkType.profile));
      expect(result.isValid, isTrue);
    });

    test('socialmesh://node still works', () {
      final result = parser.parse('socialmesh://node/abc123');
      expect(result.type, equals(DeepLinkType.node));
      expect(result.isValid, isTrue);
    });

    test('socialmesh://channel still works', () {
      final result = parser.parse('socialmesh://channel/abc123');
      expect(result.type, equals(DeepLinkType.channel));
      expect(result.isValid, isTrue);
    });
  });
}
