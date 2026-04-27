// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../../core/logging.dart';
import 'games/tictactoe/ttt_codec.dart';
import 'games/tictactoe/ttt_payload.dart';
import 'games/tictactoe/ttt_rules.dart';
import 'sip_play_codec.dart';
import 'sip_play_constants.dart';
import 'sip_play_payload.dart';
import 'sip_play_registry.dart';

/// Direction of the entry as the engine sees it. The engine doesn't
/// know about the SIP DM session model directly — callers tag every
/// envelope they hand in with the local-side perspective so mark
/// assignment + "is it my turn?" work without further context.
enum SipPlayEntryDirection {
  /// The local user produced this envelope (outbound on the wire).
  outbound,

  /// The remote peer produced this envelope (inbound from the wire).
  inbound,
}

/// One historical SIP Play entry. The engine only needs the bytes
/// (decoded into a [SipPlayEnvelope]) and the direction; it does NOT
/// take any timestamps or external metadata so replay is byte-pure.
class SipPlayEntry {
  final SipPlayEnvelope envelope;
  final SipPlayEntryDirection direction;

  const SipPlayEntry({required this.envelope, required this.direction});
}

/// Lifecycle status of a single game instance.
enum SipPlayInstanceStatus {
  /// `offer` seen, waiting for `accept` / `decline`.
  pendingOffer,

  /// Both sides have committed; moves are flowing.
  active,

  /// Local side declined a pending offer (terminal).
  declinedByLocal,

  /// Remote side declined our offer (terminal).
  declinedByRemote,

  /// Local side resigned (terminal).
  resignedByLocal,

  /// Remote side resigned (terminal).
  resignedByRemote,

  /// Game ended with a winner (board completion or three-in-a-row).
  won,

  /// Game ended in a draw (board full, no winner).
  draw,

  /// Receiver doesn't recognise this gameType — terminal, no further
  /// state changes applied. Renderer shows the safe fallback UX.
  unsupported,
}

/// Derived per-instance state. Built by [SipPlayEngine.replay] from
/// the entry log; mutated nowhere else.
class SipPlayInstanceState {
  /// Wire game-type byte. Held as raw int so unsupported codes can
  /// still be represented.
  final int gameTypeCode;

  /// Per-(sessionTag, peer pair) instance id from the offer envelope.
  final int instanceId;

  /// Lifecycle status.
  final SipPlayInstanceStatus status;

  /// Local mark (X = offerer, O = acceptor). Null until both ends
  /// have committed (i.e. status >= active or terminal-after-active).
  final TttMark? localMark;

  /// Remote mark. Null in the same conditions as [localMark].
  final TttMark? remoteMark;

  /// Current TTT board. Only meaningful for the TTT renderer; other
  /// games would hold their own state. Held here for v1 simplicity —
  /// future games will refactor this onto a per-game state object.
  final TttBoard board;

  /// Whose turn it is when status is `active`. Null otherwise.
  final TttMark? turn;

  /// Highest seq applied. Receivers enforce
  /// `incoming.seq == lastAppliedSeq + 1` strictly.
  final int lastAppliedSeq;

  /// Winner mark when status is `won`. Null otherwise.
  final TttMark? winner;

  const SipPlayInstanceState({
    required this.gameTypeCode,
    required this.instanceId,
    required this.status,
    required this.localMark,
    required this.remoteMark,
    required this.board,
    required this.turn,
    required this.lastAppliedSeq,
    required this.winner,
  });

  /// Convenience: is the local user the side whose turn it is?
  bool get isLocalTurn =>
      status == SipPlayInstanceStatus.active &&
      turn != null &&
      localMark != null &&
      turn == localMark;

  /// Convenience: terminal states allow no further moves.
  bool get isTerminal => switch (status) {
    SipPlayInstanceStatus.pendingOffer || SipPlayInstanceStatus.active => false,
    _ => true,
  };
}

