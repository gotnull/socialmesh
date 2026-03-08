// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Nearby activity model for Mesh Explorer.
///
/// Represents a single public-facing event derived from MRRP service
/// advert state changes. Activity items are ephemeral, deduplicated,
/// and capped to keep the experience ambient rather than noisy.
library;

import 'package:flutter/material.dart';

/// The type of nearby activity event.
enum NearbyActivityType {
  /// A new public service appeared.
  serviceAppeared,

  /// An existing public service was updated (re-advertised).
  serviceUpdated,

  /// A public service expired and is no longer visible.
  serviceExpired,
}

/// A single nearby activity event derived from MRRP service advert changes.
///
/// Immutable value type — equality is based on [id].
class NearbyActivity {
  /// Stable identifier for deduplication: `nodeId:serviceId`.
  final String id;

  /// Activity type.
  final NearbyActivityType type;

  /// The MRRP service ID that triggered this activity.
  final int serviceId;

  /// The remote peer's node ID.
  final int nodeId;

  /// Human-readable title for the activity (e.g. "Bulletin Board").
  final String title;

  /// Short human-readable subtitle (e.g. "New board nearby").
  final String subtitle;

  /// Icon to display for this activity.
  final IconData icon;

  /// When this activity event occurred.
  final DateTime occurredAt;

  /// When this activity expires and should be removed from the feed.
  final DateTime expiresAt;

  const NearbyActivity({
    required this.id,
    required this.type,
    required this.serviceId,
    required this.nodeId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.occurredAt,
    required this.expiresAt,
  });

  /// Whether this activity has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NearbyActivity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
