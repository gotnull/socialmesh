// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Entry — the core data model for the mesh field journal.
//
// Each discovered Meshtastic node gets a NodeDexEntry that tracks
// discovery history, encounter statistics, social tags, and the
// data needed to derive procedural identity (sigils and traits).
//
// This model is independent of MeshNode — it reads from node data
// but persists its own enrichment layer.

import 'dart:convert';
import 'dart:ui';

/// Social classification a user can assign to a node.
///
/// These are user-driven labels that add meaning to discovered nodes.
/// A node can have at most one social tag.
enum NodeSocialTag {
  /// A known person — someone the user communicates with.
  contact,

  /// A trusted infrastructure node — verified relay or gateway.
  trustedNode,

  /// A known relay — a node that forwards traffic reliably.
  knownRelay,

  /// A frequent peer — regularly co-seen on the mesh.
  frequentPeer;

  String get displayLabel {
    return switch (this) {
      NodeSocialTag.contact => 'Contact',
      NodeSocialTag.trustedNode => 'Trusted Node',
      NodeSocialTag.knownRelay => 'Known Relay',
      NodeSocialTag.frequentPeer => 'Frequent Peer',
    };
  }

  String get icon {
    return switch (this) {
      NodeSocialTag.contact => '\u{1F4AC}',
      NodeSocialTag.trustedNode => '\u{1F6E1}',
      NodeSocialTag.knownRelay => '\u{1F4E1}',
      NodeSocialTag.frequentPeer => '\u{1F91D}',
    };
  }
}

/// Passive personality trait inferred from telemetry and behavior.
///
/// Traits are never user-editable. They are always derived from
/// real metrics: encounter patterns, position history, uptime,
/// role, and activity frequency.
enum NodeTrait {
  /// Seen across multiple regions or positions — a mobile node.
  wanderer,

  /// Always active, high uptime, frequently heard.
  beacon,

  /// Rarely seen, low encounter count relative to age.
  ghost,

  /// Fixed position, long-lived, stable presence.
  sentinel,

  /// High throughput role (ROUTER, ROUTER_CLIENT), forwarding traffic.
  relay,

  /// High message volume relative to encounters — carries data.
  courier,

  /// Persistent fixed infrastructure with high co-seen connectivity.
  anchor,

  /// Intermittent presence with irregular timing — appears and fades.
  drifter,

  /// Recently discovered, not enough data to classify.
  unknown;

  String get displayLabel {
    return switch (this) {
      NodeTrait.wanderer => 'Wanderer',
      NodeTrait.beacon => 'Beacon',
      NodeTrait.ghost => 'Ghost',
      NodeTrait.sentinel => 'Sentinel',
      NodeTrait.relay => 'Relay',
      NodeTrait.courier => 'Courier',
      NodeTrait.anchor => 'Anchor',
      NodeTrait.drifter => 'Drifter',
      NodeTrait.unknown => 'Newcomer',
    };
  }

  String get description {
    return switch (this) {
      NodeTrait.wanderer => 'Seen across multiple locations',
      NodeTrait.beacon => 'Always active, high availability',
      NodeTrait.ghost => 'Rarely seen, elusive presence',
      NodeTrait.sentinel => 'Fixed position, long-lived guardian',
      NodeTrait.relay => 'High throughput, forwards traffic',
      NodeTrait.courier => 'Carries messages across the mesh',
      NodeTrait.anchor => 'Persistent hub with many connections',
      NodeTrait.drifter => 'Irregular timing, fades in and out',
      NodeTrait.unknown => 'Recently discovered',
    };
  }

  /// Accent color associated with this trait for UI rendering.
  Color get color {
    return switch (this) {
      NodeTrait.wanderer => const Color(0xFF0EA5E9),
      NodeTrait.beacon => const Color(0xFFFBBF24),
      NodeTrait.ghost => const Color(0xFF8B5CF6),
      NodeTrait.sentinel => const Color(0xFF10B981),
      NodeTrait.relay => const Color(0xFFF97316),
      NodeTrait.courier => const Color(0xFF06B6D4),
      NodeTrait.anchor => const Color(0xFF6366F1),
      NodeTrait.drifter => const Color(0xFFEC4899),
      NodeTrait.unknown => const Color(0xFF9CA3AF),
    };
  }
}

/// A single encounter record — one observation of a node at a point in time.
///
/// Encounter records are kept in a rolling window (most recent N entries)
/// to avoid unbounded storage growth while preserving useful history.
class EncounterRecord {
  /// When this encounter was recorded.
  final DateTime timestamp;

  /// Distance in meters at time of encounter, if available.
  final double? distanceMeters;

  /// Signal-to-noise ratio at time of encounter.
  final int? snr;

  /// Received signal strength indicator at time of encounter.
  final int? rssi;

  /// Latitude at time of encounter, if position was available.
  final double? latitude;

  /// Longitude at time of encounter, if position was available.
  final double? longitude;

  const EncounterRecord({
    required this.timestamp,
    this.distanceMeters,
    this.snr,
    this.rssi,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'ts': timestamp.millisecondsSinceEpoch,
      if (distanceMeters != null) 'd': distanceMeters,
      if (snr != null) 's': snr,
      if (rssi != null) 'r': rssi,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lon': longitude,
    };
  }

