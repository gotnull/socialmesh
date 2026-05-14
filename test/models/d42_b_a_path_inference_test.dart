// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-B-A: pure `inferRecentPathBytes` helper pins.
//
// The helper is the inference rule. It is pure (no I/O), receives
// pre-loaded evidence, and returns the newest valid candidate's hop
// bytes + provenance. This file pins:
//   - empty input returns null
//   - one D39 entry returns savedHistory provenance
//   - one inbound message returns inboundMessage provenance
//   - newer D39 beats older inbound message
//   - newer inbound message beats older D39
//   - outbound message ignored (path describes what we sent, not how
//     to reach the contact)
//   - inbound `pathLength == null` ignored
//   - inbound `pathLength == 0` ignored (0-hop direct - no fixed
//     route to draw beyond the endpoints; provider's drawability
//     check handles those separately if ever exposed)
//   - inbound `pathLength == -1` (flood) ignored
//   - inbound empty pathBytes ignored
//   - >64-byte candidate ignored (defensive against malformed records)
//   - tie-break 1: identical timestamp, saved vs inbound -> saved wins
//   - tie-break 2: identical timestamp, both saved, shorter hop count
//     wins
//   - tie-break 3: identical timestamp, both saved, identical hop
//     count, lexical byte order ascending wins
//   - tie-break is deterministic across input ordering

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_path_overlay.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

Uint8List _b(List<int> xs) => Uint8List.fromList(xs);

MeshCorePathHistoryEntry _saved({
  required String id,
  required List<int> bytes,
  required DateTime lastUsedAt,
  DateTime? createdAt,
  MeshCorePathSource source = MeshCorePathSource.trace,
}) {
  return MeshCorePathHistoryEntry(
    id: id,
    bytes: _b(bytes),
    len: bytes.length,
    source: source,
    createdAt: createdAt ?? lastUsedAt,
    lastUsedAt: lastUsedAt,
  );
}

MeshCoreStoredMessage _inbound({
  required String id,
  required List<int> pathBytes,
  required int? pathLength,
  required DateTime timestamp,
  bool isOutgoing = false,
}) {
  return MeshCoreStoredMessage(
    id: id,
    senderKey: Uint8List.fromList(List<int>.generate(32, (i) => i)),
    text: 'msg',
    timestamp: timestamp,
    isOutgoing: isOutgoing,
    pathBytes: _b(pathBytes),
    pathLength: pathLength,
  );
}

