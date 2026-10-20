// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Constants for the Global Layer (MQTT) feature.
///
/// All magic numbers, default values, and preset configurations
/// are centralized here to avoid hardcoding across the module.
library;

import '../../l10n/app_localizations.dart';

/// Network and connection constants for the Global Layer.
class GlobalLayerConstants {
  GlobalLayerConstants._();

  // ---------------------------------------------------------------------------
  // Connection defaults
  // ---------------------------------------------------------------------------

  /// Default MQTT broker port (unencrypted).
  static const int defaultPort = 1883;

  /// Default MQTT broker port with TLS.
  static const int defaultTlsPort = 8883;

  /// Default MQTT keep-alive interval in seconds.
  static const int keepAliveSeconds = 60;

  /// Maximum time to wait for a connection attempt before timing out.
  static const Duration connectionTimeout = Duration(seconds: 15);

  /// Maximum time to wait for a single diagnostic check.
  static const Duration diagnosticStepTimeout = Duration(seconds: 10);

  /// Delay before the first automatic reconnection attempt.
  static const Duration reconnectBaseDelay = Duration(seconds: 2);

  /// Maximum delay between reconnection attempts (exponential backoff cap).
  static const Duration reconnectMaxDelay = Duration(seconds: 60);

  /// Number of consecutive failures before marking the connection as degraded.
  static const int degradedThreshold = 3;

  /// Maximum number of automatic reconnection attempts before giving up.
  static const int maxReconnectAttempts = 10;

  /// MQTT protocol version used by the client.
  static const int mqttProtocolVersion = 4; // MQTT 3.1.1

  // ---------------------------------------------------------------------------
  // Topic builder
  // ---------------------------------------------------------------------------

  /// Default topic root when the user has not configured one.
  static const String defaultTopicRoot = 'msh';

  /// Separator character for MQTT topic levels.
  static const String topicSeparator = '/';

  /// MQTT single-level wildcard.
  static const String singleLevelWildcard = '+';

  /// MQTT multi-level wildcard.
  static const String multiLevelWildcard = '#';

  /// Maximum length for a user-defined topic root.
  static const int maxTopicRootLength = 64;

  /// Maximum length for a fully-assembled topic string.
  static const int maxTopicLength = 256;

  /// Suffix appended during connection testing to avoid polluting real topics.
  static const String testTopicSuffix = '/\$test';

  // ---------------------------------------------------------------------------
  // Privacy & safety defaults
  // ---------------------------------------------------------------------------

  /// Whether outbound message sharing is enabled by default. Always OFF.
  static const bool defaultShareMessages = false;

  /// Whether telemetry sharing is enabled by default. Always OFF.
  static const bool defaultShareTelemetry = false;

  /// Whether inbound global chat is accepted by default. Always OFF.
  static const bool defaultAllowInboundGlobal = false;

  // ---------------------------------------------------------------------------
  // Metrics & monitoring
  // ---------------------------------------------------------------------------

  /// Rolling window for throughput rate calculation.
  static const Duration metricsWindow = Duration(minutes: 5);

  /// How often to refresh health metrics in the status panel.
  static const Duration metricsRefreshInterval = Duration(seconds: 10);

  /// Maximum number of recent errors to retain in the diagnostics log.
  static const int maxRecentErrors = 50;

  /// Maximum number of throughput samples to retain.
  static const int maxThroughputSamples = 60;

  // ---------------------------------------------------------------------------
  // Secure storage keys
  // ---------------------------------------------------------------------------

  /// Prefix for all Global Layer secure storage entries.
  static const String secureStoragePrefix = 'global_layer_';

  /// Key for the broker password in secure storage.
  static const String passwordStorageKey = '${secureStoragePrefix}password';

  /// Key for the serialized config (minus secrets) in shared preferences.
  static const String configPrefsKey = '${secureStoragePrefix}config';

  /// Key for the "setup completed" flag in shared preferences.
  static const String setupCompleteKey = '${secureStoragePrefix}setup_complete';

  /// Key for the "first viewed" flag (controls NEW badge in drawer).
  static const String firstViewedKey = '${secureStoragePrefix}first_viewed';

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  /// Label shown in the drawer and settings for this feature.
  static const String featureLabel =
      'Global Layer'; // lint-allow: hardcoded-string

