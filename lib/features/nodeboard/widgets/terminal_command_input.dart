// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Terminal command input bar. Structurally identical to the Messages
// chat composer (see lib/features/messaging/widgets/chat_composer.dart
// and its wrapper in messaging_screen.dart): card-backed outer
// container with a top divider, SafeArea, a borderless rounded fill
// field, and a 48×48 flat-circle accent send button with Icons.send.
// The only BBS concessions are the monospace font and the inline `>`
// prompt glyph in the leading slot.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';

// lint-allow: hardcoded-string
const _kTerminalFontFamily = 'JetBrainsMono';

class TerminalCommandInput extends StatefulWidget {
  const TerminalCommandInput({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.promptGlyph = '>',
  });

  final void Function(String command) onSubmit;
  final bool enabled;
  final String promptGlyph;

  @override
  State<TerminalCommandInput> createState() => _TerminalCommandInputState();
}

class _TerminalCommandInputState extends State<TerminalCommandInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  void _handleSubmit([String? value]) {
    final trimmed = (value ?? _controller.text).trim();
    if (trimmed.isEmpty) return;
    AppLogging.nodeBoard('Terminal: input submitted "$trimmed"');
    HapticFeedback.lightImpact();
    widget.onSubmit(trimmed);
    _controller.clear();
    // Hide the on-screen keyboard but keep the field focused so the
    // caret stays visible and one tap brings the keyboard back.
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading `>` glyph — mirrors the ChatComposer `leading` slot
            // (e.g. quick-responses button in messaging_screen.dart).
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacing10),
              child: Text(
                widget.promptGlyph,
                style: TextStyle(
                  fontFamily: _kTerminalFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.accentColor,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground
                      : AppTheme.lightBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radius24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLength: 256,
                  onSubmitted: _handleSubmit,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.text,
                  cursorColor: context.accentColor,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontFamily: _kTerminalFontFamily,
                    fontSize: 16,
                    color: isDark
                        ? AppTheme.textPrimary
                        : AppTheme.textPrimaryLight,
                    height: 1.3,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    // lint-allow: hardcoded-string
                    hintText: 'type a command',
                    hintStyle: TextStyle(
                      fontFamily: _kTerminalFontFamily,
                      fontSize: 15,
                      color: isDark
                          ? AppTheme.textTertiary
                          : AppTheme.textTertiaryLight,
                      letterSpacing: 0.5,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            _SendButton(onTap: _canSend ? _handleSubmit : null),
          ],
        ),
      ),
    );
  }
}

/// 48×48 flat-circle accent send button. Matches
/// [ChatComposer]'s `_SendButton` exactly: `AnimatedContainer` fill,
/// `BoxShape.circle`, `Icons.send` at 20px, 30% alpha when disabled,
/// white icon. No elevation, no shadow, no Material/InkWell.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final isEnabled = onTap != null;

    return GestureDetector(
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
  }
}
