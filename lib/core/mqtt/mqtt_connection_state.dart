// SPDX-License-Identifier: GPL-3.0-or-later

/// Connection state machine for the Global Layer (MQTT) feature.
///
/// This defines all possible states of the Global Layer connection,
/// valid transitions between them, and display helpers for the UI.
/// The state machine enforces correctness — invalid transitions are
/// rejected and logged rather than silently accepted.
library;

import 'package:flutter/material.dart';

/// The connection state of the Global Layer broker link.
///
/// State diagram:
///
///   disabled ──► disconnected ──► connecting ──► connected
///                     ▲                              │
///                     │                              ▼
///                disconnecting ◄─── degraded ◄── (failures)
///                     ▲               │
///                     │               ▼
///                     └──────── reconnecting ──► connected
///
///   Any state can transition to [error], which auto-resolves
///   to [disconnected] after the error is surfaced.
enum GlobalLayerConnectionState {
  /// The Global Layer feature is not configured or explicitly turned off.
  /// This is the initial state before setup is completed.
  disabled,

  /// Configured but not currently connected to the broker.
  disconnected,

  /// Actively establishing a connection to the broker.
  connecting,

  /// Successfully connected and subscribed to configured topics.
  connected,

  /// Connection was established but is experiencing issues
  /// (e.g. repeated ping failures, partial subscription loss).
  degraded,

  /// Attempting to restore a previously established connection
  /// after a transient failure.
  reconnecting,

  /// Gracefully shutting down the connection.
  disconnecting,

  /// An unrecoverable error occurred. The UI should surface the
  /// error details and offer corrective actions.
  error;

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Human-readable label for the status panel.
  String get displayLabel => switch (this) {
    disabled => 'Not Set Up',
    disconnected => 'Disconnected',
    connecting => 'Connecting',
    connected => 'Connected',
    degraded => 'Degraded',
    reconnecting => 'Reconnecting',
    disconnecting => 'Disconnecting',
    error => 'Error',
  };

  /// Short description shown below the status label.
  String get displayDescription => switch (this) {
    disabled => 'Complete setup to connect your mesh to the wider world.',
    disconnected => 'The Global Layer is configured but not active.',
    connecting => 'Establishing a connection to the broker\u2026',
    connected => 'Your mesh is bridged to the Global Layer.',
    degraded => 'Connected with issues. Some data may not be flowing.',
    reconnecting => 'Connection lost. Attempting to reconnect\u2026',
    disconnecting => 'Closing the connection\u2026',
    error => 'Something went wrong. Check diagnostics for details.',
  };

  /// Material icon for the status indicator.
  IconData get icon => switch (this) {
    disabled => Icons.cloud_off_outlined,
    disconnected => Icons.cloud_off_outlined,
    connecting => Icons.cloud_sync_outlined,
    connected => Icons.cloud_done_outlined,
    degraded => Icons.cloud_outlined,
    reconnecting => Icons.cloud_sync_outlined,
    disconnecting => Icons.cloud_sync_outlined,
    error => Icons.error_outline,
  };

  /// Semantic color for the status indicator.
  ///
  /// Returns a color that works in both light and dark themes.
  /// These are intentionally static values rather than theme-dependent
  /// because they carry semantic meaning (green = good, red = bad).
  Color get statusColor => switch (this) {
    disabled => const Color(0xFF9CA3AF), // grey
    disconnected => const Color(0xFF9CA3AF), // grey
    connecting => const Color(0xFFFBBF24), // amber
    connected => const Color(0xFF4ADE80), // green
    degraded => const Color(0xFFFF9D6E), // orange
    reconnecting => const Color(0xFFFBBF24), // amber
    disconnecting => const Color(0xFF9CA3AF), // grey
    error => const Color(0xFFEF4444), // red
  };

  // ---------------------------------------------------------------------------
  // State classification
  // ---------------------------------------------------------------------------

  /// Whether the connection is in a transitional state (connecting,
  /// reconnecting, or disconnecting).
  bool get isTransitional => switch (this) {
    connecting || reconnecting || disconnecting => true,
    _ => false,
  };

  /// Whether the connection is in a state where data can potentially flow.
  bool get isActive => switch (this) {
    connected || degraded => true,
    _ => false,
  };

  /// Whether the feature is configured (setup has been completed).
  bool get isConfigured => this != disabled;

  /// Whether user-initiated actions (reconnect, disconnect, pause)
  /// should be available.
  bool get allowsUserActions => switch (this) {
    connected || degraded || disconnected || error => true,
    _ => false,
  };

  /// Whether the status indicator should pulse or animate.
  /// Respects Reduce Motion preference at the call site.
  bool get shouldAnimate => isTransitional;
}

/// Validates and documents transitions in the Global Layer state machine.
///
/// This class is intentionally stateless — it operates on a
/// (current, target) pair and returns whether the transition is valid.
/// The actual state is held by the provider layer.
class GlobalLayerStateMachine {
  GlobalLayerStateMachine._();

