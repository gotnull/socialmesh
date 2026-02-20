// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../services/notifications/notification_service.dart';
import '../models/tak_event.dart';
import '../models/tak_publish_config.dart';
import '../services/tak_database.dart';
import '../services/tak_gateway_client.dart';
import '../services/tak_position_publisher.dart';
import 'tak_settings_provider.dart';
import '../services/tak_stale_monitor.dart';
import 'tak_tracking_provider.dart';

/// Whether the TAK Gateway feature is enabled.
final isTakEnabledProvider = Provider<bool>((ref) {
  final enabled = AppFeatureFlags.isTakGatewayEnabled;
  AppLogging.tak('isTakEnabledProvider: $enabled');
  return enabled;
});

/// TAK event database instance (singleton).
final takDatabaseProvider = Provider<TakDatabase>((ref) {
  AppLogging.tak('Creating TakDatabase provider');
  final db = TakDatabase();
  ref.onDispose(() {
    AppLogging.tak('Disposing TakDatabase provider');
    db.close();
  });
  return db;
});

/// Derived gateway URL that only changes when the actual URL string changes.
///
/// This prevents [takGatewayClientProvider] from rebuilding when
/// [takSettingsProvider] transitions from AsyncLoading → AsyncData with the
/// same effective URL (the default). Without this, the provider rebuild race
/// disposes the in-flight client and causes "Cannot add new events after
/// calling close".
final _takGatewayUrlProvider = Provider<String>((ref) {
  final settings = ref.watch(takSettingsProvider).value;
  if (settings != null && settings.gatewayUrl.isNotEmpty) {
    return settings.gatewayUrl;
  }
  return AppUrls.takGatewayUrl;
});

/// TAK Gateway WebSocket client.
///
/// Watches [_takGatewayUrlProvider] so it only rebuilds (and re-creates the
/// client) when the effective gateway URL actually changes — not on every
/// settings async-state transition.
final takGatewayClientProvider = Provider<TakGatewayClient>((ref) {
  final authService = ref.read(authServiceProvider);
  final gatewayUrl = ref.watch(_takGatewayUrlProvider);

  AppLogging.tak('Creating TakGatewayClient provider: url=$gatewayUrl');
  final client = TakGatewayClient(
    gatewayUrl: gatewayUrl,
    getAuthToken: () => authService.getIdToken(),
  );
  ref.onDispose(() {
    AppLogging.tak('Disposing TakGatewayClient provider');
    client.dispose();
  });
  return client;
});

/// Stream of connection state changes.
final takConnectionStateProvider = StreamProvider<TakConnectionState>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  AppLogging.tak('takConnectionStateProvider subscribed');
  return client.stateStream;
});

/// Stream of individual TAK events.
final takEventStreamProvider = StreamProvider<TakEvent>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  AppLogging.tak('takEventStreamProvider subscribed');
  return client.eventStream;
});

/// Stream of snapshot backfills.
final takSnapshotStreamProvider = StreamProvider<List<TakEvent>>((ref) {
  final client = ref.watch(takGatewayClientProvider);
  AppLogging.tak('takSnapshotStreamProvider subscribed');
  return client.snapshotStream;
});

// ---------------------------------------------------------------------------
// Persistence layer
// ---------------------------------------------------------------------------

/// Manages the TAK event persistence lifecycle.
///
/// On build it initializes the database, loads persisted events, subscribes
/// to the gateway event and snapshot streams, persists incoming data, and
/// runs periodic cleanup every 60 seconds.
final takPersistenceNotifierProvider =
    AsyncNotifierProvider<TakPersistenceNotifier, List<TakEvent>>(
      TakPersistenceNotifier.new,
    );

/// AsyncNotifier that owns the TAK entity list, backed by SQLite.
class TakPersistenceNotifier extends AsyncNotifier<List<TakEvent>> {
  StreamSubscription<TakEvent>? _eventSub;
  StreamSubscription<List<TakEvent>>? _snapshotSub;
  Timer? _cleanupTimer;

  @override
  Future<List<TakEvent>> build() async {
    AppLogging.tak('TakPersistenceNotifier: initializing database');
    final db = ref.read(takDatabaseProvider);
    await db.init();

    // Load persisted events
    final persisted = await db.getActiveEvents(limit: 500);
    AppLogging.tak(
      'TakPersistenceNotifier: loaded ${persisted.length} events from database',
    );

    // Listen to gateway streams
    final client = ref.read(takGatewayClientProvider);

    _eventSub = client.eventStream.listen(_onEvent);
    _snapshotSub = client.snapshotStream.listen(_onSnapshot);

    // Periodic cleanup every 60 seconds
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _runCleanup(),
    );

    ref.onDispose(() {
      AppLogging.tak('TakPersistenceNotifier: disposing');
      _eventSub?.cancel();
      _snapshotSub?.cancel();
      _cleanupTimer?.cancel();
    });

