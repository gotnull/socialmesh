// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_review_service.dart';
import '../core/widgets/review_nudge_dialog.dart';

/// Provider for the AppReviewService.
/// Initializes lazily and caches the instance.
final appReviewServiceProvider = FutureProvider<AppReviewService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return AppReviewService(prefs: prefs);
});

/// Extension on WidgetRef for convenient review prompting.
extension ReviewPromptExtension on WidgetRef {
  /// Attempt to show a review prompt if eligibility criteria are met.
  ///
  /// This is a convenience method that handles the full flow:
  /// 1. Check eligibility
  /// 2. Show the custom dialog
  /// 3. Handle the native review request
  ///
  /// [context] is required to show the dialog.
  /// [surface] identifies where this was triggered from (for analytics).
  Future<void> maybePromptForReview(
    BuildContext context, {
    required String surface,
    int minSessions = 5,
    Duration minSinceInstall = const Duration(days: 7),
    Duration cooldown = const Duration(days: 90),
  }) async {
    try {
      final reviewService = await read(appReviewServiceProvider.future);

      final shouldPrompt = await reviewService.maybePromptForReview(
        surface: surface,
        minSessions: minSessions,
        minSinceInstall: minSinceInstall,
        cooldown: cooldown,
      );

      if (shouldPrompt && context.mounted) {
        await ReviewNudgeDialog.show(context, surface: surface);
      }
    } catch (e) {
      // Silently fail - review prompts are non-critical
      debugPrint('[AppReview] Error prompting for review: $e');
    }
  }
}
