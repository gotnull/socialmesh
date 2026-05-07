// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../core/l10n/l10n_extension.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/meshcore_constants.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/chat_bubble_text.dart';
import '../../../core/widgets/chat_composer.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/jump_to_latest_pill.dart';
import '../../../core/widgets/linkified_text.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_channel.dart';
import '../contact_l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../providers/meshcore_message_providers.dart';
import '../../../services/meshcore/protocol/meshcore_chat_meta_envelope.dart';
import '../../../services/meshcore/protocol/meshcore_frame.dart';
import '../../../services/meshcore/storage/meshcore_message_store.dart';
import '../parsers/meshcore_message_frame_parser.dart';
import '../../../services/meshcore/storage/meshcore_contact_store.dart';
import '../../../utils/snackbar.dart';

/// Types of MeshCore chat conversations.
enum MeshCoreChatType { contact, channel }

/// Firmware ack code the app waits for after sending a text message,
/// keyed by chat type. Channels are flooded with no per-recipient
/// confirmation and the firmware returns RESP_CODE_OK (0x00) with an
/// empty payload. Contact messages return RESP_CODE_SENT (0x06) with
/// a 9-byte payload (expected_ack_hash + est_time_to_send); the routed
/// delivery ack arrives separately as PUSH_CODE_SEND_CONFIRMED (0x82).
///
/// Visible for testing so the wire-level mapping is regression-pinned
/// independently of the widget tree.
@visibleForTesting
int meshCoreExpectedSendResponseCode(MeshCoreChatType chatType) {
  switch (chatType) {
    case MeshCoreChatType.contact:
      return MeshCoreResponses.sent;
    case MeshCoreChatType.channel:
      return MeshCoreResponses.ok;
  }
}

/// True when [status] represents a successful delivery state that must
/// not be downgraded by a late timeout. Used to make `_markMessageFailed`
/// idempotent so a 5s timeout firing AFTER a routed-ack already flipped
/// the bubble to `delivered` (or after firmware-OK flipped it to `sent`)
/// does not stomp the success state. Pre-D14 the failure path was
/// unconditional and clobbered confirmed deliveries.
@visibleForTesting
bool meshCoreIsTerminalDeliveryStatus(MeshCoreMessageDeliveryStatus status) {
  return status == MeshCoreMessageDeliveryStatus.sent ||
      status == MeshCoreMessageDeliveryStatus.delivered;
}

/// True when [status] is an outgoing-message state that a routed-ack
/// 0x82 is allowed to flip to `delivered`. Pre-D14 only `pending`
/// matched, which silently dropped routed-acks for any contact message
/// that had already transitioned `pending` -> `sent` on RESP_CODE_SENT.
@visibleForTesting
bool meshCoreIsUnconfirmedOutgoingStatus(MeshCoreMessageDeliveryStatus status) {
  return status == MeshCoreMessageDeliveryStatus.pending ||
      status == MeshCoreMessageDeliveryStatus.sent;
}

/// MeshCore Chat Screen - for messaging contacts or channels.
class MeshCoreChatScreen extends ConsumerStatefulWidget {
  final MeshCoreChatType chatType;
  final MeshCoreContact? contact;
  final MeshCoreChannel? channel;
  @visibleForTesting
  final List<MeshCoreMessage> initialMessages;

  const MeshCoreChatScreen.contact({
    super.key,
    required MeshCoreContact this.contact,
    @visibleForTesting this.initialMessages = const [],
  }) : chatType = MeshCoreChatType.contact,
       channel = null;

  const MeshCoreChatScreen.channel({
    super.key,
    required MeshCoreChannel this.channel,
    @visibleForTesting this.initialMessages = const [],
  }) : chatType = MeshCoreChatType.channel,
       contact = null;

  @override
  ConsumerState<MeshCoreChatScreen> createState() => _MeshCoreChatScreenState();
}

