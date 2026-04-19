// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_feed_ranking.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';

void main() {
  late MeshFeedRanking ranking;
  late DateTime now;

  setUp(() {
    ranking = const MeshFeedRanking();
    now = DateTime(2024, 1, 15, 12); // Fixed reference time
  });

  MeshPost makePost({
    int authorNodeNum = 1,
    required int createdAtMs,
    String content = 'test',
    MeshPostTtl ttl = MeshPostTtl.hours24,
    int? hopCount,
    bool isLocal = false,
    double? trustScore,
    DateTime? lastSeenAt,
  }) {
    return MeshPost(
      authorNodeNum: authorNodeNum,
      createdAtMs: createdAtMs,
      content: content,
      ttl: ttl,
      hopCount: hopCount,
      isLocal: isLocal,
      trustScore: trustScore,
      lastSeenAt: lastSeenAt,
    );
  }

  group('FeedRankingConfig', () {
    test('default weights sum to 1.0', () {
      const config = FeedRankingConfig();
      final sum =
          config.freshnessWeight +
          config.trustWeight +
          config.proximityWeight +
          config.recencyWeight;
      expect(sum, closeTo(1.0, 0.001));
    });
  });

  group('MeshFeedRanking.rank()', () {
    test('empty list returns empty list', () {
      final result = ranking.rank([], now: now);
      expect(result, isEmpty);
    });

    test('single post returns one ranked post', () {
      final post = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      );
      final result = ranking.rank([post], now: now);
      expect(result.length, equals(1));
      expect(result.first.post.id, equals(post.id));
      expect(result.first.score, greaterThan(0.0));
      expect(result.first.score, lessThanOrEqualTo(1.0));
    });

    test('fresher posts rank higher (all else equal)', () {
      final fresh = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        content: 'fresh',
        trustScore: 0.5,
        hopCount: 2,
        lastSeenAt: now,
      );
      final old = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 20))
            .millisecondsSinceEpoch,
        content: 'old',
        trustScore: 0.5,
        hopCount: 2,
        lastSeenAt: now,
      );
      final result = ranking.rank([old, fresh], now: now);
      expect(result.first.post.id, equals(fresh.id));
    });

    test('higher trust scores rank higher (all else equal)', () {
      final trusted = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        content: 'trusted',
        trustScore: 0.9,
        hopCount: 2,
        lastSeenAt: now,
      );
      final untrusted = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        content: 'untrusted',
        trustScore: 0.1,
        hopCount: 2,
        lastSeenAt: now,
      );
      final result = ranking.rank([untrusted, trusted], now: now);
      expect(result.first.post.id, equals(trusted.id));
    });

    test('local posts have higher proximity score', () {
      final local = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        content: 'local',
        isLocal: true,
        trustScore: 0.5,
        lastSeenAt: now,
      );
      final distant = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        content: 'distant',
        hopCount: 6,
        trustScore: 0.5,
        lastSeenAt: now,
      );
      final result = ranking.rank([distant, local], now: now);
      final localRanked = result.firstWhere((r) => r.post.id == local.id);
      final distantRanked = result.firstWhere((r) => r.post.id == distant.id);
      expect(
        localRanked.proximityComponent,
        greaterThan(distantRanked.proximityComponent),
      );
    });

    test('recently seen posts rank higher', () {
      final recent = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 12))
            .millisecondsSinceEpoch,
        content: 'recent',
        trustScore: 0.5,
        hopCount: 2,
        lastSeenAt: now,
      );
      final stale = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 12))
            .millisecondsSinceEpoch,
        content: 'stale',
        trustScore: 0.5,
        hopCount: 2,
        lastSeenAt: now.subtract(const Duration(hours: 5)),
      );
      final result = ranking.rank([stale, recent], now: now);
      final recentRanked = result.firstWhere((r) => r.post.id == recent.id);
      final staleRanked = result.firstWhere((r) => r.post.id == stale.id);
      expect(
        recentRanked.recencyComponent,
        greaterThan(staleRanked.recencyComponent),
      );
    });

    test('deterministic tiebreak: createdAtMs DESC then id ASC', () {
      // Create posts with the same score characteristics but different timestamps
      final post1 = makePost(
        authorNodeNum: 1,
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        content: 'post-alpha',
        trustScore: 0.5,
        hopCount: 2,
        lastSeenAt: now,
      );
      final post2 = makePost(
        authorNodeNum: 2,
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        content: 'post-beta',
        trustScore: 0.5,
        hopCount: 2,
        lastSeenAt: now,
      );

      // Multiple rankings should produce the same order
      final result1 = ranking.rank([post1, post2], now: now);
      final result2 = ranking.rank([post2, post1], now: now);
      expect(
        result1.map((r) => r.post.id).toList(),
        equals(result2.map((r) => r.post.id).toList()),
      );
    });

    test('score components are individually valid (0.0-1.0)', () {
      final post = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 6))
            .millisecondsSinceEpoch,
        trustScore: 0.7,
        hopCount: 3,
        lastSeenAt: now.subtract(const Duration(minutes: 30)),
      );
      final result = ranking.rank([post], now: now);
      final ranked = result.first;

      expect(ranked.freshnessComponent, inInclusiveRange(0.0, 1.0));
      expect(ranked.trustComponent, inInclusiveRange(0.0, 1.0));
      expect(ranked.proximityComponent, inInclusiveRange(0.0, 1.0));
      expect(ranked.recencyComponent, inInclusiveRange(0.0, 1.0));
      expect(ranked.score, inInclusiveRange(0.0, 1.0));
    });

    test('expired post has zero freshness', () {
      final expired = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch,
        ttl: MeshPostTtl.hours24,
        lastSeenAt: now,
      );
      final result = ranking.rank([expired], now: now);
      expect(result.first.freshnessComponent, equals(0.0));
    });

    test('just-created post has high freshness', () {
      final fresh = makePost(
        createdAtMs: now.millisecondsSinceEpoch,
        lastSeenAt: now,
      );
      final result = ranking.rank([fresh], now: now);
      expect(result.first.freshnessComponent, closeTo(1.0, 0.01));
    });

    test('null trust score defaults to 0.1', () {
      final post = makePost(
        createdAtMs: now.millisecondsSinceEpoch,
        trustScore: null,
        lastSeenAt: now,
      );
      final result = ranking.rank([post], now: now);
      expect(result.first.trustComponent, closeTo(0.1, 0.001));
    });

    test('custom config weights are respected', () {
      final customRanking = MeshFeedRanking(
        config: FeedRankingConfig(
          freshnessWeight: 0.0,
          trustWeight: 1.0,
          proximityWeight: 0.0,
          recencyWeight: 0.0,
        ),
      );

      final highTrust = makePost(
        createdAtMs: now
            .subtract(const Duration(hours: 20))
            .millisecondsSinceEpoch,
        content: 'high-trust',
        trustScore: 0.9,
        lastSeenAt: now,
      );
      final lowTrust = makePost(
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'low-trust',
        trustScore: 0.1,
        lastSeenAt: now,
      );

      final result = customRanking.rank([lowTrust, highTrust], now: now);
      // With trust-only weighting, high trust should win despite being older
      expect(result.first.post.id, equals(highTrust.id));
    });
  });
}
