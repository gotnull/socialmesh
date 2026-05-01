// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
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

  /// World Mesh API URL — nodes, stats, map.
  /// All APIs default to api.socialmesh.app (the unified API entry point).
  /// Override via .env for transitional Railway-direct routing.
  static String get worldMeshApiUrl =>
      dotenv.env['WORLD_MESH_API_URL'] ?? 'https://api.socialmesh.app';

  /// Sigil API URL — node identity card snapshots (NodeDex backend).
  /// Default: api.socialmesh.app. Override via .env to Railway domain
  /// until the API gateway is deployed.
  static String get sigilApiUrl =>
      dotenv.env['SIGIL_API_URL'] ?? 'https://api.socialmesh.app';

  /// Sigil API key (authenticates POST requests)
  static String get sigilApiKey => dotenv.env['SIGIL_API_KEY'] ?? '';

  /// Aether API URL — shared flight snapshots.
  /// Default: api.socialmesh.app. Override via .env to Railway domain
  /// until the API gateway is deployed.
  static String get aetherApiUrl =>
      dotenv.env['AETHER_API_URL'] ?? 'https://api.socialmesh.app';

  /// Aether API key (authenticates POST requests)
  static String get aetherApiKey => dotenv.env['AETHER_API_KEY'] ?? '';

  /// TAK Gateway URL — CoT event streaming.
  /// Default: tak.socialmesh.app (dedicated TAK subdomain).
  static String get takGatewayUrl =>
      dotenv.env['TAK_GATEWAY_URL'] ?? 'https://tak.socialmesh.app';

  /// NodeBoard API URL — personal BBS boards.
  /// Default: nodeboard.socialmesh.app (Nodeboard BBS)
  static String get nodeBoardApiUrl =>
      dotenv.env['NODEBOARD_API_URL'] ?? 'https://nodeboard.socialmesh.app';

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

  // Share link URLs — these point to public web portals, never API domains.
  // Portal domains (socialmesh.app/*) serve HTML; API domains serve JSON.
  static String shareSigilUrl(String id) => 'https://socialmesh.app/sigil/$id';
  static String shareFlightUrl(String id) =>
      'https://socialmesh.app/aether/flight/$id';
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
    try {
      final env = dotenv.env['NODEDEX_COSEEN_PAGE_SIZE'];
      if (env != null) {
        final parsed = int.tryParse(env);
        if (parsed != null && parsed > 0) return parsed;
      }
    } on Error {
      // dotenv not yet loaded (e.g. in unit tests).
    }
    return 20;
  }

  /// Number of recent encounters to display per page in the detail screen.
  /// Override via .env with NODEDEX_ENCOUNTER_PAGE_SIZE.
  static int get encounterPageSize {
    try {
      final env = dotenv.env['NODEDEX_ENCOUNTER_PAGE_SIZE'];
      if (env != null) {
        final parsed = int.tryParse(env);
        if (parsed != null && parsed > 0) return parsed;
      }
    } on Error {
      // dotenv not yet loaded (e.g. in unit tests).
    }
    return 10;
  }

  /// Number of activity timeline events to display per page.
  /// Override via .env with NODEDEX_TIMELINE_PAGE_SIZE.
  static int get timelinePageSize {
    try {
      final env = dotenv.env['NODEDEX_TIMELINE_PAGE_SIZE'];
      if (env != null) {
        final parsed = int.tryParse(env);
        if (parsed != null && parsed > 0) return parsed;
      }
    } on Error {
      // dotenv not yet loaded (e.g. in unit tests).
    }
    return 10;
  }
}

/// App-level feature flags read from `.env`.
///
/// These gate entire features that may be in testing or not yet released.
/// Default values are safe: features are disabled unless explicitly enabled.
class AppFeatureFlags {
  AppFeatureFlags._();