class _MeshCoreChatScreenState extends ConsumerState<MeshCoreChatScreen>
    with LifecycleSafeMixin<MeshCoreChatScreen> {
  void _dismissKeyboard() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
  }

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<MeshCoreMessage> _messages = [];
  bool _isSending = false;
  bool _isLoading = true;
  StreamSubscription<MeshCoreFrame>? _frameSubscription;
  final MeshCoreMessageStore _messageStore = MeshCoreMessageStore();
  final MeshCoreContactStore _contactStore = MeshCoreContactStore();

  /// D30: jump-to-latest pill visibility. True when the user has
  /// scrolled the message list up far enough that they're no longer
  /// reading the bottom (most-recent) entry. Mirrors the SIP DM screen.
  bool _showJumpToLatest = false;

  /// Distance in pixels from the bottom within which we still consider
  /// the user "at the latest". Mirrors the SIP DM threshold so the
  /// affordance feels consistent across chat surfaces.
  static const double _atBottomThresholdPx = 120;

  /// D33: source message the user is currently composing a reply to.
  /// Null when the composer is not in reply mode. Set by the long-press
  /// Reply action, cleared by Cancel reply, by a successful send, or
  /// when the source message disappears (e.g. local-delete).
  MeshCoreMessage? _replyingTo;

  String get _conversationId {
    if (widget.chatType == MeshCoreChatType.contact) {
      return widget.contact!.publicKeyHex;
    } else {
      return 'channel_${widget.channel!.index}';
    }
  }

  String get _title {
    if (widget.chatType == MeshCoreChatType.contact) {
      // D23: prefer the contact's `displayName` getter, which falls
      // through to the redacted pubkey fingerprint
      // (`<79426d8d…0831782b>`) when the firmware entry has an empty
      // name. Only the rare empty-name + empty-pubkey case lands on
      // the localized "Unknown" placeholder.
      final display = widget.contact!.displayName;
      return display.isNotEmpty
          ? display
          : context.l10n.meshcoreContactUnknownName;
    } else {
      return widget.channel!.displayName;
    }
  }

  Color get _accentColor {
    if (widget.chatType == MeshCoreChatType.contact) {
      return AccentColors.cyan;
    } else {
      return AccentColors.purple;
    }
  }

  @override
  void initState() {
    super.initState();
    AppLogging.meshcore(
      'event=screen.opened name=chat '
      'type=${widget.chatType == MeshCoreChatType.contact ? "contact" : "channel"}',
    );
    _scrollController.addListener(_onScroll);
    if (widget.initialMessages.isNotEmpty) {
      _messages.addAll(widget.initialMessages);
      _isLoading = false;
    } else {
      _loadMessages();
    }
    _subscribeToIncomingMessages();
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// D30: toggle [_showJumpToLatest] based on scroll position relative
  /// to the bottom of the message list.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    final shouldShow = distanceFromBottom > _atBottomThresholdPx;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  /// D30: tap handler for the jump-to-latest pill.
  void _jumpToLatest() {
    HapticFeedback.lightImpact();
    _scrollToBottom();
    if (mounted) {
      setState(() => _showJumpToLatest = false);
    }
  }

  Future<void> _loadMessages() async {
    // Load persisted messages from storage
    setState(() => _isLoading = true);
    try {
      await _messageStore.init();
      await _contactStore.init();

      final storedMessages = widget.chatType == MeshCoreChatType.contact
          ? await _messageStore.loadContactMessages(_conversationId)
          : await _messageStore.loadChannelMessages(widget.channel!.index);

      final messages = storedMessages.map((stored) {
        return MeshCoreMessage(
          id: stored.id,
          text: stored.text,
          timestamp: stored.timestamp,
          isOutgoing: stored.isOutgoing,
          status: _convertStatus(stored.status),
          senderKey: stored.senderKey,
          pathLength: stored.pathLength,
          snrQuarter: stored.snrQuarter,
          mmf: stored.mmf,
          replyToMmf: stored.replyToMmf,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
          _isLoading = false;
        });
        // Clear unread count when opening chat. D19.D extends this
        // to channels too: pre-D19 only the contact path called
        // markAsRead, so a channel with unread messages stayed
        // unread forever on the Channels list tile until contact
        // mode also opened. Both paths now mark-read on chat open.
        if (widget.chatType == MeshCoreChatType.contact) {
          await _contactStore.clearUnreadCount(_conversationId);
        }
        ref
            .read(meshCoreConversationsProvider.notifier)
            .markAsRead(_conversationId);
        // Scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      AppLogging.storage('MeshCore Chat: Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToIncomingMessages() {
    // Subscribe to incoming messages from the session
    final session = ref.read(meshCoreSessionProvider);
    if (session != null && session.isActive) {
      _frameSubscription = session.frameStream.listen(_handleIncomingFrame);
    }
  }

  void _handleIncomingFrame(MeshCoreFrame frame) {
    // D17.B note: the unconditional `event=frame.received` tap moved
    // to `MeshCoreSession._onFrameDecoded`. The chat widget no longer
    // emits a duplicate of that event because (a) it would only fire
    // when a chat screen happened to be mounted, masking real bridge
    // failures (see D15), and (b) it produced two log lines per frame.
    // The widget is still the per-handler dispatcher for chat-scoped
    // frames; parse.ok / parse.rejected logs continue to fire here.
    if (widget.chatType == MeshCoreChatType.contact) {
      if (frame.command == MeshCoreResponses.contactMsgRecv ||
          frame.command == MeshCoreResponses.contactMsgRecvV3) {
        _handleIncomingContactMessage(frame);
      }
    } else {
      if (frame.command == MeshCoreResponses.channelMsgRecv ||
          frame.command == MeshCoreResponses.channelMsgRecvV3) {
        _handleIncomingChannelMessage(frame);
      }
    }

    // Push-code visibility. We don't fully wire send-confirmed routing
    // here yet (channel messages never produce one; contact ACK
    // tracking is a separate slice), but at minimum log when the
    // firmware tickles us so the diag bundle proves the radio is alive
    // and the BLE/TCP transport is delivering pushes.
    if (frame.command == MeshCorePushCodes.sendConfirmed) {
      AppLogging.meshcore('event=push.observed code=0x82 name=send_confirmed');
      _handleDeliveryConfirmation(frame);
    } else if (frame.command == MeshCorePushCodes.msgWaiting) {
      AppLogging.meshcore('event=push.observed code=0x83 name=msg_waiting');
    }
  }

  void _handleIncomingContactMessage(MeshCoreFrame frame) {
    final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
    if (!result.ok) {
      AppLogging.meshcore(
        'event=message.parse.rejected scope=contact '
        'code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} '
        'reason=${result.rejectReason}',
        error: true,
      );
      return;
    }
    final parsed = result.value!;

    AppLogging.meshcore(
      'event=message.parse.ok scope=contact '
      'protocol=${parsed.protocol.name} '
      'pathLen=${parsed.pathLen} '
      'txtType=${parsed.txtType} '
      'snrQ=${parsed.snrQuarter ?? "-"} '
      'size=${parsed.text.length}',
    );

    // Match by 6-byte sender prefix. Firmware never sends the full
    // 32-byte pubkey for inbound contact messages, so an exact-equality
    // check against the contact's full publicKeyHex is structurally
    // wrong and was the pre-D12 bug.
    final isMine = MeshCoreMessageFrameParser.senderPrefixMatches(
      contactPublicKeyHex: widget.contact!.publicKeyHex,
      senderPrefixHex: parsed.senderPrefixHex,
    );
    if (!isMine) return;

    // We have the contact's full pubkey on the widget. Preserve it on
    // the persisted message rather than the truncated 6-byte prefix
    // firmware just gave us, so message metadata is consistent with
    // the contacts list.
    final senderKey = widget.contact!.publicKey;

    // D19.B: deterministic id matches the conversations notifier so
    // when the chat reopens later, `_loadMessages` reads from the
    // store and finds the same id (no duplicate bubble vs the
    // transient in-memory entry we add below).
    final stableId = meshCoreInboundContactMessageId(
      senderPrefixHex: parsed.senderPrefixHex,
      timestamp: parsed.timestamp,
      text: parsed.text,
    );

    final message = MeshCoreMessage(
      id: stableId,
      text: parsed.text,
      timestamp: parsed.timestamp,
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: senderKey,
      pathLength: parsed.pathLen,
      snrQuarter: parsed.snrQuarter,
    );

    if (mounted) {
      // D19.B: in-memory only. The conversations notifier owns
      // inbound persistence; calling `_persistMessage` here too
      // would risk a double-write race against the off-frame
      // microtask in the notifier. Both paths use the same
      // deterministic id, so the store dedupes regardless, but
      // not writing twice keeps the diag log surface clean.
      setState(() => _messages.add(message));
      // D30: only auto-scroll when the user is parked at the bottom.
      // Honour the jump-to-latest pill — if it's showing, the user is
      // reading earlier history and we must not yank them away.
      if (!_showJumpToLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    AppLogging.meshcore(
      'event=message.received type=contact size=${parsed.text.length} '
      'sender=${AppLogging.publicKeyFingerprint(senderKey)}',
    );
  }

  void _handleIncomingChannelMessage(MeshCoreFrame frame) {
    final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
    if (!result.ok) {
      // Log + drop. Reason carried so the diag bundle pins which
      // firmware shape we hit (V3 too short, legacy too short,
      // unknown command code). No exception, no UI surface, this is
      // the routine drop path for frames that aren't for us.
      AppLogging.meshcore(
        'event=message.parse.rejected scope=channel '
        'code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} '
        'reason=${result.rejectReason}',
        error: true,
      );
      return;
    }
    final parsed = result.value!;

    AppLogging.meshcore(
      'event=message.parse.ok scope=channel '
      'protocol=${parsed.protocol.name} '
      'channel=${parsed.channelIndex} '
      'pathLen=${parsed.pathLen} '
      'txtType=${parsed.txtType} '
      'snrQ=${parsed.snrQuarter ?? "-"} '
      'size=${parsed.text.length}',
    );

    // Filter to the channel slot the user is currently viewing.
    if (parsed.channelIndex != widget.channel!.index) return;

    // Channel messages never carry sender identity in firmware, so
    // there is no senderKey to populate. The message model field
    // exists but downstream persistence treats empty as "unknown
    // sender" and renders the channel-anonymous bubble.
    //
    // D19.B: deterministic id matches the conversations notifier so
    // the in-memory bubble we add here merges cleanly with the
    // store-persisted entry on next chat reopen. Persistence itself
    // is owned by `MeshCoreConversationsNotifier`; we only update the
    // local UI list here.
    final stableId = meshCoreInboundChannelMessageId(
      channelIndex: parsed.channelIndex,
      timestamp: parsed.timestamp,
      text: parsed.text,
    );
    final message = MeshCoreMessage(
      id: stableId,
      text: parsed.text,
      timestamp: parsed.timestamp,
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: null,
      pathLength: parsed.pathLen,
      snrQuarter: parsed.snrQuarter,
    );

    if (mounted) {
      setState(() => _messages.add(message));
      // D30: respect the jump-to-latest pill — only auto-scroll when
      // the user is already parked at the bottom.
      if (!_showJumpToLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    AppLogging.meshcore(
      'event=message.received type=channel slot=${parsed.channelIndex} '
      'size=${parsed.text.length}',
    );
  }

  void _handleDeliveryConfirmation(MeshCoreFrame frame) {
    // Mark the most recent unacknowledged outgoing message as delivered.
    //
    // After D14, contact sends transition pending -> sent on
    // RESP_CODE_SENT (0x06) before the routed-ack 0x82 arrives, so the
    // confirm handler must accept BOTH `pending` and `sent`. Pre-D14
    // this only matched `pending` and silently dropped routed-acks for
    // any message that had already flipped to `sent`.
    if (mounted && _messages.isNotEmpty) {
      final lastUnconfirmed = _messages.lastIndexWhere(
        (m) => m.isOutgoing && meshCoreIsUnconfirmedOutgoingStatus(m.status),
      );
      if (lastUnconfirmed >= 0) {
        setState(() {
          _messages[lastUnconfirmed] = _messages[lastUnconfirmed].copyWith(
            status: MeshCoreMessageDeliveryStatus.delivered,
          );
        });
        _persistMessage(_messages[lastUnconfirmed]);
      }
    }
  }

  Future<void> _persistMessage(MeshCoreMessage message) async {
    try {
      // Get sender key - for outgoing messages use self, for incoming use the provided key
      final selfInfo = ref.read(meshCoreSelfInfoProvider).selfInfo;
      final senderKey = message.isOutgoing
          ? (selfInfo?.pubKey ?? Uint8List(32))
          : (message.senderKey ?? Uint8List(32));

      final stored = MeshCoreStoredMessage(
        id: message.id,
        senderKey: senderKey,
        text: message.text,
        timestamp: message.timestamp,
        isOutgoing: message.isOutgoing,
        status: _convertToStoredStatus(message.status),
        pathLength: message.pathLength,
        isChannelMessage: widget.chatType == MeshCoreChatType.channel,
        channelIndex: widget.channel?.index,
        snrQuarter: message.snrQuarter,
        // D33: round-trip MMF + replyToMmf so the on-disk record matches
        // the in-memory bubble. On reload, `_loadMessages` reads these
        // back so the reply quote-preview row renders without re-decoding.
        mmf: message.mmf,
        replyToMmf: message.replyToMmf,
      );

      if (widget.chatType == MeshCoreChatType.contact) {
        await _messageStore.addContactMessage(_conversationId, stored);
      } else {
        await _messageStore.addChannelMessage(widget.channel!.index, stored);
      }
    } catch (e) {
      AppLogging.storage('MeshCore Chat: Error persisting message: $e');
    }
  }

  MeshCoreMessageDeliveryStatus _convertStatus(MeshCoreMessageStatus status) {
    switch (status) {
      case MeshCoreMessageStatus.pending:
        return MeshCoreMessageDeliveryStatus.pending;
      case MeshCoreMessageStatus.sent:
        return MeshCoreMessageDeliveryStatus.sent;
      case MeshCoreMessageStatus.delivered:
        return MeshCoreMessageDeliveryStatus.delivered;
      case MeshCoreMessageStatus.failed:
        return MeshCoreMessageDeliveryStatus.failed;
    }
  }

  MeshCoreMessageStatus _convertToStoredStatus(
    MeshCoreMessageDeliveryStatus status,
  ) {
    switch (status) {
      case MeshCoreMessageDeliveryStatus.pending:
        return MeshCoreMessageStatus.pending;
      case MeshCoreMessageDeliveryStatus.sent:
        return MeshCoreMessageStatus.sent;
      case MeshCoreMessageDeliveryStatus.delivered:
        return MeshCoreMessageStatus.delivered;
      case MeshCoreMessageDeliveryStatus.failed:
        return MeshCoreMessageStatus.failed;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // D33: lock in one wire timestamp so the same value lands in BOTH
    // the wire frame's timestamp field AND the outbound MMF. Receivers
    // echo the wire timestamp verbatim, so as long as we use the same
    // integer at both places, the receiver-derived MMF matches our
    // outbound MMF byte-for-byte.
    final now = DateTime.now();
    final timestampS = now.millisecondsSinceEpoch ~/ 1000;
    // D33: nullable when self pubkey isn't yet loaded (rare; chat
    // can't be opened pre-identification). Persisting `mmf=null` is
    // fine — the message just doesn't participate in the reply MMF
    // index until the next send/load cycle stamps it.
    final ownMmf = _outboundMmfFor(timestampS)?.toStableString();

    // D33: snapshot reply state and clear UI state up-front so a quick
    // re-tap on Send doesn't double-send into the same reply.
    final replyTarget = _replyingTo;

    final message = MeshCoreMessage(
      id: now.millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: now,
      isOutgoing: true,
      status: MeshCoreMessageDeliveryStatus.pending,
      mmf: ownMmf,
      replyToMmf: replyTarget?.mmf,
    );

    setState(() {
      _messages.add(message);
      _messageController.clear();
      _replyingTo = null;
    });

    // Persist immediately as pending so a kill-mid-send still surfaces
    // the bubble after relaunch.
    await _persistMessage(message);

    // First send goes straight to the bottom. Retry (which calls
    // `_doSend` directly) skips this so we don't fight the user's
    // scroll position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });

    await _doSend(message, timestampS: timestampS, replyTarget: replyTarget);
  }

  /// D33: compute the outbound MMF for a message stamped at
  /// [timestampS] (Unix-epoch seconds). Channel scope uses the
  /// channel index; contact scope uses the FIRST 6 BYTES of the
  /// **author's** (i.e. self's) public key. Receivers observe the
  /// same prefix verbatim in the wire frame's `senderPrefix` field,
  /// so receiver-derived inbound MMFs (which use that senderPrefix)
  /// match the author's outbound MMF byte-for-byte.
  ///
  /// Pre-fix this used `widget.contact!.publicKey.sublist(0, 6)` —
  /// "the other party's" prefix — which produced asymmetric MMFs
  /// across the conversation: the author's stored MMF used the
  /// receiver's prefix while the receiver's stored MMF (from the
  /// wire's senderPrefix) used the author's prefix. Replies that
  /// embedded the author-side MMF as `target` then failed to
  /// resolve on the receiver side, surfacing the
  /// "Reply to a message you don't have" fallback even when the
  /// target was clearly in the receiver's local store. Field-test
  /// confirmed this on 2026-05-07; spec was internally inconsistent.
  ///
  /// Returns null if self-pubkey isn't available yet (e.g. selfInfo
  /// hasn't loaded). Callers fall through to the legacy mmf=null
  /// path so the message persists without an MMF rather than
  /// crashing.
  MeshCoreMmf? _outboundMmfFor(int timestampS) {
    if (widget.chatType == MeshCoreChatType.contact) {
      final selfPubkey = ref.read(meshCoreSelfInfoProvider).selfInfo?.pubKey;
      if (selfPubkey == null || selfPubkey.length < 6) return null;
      return MeshCoreMmf.contact(
        peerPubkeyPrefix: Uint8List.fromList(selfPubkey.sublist(0, 6)),
        targetTimestampS: timestampS,
      );
    }
    return MeshCoreMmf.channel(
      channelIndex: widget.channel!.index,
      targetTimestampS: timestampS,
    );
  }

  /// D33: build the human-readable fallback summary appended after
  /// `[/mrrp]`. Non-SocialMesh peers see `Sender replied: body`
  /// rendered as plain text since they don't strip the envelope.
  /// The codec self-truncates to [kChatMetaSummaryMaxBytes].
  String _replySummaryFor(String body) {
    final me = context.l10n.meshcoreChatReplyYou;
    return '$me replied: $body';
  }

  /// D33: locate the locally-stored message a given MMF refers to.
  /// Returns null if no message in the visible list matches — the
  /// caller surfaces the "Reply to a message you don't have"
  /// fallback in that case.
  MeshCoreMessage? _findMessageByMmf(String mmf) {
    for (final m in _messages) {
      if (m.mmf == mmf) return m;
    }
    return null;
  }

  /// D33: enter reply-compose mode. Latches the source message so
  /// the next send threads against it. No-op when the source has no
  /// MMF (the long-press menu hides Reply in that case, but defence
  /// in depth — a stale tap shouldn't half-arm reply state).
  void _startReply(MeshCoreMessage source) {
    if (source.mmf == null) return;
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = source);
    _focusNode.requestFocus();
  }

  /// D33: exit reply-compose mode. Called by the chip's X button,
  /// after a successful send (handled inline), and any flow that
  /// invalidates the source bubble (local-delete, cleared list).
  void _cancelReply() {
    if (_replyingTo == null) return;
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = null);
  }

  /// D30 Part E: long-press action sheet on a message bubble. Offers
  /// Copy (always), Retry (only for failed outbound messages), and
  /// Delete locally (always). Operating on a no-longer-tracked message
  /// is a quiet no-op so a stale long-press doesn't spam errors.
  Future<void> _showMessageActions(MeshCoreMessage message) async {
    HapticFeedback.mediumImpact();

    final canRetry =
        message.isOutgoing &&
        message.status == MeshCoreMessageDeliveryStatus.failed &&
        !_isSending;

    // D33: Reply is offered only when the feature flag is on AND the
    // source message has a derivable MMF. Pre-D33 records (and any
    // outbound message we couldn't pin a stable target on) hide
    // Reply rather than offering it and silently dropping the
    // envelope client-side.
    final canReply =
        AppFeatureFlags.enableMeshCoreReplies && message.mmf != null;

    final result = await AppBottomSheet.showActions<String>(
      context: context,
      actions: [
        if (canReply)
          BottomSheetAction<String>(
            icon: Icons.reply_rounded,
            label: context.l10n.meshcoreChatActionReply,
            value: 'reply',
          ),
        BottomSheetAction<String>(
          icon: Icons.content_copy_rounded,
          label: context.l10n.meshcoreChatActionCopy,
          value: 'copy',
        ),
        if (canRetry)
          BottomSheetAction<String>(
            icon: Icons.refresh_rounded,
            label: context.l10n.meshcoreChatActionRetry,
            value: 'retry',
          ),
        BottomSheetAction<String>(
          icon: Icons.delete_outline_rounded,
          label: context.l10n.meshcoreChatActionDelete,
          value: 'delete',
          isDestructive: true,
        ),
      ],
    );

    if (!mounted) return;
    switch (result) {
      case 'reply':
        _startReply(message);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) {
          showSuccessSnackBar(context, context.l10n.meshcoreChatMessageCopied);
        }
        break;
      case 'retry':
        await _retryFailedMessage(message);
        break;
      case 'delete':
        await _deleteMessageLocally(message);
        break;
      default:
        break;
    }
  }

  /// D30 Part E: delete a single message from local storage and the
  /// in-memory list. Emits no wire frame; remote peers retain their
  /// copy. No-op if the message id is unknown to the store.
  Future<void> _deleteMessageLocally(MeshCoreMessage message) async {
    try {
      await _messageStore.init();
      final removed = widget.chatType == MeshCoreChatType.contact
          ? await _messageStore.deleteContactMessage(
              _conversationId,
              message.id,
            )
          : await _messageStore.deleteChannelMessage(
              widget.channel!.index,
              message.id,
            );

      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }

      AppLogging.meshcore(
        'event=message.delete.local '
        'type=${widget.chatType == MeshCoreChatType.contact ? "contact" : "channel"} '
        'storeRemoved=$removed',
      );

      if (mounted) {
        showSuccessSnackBar(context, context.l10n.meshcoreChatMessageDeleted);
      }
    } catch (e) {
      AppLogging.meshcore(
        'event=message.delete.failed reason=${e.runtimeType}',
        error: true,
      );
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.meshcoreChatMessageDeleteFailed,
        );
      }
    }
  }

  /// D30: retry a failed outbound message using the existing send path.
  /// Reuses the same message id (no duplicate bubble), flips status
  /// `failed` -> `pending`, and runs the wire send. Inbound messages,
  /// non-failed outbound messages, and any send already in flight
  /// (`_isSending`) are no-ops.
  Future<void> _retryFailedMessage(MeshCoreMessage message) async {
    if (_isSending) return;
    if (!message.isOutgoing) return;
    if (message.status != MeshCoreMessageDeliveryStatus.failed) return;

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index < 0) return;

    setState(() {
      _messages[index] = _messages[index].copyWith(
        status: MeshCoreMessageDeliveryStatus.pending,
      );
    });
    final pending = _messages[index];
    await _persistMessage(pending);

    AppLogging.meshcore(
      'event=message.retry.requested '
      'type=${widget.chatType == MeshCoreChatType.contact ? "contact" : "channel"} '
      'size=${pending.text.length}',
    );

    // D33: retries fire a fresh wire timestamp so the radio doesn't
    // see two distinct frames sharing the same `(senderPrefix, ts)`
    // pair (the firmware's tag-based dedupe table would silently drop
    // the retry as a duplicate). The retry's MMF + replyToMmf are
    // updated in lockstep to keep the local store consistent.
    final retryTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final retryMmf = _outboundMmfFor(retryTs)?.toStableString();
    final retryReplyTarget = pending.replyToMmf == null
        ? null
        : _findMessageByMmf(pending.replyToMmf!);
    if (!mounted) return;
    setState(() {
      final i = _messages.indexWhere((m) => m.id == pending.id);
      if (i >= 0) {
        _messages[i] = _messages[i].copyWith(mmf: retryMmf);
      }
    });
    final retryMessage = _messages.firstWhere((m) => m.id == pending.id);
    await _persistMessage(retryMessage);
    if (!mounted) return;

    await _doSend(
      retryMessage,
      timestampS: retryTs,
      replyTarget: retryReplyTarget,
    );
  }

  /// D30 P0/P1: shared send body used by both the first send and the
  /// retry path. Drives the firmware ack waiter, flips bubble status
  /// on success/failure, and surfaces user-facing errors.
  ///
  /// Caller is responsible for ensuring the message already exists in
  /// `_messages` (and storage) with `pending` status before calling.
  ///
  /// D33: [timestampS] is the Unix-epoch-seconds timestamp the wire
  /// frame must carry — caller controls this so the outbound MMF
  /// (already stored on [message]) matches what receivers will derive.
  /// [replyTarget], when non-null, causes the wire body to be encoded
  /// as a chat-meta REPLY envelope; when null the body is sent
  /// verbatim (existing plain-text path).
  Future<void> _doSend(
    MeshCoreMessage message, {
    required int timestampS,
    MeshCoreMessage? replyTarget,
  }) async {
    if (_isSending) return;

    // Capture providers before any await.
    final coordinator = ref.read(connectionCoordinatorProvider);

    setState(() {
      _isSending = true;
    });

    final chatTypeTag = widget.chatType == MeshCoreChatType.contact
        ? 'contact'
        : 'channel';
    // D21.A: redacted target fingerprint on contact sends so the diag
    // log can attribute later 0x82 acks to a specific peer. Channels
    // are flooded with no per-recipient ack so target attribution does
    // not apply.
    final targetTag = widget.chatType == MeshCoreChatType.contact
        ? ' target='
              '${AppLogging.publicKeyFingerprint(widget.contact!.publicKey)}'
        : '';
    AppLogging.meshcore(
      'event=message.send.attempted type=$chatTypeTag '
      'size=${message.text.length}$targetTag',
    );

    try {
      final adapter = coordinator.meshCoreAdapter;

      if (adapter == null) {
        _markMessageFailed(message.id);
        AppLogging.meshcore(
          'event=message.send.failed type=$chatTypeTag reason=no_adapter',
          error: true,
        );
        if (mounted) {
          showErrorSnackBar(context, context.l10n.meshcoreNotConnectedToDevice);
        }
        return;
      }

      final session = adapter.session;
      if (session == null || !session.isActive) {
        _markMessageFailed(message.id);
        AppLogging.meshcore(
          'event=message.send.failed type=$chatTypeTag reason=session_inactive',
          error: true,
        );
        if (mounted) {
          showErrorSnackBar(context, context.l10n.meshcoreSessionNotActive);
        }
        return;
      }

      // D33: when [replyTarget] is non-null AND has an MMF, encode the
      // wire body as a chat-meta REPLY envelope. The bubble's stored
      // `text` (the user's typed body) and the wire body diverge: the
      // local copy keeps the body verbatim; the wire body adds the
      // [mrrp]…[/mrrp] envelope + human summary so non-SocialMesh
      // peers see a comprehensible "<sender> replied: <body>" line.
      final wireBody = (replyTarget?.mmf != null)
          ? ChatMetaEnvelopeCodec.encodeReply(
              target: MeshCoreMmf.parseString(replyTarget!.mmf!)!,
              body: message.text,
              summary: _replySummaryFor(message.text),
            )
          : message.text;
      final isReplyEnvelope = replyTarget?.mmf != null;
      if (isReplyEnvelope) {
        AppLogging.meshcore(
          'event=chat_meta.reply.send.attempted type=$chatTypeTag '
          'target=${replyTarget!.mmf} body_size=${message.text.length} '
          'wire_size=${utf8.encode(wireBody).length}',
        );
      }

      // Build the send frame. Firmware's synchronous ack code differs
      // between the two send commands (D14 finding: contact path was
      // false-timing-out because the app waited for OK on both):
      //   * CMD_SEND_CHANNEL_TXT_MSG (0x03) -> RESP_CODE_OK (0x00),
      //     0-byte payload. Channels are flooded with no routed ack.
      //   * CMD_SEND_TXT_MSG          (0x02) -> RESP_CODE_SENT (0x06),
      //     9-byte payload (expected_ack_hash + est_time_to_send).
      //     A later PUSH_CODE_SEND_CONFIRMED (0x82) carries the
      //     routed-delivery ack from the peer.
      final frame = widget.chatType == MeshCoreChatType.contact
          ? _buildSendTextMsgFrame(
              widget.contact!.publicKey,
              wireBody,
              timestampS,
            )
          : _buildSendChannelTextMsgFrame(
              widget.channel!.index,
              wireBody,
              timestampS,
            );

      // D33: route through `sendTextMessage` so the new
      // `MeshCoreSendRateLimiter` gets to gate the send. The
      // budget accounting and host-side rejection live in the
      // session; the chat surface only needs to discriminate the
      // three terminal outcomes.
      final result = await session.sendTextMessage(
        command: frame.command,
        payload: frame.payload,
        expectedResponse: meshCoreExpectedSendResponseCode(widget.chatType),
        timeout: const Duration(seconds: 5),
      );

      if (result.rateLimited) {
        _markMessageFailed(message.id);
        AppLogging.meshcore(
          'event=message.send.rate_limited type=$chatTypeTag '
          'size=${message.text.length} '
          'wait_ms=${result.nextSendIn?.inMilliseconds ?? 0} '
          'reply=${isReplyEnvelope ? 1 : 0}',
          error: true,
        );
        if (mounted) {
          // D33: surface the seconds-remaining hint instead of the
          // generic failure message. Round up so a sub-second wait
          // still reads as "1s" rather than "0s".
          final waitMs = result.nextSendIn?.inMilliseconds ?? 0;
          final waitSeconds = ((waitMs + 999) ~/ 1000).clamp(1, 60);
          showErrorSnackBar(
            context,
            context.l10n.meshcoreChatReplyRateLimited(waitSeconds),
          );
        }
        return;
      }

      if (result.firmwareTimeout) {
        _markMessageFailed(message.id);
        AppLogging.protocol(
          'MeshCore Chat: Send timeout / error for $_title: ${message.text}',
        );
        AppLogging.meshcore(
          'event=message.send.timeout type=$chatTypeTag '
          'size=${message.text.length}',
          error: true,
        );
        if (mounted) {
          showErrorSnackBar(context, context.l10n.meshcoreFailedToSendMessage);
        }
        return;
      }

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index >= 0) {
            _messages[index] = _messages[index].copyWith(
              status: MeshCoreMessageDeliveryStatus.sent,
            );
          }
        });
        _persistMessage(_messages.firstWhere((m) => m.id == message.id));
      }

      AppLogging.protocol(
        'MeshCore Chat: Sent message to $_title: ${message.text}',
      );
      AppLogging.meshcore(
        'event=message.send.accepted type=$chatTypeTag '
        'size=${message.text.length}',
      );
    } catch (e) {
      AppLogging.protocol('MeshCore Chat: Error sending message: $e');
      AppLogging.meshcore(
        'event=message.send.failed type=$chatTypeTag reason=${e.runtimeType}',
        error: true,
      );
      _markMessageFailed(message.id);
      if (mounted) {
        showErrorSnackBar(context, context.l10n.meshcoreFailedToSendMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _markMessageFailed(String messageId) {
    if (mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          // Idempotent: only flip messages that have not yet reached a
          // success state. Otherwise a late timeout would stomp a bubble
          // that already flipped to `sent` (firmware OK landed) or
          // `delivered` (routed-ack 0x82 landed) just before the 5s
          // timeout fired. Pre-D14 this clobbered confirmed deliveries.
          if (meshCoreIsTerminalDeliveryStatus(_messages[index].status)) {
            return;
          }
          _messages[index] = _messages[index].copyWith(
            status: MeshCoreMessageDeliveryStatus.failed,
          );
          _persistMessage(_messages[index]);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkStatus = ref.watch(linkStatusProvider);
    final isConnected = linkStatus.isConnected;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold.body(
        hasScrollBody: true,
        titleWidget: _buildTitleWidget(),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: _accentColor),
            onPressed: _showChatInfo,
          ),
        ],
        body: Column(
          children: [
            // Connection status banner
            if (!isConnected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppTheme.errorRed.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_off_rounded,
                      size: 16,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.meshcoreDisconnectedMessagesWillQueue,
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing16,
                            vertical: AppTheme.spacing8,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: AppTheme.spacing12,
                          child: JumpToLatestPill(
                            visible: _showJumpToLatest,
                            onTap: _jumpToLatest,
                            label: context.l10n.meshcoreChatJumpToLatest,
                          ),
                        ),
                      ],
                    ),
            ),

            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleWidget() {
    final isChannel = widget.chatType == MeshCoreChatType.channel;
    final subtitle = isChannel
        ? context.l10n.messagingChannelSubtitle
        : context.l10n.messagingDirectMessageSubtitle;

    return Row(
      children: [
        if (isChannel)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.channel!.isPublic ? Icons.tag_rounded : Icons.lock_rounded,
              color: _accentColor,
              size: 18,
            ),
          )
        else
          NodeAvatar(
            text: _initialsFor(_title, fallback: '?'),
            color: _accentColor,
            size: 36,
          ),
        const SizedBox(width: AppTheme.spacing12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoScrollText(
                _title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.meshcoreLoadingMessages,
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      );
    }
    final isContact = widget.chatType == MeshCoreChatType.contact;
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: isContact
            ? const [
                Icons.chat_bubble_outline_rounded,
                Icons.send_rounded,
                Icons.forum_outlined,
                Icons.markunread_outlined,
                Icons.alternate_email_rounded,
                Icons.bolt_outlined,
              ]
            : const [
                Icons.forum_outlined,
                Icons.tag_rounded,
                Icons.broadcast_on_personal_outlined,
                Icons.cell_tower_rounded,
                Icons.podcasts_rounded,
                Icons.public_rounded,
              ],
        taglines: [
          context.l10n.meshcoreChatEmptyTagline1,
          context.l10n.meshcoreChatEmptyTagline2,
          context.l10n.meshcoreChatEmptyTagline3,
        ],
        titlePrefix: context.l10n.meshcoreChatEmptyTitlePrefix,
        titleKeyword: context.l10n.meshcoreChatEmptyTitleKeyword,
        titleSuffix: context.l10n.meshcoreChatEmptyTitleSuffix,
        accentColor: _accentColor,
      ),
    );
  }

  Widget _buildMessageBubble(MeshCoreMessage message) {
    final isOutgoing = message.isOutgoing;

    if (isOutgoing) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => _showMessageActions(message),
                    child: Container(
                      key: ValueKey('meshcore-message-${message.id}'),
                      margin: const EdgeInsets.only(left: 64),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing10,
                      ),
                      decoration: BoxDecoration(
                        color: _outgoingBubbleColor(context, message.status),
                        borderRadius: BorderRadius.circular(AppTheme.radius18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (message.replyToMmf != null)
                            _buildReplyQuoteRow(message, onAccent: true),
                          LinkifiedText(
                            text: message.text,
                            // Match inbound bubble size (15pt) so a
                            // back-and-forth thread reads with one
                            // consistent rhythm. The 14/15 split was a
                            // pre-D30 inconsistency the developer
                            // surfaced during the live smoke; fixed
                            // here as part of the MeshCore polish pass.
                            style: chatBubbleBodyStyle(
                              ref,
                              baseFontSize: 14,
                              color: Colors.white,
                            ),
                            linkStyle: const TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildOutgoingStatusInline(message.status),
                              if (message.status ==
                                  MeshCoreMessageDeliveryStatus.pending)
                                const SizedBox(width: AppTheme.spacing4),
                              Text(
                                _formatTime(message.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              if (message.status !=
                                  MeshCoreMessageDeliveryStatus.pending) ...[
                                const SizedBox(width: AppTheme.spacing4),
                                _buildStatusIcon(
                                  message.status,
                                  sentByMe: true,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final showSender = widget.chatType == MeshCoreChatType.channel;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing8),
              child: NodeAvatar(
                text: _initialsFor(_senderLabel(message), fallback: '?'),
                color: _senderColor(message),
                size: 32,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showMessageActions(message),
                  child: Container(
                    key: ValueKey('meshcore-message-${message.id}'),
                    margin: const EdgeInsets.only(right: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                      vertical: AppTheme.spacing10,
                    ),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showSender) ...[
                          Text(
                            _senderLabel(message),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _senderColor(message),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                        ],
                        if (message.replyToMmf != null)
                          _buildReplyQuoteRow(message, onAccent: false),
                        LinkifiedText(
                          text: message.text,
                          // Canonical chat-body size (14pt) shared
                          // with the outbound bubble + Meshtastic +
                          // SIP DM. The 14/15 split was a pre-D30
                          // inconsistency surfaced during live smoke;
                          // unified on 14 across all chat surfaces.
                          style: chatBubbleBodyStyle(
                            ref,
                            baseFontSize: 14,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                        _buildInboundLinkMeta(message),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// D33: inline quote-preview row that renders above the body of any
  /// bubble whose `replyToMmf` is set. Two states:
  ///
  ///   - **Resolved**: the local store has the target message — the row
  ///     shows the target author + a single-line preview of its body
  ///     and tapping it scrolls the list to the target bubble.
  ///   - **Missing**: the target isn't in the local store (out-of-order
  ///     receive, contact-side gap, peer pre-D33). The row falls back
  ///     to a localized "Reply to a message you don't have" line and
  ///     does not attach a tap handler.
  ///
  /// [onAccent] is true when the row is rendered inside the outbound
  /// (accent-coloured) bubble so the inner background contrasts against
  /// white text instead of [context.card].
  Widget _buildReplyQuoteRow(
    MeshCoreMessage message, {
    required bool onAccent,
  }) {
    final targetMmf = message.replyToMmf;
    if (targetMmf == null) return const SizedBox.shrink();

    final target = _findMessageByMmf(targetMmf);
    final accent = onAccent
        ? Colors.white.withValues(alpha: 0.85)
        : _accentColor;
    final bodyColor = onAccent
        ? Colors.white.withValues(alpha: 0.85)
        : context.textSecondary;
    final railColor = onAccent
        ? Colors.white.withValues(alpha: 0.65)
        : _accentColor;
    final fillColor = onAccent
        ? Colors.white.withValues(alpha: 0.15)
        : _accentColor.withValues(alpha: 0.10);

    final isResolved = target != null;
    final headLabel = isResolved
        ? _replyAuthorLabel(target)
        : context.l10n.meshcoreChatReplyMissingTarget;
    final preview = isResolved ? _replyPreviewBody(target) : '';

    final inner = Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border(left: BorderSide(color: railColor, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      margin: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          if (preview.isNotEmpty)
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: bodyColor),
            ),
        ],
      ),
    );

    if (!isResolved) return inner;
    return GestureDetector(
      key: ValueKey('meshcore-reply-quote-${message.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _jumpToMessage(target.id),
      child: inner,
    );
  }

  /// D33: scroll the list so the bubble with [messageId] is visible
  /// near the centre. Used by the reply quote-preview row's tap
  /// handler. Falls back to a no-op when the id isn't in the visible
  /// list (e.g. trimmed by the 500-message store cap).
  void _jumpToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    HapticFeedback.selectionClick();
    if (!_scrollController.hasClients) return;
    // Approximate per-bubble height. The list isn't a fixed-extent
    // ListView so we can't compute exactly; estimating 76px per
    // bubble and clamping to the available scroll range keeps the
    // jump close enough that the target enters the viewport.
    const estPerBubble = 76.0;
    final position = _scrollController.position;
    final target = (index * estPerBubble).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// D30 Part C: inline SNR + hop-count metadata for inbound bubbles.
  /// Hidden when the firmware did not surface either field. Outbound
  /// bubbles never call this. SNR is encoded by the firmware in
  /// quarter-dB units (signed int8 / 4 = dB).
  Widget _buildInboundLinkMeta(MeshCoreMessage message) {
    final hasSnr = message.snrQuarter != null;
    final hasPath = message.pathLength != null;
    if (!hasSnr && !hasPath) return const SizedBox.shrink();

    final parts = <String>[];
    if (hasSnr) {
      final snrDb = message.snrQuarter! / 4.0;
      parts.add(
        context.l10n.meshcoreChatInboundMetaSnr(snrDb.toStringAsFixed(1)),
      );
    }
    if (hasPath) {
      final hops = message.pathLength!;
      // Firmware semantics for pathLen byte:
      //   0       = decoded directly (no relays in path)
      //   1..N    = traveled through N intermediate relays
      //   0xFF    = sentinel ("path unknown / not yet established"),
      //             commonly seen on contact DMs that arrived via a
      //             still-converging route. Render nothing — "via 255
      //             hops" is not a meaningful count.
      // We map 0 and 1 both to "direct" (the live D30 smoke surfaced
      // "via 0 hops" on legacy channel bubbles, which reads awkwardly).
      if (hops != 0xFF) {
        parts.add(
          hops <= 1
              ? context.l10n.meshcoreChatInboundMetaPathDirect
              : context.l10n.meshcoreChatInboundMetaPathHops(hops),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing2),
      child: Text(
        parts.join('  ·  '),
        style: TextStyle(fontSize: 10, color: context.textTertiary),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _outgoingBubbleColor(
    BuildContext context,
    MeshCoreMessageDeliveryStatus status,
  ) {
    switch (status) {
      case MeshCoreMessageDeliveryStatus.failed:
        return AppTheme.errorRed.withValues(alpha: 0.8);
      case MeshCoreMessageDeliveryStatus.pending:
        return context.accentColor.withValues(alpha: 0.6);
      case MeshCoreMessageDeliveryStatus.sent:
      case MeshCoreMessageDeliveryStatus.delivered:
        return context.accentColor;
    }
  }

  Widget _buildOutgoingStatusInline(MeshCoreMessageDeliveryStatus status) {
    if (status != MeshCoreMessageDeliveryStatus.pending) {
      return const SizedBox.shrink();
    }

    return const SizedBox(
      width: 12,
      height: 12,
      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
    );
  }

  Widget _buildStatusIcon(
    MeshCoreMessageDeliveryStatus status, {
    bool sentByMe = false,
  }) {
    final muted = sentByMe
        ? Colors.white.withValues(alpha: 0.7)
        : context.textTertiary;
    switch (status) {
      case MeshCoreMessageDeliveryStatus.pending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: muted),
        );
      case MeshCoreMessageDeliveryStatus.sent:
        return Icon(Icons.done_rounded, size: 14, color: muted);
      case MeshCoreMessageDeliveryStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: muted);
      case MeshCoreMessageDeliveryStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: AppTheme.errorRed,
        );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _buildReplyComposerChip(_replyingTo!),
            ChatComposer(
              controller: _messageController,
              focusNode: _focusNode,
              onSend: _sendMessage,
              hintText: context.l10n.meshcoreTypeMessageHint,
              sendTooltip: context.l10n.meshcoreSendMessage,
              enabled: !_isSending,
              leading: GestureDetector(
                onTap: _showChatInfo,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: context.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// D33: composer banner shown above the input while in reply mode.
  /// Renders `Replying to {name}` + the source body's first line, with
  /// an X to cancel. The widget uses the shared accent rail + tonal
  /// background so the reply context reads at a glance without
  /// stealing focus from the composer.
  Widget _buildReplyComposerChip(MeshCoreMessage source) {
    final nameText = _replyAuthorLabel(source);
    final preview = _replyPreviewBody(source);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Container(
        key: const ValueKey('meshcore-reply-composer-chip'),
        decoration: BoxDecoration(
          color: _accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border(left: BorderSide(color: _accentColor, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        child: Row(
          children: [
            Icon(Icons.reply_rounded, size: 16, color: _accentColor),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.meshcoreChatComposerReplyingTo(nameText),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                  if (preview.isNotEmpty)
                    Text(
                      preview,
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
            IconButton(
              key: const ValueKey('meshcore-reply-composer-cancel'),
              icon: const Icon(Icons.close_rounded),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: context.l10n.meshcoreChatComposerCancelReply,
              color: context.textSecondary,
              onPressed: _cancelReply,
            ),
          ],
        ),
      ),
    );
  }

  /// D33: rendering label for the author of [source]. Outbound
  /// messages show "You"; inbound channel messages show the sender
  /// name when available, falling back to the bubble's existing
  /// `_senderLabel`; inbound contact messages show the contact's
  /// own display name.
  String _replyAuthorLabel(MeshCoreMessage source) {
    if (source.isOutgoing) return context.l10n.meshcoreChatReplyYou;
    if (widget.chatType == MeshCoreChatType.contact) {
      return _title;
    }
    return _senderLabel(source);
  }

  /// D33: short single-line preview of [source]'s body for the chip
  /// and the bubble quote-row. Strips embedded line breaks and trims
  /// to ~80 chars before the rendering layer ellipsizes further.
  String _replyPreviewBody(MeshCoreMessage source) {
    final flat = source.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 80) return flat;
    return flat.substring(0, 80);
  }

  String _senderLabel(MeshCoreMessage message) {
    if (message.senderName != null && message.senderName!.isNotEmpty) {
      return message.senderName!;
    }
    final key = message.senderKey;
    if (key == null || key.isEmpty) {
      return context.l10n.meshcoreUnknown;
    }
    final hex = key
        .take(2)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '!$hex';
  }

  String _initialsFor(String value, {required String fallback}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed.toUpperCase();
  }

  Color _senderColor(MeshCoreMessage message) {
    final key = message.senderKey;
    if (key == null || key.isEmpty) {
      return AccentColors.purple;
    }
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      AppTheme.graphBlue,
      const Color(0xFFF59E0B),
      AppTheme.errorRed,
      AccentColors.emerald,
    ];
    return colors[key.first % colors.length];
  }

  void _showChatInfo() {
    AppBottomSheet.show<void>(
      context: context,
      child: widget.chatType == MeshCoreChatType.contact
          ? _buildContactInfo()
          : _buildChannelInfo(),
    );
  }

  Widget _buildContactInfo() {
    final contact = widget.contact!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _accentColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        Center(
          child: Text(
            contact.name,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing8),
        Center(
          child: Text(
            contact.localizedTypeLabel(context.l10n),
            style: TextStyle(color: _accentColor, fontSize: 14),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: context.l10n.meshcoreDeviceInfo),
        InfoTable(
          rows: [
            InfoTableRow(
              label: context.l10n.meshcorePublicKeySettingsLabel,
              value: contact.publicKeyHex,
              icon: Icons.key_outlined,
            ),
            InfoTableRow(
              label: context.l10n.meshcoreChatInfoPath,
              value: contact.localizedPathLabel(context.l10n),
              icon: Icons.alt_route_outlined,
            ),
            InfoTableRow(
              label: context.l10n.meshcoreChatInfoLastSeen,
              value: _formatDateTime(contact.lastSeen),
              icon: Icons.schedule_outlined,
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: contact.publicKeyHex));
              showSuccessSnackBar(
                context,
                context.l10n.meshcorePublicKeyCopied,
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.l10n.meshcoreCopyPublicKey),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelInfo() {
    final channel = widget.channel!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: _accentColor.withValues(alpha: 0.2),
            child: Icon(
              channel.isPublic ? Icons.tag_rounded : Icons.lock_rounded,
              color: _accentColor,
              size: 32,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        Center(
          child: Text(
            channel.displayName,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing8),
        Center(
          child: Text(
            channel.isPublic
                ? context.l10n.meshcorePublicChannel
                : context.l10n.meshcorePrivateChannel,
            style: TextStyle(color: _accentColor, fontSize: 14),
          ),
        ),
        SizedBox(height: AppTheme.spacing16),
        SectionTitle(title: context.l10n.meshcoreDeviceInfo),
        InfoTable(
          rows: [
            InfoTableRow(
              label: context.l10n.meshcoreChannelInfoIndex,
              value: '${channel.index}',
              icon: Icons.tag,
            ),
            InfoTableRow(
              label: context.l10n.meshcoreChannelInfoPsk,
              value: channel.pskHex,
              icon: Icons.vpn_key_outlined,
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: channel.pskHex));
              showSuccessSnackBar(
                context,
                context.l10n.meshcoreChannelPskCopied,
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.l10n.meshcoreCopyChannelCode),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return context.l10n.meshcoreTimeAgoDays(diff.inDays);
    } else if (diff.inHours > 0) {
      return context.l10n.meshcoreTimeAgoHours(diff.inHours);
    } else if (diff.inMinutes > 0) {
      return context.l10n.meshcoreTimeAgoMinutes(diff.inMinutes);
    } else {
      return context.l10n.meshcoreJustNow;
    }
  }

  /// Build CMD_SEND_TXT_MSG frame for contact message.
  /// Format: [cmd][txt_type][attempt][timestamp x4][pub_key_prefix x6][text...]\0
  ///
  /// D33: [timestampS] is supplied by the caller so the same value can
  /// be reused for the outbound MMF (`02:<peerPrefix>:<ts>`). Receivers
  /// echo the timestamp verbatim, so MMFs derived from the wire field
  /// match on both ends.
  MeshCoreFrame _buildSendTextMsgFrame(
    Uint8List recipientPubKey,
    String text,
    int timestampS,
  ) {
    final builder = BytesBuilder();
    builder.addByte(0); // txt_type = plain
    builder.addByte(0); // attempt = 0
    builder.addByte(timestampS & 0xFF);
    builder.addByte((timestampS >> 8) & 0xFF);
    builder.addByte((timestampS >> 16) & 0xFF);
    builder.addByte((timestampS >> 24) & 0xFF);
    builder.add(recipientPubKey.sublist(0, 6));
    builder.add(utf8.encode(text));
    builder.addByte(0);

    return MeshCoreFrame(
      command: MeshCoreCommands.sendTxtMsg,
      payload: builder.toBytes(),
    );
  }

  /// Build CMD_SEND_CHANNEL_TXT_MSG frame for channel message.
  /// Format: [cmd][txt_type][channel_idx][timestamp x4][text...]\0
  MeshCoreFrame _buildSendChannelTextMsgFrame(
    int channelIndex,
    String text,
    int timestampS,
  ) {
    final builder = BytesBuilder();
    builder.addByte(0); // txt_type = plain
    builder.addByte(channelIndex);
    builder.addByte(timestampS & 0xFF);
    builder.addByte((timestampS >> 8) & 0xFF);
    builder.addByte((timestampS >> 16) & 0xFF);
    builder.addByte((timestampS >> 24) & 0xFF);
    builder.add(utf8.encode(text));
    builder.addByte(0);

    return MeshCoreFrame(
      command: MeshCoreCommands.sendChannelTxtMsg,
      payload: builder.toBytes(),
    );
  }
}
