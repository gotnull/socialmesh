// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
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
}