  factory EncounterRecord.fromJson(Map<String, dynamic> json) {
    return EncounterRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      distanceMeters: (json['d'] as num?)?.toDouble(),
      snr: json['s'] as int?,
      rssi: json['r'] as int?,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
    );
  }

  EncounterRecord copyWith({
    DateTime? timestamp,
    double? distanceMeters,
    int? snr,
    int? rssi,
    double? latitude,
    double? longitude,
  }) {
    return EncounterRecord(
      timestamp: timestamp ?? this.timestamp,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      snr: snr ?? this.snr,
      rssi: rssi ?? this.rssi,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// Deterministic sigil data derived from a node's identity.
///
/// The sigil is a geometric visual identity generated from the node's
/// numeric ID. It never changes for a given node — the same nodeNum
/// always produces the same sigil.
class SigilData {
  /// Number of vertices in the outer polygon (3-8).
  final int vertices;

  /// Rotation offset in radians for the outer polygon.
  final double rotation;

  /// Number of inner rings (0-3).
  final int innerRings;

  /// Whether to draw connecting lines from center to vertices.
  final bool drawRadials;

  /// Whether to draw a dot at the center.
  final bool centerDot;

  /// Symmetry fold count for inner pattern (2-6).
  final int symmetryFold;

  /// Primary color for the sigil.
  final Color primaryColor;

  /// Secondary color for accents and inner elements.
  final Color secondaryColor;

  /// Tertiary color for subtle details.
  final Color tertiaryColor;

  const SigilData({
    required this.vertices,
    required this.rotation,
    required this.innerRings,
    required this.drawRadials,
    required this.centerDot,
    required this.symmetryFold,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'v': vertices,
      'r': rotation,
      'ir': innerRings,
      'dr': drawRadials,
      'cd': centerDot,
      'sf': symmetryFold,
      'pc': primaryColor.value,
      'sc': secondaryColor.value,
      'tc': tertiaryColor.value,
    };
  }

  factory SigilData.fromJson(Map<String, dynamic> json) {
    return SigilData(
      vertices: json['v'] as int,
      rotation: (json['r'] as num).toDouble(),
      innerRings: json['ir'] as int,
      drawRadials: json['dr'] as bool,
      centerDot: json['cd'] as bool,
      symmetryFold: json['sf'] as int,
      primaryColor: Color(json['pc'] as int),
      secondaryColor: Color(json['sc'] as int),
      tertiaryColor: Color(json['tc'] as int),
    );
  }
}

/// A region where a node has been observed.
///
/// Regions are derived from position data when available, or from
/// the device's configured LoRa region as a fallback. Each region
/// tracks when it was first and last seen.
class SeenRegion {
  /// Region identifier — either a geohash prefix or LoRa region code.
  final String regionId;

  /// Human-readable region label.
  final String label;

  /// First time this node was seen in this region.
  final DateTime firstSeen;

  /// Last time this node was seen in this region.
  final DateTime lastSeen;

  /// Number of encounters in this region.
  final int encounterCount;

  const SeenRegion({
    required this.regionId,
    required this.label,
    required this.firstSeen,
    required this.lastSeen,
    required this.encounterCount,
  });

  SeenRegion copyWith({DateTime? lastSeen, int? encounterCount}) {
    return SeenRegion(
      regionId: regionId,
      label: label,
      firstSeen: firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      encounterCount: encounterCount ?? this.encounterCount,
    );
  }

  /// Merge two records for the same region, keeping the broadest time
  /// span and the highest encounter count.
  SeenRegion merge(SeenRegion other) {
    assert(regionId == other.regionId, 'Cannot merge different regions');
    return SeenRegion(
      regionId: regionId,
      label: label.isNotEmpty ? label : other.label,
      firstSeen: firstSeen.isBefore(other.firstSeen)
          ? firstSeen
          : other.firstSeen,
      lastSeen: lastSeen.isAfter(other.lastSeen) ? lastSeen : other.lastSeen,
      encounterCount: encounterCount > other.encounterCount
          ? encounterCount
          : other.encounterCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': regionId,
      'l': label,
      'fs': firstSeen.millisecondsSinceEpoch,
      'ls': lastSeen.millisecondsSinceEpoch,
      'ec': encounterCount,
    };
  }

  factory SeenRegion.fromJson(Map<String, dynamic> json) {
    return SeenRegion(
      regionId: json['id'] as String,
      label: json['l'] as String,
      firstSeen: DateTime.fromMillisecondsSinceEpoch(json['fs'] as int),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['ls'] as int),
      encounterCount: json['ec'] as int,
    );
  }
}

/// Explorer prestige title derived from real discovery data.
///
/// Titles are earned through actual mesh exploration — node count,
/// region diversity, distance records, and encounter breadth.
/// No grinding, no gamification. Just recognition of real activity.
enum ExplorerTitle {
  /// Fewer than 5 nodes discovered.
  newcomer,

  /// 5-19 nodes discovered.
  observer,

  /// 20-49 nodes discovered.
  explorer,

  /// 50-99 nodes discovered.
  cartographer,

  /// 100-199 nodes discovered.
  signalHunter,

  /// 200+ nodes discovered.
  meshVeteran,

  /// 200+ nodes AND 5+ regions.
  meshCartographer,

  /// Has the longest distance record above 10km.
  longRangeRecordHolder;

  String get displayLabel {
    return switch (this) {
      ExplorerTitle.newcomer => 'Newcomer',
      ExplorerTitle.observer => 'Observer',
      ExplorerTitle.explorer => 'Explorer',
      ExplorerTitle.cartographer => 'Cartographer',
      ExplorerTitle.signalHunter => 'Signal Hunter',
      ExplorerTitle.meshVeteran => 'Mesh Veteran',
      ExplorerTitle.meshCartographer => 'Mesh Cartographer',
      ExplorerTitle.longRangeRecordHolder => 'Long-Range Record Holder',
    };
  }

  String get description {
    return switch (this) {
      ExplorerTitle.newcomer => 'Beginning the mesh journey',
      ExplorerTitle.observer => 'Building awareness of the mesh',
      ExplorerTitle.explorer => 'Actively discovering the network',
      ExplorerTitle.cartographer => 'Mapping the invisible infrastructure',
      ExplorerTitle.signalHunter => 'Seeking signals across the spectrum',
      ExplorerTitle.meshVeteran => 'Deep knowledge of the mesh',
      ExplorerTitle.meshCartographer => 'Charting regions and routes',
      ExplorerTitle.longRangeRecordHolder => 'Pushing the limits of range',
    };
  }
}

// =============================================================================
// Co-Seen Relationship
// =============================================================================

/// A relationship record between two co-seen nodes.
///
/// Two nodes are "co-seen" when they appear in the same session.
/// This rich relationship model tracks the full history of the
/// co-occurrence — when it started, when it was last observed,
/// how many times they have been seen together, and how many
/// messages were exchanged while both were present.
///
/// Schema v2 replaces the legacy v1 format where coSeenNodes was
/// a simple `Map<int, int>` (nodeNum -> count). The fromJson
/// factory handles both formats transparently for migration.
class CoSeenRelationship {
  /// Number of times these two nodes have been co-seen.
  final int count;

  /// When this co-seen relationship was first recorded.
  final DateTime firstSeen;

  /// When this co-seen relationship was most recently recorded.
  final DateTime lastSeen;

  /// Number of messages exchanged while both nodes were co-seen.
  final int messageCount;

  const CoSeenRelationship({
    required this.count,
    required this.firstSeen,
    required this.lastSeen,
    this.messageCount = 0,
  });

  /// Create a new relationship from a first co-sighting.
  factory CoSeenRelationship.initial({DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    return CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now);
  }

  /// Record another co-sighting, incrementing count and updating lastSeen.
  CoSeenRelationship recordSighting({DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    return CoSeenRelationship(
      count: count + 1,
      firstSeen: firstSeen,
      lastSeen: now,
      messageCount: messageCount,
    );
  }

  /// Increment the message count for this relationship.
  CoSeenRelationship incrementMessages({int by = 1}) {
    return CoSeenRelationship(
      count: count,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      messageCount: messageCount + by,
    );
  }

  /// Duration of the relationship from first to last sighting.
  Duration get relationshipAge => lastSeen.difference(firstSeen);

  /// Time since the last co-sighting.
  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeen);

  CoSeenRelationship copyWith({
    int? count,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int? messageCount,
  }) {
    return CoSeenRelationship(
      count: count ?? this.count,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'c': count,
      'fs': firstSeen.millisecondsSinceEpoch,
      'ls': lastSeen.millisecondsSinceEpoch,
      if (messageCount > 0) 'mc': messageCount,
    };
  }

  /// Deserialize from JSON, supporting both v2 (object) and v1 (int) formats.
  ///
  /// V2 format: `{"c": 5, "fs": 1700000000000, "ls": 1700100000000, "mc": 2}`
  /// V1 legacy format: just an `int` count value (migrated transparently).
  ///
  /// When migrating from v1, [fallbackFirstSeen] is used as the firstSeen
  /// and lastSeen timestamps since the legacy format did not track them.
  factory CoSeenRelationship.fromJson(
    dynamic json, {
    DateTime? fallbackFirstSeen,
  }) {
    if (json is int) {
      // Legacy v1 migration: plain count integer.
      final fallback = fallbackFirstSeen ?? DateTime.now();
      return CoSeenRelationship(
        count: json,
        firstSeen: fallback,
        lastSeen: fallback,
      );
    }

    final map = json as Map<String, dynamic>;
    return CoSeenRelationship(
      count: map['c'] as int? ?? 1,
      firstSeen: map['fs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['fs'] as int)
          : (fallbackFirstSeen ?? DateTime.now()),
      lastSeen: map['ls'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['ls'] as int)
          : (fallbackFirstSeen ?? DateTime.now()),
      messageCount: map['mc'] as int? ?? 0,
    );
  }

  /// Merge two relationship records, keeping the broadest time span
  /// and the highest counts.
  CoSeenRelationship merge(CoSeenRelationship other) {
    return CoSeenRelationship(
      count: count > other.count ? count : other.count,
      firstSeen: firstSeen.isBefore(other.firstSeen)
          ? firstSeen
          : other.firstSeen,
      lastSeen: lastSeen.isAfter(other.lastSeen) ? lastSeen : other.lastSeen,
      messageCount: messageCount > other.messageCount
          ? messageCount
          : other.messageCount,
    );
  }

  @override
  String toString() =>
      'CoSeenRelationship(count: $count, '
      'first: $firstSeen, last: $lastSeen, '
      'messages: $messageCount)';
}

// =============================================================================
// NodeDex Entry
// =============================================================================

/// The core NodeDex entry for a single discovered node.
///
/// This is the enrichment layer that sits on top of MeshNode data.
/// It tracks discovery history, encounter statistics, user-assigned
/// social tags, and derived data for procedural identity.
class NodeDexEntry {
  /// Meshtastic node number — primary key, matches MeshNode.nodeNum.
  final int nodeNum;

  /// When this node was first discovered by the user.
  final DateTime firstSeen;

  /// When this node was most recently seen.
  final DateTime lastSeen;

  /// Total number of distinct encounter sessions.
  ///
  /// An encounter is counted when a node appears after being absent
  /// for at least the encounter cooldown period (default: 5 minutes).
  final int encounterCount;

  /// Maximum distance (meters) at which this node has been observed.
  final double? maxDistanceSeen;

  /// Best SNR ever recorded for this node.
  final int? bestSnr;

  /// Best RSSI ever recorded for this node.
  final int? bestRssi;

  /// Number of messages exchanged with this node.
  final int messageCount;

  /// User-assigned social classification.
  final NodeSocialTag? socialTag;

  /// Timestamp (ms since epoch) when socialTag was last modified.
  ///
  /// Used for last-write-wins conflict resolution during Cloud Sync.
  /// When null, the field is treated as "never explicitly set" and
  /// loses to any timestamped value during merge.
  final int? socialTagUpdatedAtMs;

  /// User-written note about this node (optional, max 280 chars).
  final String? userNote;

  /// Timestamp (ms since epoch) when userNote was last modified.
  ///
  /// Used for last-write-wins conflict resolution during Cloud Sync.
  /// When null, the field is treated as "never explicitly set" and
  /// loses to any timestamped value during merge.
  final int? userNoteUpdatedAtMs;

  /// Rolling window of recent encounters (most recent 50).
  final List<EncounterRecord> encounters;

  /// Regions where this node has been observed.
  final List<SeenRegion> seenRegions;

  /// Co-seen node relationships: nodeNum -> CoSeenRelationship.
  ///
  /// Two nodes are "co-seen" when they appear in the same session.
  /// This powers the constellation visualization. Each relationship
  /// tracks count, firstSeen, lastSeen, and messageCount.
  final Map<int, CoSeenRelationship> coSeenNodes;

  /// Cached sigil data for this node's procedural identity.
  final SigilData? sigil;

  /// Maximum number of encounter records to retain.
  static const int maxEncounterRecords = 50;

  /// Minimum gap between encounters to count as a new encounter (minutes).
  static const int encounterCooldownMinutes = 5;

  /// Conflict window for near-simultaneous edits (milliseconds).
  ///
  /// If two devices modify the same field within this window and produce
  /// different values, the merge produces a conflict indicator rather
  /// than silently dropping one value.
  static const int conflictWindowMs = 5000;

  const NodeDexEntry({
    required this.nodeNum,
    required this.firstSeen,
    required this.lastSeen,
    this.encounterCount = 1,
    this.maxDistanceSeen,
    this.bestSnr,
    this.bestRssi,
    this.messageCount = 0,
    this.socialTag,
    this.socialTagUpdatedAtMs,
    this.userNote,
    this.userNoteUpdatedAtMs,
    this.encounters = const [],
    this.seenRegions = const [],
    this.coSeenNodes = const {},
    this.sigil,
  });

  /// Create a new entry for a freshly discovered node.
  factory NodeDexEntry.discovered({
    required int nodeNum,
    DateTime? timestamp,
    double? distance,
    int? snr,
    int? rssi,
    double? latitude,
    double? longitude,
    SigilData? sigil,
  }) {
    final now = timestamp ?? DateTime.now();
    final encounter = EncounterRecord(
      timestamp: now,
      distanceMeters: distance,
      snr: snr,
      rssi: rssi,
      latitude: latitude,
      longitude: longitude,
    );

    return NodeDexEntry(
      nodeNum: nodeNum,
      firstSeen: now,
      lastSeen: now,
      encounterCount: 1,
      maxDistanceSeen: distance,
      bestSnr: snr,
      bestRssi: rssi,
      encounters: [encounter],
      sigil: sigil,
    );
  }

  /// Whether this node was discovered in the last 24 hours.
  bool get isRecentlyDiscovered {
    return DateTime.now().difference(firstSeen).inHours < 24;
  }

  /// Age of this entry since first discovery.
  Duration get age => DateTime.now().difference(firstSeen);

  /// Time since last seen.
  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeen);

  /// Number of distinct regions where this node has been observed.
  int get regionCount => seenRegions.length;

  /// Number of nodes that have been co-seen with this one.
  int get coSeenCount => coSeenNodes.length;

  /// The highest co-seen weight (count) among all relationships.
  ///
  /// Returns 0 if no co-seen relationships exist.
  int get topCoSeenWeight {
    if (coSeenNodes.isEmpty) return 0;
    int max = 0;
    for (final rel in coSeenNodes.values) {
      if (rel.count > max) max = rel.count;
    }
    return max;
  }

  /// Total number of distinct positions recorded across encounters.
  int get distinctPositionCount {
    final positions = <String>{};
    for (final encounter in encounters) {
      if (encounter.latitude != null && encounter.longitude != null) {
        // Round to ~100m precision for distinct position counting
        final lat = (encounter.latitude! * 1000).round();
        final lon = (encounter.longitude! * 1000).round();
        positions.add('$lat,$lon');
      }
    }
    return positions.length;
  }

  /// Whether enough data exists to infer a trait beyond "unknown".
  bool get hasEnoughDataForTrait => encounterCount >= 3 || age.inDays >= 1;

  NodeDexEntry copyWith({
    int? nodeNum,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int? encounterCount,
    double? maxDistanceSeen,
    int? bestSnr,
    int? bestRssi,
    int? messageCount,
    NodeSocialTag? socialTag,
    bool clearSocialTag = false,
    int? socialTagUpdatedAtMs,
    String? userNote,
    bool clearUserNote = false,
    int? userNoteUpdatedAtMs,
    List<EncounterRecord>? encounters,
    List<SeenRegion>? seenRegions,
    Map<int, CoSeenRelationship>? coSeenNodes,
    SigilData? sigil,
  }) {
    // Auto-stamp when socialTag changes via copyWith.
    final effectiveStMs = clearSocialTag || socialTag != null
        ? (socialTagUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch)
        : (socialTagUpdatedAtMs ?? this.socialTagUpdatedAtMs);

    // Auto-stamp when userNote changes via copyWith.
    final effectiveUnMs = clearUserNote || userNote != null
        ? (userNoteUpdatedAtMs ?? DateTime.now().millisecondsSinceEpoch)
        : (userNoteUpdatedAtMs ?? this.userNoteUpdatedAtMs);

    return NodeDexEntry(
      nodeNum: nodeNum ?? this.nodeNum,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      encounterCount: encounterCount ?? this.encounterCount,
      maxDistanceSeen: maxDistanceSeen ?? this.maxDistanceSeen,
      bestSnr: bestSnr ?? this.bestSnr,
      bestRssi: bestRssi ?? this.bestRssi,
      messageCount: messageCount ?? this.messageCount,
      socialTag: clearSocialTag ? null : (socialTag ?? this.socialTag),
      socialTagUpdatedAtMs: effectiveStMs,
      userNote: clearUserNote ? null : (userNote ?? this.userNote),
      userNoteUpdatedAtMs: effectiveUnMs,
      encounters: encounters ?? this.encounters,
      seenRegions: seenRegions ?? this.seenRegions,
      coSeenNodes: coSeenNodes ?? this.coSeenNodes,
      sigil: sigil ?? this.sigil,
    );
  }

  /// Record a new encounter with this node.
  ///
  /// Only increments encounterCount if enough time has passed since
  /// the last encounter (cooldown period). Always updates lastSeen
  /// and appends to the encounter log.
  NodeDexEntry recordEncounter({
    DateTime? timestamp,
    double? distance,
    int? snr,
    int? rssi,
    double? latitude,
    double? longitude,
  }) {
    final now = timestamp ?? DateTime.now();
    final encounter = EncounterRecord(
      timestamp: now,
      distanceMeters: distance,
      snr: snr,
      rssi: rssi,
      latitude: latitude,
      longitude: longitude,
    );

    // Determine if this counts as a new encounter
    final isNewEncounter =
        encounters.isEmpty ||
        now.difference(encounters.last.timestamp).inMinutes >=
            encounterCooldownMinutes;

    // Update best metrics
    double? newMaxDistance = maxDistanceSeen;
    if (distance != null) {
      if (newMaxDistance == null || distance > newMaxDistance) {
        newMaxDistance = distance;
      }
    }

    int? newBestSnr = bestSnr;
    if (snr != null) {
      if (newBestSnr == null || snr > newBestSnr) {
        newBestSnr = snr;
      }
    }

    int? newBestRssi = bestRssi;
    if (rssi != null) {
      // RSSI is negative; closer to 0 is better
      if (newBestRssi == null || rssi > newBestRssi) {
        newBestRssi = rssi;
      }
    }

    // Maintain rolling window of encounters
    final updatedEncounters = List<EncounterRecord>.from(encounters)
      ..add(encounter);
    while (updatedEncounters.length > maxEncounterRecords) {
      updatedEncounters.removeAt(0);
    }

    return copyWith(
      lastSeen: now,
      encounterCount: isNewEncounter ? encounterCount + 1 : encounterCount,
      maxDistanceSeen: newMaxDistance,
      bestSnr: newBestSnr,
      bestRssi: newBestRssi,
      encounters: updatedEncounters,
    );
  }

  /// Register a co-seen relationship with another node.
  ///
  /// If this is the first time the pair has been co-seen, creates a
  /// new [CoSeenRelationship]. Otherwise, increments the existing
  /// relationship's count and updates its lastSeen timestamp.
  NodeDexEntry addCoSeen(int otherNodeNum, {DateTime? timestamp}) {
    if (otherNodeNum == nodeNum) return this;
    final updated = Map<int, CoSeenRelationship>.from(coSeenNodes);
    final existing = updated[otherNodeNum];
    if (existing != null) {
      updated[otherNodeNum] = existing.recordSighting(timestamp: timestamp);
    } else {
      updated[otherNodeNum] = CoSeenRelationship.initial(timestamp: timestamp);
    }
    return copyWith(coSeenNodes: updated);
  }

  /// Increment the message count for a co-seen relationship.
  ///
  /// If the relationship does not exist, this is a no-op.
  NodeDexEntry incrementCoSeenMessages(int otherNodeNum, {int by = 1}) {
    if (otherNodeNum == nodeNum) return this;
    final existing = coSeenNodes[otherNodeNum];
    if (existing == null) return this;
    final updated = Map<int, CoSeenRelationship>.from(coSeenNodes);
    updated[otherNodeNum] = existing.incrementMessages(by: by);
    return copyWith(coSeenNodes: updated);
  }

  /// Add or update a region observation.
  NodeDexEntry addRegion(String regionId, String label, {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    final updated = List<SeenRegion>.from(seenRegions);
    final existingIndex = updated.indexWhere((r) => r.regionId == regionId);

    if (existingIndex >= 0) {
      updated[existingIndex] = updated[existingIndex].copyWith(
        lastSeen: now,
        encounterCount: updated[existingIndex].encounterCount + 1,
      );
    } else {
      updated.add(
        SeenRegion(
          regionId: regionId,
          label: label,
          firstSeen: now,
          lastSeen: now,
          encounterCount: 1,
        ),
      );
    }

    return copyWith(seenRegions: updated);
  }

  /// Increment message count.
  NodeDexEntry incrementMessages({int by = 1}) {
    return copyWith(messageCount: messageCount + by);
  }

  // -------------------------------------------------------------------------
  // Merge
  // -------------------------------------------------------------------------

  /// Merge another entry for the same node into this one.
  ///
  /// Produces a combined entry that preserves the broadest time spans,
  /// highest metric values, and intelligently merged sub-collections
  /// (co-seen relationships, regions, encounters).
  ///
  /// Merge rules:
  /// - firstSeen: earliest of the two
  /// - lastSeen: latest of the two
  /// - encounterCount: maximum of the two
  /// - maxDistanceSeen: maximum of the two
  /// - bestSnr: maximum of the two
  /// - bestRssi: maximum of the two (closer to 0)
  /// - messageCount: maximum of the two
  /// - socialTag: last-write-wins by socialTagUpdatedAtMs timestamp;
  ///   if both edited within [conflictWindowMs] with different values,
  ///   the later timestamp wins but a conflict is flagged
  /// - userNote: last-write-wins by userNoteUpdatedAtMs timestamp;
  ///   same conflict detection as socialTag
  /// - encounters: union by timestamp, capped at maxEncounterRecords
  /// - seenRegions: merged by regionId using SeenRegion.merge
  /// - coSeenNodes: merged per-edge using CoSeenRelationship.merge
  /// - sigil: prefer this entry's sigil if set, else other's
  NodeDexEntry mergeWith(NodeDexEntry other) {
    assert(
      nodeNum == other.nodeNum,
      'Cannot merge entries for different nodes',
    );

    // --- Scalar metrics: take the best ---
    final mergedFirstSeen = firstSeen.isBefore(other.firstSeen)
        ? firstSeen
        : other.firstSeen;
    final mergedLastSeen = lastSeen.isAfter(other.lastSeen)
        ? lastSeen
        : other.lastSeen;
    final mergedEncounterCount = encounterCount > other.encounterCount
        ? encounterCount
        : other.encounterCount;
    final mergedMessageCount = messageCount > other.messageCount
        ? messageCount
        : other.messageCount;

    double? mergedMaxDistance;
    if (maxDistanceSeen != null && other.maxDistanceSeen != null) {
      mergedMaxDistance = maxDistanceSeen! > other.maxDistanceSeen!
          ? maxDistanceSeen
          : other.maxDistanceSeen;
    } else {
      mergedMaxDistance = maxDistanceSeen ?? other.maxDistanceSeen;
    }

    int? mergedBestSnr;
    if (bestSnr != null && other.bestSnr != null) {
      mergedBestSnr = bestSnr! > other.bestSnr! ? bestSnr : other.bestSnr;
    } else {
      mergedBestSnr = bestSnr ?? other.bestSnr;
    }

    int? mergedBestRssi;
    if (bestRssi != null && other.bestRssi != null) {
      mergedBestRssi = bestRssi! > other.bestRssi! ? bestRssi : other.bestRssi;
    } else {
      mergedBestRssi = bestRssi ?? other.bestRssi;
    }

    // --- User-editable fields: last-write-wins by per-field timestamp ---
    final mergedTagResult = _mergeUserField<NodeSocialTag>(
      localValue: socialTag,
      localTimestamp: socialTagUpdatedAtMs,
      remoteValue: other.socialTag,
      remoteTimestamp: other.socialTagUpdatedAtMs,
    );
    final mergedNoteResult = _mergeUserField<String>(
      localValue: userNote,
      localTimestamp: userNoteUpdatedAtMs,
      remoteValue: other.userNote,
      remoteTimestamp: other.userNoteUpdatedAtMs,
    );

    final mergedSigil = sigil ?? other.sigil;

    // --- Encounters: union by timestamp, keep most recent N ---
    final encounterTimestamps = <int>{};
    final allEncounters = <EncounterRecord>[];
    for (final enc in encounters) {
      final key = enc.timestamp.millisecondsSinceEpoch;
      if (encounterTimestamps.add(key)) {
        allEncounters.add(enc);
      }
    }
    for (final enc in other.encounters) {
      final key = enc.timestamp.millisecondsSinceEpoch;
      if (encounterTimestamps.add(key)) {
        allEncounters.add(enc);
      }
    }
    allEncounters.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final mergedEncounters = allEncounters.length > maxEncounterRecords
        ? allEncounters.sublist(allEncounters.length - maxEncounterRecords)
        : allEncounters;

    // --- Regions: merge by regionId ---
    final regionMap = <String, SeenRegion>{};
    for (final region in seenRegions) {
      regionMap[region.regionId] = region;
    }
    for (final region in other.seenRegions) {
      final existing = regionMap[region.regionId];
      if (existing != null) {
        regionMap[region.regionId] = existing.merge(region);
      } else {
        regionMap[region.regionId] = region;
      }
    }

    // --- Co-seen relationships: merge per edge ---
    final mergedCoSeen = Map<int, CoSeenRelationship>.from(coSeenNodes);
    for (final entry in other.coSeenNodes.entries) {
      final existing = mergedCoSeen[entry.key];
      if (existing != null) {
        mergedCoSeen[entry.key] = existing.merge(entry.value);
      } else {
        mergedCoSeen[entry.key] = entry.value;
      }
    }

    return NodeDexEntry(
      nodeNum: nodeNum,
      firstSeen: mergedFirstSeen,
      lastSeen: mergedLastSeen,
      encounterCount: mergedEncounterCount,
      maxDistanceSeen: mergedMaxDistance,
      bestSnr: mergedBestSnr,
      bestRssi: mergedBestRssi,
      messageCount: mergedMessageCount,
      socialTag: mergedTagResult.value,
      socialTagUpdatedAtMs: mergedTagResult.timestamp,
      userNote: mergedNoteResult.value,
      userNoteUpdatedAtMs: mergedNoteResult.timestamp,
      encounters: mergedEncounters,
      seenRegions: regionMap.values.toList(),
      coSeenNodes: mergedCoSeen,
      sigil: mergedSigil,
    );
  }

  /// Merge a single user-editable field using last-write-wins semantics.
  ///
  /// Rules:
  /// 1. If only one side has a timestamp, that side wins.
  /// 2. If both have timestamps, the later timestamp wins.
  /// 3. If both are null timestamps, prefer non-null value (legacy compat).
  /// 4. If timestamps are within [conflictWindowMs] and values differ,
  ///    the later timestamp still wins but [isConflict] is set true.
  static _MergeResult<T> _mergeUserField<T>({
    required T? localValue,
    required int? localTimestamp,
    required T? remoteValue,
    required int? remoteTimestamp,
  }) {
    // Both timestamps null: legacy fallback — prefer non-null, favor local.
    if (localTimestamp == null && remoteTimestamp == null) {
      return _MergeResult(
        value: localValue ?? remoteValue,
        timestamp: null,
        isConflict: false,
      );
    }

    // Only one side has a timestamp — that side wins.
    if (localTimestamp == null) {
      return _MergeResult(
        value: remoteValue,
        timestamp: remoteTimestamp,
        isConflict: false,
      );
    }
    if (remoteTimestamp == null) {
      return _MergeResult(
        value: localValue,
        timestamp: localTimestamp,
        isConflict: false,
      );
    }

    // Both have timestamps — compare.
    final diff = (localTimestamp - remoteTimestamp).abs();
    final valuesMatch = localValue == remoteValue;
    final isConflict = diff <= conflictWindowMs && !valuesMatch;

    if (localTimestamp >= remoteTimestamp) {
      return _MergeResult(
        value: localValue,
        timestamp: localTimestamp,
        isConflict: isConflict,
        losingValue: isConflict ? remoteValue : null,
      );
    } else {
      return _MergeResult(
        value: remoteValue,
        timestamp: remoteTimestamp,
        isConflict: isConflict,
        losingValue: isConflict ? localValue : null,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Serialization
  // -------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'nn': nodeNum,
      'fs': firstSeen.millisecondsSinceEpoch,
      'ls': lastSeen.millisecondsSinceEpoch,
      'ec': encounterCount,
      if (maxDistanceSeen != null) 'md': maxDistanceSeen,
      if (bestSnr != null) 'bs': bestSnr,
      if (bestRssi != null) 'br': bestRssi,
      'mc': messageCount,
      if (socialTag != null) 'st': socialTag!.index,
      if (socialTagUpdatedAtMs != null) 'st_ms': socialTagUpdatedAtMs,
      if (userNote != null) 'un': userNote,
      if (userNoteUpdatedAtMs != null) 'un_ms': userNoteUpdatedAtMs,
      'enc': encounters.map((e) => e.toJson()).toList(),
      'sr': seenRegions.map((r) => r.toJson()).toList(),
      // Schema v2: store CoSeenRelationship objects.
      'csn': coSeenNodes.map((k, v) => MapEntry(k.toString(), v.toJson())),
      if (sigil != null) 'sig': sigil!.toJson(),
    };
  }

  /// Deserialize from JSON, supporting both schema v1 and v2.
  ///
  /// v1 `csn` format: `{"nodeNum": count}` (plain int values)
  /// v2 `csn` format: `{"nodeNum": {"c": ..., "fs": ..., "ls": ...}}`
  ///
  /// Legacy v1 entries are transparently migrated to v2 using the
  /// entry's own firstSeen as the fallback timestamp.
  factory NodeDexEntry.fromJson(Map<String, dynamic> json) {
    final entryFirstSeen = DateTime.fromMillisecondsSinceEpoch(
      json['fs'] as int,
    );

    // Parse co-seen nodes with v1/v2 migration.
    final coSeenRaw = json['csn'] as Map<String, dynamic>? ?? {};
    final coSeen = <int, CoSeenRelationship>{};
    for (final entry in coSeenRaw.entries) {
      final nodeNum = int.parse(entry.key);
      coSeen[nodeNum] = CoSeenRelationship.fromJson(
        entry.value,
        fallbackFirstSeen: entryFirstSeen,
      );
    }

    return NodeDexEntry(
      nodeNum: json['nn'] as int,
      firstSeen: entryFirstSeen,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['ls'] as int),
      encounterCount: json['ec'] as int? ?? 1,
      maxDistanceSeen: (json['md'] as num?)?.toDouble(),
      bestSnr: json['bs'] as int?,
      bestRssi: json['br'] as int?,
      messageCount: json['mc'] as int? ?? 0,
      socialTag: json['st'] != null
          ? NodeSocialTag.values[json['st'] as int]
          : null,
      socialTagUpdatedAtMs: json['st_ms'] as int?,
      userNote: json['un'] as String?,
      userNoteUpdatedAtMs: json['un_ms'] as int?,
      encounters:
          (json['enc'] as List<dynamic>?)
              ?.map((e) => EncounterRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      seenRegions:
          (json['sr'] as List<dynamic>?)
              ?.map((r) => SeenRegion.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      coSeenNodes: coSeen,
      sigil: json['sig'] != null
          ? SigilData.fromJson(json['sig'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Encode a list of entries to a JSON string for storage.
  static String encodeList(List<NodeDexEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }

  /// Decode a JSON string to a list of entries.
  static List<NodeDexEntry> decodeList(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => NodeDexEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeDexEntry &&
          runtimeType == other.runtimeType &&
          nodeNum == other.nodeNum &&
          socialTag == other.socialTag &&
          userNote == other.userNote &&
          encounterCount == other.encounterCount &&
          messageCount == other.messageCount &&
          bestSnr == other.bestSnr &&
          bestRssi == other.bestRssi &&
          maxDistanceSeen == other.maxDistanceSeen &&
          lastSeen == other.lastSeen &&
          encounters.length == other.encounters.length &&
          seenRegions.length == other.seenRegions.length &&
          coSeenNodes.length == other.coSeenNodes.length;

  @override
  int get hashCode =>
      Object.hash(nodeNum, socialTag, userNote, encounterCount, messageCount);

  @override
  String toString() =>
      'NodeDexEntry(node: $nodeNum, '
      'encounters: $encounterCount, '
      'regions: $regionCount, '
      'tag: ${socialTag?.displayLabel ?? "none"})';
}

/// Result of merging a single user-editable field.
///
/// Carries the winning value, its timestamp, and whether a conflict
/// was detected (both sides edited within the conflict window).
class _MergeResult<T> {
  final T? value;
  final int? timestamp;
  final bool isConflict;
  final T? losingValue;

  const _MergeResult({
    required this.value,
    required this.timestamp,
    required this.isConflict,
    this.losingValue,
  });
}

/// Aggregate statistics across the entire NodeDex.
///
/// Computed from the full set of NodeDexEntry records to derive
/// explorer titles and summary data for the main screen.
class NodeDexStats {
  /// Total number of unique nodes discovered.
  final int totalNodes;

  /// Total number of distinct regions explored.
  final int totalRegions;

  /// The longest distance ever recorded to any node (meters).
  final double? longestDistance;

  /// Total encounter count across all nodes.
  final int totalEncounters;

  /// The oldest discovery date.
  final DateTime? oldestDiscovery;

  /// The most recent discovery date.
  final DateTime? newestDiscovery;

  /// Number of nodes with each trait.
  final Map<NodeTrait, int> traitDistribution;

  /// Number of nodes with each social tag.
  final Map<NodeSocialTag, int> socialTagDistribution;

  /// Best SNR ever recorded across all nodes.
  final int? bestSnrOverall;

  /// Best RSSI ever recorded across all nodes.
  final int? bestRssiOverall;

  const NodeDexStats({
    this.totalNodes = 0,
    this.totalRegions = 0,
    this.longestDistance,
    this.totalEncounters = 0,
    this.oldestDiscovery,
    this.newestDiscovery,
    this.traitDistribution = const {},
    this.socialTagDistribution = const {},
    this.bestSnrOverall,
    this.bestRssiOverall,
  });

  /// Derive the explorer title from the current stats.
  ExplorerTitle get explorerTitle {
    if (longestDistance != null &&
        longestDistance! > 10000 &&
        totalNodes >= 50) {
      return ExplorerTitle.longRangeRecordHolder;
    }
    if (totalNodes >= 200 && totalRegions >= 5) {
      return ExplorerTitle.meshCartographer;
    }
    if (totalNodes >= 200) {
      return ExplorerTitle.meshVeteran;
    }
    if (totalNodes >= 100) {
      return ExplorerTitle.signalHunter;
    }
    if (totalNodes >= 50) {
      return ExplorerTitle.cartographer;
    }
    if (totalNodes >= 20) {
      return ExplorerTitle.explorer;
    }
    if (totalNodes >= 5) {
      return ExplorerTitle.observer;
    }
    return ExplorerTitle.newcomer;
  }

  /// How many days the user has been exploring.
  int get daysExploring {
    if (oldestDiscovery == null) return 0;
    return DateTime.now().difference(oldestDiscovery!).inDays;
  }
}
