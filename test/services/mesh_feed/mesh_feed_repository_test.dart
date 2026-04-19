// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_database.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_ranking.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_repository.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';

/// Fake in-memory [MeshFeedDatabase] for unit testing the repository layer.
///
/// Uses a simple Map store — no real SQLite dependency.
class FakeMeshFeedDatabase extends MeshFeedDatabase {
  FakeMeshFeedDatabase() : super(dbPathOverride: ':memory:');

  final Map<String, MeshPost> _posts = {};
  final List<Receipt> _receipts = [];

  @override
  bool get isOpen => true;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<bool> upsertPost(MeshPost post) async {
    if (_posts.containsKey(post.id)) {
      final existing = _posts[post.id]!;
      _posts[post.id] = existing.copyWith(
        seenViaTransports: {
          ...existing.seenViaTransports,
          ...post.seenViaTransports,
        },
        hopCount:
            (post.hopCount != null &&
                (existing.hopCount == null ||
                    post.hopCount! < existing.hopCount!))
            ? post.hopCount
            : existing.hopCount,
        trustScore: post.trustScore ?? existing.trustScore,
        lastSeenAt: post.lastSeenAt,
      );
      return false;
    }
    _posts[post.id] = post;
    return true;
  }

  @override
  Future<void> addReceipt({
    required String postId,
    required MeshTransportType transport,
    String? peerId,
    int? hopCount,
  }) async {
    _receipts.add(
      Receipt(postId: postId, transport: transport, hopCount: hopCount),
    );
  }

  @override
  Future<List<MeshPost>> getActivePosts({int limit = 200}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = _posts.values
        .where((p) => p.expiresAt.millisecondsSinceEpoch > nowMs)
        .toList();
    active.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    if (active.length > limit) return active.sublist(0, limit);
    return active;
  }

  @override
  Future<List<MeshPost>> getSyncEligiblePosts({
    int? afterMs,
    int limit = 100,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return _posts.values
        .where(
          (p) =>
              p.expiresAt.millisecondsSinceEpoch > nowMs &&
              p.syncState == MeshPostSyncState.pending &&
              (afterMs == null || p.createdAtMs > afterMs),
        )
        .toList();
  }

  @override
  Future<MeshPost?> getPost(String id) async {
    return _posts[id];
  }

  @override
  Future<int> cleanupExpired() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expired = _posts.entries
        .where((e) => e.value.expiresAt.millisecondsSinceEpoch <= nowMs)
        .map((e) => e.key)
        .toList();
    for (final id in expired) {
      _posts.remove(id);
    }
    return expired.length;
  }

  @override
  Future<int> countActivePosts() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return _posts.values
        .where((p) => p.expiresAt.millisecondsSinceEpoch > nowMs)
        .length;
  }

  /// Expose post count for test assertions.
  int get storedCount => _posts.length;

  /// Expose receipts for test assertions.
  List<Receipt> get receipts => List.unmodifiable(_receipts);
}

class Receipt {
  Receipt({required this.postId, required this.transport, this.hopCount});
  final String postId;
  final MeshTransportType transport;
  final int? hopCount;
}

