// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';

enum PresenceConfidence { active, fading, stale, unknown }

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
