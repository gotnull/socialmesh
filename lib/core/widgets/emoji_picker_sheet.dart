// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme.dart';
import '../widgets/app_bottom_sheet.dart';

/// Full emoji picker powered by emoji_picker_flutter.
///
/// Shows the complete Unicode emoji set with categories, search, recents, and
/// skin tone selection — no hardcoded emoji lists. Shared between message
/// tapbacks and waypoint icons; present it via [showEmojiPickerSheet].
class EmojiPickerSheet extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;

  const EmojiPickerSheet({super.key, required this.onEmojiSelected});

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
                    context.l10n.messageContextMenuNoRecents,
                    style: TextStyle(fontSize: 16, color: context.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                  loadingIndicator: const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                ),
                skinToneConfig: const SkinToneConfig(
                  enabled: true,
                  dialogBackgroundColor: AppTheme.darkSurface,
                  indicatorColor: SemanticColors.disabled,
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
                  hintText: context.l10n.messageContextMenuSearchEmoji,
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

/// Present the shared [EmojiPickerSheet] as a draggable bottom sheet and
/// resolve to the picked emoji string (or null if dismissed).
Future<String?> showEmojiPickerSheet(BuildContext context) {
  return AppBottomSheet.showRaw<String>(
    context: context,
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (_, scrollController) => EmojiPickerSheet(
        onEmojiSelected: (emoji) => Navigator.pop(sheetCtx, emoji),
      ),
    ),
  );
}
