// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart';

enum PresenceConfidence { active, fading, stale, unknown }

/// Fuzzy last-seen buckets for human-friendly time display.
enum LastSeenBucket {
  activeRecently,
  seenToday,
  seenThisWeek,
  inactive;

  String get label {
    switch (this) {
      case LastSeenBucket.activeRecently:
        return 'Active recently';
      case LastSeenBucket.seenToday:
        return 'Seen today';
      case LastSeenBucket.seenThisWeek:
        return 'Seen this week';
      case LastSeenBucket.inactive:
        return 'Inactive';
    }
  }

  /// Derive bucket from duration since last heard.
  static LastSeenBucket fromDuration(Duration? timeSinceLastHeard) {
    if (timeSinceLastHeard == null) return LastSeenBucket.inactive;
    if (timeSinceLastHeard.inMinutes < 15) return LastSeenBucket.activeRecently;
    if (timeSinceLastHeard.inHours < 24) return LastSeenBucket.seenToday;
    if (timeSinceLastHeard.inDays < 7) return LastSeenBucket.seenThisWeek;
    return LastSeenBucket.inactive;
  }
}

/// Confidence tiers for presence signal strength.
enum ConfidenceTier {
  strong,
  moderate,
  weak;

  String get label {
    switch (this) {
      case ConfidenceTier.strong:
        return 'Strong';
      case ConfidenceTier.moderate:
        return 'Moderate';
      case ConfidenceTier.weak:
        return 'Weak';
    }
  }

  /// Derive tier from presence confidence.
  static ConfidenceTier fromConfidence(PresenceConfidence confidence) {
    switch (confidence) {
      case PresenceConfidence.active:
        return ConfidenceTier.strong;
      case PresenceConfidence.fading:
        return ConfidenceTier.moderate;
      case PresenceConfidence.stale:
      case PresenceConfidence.unknown:
        return ConfidenceTier.weak;
    }
  }
}

/// User-expressed intent for why they are on the mesh.
enum PresenceIntent {
  unknown(0),
  available(1),
  camping(2),
  traveling(3),
  emergencyStandby(4),
  relayNode(5),
  passive(6);

  const PresenceIntent(this.value);
  final int value;

  static PresenceIntent fromValue(int? value) {
    if (value == null) return PresenceIntent.unknown;
    return PresenceIntent.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PresenceIntent.unknown,
    );
  }

  String get label {
    switch (this) {
      case PresenceIntent.unknown:
        return 'Unknown';
      case PresenceIntent.available:
        return 'Available';
      case PresenceIntent.camping:
        return 'Camping';
      case PresenceIntent.traveling:
        return 'Traveling';
      case PresenceIntent.emergencyStandby:
        return 'Emergency Standby';
      case PresenceIntent.relayNode:
        return 'Relay Node';
      case PresenceIntent.passive:
        return 'Passive';
    }
  }
}

/// Extended presence info broadcast over the mesh.
/// Serialized as compact JSON: `{"i": <int>, "s": "<status>"}`
@immutable
class ExtendedPresenceInfo {
  final PresenceIntent intent;
  final String? shortStatus;

  static const int maxStatusLength = 64;

  const ExtendedPresenceInfo({
    this.intent = PresenceIntent.unknown,
    this.shortStatus,
  });

