// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/app_review_service.dart';

void main() {
  group('AppReviewService', () {
    late SharedPreferences prefs;
    late AppReviewService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = AppReviewService(prefs: prefs);
    });

    group('recordSession', () {
      test('records install date on first session', () async {
        expect(service.installDate, isNull);
        await service.recordSession();
        expect(service.installDate, isNotNull);
      });

      test('increments session count', () async {
        expect(service.sessionCount, 0);
        await service.recordSession();
        expect(service.sessionCount, 1);
        await service.recordSession();
        expect(service.sessionCount, 2);
      });

      test('does not overwrite existing install date', () async {
        await service.recordSession();
        final firstInstallDate = service.installDate;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await service.recordSession();
        expect(service.installDate, firstInstallDate);
      });
    });

    group('recordMessageSent', () {
      test('increments message count and returns new count', () async {
        expect(service.messagesSentCount, 0);
        final count1 = await service.recordMessageSent();
        expect(count1, 1);
        expect(service.messagesSentCount, 1);

        final count2 = await service.recordMessageSent();
        expect(count2, 2);
        expect(service.messagesSentCount, 2);
      });
    });

    group('checkEligibility', () {
      test('returns false when session count is below minimum', () async {
        // Only 2 sessions, need 5
        await service.recordSession();
        await service.recordSession();

        final result = service.checkEligibility(
          minSessions: 5,
          minSinceInstall: Duration.zero,
          cooldown: Duration.zero,
        );
        expect(result.eligible, isFalse);
        expect(result.reason, contains('INSUFFICIENT_SESSIONS'));
      });

      test('returns false when install date is too recent', () async {
        // Record enough sessions
        for (var i = 0; i < 10; i++) {
          await service.recordSession();
        }

        // Install date was just now (< 7 days)
        final result = service.checkEligibility(
          minSessions: 5,
          minSinceInstall: const Duration(days: 7),
          cooldown: Duration.zero,
        );
        expect(result.eligible, isFalse);
        expect(result.reason, contains('TOO_SOON_AFTER_INSTALL'));
      });

      test('returns false when within cooldown period', () async {
        // Set up a past install date (30 days ago)
        final oldDate = DateTime.now().subtract(const Duration(days: 30));
        await prefs.setInt('review_install_at', oldDate.millisecondsSinceEpoch);
        // Record enough sessions
        await prefs.setInt('review_session_count', 10);

        // Set last prompt to yesterday
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await prefs.setInt(
          'review_last_prompt_at',
          yesterday.millisecondsSinceEpoch,
        );

        // Refresh service to pick up new prefs
        service = AppReviewService(prefs: prefs);

        // Cooldown is 90 days, last prompt was yesterday
        final result = service.checkEligibility(
          minSessions: 5,
          minSinceInstall: const Duration(days: 7),
          cooldown: const Duration(days: 90),
        );
        expect(result.eligible, isFalse);
        expect(result.reason, contains('COOLDOWN_ACTIVE'));
      });

      test('returns true when all criteria are met', () async {
        // Set up a past install date (30 days ago)
        final oldDate = DateTime.now().subtract(const Duration(days: 30));
        await prefs.setInt('review_install_at', oldDate.millisecondsSinceEpoch);
        // Record enough sessions
        await prefs.setInt('review_session_count', 10);
        // No previous prompt

        // Refresh service to pick up new prefs
        service = AppReviewService(prefs: prefs);

        final result = service.checkEligibility(
          minSessions: 5,
          minSinceInstall: const Duration(days: 7),
          cooldown: const Duration(days: 90),
        );
        expect(result.eligible, isTrue);
        expect(result.reason, equals('ALL_CRITERIA_MET'));
      });

      test('returns true when cooldown has passed', () async {
        // Set up a past install date (180 days ago)
        final oldDate = DateTime.now().subtract(const Duration(days: 180));
        await prefs.setInt('review_install_at', oldDate.millisecondsSinceEpoch);
        // Record enough sessions
        await prefs.setInt('review_session_count', 10);

        // Set last prompt to 100 days ago (past 90-day cooldown)
        final oldPrompt = DateTime.now().subtract(const Duration(days: 100));
        await prefs.setInt(
          'review_last_prompt_at',
          oldPrompt.millisecondsSinceEpoch,
        );

        // Refresh service to pick up new prefs
        service = AppReviewService(prefs: prefs);

        final result = service.checkEligibility(
          minSessions: 5,
          minSinceInstall: const Duration(days: 7),
          cooldown: const Duration(days: 90),
        );
        expect(result.eligible, isTrue);
        expect(result.reason, equals('ALL_CRITERIA_MET'));
      });
    });

    group('recordPromptShown', () {
      test('updates last prompt date and increments count', () async {
        expect(service.lastPromptDate, isNull);
        expect(service.promptCount, 0);

        await service.recordPromptShown('test_surface');

        expect(service.lastPromptDate, isNotNull);
        expect(service.promptCount, 1);

        await service.recordPromptShown('test_surface_2');
        expect(service.promptCount, 2);
      });
    });

    group('edge cases', () {
      test('handles zero minimum requirements', () async {
        await service.recordSession();

        final result = service.checkEligibility(
          minSessions: 0,
          minSinceInstall: Duration.zero,
          cooldown: Duration.zero,
        );
        expect(result.eligible, isTrue);
      });

      test('handles exactly at threshold values', () async {
        // Set install date to exactly 7 days ago
        final exactlySevenDays = DateTime.now().subtract(
          const Duration(days: 7),
        );
        await prefs.setInt(
          'review_install_at',
          exactlySevenDays.millisecondsSinceEpoch,
        );
        // Set exactly 5 sessions
        await prefs.setInt('review_session_count', 5);

        service = AppReviewService(prefs: prefs);

        final result = service.checkEligibility(
          minSessions: 5,
          minSinceInstall: const Duration(days: 7),
          cooldown: Duration.zero,
        );
        expect(result.eligible, isTrue);
      });

      test('handles pre-existing data from previous app version', () async {
        // Simulate partial data from previous version (no install date)
        await prefs.setInt('review_session_count', 20);

        service = AppReviewService(prefs: prefs);

        // Should still work - recordSession will set install date
        await service.recordSession();
        expect(service.installDate, isNotNull);
        expect(service.sessionCount, 21);
      });
    });
  });
}