void main() {
  late FakeMeshFeedDatabase db;
  late MeshFeedRepository repo;

  setUp(() {
    db = FakeMeshFeedDatabase();
    repo = MeshFeedRepository(database: db);
  });

  tearDown(() async {
    await repo.dispose();
  });

  group('MeshFeedRepository.ingest()', () {
    test('new post returns IngestResult.inserted', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'Hello mesh!',
        seenViaTransports: {MeshTransportType.lora},
      );

      final result = await repo.ingest(post);
      expect(result, equals(IngestResult.inserted));
      expect(db.storedCount, equals(1));
    });

    test(
      'duplicate post within replay window returns replaySuppressed',
      () async {
        final post = MeshPost(
          authorNodeNum: 1,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          content: 'Hello mesh!',
          seenViaTransports: {MeshTransportType.lora},
        );

        await repo.ingest(post);
        final result = await repo.ingest(post);
        expect(result, equals(IngestResult.replaySuppressed));
        expect(db.storedCount, equals(1)); // Still only one post
      },
    );

    test('expired post returns IngestResult.rejectedExpired', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch,
        content: 'Expired content',
        ttl: MeshPostTtl.hours24,
      );

      final result = await repo.ingest(post);
      expect(result, equals(IngestResult.rejectedExpired));
      expect(db.storedCount, equals(0)); // Not stored
    });

    test('receipts are recorded on ingest', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'Receipts test',
        seenViaTransports: {
          MeshTransportType.lora,
          MeshTransportType.blePeerSync,
        },
        hopCount: 2,
      );

      await repo.ingest(post);
      expect(db.receipts.length, equals(2));
      expect(
        db.receipts.map((r) => r.transport).toSet(),
        containsAll([MeshTransportType.lora, MeshTransportType.blePeerSync]),
      );
    });

    test('cross-transport dedup merges transports', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final fromLora = MeshPost(
        authorNodeNum: 42,
        createdAtMs: now,
        content: 'Emergency alert',
        seenViaTransports: {MeshTransportType.lora},
        hopCount: 3,
      );

      final fromSync = MeshPost(
        authorNodeNum: 42,
        createdAtMs: now,
        content: 'Emergency alert',
        seenViaTransports: {MeshTransportType.lanPeerSync},
        hopCount: 1,
      );

      await repo.ingest(fromLora);
      final result = await repo.ingest(fromSync);
      expect(result, equals(IngestResult.provenanceUpdated));
      expect(db.storedCount, equals(1));

      // Verify merged post has both transports
      final stored = await repo.getPost(fromLora.id);
      expect(stored, isNotNull);
      expect(
        stored!.seenViaTransports,
        containsAll([MeshTransportType.lora, MeshTransportType.lanPeerSync]),
      );
    });
  });

  group('MeshFeedRepository.createLocalPost()', () {
    test('creates a local post with correct defaults', () async {
      final post = await repo.createLocalPost(
        authorNodeNum: 99,
        content: 'My local message',
      );

      expect(post.isLocal, isTrue);
      expect(post.authorNodeNum, equals(99));
      expect(post.content, equals('My local message'));
      expect(post.seenViaTransports, contains(MeshTransportType.local));
      expect(post.ttl, equals(MeshPostTtl.hours24));
      expect(post.propagation, equals(MeshPostPropagation.normal));
    });

    test('respects custom ttl and propagation', () async {
      final post = await repo.createLocalPost(
        authorNodeNum: 99,
        content: 'Short bulletin',
        ttl: MeshPostTtl.hours1,
        propagation: MeshPostPropagation.localOnly,
      );

      expect(post.ttl, equals(MeshPostTtl.hours1));
      expect(post.propagation, equals(MeshPostPropagation.localOnly));
    });

    test('local post is immediately retrievable', () async {
      final post = await repo.createLocalPost(
        authorNodeNum: 99,
        content: 'Find me!',
      );

      final found = await repo.getPost(post.id);
      expect(found, isNotNull);
      expect(found!.content, equals('Find me!'));
    });
  });

  group('MeshFeedRepository.getRankedFeed()', () {
    test('returns empty list when no posts', () async {
      final feed = await repo.getRankedFeed();
      expect(feed, isEmpty);
    });

    test('returns ranked posts in order', () async {
      // Create posts with different ages
      final now = DateTime.now().millisecondsSinceEpoch;
      await repo.ingest(
        MeshPost(
          authorNodeNum: 1,
          createdAtMs: now - 3600000, // 1 hour ago
          content: 'older post',
          trustScore: 0.5,
        ),
      );
      await repo.ingest(
        MeshPost(
          authorNodeNum: 2,
          createdAtMs: now - 600000, // 10 min ago
          content: 'newer post',
          trustScore: 0.5,
        ),
      );

      final feed = await repo.getRankedFeed();
      expect(feed.length, equals(2));
      // Newer should rank higher due to freshness
      expect(feed.first.post.content, equals('newer post'));
    });
  });

  group('MeshFeedRepository.feedStream', () {
    test('emits after ingest', () async {
      final completer = Completer<List<RankedPost>>();
      repo.feedStream.listen((event) {
        if (!completer.isCompleted) completer.complete(event);
      });

      await repo.ingest(
        MeshPost(
          authorNodeNum: 1,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          content: 'Stream test',
        ),
      );

      final feed = await completer.future.timeout(const Duration(seconds: 2));
      expect(feed, isNotEmpty);
      expect(feed.first.post.content, equals('Stream test'));
    });

    test('emits after createLocalPost', () async {
      final completer = Completer<List<RankedPost>>();
      repo.feedStream.listen((event) {
        if (!completer.isCompleted) completer.complete(event);
      });

      await repo.createLocalPost(
        authorNodeNum: 1,
        content: 'Local stream test',
      );

      final feed = await completer.future.timeout(const Duration(seconds: 2));
      expect(feed, isNotEmpty);
      expect(feed.first.post.content, equals('Local stream test'));
    });
  });

  group('MeshFeedRepository.getSyncEligible()', () {
    test('returns non-expired pending posts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await repo.ingest(
        MeshPost(authorNodeNum: 1, createdAtMs: now, content: 'Sync eligible'),
      );

      final eligible = await repo.getSyncEligible();
      expect(eligible.length, equals(1));
      expect(eligible.first.content, equals('Sync eligible'));
    });

    test('afterMs filters older posts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await repo.ingest(
        MeshPost(
          authorNodeNum: 1,
          createdAtMs: now - 5000,
          content: 'Old post',
        ),
      );
      await repo.ingest(
        MeshPost(authorNodeNum: 2, createdAtMs: now, content: 'New post'),
      );

      final eligible = await repo.getSyncEligible(afterMs: now - 1000);
      expect(eligible.length, equals(1));
      expect(eligible.first.content, equals('New post'));
    });
  });

  group('MeshFeedRepository.countActive()', () {
    test('counts non-expired posts', () async {
      await repo.ingest(
        MeshPost(
          authorNodeNum: 1,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          content: 'Active post',
        ),
      );

      final count = await repo.countActive();
      expect(count, equals(1));
    });
  });

  group('MeshFeedRepository.dispose()', () {
    test('closes feed stream', () async {
      await repo.dispose();

      // A closed broadcast StreamController.stream.listen returns a done
      // subscription — verify it fires onDone immediately.
      final completer = Completer<bool>();
      repo.feedStream.listen(
        (_) {},
        onDone: () {
          if (!completer.isCompleted) completer.complete(true);
        },
      );
      final isDone = await completer.future.timeout(const Duration(seconds: 1));
      expect(isDone, isTrue);
    });
  });
}
