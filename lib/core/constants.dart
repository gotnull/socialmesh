// SPDX-License-Identifier: GPL-3.0-or-later
/// Application constants and configuration values
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App URLs - centralized URL management
/// Use .env for overrides in development/staging
class AppUrls {
  AppUrls._();

  /// Base website URL
  static String get baseUrl =>
      dotenv.env['APP_BASE_URL'] ?? 'https://socialmesh.app';

  /// Cloud Functions base URL
  static String get cloudFunctionsUrl =>
      dotenv.env['CLOUD_FUNCTIONS_URL'] ??
      'https://us-central1-social-mesh-app.cloudfunctions.net';

  /// World Mesh API URL
  static String get worldMeshApiUrl =>
      dotenv.env['WORLD_MESH_API_URL'] ?? 'https://api.socialmesh.app';

  /// Sigil API URL (Railway-hosted, custom domain)
  static String get sigilApiUrl =>
      dotenv.env['SIGIL_API_URL'] ?? 'https://sigil.socialmesh.app';

  /// Sigil API key (authenticates POST requests)
  static String get sigilApiKey => dotenv.env['SIGIL_API_KEY'] ?? '';

  // Legal & Documentation URLs
  static String get termsUrl => '$baseUrl/terms';
  static String get privacyUrl => '$baseUrl/privacy';
  static String get supportUrl => '$baseUrl/support';
  static String get docsUrl => '$baseUrl/docs';
  static String get faqUrl => '$baseUrl/faq';
  static String get deleteAccountUrl => '$baseUrl/delete-account';

  // In-app versions (hide navigation when viewed in webview)
  static String get termsUrlInApp => '$baseUrl/terms?inapp=true';
  static String get privacyUrlInApp => '$baseUrl/privacy?inapp=true';

  // In-app versions with section anchor for deep linking to specific sections
  static String termsUrlInAppWithSection(String anchor) =>
      '$baseUrl/terms?inapp=true#$anchor';
  static String privacyUrlInAppWithSection(String anchor) =>
      '$baseUrl/privacy?inapp=true#$anchor';
  static String get supportUrlInApp => '$baseUrl/support?inapp=true';
  static String get docsUrlInApp => '$baseUrl/docs?inapp=true';
  static String get faqUrlInApp => '$baseUrl/faq?inapp=true';
  static String get deleteAccountUrlInApp =>
      '$baseUrl/delete-account?inapp=true';

  // Share link URLs
  static String shareSigilUrl(String id) => '$baseUrl/sigil/$id';
  static String shareNodeUrl(String id) => '$baseUrl/share/node/$id';
  static String shareProfileUrl(String id) => '$baseUrl/share/profile/$id';
  static String shareWidgetUrl(String id) => '$baseUrl/share/widget/$id';
  static String shareChannelUrl(String id) => '$baseUrl/share/channel/$id';
  static String sharePostUrl(String id) => '$baseUrl/share/post/$id';
  static String shareAutomationUrl(String id) =>
      '$baseUrl/share/automation/$id';
  static String shareLocationUrl(double lat, double lng, {String? label}) {
    final params =
        'lat=$lat&lng=$lng${label != null ? '&label=${Uri.encodeComponent(label)}' : ''}';
    return '$baseUrl/share/location?$params';
  }

  // App Store URLs
  static String get appStoreUrl =>
      dotenv.env['APP_STORE_URL'] ?? 'https://apps.apple.com/app/id6742694642';

  static String get playStoreUrl =>
      dotenv.env['PLAY_STORE_URL'] ??
      'https://play.google.com/store/apps/details?id=com.gotnull.socialmesh';

  // App identifiers
  static const String iosAppId = '6739187207';
  static const String androidPackage = 'com.gotnull.socialmesh';
  static const String deepLinkScheme = 'socialmesh';
}

/// Database and storage constants
class StorageConstants {
  static const String databaseName = 'socialmesh.db';
  static const int databaseVersion = 1;
  static const int maxCacheSizeMb = 500;
  static const int defaultMessageTtlHours = 72;
  static const int maxOfflineQueueSize = 100;
}

