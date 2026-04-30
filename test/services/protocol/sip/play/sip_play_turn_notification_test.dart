// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the `onPlayMoveYourTurn` hook on [SipDmManager]:
///
/// Field-test request — when an inbound SIP Play move arrives and the
/// per-instance replay shows the local side is now the active player,
/// the manager must fire `onPlayMoveYourTurn(peerNodeId, sessionTag,
/// gameTypeCode, instanceId)` exactly once. The provider layer wires
/// this to a local notification so a backgrounded user gets pinged
/// for their turn.
///
/// Negatives covered: offer / accept / decline / resign actions do
/// NOT fire the hook (offerer is already engaged, terminal actions
/// have no follow-up turn).
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_constants.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_payload.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

const int _kSessionTag = 0xAA;
const int _kPeerNodeId = 0xBEEF;
const int _kInstanceId = 0xAB;

SipDmManager _newDm() {
  return SipDmManager(rateLimiter: SipRateLimiter(), clock: () => 1000000);
}

Uint8List _envelopeBytes({
  required SipPlayAction action,
  required int seq,
  Uint8List? gamePayload,
}) {
  return SipPlayCodec.encode(
    SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: SipPlayGameType.ticTacToe.code,
      instanceId: _kInstanceId,
      action: action,
      seq: seq,
      gamePayload: gamePayload ?? Uint8List(0),
    ),
  )!;
}

Uint8List _moveBytes({required int cell, required TttMark mark}) {
  return TttCodec.encodeMove(TttMove(cell: cell, mark: mark))!;
}

SipFrame _frame({required int nonce, required Uint8List payload}) {
  return SipFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: SipMessageType.dmPlay,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: _kSessionTag,
    nonce: nonce,
    timestampS: 1234567890,
    payloadLen: payload.length,
    payload: payload,
  );
}

