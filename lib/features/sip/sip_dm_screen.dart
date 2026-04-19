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
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../features/messaging/widgets/chat_composer.dart';
import '../../features/nodedex/models/nodedex_entry.dart';
import '../../features/nodedex/models/sigil_evolution.dart';
import '../../features/nodedex/providers/nodedex_providers.dart';
import '../../features/nodedex/services/patina_score.dart';
import '../../features/nodedex/services/trait_engine.dart';
import '../../features/nodedex/screens/nodedex_detail_screen.dart';
import '../../features/nodedex/widgets/sigil_painter.dart';
import '../../features/nodes/node_display_name_resolver.dart';
import '../../providers/app_providers.dart';
import '../../providers/sip_dm_secure_router.dart';
import '../../providers/sip_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/protocol/sip/sip_dm.dart';
import '../../services/protocol/sip/sip_messages_dm.dart';
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

class _SipDmScreenState extends ConsumerState<SipDmScreen>
    with LifecycleSafeMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  /// The message being replied to, or null if not replying.
  SipDmHistoryEntry? _replyingToEntry;

  /// Timer to dismiss the typing indicator after the display duration.
  Timer? _typingDismissTimer;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);

    // Auto-focus the input field when entering the DM screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _typingDismissTimer?.cancel();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final dm = ref.read(sipDmManagerProvider);
    if (dm == null) return;

    final haptics = ref.read(hapticServiceProvider);

    // If replying, format the message with the quote prefix.
    final messageText = _replyingToEntry != null
        ? SipDmManager.formatReplyMessage(
            quotedText: SipDmManager.extractReplyBody(_replyingToEntry!.text),
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
      SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
      SipDmSendError.sessionClosed => l10n.sipDmSessionClosed,
      SipDmSendError.sessionNotFound => l10n.sipDmSessionClosed,
      _ => l10n.sipDmSessionClosed,
    };

    showErrorSnackBar(context, message);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onPin() {
    final dm = ref.read(sipDmManagerProvider);
    if (dm == null) return;

    final session = dm.getSession(widget.sessionTag);
    if (session == null) return;

    final haptics = ref.read(hapticServiceProvider);

    if (session.isPinned) {
      dm.unpinSession(widget.sessionTag);
    } else {
      dm.pinSession(widget.sessionTag);
    }
    haptics.trigger(HapticType.light);
    setState(() {});
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

  void _onReply(SipDmHistoryEntry entry) {
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    setState(() => _replyingToEntry = entry);
    // Focus the input field so the user can start typing immediately.
    _inputFocusNode.requestFocus();
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

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        title: title,
        controller: _scrollController,
        resizeToAvoidBottomInset:
            false, // We handle keyboard insets manually in _buildInputBar
        bottomNavigationBar: _buildInputBar(context, session),
        actions: [
          if (session != null)
            AppBarOverflowMenu<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin', // lint-allow: hardcoded-string
                  child: ListTile(
                    leading: Icon(
                      session.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                    title: Text(
                      session.isPinned
                          ? l10n.sipDmUnpinAction
                          : l10n.sipDmPinAction,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'close', // lint-allow: hardcoded-string
                  child: ListTile(
                    leading: const Icon(Icons.close),
                    title: Text(l10n.sipDmCloseAction),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'pin') {
                  _onPin(); // lint-allow: hardcoded-string
                }
                if (value == 'close') {
                  _onClose(); // lint-allow: hardcoded-string
                }
              },
            ),
        ],
        slivers: [
          // Pinned session info bar with frosted-glass effect
          if (session != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SessionInfoBarDelegate(session: session),
            ),

          // Messages
          if (history.isNotEmpty || peerIsTyping)
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList.builder(
                itemCount: history.length + (peerIsTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  // Typing indicator at the end
                  if (index == history.length) {
                    return const _TypingIndicatorBubble();
                  }
                  final entry = history[index];
                  return GestureDetector(
                    onLongPress: () => _showMessageMenu(entry),
                    child: _MessageBubble(
                      entry: entry,
                      peerNodeId: session!.peerNodeId,
                    ),
                  );
                },
              ),
            )
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            ),
        ],
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

  Widget _buildInputBar(BuildContext context, SipDmSession? session) {
    final l10n = context.l10n;
    final enabled =
        session != null && session.status == SipDmSessionStatus.active;

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
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: context.accentColor,
                            ),
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
                                    SipDmManager.extractReplyBody(
                                      _replyingToEntry!.text,
                                    ),
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
                  maxLength: 180,
                  maxLines: 4,
                  enabled: enabled,
                  sendTooltip: l10n.sipDmSendButton,
                ),
              ),
            ],
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

/// Fixed extent: vertical padding (12+12) + avatar height (32) + divider (1).
const double _kInfoBarExtent = 57.0;

class _SessionInfoBarDelegate extends SliverPersistentHeaderDelegate {
  final SipDmSession session;

  _SessionInfoBarDelegate({required this.session});

  @override
  double get minExtent => _kInfoBarExtent;

  @override
  double get maxExtent => _kInfoBarExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
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
              bottom: BorderSide(color: context.border.withValues(alpha: 0.3)),
            ),
          ),
          child: _SessionInfoBar(session: session),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SessionInfoBarDelegate oldDelegate) =>
      session.sessionTag != oldDelegate.session.sessionTag ||
      session.isPinned != oldDelegate.session.isPinned ||
      session.status != oldDelegate.session.status;
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

          // Expiry or pinned badge
          _buildStatusBadge(context, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, dynamic l10n) {
    if (session.isPinned) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing6,
          vertical: AppTheme.spacing2,
        ),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radius6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin, size: 12, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing4),
            Text(
              l10n.sipDmPinned,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.accentColor,
              ),
            ),
          ],
        ),
      );
    }

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

  const _MessageBubble({required this.entry, required this.peerNodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutbound = entry.direction == SipDmDirection.outbound;
    final replyTo = entry.replyToText;
    final bodyText = SipDmManager.extractReplyBody(entry.text);
    final hasReactions =
        entry.localReaction != null || entry.peerReaction != null;

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
              // Message bubble
              Container(
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
                    // Quoted reply block
                    if (replyTo != null) ...[
                      Container(
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
                          color: context.accentColor.withValues(alpha: 0.06),
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
                      _formatTime(entry.timestampMs),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Reaction row — Telegram-style pills below the bubble
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

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
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
