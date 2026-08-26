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

  /// Mapbox public access token (`pk.*`) used for raster Static Tiles API
  /// requests. Empty when not configured; callers must check before using.
  static String get mapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  /// MapTiler API key used for the terrain basemap's `@2x` raster tiles.
  /// Empty when not configured; callers fall back to OpenTopoMap. Guarded on
  /// `isInitialized` because `MapConfig.isMaptilerActive` reads this directly
  /// (no feature-flag short-circuit) and would otherwise throw in unit tests
  /// where dotenv is never loaded.
  static String get maptilerToken =>
      dotenv.isInitialized ? (dotenv.env['MAPTILER_TOKEN'] ?? '') : '';

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

  /// Whether per-packet node updates coalesce into one state emission
  /// per short window. Structural events (new node, own node, position
  /// change) always flush synchronously, so discovery and map latency
  /// are unchanged; only lastHeard/RSSI/telemetry churn coalesces.
  /// Default: true. Set `NODE_EMISSION_COALESCING_ENABLED=false` in
  /// `.env` (or flip remotely) to restore per-event emission verbatim.
  static bool get isNodeEmissionCoalescingEnabled {
    try {
      final raw = dotenv.env['NODE_EMISSION_COALESCING_ENABLED']
          ?.toLowerCase()
          .trim();
      return raw != 'false' && raw != '0';
    } catch (_) {
      return true;
    }
  }

  /// Whether the MQTT client-proxy liveness watchdog is active. When on, the
  /// proxy tracks an independent proof-of-life (PINGRESP, inbound traffic, or
  /// a fresh connect) and force-reconnects a socket that goes silent past the
  /// stale threshold — recovering the half-open case the package's keep-alive
  /// stays blind to. Default: true. Set `MQTT_PROXY_LIVENESS_WATCHDOG_ENABLED=false`
  /// in `.env` (or flip remotely) to restore package-keep-alive-only behaviour.
  static bool get isMqttProxyLivenessWatchdogEnabled {
    try {
      final raw = dotenv.env['MQTT_PROXY_LIVENESS_WATCHDOG_ENABLED']
          ?.toLowerCase()
          .trim();
      return raw != 'false' && raw != '0';
    } catch (_) {
      return true;
    }
  }

  /// Whether Core Bluetooth state restoration is requested at boot (iOS and
  /// macOS; no effect on Android). When on, the OS relaunches the app in the
  /// background after a memory-pressure kill as soon as the connected radio
  /// delivers a BLE event, so the session re-attaches before the user
  /// returns to the app. Read once at boot before the first
  /// flutter_blue_plus call; changing it takes effect on the next launch.
  /// Default: true. Set `BLE_STATE_RESTORATION_ENABLED=false` in `.env` to
  /// fall back to foreground-only reconnects.
  static bool get isBleStateRestorationEnabled {
    try {
      final raw = dotenv.env['BLE_STATE_RESTORATION_ENABLED']
          ?.toLowerCase()
          .trim();
      return raw != 'false' && raw != '0';
    } catch (_) {
      return true;
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

  /// Whether MeshCore radios are surfaced alongside Meshtastic in the
  /// default BLE scanner filter. Set `MESHCORE_ENABLED=true` in `.env`.
  /// Default: false — the scanner only matches the Meshtastic service UUID.
  static bool get isMeshCoreEnabled {
    try {
      final raw = dotenv.env['MESHCORE_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether map tiles route to Mapbox instead of CARTO + Esri + OpenTopoMap.
  /// Effective only when `MAPBOX_TOKEN` is also set (callers re-check via
  /// `MapConfig.isMapboxActive`). Set `MAPBOX_ENABLED=true` in `.env`.
  /// Default: false — the base experience uses the existing tile providers.
  static bool get isMapboxEnabled {
    try {
      final raw = dotenv.env['MAPBOX_ENABLED']?.toLowerCase().trim();
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

  /// Whether the Operations participation objectives feature is enabled.
  /// Set `OPERATIONS_ENABLED=true` in `.env` to enable.
  /// Default: false — the Operations surface is hidden until explicitly
  /// enabled. Operations observe existing app state passively and never
  /// add RF traffic, but the UI is gated while v1 stabilizes.
  static bool get isOperationsEnabled {
    try {
      final raw = dotenv.env['OPERATIONS_ENABLED']?.toLowerCase().trim();
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

  /// Whether the per-node NodeDex Constellation view is reachable.
  /// Set `NODEDEX_CONSTELLATION_ENABLED=true` in `.env` to expose the
  /// Constellation app-bar icon on the NodeDex detail screen.
  /// Default: false — the feature is dormant pending UX iteration.
  static bool get isNodeDexConstellationEnabled {
    try {
      final raw = dotenv.env['NODEDEX_CONSTELLATION_ENABLED']
          ?.toLowerCase()
          .trim();
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
  /// Default: false - wallet button is hidden until the Sigil API
  /// wallet endpoint is production-ready.
  static bool get isAppleWalletEnabled {
    try {
      final raw = dotenv.env['APPLE_WALLET_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether group / community licensing groundwork is active.
  /// Set `GROUP_LICENSING_ENABLED=true` in `.env` to enable.
  /// Default: false. With the flag off, [currentUserLicenseOrgIdsProvider]
  /// always yields an empty set even for signed-in users. This gate
  /// fronts every future surface (license-org membership reads, seat
  /// allocation, org-pack purchases) so a partial roll-out cannot
  /// silently surface incomplete features. See
  /// `docs/engineering/GROUP_LICENSING_FOUNDATION.md`.
  static bool get isGroupLicensingEnabled {
    try {
      final raw = dotenv.env['GROUP_LICENSING_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Community Pack entry-point card on the Premium screen
  /// is visible. Set `COMMUNITY_PACK_ENABLED=true` in `.env` to enable.
  /// Default: false. The card surfaces two pack tiles (Community Pack
  /// 10 / 20) that launch the existing org checkout sheet. Default off
  /// until the corresponding Stripe SKUs (`community_pack_10`,
  /// `community_pack_20`) are live on the backend, so the tap cannot
  /// land on a broken checkout. When this flag is on, the legacy
  /// "Buy a group license" tile in the Group Licensing section is
  /// hidden to avoid a redundant purchase path.
  static bool get isCommunityPackEnabled {
    try {
      final raw = dotenv.env['COMMUNITY_PACK_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Teams product surface is visible.
  /// Set `TEAMS_ENABLED=true` in `.env` to enable.
  /// Default: false.
  ///
  /// Product VISIBILITY only - it decides whether the Teams entry point
  /// exists, never who may read or write organisation data. Membership
  /// is authorised by `firestore.rules`; this flag is not an
  /// authorisation boundary and the client owns it.
  static bool get isTeamsEnabled {
    try {
      final raw = dotenv.env['TEAMS_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the Teams fleet inventory is active.
  /// Set `LICENSE_ORG_FLEET_ENABLED=true` in `.env` to enable.
  /// Default: false. With the flag off, `licenseOrgFleetProvider` always
  /// yields an empty snapshot and the local cache is never consulted,
  /// so a partial roll-out cannot surface an incomplete surface.
  ///
  /// This is a CLIENT gate only. It is never an authorisation boundary -
  /// fleet reads are authorised by `firestore.rules` and fleet writes by
  /// the Admin-SDK callables, neither of which consults this flag.
  /// See docs/teams/PHASE-1-DESIGN.md.
  static bool get isLicenseOrgFleetEnabled {
    try {
      final raw = dotenv.env['LICENSE_ORG_FLEET_ENABLED']?.toLowerCase().trim();
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

  /// Whether the MeshCanvas feature is enabled.
  ///
  /// Set `MESH_CANVAS_ENABLED=true` in `.env` to enable. Default: false
  /// (drawer entry hidden, inbound frames still demuxed by
  /// `ProtocolService` but apply path is a no-op). MeshCanvas v0.1 is
  /// Meshtastic-only; the drawer tile NEVER appears in the MeshCore
  /// shell regardless of this flag.
  static bool get isMeshCanvasEnabled {
    try {
      final raw = dotenv.env['MESH_CANVAS_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// Whether the SIP (SocialMesh Identity Protocol) feature is enabled.
  /// Set `SIP_ENABLED=true` (or `HANDSHAKE_ENABLED=true`) in `.env`.
  /// Default: false — SIP UI is hidden unless explicitly enabled.
  ///
  /// MeshCanvas frames ride SIP-wrapped MRRP, so [isMeshCanvasEnabled]
  /// also implicitly enables SIP. The handshake/secure-DM surfaces
  /// stay off unless `HANDSHAKE_ENABLED=true`; only the wire transport
  /// turns on.
  static bool get isSipEnabled {
    if (isHandshakeEnabled) return true;
    if (isMeshCanvasEnabled) return true;
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
  ///
  /// MeshCanvas rides MRRP, so [isMeshCanvasEnabled] also implicitly
  /// enables it. Same scope rule as [isSipEnabled]: only the wire
  /// transport turns on; harness UI / handshake-only surfaces stay
  /// gated on their own flags.
  static bool get isMrrpEnabled {
    if (!isSipEnabled) return false;
    if (isHandshakeEnabled) return true;
    if (isMeshCanvasEnabled) return true;
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

  /// Whether the Incident Mode "Help Request" workflow (personal SOS over
  /// the unified incident.v1 envelope, SPP type 0x13) is enabled.
  /// Set `INCIDENT_HELP_REQUEST_ENABLED=true` in `.env` to enable.
  ///
  /// Workflow subflag beneath the unified incident layer: requires
  /// [isMeshIncidentsEnabled] (the master flag). Default: false. The
  /// hazard_report workflow stays on its existing path regardless of this
  /// flag. See docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md §11.
  static bool get isIncidentHelpRequestEnabled {
    if (!isMeshIncidentsEnabled) return false;
    try {
      final raw = dotenv.env['INCIDENT_HELP_REQUEST_ENABLED']
          ?.toLowerCase()
          .trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  /// D33: gate the MeshCore reply UI + send path.
  ///
  /// Set `MESHCORE_REPLIES_ENABLED=true` in `.env` to enable.
  /// Default: false. Read at every chat-screen build, so toggling
  /// requires a process restart.
  ///
  /// What this flag gates:
  ///   - Long-press "Reply" menu action (hidden when OFF).
  ///   - Composer reply state and `sendReply` API (blocked when OFF).
  ///
  /// What this flag does NOT gate:
  ///   - Inbound reply envelope parsing (always-on so a flag flip
  ///     mid-conversation doesn't make existing reply bubbles render
  ///     as raw envelope text).
  ///   - Existing plain-text send (untouched).
  ///
  /// Spec: `docs/protocol/MESHCORE_REPLIES_D33_IMPLEMENTATION_PLAN.md`
  /// §4.
  static bool get enableMeshCoreReplies {
    try {
      final raw = dotenv.env['MESHCORE_REPLIES_ENABLED']?.toLowerCase().trim();
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

  // Whether the Stripe Checkout external purchase path is enabled.
  //
  // Stripe is the primary external (off-store) purchase path for
  // unlocking packs when App Store / Play Store IAP is unavailable or
  // unreliable, so it is ON by default and needs no `.env` entry. Set
  // `STRIPE_PURCHASES_ENABLED=false` in `.env` (or via the remote-flag
  // overlay) to kill the Stripe handoff sheet + the createCheckout call
  // when `provider=stripe`. Only the literal value `false`
  // (case-insensitive, trimmed) disables; a missing or unparseable
  // value stays enabled (opt-out, not opt-in).
  static bool get isStripePurchasesEnabled {
    try {
      final raw = dotenv.env['STRIPE_PURCHASES_ENABLED']?.trim().toLowerCase();
      return raw != 'false';
    } catch (_) {
      return true;
    }
  }

  // Whether the Buy Me a Coffee external purchase path is enabled.
  //
  // Set `BMC_PURCHASE_ENABLED=true` in `.env` to enable. Default:
  // false. BMC is kept as a secondary external path (and eventual
  // tipping surface). The BMC handoff sheet, reference-code copy,
  // and createCheckout call when `provider=buymeacoffee` are all
  // gated on this flag.
  static bool get isBuyMeACoffeeEnabled {
    try {
      final raw = dotenv.env['BMC_PURCHASE_ENABLED']?.toLowerCase().trim();
      return raw == 'true' || raw == '1';
    } catch (_) {
      return false;
    }
  }

  // Shorthand: any external (off-store) purchase provider is enabled.
  //
  // Gates the surfaces that are agnostic to which provider is live:
  //   - The "Alternative payment" container on pack tiles (the inner
  //     button picks Stripe vs BMC based on which flag is on)
  //   - The "Have an unlock code?" support fallback link
  //   - `socialmesh://purchase-return` deep-link dispatch
  //   - `PurchaseStateNotifier`'s external entitlement merge
  //
  // Stays on when either provider's flag is on. With both off, every
  // external surface is invisible and `getExternalEntitlements` is
  // never called.
  static bool get isExternalPurchaseEnabled =>
      isStripePurchasesEnabled || isBuyMeACoffeeEnabled;

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
