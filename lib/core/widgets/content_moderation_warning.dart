import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_bottom_sheet.dart';

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

/// Instagram-style content moderation warning dialog.
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
  /// Returns true if user chose to proceed, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required ContentModerationCheckResult result,
  }) async {
    final shouldProceed = await showModalBottomSheet<bool>(
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
    return shouldProceed ?? false;
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isBlocked ? Colors.red : Colors.orange).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBlocked ? Icons.block : Icons.warning_amber_rounded,
                  size: 32,
                  color: isBlocked ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isBlocked
                    ? 'Content Not Allowed'
                    : 'Content May Violate Guidelines',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isBlocked
                    ? 'Your content violates our Community Guidelines and cannot be posted.'
                    : 'Your content may violate our Community Guidelines. Please review before posting.',
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
            padding: const EdgeInsets.all(16),
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
                    const SizedBox(width: 8),
                    Text(
                      'Issues Detected',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.error.withAlpha(50),
                        ),
                      ),
                      child: Text(
                        _formatCategory(category),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: theme.hintColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBlocked
                        ? 'Repeated violations may result in account restrictions.'
                        : 'Posting content that violates our guidelines may result in content removal and account warnings.',
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                      Navigator.pop(context, false);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Content'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (onCancel != null) {
                          onCancel!();
                        } else {
                          Navigator.pop(context, false);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  // Show "Post Anyway" for warnings (not blocks)
                  // When using the static show() method, callbacks are null
                  // so we check !isBlocked to allow proceeding for flagged content
                  if (!isBlocked) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                          onProceedAnyway?.call();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                          side: BorderSide(color: Colors.orange.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Post Anyway'),
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

  String _formatCategory(String category) {
    // Convert category names to user-friendly display
    switch (category.toLowerCase()) {
      case 'sexual':
        return 'Sexual Content';
      case 'hate':
        return 'Hate Speech';
      case 'violence':
        return 'Violence';
      case 'profanity':
        return 'Profanity';
      case 'harassment':
        return 'Harassment';
      case 'spam':
        return 'Spam';
      case 'illegal':
        return 'Illegal Activity';
      case 'selfharm':
        return 'Self-Harm';
      case 'adult':
        return 'Adult Content';
      case 'racy':
        return 'Suggestive Content';
      default:
        return category
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
            })
            .join(' ');
    }
  }
}

/// Shows a snackbar notification when content was auto-rejected.
class ContentRejectionNotification {
  static void show(BuildContext context, {String? reason}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block, color: Colors.red, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content Removed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    reason ?? 'Your content violated our Community Guidelines.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: context.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Learn More',
          onPressed: () {
            // Could navigate to community guidelines
          },
        ),
      ),
    );
  }
}
