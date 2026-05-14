// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A1: pure path-selection + weight helpers. No I/O, no
// providers, no globals — every input arrives via the function
// signature so the algorithm can be exercised byte-for-byte in a
// table-driven test.
//
// The rotation orchestrator (lands in D48-A2) calls
// [selectPathForAttempt] once per retry attempt to pick which
// saved path's bytes to write into the contact's `out_path` via
// `CMD_ADD_UPDATE_CONTACT 0x09`. A null return means "use flood
// (pathLen = -1)" — the final retry attempt always falls through
// to flood so a contact whose ranked paths all fail still gets one
// last opportunity to deliver.
//
// Ranking score (mirrors meshcore-open's composite from
// `path_history_service.dart:471-496`):
//   reliability   45%  successCount / (successCount + failureCount + 1)
//   freshness     10%  max(0, 1 - daysSinceLastUsed / 7)
//   routeWeight   20%  current weight / maxRouteWeight
//   latency       (deferred — we don't yet record trip-time per
//                  path, so the latency component contributes 0%
//                  and the composite is effectively 75%-of-100%.
//                  D48-B will fold it in.)
//
// Privacy: never log raw path bytes from inside these helpers.
// Callers that log do so with `path_idx` / `weight` / `delta_op`
// only.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../models/meshcore_auto_route_settings.dart';
import '../storage/meshcore_path_history_store.dart';

/// D48-A1: how recently a path was used by THIS message's rotation.
/// Prevents back-to-back re-selection of the same path during the
/// retry loop. Matches meshcore-open's `diversityWindow = 2`.
const int kMeshCorePathDiversityWindow = 2;

/// D48-A1: pick a path's hop bytes for the next retry attempt.
///
/// Returns:
///   - the chosen entry's `bytes` (caller writes these into the
///     contact's `out_path` via `CMD_ADD_UPDATE_CONTACT`), OR
///   - null, meaning the orchestrator should use flood
///     (pathLen = -1) for this attempt.
///
/// Null happens when:
///   - this is the final attempt ([attemptIndex] == [maxAttempts]-1),
///   - no ranked path qualifies (all evicted / all in the diversity
///     window),
///   - [history] is empty.
///
/// Inputs:
///   - [history]: the contact's saved-paths list as stored. Order
///     is irrelevant; the helper ranks internally.
///   - [attemptIndex]: 0-based attempt counter for this message
///     (0 = first send, 1 = first retry, ...).
///   - [maxAttempts]: total attempts the orchestrator will make
///     including the initial send.
///   - [recentSelections]: hop-byte sequences selected on prior
///     attempts of THIS message. The helper avoids re-selecting any
///     entry whose bytes appear in the last [kMeshCorePathDiversityWindow]
///     entries.
///   - [settings]: the live auto-route settings (used here only as
///     a weight scale; selection itself ignores
///     `enabled` — the caller gates that).
///   - [now]: clock anchor for the freshness component.
Uint8List? selectPathForAttempt({
  required List<MeshCorePathHistoryEntry> history,
  required int attemptIndex,
  required int maxAttempts,
  required List<Uint8List> recentSelections,
  required MeshCoreAutoRouteSettings settings,
  required DateTime now,
}) {
  // Final attempt: flood fallback. The orchestrator writes
  // `pathLen = -1` to the contact and lets the firmware flood-route.
  if (attemptIndex >= maxAttempts - 1) return null;

  if (history.isEmpty) return null;

  // Build the diversity-avoid set from the last N selections.
  final avoid = <_BytesKey>{};
  final recencyStart = recentSelections.length - kMeshCorePathDiversityWindow;
  for (
    var i = recencyStart < 0 ? 0 : recencyStart;
    i < recentSelections.length;
    i++
  ) {
    avoid.add(_BytesKey(recentSelections[i]));
  }

  // Score every entry; ignore evicted (routeWeight <= 0) since the
  // store removes them on failure, but be defensive against legacy
  // rows that may have a 0 weight.
  final scored = <_ScoredEntry>[];
  for (final entry in history) {
    if (entry.routeWeight <= 0) continue;
    if (avoid.contains(_BytesKey(entry.bytes))) continue;
    scored.add(
      _ScoredEntry(
        entry: entry,
        score: _composite(entry: entry, settings: settings, now: now),
      ),
    );
  }
  if (scored.isEmpty) return null;

  // Sort descending by score with a deterministic tiebreaker:
  // higher score first, then shorter hop count (fewer hops better),
  // then lexically-smaller bytes (stable across runs).
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byLen = a.entry.bytes.length.compareTo(b.entry.bytes.length);
    if (byLen != 0) return byLen;
    return _bytesCompare(a.entry.bytes, b.entry.bytes);
  });

  // Round-robin: attempt-1 maps to rank 0 (best path), attempt-2 to
  // rank 1, etc. attemptIndex 0 is the initial send (rotation
  // wouldn't normally call this) — pick rank 0 defensively rather
  // than negative-indexing.
  final retryIndex = attemptIndex <= 0 ? 0 : attemptIndex - 1;
  final picked = scored[retryIndex % scored.length];
  return Uint8List.fromList(picked.entry.bytes);
}

