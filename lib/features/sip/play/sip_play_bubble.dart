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
import '../../../services/protocol/sip/play/games/tictactoe/ttt_codec.dart';
import '../../../services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import '../../../services/protocol/sip/play/sip_play_codec.dart';
import '../../../services/protocol/sip/play/sip_play_constants.dart';
import '../../../services/protocol/sip/play/sip_play_engine.dart';
import '../../../services/protocol/sip/play/sip_play_payload.dart';
import '../../../services/protocol/sip/play/sip_play_registry.dart';
import '../../../utils/snackbar.dart';
import 'games/tictactoe/ttt_board_widget.dart';

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

  const SipPlayBubble({
    super.key,
    required this.sessionTag,
    required this.peerNodeId,
    required this.entryPayload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = parsePlayHeaderForUi(entryPayload);
    if (header == null) {
      return _MalformedFallback();
    }

    // We only render a bubble for the FIRST entry of an instance
    // (the offer). Subsequent moves don't get their own bubble —
    // they update the offer bubble's state in place via the engine.
    if (header.action != SipPlayAction.offer) {
      return const SizedBox.shrink();
    }

    if (!SipPlayRegistry.isSupported(header.gameTypeCode)) {
      return _UnsupportedFallback();
    }

    final state = ref.watch(
      sipPlayInstanceStateProvider((
        sessionTag: sessionTag,
        instanceId: header.instanceId,
      )),
    );
    if (state == null) {
      // Race: history entry exists but engine hasn't seen it. Render
      // the malformed fallback rather than blanking — the user gets
      // a hint something is off without a crash.
      return _MalformedFallback();
    }

    // Mid-game block: freeze input, no inbound applied. The protocol
    // layer already drops further inbound envelopes and the router
    // already returns peerBlocked on outbound; this gate just makes
    // the visible affordance match the locked-in policy.
    final isPeerBlocked = ref
        .read(peerSafetyManagerProvider.notifier)
        .isBlocked(peerNodeId);

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
      ),
    );
  }
}

class _DispatchBody extends ConsumerWidget {
  final SipPlayInstanceState state;
  final int sessionTag;
  final int peerNodeId;
  final bool peerBlocked;

