// SPDX-License-Identifier: GPL-3.0-or-later

/// Remote Sighting model — privacy-first minimal metadata for nodes
/// discovered via the Global Layer (MQTT) broker.
///
/// A [RemoteSighting] represents a node that was observed by a remote
/// mesh and relayed through the broker. These records are intentionally
/// minimal to respect privacy:
/// - No position data
/// - No message content
/// - No signal metrics (SNR/RSSI are local-only measurements)
/// - Only identity metadata that the node itself broadcasts
///
/// Remote sightings are opt-in. Users must explicitly enable inbound
/// global data in their Global Layer privacy settings before any
/// remote sightings are recorded.
library;

import 'dart:convert';

/// The source through which a node was discovered.
///
/// Used to distinguish locally-observed nodes from those seen via
/// the Global Layer, and to support filtering in the NodeDex UI.
enum NodeDiscoverySource {
  /// Discovered via local mesh radio (BLE/USB → LoRa).
  local,

  /// Discovered via the Global Layer MQTT broker (remote mesh).
  remote,

  /// Discovered both locally and via the Global Layer.
  ///
  /// This occurs when a node is first seen locally and later appears
  /// on the broker (or vice versa). The NodeDex entry retains the
  /// richer local data while noting that remote sightings also exist.
  mixed;

  /// Human-readable label for filter chips and badges.
  String get displayLabel => switch (this) {
    local => 'Local',
    remote => 'Remote',
    mixed => 'Mixed',
  };

  /// Short description for tooltips and help text.
  String get description => switch (this) {
    local => 'Discovered via your local mesh radio.',
    remote => 'Discovered via the Global Layer broker.',
    mixed => 'Seen both locally and via the Global Layer.',
  };

  /// Serialization key for JSON storage.
  String get key => name;

  /// Deserialize from a JSON key string.
  ///
  /// Returns [local] for unrecognised values to maintain backward
  /// compatibility when older app versions encounter new source types.
  static NodeDiscoverySource fromKey(String? key) {
    if (key == null) return local;
    return switch (key) {
      'local' => local,
      'remote' => remote,
      'mixed' => mixed,
      _ => local,
    };
  }
}

/// A single remote sighting record for a node observed via the
/// Global Layer MQTT broker.
///
/// These records are privacy-first by design:
/// - No GPS coordinates (position is a local-only measurement)
/// - No signal quality (SNR/RSSI are local-only measurements)
/// - No message content (only the fact that the node exists)
/// - Only publicly-broadcast identity fields
///
/// A remote sighting is created when:
/// 1. The Global Layer is connected and privacy allows inbound data
/// 2. A node info or telemetry message arrives on a subscribed topic
/// 3. The message contains a node identity not previously known locally
///
/// Remote sightings feed into the NodeDex as lightweight entries
/// that can be enriched if the node is later seen locally.
class RemoteSighting {
  /// The node number (Meshtastic node ID) of the sighted node.
  final int nodeNum;

  /// When this sighting was recorded (local device time).
  final DateTime timestamp;

  /// The MQTT topic on which this sighting was received.
  ///
  /// Useful for diagnostics and understanding which topic categories
  /// are producing remote node discoveries.
  final String topic;

  /// The broker URI that relayed this sighting.
  ///
  /// Stored so that sightings from different brokers can be
  /// distinguished if the user changes broker configuration.
  final String brokerUri;

  /// Display name of the node, if included in the broadcast.
  ///
  /// This is the long name from the node info packet. May be null
  /// if the sighting came from a telemetry or position packet that
  /// does not include identity fields.
  final String? displayName;

  /// Short name of the node (up to 4 characters), if available.
  final String? shortName;

  /// Hardware model string (e.g. "HELTEC_V3"), if available.
  final String? hardwareModel;

  /// Firmware version string, if included in the broadcast.
  final String? firmwareVersion;

