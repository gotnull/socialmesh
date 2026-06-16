// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../models/presence_confidence.dart';
import '../../utils/timestamp_validation.dart';

/// Operational health of a node for SiteOps visibility.
///
/// This is a coarse, protocol-agnostic projection used by site operators to
/// answer "is this node reporting, overdue, presumed down, or never seen?".
/// It is deliberately distinct from the social [PresenceConfidence] tiers
/// (active / fading / stale / unknown) and does not change any presence
/// behaviour, labels, chips, filters, or sorting.
enum NodeHealthState {
  /// Reporting normally — heard within [PresenceThresholds.freshWindow].
  fresh,

  /// Overdue — heard within the 2 h online window but past the fresh window.
  stale,

  /// No signal — not heard beyond the 2 h online window. This is INFERRED, not
  /// confirmed: LoRa has no offline signal, so the node may be down, out of
  /// range, asleep, or simply idle. Surfaced as "No signal", never "Offline".
  offline,

  /// Never heard, or an implausible / out-of-order timestamp.
  unknown,
}

/// Classify a node's operational health from its most recent activity
/// timestamp ([lastActivity]) relative to [now].
///
/// - [NodeHealthState.unknown] when [lastActivity] is null, implausible
///   (per [TimestampValidation.isPlausible]), or yields a negative age.
/// - [NodeHealthState.fresh] when age <= [PresenceThresholds.freshWindow]
///   (15 minutes).
/// - [NodeHealthState.stale] when age <= [PresenceThresholds.onlineWindow]
///   (2 hours).
/// - [NodeHealthState.offline] otherwise.
///
/// The offline boundary reuses [PresenceThresholds.onlineWindow] so this
/// projection stays consistent with the existing online/offline line.
NodeHealthState classifyHealth({
  required DateTime? lastActivity,
  required DateTime now,
}) {
  if (lastActivity == null) return NodeHealthState.unknown;
  if (!TimestampValidation.isPlausible(lastActivity, referenceTime: now)) {
    return NodeHealthState.unknown;
  }
  final age = now.difference(lastActivity);
  if (age.isNegative) return NodeHealthState.unknown;
  if (age <= PresenceThresholds.freshWindow) return NodeHealthState.fresh;
  if (age <= PresenceThresholds.onlineWindow) return NodeHealthState.stale;
  return NodeHealthState.offline;
}