  const _DispatchBody({
    required this.state,
    required this.sessionTag,
    required this.peerNodeId,
    required this.peerBlocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.status) {
      case SipPlayInstanceStatus.unsupported:
        return _UnsupportedFallback();

      case SipPlayInstanceStatus.pendingOffer:
        // localMark is null pre-accept, so we can't tell offerer from
        // acceptor by mark alone — disambiguate via the offer
        // envelope's direction.
        final isOutbound = _readFirstOfferDirectionIsOutbound(
          ref,
          sessionTag,
          state.instanceId,
        );
        return isOutbound
            ? _OutgoingOfferRow(state: state)
            : _IncomingOfferRow(
                state: state,
                sessionTag: sessionTag,
                peerNodeId: peerNodeId,
                peerBlocked: peerBlocked,
              );

      case SipPlayInstanceStatus.declinedByLocal:
      case SipPlayInstanceStatus.declinedByRemote:
      case SipPlayInstanceStatus.active:
      case SipPlayInstanceStatus.resignedByLocal:
      case SipPlayInstanceStatus.resignedByRemote:
      case SipPlayInstanceStatus.won:
      case SipPlayInstanceStatus.draw:
        return _BoardSection(
          state: state,
          sessionTag: sessionTag,
          peerBlocked: peerBlocked,
        );
    }
  }
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
        Icon(Icons.grid_3x3, size: 22, color: context.accentColor),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sipPlayOfferOutgoingTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                l10n.sipPlayPickerSubtitle,
                style: TextStyle(fontSize: 11, color: context.textTertiary),
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
            Icon(Icons.grid_3x3, size: 22, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                l10n.sipPlayOfferIncomingTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
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
    final outcome = await router.sendPlay(
      sessionTag: widget.sessionTag,
      playPayload: bytes,
    );
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
class _BoardSection extends ConsumerStatefulWidget {
  final SipPlayInstanceState state;
  final int sessionTag;
  final bool peerBlocked;
  const _BoardSection({
    required this.state,
    required this.sessionTag,
    required this.peerBlocked,
  });

  @override
  ConsumerState<_BoardSection> createState() => _BoardSectionState();
}

class _BoardSectionState extends ConsumerState<_BoardSection>
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
  void didUpdateWidget(covariant _BoardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Audio cues on lifecycle transitions. The engine state is the
    // authoritative trigger — we compare the previous frame's status
    // with the current frame's, so each cue fires exactly once per
    // transition regardless of how many rebuilds happen between.
    final prevStatus = oldWidget.state.status;
    final nextStatus = widget.state.status;
    if (prevStatus != nextStatus) {
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

    final pending = _pendingMove;
    if (pending == null) return;
    // Engine state caught up — the cell now holds the expected mark.
    // Clear the overlay so the confirmed glyph renders normally.
    final boardCell = widget.state.board.cells[pending.cell];
    if (boardCell == pending.mark) {
      AppLogging.sipPlay(
        'PLAY_MOVE_RESOLVED instance=0x'
        '${widget.state.instanceId.toRadixString(16)} cell=${pending.cell}',
      );
      _pendingMove = null;
      _interactionLock = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final caption = tttStatusCaption(
      context: context,
      isLocalTurn: state.isLocalTurn,
      localWon:
          state.status == SipPlayInstanceStatus.won &&
          state.winner == state.localMark,
      remoteWon:
          state.status == SipPlayInstanceStatus.won &&
          state.winner == state.remoteMark,
      draw: state.status == SipPlayInstanceStatus.draw,
      localResigned: state.status == SipPlayInstanceStatus.resignedByLocal,
      remoteResigned: state.status == SipPlayInstanceStatus.resignedByRemote,
      localDeclined: state.status == SipPlayInstanceStatus.declinedByLocal,
      remoteDeclined: state.status == SipPlayInstanceStatus.declinedByRemote,
    );

    final boardEnabled =
        !widget.peerBlocked &&
        state.status == SipPlayInstanceStatus.active &&
        state.isLocalTurn &&
        _pendingMove == null;

    final canResign =
        state.status == SipPlayInstanceStatus.active && !widget.peerBlocked;

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
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            if (state.isLocalTurn &&
                state.status == SipPlayInstanceStatus.active)
              TttTurnPulseDot(color: context.accentColor),
            const SizedBox(width: AppTheme.spacing4),
            Expanded(
              child: Text(
                caption,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      state.isLocalTurn &&
                          state.status == SipPlayInstanceStatus.active
                      ? context.accentColor
                      : context.textSecondary,
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
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        if (state.status != SipPlayInstanceStatus.declinedByLocal &&
            state.status != SipPlayInstanceStatus.declinedByRemote)
          TttBoardWidget(
            board: state.board,
            localMark: state.localMark,
            enabled: boardEnabled,
            pendingMove: _pendingMove,
            onCellTap: _onCellTap,
          ),
      ],
    );
  }

  void _onCellTap(int cell) {
    if (_interactionLock) return;
    final state = widget.state;
    if (state.localMark == null) return;
    if (!state.isLocalTurn) return;
    if (!state.board.isLegalMove(cell)) return;

    final mark = state.localMark!;
    AppLogging.sipPlay(
      'PLAY_MOVE_TAP instance=0x${state.instanceId.toRadixString(16)} '
      'cell=$cell pending=true',
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
    if (!mounted) return;
    if (!outcome.isOk) {
      final message = switch (outcome.error) {
        SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
        SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
        SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
        _ => l10n.sipDmSessionClosed,
      };
      AppLogging.sipPlay(
        'move_blocked reason=${outcome.error?.name} '
        'instance=0x${state.instanceId.toRadixString(16)}',
      );
      // Send failed — engine state never advanced, so the pending
      // overlay must be cleared explicitly here. didUpdateWidget
      // would clear it on a successful send because the cell flips
      // to the target mark; a failure leaves the cell empty so the
      // overlay would otherwise stick forever.
      _clearPending();
      showErrorSnackBar(context, message);
    }
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
              style: TextStyle(fontSize: 13, color: context.textSecondary),
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
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  l10n.sipPlayUnsupportedGameBody,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