  /// Short description for onboarding / tooltips.
  static const String featureTagline =
      'Connect your local mesh to the wider world'; // lint-allow: hardcoded-string

  /// Badge key for What\'s New integration.
  static const String whatsNewBadgeKey = 'global_layer';

  /// Maximum number of topic subscriptions shown in the explorer before
  /// paging.
  static const int topicExplorerPageSize = 20;
}

/// Preset broker configurations that users can choose from during setup.
///
/// These are provided as starting points only - every field is editable
/// after selection. The presets give new users a working starting point
/// without needing to know what MQTT is or how to find a broker.
class BrokerPreset {
  /// Human-readable name for the preset.
  final String name;

  /// Brief explanation of what this preset is for.
  final String description;

  /// Broker hostname or IP address.
  final String host;

  /// Broker port.
  final int port;

  /// Whether TLS should be enabled.
  final bool useTls;

  /// Whether authentication is typically required.
  final bool requiresAuth;

  /// Default username for this broker (empty if anonymous).
  final String defaultUsername;

  /// Default password for this broker (empty if anonymous).
  ///
  /// Public brokers that publish their credentials openly (e.g. the
  /// official Meshtastic MQTT server) have them listed here. These
  /// are NOT secrets - they are documented in the Meshtastic project.
  final String defaultPassword;

  /// Suggested topic root for this broker.
  final String suggestedRoot;

  /// Material icon name to display in the picker.
  final String iconName;

  /// Whether this is the manual/custom entry option.
  final bool isCustom;

  /// Optional note shown below the preset in the picker (e.g. uptime
  /// caveats, regional info).
  final String? note;

  const BrokerPreset({
    required this.name,
    required this.description,
    required this.host,
    required this.port,
    required this.useTls,
    required this.requiresAuth,
    this.defaultUsername = '',
    this.defaultPassword = '',
    required this.suggestedRoot,
    this.iconName = 'dns_outlined',
    this.isCustom = false,
    this.note,
  });

  /// Localised name for this preset, resolved by [host].
  String localizedName(AppLocalizations l10n) => switch (host) {
    'mqtt.meshtastic.org' => l10n.mqttBrokerMeshtasticName,
    'test.mosquitto.org' => l10n.mqttBrokerMosquittoName,
    '' => l10n.mqttBrokerCustomName,
    _ => name,
  };

  /// Localised description for this preset, resolved by [host].
  String localizedDescription(AppLocalizations l10n) => switch (host) {
    'mqtt.meshtastic.org' => l10n.mqttBrokerMeshtasticDescription,
    'test.mosquitto.org' => l10n.mqttBrokerMosquittoDescription,
    '' => l10n.mqttBrokerCustomDescription,
    _ => description,
  };

  /// Localised note for this preset, resolved by [host].
  String? localizedNote(AppLocalizations l10n) {
    if (note == null) return null;
    return switch (host) {
      'mqtt.meshtastic.org' => l10n.mqttBrokerMeshtasticNote,
      'test.mosquitto.org' => l10n.mqttBrokerMosquittoNote,
      _ => note,
    };
  }

  /// Whether this preset provides default credentials.
  bool get hasDefaultCredentials =>
      defaultUsername.isNotEmpty && defaultPassword.isNotEmpty;

