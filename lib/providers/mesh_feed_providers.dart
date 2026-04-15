// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for the mesh feed and peer sync features.
///
/// Provider graph:
///   meshFeedDatabaseProvider (FutureProvider — opens DB)
///     ↓
///   meshFeedRepositoryProvider (Provider — wraps DB + ranking)
///     ↓
///   meshFeedNotifierProvider (NotifierProvider — manages feed state)
///     ↓
///   lanSyncServiceProvider (Provider — LAN mDNS discovery + TCP sync)
///     ↓
///   UI: MeshFeedScreen watches meshFeedNotifierProvider
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../services/mesh_feed/mesh_feed_database.dart';
import '../services/mesh_feed/mesh_feed_ranking.dart';
import '../services/mesh_feed/mesh_feed_repository.dart';
import '../services/mesh_feed/mesh_post.dart';
import '../services/mesh_feed/mesh_sync_service.dart';
import '../services/mesh_sync/lan_sync_service.dart';
import 'app_providers.dart';

// ---------------------------------------------------------------------------
// Feature flag
// ---------------------------------------------------------------------------

/// Whether the mesh feed feature is enabled.
final meshFeedEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isMeshFeedEnabled;
});

/// Whether opportunistic peer sync is enabled.
final opportunisticSyncEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isOpportunisticSyncEnabled;
});

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// Initialises and exposes the mesh feed database.
final meshFeedDatabaseProvider = FutureProvider<MeshFeedDatabase>((ref) async {
  final db = MeshFeedDatabase();
  await db.open();
  ref.onDispose(() => db.close());
  return db;
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Mesh feed repository — coordinates ingest, dedup, ranking.
final meshFeedRepositoryProvider = Provider<MeshFeedRepository>((ref) {
  final dbAsync = ref.watch(meshFeedDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('MeshFeedDatabase not ready');
  }

  final repo = MeshFeedRepository(
    database: db,
    ranking: const MeshFeedRanking(),
  );
  repo.startCleanup();
  ref.onDispose(() => repo.dispose());
  return repo;
});

// ---------------------------------------------------------------------------
// Sync service
// ---------------------------------------------------------------------------

/// Mesh sync service — cursor-based incremental peer sync.
final meshSyncServiceProvider = Provider<MeshSyncService>((ref) {
  final dbAsync = ref.watch(meshFeedDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('MeshFeedDatabase not ready');
  }
  return MeshSyncService(database: db);
});

// ---------------------------------------------------------------------------
// Feed state
// ---------------------------------------------------------------------------

/// Feed state — the current ranked list of posts.
class MeshFeedState {
  const MeshFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.activePostCount = 0,
  });

  /// Ranked posts for display.
  final List<RankedPost> posts;

  /// Whether the feed is loading.
  final bool isLoading;

  /// Last error, if any.
  final String? error;

  /// Total count of active posts.
  final int activePostCount;

  MeshFeedState copyWith({
    List<RankedPost>? posts,
    bool? isLoading,
    String? error,
    int? activePostCount,
  }) {
    return MeshFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activePostCount: activePostCount ?? this.activePostCount,
    );
  }
}

/// Feed state notifier — manages the reactive feed.
class MeshFeedNotifier extends Notifier<MeshFeedState> {
  StreamSubscription<List<RankedPost>>? _feedSub;

  @override
  MeshFeedState build() {
    // Watch the database async value — re-runs build when DB becomes ready.
    final dbAsync = ref.watch(meshFeedDatabaseProvider);

    // Cancel previous subscription on rebuild.
    _feedSub?.cancel();
    _feedSub = null;

    ref.onDispose(() {
      _feedSub?.cancel();
      _feedSub = null;
    });

    return dbAsync.when(
      loading: () => const MeshFeedState(isLoading: true),
      error: (e, _) => MeshFeedState(error: e.toString()),
      data: (_) {
        // DB is ready — schedule async setup after build() returns.
        Future.microtask(_setupFeed);
        return const MeshFeedState(isLoading: true);
      },
    );
  }

