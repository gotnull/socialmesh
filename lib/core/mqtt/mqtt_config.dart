// SPDX-License-Identifier: GPL-3.0-or-later

/// Configuration model for the Global Layer (MQTT) feature.
///
/// [GlobalLayerConfig] holds all user-configurable settings for the
/// Global Layer: broker connection details, privacy toggles, topic
/// subscriptions, and metadata. It is designed for:
///
/// - Safe serialization: secrets (password) are excluded from [toJson]
///   and stored separately via secure storage.
/// - Redacted export: [toRedactedJson] produces a diagnostics-safe
///   representation with all sensitive fields masked.
/// - Immutability: all mutations go through [copyWith].
library;

import 'dart:convert';

import 'mqtt_constants.dart';

/// Privacy and safety toggles for the Global Layer.
///
/// All toggles default to OFF (safe-by-default). The user must
/// explicitly opt in to each data-sharing category.
class GlobalLayerPrivacySettings {
  /// Whether local mesh messages are forwarded to the broker.
  final bool shareMessages;

  /// Whether device telemetry (battery, voltage, uptime) is published.
  final bool shareTelemetry;

  /// Whether inbound messages from the Global Layer are delivered
  /// to local mesh channels.
  final bool allowInboundGlobal;

  const GlobalLayerPrivacySettings({
    this.shareMessages = GlobalLayerConstants.defaultShareMessages,
    this.shareTelemetry = GlobalLayerConstants.defaultShareTelemetry,
    this.allowInboundGlobal = GlobalLayerConstants.defaultAllowInboundGlobal,
  });

  /// All toggles are off — nothing is shared.
  static const GlobalLayerPrivacySettings allOff = GlobalLayerPrivacySettings();

  GlobalLayerPrivacySettings copyWith({
    bool? shareMessages,
    bool? shareTelemetry,
    bool? allowInboundGlobal,
  }) {
    return GlobalLayerPrivacySettings(
      shareMessages: shareMessages ?? this.shareMessages,
      shareTelemetry: shareTelemetry ?? this.shareTelemetry,
      allowInboundGlobal: allowInboundGlobal ?? this.allowInboundGlobal,
    );
  }

  /// Whether any data sharing is enabled at all.
  bool get isAnythingShared =>
      shareMessages || shareTelemetry || allowInboundGlobal;

  Map<String, dynamic> toJson() => {
    'shareMessages': shareMessages,
    'shareTelemetry': shareTelemetry,
    'allowInboundGlobal': allowInboundGlobal,
  };