void main() {
  group('inferRecentPathBytes - D42-B-A', () {
    test('empty inputs returns null', () {
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: const [],
      );
      expect(r, isNull);
    });

    test('one D39 entry returns savedHistory provenance', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: [
          _saved(id: 'a', bytes: [0x01, 0x02], lastUsedAt: ts),
        ],
        storedMessages: const [],
      );
      expect(r, isNotNull);
      expect(r!.evidence, MeshCoreInferenceEvidence.savedHistory);
      expect(r.asOf, ts);
      expect(r.hopBytes, equals([0x01, 0x02]));
    });

    test('one inbound message returns inboundMessage provenance', () {
      final ts = DateTime.utc(2026, 5, 12, 10);
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: [
          _inbound(
            id: 'i1',
            pathBytes: [0xAA, 0xBB],
            pathLength: 2,
            timestamp: ts,
          ),
        ],
      );
      expect(r, isNotNull);
      expect(r!.evidence, MeshCoreInferenceEvidence.inboundMessage);
      expect(r.asOf, ts);
      expect(r.hopBytes, equals([0xAA, 0xBB]));
    });

    test('newer D39 beats older inbound message', () {
      final older = DateTime.utc(2026, 5, 11, 9);
      final newer = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: [
          _saved(id: 'a', bytes: [0xFA, 0xCE], lastUsedAt: newer),
        ],
        storedMessages: [
          _inbound(
            id: 'i1',
            pathBytes: [0xAA, 0xBB],
            pathLength: 2,
            timestamp: older,
          ),
        ],
      );
      expect(r!.evidence, MeshCoreInferenceEvidence.savedHistory);
      expect(r.hopBytes, equals([0xFA, 0xCE]));
    });

    test('newer inbound message beats older D39', () {
      final older = DateTime.utc(2026, 5, 11, 9);
      final newer = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: [
          _saved(id: 'a', bytes: [0xFA, 0xCE], lastUsedAt: older),
        ],
        storedMessages: [
          _inbound(
            id: 'i1',
            pathBytes: [0xAA, 0xBB],
            pathLength: 2,
            timestamp: newer,
          ),
        ],
      );
      expect(r!.evidence, MeshCoreInferenceEvidence.inboundMessage);
      expect(r.hopBytes, equals([0xAA, 0xBB]));
    });

    test('outbound message ignored even when newest', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: [
          _inbound(
            id: 'o1',
            pathBytes: [0xAA, 0xBB],
            pathLength: 2,
            timestamp: ts,
            isOutgoing: true,
          ),
        ],
      );
      expect(r, isNull);
    });

    test('inbound pathLength == null ignored', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: [
          _inbound(
            id: 'i1',
            pathBytes: [0xAA, 0xBB],
            pathLength: null,
            timestamp: ts,
          ),
        ],
      );
      expect(r, isNull);
    });

    test('inbound pathLength == 0 ignored', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: [
          _inbound(
            id: 'i1',
            pathBytes: [0xAA, 0xBB],
            pathLength: 0,
            timestamp: ts,
          ),
        ],
      );
      expect(r, isNull);
    });

    test('inbound pathLength == -1 (flood) ignored', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: [
          _inbound(
            id: 'i1',
            pathBytes: [0xAA, 0xBB],
            pathLength: -1,
            timestamp: ts,
          ),
        ],
      );
      expect(r, isNull);
    });

    test('inbound empty pathBytes ignored', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: const [],
        storedMessages: [
          _inbound(id: 'i1', pathBytes: const [], pathLength: 1, timestamp: ts),
        ],
      );
      expect(r, isNull);
    });

    test('>64-byte candidate ignored defensively (saved + inbound)', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final tooLong = List<int>.generate(65, (i) => i);
      final r = inferRecentPathBytes(
        savedEntries: [_saved(id: 'a', bytes: tooLong, lastUsedAt: ts)],
        storedMessages: [
          _inbound(id: 'i1', pathBytes: tooLong, pathLength: 65, timestamp: ts),
        ],
      );
      expect(r, isNull);
    });

    test(
      'tie-break 1: identical timestamp, saved vs inbound -> saved wins',
      () {
        final ts = DateTime.utc(2026, 5, 12, 9);
        final r = inferRecentPathBytes(
          savedEntries: [
            _saved(id: 'a', bytes: [0x10, 0x20], lastUsedAt: ts),
          ],
          storedMessages: [
            _inbound(
              id: 'i1',
              pathBytes: [0xAA, 0xBB],
              pathLength: 2,
              timestamp: ts,
            ),
          ],
        );
        expect(r!.evidence, MeshCoreInferenceEvidence.savedHistory);
        expect(r.hopBytes, equals([0x10, 0x20]));
      },
    );

    test('tie-break 2: same timestamp, both saved, shorter hop count wins', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: [
          _saved(id: 'long', bytes: [0x01, 0x02, 0x03], lastUsedAt: ts),
          _saved(id: 'short', bytes: [0x99, 0x88], lastUsedAt: ts),
        ],
        storedMessages: const [],
      );
      expect(r!.hopBytes, equals([0x99, 0x88]));
    });

    test(
      'tie-break 3: same timestamp + length, lexical bytes ascending wins',
      () {
        final ts = DateTime.utc(2026, 5, 12, 9);
        final r = inferRecentPathBytes(
          savedEntries: [
            _saved(id: 'high', bytes: [0xFF, 0xFF], lastUsedAt: ts),
            _saved(id: 'low', bytes: [0x10, 0x20], lastUsedAt: ts),
          ],
          storedMessages: const [],
        );
        expect(r!.hopBytes, equals([0x10, 0x20]));
      },
    );

    test('tie-break is deterministic across input ordering', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final a = _saved(id: 'a', bytes: [0x10, 0x20], lastUsedAt: ts);
      final b = _saved(id: 'b', bytes: [0x10, 0x21], lastUsedAt: ts);
      final c = _saved(id: 'c', bytes: [0x05, 0x05, 0x05], lastUsedAt: ts);

      final r1 = inferRecentPathBytes(
        savedEntries: [a, b, c],
        storedMessages: const [],
      );
      final r2 = inferRecentPathBytes(
        savedEntries: [c, b, a],
        storedMessages: const [],
      );
      final r3 = inferRecentPathBytes(
        savedEntries: [b, c, a],
        storedMessages: const [],
      );

      // Shorter (a/b are length 2; c is length 3) wins on tier 2.
      // Then lexical: 0x10 0x20 < 0x10 0x21 → 'a'.
      expect(r1!.hopBytes, equals([0x10, 0x20]));
      expect(r2!.hopBytes, equals([0x10, 0x20]));
      expect(r3!.hopBytes, equals([0x10, 0x20]));
    });

    test('manual D39 source accepted alongside trace', () {
      final ts = DateTime.utc(2026, 5, 12, 9);
      final r = inferRecentPathBytes(
        savedEntries: [
          _saved(
            id: 'm',
            bytes: [0x42, 0x43],
            lastUsedAt: ts,
            source: MeshCorePathSource.manual,
          ),
        ],
        storedMessages: const [],
      );
      expect(r, isNotNull);
      expect(r!.evidence, MeshCoreInferenceEvidence.savedHistory);
    });
  });

  group('MeshCoreInferredPath toString redaction - D42-B-A', () {
    test('toString never embeds raw byte content', () {
      final r = inferRecentPathBytes(
        savedEntries: [
          _saved(
            id: 'a',
            bytes: [0xDE, 0xAD, 0xBE, 0xEF],
            lastUsedAt: DateTime.utc(2026, 5, 12, 9),
          ),
        ],
        storedMessages: const [],
      );
      final s = r!.toString();
      // No 8-char hex run (would leak the 4-byte path bytes).
      expect(RegExp(r'[0-9a-fA-F]{8}').hasMatch(s), isFalse);
      // No 32 or 64-char hex run.
      expect(RegExp(r'[0-9a-fA-F]{32}').hasMatch(s), isFalse);
    });
  });
}
