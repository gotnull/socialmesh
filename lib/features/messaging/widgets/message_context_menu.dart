import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/mesh_models.dart';
import '../../../models/tapback.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/telemetry_providers.dart';
import '../../../services/haptic_service.dart';
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

class _MessageContextMenuState extends ConsumerState<MessageContextMenu> {
  bool _tapbackExpanded = false;
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Channel indicator
          if (widget.channelIndex != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Channel: ${widget.channelIndex}',
                style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
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

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.darkBorder.withValues(alpha: 0.3),
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
    final color = isDestructive ? AppTheme.errorRed : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 16, color: color)),
            ),
            if (hasSubmenu)
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 20,
                color: AppTheme.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapbackSection() {
    final settingsAsync = ref.watch(settingsServiceProvider);

    return settingsAsync.when(
      data: (settings) {
        final tapbacks = settings.enabledTapbacks;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _tapbackExpanded = !_tapbackExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Tapback',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const Spacer(),
                    Icon(
                      _tapbackExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            if (_tapbackExpanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.darkBorder.withValues(alpha: 0.2),
                indent: 16,
                endIndent: 16,
              ),
              ...tapbacks.map((config) => _buildTapbackItem(config)),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildTapbackItem(TapbackConfig config) {
    return InkWell(
      onTap: () => _sendTapback(config.type, config.emoji),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(config.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              config.label,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTapback(TapbackType type, String emoji) async {
    final protocol = ref.read(protocolServiceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final storage = ref.read(tapbackStorageProvider).value;

    if (myNodeNum == null) return;

    // Create local tapback record
    final tapback = MessageTapback(
      messageId: widget.message.id,
      fromNodeNum: myNodeNum,
      type: type,
    );

    // Save locally
    await storage?.addTapback(tapback);

    // Send tapback message over the mesh
    // Use the configured emoji (which may differ from TapbackType default)
    try {
      final toNode = widget.isFromMe ? widget.message.to : widget.message.from;
      await protocol.sendMessage(
        text: emoji,
        to: toNode,
        channel: widget.channelIndex ?? 0,
        wantAck: true,
        isEmoji: true,
        replyId: widget.message.packetId,
        source: MessageSource.tapback,
      );

      ref.haptics.itemSelect();

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Tapback sent');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showErrorSnackBar(context, 'Failed to send tapback');
      }
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
                const Text(
                  'Message Details',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const Spacer(),
                Icon(
                  _detailsExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_detailsExpanded) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.darkBorder.withValues(alpha: 0.2),
            indent: 16,
            endIndent: 16,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Hops away for received messages (not available in current message model)
          // This would show hop count if available from the protocol layer
          if (!widget.isFromMe)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    'From: ${widget.senderName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // Delivery status for sent messages
          if (widget.isFromMe) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Text(
                    _getDeliveryStatusText(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
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
