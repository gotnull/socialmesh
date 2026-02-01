// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/review_nudge_dialog.dart';
import 'package:socialmesh/providers/review_providers.dart';
import 'package:socialmesh/services/app_review_service.dart';

/// Mock InAppReview for testing
class MockAppReviewService extends AppReviewService {
  MockAppReviewService({required super.prefs});

  bool requestNativeReviewCalled = false;

  @override
  Future<bool> requestNativeReview() async {
    requestNativeReviewCalled = true;
    // Simulate brief delay
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return true;
  }
}

void main() {
  group('ReviewNudgeDialog', () {
    late SharedPreferences prefs;
    late MockAppReviewService mockService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockService = MockAppReviewService(prefs: prefs);
    });

    Widget buildTestWidget({required Widget child, AppReviewService? service}) {
      return ProviderScope(
        overrides: [
          appReviewServiceProvider.overrideWith(
            (ref) async => service ?? mockService,
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('displays title and subtitle', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enjoying Socialmesh?'), findsOneWidget);
      expect(
        find.text(
          'Your feedback helps us improve the app and reach more mesh enthusiasts.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays Rate it and Not now buttons', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Rate it'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('closes dialog when Not now is tapped', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enjoying Socialmesh?'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Enjoying Socialmesh?'), findsNothing);
    });

    testWidgets('calls native review when Rate it is tapped', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rate it'));
      await tester.pumpAndSettle();

      expect(mockService.requestNativeReviewCalled, isTrue);
    });

    testWidgets('shows loading spinner when Rate it is processing', (
      tester,
    ) async {
      // Create a slow mock service
      final slowService = _SlowMockAppReviewService(prefs: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          service: slowService,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap Rate it but don't settle - check for spinner
      await tester.tap(find.text('Rate it'));
      // Pump a few frames to let setState run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should show CircularProgressIndicator while loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let it finish - use timeout to avoid hanging if service is slow
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('disables Not now button during loading', (tester) async {
      final slowService = _SlowMockAppReviewService(prefs: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          service: slowService,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rate it'));
      // Pump a few frames to let setState run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Find the Not now button and check if it's disabled
      final notNowButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Not now'),
      );
      expect(notNowButton.onPressed, isNull);

      // Let it finish - use timeout to avoid hanging if service is slow
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('closes dialog after successful rate operation', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ReviewNudgeDialog.show(context, surface: 'test'),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enjoying Socialmesh?'), findsOneWidget);

      await tester.tap(find.text('Rate it'));
      await tester.pumpAndSettle();

      // Dialog should be closed after successful rate operation
      expect(find.text('Enjoying Socialmesh?'), findsNothing);
    });
  });
}

/// A mock that takes longer to respond, for testing loading states.
/// Uses delays that are long enough to catch intermediate states but
/// short enough to not slow down tests excessively.
class _SlowMockAppReviewService extends AppReviewService {
  _SlowMockAppReviewService({required super.prefs});

  @override
  Future<bool> requestNativeReview() async {
    // Long enough to observe loading state, short enough for fast tests
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<void> recordPromptShown(String surface) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await super.recordPromptShown(surface);
  }
}
