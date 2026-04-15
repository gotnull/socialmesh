// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_database.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';
import 'package:socialmesh/services/mesh_feed/mesh_sync_service.dart';

/// Fake in-memory [MeshFeedDatabase] for sync service tests.
///
/// Implements the cursor-based sync methods with deterministic local_seq
/// assignment. Posts are stored in insertion order.
class _FakeSyncDb extends MeshFeedDatabase {
  _FakeSyncDb() : super(dbPathOverride: ':memory:');

  final Map<String, MeshPost> posts = {};
  final Map<String, _PeerState> peers = {};
  int _nextSeq = 1;
  int _nextSyncSeq = 1;

  @override
  bool get isOpen => true;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<bool> upsertPost(MeshPost post) async {
    if (posts.containsKey(post.id)) {
      final existing = posts[post.id]!;
      // MERGE: bump localSeq but NOT syncSeq.
      posts[post.id] = existing.copyWith(
        seenViaTransports: {
          ...existing.seenViaTransports,
          ...post.seenViaTransports,
        },
        lastSeenAt: post.lastSeenAt,
        localSeq: _nextSeq,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      _nextSeq++;
      return false;
    }
    // INSERT: assign both localSeq and syncSeq.
    posts[post.id] = post.copyWith(
      localSeq: _nextSeq,
      syncSeq: _nextSyncSeq,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _nextSeq++;
    _nextSyncSeq++;
    return true;
  }

  @override
  Future<void> addReceipt({
    required String postId,
    required MeshTransportType transport,
    String? peerId,
    int? hopCount,
  }) async {}

  @override
  Future<List<MeshPost>> getActivePosts({int limit = 200}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return posts.values
        .where((p) => p.expiresAt.millisecondsSinceEpoch > nowMs)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  @override
  Future<MeshPost?> getPost(String id) async => posts[id];

  @override
  Future<int> cleanupExpired() async => 0;

  @override
  Future<int> countActivePosts() async => posts.length;

  @override
  Future<List<MeshPost>> getSyncEligiblePosts({
    int? afterMs,
    int limit = 100,
  }) async {
    return posts.values.toList();
  }

  @override
  Future<void> upsertSyncPeer({
    required String peerId,
    String? displayName,
    required MeshTransportType transport,
    int? syncCursorMs,
  }) async {
    peers[peerId] = _PeerState(
      peerId: peerId,
      displayName: displayName,
      transport: transport,
      syncCursorMs: syncCursorMs,
      syncCursorSeq: peers[peerId]?.syncCursorSeq,
    );
  }

  @override
  Future<int?> getSyncCursorSeq(String peerId) async {
    return peers[peerId]?.syncCursorSeq;
  }

  @override
  Future<void> updateSyncCursorSeq(String peerId, int cursorSeq) async {
    final existing = peers[peerId];
    if (existing != null) {
      peers[peerId] = _PeerState(
        peerId: existing.peerId,
        displayName: existing.displayName,
        transport: existing.transport,
        syncCursorMs: existing.syncCursorMs,
        syncCursorSeq: cursorSeq,
      );
    }
  }

  @override
  Future<List<MeshPost>> getPostsAfterSeq({
    int? afterSeq,
    int limit = 50,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var result = posts.values
        .where(
          (p) =>
              p.expiresAt.millisecondsSinceEpoch > nowMs && p.syncSeq != null,
        )
        .toList();
    if (afterSeq != null) {
      result = result.where((p) => p.syncSeq! > afterSeq).toList();
    }
    // Deterministic ordering: sync_seq ASC, id ASC.
    result.sort((a, b) {
      final seqCmp = a.syncSeq!.compareTo(b.syncSeq!);
      if (seqCmp != 0) return seqCmp;
      return a.id.compareTo(b.id);
    });
    if (result.length > limit) return result.sublist(0, limit);
    return result;
  }
}

class _PeerState {
  _PeerState({
    required this.peerId,
    this.displayName,
    required this.transport,
    this.syncCursorMs,
    this.syncCursorSeq,
  });

  final String peerId;
  final String? displayName;
  final MeshTransportType transport;
  final int? syncCursorMs;
  final int? syncCursorSeq;
}

MeshPost _makePost(int nodeNum, String content) {
  return MeshPost(
    authorNodeNum: nodeNum,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
    content: content,
    seenViaTransports: {MeshTransportType.lora},
  );
}

void main() {
  late _FakeSyncDb db;
  late MeshSyncService syncService;

  setUp(() {
    db = _FakeSyncDb();
    syncService = MeshSyncService(database: db);
  });

  group('MeshSyncService.registerPeer()', () {
    test('registers a new peer', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
        displayName: 'Node Alpha',
      );
      expect(db.peers.containsKey('peer-1'), isTrue);
      expect(db.peers['peer-1']!.displayName, equals('Node Alpha'));
    });
  });

  group('MeshSyncService.getPostsForPeer()', () {
    test('peer with no cursor gets first batch', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      // Insert 3 posts.
      await db.upsertPost(_makePost(1, 'Post A'));
      await db.upsertPost(_makePost(2, 'Post B'));
      await db.upsertPost(_makePost(3, 'Post C'));

      final batch = await syncService.getPostsForPeer('peer-1');
      expect(batch.posts.length, equals(3));
      expect(batch.hasMore, isFalse);
      expect(batch.cursorSeq, isNotNull);
    });

    test('batch ordering is deterministic by local_seq', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      await db.upsertPost(_makePost(1, 'First'));
      await db.upsertPost(_makePost(2, 'Second'));
      await db.upsertPost(_makePost(3, 'Third'));

      final batch = await syncService.getPostsForPeer('peer-1');
      // Should be in local_seq ASC order.
      for (var i = 1; i < batch.posts.length; i++) {
        expect(
          batch.posts[i].localSeq! >= batch.posts[i - 1].localSeq!,
          isTrue,
        );
      }
    });

    test('after cursor update only later items returned', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      await db.upsertPost(_makePost(1, 'Early'));
      await db.upsertPost(_makePost(2, 'Middle'));

      // Get first batch and acknowledge.
      final batch1 = await syncService.getPostsForPeer('peer-1');
      expect(batch1.posts.length, equals(2));
      await syncService.acknowledgeSyncBatch('peer-1', batch1.cursorSeq!);

      // Insert more posts.
      await db.upsertPost(_makePost(3, 'Late'));

      // Second batch should only contain the new post.
      final batch2 = await syncService.getPostsForPeer('peer-1');
      expect(batch2.posts.length, equals(1));
      expect(batch2.posts.first.content, equals('Late'));
    });

    test('bounded batch size is respected', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      // Insert 10 posts.
      for (var i = 0; i < 10; i++) {
        await db.upsertPost(_makePost(i, 'Post $i'));
      }

      final batch = await syncService.getPostsForPeer('peer-1', batchSize: 3);
      expect(batch.posts.length, equals(3));
      expect(batch.hasMore, isTrue);
    });