/// Identity and cryptography constants
class IdentityConstants {
  static const int keyRotationIntervalHours = 24;
  static const int identityKeyLengthBytes = 32;
  static const int encryptionKeyLengthBytes = 32;
  static const int signatureKeyLengthBytes = 64;
  static const int nonceLength = 12;
  static const int saltLength = 16;
  static const int avatarSeed = 8;
}

/// Feed and content constants
class FeedConstants {
  static const int defaultRadiusMeters = 5000;
  static const int maxRadiusMeters = 50000;
  static const int minRadiusMeters = 100;
  static const int maxPostLengthChars = 1000;
  static const int maxMediaAttachments = 4;
  static const int maxMediaSizeMb = 10;
  static const int trendingWindowHours = 24;
  static const int maxFeedItems = 500;
  static const double proximityWeight = 0.4;
  static const double recencyWeight = 0.35;
  static const double propagationWeight = 0.25;
}

/// Community constants
class CommunityConstants {
  static const int maxMembersPerGroup = 100;
  static const int maxGroupNameLength = 50;
  static const int maxGroupDescriptionLength = 500;
  static const int joinCodeLength = 8;
  static const int proximityJoinRadiusMeters = 50;
  static const int votingDurationHours = 24;
}

/// Mesh networking constants
class MeshConstants {
  static const int maxHopCount = 7;
  static const int defaultTtlHops = 3;
  static const int packetRetryCount = 3;
  static const int packetRetryDelayMs = 500;
  static const int maxPacketSizeBytes = 256;
  static const int chunkSizeBytes = 200;
  static const int discoveryIntervalSeconds = 30;
  static const int presenceTimeoutSeconds = 300;
}

/// UI constants
class UiConstants {
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double avatarSizeSmall = 32.0;
  static const double avatarSizeMedium = 48.0;
  static const double avatarSizeLarge = 72.0;
  static const int animationDurationMs = 200;
  static const int longAnimationDurationMs = 400;
}

/// Asset paths
class AssetPaths {
  static const String appIcon =
      'assets/app_icons/source/socialmesh_icon_1024.png';
}

/// TTL presets for ephemeral content
enum ContentTtl {
  oneHour(1, '1 hour'),
  sixHours(6, '6 hours'),
  oneDay(24, '1 day'),
  threeDays(72, '3 days'),
  oneWeek(168, '1 week'),
  permanent(0, 'Permanent');

  final int hours;
  final String displayName;
  const ContentTtl(this.hours, this.displayName);
}

/// Encryption strength levels
enum EncryptionLevel {
  none(0, 'None', 'No encryption'),
  basic(16, 'Basic', '128-bit encryption'),
  e2ee(32, 'E2EE', 'End-to-end encryption');

  final int keyBytes;
  final String name;
  final String description;
  const EncryptionLevel(this.keyBytes, this.name, this.description);
}

/// Network mode configuration
enum NetworkMode {
  meshOnly('Mesh Only', 'Communication only via mesh network'),
  internetOnly('Internet Only', 'Communication only via internet'),
  hybrid('Hybrid', 'Use both mesh and internet');

  final String displayName;
  final String description;
  const NetworkMode(this.displayName, this.description);
}

/// NodeDex feature configuration
class NodeDexConfig {
  NodeDexConfig._();

  /// Number of co-seen nodes to display per page in the detail screen.
  /// Override via .env with NODEDEX_COSEEN_PAGE_SIZE.
  static int get coSeenPageSize {
    final env = dotenv.env['NODEDEX_COSEEN_PAGE_SIZE'];
    if (env != null) {
      final parsed = int.tryParse(env);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 20;
  }

  /// Number of recent encounters to display per page in the detail screen.
  /// Override via .env with NODEDEX_ENCOUNTER_PAGE_SIZE.
  static int get encounterPageSize {
    final env = dotenv.env['NODEDEX_ENCOUNTER_PAGE_SIZE'];
    if (env != null) {
      final parsed = int.tryParse(env);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 10;
  }
}

/// Privacy level for content visibility
enum PrivacyLevel {
  public('Public', 'Visible to all nodes in radius'),
  friends('Friends', 'Visible to verified friends only'),
  meshOnly('Mesh Only', 'Never leaves mesh network'),
  private_('Private', 'End-to-end encrypted');

  final String displayName;
  final String description;
  const PrivacyLevel(this.displayName, this.description);
}
