// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Engine replay tests. These pin the locked-in invariants:
///
///   - State is derived purely from the entry log.
///   - Strict-seq enforcement: `incoming.seq == lastApplied + 1` else
///     drop (no buffering, no recovery).
///   - Duplicates / replays drop without state change.
///   - Sync action is reserved-in-v1: drop without applying.
///   - Mark assignment is deterministic from offer direction.
///   - Unknown gameType becomes a terminal `unsupported` state with
///     no further entries applied.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/games/connectfour/c4_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/games/connectfour/c4_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_constants.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_engine.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_payload.dart';

const int _instanceId = 0xBEEF;
const int _gameTypeTtt = 0x01;
const int _gameTypeC4 = 0x02;

SipPlayEnvelope _envelope({
  required SipPlayAction action,
  required int seq,
  Uint8List? gamePayload,
  int gameTypeCode = _gameTypeTtt,
  int instanceId = _instanceId,
}) {
  return SipPlayEnvelope(
    typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
    gameTypeCode: gameTypeCode,
    instanceId: instanceId,
    action: action,
    seq: seq,
    gamePayload: gamePayload ?? Uint8List(0),
  );
}

SipPlayEntry _entry(SipPlayEnvelope env, SipPlayEntryDirection dir) =>
    SipPlayEntry(envelope: env, direction: dir);

Uint8List _moveBytes({required int cell, required TttMark mark}) {
  return TttCodec.encodeMove(TttMove(cell: cell, mark: mark))!;
}

Uint8List _c4MoveBytes({required int column, required C4Disc disc}) {
  return C4Codec.encodeMove(C4Move(column: column, disc: disc))!;
}

/// Test-only adapter: a TTT-locked replay, casting the sealed base
/// down once at the call site rather than per-assertion.
TttInstanceState _replayTtt(List<SipPlayEntry> entries) =>
    SipPlayEngine.replay(entries) as TttInstanceState;

/// Test-only adapter: a C4-locked replay.
C4InstanceState _replayC4(List<SipPlayEntry> entries) =>
    SipPlayEngine.replay(entries) as C4InstanceState;