  factory GlobalLayerPrivacySettings.fromJson(Map<String, dynamic> json) {
    return GlobalLayerPrivacySettings(
      shareMessages:
          json['shareMessages'] as bool? ??
          GlobalLayerConstants.defaultShareMessages,
      shareTelemetry:
          json['shareTelemetry'] as bool? ??
          GlobalLayerConstants.defaultShareTelemetry,
      allowInboundGlobal:
          json['allowInboundGlobal'] as bool? ??
          GlobalLayerConstants.defaultAllowInboundGlobal,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalLayerPrivacySettings &&
          runtimeType == other.runtimeType &&
          shareMessages == other.shareMessages &&
          shareTelemetry == other.shareTelemetry &&
          allowInboundGlobal == other.allowInboundGlobal;

  @override
  int get hashCode =>
      Object.hash(shareMessages, shareTelemetry, allowInboundGlobal);

  @override
  String toString() =>
      'GlobalLayerPrivacySettings('
      'shareMessages: $shareMessages, '
      'shareTelemetry: $shareTelemetry, '
      'allowInboundGlobal: $allowInboundGlobal)';
}

/// A single topic subscription entry in the Global Layer config.
///
/// Each entry corresponds to a topic template instantiated with the
/// user's chosen root and optional channel/node identifiers.
class TopicSubscription {
  /// The fully-resolved MQTT topic string.
  final String topic;

  /// The label from the [TopicTemplate] that generated this subscription,
  /// or a custom label if the user created it manually.
  final String label;

  /// Whether this subscription is currently active.
  /// Users can disable subscriptions without deleting them.
  final bool enabled;

  /// Timestamp of the last message received on this topic, if any.
  final DateTime? lastMessageAt;

  const TopicSubscription({
    required this.topic,
    required this.label,
    this.enabled = false,
    this.lastMessageAt,
  });

  TopicSubscription copyWith({
    String? topic,
    String? label,
    bool? enabled,
    DateTime? lastMessageAt,
  }) {
    return TopicSubscription(
      topic: topic ?? this.topic,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'label': label,
    'enabled': enabled,
    if (lastMessageAt != null)
      'lastMessageAt': lastMessageAt!.toIso8601String(),
  };

  factory TopicSubscription.fromJson(Map<String, dynamic> json) {
    return TopicSubscription(
      topic: json['topic'] as String? ?? '',
      label: json['label'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicSubscription &&
          runtimeType == other.runtimeType &&
          topic == other.topic &&
          label == other.label &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(topic, label, enabled);

  @override
  String toString() =>
      'TopicSubscription(topic: $topic, label: $label, enabled: $enabled)';
}

/// Complete configuration for the Global Layer feature.
///
/// This model holds everything needed to establish and manage the
/// MQTT broker connection. The [password] field is intentionally
/// excluded from [toJson] — it must be stored and retrieved via
/// secure storage separately.
class GlobalLayerConfig {
  // ---------------------------------------------------------------------------
  // Broker connection
  // ---------------------------------------------------------------------------

  /// Broker hostname or IP address.
  final String host;

  /// Broker port number.
  final int port;

  /// Whether to use TLS for the broker connection.
  final bool useTls;

  /// Authentication username (may be empty if broker allows anonymous).
  final String username;

  /// Authentication password. NEVER serialized to JSON.
  /// Stored and loaded separately via [GlobalLayerSecureStorage].
  final String password;

  /// MQTT client identifier. Auto-generated if empty.
  final String clientId;

  // ---------------------------------------------------------------------------
  // Topics
  // ---------------------------------------------------------------------------

  /// User-defined root prefix for all topics.
  final String topicRoot;

  /// Configured topic subscriptions.
  final List<TopicSubscription> subscriptions;

  // ---------------------------------------------------------------------------
  // Privacy
  // ---------------------------------------------------------------------------

  /// Privacy and safety toggles.
  final GlobalLayerPrivacySettings privacy;

  // ---------------------------------------------------------------------------
  // Feature state
  // ---------------------------------------------------------------------------

  /// Whether the Global Layer feature is enabled (user has completed setup
  /// and has not paused it).
  final bool enabled;

  /// Whether the setup wizard has been completed at least once.
  final bool setupComplete;

  /// Timestamp of the last successful connection, if any.
  final DateTime? lastConnectedAt;

  /// Timestamp when this config was last modified.
  final DateTime? lastModifiedAt;

  const GlobalLayerConfig({
    this.host = '',
    this.port = GlobalLayerConstants.defaultTlsPort,
    this.useTls = true,
    this.username = '',
    this.password = '',
    this.clientId = '',
    this.topicRoot = GlobalLayerConstants.defaultTopicRoot,
    this.subscriptions = const [],
    this.privacy = const GlobalLayerPrivacySettings(),
    this.enabled = false,
    this.setupComplete = false,
    this.lastConnectedAt,
    this.lastModifiedAt,
  });

  /// A blank config representing the initial state before setup.
  static const GlobalLayerConfig initial = GlobalLayerConfig();

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// Whether the broker connection details are minimally valid
  /// (host is non-empty).
  bool get hasBrokerConfig => host.trim().isNotEmpty;

  /// Whether authentication credentials are configured.
  bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;

  /// The effective port, accounting for TLS default.
  int get effectivePort {
    if (port > 0) return port;
    return useTls
        ? GlobalLayerConstants.defaultTlsPort
        : GlobalLayerConstants.defaultPort;
  }

  /// List of currently enabled topic subscriptions.
  List<TopicSubscription> get enabledSubscriptions =>
      subscriptions.where((s) => s.enabled).toList(growable: false);

  /// Whether at least one topic is enabled.
  bool get hasEnabledTopics => subscriptions.any((s) => s.enabled);

  /// Connection URI for display purposes (never includes password).
  String get displayUri {
    final scheme = useTls ? 'mqtts' : 'mqtt';
    final portSuffix =
        (useTls && port == GlobalLayerConstants.defaultTlsPort) ||
            (!useTls && port == GlobalLayerConstants.defaultPort)
        ? ''
        : ':$port';
    return '$scheme://$host$portSuffix';
  }

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  GlobalLayerConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    String? username,
    String? password,
    String? clientId,
    String? topicRoot,
    List<TopicSubscription>? subscriptions,
    GlobalLayerPrivacySettings? privacy,
    bool? enabled,
    bool? setupComplete,
    DateTime? lastConnectedAt,
    DateTime? lastModifiedAt,
  }) {
    return GlobalLayerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      username: username ?? this.username,
      password: password ?? this.password,
      clientId: clientId ?? this.clientId,
      topicRoot: topicRoot ?? this.topicRoot,
      subscriptions: subscriptions ?? this.subscriptions,
      privacy: privacy ?? this.privacy,
      enabled: enabled ?? this.enabled,
      setupComplete: setupComplete ?? this.setupComplete,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  /// Returns a copy with an updated subscription at [index].
  GlobalLayerConfig withSubscription(int index, TopicSubscription sub) {
    if (index < 0 || index >= subscriptions.length) return this;
    final updated = List<TopicSubscription>.of(subscriptions);
    updated[index] = sub;
    return copyWith(subscriptions: updated, lastModifiedAt: DateTime.now());
  }

  /// Returns a copy with an added subscription.
  GlobalLayerConfig addSubscription(TopicSubscription sub) {
    return copyWith(
      subscriptions: [...subscriptions, sub],
      lastModifiedAt: DateTime.now(),
    );
  }

  /// Returns a copy with the subscription at [index] removed.
  GlobalLayerConfig removeSubscription(int index) {
    if (index < 0 || index >= subscriptions.length) return this;
    final updated = List<TopicSubscription>.of(subscriptions);
    updated.removeAt(index);
    return copyWith(subscriptions: updated, lastModifiedAt: DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Serializes the config to JSON, EXCLUDING the password.
  ///
  /// The password must be stored separately in secure storage.
  /// Use [GlobalLayerSecureStorage] to persist and retrieve it.
  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'useTls': useTls,
    'username': username,
    // password intentionally omitted
    'clientId': clientId,
    'topicRoot': topicRoot,
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'privacy': privacy.toJson(),
    'enabled': enabled,
    'setupComplete': setupComplete,
    if (lastConnectedAt != null)
      'lastConnectedAt': lastConnectedAt!.toIso8601String(),
    if (lastModifiedAt != null)
      'lastModifiedAt': lastModifiedAt!.toIso8601String(),
  };

  /// Serializes to a JSON string (without password).
  String toJsonString() => jsonEncode(toJson());

  /// Deserializes from JSON. The password must be provided separately
  /// after loading from secure storage.
  factory GlobalLayerConfig.fromJson(
    Map<String, dynamic> json, {
    String password = '',
  }) {
    return GlobalLayerConfig(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? GlobalLayerConstants.defaultTlsPort,
      useTls: json['useTls'] as bool? ?? true,
      username: json['username'] as String? ?? '',
      password: password,
      clientId: json['clientId'] as String? ?? '',
      topicRoot:
          json['topicRoot'] as String? ?? GlobalLayerConstants.defaultTopicRoot,
      subscriptions:
          (json['subscriptions'] as List<dynamic>?)
              ?.map(
                (e) => TopicSubscription.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      privacy: json['privacy'] != null
          ? GlobalLayerPrivacySettings.fromJson(
              json['privacy'] as Map<String, dynamic>,
            )
          : const GlobalLayerPrivacySettings(),
      enabled: json['enabled'] as bool? ?? false,
      setupComplete: json['setupComplete'] as bool? ?? false,
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.tryParse(json['lastConnectedAt'] as String)
          : null,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
    );
  }

  /// Deserializes from a JSON string.
  factory GlobalLayerConfig.fromJsonString(
    String jsonString, {
    String password = '',
  }) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return GlobalLayerConfig.fromJson(json, password: password);
  }

  /// Returns a diagnostics-safe JSON representation with all
  /// sensitive fields redacted.
  ///
  /// Safe to include in bug reports, logs, and clipboard exports.
  Map<String, dynamic> toRedactedJson() => {
    'host': host.isEmpty ? '(empty)' : host,
    'port': port,
    'useTls': useTls,
    'username': username.isEmpty ? '(empty)' : '***',
    'password': password.isEmpty ? '(empty)' : '***',
    'clientId': clientId.isEmpty ? '(auto)' : clientId,
    'topicRoot': topicRoot,
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    'privacy': privacy.toJson(),
    'enabled': enabled,
    'setupComplete': setupComplete,
    'hasEnabledTopics': hasEnabledTopics,
    'enabledTopicCount': enabledSubscriptions.length,
    if (lastConnectedAt != null)
      'lastConnectedAt': lastConnectedAt!.toIso8601String(),
    if (lastModifiedAt != null)
      'lastModifiedAt': lastModifiedAt!.toIso8601String(),
  };

  /// Redacted JSON as a formatted string, suitable for copy-to-clipboard.
  String toRedactedString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toRedactedJson());
  }

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalLayerConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          useTls == other.useTls &&
          username == other.username &&
          password == other.password &&
          clientId == other.clientId &&
          topicRoot == other.topicRoot &&
          privacy == other.privacy &&
          enabled == other.enabled &&
          setupComplete == other.setupComplete;

  @override
  int get hashCode => Object.hash(
    host,
    port,
    useTls,
    username,
    password,
    clientId,
    topicRoot,
    privacy,
    enabled,
    setupComplete,
  );

  @override
  String toString() =>
      'GlobalLayerConfig('
      'host: $host, '
      'port: $port, '
      'useTls: $useTls, '
      'username: ${username.isEmpty ? "(empty)" : "***"}, '
      'topicRoot: $topicRoot, '
      'enabled: $enabled, '
      'setupComplete: $setupComplete, '
      'subscriptions: ${subscriptions.length}, '
      'privacy: $privacy)';
}
