// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../services/protocol/text_message_payload_budget.dart';

typedef ChatComposerBudgetResolver =
    TextMessagePayloadBudget Function(String text);
typedef ChatComposerBudgetLabelBuilder =
    String Function(BuildContext context, TextMessagePayloadBudget budget);

/// A chat message composer with multiline input, an explicit Send button,
/// and keyboard shortcuts (Ctrl/Cmd+Enter to send).
///
/// Matches the Meshtastic iOS pattern:
/// - Enter inserts a newline and the field grows vertically.
/// - The Send button stays visible but only enables for sendable drafts.
/// - Ctrl/Cmd+Enter sends on desktop / hardware keyboards.
/// - The input grows from 1 line up to [maxLines] (default 6) before scrolling.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.hintText,
    this.maxLength = 500,
    this.minLines = 1,
    this.maxLines = 6,
    this.leading,
    this.sendTooltip,
    this.enabled = true,
    this.budgetResolver,
    this.budgetLabelBuilder,
  }) : assert(
         budgetResolver == null || budgetLabelBuilder != null,
         'budgetLabelBuilder is required when budgetResolver is set',
       );

  /// Controller for the text input.
  final TextEditingController controller;

  /// Focus node for the text input.
  final FocusNode focusNode;

  /// Callback invoked when the user triggers send (button tap or Ctrl/Cmd+Enter).
  /// The caller is responsible for validation, clearing the controller, and
  /// managing focus.
  final VoidCallback onSend;

  /// Hint text displayed in the input when empty.
  final String hintText;

  /// Maximum character length for the input.
  final int maxLength;

  /// Minimum visible lines (default 1).
  final int minLines;

  /// Maximum visible lines before the input scrolls (default 6).
  final int maxLines;

  /// Optional widget placed before the text field (e.g. quick-responses button).
  final Widget? leading;

  /// Tooltip for the send button. Shown on long-press / hover.
  final String? sendTooltip;

  /// Whether the input is enabled. When false, the text field is read-only
  /// and the send button is hidden.
  final bool enabled;

  /// Optional budget resolver used to show a live counter and disable send
  /// when the draft does not fit the outgoing packet envelope.
  final ChatComposerBudgetResolver? budgetResolver;

  /// Localized label builder for the live message budget counter.
  final ChatComposerBudgetLabelBuilder? budgetLabelBuilder;

  bool _canSend(String text) {
    if (!enabled) return false;

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;

    final budget = budgetResolver?.call(trimmedText);
    return budget?.fitsInPacket ?? true;
  }

  /// Handles the Ctrl/Cmd+Enter keyboard shortcut to send.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (!isEnter) return KeyEventResult.ignored;

    final isModifierPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isModifierPressed) {
      if (_canSend(controller.text)) {
        onSend();
      }
      return KeyEventResult.handled;
    }

    // Plain Enter → let the TextField handle it (inserts newline).
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final composerListenable = Listenable.merge([controller, focusNode]);

    return ListenableBuilder(
      listenable: composerListenable,
      builder: (context, _) {
        final trimmedText = controller.text.trim();
        final hasText = trimmedText.isNotEmpty;
        final budget = budgetResolver?.call(trimmedText);
        final canSend = _canSend(controller.text);
        final counterText = budget != null && budgetLabelBuilder != null
            ? budgetLabelBuilder!(context, budget)
            : null;
        final showCounter =
            enabled &&
            counterText != null &&
            (focusNode.hasFocus || hasText || !(budget?.fitsInPacket ?? true));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                child: leading!,
              ),
              const SizedBox(width: AppTheme.spacing8),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkBackground
                          : AppTheme.lightBackground,
                      borderRadius: BorderRadius.circular(AppTheme.radius24),
                    ),
                    child: Focus(
                      onKeyEvent: _handleKeyEvent,
                      child: TextField(
                        maxLength: maxLength,
                        controller: controller,
                        focusNode: focusNode,
                        enabled: enabled,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textPrimary
                              : AppTheme.textPrimaryLight,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: minLines,
                        maxLines: maxLines,
                        decoration: InputDecoration(
                          hintText: hintText,
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
                  if (showCounter)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppTheme.spacing4,
                        right: AppTheme.spacing8,
                      ),
                      child: Text(
                        counterText,
                        key: const Key('chat-composer-byte-counter'),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: budget?.fitsInPacket ?? true
                              ? (isDark
                                    ? AppTheme.textTertiary
                                    : AppTheme.textTertiaryLight)
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: AppTheme.spacing12),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing0),
                child: _SendButton(
                  onTap: canSend ? onSend : null,
                  tooltip: sendTooltip,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, this.tooltip});

  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final isEnabled = onTap != null;

    final button = GestureDetector(
      onTap: isEnabled
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isEnabled ? accentColor : accentColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send,
          color: isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
          size: 20,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
