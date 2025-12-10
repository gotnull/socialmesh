/// Application constants and configuration values
library;

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