/// D48-A2: compute the firmware-side expected ack-hash for a
/// CMD_SEND_TXT_MSG attempt.
///
/// Wire algorithm (ported byte-for-byte from meshcore-open's
/// `MessageRetryService.computeExpectedAckHash`, which itself
/// mirrors the firmware in
/// `MeshCore/examples/companion_radio/MyMesh.cpp`):
///
///   buffer  = [timestamp:u32 LE][attempt & 0x03:u8]
///             [text utf-8 bytes][sender pubkey:32 B]
///   digest  = SHA-256(buffer)
///   ackHash = u32-LE(digest[0..4])
///
/// Returned as an unsigned 32-bit int. The firmware echoes the same
/// value in the sync `RESP_CODE_SENT 0x06` ack at payload offset
/// `[1..5]` and in the routed `PUSH_CODE_SEND_CONFIRMED 0x82` push
/// at payload offset `[0..4]`. The orchestrator matches on this
/// hash to correlate a 0x82 push back to the originating send.
///
/// Note `attempt & 0x03`: the firmware only encodes the bottom two
/// bits of the attempt counter in the hash so meshcore-open
/// permits at most 4 distinguishable attempts per outbound
/// message before hash collisions begin. We mirror the mask
/// exactly — the orchestrator's [MeshCoreAutoRouteSettings.maxRetries]
/// upper bound is independently capped at 8 by setting clamping,
/// but post-collision attempts (attempt 4 collides with 0, 5 with
/// 1, ...) reuse an earlier attempt's expected hash so the
/// firmware's `expected_ack_table` will still match if it hasn't
/// rolled the entry out. Acceptable: D48-A1's diversity window of
/// 2 ensures we rotate paths long before the hash collides.
int computeExpectedAckHash({
  required int timestampSeconds,
  required int attempt,
  required String text,
  required Uint8List senderPubKey,
}) {
  final textBytes = utf8.encode(text);
  final buffer = Uint8List(4 + 1 + textBytes.length + senderPubKey.length);
  var offset = 0;
  buffer[offset++] = timestampSeconds & 0xFF;
  buffer[offset++] = (timestampSeconds >> 8) & 0xFF;
  buffer[offset++] = (timestampSeconds >> 16) & 0xFF;
  buffer[offset++] = (timestampSeconds >> 24) & 0xFF;
  buffer[offset++] = attempt & 0x03;
  buffer.setRange(offset, offset + textBytes.length, textBytes);
  offset += textBytes.length;
  buffer.setRange(offset, offset + senderPubKey.length, senderPubKey);
  final digest = sha256.convert(buffer);
  final b = digest.bytes;
  return (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
}

/// D48-A1: pre-clamped post-success weight. Caller writes the
/// returned value via `recordPathSuccess`.
double weightAfterSuccess(
  double currentWeight,
  MeshCoreAutoRouteSettings settings,
) {
  final next = currentWeight + settings.routeWeightSuccessIncrement;
  if (next > settings.maxRouteWeight) return settings.maxRouteWeight;
  if (next < 0) return 0;
  return next;
}

/// D48-A1: pre-clamped post-failure weight. A return ≤ 0 signals to
/// the caller that the entry should be evicted from the history
/// store on this update.
double weightAfterFailure(
  double currentWeight,
  MeshCoreAutoRouteSettings settings,
) {
  final next = currentWeight - settings.routeWeightFailureDecrement;
  // Caller treats ≤ 0 as eviction; don't clamp the floor here so the
  // signal survives.
  return next;
}

double _composite({
  required MeshCorePathHistoryEntry entry,
  required MeshCoreAutoRouteSettings settings,
  required DateTime now,
}) {
  // Reliability: heavier weight on success vs failure; +1 in the
  // denominator avoids divide-by-zero on new entries (favors them
  // slightly until first failure).
  final reliability =
      entry.successCount / (entry.successCount + entry.failureCount + 1);

  // Freshness: linear decay from 1.0 (used today) to 0.0 (≥ 7 days
  // ago). Caps at 0 for older entries.
  final daysSinceLastUsed =
      now.difference(entry.lastUsedAt).inMilliseconds /
      const Duration(days: 1).inMilliseconds;
  final freshness = daysSinceLastUsed >= 7.0
      ? 0.0
      : (1.0 - daysSinceLastUsed / 7.0);

  // Route weight normalized: divide by the policy's max so the
  // component sits in [0, 1].
  final weightComponent = settings.maxRouteWeight <= 0
      ? 0.0
      : (entry.routeWeight / settings.maxRouteWeight);

  // 0.45 + 0.10 + 0.20 = 0.75 — latency (0.25) deferred.
  return (reliability * 0.45) + (freshness * 0.10) + (weightComponent * 0.20);
}

int _bytesCompare(Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

class _ScoredEntry {
  final MeshCorePathHistoryEntry entry;
  final double score;
  const _ScoredEntry({required this.entry, required this.score});
}

/// Bytes-equality wrapper for Set membership in the diversity-avoid
/// check. `Uint8List` uses identity equality by default; this wraps
/// content equality.
class _BytesKey {
  final Uint8List bytes;
  const _BytesKey(this.bytes);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _BytesKey) return false;
    if (other.bytes.length != bytes.length) return false;
    for (var i = 0; i < bytes.length; i++) {
      if (other.bytes[i] != bytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // FNV-1a 32-bit; fine for the small lookup tables we use.
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h = (h ^ b) & 0xFFFFFFFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
