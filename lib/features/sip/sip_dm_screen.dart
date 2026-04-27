// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP DM Screen — ephemeral chat thread for a single SIP session.
//
// Design patterns used (matching the rest of the app):
// - GlassScaffold with resolved peer name in title
// - Card-styled session info bar with sigil + evolution
// - Message bubbles with semantic colors and rounded corners
// - AppBarOverflowMenu for pin/close actions
// - BouncyTap on interactive elements
// - Consistent badge styling (container + color + radius6)

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/jump_to_latest_pill.dart';
import '../../core/widgets/status_banner.dart';
import '../../features/messaging/widgets/chat_composer.dart';
import '../../features/sip/play/sip_play_bubble.dart';
import '../../features/sip/signal/sip_signal_bubble.dart';
import '../../features/sip/signal/sip_signal_composer_panel.dart';
import '../../features/sip/play/sip_play_picker.dart';
import '../../features/sip/sketch/sip_ink_bubble.dart';
import '../../features/sip/sketch/sip_ink_composer.dart';
import '../../features/nodedex/models/nodedex_entry.dart';
import '../../features/nodedex/models/sigil_evolution.dart';
import '../../features/nodedex/providers/nodedex_providers.dart';
import '../../features/nodedex/services/patina_score.dart';
import '../../features/nodedex/services/trait_engine.dart';
import '../../features/nodedex/screens/nodedex_detail_screen.dart';
import '../../features/nodedex/widgets/sigil_painter.dart';
import '../../features/nodes/node_display_name_resolver.dart';
import '../../providers/app_providers.dart';
import '../../providers/overlay_providers.dart';
import '../../providers/peer_safety_providers.dart';
import '../../providers/sip_dm_secure_router.dart';
import '../../providers/sip_play_providers.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/play/sip_play_engine.dart';
import '../../services/protocol/sip/sip_dm.dart';
import '../../services/protocol/sip/sip_ink_simplifier.dart';
import '../../services/protocol/sip/sip_messages_dm.dart';
import '../../services/protocol/sip/signal/sip_signal_codec.dart';
import '../../services/protocol/text_message_payload_budget.dart';
import '../../utils/snackbar.dart';

/// Ephemeral DM thread screen for a single SIP session.
///
/// Displays the message history with the peer's sigil avatar and
/// resolved name, expiry countdown, and input field for composing
/// new messages.
class SipDmScreen extends ConsumerStatefulWidget {
  /// Session tag of the DM session to display.
  final int sessionTag;

  const SipDmScreen({super.key, required this.sessionTag});

  @override
  ConsumerState<SipDmScreen> createState() => _SipDmScreenState();
}

/// Composer modes available in an accepted SIP DM session.
///
/// `text` is the historical default. `sketch` activates the SIP Ink
/// canvas instead of the text input. The mode is screen-local — no
/// provider, since switching is purely UI state.
enum _SipDmComposerMode { text, sketch, play, signal }

