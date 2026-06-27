// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins computeDmContactDirection's derivation contract: inbound peer
// messages flag messagedMe, outbound flag iMessaged, both accumulate
// across a conversation, and tapbacks / broadcasts are skipped.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/dm_recency_provider.dart';

const _me = 0x1000;
const _peer = 0x2000;
const _broadcast = 0xFFFFFFFF;

Message _dm({
  required int from,
  required int to,
  required DateTime timestamp,
  bool received = false,
  bool isEmoji = false,
  int? replyId,
}) {
  return Message(
    from: from,
    to: to,
    text: 'msg',
    timestamp: timestamp,
    received: received,
    isEmoji: isEmoji,
    replyId: replyId,
  );
}

void main() {
  test('inbound peer message flags messagedMe only', () {
    final dir = computeDmContactDirection([
      _dm(
        from: _peer,
        to: _me,
        timestamp: DateTime(2026, 6, 1),
        received: true,
      ),
    ], _me);

    expect(dir[_peer]!.messagedMe, isTrue);
    expect(dir[_peer]!.iMessaged, isFalse);
  });

  test('outbound message flags iMessaged only', () {
    final dir = computeDmContactDirection([
      _dm(from: _me, to: _peer, timestamp: DateTime(2026, 6, 1)),
    ], _me);

    expect(dir[_peer]!.iMessaged, isTrue);
    expect(dir[_peer]!.messagedMe, isFalse);
  });

  test('a two-way conversation flags both directions', () {
    final dir = computeDmContactDirection([
      _dm(
        from: _peer,
        to: _me,
        timestamp: DateTime(2026, 6, 1),
        received: true,
      ),
      _dm(from: _me, to: _peer, timestamp: DateTime(2026, 6, 2)),
    ], _me);

    expect(dir[_peer]!.messagedMe, isTrue);
    expect(dir[_peer]!.iMessaged, isTrue);
  });

  test('peers with no direct messages are absent', () {
    final dir = computeDmContactDirection(const [], _me);
    expect(dir.containsKey(_peer), isFalse);
  });

  test('tapback reactions are not conversations', () {
    // A reply carrying an emoji is the canonical tapback shape.
    final dir = computeDmContactDirection([
      _dm(
        from: _peer,
        to: _me,
        timestamp: DateTime(2026, 6, 1),
        received: true,
        isEmoji: true,
        replyId: 42,
      ),
    ], _me);

    expect(dir.containsKey(_peer), isFalse);
  });

  test('broadcasts are not direct conversations', () {
    final dir = computeDmContactDirection([
      _dm(
        from: _peer,
        to: _broadcast,
        timestamp: DateTime(2026, 6, 1),
        received: true,
      ),
    ], _me);

    expect(dir.containsKey(_peer), isFalse);
  });
}
