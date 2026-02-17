// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../models/aether_flight.dart';
import 'aether_providers.dart';

/// SharedPreferences keys for persisting flight notification state.
const _kNotifiedNodeIds = 'aether_notified_node_ids';
const _kDismissedOverlayNodeIds = 'aether_dismissed_overlay_node_ids';

/// Grace period after a flight is activated before it can produce a match.
/// Prevents false positives when Device A schedules a flight and Device B
/// is still physically next to it on the ground.
const Duration _kMinAirborneGrace = Duration(minutes: 10);

/// A match between a mesh node in your node list and an active Aether flight.
class AetherFlightMatch {
  /// The Aether flight that the node is on.
  final AetherFlight flight;

  /// The local mesh node that was matched.
  final MeshNode node;

  /// When this match was first detected.
  final DateTime detectedAt;

  const AetherFlightMatch({
    required this.flight,
    required this.node,
    required this.detectedAt,
  });
}

/// State for the flight matcher, tracking current matches and which ones
/// have already been notified to avoid repeated alerts.
class AetherFlightMatcherState {
  /// Currently active matches (node is in mesh + flight is active).
  final List<AetherFlightMatch> matches;

  /// Node IDs (hex) that have already triggered a notification this session.
  /// Prevents spamming the user when the same node reconnects.
  final Set<String> notifiedNodeIds;

  /// Node IDs whose overlay card was manually dismissed by the user.
  /// These matches still appear in the Aether screen section but
  /// no longer show as a floating overlay.
  final Set<String> dismissedOverlayNodeIds;

  /// Whether active flights have been fetched at least once.
  final bool hasFetched;

  const AetherFlightMatcherState({
    this.matches = const [],
    this.notifiedNodeIds = const {},
    this.dismissedOverlayNodeIds = const {},
    this.hasFetched = false,
  });

  AetherFlightMatcherState copyWith({
    List<AetherFlightMatch>? matches,
    Set<String>? notifiedNodeIds,
    Set<String>? dismissedOverlayNodeIds,
    bool? hasFetched,
  }) {
    return AetherFlightMatcherState(
      matches: matches ?? this.matches,
      notifiedNodeIds: notifiedNodeIds ?? this.notifiedNodeIds,
      dismissedOverlayNodeIds:
          dismissedOverlayNodeIds ?? this.dismissedOverlayNodeIds,
      hasFetched: hasFetched ?? this.hasFetched,
    );
  }
}

