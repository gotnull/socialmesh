// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Signature for the send side of the drain: deliver [text] to node [peerId].
/// Throws when the radio is unavailable so the item stays queued (the
/// optimistic-queue contract from CARPLAY_COMMUNICATION_V0_1.md section 6).
typedef CarPlaySendFn =
    Future<void> Function(int peerId, String text, String itemId);

/// Pure drain logic for the CarPlay outbox.
///
/// Decoupled from the platform channel and `ProtocolService` so the
/// send/keep/drop decisions are unit-testable. Given the decoded outbox items
/// and a [CarPlaySendFn], it returns the ids that should be removed from the
/// shared container.
///
/// v0.1 handles `send` items only. `markRead` ops (INSetMessageAttributeIntent)
/// have no producer until the SiriKit Intents extension ships, so read-state
/// reconciliation lands in that slice alongside its producer rather than as a
/// stub here. Unknown kinds are left in place, not silently dropped.
class CarPlayDrainProcessor {
  /// Process [items], invoking [send] for each fresh `send` item.
  ///
  /// [alreadyDrained] holds ids sent in a prior pass whose container removal
  /// may not have completed; they are returned for removal without re-sending,
  /// giving idempotency across retries. Returns the ids safe to remove.
  static Future<List<String>> process({
    required List<Map<String, dynamic>> items,
    required CarPlaySendFn send,
    required Set<String> alreadyDrained,
  }) async {
    final drained = <String>[];

    for (final item in items) {
      final id = item['id'] as String?;
      if (id == null) continue; // malformed item with no idempotency key

      // Already sent in a prior pass: schedule removal, never re-send.
      if (alreadyDrained.contains(id)) {
        drained.add(id);
        continue;
      }

      final kind = (item['kind'] as String?) ?? 'send';
      if (kind != 'send') {
        // markRead / future kinds: leave queued for the slice that owns them.
        continue;
      }

      final peerId = int.tryParse((item['peerId'] as String?) ?? '');
      final text = (item['text'] as String?) ?? '';
      if (peerId == null || text.isEmpty) {
        // Unrecoverable: drop so it does not wedge the queue forever.
        drained.add(id);
        continue;
      }

      try {
        await send(peerId, text, id);
        drained.add(id);
      } catch (_) {
        // Radio down / not ready: keep queued, retry on the next trigger.
      }
    }

    return drained;
  }
}
