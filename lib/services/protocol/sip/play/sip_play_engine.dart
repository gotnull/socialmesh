// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../../../core/logging.dart';
import 'games/connectfour/c4_codec.dart';
import 'games/connectfour/c4_payload.dart';
import 'games/connectfour/c4_rules.dart';
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
///
/// Sealed hierarchy: every concrete instance is one of the per-game
/// subclasses ([TttInstanceState], future C4InstanceState, ...) or
/// the catch-all [UnsupportedInstanceState] for unknown game-type
/// codes. Consumers use Dart 3 sealed-switch to destructure on the
/// runtime type — the compiler enforces exhaustiveness so adding a
/// new game can't silently miss a render path.
sealed class SipPlayInstanceState {
  /// Wire game-type byte. Held as raw int so unsupported codes can
  /// still be represented.
  final int gameTypeCode;

  /// Per-(sessionTag, peer pair) instance id from the offer envelope.
  final int instanceId;

  /// Lifecycle status.
  final SipPlayInstanceStatus status;

  /// Highest seq applied. Receivers enforce
  /// `incoming.seq == lastAppliedSeq + 1` strictly.
  final int lastAppliedSeq;

  const SipPlayInstanceState({
    required this.gameTypeCode,
    required this.instanceId,
    required this.status,
    required this.lastAppliedSeq,
  });

  /// Convenience: is the local user the side whose turn it is?
  /// Game-specific — each subclass compares its own turn-marker
  /// against its own localMark/localDisc/etc.
  bool get isLocalTurn;

  /// Convenience: terminal states allow no further moves. Pure
  /// function of [status], so shared on the base.
  bool get isTerminal => switch (status) {
    SipPlayInstanceStatus.pendingOffer || SipPlayInstanceStatus.active => false,
    _ => true,
  };
}

/// Per-instance state for a Tic-Tac-Toe game. Carries the 9-cell
/// board and the X/O role markers; [SipPlayEngine.replay] constructs
/// this whenever the locked `gameTypeCode` resolves to TTT.
class TttInstanceState extends SipPlayInstanceState {
  /// Local mark (X = offerer, O = acceptor). Null until both ends
  /// have committed (i.e. status >= active or terminal-after-active).
  final TttMark? localMark;

  /// Remote mark. Null in the same conditions as [localMark].
  final TttMark? remoteMark;

  /// Current TTT board.
  final TttBoard board;

  /// Whose turn it is when status is `active`. Null otherwise.
  final TttMark? turn;

  /// Winner mark when status is `won`. Null otherwise.
  final TttMark? winner;

  const TttInstanceState({
    required super.gameTypeCode,
    required super.instanceId,
    required super.status,
    required super.lastAppliedSeq,
    required this.localMark,
    required this.remoteMark,
    required this.board,
    required this.turn,
    required this.winner,
  });

  @override
  bool get isLocalTurn =>
      status == SipPlayInstanceStatus.active &&
      turn != null &&
      localMark != null &&
      turn == localMark;
}

/// Per-instance state for a Connect Four game. Carries the 6×7 board
/// and the red/yellow role markers; [SipPlayEngine.replay] constructs
/// this whenever the locked `gameTypeCode` resolves to C4.
///
/// Note: `localDisc` / `remoteDisc` are wire-side names; the UI
/// rendering layer treats them as opaque "local-side" / "peer-side"
/// markers and chooses themed colours rather than hard-coded
/// red/yellow. See `c4_payload.dart` for the convention.
class C4InstanceState extends SipPlayInstanceState {
  /// Local disc colour. Null until both ends have committed.
  final C4Disc? localDisc;

  /// Remote disc colour. Null in the same conditions as [localDisc].
  final C4Disc? remoteDisc;

  /// Current C4 board.
  final C4Board board;

  /// Whose turn it is when status is `active`. Null otherwise.
  final C4Disc? turn;

  /// Winner disc when status is `won`. Null otherwise.
  final C4Disc? winner;

  const C4InstanceState({
    required super.gameTypeCode,
    required super.instanceId,
    required super.status,
    required super.lastAppliedSeq,
    required this.localDisc,
    required this.remoteDisc,
    required this.board,
    required this.turn,
    required this.winner,
  });

  @override
  bool get isLocalTurn =>
      status == SipPlayInstanceStatus.active &&
      turn != null &&
      localDisc != null &&
      turn == localDisc;
}

