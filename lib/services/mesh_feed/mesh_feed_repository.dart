// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh feed repository — coordinates post ingest, dedup, ranking, expiry.
///
/// This is the single source of truth for mesh feed state. Providers watch
/// its streams; UI never touches the database directly.
library;

import 'dart:async';

import '../../core/logging.dart';
import 'mesh_feed_database.dart';
import 'mesh_feed_ranking.dart';
import 'mesh_post.dart';

/// Ingest result for observability.
enum IngestResult {
  /// New post inserted.
  inserted,

  /// Existing post had metadata merged (new transport, updated hop count).
  merged,

  /// Only provenance/receipt updated — no object-level merge needed.
  provenanceUpdated,

  /// Replay suppressed — same post ingested recently with no new info.
  replaySuppressed,

  /// Post rejected — expired.
  rejectedExpired,

  /// Post rejected — invalid content or structure.
  rejectedInvalid,
}

/// Configuration for replay protection.
class ReplayGuardConfig {
  const ReplayGuardConfig({this.windowMs = 30000, this.maxCacheSize = 500});

  /// Replay suppression window in milliseconds (default 30s).
  final int windowMs;

  /// Maximum entries in the in-memory replay cache.
  final int maxCacheSize;
}

/// In-memory replay cache entry.
class _ReplayCacheEntry {
  _ReplayCacheEntry({required this.timestampMs, required this.transports});

  final int timestampMs;
  final Set<MeshTransportType> transports;
}

/// Repository coordinating feed persistence, dedup, ranking, and lifecycle.
class MeshFeedRepository {
  MeshFeedRepository({
    required MeshFeedDatabase database,
    MeshFeedRanking? ranking,
    this.replayConfig = const ReplayGuardConfig(),
  }) : _db = database,
       _ranking = ranking ?? const MeshFeedRanking();

  final MeshFeedDatabase _db;
  final MeshFeedRanking _ranking;

  /// Replay protection configuration.
  final ReplayGuardConfig replayConfig;

  /// In-memory replay cache — keyed by canonical post ID.
  final Map<String, _ReplayCacheEntry> _replayCache = {};

  final _feedController = StreamController<List<RankedPost>>.broadcast();
  Timer? _cleanupTimer;

  /// Ranked feed stream — emits whenever the feed changes.
  Stream<List<RankedPost>> get feedStream => _feedController.stream;

  /// Start periodic cleanup of expired posts.
  void startCleanup({Duration interval = const Duration(minutes: 5)}) {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(interval, (_) => _cleanup());
  }

