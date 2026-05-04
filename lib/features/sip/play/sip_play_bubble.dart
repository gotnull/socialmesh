// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inline message-timeline bubble for one SIP Play instance.
///
/// Reads the derived `SipPlayInstanceState` from
/// `sipPlayInstanceStateProvider` and dispatches by status:
///
///   - pendingOffer + outbound → "You offered" + waiting status
///   - pendingOffer + inbound  → Accept / Decline controls
///   - active                  → 3x3 board + status caption + Resign
///   - terminal (won/draw/...) → board (read-only) + final caption
///   - unsupported game type   → safe fallback
///   - malformed envelope      → informational fallback (no state)
///
/// Render-layer only — no protocol or session mutation here. All
/// outbound moves flow through `sipDmRouterProvider.sendPlay`.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../providers/peer_safety_providers.dart';
import '../../../providers/sip_dm_secure_router.dart';
import '../../../providers/sip_play_providers.dart';
import '../../../services/audio/sip_play_sound_service.dart';
import '../../../providers/sip_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/sip_dm.dart';
import '../../../services/protocol/sip/play/games/connectfour/c4_codec.dart';
import '../../../services/protocol/sip/play/games/connectfour/c4_payload.dart';
import '../../../services/protocol/sip/play/games/connectfour/c4_rules.dart';
import '../../../services/protocol/sip/play/games/tictactoe/ttt_codec.dart';
import '../../../services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import '../../../services/protocol/sip/play/sip_play_codec.dart';
import '../../../services/protocol/sip/play/sip_play_constants.dart';
import '../../../services/protocol/sip/play/sip_play_engine.dart';
import '../../../services/protocol/sip/play/sip_play_payload.dart';
import '../../../services/protocol/sip/play/sip_play_registry.dart';
import '../../../utils/snackbar.dart';
import 'games/connectfour/c4_board_widget.dart';
import 'games/tictactoe/ttt_board_widget.dart';
import 'play_status_caption.dart';

class SipPlayBubble extends ConsumerWidget {
  /// SIP DM session this play instance belongs to.
  final int sessionTag;

  /// Peer node id (used for the mid-game block check).
  final int peerNodeId;

  /// Wire payload of the SIP DM history entry that produced this
  /// bubble. We decode it once to extract the instance id, then read
  /// the derived state via the provider so the bubble updates as
  /// further entries arrive.
  final Uint8List entryPayload;

  /// Wall-clock timestamp (ms since epoch) of the offer entry that
  /// produced this bubble. Surfaced on terminal cards (declined /
  /// resigned / won / draw) so the user can see when the game ended.
  final int entryTimestampMs;

  /// Optional dismiss callback. When non-null the terminal-decline
  /// card renders an explicit close (×) button on the right; tapping
  /// it should remove the underlying offer entry from the session
  /// history (the only general long-press menu is suppressed for
  /// play bubbles, so terminal cards otherwise have no way out).
  final VoidCallback? onDismiss;

  const SipPlayBubble({
    super.key,
    required this.sessionTag,
    required this.peerNodeId,
    required this.entryPayload,
    required this.entryTimestampMs,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = parsePlayHeaderForUi(entryPayload);
    if (header == null) {
      AppLogging.sipPlay(
        'BUBBLE_FALLBACK reason=malformedHeader '
        'sessionTag=$sessionTag peer=0x${peerNodeId.toRadixString(16)} '
        'payloadBytes=${entryPayload.length}',
      );
      return _MalformedFallback();
    }

    // We only render a bubble for the FIRST entry of an instance
    // (the offer). Subsequent moves don't get their own bubble —
    // they update the offer bubble's state in place via the engine.
    if (header.action != SipPlayAction.offer) {
      return const SizedBox.shrink();
    }

    if (!SipPlayRegistry.isSupported(header.gameTypeCode)) {
      AppLogging.sipPlay(
        'BUBBLE_FALLBACK reason=unsupportedGame '
        'gameType=0x${header.gameTypeCode.toRadixString(16)} '
        'instance=0x${header.instanceId.toRadixString(16)}',
      );
      return _UnsupportedFallback();
    }

    final stateKey = (sessionTag: sessionTag, instanceId: header.instanceId);
    // Lifecycle feedback (UX #3): when an outbound offer's status
    // transitions from pendingOffer to active or declinedByRemote,
    // surface a one-shot snackbar. ref.listen fires once per state
    // change rather than on every rebuild, so the snackbar doesn't
    // duplicate. We restrict to outbound offers — the receiver
    // already has visible UI feedback (the offer card morphs into
    // the board for accept, into a decline card for decline).
    ref.listen<SipPlayInstanceState?>(sipPlayInstanceStateProvider(stateKey), (
      prev,
      next,
    ) {
      if (prev?.status != SipPlayInstanceStatus.pendingOffer) return;
      if (next == null) return;
      final isOutbound = _readFirstOfferDirectionIsOutbound(
        ref,
        sessionTag,
        header.instanceId,
      );
      if (!isOutbound) return;
      final l10n = context.l10n;
      switch (next.status) {
        case SipPlayInstanceStatus.active:
          showInfoSnackBar(context, l10n.sipPlayLifecycleAccepted);
          break;
        case SipPlayInstanceStatus.declinedByRemote:
          showWarningSnackBar(context, l10n.sipPlayLifecycleDeclined);
          break;
        default:
          break;
      }
    });
    final state = ref.watch(sipPlayInstanceStateProvider(stateKey));
    if (state == null) {
      // Race: history entry exists but engine hasn't seen it. Render
      // the malformed fallback rather than blanking — the user gets
      // a hint something is off without a crash.
      AppLogging.sipPlay(
        'BUBBLE_FALLBACK reason=stateNull '
        'sessionTag=$sessionTag '
        'instance=0x${header.instanceId.toRadixString(16)}',
      );
      return _MalformedFallback();
    }

    // Mid-game block: freeze input, no inbound applied. The protocol
    // layer already drops further inbound envelopes and the router
    // already returns peerBlocked on outbound; this gate just makes
    // the visible affordance match the locked-in policy.
    final isPeerBlocked = ref
        .read(peerSafetyManagerProvider.notifier)
        .isBlocked(peerNodeId);

    final perGameLog = switch (state) {
      TttInstanceState s => 'localMark=${s.localMark?.name ?? "null"}',
      C4InstanceState s => 'localDisc=${s.localDisc?.name ?? "null"}',
      UnsupportedInstanceState _ => 'unsupported',
    };
    AppLogging.sipPlay(
      'BUBBLE_BUILD sessionTag=$sessionTag '
      'peer=0x${peerNodeId.toRadixString(16)} '
      'instance=0x${state.instanceId.toRadixString(16)} '
      'status=${state.status.name} '
      '$perGameLog '
      'isLocalTurn=${state.isLocalTurn} '
      'lastAppliedSeq=${state.lastAppliedSeq} '
      'peerBlocked=$isPeerBlocked',
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.4)),
      ),
      child: _DispatchBody(
        state: state,
        sessionTag: sessionTag,
        peerNodeId: peerNodeId,
        peerBlocked: isPeerBlocked,
        entryTimestampMs: entryTimestampMs,
        onDismiss: onDismiss,
      ),
    );
  }
}

