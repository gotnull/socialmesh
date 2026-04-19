// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';
import 'package:socialmesh/services/mesh_feed/mesh_propagation_policy.dart';

void main() {
  const policy = MeshPropagationPolicy();
  final now = DateTime(2026, 4, 15, 12, 0, 0);

  MeshPost makePost({
    MeshPostTtl ttl = MeshPostTtl.hours24,
    MeshPostPropagation propagation = MeshPostPropagation.normal,
    Duration age = Duration.zero,
    String content = 'Hello mesh',
    int? loraRebroadcastAtMs,
  }) {
    return MeshPost(
      authorNodeNum: 1,
      createdAtMs: now.subtract(age).millisecondsSinceEpoch,
      content: content,
      ttl: ttl,
      propagation: propagation,
      seenViaTransports: {MeshTransportType.lora},
      loraRebroadcastAtMs: loraRebroadcastAtMs,
    );
  }

  group('MeshPropagationPolicy.evaluate()', () {
    test('fresh normal post is eligible', () {
      final post = makePost();
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.eligible),
      );
    });

    test('expired post is denied', () {
      final post = makePost(
        ttl: MeshPostTtl.hours1,
        age: const Duration(hours: 2),
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedExpired),
      );
    });

    test('localOnly post is denied', () {
      final post = makePost(propagation: MeshPostPropagation.localOnly);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedLocalOnly),
      );
    });

    test('conservative post is denied by default', () {
      final post = makePost(propagation: MeshPostPropagation.conservative);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedConservative),
      );
    });

    test('conservative post is eligible when config allows', () {
      const lenientPolicy = MeshPropagationPolicy(
        config: PropagationPolicyConfig(allowConservativeOnLora: true),
      );
      final post = makePost(propagation: MeshPostPropagation.conservative);
      expect(
        lenientPolicy.evaluate(post, now: now),
        equals(PropagationDecision.eligible),
      );
    });

    test('already rebroadcast post is denied', () {
      final post = makePost(
        loraRebroadcastAtMs: now
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedAlreadyRebroadcast),
      );
    });

    test('oversized post is denied for LoRa', () {
      final longContent = 'x' * 201; // 201 ASCII bytes > 200 budget
      final post = makePost(content: longContent);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedOverBudget),
      );
    });

    test('exactly 200-byte content is eligible', () {
      final exactContent = 'x' * 200;
      final post = makePost(content: exactContent);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.eligible),
      );
    });

    test('post older than half TTL is denied as too old', () {
      // 24h TTL, 13h age → 54% of TTL → exceeds 50% maxAgeFraction
      final post = makePost(
        ttl: MeshPostTtl.hours24,
        age: const Duration(hours: 13),
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedTooOld),
      );
    });

    test('post at exactly half TTL boundary is denied', () {
      // 24h TTL, 12h age → exactly 50% = denied (> check)
      final post = makePost(
        ttl: MeshPostTtl.hours24,
        age: const Duration(hours: 12, seconds: 1),
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedTooOld),
      );
    });

    test('post just under half TTL is eligible', () {
      // 24h TTL, 11h age → 46% of TTL → under threshold
      final post = makePost(
        ttl: MeshPostTtl.hours24,
        age: const Duration(hours: 11),
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.eligible),
      );
    });

    test('custom maxAgeFraction is respected', () {
      const strictPolicy = MeshPropagationPolicy(
        config: PropagationPolicyConfig(maxAgeFraction: 0.25),
      );
      // 24h TTL, 7h age → 29% > 25% → denied
      final post = makePost(
        ttl: MeshPostTtl.hours24,
        age: const Duration(hours: 7),
      );
      expect(
        strictPolicy.evaluate(post, now: now),
        equals(PropagationDecision.deniedTooOld),
      );
    });

    test('unicode content is measured in UTF-8 bytes, not chars', () {
      // Each emoji is 4 bytes. 51 emojis × 4 = 204 bytes > 200 budget.
      final emojiContent = '🔥' * 51;
      final post = makePost(content: emojiContent);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedOverBudget),
      );
    });

    test('policy checks are ordered: expired before localOnly', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        content: 'Both expired and localOnly',
        ttl: MeshPostTtl.hours1,
        propagation: MeshPostPropagation.localOnly,
        seenViaTransports: {MeshTransportType.lora},
      );
      // Should be deniedExpired, not deniedLocalOnly (expired checked first)
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedExpired),
      );
    });
  });

  group('MeshPropagationPolicy.filterEligible()', () {
    test('filters out ineligible posts', () {
      final eligible = makePost(content: 'Good');
      final expired = makePost(
        ttl: MeshPostTtl.hours1,
        age: const Duration(hours: 2),
      );
      final oversized = makePost(content: 'x' * 201);

      final result = policy.filterEligible([
        eligible,
        expired,
        oversized,
      ], now: now);
      expect(result, hasLength(1));
      expect(result.first.id, equals(eligible.id));
    });

    test('returns empty list when no posts are eligible', () {
      final expired = makePost(
        ttl: MeshPostTtl.hours1,
        age: const Duration(hours: 2),
      );
      final result = policy.filterEligible([expired], now: now);
      expect(result, isEmpty);
    });

    test('returns all posts when all are eligible', () {
      final posts = [makePost(content: 'Post A'), makePost(content: 'Post B')];
      final result = policy.filterEligible(posts, now: now);
      expect(result, hasLength(2));
    });
  });
}
