// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/aether/models/aether_flight.dart';
import 'package:socialmesh/features/aether/providers/aether_flight_matcher_provider.dart';
import 'package:socialmesh/features/aether/providers/aether_providers.dart';
import 'package:socialmesh/features/aether/services/aether_share_service.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _TestNodesNotifier extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {};

  void setNodes(Map<int, MeshNode> nodes) {
    state = nodes;
  }
}

/// Fake share service that returns canned active flights without
/// making HTTP requests.
class _FakeShareService extends AetherShareService {
  List<AetherFlight> activeFlights;

  _FakeShareService({this.activeFlights = const []});

  @override
  Future<AetherFlightsPage> fetchFlights({
    String? query,
    String? departure,
    String? arrival,
    String? flightNumber,
    bool? activeOnly,
    AetherSortOption sort = AetherSortOption.newest,
    int page = 1,
    int limit = 20,
  }) async {
    return AetherFlightsPage(
      flights: activeFlights,
      page: 1,
      limit: limit,
      total: activeFlights.length,
      totalPages: 1,
    );
  }
}

AetherFlight _makeFlight({
  String id = 'flight-1',
  String nodeId = '!a1b2c3d4',
  String flightNumber = 'UA123',
  String departure = 'LAX',
  String arrival = 'JFK',
  bool isActive = true,
}) {
  final now = DateTime.now();
  return AetherFlight(
    id: id,
    nodeId: nodeId,
    flightNumber: flightNumber,
    departure: departure,
    arrival: arrival,
    scheduledDeparture: now.subtract(const Duration(hours: 1)),
    scheduledArrival: now.add(const Duration(hours: 4)),
    userId: 'user-1',
    isActive: isActive,
    createdAt: now,
  );
}

MeshNode _makeNode({
  int nodeNum = 0xa1b2c3d4,
  String? userId = '!a1b2c3d4',
  String? longName = 'Flight Node',
  int? rssi = -80,
  int? snr = 5,
}) {
  return MeshNode(
    nodeNum: nodeNum,
    userId: userId,
    longName: longName,
    rssi: rssi,
    snr: snr,
    lastHeard: DateTime.now(),
  );
}