  void _setupFeed() {
    try {
      final repo = ref.read(meshFeedRepositoryProvider);

      _feedSub = repo.feedStream.listen(
        (ranked) {
          state = MeshFeedState(posts: ranked, activePostCount: ranked.length);
        },
        onError: (Object e) {
          state = MeshFeedState(error: e.toString());
        },
      );

      // Initial load.
      _loadFeed();
    } catch (e) {
      state = MeshFeedState(error: e.toString());
    }
  }

  Future<void> _loadFeed() async {
    try {
      final repo = ref.read(meshFeedRepositoryProvider);
      final ranked = await repo.getRankedFeed();
      state = MeshFeedState(posts: ranked, activePostCount: ranked.length);
    } catch (e) {
      state = MeshFeedState(error: e.toString());
    }
  }

  /// Refresh the feed.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadFeed();
  }

  /// Create a new local post.
  Future<MeshPost?> createPost({
    required int authorNodeNum,
    required String content,
    MeshPostTtl ttl = MeshPostTtl.hours24,
    MeshPostPropagation propagation = MeshPostPropagation.normal,
  }) async {
    try {
      final repo = ref.read(meshFeedRepositoryProvider);
      return await repo.createLocalPost(
        authorNodeNum: authorNodeNum,
        content: content,
        ttl: ttl,
        propagation: propagation,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

/// The mesh feed notifier provider.
final meshFeedNotifierProvider =
    NotifierProvider<MeshFeedNotifier, MeshFeedState>(MeshFeedNotifier.new);

// ---------------------------------------------------------------------------
// LAN peer sync
// ---------------------------------------------------------------------------

/// LAN sync service — manages mDNS advertising, discovery, and TCP sync.
///
/// Automatically starts mDNS advertising, discovery, and periodic
/// sync when both `MESH_FEED_ENABLED` and `OPPORTUNISTIC_SYNC_ENABLED`
/// are true and a connected node number is available.
///
/// Discovery lifecycle:
///   1. [LanSyncService.startAdvertising] — TCP listener + mDNS broadcast
///   2. [LanSyncService.startDiscovery] — scan for peers via mDNS
///   3. Periodic timer (60 s) — [syncWithDiscoveredPeers] for each peer
final lanSyncServiceProvider = Provider<LanSyncService?>((ref) {
  final feedEnabled = ref.watch(meshFeedEnabledProvider);
  final syncEnabled = ref.watch(opportunisticSyncEnabledProvider);

  if (!feedEnabled || !syncEnabled) {
    AppLogging.meshFeed(
      'LAN-SYNC: disabled (feedEnabled=$feedEnabled '
      'syncEnabled=$syncEnabled)',
    );
    return null;
  }

  final myNodeNum = ref.watch(myNodeNumProvider);
  if (myNodeNum == null) {
    AppLogging.meshFeed('LAN-SYNC: waiting for myNodeNum');
    return null;
  }

  final dbAsync = ref.watch(meshFeedDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    AppLogging.meshFeed('LAN-SYNC: waiting for database');
    return null;
  }

  MeshFeedRepository repo;
  MeshSyncService syncService;
  try {
    repo = ref.watch(meshFeedRepositoryProvider);
    syncService = ref.watch(meshSyncServiceProvider);
  } catch (_) {
    AppLogging.meshFeed('LAN-SYNC: waiting for repository/sync service');
    return null;
  }

  final service = LanSyncService(
    localNodeNum: myNodeNum,
    localDisplayName: myNodeNum.toRadixString(16),
    feedRepository: repo,
    syncService: syncService,
  );

  AppLogging.meshFeed('LAN-SYNC: creating service for node=$myNodeNum');

  // Start mDNS advertising + discovery.
  Future<void> startSync() async {
    try {
      await service.startAdvertising();
      await service.startDiscovery();
    } catch (e) {
      AppLogging.meshFeed('LAN-SYNC: mDNS startup FAILED: $e');
    }
  }

  startSync();

  // Periodic sync with discovered peers.
  final timer = Timer.periodic(
    const Duration(seconds: 60),
    (_) => service.syncWithDiscoveredPeers(),
  );

  ref.onDispose(() {
    AppLogging.meshFeed('LAN-SYNC: disposing service');
    timer.cancel();
    service.dispose();
  });

  return service;
});
