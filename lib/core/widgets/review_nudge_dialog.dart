// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../safety/lifecycle_mixin.dart';
import '../widgets/app_bottom_sheet.dart';
import '../../providers/review_providers.dart';
import 'package:socialmesh/core/theme.dart';

/// A dialog that asks the user if they're enjoying the app and offers
/// to prompt for a review.
///
/// This follows the pattern of showing a custom dialog first, then
/// only calling the native review prompt if the user taps "Rate it".
class ReviewNudgeDialog extends ConsumerStatefulWidget {
  const ReviewNudgeDialog({super.key, required this.surface});

  /// Identifies where this dialog was triggered from (for analytics)
  final String surface;

  /// Show the review nudge dialog.
  ///
  /// Returns true if the user tapped "Rate it" and we called the native
  /// review prompt, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String surface,
  }) async {
    final result = await AppBottomSheet.show<bool>(
      context: context,
      child: ReviewNudgeDialog(surface: surface),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ReviewNudgeDialog> createState() => _ReviewNudgeDialogState();
}

class _ReviewNudgeDialogState extends ConsumerState<ReviewNudgeDialog>
    with LifecycleSafeMixin<ReviewNudgeDialog> {
  bool _isLoading = false;

  Future<void> _handleRateIt() async {
    safeSetState(() => _isLoading = true);

    // Capture provider ref before await
    final reviewServiceFuture = ref.read(appReviewServiceProvider.future);

    try {
      final reviewService = await reviewServiceFuture;
      if (!mounted) return;

      // Record that we showed the prompt
      await reviewService.recordPromptShown(widget.surface);

      // Request the native review
      await reviewService.requestNativeReview();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      Navigator.of(context).pop(false);
    }
  }

  void _handleNotNow() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.favorite_rounded,
            size: 32,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          'Enjoying Socialmesh?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacing12),
        Text(
          'Your feedback helps us improve the app and reach more mesh enthusiasts.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacing24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleNotNow,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                child: Text(
                  'Not now',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _handleRateIt,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                ),
                icon: _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.star_rounded, size: 18),
                label: Text(_isLoading ? 'Opening...' : 'Rate it'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
