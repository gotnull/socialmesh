// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/markdown_formatting.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import 'app_bottom_sheet.dart';

/// Message-composer formatting toolbar mirroring the reference iOS client:
/// bold / italic / strikethrough / code buttons that wrap or toggle the
/// current selection with markdown delimiters (a collapsed cursor inserts
/// an empty pair), plus a link button that prompts for a URL and wraps the
/// selection as `[text](url)` (or unwraps an already-linked selection).
///
/// Buttons are plain gesture targets with no focus nodes, so tapping them
/// never dismisses the keyboard; every mutation is applied atomically via
/// `controller.value` and returns focus to the field.
class ChatFormattingToolbar extends StatelessWidget {
  const ChatFormattingToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The composer field's maxLength. Programmatic `controller.value` sets
  /// bypass the field's own input formatter, so the toolbar enforces the
  /// same ceiling itself and refuses (with an error haptic) any mutation
  /// that would exceed it. Byte-budget overrun stays permitted, exactly
  /// like typing: the composer's counter and send gating own that.
  final int maxLength;

  final bool enabled;

  // Canonical tap-target size from the reference iOS toolbar buttons.
  static const double _buttonMinWidth = 44;
  static const double _buttonMinHeight = 36;

  bool get _selectionValid => controller.selection.isValid;

  void _commit(FormattingResult result) {
    if (result.text.length > maxLength) {
      HapticFeedback.heavyImpact();
      return;
    }
    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.selectionStart,
        extentOffset: result.selectionEnd,
      ),
    );
    HapticFeedback.lightImpact();
    focusNode.requestFocus();
  }

  void _applyStyle(MarkdownStyle style) {
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final result = selection.isCollapsed
        ? insertDelimiters(value.text, selection.baseOffset, style)
        : wrapSelection(value.text, selection.start, selection.end, style);
    _commit(result);
  }

  Future<void> _applyLink(BuildContext context) async {
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid) return;

    final selectedText = selection.isCollapsed
        ? ''
        : value.text.substring(selection.start, selection.end);
    if (isMarkdownLink(selectedText)) {
      final result = unwrapLink(value.text, selection.start, selection.end);
      if (result != null) _commit(result);
      return;
    }

    // Capture text + offsets BEFORE the sheet: opening it moves focus and
    // can invalidate the selection.
    final textBefore = value.text;
    final start = selection.start;
    final end = selection.end;

    final url = await AppBottomSheet.show<String>(
      context: context,
      child: _InsertLinkSheet(maxLength: maxLength),
    );
    if (url == null || url.isEmpty) return;
    if (controller.text != textBefore) {
      // The field changed while the sheet was up; the captured offsets no
      // longer describe this text.
      HapticFeedback.heavyImpact();
      return;
    }
    _commit(wrapSelectionWithLink(textBefore, start, end, url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buttonsEnabled = enabled && _selectionValid;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarButton(
          icon: Icons.format_bold,
          label: l10n.formattingBoldLabel,
          enabled: buttonsEnabled,
          onTap: () => _applyStyle(MarkdownStyle.bold),
        ),
        _ToolbarButton(
          icon: Icons.format_italic,
          label: l10n.formattingItalicLabel,
          enabled: buttonsEnabled,
          onTap: () => _applyStyle(MarkdownStyle.italic),
        ),
        _ToolbarButton(
          icon: Icons.format_strikethrough,
          label: l10n.formattingStrikethroughLabel,
          enabled: buttonsEnabled,
          onTap: () => _applyStyle(MarkdownStyle.strikethrough),
        ),
        _ToolbarButton(
          icon: Icons.code,
          label: l10n.formattingCodeLabel,
          enabled: buttonsEnabled,
          onTap: () => _applyStyle(MarkdownStyle.code),
        ),
        _ToolbarButton(
          icon: Icons.link,
          label: l10n.formattingLinkLabel,
          enabled: buttonsEnabled,
          onTap: () => _applyLink(context),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: ChatFormattingToolbar._buttonMinWidth,
            height: ChatFormattingToolbar._buttonMinHeight,
            child: Icon(
              icon,
              size: AppTheme.spacing20,
              color: enabled ? context.textSecondary : context.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InsertLinkSheet extends StatefulWidget {
  const _InsertLinkSheet({required this.maxLength});

  final int maxLength;

  @override
  State<_InsertLinkSheet> createState() => _InsertLinkSheetState();
}

class _InsertLinkSheetState extends State<_InsertLinkSheet> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _pop(BuildContext context, String? result) =>
      Navigator.pop(context, result);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.formattingLinkSheetTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Text(
          l10n.formattingLinkSheetDescription,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacing16),
        BottomSheetTextField(
          controller: _urlController,
          label: l10n.formattingLinkUrlHint,
          hint: l10n.formattingLinkUrlHint,
          maxLength: widget.maxLength,
          autofocus: true,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => setState(() {}),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) _pop(context, value.trim());
          },
        ),
        const SizedBox(height: AppTheme.spacing24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pop(context, null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  side: BorderSide(color: SemanticColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(l10n.commonCancel),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: FilledButton(
                onPressed: _urlController.text.trim().isEmpty
                    ? null
                    : () => _pop(context, _urlController.text.trim()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  backgroundColor: context.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(l10n.formattingLinkInsertAction),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
