// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canonical NodeBoard reply composer — fixed to the bottom of the thread
// detail screen. Structurally identical to the Messages chat composer
// (lib/features/messaging/widgets/chat_composer.dart and its wrapper in
// messaging_screen.dart): spacing16 outer padding, SafeArea, borderless
// rounded-fill field, and a 48×48 flat-circle accent send button with
// Icons.send. When the thread is locked the input is replaced with a
// muted lock banner.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';

class NodeBoardReplyComposer extends StatefulWidget {
  const NodeBoardReplyComposer({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.isLocked = false,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSend;
  final bool isLocked;

  @override
  State<NodeBoardReplyComposer> createState() => _NodeBoardReplyComposerState();
}

class _NodeBoardReplyComposerState extends State<NodeBoardReplyComposer> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSend =>
      !widget.isLocked &&
      !widget.isSending &&
      widget.controller.text.trim().isNotEmpty;

  Future<void> _handleSend() async {
    if (!_canSend) return;
    final body = widget.controller.text.trim();
    AppLogging.nodeBoard(
      'UI: submitting reply to thread (${body.length} chars)',
    );
    HapticFeedback.lightImpact();
    await widget.onSend();
    // Hide the IME after send, but keep focus so the caret stays in
    // the field and a single tap brings the keyboard back.
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        child: widget.isLocked
            ? _LockedBanner()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkBackground
                            : AppTheme.lightBackground,
                        borderRadius: BorderRadius.circular(AppTheme.radius24),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        enabled: !widget.isSending,
                        maxLength: 50000,
                        minLines: 1,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        cursorColor: context.accentColor,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textPrimary
                              : AppTheme.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          // lint-allow: hardcoded-string
                          hintText: 'Reply...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppTheme.textTertiary
                                : AppTheme.textTertiaryLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  _SendButton(
                    isSending: widget.isSending,
                    onTap: _canSend ? _handleSend : null,
                  ),
                ],
              ),
      ),
    );
  }
}

/// 48×48 flat-circle accent send button. Matches [ChatComposer]'s
/// `_SendButton` exactly: `AnimatedContainer` fill, `BoxShape.circle`,
/// `Icons.send` at 20px, 30% alpha when disabled, white icon. No
/// elevation, no shadow, no Material/InkWell. While [isSending] is
/// true the icon is swapped for a small white progress indicator.
class _SendButton extends StatelessWidget {
  final bool isSending;
  final Future<void> Function()? onTap;

  const _SendButton({required this.isSending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final isEnabled = onTap != null && !isSending;

    return GestureDetector(
      onTap: isEnabled ? () => onTap!() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEnabled ? accentColor : accentColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  Icons.send,
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Locked banner — shown in place of the input when the thread is locked.
// ---------------------------------------------------------------------------

class _LockedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 16, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          // lint-allow: hardcoded-string
          'Thread is locked',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }
}
