// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// LoRa propagation policy — determines whether a [MeshPost] is eligible
/// for rebroadcast over constrained transports.
///
/// Design principles:
/// - Airtime-safe: never rebroadcast over-budget or expired content
/// - One-time local rebroadcast: a post is propagated once per device
/// - Deterministic: same inputs → same decision
/// - Extension-ready: trust/priority weighting can be layered on later
library;

import 'dart:convert';

import '../../core/logging.dart';
import 'mesh_post.dart';

/// Maximum UTF-8 bytes for LoRa content payload.
const int loraContentBudget = 200;

/// Result of a propagation eligibility check.
enum PropagationDecision {
  /// Post is eligible for LoRa propagation.
  eligible,

  /// Denied — post has expired.
  deniedExpired,

  /// Denied — already rebroadcast from this device.
  deniedAlreadyRebroadcast,

  /// Denied — propagation policy is localOnly.
  deniedLocalOnly,

  /// Denied — content exceeds LoRa wire budget.
  deniedOverBudget,

  /// Denied — post is too old relative to its TTL.
  deniedTooOld,

  /// Denied — conservative policy, constrained transport not preferred.
  deniedConservative,
}

/// Configuration for propagation policy.
class PropagationPolicyConfig {
  const PropagationPolicyConfig({
    this.maxAgeFraction = 0.5,
    this.loraContentBudget = 200,
    this.allowConservativeOnLora = false,
  });

  /// Maximum age as a fraction of TTL (0.0–1.0). Posts older than
  /// `ttl * maxAgeFraction` are denied as too old. Default 0.5 = half of TTL.
  final double maxAgeFraction;

  /// Maximum UTF-8 content bytes for LoRa.
  final int loraContentBudget;

  /// Whether to allow conservative-propagation posts on LoRa.
  /// If false, conservative posts are only propagated via BLE/WiFi.
  final bool allowConservativeOnLora;
}

/// Determines whether a [MeshPost] is eligible for LoRa rebroadcast.
///
/// This is a pure, stateless policy evaluator. Propagation state
/// (rebroadcast timestamps) comes from the post's metadata fields,
/// which are backed by persistent storage.
class MeshPropagationPolicy {
  const MeshPropagationPolicy({this.config = const PropagationPolicyConfig()});

  /// Policy configuration.
  final PropagationPolicyConfig config;

  /// Evaluate whether [post] is eligible for LoRa propagation.
  ///
  /// [now] is injectable for deterministic testing.
  PropagationDecision evaluate(MeshPost post, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final postShort = post.id.length >= 8 ? post.id.substring(0, 8) : post.id;

    // 1. Expired posts are never propagated.
    if (timestamp.isAfter(post.expiresAt)) {
      AppLogging.meshFeed('propagation DENIED post=$postShort… reason=expired');
      return PropagationDecision.deniedExpired;
    }

    // 2. localOnly posts are never forwarded beyond direct peers.
    if (post.propagation == MeshPostPropagation.localOnly) {
      AppLogging.meshFeed(
        'propagation DENIED post=$postShort… reason=localOnly',
      );
      return PropagationDecision.deniedLocalOnly;
    }

    // 3. Conservative posts are denied on LoRa unless config allows.
    if (post.propagation == MeshPostPropagation.conservative &&
        !config.allowConservativeOnLora) {
      AppLogging.meshFeed(
        'propagation DENIED post=$postShort… reason=conservative',
      );
      return PropagationDecision.deniedConservative;
    }

    // 4. Already rebroadcast from this device.
    if (post.loraRebroadcastAtMs != null) {
      AppLogging.meshFeed(
        'propagation DENIED post=$postShort… reason=alreadyRebroadcast',
      );
      return PropagationDecision.deniedAlreadyRebroadcast;
    }

    // 5. Content exceeds LoRa wire budget.
    final contentBytes = utf8.encode(post.content);
    if (contentBytes.length > config.loraContentBudget) {
      AppLogging.meshFeed(
        'propagation DENIED post=$postShort… '
        'reason=overBudget (${contentBytes.length}/${config.loraContentBudget}B)',
      );
      return PropagationDecision.deniedOverBudget;
    }

    // 6. Too old — past maxAgeFraction of its TTL.
    final createdAt = DateTime.fromMillisecondsSinceEpoch(post.createdAtMs);
    final ttlMs = post.ttl.duration.inMilliseconds;
    final ageMs = timestamp.difference(createdAt).inMilliseconds;
    if (ttlMs > 0 && ageMs > ttlMs * config.maxAgeFraction) {
      AppLogging.meshFeed(
        'propagation DENIED post=$postShort… '
        'reason=tooOld (age=${ageMs}ms, max=${(ttlMs * config.maxAgeFraction).round()}ms)',
      );
      return PropagationDecision.deniedTooOld;
    }

    AppLogging.meshFeed(
      'propagation ELIGIBLE post=$postShort… '
      '${contentBytes.length}B age=${ageMs}ms',
    );
    return PropagationDecision.eligible;
  }

  /// Filter a list of posts to only those eligible for LoRa propagation.
  ///
  /// [now] is injectable for deterministic testing.
  List<MeshPost> filterEligible(List<MeshPost> posts, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return posts
        .where(
          (p) => evaluate(p, now: timestamp) == PropagationDecision.eligible,
        )
        .toList();
  }
}
