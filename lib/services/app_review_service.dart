// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for SharedPreferences storage
class _ReviewKeys {
  static const String installAt = 'review_install_at';
  static const String sessionCount = 'review_session_count';
  static const String lastPromptAt = 'review_last_prompt_at';
  static const String promptCount = 'review_prompt_count';
  static const String messagesSentCount = 'review_messages_sent_count';
}

/// Service for managing in-app review prompts with rate limiting.
///
/// Uses iOS StoreKit / Android Play In-App Review via the in_app_review plugin.
/// Tracks install time, session count, and prompt history to avoid spamming users.
class AppReviewService {
  AppReviewService({required SharedPreferences prefs, InAppReview? inAppReview})
    : _prefs = prefs,
      _inAppReview = inAppReview ?? InAppReview.instance;

  final SharedPreferences _prefs;
  final InAppReview _inAppReview;

  /// Log a structured review event for analytics/debugging
  void _log(String event, [Map<String, dynamic>? data]) {
    final message = data != null ? '$event: $data' : event;
    debugPrint('[AppReview] $message');
  }

  /// Initialize the service - call once at app startup.
  /// Records install time if not already set and increments session count.
  Future<void> recordSession() async {
    // Record install time on first run
    if (_prefs.getInt(_ReviewKeys.installAt) == null) {
      await _prefs.setInt(
        _ReviewKeys.installAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    // Increment session count
    final sessions = (_prefs.getInt(_ReviewKeys.sessionCount) ?? 0) + 1;
    await _prefs.setInt(_ReviewKeys.sessionCount, sessions);

    _log('SESSION_RECORDED', {'sessionCount': sessions});
  }

  /// Increment the count of messages sent by the user.
  /// Used to trigger review prompts after milestone message counts.
  /// Returns the new count.
  Future<int> recordMessageSent() async {
    final count = (_prefs.getInt(_ReviewKeys.messagesSentCount) ?? 0) + 1;
    await _prefs.setInt(_ReviewKeys.messagesSentCount, count);
    return count;
  }

  /// Get the number of messages sent
  int get messagesSentCount =>
      _prefs.getInt(_ReviewKeys.messagesSentCount) ?? 0;

  /// Get the current session count
  int get sessionCount => _prefs.getInt(_ReviewKeys.sessionCount) ?? 0;

  /// Get the install date
  DateTime? get installDate {
    final timestamp = _prefs.getInt(_ReviewKeys.installAt);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Get the last prompt date
  DateTime? get lastPromptDate {
    final timestamp = _prefs.getInt(_ReviewKeys.lastPromptAt);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Get the total number of times we've prompted
  int get promptCount => _prefs.getInt(_ReviewKeys.promptCount) ?? 0;

  /// Check if the user is eligible for a review prompt.
  ///
  /// Returns a tuple of (eligible, reason) where reason explains why
  /// the user is or isn't eligible.
  ({bool eligible, String reason}) checkEligibility({
    int minSessions = 5,
    Duration minSinceInstall = const Duration(days: 7),
    Duration cooldown = const Duration(days: 90),
  }) {
    final now = DateTime.now();

    // Check session count
    final sessions = sessionCount;
    if (sessions < minSessions) {
      return (
        eligible: false,
        reason: 'INSUFFICIENT_SESSIONS ($sessions < $minSessions)',
      );
    }

    // Check time since install
    final install = installDate;
    if (install == null) {
      return (eligible: false, reason: 'NO_INSTALL_DATE');
    }

    final daysSinceInstall = now.difference(install);
    if (daysSinceInstall < minSinceInstall) {
      return (
        eligible: false,
        reason:
            'TOO_SOON_AFTER_INSTALL (${daysSinceInstall.inDays} < ${minSinceInstall.inDays} days)',
      );
    }

    // Check cooldown since last prompt
    final lastPrompt = lastPromptDate;
    if (lastPrompt != null) {
      final daysSincePrompt = now.difference(lastPrompt);
      if (daysSincePrompt < cooldown) {
        return (
          eligible: false,
          reason:
              'COOLDOWN_ACTIVE (${daysSincePrompt.inDays} < ${cooldown.inDays} days)',
        );
      }
    }

    return (eligible: true, reason: 'ALL_CRITERIA_MET');
  }

  /// Attempt to prompt for a review if eligibility criteria are met.
  ///
  /// [surface] identifies where in the app this was triggered from (for analytics).
  /// [minSessions] minimum number of app sessions before prompting (default: 5).
  /// [minSinceInstall] minimum time since first install (default: 7 days).
  /// [cooldown] minimum time between prompts (default: 90 days).
  ///
  /// Returns true if the prompt was shown, false otherwise.
  Future<bool> maybePromptForReview({
    required String surface,
    int minSessions = 5,
    Duration minSinceInstall = const Duration(days: 7),
    Duration cooldown = const Duration(days: 90),
  }) async {
    final eligibility = checkEligibility(
      minSessions: minSessions,
      minSinceInstall: minSinceInstall,
      cooldown: cooldown,
    );

    if (!eligibility.eligible) {
      _log('REVIEW_PROMPT_SKIPPED_${eligibility.reason}', {'surface': surface});
      return false;
    }

    _log('REVIEW_PROMPT_ELIGIBLE', {
      'surface': surface,
      'sessions': sessionCount,
      'promptCount': promptCount,
    });

    return true;
  }

  /// Record that a prompt was shown to the user.
  /// Call this when showing the custom dialog.
  Future<void> recordPromptShown(String surface) async {
    final now = DateTime.now();
    await _prefs.setInt(_ReviewKeys.lastPromptAt, now.millisecondsSinceEpoch);
    await _prefs.setInt(_ReviewKeys.promptCount, promptCount + 1);
    _log('REVIEW_PROMPT_SHOWN_CUSTOM', {'surface': surface});
  }

  /// Request the native review dialog.
  /// Returns true if requestReview() was called, false if we fell back to store listing.
  Future<bool> requestNativeReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();

      if (isAvailable) {
        _log('REVIEW_REQUEST_CALLED');
        await _inAppReview.requestReview();
        return true;
      } else {
        _log('REVIEW_FALLBACK_STORE_LISTING', {'reason': 'not_available'});
        await _inAppReview.openStoreListing(
          appStoreId: '6475642447', // iOS App Store ID
        );
        return false;
      }
    } catch (e) {
      _log('REVIEW_FALLBACK_STORE_LISTING', {'reason': 'error', 'error': '$e'});
      try {
        await _inAppReview.openStoreListing(appStoreId: '6475642447');
      } catch (_) {
        // Ignore fallback errors
      }
      return false;
    }
  }

  /// Open the store listing directly (for manual "Rate Us" buttons).
  Future<void> openStoreListing() async {
    _log('REVIEW_STORE_LISTING_OPENED');
    await _inAppReview.openStoreListing(appStoreId: '6475642447');
  }
}