  /// Whether the Voice Messages feature is enabled.
  /// Set `VOICE_MESSAGES_ENABLED=true` in `.env` to enable.
  /// Default: false — experimental Codec2 voice messages are hidden.
  static bool get isVoiceMessagesEnabled {
    try {
      final raw = dotenv.env['VOICE_MESSAGES_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Device Shop feature is enabled.
  /// Set `DEVICE_SHOP_ENABLED=true` in `.env` to enable.
  /// Default: false — the device shop is hidden unless explicitly enabled.
  static bool get isDeviceShopEnabled {
    try {
      final raw = dotenv.env['DEVICE_SHOP_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the message timeline / week view is enabled.
  /// Set `MESSAGE_TIMELINE_ENABLED=true` in `.env` to enable.
  /// Default: false — the experimental message timeline is hidden.
  static bool get isMessageTimelineEnabled {
    try {
      final raw = dotenv.env['MESSAGE_TIMELINE_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the File Transfer feature is enabled.
  /// Set `FILE_TRANSFER_ENABLED=true` in `.env` to enable.
  /// Default: false — experimental mesh file transfer is hidden.
  static bool get isFileTransferEnabled {
    try {
      final raw = dotenv.env['FILE_TRANSFER_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Aether flight tracking feature is enabled.
  /// Set `AETHER_ENABLED=true` in `.env` to enable.
  static bool get isAetherEnabled {
    try {
      final raw = dotenv.env['AETHER_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the TAK Gateway feature is enabled.
  /// Set `TAK_GATEWAY_ENABLED=true` in `.env` to enable.
  /// Default: false — all TAK features are off unless explicitly enabled.
  static bool get isTakGatewayEnabled {
    try {
      final raw = dotenv.env['TAK_GATEWAY_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the TAK Mesh Bridge (on-device TAK server) is enabled.
  /// Set `TAK_MESH_BRIDGE_ENABLED=true` in `.env` to enable.
  /// Default: false — bridge functionality is off unless explicitly enabled.
  static bool get isTakMeshBridgeEnabled {
    try {
      final raw = dotenv.env['TAK_MESH_BRIDGE_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Social feature (stories, posts, profile social) is enabled.
  /// Set `SOCIAL_ENABLED=true` in `.env` to enable.
  /// Default: false — Social Hub is hidden unless explicitly enabled.
  static bool get isSocialEnabled {
    try {
      final raw = dotenv.env['SOCIAL_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Apple Wallet sigil card feature is enabled.
  /// Set `APPLE_WALLET_ENABLED=true` in `.env` to enable.
  /// Default: false — wallet button is hidden until the Sigil API
  /// wallet endpoint is production-ready.
  static bool get isAppleWalletEnabled {
    try {
      final raw = dotenv.env['APPLE_WALLET_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Shorthand that turns on every flag required for the SIP handshake
  /// + secure-DM stack: SIP, MRRP, and the three overlay flags (link,
  /// resource, secure). Set `HANDSHAKE_ENABLED=true` in `.env` to enable
  /// the whole stack with one switch instead of toggling each flag.
  ///
  /// The individual flags (`SIP_ENABLED`, `MRRP_ENABLED`,
  /// `OVERLAY_LINK_ENABLED`, `OVERLAY_RESOURCE_ENABLED`,
  /// `OVERLAY_SECURE_ENABLED`) still work independently — useful for
  /// testing partial stacks. This shorthand is OR'd in: if either the
  /// shorthand OR the granular flag is on, the feature is enabled.
  static bool get isHandshakeEnabled {
    try {
      final raw = dotenv.env['HANDSHAKE_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the SIP (Socialmesh Identity Protocol) feature is enabled.
  /// Set `SIP_ENABLED=true` (or `HANDSHAKE_ENABLED=true`) in `.env`.
  /// Default: false — SIP UI is hidden unless explicitly enabled.
  static bool get isSipEnabled {
    if (isHandshakeEnabled) return true;
    try {
      final raw = dotenv.env['SIP_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether TAK position publishing is enabled.
  /// Set `TAK_PUBLISH_ENABLED=true` in `.env` to enable.
  /// Requires [isTakGatewayEnabled] to be true. Default: false.
  static bool get isTakPublishEnabled {
    if (!isTakGatewayEnabled) return false;
    try {
      final raw = dotenv.env['TAK_PUBLISH_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether TAK video streaming is enabled.
  /// Set `TAK_VIDEO_ENABLED=true` in `.env` to enable.
  /// Requires [isTakGatewayEnabled] to be true. Default: false.
  static bool get isTakVideoEnabled {
    if (!isTakGatewayEnabled) return false;
    try {
      final raw = dotenv.env['TAK_VIDEO_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the MRRP (Mesh Request/Response Protocol) feature is enabled.
  /// Set `MRRP_ENABLED=true` (or `HANDSHAKE_ENABLED=true`) in `.env`.
  /// Requires [isSipEnabled] to be true. Default: false.
  static bool get isMrrpEnabled {
    if (!isSipEnabled) return false;
    if (isHandshakeEnabled) return true;
    try {
      final raw = dotenv.env['MRRP_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the MRRP protocol harness UI is enabled.
  /// Set `MRRP_HARNESS_ENABLED=true` in `.env` to enable.
  /// Requires [isMrrpEnabled] to be true. Default: false.
  static bool get isMrrpHarnessEnabled {
    if (!isMrrpEnabled) return false;
    try {
      final raw = dotenv.env['MRRP_HARNESS_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether mesh incident reporting over MRRP/SPP is enabled.
  /// Set `MESH_INCIDENTS_ENABLED=true` in `.env` to enable.
  /// Requires [isMrrpEnabled] to be true. Default: false.
  static bool get isMeshIncidentsEnabled {
    if (!isMrrpEnabled) return false;
    try {
      final raw = dotenv.env['MESH_INCIDENTS_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Translation Pack feature UI is enabled.
  /// Set `TRANSLATION_ENABLED=true` in `.env` to enable.
  /// Default: false — translation features are hidden until ready for release.
  static bool get isTranslationEnabled {
    try {
      final raw = dotenv.env['TRANSLATION_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the in-app language selector is shown in Appearance & Accessibility.
  /// Set `LANGUAGE_SELECTOR_ENABLED=true` in `.env` to enable.
  /// Default: false — translations are handled by the OS locale automatically.
  static bool get isLanguageSelectorEnabled {
    try {
      final raw = dotenv.env['LANGUAGE_SELECTOR_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Mesh Explorer public-facing discovery experience is enabled.
  /// Set `MESH_EXPLORER_ENABLED=true` in `.env` to enable.
  /// Requires both [isSipEnabled] and [isMrrpEnabled] to be true.
  /// Default: false.
  static bool get isMeshExplorerEnabled {
    if (!isSipEnabled || !isMrrpEnabled) return false;
    try {
      final raw = dotenv.env['MESH_EXPLORER_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Mesh Services (Create Service) feature is enabled.
  /// Set `MESH_SERVICES_ENABLED=true` in `.env` to enable.
  /// Requires both [isSipEnabled] and [isMrrpEnabled] to be true.
  /// Default: false.
  static bool get isMeshServicesEnabled {
    if (!isSipEnabled || !isMrrpEnabled) return false;
    try {
      final raw = dotenv.env['MESH_SERVICES_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the NodeBoard (personal BBS) feature is enabled.
  /// Set `NODEBOARD_ENABLED=true` in `.env` to enable.
  /// Default: false — NodeBoard UI is hidden until ready for release.
  static bool get isNodeBoardEnabled {
    try {
      final raw = dotenv.env['NODEBOARD_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Node Pet (procedural sigil creature) feature is enabled.
  /// Set `PET_ENABLED=true` in `.env` to enable.
  /// Default: false — owner pet UI is hidden behind the flag.
  static bool get isPetEnabled {
    try {
      final raw = dotenv.env['PET_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Mesh Feed (store-and-forward content feed) is enabled.
  /// Set `MESH_FEED_ENABLED=true` in `.env` to enable.
  /// Default: false — mesh feed UI is hidden until ready for release.
  static bool get isMeshFeedEnabled {
    try {
      final raw = dotenv.env['MESH_FEED_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Mesh Capacity Advisor drawer entry is enabled.
  /// Set `MESH_CAPACITY_ENABLED=true` in `.env` to expose the screen
  /// from the drawer. Default: false — feature is hidden until ready
  /// for release. The advisor's pure logic (snapshots, providers) is
  /// always available; this flag only controls the drawer surface.
  static bool get isMeshCapacityEnabled {
    try {
      final raw = dotenv.env['MESH_CAPACITY_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether opportunistic peer sync (LAN/BLE) is enabled.
  /// Set `OPPORTUNISTIC_SYNC_ENABLED=true` in `.env` to enable.
  /// Requires [isMeshFeedEnabled] to be true.
  /// Default: false — peer sync is off until protocol is validated.
  static bool get isOpportunisticSyncEnabled {
    if (!isMeshFeedEnabled) return false;
    try {
      final raw = dotenv.env['OPPORTUNISTIC_SYNC_ENABLED']
          ?.toLowerCase()
          .trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether Meshtastic RF transport for mesh feed posts is enabled.
  /// Set `MESH_FEED_RF_ENABLED=true` in `.env` to enable.
  /// Requires [isMeshFeedEnabled] to be true.
  /// Default: true when mesh feed is enabled — RF is the primary transport.
  static bool get isMeshFeedRfEnabled {
    if (!isMeshFeedEnabled) return false;
    try {
      final raw = dotenv.env['MESH_FEED_RF_ENABLED']?.toLowerCase().trim();
      // Default to true when mesh feed is enabled — RF is the canonical
      // transport. The flag exists to allow disabling RF in isolation
      // (e.g. during LAN-only testing).
      if (raw == null) return true;
      return raw == 'true' || raw == '1';
    } catch (_) {
      return true;
    }
  }

  /// Whether the Reticulum Tunnel (Meshtastic portnum 76) UI is enabled.
  /// Set `RETICULUM_TUNNEL_ENABLED=true` in `.env` to enable.
  /// Default: false — the Settings tile, NodeDex `RNS` activity badge,
  /// and NodeDex detail "RNS fragments" card are all hidden. The
  /// background protocol-service hook + Phase 1 pipeline still observe
  /// port-76 traffic regardless; this flag only gates user-facing UI.
  static bool get isReticulumTunnelEnabled {
    try {
      final raw = dotenv.env['RETICULUM_TUNNEL_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
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

/// Constants governing the DM confirmation-timeout and bounded auto-retry
/// feature.  Centralised here so they are easy to adjust without hunting
/// through UI code.
class DmRetryConstants {
  DmRetryConstants._();

  /// A sent DM with no ACK after this duration transitions from "Sent to
  /// radio" → "Unconfirmed".
  ///
  /// Rationale: Meshtastic firmware retransmits up to ~5× over ~15–30 s.
  /// Five minutes gives ample time for the packet to traverse the mesh and
  /// for the radio's own firmware-level retry mechanism to complete.
  static const Duration ackTimeout = Duration(minutes: 5);

  /// Fixed interval between auto-retry attempts.
  static const Duration retryInterval = Duration(seconds: 60);

  /// Maximum number of auto-retry attempts before the coordinator gives up
  /// and leaves the message in the Unconfirmed state.
  static const int maxAutoRetries = 5;

  /// Auto-retry stops after this window measured from the first send time,
  /// regardless of [maxAutoRetries].
  static const Duration autoRetryWindow = Duration(minutes: 10);

  /// How often the retry coordinator polls for timed-out / unconfirmed
  /// messages.  Short enough to notice timeouts promptly; long enough to
  /// be negligible on battery.
  static const Duration coordinatorTickInterval = Duration(seconds: 15);
}
