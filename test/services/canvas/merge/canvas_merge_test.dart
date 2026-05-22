// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_merge.dart';

/// Trivial cell state used by the property tests.
class _Cell {
  int ts;
  int author;
  int seq;
  int color;
  _Cell({
    required this.ts,
    required this.author,
    required this.seq,
    required this.color,
  });
}

class _Op {
  final int ts;
  final int author;
  final int seq;
  final int color;
  const _Op({
    required this.ts,
    required this.author,
    required this.seq,
    required this.color,
  });
}

/// Apply [op] under the LWW rule. Mutates [cell] in place when accepted.
void _apply(_Cell? cell, _Op op, _Cell Function() initIfEmpty) {
  if (cell == null) return; // caller handles
  final accepted = canvasMergeAccept(
    opTs: op.ts,
    opAuthor: op.author,
    opSeq: op.seq,
    currentTs: cell.ts,
    currentAuthor: cell.author,
    currentSeq: cell.seq,
  );
  if (!accepted) return;
  cell.ts = op.ts;
  cell.author = op.author;
  cell.seq = op.seq;
  cell.color = op.color;
}

void main() {
  group('canvasMergeAccept — newer op_ts wins', () {
    test('strictly newer ts accepts regardless of other fields', () {
      expect(
        canvasMergeAccept(
          opTs: 200,
          opAuthor: 0xFFFFFFFF,
          opSeq: 0,
          currentTs: 100,
          currentAuthor: 0,
          currentSeq: 255,
        ),
        isTrue,
      );
    });

    test('strictly older ts rejects regardless of other fields', () {
      expect(
        canvasMergeAccept(
          opTs: 50,
          opAuthor: 0,
          opSeq: 0,
          currentTs: 100,
          currentAuthor: 0xFFFFFFFF,
          currentSeq: 255,
        ),
        isFalse,
      );
    });
  });

  group('canvasMergeAccept — same ts, lower author wins', () {
    test('lower author wins on tie', () {
      expect(
        canvasMergeAccept(
          opTs: 100,
          opAuthor: 0x100,
          opSeq: 0,
          currentTs: 100,
          currentAuthor: 0x200,
          currentSeq: 50,
        ),
        isTrue,
      );
    });

    test('higher author rejects on tie', () {
      expect(
        canvasMergeAccept(
          opTs: 100,
          opAuthor: 0x300,
          opSeq: 99,
          currentTs: 100,
          currentAuthor: 0x200,
          currentSeq: 0,
        ),
        isFalse,
      );
    });

    test('equal author falls through to op_seq comparator', () {
      expect(
        canvasMergeAccept(
          opTs: 100,
          opAuthor: 0x200,
          opSeq: 5,
          currentTs: 100,
          currentAuthor: 0x200,
          currentSeq: 4,
        ),
        isTrue,
      );
    });
  });

  group('canvasMergeAccept — op_seq mod-256 forward window', () {
    test('delta=1 accepts', () {
      expect(
        canvasMergeAccept(
          opTs: 1,
          opAuthor: 1,
          opSeq: 5,
          currentTs: 1,
          currentAuthor: 1,
          currentSeq: 4,
        ),
        isTrue,
      );
    });

    test('delta=127 (boundary inclusive) accepts', () {
      expect(
        canvasMergeAccept(
          opTs: 1,
          opAuthor: 1,
          opSeq: 127,
          currentTs: 1,
          currentAuthor: 1,
          currentSeq: 0,
        ),
        isTrue,
      );
    });

    test('delta=128 (just outside window) rejects', () {
      expect(
        canvasMergeAccept(
          opTs: 1,
          opAuthor: 1,
          opSeq: 128,
          currentTs: 1,
          currentAuthor: 1,
          currentSeq: 0,
        ),
        isFalse,
      );
    });

    test('delta=0 rejects (idempotent — same op is not "newer")', () {
      expect(
        canvasMergeAccept(
          opTs: 1,
          opAuthor: 1,
          opSeq: 5,
          currentTs: 1,
          currentAuthor: 1,
          currentSeq: 5,
        ),
        isFalse,
      );
    });

    test('wrap-around 255 -> 0 accepts (delta=1)', () {
      expect(
        canvasMergeAccept(
          opTs: 1,
          opAuthor: 1,
          opSeq: 0,
          currentTs: 1,
          currentAuthor: 1,
          currentSeq: 255,
        ),
        isTrue,
      );
    });

    test('reverse delta (op_seq=4, current=5) rejects', () {
      expect(
        canvasMergeAccept(
          opTs: 1,
          opAuthor: 1,
          opSeq: 4,
          currentTs: 1,
          currentAuthor: 1,
          currentSeq: 5,
        ),
        isFalse,
      );
    });
  });

  group('duplicate / idempotent', () {
    test('identical (ts, author, seq) rejects', () {
      expect(
        canvasMergeAccept(
          opTs: 42,
          opAuthor: 7,
          opSeq: 99,
          currentTs: 42,
          currentAuthor: 7,
          currentSeq: 99,
        ),
        isFalse,
      );
    });

    test('repeated application is a no-op', () {
      final cell = _Cell(ts: 100, author: 1, seq: 5, color: 9);
      const op = _Op(ts: 100, author: 1, seq: 5, color: 9);
      for (var i = 0; i < 5; i++) {
        _apply(cell, op, () => throw StateError('unused'));
      }
      expect(cell.ts, 100);
      expect(cell.author, 1);
      expect(cell.seq, 5);
      expect(cell.color, 9);
    });
  });

  group('100 randomized order permutations converge', () {
    // Property: for the same set of ops, every shuffle of arrival order
    // produces the same final per-cell state.
    test('20 ops across N permutations have identical final state', () {
      // Construct a deterministic test op set with a mix of (ts, author,
      // seq) collisions to exercise every clause of the comparator.
      final ops = <_Op>[
        const _Op(ts: 100, author: 1, seq: 0, color: 1),
        const _Op(ts: 100, author: 2, seq: 0, color: 2),
        const _Op(ts: 110, author: 1, seq: 1, color: 3),
        const _Op(ts: 110, author: 1, seq: 2, color: 4),
        const _Op(ts: 105, author: 3, seq: 9, color: 5),
        const _Op(ts: 120, author: 4, seq: 5, color: 6),
        const _Op(ts: 100, author: 4, seq: 17, color: 7),
        const _Op(ts: 130, author: 1, seq: 0, color: 8),
        const _Op(ts: 130, author: 2, seq: 7, color: 9),
        const _Op(ts: 130, author: 1, seq: 1, color: 10),
        const _Op(ts: 125, author: 5, seq: 200, color: 11),
        const _Op(ts: 125, author: 5, seq: 201, color: 12),
        const _Op(ts: 125, author: 5, seq: 255, color: 13),
        const _Op(ts: 125, author: 5, seq: 0, color: 14),
        const _Op(ts: 140, author: 6, seq: 0, color: 15),
        const _Op(ts: 140, author: 6, seq: 1, color: 16),
        const _Op(ts: 90, author: 1, seq: 99, color: 17),
        const _Op(ts: 90, author: 2, seq: 99, color: 18),
        const _Op(ts: 140, author: 5, seq: 0, color: 19),
        const _Op(ts: 145, author: 5, seq: 1, color: 20),
      ];

      // Compute the canonical final state by applying every op against
      // every other op via the comparator's total order: the surviving
      // op is the one that beats every other in pairwise comparison.
      _Op? winner;
      for (final candidate in ops) {
        if (winner == null) {
          winner = candidate;
          continue;
        }
        final candidateWins = canvasMergeAccept(
          opTs: candidate.ts,
          opAuthor: candidate.author,
          opSeq: candidate.seq,
          currentTs: winner.ts,
          currentAuthor: winner.author,
          currentSeq: winner.seq,
        );
        if (candidateWins) winner = candidate;
      }
      expect(winner, isNotNull);

      final rng = Random(0xC0DE);
      final permutations = <List<_Op>>[];
      for (var i = 0; i < 100; i++) {
        final shuffled = List<_Op>.from(ops);
        shuffled.shuffle(rng);
        permutations.add(shuffled);
      }

      // Apply every permutation and assert the final cell state equals
      // the canonical winner. We need to seed each replay from an
      // unpainted cell — the comparator can only run after the first
      // accepted op, so we treat any first op as accepted.
      for (var i = 0; i < permutations.length; i++) {
        final order = permutations[i];
        _Cell? cell;
        for (final op in order) {
          if (cell == null) {
            cell = _Cell(
              ts: op.ts,
              author: op.author,
              seq: op.seq,
              color: op.color,
            );
            continue;
          }
          _apply(cell, op, () => throw StateError('unused'));
        }
        expect(cell, isNotNull);
        expect(cell!.ts, winner!.ts, reason: 'permutation #$i diverged on ts');
        expect(
          cell.author,
          winner.author,
          reason: 'permutation #$i diverged on author',
        );
        expect(cell.seq, winner.seq, reason: 'permutation #$i diverged on seq');
        expect(
          cell.color,
          winner.color,
          reason: 'permutation #$i diverged on color',
        );
      }
    });
  });
}