  /// Ingest a post from any transport. Handles replay protection, dedup,
  /// metadata merge, provenance recording, and feed refresh.
  ///
  /// Replay protection flow:
  /// 1. Reject expired posts immediately.
  /// 2. Check in-memory replay cache for recent ingest of same ID.
  ///    - If within window and no new transports → [IngestResult.replaySuppressed]
  ///    - If within window but new transport → record provenance only →
  ///      [IngestResult.provenanceUpdated]
  /// 3. Full ingest path: upsert + receipt + feed refresh.
  ///
  /// Returns the ingest outcome for observability logging.
  Future<IngestResult> ingest(MeshPost post) async {
    // Reject expired posts.
    if (post.isExpired) {
      AppLogging.meshFeed('rejected expired post ${post.id}');
      return IngestResult.rejectedExpired;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cached = _replayCache[post.id];

    // Replay guard: check if same post was ingested recently.
    if (cached != null &&
        (nowMs - cached.timestampMs) < replayConfig.windowMs) {
      // Check if the incoming transports bring new provenance.
      final newTransports = post.seenViaTransports.difference(
        cached.transports,
      );
      if (newTransports.isEmpty) {
        AppLogging.meshFeed(
          'replay suppressed ${post.id} '
          '(${nowMs - cached.timestampMs}ms since last)',
        );
        return IngestResult.replaySuppressed;
      }

      // New transport provenance — record receipts and merge transports
      // without full upsert churn.
      for (final transport in newTransports) {
        await _db.addReceipt(
          postId: post.id,
          transport: transport,
          hopCount: post.hopCount,
        );
      }

      // Update the DB transport set via a lightweight merge.
      await _db.upsertPost(post);

      // Update replay cache with merged transports.
      _replayCache[post.id] = _ReplayCacheEntry(
        timestampMs: nowMs,
        transports: {...cached.transports, ...post.seenViaTransports},
      );

      AppLogging.meshFeed(
        'provenance updated ${post.id} '
        'added ${newTransports.map((t) => t.name).join(",")}',
      );
      await _emitFeed();
      return IngestResult.provenanceUpdated;
    }

    // Full ingest path — outside replay window or first time.
    final isNew = await _db.upsertPost(post);

    // Record transport receipts.
    for (final transport in post.seenViaTransports) {
      await _db.addReceipt(
        postId: post.id,
        transport: transport,
        hopCount: post.hopCount,
      );
    }

    // Update replay cache.
    _replayCache[post.id] = _ReplayCacheEntry(
      timestampMs: nowMs,
      transports: post.seenViaTransports.toSet(),
    );
    _pruneReplayCache();

    if (isNew) {
      AppLogging.meshFeed(
        'ingested new post ${post.id} '
        'from node ${post.authorNodeNum} '
        'via ${post.seenViaTransports.map((t) => t.name).join(",")}',
      );
    } else {
      AppLogging.meshFeed(
        'merged metadata for ${post.id} '
        'via ${post.seenViaTransports.map((t) => t.name).join(",")}',
      );
    }

    // Refresh feed after ingest.
    await _emitFeed();

    return isNew ? IngestResult.inserted : IngestResult.merged;
  }

  /// Evict oldest replay cache entries when size exceeds limit.
  void _pruneReplayCache() {
    if (_replayCache.length <= replayConfig.maxCacheSize) return;
    final entries = _replayCache.entries.toList()
      ..sort((a, b) => a.value.timestampMs.compareTo(b.value.timestampMs));
    final toRemove = entries.length - replayConfig.maxCacheSize;
    for (var i = 0; i < toRemove; i++) {
      _replayCache.remove(entries[i].key);
    }
    AppLogging.meshFeed(
      'replay cache pruned: removed=$toRemove remaining=${_replayCache.length}',
    );
  }

  /// Create a local post and ingest it.
  Future<MeshPost> createLocalPost({
    required int authorNodeNum,
    required String content,
    MeshPostTtl ttl = MeshPostTtl.hours24,
    MeshPostPropagation propagation = MeshPostPropagation.normal,
    double? trustScore,
  }) async {
    final post = MeshPost(
      authorNodeNum: authorNodeNum,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      content: content,
      ttl: ttl,
      propagation: propagation,
      isLocal: true,
      seenViaTransports: {MeshTransportType.local},
      trustScore: trustScore,
    );

    await ingest(post);
    AppLogging.meshFeed(
      'created local post=${post.id.substring(0, 8)}… '
      'ttl=${ttl.name} propagation=${propagation.name}',
    );
    return post;
  }

  /// Get the current ranked feed.
  Future<List<RankedPost>> getRankedFeed({int limit = 200}) async {
    final posts = await _db.getActivePosts(limit: limit);
    return _ranking.rank(posts);
  }

  /// Get posts eligible for peer sync.
  Future<List<MeshPost>> getSyncEligible({int? afterMs}) async {
    return _db.getSyncEligiblePosts(afterMs: afterMs);
  }

  /// Get a single post by ID.
  Future<MeshPost?> getPost(String id) => _db.getPost(id);

  /// Count of active posts.
  Future<int> countActive() => _db.countActivePosts();

  /// Force a feed refresh (e.g. after trust scores change).
  Future<void> refreshFeed() => _emitFeed();

  /// Clear the in-memory replay cache (e.g. for testing restart simulation).
  void clearReplayCache() => _replayCache.clear();

  /// Current size of the replay cache (for observability/testing).
  int get replayCacheSize => _replayCache.length;

  /// Get posts eligible for LoRa propagation from the database.
  Future<List<MeshPost>> getLoraEligiblePosts({int limit = 20}) =>
      _db.getLoraEligiblePosts(limit: limit);

  /// Mark a post as rebroadcast over LoRa.
  Future<void> markLoraRebroadcast(String postId) =>
      _db.markLoraRebroadcast(postId);

  /// Direct access to the database (for services like [MeshSyncService]).
  MeshFeedDatabase get database => _db;

  Future<void> _emitFeed() async {
    final ranked = await getRankedFeed();
    if (!_feedController.isClosed) {
      _feedController.add(ranked);
    }
  }

  Future<void> _cleanup() async {
    final removed = await _db.cleanupExpired();
    if (removed > 0) {
      AppLogging.meshFeed('cleaned up $removed expired posts');
      await _emitFeed();
    }
  }

  /// Dispose streams and timers.
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _feedController.close();
  }
}