/// Normalizes a Meshtastic node ID to a comparable lowercase hex string
/// without the leading '!' prefix.
///
/// Node IDs in AetherFlight use the `!hex` format (e.g., `!a1b2c3d4`),
/// while MeshNode stores `userId` as `!a1b2c3d4` and `nodeNum` as int.
String _normalizeNodeId(String id) {
  final trimmed = id.trim().toLowerCase();
  if (trimmed.startsWith('!')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

/// Notifier that cross-references discovered mesh nodes with active
/// Aether flights. When a node in the local mesh matches an active
/// flight's node ID, it creates a match entry and exposes it for
/// UI display and notifications.
class AetherFlightMatcherNotifier extends Notifier<AetherFlightMatcherState> {
  @override
  AetherFlightMatcherState build() {
    AppLogging.aether('AetherFlightMatcherNotifier.build() — initializing');
    // Watch the local nodes list for changes
    ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, next) {
      _recheckMatches();
    });

    // Watch Firestore active flights for real-time updates
    ref.listen(aetherActiveFlightsProvider, (previous, next) {
      _recheckMatches();
    });

    // Restore persisted notification state, then fetch flights
    _restorePersistedState();

    return const AetherFlightMatcherState();
  }

  /// Restore notified / dismissed sets from SharedPreferences so
  /// the user is not re-alerted for flights they already saw.
  Future<void> _restorePersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notified = prefs.getStringList(_kNotifiedNodeIds) ?? [];
      final dismissed = prefs.getStringList(_kDismissedOverlayNodeIds) ?? [];
      state = state.copyWith(
        notifiedNodeIds: {...state.notifiedNodeIds, ...notified},
        dismissedOverlayNodeIds: {
          ...state.dismissedOverlayNodeIds,
          ...dismissed,
        },
      );
      AppLogging.aether(
        'Flight matcher: restored ${notified.length} notified, '
        '${dismissed.length} dismissed from disk',
      );
    } catch (e) {
      AppLogging.aether(
        'Flight matcher: failed to restore persisted state: $e',
      );
    }
    // Now safe to fetch flights
    await _fetchApiFlights();
  }

  /// Persist the notified set to disk.
  Future<void> _persistNotified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kNotifiedNodeIds,
        state.notifiedNodeIds.toList(),
      );
    } catch (e) {
      AppLogging.aether('Flight matcher: failed to persist notified: $e');
    }
  }

  /// Persist the dismissed overlay set to disk.
  Future<void> _persistDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kDismissedOverlayNodeIds,
        state.dismissedOverlayNodeIds.toList(),
      );
    } catch (e) {
      AppLogging.aether('Flight matcher: failed to persist dismissed: $e');
    }
  }

  /// Active flights from the REST API (community-shared).
  List<AetherFlight> _apiFlights = [];

  /// Fetch active flights from the Aether API so we can detect
  /// community-shared flights too, not just the user's own.
  Future<void> _fetchApiFlights() async {
    try {
      final shareService = ref.read(aetherShareServiceProvider);
      final page = await shareService.fetchFlights(
        activeOnly: true,
        limit: 100,
      );
      _apiFlights = page.flights;
      AppLogging.aether(
        'Flight matcher: fetched ${_apiFlights.length} active API flights',
      );
      _recheckMatches();
    } catch (e) {
      AppLogging.aether(
        'Flight matcher: API fetch failed (will use Firestore only): $e',
      );
    }
  }

  /// Refresh API flights. Called periodically or on user action.
  Future<void> refresh() async {
    await _fetchApiFlights();
  }

  /// Cross-reference all known active flights against discovered nodes.
  void _recheckMatches() {
    final nodes = ref.read(nodesProvider);
    if (nodes.isEmpty) {
      if (state.matches.isNotEmpty) {
        AppLogging.aether('Flight matcher: nodes empty, clearing matches');
        state = state.copyWith(matches: [], hasFetched: true);
      }
      return;
    }

    // Combine Firestore and API active flights, deduplicate by flight ID
    final firestoreFlights =
        ref.read(aetherActiveFlightsProvider).asData?.value ?? [];
    final allFlights = <String, AetherFlight>{};
    for (final f in firestoreFlights) {
      allFlights[f.id] = f;
    }
    for (final f in _apiFlights) {
      allFlights.putIfAbsent(f.id, () => f);
    }

    if (allFlights.isEmpty) {
      if (state.matches.isNotEmpty) {
        state = state.copyWith(matches: [], hasFetched: true);
      } else if (!state.hasFetched) {
        state = state.copyWith(hasFetched: true);
      }
      return;
    }

    // Build a lookup: normalized hex node ID → MeshNode
    final nodesByHex = <String, MeshNode>{};
    for (final node in nodes.values) {
      // Use userId if available (already has ! prefix), otherwise convert
      final hexId = node.userId ?? '!${node.nodeNum.toRadixString(16)}';
      nodesByHex[_normalizeNodeId(hexId)] = node;
    }

    // Find matches
    final now = DateTime.now();
    final currentUid = ref.read(aetherCurrentUserIdProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final myNodeHex = myNodeNum?.toRadixString(16).toLowerCase();
    final newMatches = <AetherFlightMatch>[];
    for (final flight in allFlights.values) {
      if (flight.nodeId.isEmpty) continue;

      // Skip the current user's own flights — they already know about them.
      if (currentUid != null &&
          flight.userId.isNotEmpty &&
          flight.userId == currentUid) {
        continue;
      }

      // Skip flights whose own node is this device — can't receive yourself.
      final normalizedFlightNode = _normalizeNodeId(flight.nodeId);
      if (myNodeHex != null && normalizedFlightNode == myNodeHex) {
        continue;
      }

      // Grace period: skip flights that were activated less than 10 minutes
      // ago. This avoids false matches when the flight node is still on the
      // ground near the reporting device.
      final airborneAt = flight.scheduledDeparture;
      if (now.difference(airborneAt) < _kMinAirborneGrace) {
        continue;
      }

      final matchedNode = nodesByHex[normalizedFlightNode];
      if (matchedNode != null) {
        // Preserve the original detection time if this is an existing match
        final existingMatch = state.matches
            .where(
              (m) => _normalizeNodeId(m.flight.nodeId) == normalizedFlightNode,
            )
            .firstOrNull;
        newMatches.add(
          AetherFlightMatch(
            flight: flight,
            node: matchedNode,
            detectedAt: existingMatch?.detectedAt ?? DateTime.now(),
          ),
        );
      }
    }

    state = state.copyWith(matches: newMatches, hasFetched: true);
    if (newMatches.isNotEmpty) {
      AppLogging.aether(
        'Flight matcher: ${newMatches.length} match(es) found — '
        '${newMatches.map((m) => m.flight.flightNumber).join(', ')}',
      );
    }

    // Prune persisted state for flights that are no longer active
    // so stale entries don't accumulate across sessions.
    final activeNodeIds = newMatches
        .map((m) => _normalizeNodeId(m.flight.nodeId))
        .toSet();
    final staleNotified = state.notifiedNodeIds.difference(activeNodeIds);
    final staleDismissed = state.dismissedOverlayNodeIds.difference(
      activeNodeIds,
    );
    if (staleNotified.isNotEmpty || staleDismissed.isNotEmpty) {
      state = state.copyWith(
        notifiedNodeIds: state.notifiedNodeIds.difference(staleNotified),
        dismissedOverlayNodeIds: state.dismissedOverlayNodeIds.difference(
          staleDismissed,
        ),
      );
      _persistNotified();
      _persistDismissed();
      AppLogging.aether(
        'Flight matcher: pruned ${staleNotified.length} notified, '
        '${staleDismissed.length} dismissed stale entries',
      );
    }
  }

  /// Mark a node ID as notified so we don't alert the user again.
  /// Persisted to disk so the notification survives app restarts.
  void markNotified(String nodeId) {
    AppLogging.aether('Flight matcher: markNotified($nodeId)');
    final normalized = _normalizeNodeId(nodeId);
    state = state.copyWith(
      notifiedNodeIds: {...state.notifiedNodeIds, normalized},
    );
    _persistNotified();
  }

  /// Get matches that haven't been notified yet.
  List<AetherFlightMatch> get unnotifiedMatches {
    return state.matches.where((m) {
      final normalized = _normalizeNodeId(m.flight.nodeId);
      return !state.notifiedNodeIds.contains(normalized);
    }).toList();
  }

  /// Dismiss a match from the floating overlay. The match still
  /// appears in the Aether screen section for later action.
  /// Persisted to disk so the overlay stays dismissed across restarts.
  void dismissOverlay(String nodeId) {
    AppLogging.aether('Flight matcher: dismissOverlay($nodeId)');
    final normalized = _normalizeNodeId(nodeId);
    state = state.copyWith(
      dismissedOverlayNodeIds: {...state.dismissedOverlayNodeIds, normalized},
    );
    _persistDismissed();
  }

  /// Clear persisted notification state. Called when all flights for
  /// a node have ended so stale entries don't accumulate forever.
  Future<void> clearPersistedStateForNode(String nodeId) async {
    final normalized = _normalizeNodeId(nodeId);
    final newNotified = {...state.notifiedNodeIds}..remove(normalized);
    final newDismissed = {...state.dismissedOverlayNodeIds}..remove(normalized);
    state = state.copyWith(
      notifiedNodeIds: newNotified,
      dismissedOverlayNodeIds: newDismissed,
    );
    await _persistNotified();
    await _persistDismissed();
  }

  /// Matches that should show in the floating overlay (not dismissed).
  List<AetherFlightMatch> get activeOverlayMatches {
    return state.matches.where((m) {
      final normalized = _normalizeNodeId(m.flight.nodeId);
      return !state.dismissedOverlayNodeIds.contains(normalized);
    }).toList();
  }
}

/// Provider for the Aether flight matcher.
final aetherFlightMatcherProvider =
    NotifierProvider<AetherFlightMatcherNotifier, AetherFlightMatcherState>(
      AetherFlightMatcherNotifier.new,
    );

/// Convenience provider that exposes just the current matches list.
final aetherFlightMatchesProvider = Provider<List<AetherFlightMatch>>((ref) {
  return ref.watch(aetherFlightMatcherProvider).matches;
});

/// Matches that should appear in the floating overlay (not dismissed).
final aetherOverlayMatchesProvider = Provider<List<AetherFlightMatch>>((ref) {
  final state = ref.watch(aetherFlightMatcherProvider);
  return state.matches.where((m) {
    final normalized = _normalizeNodeId(m.flight.nodeId);
    return !state.dismissedOverlayNodeIds.contains(normalized);
  }).toList();
});