class _DispatchBody extends ConsumerWidget {
  final SipPlayInstanceState state;
  final int sessionTag;
  final int peerNodeId;
  final bool peerBlocked;
  final int entryTimestampMs;
  final VoidCallback? onDismiss;

  const _DispatchBody({
    required this.state,
    required this.sessionTag,
    required this.peerNodeId,
    required this.peerBlocked,
    required this.entryTimestampMs,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLogging.sipPlay(
      'DISPATCH status=${state.status.name} '
      'instance=0x${state.instanceId.toRadixString(16)} '
      'peerBlocked=$peerBlocked',
    );
    // Outer switch: sealed-state subtype. The compiler enforces
    // exhaustiveness so adding a new game (C4 etc.) forces a render
    // path here. Inner switch: lifecycle status, scoped to the now-
    // narrowed game subclass.
    return switch (state) {
      UnsupportedInstanceState _ => _UnsupportedFallback(),
      TttInstanceState s => _dispatchTtt(context, ref, s),
      C4InstanceState s => _dispatchC4(context, ref, s),
    };
  }

  /// Pendingoffer rows are game-agnostic — they only access fields on
  /// the sealed base. Both [_dispatchTtt] and [_dispatchC4] use them.
  Widget _pendingOfferRow(
    BuildContext context,
    WidgetRef ref,
    SipPlayInstanceState s,
  ) {
    final isOutbound = _readFirstOfferDirectionIsOutbound(
      ref,
      sessionTag,
      s.instanceId,
    );
    AppLogging.sipPlay(
      'DISPATCH_PENDING_OFFER isOutbound=$isOutbound '
      'instance=0x${s.instanceId.toRadixString(16)}',
    );
    return isOutbound
        ? _OutgoingOfferRow(state: s)
        : _IncomingOfferRow(
            state: s,
            sessionTag: sessionTag,
            peerNodeId: peerNodeId,
            peerBlocked: peerBlocked,
          );
  }

  Widget _dispatchC4(BuildContext context, WidgetRef ref, C4InstanceState s) {
    switch (s.status) {
      case SipPlayInstanceStatus.unsupported:
        return _UnsupportedFallback();
      case SipPlayInstanceStatus.pendingOffer:
        return _pendingOfferRow(context, ref, s);
      case SipPlayInstanceStatus.declinedByLocal:
      case SipPlayInstanceStatus.declinedByRemote:
      case SipPlayInstanceStatus.active:
      case SipPlayInstanceStatus.resignedByLocal:
      case SipPlayInstanceStatus.resignedByRemote:
      case SipPlayInstanceStatus.won:
      case SipPlayInstanceStatus.draw:
        return _C4BoardSection(
          state: s,
          sessionTag: sessionTag,
          peerBlocked: peerBlocked,
          entryTimestampMs: entryTimestampMs,
          onDismiss: onDismiss,
        );
    }
  }

  Widget _dispatchTtt(BuildContext context, WidgetRef ref, TttInstanceState s) {
    switch (s.status) {
      case SipPlayInstanceStatus.unsupported:
        // Not reachable here (sealed switch already routed unsupported
        // states to _UnsupportedFallback before construction), but the
        // case is kept for status-switch exhaustiveness.
        return _UnsupportedFallback();

      case SipPlayInstanceStatus.pendingOffer:
        return _pendingOfferRow(context, ref, s);

      case SipPlayInstanceStatus.declinedByLocal:
      case SipPlayInstanceStatus.declinedByRemote:
      case SipPlayInstanceStatus.active:
      case SipPlayInstanceStatus.resignedByLocal:
      case SipPlayInstanceStatus.resignedByRemote:
      case SipPlayInstanceStatus.won:
      case SipPlayInstanceStatus.draw:
        return _TttBoardSection(
          state: s,
          sessionTag: sessionTag,
          peerBlocked: peerBlocked,
          entryTimestampMs: entryTimestampMs,
          onDismiss: onDismiss,
        );
    }
  }
}

/// Localised game name for an envelope's `gameTypeCode`. Falls back
/// to the TTT name for unknown codes — the unsupported fallback path
/// renders elsewhere, this is just defensive copy.
String _gameNameFor(AppLocalizations l10n, int gameTypeCode) {
  return switch (SipPlayGameType.fromCode(gameTypeCode)) {
    SipPlayGameType.connectFour => l10n.sipPlayGameConnectFour,
    SipPlayGameType.ticTacToe => l10n.sipPlayGameTicTacToe,
    null => l10n.sipPlayGameTicTacToe,
  };
}

/// Icon glyph that visually identifies the game on offer rows. Mirrors
/// the picker-tile icon choices in `_GameOfferCard`.
IconData _iconForGameType(int gameTypeCode) {
  return switch (SipPlayGameType.fromCode(gameTypeCode)) {
    SipPlayGameType.connectFour => Icons.view_column_outlined,
    SipPlayGameType.ticTacToe => Icons.grid_3x3,
    null => Icons.grid_3x3,
  };
}

/// Was the offer envelope for [instanceId] sent by the local user?
///
/// The engine doesn't expose offer direction on
/// [SipPlayInstanceState] directly — it only matters during the
/// brief pendingOffer window so the UI can decide between the
/// "you offered" and "they offered" variants. We re-scan the raw
/// session history (cheap: only the first matching entry is
/// inspected) rather than enlarging the state object for one
/// transitional view.
bool _readFirstOfferDirectionIsOutbound(
  WidgetRef ref,
  int sessionTag,
  int instanceId,
) {
  final dm = ref.read(sipDmManagerProvider);
  if (dm == null) return false;
  final history = dm.getHistory(sessionTag);
  if (history == null) return false;
  for (final entry in history) {
    if (entry.contentType != SipDmContentType.play) continue;
    final payload = entry.payload;
    if (payload == null || payload.isEmpty) continue;
    final decoded = SipPlayEngine.decodeEntry(
      payload: Uint8List.fromList(payload),
      direction: entry.direction == SipDmDirection.outbound
          ? SipPlayEntryDirection.outbound
          : SipPlayEntryDirection.inbound,
    );
    if (decoded == null) continue;
    if (decoded.envelope.instanceId != instanceId) continue;
    if (decoded.envelope.action != SipPlayAction.offer) continue;
    return decoded.direction == SipPlayEntryDirection.outbound;
  }
  return false;
}

class _OutgoingOfferRow extends StatelessWidget {
  final SipPlayInstanceState state;
  const _OutgoingOfferRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Icon(
          _iconForGameType(state.gameTypeCode),
          size: 22,
          color: context.accentColor,
        ),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sipPlayOfferOutgoingTitle(
                  _gameNameFor(l10n, state.gameTypeCode),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                l10n.sipPlayPickerSubtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.textTertiary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Inbound offer card with optimistic UX:
///   - tapping Accept / Decline immediately disables both buttons
///     and surfaces an inline spinner (`_responding` flag),
///   - on success the engine state advances pendingOffer → active
///     (or → declinedByLocal) and the parent dispatcher swaps in the
///     board section — no flicker because the bubble's outer
///     container is unchanged,
///   - on failure the flag clears, both buttons re-enable, and we
///     surface a snackbar with the typed error.
class _IncomingOfferRow extends ConsumerStatefulWidget {
  // Game-agnostic: only reads `gameTypeCode`, `instanceId`, and
  // `lastAppliedSeq` from the base class — the offer-response
  // envelope it builds is the same shape for every game.
  final SipPlayInstanceState state;
  final int sessionTag;
  final int peerNodeId;
  final bool peerBlocked;
  const _IncomingOfferRow({
    required this.state,
    required this.sessionTag,
    required this.peerNodeId,
    required this.peerBlocked,
  });

  @override
  ConsumerState<_IncomingOfferRow> createState() => _IncomingOfferRowState();
}

class _IncomingOfferRowState extends ConsumerState<_IncomingOfferRow>
    with LifecycleSafeMixin {
  /// Tracks an in-flight Accept / Decline send. While true, both
  /// buttons disable and a spinner replaces the active button's icon.
  /// Cleared on send completion (parent rebuild handles the success
  /// case implicitly because the dispatcher routes elsewhere when
  /// status flips — this State is unmounted then).
  bool _responding = false;

  /// True when the LAST attempt was an Accept. Drives which button
  /// shows the spinner.
  bool _respondingAccept = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disabled = widget.peerBlocked || _responding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _iconForGameType(widget.state.gameTypeCode),
              size: 22,
              color: context.accentColor,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                l10n.sipPlayOfferIncomingTitle(
                  _gameNameFor(l10n, widget.state.gameTypeCode),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: disabled ? null : () => _respond(accept: true),
                icon: _responding && _respondingAccept
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(l10n.sipPlayOfferAccept),
                style: FilledButton.styleFrom(
                  backgroundColor: AccentColors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(34),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : () => _respond(accept: false),
                icon: _responding && !_respondingAccept
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AccentColors.red,
                          ),
                        ),
                      )
                    : const Icon(Icons.close, size: 16),
                label: Text(l10n.sipPlayOfferDecline),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AccentColors.red,
                  side: BorderSide(
                    color: AccentColors.red.withValues(alpha: 0.6),
                  ),
                  minimumSize: const Size.fromHeight(34),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _respond({required bool accept}) async {
    if (_responding) return; // double-tap guard
    final l10n = context.l10n;
    final peerHex = '0x${widget.peerNodeId.toRadixString(16)}';

    AppLogging.sipPlay(
      accept
          ? 'PLAY_ACCEPT_TAP peer=$peerHex '
                'instance=0x${widget.state.instanceId.toRadixString(16)}'
          : 'PLAY_DECLINE_TAP peer=$peerHex '
                'instance=0x${widget.state.instanceId.toRadixString(16)}',
    );

    setState(() {
      _responding = true;
      _respondingAccept = accept;
    });

    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final router = ref.read(sipDmRouterProvider);

    final envelope = SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: widget.state.gameTypeCode,
      instanceId: widget.state.instanceId,
      action: accept ? SipPlayAction.accept : SipPlayAction.decline,
      // Strict-seq: response is always seq=1, paired with the offer's
      // seq=0. The engine rejects anything else.
      seq: widget.state.lastAppliedSeq + 1,
      gamePayload: Uint8List(0),
    );
    final bytes = SipPlayCodec.encode(envelope);
    if (bytes == null) {
      AppLogging.sipPlay(
        accept
            ? 'PLAY_ACCEPT_FAIL reason=encode '
                  'instance=0x${widget.state.instanceId.toRadixString(16)}'
            : 'PLAY_DECLINE_FAIL reason=encode '
                  'instance=0x${widget.state.instanceId.toRadixString(16)}',
      );
      if (mounted) setState(() => _responding = false);
      return;
    }
    final SipDmRouterOutcome outcome;
    try {
      outcome = await router.sendPlay(
        sessionTag: widget.sessionTag,
        playPayload: bytes,
      );
    } catch (err) {
      // Defensive: if the send path throws synchronously (e.g. a
      // native plugin dlopen failure on a misbuilt iOS Runner), the
      // outcome-based branches below never fire and the spinner would
      // remain forever. Always re-enable the buttons and surface a
      // generic failure snackbar.
      AppLogging.sipPlay(
        'PLAY_${accept ? 'ACCEPT' : 'DECLINE'}_FAIL reason=throw '
        'detail=${err.runtimeType} peer=$peerHex '
        'instance=0x${widget.state.instanceId.toRadixString(16)}',
      );
      if (mounted) {
        setState(() => _responding = false);
        showErrorSnackBar(context, l10n.sipDmSessionClosed);
      }
      return;
    }
    if (!mounted) return;
    if (!outcome.isOk) {
      AppLogging.sipPlay(
        accept
            ? 'PLAY_ACCEPT_FAIL reason=${outcome.error?.name} peer=$peerHex '
                  'instance=0x${widget.state.instanceId.toRadixString(16)}'
            : 'PLAY_DECLINE_FAIL reason=${outcome.error?.name} peer=$peerHex '
                  'instance=0x${widget.state.instanceId.toRadixString(16)}',
      );
      setState(() => _responding = false);
      final message = switch (outcome.error) {
        SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
        SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
        SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
        SipDmSendError.peerUnsupported => l10n.sipPlayPeerUnsupported,
        _ => l10n.sipDmSessionClosed,
      };
      showErrorSnackBar(context, message);
      return;
    }
    AppLogging.sipPlay(
      accept
          ? 'PLAY_ACCEPT_SUCCESS peer=$peerHex '
                'instance=0x${widget.state.instanceId.toRadixString(16)}'
          : 'PLAY_DECLINE_SUCCESS peer=$peerHex '
                'instance=0x${widget.state.instanceId.toRadixString(16)}',
    );
    // Don't clear _responding — the engine state has flipped to
    // active (or declinedByLocal), the dispatcher will swap _BoardSection
    // in on the next rebuild and this State is disposed cleanly.
  }
}

/// Active / terminal board view with optimistic move handling.
///
/// Local UI state added on top of the engine:
///   - `_pendingMove`: a TttMove the local user just tapped that has
///     not yet been reflected in `widget.state.board`. Renders as a
///     pulsing ghost on the target cell.
///   - `_interactionLock`: while a pending move is in flight no
///     further taps register, preventing double-sends.
///
/// **The pending overlay never enters the entry log** — it's pure
/// UI. The instant the engine state advances and the cell shows the
/// expected mark, `didUpdateWidget` clears the overlay. If the send
/// fails the overlay clears too because the engine never saw it.
class _TttBoardSection extends ConsumerStatefulWidget {
  final TttInstanceState state;
  final int sessionTag;
  final bool peerBlocked;
  final int entryTimestampMs;
  final VoidCallback? onDismiss;
  const _TttBoardSection({
    required this.state,
    required this.sessionTag,
    required this.entryTimestampMs,
    required this.onDismiss,
    required this.peerBlocked,
  });

