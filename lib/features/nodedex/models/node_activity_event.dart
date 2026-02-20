// SPDX-License-Identifier: GPL-3.0-or-later

// Node Activity Event — union type for the node activity timeline.
//
// Each variant represents one observable event in a node's history.
// Events are aggregated from multiple data sources (encounters,
// messages, presence transitions, signals, milestones) and sorted
// chronologically to form a unified activity feed.

import 'package:flutter/foundation.dart';

import '../../../models/presence_confidence.dart';

/// The kind of event in the node activity timeline.
enum NodeActivityEventType {
  /// A recorded encounter observation.
  encounter,

  /// A mesh message sent to or received from the node.
  message,

  /// A presence state transition (e.g. active -> fading).
  presenceChange,

  /// A signal (ephemeral post) from the node.
  signal,

  /// A noteworthy milestone (e.g. first seen, 100th encounter).
  milestone,
}

/// A single event in the node activity timeline.
///
/// Sealed class hierarchy — each variant carries type-specific
/// data while sharing the common [timestamp] and [type] fields
/// needed for sorting and rendering.
@immutable
sealed class NodeActivityEvent implements Comparable<NodeActivityEvent> {
  /// When this event occurred.
  final DateTime timestamp;

  /// The discriminator for switch-based rendering.
  final NodeActivityEventType type;

  const NodeActivityEvent({required this.timestamp, required this.type});

  /// Sort descending by timestamp (newest first).
  @override
  int compareTo(NodeActivityEvent other) =>
      other.timestamp.compareTo(timestamp);
}

/// An encounter observation event.
///
/// When [count] is 1 this represents a single encounter. When > 1 it
/// represents a session of consecutive encounters grouped within a
/// time window. The [timestamp] is the most recent encounter and
/// [sessionStart] the earliest in the session. Metric fields hold the
/// best values observed across the session.
class EncounterActivityEvent extends NodeActivityEvent {
  /// Number of encounters in this session (1 = single encounter).
  final int count;

  /// Start of the session (differs from [timestamp] only when [count] > 1).
  final DateTime sessionStart;

  /// Best (closest) distance in meters across the session, if available.
  final double? distanceMeters;

  /// Best signal-to-noise ratio across the session.
  final int? snr;

  /// Best RSSI across the session.
  final int? rssi;

  /// Latitude of the most recent encounter, if available.
  final double? latitude;

  /// Longitude of the most recent encounter, if available.
  final double? longitude;

  const EncounterActivityEvent({
    required super.timestamp,
    this.count = 1,
    DateTime? sessionStart,
    this.distanceMeters,
    this.snr,
    this.rssi,
    this.latitude,
    this.longitude,
  }) : sessionStart = sessionStart ?? timestamp,
       super(type: NodeActivityEventType.encounter);
}

/// A mesh message event.
class MessageActivityEvent extends NodeActivityEvent {
  /// The message text (truncated for timeline display).
  final String text;

  /// Whether the message was sent by the local user.
  final bool outgoing;

  /// Channel number, if applicable.
  final int? channel;

  const MessageActivityEvent({
    required super.timestamp,
    required this.text,
    required this.outgoing,
    this.channel,
  }) : super(type: NodeActivityEventType.message);
}

/// A presence state transition event.
class PresenceChangeActivityEvent extends NodeActivityEvent {
  /// The previous presence state.
  final PresenceConfidence fromState;

  /// The new presence state.
  final PresenceConfidence toState;

  const PresenceChangeActivityEvent({
    required super.timestamp,
    required this.fromState,
    required this.toState,
  }) : super(type: NodeActivityEventType.presenceChange);
}

/// A signal (ephemeral post) from the node.
class SignalActivityEvent extends NodeActivityEvent {
  /// The signal content text (truncated for timeline display).
  final String content;

  /// Signal ID for navigation.
  final String signalId;

  const SignalActivityEvent({
    required super.timestamp,
    required this.content,
    required this.signalId,
  }) : super(type: NodeActivityEventType.signal);
}

/// The kind of milestone achieved.
enum MilestoneKind {
  /// The very first time this node was discovered.
  firstSeen,

  /// A round encounter count (10th, 50th, 100th, etc.).
  encounterMilestone,
}

/// A milestone event in the node's history.
class MilestoneActivityEvent extends NodeActivityEvent {
  /// What kind of milestone this is.
  final MilestoneKind kind;

  /// Human-readable label for the milestone.
  final String label;

  const MilestoneActivityEvent({
    required super.timestamp,
    required this.kind,
    required this.label,
  }) : super(type: NodeActivityEventType.milestone);
}
