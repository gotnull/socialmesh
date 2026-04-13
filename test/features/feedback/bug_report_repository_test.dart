// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/admin/bug_reports/admin_bug_report_providers.dart';
import 'package:socialmesh/features/feedback/bug_report_repository.dart';

void main() {
  group('hydrateBugReports', () {
    test('preserves report order and marks threads as loaded', () {
      final reports = [
        BugReport(
          id: 'report-a',
          description: 'First report',
          createdAt: DateTime(2026, 4, 13),
          responsesLoaded: false,
        ),
        BugReport(
          id: 'report-b',
          description: 'Second report',
          createdAt: DateTime(2026, 4, 12),
          responsesLoaded: false,
        ),
      ];

      final hydrated = hydrateBugReports(
        reports: reports,
        responsesByReportId: {
          'report-b': [
            BugReportResponse(
              id: 'response-1',
              from: 'founder',
              message: 'Need a few more details.',
              createdAt: DateTime(2026, 4, 13, 9),
            ),
          ],
        },
      );

      expect(hydrated.map((report) => report.id).toList(), [
        'report-a',
        'report-b',
      ]);
      expect(hydrated.every((report) => report.responsesLoaded), isTrue);
      expect(hydrated[0].responses, isEmpty);
      expect(hydrated[1].responses.single.message, 'Need a few more details.');
    });
  });

  group('admin bug report hydration', () {
    test('counts only unread user replies for admins', () {
      final responses = [
        BugReportResponse(
          id: 'founder-1',
          from: 'founder',
          message: 'We are investigating this.',
          createdAt: DateTime(2026, 4, 13, 8),
        ),
        BugReportResponse(
          id: 'user-1',
          from: 'user',
          message: 'It still happens on startup.',
          createdAt: DateTime(2026, 4, 13, 9),
        ),
        BugReportResponse(
          id: 'user-2',
          from: 'user',
          message: 'Here is another screenshot.',
          createdAt: DateTime(2026, 4, 13, 10),
        ),
      ];

      final unreadCount = countUnreadUserRepliesForAdmin(
        responses: responses,
        readByAdminFlags: [true, false, true],
      );

      expect(unreadCount, 1);
    });

    test('hydrates admin reports with unread counts and loaded threads', () {
      final reports = [
        AdminBugReport(
          id: 'admin-report',
          description: 'Crash when opening map',
          createdAt: DateTime(2026, 4, 13),
          responsesLoaded: false,
        ),
      ];

      final hydrated = hydrateAdminBugReports(
        reports: reports,
        threadDataByReportId: {
          'admin-report': AdminBugReportThreadData(
            responses: [
              BugReportResponse(
                id: 'user-1',
                from: 'user',
                message: 'The app freezes after the first pan.',
                createdAt: DateTime(2026, 4, 13, 11),
              ),
            ],
            readByAdminFlags: [false],
          ),
        },
      );

      expect(hydrated.single.responsesLoaded, isTrue);
      expect(hydrated.single.hasUnreadUserReplies, isTrue);
      expect(hydrated.single.unreadUserReplyCount, 1);
      expect(hydrated.single.responses.single.isFromUser, isTrue);
    });
  });
}