  /// Parse from compact JSON payload.
  /// Gracefully handles malformed data by returning defaults.
  factory ExtendedPresenceInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExtendedPresenceInfo();
    try {
      final intent = PresenceIntent.fromValue(json['i'] as int?);
      String? status = json['s'] as String?;
      if (status != null) {
        status = status.trim();
        if (status.isEmpty) status = null;
        if (status != null && status.length > maxStatusLength) {
          status = status.substring(0, maxStatusLength);
        }
      }
      return ExtendedPresenceInfo(intent: intent, shortStatus: status);
    } catch (_) {
      return const ExtendedPresenceInfo();
    }
  }

  /// Parse from JSON string payload.
  factory ExtendedPresenceInfo.fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return const ExtendedPresenceInfo();
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return ExtendedPresenceInfo.fromJson(json);
    } catch (_) {
      return const ExtendedPresenceInfo();
    }
  }

  /// Serialize to compact JSON.
  /// Omits fields that are default/null to minimize payload size.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (intent != PresenceIntent.unknown) {
      json['i'] = intent.value;
    }
    if (shortStatus != null && shortStatus!.isNotEmpty) {
      final trimmed = shortStatus!.trim();
      if (trimmed.isNotEmpty) {
        json['s'] = trimmed.length > maxStatusLength
            ? trimmed.substring(0, maxStatusLength)
            : trimmed;
      }
    }
    return json;
  }

  /// Serialize to JSON string payload.
  /// Returns null if nothing to send (all defaults).
  String? toPayload() {
    final json = toJson();
    if (json.isEmpty) return null;
    return jsonEncode(json);
  }

  /// Check if there's any non-default data to broadcast.
  bool get hasData =>
      intent != PresenceIntent.unknown ||
      (shortStatus != null && shortStatus!.trim().isNotEmpty);

  ExtendedPresenceInfo copyWith({
    PresenceIntent? intent,
    String? shortStatus,
    bool clearStatus = false,
  }) {
    return ExtendedPresenceInfo(
      intent: intent ?? this.intent,
      shortStatus: clearStatus ? null : (shortStatus ?? this.shortStatus),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtendedPresenceInfo &&
          intent == other.intent &&
          shortStatus == other.shortStatus;

  @override
  int get hashCode => Object.hash(intent, shortStatus);
}

@immutable
class PresenceThresholds {
  /// Heard within this window is treated as actively present.
  static const Duration activeWindow = Duration(minutes: 2);

  /// Heard within this window is treated as fading (recent but silent).
  static const Duration fadingWindow = Duration(minutes: 10);

  /// Heard within this window is treated as stale (likely offline).
  static const Duration staleWindow = Duration(minutes: 60);

  const PresenceThresholds();
}

class PresenceCalculator {
  static PresenceConfidence fromLastHeard(
    DateTime? lastHeard, {
    required DateTime now,
  }) {
    if (lastHeard == null) {
      return PresenceConfidence.unknown;
    }

    final age = now.difference(lastHeard);
    if (age <= PresenceThresholds.activeWindow) {
      return PresenceConfidence.active;
    }
    if (age <= PresenceThresholds.fadingWindow) {
      return PresenceConfidence.fading;
    }
    if (age <= PresenceThresholds.staleWindow) {
      return PresenceConfidence.stale;
    }
    return PresenceConfidence.unknown;
  }
}

extension PresenceConfidenceText on PresenceConfidence {
  String get label {
    switch (this) {
      case PresenceConfidence.active:
        return 'Active';
      case PresenceConfidence.fading:
        return 'Seen recently';
      case PresenceConfidence.stale:
        return 'Inactive';
      case PresenceConfidence.unknown:
        return 'Unknown';
    }
  }

  bool get isActive => this == PresenceConfidence.active;
  bool get isFading => this == PresenceConfidence.fading;
  bool get isStale => this == PresenceConfidence.stale;
  bool get isUnknown => this == PresenceConfidence.unknown;
  bool get isInactive =>
      this == PresenceConfidence.stale || this == PresenceConfidence.unknown;
}

/// Icon data helper for PresenceIntent (separate to avoid circular import)
class PresenceIntentIcons {
  static const Map<PresenceIntent, int> _iconCodes = {
    PresenceIntent.unknown: 0xe8fd, // help_outline
    PresenceIntent.available: 0xe558, // person
    PresenceIntent.camping: 0xea3a, // cabin
    PresenceIntent.traveling: 0xe531, // directions_car
    PresenceIntent.emergencyStandby: 0xeb2e, // emergency
    PresenceIntent.relayNode: 0xe1b1, // router
    PresenceIntent.passive: 0xe63e, // visibility_off
  };

  static int codeFor(PresenceIntent intent) => _iconCodes[intent] ?? 0xe8fd;
}