void main() {
  group('Mark assignment determinism', () {
    test('local offered → localMark X, remoteMark O', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.active));
      expect(state.localMark, equals(TttMark.x));
      expect(state.remoteMark, equals(TttMark.o));
      expect(state.turn, equals(TttMark.x));
      expect(state.isLocalTurn, isTrue);
    });

    test('remote offered → localMark O, remoteMark X', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.localMark, equals(TttMark.o));
      expect(state.remoteMark, equals(TttMark.x));
      expect(state.turn, equals(TttMark.x));
      expect(state.isLocalTurn, isFalse);
    });
  });

  group('Pure replay determinism', () {
    test('replaying the same log twice produces identical state', () {
      final log = [
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ];
      final s1 = _replayTtt(log);
      final s2 = _replayTtt(log);

      expect(s1.status, equals(s2.status));
      expect(s1.lastAppliedSeq, equals(s2.lastAppliedSeq));
      expect(s1.board.cells, equals(s2.board.cells));
      expect(s1.turn, equals(s2.turn));
    });
  });

  group('Strict-seq enforcement', () {
    test('move with seq != lastApplied + 1 is dropped', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          // Skipped seq=2 — seq=3 must be dropped.
          _envelope(
            action: SipPlayAction.move,
            seq: 3,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.active));
      expect(state.lastAppliedSeq, equals(1));
      expect(state.board.moveCount, equals(0));
    });

    test('duplicate move (seq <= lastApplied) is dropped', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2, // duplicate
            gamePayload: _moveBytes(cell: 1, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.lastAppliedSeq, equals(2));
      expect(state.board.moveCount, equals(1));
      expect(state.board.cells[0], equals(TttMark.x));
      expect(state.board.cells[1], isNull);
    });

    test('out-of-order move drops, then in-order continues normally', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          // seq=5 — out of order, dropped
          _envelope(
            action: SipPlayAction.move,
            seq: 5,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          // seq=2 — correct
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.lastAppliedSeq, equals(2));
      expect(state.board.cells[4], equals(TttMark.x));
      expect(state.board.cells[0], isNull);
    });
  });

  group('Game lifecycle', () {
    test('offer → decline locks declined-by-acceptor terminal', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.declinedByRemote));
      expect(state.isTerminal, isTrue);
    });

    test('full TTT win sequence on diagonal — winner detected at end', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        // X (local) takes 0
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
        // O takes 1
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 3,
            gamePayload: _moveBytes(cell: 1, mark: TttMark.o),
          ),
          SipPlayEntryDirection.inbound,
        ),
        // X takes 4
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 4,
            gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
        // O takes 2
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 5,
            gamePayload: _moveBytes(cell: 2, mark: TttMark.o),
          ),
          SipPlayEntryDirection.inbound,
        ),
        // X takes 8 — wins on diagonal 0-4-8
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 6,
            gamePayload: _moveBytes(cell: 8, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.won));
      expect(state.winner, equals(TttMark.x));
      expect(state.turn, isNull);
    });

    test('resign during active locks resignedByLocal terminal', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.resign, seq: 2),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.resignedByLocal));
      expect(state.isTerminal, isTrue);
    });

    test('moves attempted on the wrong-cell are dropped (cell occupied)', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          // Wrong-mark move (peer claims X mid-game) → drop.
          _envelope(
            action: SipPlayAction.move,
            seq: 3,
            gamePayload: _moveBytes(cell: 1, mark: TttMark.x),
          ),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.lastAppliedSeq, equals(2));
      expect(state.board.cells[1], isNull);
    });

    test('move on already-occupied cell is dropped', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          // O tries cell 4 — already occupied by X.
          _envelope(
            action: SipPlayAction.move,
            seq: 3,
            gamePayload: _moveBytes(cell: 4, mark: TttMark.o),
          ),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.lastAppliedSeq, equals(2));
      expect(state.board.cells[4], equals(TttMark.x));
    });
  });

  group('Reserved + safety branches', () {
    test('sync action is silently dropped (reserved in v1)', () {
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          // Should be a no-op — sync is reserved.
          _envelope(action: SipPlayAction.sync, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.pendingOffer));
      expect(state.lastAppliedSeq, equals(0));
    });

    test('unknown gameType becomes terminal unsupported on first envelope', () {
      // This branch returns UnsupportedInstanceState (no board), so we
      // bypass the TTT-cast helper and assert against the sealed base.
      final state = SipPlayEngine.replay([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: 0xFE, // unknown
          ),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          // Subsequent valid envelope must NOT mutate the unsupported
          // terminal state.
          _envelope(
            action: SipPlayAction.move,
            seq: 1,
            gameTypeCode: 0xFE,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state, isA<UnsupportedInstanceState>());
      expect(state.status, equals(SipPlayInstanceStatus.unsupported));
      expect(state.gameTypeCode, equals(0xFE));
      // No board on UnsupportedInstanceState — its absence IS the
      // assertion (subsequent envelopes can't apply moves).
    });

    test('mid-stream gameType drift on a valid game is ignored', () {
      // First envelope is TTT; later envelope claims a different
      // gameType. Engine ignores the drifting envelope.
      final state = _replayTtt([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1, gameTypeCode: 0x99),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      // The accept's gameTypeCode mismatch causes it to be ignored.
      expect(state.status, equals(SipPlayInstanceStatus.pendingOffer));
    });

    test('decode helper returns null on malformed payload bytes', () {
      // Empty / garbage / wrong-version inputs to decodeEntry must
      // return null without throwing.
      expect(
        SipPlayEngine.decodeEntry(
          payload: Uint8List(0),
          direction: SipPlayEntryDirection.inbound,
        ),
        isNull,
      );
      expect(
        SipPlayEngine.decodeEntry(
          payload: Uint8List.fromList([0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]),
          direction: SipPlayEntryDirection.inbound,
        ),
        isNull,
      );
    });
  });

  group('Move payload size budget', () {
    test('encoded TTT move envelope is exactly 7 bytes', () {
      final env = _envelope(
        action: SipPlayAction.move,
        seq: 1,
        gamePayload: _moveBytes(cell: 0, mark: TttMark.x),
      );
      final bytes = SipPlayCodec.encode(env)!;
      expect(bytes.length, equals(7));
    });

    test('encoded C4 move envelope is exactly 7 bytes', () {
      final env = _envelope(
        action: SipPlayAction.move,
        seq: 1,
        gameTypeCode: _gameTypeC4,
        gamePayload: _c4MoveBytes(column: 3, disc: C4Disc.red),
      );
      final bytes = SipPlayCodec.encode(env)!;
      expect(bytes.length, equals(7));
    });
  });

  // -------------------------------------------------------------------
  // Connect Four replay tests. The engine's lifecycle (offer / accept
  // / decline / resign / seq enforcement) is shared with TTT via the
  // private `_LifecycleProcessor`; these tests pin the C4-specific
  // behaviour: red/yellow assignment, gravity-driven move handling,
  // four-in-a-row win detection, illegal-column drops.
  // -------------------------------------------------------------------

  group('C4 mark assignment determinism', () {
    test('local offered → localDisc red, remoteDisc yellow', () {
      final state = _replayC4([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.active));
      expect(state.localDisc, equals(C4Disc.red));
      expect(state.remoteDisc, equals(C4Disc.yellow));
      expect(state.turn, equals(C4Disc.red));
      expect(state.isLocalTurn, isTrue);
    });

    test('local accepted → localDisc yellow, remoteDisc red', () {
      final state = _replayC4([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.localDisc, equals(C4Disc.yellow));
      expect(state.remoteDisc, equals(C4Disc.red));
      expect(state.turn, equals(C4Disc.red));
      expect(state.isLocalTurn, isFalse);
    });
  });

  group('C4 move replay', () {
    test('moves apply gravity (column → bottom row)', () {
      final state = _replayC4([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 3, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.lastAppliedSeq, equals(2));
      expect(state.board.cellAt(5, 3), equals(C4Disc.red));
      expect(state.board.cellAt(4, 3), isNull);
      expect(state.turn, equals(C4Disc.yellow));
    });

    test('two moves in same column stack via gravity', () {
      final state = _replayC4([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 0, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 3,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 0, disc: C4Disc.yellow),
          ),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state.board.cellAt(5, 0), equals(C4Disc.red));
      expect(state.board.cellAt(4, 0), equals(C4Disc.yellow));
      expect(state.board.cellAt(3, 0), isNull);
      expect(state.turn, equals(C4Disc.red));
    });

    test('horizontal four-in-a-row at the bottom row → winner', () {
      // Build a full 4-in-a-row across the bottom of column 0..3 with
      // red, alternating yellow drops in column 6 to keep turns valid.
      final state = _replayC4([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
        // R at col 0
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 0, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
        // Y at col 6
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 3,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 6, disc: C4Disc.yellow),
          ),
          SipPlayEntryDirection.inbound,
        ),
        // R at col 1
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 4,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 1, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
        // Y at col 6 again
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 5,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 6, disc: C4Disc.yellow),
          ),
          SipPlayEntryDirection.inbound,
        ),
        // R at col 2
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 6,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 2, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
        // Y at col 6 again
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 7,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 6, disc: C4Disc.yellow),
          ),
          SipPlayEntryDirection.inbound,
        ),
        // R at col 3 — wins horizontally on row 5.
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 8,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 3, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.status, equals(SipPlayInstanceStatus.won));
      expect(state.winner, equals(C4Disc.red));
      expect(state.turn, isNull);
    });

    test('move with wrong disc colour for sender is dropped', () {
      // Local is red. Sending a yellow move from local must drop.
      final state = _replayC4([
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: 2,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 0, disc: C4Disc.yellow),
          ),
          SipPlayEntryDirection.outbound,
        ),
      ]);
      expect(state.lastAppliedSeq, equals(1));
      expect(state.board.moveCount, equals(0));
      expect(state.turn, equals(C4Disc.red));
    });

    test('move into a full column is dropped', () {
      // Stack 6 reds + yellows in column 0, then attempt one more.
      final entries = <SipPlayEntry>[
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.accept,
            seq: 1,
            gameTypeCode: _gameTypeC4,
          ),
          SipPlayEntryDirection.inbound,
        ),
      ];
      var seq = 2;
      // Alternate red/yellow drops into column 0, six total → fills.
      for (var i = 0; i < 6; i += 1) {
        final disc = i.isEven ? C4Disc.red : C4Disc.yellow;
        final dir = i.isEven
            ? SipPlayEntryDirection.outbound
            : SipPlayEntryDirection.inbound;
        entries.add(
          _entry(
            _envelope(
              action: SipPlayAction.move,
              seq: seq,
              gameTypeCode: _gameTypeC4,
              gamePayload: _c4MoveBytes(column: 0, disc: disc),
            ),
            dir,
          ),
        );
        seq += 1;
      }
      // Attempt a 7th drop (red) into column 0 — column is full.
      entries.add(
        _entry(
          _envelope(
            action: SipPlayAction.move,
            seq: seq,
            gameTypeCode: _gameTypeC4,
            gamePayload: _c4MoveBytes(column: 0, disc: C4Disc.red),
          ),
          SipPlayEntryDirection.outbound,
        ),
      );
      final state = _replayC4(entries);
      // The full-column move was dropped — lastAppliedSeq stays at 7
      // (1 accept + 6 successful moves, last one's seq was 7).
      expect(state.lastAppliedSeq, equals(7));
      expect(state.board.cellAt(0, 0), isNotNull);
      expect(state.board.cellAt(0, 1), isNull);
    });
  });

  group('C4 unknown disc → unsupported game-type fallback', () {
    test('engine returns sealed UnsupportedInstanceState for code 0x03', () {
      final state = SipPlayEngine.replay([
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0, gameTypeCode: 0x03),
          SipPlayEntryDirection.inbound,
        ),
      ]);
      expect(state, isA<UnsupportedInstanceState>());
      expect(state.status, equals(SipPlayInstanceStatus.unsupported));
      expect(state.gameTypeCode, equals(0x03));
    });
  });

  // Sticky-terminal invariant: a witnessed decline/resign envelope must
  // make the instance non-blocking even if replay context is missing.
  // Regression for the picker that stuck on "A game offer is already in
  // progress" after the peer declined — see SocialMesh issue where a
  // truncated history (offer entry lost, only decline surviving)
  // replayed back to `pendingOffer` and blocked every future offer.
  group('hasNonTerminalInstanceForGameType — sticky terminal invariant', () {
    test('orphan decline with no offer → does not block', () {
      // Replay context missing: only the decline survives. Without the
      // sticky-terminal override, replay returns pendingOffer and the
      // picker would refuse forever.
      final entries = [
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isFalse,
      );
    });

    test('orphan resign with no offer → does not block', () {
      final entries = [
        _entry(
          _envelope(action: SipPlayAction.resign, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isFalse,
      );
    });

    test('offer alone → blocks', () {
      final entries = [
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isTrue,
      );
    });

    test('offer + decline → does not block', () {
      final entries = [
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1),
          SipPlayEntryDirection.outbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isFalse,
      );
    });

    test('offer + accept + resign → does not block', () {
      final entries = [
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.resign, seq: 2),
          SipPlayEntryDirection.outbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isFalse,
      );
    });

    test('offer + decline truncated to decline only → does not block '
        '(captured-log regression: entries=1 lastAppliedSeq=-1 '
        'status=pendingOffer)', () {
      // Reproduces the exact log signature: history list lost the
      // offer between epoch 9 and epoch 10, leaving only the decline.
      // Replay alone would put this back at pendingOffer; the
      // sticky-terminal override saves the user.
      final fullLog = [
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.inbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1),
          SipPlayEntryDirection.outbound,
        ),
      ];
      final truncated = fullLog.sublist(1);
      // Pin the underlying replay regression: with the offer gone,
      // replay regresses to pendingOffer / -1 — the exact signature
      // from the captured log. We assert it here so a future replay
      // refactor can't silently mask the upstream issue.
      final replayed = SipPlayEngine.replay(truncated);
      expect(replayed.status, equals(SipPlayInstanceStatus.pendingOffer));
      expect(replayed.lastAppliedSeq, equals(-1));
      // Sticky-terminal override returns false despite replay regression.
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: truncated,
          gameTypeCode: _gameTypeTtt,
        ),
        isFalse,
      );
    });

    test('outbound offer + inbound decline scenario → fresh offer allowed', () {
      // Mirror of the user's reported flow: I sent an offer, the
      // peer declined. The picker must let me send another offer
      // for the same game type without "A game offer is already in
      // progress."
      final entries = [
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1),
          SipPlayEntryDirection.inbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isFalse,
      );
    });

    test('multi-instance: one declined + one pending → still blocks '
        '(only genuinely non-terminal offers gate the duplicate guard)', () {
      final entries = [
        // Instance A: declined, terminal.
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0, instanceId: 0xAAAA),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1, instanceId: 0xAAAA),
          SipPlayEntryDirection.inbound,
        ),
        // Instance B: pending, non-terminal.
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0, instanceId: 0xBBBB),
          SipPlayEntryDirection.outbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isTrue,
      );
    });

    test('multi-instance: one active + one declined → still blocks '
        '(active game on same gameType gates fresh offer)', () {
      final entries = [
        // Instance A: declined, terminal.
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0, instanceId: 0xAAAA),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.decline, seq: 1, instanceId: 0xAAAA),
          SipPlayEntryDirection.inbound,
        ),
        // Instance B: active.
        _entry(
          _envelope(action: SipPlayAction.offer, seq: 0, instanceId: 0xBBBB),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(action: SipPlayAction.accept, seq: 1, instanceId: 0xBBBB),
          SipPlayEntryDirection.inbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeTtt,
        ),
        isTrue,
      );
    });

    test('different gameType → not affected by other-game terminal state', () {
      // Declined TTT instance must not unblock or affect a C4 query.
      final entries = [
        _entry(
          _envelope(
            action: SipPlayAction.offer,
            seq: 0,
            gameTypeCode: _gameTypeTtt,
          ),
          SipPlayEntryDirection.outbound,
        ),
        _entry(
          _envelope(
            action: SipPlayAction.decline,
            seq: 1,
            gameTypeCode: _gameTypeTtt,
          ),
          SipPlayEntryDirection.inbound,
        ),
      ];
      expect(
        SipPlayEngine.hasNonTerminalInstanceForGameType(
          entries: entries,
          gameTypeCode: _gameTypeC4,
        ),
        isFalse,
      );
    });
  });
}
