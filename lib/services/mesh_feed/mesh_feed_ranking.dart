// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feed ranking engine — deterministic scoring for mesh post ordering.
///
/// The ranking is a weighted blend of four signals:
///   1. Freshness (35%) — how close to creation vs. expiry
///   2. Trust     (30%) — author trust score from NodeDex evidence
///   3. Proximity (20%) — hop distance (lower = closer = higher score)
///   4. Recency   (15%) — how recently the post was last seen
///
/// Tie-breaking is deterministic: posts with equal score are ordered
/// by (createdAtMs DESC, id ASC).
library;

import 'dart:math' as math;

import 'mesh_post.dart';

/// A scored post ready for ranked display.
class RankedPost {
  const RankedPost({
    required this.post,
    required this.score,
    required this.freshnessComponent,
    required this.trustComponent,
    required this.proximityComponent,
    required this.recencyComponent,
  });

  /// The underlying post.
  final MeshPost post;

  /// Overall ranking score (0.0–1.0).
  final double score;

  /// Individual component scores (0.0–1.0 each, pre-weight).
  final double freshnessComponent;
  final double trustComponent;
  final double proximityComponent;
  final double recencyComponent;
}

/// Configuration for the ranking weights.
class FeedRankingConfig {
  const FeedRankingConfig({
    this.freshnessWeight = 0.35,
    this.trustWeight = 0.30,
    this.proximityWeight = 0.20,
    this.recencyWeight = 0.15,
    this.maxHops = 7,
    this.recencyHalfLifeMs = 3600000, // 1 hour
  });

  /// Weight for freshness signal.
  final double freshnessWeight;

  /// Weight for trust signal.
  final double trustWeight;

  /// Weight for proximity signal.
  final double proximityWeight;

  /// Weight for recency signal.
  final double recencyWeight;

  /// Maximum hop count for normalisation.
  final int maxHops;

  /// Half-life for recency decay in milliseconds.
  final int recencyHalfLifeMs;
}

/// Deterministic ranking engine for mesh feed posts.
///
/// All methods are pure functions with no side effects.
class MeshFeedRanking {
  const MeshFeedRanking({this.config = const FeedRankingConfig()});

  /// Ranking configuration.
  final FeedRankingConfig config;

  /// Rank a list of posts, returning scored entries in descending order.
  ///
  /// [now] is injectable for deterministic testing.
  List<RankedPost> rank(List<MeshPost> posts, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final scored = posts.map((p) => _score(p, timestamp)).toList();

    // Deterministic sort: score DESC, then createdAtMs DESC, then id ASC
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      final tsCmp = b.post.createdAtMs.compareTo(a.post.createdAtMs);
      if (tsCmp != 0) return tsCmp;
      return a.post.id.compareTo(b.post.id);
    });

    return scored;
  }

  RankedPost _score(MeshPost post, DateTime now) {
    final freshness = _scoreFreshness(post, now);
    final trust = _scoreTrust(post);
    final proximity = _scoreProximity(post);
    final recency = _scoreRecency(post, now);

    final score =
        freshness * config.freshnessWeight +
        trust * config.trustWeight +
        proximity * config.proximityWeight +
        recency * config.recencyWeight;

    return RankedPost(
      post: post,
      score: score.clamp(0.0, 1.0),
      freshnessComponent: freshness,
      trustComponent: trust,
      proximityComponent: proximity,
      recencyComponent: recency,
    );
  }

  /// Freshness: linear from 1.0 (just created) to 0.0 (at expiry).
  double _scoreFreshness(MeshPost post, DateTime now) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(post.createdAtMs);
    final ttlMs = post.ttl.duration.inMilliseconds;
    if (ttlMs <= 0) return 0.0;
    final elapsed = now.difference(createdAt).inMilliseconds;
    return (1.0 - elapsed / ttlMs).clamp(0.0, 1.0);
  }

  /// Trust: directly from cached author trust score (0.0 to 1.0).
  /// Returns 0.1 for unknown trust (not 0.0, so untrusted content is
  /// still visible rather than buried).
  double _scoreTrust(MeshPost post) {
    return (post.trustScore ?? 0.1).clamp(0.0, 1.0);
  }

  /// Proximity: inverse of hop count normalised to [maxHops].
  /// Local posts (hop 0 or null) score 1.0.
  double _scoreProximity(MeshPost post) {
    if (post.isLocal) return 1.0;
    final hops = post.hopCount ?? config.maxHops;
    return (1.0 - hops / config.maxHops).clamp(0.0, 1.0);
  }

  /// Recency: exponential decay from last seen time.
  double _scoreRecency(MeshPost post, DateTime now) {
    final elapsedMs = now.difference(post.lastSeenAt).inMilliseconds;
    if (elapsedMs <= 0) return 1.0;
    // e^(-ln2 * elapsed / halfLife)
    return math.exp(-0.693 * elapsedMs / config.recencyHalfLifeMs);
  }
}
