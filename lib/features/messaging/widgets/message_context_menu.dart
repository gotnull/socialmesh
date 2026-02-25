// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../models/mesh_models.dart';
import '../../../models/tapback.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/telemetry_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../core/logging.dart';
import '../../../utils/snackbar.dart';

/// Shows a context menu for a message with tapback, reply, copy, details, and delete options
class MessageContextMenu extends ConsumerStatefulWidget {
  final Message message;
  final bool isFromMe;
  final String senderName;
  final int? channelIndex;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.isFromMe,
    required this.senderName,
    this.channelIndex,
    this.onReply,
    this.onDelete,
  });

  @override
  ConsumerState<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends ConsumerState<MessageContextMenu>
    with LifecycleSafeMixin {
  bool _detailsExpanded = false;

  /// Quick-reaction emojis shown inline (matches Meshtastic iOS defaults).
  static const _quickReactions = [
    '👋',
    '❤️',
    '👍',
    '👎',
    '🤣',
    '‼️',
    '❓',
    '💩',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Channel indicator
          if (widget.channelIndex != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 4),
              child: Text(
                'Channel: ${widget.channelIndex}',
                style: context.bodySmallStyle?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ),

          // Tapback section
          _buildTapbackSection(),

          _buildDivider(),

          // Reply
          _buildMenuItem(
            icon: Icons.reply,
            label: 'Reply',
            onTap: () {
              Navigator.pop(context);
              widget.onReply?.call();
            },
          ),

          // Copy
          _buildMenuItem(
            icon: Icons.copy,
            label: 'Copy',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.message.text));
              if (context.mounted) {
                Navigator.pop(context);
                showSuccessSnackBar(context, 'Message copied');
              }
            },
          ),

          // Message Details section
          _buildDetailsSection(),

          _buildDivider(),

          // Delete
          _buildMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
          ),

          const SizedBox(height: AppTheme.spacing8),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.border.withValues(alpha: 0.3),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool hasSubmenu = false,
    bool isExpanded = false,
  }) {
    final color = isDestructive ? AppTheme.errorRed : context.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                label,
                style: context.titleSmallStyle?.copyWith(color: color),
              ),
            ),
            if (hasSubmenu)
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 20,
                color: context.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapbackSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in _quickReactions)
            _QuickReactionButton(
              emoji: emoji,
              onTap: () => _sendTapback(emoji),
            ),
          _MoreEmojiButton(onEmojiSelected: _sendTapback),
        ],
      ),
    );
  }

  Future<void> _sendTapback(String emoji) async {
    AppLogging.messages(
      '🏷️ _sendTapback START: emoji=$emoji, '
      'messageId=${widget.message.id}, packetId=${widget.message.packetId}',
    );

    // Capture all provider references BEFORE any async operations
    final protocol = ref.read(protocolServiceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final storage = ref.read(tapbackStorageProvider).value;
    final haptics = ref.read(hapticServiceProvider);
    final navigator = Navigator.of(context);

    if (myNodeNum == null) {
      AppLogging.messages('🏷️ _sendTapback ABORT: myNodeNum is null');
      return;
    }

    AppLogging.messages(
      '🏷️ _sendTapback: myNodeNum=$myNodeNum, '
      'storage=${storage != null ? "available" : "NULL"}',
    );

    // Create local tapback record
    final tapback = MessageTapback(
      messageId: widget.message.id,
      fromNodeNum: myNodeNum,
      emoji: emoji,
    );

    // Save locally
    await storage?.addTapback(tapback);
    AppLogging.messages(
      '🏷️ _sendTapback: local tapback stored for message ${widget.message.id}',
    );

    // Invalidate tapbacks so UI updates for own tapback
    ref.invalidate(messageTapbacksProvider(widget.message.id));

    // Send tapback emoji over the mesh
    try {
      final toNode = widget.isFromMe ? widget.message.to : widget.message.from;
      // Broadcast messages (0xFFFFFFFF) never receive ACKs, so wantAck must
      // be false to avoid the message being stuck in pending status forever.
      final isBroadcast = toNode == 0xFFFFFFFF;
      AppLogging.messages(
        '🏷️ _sendTapback: sending over mesh — to=$toNode, '
        'channel=${widget.channelIndex ?? 0}, isBroadcast=$isBroadcast, '
        'replyId=${widget.message.packetId}',
      );
      await protocol.sendMessage(
        text: emoji,
        to: toNode,
        channel: widget.channelIndex ?? 0,
        wantAck: !isBroadcast,
        isEmoji: true,
        replyId: widget.message.packetId,
        source: MessageSource.tapback,
      );

      AppLogging.messages('🏷️ _sendTapback: mesh send SUCCESS');

      // Check mounted after await before any UI operations
      if (!mounted) return;

      haptics.trigger(HapticType.selection);
      navigator.pop();
      showSuccessSnackBar(context, 'Tapback sent');
    } catch (e) {
      AppLogging.messages('🏷️ _sendTapback: mesh send FAILED: $e');
      if (!mounted) return;

      navigator.pop();
      showErrorSnackBar(context, 'Failed to send tapback');
    }
  }

  Widget _buildDetailsSection() {
    final dateFormat = DateFormat('dd/MM/yy, h:mm:ss a');
    final formattedDate = dateFormat.format(widget.message.timestamp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  'Message Details',
                  style: context.titleSmallStyle?.copyWith(
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _detailsExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_detailsExpanded) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: context.border.withValues(alpha: 0.2),
            indent: 16,
            endIndent: 16,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hops, SNR, RSSI for received messages
          if (!widget.isFromMe) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 4, 16, 4),
              child: Row(
                children: [
                  Text(
                    'From: ${widget.senderName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 4, 16, 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (widget.message.hopCount != null)
                    _DetailChip(
                      icon: Icons.route,
                      label:
                          '${widget.message.hopCount} '
                          '${widget.message.hopCount == 1 ? 'hop' : 'hops'}',
                    ),
                  if (widget.message.rxSnr != null)
                    _DetailChip(
                      icon: Icons.signal_cellular_alt,
                      label:
                          'SNR ${widget.message.rxSnr!.toStringAsFixed(1)} dB',
                    ),
                  if (widget.message.rxRssi != null)
                    _DetailChip(
                      icon: Icons.cell_tower,
                      label: 'RSSI ${widget.message.rxRssi} dBm',
                    ),
                ],
              ),
            ),
          ],
          // Delivery status for sent messages
          if (widget.isFromMe) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    _getDeliveryStatusText(),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _getDeliveryStatusText() {
    switch (widget.message.status) {
      case MessageStatus.pending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered ✔️';
      case MessageStatus.failed:
        return 'Failed: ${widget.message.errorMessage ?? "Unknown error"}';
    }
  }
}