/// Create a [ProviderContainer] with the standard overrides needed for
/// the flight matcher tests. Returns the container and the test helpers.
({
  ProviderContainer container,
  _TestNodesNotifier nodesNotifier,
  _FakeShareService shareService,
})
_createContainer({
  List<AetherFlight> firestoreFlights = const [],
  List<AetherFlight> apiFlights = const [],
}) {
  final nodesNotifier = _TestNodesNotifier();
  final shareService = _FakeShareService(activeFlights: apiFlights);

  final container = ProviderContainer(
    overrides: [
      nodesProvider.overrideWith(() => nodesNotifier),
      aetherActiveFlightsProvider.overrideWithValue(
        AsyncValue.data(firestoreFlights),
      ),
      aetherShareServiceProvider.overrideWithValue(shareService),
    ],
  );

  // Eagerly initialize the matcher so ref.listen callbacks are
  // registered before any test mutates node state.
  container.read(aetherFlightMatcherProvider);

  return (
    container: container,
    nodesNotifier: nodesNotifier,
    shareService: shareService,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AetherFlightMatch model', () {
    test('stores flight, node, and detection time', () {
      final flight = _makeFlight();
      final node = _makeNode();
      final detectedAt = DateTime(2026, 2, 13, 12, 0);

      final match = AetherFlightMatch(
        flight: flight,
        node: node,
        detectedAt: detectedAt,
      );

      expect(match.flight.flightNumber, 'UA123');
      expect(match.node.nodeNum, 0xa1b2c3d4);
      expect(match.detectedAt, detectedAt);
    });
  });

  group('AetherFlightMatcherState', () {
    test('default state is empty', () {
      const state = AetherFlightMatcherState();
      expect(state.matches, isEmpty);
      expect(state.notifiedNodeIds, isEmpty);
      expect(state.hasFetched, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      final match = AetherFlightMatch(
        flight: _makeFlight(),
        node: _makeNode(),
        detectedAt: DateTime.now(),
      );
      final state = AetherFlightMatcherState(
        matches: [match],
        notifiedNodeIds: {'abc'},
        hasFetched: true,
      );

      final updated = state.copyWith(hasFetched: false);
      expect(updated.matches, hasLength(1));
      expect(updated.notifiedNodeIds, contains('abc'));
      expect(updated.hasFetched, isFalse);
    });
  });

  group('AetherFlightMatcherNotifier', () {
    test('matches node in mesh to active Firestore flight', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      // Set a matching node
      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      // Allow async listeners to fire
      await Future<void>.delayed(Duration.zero);

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, hasLength(1));
      expect(state.matches.first.flight.flightNumber, 'UA123');
      expect(state.matches.first.node.nodeNum, 0xa1b2c3d4);
    });

    test('matches node in mesh to active API flight', () async {
      final flight = _makeFlight(
        id: 'api-1',
        nodeId: '!deadbeef',
        flightNumber: 'BA456',
      );
      final h = _createContainer(apiFlights: [flight]);
      addTearDown(h.container.dispose);

      // Read the provider to trigger build() and _fetchApiFlights()
      h.container.read(aetherFlightMatcherProvider);

      // Set matching node
      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xdeadbeef: _makeNode(nodeNum: 0xdeadbeef, userId: '!deadbeef'),
      });

      // Let the API fetch + recheck complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, hasLength(1));
      expect(state.matches.first.flight.flightNumber, 'BA456');
    });

    test('no match when node IDs differ', () async {
      final flight = _makeFlight(nodeId: '!aaaaaaaa');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xbbbbbbbb: _makeNode(nodeNum: 0xbbbbbbbb, userId: '!bbbbbbbb'),
      });

      await Future<void>.delayed(Duration.zero);

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, isEmpty);
    });

    test('no match when flight has empty nodeId', () async {
      final flight = _makeFlight(nodeId: '');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, isEmpty);
    });

    test('case-insensitive matching on node ID', () async {
      final flight = _makeFlight(nodeId: '!A1B2C3D4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, hasLength(1));
    });

    test('deduplicates when same flight is in Firestore and API', () async {
      final flight = _makeFlight(id: 'same-id', nodeId: '!a1b2c3d4');
      final h = _createContainer(
        firestoreFlights: [flight],
        apiFlights: [flight],
      );
      addTearDown(h.container.dispose);

      // Read provider to trigger build + API fetch
      h.container.read(aetherFlightMatcherProvider);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = h.container.read(aetherFlightMatcherProvider);
      // Should deduplicate by ID — only one match
      expect(state.matches, hasLength(1));
    });

    test('match disappears when node leaves mesh', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;

      // Add node → match appears
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        h.container.read(aetherFlightMatcherProvider).matches,
        hasLength(1),
      );

      // Remove node → match disappears
      notifier.setNodes({});
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(aetherFlightMatcherProvider).matches, isEmpty);
    });

    test('multiple flights can match different nodes', () async {
      final flightA = _makeFlight(
        id: 'f-1',
        nodeId: '!aaaa1111',
        flightNumber: 'UA100',
      );
      final flightB = _makeFlight(
        id: 'f-2',
        nodeId: '!bbbb2222',
        flightNumber: 'DL200',
      );
      final h = _createContainer(firestoreFlights: [flightA, flightB]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xaaaa1111: _makeNode(
          nodeNum: 0xaaaa1111,
          userId: '!aaaa1111',
          longName: 'Node A',
        ),
        0xbbbb2222: _makeNode(
          nodeNum: 0xbbbb2222,
          userId: '!bbbb2222',
          longName: 'Node B',
        ),
      });

      await Future<void>.delayed(Duration.zero);

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, hasLength(2));
      final flightNumbers = state.matches.map((m) => m.flight.flightNumber);
      expect(flightNumbers, containsAll(['UA100', 'DL200']));
    });

    test('matches node by nodeNum hex when userId is null', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      // userId is null — matcher should fall back to nodeNum hex
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: null),
      });

      await Future<void>.delayed(Duration.zero);

      final state = h.container.read(aetherFlightMatcherProvider);
      expect(state.matches, hasLength(1));
    });
  });

  group('Notification tracking', () {
    test('markNotified prevents repeated alerts', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final matcher = h.container.read(aetherFlightMatcherProvider.notifier);

      // Initially unnotified
      expect(matcher.unnotifiedMatches, hasLength(1));

      // Mark as notified
      matcher.markNotified('!a1b2c3d4');

      // Should now be empty
      expect(matcher.unnotifiedMatches, isEmpty);

      // But match still exists in state
      expect(
        h.container.read(aetherFlightMatcherProvider).matches,
        hasLength(1),
      );
    });

    test('markNotified normalizes node ID format', () async {
      final flight = _makeFlight(nodeId: '!A1B2C3D4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final matcher = h.container.read(aetherFlightMatcherProvider.notifier);

      // Mark with different casing — should still work
      matcher.markNotified('!a1b2c3d4');
      expect(matcher.unnotifiedMatches, isEmpty);
    });

    test('notifiedNodeIds persists across rechecks', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notesNotifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notesNotifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final matcher = h.container.read(aetherFlightMatcherProvider.notifier);
      matcher.markNotified('!a1b2c3d4');

      // Trigger a recheck by changing nodes
      notesNotifier.setNodes({
        0xa1b2c3d4: _makeNode(
          nodeNum: 0xa1b2c3d4,
          userId: '!a1b2c3d4',
          rssi: -90,
        ),
      });
      await Future<void>.delayed(Duration.zero);

      // Match is still there but still notified
      expect(
        h.container.read(aetherFlightMatcherProvider).matches,
        hasLength(1),
      );
      expect(matcher.unnotifiedMatches, isEmpty);
    });
  });

  group('Convenience providers', () {
    test('aetherFlightMatchesProvider exposes matches list', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final matches = h.container.read(aetherFlightMatchesProvider);
      expect(matches, hasLength(1));
      expect(matches.first.flight.flightNumber, 'UA123');
    });

    test('aetherFlightMatchesProvider is empty when no matches', () {
      final h = _createContainer();
      addTearDown(h.container.dispose);

      // Read to trigger build
      h.container.read(aetherFlightMatcherProvider);

      final matches = h.container.read(aetherFlightMatchesProvider);
      expect(matches, isEmpty);
    });
  });

  group('Detection time preservation', () {
    test('detectedAt is preserved across rechecks', () async {
      final flight = _makeFlight(nodeId: '!a1b2c3d4');
      final h = _createContainer(firestoreFlights: [flight]);
      addTearDown(h.container.dispose);

      final notifier =
          h.container.read(nodesProvider.notifier) as _TestNodesNotifier;
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(nodeNum: 0xa1b2c3d4, userId: '!a1b2c3d4'),
      });

      await Future<void>.delayed(Duration.zero);

      final firstDetection = h.container
          .read(aetherFlightMatcherProvider)
          .matches
          .first
          .detectedAt;

      // Wait a bit and trigger recheck
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier.setNodes({
        0xa1b2c3d4: _makeNode(
          nodeNum: 0xa1b2c3d4,
          userId: '!a1b2c3d4',
          rssi: -95,
        ),
      });
      await Future<void>.delayed(Duration.zero);

      final secondDetection = h.container
          .read(aetherFlightMatcherProvider)
          .matches
          .first
          .detectedAt;

      // Detection time should be the same as the first detection
      expect(secondDetection, equals(firstDetection));
    });
  });
}
