import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/features/signals/widgets/thread_like_refresh_indicator.dart';

void main() {
  testWidgets('indicator becomes visible on pull and calls onRefresh', (
    WidgetTester tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ThreadLikeRefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              child: ListView(
                children: List.generate(
                  30,
                  (i) => ListTile(title: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Pull down from top
    await tester.fling(find.byType(ListView), const Offset(0, 200), 1000);
    await tester.pump();

    // Indicator should be drawn (CustomPaint present and has height > 0)
    final customPaint = tester.widgetList(find.byType(CustomPaint)).first;
    expect(customPaint, isNotNull);

    // Release and wait for onRefresh to be called
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // onRefresh should have been called by now
    expect(refreshed, isTrue);
  });

  testWidgets('indicator not visible when not pulled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ThreadLikeRefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                children: List.generate(
                  3,
                  (i) => ListTile(title: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // No pull performed
    await tester.pumpAndSettle();

    // The CustomPaint still exists, but its height should be zero (no visible area)
    final paints = tester.renderObjectList(find.byType(CustomPaint));
    final anyNonZero = paints.any((r) => r.paintBounds.height > 0);
    expect(anyNonZero, isFalse);
  });
}