    return persisted;
  }

  Future<void> _onEvent(TakEvent event) async {
    final db = ref.read(takDatabaseProvider);

    // Record position history before upserting (preserves trail data)
    await db.insertPositionHistory(
      uid: event.uid,
      lat: event.lat,
      lon: event.lon,
      timeUtcMs: event.timeUtcMs,
    );

    await db.upsert(event);

    // Update in-memory list
    final current = List<TakEvent>.of(state.value ?? []);
    final idx = current.indexWhere(
      (e) => e.uid == event.uid && e.type == event.type,
    );
    if (idx >= 0) {
      current[idx] = event;
    } else {
      current.insert(0, event);
    }
    state = AsyncData(current);
  }

  Future<void> _onSnapshot(List<TakEvent> snapshot) async {
    AppLogging.tak(
      'TakPersistenceNotifier: snapshot received, ${snapshot.length} events',
    );
    final db = ref.read(takDatabaseProvider);
    await db.insertBatch(snapshot);

    // Merge into in-memory list
    final current = List<TakEvent>.of(state.value ?? []);
    for (final event in snapshot) {
      final idx = current.indexWhere(
        (e) => e.uid == event.uid && e.type == event.type,
      );
      if (idx >= 0) {
        current[idx] = event;
      } else {
        current.add(event);
      }
    }
    current.sort((a, b) => b.receivedUtcMs.compareTo(a.receivedUtcMs));
    state = AsyncData(current);
  }

  Future<void> _runCleanup() async {
    final db = ref.read(takDatabaseProvider);
    final removed = await db.cleanupStale();
    await db.enforceMaxEvents();

    if (removed > 0) {
      // Remove stale events from in-memory list
      final current = List<TakEvent>.of(state.value ?? []);
      final cutoff =
          DateTime.now().millisecondsSinceEpoch -
          TakDatabase.staleGracePeriodMs;
      final active = current.where((e) => e.staleUtcMs >= cutoff).toList();
      AppLogging.tak(
        'TakPersistenceNotifier: cleanup cycle -- $removed stale removed, '
        '${active.length} active',
      );
      state = AsyncData(active);
    }
  }
}

/// Active (non-disposed) TAK events.
///
/// This is the single source of truth consumed by both [TakScreen] and the
/// TAK map layer.
final takActiveEventsProvider = Provider<List<TakEvent>>((ref) {
  final asyncEvents = ref.watch(takPersistenceNotifierProvider);
  final events = asyncEvents.value ?? [];
  final staleCount = events.where((e) => e.isStale).length;
  AppLogging.tak(
    'takActiveEventsProvider: ${events.length} active events '
    '($staleCount stale filtered)',
  );
  return events;
});

// ---------------------------------------------------------------------------
// Position publishing
// ---------------------------------------------------------------------------

/// TAK position publisher instance.
///
/// Publishes the local node's position as a CoT SA event to the TAK Gateway
/// REST endpoint. Gated by [AppFeatureFlags.isTakPublishEnabled].
final takPositionPublisherProvider = Provider<TakPositionPublisher?>((ref) {
  if (!AppFeatureFlags.isTakPublishEnabled) {
    AppLogging.tak('takPositionPublisherProvider: publishing disabled');
    return null;
  }

  final client = ref.watch(takGatewayClientProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  final nodes = ref.watch(nodesProvider);

  String? getNodeHex() {
    if (myNodeNum == null) return null;
    return myNodeNum.toRadixString(16).toUpperCase();
  }

  double? getLat() {
    if (myNodeNum == null) return null;
    return nodes[myNodeNum]?.latitude;
  }

  double? getLon() {
    if (myNodeNum == null) return null;
    return nodes[myNodeNum]?.longitude;
  }

  String getNodeName() {
    if (myNodeNum == null) return 'Unknown';
    return nodes[myNodeNum]?.displayName ?? 'Unknown';
  }

  final publisher = TakPositionPublisher(
    client: client,
    getNodeHex: getNodeHex,
    getLat: getLat,
    getLon: getLon,
    getNodeName: getNodeName,
    config: const TakPublishConfig(enabled: true, intervalSeconds: 60),
  );

  AppLogging.tak('takPositionPublisherProvider: created');

  ref.onDispose(() {
    AppLogging.tak('takPositionPublisherProvider: disposing');
    publisher.dispose();
  });

  return publisher;
});

// ---------------------------------------------------------------------------
// Stale entity monitoring
// ---------------------------------------------------------------------------

/// Monitors tracked TAK entities for stale transitions and fires local
/// notifications via [NotificationService].
final takStaleMonitorProvider = Provider<TakStaleMonitor>((ref) {
  final trackedUids = ref.watch(takTrackedUidsProvider);
  final events = ref.watch(takActiveEventsProvider);

  final monitor = TakStaleMonitor(
    notificationService: NotificationService(),
    getTrackedUids: () => trackedUids,
    getEvents: () => events,
  );

  // Auto-start when there are tracked entities.
  if (trackedUids.isNotEmpty) {
    monitor.start();
  }

  ref.onDispose(() {
    AppLogging.tak('takStaleMonitorProvider: disposing');
    monitor.dispose();
  });

  return monitor;
});

// ---------------------------------------------------------------------------
// Show on map request
// ---------------------------------------------------------------------------

/// A pending request to center the map on a specific TAK entity.
///
/// Set by [TakEventDetailScreen] "Show on Map" action, consumed by
/// [MapScreen]. The request flow is:
///   1. Detail screen calls `request(event)`
///   2. Detail screen pops (Navigator.pop)
///   3. MapScreen listener sees the non-null value, centers on the location,
///      calls `consume()` to clear the request.
class TakShowOnMapNotifier extends Notifier<TakEvent?> {
  @override
  TakEvent? build() => null;

  void request(TakEvent event) => state = event;
  void consume() => state = null;
}

/// Provider for "show TAK entity on map" navigation requests.
final takShowOnMapProvider = NotifierProvider<TakShowOnMapNotifier, TakEvent?>(
  TakShowOnMapNotifier.new,
);
