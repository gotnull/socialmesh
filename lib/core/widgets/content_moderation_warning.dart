// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import 'app_bottom_sheet.dart';
import '../../utils/snackbar.dart';
import 'package:socialmesh/core/theme.dart';

/// Action taken by user in content moderation dialog
enum ContentModerationAction { edit, cancel, proceed }

/// Result from content moderation check
class ContentModerationCheckResult {
  const ContentModerationCheckResult({
    required this.passed,
    required this.action,
    this.categories = const [],
    this.details,
  });

  final bool passed;
  final String action;
  final List<String> categories;
  final String? details;

  bool get shouldBlock => action == 'reject' || !passed;
  bool get shouldWarn => action == 'review' || action == 'flag';
}

/// Content moderation warning dialog.
/// Shows when user attempts to post content that violates guidelines.
class ContentModerationWarning extends StatelessWidget {
  const ContentModerationWarning({
    super.key,
    required this.result,
    required this.onEdit,
    required this.onCancel,
    this.onProceedAnyway,
  });

  final ContentModerationCheckResult result;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback? onProceedAnyway;

  /// Show the moderation warning as a bottom sheet.
  /// Returns ContentModerationAction indicating what user chose.
  static Future<ContentModerationAction> show(
    BuildContext context, {
    required ContentModerationCheckResult result,
  }) async {
    final action = await showModalBottomSheet<ContentModerationAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AppBottomSheet(
        child: SafeArea(
          top: false,
          child: _ContentModerationWarningContent(result: result),
        ),
      ),
    );
    return action ?? ContentModerationAction.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return _ContentModerationWarningContent(
      result: result,
      onEdit: onEdit,
      onCancel: onCancel,
      onProceedAnyway: onProceedAnyway,
    );
  }
}

class _ContentModerationWarningContent extends StatelessWidget {
  const _ContentModerationWarningContent({
    required this.result,
    this.onEdit,
    this.onCancel,
    this.onProceedAnyway,
  });

  final ContentModerationCheckResult result;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onProceedAnyway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBlocked = result.shouldBlock;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with warning icon
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing20, 24, 20, 16),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isBlocked ? AppTheme.errorRed : AccentColors.orange)
                      .withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBlocked ? Icons.block : Icons.warning_amber_rounded,
                  size: 32,
                  color: isBlocked ? AppTheme.errorRed : AccentColors.orange,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                isBlocked
                    ? context.l10n.contentModerationNotAllowedTitle
                    : context.l10n.contentModerationMayViolateTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                isBlocked
                    ? context.l10n.contentModerationBlockedMessage
                    : context.l10n.contentModerationWarningMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Violation categories
        if (result.categories.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.gpp_bad_outlined,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      context.l10n.contentModerationIssuesDetected,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.categories.map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(AppTheme.radius16),
                        border: Border.all(
                          color: theme.colorScheme.error.withAlpha(50),
                        ),
                      ),
                      child: Text(
                        _formatCategory(context, category),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        // Info box about consequences
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: theme.hintColor),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    isBlocked
                        ? context.l10n.contentModerationRepeatedViolations
                        : context.l10n.contentModerationPostingViolations,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 24),
          child: Column(
            children: [
              // Primary action: Edit content
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (onEdit != null) {
                      onEdit!();
                    } else {
                      Navigator.pop(context, ContentModerationAction.edit);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(context.l10n.contentModerationEditContent),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (onCancel != null) {
                          onCancel!();
                        } else {
                          Navigator.pop(
                            context,
                            ContentModerationAction.cancel,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ),
                  // Show "Post Anyway" for warnings (not blocks)
                  // When using the static show() method, callbacks are null
                  // so we check !isBlocked to allow proceeding for flagged content
                  if (!isBlocked) ...[
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            ContentModerationAction.proceed,
                          );
                          onProceedAnyway?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AccentColors.orange,
                          side: BorderSide(color: AccentColors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(context.l10n.contentModerationPostAnyway),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCategory(BuildContext context, String category) {
    // Convert category names to user-friendly display
    switch (category.toLowerCase()) {
      case 'sexual':
        return context.l10n.contentModerationSexualContent;
      case 'hate':
        return context.l10n.contentModerationHateSpeech;
      case 'violence':
        return context.l10n.contentModerationViolence;
      case 'profanity':
        return context.l10n.contentModerationProfanity;
      case 'harassment':
        return context.l10n.contentModerationHarassment;
      case 'spam':
        return context.l10n.contentModerationSpam;
      case 'illegal':
        return context.l10n.contentModerationIllegalActivity;
      case 'selfharm':
        return context.l10n.contentModerationSelfHarm;
      case 'adult':
        return context.l10n.contentModerationAdultContent;
      case 'racy':
        return context.l10n.contentModerationSuggestiveContent;
      default:
        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) {
              final chars = word.characters;
              if (chars.isEmpty) return word;
              final first = chars.first;
              final rest = chars.skip(1).string;
              return '${first.toUpperCase()}${rest.toLowerCase()}';
            })
            .join(' ');
    }
  }
}

/// Shows a snackbar notification when content was auto-rejected.
class ContentRejectionNotification {
  static void show(BuildContext context, {String? reason}) {
    final message = reason != null
        ? context.l10n.contentModerationRemovedWithReason(reason)
        : context.l10n.contentModerationRemovedGeneric;

    showActionSnackBar(
      context,
      message,
      actionLabel: context.l10n.contentModerationLearnMore,
      onAction: () {
        // Could navigate to community guidelines
      },
      type: SnackBarType.error,
      duration: const Duration(seconds: 5),
    );
  }
}