class _SipDmScreenState extends ConsumerState<SipDmScreen>
    with LifecycleSafeMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  /// The message being replied to, or null if not replying.
  SipDmHistoryEntry? _replyingToEntry;

  /// Active composer mode. Defaults to text.
  _SipDmComposerMode _composerMode = _SipDmComposerMode.text;

  /// Persistent sketch draft. Survives mode switches so the user can
  /// flip back from text to sketch and find their strokes intact.
  /// Cleared after a successful send by the SIP Ink composer.
  final List<SipInkRawStroke> _sketchDraft = [];

  /// Timer to dismiss the typing indicator after the display duration.
  Timer? _typingDismissTimer;

  /// Whether the jump-to-latest affordance is visible. True when the
  /// user has scrolled the message list up far enough that they're no
  /// longer reading the bottom (most-recent) entry.
  bool _showJumpToLatest = false;

  /// History length on the previous build. Null means "first build, no
  /// comparison yet". Used to detect new inbound messages and auto-
  /// scroll when the user is parked at the bottom — important in
  /// sketch mode where the canvas occupies vertical space and a
  /// freshly arrived sketch otherwise lands off-screen.
  int? _lastHistoryLength;

  /// Timestamp (ms) of a message that should briefly glow because the
  /// user just tapped a reply quote pointing to it. Null = no
  /// highlight active. Cleared automatically by [_highlightClearTimer]
  /// after the cue has played.
  int? _highlightedTimestampMs;
  Timer? _highlightClearTimer;

  /// Distance in pixels from the bottom within which we still consider
  /// the user "at the latest". Mirrors the messaging screen's threshold
  /// so the affordance feels consistent across chat surfaces.
  static const double _atBottomThresholdPx = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    // Auto-focus the input field when entering the DM screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });

    // Land at the latest message on every entry/re-entry. Without this,
    // popping back to the DM screen from the SIP hub leaves the list
    // halfway up because the controller starts at offset 0 and the
    // CustomScrollView builds top-down.
    _scrollToBottom(animate: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _typingDismissTimer?.cancel();
    _highlightClearTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // The keyboard opening/closing or the screen rotating changes the
    // ListView's `maxScrollExtent`. The ScrollController preserves
    // `pixels`, so a user who was anchored to the latest message ends
    // up "a little up" once new content space appears below them.
    // Re-anchor on every metric change while the user was at-bottom
    // (no jump-to-latest pill showing). This is the canonical fix for
    // the navigate-away-and-back regression: the keyboard re-shows on
    // re-entry and shifts the bottom out from under the controller.
    if (!mounted || _showJumpToLatest) return;
    _scrollToBottom(animate: false);
  }

  /// Toggle [_showJumpToLatest] based on the user's current scroll
  /// position relative to the bottom of the message list.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    final shouldShow = distanceFromBottom > _atBottomThresholdPx;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  /// Send a typing indicator when the user starts composing.
  void _onTextChanged() {
    if (_messageController.text.isEmpty) return;

    final dm = ref.read(sipDmManagerProvider);
    if (dm == null) return;

    final encoded = dm.buildTypingIndicator(sessionTag: widget.sessionTag);
    if (encoded != null) {
      final protocol = ref.read(protocolServiceProvider);
      protocol.sendSipPacket(encoded);
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // SIP DM caps text at SipDmConstants.maxDmTextBytes UTF-8 bytes (not
  // characters) — emoji/CJK runs out of budget faster than the visible
  // char count suggests. Surface that to the user via the same byte
  // counter pattern used in the messaging composer.
  TextMessagePayloadBudget _measureSipDmBudget(String text) {
    final bytes = utf8.encode(text).length;
    return TextMessagePayloadBudget(
      utf8Bytes: bytes,
      maxUtf8Bytes: SipDmConstants.maxDmTextBytes,
      encodedDataBytes: bytes,
      maxEncodedDataBytes: SipDmConstants.maxDmTextBytes,
      replyId: null,
      isEmoji: false,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final dm = ref.read(sipDmManagerProvider);
    if (dm == null) return;

    final haptics = ref.read(hapticServiceProvider);

    // If replying, format the message with the quote prefix. Ink
    // entries have no plaintext body — substitute the localized
    // placeholder so the recipient sees a meaningful quote block
    // instead of an empty `>` line.
    final messageText = _replyingToEntry != null
        ? SipDmManager.formatReplyMessage(
            quotedText: _replyingQuoteText(_replyingToEntry!),
            replyText: text,
          )
        : text;

    // Phase 2: route through the secure-aware DM router instead of
    // building a plaintext frame directly. The router picks secure or
    // plaintext per the encrypt-when-all-true gate and sends exactly
    // one transport.
    final outcome = await ref
        .read(sipDmRouterProvider)
        .sendText(sessionTag: widget.sessionTag, text: messageText);

    if (!mounted) return;
    if (outcome.isOk) {
      haptics.trigger(HapticType.light);
      _messageController.clear();
      _cancelReply();
      setState(() {}); // Refresh message list.
      _scrollToBottom();
    } else {
      haptics.trigger(HapticType.error);
      _showSendError(outcome.error);
    }
  }

  void _showSendError(SipDmSendError? error) {
    if (!mounted) return;
    final l10n = context.l10n;
    final message = switch (error) {
      // T+S: per-peer block. Surfaced as a distinct snackbar so the
      // user can recognise self-imposed state (vs. a generic
      // "couldn't send" failure) and reach for the SIP Hub Blocked
      // section to unblock.
      SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
      // T+S: per-peer × per-kind token bucket (text 6/60s, sketch
      // 2/60s, reaction 6/60s). Distinct from the global airtime
      // budget below.
      SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
      // Global SIP airtime cap (1024 bytes / 60s, shared across
      // SIP / MRRP / overlay).
      SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
      SipDmSendError.textTooLong => l10n.sipDmTextTooLong(
        SipDmConstants.maxDmTextBytes,
      ),
      SipDmSendError.sessionClosed => l10n.sipDmSessionClosed,
      SipDmSendError.sessionNotFound => l10n.sipDmSessionClosed,
      _ => l10n.sipDmSessionClosed,
    };

    showErrorSnackBar(context, message);
  }

  /// Maximum number of frames to retry [_scrollToBottom] while the
  /// layout settles. At 60 fps that's ~500 ms — long enough to outlast
  /// the route push transition, but bounded so we don't loop forever
  /// when the chat is genuinely empty (or shorter than the viewport).
  static const int _scrollToBottomMaxAttempts = 30;

  void _scrollToBottom({bool animate = true, int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Layout may not be settled yet — controller not attached, or
      // the ListView's maxScrollExtent is still 0 because items
      // haven't been laid out. Retry on the next frame until we have
      // a usable position or we hit the attempt cap.
      final hasUsablePosition =
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0;
      if (!hasUsablePosition) {
        if (attempt < _scrollToBottomMaxAttempts) {
          _scrollToBottom(animate: animate, attempt: attempt + 1);
        }
        return;
      }
      final position = _scrollController.position;
      if (animate) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  void _jumpToLatest() {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    _scrollToBottom(animate: true);
    if (mounted) {
      setState(() => _showJumpToLatest = false);
    }
  }

  void _onClose() {
    final dm = ref.read(sipDmManagerProvider);
    if (dm == null) return;

    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final encoded = dm.closeSession(widget.sessionTag);
    if (encoded != null) {
      ref.read(protocolServiceProvider).sendSipPacket(encoded);
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // Trust + Safety overflow actions (Mute / Block / Reset / Remove)
  //
  // Hard separation, per Phase 9 spec:
  //   - Mute  = notifications only. Reversible toggle. No confirm.
  //             Inbound DMs still arrive and are stored.
  //   - Block = persist block via PeerSafetyManager. Future inbound
  //             HELLO / DM / MRRP frames hit the protocol-layer
  //             safety gate and are silently dropped. Local
  //             conversation history is PRESERVED — to wipe history
  //             too, the user must also choose Remove.
  //   - Reset = drop the in-memory secure (X25519) session for the
  //             canonical overlay link with this peer. Next outbound
  //             DM renegotiates fresh keys. No history wipe. The
  //             underlying overlay link stays open.
  //   - Remove = clear local message history + drop the local
  //              session entry. Emits NO wire frame (no DM_CLOSE).
  //              Peer is not notified.
  //
  // All destructive actions (Block, Reset, Remove) go through
  // AppBottomSheet.showConfirm with isDestructive: true.
  // ---------------------------------------------------------------------

  Widget _buildOverflowMenu(BuildContext context, SipDmSession session) {
    final l10n = context.l10n;
    // Watch the manager so the Mute label flips immediately when
    // mute state changes elsewhere (e.g. Mesh Explorer tap).
    ref.watch(peerSafetyManagerProvider);
    final isMuted = ref
        .read(peerSafetyManagerProvider.notifier)
        .isMuted(session.peerNodeId);

    // Visual hierarchy (semantics unchanged from Phase 9):
    //   PREFERENCES  -> Mute / Unmute notifications
    //   SAFETY       -> Block
    //   SESSION      -> Reset secure connection, Close session
    //   DATA         -> Remove conversation
    //
    // Section headers are non-interactive `enabled: false` items so
    // taps fall through cleanly. The five existing action values
    // ('mute', 'block', 'reset_secure', 'remove', 'close') are
    // preserved byte-for-byte — overflow wiring tests still pin them.
    return AppBarOverflowMenu<String>(
      itemBuilder: (context) => [
        _sectionHeader(context, l10n.sipDmOverflowSectionPreferences),
        PopupMenuItem(
          value: 'mute',
          child: ListTile(
            leading: Icon(
              isMuted ? Icons.notifications_active : Icons.notifications_off,
            ),
            title: Text(isMuted ? l10n.sipDmMenuUnmute : l10n.sipDmMenuMute),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        _sectionHeader(context, l10n.sipDmOverflowSectionSafety),
        PopupMenuItem(
          value: 'block',
          child: ListTile(
            leading: Icon(
              Icons.block,
              color: SemanticColors.error.withValues(alpha: 0.85),
            ),
            title: Text(l10n.sipDmMenuBlock),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        _sectionHeader(context, l10n.sipDmOverflowSectionSession),
        PopupMenuItem(
          value: 'reset_secure',
          child: ListTile(
            leading: const Icon(Icons.lock_reset),
            title: Text(l10n.sipDmMenuResetSecure),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'close',
          child: ListTile(
            leading: const Icon(Icons.close),
            title: Text(l10n.sipDmCloseAction),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        _sectionHeader(context, l10n.sipDmOverflowSectionData),
        PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: SemanticColors.error.withValues(alpha: 0.85),
            ),
            title: Text(l10n.sipDmMenuRemove),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'mute':
            _onToggleMute(session);
          case 'block':
            _onBlockPeer(session);
          case 'reset_secure':
            _onResetSecureSession(session);
          case 'remove':
            _onRemoveConversation(session);
          case 'close':
            _onClose();
        }
      },
    );
  }

  /// Non-interactive section label inside the DM overflow popup.
  /// Rendered as a disabled `PopupMenuItem` so any stray tap falls
  /// through without triggering an action.
  PopupMenuItem<String> _sectionHeader(BuildContext context, String label) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
          letterSpacing: 1.2,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  Future<void> _onToggleMute(SipDmSession session) async {
    final manager = ref.read(peerSafetyManagerProvider.notifier);
    final wasMuted = manager.isMuted(session.peerNodeId);
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
    final l10n = context.l10n;

    if (wasMuted) {
      await manager.unmute(session.peerNodeId);
      if (!mounted) return;
      showInfoSnackBar(context, l10n.sipDmActionUnmutedSnack);
    } else {
      await manager.mute(session.peerNodeId);
      if (!mounted) return;
      showInfoSnackBar(context, l10n.sipDmActionMutedSnack);
    }
  }

  Future<void> _onBlockPeer(SipDmSession session) async {
    final l10n = context.l10n;
    final manager = ref.read(peerSafetyManagerProvider.notifier);
    final navigator = Navigator.of(context);
    ref.read(hapticServiceProvider).trigger(HapticType.heavy);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipDmBlockConfirmTitle,
      message: l10n.sipDmBlockConfirmBody,
      confirmLabel: l10n.sipDmBlockConfirmAction,
      cancelLabel: l10n.sipDmConfirmCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;

    AppLogging.sip(
      'SIP_DM: Block confirmed via overflow for '
      'peer=0x${session.peerNodeId.toRadixString(16)} '
      '— history preserved, no wire frame',
    );
    // History is intentionally preserved per Phase 9 spec. The user
    // must explicitly Remove to wipe local conversation.
    await manager.block(session.peerNodeId, reasonCode: 'dm_overflow_block');
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _onResetSecureSession(SipDmSession session) async {
    final l10n = context.l10n;
    ref.read(hapticServiceProvider).trigger(HapticType.medium);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipDmResetConfirmTitle,
      message: l10n.sipDmResetConfirmBody,
      confirmLabel: l10n.sipDmResetConfirmAction,
      cancelLabel: l10n.sipDmConfirmCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;

    // Look up the canonical overlay link for this peer. If none
    // exists yet (peer never advertised secure, or link was torn
    // down) Reset is a no-op — the next outbound DM falls back to
    // plaintext via the existing router gates.
    final store = await ref.read(overlayLinkStoreProvider.future);
    final records = await store.getNonTerminalForPeerNode(session.peerNodeId);
    if (records.isEmpty) {
      AppLogging.sip(
        'SIP_DM: Reset secure — no canonical link for '
        'peer=0x${session.peerNodeId.toRadixString(16)} (no-op)',
      );
      if (!mounted) return;
      showInfoSnackBar(context, l10n.sipDmActionResetSnack);
      return;
    }
    final canonical = records.first;

    final secureMgr = await ref.read(
      overlaySecureSessionManagerProvider.future,
    );
    final dropped = secureMgr.resetSession(canonical.linkId);
    AppLogging.sip(
      'SIP_DM: Reset secure for peer=0x'
      '${session.peerNodeId.toRadixString(16)} '
      'linkId=0x${canonical.linkId.toRadixString(16)} '
      'dropped=$dropped',
    );
    if (!mounted) return;
    showInfoSnackBar(context, l10n.sipDmActionResetSnack);
  }

  Future<void> _onRemoveConversation(SipDmSession session) async {
    final l10n = context.l10n;
    final dm = ref.read(sipDmManagerProvider);
    final navigator = Navigator.of(context);
    ref.read(hapticServiceProvider).trigger(HapticType.heavy);

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.sipDmRemoveConfirmTitle,
      message: l10n.sipDmRemoveConfirmBody,
      confirmLabel: l10n.sipDmRemoveConfirmAction,
      cancelLabel: l10n.sipDmConfirmCancel,
      isDestructive: true,
    );
    if (confirmed != true) return;

    if (dm == null) return;
    final removed = dm.removeSessionLocally(widget.sessionTag);
    AppLogging.sip(
      'SIP_DM: Remove conversation for '
      'peer=0x${session.peerNodeId.toRadixString(16)} '
      'tag=0x${widget.sessionTag.toRadixString(16)} removed=$removed '
      '— no wire frame',
    );
    if (!mounted) return;
    navigator.pop();
  }

  void _onReply(SipDmHistoryEntry entry) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    setState(() {
      _replyingToEntry = entry;
      // Replies always compose as text — sketch payloads can't carry
      // a quote prefix (the wire format has no provision for it), so
      // forcing Text mode keeps the reply path uniform regardless of
      // what's being replied to. The user's sketch draft lives in
      // [_sketchDraft] and is preserved.
      _composerMode = _SipDmComposerMode.text;
    });
    _inputFocusNode.requestFocus();
  }

  /// Quoted text to display in the reply indicator and embed in the
  /// wire-encoded `> ... \n ...` prefix. Ink and Signal entries fall
  /// back to localised placeholders since they carry no plaintext
  /// body — the placeholder lets `_findReplyTarget` walk back to the
  /// matching content type without an explicit reference.
  String _replyingQuoteText(SipDmHistoryEntry entry) {
    if (entry.contentType == SipDmContentType.ink) {
      return context.l10n.sipDmInkReplyPlaceholder;
    }
    if (entry.contentType == SipDmContentType.signal) {
      return context.l10n.sipDmSignalReplyPlaceholder;
    }
    return SipDmManager.extractReplyBody(entry.text);
  }

  /// Best-effort match from a reply entry's quote string back to the
  /// original entry it points at. The wire format doesn't carry an
  /// explicit reference (the quote is just truncated text), so we
  /// search backwards from the reply for the most recent candidate
  /// whose body matches the quote prefix — handling the 40-char
  /// `...` truncation in [SipDmManager.formatReplyMessage] and the
  /// `🎨 Sketch` placeholder used for ink replies.
  SipDmHistoryEntry? _findReplyTarget(
    SipDmHistoryEntry replyEntry,
    List<SipDmHistoryEntry> history,
  ) {
    final replyIdx = history.indexOf(replyEntry);
    if (replyIdx <= 0) return null;
    final replyToText = replyEntry.replyToText;
    if (replyToText == null || replyToText.isEmpty) return null;

    // Detect ink / signal replies by their emoji prefix rather than
    // string-equality against the localised placeholder. The wire
    // carries whatever locale the SENDER composed in (e.g. Italian
    // "📡 Segnale"), but the READER might be in English ("📡 Signal").
    // String-equality silently failed for cross-locale or mid-session
    // locale changes; the emoji is the locale-stable signature.
    const inkEmoji = '🎨';
    const signalEmoji = '📡';
    final isInkReply = replyToText.startsWith(inkEmoji);
    final isSignalReply = replyToText.startsWith(signalEmoji);
    final probe = replyToText.endsWith('...')
        ? replyToText.substring(0, replyToText.length - 3)
        : replyToText;

    AppLogging.sip(
      'REPLY_QUOTE_LOOKUP replyIdx=$replyIdx '
      'replyToText="$replyToText" isInk=$isInkReply isSignal=$isSignalReply',
    );

    for (var i = replyIdx - 1; i >= 0; i--) {
      final candidate = history[i];
      if (isInkReply) {
        if (candidate.contentType == SipDmContentType.ink) {
          AppLogging.sip(
            'REPLY_QUOTE_MATCH kind=ink targetIdx=$i '
            'targetTs=${candidate.timestampMs}',
          );
          return candidate;
        }
      } else if (isSignalReply) {
        if (candidate.contentType == SipDmContentType.signal) {
          AppLogging.sip(
            'REPLY_QUOTE_MATCH kind=signal targetIdx=$i '
            'targetTs=${candidate.timestampMs}',
          );
          return candidate;
        }
      } else {
        if (candidate.contentType != SipDmContentType.text) continue;
        final body = SipDmManager.extractReplyBody(candidate.text);
        if (probe.isNotEmpty && body.startsWith(probe)) {
          AppLogging.sip(
            'REPLY_QUOTE_MATCH kind=text targetIdx=$i '
            'targetTs=${candidate.timestampMs}',
          );
          return candidate;
        }
      }
    }
    AppLogging.sip(
      'REPLY_QUOTE_MISS replyToText="$replyToText" '
      'isInk=$isInkReply isSignal=$isSignalReply',
    );
    return null;
  }

  /// Handler invoked when the user taps a reply quote inside a
  /// message bubble. Briefly highlights the original message; if it's
  /// off-screen, scrolls to it first. Best-effort: when the heuristic
  /// can't pin a target (long-since-evicted history, ambiguous
  /// quotes), the tap is a no-op.
  void _onReplyQuoteTap(
    SipDmHistoryEntry replyEntry,
    List<SipDmHistoryEntry> history,
  ) {
    final target = _findReplyTarget(replyEntry, history);
    if (target == null) return;
    _jumpAndHighlightEntry(target, history);
  }

  /// Scroll the chat list so [target] is visible and pulse the
  /// highlight halo on it for ~1.8 s. If the target's render object
  /// is mounted we use `Scrollable.ensureVisible` directly; otherwise
  /// we animate to an index-ratio approximation, then retry once the
  /// real bubble is in the layout tree. Used by the reply-quote tap
  /// path and by the composer chip jump-to-latest behaviour.
  void _jumpAndHighlightEntry(
    SipDmHistoryEntry target,
    List<SipDmHistoryEntry> history,
  ) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);

    setState(() => _highlightedTimestampMs = target.timestampMs);
    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _highlightedTimestampMs = null);
    });

    final key = GlobalObjectKey(target);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
      return;
    }

    // Target not currently rendered — animate to a rough offset based
    // on its index ratio, then retry ensureVisible after the scroll
    // settles so the alignment is precise.
    if (!_scrollController.hasClients) return;
    final targetIndex = history.indexOf(target);
    if (targetIndex < 0) return;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final denom = math.max(history.length - 1, 1);
    final approx = (maxOffset * targetIndex / denom).clamp(0.0, maxOffset);
    _scrollController.animateTo(
      approx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      final ctx2 = key.currentContext;
      if (ctx2 == null || !ctx2.mounted) return;
      Scrollable.ensureVisible(
        ctx2,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    });
  }

  /// Single entry point for "find the latest entry matching this
  /// predicate and bring it into view". All chip / sub-mode / banner
  /// jump paths (sketch chip, signal chip, signal sub-mode toggle,
  /// "Jump to game" banner) flow through here so the find→highlight
  /// pipeline is defined exactly once.
  ///
  /// The predicate is supplied per-call so callers stay declarative:
  ///   `_jumpToLatestWhere((e) => e.contentType == SipDmContentType.ink)`
  ///
  /// No-op when the session has no entries, no entries match, or the
  /// DM manager isn't attached.
  void _jumpToLatestWhere(bool Function(SipDmHistoryEntry entry) test) {
    final dm = ref.read(sipDmManagerProvider);
    final history = dm?.getHistory(widget.sessionTag);
    if (history == null || history.isEmpty) return;
    for (var i = history.length - 1; i >= 0; i--) {
      if (test(history[i])) {
        _jumpAndHighlightEntry(history[i], history);
        return;
      }
    }
  }

  void _cancelReply() {
    if (_replyingToEntry != null) {
      setState(() => _replyingToEntry = null);
    }
  }

  void _onCopy(SipDmHistoryEntry entry) {
    final body = SipDmManager.extractReplyBody(entry.text);
    Clipboard.setData(ClipboardData(text: body));
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    if (mounted) showInfoSnackBar(context, context.l10n.sipDmMessageCopied);
  }

  void _onDelete(SipDmHistoryEntry entry) {
    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.medium);
    AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.sipDmDeleteConfirmTitle,
      message: context.l10n.sipDmDeleteConfirmMessage,
      confirmLabel: context.l10n.sipDmActionDelete,
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        final dm = ref.read(sipDmManagerProvider);
        // Send delete to peer and remove locally.
        final encoded = dm?.buildDmDelete(
          sessionTag: widget.sessionTag,
          targetEntry: entry,
        );
        if (encoded != null) {
          final protocol = ref.read(protocolServiceProvider);
          protocol.sendSipPacket(encoded);
        } else {
          // Fallback: local-only delete if send fails.
          dm?.removeMessage(widget.sessionTag, entry);
        }
        haptics.trigger(HapticType.light);
        setState(() {});
      }
    });
  }

  Future<void> _onReact(SipDmHistoryEntry entry, int emojiIndex) async {
    final dm = ref.read(sipDmManagerProvider);
    if (dm == null) return;

    final haptics = ref.read(hapticServiceProvider);
    haptics.trigger(HapticType.light);

    // Toggle: tapping the same emoji removes the reaction.
    if (entry.localReaction == emojiIndex) {
      entry.localReaction = null;
      setState(() {});
      return;
    }

    // Phase 2: route reactions through the secure-aware router.
    await ref
        .read(sipDmRouterProvider)
        .sendReaction(
          sessionTag: widget.sessionTag,
          emojiIndex: emojiIndex,
          targetEntry: entry,
        );
    if (!mounted) return;
    setState(() {});
  }

  void _showMessageMenu(SipDmHistoryEntry entry) {
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    final l10n = context.l10n;

    AppBottomSheet.show<void>(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji reaction row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(SipDmReactionEmojis.all.length, (index) {
                final isSelected = entry.localReaction == index;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _onReact(entry, index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.accentColor.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Text(
                      SipDmReactionEmojis.all[index],
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }),
            ),
          ),
          Divider(height: 1, color: context.border),
          // Reply
          ListTile(
            leading: Icon(Icons.reply, color: context.textPrimary),
            title: Text(
              l10n.sipDmActionReply,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              _onReply(entry);
            },
          ),
          // Copy
          ListTile(
            leading: Icon(Icons.copy, color: context.textPrimary),
            title: Text(
              l10n.sipDmActionCopy,
              style: TextStyle(color: context.textPrimary),
            ),
            onTap: () {
              Navigator.pop(context);
              _onCopy(entry);
            },
          ),
          // Delete — only available for your own messages
          if (entry.direction == SipDmDirection.outbound)
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorRed,
              ),
              title: Text(
                l10n.sipDmActionDelete,
                style: const TextStyle(color: AppTheme.errorRed),
              ),
              onTap: () {
                Navigator.pop(context);
                _onDelete(entry);
              },
            ),
          const SizedBox(height: AppTheme.spacing8),
        ],
      ),
    );
  }

  void _scheduleTypingDismiss() {
    _typingDismissTimer?.cancel();
    _typingDismissTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() {});
    });
  }

  // Resolve the peer's display name.
  String _resolvePeerName(SipDmSession session) {
    final entry = ref.read(nodeDexEntryProvider(session.peerNodeId));
    final nodes = ref.read(nodesProvider);
    final node = nodes[session.peerNodeId];

    return entry?.localNickname ??
        entry?.sipDisplayName ??
        node?.displayName ??
        entry?.lastKnownName ??
        NodeDisplayNameResolver.defaultName(session.peerNodeId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dm = ref.watch(sipDmManagerProvider);
    final session = dm?.getSession(widget.sessionTag);
    ref.watch(sipDmEpochProvider); // Rebuild on new messages
    ref.watch(sipDmTypingEpochProvider); // Rebuild on typing indicators
    // Rebuild when the peer's advertised capabilities change. Without
    // this, the Sketch / Play / Signal tabs stay hidden until the next
    // unrelated rebuild even after the peer's CAP_BEACON or
    // ROLLCALL_RESP arrives with the full feature bitmap. Field-bug
    // root cause from the Android-vs-iOS asymmetry: passive discovery
    // inserts a `features=sip0` placeholder, the real caps arrive
    // moments later (logs show the `caps updated` line), but
    // `_peerSupportsSignal`/`Play`/`Ink` only re-runs when the screen
    // rebuilds for some other reason.
    ref.watch(sipPeerCacheEpochProvider);

    // Auto-pop when the peer closes the session remotely.
    ref.listen<int>(sipDmEpochProvider, (_, epoch) {
      final currentDm = ref.read(sipDmManagerProvider);
      if (currentDm?.isSessionClosed(widget.sessionTag) == true && mounted) {
        safeShowSnackBar(l10n.sipDmSessionClosed);
        Navigator.of(context).pop();
      }
    });

    // Check if the peer is currently typing.
    final peerIsTyping = dm?.isPeerTyping(widget.sessionTag) ?? false;
    if (peerIsTyping) _scheduleTypingDismiss();

    final title = session != null ? _resolvePeerName(session) : l10n.sipDmTitle;

    final history = (session != null && dm != null)
        ? (dm.getHistory(widget.sessionTag) ?? <SipDmHistoryEntry>[])
        : <SipDmHistoryEntry>[];

    // Auto-scroll to latest on inbound additions when the user is
    // parked at the bottom. Outbound sends already trigger
    // _scrollToBottom from _sendMessage / SipInkComposer.onSent, so
    // we only need to handle inbound here. Initial build is skipped
    // (initState already lands at bottom non-animated).
    if (_lastHistoryLength != null &&
        history.length > _lastHistoryLength! &&
        history.isNotEmpty &&
        history.last.direction == SipDmDirection.inbound &&
        !_showJumpToLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom(animate: true);
      });
    }
    _lastHistoryLength = history.length;

    final hasContent = history.isNotEmpty || peerIsTyping;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold.body(
        title: title,
        hasScrollBody: true,
        resizeToAvoidBottomInset:
            false, // We handle keyboard insets manually in _buildInputBar
        bottomNavigationBar: _buildInputBar(context, session),
        actions: [if (session != null) _buildOverflowMenu(context, session)],
        // Body layout mirrors the messaging screen: a Column with the
        // session info bar fixed at top, then an Expanded Stack that
        // holds the chat list with the JumpToLatestPill overlaid on
        // top. The pill is a Positioned sibling of the list so the
        // chat extends right up to the input bar — the pill floats
        // transparently above the most recent messages, identical to
        // how the messaging screen handles its jump affordance.
        body: Column(
          children: [
            if (session != null)
              ClipRect(
                clipBehavior: Clip.hardEdge,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _kInfoBarBlurSigma,
                    sigmaY: _kInfoBarBlurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.background.withValues(
                        alpha: _kInfoBarBackgroundAlpha,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: context.border.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: _SessionInfoBar(session: session),
                  ),
                ),
              ),
            if (session != null)
              _FirstContactBanner(peerNodeId: session.peerNodeId),
            Expanded(
              // Tapping the chat surface returns the composer to Text
              // mode. Drafts on the active non-Text panel survive in
              // their respective State holders (_textController +
              // _sketchDraft live on this State; play state is in
              // providers). Signal Tone/Morse drafts are panel-local
              // and reset on tab switch — see KNOWN_LIMITS.
              //
              // `translucent` so the gesture fires on empty-space taps
              // AND propagates through to bubble GestureDetectors for
              // long-press.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _composerMode == _SipDmComposerMode.text
                    ? null
                    : () {
                        setState(() {
                          _composerMode = _SipDmComposerMode.text;
                        });
                      },
                child: Stack(
                  children: [
                    if (hasContent)
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        itemCount: history.length + (peerIsTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == history.length) {
                            return const _TypingIndicatorBubble();
                          }
                          final entry = history[index];
                          // SIP Play bubbles own their own affordances
                          // (Accept / Decline / Resign / cell taps) and
                          // are not reaction / reply / delete targets.
                          // Suppress the generic message-action sheet
                          // for them — the actions don't apply, and
                          // letting users delete a play entry leaves
                          // the engine state log incoherent (later
                          // entries reference the deleted offer).
                          final suppressLongPress =
                              entry.contentType == SipDmContentType.play;
                          return GestureDetector(
                            // GlobalObjectKey lets _onReplyQuoteTap find
                            // and ensureVisible this bubble even when
                            // it's off-screen. Keyed on the entry
                            // instance (identity) rather than
                            // `entry.timestampMs` because two messages
                            // sent in the same second collide on the
                            // millisecond-rounded timestamp and Flutter
                            // throws "Multiple widgets used the same
                            // GlobalKey" — see logs.txt regression.
                            key: GlobalObjectKey(entry),
                            onLongPress: suppressLongPress
                                ? null
                                : () => _showMessageMenu(entry),
                            child: _MessageBubble(
                              entry: entry,
                              peerNodeId: session!.peerNodeId,
                              sessionTag: widget.sessionTag,
                              isHighlighted:
                                  entry.timestampMs == _highlightedTimestampMs,
                              onReplyQuoteTap: entry.replyToText != null
                                  ? () => _onReplyQuoteTap(entry, history)
                                  : null,
                            ),
                          );
                        },
                      )
                    else
                      _buildEmptyState(context),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppTheme.spacing12,
                      child: JumpToLatestPill(
                        visible: _showJumpToLatest,
                        onTap: _jumpToLatest,
                        label: l10n.sipDmJumpToLatest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              l10n.sipDmEmptyState,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.sipDmEmptyDescription,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _peerSupportsInk(SipDmSession? session) {
    if (session == null) return false;
    final discovery = ref.read(sipDiscoveryProvider);
    final peer = discovery?.getPeer(session.peerNodeId);
    return peer?.supportsDmInkV1 ?? false;
  }

  bool _peerSupportsPlay(SipDmSession? session) {
    if (session == null) return false;
    final discovery = ref.read(sipDiscoveryProvider);
    final peer = discovery?.getPeer(session.peerNodeId);
    return peer?.supportsDmPlayV1 ?? false;
  }

  bool _peerSupportsSignal(SipDmSession? session) {
    if (session == null) return false;
    final discovery = ref.read(sipDiscoveryProvider);
    final peer = discovery?.getPeer(session.peerNodeId);
    return peer?.supportsDmSignalV1 ?? false;
  }

  Widget _buildInputBar(BuildContext context, SipDmSession? session) {
    final enabled =
        session != null && session.status == SipDmSessionStatus.active;
    final peerSupportsInk = _peerSupportsInk(session);
    final peerSupportsPlay = _peerSupportsPlay(session);
    final peerSupportsSignal = _peerSupportsSignal(session);
    // T+S: hide the Play / Signal tabs when the peer is blocked.
    // Defence-in-depth on top of the router-level peerBlocked guard —
    // keeps the affordance honest about the locked-in "no further
    // outbound" rule.
    final peerBlocked =
        session != null &&
        ref.watch(peerSafetyManagerProvider).value != null &&
        ref
            .read(peerSafetyManagerProvider.notifier)
            .isBlocked(session.peerNodeId);
    final showSketchTab = enabled && peerSupportsInk;
    final showPlayTab = enabled && peerSupportsPlay && !peerBlocked;
    final showSignalTab = enabled && peerSupportsSignal && !peerBlocked;
    final showAnyTabs = showSketchTab || showPlayTab || showSignalTab;

    // Auto-fall-back the active mode if the previously-selected tab
    // is no longer available (e.g. peer just got blocked while Play
    // tab was open). Routes the user back to text rather than
    // stranding them on a hidden tab.
    if (_composerMode == _SipDmComposerMode.sketch && !showSketchTab) {
      _composerMode = _SipDmComposerMode.text;
    }
    if (_composerMode == _SipDmComposerMode.play && !showPlayTab) {
      _composerMode = _SipDmComposerMode.text;
    }
    if (_composerMode == _SipDmComposerMode.signal && !showSignalTab) {
      _composerMode = _SipDmComposerMode.text;
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.5),
          border: Border(
            top: BorderSide(color: context.textTertiary.withValues(alpha: 0.1)),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: MediaQuery.of(context).viewInsets.bottom == 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showAnyTabs)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacing8,
                    left: AppTheme.spacing16,
                    right: AppTheme.spacing16,
                  ),
                  child: _ComposerModeSwitcher(
                    mode: _composerMode,
                    showSketch: showSketchTab,
                    showPlay: showPlayTab,
                    showSignal: showSignalTab,
                    onChanged: (mode) {
                      if (mode == _composerMode) return;
                      ref.read(hapticServiceProvider).trigger(HapticType.light);
                      setState(() {
                        _composerMode = mode;
                        // Drafts are intentionally NOT cleared here:
                        // both _textController and _sketchDraft live
                        // on the State so switching tabs preserves
                        // both compose surfaces.
                      });
                      // Keyboard focus tracks the active mode. The
                      // request runs in a post-frame callback because
                      // the text input is wrapped in a Visibility that
                      // doesn't flip its `visible` flag until the
                      // rebuild after this setState — calling
                      // requestFocus inside setState lands on a still-
                      // hidden widget and iOS silently drops it.
                      if (mode == _SipDmComposerMode.text) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _inputFocusNode.requestFocus();
                        });
                      } else {
                        _inputFocusNode.unfocus();
                      }
                      // Reveal the latest bubble of the selected
                      // medium so the chip tap both opens the
                      // composer surface AND points at the running
                      // conversation in that medium. Play has its
                      // own dedicated "Jump to game" banner inside
                      // the play composer panel, so the chip stays
                      // a pure mode switch there. Text never lands
                      // anywhere — the user has the typing cursor.
                      switch (mode) {
                        case _SipDmComposerMode.text:
                        case _SipDmComposerMode.play:
                          break;
                        case _SipDmComposerMode.sketch:
                          _jumpToLatestWhere(
                            (e) => e.contentType == SipDmContentType.ink,
                          );
                        case _SipDmComposerMode.signal:
                          _jumpToLatestWhere(
                            (e) => e.contentType == SipDmContentType.signal,
                          );
                      }
                    },
                  ),
                ),
              // Composer mode body — IndexedStack so every currently-
              // visible panel stays mounted while only one is shown.
              // This preserves Signal phrase / tap-Morse / type-Morse
              // drafts (and play / sketch state) across tab toggles
              // without lifting all that state up to this State class.
              //
              // The children list is rebuilt only when tab visibility
              // changes (peer goes blocked, session closed, etc.) — a
              // mode toggle within the same visibility config keeps
              // every child's Element identity intact, so each panel's
              // State survives.
              _buildComposerStack(
                context: context,
                session: session,
                enabled: enabled,
                showSketchTab: showSketchTab,
                showPlayTab: showPlayTab,
                showSignalTab: showSignalTab,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scroll the message list to the latest SIP Play bubble and
  /// briefly pulse the highlight halo on it. Routes through the
  /// shared [_jumpToLatestWhere] pipeline so the Play "Jump to game"
  /// banner gets the same find→ensureVisible→highlight treatment
  /// every other chip jump uses.
  void _jumpToLatestPlayBubble() {
    _jumpToLatestWhere((e) => e.contentType == SipDmContentType.play);
  }

  /// Build the composer body. Every currently-visible mode is kept
  /// mounted (so its State persists across tab toggles), but
  /// invisible panels take zero layout space.
  ///
  /// Why not `IndexedStack`: that primitive sizes the stack to the
  /// tallest child, so the chat list would shrink to leave room for
  /// the (hidden) Signal keypad even in Text mode. `Visibility` with
  /// `maintainState: true` solves both halves — the StatefulElement
  /// for each panel stays alive (drafts survive: phrase notes,
  /// tap-Morse buffer, sketch strokes), but `visible: false` swaps
  /// the rendered subtree for `SizedBox.shrink()` so layout collapses
  /// to the active panel only.
  ///
  /// The text input is always present (no peer-cap gate). The other
  /// panels mount only when their tab is visible. If the current
  /// `_composerMode` points to a tab that just got hidden (peer
  /// blocked, session closed), the auto-fallback in `_buildInputBar`
  /// already routes back to text — this widget just renders whatever
  /// `_composerMode` says.
  Widget _buildComposerStack({
    required BuildContext context,
    required SipDmSession? session,
    required bool enabled,
    required bool showSketchTab,
    required bool showPlayTab,
    required bool showSignalTab,
  }) {
    final isText = _composerMode == _SipDmComposerMode.text;
    final isSketch = _composerMode == _SipDmComposerMode.sketch;
    final isPlay = _composerMode == _SipDmComposerMode.play;
    final isSignal = _composerMode == _SipDmComposerMode.signal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Visibility(
          visible: isText,
          maintainState: true,
          child: _buildTextInputBlock(context, enabled),
        ),
        if (showSketchTab)
          Visibility(
            visible: isSketch,
            maintainState: true,
            child: SipInkComposer(
              sessionTag: widget.sessionTag,
              enabled: enabled,
              draft: _sketchDraft,
              onDraftChanged: () {
                if (mounted) setState(() {});
              },
              onSent: _scrollToBottom,
            ),
          ),
        if (showPlayTab)
          Visibility(
            visible: isPlay,
            maintainState: true,
            child: _PlayComposerPanel(
              sessionTag: widget.sessionTag,
              peerNodeId: session!.peerNodeId,
              onJumpToLatestGame: _jumpToLatestPlayBubble,
            ),
          ),
        if (showSignalTab)
          Visibility(
            visible: isSignal,
            maintainState: true,
            child: SipSignalComposerPanel(
              sessionTag: widget.sessionTag,
              onSubModeChanged: (kind) {
                _jumpToLatestWhere((e) {
                  if (e.contentType != SipDmContentType.signal) return false;
                  final payload = e.payload;
                  if (payload == null || payload.isEmpty) return false;
                  final result = SipSignalCodec.decode(
                    Uint8List.fromList(payload),
                  );
                  return result.isOk && result.envelope!.kind == kind;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTextInputBlock(BuildContext context, bool enabled) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply indicator (animated slide-in)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _replyingToEntry != null
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing8,
                  ),
                  color: context.accentColor.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: context.accentColor),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.sipDmReplyingTo,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.accentColor,
                              ),
                            ),
                            Text(
                              _replyingQuoteText(_replyingToEntry!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Input field — reuses ChatComposer for consistent UX
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing8,
          ),
          child: ChatComposer(
            controller: _messageController,
            focusNode: _inputFocusNode,
            onSend: _sendMessage,
            hintText: l10n.sipDmInputHint,
            maxLength: SipDmConstants.maxDmTextBytes,
            maxLines: 4,
            enabled: enabled,
            sendTooltip: l10n.sipDmSendButton,
            budgetResolver: _measureSipDmBudget,
            budgetLabelBuilder: (context, budget) =>
                context.l10n.messagingComposerByteCounter(
                  budget.utf8Bytes,
                  budget.maxUtf8Bytes,
                ),
          ),
        ),
      ],
    );
  }
}