void main() {
  group('SipDmManager.onPlayMoveYourTurn — fast-path field-test request', () {
    test('fires once when an inbound move flips turn back to the local '
        'side (offerer = X, opponent O moves first after our X)', () {
      final dm = _newDm();
      dm.createSession(sessionTag: _kSessionTag, peerNodeId: _kPeerNodeId);

      final fired = <(int, int, int, int)>[];
      dm.onPlayMoveYourTurn = (peer, tag, game, instance) {
        fired.add((peer, tag, game, instance));
      };

      // 1. Local offers (outbound seq=0). Bytes pre-built and
      //    routed through `buildPlayMessage` so the entry lands in
      //    the session history with `outbound` direction — the
      //    offerer becomes X by the engine's mark assignment rule.
      final offerResult = dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(action: SipPlayAction.offer, seq: 0),
      );
      expect(offerResult.isOk, isTrue);

      // 2. Remote accepts (inbound seq=1). Local turn = X (local
      //    plays first). No callback fired yet — accept is not a
      //    `move`.
      dm.handleInboundPlay(
        _frame(
          nonce: 1,
          payload: _envelopeBytes(action: SipPlayAction.accept, seq: 1),
        ),
      );
      expect(fired, isEmpty, reason: 'accept must not fire turn hook');

      // 3. Local moves cell 4 (X, seq=2). Turn flips to remote.
      final move1 = dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(
          action: SipPlayAction.move,
          seq: 2,
          gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
        ),
      );
      expect(move1.isOk, isTrue);
      expect(
        fired,
        isEmpty,
        reason:
            'outbound move must not fire turn hook (it flips turn '
            'AWAY from us, not toward us)',
      );

      // 4. Remote moves cell 0 (O, seq=3). Turn flips back to
      //    local — hook MUST fire exactly once with the right args.
      dm.handleInboundPlay(
        _frame(
          nonce: 2,
          payload: _envelopeBytes(
            action: SipPlayAction.move,
            seq: 3,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.o),
          ),
        ),
      );
      expect(
        fired,
        hasLength(1),
        reason: 'inbound move flipping turn to local must fire hook',
      );
      expect(fired.single.$1, equals(_kPeerNodeId));
      expect(fired.single.$2, equals(_kSessionTag));
      expect(fired.single.$3, equals(SipPlayGameType.ticTacToe.code));
      expect(fired.single.$4, equals(_kInstanceId));
    });

    test('does NOT fire on inbound offer / accept / decline / resign — '
        'only on inbound `move` actions', () {
      final dm = _newDm();
      dm.createSession(sessionTag: _kSessionTag, peerNodeId: _kPeerNodeId);

      var fireCount = 0;
      dm.onPlayMoveYourTurn = (_, _, _, _) => fireCount++;

      // Inbound offer (remote initiator). Local would be O, X
      // (remote) plays first → local turn is FALSE here regardless,
      // but more importantly the hook must NOT fire on offer.
      dm.handleInboundPlay(
        _frame(
          nonce: 10,
          payload: _envelopeBytes(action: SipPlayAction.offer, seq: 0),
        ),
      );
      expect(fireCount, equals(0), reason: 'inbound offer path');

      // Local accepts (outbound seq=1) so the game is active. The
      // accept goes through buildPlayMessage so the entry lands
      // outbound.
      final acceptResult = dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(action: SipPlayAction.accept, seq: 1),
      );
      expect(acceptResult.isOk, isTrue);

      // Inbound resign — terminal action, must not fire hook.
      dm.handleInboundPlay(
        _frame(
          nonce: 11,
          payload: _envelopeBytes(action: SipPlayAction.resign, seq: 2),
        ),
      );
      expect(fireCount, equals(0), reason: 'inbound resign path');
    });

    test('inbound move that does NOT flip turn to local does not fire '
        '— defence against false positives if engine decoded as drop', () {
      final dm = _newDm();
      dm.createSession(sessionTag: _kSessionTag, peerNodeId: _kPeerNodeId);

      var fireCount = 0;
      dm.onPlayMoveYourTurn = (_, _, _, _) => fireCount++;

      // Set up so it's REMOTE's turn (local just moved).
      dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(action: SipPlayAction.offer, seq: 0),
      );
      dm.handleInboundPlay(
        _frame(
          nonce: 1,
          payload: _envelopeBytes(action: SipPlayAction.accept, seq: 1),
        ),
      );
      // Local plays cell 4 — turn now remote.
      dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(
          action: SipPlayAction.move,
          seq: 2,
          gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
        ),
      );

      // Send an out-of-order inbound move (seq=5, skipping 3+4).
      // Engine drops it for strict-seq violation; turn stays
      // remote. Hook must NOT fire.
      dm.handleInboundPlay(
        _frame(
          nonce: 99,
          payload: _envelopeBytes(
            action: SipPlayAction.move,
            seq: 5,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.o),
          ),
        ),
      );
      expect(
        fireCount,
        equals(0),
        reason:
            'engine-dropped out-of-order move must not flip turn '
            'state, so hook must not fire',
      );
    });

    test('hook exception is swallowed and does not break the manager', () {
      final dm = _newDm();
      dm.createSession(sessionTag: _kSessionTag, peerNodeId: _kPeerNodeId);

      dm.onPlayMoveYourTurn = (_, _, _, _) =>
          throw StateError('fake notification crash');

      // Drive a full mini-game.
      dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(action: SipPlayAction.offer, seq: 0),
      );
      dm.handleInboundPlay(
        _frame(
          nonce: 1,
          payload: _envelopeBytes(action: SipPlayAction.accept, seq: 1),
        ),
      );
      dm.buildPlayMessage(
        sessionTag: _kSessionTag,
        playPayload: _envelopeBytes(
          action: SipPlayAction.move,
          seq: 2,
          gamePayload: _moveBytes(cell: 4, mark: TttMark.x),
        ),
      );

      // Inbound move that flips turn — the throwing hook is invoked
      // but the manager's path must complete without propagating.
      final result = dm.handleInboundPlay(
        _frame(
          nonce: 2,
          payload: _envelopeBytes(
            action: SipPlayAction.move,
            seq: 3,
            gamePayload: _moveBytes(cell: 0, mark: TttMark.o),
          ),
        ),
      );
      expect(
        result,
        isNotNull,
        reason: 'manager must still return the parsed envelope',
      );
      expect(
        dm.getHistory(_kSessionTag),
        hasLength(4),
        reason:
            'history append happens before the hook fires, so the '
            'thrown exception cannot rip out the inbound state',
      );
    });
  });
}
