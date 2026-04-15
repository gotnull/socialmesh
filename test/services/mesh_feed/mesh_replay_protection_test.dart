// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_database.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_repository.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';

/// Fake in-memory [MeshFeedDatabase] for replay protection tests.
class _FakeDb extends MeshFeedDatabase {
  _FakeDb() : super(dbPathOverride: ':memory:');

  final Map<String, MeshPost> posts = {};
  final List<_Receipt> receipts = [];

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
      posts[post.id] = existing.copyWith(
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
    posts[post.id] = post;
    return true;
  }

  @override
  Future<void> addReceipt({
    required String postId,
    required MeshTransportType transport,
    String? peerId,
    int? hopCount,
  }) async {
    receipts.add(
      _Receipt(postId: postId, transport: transport, hopCount: hopCount),
    );
  }

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

  int get upsertCallCount => _upsertCallCount;
  int _upsertCallCount = 0;

  /// Counts how many times upsertPost is called (for churn measurement).
  Future<bool> countedUpsert(MeshPost post) async {
    _upsertCallCount++;
    return upsertPost(post);
  }
}

class _Receipt {
  _Receipt({required this.postId, required this.transport, this.hopCount});
  final String postId;
  final MeshTransportType transport;
  final int? hopCount;
}

void main() {
  late _FakeDb db;
  late MeshFeedRepository repo;

  setUp(() {
    db = _FakeDb();
    repo = MeshFeedRepository(
      database: db,
      replayConfig: const ReplayGuardConfig(windowMs: 30000),
    );
  });

  tearDown(() async {
    await repo.dispose();
  });

  group('Replay protection', () {
    test('first ingest of a post returns inserted', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'First post',
        seenViaTransports: {MeshTransportType.lora},
      );

      final result = await repo.ingest(post);
      expect(result, equals(IngestResult.inserted));
      expect(db.posts.length, equals(1));
      expect(repo.replayCacheSize, equals(1));
    });

    test(
      'immediate duplicate from same transport is replay suppressed',
      () async {
        final post = MeshPost(
          authorNodeNum: 1,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          content: 'Duplicate test',
          seenViaTransports: {MeshTransportType.lora},
        );

        await repo.ingest(post);
        final result = await repo.ingest(post);
        expect(result, equals(IngestResult.replaySuppressed));
        expect(db.posts.length, equals(1));
      },
    );

    test('burst replay of same object 100 times only inserts once', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'Burst test',
        seenViaTransports: {MeshTransportType.lora},
      );

      final results = <IngestResult>[];
      for (var i = 0; i < 100; i++) {
        results.add(await repo.ingest(post));
      }

      expect(results.where((r) => r == IngestResult.inserted).length, 1);
      expect(
        results.where((r) => r == IngestResult.replaySuppressed).length,
        99,
      );
      expect(db.posts.length, equals(1));
    });

    test(
      'immediate duplicate from different transport records new provenance',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final fromLora = MeshPost(
          authorNodeNum: 42,
          createdAtMs: now,
          content: 'Multi-transport test',
          seenViaTransports: {MeshTransportType.lora},
          hopCount: 3,
        );
        final fromWifi = MeshPost(
          authorNodeNum: 42,
          createdAtMs: now,
          content: 'Multi-transport test',
          seenViaTransports: {MeshTransportType.lanPeerSync},
          hopCount: 1,
        );

        await repo.ingest(fromLora);
        final result = await repo.ingest(fromWifi);
        expect(result, equals(IngestResult.provenanceUpdated));
        expect(db.posts.length, equals(1));

        // Verify provenance was recorded.
        final stored = db.posts.values.first;
        expect(
          stored.seenViaTransports,
          containsAll([MeshTransportType.lora, MeshTransportType.lanPeerSync]),
        );

        // Verify receipt was added for the new transport.
        expect(
          db.receipts
              .where((r) => r.transport == MeshTransportType.lanPeerSync)
              .isNotEmpty,
          isTrue,
        );
      },
    );

    test(
      'replay after cache clear (restart simulation) does full ingest',
      () async {
        final post = MeshPost(
          authorNodeNum: 1,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          content: 'Restart test',
          seenViaTransports: {MeshTransportType.lora},
        );

        await repo.ingest(post);
        expect(db.posts.length, equals(1));

        // Simulate app restart by clearing replay cache.
        repo.clearReplayCache();
        expect(repo.replayCacheSize, equals(0));

        // Re-ingest the same post — should go through full path (merged).
        final result = await repo.ingest(post);
        expect(result, equals(IngestResult.merged));
        expect(db.posts.length, equals(1));
      },
    );

    test(
      'existing stored object from new transport after restart merges',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final post = MeshPost(
          authorNodeNum: 1,
          createdAtMs: now,
          content: 'Cross-restart test',
          seenViaTransports: {MeshTransportType.lora},
        );

        await repo.ingest(post);
        repo.clearReplayCache();

        // Now receive same post from WiFi after restart.
        final fromWifi = MeshPost(
          authorNodeNum: 1,
          createdAtMs: now,
          content: 'Cross-restart test',
          seenViaTransports: {MeshTransportType.lanPeerSync},
        );

        final result = await repo.ingest(fromWifi);
        expect(result, equals(IngestResult.merged));
        expect(db.posts.length, equals(1));

        final stored = db.posts.values.first;
        expect(
          stored.seenViaTransports,
          containsAll([MeshTransportType.lora, MeshTransportType.lanPeerSync]),
        );
      },
    );

    test('replay suppression does not break feed stream', () async {
      final completer = Completer<List<dynamic>>();
      final emissions = <int>[];
      repo.feedStream.listen((event) {
        emissions.add(event.length);
        if (emissions.isNotEmpty && !completer.isCompleted) {
          completer.complete(emissions);
        }
      });

      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'Stream test',
        seenViaTransports: {MeshTransportType.lora},
      );

      // First ingest emits.
      await repo.ingest(post);
      await completer.future.timeout(const Duration(seconds: 2));

      // Replay-suppressed ingest should NOT emit.
      final preCount = emissions.length;
      await repo.ingest(post);
      // Give a tick for any potential emission.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.length, equals(preCount));
    });

    test('replay cache prunes oldest entries when max size exceeded', () async {
      // Use a tiny cache.
      final smallRepo = MeshFeedRepository(
        database: db,
        replayConfig: const ReplayGuardConfig(maxCacheSize: 3),
      );

      for (var i = 0; i < 5; i++) {
        await smallRepo.ingest(
          MeshPost(
            authorNodeNum: i,
            createdAtMs: DateTime.now().millisecondsSinceEpoch + i,
            content: 'Post $i',
            seenViaTransports: {MeshTransportType.lora},
          ),
        );
      }

      expect(smallRepo.replayCacheSize, lessThanOrEqualTo(3));

      await smallRepo.dispose();
    });

    test('expired post is still rejected during replay window', () async {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch,
        content: 'Old and expired',
        ttl: MeshPostTtl.hours24,
      );

      final result = await repo.ingest(post);
      expect(result, equals(IngestResult.rejectedExpired));
      expect(db.posts.length, equals(0));
    });
  });
}