  /// Set of all valid (from, to) state transitions.
  ///
  /// Any transition not in this set is considered invalid and will
  /// be rejected by [canTransition].
  static final Set<(GlobalLayerConnectionState, GlobalLayerConnectionState)>
  _validTransitions = {
    // Feature lifecycle
    (
      GlobalLayerConnectionState.disabled,
      GlobalLayerConnectionState.disconnected,
    ),

    // Normal connect flow
    (
      GlobalLayerConnectionState.disconnected,
      GlobalLayerConnectionState.connecting,
    ),
    (
      GlobalLayerConnectionState.connecting,
      GlobalLayerConnectionState.connected,
    ),
    (GlobalLayerConnectionState.connecting, GlobalLayerConnectionState.error),
    (
      GlobalLayerConnectionState.connecting,
      GlobalLayerConnectionState.disconnected,
    ), // user cancel
    // Normal disconnect flow
    (
      GlobalLayerConnectionState.connected,
      GlobalLayerConnectionState.disconnecting,
    ),
    (
      GlobalLayerConnectionState.disconnecting,
      GlobalLayerConnectionState.disconnected,
    ),

    // Degradation
    (GlobalLayerConnectionState.connected, GlobalLayerConnectionState.degraded),
    (
      GlobalLayerConnectionState.degraded,
      GlobalLayerConnectionState.connected,
    ), // recovery
    (
      GlobalLayerConnectionState.degraded,
      GlobalLayerConnectionState.reconnecting,
    ),
    (
      GlobalLayerConnectionState.degraded,
      GlobalLayerConnectionState.disconnecting,
    ),

    // Reconnection
    (
      GlobalLayerConnectionState.reconnecting,
      GlobalLayerConnectionState.connected,
    ),
    (GlobalLayerConnectionState.reconnecting, GlobalLayerConnectionState.error),
    (
      GlobalLayerConnectionState.reconnecting,
      GlobalLayerConnectionState.disconnected,
    ), // give up / user cancel
    // Unexpected disconnect (broker drop, network loss)
    (
      GlobalLayerConnectionState.connected,
      GlobalLayerConnectionState.reconnecting,
    ),

    // Error recovery
    (GlobalLayerConnectionState.error, GlobalLayerConnectionState.disconnected),
    (
      GlobalLayerConnectionState.error,
      GlobalLayerConnectionState.connecting,
    ), // retry
    // Feature disable (from any configured state)
    (
      GlobalLayerConnectionState.disconnected,
      GlobalLayerConnectionState.disabled,
    ),
    (GlobalLayerConnectionState.connected, GlobalLayerConnectionState.disabled),
    (GlobalLayerConnectionState.degraded, GlobalLayerConnectionState.disabled),
    (GlobalLayerConnectionState.error, GlobalLayerConnectionState.disabled),
  };

  /// Returns `true` if transitioning from [from] to [to] is valid.
  static bool canTransition(
    GlobalLayerConnectionState from,
    GlobalLayerConnectionState to,
  ) {
    if (from == to) return false; // No self-transitions
    return _validTransitions.contains((from, to));
  }

  /// Returns the set of states reachable from [current].
  static Set<GlobalLayerConnectionState> reachableFrom(
    GlobalLayerConnectionState current,
  ) {
    return _validTransitions
        .where((pair) => pair.$1 == current)
        .map((pair) => pair.$2)
        .toSet();
  }

  /// Describes why a transition is invalid, for logging and diagnostics.
  ///
  /// Returns `null` if the transition is valid.
  static String? transitionError(
    GlobalLayerConnectionState from,
    GlobalLayerConnectionState to,
  ) {
    if (from == to) {
      return 'Cannot transition from ${from.name} to itself.';
    }
    if (!canTransition(from, to)) {
      final reachable = reachableFrom(from).map((s) => s.name).join(', ');
      return 'Invalid transition: ${from.name} -> ${to.name}. '
          'Valid targets from ${from.name}: [$reachable].';
    }
    return null;
  }
}

/// A timestamped record of a state transition, used for diagnostics
/// and the status panel history.
class GlobalLayerStateTransition {
  /// The state before the transition.
  final GlobalLayerConnectionState from;

  /// The state after the transition.
  final GlobalLayerConnectionState to;

  /// When the transition occurred.
  final DateTime timestamp;

  /// Optional human-readable reason for the transition
  /// (e.g. "User tapped Reconnect", "Broker closed connection").
  final String? reason;

  /// Optional error message if transitioning to [GlobalLayerConnectionState.error].
  final String? errorMessage;

  const GlobalLayerStateTransition({
    required this.from,
    required this.to,
    required this.timestamp,
    this.reason,
    this.errorMessage,
  });

  /// Duration since this transition occurred.
  Duration get age => DateTime.now().difference(timestamp);

  /// Redacted representation safe for diagnostics export.
  /// No secrets can appear in state transitions, but this method
  /// exists for API consistency with other redactable models.
  Map<String, dynamic> toRedactedJson() => {
    'from': from.name,
    'to': to.name,
    'timestamp': timestamp.toIso8601String(),
    if (reason != null) 'reason': reason,
    if (errorMessage != null) 'error': errorMessage,
  };

  @override
  String toString() =>
      'GlobalLayerStateTransition(${from.name} -> ${to.name}, '
      '${timestamp.toIso8601String()}'
      '${reason != null ? ', reason: $reason' : ''}'
      '${errorMessage != null ? ', error: $errorMessage' : ''})';
}