/// Pure-replay SIP Play engine.
///
/// Hard invariants (locked by the user before implementation):
///   - State is ALWAYS derived from the entry log — no hidden flags,
///     no timers, no side-channel mutation. Re-running [replay] over
///     the same log produces an identical [SipPlayInstanceState].
///   - Strict seq enforcement: an inbound `move` envelope must have
///     `seq == lastAppliedSeq + 1`. Anything else (mismatch, duplicate,
///     out-of-order) is dropped + logged with no state change.
///   - No `sync` action support in v1. Receivers drop the slot
///     silently. The enum value exists so future versions can
///     introduce it without re-numbering the wire.
///   - Unknown gameType codes terminate the instance as
///     [SipPlayInstanceStatus.unsupported] on first envelope; no
///     further envelopes mutate it.
///   - Mid-game block: the engine does NOT auto-resign or mutate
///     state when T+S blocks a peer; the higher layers (router,
///     SipDmManager.handleInboundPlay) are responsible for stopping
///     envelopes from reaching the engine in that case. The UI
///     freezes (no outbound moves possible) but the entry log stays
///     intact.
class SipPlayEngine {
  /// Replay an entry log into the final state for one instance.
  ///
  /// `entries` is the time-ordered list of SIP Play entries belonging
  /// to ONE `(sessionTag, instanceId)` pair. Caller filters; the
  /// engine assumes single-instance input.
  static SipPlayInstanceState replay(List<SipPlayEntry> entries) {
    if (entries.isEmpty) {
      // Pre-offer placeholder. Callers shouldn't normally hit this —
      // they hold an instance only after the offer envelope has been
      // appended — but the engine has to return something safe.
      return _emptyState(0, 0);
    }

    // Lock the instanceId + gameTypeCode from the first envelope so
    // mid-stream "drift" (a malformed sender flipping the gameType on
    // a later envelope) cannot corrupt the derived state. The engine
    // simply ignores envelopes with mismatched ids.
    final first = entries.first.envelope;
    final instanceId = first.instanceId;
    final gameTypeCode = first.gameTypeCode;

    // Unknown gameType is a hard terminal — receivers do not interact
    // beyond rendering the unsupported fallback.
    if (!SipPlayRegistry.isSupported(gameTypeCode)) {
      AppLogging.sipPlay(
        'replay_terminal_unsupported_game_type '
        'instance=0x${instanceId.toRadixString(16)} '
        'gameType=0x${gameTypeCode.toRadixString(16)}',
      );
      return SipPlayInstanceState(
        gameTypeCode: gameTypeCode,
        instanceId: instanceId,
        status: SipPlayInstanceStatus.unsupported,
        localMark: null,
        remoteMark: null,
        board: TttBoard.empty(),
        turn: null,
        lastAppliedSeq: -1,
        winner: null,
      );
    }

    var status = SipPlayInstanceStatus.pendingOffer;
    TttMark? localMark;
    TttMark? remoteMark;
    var board = TttBoard.empty();
    TttMark? turn;
    var lastAppliedSeq = -1;
    TttMark? winner;
    SipPlayEntryDirection? offerDirection;

    for (var i = 0; i < entries.length; i += 1) {
      final entry = entries[i];
      final env = entry.envelope;

      // Ignore envelopes that do not match the locked instance id
      // (defence-in-depth — caller should have filtered already).
      if (env.instanceId != instanceId) continue;
      if (env.gameTypeCode != gameTypeCode) continue;

      // Reserved-in-v1 sync action: drop without state change. See
      // SipPlayConstants enum dartdoc.
      if (env.action == SipPlayAction.sync) {
        AppLogging.sipPlay(
          'replay_drop reason=sync_reserved_in_v1 '
          'instance=0x${instanceId.toRadixString(16)} '
          'seq=${env.seq}',
        );
        continue;
      }

      switch (env.action) {
        case SipPlayAction.offer:
          if (i != 0) {
            // Only the first envelope in a log can be an offer; a
            // later "offer" envelope is corrupt input.
            AppLogging.sipPlay(
              'replay_drop reason=duplicate_offer '
              'instance=0x${instanceId.toRadixString(16)} seq=${env.seq}',
            );
            continue;
          }
          if (env.seq != 0) {
            AppLogging.sipPlay(
              'replay_drop reason=offer_seq_nonzero '
              'instance=0x${instanceId.toRadixString(16)} seq=${env.seq}',
            );
            continue;
          }
          offerDirection = entry.direction;
          // Mark assignment is locked at accept time. Until then we
          // only know the candidate offerer's perspective.
          lastAppliedSeq = 0;

        case SipPlayAction.accept:
          if (status != SipPlayInstanceStatus.pendingOffer) {
            AppLogging.sipPlay(
              'replay_drop reason=accept_in_wrong_status status=${status.name} '
              'seq=${env.seq}',
            );
            continue;
          }
          if (offerDirection == null) {
            AppLogging.sipPlay(
              'replay_drop reason=accept_without_offer seq=${env.seq}',
            );
            continue;
          }
          if (entry.direction == offerDirection) {
            // Local can't accept its own offer — that would be a
            // corrupt log. Drop.
            AppLogging.sipPlay(
              'replay_drop reason=accept_from_offerer seq=${env.seq}',
            );
            continue;
          }
          if (env.seq != lastAppliedSeq + 1) {
            AppLogging.sipPlay(
              'replay_drop reason=accept_seq_mismatch '
              'expected=${lastAppliedSeq + 1} got=${env.seq}',
            );
            continue;
          }
          // Lock marks: offerer plays X (and moves first); acceptor
          // plays O. Both sides reach this conclusion identically
          // from the entry log — the engine just stamps it onto the
          // local-side perspective.
          if (offerDirection == SipPlayEntryDirection.outbound) {
            localMark = TttMark.x;
            remoteMark = TttMark.o;
          } else {
            localMark = TttMark.o;
            remoteMark = TttMark.x;
          }
          status = SipPlayInstanceStatus.active;
          turn = TttMark.x;
          lastAppliedSeq = env.seq;

        case SipPlayAction.decline:
          if (status != SipPlayInstanceStatus.pendingOffer) {
            AppLogging.sipPlay(
              'replay_drop reason=decline_in_wrong_status '
              'status=${status.name} seq=${env.seq}',
            );
            continue;
          }
          if (offerDirection == null) continue;
          if (entry.direction == offerDirection) {
            AppLogging.sipPlay(
              'replay_drop reason=decline_from_offerer seq=${env.seq}',
            );
            continue;
          }
          if (env.seq != lastAppliedSeq + 1) {
            AppLogging.sipPlay(
              'replay_drop reason=decline_seq_mismatch '
              'expected=${lastAppliedSeq + 1} got=${env.seq}',
            );
            continue;
          }
          status = entry.direction == SipPlayEntryDirection.outbound
              ? SipPlayInstanceStatus.declinedByLocal
              : SipPlayInstanceStatus.declinedByRemote;
          lastAppliedSeq = env.seq;

        case SipPlayAction.move:
          if (status != SipPlayInstanceStatus.active) {
            AppLogging.sipPlay(
              'replay_drop reason=move_in_wrong_status status=${status.name} '
              'seq=${env.seq}',
            );
            continue;
          }
          if (env.seq <= lastAppliedSeq) {
            AppLogging.sipPlay(
              'replay_drop reason=duplicate_or_replay '
              'last=$lastAppliedSeq got=${env.seq}',
            );
            continue;
          }
          if (env.seq != lastAppliedSeq + 1) {
            AppLogging.sipPlay(
              'replay_drop reason=move_seq_mismatch '
              'expected=${lastAppliedSeq + 1} got=${env.seq}',
            );
            continue;
          }
          final move = TttCodec.decodeMove(env.gamePayload);
          if (move == null) {
            AppLogging.sipPlay(
              'replay_drop reason=ttt_payload_malformed seq=${env.seq}',
            );
            continue;
          }
          // Sender's mark must equal the deterministic mark for the
          // direction. Catches a malicious or buggy peer claiming
          // the wrong mark.
          final expectedMarkForSender =
              entry.direction == SipPlayEntryDirection.outbound
              ? localMark
              : remoteMark;
          if (move.mark != expectedMarkForSender) {
            AppLogging.sipPlay(
              'replay_drop reason=mark_mismatch '
              'expected=${expectedMarkForSender?.name} got=${move.mark.name}',
            );
            continue;
          }
          // Must be sender's turn AND the cell must be empty.
          if (move.mark != turn) {
            AppLogging.sipPlay(
              'replay_drop reason=not_senders_turn turn=${turn?.name} '
              'mark=${move.mark.name} seq=${env.seq}',
            );
            continue;
          }
          if (!board.isLegalMove(move.cell)) {
            AppLogging.sipPlay(
              'replay_drop reason=cell_occupied cell=${move.cell} '
              'seq=${env.seq}',
            );
            continue;
          }
          board = board.apply(move.cell, move.mark);
          lastAppliedSeq = env.seq;
          // Recompute status post-move.
          final w = board.winner;
          if (w != null) {
            status = SipPlayInstanceStatus.won;
            winner = w;
            turn = null;
          } else if (board.isDraw) {
            status = SipPlayInstanceStatus.draw;
            turn = null;
          } else {
            turn = move.mark.opponent;
          }

        case SipPlayAction.resign:
          if (status != SipPlayInstanceStatus.active) {
            AppLogging.sipPlay(
              'replay_drop reason=resign_in_wrong_status '
              'status=${status.name} seq=${env.seq}',
            );
            continue;
          }
          if (env.seq != lastAppliedSeq + 1) {
            AppLogging.sipPlay(
              'replay_drop reason=resign_seq_mismatch '
              'expected=${lastAppliedSeq + 1} got=${env.seq}',
            );
            continue;
          }
          status = entry.direction == SipPlayEntryDirection.outbound
              ? SipPlayInstanceStatus.resignedByLocal
              : SipPlayInstanceStatus.resignedByRemote;
          lastAppliedSeq = env.seq;
          turn = null;

        case SipPlayAction.sync:
          // Already handled above (reserved-in-v1 drop).
          break;
      }
    }

    return SipPlayInstanceState(
      gameTypeCode: gameTypeCode,
      instanceId: instanceId,
      status: status,
      localMark: localMark,
      remoteMark: remoteMark,
      board: board,
      turn: turn,
      lastAppliedSeq: lastAppliedSeq,
      winner: winner,
    );
  }