  /// Built-in presets. Users can always override every field.
  ///
  /// Order matters - the first non-custom preset is the recommended
  /// default for new users.
  static const List<BrokerPreset> defaults = [
    // ------------------------------------------------------------------
    // Official Meshtastic MQTT server
    // ------------------------------------------------------------------
    BrokerPreset(
      name: 'Meshtastic (Official)',
      description:
          'The default Meshtastic MQTT server. Connects you to the ' // lint-allow: hardcoded-string
          'worldwide Meshtastic mesh network. No account needed.', // lint-allow: hardcoded-string
      host: 'mqtt.meshtastic.org',
      port: GlobalLayerConstants.defaultTlsPort,
      useTls: true,
      requiresAuth: true,
      defaultUsername: 'meshdev',
      defaultPassword: 'large4cats',
      suggestedRoot: GlobalLayerConstants.defaultTopicRoot,
      iconName: 'cell_tower',
      note: 'Public credentials are shared by all Meshtastic users.',
    ),
    // ------------------------------------------------------------------
    // Mosquitto test broker (useful for testing / development)
    // ------------------------------------------------------------------
    BrokerPreset(
      name: 'Mosquitto Test',
      description:
          'A free public test broker run by the Eclipse Mosquitto ' // lint-allow: hardcoded-string
          'project. Good for testing your setup before connecting ' // lint-allow: hardcoded-string
          'to a production broker.', // lint-allow: hardcoded-string
      host: 'test.mosquitto.org',
      port: GlobalLayerConstants.defaultTlsPort,
      useTls: true,
      requiresAuth: false,
      suggestedRoot: GlobalLayerConstants.defaultTopicRoot,
      iconName: 'science_outlined',
      note: 'Test broker - not for production use. May have downtime.',
    ),
    // ------------------------------------------------------------------
    // Custom / manual entry
    // ------------------------------------------------------------------
    BrokerPreset(
      name: 'Custom Broker',
      description: 'Enter your own broker details manually.', // lint-allow: hardcoded-string
      host: '',
      port: GlobalLayerConstants.defaultTlsPort,
      useTls: true,
      requiresAuth: false,
      suggestedRoot: GlobalLayerConstants.defaultTopicRoot,
      iconName: 'tune',
      isCustom: true,
    ),
  ];
}

/// Topic template definitions for the Topic Builder UI.
///
/// Each template describes a category of MQTT topic with placeholder
/// segments that the builder fills in from user config and device info.
class TopicTemplate {
  /// Human-readable label (e.g. "Chat messages").
  final String label;

  /// Icon name from Material Icons to display in the UI.
  final String iconName;

  /// Brief description of what this topic carries.
  final String description;

  /// Pattern with placeholders: {root}, {channel}, {nodeId}.
  final String pattern;

  /// Whether this template is enabled by default in new setups.
  final bool enabledByDefault;

  const TopicTemplate({
    required this.label,
    required this.iconName,
    required this.description,
    required this.pattern,
    this.enabledByDefault = false,
  });

  /// Localised label for this template, resolved by [pattern].
  String localizedLabel(AppLocalizations l10n) => switch (pattern) {
    '{root}/chat/{channel}' => l10n.mqttTopicChatLabel,
    '{root}/telemetry/{nodeId}' => l10n.mqttTopicTelemetryLabel,
    '{root}/position/{nodeId}' => l10n.mqttTopicPositionLabel,
    '{root}/nodeinfo/{nodeId}' => l10n.mqttTopicNodeInfoLabel,
    '{root}/map/{nodeId}' => l10n.mqttTopicMapReportsLabel,
    _ => label,
  };

  /// Localised description for this template, resolved by [pattern].
  String localizedDescription(AppLocalizations l10n) => switch (pattern) {
    '{root}/chat/{channel}' => l10n.mqttTopicChatDescription,
    '{root}/telemetry/{nodeId}' => l10n.mqttTopicTelemetryDescription,
    '{root}/position/{nodeId}' => l10n.mqttTopicPositionDescription,
    '{root}/nodeinfo/{nodeId}' => l10n.mqttTopicNodeInfoDescription,
    '{root}/map/{nodeId}' => l10n.mqttTopicMapReportsDescription,
    _ => description,
  };