    test('empty database returns empty batch', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      final batch = await syncService.getPostsForPeer('peer-1');
      expect(batch.isEmpty, isTrue);
      expect(batch.cursorSeq, isNull);
      expect(batch.hasMore, isFalse);
    });

    test('no duplicate objects when cursor advances correctly', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      // Insert 5 posts.
      for (var i = 0; i < 5; i++) {
        await db.upsertPost(_makePost(i, 'Post $i'));
      }

      // Fetch in batches of 2.
      final allFetched = <String>{};

      var batch = await syncService.getPostsForPeer('peer-1', batchSize: 2);
      for (final p in batch.posts) {
        expect(allFetched.contains(p.id), isFalse);
        allFetched.add(p.id);
      }
      await syncService.acknowledgeSyncBatch('peer-1', batch.cursorSeq!);

      batch = await syncService.getPostsForPeer('peer-1', batchSize: 2);
      for (final p in batch.posts) {
        expect(allFetched.contains(p.id), isFalse);
        allFetched.add(p.id);
      }
      await syncService.acknowledgeSyncBatch('peer-1', batch.cursorSeq!);

      batch = await syncService.getPostsForPeer('peer-1', batchSize: 2);
      for (final p in batch.posts) {
        expect(allFetched.contains(p.id), isFalse);
        allFetched.add(p.id);
      }

      expect(allFetched.length, equals(5));
    });
  });

  group('MeshSyncService.acknowledgeSyncBatch()', () {
    test('advances cursor', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      await db.upsertPost(_makePost(1, 'Test'));
      final batch = await syncService.getPostsForPeer('peer-1');
      await syncService.acknowledgeSyncBatch('peer-1', batch.cursorSeq!);

      final cursor = await syncService.getCursorForPeer('peer-1');
      expect(cursor, equals(batch.cursorSeq));
    });

    test('does not regress cursor', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      await db.upsertPost(_makePost(1, 'First'));
      await db.upsertPost(_makePost(2, 'Second'));

      final batch = await syncService.getPostsForPeer('peer-1');
      await syncService.acknowledgeSyncBatch('peer-1', batch.cursorSeq!);

      final cursorBefore = await syncService.getCursorForPeer('peer-1');

      // Try to set cursor to a lower value.
      await syncService.acknowledgeSyncBatch('peer-1', 1);

      final cursorAfter = await syncService.getCursorForPeer('peer-1');
      expect(cursorAfter, equals(cursorBefore));
    });

    test('cursor survives restart-equivalent reload', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      await db.upsertPost(_makePost(1, 'Persistent'));
      final batch = await syncService.getPostsForPeer('peer-1');
      await syncService.acknowledgeSyncBatch('peer-1', batch.cursorSeq!);

      // Create a new service instance pointing to same DB (simulates restart).
      final reloaded = MeshSyncService(database: db);
      final cursor = await reloaded.getCursorForPeer('peer-1');
      expect(cursor, equals(batch.cursorSeq));
    });
  });

  group('Concurrent ingest safety', () {
    test(
      'concurrent duplicate ingests do not create duplicate objects',
      () async {
        final post = _makePost(1, 'Concurrent test');

        // Simulate concurrent ingests.
        final futures = <Future<bool>>[];
        for (var i = 0; i < 10; i++) {
          futures.add(db.upsertPost(post));
        }
        await Future.wait(futures);

        expect(db.posts.length, equals(1));
      },
    );
  });

  group('Provenance persistence', () {
    test('transport provenance survives row round-trip', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'Provenance test',
        seenViaTransports: {MeshTransportType.lora},
      );
      await db.upsertPost(post);

      // Add WiFi transport.
      final wifiPost = MeshPost(
        authorNodeNum: 1,
        createdAtMs: post.createdAtMs,
        content: 'Provenance test',
        seenViaTransports: {MeshTransportType.lanPeerSync},
      );
      await db.upsertPost(wifiPost);

      // Read back.
      final stored = await db.getPost(post.id);
      expect(stored, isNotNull);
      expect(
        stored!.seenViaTransports,
        containsAll([MeshTransportType.lora, MeshTransportType.lanPeerSync]),
      );
    });

    test('firstSeenAt is preserved on merge', () async {
      final now = DateTime.now();
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'First seen test',
        firstSeenAt: now.subtract(const Duration(minutes: 10)),
        seenViaTransports: {MeshTransportType.lora},
      );
      await db.upsertPost(post);

      final firstSeenBefore = (await db.getPost(post.id))!.firstSeenAt;

      // Re-ingest with different transport.
      final laterPost = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'First seen test',
        firstSeenAt: now,
        seenViaTransports: {MeshTransportType.lanPeerSync},
      );
      await db.upsertPost(laterPost);

      final firstSeenAfter = (await db.getPost(post.id))!.firstSeenAt;
      // firstSeenAt should be preserved (first value, not overwritten).
      expect(firstSeenAfter, equals(firstSeenBefore));
    });

    test('lastSeenAt updates on merge', () async {
      final now = DateTime.now();
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'Last seen test',
        lastSeenAt: now.subtract(const Duration(minutes: 10)),
        seenViaTransports: {MeshTransportType.lora},
      );
      await db.upsertPost(post);

      final lastSeenBefore = (await db.getPost(post.id))!.lastSeenAt;

      // Re-ingest with later lastSeenAt.
      final laterPost = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'Last seen test',
        lastSeenAt: now,
        seenViaTransports: {MeshTransportType.lanPeerSync},
      );
      await db.upsertPost(laterPost);

      final lastSeenAfter = (await db.getPost(post.id))!.lastSeenAt;
      expect(lastSeenAfter.isAfter(lastSeenBefore), isTrue);
    });
  });

  group('sync_seq churn prevention', () {
    test('metadata-only merge does not re-enter outbound sync batch', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      // Insert a new post — gets both localSeq and syncSeq.
      await db.upsertPost(_makePost(1, 'Original post'));

      // Initial batch should contain the post.
      final batch1 = await syncService.getPostsForPeer('peer-1');
      expect(batch1.posts.length, equals(1));
      expect(batch1.cursorSeq, isNotNull);

      // Acknowledge the batch.
      await syncService.acknowledgeSyncBatch('peer-1', batch1.cursorSeq!);

      // Metadata-only merge — add a new transport (simulates provenance
      // update from LAN peer sync).
      final post = batch1.posts.first;
      await db.upsertPost(
        post.copyWith(
          seenViaTransports: {
            ...post.seenViaTransports,
            MeshTransportType.lanPeerSync,
          },
        ),
      );

      // After merge, the post should NOT reappear in the next batch.
      final batch2 = await syncService.getPostsForPeer('peer-1');
      expect(batch2.posts, isEmpty);
      expect(batch2.hasMore, isFalse);
    });

    test('new post after merge still syncs', () async {
      await syncService.registerPeer(
        peerId: 'peer-1',
        transport: MeshTransportType.blePeerSync,
      );

      // Insert post A.
      await db.upsertPost(_makePost(1, 'Post A'));
      final batch1 = await syncService.getPostsForPeer('peer-1');
      await syncService.acknowledgeSyncBatch('peer-1', batch1.cursorSeq!);

      // Merge post A (provenance update).
      await db.upsertPost(
        batch1.posts.first.copyWith(
          seenViaTransports: {
            MeshTransportType.lora,
            MeshTransportType.lanPeerSync,
          },
        ),
      );

      // Insert post B — should get a new syncSeq.
      await db.upsertPost(_makePost(2, 'Post B'));

      // Batch should contain ONLY post B (not the merged post A).
      final batch2 = await syncService.getPostsForPeer('peer-1');
      expect(batch2.posts.length, equals(1));
      expect(batch2.posts.first.content, equals('Post B'));
    });

    test('syncSeq is stable across metadata merges', () async {
      // Insert a post.
      await db.upsertPost(_makePost(1, 'Stable test'));
      final postAfterInsert = db.posts.values.first;
      final originalSyncSeq = postAfterInsert.syncSeq;

      // Merge metadata.
      await db.upsertPost(
        postAfterInsert.copyWith(
          seenViaTransports: {
            MeshTransportType.lora,
            MeshTransportType.lanPeerSync,
          },
        ),
      );
      final postAfterMerge = db.posts.values.first;

      // localSeq should have been bumped but syncSeq should be unchanged.
      expect(postAfterMerge.localSeq, greaterThan(postAfterInsert.localSeq!));
      expect(postAfterMerge.syncSeq, equals(originalSyncSeq));
    });
  });
}