  static SipPlayInstanceState _emptyState(int gameTypeCode, int instanceId) {
    return SipPlayInstanceState(
      gameTypeCode: gameTypeCode,
      instanceId: instanceId,
      status: SipPlayInstanceStatus.pendingOffer,
      localMark: null,
      remoteMark: null,
      board: TttBoard.empty(),
      turn: null,
      lastAppliedSeq: -1,
      winner: null,
    );
  }

  /// Group raw SIP Play envelopes by `instanceId`, preserving the
  /// log order within each group. UI providers use this to derive
  /// per-instance views from one session's full play-entry stream.
  ///
  /// Pure helper — no I/O, no clock.
  static Map<int, List<SipPlayEntry>> groupByInstance(
    List<SipPlayEntry> entries,
  ) {
    final out = <int, List<SipPlayEntry>>{};
    for (final entry in entries) {
      out
          .putIfAbsent(entry.envelope.instanceId, () => <SipPlayEntry>[])
          .add(entry);
    }
    return out;
  }

  /// Decode raw SIP DM history payload bytes into a [SipPlayEntry],
  /// or return null on malformation. Convenience wrapper around
  /// [SipPlayCodec.decode] used by UI providers replaying entries
  /// pulled from `SipDmHistoryEntry.payload`.
  static SipPlayEntry? decodeEntry({
    required Uint8List payload,
    required SipPlayEntryDirection direction,
  }) {
    final result = SipPlayCodec.decode(payload);
    if (!result.isOk) {
      AppLogging.sipPlay(
        'engine_decode_drop reason=${result.error?.name} '
        'bytes=${payload.length}',
      );
      return null;
    }
    return SipPlayEntry(envelope: result.envelope!, direction: direction);
  }
}