/// Inline Play composer panel — shown when the user selects the Play
/// tab in the DM composer mode switcher.
///
/// Pure UI dispatcher:
///   - "Play a game" header + airtime-friendly subtitle,
///   - Tic-Tac-Toe card with supporting copy + a "7 B moves" badge
///     calling out the move payload size,
///   - "Game in progress" banner with a Jump-to-game affordance when
///     a non-terminal SIP Play instance exists in this session,
///   - Tap on the TTT card opens the existing `SipPlayPicker` sheet
///     (which is what dispatches the offer through the router).
///
/// The panel never sends anything itself and never mutates engine
/// state. It strictly orchestrates UI dispatch into existing surfaces.
class _PlayComposerPanel extends ConsumerWidget {
  final int sessionTag;
  final int peerNodeId;

  /// Called when the user taps "Jump to game" — the parent screen
  /// scrolls the chat to the latest play bubble.
  final VoidCallback onJumpToLatestGame;

  const _PlayComposerPanel({
    required this.sessionTag,
    required this.peerNodeId,
    required this.onJumpToLatestGame,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Watch the play instance ids for this session so the
    // "Game in progress" banner reacts in real time. Banner shows
    // ONLY when at least one instance is in the `active` state —
    // a `pendingOffer` is not "in progress" yet (the peer hasn't
    // accepted) and a "Jump to game" affordance there is misleading.
    // Terminal instances (declined / resigned / won / draw) don't
    // qualify either.
    final instanceIds = ref.watch(sipPlayInstanceIdsProvider(sessionTag));
    final hasActiveInstance = instanceIds.any((id) {
      final state = ref.read(
        sipPlayInstanceStateProvider((sessionTag: sessionTag, instanceId: id)),
      );
      return state != null && state.status == SipPlayInstanceStatus.active;
    });

    // Focus mode: when a non-terminal SIP Play instance exists in
    // this session, the panel collapses to ONLY the resume banner.
    // Hides the "Play a game" header, subtitle, and Tic-Tac-Toe card
    // so the visible composer area shrinks and the active board
    // bubble (which lives inline in the chat timeline) stays
    // unobscured. Also prevents starting a duplicate game while one
    // is in flight — the registry's "one active per peer" rule.
    if (hasActiveInstance) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing12,
          AppTheme.spacing16,
          AppTheme.spacing12,
        ),
        child: _GameInProgressBanner(onJump: onJumpToLatestGame),
      );
    }

    // Default mode: header + subtitle + game cards (currently just
    // Tic-Tac-Toe). Visible only when no active game exists.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.sipPlayPanelTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.sipPlayPanelSubtitle,
            style: TextStyle(fontSize: 12, color: context.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _TicTacToeCard(
            onTap: () => showSipPlayPicker(
              context: context,
              ref: ref,
              sessionTag: sessionTag,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicTacToeCard extends StatelessWidget {
  final VoidCallback onTap;
  const _TicTacToeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.background.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radius10),
              ),
              child: Icon(Icons.grid_3x3, size: 20, color: context.accentColor),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Title is Flexible so the longer
                      // "Tiny moves • ~7 bytes" badge can't push it
                      // off-screen on narrow devices (iPhone SE).
                      Flexible(
                        child: Text(
                          l10n.sipPlayGameTicTacToe,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      _SizeBadge(label: l10n.sipPlayPanelTttSizeBadge),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    l10n.sipPlayPanelTttSupporting,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SizeBadge extends StatelessWidget {
  final String label;
  const _SizeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.accentColor,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _GameInProgressBanner extends StatelessWidget {
  final VoidCallback onJump;
  const _GameInProgressBanner({required this.onJump});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, size: 18, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sipPlayPanelGameInProgressTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  l10n.sipPlayPanelGameInProgressBody,
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          TextButton(
            onPressed: onJump,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing4,
              ),
              minimumSize: const Size(0, 28),
            ),
            child: Text(
              l10n.sipPlayPanelGameInProgressJump,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic equal-width segmented switcher for the DM composer modes.
///
/// Renders Text + whichever non-text modes the peer + safety state
/// makes available:
///   - Sketch when the peer advertises dmInkV1,
///   - Play when the peer advertises dmPlayV1 AND is not blocked
///     AND the session is active.
///
/// The selected segment is filled with the accent colour; the others
/// are transparent. Hide-when-unsupported gating mirrors today's
/// behaviour — peers without any non-text capability see no switcher
/// at all (the parent collapses it).
class _ComposerModeSwitcher extends StatelessWidget {
  final _SipDmComposerMode mode;
  final ValueChanged<_SipDmComposerMode> onChanged;
  final bool showSketch;
  final bool showPlay;
  final bool showSignal;

  const _ComposerModeSwitcher({
    required this.mode,
    required this.onChanged,
    required this.showSketch,
    required this.showPlay,
    required this.showSignal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Row(
        children: [
          _segment(
            context,
            _SipDmComposerMode.text,
            l10n.sipDmComposerModeText,
          ),
          if (showSketch)
            _segment(
              context,
              _SipDmComposerMode.sketch,
              l10n.sipDmComposerModeSketch,
            ),
          if (showPlay)
            _segment(
              context,
              _SipDmComposerMode.play,
              l10n.sipDmComposerModePlay,
            ),
          if (showSignal)
            _segment(
              context,
              _SipDmComposerMode.signal,
              l10n.sipDmComposerModeSignal,
            ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    _SipDmComposerMode value,
    String label,
  ) {
    final isSelected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? context.accentColor : context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Session info bar delegate — frosted-glass pinned header (Signals pattern)
// =============================================================================

/// Blur sigma for the frosted-glass effect on the pinned session bar.
const double _kInfoBarBlurSigma = 20.0;

/// Background opacity for the frosted-glass container.
const double _kInfoBarBackgroundAlpha = 0.8;

// =============================================================================
// First-contact banner — only shown when the local user hasn't yet
// explicitly accepted a handshake from this peer (e.g. they initiated
// the handshake themselves) AND hasn't tapped to dismiss the banner.
//
// Tap-to-dismiss persists locally via [FirstContactBannerDismissals]
// (SharedPreferences). Dismissal does NOT mutate any protocol state
// — it never calls markFirstHandshake, never changes the safety
// state, never sends any wire frame.
// =============================================================================

class _FirstContactBanner extends ConsumerWidget {
  final int peerNodeId;

  const _FirstContactBanner({required this.peerNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the manager state so the banner disappears immediately
    // once the user accepts a handshake (which sets hasFirstContact).
    ref.watch(peerSafetyManagerProvider);
    ref.watch(firstContactBannerDismissalsProvider);

    final mgr = ref.read(peerSafetyManagerProvider.notifier);
    final dismissals = ref.read(firstContactBannerDismissalsProvider.notifier);

    final hasFirstContact = mgr.hasFirstContact(peerNodeId);
    final isDismissed = dismissals.isDismissed(peerNodeId);
    if (hasFirstContact || isDismissed) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        0,
      ),
      child: StatusBanner.warning(
        title: l10n.sipDmFirstContactBannerTitle,
        subtitle: l10n.sipDmFirstContactBannerBody,
        icon: Icons.shield_outlined,
        onTap: () {
          ref.read(hapticServiceProvider).trigger(HapticType.light);
          dismissals.dismiss(peerNodeId);
        },
        onDismiss: () {
          ref.read(hapticServiceProvider).trigger(HapticType.light);
          dismissals.dismiss(peerNodeId);
        },
      ),
    );
  }
}

// =============================================================================
// Session info bar content — sigil + hex ID + status badge
// =============================================================================

class _SessionInfoBar extends ConsumerWidget {
  final SipDmSession session;

  const _SessionInfoBar({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = ref.watch(nodeDexEntryProvider(session.peerNodeId));
    final patinaResult = ref.watch(nodeDexPatinaProvider(session.peerNodeId));
    final traitResult = ref.watch(nodeDexTraitProvider(session.peerNodeId));
    final hexId =
        '!${session.peerNodeId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: [
          // Sigil avatar (small) with evolution — tap to view NodeDex
          GestureDetector(
            onTap: () {
              ref.read(hapticServiceProvider).trigger(HapticType.light);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      NodeDexDetailScreen(nodeNum: session.peerNodeId),
                ),
              );
            },
            child: _buildSmallAvatar(context, entry, patinaResult, traitResult),
          ),
          const SizedBox(width: AppTheme.spacing10),

          // Hex ID
          Expanded(
            child: Text(
              hexId,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),

          // Expiry badge
          _buildStatusBadge(context, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, dynamic l10n) {
    final expiryText = l10n.sipDmExpiry(_formatTtl(session));
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 11, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            expiryText,
            style: TextStyle(fontSize: 11, color: context.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAvatar(
    BuildContext context,
    NodeDexEntry? entry,
    PatinaResult patinaResult,
    TraitResult traitResult,
  ) {
    if (entry?.sigil != null) {
      return SigilAvatar(
        sigil: entry!.sigil,
        nodeNum: session.peerNodeId,
        size: 32,
        evolution: SigilEvolution.fromPatina(
          patinaResult.score,
          trait: traitResult.primary,
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Icon(
        Icons.sensors,
        size: 16,
        color: context.accentColor.withValues(alpha: 0.7),
      ),
    );
  }

  static String _formatTtl(SipDmSession session) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = session.createdAtMs + (session.ttlS * 1000);
    final remainingS = ((expiresAtMs - nowMs) / 1000).clamp(0, double.infinity);

    if (remainingS > 3600) {
      return '${(remainingS / 3600).floor()}h';
    } else if (remainingS > 60) {
      return '${(remainingS / 60).floor()}m';
    } else {
      return '${remainingS.floor()}s';
    }
  }
}

// =============================================================================
// Message bubble — semantic colors with proper card styling
// =============================================================================

class _MessageBubble extends ConsumerWidget {
  final SipDmHistoryEntry entry;
  final int peerNodeId;

  /// SIP DM session tag — only consumed by the SIP Play branch so
  /// the play bubble can dispatch moves through the router. Threaded
  /// here rather than reading from a provider so the bubble has no
  /// hidden lookup paths.
  final int sessionTag;

  /// True when the user just tapped a reply quote pointing at this
  /// bubble — paints a brief accent halo to draw the eye to it.
  final bool isHighlighted;

  /// Tap handler for the quoted-reply block. Null when this bubble
  /// isn't a reply (no quote is rendered).
  final VoidCallback? onReplyQuoteTap;

  const _MessageBubble({
    required this.entry,
    required this.peerNodeId,
    required this.sessionTag,
    this.isHighlighted = false,
    this.onReplyQuoteTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutbound = entry.direction == SipDmDirection.outbound;
    final replyTo = entry.replyToText;
    final bodyText = SipDmManager.extractReplyBody(entry.text);
    final hasReactions =
        entry.localReaction != null || entry.peerReaction != null;
    final isInk =
        entry.contentType == SipDmContentType.ink && entry.payload != null;
    final isPlay =
        entry.contentType == SipDmContentType.play && entry.payload != null;
    final isSignal =
        entry.contentType == SipDmContentType.signal && entry.payload != null;

    if (isPlay) {
      // SIP Play bubble owns its own status / board / controls. It
      // skips the reactions row and reply-quote affordances — games
      // are not reaction targets in v1. Terminal-decline cards get
      // an explicit dismiss button that removes the offer entry from
      // session history; the instance-id provider is offer-gated, so
      // dropping the offer effectively retires the whole instance
      // from the timeline + Play tab.
      return SipPlayBubble(
        sessionTag: sessionTag,
        peerNodeId: peerNodeId,
        entryPayload: entry.payload!,
        entryTimestampMs: entry.timestampMs,
        onDismiss: () {
          ref.read(sipDmManagerProvider)?.removeMessage(sessionTag, entry);
        },
      );
    }

    if (isSignal) {
      // SIP Signal bubble shows phrase or Morse + Replay. Skips
      // reactions / reply quote affordances.
      return Align(
        alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: SipSignalBubble(
            entryPayload: entry.payload!,
            isOutbound: isOutbound,
          ),
        ),
      );
    }

    return Align(
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isOutbound
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Bubble body — wrapped in the highlight halo (border + blink
              // + shake). Reactions are deliberately OUTSIDE the halo so
              // the accent ring frames the message itself, not the
              // floating reaction pill below it.
              if (isInk)
                Column(
                  crossAxisAlignment: isOutbound
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    _HighlightHalo(
                      isHighlighted: isHighlighted,
                      child: SipInkBubble(
                        payload: entry.payload!,
                        isOutbound: isOutbound,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      _formatTime(context, entry.timestampMs),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                )
              else
                _HighlightHalo(
                  isHighlighted: isHighlighted,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing8,
                    ),
                    decoration: BoxDecoration(
                      color: isOutbound
                          ? context.accentColor.withValues(alpha: 0.15)
                          : context.card,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppTheme.radius12),
                        topRight: const Radius.circular(AppTheme.radius12),
                        bottomLeft: isOutbound
                            ? const Radius.circular(AppTheme.radius12)
                            : const Radius.circular(AppTheme.radius4),
                        bottomRight: isOutbound
                            ? const Radius.circular(AppTheme.radius4)
                            : const Radius.circular(AppTheme.radius12),
                      ),
                      border: isOutbound
                          ? null
                          : Border.all(
                              color: context.border.withValues(alpha: 0.5),
                            ),
                    ),
                    child: Column(
                      crossAxisAlignment: isOutbound
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Quoted reply block — tappable, jumps to /
                        // glows the original message when matched.
                        if (replyTo != null) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onReplyQuoteTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing8,
                                vertical: AppTheme.spacing4,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: context.accentColor,
                                    width: 2,
                                  ),
                                ),
                                color: context.accentColor.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                              child: Text(
                                replyTo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                        ],
                        Text(
                          bodyText,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          _formatTime(context, entry.timestampMs),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Reaction row — Telegram-style pills below the bubble.
              // Intentionally rendered outside _HighlightHalo so taps on a
              // reply quote frame the original message, not its reactions.
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: isOutbound
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: hasReactions
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacing4),
                        child: _buildReactionRow(context, ref, isOutbound),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionRow(
    BuildContext context,
    WidgetRef ref,
    bool isOutbound,
  ) {
    // Same emoji from both users — single pill with both sigils.
    if (entry.localReaction != null &&
        entry.peerReaction != null &&
        entry.localReaction == entry.peerReaction) {
      final emoji = SipDmReactionEmojis.all[entry.localReaction!];
      final myNodeNum = ref.watch(myNodeNumProvider);
      final myNdxEntry = myNodeNum != null
          ? ref.watch(nodeDexEntryProvider(myNodeNum))
          : null;
      final myPatinaResult = myNodeNum != null
          ? ref.watch(nodeDexPatinaProvider(myNodeNum))
          : null;
      final myTraitResult = myNodeNum != null
          ? ref.watch(nodeDexTraitProvider(myNodeNum))
          : null;
      final peerNdxEntry = ref.watch(nodeDexEntryProvider(peerNodeId));
      final peerPatinaResult = ref.watch(nodeDexPatinaProvider(peerNodeId));
      final peerTraitResult = ref.watch(nodeDexTraitProvider(peerNodeId));
      return _reactionPill(
        context,
        tint: context.accentColor.withValues(alpha: 0.12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (myNdxEntry?.sigil != null && myNodeNum != null) ...[
              SigilAvatar(
                sigil: myNdxEntry!.sigil,
                nodeNum: myNodeNum,
                size: 18,
                evolution: SigilEvolution.fromPatina(
                  myPatinaResult?.score ?? 0,
                  trait: myTraitResult?.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
            ],
            if (peerNdxEntry?.sigil != null) ...[
              SigilAvatar(
                sigil: peerNdxEntry!.sigil,
                nodeNum: peerNodeId,
                size: 18,
                evolution: SigilEvolution.fromPatina(
                  peerPatinaResult.score,
                  trait: peerTraitResult.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
            ],
            Text(emoji, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    // Different emojis or single reaction.
    final pills = <Widget>[];

    if (entry.localReaction != null) {
      final emoji = SipDmReactionEmojis.all[entry.localReaction!];
      final myNodeNum = ref.watch(myNodeNumProvider);
      final myNdxEntry = myNodeNum != null
          ? ref.watch(nodeDexEntryProvider(myNodeNum))
          : null;
      final myPatinaResult = myNodeNum != null
          ? ref.watch(nodeDexPatinaProvider(myNodeNum))
          : null;
      final myTraitResult = myNodeNum != null
          ? ref.watch(nodeDexTraitProvider(myNodeNum))
          : null;

      pills.add(
        _reactionPill(
          context,
          tint: context.accentColor.withValues(alpha: 0.12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (myNdxEntry?.sigil != null && myNodeNum != null) ...[
                SigilAvatar(
                  sigil: myNdxEntry!.sigil,
                  nodeNum: myNodeNum,
                  size: 18,
                  evolution: SigilEvolution.fromPatina(
                    myPatinaResult?.score ?? 0,
                    trait: myTraitResult?.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing2),
              ],
              Text(emoji, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (entry.peerReaction != null) {
      final emoji = SipDmReactionEmojis.all[entry.peerReaction!];
      final ndxEntry = ref.watch(nodeDexEntryProvider(peerNodeId));
      final patinaResult = ref.watch(nodeDexPatinaProvider(peerNodeId));
      final traitResult = ref.watch(nodeDexTraitProvider(peerNodeId));

      pills.add(
        _reactionPill(
          context,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ndxEntry?.sigil != null) ...[
                SigilAvatar(
                  sigil: ndxEntry!.sigil,
                  nodeNum: peerNodeId,
                  size: 18,
                  evolution: SigilEvolution.fromPatina(
                    patinaResult.score,
                    trait: traitResult.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing2),
              ],
              Text(emoji, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.spacing4),
          pills[i],
        ],
      ],
    );
  }

  Widget _reactionPill(
    BuildContext context, {
    required Widget child,
    Color? tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: tint ?? context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatTime(BuildContext context, int ms) {
    // Use MaterialLocalizations via TimeOfDay.format(context). This
    // respects the user's locale (en_US -> "3:43 PM", de_DE -> "15:43",
    // etc.) AND the platform 24-hour preference reported by
    // MediaQuery.alwaysUse24HourFormat. No hand-rolled padding,
    // no AM/PM heuristics.
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return TimeOfDay.fromDateTime(dt).format(context);
  }
}

// =============================================================================
// Highlight halo — accent-blink + damped-shake wrapper used to draw the eye
// to a message bubble after the user taps a reply quote pointing at it.
// Always reserves a 1.5px border so layout doesn't jump when triggered.
// =============================================================================

class _HighlightHalo extends StatefulWidget {
  final bool isHighlighted;
  final Widget child;

  const _HighlightHalo({required this.isHighlighted, required this.child});

  @override
  State<_HighlightHalo> createState() => _HighlightHaloState();
}

class _HighlightHaloState extends State<_HighlightHalo>
    with SingleTickerProviderStateMixin {
  // Total halo duration: shake settles in the first ~360ms, border blinks
  // for the full 1200ms (3 pulses) so the user has time to register the
  // jump after the list scrolls into view.
  static const Duration _haloDuration = Duration(milliseconds: 1200);
  static const double _shakeWindow = 0.30; // first 30% of the timeline
  static const double _shakeAmplitude = 4.0;
  static const int _blinkPulses = 3;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _haloDuration);
    if (widget.isHighlighted) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _HighlightHalo old) {
    super.didUpdateWidget(old);
    if (widget.isHighlighted && !old.isHighlighted) {
      _controller.forward(from: 0);
    } else if (!widget.isHighlighted && old.isHighlighted) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final active = widget.isHighlighted;

        // Damped horizontal sine confined to the first _shakeWindow of the
        // timeline, then settles to zero.
        final shake = active && t < _shakeWindow
            ? math.sin((t / _shakeWindow) * math.pi * 3) *
                  _shakeAmplitude *
                  (1 - t / _shakeWindow)
            : 0.0;

        // Blink: |sin(t·π·N)| gives N pulses across [0,1]. Final pulse
        // fades naturally as the controller completes.
        final blink = active ? math.sin(t * math.pi * _blinkPulses).abs() : 0.0;

        return Transform.translate(
          offset: Offset(shake, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(
                color: context.accentColor.withValues(alpha: blink),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// =============================================================================
// Typing indicator — animated bouncing dots (iMessage-style)
// =============================================================================

class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble();

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radius12),
            topRight: Radius.circular(AppTheme.radius12),
            bottomLeft: Radius.circular(AppTheme.radius4),
            bottomRight: Radius.circular(AppTheme.radius12),
          ),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                // Stagger each dot by 0.2 of the animation cycle.
                final delay = index * 0.2;
                final value = ((_controller.value - delay) % 1.0).clamp(
                  0.0,
                  1.0,
                );
                // Bounce: 0→1→0 as a sin curve over a portion of the cycle.
                final bounce = value < 0.5
                    ? (value * 2.0) // ramp up
                    : value < 0.7
                    ? 1.0 -
                          ((value - 0.5) * 5.0) // ramp down
                    : 0.0;

                return Padding(
                  padding: EdgeInsets.only(
                    right: index < 2 ? AppTheme.spacing4 : 0,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, -4 * bounce.clamp(0.0, 1.0)),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.textTertiary.withValues(
                          alpha: 0.4 + (0.4 * bounce.clamp(0.0, 1.0)),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