  /// The region/channel context from the topic path, if parseable.
  ///
  /// For example, a sighting from topic `msh/chat/LongFast` would
  /// have channelContext "LongFast". This helps users understand
  /// which remote communities are producing sightings.
  final String? channelContext;

  const RemoteSighting({
    required this.nodeNum,
    required this.timestamp,
    required this.topic,
    required this.brokerUri,
    this.displayName,
    this.shortName,
    this.hardwareModel,
    this.firmwareVersion,
    this.channelContext,
  });

  /// Creates a sighting with the current timestamp.
  factory RemoteSighting.now({
    required int nodeNum,
    required String topic,
    required String brokerUri,
    String? displayName,
    String? shortName,
    String? hardwareModel,
    String? firmwareVersion,
    String? channelContext,
  }) {
    return RemoteSighting(
      nodeNum: nodeNum,
      timestamp: DateTime.now(),
      topic: topic,
      brokerUri: brokerUri,
      displayName: displayName,
      shortName: shortName,
      hardwareModel: hardwareModel,
      firmwareVersion: firmwareVersion,
      channelContext: channelContext,
    );
  }

  /// Whether this sighting includes enough identity data to create
  /// a meaningful NodeDex entry.
  ///
  /// At minimum we need a node number (always present) and ideally
  /// a display name. Sightings without names can still be recorded
  /// but will show as "Unknown (hex ID)" in the NodeDex.
  bool get hasIdentity => displayName != null || shortName != null;

  /// Age of this sighting since it was recorded.
  Duration get age => DateTime.now().difference(timestamp);

