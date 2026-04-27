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
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_constants.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_engine.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_payload.dart';

const int _instanceId = 0xBEEF;
const int _gameTypeTtt = 0x01;

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

void main() {
  group('Mark assignment determinism', () {
    test('local offered → localMark X, remoteMark O', () {
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final s1 = SipPlayEngine.replay(log);
      final s2 = SipPlayEngine.replay(log);

      expect(s1.status, equals(s2.status));
      expect(s1.lastAppliedSeq, equals(s2.lastAppliedSeq));
      expect(s1.board.cells, equals(s2.board.cells));
      expect(s1.turn, equals(s2.turn));
    });
  });

  group('Strict-seq enforcement', () {
    test('move with seq != lastApplied + 1 is dropped', () {
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      final state = SipPlayEngine.replay([
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
      expect(state.status, equals(SipPlayInstanceStatus.unsupported));
      expect(state.gameTypeCode, equals(0xFE));
      expect(state.board.moveCount, equals(0));
    });

    test('mid-stream gameType drift on a valid game is ignored', () {
      // First envelope is TTT; later envelope claims a different
      // gameType. Engine ignores the drifting envelope.
      final state = SipPlayEngine.replay([
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
  });
}