  /// Standard topic templates available in the Topic Builder.
  static const List<TopicTemplate> builtIn = [
    TopicTemplate(
      label: 'Chat', // lint-allow: hardcoded-string
      iconName: 'chat_bubble_outline',
      description: 'Text messages exchanged between mesh nodes on a specific channel.', // lint-allow: hardcoded-string
      pattern: '{root}/chat/{channel}',
      enabledByDefault: false,
    ),
    TopicTemplate(
      label: 'Telemetry', // lint-allow: hardcoded-string
      iconName: 'monitor_heart_outlined',
      description: 'Device health data such as battery level, voltage, and uptime.', // lint-allow: hardcoded-string
      pattern: '{root}/telemetry/{nodeId}',
      enabledByDefault: false,
    ),
    TopicTemplate(
      label: 'Position', // lint-allow: hardcoded-string
      iconName: 'location_on_outlined',
      description: 'GPS coordinates reported by mesh nodes (privacy-sensitive).', // lint-allow: hardcoded-string
      pattern: '{root}/position/{nodeId}',
      enabledByDefault: false,
    ),
    TopicTemplate(
      label: 'Node Info', // lint-allow: hardcoded-string
      iconName: 'info_outline',
      description:
          'Node identity broadcasts including long name, short name, and ' // lint-allow: hardcoded-string
          'hardware model.', // lint-allow: hardcoded-string
      pattern: '{root}/nodeinfo/{nodeId}',
      enabledByDefault: false,
    ),
    TopicTemplate(
      label: 'Map Reports', // lint-allow: hardcoded-string
      iconName: 'map_outlined',
      description: 'Periodic position reports for public mesh mapping services.', // lint-allow: hardcoded-string
      pattern: '{root}/map/{nodeId}',
      enabledByDefault: false,
    ),
  ];
}

/// User-facing copy for the setup wizard steps.
///
/// Kept here rather than in UI files so copy can be reviewed and
/// tested independently of the widget tree.
class GlobalLayerCopy {
  GlobalLayerCopy._();

  /// Step 1: Explanation
  static const String explainTitle =
      'What is the Global Layer?'; // lint-allow: hardcoded-string
  static const String explainBody =
      'Your mesh radio connects nearby devices over radio waves - no ' // lint-allow: hardcoded-string
      'internet needed. The Global Layer extends that reach by bridging ' // lint-allow: hardcoded-string
      'your local mesh to a server (called a broker) over the internet.\n\n' // lint-allow: hardcoded-string
      'Think of it as a portal: messages from your mesh can travel through ' // lint-allow: hardcoded-string
      'the portal to reach other meshes connected to the same broker, ' // lint-allow: hardcoded-string
      'anywhere in the world.'; // lint-allow: hardcoded-string
  static const String explainWhatItDoes =
      'Bridges your local mesh to remote meshes via an internet server.'; // lint-allow: hardcoded-string
  static const String explainWhatItDoesNot =
      'Does NOT replace your radio. Local mesh works independently even ' // lint-allow: hardcoded-string
      'if the Global Layer is offline.'; // lint-allow: hardcoded-string

  /// Step 2: Broker configuration
  static const String brokerTitle =
      'Choose a Broker'; // lint-allow: hardcoded-string
  static const String brokerBody =
      'Pick a broker to connect through. Most users should start with ' // lint-allow: hardcoded-string
      'the official Meshtastic server - it works out of the box with ' // lint-allow: hardcoded-string
      'no setup required.'; // lint-allow: hardcoded-string

  /// Step 3: Topic selection
  static const String topicsTitle =
      'Choose What to Share'; // lint-allow: hardcoded-string
  static const String topicsBody =
      'Topics control which types of data flow through the Global Layer. ' // lint-allow: hardcoded-string
      'You can enable or disable each type independently.'; // lint-allow: hardcoded-string

  /// Step 4: Privacy & Safety
  static const String privacyTitle =
      'Privacy & Safety'; // lint-allow: hardcoded-string
  static const String privacyBody =
      'The Global Layer is opt-in. Nothing is shared until you explicitly ' // lint-allow: hardcoded-string
      'enable it below. You can change these settings at any time.'; // lint-allow: hardcoded-string
  static const String privacyBrokerTrustWarning =
      'Your broker can see all data you send through it. Only connect to ' // lint-allow: hardcoded-string
      'brokers you trust.'; // lint-allow: hardcoded-string

  /// Step 5: Connection test
  static const String testTitle =
      'Test Connection'; // lint-allow: hardcoded-string
  static const String testBody =
      'Verifying that your broker is reachable and configured correctly.'; // lint-allow: hardcoded-string

  /// Step 6: Summary
  static const String summaryTitle =
      'Ready to Connect'; // lint-allow: hardcoded-string
  static const String summaryBody =
      'Review your Global Layer settings below. You can change any of ' // lint-allow: hardcoded-string
      'these later from the Global Layer status screen.'; // lint-allow: hardcoded-string
}