/// Shows the message context menu as a bottom sheet
Future<void> showMessageContextMenu(
  BuildContext context, {
  required Message message,
  required bool isFromMe,
  required String senderName,
  int? channelIndex,
  VoidCallback? onReply,
  VoidCallback? onDelete,
}) {
  HapticFeedback.selectionClick();

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: MessageContextMenu(
        message: message,
        isFromMe: isFromMe,
        senderName: senderName,
        channelIndex: channelIndex,
        onReply: onReply,
        onDelete: onDelete,
      ),
    ),
  );
}

/// Tappable emoji circle for the quick-reaction row.
class _QuickReactionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _QuickReactionButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.border.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// "+" button that opens a full emoji picker sheet.
class _MoreEmojiButton extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;

  const _MoreEmojiButton({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEmojiPicker(context),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.border.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add, size: 20, color: context.textTertiary),
      ),
    );
  }

  void _showEmojiPicker(BuildContext outerContext) {
    showModalBottomSheet<String>(
      context: outerContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, scrollController) => _EmojiPickerSheet(
          onEmojiSelected: (emoji) {
            Navigator.pop(sheetCtx, emoji);
          },
        ),
      ),
    ).then((emoji) {
      if (emoji != null) onEmojiSelected(emoji);
    });
  }
}

/// Full emoji picker powered by emoji_picker_flutter.
///
/// Shows the complete Unicode emoji set with categories, search,
/// recents, and skin tone selection — no hardcoded emoji lists.
class _EmojiPickerSheet extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;

  const _EmojiPickerSheet({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppTheme.radius2),
              ),
            ),
          ),
          // Picker
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) => onEmojiSelected(emoji.emoji),
              config: Config(
                height: double.infinity,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax:
                      28 *
                      (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  columns: 8,
                  noRecents: Text(
                    'No Recents',
                    style: TextStyle(fontSize: 16, color: context.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                  loadingIndicator: const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                ),
                skinToneConfig: const SkinToneConfig(
                  enabled: true,
                  dialogBackgroundColor: Color(0xFF303030),
                  indicatorColor: Colors.grey,
                ),
                categoryViewConfig: CategoryViewConfig(
                  initCategory: Category.RECENT,
                  backgroundColor: Colors.transparent,
                  indicatorColor: context.textPrimary,
                  iconColorSelected: context.textPrimary,
                  iconColor: context.textTertiary,
                  categoryIcons: const CategoryIcons(),
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: Colors.transparent,
                  buttonIconColor: context.textTertiary,
                  hintText: 'Search emoji...',
                  hintTextStyle: TextStyle(
                    color: context.textTertiary,
                    fontSize: 14,
                  ),
                  inputTextStyle: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon + label chip used in the message details section.
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
      ],
    );
  }
}
