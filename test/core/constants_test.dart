import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/constants.dart';

void main() {
  setUpAll(() {
    // Initialize dotenv with minimal env to use default values
    // We use a dummy key since flutter_dotenv requires non-empty content
    dotenv.loadFromString(envString: 'TEST_MODE=true');
  });

  group('AppUrls', () {
    group('Share URLs', () {
      test('shareNodeUrl generates correct URL', () {
        final url = AppUrls.shareNodeUrl('abc123');
        expect(url, contains('/share/node/abc123'));
        expect(url, startsWith('https://'));
      });

      test('shareProfileUrl generates correct URL', () {
        final url = AppUrls.shareProfileUrl('user456');
        expect(url, contains('/share/profile/user456'));
        expect(url, startsWith('https://'));
      });

      test('shareWidgetUrl generates correct URL', () {
        final url = AppUrls.shareWidgetUrl('widget789');
        expect(url, contains('/share/widget/widget789'));
        expect(url, startsWith('https://'));
      });

      test('shareLocationUrl without label generates correct URL', () {
        final url = AppUrls.shareLocationUrl(37.7749, -122.4194);
        expect(url, contains('/share/location?'));
        expect(url, contains('lat=37.7749'));
        expect(url, contains('lng=-122.4194'));
        expect(url, isNot(contains('label=')));
      });

      test('shareLocationUrl with label encodes properly', () {
        final url = AppUrls.shareLocationUrl(
          37.7749,
          -122.4194,
          label: 'San Francisco',
        );
        expect(url, contains('lat=37.7749'));
        expect(url, contains('lng=-122.4194'));
        expect(url, contains('label=San%20Francisco'));
      });
    });

    group('Legal URLs', () {
      test('termsUrl ends with /terms', () {
        expect(AppUrls.termsUrl, endsWith('/terms'));
      });

      test('privacyUrl ends with /privacy', () {
        expect(AppUrls.privacyUrl, endsWith('/privacy'));
      });

      test('supportUrl ends with /support', () {
        expect(AppUrls.supportUrl, endsWith('/support'));
      });

      test('docsUrl ends with /docs', () {
        expect(AppUrls.docsUrl, endsWith('/docs'));
      });

      test('faqUrl ends with /faq', () {
        expect(AppUrls.faqUrl, endsWith('/faq'));
      });

      test('deleteAccountUrl ends with /delete-account', () {
        expect(AppUrls.deleteAccountUrl, endsWith('/delete-account'));
      });
    });

    group('Default base URL', () {
      test('baseUrl defaults to socialmesh.app', () {
        expect(AppUrls.baseUrl, 'https://socialmesh.app');
      });

      test('cloudFunctionsUrl defaults to us-central1', () {
        expect(
          AppUrls.cloudFunctionsUrl,
          'https://us-central1-social-mesh-app.cloudfunctions.net',
        );
      });

      test('worldMeshApiUrl defaults to api subdomain', () {
        expect(AppUrls.worldMeshApiUrl, 'https://api.socialmesh.app');
      });
    });

    group('App identifiers', () {
      test('iosAppId is correct format', () {
        expect(AppUrls.iosAppId, matches(RegExp(r'^\d+$')));
        expect(AppUrls.iosAppId.length, greaterThan(5));
      });

      test('androidPackage follows reverse domain notation', () {
        expect(AppUrls.androidPackage, 'app.socialmesh');
        expect(AppUrls.androidPackage, contains('.'));
      });

      test('deepLinkScheme is lowercase', () {
        expect(AppUrls.deepLinkScheme, 'socialmesh');
        expect(AppUrls.deepLinkScheme, AppUrls.deepLinkScheme.toLowerCase());
      });
    });

    group('Store URLs', () {
      test('appStoreUrl is valid Apple URL', () {
        expect(AppUrls.appStoreUrl, startsWith('https://apps.apple.com'));
        expect(AppUrls.appStoreUrl, contains('socialmesh'));
      });

      test('playStoreUrl is valid Google URL', () {
        expect(AppUrls.playStoreUrl, startsWith('https://play.google.com'));
        expect(AppUrls.playStoreUrl, contains('app.socialmesh'));
      });
    });
  });

  group('StorageConstants', () {
    test('has correct database name', () {
      expect(StorageConstants.databaseName, 'socialmesh.db');
    });

    test('has correct database version', () {
      expect(StorageConstants.databaseVersion, 1);
    });

    test('has reasonable cache size', () {
      expect(StorageConstants.maxCacheSizeMb, 500);
    });

    test('has reasonable message TTL', () {
      expect(StorageConstants.defaultMessageTtlHours, 72);
    });

    test('has reasonable offline queue size', () {
      expect(StorageConstants.maxOfflineQueueSize, 100);
    });
  });

  group('IdentityConstants', () {
    test('has correct key rotation interval', () {
      expect(IdentityConstants.keyRotationIntervalHours, 24);
    });

    test('has correct key lengths', () {
      expect(IdentityConstants.identityKeyLengthBytes, 32);
      expect(IdentityConstants.encryptionKeyLengthBytes, 32);
      expect(IdentityConstants.signatureKeyLengthBytes, 64);
    });

    test('has correct nonce and salt lengths', () {
      expect(IdentityConstants.nonceLength, 12);
      expect(IdentityConstants.saltLength, 16);
    });

    test('has avatar seed', () {
      expect(IdentityConstants.avatarSeed, 8);
    });
  });

  group('FeedConstants', () {
    test('has correct radius values', () {
      expect(FeedConstants.defaultRadiusMeters, 5000);
      expect(FeedConstants.maxRadiusMeters, 50000);
      expect(FeedConstants.minRadiusMeters, 100);
    });

    test('has correct post limits', () {
      expect(FeedConstants.maxPostLengthChars, 1000);
      expect(FeedConstants.maxMediaAttachments, 4);
      expect(FeedConstants.maxMediaSizeMb, 10);
    });

    test('has correct feed settings', () {
      expect(FeedConstants.trendingWindowHours, 24);
      expect(FeedConstants.maxFeedItems, 500);
    });

    test('weights sum to 1.0', () {
      final totalWeight =
          FeedConstants.proximityWeight +
          FeedConstants.recencyWeight +
          FeedConstants.propagationWeight;
      expect(totalWeight, 1.0);
    });
  });

  group('CommunityConstants', () {
    test('has correct member limits', () {
      expect(CommunityConstants.maxMembersPerGroup, 100);
    });

    test('has correct name/description limits', () {
      expect(CommunityConstants.maxGroupNameLength, 50);
      expect(CommunityConstants.maxGroupDescriptionLength, 500);
    });

    test('has correct join settings', () {
      expect(CommunityConstants.joinCodeLength, 8);
      expect(CommunityConstants.proximityJoinRadiusMeters, 50);
    });

    test('has correct voting duration', () {
      expect(CommunityConstants.votingDurationHours, 24);
    });
  });

  group('MeshConstants', () {
    test('has correct hop settings', () {
      expect(MeshConstants.maxHopCount, 7);
      expect(MeshConstants.defaultTtlHops, 3);
    });

    test('has correct packet settings', () {
      expect(MeshConstants.packetRetryCount, 3);
      expect(MeshConstants.packetRetryDelayMs, 500);
      expect(MeshConstants.maxPacketSizeBytes, 256);
      expect(MeshConstants.chunkSizeBytes, 200);
    });

    test('has correct discovery settings', () {
      expect(MeshConstants.discoveryIntervalSeconds, 30);
      expect(MeshConstants.presenceTimeoutSeconds, 300);
    });
  });

  group('UiConstants', () {
    test('has correct padding and radius values', () {
      expect(UiConstants.defaultPadding, 16.0);
      expect(UiConstants.cardBorderRadius, 16.0);
      expect(UiConstants.buttonBorderRadius, 12.0);
    });

    test('has correct avatar sizes', () {
      expect(UiConstants.avatarSizeSmall, 32.0);
      expect(UiConstants.avatarSizeMedium, 48.0);
      expect(UiConstants.avatarSizeLarge, 72.0);
    });

    test('has correct animation durations', () {
      expect(UiConstants.animationDurationMs, 200);
      expect(UiConstants.longAnimationDurationMs, 400);
    });
  });

  group('ContentTtl', () {
    test('has all expected values', () {
      expect(ContentTtl.values.length, 6);
    });

    test('oneHour has correct hours', () {
      expect(ContentTtl.oneHour.hours, 1);
      expect(ContentTtl.oneHour.displayName, '1 hour');
    });

    test('sixHours has correct hours', () {
      expect(ContentTtl.sixHours.hours, 6);
      expect(ContentTtl.sixHours.displayName, '6 hours');
    });

    test('oneDay has correct hours', () {
      expect(ContentTtl.oneDay.hours, 24);
      expect(ContentTtl.oneDay.displayName, '1 day');
    });

    test('threeDays has correct hours', () {
      expect(ContentTtl.threeDays.hours, 72);
      expect(ContentTtl.threeDays.displayName, '3 days');
    });

    test('oneWeek has correct hours', () {
      expect(ContentTtl.oneWeek.hours, 168);
      expect(ContentTtl.oneWeek.displayName, '1 week');
    });

    test('permanent has zero hours', () {
      expect(ContentTtl.permanent.hours, 0);
      expect(ContentTtl.permanent.displayName, 'Permanent');
    });
  });

  group('EncryptionLevel', () {
    test('has all expected values', () {
      expect(EncryptionLevel.values.length, 3);
    });

    test('none has zero key bytes', () {
      expect(EncryptionLevel.none.keyBytes, 0);
      expect(EncryptionLevel.none.name, 'None');
      expect(EncryptionLevel.none.description, 'No encryption');
    });

    test('basic has 16 key bytes', () {
      expect(EncryptionLevel.basic.keyBytes, 16);
      expect(EncryptionLevel.basic.name, 'Basic');
      expect(EncryptionLevel.basic.description, '128-bit encryption');
    });

    test('e2ee has 32 key bytes', () {
      expect(EncryptionLevel.e2ee.keyBytes, 32);
      expect(EncryptionLevel.e2ee.name, 'E2EE');
      expect(EncryptionLevel.e2ee.description, 'End-to-end encryption');
    });
  });

  group('NetworkMode', () {
    test('has all expected values', () {
      expect(NetworkMode.values.length, 3);
    });

    test('meshOnly has correct properties', () {
      expect(NetworkMode.meshOnly.displayName, 'Mesh Only');
      expect(
        NetworkMode.meshOnly.description,
        'Communication only via mesh network',
      );
    });

    test('internetOnly has correct properties', () {
      expect(NetworkMode.internetOnly.displayName, 'Internet Only');
      expect(
        NetworkMode.internetOnly.description,
        'Communication only via internet',
      );
    });

    test('hybrid has correct properties', () {
      expect(NetworkMode.hybrid.displayName, 'Hybrid');
      expect(NetworkMode.hybrid.description, 'Use both mesh and internet');
    });
  });

  group('PrivacyLevel', () {
    test('has all expected values', () {
      expect(PrivacyLevel.values.length, 4);
    });

    test('public has correct properties', () {
      expect(PrivacyLevel.public.displayName, 'Public');
      expect(PrivacyLevel.public.description, 'Visible to all nodes in radius');
    });

    test('friends has correct properties', () {
      expect(PrivacyLevel.friends.displayName, 'Friends');
      expect(
        PrivacyLevel.friends.description,
        'Visible to verified friends only',
      );
    });

    test('meshOnly has correct properties', () {
      expect(PrivacyLevel.meshOnly.displayName, 'Mesh Only');
      expect(PrivacyLevel.meshOnly.description, 'Never leaves mesh network');
    });

    test('private_ has correct properties', () {
      expect(PrivacyLevel.private_.displayName, 'Private');
      expect(PrivacyLevel.private_.description, 'End-to-end encrypted');
    });
  });
}
