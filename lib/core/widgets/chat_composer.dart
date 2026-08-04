// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../../services/protocol/text_message_payload_budget.dart';
import 'chat_formatting_toolbar.dart';

typedef ChatComposerBudgetResolver =
    TextMessagePayloadBudget Function(String text);
typedef ChatComposerBudgetLabelBuilder =
    String Function(BuildContext context, TextMessagePayloadBudget budget);

/// Blocks edits that would push the field past [maxBytes] UTF-8 bytes.
///
/// Flutter's built-in length limiting counts characters, so a character cap
/// under-constrains multi-byte text (umlauts, emoji) when the wire budget is
/// measured in bytes. Shrinking edits are always allowed so an over-budget
/// draft (e.g. after a reply context tightens the budget) can still be
/// deleted back under the limit.
class Utf8LengthLimitingTextInputFormatter extends TextInputFormatter {
  const Utf8LengthLimitingTextInputFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newBytes = utf8.encode(newValue.text).length;
    if (newBytes <= maxBytes) return newValue;
    if (newBytes <= utf8.encode(oldValue.text).length) return newValue;
    return oldValue;
  }
}

/// A neutral chat message composer with multiline input, an explicit Send
/// button, and keyboard shortcuts.
///
/// Protocol-specific screens own validation, send behavior, and any state.
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
    this.enableFormattingToolbar = false,
    this.budgetResolver,
    this.budgetLabelBuilder,
  }) : assert(
         budgetResolver == null || budgetLabelBuilder != null,
         'budgetLabelBuilder is required when budgetResolver is set',
       );

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final String hintText;

  /// Maximum UTF-8 bytes accepted by the field. Enforced by a byte-aware
  /// input formatter in addition to Flutter's character-based `maxLength`,
  /// so multi-byte text cannot be typed past a byte-measured wire budget.
  final int maxLength;
  final int minLines;
  final int maxLines;
  final Widget? leading;
  final String? sendTooltip;
  final bool enabled;

  /// Shows the markdown formatting toolbar above the field while it has
  /// focus. Off by default; only surfaces whose peers render inline
  /// markdown (Meshtastic messaging) should enable it.
  final bool enableFormattingToolbar;

  final ChatComposerBudgetResolver? budgetResolver;
  final ChatComposerBudgetLabelBuilder? budgetLabelBuilder;

  bool _canSend(String text) {
    if (!enabled) return false;
    if (!TextMessagePayloadSizer.hasSendableContent(text)) return false;

    final budget = budgetResolver?.call(text);
    return budget?.fitsInPacket ?? true;
  }

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

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final composerListenable = Listenable.merge([controller, focusNode]);

    return ListenableBuilder(
      listenable: composerListenable,
      builder: (context, _) {
        final rawText = controller.text;
        final hasText = rawText.isNotEmpty;
        final budget = budgetResolver?.call(rawText);
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
                  if (enableFormattingToolbar)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.topCenter,
                      child: enabled && focusNode.hasFocus
                          ? Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.spacing4,
                              ),
                              child: ChatFormattingToolbar(
                                controller: controller,
                                focusNode: focusNode,
                                maxLength: maxLength,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
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
                        inputFormatters: [
                          Utf8LengthLimitingTextInputFormatter(maxLength),
                        ],
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
                            horizontal: AppTheme.spacing20,
                            vertical: AppTheme.spacing12,
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
              _SendButton(onTap: canSend ? onSend : null, tooltip: sendTooltip),
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
