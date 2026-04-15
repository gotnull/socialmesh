// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Incremental peer sync service — cursor-driven batch sync for mesh feed.
///
/// Uses monotonic [MeshPost.localSeq] for clock-skew-safe ordering.
/// Deterministic tiebreak on canonical post ID ensures no skipped or
/// duplicated objects when cursors advance correctly.
///
/// Sync flow:
///   1. Peer connects (BLE/WiFi)
///   2. [getPostsForPeer] returns the next batch after the peer's cursor
///   3. Posts are transferred
///   4. [acknowledgeSyncBatch] advances the cursor on confirmed delivery
///
/// Cursor is only advanced on acknowledgement — not on selection.
library;

import '../../core/logging.dart';
import '../mesh_feed/mesh_feed_database.dart';
import '../mesh_feed/mesh_post.dart';

/// A batch of posts for sync, with cursor metadata.
class SyncBatch {
  const SyncBatch({
    required this.posts,
    required this.cursorSeq,
    required this.hasMore,
  });

  /// Posts in this batch, ordered by local_seq ASC.
  final List<MeshPost> posts;

  /// The local_seq of the last post in this batch.
  /// Used to acknowledge successful delivery and advance the cursor.
  /// Null if the batch is empty.
  final int? cursorSeq;

  /// Whether there are more posts after this batch.
  final bool hasMore;

  /// Convenience: whether this batch contains any posts.
  bool get isEmpty => posts.isEmpty;

  /// Convenience: number of posts in this batch.
  int get length => posts.length;
}

/// Service coordinating incremental peer sync using monotonic cursors.
///
/// This service does not own the transport — it provides the data contract
/// that BLE/WiFi sync sessions use for efficient, resumable sync.
class MeshSyncService {
  MeshSyncService({required MeshFeedDatabase database}) : _db = database;

  final MeshFeedDatabase _db;

  /// Register or update a sync peer. Call when a peer is discovered.
  Future<void> registerPeer({
    required String peerId,
    required MeshTransportType transport,
    String? displayName,
  }) async {
    await _db.upsertSyncPeer(
      peerId: peerId,
      transport: transport,
      displayName: displayName,
    );
    AppLogging.meshFeed('sync peer registered: $peerId via ${transport.name}');
  }

  /// Get the next batch of posts for a peer based on their sync_seq cursor.
  ///
  /// Returns up to [batchSize] non-expired posts ordered deterministically
  /// by `(sync_seq ASC, id ASC)`. A peer with no cursor (first sync)
  /// gets the first batch from the beginning.
  ///
  /// Uses `sync_seq` — only bumped on INSERT, not metadata merges.
  /// The cursor is NOT advanced here — only on [acknowledgeSyncBatch].
  Future<SyncBatch> getPostsForPeer(String peerId, {int batchSize = 50}) async {
    final cursorSeq = await _db.getSyncCursorSeq(peerId);

    // Fetch batchSize + 1 to detect hasMore.
    final posts = await _db.getPostsAfterSeq(
      afterSeq: cursorSeq,
      limit: batchSize + 1,
    );

    final hasMore = posts.length > batchSize;
    final batch = hasMore ? posts.sublist(0, batchSize) : posts;

    final lastSeq = batch.isNotEmpty ? batch.last.syncSeq : null;

    AppLogging.meshFeed(
      'sync batch: peer=$peerId cursor=${cursorSeq ?? 'none'} '
      'posts=${batch.length} hasMore=$hasMore',
    );

    return SyncBatch(posts: batch, cursorSeq: lastSeq, hasMore: hasMore);
  }

  /// Acknowledge successful delivery of a sync batch, advancing the cursor.
  ///
  /// [cursorSeq] must be the [SyncBatch.cursorSeq] value from the
  /// delivered batch. Only advance — never regress.
  Future<void> acknowledgeSyncBatch(String peerId, int cursorSeq) async {
    // Safety: only advance, never regress.
    final current = await _db.getSyncCursorSeq(peerId);
    if (current != null && cursorSeq <= current) {
      AppLogging.meshFeed(
        'sync ack REJECTED: peer=$peerId '
        'requested=$cursorSeq current=$current (would regress)',
      );
      return;
    }

    await _db.updateSyncCursorSeq(peerId, cursorSeq);
    AppLogging.meshFeed(
      'sync ack OK: peer=$peerId cursor ${current ?? 0} → $cursorSeq',
    );
  }

  /// Get the current cursor sequence for a peer (for diagnostics).
  Future<int?> getCursorForPeer(String peerId) => _db.getSyncCursorSeq(peerId);
}
