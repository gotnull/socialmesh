// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../models/aether_flight.dart';
import 'aether_providers.dart';

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
    // Watch the local nodes list for changes
    ref.listen<Map<int, MeshNode>>(nodesProvider, (previous, next) {
      _recheckMatches();
    });

    // Watch Firestore active flights for real-time updates
    ref.listen(aetherActiveFlightsProvider, (previous, next) {
      _recheckMatches();
    });

    // Also do an initial fetch from the API for community flights
    _fetchApiFlights();

    return const AetherFlightMatcherState();
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
    final newMatches = <AetherFlightMatch>[];
    for (final flight in allFlights.values) {
      if (flight.nodeId.isEmpty) continue;
      final normalizedFlightNode = _normalizeNodeId(flight.nodeId);
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
  }

  /// Mark a node ID as notified so we don't alert the user again
  /// for the same flight during this session.
  void markNotified(String nodeId) {
    final normalized = _normalizeNodeId(nodeId);
    state = state.copyWith(
      notifiedNodeIds: {...state.notifiedNodeIds, normalized},
    );
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
  void dismissOverlay(String nodeId) {
    final normalized = _normalizeNodeId(nodeId);
    state = state.copyWith(
      dismissedOverlayNodeIds: {...state.dismissedOverlayNodeIds, normalized},
    );
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