/// Per-instance state when the receiver doesn't recognise the
/// `gameTypeCode`. The status is locked to
/// [SipPlayInstanceStatus.unsupported]; no game-specific board is
/// carried because we have no rules to apply. Renderers show the
/// safe fallback UX.
class UnsupportedInstanceState extends SipPlayInstanceState {
  const UnsupportedInstanceState({
    required super.gameTypeCode,
    required super.instanceId,
    required super.lastAppliedSeq,
  }) : super(status: SipPlayInstanceStatus.unsupported);

  @override
  bool get isLocalTurn => false;
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
  ///
  /// Dispatches by the locked `gameTypeCode` to the per-game replay
  /// implementation. The lifecycle (offer / accept / decline /
  /// resign) is shared across games via [_LifecycleProcessor]; only
  /// the `move` branch and the role-marker assignment differ per
  /// game.
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
      return UnsupportedInstanceState(
        gameTypeCode: gameTypeCode,
        instanceId: instanceId,
        lastAppliedSeq: -1,
      );
    }

    final type = SipPlayGameType.fromCode(gameTypeCode);
    switch (type) {
      case SipPlayGameType.ticTacToe:
        return _replayTtt(entries, instanceId, gameTypeCode);
      case SipPlayGameType.connectFour:
        return _replayC4(entries, instanceId, gameTypeCode);
      case null:
        // isSupported guard above already rejects unknown codes; this
        // arm is unreachable at runtime but keeps the switch
        // exhaustive (Dart 3 doesn't infer nullable through registry
        // lookup + null-coalescing-style guards).
        return UnsupportedInstanceState(
          gameTypeCode: gameTypeCode,
          instanceId: instanceId,
          lastAppliedSeq: -1,
        );
    }
  }

  /// Per-game replay for Tic-Tac-Toe. Walks the entry log, defers
  /// every non-move action to the shared [_LifecycleProcessor], and
  /// owns the TTT-specific move handling + role assignment.
  static TttInstanceState _replayTtt(
    List<SipPlayEntry> entries,
    int instanceId,
    int gameTypeCode,
  ) {
    final lc = _LifecycleProcessor(instanceId: instanceId);
    TttMark? localMark;
    TttMark? remoteMark;
    var board = TttBoard.empty();
    TttMark? turn;
    TttMark? winner;

    for (var i = 0; i < entries.length; i += 1) {
      final entry = entries[i];
      final env = entry.envelope;
      if (env.instanceId != instanceId) continue;
      if (env.gameTypeCode != gameTypeCode) continue;

      final outcome = lc.process(entry: entry, entryIndex: i);
      if (outcome == _LifecycleOutcome.dropped) continue;
      if (outcome == _LifecycleOutcome.consumed) {
        if (lc.justAccepted) {
          // Lock marks: offerer plays X (and moves first); acceptor
          // plays O. Both sides reach this conclusion identically
          // from the entry log.
          if (lc.offerDirection == SipPlayEntryDirection.outbound) {
            localMark = TttMark.x;
            remoteMark = TttMark.o;
          } else {
            localMark = TttMark.o;
            remoteMark = TttMark.x;
          }
          turn = TttMark.x;
        }
        if (lc.status == SipPlayInstanceStatus.resignedByLocal ||
            lc.status == SipPlayInstanceStatus.resignedByRemote) {
          turn = null;
        }
        continue;
      }
      // outcome == delegate → caller handles move action.

      // Move-specific seq + status guards (same shape as lifecycle but
      // here we own the post-move winner/draw state machine).
      if (lc.status != SipPlayInstanceStatus.active) {
        AppLogging.sipPlay(
          'replay_drop reason=move_in_wrong_status status=${lc.status.name} '
          'seq=${env.seq}',
        );
        continue;
      }
      if (env.seq <= lc.lastAppliedSeq) {
        AppLogging.sipPlay(
          'replay_drop reason=duplicate_or_replay '
          'last=${lc.lastAppliedSeq} got=${env.seq}',
        );
        continue;
      }
      if (env.seq != lc.lastAppliedSeq + 1) {
        AppLogging.sipPlay(
          'replay_drop reason=move_seq_mismatch '
          'expected=${lc.lastAppliedSeq + 1} got=${env.seq}',
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
      // direction. Catches a malicious or buggy peer claiming the
      // wrong mark.
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
      lc.lastAppliedSeq = env.seq;
      final w = board.winner;
      if (w != null) {
        lc.status = SipPlayInstanceStatus.won;
        winner = w;
        turn = null;
      } else if (board.isDraw) {
        lc.status = SipPlayInstanceStatus.draw;
        turn = null;
      } else {
        turn = move.mark.opponent;
      }
    }

    return TttInstanceState(
      gameTypeCode: gameTypeCode,
      instanceId: instanceId,
      status: lc.status,
      localMark: localMark,
      remoteMark: remoteMark,
      board: board,
      turn: turn,
      lastAppliedSeq: lc.lastAppliedSeq,
      winner: winner,
    );
  }

  /// Per-game replay for Connect Four. Mirrors [_replayTtt] step for
  /// step but with C4 types (column → row via gravity, 4-in-a-row win
  /// detection). The lifecycle is identical to TTT and lives in the
  /// shared [_LifecycleProcessor].
  static C4InstanceState _replayC4(
    List<SipPlayEntry> entries,
    int instanceId,
    int gameTypeCode,
  ) {
    final lc = _LifecycleProcessor(instanceId: instanceId);
    C4Disc? localDisc;
    C4Disc? remoteDisc;
    var board = C4Board.empty();
    C4Disc? turn;
    C4Disc? winner;

    for (var i = 0; i < entries.length; i += 1) {
      final entry = entries[i];
      final env = entry.envelope;
      if (env.instanceId != instanceId) continue;
      if (env.gameTypeCode != gameTypeCode) continue;

      final outcome = lc.process(entry: entry, entryIndex: i);
      if (outcome == _LifecycleOutcome.dropped) continue;
      if (outcome == _LifecycleOutcome.consumed) {
        if (lc.justAccepted) {
          // Offerer plays red (and moves first); acceptor plays
          // yellow. Same offerer-first-mover rule as TTT.
          if (lc.offerDirection == SipPlayEntryDirection.outbound) {
            localDisc = C4Disc.red;
            remoteDisc = C4Disc.yellow;
          } else {
            localDisc = C4Disc.yellow;
            remoteDisc = C4Disc.red;
          }
          turn = C4Disc.red;
        }
        if (lc.status == SipPlayInstanceStatus.resignedByLocal ||
            lc.status == SipPlayInstanceStatus.resignedByRemote) {
          turn = null;
        }
        continue;
      }

      if (lc.status != SipPlayInstanceStatus.active) {
        AppLogging.sipPlay(
          'replay_drop reason=move_in_wrong_status status=${lc.status.name} '
          'seq=${env.seq}',
        );
        continue;
      }
      if (env.seq <= lc.lastAppliedSeq) {
        AppLogging.sipPlay(
          'replay_drop reason=duplicate_or_replay '
          'last=${lc.lastAppliedSeq} got=${env.seq}',
        );
        continue;
      }
      if (env.seq != lc.lastAppliedSeq + 1) {
        AppLogging.sipPlay(
          'replay_drop reason=move_seq_mismatch '
          'expected=${lc.lastAppliedSeq + 1} got=${env.seq}',
        );
        continue;
      }
      final move = C4Codec.decodeMove(env.gamePayload);
      if (move == null) {
        AppLogging.sipPlay(
          'replay_drop reason=c4_payload_malformed seq=${env.seq}',
        );
        continue;
      }
      final expectedDiscForSender =
          entry.direction == SipPlayEntryDirection.outbound
          ? localDisc
          : remoteDisc;
      if (move.disc != expectedDiscForSender) {
        AppLogging.sipPlay(
          'replay_drop reason=disc_mismatch '
          'expected=${expectedDiscForSender?.name} got=${move.disc.name}',
        );
        continue;
      }
      if (move.disc != turn) {
        AppLogging.sipPlay(
          'replay_drop reason=not_senders_turn turn=${turn?.name} '
          'disc=${move.disc.name} seq=${env.seq}',
        );
        continue;
      }
      if (!board.isLegalMove(move.column)) {
        AppLogging.sipPlay(
          'replay_drop reason=column_full column=${move.column} '
          'seq=${env.seq}',
        );
        continue;
      }
      board = board.apply(move.column, move.disc);
      lc.lastAppliedSeq = env.seq;
      final w = board.winner;
      if (w != null) {
        lc.status = SipPlayInstanceStatus.won;
        winner = w;
        turn = null;
      } else if (board.isDraw) {
        lc.status = SipPlayInstanceStatus.draw;
        turn = null;
      } else {
        turn = move.disc.opponent;
      }
    }

    return C4InstanceState(
      gameTypeCode: gameTypeCode,
      instanceId: instanceId,
      status: lc.status,
      localDisc: localDisc,
      remoteDisc: remoteDisc,
      board: board,
      turn: turn,
      lastAppliedSeq: lc.lastAppliedSeq,
      winner: winner,
    );
  }

  /// Defensive placeholder for the empty-entries edge case (callers
  /// shouldn't normally hit this — they hold an instance only after
  /// the offer envelope has been appended). Returns a TTT state in
  /// the pendingOffer status with an empty board because TTT is the
  /// default game type when the engine has no envelope to lock from.
  static SipPlayInstanceState _emptyState(int gameTypeCode, int instanceId) {
    return TttInstanceState(
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

  /// Whether the given DM-play entry log contains any non-terminal
  /// instance (`pendingOffer` or `active`) for [gameTypeCode]. Used by
  /// the offer paths — both the sender (`sendSipPlayOffer`) and the
  /// receiver (`SipDmManager.handleInboundPlay`) — to refuse a second
  /// concurrent offer for the same game in the same session.
  ///
  /// Groups entries by instanceId; each group is matched against
  /// [gameTypeCode] via the first envelope. Per-group, the answer is
  /// determined in two stages:
  ///
  /// 1. **Terminal-envelope override (sticky terminal invariant).**
  ///    Terminal lifecycle envelopes are sticky. A witnessed decline /
  ///    resign must make the instance non-blocking even if the offer
  ///    or earlier replay context is missing. Without this, a
  ///    truncated history (offer entry lost, only the decline
  ///    surviving) replays back to `pendingOffer` and blocks every
  ///    future offer for that gameType forever — see SocialMesh issue
  ///    where the picker stuck on "A game offer is already in
  ///    progress" after a peer declined.
  /// 2. **Replay fallback.** When no terminal envelope is present, run
  ///    the standard replay and treat `pendingOffer`/`active` as
  ///    blocking; everything else (won/draw/unsupported/etc.) is
  ///    non-blocking.
  ///
  /// When a group carries a terminal envelope but replay still lands
  /// on a non-terminal status, that's a real history-coherence bug
  /// upstream — log it (not deduped at the engine level — callers
  /// invoke this rarely, on offer-tap or offer-receive) so the lost
  /// entry can be investigated, but do not block the user.
  static bool hasNonTerminalInstanceForGameType({
    required List<SipPlayEntry> entries,
    required int gameTypeCode,
  }) {
    final byInstance = groupByInstance(entries);
    for (final group in byInstance.entries) {
      final instanceId = group.key;
      final instanceEntries = group.value;
      if (instanceEntries.isEmpty) continue;
      final firstGameType = instanceEntries.first.envelope.gameTypeCode;
      if (firstGameType != gameTypeCode) continue;

      // Stage 1: terminal-envelope override.
      SipPlayEntry? terminalEnvelope;
      for (final e in instanceEntries) {
        final action = e.envelope.action;
        if (action == SipPlayAction.decline || action == SipPlayAction.resign) {
          terminalEnvelope = e;
          break;
        }
      }
      if (terminalEnvelope != null) {
        final state = replay(instanceEntries);
        if (state.status == SipPlayInstanceStatus.pendingOffer ||
            state.status == SipPlayInstanceStatus.active) {
          AppLogging.sipPlay(
            'lifecycle_incoherent '
            'reason=terminalEnvelopeOverridesReplay '
            'instance=0x${instanceId.toRadixString(16)} '
            'gameType=0x${gameTypeCode.toRadixString(16)} '
            'terminalAction=${terminalEnvelope.envelope.action.name} '
            'replayStatus=${state.status.name} '
            'entryCount=${instanceEntries.length}',
          );
        }
        continue;
      }

      // Stage 2: replay-based fallback.
      final state = replay(instanceEntries);
      if (state.status == SipPlayInstanceStatus.pendingOffer ||
          state.status == SipPlayInstanceStatus.active) {
        return true;
      }
    }
    return false;
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

/// What happened to a single SIP Play entry as the shared
/// [_LifecycleProcessor] inspected it.
enum _LifecycleOutcome {
  /// The entry was a valid lifecycle action (offer / accept / decline
  /// / resign). Per-game state machinery is up to date with whatever
  /// the processor mutated; the caller skips to the next entry.
  consumed,

  /// The entry was malformed for the current state (wrong status,
  /// wrong seq, sync action in v1, etc.). Already drop-logged. Caller
  /// skips to the next entry.
  dropped,

  /// The entry is a `move`. Lifecycle has nothing to say — the caller
  /// must decode the per-game move payload and apply it.
  delegate,
}

/// Game-agnostic lifecycle state-machine for SIP Play. Encapsulates
/// the offer / accept / decline / resign branches that are identical
/// across every game; per-game replay walks the entries and only
/// owns the `move` action + role (mark / disc) assignment at the
/// moment [_LifecycleProcessor.justAccepted] flips true.
///
/// Mutates [status], [lastAppliedSeq], [offerDirection],
/// [justAccepted] in place for each call to [process].
class _LifecycleProcessor {
  final int instanceId;

  SipPlayInstanceStatus status = SipPlayInstanceStatus.pendingOffer;
  int lastAppliedSeq = -1;
  SipPlayEntryDirection? offerDirection;

  /// True for exactly one [process] call: the one that transitioned
  /// the instance from `pendingOffer` to `active`. Per-game replay
  /// reads this to know when to stamp role markers (TttMark.x / O,
  /// C4Disc.red / yellow). Reset to false on every subsequent call.
  bool justAccepted = false;

  _LifecycleProcessor({required this.instanceId});

  _LifecycleOutcome process({
    required SipPlayEntry entry,
    required int entryIndex,
  }) {
    justAccepted = false;
    final env = entry.envelope;

    // Reserved-in-v1 sync action: drop without state change.
    if (env.action == SipPlayAction.sync) {
      AppLogging.sipPlay(
        'replay_drop reason=sync_reserved_in_v1 '
        'instance=0x${instanceId.toRadixString(16)} '
        'seq=${env.seq}',
      );
      return _LifecycleOutcome.dropped;
    }

    switch (env.action) {
      case SipPlayAction.offer:
        if (entryIndex != 0) {
          AppLogging.sipPlay(
            'replay_drop reason=duplicate_offer '
            'instance=0x${instanceId.toRadixString(16)} seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (env.seq != 0) {
          AppLogging.sipPlay(
            'replay_drop reason=offer_seq_nonzero '
            'instance=0x${instanceId.toRadixString(16)} seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        offerDirection = entry.direction;
        lastAppliedSeq = 0;
        return _LifecycleOutcome.consumed;

      case SipPlayAction.accept:
        if (status != SipPlayInstanceStatus.pendingOffer) {
          AppLogging.sipPlay(
            'replay_drop reason=accept_in_wrong_status status=${status.name} '
            'seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (offerDirection == null) {
          AppLogging.sipPlay(
            'replay_drop reason=accept_without_offer seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (entry.direction == offerDirection) {
          AppLogging.sipPlay(
            'replay_drop reason=accept_from_offerer seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (env.seq != lastAppliedSeq + 1) {
          AppLogging.sipPlay(
            'replay_drop reason=accept_seq_mismatch '
            'expected=${lastAppliedSeq + 1} got=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        status = SipPlayInstanceStatus.active;
        lastAppliedSeq = env.seq;
        justAccepted = true;
        return _LifecycleOutcome.consumed;

      case SipPlayAction.decline:
        if (status != SipPlayInstanceStatus.pendingOffer) {
          AppLogging.sipPlay(
            'replay_drop reason=decline_in_wrong_status '
            'status=${status.name} seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (offerDirection == null) return _LifecycleOutcome.dropped;
        if (entry.direction == offerDirection) {
          AppLogging.sipPlay(
            'replay_drop reason=decline_from_offerer seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (env.seq != lastAppliedSeq + 1) {
          AppLogging.sipPlay(
            'replay_drop reason=decline_seq_mismatch '
            'expected=${lastAppliedSeq + 1} got=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        status = entry.direction == SipPlayEntryDirection.outbound
            ? SipPlayInstanceStatus.declinedByLocal
            : SipPlayInstanceStatus.declinedByRemote;
        lastAppliedSeq = env.seq;
        return _LifecycleOutcome.consumed;

      case SipPlayAction.resign:
        if (status != SipPlayInstanceStatus.active) {
          AppLogging.sipPlay(
            'replay_drop reason=resign_in_wrong_status '
            'status=${status.name} seq=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        if (env.seq != lastAppliedSeq + 1) {
          AppLogging.sipPlay(
            'replay_drop reason=resign_seq_mismatch '
            'expected=${lastAppliedSeq + 1} got=${env.seq}',
          );
          return _LifecycleOutcome.dropped;
        }
        status = entry.direction == SipPlayEntryDirection.outbound
            ? SipPlayInstanceStatus.resignedByLocal
            : SipPlayInstanceStatus.resignedByRemote;
        lastAppliedSeq = env.seq;
        return _LifecycleOutcome.consumed;

      case SipPlayAction.move:
        return _LifecycleOutcome.delegate;

      case SipPlayAction.sync:
        // Already handled above (reserved-in-v1 drop).
        return _LifecycleOutcome.dropped;
    }
  }
}