  @override
  ConsumerState<_TttBoardSection> createState() => _TttBoardSectionState();
}

class _TttBoardSectionState extends ConsumerState<_TttBoardSection>
    with LifecycleSafeMixin {
  /// Optimistic-overlay move. Never mutated by the engine — set when
  /// the user taps a legal cell, cleared when the engine state
  /// advances OR a send-error returns.
  TttMove? _pendingMove;

  /// Defensive guard against double-tapping the same cell while the
  /// router is in flight. The pending overlay already stops the
  /// child board from registering further taps but this lock also
  /// suppresses re-entry into `_sendMove`.
  bool _interactionLock = false;

  @override
  void didUpdateWidget(covariant _TttBoardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Audio cues on lifecycle transitions. The engine state is the
    // authoritative trigger — we compare the previous frame's status
    // with the current frame's, so each cue fires exactly once per
    // transition regardless of how many rebuilds happen between.
    final prevStatus = oldWidget.state.status;
    final nextStatus = widget.state.status;
    final instanceHex = '0x${widget.state.instanceId.toRadixString(16)}';
    if (prevStatus != nextStatus) {
      AppLogging.sipPlay(
        'BOARD_STATUS_CHANGE instance=$instanceHex '
        '${prevStatus.name}->${nextStatus.name}',
      );
      // pendingOffer → active = "game starts" for both sides.
      if (prevStatus == SipPlayInstanceStatus.pendingOffer &&
          nextStatus == SipPlayInstanceStatus.active) {
        ref.read(sipPlaySoundServiceProvider).play(SipPlaySoundCue.gameStart);
      }
      // Any → declined = the offer was rejected (either side).
      // Reuses the handshake-decline SFX so the user has one
      // consistent "no thanks" cue across SIP layers.
      if (nextStatus == SipPlayInstanceStatus.declinedByLocal ||
          nextStatus == SipPlayInstanceStatus.declinedByRemote) {
        ref
            .read(sipPlaySoundServiceProvider)
            .play(SipPlaySoundCue.rejectedDeclined);
      }
    }
    if (oldWidget.state.lastAppliedSeq != widget.state.lastAppliedSeq) {
      AppLogging.sipPlay(
        'BOARD_SEQ_ADVANCE instance=$instanceHex '
        '${oldWidget.state.lastAppliedSeq}->${widget.state.lastAppliedSeq} '
        'turn=${widget.state.turn?.name ?? "null"} '
        'isLocalTurn=${widget.state.isLocalTurn}',
      );
    }

    final pending = _pendingMove;
    if (pending == null) return;
    // Engine state caught up — the cell now holds the expected mark.
    // Clear the overlay so the confirmed glyph renders normally.
    final boardCell = widget.state.board.cells[pending.cell];
    if (boardCell == pending.mark) {
      AppLogging.sipPlay(
        'PLAY_MOVE_RESOLVED instance=$instanceHex cell=${pending.cell}',
      );
      _pendingMove = null;
      _interactionLock = false;
    } else {
      AppLogging.sipPlay(
        'PLAY_MOVE_PENDING_HOLDS instance=$instanceHex '
        'cell=${pending.cell} expected=${pending.mark.name} '
        'actual=${boardCell?.name ?? "null"}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;

    final boardEnabled =
        !widget.peerBlocked &&
        state.status == SipPlayInstanceStatus.active &&
        state.isLocalTurn &&
        _pendingMove == null;

    final canResign =
        state.status == SipPlayInstanceStatus.active && !widget.peerBlocked;

    final isDeclined =
        state.status == SipPlayInstanceStatus.declinedByLocal ||
        state.status == SipPlayInstanceStatus.declinedByRemote;

    AppLogging.sipPlay(
      'BOARD_SECTION_BUILD instance=0x${state.instanceId.toRadixString(16)} '
      'boardEnabled=$boardEnabled '
      'peerBlocked=${widget.peerBlocked} '
      'statusActive=${state.status == SipPlayInstanceStatus.active} '
      'status=${state.status.name} '
      'isLocalTurn=${state.isLocalTurn} '
      'turn=${state.turn?.name ?? "null"} '
      'localMark=${state.localMark?.name ?? "null"} '
      'pendingMoveCell=${_pendingMove?.cell ?? "null"} '
      'interactionLock=$_interactionLock',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: title + (optional) pulse turn dot + status
        // caption + resign button (top-right, low-prominence).
        Row(
          children: [
            Text(
              l10n.sipPlayGameTicTacToe,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            if (state.isLocalTurn &&
                state.status == SipPlayInstanceStatus.active)
              PlayTurnPulseDot(color: context.accentColor),
            const SizedBox(width: AppTheme.spacing4),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: PlayStatusBanner(
                  isLocalTurn: state.isLocalTurn,
                  isActive: state.status == SipPlayInstanceStatus.active,
                  localWon:
                      state.status == SipPlayInstanceStatus.won &&
                      state.winner == state.localMark,
                  remoteWon:
                      state.status == SipPlayInstanceStatus.won &&
                      state.winner == state.remoteMark,
                  draw: state.status == SipPlayInstanceStatus.draw,
                  localResigned:
                      state.status == SipPlayInstanceStatus.resignedByLocal,
                  remoteResigned:
                      state.status == SipPlayInstanceStatus.resignedByRemote,
                  localDeclined:
                      state.status == SipPlayInstanceStatus.declinedByLocal,
                  remoteDeclined:
                      state.status == SipPlayInstanceStatus.declinedByRemote,
                ),
              ),
            ),
            if (canResign)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing4),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: _confirmResign,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    splashRadius: 18,
                    tooltip: l10n.sipPlayResign,
                    icon: Icon(
                      Icons.flag_outlined,
                      color: SemanticColors.error.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            if (isDeclined && widget.onDismiss != null)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing4),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: widget.onDismiss,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    splashRadius: 18,
                    tooltip: l10n.sipDmActionDelete,
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // The header→board spacer renders only when the board itself
        // does. On terminal-declined cards the board is hidden, and
        // an orphan spacer would leave the card visibly bottom-heavy
        // (more whitespace under the header than above it).
        if (state.status != SipPlayInstanceStatus.declinedByLocal &&
            state.status != SipPlayInstanceStatus.declinedByRemote) ...[
          const SizedBox(height: AppTheme.spacing8),
          TttBoardWidget(
            board: state.board,
            localMark: state.localMark,
            enabled: boardEnabled,
            pendingMove: _pendingMove,
            onCellTap: _onCellTap,
          ),
        ],
        if (isDeclined) ...[
          const SizedBox(height: AppTheme.spacing4),
          Text(
            // Format with the user's locale + 24/12-hour preference,
            // matching the style text bubbles use just below the body.
            TimeOfDay.fromDateTime(
              DateTime.fromMillisecondsSinceEpoch(widget.entryTimestampMs),
            ).format(context),
            style: TextStyle(
              fontSize: 10,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ],
    );
  }

  void _onCellTap(int cell) {
    final state = widget.state;
    final instanceHex = '0x${state.instanceId.toRadixString(16)}';
    AppLogging.sipPlay(
      'PLAY_MOVE_TAP_ENTER instance=$instanceHex cell=$cell '
      'interactionLock=$_interactionLock '
      'localMark=${state.localMark?.name ?? "null"} '
      'isLocalTurn=${state.isLocalTurn} '
      'turn=${state.turn?.name ?? "null"} '
      'status=${state.status.name} '
      'cellMark=${state.board.cells[cell]?.name ?? "null"} '
      'isLegal=${state.board.isLegalMove(cell)}',
    );
    if (_interactionLock) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=interactionLock '
        'instance=$instanceHex cell=$cell',
      );
      return;
    }
    if (state.localMark == null) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=noLocalMark '
        'instance=$instanceHex cell=$cell status=${state.status.name}',
      );
      return;
    }
    if (!state.isLocalTurn) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=notLocalTurn '
        'instance=$instanceHex cell=$cell '
        'turn=${state.turn?.name ?? "null"} '
        'localMark=${state.localMark?.name ?? "null"} '
        'status=${state.status.name}',
      );
      return;
    }
    if (!state.board.isLegalMove(cell)) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=illegalMove '
        'instance=$instanceHex cell=$cell '
        'cellMark=${state.board.cells[cell]?.name ?? "null"}',
      );
      return;
    }

    final mark = state.localMark!;
    AppLogging.sipPlay(
      'PLAY_MOVE_TAP instance=$instanceHex cell=$cell pending=true',
    );
    setState(() {
      _pendingMove = TttMove(cell: cell, mark: mark);
      _interactionLock = true;
    });
    _sendMove(cell: cell, mark: mark);
  }

  Future<void> _sendMove({required int cell, required TttMark mark}) async {
    final l10n = context.l10n;
    final state = widget.state;
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
    final router = ref.read(sipDmRouterProvider);

    final movePayload = TttCodec.encodeMove(TttMove(cell: cell, mark: mark));
    if (movePayload == null) {
      AppLogging.sipPlay(
        'move_encode_failed cell=$cell '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
      _clearPending();
      return;
    }

    final envelope = SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: state.gameTypeCode,
      instanceId: state.instanceId,
      action: SipPlayAction.move,
      seq: state.lastAppliedSeq + 1,
      gamePayload: movePayload,
    );
    final bytes = SipPlayCodec.encode(envelope);
    if (bytes == null) {
      AppLogging.sipPlay(
        'move_envelope_encode_failed '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
      _clearPending();
      return;
    }
    AppLogging.sipPlay(
      'move_attempt instance=0x${state.instanceId.toRadixString(16)} '
      'cell=$cell seq=${envelope.seq} bytes=${bytes.length}',
    );

    final outcome = await router.sendPlay(
      sessionTag: widget.sessionTag,
      playPayload: bytes,
    );
    if (!mounted) {
      AppLogging.sipPlay(
        'move_after_send_unmounted '
        'instance=0x${state.instanceId.toRadixString(16)} cell=$cell',
      );
      return;
    }
    if (!outcome.isOk) {
      final message = switch (outcome.error) {
        SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
        SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
        SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
        SipDmSendError.peerUnsupported => l10n.sipPlayPeerUnsupported,
        _ => l10n.sipDmSessionClosed,
      };
      AppLogging.sipPlay(
        'move_blocked reason=${outcome.error?.name} '
        'instance=0x${state.instanceId.toRadixString(16)} cell=$cell',
      );
      // Send failed — engine state never advanced, so the pending
      // overlay must be cleared explicitly here. didUpdateWidget
      // would clear it on a successful send because the cell flips
      // to the target mark; a failure leaves the cell empty so the
      // overlay would otherwise stick forever.
      _clearPending();
      showErrorSnackBar(context, message);
      return;
    }
    AppLogging.sipPlay(
      'move_send_ok instance=0x${state.instanceId.toRadixString(16)} '
      'cell=$cell seq=${envelope.seq} bytes=${bytes.length}',
    );
    // Success path: engine state will rebuild this widget; clearing
    // is handled in didUpdateWidget once the cell shows the target
    // mark.
  }

  void _clearPending() {
    if (!mounted) return;
    setState(() {
      _pendingMove = null;
      _interactionLock = false;
    });
  }

  Future<void> _confirmResign() async {
    final l10n = context.l10n;
    final state = widget.state;
    ref.read(hapticServiceProvider).trigger(HapticType.heavy);
    final router = ref.read(sipDmRouterProvider);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipPlayResignConfirmTitle,
      message: l10n.sipPlayResignConfirmBody,
      confirmLabel: l10n.sipPlayResignConfirmAction,
      cancelLabel: l10n.sipPlayResignConfirmCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;

    final envelope = SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: state.gameTypeCode,
      instanceId: state.instanceId,
      action: SipPlayAction.resign,
      seq: state.lastAppliedSeq + 1,
      gamePayload: Uint8List(0),
    );
    final bytes = SipPlayCodec.encode(envelope);
    if (bytes == null) return;
    final outcome = await router.sendPlay(
      sessionTag: widget.sessionTag,
      playPayload: bytes,
    );
    if (!mounted) return;
    if (!outcome.isOk) {
      AppLogging.sipPlay(
        'resign_blocked reason=${outcome.error?.name} '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
    }
  }
}

