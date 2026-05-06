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
import '../../../core/widgets/linkified_text.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact.dart';
import '../../../models/meshcore_channel.dart';
import '../contact_l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../providers/meshcore_message_providers.dart';
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

  String get _conversationId {
    if (widget.chatType == MeshCoreChatType.contact) {
      return widget.contact!.publicKeyHex;
    } else {
      return 'channel_${widget.channel!.index}';
    }
  }

  String get _title {
    if (widget.chatType == MeshCoreChatType.contact) {
      // The contact may have been auto-added from an inbound mesh advert
      // that did not carry a friendly name. Fall back to the localized
      // "Unknown" string so the chat header always renders a title rather
      // than a blank line above the "Direct Message" subtitle.
      final name = widget.contact!.name;
      return name.isNotEmpty ? name : context.l10n.meshcoreContactUnknownName;
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
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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
    );

    if (mounted) {
      // D19.B: in-memory only. The conversations notifier owns
      // inbound persistence; calling `_persistMessage` here too
      // would risk a double-write race against the off-frame
      // microtask in the notifier. Both paths use the same
      // deterministic id, so the store dedupes regardless, but
      // not writing twice keeps the diag log surface clean.
      setState(() => _messages.add(message));
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    );

    if (mounted) {
      setState(() => _messages.add(message));
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

    // Capture providers before any await
    final coordinator = ref.read(connectionCoordinatorProvider);

    setState(() {
      _isSending = true;
    });

    final chatTypeTag = widget.chatType == MeshCoreChatType.contact
        ? 'contact'
        : 'channel';
    // D21.A: redacted target fingerprint on contact sends so the diag
    // log can attribute later 0x82 acks to a specific peer. Without
    // this we couldn't tell from the log alone whether an iPhone DM
    // targeted Radio A or some other discovered peer. Channels are
    // flooded with no per-recipient ack so target attribution does
    // not apply.
    final targetTag = widget.chatType == MeshCoreChatType.contact
        ? ' target='
              '${AppLogging.publicKeyFingerprint(widget.contact!.publicKey)}'
        : '';
    AppLogging.meshcore(
      'event=message.send.attempted type=$chatTypeTag '
      'size=${text.length}$targetTag',
    );

    try {
      // Create local message with pending status
      final message = MeshCoreMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        timestamp: DateTime.now(),
        isOutgoing: true,
        status: MeshCoreMessageDeliveryStatus.pending,
      );

      setState(() {
        _messages.add(message);
        _messageController.clear();
      });

      // Persist immediately as pending
      await _persistMessage(message);

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });

      // Send via MeshCore protocol (coordinator captured before await)
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

      // Build and send the message frame
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

      // Build the send frame. Firmware's synchronous ack code differs
      // between the two send commands (D14 finding: contact path was
      // false-timing-out because the app waited for OK on both):
      //   * CMD_SEND_CHANNEL_TXT_MSG (0x03) -> RESP_CODE_OK (0x00),
      //     0-byte payload. Channels are flooded with no routed ack.
      //   * CMD_SEND_TXT_MSG          (0x02) -> RESP_CODE_SENT (0x06),
      //     9-byte payload (expected_ack_hash + est_time_to_send).
      //     A later PUSH_CODE_SEND_CONFIRMED (0x82) carries the
      //     routed-delivery ack from the peer.
      // We sendAndWait on the right code per chat type so the bubble
      // flips to `sent` immediately on firmware ack, and the later
      // 0x82 push (if any) flips `sent` -> `delivered` via
      // `_handleDeliveryConfirmation`.
      final frame = widget.chatType == MeshCoreChatType.contact
          ? _buildSendTextMsgFrame(widget.contact!.publicKey, text)
          : _buildSendChannelTextMsgFrame(widget.channel!.index, text);

      final response = await session.sendAndWait(
        frame.command,
        payload: frame.payload,
        expectedResponse: meshCoreExpectedSendResponseCode(widget.chatType),
        timeout: const Duration(seconds: 5),
      );

      if (response == null) {
        // Either firmware returned RESP_CODE_ERR (which the codec
        // routes to the status stream and never satisfies a waiter)
        // or no response landed before the 5s timeout. Either way
        // the send is not confirmed.
        _markMessageFailed(message.id);
        AppLogging.protocol(
          'MeshCore Chat: Send timeout / error for $_title: $text',
        );
        AppLogging.meshcore(
          'event=message.send.timeout type=$chatTypeTag size=${text.length}',
          error: true,
        );
        if (mounted) {
          showErrorSnackBar(context, context.l10n.meshcoreFailedToSendMessage);
        }
        return;
      }

      // Firmware acknowledged the command. For channel messages this
      // is the only ack we ever get (channel messages are flooded with
      // no per-recipient confirmation). For contact messages the
      // firmware may later emit PUSH_CODE_SEND_CONFIRMED (0x82) with
      // the routed-ack, which `_handleDeliveryConfirmation` flips to
      // `delivered`.
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

      AppLogging.protocol('MeshCore Chat: Sent message to $_title: $text');
      AppLogging.meshcore(
        'event=message.send.accepted type=$chatTypeTag size=${text.length}',
      );
    } catch (e) {
      AppLogging.protocol('MeshCore Chat: Error sending message: $e');
      AppLogging.meshcore(
        'event=message.send.failed type=$chatTypeTag reason=${e.runtimeType}',
        error: true,
      );
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
                  : ListView.builder(
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
                        LinkifiedText(
                          text: message.text,
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
                              _buildStatusIcon(message.status, sentByMe: true),
                            ],
                          ],
                        ),
                      ],
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
                Container(
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
                      LinkifiedText(
                        text: message.text,
                        style: chatBubbleBodyStyle(
                          ref,
                          baseFontSize: 15,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        child: ChatComposer(
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
      ),
    );
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
  MeshCoreFrame _buildSendTextMsgFrame(Uint8List recipientPubKey, String text) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final builder = BytesBuilder();
    builder.addByte(0); // txt_type = plain
    builder.addByte(0); // attempt = 0
    // timestamp (4 bytes little-endian)
    builder.addByte(timestamp & 0xFF);
    builder.addByte((timestamp >> 8) & 0xFF);
    builder.addByte((timestamp >> 16) & 0xFF);
    builder.addByte((timestamp >> 24) & 0xFF);
    // pub_key prefix (first 6 bytes)
    builder.add(recipientPubKey.sublist(0, 6));
    // text + null terminator
    builder.add(utf8.encode(text));
    builder.addByte(0);

    return MeshCoreFrame(
      command: MeshCoreCommands.sendTxtMsg,
      payload: builder.toBytes(),
    );
  }

  /// Build CMD_SEND_CHANNEL_TXT_MSG frame for channel message.
  /// Format: [cmd][txt_type][channel_idx][timestamp x4][text...]\0
  MeshCoreFrame _buildSendChannelTextMsgFrame(int channelIndex, String text) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final builder = BytesBuilder();
    builder.addByte(0); // txt_type = plain
    builder.addByte(channelIndex);
    // timestamp (4 bytes little-endian)
    builder.addByte(timestamp & 0xFF);
    builder.addByte((timestamp >> 8) & 0xFF);
    builder.addByte((timestamp >> 16) & 0xFF);
    builder.addByte((timestamp >> 24) & 0xFF);
    // text + null terminator
    builder.add(utf8.encode(text));
    builder.addByte(0);

    return MeshCoreFrame(
      command: MeshCoreCommands.sendChannelTxtMsg,
      payload: builder.toBytes(),
    );
  }
}
