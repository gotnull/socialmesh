// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Reusable bottom sheet for editing the user-authored note attached to a
// NodeDex entry. Mirrors the visual + behavioural contract of the inline
// note editor on the full NodeDex detail screen (same hint, save/cancel
// chips, 280-char limit, setUserNote dispatch through NodeDexNotifier).
// Invokable from any screen that has a node_num + the current note so
// note editing UX is identical everywhere (Node Details preview card,
// NodeDex detail screen, future call sites).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../providers/nodedex_providers.dart';

class NodeNoteEditSheet extends ConsumerStatefulWidget {
  const NodeNoteEditSheet({
    super.key,
    required this.nodeNum,
    required this.initialNote,
  });

  final int nodeNum;
  final String? initialNote;

  static const int maxLength = 280;

  /// Opens the sheet wrapped in [AppBottomSheet.show]. Callers pass the
  /// current note text so the field hydrates without an extra read.
  static Future<void> show({
    required BuildContext context,
    required int nodeNum,
    required String? initialNote,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      child: NodeNoteEditSheet(nodeNum: nodeNum, initialNote: initialNote),
    );
  }

  @override
  ConsumerState<NodeNoteEditSheet> createState() => _NodeNoteEditSheetState();
}

class _NodeNoteEditSheetState extends ConsumerState<NodeNoteEditSheet>
    with LifecycleSafeMixin<NodeNoteEditSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    HapticFeedback.selectionClick();
    final raw = _controller.text.trim();
    final next = raw.isEmpty ? null : raw;
    ref.read(nodeDexProvider.notifier).setUserNote(widget.nodeNum, next);
    AppLogging.nodes(
      '[NodeNoteEdit] saved nodeNum=${widget.nodeNum} '
      'len=${next?.length ?? 0}',
    );
    FocusScope.of(context).unfocus();
    safeNavigatorPop();
  }

  void _cancel() {
    HapticFeedback.lightImpact();
    AppLogging.nodes('[NodeNoteEdit] cancelled nodeNum=${widget.nodeNum}');
    FocusScope.of(context).unfocus();
    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final hasInitial = (widget.initialNote ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasInitial
                    ? context.l10n.nodedexNoteEdit
                    : context.l10n.nodedexNoteAdd,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: _cancel,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing10,
                  vertical: AppTheme.spacing5,
                ),
                decoration: BoxDecoration(
                  color: context.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Text(
                  context.l10n.nodedexNoteCancel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing10,
                  vertical: AppTheme.spacing5,
                ),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Text(
                  context.l10n.nodedexNoteSave,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.accentColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: 5,
          minLines: 3,
          maxLength: NodeNoteEditSheet.maxLength,
          scrollPadding: const EdgeInsets.all(AppTheme.spacing80),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: context.l10n.nodedexNoteHint,
            hintStyle: TextStyle(fontSize: 14, color: context.textTertiary),
            filled: true,
            fillColor: context.background,
            contentPadding: const EdgeInsets.all(AppTheme.spacing12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              borderSide: BorderSide(
                color: context.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              borderSide: BorderSide(
                color: context.accentColor.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final remaining =
                NodeNoteEditSheet.maxLength - value.text.characters.length;
            final low = remaining < 20;
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 11,
                  color: low ? AccentColors.orange : context.textTertiary,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