/// Active / terminal Connect Four board view with optimistic move
/// handling. Mirrors [_TttBoardSection]'s lifecycle 1:1 — same audio
/// cues, same pending-overlay + interaction-lock pattern, same
/// dismiss + resign affordances. Differences are confined to the
/// inner board widget (column-tap C4 grid instead of cell-tap TTT
/// grid), the move encoding (C4Codec), and the pending-resolution
/// check (compare against the disc that lands at gravity row, not a
/// fixed cell index).
class _C4BoardSection extends ConsumerStatefulWidget {
  final C4InstanceState state;
  final int sessionTag;
  final bool peerBlocked;
  final int entryTimestampMs;
  final VoidCallback? onDismiss;
  const _C4BoardSection({
    required this.state,
    required this.sessionTag,
    required this.entryTimestampMs,
    required this.onDismiss,
    required this.peerBlocked,
  });

  @override
  ConsumerState<_C4BoardSection> createState() => _C4BoardSectionState();
}

class _C4BoardSectionState extends ConsumerState<_C4BoardSection>
    with LifecycleSafeMixin {
  C4Move? _pendingMove;
  bool _interactionLock = false;

  @override
  void didUpdateWidget(covariant _C4BoardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final prevStatus = oldWidget.state.status;
    final nextStatus = widget.state.status;
    final instanceHex = '0x${widget.state.instanceId.toRadixString(16)}';
    if (prevStatus != nextStatus) {
      AppLogging.sipPlay(
        'BOARD_STATUS_CHANGE instance=$instanceHex '
        '${prevStatus.name}->${nextStatus.name}',
      );
      if (prevStatus == SipPlayInstanceStatus.pendingOffer &&
          nextStatus == SipPlayInstanceStatus.active) {
        ref.read(sipPlaySoundServiceProvider).play(SipPlaySoundCue.gameStart);
      }
      if (nextStatus == SipPlayInstanceStatus.declinedByLocal ||
          nextStatus == SipPlayInstanceStatus.declinedByRemote) {
        ref
            .read(sipPlaySoundServiceProvider)
            .play(SipPlaySoundCue.rejectedDeclined);
      }
    }
    if (oldWidget.state.lastAppliedSeq != widget.state.lastAppliedSeq) {
      AppLogging.sipPlay(
        'BOARD_SEQ_ADVANCE instance=$instanceHex '
        '${oldWidget.state.lastAppliedSeq}->${widget.state.lastAppliedSeq} '
        'turn=${widget.state.turn?.name ?? "null"} '
        'isLocalTurn=${widget.state.isLocalTurn}',
      );
    }

    final pending = _pendingMove;
    if (pending == null) return;
    // Engine state caught up — the disc with our pending colour has
    // landed somewhere in the targeted column. Find the topmost disc
    // there: if it's our pending mark, the move resolved.
    final topRow = _topFilledRow(widget.state.board, pending.column);
    final topDisc = topRow == null
        ? null
        : widget.state.board.cellAt(topRow, pending.column);
    if (topDisc == pending.disc) {
      AppLogging.sipPlay(
        'PLAY_MOVE_RESOLVED instance=$instanceHex column=${pending.column}',
      );
      _pendingMove = null;
      _interactionLock = false;
    } else {
      AppLogging.sipPlay(
        'PLAY_MOVE_PENDING_HOLDS instance=$instanceHex '
        'column=${pending.column} expected=${pending.disc.name} '
        'actual=${topDisc?.name ?? "null"}',
      );
    }
  }

  int? _topFilledRow(C4Board board, int column) {
    for (var r = 0; r < C4Board.rows; r += 1) {
      if (board.cellAt(r, column) != null) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;

    final boardEnabled =
        !widget.peerBlocked &&
        state.status == SipPlayInstanceStatus.active &&
        state.isLocalTurn &&
        _pendingMove == null;

    final canResign =
        state.status == SipPlayInstanceStatus.active && !widget.peerBlocked;

    final isDeclined =
        state.status == SipPlayInstanceStatus.declinedByLocal ||
        state.status == SipPlayInstanceStatus.declinedByRemote;

    AppLogging.sipPlay(
      'BOARD_SECTION_BUILD instance=0x${state.instanceId.toRadixString(16)} '
      'game=c4 boardEnabled=$boardEnabled '
      'peerBlocked=${widget.peerBlocked} '
      'statusActive=${state.status == SipPlayInstanceStatus.active} '
      'status=${state.status.name} '
      'isLocalTurn=${state.isLocalTurn} '
      'turn=${state.turn?.name ?? "null"} '
      'localDisc=${state.localDisc?.name ?? "null"} '
      'pendingColumn=${_pendingMove?.column ?? "null"} '
      'interactionLock=$_interactionLock',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.sipPlayGameConnectFour,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            if (state.isLocalTurn &&
                state.status == SipPlayInstanceStatus.active)
              PlayTurnPulseDot(color: context.accentColor),
            const SizedBox(width: AppTheme.spacing4),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: PlayStatusBanner(
                  isLocalTurn: state.isLocalTurn,
                  isActive: state.status == SipPlayInstanceStatus.active,
                  localWon:
                      state.status == SipPlayInstanceStatus.won &&
                      state.winner == state.localDisc,
                  remoteWon:
                      state.status == SipPlayInstanceStatus.won &&
                      state.winner == state.remoteDisc,
                  draw: state.status == SipPlayInstanceStatus.draw,
                  localResigned:
                      state.status == SipPlayInstanceStatus.resignedByLocal,
                  remoteResigned:
                      state.status == SipPlayInstanceStatus.resignedByRemote,
                  localDeclined:
                      state.status == SipPlayInstanceStatus.declinedByLocal,
                  remoteDeclined:
                      state.status == SipPlayInstanceStatus.declinedByRemote,
                ),
              ),
            ),
            if (canResign)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing4),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: _confirmResign,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    splashRadius: 18,
                    tooltip: l10n.sipPlayResign,
                    icon: Icon(
                      Icons.flag_outlined,
                      color: SemanticColors.error.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            if (isDeclined && widget.onDismiss != null)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing4),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: widget.onDismiss,
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    splashRadius: 18,
                    tooltip: l10n.sipDmActionDelete,
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (state.status != SipPlayInstanceStatus.declinedByLocal &&
            state.status != SipPlayInstanceStatus.declinedByRemote) ...[
          const SizedBox(height: AppTheme.spacing8),
          C4BoardWidget(
            board: state.board,
            localDisc: state.localDisc,
            enabled: boardEnabled,
            pendingMove: _pendingMove,
            onColumnTap: _onColumnTap,
          ),
        ],
        if (isDeclined) ...[
          const SizedBox(height: AppTheme.spacing4),
          Text(
            TimeOfDay.fromDateTime(
              DateTime.fromMillisecondsSinceEpoch(widget.entryTimestampMs),
            ).format(context),
            style: TextStyle(
              fontSize: 10,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ],
    );
  }

  void _onColumnTap(int column) {
    final state = widget.state;
    final instanceHex = '0x${state.instanceId.toRadixString(16)}';
    AppLogging.sipPlay(
      'PLAY_MOVE_TAP_ENTER instance=$instanceHex column=$column '
      'interactionLock=$_interactionLock '
      'localDisc=${state.localDisc?.name ?? "null"} '
      'isLocalTurn=${state.isLocalTurn} '
      'turn=${state.turn?.name ?? "null"} '
      'status=${state.status.name} '
      'columnFull=${!state.board.isLegalMove(column)}',
    );
    if (_interactionLock) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=interactionLock '
        'instance=$instanceHex column=$column',
      );
      return;
    }
    if (state.localDisc == null) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=noLocalDisc '
        'instance=$instanceHex column=$column status=${state.status.name}',
      );
      return;
    }
    if (!state.isLocalTurn) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=notLocalTurn '
        'instance=$instanceHex column=$column '
        'turn=${state.turn?.name ?? "null"} '
        'localDisc=${state.localDisc?.name ?? "null"} '
        'status=${state.status.name}',
      );
      return;
    }
    if (!state.board.isLegalMove(column)) {
      AppLogging.sipPlay(
        'PLAY_MOVE_TAP_IGNORED reason=columnFull '
        'instance=$instanceHex column=$column',
      );
      return;
    }

    final disc = state.localDisc!;
    AppLogging.sipPlay(
      'PLAY_MOVE_TAP instance=$instanceHex column=$column pending=true',
    );
    setState(() {
      _pendingMove = C4Move(column: column, disc: disc);
      _interactionLock = true;
    });
    _sendMove(column: column, disc: disc);
  }

  Future<void> _sendMove({required int column, required C4Disc disc}) async {
    final l10n = context.l10n;
    final state = widget.state;
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
    final router = ref.read(sipDmRouterProvider);

    final movePayload = C4Codec.encodeMove(C4Move(column: column, disc: disc));
    if (movePayload == null) {
      AppLogging.sipPlay(
        'move_encode_failed column=$column '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
      _clearPending();
      return;
    }

    final envelope = SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: state.gameTypeCode,
      instanceId: state.instanceId,
      action: SipPlayAction.move,
      seq: state.lastAppliedSeq + 1,
      gamePayload: movePayload,
    );
    final bytes = SipPlayCodec.encode(envelope);
    if (bytes == null) {
      AppLogging.sipPlay(
        'move_envelope_encode_failed '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
      _clearPending();
      return;
    }
    AppLogging.sipPlay(
      'move_attempt instance=0x${state.instanceId.toRadixString(16)} '
      'column=$column seq=${envelope.seq} bytes=${bytes.length}',
    );

    final outcome = await router.sendPlay(
      sessionTag: widget.sessionTag,
      playPayload: bytes,
    );
    if (!mounted) {
      AppLogging.sipPlay(
        'move_after_send_unmounted '
        'instance=0x${state.instanceId.toRadixString(16)} column=$column',
      );
      return;
    }
    if (!outcome.isOk) {
      final message = switch (outcome.error) {
        SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
        SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
        SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
        SipDmSendError.peerUnsupported => l10n.sipPlayPeerUnsupported,
        _ => l10n.sipDmSessionClosed,
      };
      AppLogging.sipPlay(
        'move_blocked reason=${outcome.error?.name} '
        'instance=0x${state.instanceId.toRadixString(16)} column=$column',
      );
      _clearPending();
      showErrorSnackBar(context, message);
      return;
    }
    AppLogging.sipPlay(
      'move_send_ok instance=0x${state.instanceId.toRadixString(16)} '
      'column=$column seq=${envelope.seq} bytes=${bytes.length}',
    );
  }

  void _clearPending() {
    if (!mounted) return;
    setState(() {
      _pendingMove = null;
      _interactionLock = false;
    });
  }

  Future<void> _confirmResign() async {
    final l10n = context.l10n;
    final state = widget.state;
    ref.read(hapticServiceProvider).trigger(HapticType.heavy);
    final router = ref.read(sipDmRouterProvider);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipPlayResignConfirmTitle,
      message: l10n.sipPlayResignConfirmBody,
      confirmLabel: l10n.sipPlayResignConfirmAction,
      cancelLabel: l10n.sipPlayResignConfirmCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;

    final envelope = SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: state.gameTypeCode,
      instanceId: state.instanceId,
      action: SipPlayAction.resign,
      seq: state.lastAppliedSeq + 1,
      gamePayload: Uint8List(0),
    );
    final bytes = SipPlayCodec.encode(envelope);
    if (bytes == null) return;
    final outcome = await router.sendPlay(
      sessionTag: widget.sessionTag,
      playPayload: bytes,
    );
    if (!mounted) return;
    if (!outcome.isOk) {
      AppLogging.sipPlay(
        'resign_blocked reason=${outcome.error?.name} '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
    }
  }
}

class _MalformedFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: SemanticColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: SemanticColors.error.withValues(alpha: 0.85),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              l10n.sipPlayMalformedTitle,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 18, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sipPlayUnsupportedGame,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  l10n.sipPlayUnsupportedGameBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