  /// Whether this sighting is recent (within the last hour).
  bool get isRecent => age.inHours < 1;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'nn': nodeNum,
    'ts': timestamp.millisecondsSinceEpoch,
    'tp': topic,
    'bu': brokerUri,
    if (displayName != null) 'dn': displayName,
    if (shortName != null) 'sn': shortName,
    if (hardwareModel != null) 'hw': hardwareModel,
    if (firmwareVersion != null) 'fw': firmwareVersion,
    if (channelContext != null) 'ch': channelContext,
  };

  factory RemoteSighting.fromJson(Map<String, dynamic> json) {
    return RemoteSighting(
      nodeNum: json['nn'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      topic: json['tp'] as String? ?? '',
      brokerUri: json['bu'] as String? ?? '',
      displayName: json['dn'] as String?,
      shortName: json['sn'] as String?,
      hardwareModel: json['hw'] as String?,
      firmwareVersion: json['fw'] as String?,
      channelContext: json['ch'] as String?,
    );
  }

  /// Encode a list of sightings to a JSON string.
  static String encodeList(List<RemoteSighting> sightings) {
    return jsonEncode(sightings.map((s) => s.toJson()).toList());
  }

  /// Decode a JSON string to a list of sightings.
  static List<RemoteSighting> decodeList(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => RemoteSighting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns a redacted representation safe for diagnostics export.
  ///
  /// Node numbers are kept because they are public broadcast data,
  /// but display names are truncated to prevent accidental PII leakage
  /// in bug reports.
  Map<String, dynamic> toRedactedJson() => {
    'nodeNum': nodeNum,
    'timestamp': timestamp.toIso8601String(),
    'topic': topic,
    'broker': brokerUri,
    'hasDisplayName': displayName != null,
    'hasShortName': shortName != null,
    'hardwareModel': hardwareModel,
    'channelContext': channelContext,
  };

  RemoteSighting copyWith({
    int? nodeNum,
    DateTime? timestamp,
    String? topic,
    String? brokerUri,
    String? displayName,
    String? shortName,
    String? hardwareModel,
    String? firmwareVersion,
    String? channelContext,
  }) {
    return RemoteSighting(
      nodeNum: nodeNum ?? this.nodeNum,
      timestamp: timestamp ?? this.timestamp,
      topic: topic ?? this.topic,
      brokerUri: brokerUri ?? this.brokerUri,
      displayName: displayName ?? this.displayName,
      shortName: shortName ?? this.shortName,
      hardwareModel: hardwareModel ?? this.hardwareModel,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      channelContext: channelContext ?? this.channelContext,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteSighting &&
          runtimeType == other.runtimeType &&
          nodeNum == other.nodeNum &&
          timestamp == other.timestamp &&
          topic == other.topic;

  @override
  int get hashCode => Object.hash(nodeNum, timestamp, topic);

  @override
  String toString() =>
      'RemoteSighting(node: $nodeNum, '
      'name: ${displayName ?? "(unknown)"}, '
      'topic: $topic, '
      'age: ${age.inMinutes}min)';
}

/// Aggregate statistics for remote sightings, displayed in the
/// NodeDex stats card and Global Layer status screen.
class RemoteSightingStats {
  /// Total number of unique nodes discovered via remote sightings.
  final int uniqueNodes;

  /// Total number of remote sighting records.
  final int totalSightings;

  /// Number of sightings received in the last hour.
  final int recentSightings;

  /// The most recent sighting timestamp, if any.
  final DateTime? lastSightingAt;

  /// Distribution of sightings by topic category.
  final Map<String, int> sightingsByTopic;

  /// Distribution of sightings by broker URI.
  final Map<String, int> sightingsByBroker;

  const RemoteSightingStats({
    this.uniqueNodes = 0,
    this.totalSightings = 0,
    this.recentSightings = 0,
    this.lastSightingAt,
    this.sightingsByTopic = const {},
    this.sightingsByBroker = const {},
  });

  /// An empty stats object representing no remote sighting activity.
  static const RemoteSightingStats empty = RemoteSightingStats();

  /// Whether any remote sightings have been recorded.
  bool get hasData => totalSightings > 0;

  /// Compute stats from a list of sightings.
  factory RemoteSightingStats.fromSightings(List<RemoteSighting> sightings) {
    if (sightings.isEmpty) return empty;

    final uniqueNodeNums = <int>{};
    final topicCounts = <String, int>{};
    final brokerCounts = <String, int>{};
    int recentCount = 0;
    DateTime? latest;

    for (final sighting in sightings) {
      uniqueNodeNums.add(sighting.nodeNum);

      // Count by topic
      topicCounts[sighting.topic] = (topicCounts[sighting.topic] ?? 0) + 1;

      // Count by broker
      topicCounts[sighting.brokerUri] =
          (brokerCounts[sighting.brokerUri] ?? 0) + 1;

      // Recent check
      if (sighting.isRecent) recentCount++;

      // Latest timestamp
      if (latest == null || sighting.timestamp.isAfter(latest)) {
        latest = sighting.timestamp;
      }
    }

    return RemoteSightingStats(
      uniqueNodes: uniqueNodeNums.length,
      totalSightings: sightings.length,
      recentSightings: recentCount,
      lastSightingAt: latest,
      sightingsByTopic: topicCounts,
      sightingsByBroker: brokerCounts,
    );
  }

  Map<String, dynamic> toJson() => {
    'uniqueNodes': uniqueNodes,
    'totalSightings': totalSightings,
    'recentSightings': recentSightings,
    if (lastSightingAt != null)
      'lastSightingAt': lastSightingAt!.toIso8601String(),
    'sightingsByTopic': sightingsByTopic,
    'sightingsByBroker': sightingsByBroker,
  };

  @override
  String toString() =>
      'RemoteSightingStats('
      'unique: $uniqueNodes, '
      'total: $totalSightings, '
      'recent: $recentSightings)';
}

/// Maximum number of remote sightings to retain in memory.
///
/// Older sightings are evicted when this limit is reached.
/// The limit is generous enough for a full day of moderate broker
/// traffic but bounded to prevent unbounded memory growth.
const int maxRemoteSightingsRetained = 5000;

/// Cooldown period between recording sightings for the same node.
///
/// Prevents flooding the sighting list with repeated observations
/// of the same node on every broker message.
const Duration remoteSightingCooldown = Duration(minutes: 5);
